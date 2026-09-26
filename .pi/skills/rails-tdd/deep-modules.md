# Deep Modules (Rails edition)

A deep module has a small surface area and rich internal behavior.
A shallow module has a large API and little hidden complexity.

## Heuristics

Prefer changes that:

- reduce public method count
- remove optional/boolean argument branches from callers
- hide orchestration behind one clear entry point
- keep call sites boring

## Rails examples

- `Invoice.finalize!` that orchestrates line-item totals, tax, and status transitions
  internally is deeper than exposing five separate public steps.
- `User#can_schedule?(interview)` is deeper than leaking policy predicates into
  controllers/views.

## During TDD

When a test passes, ask:

- Did this add one-off logic to a controller that belongs in a deeper model/service?
- Did I expose internals just to make the test easier?
- Can I keep behavior and shrink interface?
