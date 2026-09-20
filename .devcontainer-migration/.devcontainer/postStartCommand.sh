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
  VERIFY_STATUS=$?
elif [ -f "$VERIFY_SCRIPT" ]; then
  echo "⚠️  Found $VERIFY_SCRIPT but it is not executable. Run: chmod +x $VERIFY_SCRIPT"
  exit 1
else
  echo "⚠️  Could not find verify-environment.sh at $VERIFY_SCRIPT"
  echo "   Expected it at the repo root, one level above .devcontainer/."
  exit 1
fi

# INIT_FAILURES_FILE is the frozen contract with the container's startup
# orchestrator (a separate agent owns writing it): absent or empty means
# every service started; a non-empty file holds one line naming each
# service that failed. This script only reads it.
INIT_FAILURES_FILE="/run/devcontainer/init-failures"
INIT_FAILED=0
if [ -s "$INIT_FAILURES_FILE" ]; then
  INIT_FAILED=1
  echo ""
  echo "❌❌❌ Container startup reported failed services: ❌❌❌"
  cat "$INIT_FAILURES_FILE"
  echo "❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌"
fi

if [ "$VERIFY_STATUS" -ne 0 ] || [ "$INIT_FAILED" -ne 0 ]; then
  echo ""
  echo "❌ postStartCommand failed: verify-environment.sh exit=$VERIFY_STATUS, init-failures=$INIT_FAILED"
  exit 1
fi
