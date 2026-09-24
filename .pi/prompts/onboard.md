---
description: Learn a project and write its AGENTS.md (commands, conventions, gotchas)
argument-hint: "<project path>"
---
Onboard yourself to the project at `${1:-.}`. Only read files, except for writing `${1:-.}/AGENTS.md` at the end. If an `AGENTS.md` already exists, show what you'd change and ask before editing it.

Gather:
- Ruby and Rails versions (`.ruby-version`, `Gemfile.lock`) and key gems (auth, jobs, frontend: Hotwire, Inertia, ViewComponent, API-only)
- The test framework and helpers (fixtures or factories, system tests), and the exact commands to run one test and the whole suite
- Lint and security tools (`.rubocop.yml`, brakeman, bundler-audit)
- Database (`config/database.yml`: adapter and DB names only, never credentials) and whether `db:migrate:status` is clean
- Domain model: the main models and how they relate (`app/models`, `db/schema.rb`)
- Conventions: service objects, concerns, serializers, i18n, and naming quirks
- How to run it (`bin/dev`, `Procfile.dev`, ports)

Then write a concise `AGENTS.md` (60 lines max) with these sections: Overview, Commands, Architecture, Conventions, Gotchas. Don't copy anything from `.env` or credentials.
