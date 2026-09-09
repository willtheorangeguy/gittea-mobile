#!/usr/bin/env python3
"""Run iOS API checks against a disposable local Gitea, never a user-supplied server.

Usage: python3 scripts/run-local-integration.py /absolute/path/to/gitea
Requires a Gitea 1.24+ binary and the iPhone 16 Pro simulator in Xcode.
"""
import base64
import getpass
import hashlib
import html.parser
import http.cookiejar
import http.client
import http.server
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import urllib.error
import urllib.parse
import uuid

root = Path(__file__).resolve().parent.parent
binary = Path(sys.argv[1]).resolve()
work = Path(tempfile.mkdtemp(prefix="gitea-mobile-integration-"))
fixture = root / ".build/integration/client.json"
fixture.parent.mkdir(parents=True, exist_ok=True)
port, proxy_port = 3189, 3190
server_url = f"http://localhost:{proxy_port}/gitea"
config = work / "app.ini"
config.write_text(f"""APP_NAME = Gitea Mobile Integration
RUN_USER = {getpass.getuser()}
RUN_MODE = prod
WORK_PATH = {work}
[database]
DB_TYPE = sqlite3
PATH = {work}/gitea.db
[repository]
ROOT = {work}/repositories
[server]
HTTP_ADDR = 127.0.0.1
HTTP_PORT = {port}
ROOT_URL = {server_url}/
DISABLE_SSH = true
APP_DATA_PATH = {work}/data
[security]
INSTALL_LOCK = true
[service]
DISABLE_REGISTRATION = true
[log]
MODE = console
LEVEL = Error
""")

class Proxy(http.server.BaseHTTPRequestHandler):
    """Exercise a reverse-proxy URL prefix with the production native client."""
    def do_GET(self): self.forward()
    def do_POST(self): self.forward()
    def do_PUT(self): self.forward()
    def do_PATCH(self): self.forward()
    def do_DELETE(self): self.forward()
    def log_message(self, *args): pass
    def forward(self):
        if not self.path.startswith("/gitea/"):
            self.send_error(404); return
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "connection"}}
        connection.request(self.command, self.path[len("/gitea"):], body=body, headers=headers)
        response = connection.getresponse()
        data = response.read()
        self.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() not in {"transfer-encoding", "connection", "content-length"}: self.send_header(key, value)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        connection.close()

def request(path, method="GET", body=None, auth=None):
    headers = {"Content-Type": "application/json"}
    if auth: headers["Authorization"] = auth
    req = urllib.request.Request(f"http://localhost:{port}/api/v1/{path}", data=json.dumps(body).encode() if body is not None else None, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"{method} {path}: HTTP {error.code}: {error.read().decode()}") from None

class FormFields(html.parser.HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.fields = {}
        self.feed(html)
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "input" and attrs.get("name"):
            self.fields[attrs["name"]] = attrs.get("value", "")

class CaptureCallback(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if newurl.startswith("giteamobile:"): return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def authorize_oauth(client_id, password):
    """Use Gitea's real login/consent pages to obtain a one-use PKCE code."""
    origin = server_url
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), CaptureCallback())
    def fetch(path, fields=None):
        body = urllib.parse.urlencode(fields).encode() if fields is not None else None
        try:
            with opener.open(urllib.request.Request(origin + path, data=body), timeout=30) as response:
                return response.read().decode(), None
        except urllib.error.HTTPError as error:
            location = error.headers.get("Location", "")
            if error.code in (302, 303, 307) and location.startswith("giteamobile://oauth/callback"):
                return "", location
            raise RuntimeError(f"OAuth browser step failed: HTTP {error.code}") from None
    login, _ = fetch("/user/login")
    fields = FormFields(login).fields
    fields.update({"user_name": "mobile-tester", "password": password})
    fetch("/user/login", fields)
    verifier, state = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    params = {"client_id": client_id, "redirect_uri": "giteamobile://oauth/callback", "response_type": "code", "scope": "write:user read:organization write:repository write:issue write:notification", "state": state, "code_challenge": challenge, "code_challenge_method": "S256"}
    consent, callback = fetch("/login/oauth/authorize?" + urllib.parse.urlencode(params))
    if not callback:
        fields = FormFields(consent).fields
        fields["granted"] = "true"
        _, callback = fetch("/login/oauth/grant", fields)
    if not callback: raise RuntimeError("Gitea did not complete OAuth authorization")
    values = urllib.parse.parse_qs(urllib.parse.urlsplit(callback).query)
    if values.get("state") != [state] or "code" not in values: raise RuntimeError("Invalid OAuth callback")
    return values["code"][0], verifier

proxy = None
server = None
simulator = None
try:
    log = open(work / "server.log", "w")
    server = subprocess.Popen([str(binary), "web", "--config", str(config), "--work-path", str(work)], stdout=log, stderr=log)
    for _ in range(100):
        try: request("version"); break
        except Exception: time.sleep(0.1)
    else: raise RuntimeError("Local Gitea did not start")
    proxy = http.server.ThreadingHTTPServer(("127.0.0.1", proxy_port), Proxy)
    threading.Thread(target=proxy.serve_forever, daemon=True).start()
    tokens = []
    bootstrap_auth = None
    for username in ["mobile-tester", "mobile-reviewer"]:
        password = secrets.token_urlsafe(24)
        subprocess.run([str(binary), "admin", "user", "create", "--config", str(config), "--work-path", str(work), "--username", username, "--password", password, "--email", username + "@example.test", "--admin", "--must-change-password=false"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        auth = "Basic " + base64.b64encode(f"{username}:{password}".encode()).decode()
        if username == "mobile-tester": bootstrap_auth = auth; bootstrap_password = password
        result = request(f"users/{username}/tokens", "POST", {"name": "ios-integration", "scopes": ["write:user", "read:organization", "write:repository", "write:issue", "write:notification"]}, auth)
        tokens.append(result["sha1"])
    auth = "token " + tokens[0]
    request("user/repos", "POST", {"name": "mobile-integration", "auto_init": True, "default_branch": "main", "readme": "Default", "private": False}, auth)
    request("orgs", "POST", {"username": "mobile-studio", "full_name": "Mobile Studio"}, bootstrap_auth)
    repo = "repos/mobile-tester/mobile-integration"
    request(repo + "/branches", "POST", {"new_branch_name": "feature/mobile", "old_branch_name": "main"}, auth)
    request(repo + "/contents/src/hello%20%23%3F.swift", "POST", {"branch": "feature/mobile", "content": base64.b64encode(b'print("Hello from self-hosted Gitea")\n').decode(), "message": "Add a Swift file"}, auth)
    request(repo + "/releases", "POST", {"tag_name": "v1.0.0", "target_commitish": "main", "name": "First release", "body": "Native iOS integration test"}, auth)
    oauth = request("user/applications/oauth2", "POST", {"name": "Gitea Mobile Integration", "confidential_client": False, "redirect_uris": ["giteamobile://oauth/callback"]}, auth)
    oauth_code, oauth_verifier = authorize_oauth(oauth["client_id"], bootstrap_password)
    fixture.write_text(json.dumps({"server": server_url, "token": tokens[0], "reviewerToken": tokens[1], "oauthClientID": oauth["client_id"], "oauthCode": oauth_code, "oauthVerifier": oauth_verifier, "password": bootstrap_password}))
    fixture.chmod(0o600)
    output = root / ".build/local-integration.log"
    result_bundle = root / ".build" / ("Integration-" + uuid.uuid4().hex + ".xcresult")
    print("Testing a disposable Gitea server through /gitea reverse-proxy subpath…", flush=True)
    destination = "platform=iOS Simulator,name=iPhone 16 Pro"
    selection = ["-only-testing:GiteaTests/LocalServerTests"]
    if "--ui" in sys.argv:
        runtimes = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"]))["runtimes"]
        runtime = next(r["identifier"] for r in runtimes if r["isAvailable"] and "iOS" in r["name"])
        simulator = subprocess.check_output(["xcrun", "simctl", "create", "Gitea OAuth Integration", "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", runtime], text=True).strip()
        destination = "platform=iOS Simulator,id=" + simulator
        payload = json.loads(fixture.read_text())
        payload["uiSimulatorID"] = simulator
        fixture.write_text(json.dumps(payload))
        selection.append("-only-testing:GiteaUITests/LocalOAuthUITests")
    with output.open("w") as build_log:
        result = subprocess.run(["xcodebuild", "-project", "Gitea.xcodeproj", "-scheme", "Gitea", "-destination", destination, "-derivedDataPath", ".build/DerivedData", "-resultBundlePath", str(result_bundle), "-parallel-testing-enabled", "NO"] + selection + ["test"], cwd=root, stdout=build_log, stderr=subprocess.STDOUT)
    for line in output.read_text().splitlines():
        if "error:" in line or "Test Case" in line or "** TEST" in line:
            print(re.sub(r"eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[redacted token]", line))
    print(f"Log: {output}")
    print(f"Test results: {result_bundle}")
    sys.exit(result.returncode)
finally:
    fixture.unlink(missing_ok=True)
    if proxy: proxy.shutdown(); proxy.server_close()
    if server:
        server.terminate()
        try: server.wait(timeout=10)
        except subprocess.TimeoutExpired: server.kill(); server.wait()
    if simulator:
        subprocess.run(["xcrun", "simctl", "shutdown", simulator], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "delete", simulator], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.rmtree(work)
