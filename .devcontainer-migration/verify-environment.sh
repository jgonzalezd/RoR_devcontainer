#!/bin/bash
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.devcontainer/lib/common.sh
source "$SCRIPT_DIR/.devcontainer/lib/common.sh"

# Off by default: a script named "verify" must not create a database as a
# side effect. Pass --create-missing-db to opt into the old behaviour.
CREATE_MISSING_DB=0
for arg in "$@"; do
  case "$arg" in
    --create-missing-db)
      CREATE_MISSING_DB=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--create-missing-db]" >&2
      exit 2
      ;;
  esac
done

# Incremented by every check that fails outright (❌). Warnings (⚠️) about
# conditions that can be transient — e.g. Postgres still starting up — do not
# count; only checks with no legitimate "still settling" explanation do.
FAILURES=0

echo "🔍 Verifying Rails + Vue.js Development Environment"
echo "================================================="

echo ""
for entry in "${DEV_TOOLS[@]}"; do
  name="${entry%%|*}"
  cmd="${entry#*|}"
  if ! check_tool "$name" $cmd; then
    FAILURES=$((FAILURES + 1))
  fi
done

echo ""
echo "🗃️  PostgreSQL Configuration:"
echo "   Version: $POSTGRES_VERSION_INFO"
# Postgres now runs in its own Compose service ("db"), not in this
# container, so `pgrep -x postgres` can never see it — that process lives on
# the other side of the network. `pg_isready` is a network client and works
# across containers, so it replaces the pgrep-based process check.
if pg_isready -h "${POSTGRES_HOST:-db}" -p 5432 >/dev/null 2>&1; then
    echo "   Status: ✅ Running"
    echo "   Port 5432: ✅ Accepting connections"
else
    echo "   Status: ❌ Not running"
    echo "   Run: docker compose -f .devcontainer/compose.yaml up -d db"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "🔗 PostgreSQL Connection Test:"
DB_USER="${DATABASE_USERNAME:-dbuser}"
if pg_isready -h "${POSTGRES_HOST:-db}" -p 5432 >/dev/null 2>&1; then
    echo "✅ PostgreSQL: Ready for connections"

    # Authentication probe: pg_isready only proves the server is accepting
    # TCP connections, not that this user/password combination can log in.
    if PGPASSWORD="${DATABASE_PASSWORD:-password}" psql -h "${POSTGRES_HOST:-db}" -U "$DB_USER" -c '\q' >/dev/null 2>&1; then
        echo "   Authentication: ✅ $DB_USER can log in"
    else
        echo "   Authentication: ❌ $DB_USER login failed"
        FAILURES=$((FAILURES + 1))
    fi
    echo "   User: $DB_USER"

    # Check if user database exists. Creating it is gated behind
    # --create-missing-db (default off) — see the flag parsing above and the
    # report handed back with this change for why a "verify" script should
    # not have this side effect on by default.
    if PGPASSWORD="${DATABASE_PASSWORD:-password}" psql -h "${POSTGRES_HOST:-db}" -U "$DB_USER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_USER"; then
        echo "   Database: $DB_USER (available)"
    elif [ "$CREATE_MISSING_DB" -eq 1 ]; then
        echo "   Database: $DB_USER does not exist — creating it now..."
        if PGPASSWORD="${DATABASE_PASSWORD:-password}" createdb -h "${POSTGRES_HOST:-db}" -U "$DB_USER" "$DB_USER" 2>/dev/null; then
            echo "   Database: $DB_USER (created)"
        else
            echo "   Database: $DB_USER (may need manual creation)"
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo "   Database: $DB_USER does not exist (re-run with --create-missing-db to create it)"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "⚠️  PostgreSQL: Not ready yet (db container may still be starting)"
    echo "   PostgreSQL starts automatically with the db service"
fi

echo ""
echo "🌐 Available Ports:"
echo "   - Rails API: http://localhost:3001"
echo "   - Vue.js App: http://localhost:3000 or 8080"
echo "   - Vite Dev: http://localhost:5173"
echo "   - PostgreSQL: localhost:5432"

echo ""
echo "🗃️  Database Connection String:"
echo "   postgresql://$DB_USER:${DATABASE_PASSWORD:-password}@localhost:5432/$DB_USER"

echo ""
echo "🛠️  Development Setup:"
echo "   - PostgreSQL Version: Parameterized (current: v$POSTGRES_VERSION)"
echo "   - Auth Method: Trust (passwordless for development)"
echo "   - Database User: $DB_USER (superuser)"
echo "   - Default Database: $DB_USER"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "✅ Environment verification complete!"
else
  echo "❌ Environment verification found $FAILURES failure(s)."
fi

[ "$FAILURES" -eq 0 ] || exit 1
