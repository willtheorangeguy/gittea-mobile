# Gitea Mobile for iOS

A native SwiftUI client for your self-hosted Gitea server, with a GitHub-style mobile workflow. Open the Xcode project, choose an iPhone simulator, and run. No npm install, Metro server, CocoaPods, or third-party Swift dependencies are required.

## Run in Xcode

1. Open **`Gitea.xcodeproj`** from this repository’s root.
2. Select the **Gitea** scheme and an iPhone simulator.
3. Press **⌘R**.
4. Choose **Explore a demo account**, or connect your Gitea server using an access token or browser sign-in.

Requires **Xcode 16 or newer** and **iOS 17 or newer**. iPhone and iPad are supported. For a physical iPhone, select your Apple development team in the Gitea target’s **Signing & Capabilities**, choose your device, and run. Change the bundle identifier if your team requires a unique one.

## Connect your own server

Enter your instance’s base URL, for example:

- `https://git.example.com`
- `https://example.com/gitea` for a reverse-proxy subpath
- `http://192.168.1.20:3000` for a server on your private network
- `http://localhost:3000` for a server on this Mac when using the simulator

Create a personal access token in **Gitea → Settings → Applications**. The connection screen links to those settings for your entered server. Sign in with that token, not your account password. For all implemented features, grant `write:user`, `read:organization`, `write:repository`, `write:issue`, and `write:notification`, with access to the repositories you want to use. Read-only tokens can browse; actions requiring additional scopes will report permission errors. Your account’s repository permissions still apply.

Access tokens, OAuth refresh tokens, and server details are stored in the **iOS Keychain** without migrating to other devices. Credentials are normally accessible only while unlocked. Opting into background notification checks changes their accessibility to after the first unlock following a restart, so checks can run while the device is locked; disabling checks restores the default. Sign-out removes them. The last server URL, appearance and notification preferences, and a notification deduplication ledger of IDs/timestamps use UserDefaults. Notification titles and bodies are not persisted in that ledger. Requests go directly to your server; the app has no analytics or intermediary backend.

HTTPS is required for public hosts. HTTP is accepted only for localhost, `.local` names, and RFC 1918/IPv4 loopback addresses. The app’s ATS configuration permits private-network HTTP; URL validation enforces that restriction before credentials are used. TLS certificate validation remains enabled. For a private CA, install and trust your CA on the device, or use a trusted HTTPS certificate. The client rejects HTTP redirects; enter the final canonical server URL. On a physical iPhone, use the Mac/server’s LAN address rather than `localhost`, and allow local-network access when iOS asks. Remote access to a private instance requires your usual VPN or reachable HTTPS endpoint.

## Browser sign-in (OAuth)

Gitea 1.23+ supports the granular scopes used by this app. Each self-hosted instance requires its own public OAuth application registration:

1. In your server’s **Settings → Applications**, create an OAuth2 application named **Gitea Mobile**.
2. Disable **Confidential client** and register the redirect URI **`giteamobile://oauth/callback`** exactly.
3. In the app, select **Browser sign-in**, enter the server URL and the application’s **Client ID**, then choose **Continue in browser**.
4. Sign in and approve access on Gitea’s page. The app never receives your password or needs a client secret.

The flow uses `ASWebAuthenticationSession`, PKCE S256, a cryptographically random state value, strict callback validation, and the same scopes listed above. Access and refresh tokens stay in Keychain. Expiring tokens refresh automatically; concurrent API calls share one refresh operation. A request rejected with HTTP 401 refreshes and retries once. Sign-out prevents a late refresh from restoring credentials. To revoke authorization on the server, remove the grant in your Gitea application settings.

## Device alerts

Open **Profile → Device alerts** to opt in. The first successful check establishes a baseline without alerting for your existing unread backlog. Subsequent new or updated unread threads produce local alerts. Tap an alert to open its conversation; alerts from a different signed-in account are ignored. Private titles are hidden unless you enable previews.

Checks run while the app is active and through iOS Background App Refresh. The app requests an opportunity after 15 minutes; **iOS chooses the actual timing and may defer or skip checks**. Your instance or VPN must be reachable. Up to 300 unread threads are checked per run. **Check now** and the last successful check time are available in settings. Disabling checks or signing out clears the app’s scheduled/delivered alerts and badge.

These are local alerts from periodic checks, **not APNs push notifications**. True push requires a notification relay and Apple push credentials; see [the feature-gap roadmap](docs/feature-gaps.md).

## Implemented

- Home with personal work shortcuts and repositories.
- Repository lists, starred repositories, organization repositories, and server-wide search.
- Repository details, star/unstar, rendered README, branch selection, nested code browsing, text preview and sharing.
- Issues: open/closed filters, involvement filters, search, creation, Markdown descriptions, comments, close and reopen.
- Pull requests: creation between branches, conversation, changed files, unified diff, comment/approve/request-changes reviews, and merge confirmation. Merge requests include the reviewed head SHA and never force a merge.
- Notifications: unread/all filters, opening threads, swipe to mark read, mark all read, and opt-in local alerts from foreground/background checks.
- OAuth browser sign-in with PKCE and automatic refresh, alongside personal access tokens.
- Commit history, release notes and asset links.
- Profile, organizations, sign-out/server switching, system/light/dark appearance.
- Pagination, pull-to-refresh, loading, empty and error states.
- An isolated, mutable demo account for trying the flows without a server.

This is an independent client, not affiliated with GitHub or Gitea. It implements the core mobile workflows; it does not claim feature parity with every GitHub Mobile or Gitea web feature. APNs push notifications, multiple simultaneous accounts, offline synchronization, inline line-by-line review comments, file editing, Actions administration, and repository administration are not implemented. Text/diff previews are limited to 1 MB; Markdown rendering supports headings, inline formatting, lists as text, and fenced code. Repository pull-request filtering applies to loaded pages because that API endpoint does not support text search; Explore searches across the server. Notification badges reflect fetched threads, not a server-wide total.

## Test

```sh
xcodebuild -project Gitea.xcodeproj -scheme Gitea \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/DerivedData test
```

Unit tests cover self-hosted URL normalization, credential-bearing requests, API failures, file decoding, pagination, demo mutations, PKCE/state validation, refresh coordination, sign-out races and notification deduplication. UI tests exercise onboarding, repositories, code, issue creation, comments, notification handling, OAuth setup, and alert settings. The optional local integration harness is described in [docs/ios-development.md](docs/ios-development.md).

## Project layout

- `Gitea/Core`: typed API models, URLSession client, Keychain session and demo service.
- `Gitea/Views`: SwiftUI screens and reusable components.
- `GiteaTests`, `GiteaUITests`: unit and simulator UI tests.
- `scripts/generate-xcode-project.py`: deterministic, dependency-free project regeneration after adding source files.
- `scripts/generate-icon.swift`: regenerates the app icon with AppKit.

The original Expo Gitea **Mirror** dashboard is preserved in `App.tsx` and `src/`. It is a separate legacy application for a different service. Its setup remains in [docs/legacy-expo.md](docs/legacy-expo.md). Use the root Xcode project for this iOS application.

## API reference

Implemented against the [Gitea 1.24 API](https://docs.gitea.com/api/1.24/) and [Gitea authentication/scopes documentation](https://docs.gitea.com/development/api-usage/). Older instances may lack individual endpoints; server errors are presented in the relevant screen.

MIT — see [LICENSE.md](LICENSE.md).
