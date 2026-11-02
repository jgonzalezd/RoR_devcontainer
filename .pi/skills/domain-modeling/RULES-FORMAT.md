# RULES.md Format

`RULES.md` is the register of the business rules the product enforces today (ADR-0010). It sits beside `CONTEXT.md`; with a `CONTEXT-MAP.md`, each context has its own. Create it lazily, when the first rule is registered.

## Structure

```md
# Rules

What the product enforces today. A rule changes only through a ticket that carries it.

## Booking

- **BR-001.** A Booking needs at least one free seat.
- **BR-002.** A Member holds at most two Bookings per day.

## Membership

- **BR-014.** A Member under 16 needs a guardian's consent. _Observed in:_ `app/models/member.rb`
```

## Rules

- **One rule per entry, in glossary words.** The text is word for word the `BR-NNN` line from the spec, without its stories and status.
- **IDs are unique across the repo and never reused.** A new rule takes the next number after the highest in `RULES.md` and the current spec.
- **Group entries under the glossary term they concern.** Add a heading when none fits.
- **Who writes it.**
  - The ticket that carries a rule adds its entry, or replaces the text for a `Changes` rule, in the same commit as the code and tests that enforce it.
  - During a grill, a rule found in the code goes in once the user confirms it is intended. It is marked `_Observed in:_ <file>` until a ticket names a test after it.
- **No planned rules.** A rule that isn't enforced yet belongs in the spec, not here.
