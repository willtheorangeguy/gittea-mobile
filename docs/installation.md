# Gitea Mirror Mobile — Installation

## Requirements

| For | You need |
|---|---|
| Running it | Node, and a Gitea Mirror instance you can sign in to |
| Testing on a phone | Expo Go, and the phone on the same network as your computer |
| Connecting from iOS | Your instance reachable over **trusted** HTTPS |

## Install

```bash
git clone https://github.com/willtheorangeguy/gittea-mobile.git
cd gittea-mobile
npm install
npm start
```

Expo prints a QR code. Scan it with Expo Go.

## The HTTPS requirement

Worth settling before anything else, because it is what stops most first attempts.

iOS applies App Transport Security inside Expo Go, which rejects:

- plain `http://` endpoints, and
- HTTPS with a self-signed or otherwise untrusted certificate.

So a Gitea Mirror instance on your LAN at `http://192.168.1.50:4321` will not connect from an
iPhone even though the phone can reach it perfectly well.

Options:

- **A real certificate**, via a reverse proxy with Let's Encrypt.
- **A secure tunnel** — Cloudflare Tunnel, Tailscale Funnel, ngrok — which gives you a trusted
  HTTPS hostname.

Android is more permissive, so the same setup may work there and fail on iOS.

## Other Expo targets

```bash
npm run ios       # requires macOS with Xcode
npm run android   # requires the Android SDK
npm run web
```

These build natively rather than running through Expo Go. Expo Go is the path the project is
set up around.

## Verify

Enter your instance URL on the Connect screen. If it accepts the URL and reaches the login
screen, networking is fine.

## Next

[Quickstart](./quickstart.md), or [Configuration](./configuration.md).
