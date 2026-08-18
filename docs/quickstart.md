# Gitea Mirror Mobile — Quickstart

You need a running Gitea Mirror instance and an account on it.

## 1. Check your instance is reachable over HTTPS

Do this before anything else. **iOS rejects plain HTTP and self-signed certificates** inside
Expo Go, so an instance on `http://192.168.x.x` will not connect from an iPhone.

You need either a trusted certificate or a secure tunnel. See
[Troubleshooting](./troubleshooting.md).

## 2. Install and start

```bash
npm install
npm start
```

Expo prints a QR code in the terminal and opens a browser panel.

## 3. Open it on your phone

1. Install **Expo Go** from the App Store or Play Store.
2. Scan the QR code.
3. The app loads over your local network — so the phone and the computer running Expo need to
   be on the same network.

## 4. Connect

Enter your Gitea Mirror instance URL. It is remembered for next time.

## 5. Sign in

Use the same email and password as the web UI. Authentication goes to your instance's existing
endpoints — this app adds no account system of its own.

Your email is remembered; **your password is not stored**.

## 6. Use it

| Tab | Shows |
|---|---|
| Dashboard | Health, recent activity, rate-limit status |
| Repositories | Mirrored repositories, with actions |
| Organizations | Mirrored organizations, with actions |
| Settings | Connection and sign-out |

Actions available on items include mirror, sync, retry, approve, ignore, and include. New
repositories and organizations can be added to the mirror from here too.

## Refreshing

The app polls for updates rather than holding a live connection, so figures catch up on the
next poll rather than instantly. See [Architecture](./architecture.md).

## Then what

- [API](./api.md) — what it calls on your instance
- [Development](./development.md) — running the tests
