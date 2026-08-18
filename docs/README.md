# Gitea Mirror Mobile — Documentation

An Expo client for a self-hosted Gitea Mirror instance. Windows-friendly to develop, tested on
a phone through Expo Go.

```
gittea-mobile/
├── docs/
│   ├── README.md          this page
│   ├── quickstart.md      install, start, connect
│   ├── installation.md    Expo Go, and what your instance needs
│   ├── configuration.md   what is stored on the device
│   ├── architecture.md    screens, api layer, session handling
│   ├── api.md             the Gitea Mirror endpoints used
│   ├── development.md     scripts, tests, project layout
│   ├── faq.md             HTTPS, credentials, offline
│   ├── troubleshooting.md the iOS certificate problem, login failures
│   └── roadmap.md         known gaps and non-goals
└── src/
    ├── screens/           Connect, Login, MainShell, and four tabs
    ├── components/        rows, badges, primitives
    ├── lib/               api, storage, formatting
    ├── types/             Gitea Mirror response types
    └── __tests__/         api, format, storage
```

## Pages

- [Quickstart](./quickstart.md) — running it against your instance
- [Installation](./installation.md) — Expo Go, and the HTTPS requirement
- [Configuration](./configuration.md) — what persists on the device and what does not
- [Architecture](./architecture.md) — the shape of the app and how sessions work
- [API](./api.md) — what it calls on your Gitea Mirror instance
- [Development](./development.md) — scripts, tests, where to change things
- [FAQ](./faq.md) — certificates, credentials, what it can and cannot do
- [Troubleshooting](./troubleshooting.md) — the iOS certificate rejection, login problems
- [Roadmap](./roadmap.md) — known gaps and non-goals

## The thing that blocks most first attempts

**iOS rejects plain HTTP and self-signed certificates** inside Expo Go. A Gitea Mirror
instance on your LAN over `http://` will not connect from an iPhone, no matter how reachable
it is.

You need a trusted certificate or a secure tunnel. See
[Troubleshooting](./troubleshooting.md).

## Credentials

Your password is **never** written to the device. Only the instance URL and the email you
last used are stored, and the session itself is a cookie held by the platform's networking
layer rather than by the app. See [Configuration](./configuration.md).
