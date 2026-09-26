# Interface Design for Testability (Rails)

Good interfaces make tests simple and resilient.

## Rules

1. Accept dependencies at boundaries.
   - Inject adapters/clients into domain objects when possible.
2. Return explicit results.
   - Prefer return values and state changes over hidden side effects.
3. Separate orchestration from computation.
   - Pure computations are easy to test quickly.
4. Expose behavior, not implementation details.
   - Test public contracts; avoid coupling tests to private helper structure.

## Rails-oriented patterns

- Controllers stay thin: parse input, call domain boundary, render result.
- Domain boundaries (models/services/policies) own branching logic.
- External APIs are wrapped behind app-level adapters for deterministic tests.

## Smells

- tests needing many stubs for internals
- tests breaking on harmless refactors
- large methods with broad parameter lists
