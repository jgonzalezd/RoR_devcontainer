---
description: Verify current changes — tests, rubocop on changed files, diff summary
argument-hint: "[project path]"
---
Verify the uncommitted changes in ${1:-the current project}. Don't edit any files unless a check fails **and** the fix is obvious and inside the scope of the change. If you fix something, say so.

1. `git status --short` and `git diff --stat` show what changed.
2. Run the tests closest to the changed files, then the full suite (`bin/rails test` or `bundle exec rspec`).
3. If `.rubocop.yml` exists, run rubocop on the changed and new Ruby files only (see the `ruby-style` skill).
4. If `db/migrate` changed, run `bin/rails db:migrate:status` and check that the `db/schema.rb` diff matches the migration.
5. Report the results as they are:

| Check | Result |
|---|---|
| Tests | e.g. 120 runs, 0 failures / N failures (list them) |
| Rubocop | offenses / clean / n/a |
| Migrations | ... |

Finish with **READY** or **NOT READY** and the reasons.
