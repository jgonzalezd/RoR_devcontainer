---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology, writing or editing a CONTEXT.md, or recording or superseding an ADR.
metadata:
  layer: core
  upstream: mattpocock/skills@c55ee46:skills/engineering/domain-modeling
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `CONTEXT.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── RULES.md
├── adr/
│   ├── ADR-0001-event-sourced-orders.md
│   └── ADR-0002-relational-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── adr/                              ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   ├── RULES.md                  ← rules this context enforces
│   │   └── adr/                      ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── adr/
```

Create files lazily: only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Bring up the rules already in force

In an existing app, before the decisions that depend on them, find the business rules already in force in the area the session touches (ADR-0010). This is fact-finding, so it's your job, not the user's: dispatch a sub-agent. Read `RULES.md` first, then what the code enforces (validations, database constraints, permission checks, guards) and the tests assert, with file references. Put them in the round as the feature's blast radius: for each rule, does the feature keep it or change it? A rule found in the code but missing from `RULES.md` is added there as soon as the user confirms it is intended, in the format in [RULES-FORMAT.md](./RULES-FORMAT.md). A rule the user calls a bug is one the feature changes. In a new app, skip this.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up: capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

The glossary should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. Its `## Language` section is a glossary and nothing else; leave the file's other sections as they are. Business rules go in the spec's Business Rules while they are planned, and in `RULES.md` once they are enforced.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Constrains future work**: hard to reverse (the cost of changing your mind later is meaningful), or later work must conform to it
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
