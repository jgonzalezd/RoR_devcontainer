---
name: ruby-style
description: Ruby/Rails style and linting workflow with RuboCop. Use before handoff and when cleaning changed files.
metadata:
  layer: backend
  upstream: none
---

# Ruby style

## Workflow

1. Honor project style config (`.rubocop.yml`) over personal preference.
2. Lint changed files only, using safe autocorrect (`-a`).
3. Avoid repo-wide style churn unless explicitly requested.

## Commands

Prefer commands from `.pi/project-profile.md`. Typical fallback:

```bash
git diff --name-only --diff-filter=AM HEAD -- '*.rb' '*.rake' | xargs -r bin/rubocop -a
git ls-files --others --exclude-standard -- '*.rb' | xargs -r bin/rubocop -a
```

If `bin/rubocop` is unavailable, try `bundle exec rubocop`.

## Rules

- Never use unsafe autocorrect (`-A`) across the whole repo without explicit request.
- Keep unrelated style changes out of feature diffs.
