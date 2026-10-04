# Prep checklist

Everything here happens before the interview, so none of it runs live.

## Never practice in a real project

`to-spec` writes `issues/prd.md`, so a practice run overwrites the project's PRD. Practice only
in a disposable project: a fresh one from `rails-agent-boilerplate`, or a copy of an existing app
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
- [ ] Fix its WARN lines that would fail a gate live, above all Chrome for `test:system`.
      - Chromium and chromedriver come from the devcontainer image (xtradeb PPA: arm64 has no
        Google Chrome). Check with `chromium --version && chromedriver --version`, same major.
      - Per project, `test/application_system_test_case.rb` uses `using: :headless_chrome` with
        `--no-sandbox`, `--disable-dev-shm-usage` and `options.binary = "/usr/bin/chromium"`
        (see secure_notes). `onboard-project` notes a headed `:chrome` driver.
      - A legacy app with the `webdrivers` gem downloads an x86 chromedriver: drop the gem
        (selenium-webdriver ≥ 4.11 finds the driver on PATH).
      - An empty `test/system/` passes with 0 runs: add one smoke test that loads a page.
- [ ] Confirm the project's ralph checks business rules (ADR-0010): `grep -q "Business Rules"
      ralph/next-ticket`. `bin/new-project` copies the boilerplate's `main`, so a project made before
      that work reached `main` plans BR rules that nothing checks and ralph doesn't register.
- [ ] Confirm the project has the performance session (ADR-0011): `grep -q perf-review ralph/once.sh ralph/next-steps`
      and `ls .pi/skills/perf-review .pi/skills/rails-performance`. Without them the last pass never
      prints the perf-review line and the session has no skill to read.
- [ ] Confirm the project has the ralph loop (ADR-0012): `test -x ralph/loop.sh && test -x ralph/next-steps`.
      Without them, `rails-agent-boilerplate/bin/onboard-project .` adds them, but it keeps an older
      `ralph/once.sh`, which has no `--afk`: copy that one from the boilerplate by hand.
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
