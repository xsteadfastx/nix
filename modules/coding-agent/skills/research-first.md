---
name: research-first
description: Research-before-code discipline, loaded in every repo. Before writing any new function, module, dependency, or integration, FIRST run `rg` against the local codebase to find what already exists, and ONLY THEN fall back to web_search. Prevents reinventing repo code and importing solutions that conflict with local conventions.
---

# research-first — rg local first, then web_search

A research-before-code discipline for **every** repo. Run it before writing any
new function, module, dependency, or integration you suspect might already
exist.

## The rule (two steps, in order)

1. **`rg` the local codebase.** Search the repo for existing implementations,
   helpers, deps, and patterns before writing anything. Check the dependency
   manifest (`package.json` / `go.mod` / `Cargo.toml` / `pyproject.toml` / …)
   for an installed package that already does it. Check `git log -S "<symbol>"`
   if it may have been tried and reverted.
2. **Only then `web_search`.** If local search came up empty, fall back to the
   web: official docs, registry search (npm / PyPI / crates.io / pkg.go.dev),
   upstream issues/PRs.

If you reach for `web_search` before running `rg` against the current repo,
**stop and go back to step 1.** The only exception is a question that is
inherently external and current (e.g. "what's the latest release of X"), where
local code cannot answer.

## Stop at the first hit

Cheap local checks first, expensive remote ones last. Stop the moment you find
a match — don't collect more evidence than you need.

```
1. rg the repo          → found? reuse it, don't rewrite
2. check the dep manifest → found? use the installed package
3. web_search / web_visit → only after 1 and 2 are empty
```

## Decision

| Signal | Action |
|--------|--------|
| Already in the repo | **Reuse** — call the existing code |
| Already in the deps | **Adopt** — use the installed package |
| Nothing local, web has it | **Adopt/Extend** — install + thin wrapper if needed |
| Nothing anywhere | **Build** — minimal custom code, informed by research |

## Evidence requirement

Before writing net-new code, state in one line what you searched and found:

> "Local: `rg` in repo (no existing helper), checked `package.json` (no dep).
> Web: npm search (no maintained match). Building."

## Anti-patterns

- **`web_search` before `rg`** — the #1 failure mode this skill exists to
  prevent.
- **Reinventing repo code** — writing a utility that already exists locally.
- **Adding a dependency** for functionality already covered by an installed
  package.
- **Silent skipping** — reporting "nothing found" when `rg` was never run.
- **Jumping to `write` / `edit`** before `rg`.