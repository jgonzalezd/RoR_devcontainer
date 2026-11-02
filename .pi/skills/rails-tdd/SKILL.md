---
name: rails-tdd
description: Test-driven development loop for Rails changes. Use when implementing a feature, fixing a bug, or changing behavior in a Rails project.
metadata:
  layer: backend
  upstream: none
---

# Rails TDD

Default assumption: Minitest + fixtures (ADR-0001/0002). If the project profile declares RSpec, follow it.

## 0) Detect the project test commands

- Prefer `.pi/project-profile.md` as source of truth.
- Fallback detection:
  - `test/` + `test_helper.rb` -> Minitest (`bin/rails test`)
  - `spec/` + `rails_helper.rb` -> RSpec (`bundle exec rspec`)

Read these references before larger design changes:

- `deep-modules.md`
- `interface-design.md`
- `refactoring.md`

## 1) Red

- Pick the lowest proving layer (model > request/integration > system).
- Write one failing test for one behavior.
- Include `US-*` in test names/descriptions when applicable.
- Run only that test; ensure failure is for the expected assertion reason.

## 2) Green

- Write the smallest production change to pass.
- When a Rails generator makes what you need (model, migration, controller, mailer, job), run `bin/rails generate … --skip`
  and edit its output instead of writing those files from memory. `--skip` keeps existing files, such as the test you
  just wrote, and never stops to ask.
- Re-run the single test, then the file.

## 3) Refactor

- Improve names/duplication while staying green.
- Re-run related scope, then full suite before handoff.

## Rules

- Do not delete/skip/weaken tests to get green.
- Prefer deterministic fixtures first; use factories only if project profile or existing suite requires them.
- Report command outputs honestly.
