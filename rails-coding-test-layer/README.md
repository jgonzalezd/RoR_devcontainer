# Rails coding-test layer

A lightweight layer on top of the `rails-agent-boilerplate` workflow for a 20–30 minute live
feature-implementation exercise. It **does not modify the workflow**: same skills, same order,
same gates. It only caps how much each stage produces, measured in counts (rounds, questions,
stories, tickets, tests), never in minutes.

```
grill-with-docs → to-spec → to-tickets → commit plan (opens feature/<slug>) → ralph/loop.sh → code-review
  → perf-review → ralph/loop.sh (perf ticket) → PR
```

## Files

| File | Purpose |
|---|---|
| `fast-track-prompt.md` | The prompt to paste. Contains only the prompt text, so it copies cleanly. |
| `prep-checklist.md` | What to do before the interview so no setup happens live. |
| `scenarios.md` | Practice briefs with the trap each grill should surface. |
| `iteration-log.md` | One row per practice run; the evidence for changing the prompt. |
| `recon.sh` | `recon.sh <project>`: read-only, ~0.1 s. Stack verdict from usage (file:line evidence) + implication, auth, schema, routes, models, rules in force (`RULES.md`, next `BR` ID), controllers, test prior art, workflow files. The grill's one recon call. |
| `bin/run-metrics` | `bin/run-metrics <pi session.jsonl>`: per-turn human/model time, AFK? flags, stalls, round trips. Fills the log's timing columns. |
| `audits/` | Audit decision logs; each one names the prompt version it drives. |

## How to run it

0. **Model (pinned):** plan and build with a paid flash model, never a `:free` one (free tiers
   queue and return empty responses: the v2 baseline lost ~5 min to stalls and a model swap):
   `pi --provider openrouter --model google/gemini-3.8-flash`. For `coarse` tickets, use a
   high-reasoning model for the build instead. Record the model in the log's Notes.
1. **Session 1 (planning):** paste `fast-track-prompt.md`, then give the project and the brief.
   The prompt makes the agent read each skill itself and run `recon.sh` once. Answer the one grill
   message, then approve the tickets. The approval message shows `ralph/preflight --plan`; the
   agent commits only the plan files once it is clean.
2. **Session 2 (build):** `ralph/loop.sh` (`fine` = up to 3 passes). Every ticket gets a new agent
   process (workshop ADR-0012): after each commit, type `/exit` and the next ticket starts. Stay at
   the terminal and narrate. The loop stops at the first pass that isn't `PASS OK`; `ralph/once.sh`
   re-runs one ticket. The "Fast-track constraints" block in the PRD reaches ralph because
   `once.sh` (each pass of the loop) puts the whole PRD in its payload. Business rules (`BR-NNN`, ADR-0010) are the
   workflow's job from here: ralph registers each rule its ticket carries in `RULES.md` in the
   ticket's commit, and stops if the work would change a rule the ticket doesn't carry.
3. **Session 3 (review):** run the review command the loop prints (one review since the loop's start). Fix only hard standard violations
   and spec misses (Spec categories a and c); explain the judgement-call smells out loud.
4. **Session 4 (performance):** when the loop prints the perf-review line, paste
   `fast-track-prompt.md` in a fresh session and say "performance session", the project and the
   sha it printed. One message: the blast-radius map and at most 3 findings with evidence (`fine`).
   Answer it like the grill; Confirm findings (caches, counters, new jobs) are yours to explain out
   loud and are built only on an explicit yes. The agent commits one perf ticket
   (`Plan: performance fixes`); run it with `ralph/loop.sh`, which then says the PR is next.
5. **After a practice run:** `bin/run-metrics ~/.pi/agent/sessions/<…>/<session>.jsonl` and add a
   row to `iteration-log.md`.

## Stage caps at a glance (prompt v11)

| Stage | Cap | Your job |
|---|---|---|
| Grill | 1 message: Stack + Seam + Branch lines, Rules in force (existing app), ≤5 questions with recommendations | "ok" / "ok except Qn: …" (seam and branch y/n in the same reply; ok keeps the rules in force) |
| Spec | `fine`: 2–3 stories, ≤2 business rules per story and ≤5 in all · `coarse`: 3–6 stories, ≤8 rules; 1 seam | nothing (already decided) |
| Onboard (only if recon shows MISSING) | `bin/onboard-project`, never hand-written; 1 commit on the default branch | Check the profile, reply y |
| Tickets | `fine`: 1 AFK per story, ≤3 · `coarse`: 1 (2 with prefactor); UI criteria get a system test or a manual check | Read the stories, the Business Rules, each ticket's criteria and Tests, Decisions + preflight; y also confirms the rules marked (assumed) |
| Commit plan | 1 commit, plan files only, first commit of `feature/<slug>` | Approve it; a WARN about foreign commits on the branch is yours to settle |
| ralph | 1 pass per ticket, all the profile's gates + `ralph/asset-check` | Stay at the terminal and narrate |
| Review | Run in full, fix a and c only | Explain the rest out loud |
| Performance | 1 message: map (≤12 paths) + `fine` ≤3 Fix findings with evidence into 1 ticket (`coarse` ≤5 into ≤2); Confirm only on your yes; 1 commit `Plan: performance fixes` | "ok" / "ok except F2: B"; explain the Confirm trade-offs out loud |
| ralph (perf) | 1 pass for the perf ticket, same gates | Narrate; the pass ends with "the PR is next" |
| PR | from `feature/<slug>`: the plan + one commit per ticket, then the perf plan + its ticket commit, nothing else | Open it |

## Iterating

- Change caps in `fast-track-prompt.md` only, and bump its version line (`FAST-TRACK MODE vN`).
- Every change should point to a row in `iteration-log.md` that motivated it.
- Workflow problems (skills, ralph, gates) are not fixed here: record them with `bin/fb` in the
  practice project and feed them back to the boilerplate.
