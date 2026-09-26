---
name: to-spec
description: "Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
metadata:
  layer: core
  upstream: mattpocock/skills@c55ee46:skills/engineering/to-spec
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching. If the project's own repo hasn't been created yet (greenfield), skip the exploration; the ADRs to respect are then the boilerplate's defaults (the workshop's ADRs, the boilerplate's `VARIANTS.md` and stack), which are settled inputs, not open questions. Refer to any you can't read by name, never by a guessed value.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the spec using the template below, then publish it to the project issue tracker (`issues/prd.md`).

Record each implementation decision that passes all three ADR criteria as an ADR, unless it already has one, and cite it in the decision (by number; by path when `CONTEXT-MAP.md` exists). The criteria: **constrains future work**: hard to reverse (the cost of changing your mind later is meaningful), or later work must conform to it; **surprising without context**; **the result of a real trade-off**. Write it to `adr/ADR-NNNN-<slug>.md` (a context's own `adr/` when `CONTEXT-MAP.md` lists one; next number) with `Status` (`accepted` only if the user explicitly settled the decision in this conversation, and `Evidence` says so; otherwise `proposed`), `Date` and `Evidence` lines, then Context, Decision, Consequences, Revisit triggers.

If the project's own repo hasn't been created yet (greenfield), create no files unless the user names one outside the future project directory: write the spec in the conversation or to that file; it goes to `issues/prd.md` once the repo exists. If no file is named, tell the user the spec lives only in this conversation. Mark the decisions that pass the ADR criteria `(ADR candidate)` instead of writing ADRs.

Add resolved domain terms that no `CONTEXT.md` glossary holds yet (all of them, pre-repo) to Further Notes as glossary entries (`**Term**:` a one or two sentence definition, `_Avoid_:` its synonyms).

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG list of user stories, numbered `US-1`, `US-2`, …. Each user story should be in the format of:

US-1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
US-1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions, including every rule, limit and edge case settled in the conversation
- Greenfield: the boilerplate variant, with the `VARIANTS.md` signals this spec states, the row they match, and the rejected alternatives; pre-repo, the user confirms it before the repo is created

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested, at which seams
- Prior art for the tests (i.e. similar types of tests in the codebase; pre-repo, the test framework and layers the boilerplate's defaults name)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
