# ADR Format

ADRs live in `adr/` and use sequential numbering: `ADR-0001-slug.md`, `ADR-0002-slug.md`, etc.

Create the `adr/` directory lazily: only when the first ADR is needed.

Set `Status: accepted` only when the user explicitly settled the decision in the conversation, and say so in `Evidence`; otherwise `proposed`, for a human to accept.

## Template

```md
# ADR-NNNN: {Short title of the decision}

- Status: proposed | accepted | deprecated | superseded by ADR-NNNN
- Date: {YYYY-MM-DD}
- Evidence: {what the decision rests on: PRD section, user answer, measurement}

## Context

{1-3 sentences: what's the situation and the forces at play.}

## Decision

{What did we decide, and why.}

## Consequences

- Positive: {…}
- Negative / accepted costs: {…}

## Revisit triggers

- {The observable signal that should reopen this decision.}
```

That's it. Each section can be a single line. The value is in recording *that* a decision was made and *why*, not in filling out sections.

An accepted ADR is never edited, except to mark it `superseded by ADR-NNNN`. To change a decision, write a new ADR; superseding one is a human decision.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Considered Options**: only when the rejected alternatives are worth remembering

## Numbering

Scan `adr/` for the highest existing number and increment by one.

## When to offer an ADR

All three of these must be true:

1. **Constrains future work**: hard to reverse (the cost of changing your mind later is meaningful), or later work must conform to it
2. **Surprising without context**: a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse and nothing later must conform to it, skip it: you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

This test is what a *durable decision* means in this workflow: one that passes it and has no ADR is a review finding.

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into a relational database."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library: just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it; otherwise someone will suggest GraphQL again in six months.
