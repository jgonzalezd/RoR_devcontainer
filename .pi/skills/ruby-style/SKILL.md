---
name: ruby-style
description: Ruby/Rails code style and linting with RuboCop, scoped to changed files. Use when cleaning up code, before handing off a change, or when the user asks about lint/style.
---

# Ruby style

1. Look for `.rubocop.yml` (often `rubocop-rails-omakase` on Rails 8). The project config wins over personal taste.
2. Lint **only files you changed**:
   ```bash
   git diff --name-only --diff-filter=AM HEAD -- '*.rb' '*.rake' | xargs -r bin/rubocop -a
   git ls-files --others --exclude-standard -- '*.rb' | xargs -r bin/rubocop -a
   ```
   Use `-a` (safe autocorrect). Never run `-A` or lint the whole repo unless asked, because it creates noisy diffs.
3. If there's no `bin/rubocop`, try `bundle exec rubocop`. If the project doesn't use rubocop, match the surrounding style and don't add rubocop.
4. Style fixes to code you didn't touch go in a **separate** change. Don't mix them into feature diffs.

Idioms: guard clauses over nested `if`, `presence`, `find_by` over `where.first`, `exists?` over `present?` on relations, `pluck` for column lists, `each` over `for`, keyword args for 3+ params, and no `rescue Exception`.
