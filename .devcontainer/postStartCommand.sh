#!/bin/bash -l
set -o pipefail

# Resolve the repo root relative to this script's own location, not to a
# hardcoded absolute path. workspaceFolder can be /workspace or
# /workspaces/<repo-name> depending on devcontainer.json; this script sits in
# .devcontainer/, so its parent directory is always the repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERIFY_SCRIPT="$REPO_ROOT/verify-environment.sh"

# PostgreSQL data is not on a bind mount in this repo; it is stored in the
# named Docker volume "postgres-data" (see .devcontainer/devcontainer.json),
# so it persists across container rebuilds independently of the repo mount.
echo "📊 Container started. PostgreSQL data persisted in the Docker named volume: postgres-data"
echo ""

# Run full environment verification
echo ""
if [ -x "$VERIFY_SCRIPT" ]; then
  "$VERIFY_SCRIPT"
elif [ -f "$VERIFY_SCRIPT" ]; then
  echo "⚠️  Found $VERIFY_SCRIPT but it is not executable. Run: chmod +x $VERIFY_SCRIPT"
  exit 1
else
  echo "⚠️  Could not find verify-environment.sh at $VERIFY_SCRIPT"
  echo "   Expected it at the repo root, one level above .devcontainer/."
  exit 1
fi
