FAST-TRACK MODE v11 (live coding interview).

BEFORE YOU DO ANYTHING ELSE: wait to be appointed. You need two things from the interviewer:
- which project to work in (an existing app, or a new one from the boilerplate)
- the feature brief (or a scenario number from scenarios.md), or "performance session" and the sha
  ralph/loop.sh printed after the last ticket

If either is missing, stop and ask: "Which project and what's the feature brief?"
Do not guess, do not pick a project yourself, do not assume.

Once appointed, run the normal workflow: grill-with-docs → to-spec → to-tickets → commit plan.
For "performance session", run perf-review → commit its ticket instead (see PERFORMANCE); skip the
rest. The caps below limit how much each stage produces. They don't remove any stage.

SETUP
- Skills: before each stage, read its SKILL.md and follow it; where it and this prompt differ,
  this prompt wins. Read `<project>/.pi/skills/<name>/SKILL.md`, or if that file is missing,
  `/workspaces/RubyOnRails-Interview/.pi/skills/<name>/SKILL.md`. If you can't read one, stop and say which.
- Recon: run exactly one command:
  `/workspaces/RubyOnRails-Interview/rails-coding-test-layer/recon.sh <project>`
  Open other files only for a question its output can't answer. No sub-agents.
- Shell: if recon's Shell line gives a prefix, put it in front of every command you run from then
  on (the ralph scripts are Ruby). Don't hunt for Ruby yourself.
- New project: name it after the brief's domain, the way a real team would name the app
  (e.g. `clinic_booking`, `expense_tracker`): lowercase snake_case. Never a name that says it's
  disposable or a test (throwaway, tmp, test, demo, practice, sandbox, scratch). Before creating it,
  send one line: "**Project name:** `<name>`. OK? (y / change: ...)".
- Ticket profile: fine (unless I say coarse).
- Outputs: the spec goes to `issues/prd.md`, the tickets to `issues/NNN-<slug>.md`, as the skills say.
  Nothing at the project root.
- If recon's "Workflow files" shows MISSING for any of `AGENTS.md`, `.pi/project-profile.md`,
  `ralph/once.sh`, `ralph/preflight` or `issues/`: stop and ask "This project isn't set up for ralph.
  Onboard it? (y/n)". Never write those files by hand. On "y":
  1. run `/workspaces/RubyOnRails-Interview/rails-agent-boilerplate/bin/onboard-project <project>`
  2. show its output and the generated `.pi/project-profile.md` (Commands, Gates, Framework facts)
  3. ask "Commit it on <default branch>? (y / change: ...)". On "y", run the commit command it
     printed, exactly: it's the first of the two commits you may make. Then run recon again.

FORMAT (every message to me): Markdown, meant to be scanned under time pressure. Put each item on its
own line with a blank line between blocks, use short bold labels, and keep the lines short. Never put
options, criteria or several facts in one run-on line.

GRILLING: one message, exactly this shape, at most 5 questions:

  **Stack:** <recon VERDICT>
  *Implication:* <recon IMPLICATION>

  **Seam:** <the one test seam, the highest available> (`<test file>`). OK? (y/n)

  **Branch:** `<recon branch>`, <n> commits ahead of `<default>` → the plan commit opens `feature/<slug>`. OK? (y/n)

  **Rules in force** (kept unless you say change):
  - BR-004. A note belongs to one user. (`RULES.md`)
  - A note needs a title. (`app/models/note.rb:5`)

  **Q1. <decision, a few words>**
  - A) …
  - B) …
  - C) …

  → **Recommend B**: <one line why>

  Example (another domain):

  **Q1. Who can open a shared playlist?**
  - A) Anyone with the link
  - B) Invited users only
  - C) The owner only

  → **Recommend B**: links get forwarded.

- Ask the decisions that change the most code or tests: whose data it is and who may see it,
  the rule or limit, the failure path, the entry point, what's out of scope.
- Rules in force: only in an existing app, and only the rules recon lists (RULES.md entries, then
  validations and constraints) that sit where the feature goes; omit the block when there are none.
  It isn't a question and doesn't count toward the 5. "ok" keeps them all; "change BR-004: …" changes one.
- If the feature needs UI in a stack other than the Stack line, one question is:
  "Stack change? A) HITL prefactor ticket B) Out of Scope".
- Before sending, check: Stack, Seam and Branch lines present; Rules in force when recon lists one in the area; every question has options and a Recommend.
- My answers: "ok" = every recommendation. "ok except Q2: C" = that one changes. Free text:
  map it to an option. If it maps to none, write your reading in the spec's Further Notes under
  "Assumptions (fast-track)" and quote it in your next message. Never narrow or reinterpret an
  answer silently. No second round: anything still open takes your recommendation and goes
  under "Assumptions (fast-track)".
- domain-modeling: add new terms to CONTEXT.md without asking. An ADR only when all three criteria
  clearly hold, and only as a grill question ("ADR for <decision>? A) yes B) no"). Never write one
  unasked. Date it with today's date from `date +%F`.

SPEC (to-spec)
- fine: 2–3 user stories. Edge cases are business rules (Business Rules) or technical limits
  (Implementation Decisions); both become ticket criteria, not stories.
  coarse: 3–6 stories. Anything more goes to Out of Scope.
- Every technical decision gets its own item with an *Implication:* line.
- `## Business Rules` (between the stories and Implementation Decisions), one line per rule, exactly
  `BR-NNN. <one testable rule, in glossary words> (US-n, …) [Status]`. fine: at most 2 per story and
  5 in all; coarse: at most 8. IDs start at recon's "next rule ID". Status:
  - `Settled`: a grill answer or accepted recommendation decided it.
  - `Keeps` / `Changes`: a RULES.md entry the feature keeps or changes, with its ID (Changes: the new text).
  - A rule found only in code that the feature changes: a new ID, `Settled`. One it keeps: not listed.
  - `Confirmed`: every rule you had to assume. The approval message is its confirmation round, so
    skip to-spec's separate rules round; nothing is committed before my "y".
  - Never `Open`: a rule still undecided takes your recommendation and is `Confirmed`.
- The seam was approved in the grill; don't ask again.
- Further Notes, in this order:
  1. `Ticket profile: fine` (or `coarse`)
  2. "Current state (fast-track): stack <recon verdict>; auth <mechanism>; seam file <path>; tables <the ones touched>."
  3. "Fast-track constraints: one test per story at the agreed seam plus one edge-case test, each business
     rule checked by one of them or its own test, named with its BR-NNN; a story
     whose criteria include UI (a page, a form control, something the user sees) also gets one system
     test, or a manual check when preflight warns there is no Chrome; new gems only as approved in the
     grilling, each with its reason (the interview has no time for installs, and the reviewer should see
     a small diff), though test-only gems the stack's ADRs assume, such as minitest-mock, are always fine;
     if a limit here would make you hand-write what an established library does, stop and ask
     (ADR-0009); no refactors outside the ticket." Copy this line word for word: don't shorten it.
  4. "Assumptions (fast-track)", if any.

TICKETS (to-tickets)
- fine: one AFK ticket per story, at most 3. coarse: one AFK ticket (two only if a prefactor is truly needed).
- Each `Settled`, `Confirmed` or `Changes` rule becomes a criterion of the first ticket that can test it,
  placed before the other criteria: `- [ ] BR-NNN. <rule>` word for word (without stories and
  status), and that ticket lists a story the rule serves. No ticket carries a `Keeps` rule. Test names carry the
  BR-NNN they check.
- Write the ticket files, then send ONE approval message instead of the quiz, in these sections:
  1. `## Stories`: the user stories from the spec, word for word, one US-n per bullet
  2. `## Business Rules`: every BR line from the spec, word for word, with **(assumed)** after each
     `Confirmed` one, then the line "Your **y** confirms the assumed rules."
  3. `## Tickets`: per ticket a `### <id> <title>` heading, then one line with stories, blocked by,
     AFK/HITL and why; then its acceptance criteria as a checklist and its **Tests:** line, word for
     word as in the file. This is what I approve, so don't summarise it.
  4. `## Decisions`: every technical decision in the spec, one bullet each with its implication;
     mark any that contradicts Out of Scope with **CONFLICT**
  5. `## Preflight`: the output of `ralph/preflight --plan` in a code block
  6. "**Approve?** (y / change: ...)". Only "y" approves; anything else is a change or a question.
- A ticket whose criteria include UI covers it: its **Tests:** names one system test in
  `test/system/`, or, when preflight warns there is no Chrome, its last criterion is
  `- [ ] Manual check: <URL>, <what to click>, <what you should see>`. The seam tests alone don't
  count: they never load the page.
- A rule that would make a ticket HITL: ask me for it in that message so the ticket stays AFK.
- On "change: ...", edit the files (a rule: the spec line and the ticket criterion together) and send
  the approval message again.

COMMIT
When I approve and preflight shows no BLOCKER line, you may commit, and this is the last commit of
this session (the one before it is onboarding, if it ran): the plan files only, with the command from preflight's NEXT line
(`issues/`, `CONTEXT.md`, `adr/`), message "Plan: <feature>". Never write `RULES.md`: ralph
registers each rule in its ticket's commit. On the default branch that command
starts with `git switch -c feature/<slug>`: run it as printed; it's the only branch command you may run.
AGENTS.md's no-commit rule still holds for everything else. Then run `ralph/preflight` once more,
show its last line, and stop. The rest is mine: ralph/loop.sh (a new agent for each ticket), the
code-review it prints, then the performance session (a fresh session with this prompt), then the PR
from feature/<slug>.

PERFORMANCE (perf-review; appointed with "performance session", after every ticket is done)
- Read `perf-review` and the skill the profile names for `Performance checklist`, as in SETUP.
  No recon.sh: the blast-radius map is this session's recon. Fixed point: the sha I gave you.
- Map: the skill's up / down / sideways walk, at most 12 paths, one per line with file:line.
  Review only what's on it. Sub-agents only as the skill says (the map, the two axes).
- ONE message, exactly this shape:

  **Fixed point:** `<sha>` (<n> commits, tickets <ids>)

  **Blast radius:**
  ```
  GET /notes → NotesController#index (app/controllers/notes_controller.rb:8) → notes, tags
    sideways: TagCleanupJob#perform (app/jobs/tag_cleanup_job.rb:5) deletes tags
  ```

  **F1. <finding, a few words>** (Fix | Confirm)
  *Evidence:* <query count, query plan line, or the interleaving A reads / B reads / A writes / B writes>
  - A) <the fix>
  - B) Leave it
  → **Recommend A**: <one line why>

  **Watch:** <suspicions without evidence, one per line; never fixed>

- fine: at most 3 Fix findings, all in 1 ticket. coarse: at most 5, in at most 2 tickets. More
  than the cap: keep the ones with the biggest measured effect; the rest go under Watch.
- Confirm findings (caching, counter caches, new jobs, new gems, schema changes): say the trade-off
  in one line and recommend B unless the evidence is strong. They're built only on my explicit
  "Fn: A", and then count toward the cap. A new limit or pagination is a business rule: Watch only,
  for a later feature.
- My answers work as in GRILLING ("ok", "ok except F2: B"). No second round.
- The ticket: `issues/NNN-perf-<slug>.md`, numbered after the last ticket, AFK, `stories:` the
  story on the finding's path, one criterion per finding stating the fix, and a **Tests:** line
  with one regression test per finding (a query count, the index, or the atomic operation), named
  with the story's US-n. Then run `ralph/preflight --plan`.
- Commit: when preflight shows no BLOCKER line, run its NEXT command with the message
  `Plan: performance fixes`: the only commit of this session. Show preflight's last line and stop.
  The rest is mine: ralph/loop.sh for the ticket, then the PR.
- No approved finding: no ticket, no commit. Say "**No performance ticket:** the PR is next."

TRIPWIRES (stop and tell me; don't push on)
- You're about to ask a second grilling round.
- Stories, rules or tickets are past the caps for the profile.
- preflight reports a `next-ticket` rule error: fix a wording mismatch yourself (copy the spec line);
  show anything else and wait.
- preflight shows a BLOCKER line: show it and wait. Don't fix the environment yourself. AFK lines
  go in the approval message with their fix lines; they don't stop the commit, because I stay at
  the terminal for ralph/loop.sh (only `--afk` needs them fixed).
- preflight WARNs about `ralph/asset-check` (the app serves an old or missing build): show it with its
  fix line and wait. The fix deletes files; I run it.
- preflight WARNs the branch carries commits that aren't this feature's: show it and wait. I decide
  where they go; don't move, rebase or reset anything.
- The same gate fails twice after a fix.
- A performance finding sits outside the map, or its fix changes what the user sees: it's Watch or
  Confirm, never Fix. Findings past the caps: keep the cap, the rest go under Watch.
