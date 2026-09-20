#!/bin/bash
# common.sh — shared helpers for the devcontainer lifecycle scripts
# (postCreateCommand.sh, postStartCommand.sh, postAttachCommand.sh,
# verify-environment.sh).
#
# This file is bind-mounted (lives in the workspace) rather than COPY'd into
# the image on purpose: every caller runs from /workspace, so an edit here
# takes effect on the next hook run. A COPY'd copy would need an image
# rebuild on every edit while its callers would not.
#
# Safe to source more than once: the guard below makes a second `source`
# a no-op instead of redefining functions or re-appending DEV_TOOLS.
# Safe to source from any cwd: it resolves its own directory from
# BASH_SOURCE rather than assuming the caller's cwd is .devcontainer/.

if [ -n "${__DEVCONTAINER_COMMON_SH_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__DEVCONTAINER_COMMON_SH_LOADED=1

# Directory this file lives in, regardless of the caller's cwd or how it was
# sourced (relative path, absolute path, symlink through PATH, etc).
DEVCONTAINER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- log helpers ------------------------------------------------------------
# Thin wrappers around the ✅/❌/⚠️ convention the three hooks already used
# inconsistently (some inlined the emoji, one hand-rolled its own check).

log_ok()   { echo "✅ $*"; }
log_fail() { echo "❌ $*"; }
log_warn() { echo "⚠️  $*"; }

# ---- check_tool ---------------------------------------------------------------
# Runs a version command and prints a check mark on success or a cross mark
# on failure. Returns 0 on success, 1 on failure, and never exits the calling
# script — each caller decides what a failure means for it (verify-
# environment.sh counts it toward its FAILURES total; postCreateCommand.sh
# collects it into MISSING_TOOLS and still exits 0 regardless).
check_tool() {
  local name="$1"
  shift
  local version_output
  if version_output="$("$@" 2>/dev/null)"; then
    log_ok "$name: $version_output"
    return 0
  else
    log_fail "$name: not found"
    return 1
  fi
}

# ---- DEV_TOOLS ----------------------------------------------------------------
# Canonical tool list, one "Display Name|command --flag" entry per tool.
# This is the union of the two lists that had drifted before this file
# existed: verify-environment.sh's list omitted npm and yarn, which only
# postCreateCommand.sh checked. See the report handed back with this change
# for the drift this consolidates.
DEV_TOOLS=(
  "Ruby|ruby --version"
  "Rails|rails --version"
  "Node.js|node --version"
  "npm|npm --version"
  "yarn|yarn --version"
  "Vue CLI|vue --version"
  "Claude Code|claude --version"
  "Pi|pi --version"
)
