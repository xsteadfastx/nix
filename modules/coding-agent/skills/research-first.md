---
name: research-first
description: Research-before-code discipline, loaded in every repo. Before writing any new function, module, dependency, or integration, run `rg` against the local codebase, search the web, AND search GitHub — all three, every time, local first then web_search then `gh search`. Prevents reinventing repo code and importing solutions that conflict with local conventions or miss better-maintained upstream options.
---

# research-first — rg local, then web_search, then `gh search`

A research-before-code discipline for **every** repo. Run it before writing any
new function, module, dependency, or integration you suspect might already
exist.

## The rule (all three, every time — local → web → GitHub)

The point of researching is three things at once: **know what's already in
your repo**, **know how people on the internet do this**, and **know what
code/projects already exist on GitHub**. All three, every time.

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
3. **`gh search` GitHub.** Always do this too — the `gh` CLI is on your PATH
   (a sops-reading wrapper on hosts that provision a `gh-token` secret), so
   use it. `gh search code <query>` finds real
   implementations across public repos; `gh search repos <query>` finds
   maintained projects; `gh search prs`/`gh search issues` surfaces upstream
   discussion and known pitfalls. → *tells you what battle-tested code already
   exists that you can study, vendor, or depend on instead of inventing.*

Local comes first so you don't reinvent or conflict with what's already here;
web comes second so you learn the conventional way; GitHub comes third so you
find concrete, reusable code. **Skipping any is a failure** — you'd be flying
blind on one axis. The only exception is a change so repo-local it has no
external analogue (e.g. renaming an internal helper) — and even then, say so.

## Stop at the first *blocker*, not the first hit

Local is cheap, web is slower, GitHub is in between — run `rg` first, then
`web_search`, then `gh search`. You don't need to exhaust every channel
before acting, but you DO need all three tiers represented before writing
net-new code.

```
1. rg the repo          → reuse if found, but still check the web + GitHub for a better option
2. check the dep manifest → use the installed package if it fits
3. web_search / web_visit → ALWAYS run; confirm upstream state + alternatives
4. gh search code/repos  → ALWAYS run; find real implementations + maintained projects
```

## Decision

| Signal | Action |
|--------|--------|
| Already in the repo | **Reuse** — call the existing code |
| Already in the deps | **Adopt** — use the installed package |
| Nothing local, web/GitHub has it | **Adopt/Extend** — install + thin wrapper if needed |
| Nothing anywhere | **Build** — minimal custom code, informed by research |

## Evidence requirement

Before writing net-new code, state in one line what you searched and found,
covering ALL THREE tiers:

> "Local: `rg` in repo (no existing helper), checked `package.json` (no dep).
> Web: npm search + the library docs (no maintained match).
> GitHub: `gh search code` found 2 hits, both unmaintained. Building."

## Anti-patterns

- **Web/GitHub before local** — calling `web_search` or `gh search` before
  `rg`-ing the repo and reading the dependency manifest. Local must come first.
- **Local-only, no web/GitHub** — skipping `web_search` or `gh search` because
  "local came up empty" or "I already know this." The web and GitHub tiers are
  mandatory, not a fallback.
- **Reinventing repo code** — writing a utility that already exists locally.
- **Reinventing upstream code** — writing something a `gh search code` would
  have found already implemented and battle-tested in a public repo.
- **Adding a dependency** for functionality already covered by an installed
  package.
- **Silent skipping** — reporting "nothing found" when `rg`, `web_search`, or
  `gh search` was never run.
- **Jumping to `write` / `edit`** before all three tiers are checked.