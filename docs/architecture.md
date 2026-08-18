# Gitea Mirror Mobile — Architecture

## Layout

```
App.tsx              entry point
index.ts             Expo registration
src/
├── screens/
│   ├── ConnectScreen.tsx    enter the instance URL
│   ├── LoginScreen.tsx      sign in
│   ├── MainShell.tsx        tab container
│   ├── DashboardTab.tsx
│   ├── RepositoriesTab.tsx
│   ├── OrganizationsTab.tsx
│   └── SettingsTab.tsx
├── components/       ActivityRow, RepositoryRow, OrganizationRow, StatusBadge, Primitives
├── lib/
│   ├── api.ts        every request to the instance
│   ├── storage.ts    the two persisted values
│   └── format.ts     display formatting
├── types/giteaMirror.ts
├── theme.ts
└── __tests__/        api, format, storage
```

## Three stages, in order

```
  ConnectScreen  ─►  LoginScreen  ─►  MainShell (four tabs)
   instance URL       credentials      the app proper
```

Separating "which server" from "who are you" is what lets the instance URL persist while the
session does not. Returning to the app skips the first screen and not the second.

## Sessions are cookies, not tokens

`api.ts` issues requests with `credentials: "include"`, so authentication rides on a cookie
managed by the platform's networking layer.

Two consequences worth knowing:

- **Nothing sensitive is in app storage.** AsyncStorage holds only the instance URL and the
  last email — no password, no bearer token. Since AsyncStorage is not encrypted, that is the
  distinction that matters.
- **The app inherits the instance's session behaviour** — expiry, renewal, invalidation are
  all decided server-side, so there is no token refresh logic to get wrong.

## One networking module

Every call lives in `src/lib/api.ts`. Screens do not fetch.

That keeps the base URL, the credentials mode, and error handling in one place — and it is
why `__tests__/api.test.ts` can cover the request layer without rendering anything.

## Polling, not push

Dashboard, repositories, organizations, and activity refresh on a poll.

A mirror status is not a chat message: it changes when a sync runs, and a short delay costs
nothing. Polling avoids a socket, a reconnect strategy, and background-execution rules on both
platforms — a reasonable trade for this application, and the reason figures catch up on the
next poll rather than instantly.

## Types mirror the server

`types/giteaMirror.ts` describes the instance's responses. It is a hand-maintained
description of someone else's API, so a Gitea Mirror upgrade can drift from it silently — see
[Roadmap](./roadmap.md).

## Expo Go as the target

There is no `eas.json` and no native build configuration. The project is arranged around
running through Expo Go, which is why the README's setup is `npm start` and a QR code.

That keeps development possible from Windows — the same constraint `adsb-tvos` in this org
solves a different way.
