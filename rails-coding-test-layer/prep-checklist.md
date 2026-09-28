# Prep checklist

Everything here happens before the interview, so none of it runs live.

## Never practice in a real project

`to-spec` writes `issues/prd.md`, so a practice run overwrites the project's PRD. Practice only
in a disposable project: a throwaway from `rails-agent-boilerplate`, or a copy of an existing app
bootstrapped as in "If they hand you their own repo" below. (The v2 baseline ran in secure_notes
itself, which had no `ralph/`, `issues/` or profile, so nothing it planned could run.)

## Practice / interview project

- [ ] Create a fresh project from the boilerplate and run `bin/setup --skip-server`.
- [ ] Commit the baseline (ralph refuses a dirty tree).
- [ ] Run all 6 gates from `.pi/project-profile.md` `## Gates` on the empty app; all green.
      - `bin/bundler-audit` downloads its advisory database: warm it now.
      - `bin/rails test:system` needs Chrome: confirm it runs.
- [ ] Run `ralph/preflight` (add `--agent claude` if you build with Claude Code) and fix every
      BLOCKER and AFK line until it says `PREFLIGHT READY` (with no tickets yet it also warns
      "no more tasks"; that is expected). It covers what used to be separate items here:
      dirty tree, ralph files, profile `## Gates`, `/ralph/runs.jsonl` in `.gitignore`, the
      project's own `AGENTS.md` letting ralph passes commit, the agent on PATH, and the
      Claude Code Bash allowlist (it prints the exact `permissions.allow` rules to add).
- [ ] Fix its WARN lines that would fail a gate live, above all Chrome for `test:system`: this
      devcontainer has none, so the first ticket that adds a system test fails every pass.
- [ ] Confirm the pinned model answers: `pi --provider openrouter --model google/gemini-3.8-flash -p "ok"`.
- [ ] If the feature will touch an LLM: the `ruby_llm` client can be stubbed in tests, and no
      test needs a real API key.

## If they hand you their own repo

- [ ] Run `rails-agent-boilerplate/bin/onboard-project <their repo>`. It adds `ralph/`, `issues/`,
      `AGENTS.md`, `CLAUDE.md`, the skills snapshot (`.pi/skills`, linked from `.claude/skills`), a
      Claude allowlist and a `.pi/project-profile.md` written from what the repo ships. It never
      overwrites a file.
- [ ] Review the profile's Commands, Gates and Framework facts, then commit on their default branch
      (the command it prints). Never on a feature branch.
- [ ] Run `ralph/preflight` until `PREFLIGHT READY`, as above. Without their own `AGENTS.md`,
      the workspace one ("don't commit") applies and stops every pass.
- [ ] Rehearse this bootstrap at least once before the interview.
