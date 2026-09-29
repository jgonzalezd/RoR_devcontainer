---
name: to-tickets
description: Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker (edges as text in one file per ticket locally, or native blocking links on a real tracker).
disable-model-invocation: true
metadata:
  layer: core
  upstream: mattpocock/skills@c55ee46:skills/engineering/to-tickets
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments. With neither, read the spec at `issues/prd.md`. Take the **ticket profile** from the spec's `Ticket profile:` line in Further Notes: `fine` or `coarse` (`coarse` if there is none). If the project's own repo doesn't exist yet (greenfield), stop: tickets are written after it is created.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Under `fine`, also note the files each slice will touch and the existing test it can copy the pattern from.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first
- Under `fine`: each slice delivers at most one story, makes at most one schema change and touches about five files; split it until it does

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

List the user stories (`US-n`) each ticket delivers. Every story in the spec must be delivered by at least one ticket; only a prefactor (including development infrastructure the slices need, such as a runnable test suite) or a wide-refactor step (below) delivers none. Every `Settled`, `Confirmed` or `Changes` rule in the spec's Business Rules lands, word for word with its ID (`BR-NNN. <rule>`, without the stories and status), as an acceptance criterion of the first ticket where it can be tested; that ticket also lists a story the rule serves (ADR-0010). A `Changes` rule's ticket also updates the tests named with its ID. No ticket carries a `Keeps` rule: its tests already enforce it. Every limit and edge case in the spec's Implementation Decisions lands the same way, in its own words.

Classify each ticket **AFK** or **HITL**, with a one-line reason. **AFK**: an agent can complete it unattended within the spec's and ADRs' boundaries. **HITL**: it needs a human decision, credentials, a risky or irreversible step such as a destructive data migration or a security-sensitive change, or judgment beyond the spec, such as a rule the spec leaves open (an `Open` rule, or one it doesn't state: don't invent it). Security-sensitive means sign-in, the role and permission model, secrets, or personal data shown to a new audience, even when the spec accepted it; enforcing an existing, already-reviewed role on a new action is not.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify ticket; green is promised only there. These batches and the integrate-and-verify ticket are HITL.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work
- **Stories**: the `US-n` it delivers
- **Rules**: the `BR-NNN` it carries
- **Mode**: AFK or HITL, and why
- **Under `fine`**: the Technical decisions it carries and its test names

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct: does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?
- Open rules a ticket needs: settle them now (they go into that ticket's criteria, and it can be AFK), or leave the ticket HITL?

If the project has `ralph/preflight`, run `ralph/preflight --plan` before you present the list, and show its BLOCKER, AFK and WARN lines below it. Each one names something that will stop or slow the unattended run, and its fix; the user decides what to fix. Don't change their environment yourself.

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the configured tracker

Publish the approved tickets. Write one file per ticket under `issues/<NNN>-<slug>.md`, numbered in dependency order (blockers first), continuing after the highest number in `issues/` and `issues/done/` (from `001` if there is none). Each file's `blocked_by` lists the ids it depends on; its **Blocked by:** line repeats them with titles. Use the per-ticket file template below: one ticket per file, never a single combined file.

Derive each ticket's acceptance criteria from its stories, the Business Rules it carries (copied as above) and the spec's Implementation and Testing Decisions, including every limit and edge case they settle and the seams to test at.

Under `fine`, add two sections after the criteria (template below):

- **Technical decisions:** copy each Implementation Decision from the spec that this ticket's code depends on, with its *Implication:* line, word for word. Don't invent one. A decision the ticket needs that the spec doesn't settle is an open rule (step 3): propose it with its implication in the quiz. If the user settles it, write it here ending with `(settled in the to-tickets quiz)`; otherwise the ticket stays HITL.
- **Tests:** the test file, the existing test whose pattern to copy, and one line per test: its name carrying a `US-n` from `stories` (and the `BR-NNN` of each rule it checks) and the behaviour it checks, at the seams the spec agreed. Every criterion has at least one test. No commands and no gate list: the loop runs the project's gates.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Do NOT close or modify any parent issue.

<local-ticket-template>

---
id: "<NNN>"
title: "<Ticket title>"
mode: <AFK or HITL>
mode_reason: "<one line: why>"
blocked_by: [<"NNN" of each Blocked by ticket>]   # [] if none
stories: [<US-n it delivers>]                     # [] only for a prefactor or wide-refactor step
---

# <NNN>: <Ticket title>

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list.

**Blocked by:** the numbers/titles of the tickets that gate this one, or "None (can start immediately)".

- [ ] BR-NNN. <rule, copied word for word from the spec>
- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

**Technical decisions:** (`fine` only)

- <decision, copied from the spec>. *Implication:* <copied with it>

Files: <the files it touches>

**Tests:** (`fine` only) in `<test file>`, following `<existing test>`:

- <test name with US-n>: <behaviour it checks>

</local-ticket-template>

Under `coarse`, avoid specific file paths or code snippets: they go stale fast. Under `fine`, name the files the ticket touches and its test file (the ticket runs soon after it is written, and a low-reasoning executor needs them), but still no code snippets. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

### 6. Check the unattended run

If the project has `ralph/preflight`, run `ralph/preflight --plan` again now that the tickets exist, and show the user its output. It names the tickets the unattended run will do and where a HITL ticket will stop it. On `PREFLIGHT READY`, the next step is its NEXT line: committing only the plan files, which the user does unless they asked you to. On the default branch that command first opens `feature/<prd-slug>`, so the plan is the feature branch's first commit. If it WARNs that the branch carries commits that aren't this feature's, show it; the user decides where they go. Anything else lists what to fix first. Without `ralph/preflight`, tell the user this check was skipped.
