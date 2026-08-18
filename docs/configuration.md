# Gitea Mirror Mobile — Configuration

There is no configuration file and no environment variables. Everything is entered in the app.

## What you enter

| Setting | Where | Purpose |
|---|---|---|
| Instance URL | Connect screen | Which Gitea Mirror to talk to |
| Email and password | Login screen | Your existing account on that instance |

## What is stored on the device

Exactly two values, via AsyncStorage:

| Key | Holds |
|---|---|
| `gitea-mirror-mobile.instance-url` | The instance URL |
| `gitea-mirror-mobile.login-email` | The email you last used |

**Your password is never written to the device.** It is sent to your instance's login endpoint
and not retained.

The session itself is a cookie, held by the platform's networking layer because requests use
`credentials: "include"` — so there is no token sitting in unencrypted app storage either.

That is the right arrangement, and it is worth stating plainly: AsyncStorage is not encrypted,
so the fact that nothing sensitive is kept there matters.

## Signing out

Clears the stored values and drops the session. The instance URL and email are conveniences,
so losing them costs a retype rather than access.

## Polling

The app refreshes by polling rather than holding a live connection. There is no interval
setting — the trade is simplicity against instant updates, and for mirror status that is a
reasonable one.

## No credentials in the repository

There is no `.env`, no config file, and nothing to fill in before building. Every
instance-specific value is entered at runtime and lives only on the device.
