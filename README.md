<!-- Logo -->
<h1 align="center">Gitea Mirror Mobile</h1>

<!-- Copy -->
<h4 align="center">An Expo client for your self-hosted Gitea Mirror instance — monitor mirrors and trigger syncs from your phone.</h4>

<!-- Badges -->
<div align="center">
  <img alt="GitHub Issues" src="https://img.shields.io/github/issues/willtheorangeguy/gittea-mobile">
  <img alt="GitHub Pull Requests" src="https://img.shields.io/github/issues-pr/willtheorangeguy/gittea-mobile">
  <img alt="License" src="https://img.shields.io/github/license/willtheorangeguy/gittea-mobile">
  <img alt="Expo" src="https://img.shields.io/badge/Expo-000020?logo=expo&logoColor=white">
</div>

<!-- Navigation -->
<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#support">Support</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#license">License</a>
</p>

## Key Features

- Connect to any Gitea Mirror instance by URL, signing in with your existing web account.
- Dashboard health, recent activity, and rate-limit status at a glance.
- Browse mirrored repositories and organizations.
- Trigger mirror, sync, retry, approve, ignore, and include actions.
- Add new repositories and organizations to the mirror.
- Your password is never stored on the device — see [`docs/architecture.md`](docs/architecture.md).

## Installation

```bash
npm install
npm start
```

Then scan the QR code with **Expo Go** on your phone. See [`docs/installation.md`](docs/installation.md).

## Usage

Enter your instance URL, sign in with the same account you use in the web UI, and the tabs cover the rest.

## Documentation

Full documentation lives in [`docs/`](docs/README.md):
[Quickstart](docs/quickstart.md) · [Installation](docs/installation.md) · [Configuration](docs/configuration.md) · [Architecture](docs/architecture.md) · [API](docs/api.md) · [Development](docs/development.md) · [FAQ](docs/faq.md) · [Troubleshooting](docs/troubleshooting.md) · [Roadmap](docs/roadmap.md)

## Support

Open a [GitHub Discussion](https://github.com/willtheorangeguy/gittea-mobile/discussions/new) or file an [issue](https://github.com/willtheorangeguy/gittea-mobile/issues/new/choose).

## Contributing

Contributions welcome. See the org-wide [Contributing Guide](https://github.com/willtheorangeguy/.github/blob/main/CONTRIBUTING.md) and [Code of Conduct](https://github.com/willtheorangeguy/.github/blob/main/CODE_OF_CONDUCT.md).

## Credits

Built with [Expo](https://expo.dev/) and [React Native](https://reactnative.dev/), against a self-hosted [Gitea Mirror](https://github.com/RayLabsHQ/gitea-mirror) instance.

## License

MIT — see [`LICENSE.md`](LICENSE.md).

> **iOS will refuse plain HTTP and self-signed certificates** inside Expo Go. Your instance needs a trusted HTTPS certificate or a secure tunnel — see [`docs/troubleshooting.md`](docs/troubleshooting.md).
