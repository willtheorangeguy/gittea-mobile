# Gitea Mirror Mobile — Development

## Setup

```bash
npm install
npm start
```

Expo prints a QR code; Expo Go on the phone loads it.

## Scripts

| Command | Does |
|---|---|
| `npm start` | Expo dev server |
| `npm test` | Jest |
| `npm run ios` | Native iOS build — needs macOS and Xcode |
| `npm run android` | Native Android build — needs the Android SDK |
| `npm run web` | Expo web target |

Expo Go is what the project is arranged around, so `npm start` is the everyday loop and the
native targets are rarely needed.

## Tests

```bash
npm test
```

Three suites, all covering `src/lib/` rather than screens:

| File | Covers |
|---|---|
| `__tests__/api.test.ts` | The request layer |
| `__tests__/format.test.ts` | Display formatting |
| `__tests__/storage.test.ts` | What persists on the device |

Testing the library and not the screens is a reasonable split for an app this size — the logic
that can be wrong lives in `lib/`, and it runs without a simulator.

`storage.test.ts` is worth keeping honest: it is the guard on *what gets written to the
device*, and the current answer is deliberately narrow.

## Where to make changes

| Change | Where |
|---|---|
| A new endpoint or request | `src/lib/api.ts` — screens should not fetch |
| Response shapes | `src/types/giteaMirror.ts` |
| A new screen or tab | `src/screens/` |
| A reusable row or badge | `src/components/` |
| Colours and spacing | `src/theme.ts` |

## Keep fetching in `api.ts`

Every request is there, which is what keeps the base URL, `credentials: "include"`, and error
handling in one place — and what lets `api.test.ts` cover the request layer without rendering.

A `fetch` in a screen breaks all three.

## Keep storage narrow

Only the instance URL and the last email are persisted, and deliberately so: AsyncStorage is
not encrypted. Adding a password or a token there would be a meaningful downgrade even though
it would work.

## Types are hand-maintained

`types/giteaMirror.ts` describes your instance's responses. Nothing generates or validates it,
so a Gitea Mirror upgrade can drift from it without any error until something renders wrong.

## Testing against a real instance

You need one running and reachable over trusted HTTPS from the phone. See
[Installation](./installation.md) — that requirement catches most people before any code
matters.
