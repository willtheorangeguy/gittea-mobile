# CLAUDE.md

## Project Overview

Gittea Mobile is a React Native (Expo) mobile app for connecting to a self-hosted Gitea Mirror instance. It supports iOS, Android, and web. Built with TypeScript in strict mode.

## Commands

- `npm install` — install dependencies
- `npm start` — start Expo dev server
- `npm test` — run Jest test suite
- `npm test -- --no-coverage` — run tests without coverage (used in CI)
- `npm run android` / `npm run ios` / `npm run web` — platform-specific launch

## Project Structure

```
src/
  components/    # Reusable UI components
  lib/           # Core logic: API client, storage, formatting utilities
  screens/       # App screens (Connect, Login, MainShell, Dashboard, Repos, Orgs, Settings)
  types/         # TypeScript interfaces for Gitea Mirror API responses
  theme.ts       # Design system (colors, spacing)
  __tests__/     # Unit tests (api, format, storage)
assets/          # App icons, splash screens, favicon
App.tsx          # Root app component — state management, routing, data fetching
index.ts         # Entry point — registers root component with Expo
```

## Architecture

- **Auth:** Cookie-based session authentication via Better Auth endpoints
- **State:** App-level snapshot state (dashboard, repos, orgs, activity) managed in `App.tsx`
- **Data sync:** Polling-based refresh mechanism
- **API client:** Custom `GiteaMirrorClient` class in `src/lib/api.ts`
- **Storage:** AsyncStorage wrapper (`src/lib/storage.ts`) for persisting instance URL and email

## Testing

- Framework: Jest with `jest-expo` preset
- Tests live in `src/__tests__/`
- Test patterns: `**/__tests__/**/*.{ts,tsx}`, `**/*.{spec,test}.{ts,tsx}`

## CI/CD

- GitHub Actions workflow (`.github/workflows/test.yml`): runs `npm ci` then `npm test -- --no-coverage` on Node 20
- Dependabot configured for weekly npm updates (minor/major only)

## Conventions

- TypeScript strict mode — no `any` types
- No ESLint or Prettier configured; rely on TypeScript for correctness
- Centralized theme in `src/theme.ts` — use palette colors and spacing constants
- No external state management library — state lives in `App.tsx`
