---
description: Propose a commit message for the current changes (does not commit)
---
Read `git status --short` and `git diff HEAD` (plus untracked files) in the current project. Then propose a commit message in Conventional Commits style:

```
<type>(<scope>): <imperative summary, ≤ 72 chars>

<why the change was needed, and what changed at a high level. Wrap at 72.>
```

If the diff mixes unrelated changes, propose how to split it into separate commits and which files go in each. **Don't run `git add` or `git commit`.** The user commits.
