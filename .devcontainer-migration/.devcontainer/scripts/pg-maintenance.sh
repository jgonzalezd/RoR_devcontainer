#!/bin/bash
#
# PostgreSQL status/health tool for the dev container.
#
# PostgreSQL runs in its own Compose service (`db`), not in this container,
# so this script is a network client only: it checks connectivity and runs
# read-only queries. It cannot start, stop or restart the server locally,
# because no local server exists to control.
#
# Usage:
#   ./pg-maintenance.sh [status|health|backup|list-backups|cleanup]

set -e

readonly SCRIPT_NAME=$(basename "$0")
readonly PGHOST="${POSTGRES_HOST:-db}"
readonly PGUSER="${DATABASE_USERNAME:-dbuser}"
readonly PGDATABASE="${DATABASE_USERNAME:-dbuser}"
readonly BACKUP_SCRIPT="$(dirname "$(readlink -f "$0")")/pg-backup.sh"

# psql reads these directly, so every call below authenticates without
# repeating the credentials. Without PGUSER/PGDATABASE, psql falls back to the
# OS user name (vscode) and a database of the same name, neither of which
# exists on the db service.
export PGUSER PGDATABASE
export PGPASSWORD="${DATABASE_PASSWORD:-password}"

log_info()    { echo "🔧 [Maintenance] $*"; }
log_success() { echo "✅ [Maintenance] $*"; }
log_error()   { echo "❌ [Maintenance] $*" >&2; }
log_warning() { echo "⚠️  [Maintenance] $*"; }

show_status() {
    log_info "PostgreSQL status ($PGHOST):"
    echo

    if pg_isready -h "$PGHOST" -q 2>/dev/null; then
        log_success "PostgreSQL is accepting connections"
        # Errors are NOT redirected to /dev/null here. A failed query and an
        # empty result print identically once stderr is discarded, which is how
        # this reported a healthy server with a blank version string.
        echo "📊 Server version:"
        if ! psql -h "$PGHOST" -tAc "SELECT version();"; then
            log_error "Could not read server version as $PGUSER"
        fi
        echo
        echo "📊 Database sizes:"
        if ! psql -h "$PGHOST" -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database ORDER BY pg_database_size(datname) DESC;"; then
            log_error "Could not read database sizes as $PGUSER"
        fi
    else
        log_error "PostgreSQL is not reachable at $PGHOST"
    fi
}

health_check() {
    log_info "Running PostgreSQL health check against $PGHOST..."

    if ! pg_isready -h "$PGHOST" -q 2>/dev/null; then
        log_error "PostgreSQL is not reachable at $PGHOST"
        return 1
    fi
    log_success "PostgreSQL is reachable"

    if psql -h "$PGHOST" -tAc "SELECT 1;" >/dev/null 2>&1; then
        log_success "Query check passed"
    else
        log_error "Query check failed"
        return 1
    fi

    log_success "Health check completed - all systems normal"
}

require_backup_script() {
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        log_error "Backup script not found: $BACKUP_SCRIPT"
        exit 1
    fi
}

show_usage() {
    cat << EOF
PostgreSQL Maintenance Tool

Usage: $SCRIPT_NAME <command>

Commands:
  status              Show connectivity, server version and database sizes
  health              Connection + query check, exits non-zero on failure
  backup              Create a dump (delegates to pg-backup.sh create)
  list-backups        List dumps (delegates to pg-backup.sh list)
  cleanup             Delete old dumps (delegates to pg-backup.sh cleanup)

PostgreSQL runs in its own container now. There is no local start/stop/restart
here; to restart the database service, run this from the host:
  docker compose -f .devcontainer/compose.yaml restart db

For restore, use pg-backup.sh directly:
  $BACKUP_SCRIPT restore <file>
EOF
}

main() {
    local command="$1"
    shift || true

    case "$command" in
        status)
            show_status
            ;;
        health)
            health_check
            ;;
        backup)
            require_backup_script
            "$BACKUP_SCRIPT" create
            ;;
        list-backups)
            require_backup_script
            "$BACKUP_SCRIPT" list
            ;;
        cleanup)
            require_backup_script
            "$BACKUP_SCRIPT" cleanup
            ;;
        restart|start|stop)
            log_warning "PostgreSQL is PID 1 in its own container now; this script cannot control it."
            echo "Run this from the host instead: docker compose -f .devcontainer/compose.yaml restart db"
            exit 1
            ;;
        help|--help|-h|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
