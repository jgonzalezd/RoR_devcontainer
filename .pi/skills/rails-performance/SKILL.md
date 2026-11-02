---
name: rails-performance
description: "Rails and PostgreSQL checklist for performance and concurrency findings: N+1 and query counting, indexes, atomic writes, get-or-create races, lock order, side effects after commit, Solid Queue concurrency. Use with perf-review, or when a Rails change is slow or racy."
metadata:
  layer: backend
  upstream: none
---

# Rails performance and concurrency checklist

The stack half of `perf-review`: what to look for, how to measure it, and which fix is proportionate. Each item says
whether its usual fix is **Fix** (proportionate, no behaviour change) or **Confirm** (needs the user's yes).
Commands come from `.pi/project-profile.md` where listed.

## Measure first

- **Query count in a test.** Rails ≥ 7.2: `assert_queries_count(n) { get notes_path }` (or `assert_no_queries`).
  Older Rails: count with a subscriber:

  ```ruby
  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
  ```

  Seed at least two rows per association, so an N+1 shows as a count that grows.
- **N+1 in the log.** `tail -n 200 log/test.log` after one test: the same `SELECT` repeated with another id.
- **Query plan.** `bin/rails console --sandbox`, then `Note.where(user_id: 1).order(:created_at).explain`
  (Rails ≥ 7.1: `.explain(:analyze)`). A `Seq Scan` on a table that grows, for a query the feature added, is evidence.
- **Strict loading** in the regression test: `Note.strict_loading.includes(:tags)` raises on a lazy load.

## Queries (Fix)

- Loop over records that touches an association → `includes` (or `preload`/`eager_load`) at the query.
- `.count` in a loop or view on a loaded relation → `.size`; presence → `exists?`, not `.present?` on a relation.
- Only some columns needed → `pluck`/`select`; batch work over many rows → `find_each`/`in_batches`.
- Pagination or a cap on an index page is a **business rule** (Confirm, via the PRD), not a Fix.

## Indexes (Fix, through a migration)

- A new `where`, `order` or join key the feature added, and every new foreign key, gets an index
  (`rails-migrations` holds the migration rules).
- Composite index: equality columns first, then the sort or range column (`[:user_id, :created_at]`).
- Uniqueness the code relies on → unique index, not only `validates :uniqueness` (the validation races).

## Atomic writes (Fix)

- Read-modify-write (`record.count += 1; record.save`) → `Model.update_counters(id, count: 1)`,
  `increment!`/`decrement!` with `touch: false`, or `update_all("count = count + 1")`.
- Conditional state change (only if still `pending`) → `Model.where(id:, state: "pending").update_all(state: "done")`
  and check the returned row count.

## Get-or-create (Fix)

- `find_or_create_by` races: two requests both miss and both insert. Fix: a unique index plus `create_or_find_by`,
  or `rescue ActiveRecord::RecordNotUnique` and retry the find once.

## Locks and deadlocks (Fix when inside the map)

- `with_lock` / `lock!` for a read-modify-write that can't be one statement. Keep the block short: no mail, HTTP or
  job enqueue inside it.
- Two paths that lock several rows must take them in the same order: `Model.where(id: ids).order(:id).lock`.
- A long lock wait should fail fast rather than pile up: `SET LOCAL lock_timeout = '2s'` inside the transaction.
- Queue-like reads by several workers: `.lock("FOR UPDATE SKIP LOCKED")`.

## Side effects and transactions (Fix)

- `deliver_later`, `perform_later` or an HTTP call inside a transaction or `after_save` → `after_commit` (or
  `after_create_commit`), so a rollback doesn't send it.
- Rails ≥ 7.2 can defer job enqueue to after commit (`enqueue_after_transaction_commit`); check the app's setting.

## Jobs (Fix or Confirm)

- A job that must not run twice at once for the same record → Solid Queue `limits_concurrency to: 1, key: ->(r) { r }`
  (Fix when Solid Queue is already the adapter).
- A job must be safe to retry: check state before acting (`return if order.shipped?`), use the atomic updates above.
- Moving work out of the request into a new job is **Confirm**: it changes when the user sees the result.

## Always Confirm

- Counter caches (`counter_cache: true`) and any stored total: a new column, a backfill, and a value that can drift.
- Caching (`Rails.cache`, fragment or Russian-doll caching): invalidation is a behaviour.
- A new gem (Bullet, rack-mini-profiler, ...): ADR-0009, the user decides.
- Schema restructuring, denormalisation, materialized views.

## Tests for a finding

One regression test per finding, named with the story (`US-n`) it protects:

- N+1 → the query-count assertion with two or more rows per association.
- Index → assert it exists: `assert ActiveRecord::Base.connection.index_exists?(:notes, [:user_id, :created_at])`.
- Race → Minitest runs each test in a transaction, so two threads can't show it. Test the atomic operation instead:
  the unique index raises `ActiveRecord::RecordNotUnique` on a duplicate, `create_or_find_by` returns the existing
  row, the conditional `update_all` returns 0 the second time.
