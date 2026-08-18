# Gitea Mirror Mobile — API

This app exposes no API. It consumes the one your **Gitea Mirror** instance already serves —
the same endpoints its web UI uses.

All requests live in `src/lib/api.ts`.

## Authentication

Cookie-based, against your instance's existing Better Auth endpoints:

```
POST  login   { email, password }   ─►  session cookie
```

Subsequent requests use `credentials: "include"`, so the cookie travels automatically. There
is no API token to generate and no separate mobile credential — if you can sign in to the web
UI, you can sign in here.

## What it reads

| Area | Used for |
|---|---|
| Dashboard | Health, recent activity, rate-limit status |
| Repositories | The mirrored repository list and their states |
| Organizations | The mirrored organization list |

## What it changes

Actions available on repositories and organizations:

`mirror`, `sync`, `retry`, `approve`, `ignore`, `include`

Plus adding new repositories and organizations to the mirror.

These are the same operations the web UI performs — the app is a second front end, not a
second system.

## Rate limits

The dashboard surfaces your instance's rate-limit status, which matters because Gitea Mirror
talks to upstream forges on your behalf. A sync that fails for quota reasons shows there
rather than as an app error.

## Base URL

Whatever you enter on the Connect screen, stored on the device. Every request is relative to
it, so pointing the app at a different instance is a matter of reconnecting.

## Versioning

There is none. `src/types/giteaMirror.ts` is a hand-written description of your instance's
responses, and nothing negotiates a version — so an upgrade on the server can change a shape
this app expects. See [Roadmap](./roadmap.md).

## Transport

HTTPS with a trusted certificate, on iOS. See [Installation](./installation.md).
