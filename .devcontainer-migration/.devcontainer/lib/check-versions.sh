#!/bin/bash
# check-versions.sh — checks mise.toml's declared [tools] versions against
# the ACTUAL RUNNING Ruby and Node toolchain (the interpreters really on
# PATH), not against another config file. A config-to-config comparison
# proves the two files agree with each other; it proves nothing about what
# is actually installed. This script answers the second question.
#
# Must be run from the repo root, since mise.toml lives there and a
# per-directory .ruby-version / .node-version legitimately overrides the
# workspace default declared in mise.toml (see mise.toml's [settings]
# comment on idiomatic_version_file_enable_tools). This script therefore
# checks the WORKSPACE DEFAULT only — it is not a promise that every
# subdirectory's active version matches too.
#
# Exit 0: declared and running versions match for both tools.
# Exit 1: a mismatch, or ruby/node is missing entirely.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MISE_TOML="$REPO_ROOT/mise.toml"

# Reuse the log helpers from common.sh if present; fall back to plain
# echo so this script still runs standalone (e.g. before common.sh exists
# in an older checkout).
if [ -f "$SCRIPT_DIR/common.sh" ]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/common.sh"
else
  log_ok()   { echo "✅ $*"; }
  log_fail() { echo "❌ $*"; }
  log_warn() { echo "⚠️  $*"; }
fi

if [ ! -f "$MISE_TOML" ]; then
  log_fail "mise.toml not found at $MISE_TOML"
  exit 1
fi

# Pull the value of a key out of a given [table] in mise.toml with
# grep/sed only — no TOML parser, no gem. Assumes the simple
# `key = "value"` layout this file is written in: one table header line,
# then key = "value" lines until the next table header or EOF.
#
# $1 = table name (e.g. "tools"), $2 = key name (e.g. "ruby")
toml_table_value() {
  local table="$1" key="$2"
  awk -v table="$table" -v key="$key" '
    /^\[/ {
      in_table = ($0 == "[" table "]")
      next
    }
    in_table {
      # match: key = "value"  (allow surrounding whitespace)
      if ($0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
        line = $0
        sub("^[^=]*=[[:space:]]*", "", line)
        gsub(/^"|"$/, "", line)
        sub(/[[:space:]]*#.*$/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$MISE_TOML"
}

DECLARED_RUBY="$(toml_table_value tools ruby)"
DECLARED_NODE="$(toml_table_value tools node)"

if [ -z "$DECLARED_RUBY" ]; then
  log_fail "mise.toml: no [tools] ruby entry found"
fi
if [ -z "$DECLARED_NODE" ]; then
  log_fail "mise.toml: no [tools] node entry found"
fi

FAILURES=0

# ---- Ruby ----
if command -v ruby >/dev/null 2>&1; then
  RUNNING_RUBY="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)"
  if [ -z "$RUNNING_RUBY" ]; then
    log_fail "Ruby: installed but version could not be read"
    FAILURES=$((FAILURES + 1))
  elif [ -n "$DECLARED_RUBY" ] && [ "$RUNNING_RUBY" = "$DECLARED_RUBY" ]; then
    log_ok "Ruby: mise.toml declares $DECLARED_RUBY, running $RUNNING_RUBY (match)"
  else
    log_fail "Ruby: mise.toml declares ${DECLARED_RUBY:-<none>}, running $RUNNING_RUBY (mismatch)"
    FAILURES=$((FAILURES + 1))
  fi
else
  log_fail "Ruby: not found on PATH (mise.toml declares ${DECLARED_RUBY:-<none>})"
  FAILURES=$((FAILURES + 1))
fi

# ---- Node ----
if command -v node >/dev/null 2>&1; then
  RUNNING_NODE_RAW="$(node --version 2>/dev/null)"   # e.g. "v22.5.0"
  RUNNING_NODE="${RUNNING_NODE_RAW#v}"
  if [ -z "$RUNNING_NODE" ]; then
    log_fail "Node: installed but version could not be read"
    FAILURES=$((FAILURES + 1))
  elif [ -n "$DECLARED_NODE" ] && [ "$RUNNING_NODE" = "$DECLARED_NODE" ]; then
    log_ok "Node: mise.toml declares $DECLARED_NODE, running $RUNNING_NODE (match)"
  elif [ -n "$DECLARED_NODE" ] && [[ "$RUNNING_NODE" == "$DECLARED_NODE".* ]]; then
    # mise.toml pins a major version only (e.g. "22"); accept any matching
    # major.minor.patch as a match for that case.
    log_ok "Node: mise.toml declares $DECLARED_NODE, running $RUNNING_NODE (match on major version)"
  else
    log_fail "Node: mise.toml declares ${DECLARED_NODE:-<none>}, running $RUNNING_NODE (mismatch)"
    FAILURES=$((FAILURES + 1))
  fi
else
  log_fail "Node: not found on PATH (mise.toml declares ${DECLARED_NODE:-<none>})"
  FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -eq 0 ]; then
  log_ok "All declared versions match the running toolchain."
  exit 0
else
  log_fail "$FAILURES tool(s) mismatched or missing. See above."
  exit 1
fi
