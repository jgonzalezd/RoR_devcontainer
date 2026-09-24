---
name: rails-debugging
description: Systematic debugging of Rails apps — failing tests, 500 errors, wrong data, slow queries. Use when something is broken or behaves unexpectedly in a Rails/Ruby project.
---

# Debugging Rails

## Loop: reproduce → isolate → hypothesise → verify → fix (with a test)
1. **Reproduce** with the smallest command: a single test (`bin/rails test file:line`), a `curl` against a running server, or `bin/rails runner`.
2. **Read the whole backtrace.** Find the first frame in `app/` or `lib/`. Frames in gems are rarely the cause.
3. **Look at the logs:** `tail -n 200 log/test.log` or `log/development.log`. They show params, the SQL that ran, and rollbacks.
4. **Inspect state safely**
   - `bin/rails console --sandbox` rolls everything back on exit.
   - `bin/rails runner 'p User.find_by(email: "x").errors.full_messages'` (read-only expressions)
   - `bin/rails routes -g users` and `bin/rails db:migrate:status`
5. **Hypothesise one cause at a time.** Add temporary `Rails.logger.debug` or `pp` lines and remove them afterwards.
6. **Fix with a regression test** that fails before the fix and passes after (see skill `rails-tdd`).

## Common culprits
- `ActiveRecord::PendingMigrationError` → `bin/rails db:test:prepare`
- Validation silently failing → `save` returned false. Check `record.errors` or use `save!` in tests.
- Strong params dropping a field → `Unpermitted parameter` in the log
- N+1 / slow pages → repeated SQL lines in the log. Use `includes`/`preload`, and add `bullet` if the project has it.
- Zeitwerk `NameError` → file path and constant name mismatch. Run `bin/rails zeitwerk:check`.
- Assets/JS not updating → `bin/dev` not running, or a stale `app/assets/builds`

## Don't
- Don't "fix" by deleting data, resetting the DB or clearing caches with destructive commands.
- Don't mutate data in console without `--sandbox` unless the user asks.
