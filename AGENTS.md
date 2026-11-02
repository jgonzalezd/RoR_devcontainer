# Agent guide: RubyOnRails-Interview workspace

Ruby 3.3.7 (rvm) · PostgreSQL in the devcontainer · Node 22. Each project is its **own git repo**.
The root repo only holds tooling and gitignores `project*/`.

## Workspace map

| Path | Rails | Tests | Lint |
|---|---|---|---|
| `projects_own/construction-manager` | 8.0 | Minitest | rubocop |
| `projects_own/inertia-js` | 8.0 | Minitest | rubocop |
| `projects_own/view_component` | 8.0 | Minitest | rubocop |
| `projects_own/interview_scheduler` | 7.1 | Minitest | rubocop |
| `projects_own/products`, `quick_wins`, `quick_wins_vAPI`, `secure_notes`, `template` | 7.1 | Minitest | none |
| `projects_own/url-shortener`, `url-shortener/` | plain Ruby | RSpec | none |
| `projects_open_source/*` | third-party code: read-only unless asked | | |

Do not touch these: `.DB_data/`, `.DB_backups/`, `.DB_logs/` (live Postgres data), `.devcontainer/`, `.pi/guards/`.
A project may have its own `AGENTS.md`. When it exists, it overrides this file for that project.

## Golden rules (non-negotiable)

1. **Scope.** Work only inside the project the task names. If it's ambiguous, ask which project.
2. **Never destroy work.** Don't delete, move, rename or overwrite files unless the task clearly requires it. Don't use `git reset --hard`, `git clean`, `git checkout -- .`, `git stash drop`, rebases, force pushes, `db:drop`/`db:reset`/`db:rollback`, or `rails destroy` unless the user asks.
   A safety guard asks the human before risky commands run. **If it blocks you, stop and explain. Never look for a workaround** (another command, a script, `ruby -e`, and so on).
3. **Prefer `edit` over `write`** for existing files. Make small, targeted changes.
4. **Migrations.** Never edit a migration that is committed or has already run. Write a new one. Never edit `db/schema.rb` by hand.
5. **Never run anything against production.** No `RAILS_ENV=production` or production credentials.
6. **Secrets.** Don't read or print `.env`, `config/master.key` or credentials. Use `.env.example` to learn variable names.
7. **Git.** Don't commit, amend or push. When a unit of work is done and green, propose a commit message (use `/commit-msg`) and let the user commit.
8. **Honesty.** Report test and lint results as they are. Never say "done" while tests fail. Never delete or skip a failing test to get green.

## Workflow

1. **Explore.** Use read, grep, find and ls. Read the relevant models, controllers, routes, tests and the project's `AGENTS.md`. For larger tasks, start with `/plan` (read-only mode).
2. **Plan.** Write numbered steps, the files each step touches, and the tests you'll add.
3. **TDD loop** (skill `rails-tdd`). Write a failing test, run it and watch it fail, write the minimal code, run it and watch it pass, then refactor.
4. **Verify** (`/verify`). Run the tests for the changed area, then the full suite. Run rubocop on changed files only. Review `git diff`.
5. **Hand off.** Summarise what changed, how you verified it, anything left open, and a proposed commit message.

Every prompt is automatically checkpointed (`/checkpoints`, `/restore <id>`, `/diff-checkpoint <id>`).

## Commands (run from the project directory)

```bash
bin/rails test                               # full Minitest suite
bin/rails test test/models/user_test.rb:42   # single test by line
bundle exec rspec spec/path_spec.rb:42       # RSpec projects
bin/rubocop -a <changed files>               # safe autocorrect only (never -A on the whole repo)
bin/rails db:migrate && bin/rails db:migrate:status
bin/rails db:test:prepare                    # when test DB schema is stale
bin/rails console --sandbox                  # changes roll back on exit
bin/rails routes -g <pattern>
tail -n 200 log/test.log                     # debug failing tests
```

Rails conventions: skinny controllers, strong params, and validations plus DB constraints (null, unique indexes, foreign keys). Use `includes` to avoid N+1 queries. Wrap multi-step writes in transactions. Use service objects only when a model gets too big. Follow the project's existing style over personal preference.
