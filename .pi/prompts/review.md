---
description: Review the uncommitted diff like a senior Rails reviewer
argument-hint: "[focus]"
---
Review the uncommitted changes (`git diff HEAD` plus untracked files) in the current project. Focus: ${@:-correctness, security, and maintainability}.

Don't edit files. Look for:
- **Correctness:** logic bugs, nil handling, off-by-one errors, missing `return` after `redirect_to`/`render`, transactions around multi-step writes
- **Rails pitfalls:** N+1 queries (missing `includes`), callbacks with side effects, `update_all`/`delete_all` skipping validations, missing DB constraints or indexes for validations (uniqueness)
- **Security:** strong params, mass assignment, authorization checks, SQL built from strings, `html_safe`/`raw`, open redirects, secrets in code. Run `bundle exec brakeman -q --no-pager` if brakeman is in the Gemfile.
- **Tests:** is each behaviour change covered? Are there edge cases and failure paths?
- **Migrations:** are they reversible and safe on large tables?

Output a list of findings ordered by severity (🔴 must-fix, 🟡 should-fix, 🔵 nit), each with `file:line`, the problem and a concrete fix. Say so plainly if there are no findings.
