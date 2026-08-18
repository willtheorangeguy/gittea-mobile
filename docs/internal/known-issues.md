# Known Issues — gittea-mobile

Concrete defects and gaps found while writing this repository's documentation in
August 2026. **Nothing here was changed** — each one needs a code, configuration, or
licensing decision rather than a documentation one.

Ordered by severity. See [`docs/roadmap.md`](../roadmap.md) for the narrative version,
which also covers deliberate non-goals.


**3 open:** 3 low.

## 1. A Jest suite exists and nothing runs it

**Severity:** Low  
**Where:** `.github/workflows/` — none present

**What:** Three test suites cover `src/lib/` — the request layer, formatting, and device storage — and there is no CI workflow.

**Why it matters:** `storage.test.ts` in particular is the guard on what gets written to the device, and the current answer is deliberately narrow: instance URL and email only, no password or token. That property is worth defending automatically, since AsyncStorage is not encrypted and a well-meaning change could widen it without anyone noticing.

**Suggested fix:** Add a workflow running `npm test` on push and pull request.

## 2. Response types are hand-maintained with nothing validating them

**Severity:** Low  
**Where:** `src/types/giteaMirror.ts`

**What:** The file describes the Gitea Mirror instance's API responses. Nothing generates it from the server and nothing negotiates a version.

**Why it matters:** A Gitea Mirror upgrade can change a shape this app expects, and the symptom is a screen rendering blank or wrong rather than a clear error — the kind of failure that is easy to misread as a connection problem.

**Suggested fix:** Validate responses at the boundary in `api.ts`, so a shape change fails loudly and names the field.

## 3. The repository name is misspelled

**Severity:** Low  
**Where:** repository name `gittea-mobile`

**What:** The app, its Expo slug, and the product are all `gitea-mirror-mobile` / "Gitea Mirror Mobile". Only the repository carries the doubled `t`.

**Why it matters:** Harmless, and it makes the clone URL and every badge in the README inconsistent with the thing they describe.

**Suggested fix:** Renaming a repository on GitHub leaves a redirect, so the cost is low if it is worth tidying.


---

## Also, across every repository

**`.bandit` is present on disk but untracked in git.** Verified in PyWorkout, treklogger,
skyscanner-cli, booking-cli, piggy, and aibot — the config file exists locally in each but
`git ls-files` does not know about it, so none of it reached GitHub.

The August 2026 security sweep therefore looks complete locally and landed nowhere. Worth
checking across all 44 repositories it covered.
