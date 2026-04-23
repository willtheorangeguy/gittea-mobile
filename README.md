# Gitea Mirror Mobile

Expo-based mobile client for connecting to a self-hosted Gitea Mirror instance from Windows and testing on iPhone.

## Stack

- Expo + React Native + TypeScript
- Cookie-based session auth against the existing Gitea Mirror Better Auth endpoints
- Polling refresh for dashboard, repositories, organizations, and activity updates

## What This Build Covers

- Connect to a Gitea Mirror instance by URL
- Sign in with the same email/password account used in the web UI
- Review dashboard health, recent activity, and rate limit status
- Monitor repositories and organizations
- Start mirror, sync, retry, approve, ignore, and include actions
- Add new repositories and organizations to the mirror

## Run On Windows

1. Install dependencies:

```bash
npm install
```

2. Start Expo:

```bash
npm start
```

3. Test on iPhone:

- Install `Expo Go` on the phone.
- Scan the QR code from the terminal/browser.
- Make sure the phone can reach your Gitea Mirror instance on the same network, or use a reachable HTTPS URL.

## Important iOS Note

For physical iPhone testing, plain HTTP and self-signed HTTPS endpoints are often rejected by iOS networking inside Expo Go. If your Gitea Mirror instance is not using a trusted certificate, use a proper HTTPS certificate or expose it through a secure tunnel.
