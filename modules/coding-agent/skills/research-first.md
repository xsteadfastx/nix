---
name: research-first
description: Research-before-code discipline, loaded in every repo. Before writing any new function, module, dependency, or integration, run `rg` against the local codebase AND search the web — both, every time, local first then web_search. Prevents reinventing repo code and importing solutions that conflict with local conventions or miss better-maintained upstream options.
---

# research-first — rg local first, then web_search

A research-before-code discipline for **every** repo. Run it before writing any
new function, module, dependency, or integration you suspect might already
exist.

## The rule (both, every time — local first, then web)

The point of researching is two things at once: **know what's already in your
repo**, and **know how people on the internet do this.** Both, every time.

1. **`rg` the local codebase.** Search the repo for existing implementations,
   helpers, deps, and patterns before writing anything. Check the dependency
   manifest (`package.json` / `go.mod` / `Cargo.toml` / `pyproject.toml` / …)
   for an installed package that already does it. Check `git log -S "<symbol>"`
   if it may have been tried and reverted. → *tells you what's already here and
   which conventions you must not clash with.*
2. **`web_search` the web.** Always do this too — not as a fallback, but as a
   required second step. Official docs, registry search (npm / PyPI / crates.io
   / pkg.go.dev), upstream issues/PRs, blog posts, Stack Overflow. → *tells you
   how the broader community solves this, what the established pattern is, and
   what pitfalls people hit.*

Local comes first so you don't reinvent or conflict with what's already here;
web comes second so you learn the conventional, battle-tested way to do it
instead of inventing your own. **Skipping either is a failure** — you'd be
flying blind on one axis. The only exception is a change so repo-local it has
no external analogue (e.g. renaming an internal helper) — and even then, say
so.

## Stop at the first *blocker*, not the first hit

Local is cheap, web is slower — run `rg` first, then `web_search`. You don't
need to exhaust every channel before acting, but you DO need both tiers
represented before writing net-new code.

```
1. rg the repo          → reuse if found, but still check the web for a better option
2. check the dep manifest → use the installed package if it fits
3. web_search / web_visit → ALWAYS run; confirm upstream state + alternatives
```

## Decision

| Signal | Action |
|--------|--------|
| Already in the repo | **Reuse** — call the existing code |
| Already in the deps | **Adopt** — use the installed package |
| Nothing local, web has it | **Adopt/Extend** — install + thin wrapper if needed |
| Nothing anywhere | **Build** — minimal custom code, informed by research |

## Evidence requirement

Before writing net-new code, state in one line what you searched and found,
covering BOTH tiers:

> "Local: `rg` in repo (no existing helper), checked `package.json` (no dep).
> Web: npm search + the library docs (no maintained match). Building."

## Anti-patterns

- **Web before local** — calling `web_search` before `rg`-ing the repo and
  reading the dependency manifest. Local must come first.
- **Local-only, no web** — skipping `web_search` because "local came up
  empty" or "I already know this." The web tier is mandatory, not a fallback.
- **Reinventing repo code** — writing a utility that already exists locally.
- **Adding a dependency** for functionality already covered by an installed
  package.
- **Silent skipping** — reporting "nothing found" when `rg` or `web_search`
  was never run.
- **Jumping to `write` / `edit`** before both tiers are checked.