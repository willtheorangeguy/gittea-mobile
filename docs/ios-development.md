# Native iOS development

Open `Gitea.xcodeproj`, select Gitea, and run on iOS 17+. The app has no external Swift dependencies. Sources are explicitly included in the project. After adding files, run `python3 scripts/generate-xcode-project.py` or add them to the appropriate target in Xcode.

## Architecture

`AppSession` owns the authenticated API client and account. Credentials live in Keychain. Every server request uses an app-defined relative API route; server-provided URLs are opened as user-initiated browser links and never used as authenticated API endpoints. URLSession uses an ephemeral configuration, no cookie persistence, and a redirect-rejecting delegate.

`OAuthBrowser` owns the system authentication session. `OAuthAttempt` constructs the PKCE authorization request and validates the exact callback origin/path and random state. `OAuthTransport` exchanges codes and refresh tokens against the configured server’s token endpoint, preserving reverse-proxy subpaths. `OAuthAuthorization` serializes concurrent refreshes. Keychain replacement compares the expected credential record under a lock so late responses cannot restore signed-out credentials. Existing personal-token records remain decodable.

`NotificationService` registers its background task at app launch, fetches unread threads, and delivers local notifications after an explicit user opt-in. The persisted ledger contains only thread IDs/timestamps and an account hash. Permission prompts, privacy previews, cancellation, account changes, and alert cleanup are handled separately from Gitea inbox read/unread state. Background scheduling is best effort and is not APNs push. Opting in changes Keychain accessibility to `AfterFirstUnlockThisDeviceOnly`; disabling checks restores `WhenUnlockedThisDeviceOnly`.

`PageModel` drives pageable lists with deduplication, cancellation and stale-response protection. Views own local loading and mutation state. After successful writes, affected resources reload from the server. The server remains authoritative for access control and merge eligibility.

`DemoServer` is an in-memory actor behind the same typed client. Each entry into the demo resets it. It deliberately provides a small set of sample repositories and conversations rather than pretending to be an actual server. No demo mutation performs network I/O.

Markdown is rendered as native SwiftUI text; executable HTML and embedded web content are not loaded. Avatar requests use HTTPS and carry no API token.

## Simulator

```sh
xcrun simctl boot 'iPhone 16 Pro'
open -a Simulator
xcodebuild -project Gitea.xcodeproj -scheme Gitea \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/DerivedData build
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/Gitea.app
xcrun simctl launch booted app.gitea.mobile
```

For an immediate demo launch, add `--demo` to the final command. UI automation uses `--uitesting` to skip credential restoration; it does not clear a real account’s Keychain entry.

## Verification

Run Product → Test (⌘U), or use the `xcodebuild test` command in the root README. Tests run without a real account. Screenshots from the UI suite are attached to the Xcode test result. Keep Xcode’s default simulator signing enabled: disabling code signing removes the simulated application entitlement that Keychain needs. A paid developer account is not required for simulator builds.

The app targets the Gitea 1.24 API. To check against a real instance, connect with a disposable test account, create a repository with a README and two branches, and exercise create/comment/close/reopen, star/unstar, pull creation/review/merge, branch browsing and notifications. Do not run write checks against production repositories.

For automated real-server testing, download a Gitea binary for your Mac from the official Gitea releases, then run:

```sh
python3 scripts/run-local-integration.py /absolute/path/to/gitea
```

Add `--ui` to also create a disposable iPhone simulator and exercise browser sign-in, Keychain restoration, notification permission/initial checks, and sign-out through the UI. The temporary simulator is shut down and deleted afterward; your normal simulator account is untouched.

The harness creates a temporary SQLite-backed Gitea bound to loopback, two disposable users, scoped tokens, a public OAuth application, a repository, branches and a release. A loopback proxy serves it under `/gitea`. It obtains a PKCE code using Gitea’s real login/consent pages, then runs `LocalServerTests` on the simulator. The tests exercise OAuth exchange/refresh, the production URLSession client, response decoding, stars, issue/comment/state mutations, pull creation, review, diff, merge, notifications and Keychain persistence. The process shuts down and its data and credential fixture are removed when the harness exits. Ports 3189 and 3190 must be free. The tests are skipped during ordinary runs when the fixture is absent.

## Verified locally

On September 8, 2026, the app built with Xcode 16.0 and passed 16 unit tests and eight UI tests on the iPhone 16 Pro / iOS 18 simulator. Three additional integration tests passed against Gitea 1.24.7 through the `/gitea` proxy. They covered browser login/consent, OAuth exchange and refresh, Keychain restoration after relaunch, notification permission and initial checks, sign-out, issue/comment mutations, branch/file decoding, stars, pull creation, approval and merge. Integration cases skip during ordinary tests when the disposable server fixture is absent.

The iPad mini layout was also inspected in dark mode. Physical-device signing, actual iOS background scheduling, APNs delivery, and a user-provided production instance have not been tested. APNs delivery is not implemented in this increment.
