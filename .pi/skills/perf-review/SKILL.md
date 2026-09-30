---
name: perf-review
description: "Performance and concurrency review of a finished feature before its PR. Maps the feature's blast radius (entry points above the changed code, what it calls below, and the existing code that touches the same data beside it), then reviews two axes in parallel sub-agents: Performance (query counts, missing indexes, unbounded loads, cross-ticket effects) and Concurrency (races and deadlocks against the other writers). Only evidenced findings count; proportionate fixes become tickets, anything heavier waits for the user's yes. Use when every ticket of a feature is done and before the PR, or when the user asks for a performance review since X."
metadata:
  layer: core
  upstream: none
---

Review what a feature changed for slow paths and for races with the rest of the system, scoped to the feature's
**blast radius**, and turn the findings the user approves into tickets. The review itself never edits code: it
writes only the ticket files the user approves, and the fixes go through the normal ticket loop with its gates.

Stack specifics (how to count queries, read a query plan, take a lock) come from the backend skill the profile's
`## Workflow skills` names for `Performance checklist`. Read it before step 2.

## Process

### 1. Pin the fixed point

The feature's first plan commit, unless the user names another fixed point. Same capture as branch-review:

- `git diff --merge-base <fixed-point>` (merge-base against the working tree),
- untracked files: `git ls-files --others --exclude-standard`,
- the commits: `git log <fixed-point>..HEAD --oneline`.

Confirm the fixed point resolves and the change is non-empty before going further. Read the PRD and the done tickets
the commits name: their stories tell you which paths matter.

### 2. Map the blast radius

This is fact-finding, so one sub-agent may do it. Start from each changed unit (a function, a class, a table) and
walk the component hierarchy it belongs to:

- **Up**: every entry point that reaches it: routes and their handlers, background jobs, scheduled tasks, consoles or
  scripts the repo documents.
- **Down**: what it calls: models, associations, callbacks, shared modules, services, and the tables and indexes they
  read and write.
- **Sideways**: existing code outside the change that reads or writes the same tables or rows: other handlers, jobs,
  callbacks. These are the parties a race or a deadlock needs.

Write the map as short paths with `file:line`, one per line:

```
POST /orders → OrdersController#create (app/…:12) → Order.place (app/…:40) → orders, stock_items
  sideways: RestockJob#perform (app/…:8) writes stock_items
```

Code outside the map is not reviewed. A slow path elsewhere is not this feature's finding: mention it at most once,
under Watch.

### 3. Review two axes, in parallel sub-agents

If your harness has no sub-agents, run them one after the other and write the first report in full before starting
the second. Each sub-agent gets the diff command, the commit list, the map, the stories, and the checklist skill's
path.

**Performance** (within the map):

- queries per request or job, and queries repeated per row (N+1);
- a new query shape (filter, sort, join key) with no index to serve it;
- loads with no bound: every row of a table that grows;
- slow work in the request path that the user waits for;
- the same computation or query repeated inside one request;
- responses or payloads that grow with the data;
- effects that only appear across tickets: ticket 002 calls ticket 001's method inside a loop, two tickets each add a
  query to the same page.

**Concurrency** (the change against each sideways party in the map):

- check-then-act and read-modify-write on shared rows (a count, a balance, a "find or create");
- two code paths that lock the same rows or tables in different orders (deadlock);
- transactions that hold locks across slow work (a network call, a large loop);
- side effects (mail, jobs, calls to other systems) fired inside a transaction that may roll back;
- jobs that aren't safe to run twice or at the same time.

Brief for both: "Report each finding with `file:line`, its path through the map, and its evidence. Under 400 words."

### 4. Evidence or it isn't a finding

A finding needs all three:

- `file:line`;
- its path through the map (which entry point reaches it);
- evidence: a measured query count (from a test or the log), the query plan for the query, or, for a race, a concrete
  interleaving written step by step (A reads, B reads, A writes, B writes: one update lost).

A suspicion without evidence goes under **Watch**. Watch items are listed once and never become tickets.

### 5. Classify

- **Fix**: a proportionate change inside the map that adds no infrastructure and changes no behaviour the user can
  see: preloading an association, an index, a uniqueness constraint with the conflict handled, an atomic update in
  place of read-modify-write, a consistent lock order, moving a side effect to after the commit.
- **Confirm**: everything else. Caching, stored counters and other denormalisation, a new background job or queue, a
  new dependency, a schema restructuring. A new limit or pagination is a business rule, not an optimisation: it goes
  to the user as a rule, never as a Fix.

Recommend, and never build a Confirm finding without the user's yes. When unsure between the two, it's Confirm.

### 6. One round with the user

One message: the map, then numbered findings, each with its class, its evidence and a recommendation, in the
grilling format (options and a recommendation per finding). Then the Watch list. The user's answer settles every
finding; there is no second round.

### 7. Tickets

Each approved finding goes into a ticket file `issues/NNN-perf-<slug>.md`, numbered after the highest existing ticket,
in to-tickets' format:

- One ticket per root cause, so a problem that spans two tickets gets one ticket, not two.
- AFK: the user already approved the fix.
- `stories:` lists the story whose path the finding is on.
- The criteria state the fix, not the symptom.
- **Tests:** one regression test per finding: a query-count assertion, the index present in the schema, or a
  concurrency test. When the test harness can't show the race (tests inside one transaction), test the atomic
  operation or the constraint instead.
- An approved Confirm finding that sets a limit becomes a business rule in the PRD first, then a criterion.

Then run the preflight check in plan mode (`ralph/preflight --plan`, as to-tickets does) and commit the ticket files
alone with the command its NEXT line prints, with the message `Plan: performance fixes`. The ticket loop reads that
subject: after these tickets it points to the PR, not to a second review. The fixes are built by the normal ticket
loop, one commit per ticket, and the PR opens after them. With no approved finding, there is nothing to commit: the
PR is next.
