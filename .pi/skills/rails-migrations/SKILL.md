---
name: rails-migrations
description: Safe ActiveRecord migrations on PostgreSQL. Use when adding/changing tables, columns, indexes, constraints, or backfills, including the persistence of a new model or association.
metadata:
  layer: backend
  upstream: none
---

# Rails migrations

## Safety rules

1. Never edit committed/applied migrations; always create a new migration.
2. Never hand-edit `db/schema.rb` or `db/structure.sql`.
3. Prefer reversible operations; use `up/down` only when necessary.

## Design rules

- Enforce each invariant the database can express twice: a DB constraint (`null: false`, unique index, foreign key, check or exclusion constraint) so no code path can bypass it, plus the matching model validation for a readable error. A validation alone (e.g. `uniqueness`) is not enough. Ship the validation no later than its constraint; when the constraint waits for a backfill, the validation goes first.
- Declare foreign keys explicitly (`references ... foreign_key: true`); never rely on the association alone.
- For a new table, name the queries it must serve and index their filter/join/sort columns in the same migration.
- For large tables: concurrent indexes + `disable_ddl_transaction!`
- For risky backfills (large or slow tables): schema change (e.g. nullable add) -> backfill -> constraint (e.g. NOT NULL), as separate migrations.
- Avoid one-step destructive renames/removals while app code still reads old fields.

## Verification

- the project profile's migrations command
- inspect schema diff for intended changes only
- run relevant tests (and full suite before handoff)

## Forbidden without explicit user approval

`db:drop`, `db:reset`, `db:schema:load`, `db:migrate:reset`, bulk destructive SQL.
