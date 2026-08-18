# Gitea Mirror Mobile — Roadmap

Known gaps, observed from the repository. Limitations, not a schedule. Concrete defects are in
[`internal/known-issues.md`](./internal/known-issues.md).

## Expo Go only

There is no `eas.json` and no native build configuration, so the app runs through Expo Go
rather than as an installable build.

That keeps development possible from Windows, which is a real benefit — and it means the app
cannot be distributed, cannot run without Expo Go installed, and inherits Expo Go's stricter
networking rules. Those rules are the cause of the certificate problem that stops most first
attempts.

An EAS build would relax the transport constraints and make the app installable, at the cost of
needing a build service.

## Gaps

**Response types are hand-maintained.** `src/types/giteaMirror.ts` describes someone else's API
with nothing generating or validating it, so a Gitea Mirror upgrade can drift from it silently
— surfacing as something rendering wrong rather than as an error.

**No screen tests.** The three suites cover `lib/` only. Reasonable for the size, and it means
navigation and rendering are unverified.

**No offline behaviour.** Every screen needs the instance. There is no cache, so a dropped
connection is a blank app rather than a stale one.

**Polling has no interval control** and no manual refresh documented, so the only way to force
an update is to move between tabs.

**No CI.** There is a Jest suite and nothing runs it on push.

**No push notifications**, so a failed sync is only visible when you open the app — arguably
the feature a phone client exists for.

## Non-goals

- **Being a Gitea client.** This manages *mirrors* through Gitea Mirror; it is not a general
  Git forge app.
- **Its own account system.** Signing in with the instance's existing credentials is what keeps
  it a second front end rather than a second system.
- **Storing credentials on the device.** The current arrangement — URL and email only — is
  deliberate.
