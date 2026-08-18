# Gitea Mirror Mobile — Troubleshooting

## Cannot connect from an iPhone

The most common problem by a wide margin, and it is iOS rather than the app.

App Transport Security inside Expo Go rejects:

- plain `http://` endpoints
- HTTPS with a self-signed or untrusted certificate

An instance at `http://192.168.1.50:4321` will fail from an iPhone even though the phone can
reach it. Options:

- **A trusted certificate** — a reverse proxy with Let's Encrypt in front of your instance.
- **A secure tunnel** — Cloudflare Tunnel, Tailscale Funnel, or ngrok gives you a trusted
  HTTPS hostname.

Android is more permissive, so testing there can confirm the app itself is fine.

## Expo Go will not load the app at all

The phone and the computer running `npm start` must be on the same network. A guest VLAN,
client isolation, or a VPN on either device breaks the connection.

## Login fails with correct credentials

- **Confirm the same credentials work in the web UI.** Authentication goes to your instance's
  endpoints, so a failure there is a failure here.
- **Check the instance URL** — a trailing path or the wrong port reaches something that is not
  the API.
- **Check the instance is actually up**, by loading its web UI from the phone's browser.

## Signed in, but the screens are empty

Usually the instance has nothing to show yet — no mirrored repositories or organizations. Check
the web UI.

If the web UI has content and the app does not, the response shape may have changed; see below.

## Everything worked, then broke after upgrading Gitea Mirror

Likely a response shape change. `src/types/giteaMirror.ts` is a hand-written description of
your instance's API, and nothing negotiates a version — so a server upgrade can alter a field
this app expects.

The symptom is usually something rendering blank or wrong rather than a clear error.

## Data looks stale

The app polls rather than holding a live connection, so a change made elsewhere appears on the
next poll. Leaving and returning to a tab is the quickest way to force it.

## An action failed

Check the dashboard's rate-limit status. Gitea Mirror talks to upstream forges on your behalf,
and a sync refused for quota reasons surfaces there rather than as an app error.

## Signed out unexpectedly

The session is your instance's cookie, so its expiry rules apply. Sign in again — the instance
URL and email are remembered.

## Tests fail

```bash
npm test
```

The three suites cover `src/lib/` and need no simulator or instance. A failure there is code,
not environment.
