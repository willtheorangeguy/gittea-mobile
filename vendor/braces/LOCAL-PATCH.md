# Local braces security backport

This package is braces 3.0.3 with the depth limits from upstream PR
[#72](https://github.com/micromatch/braces/pull/72), final commit
`28d440b5dd449dbf1fe6f3506cf94ecca4d02660`. Parsing and all recursive AST
walkers reject nesting above 100 levels. The local package version is 3.0.4 so
dependency scanners treat it as outside the affected `<=3.0.3` range.

Replace this backport with the official braces 3.0.4 release when published,
after confirming it includes the depth limits and regression fixes.
