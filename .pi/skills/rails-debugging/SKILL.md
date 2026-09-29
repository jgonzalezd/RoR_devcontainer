---
name: rails-debugging
description: Systematic debugging for Rails issues (failing tests, 500s, wrong data, slow queries). Use when behavior is broken or unexpected.
metadata:
  layer: backend
  upstream: none
---

# Rails debugging

> Run commands from `.pi/project-profile.md` where listed; the examples below
> are Rails defaults.

Loop: reproduce -> isolate -> hypothesize -> verify -> fix with a regression test.

## Steps

1. Reproduce with the smallest command (single test, focused request, or runner script).
2. Read full backtrace; find first frame in `app/` or `lib/`.
3. Check logs (`log/test.log` / `log/development.log`) for params, SQL, rollbacks.
4. Inspect state safely (`bin/rails console --sandbox`).
5. Test one hypothesis at a time; remove temporary debug output afterwards.
6. Add a regression test via `rails-tdd`.

## Common culprits

- Pending migrations -> `bin/rails db:test:prepare`
- Silent validation failure (`save` false) -> inspect `errors`
- Strong params filtering attributes
- N+1 query patterns -> add `includes`/`preload`
- Zeitwerk constant/file mismatch -> `bin/rails zeitwerk:check`

## Rules

- No destructive DB commands unless explicitly requested.
- Prefer evidence from logs/tests over intuition.
