---
name: branch-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
metadata:
  layer: core
  upstream: mattpocock/skills@c55ee46:skills/engineering/code-review
---

Two-axis review of the diff between the working tree and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff --merge-base <fixed-point>` (against the merge-base, including uncommitted changes). Untracked files are part of the change too: list them with `git ls-files --others --exclude-standard`. Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff or the untracked list is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`003`, `issues/003-<slug>.md`), read from `issues/` or `issues/done/`, and the tickets the change moves into `issues/done/`.
2. A path the user passed as an argument.
3. A spec file under `docs/` or `specs/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

A ticket's spec is the ticket plus, from the project's `issues/prd.md`, the stories its `stories:` lists, the `## Business Rules` its `BR-NNN` criteria carry, and the limits and edge cases `## Implementation Decisions` settles for them.

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`, the project's agent instructions, ADRs and profile, and its backend-layer skills (stack specifics).

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

The Standards axis also carries the **ADR gate**: a decision in the diff that passes all three ADR criteria and has no ADR in `adr/` (or in the `adr/` of a context `CONTEXT-MAP.md` lists) is a finding; one that fails any criterion is not. The criteria: **constrains future work**: hard to reverse (the cost of changing your mind later is meaningful), or later work must conform to it; **surprising without context**; **the result of a real trade-off**. An ADR the change adds as `accepted` whose Evidence doesn't show the user settled the decision should be `proposed`: a finding. So is any edit to an accepted ADR other than marking it superseded.

The Standards axis also carries the **reuse gate** (ADR-0009). A finding is code in the diff that re-implements what an established library already does (a stub or mock helper, an HTTP client, a parser, retry or date logic), unless an ADR, the PRD or the ticket approved hand-writing it. The fix names the library.

### 4. Spawn both sub-agents in parallel

If your harness has no sub-agents, run the two reviews yourself, one after the other: write the Standards report in full before you start the Spec review, then write the Spec report without revising the first.

**Standards sub-agent prompt** should include:

- The full diff command, commit list and untracked files.
- The list of standards-source files you found in step 3, **plus the smell baseline and the ADR gate from step 3** pasted in full (the sub-agent has no other access to them).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell you spot: name it and quote the hunk; and (c) every decision the ADR gate flags: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** should include:

- The diff command, commit list and untracked files.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial, including a PRD rule for the ticket's stories that neither the diff nor any ticket's criteria in `issues/` or `issues/done/` carries; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong; (d) each story in the ticket's `stories:` that no test in the change carries in its name, and a ticket with `stories: []` that isn't a prefactor (including development infrastructure the slices need) or wide-refactor step; (e) business rules (ADR-0010): each `BR-NNN` criterion that no test in the change names, or that the change doesn't add to `RULES.md` word for word, and any change to a `RULES.md` entry, or to a test named with a `BR-NNN`, that the ticket doesn't carry. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
