# Gitea Mirror Mobile — FAQ

## It will not connect to my instance over HTTP.

Correct, and not a bug you can configure around. iOS applies App Transport Security inside
Expo Go and rejects plain `http://` as well as self-signed certificates.

You need a trusted certificate or a secure tunnel — Cloudflare Tunnel, Tailscale Funnel, and
ngrok all work. See [Installation](./installation.md).

## Is my password stored on my phone?

No. Only the instance URL and the email you last used are saved. The password goes to your
instance's login endpoint and is not retained.

The session is a cookie held by the platform's networking layer, so there is no token in app
storage either — which matters, because AsyncStorage is not encrypted.

## Do I need a separate account or API token?

No. Sign in with the same email and password as the web UI. The app adds no account system of
its own.

## Does it work on Android?

Yes, and often more easily — Android is more permissive about certificates than iOS, so a
setup that fails on iPhone may work there.

## Why does it not update instantly?

It polls rather than holding a live connection. A mirror's status changes when a sync runs, so
a short delay costs nothing — and polling avoids sockets, reconnection logic, and
background-execution rules on both platforms.

## Can I use it offline?

No. Every screen reflects your instance's current state, and there is no local cache.

## What can I actually do from the app?

Everything the web UI does for mirrors: review dashboard health, activity, and rate limits;
browse repositories and organizations; run mirror, sync, retry, approve, ignore, and include;
and add new repositories and organizations.

## Why is there no App Store build?

There is no `eas.json` and no native build configuration — the project targets Expo Go, which
keeps development possible from Windows. See [Roadmap](./roadmap.md).

## Will it break when I upgrade Gitea Mirror?

Possibly. `src/types/giteaMirror.ts` is a hand-written description of your instance's
responses with nothing negotiating a version, so a changed shape surfaces as something
rendering wrong rather than as a clear error.

## Why is the repository called `gittea-mobile`?

A typo that stuck. The app, its slug, and the product are all "gitea".
