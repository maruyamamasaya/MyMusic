# AI development foundation

## Request

Strengthen the repository so AI agents can locate, change, and validate only the minimum relevant code safely.

## Investigation

Remote `origin/main` was fetched and made the source of truth before changes. Its latest architecture includes the iOS app, Apple Watch remote target, Python Analyzer, and local Analytics. It already has `SOURCE_INDEX.md`, which fulfills the CODEMAP role without duplicating a second index. `CURRENT.md` had accumulated historical detail; testing/operations ownership, scoped rules, and a standard verification command were absent.

## Changes

- Added search-first navigation and concise current-state guidance while preserving current remote functionality, including Apple Watch.
- Added Fast/Full validation map, operations ownership, scoped `AGENTS.md` files, and the macOS verification entry point.
- Made `SOURCE_INDEX.md` explicitly the search-starting CODEMAP and documented search-tool selection.
- AI 向けに追加・更新した文書を日本語中心へ統一した。

## Validation

- Document paths and `git diff --check` passed. This Windows environment has no Bash or Python command on `PATH`, so the shell syntax and runtime suites remain unexecuted. Full validation requires configured Python, Node, Xcode, and a Simulator.

## Result

The primary guidance now routes agents from a small root contract to the current state, search index, nearest rules, references, tests, and only then implementation.

## Remaining Issues

- Dedicated lint and CI remain unconfigured. Device verification and the full test suite require a macOS/Xcode development environment.
