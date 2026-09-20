#!/bin/bash
#
# PostgreSQL logical-dump manager for the dev container. PostgreSQL runs in
# its own Compose service (`db`, official postgres:15 image), not in this
# container, so this is a network client: pg_dump/pg_restore/psql over TCP.
# It never stops, starts, or touches a local data directory — none exists here.
#
# Usage: ./pg-backup.sh [create|list|restore <file>|cleanup]
# Env: POSTGRES_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, PG_DUMP_DIR, MAX_DUMPS

set -e

readonly PGHOST="${POSTGRES_HOST:-db}"
readonly PGUSER="${DATABASE_USERNAME:-dbuser}"
readonly PGPASSWORD="${DATABASE_PASSWORD:-password}"
readonly PGDATABASE="${DATABASE_USERNAME:-dbuser}"
export PGPASSWORD

# /var/lib/postgresql-dumps is a fresh path, NOT /var/lib/postgresql-backup.
# That other path is bind-mounted to .DB_backups/ in the repo, which sits on
# iCloud Drive (iCloud evicts unsynced files), and holds the two 38 MB
# physical cluster copies made before this migration — the only pre-migration
# fallback that exists. Never write to, delete from, or otherwise touch
# /var/lib/postgresql-backup or .DB_backups/ from this script.
readonly PG_DUMP_DIR="${PG_DUMP_DIR:-/var/lib/postgresql-dumps}"
readonly MAX_DUMPS="${MAX_DUMPS:-7}"
readonly SCRIPT_NAME=$(basename "$0")

log_info()    { echo "🔧 [Backup] $*"; }
log_success() { echo "✅ [Backup] $*"; }
log_error()   { echo "❌ [Backup] $*" >&2; }
log_warning() { echo "⚠️  [Backup] $*"; }

require_dump_dir() {
    if [ ! -d "$PG_DUMP_DIR" ]; then
        log_error "Dump directory does not exist: $PG_DUMP_DIR"
        exit 1
    fi
    if [ ! -w "$PG_DUMP_DIR" ]; then
        log_error "Dump directory is not writable: $PG_DUMP_DIR"
        exit 1
    fi
}

create_dump() {
    require_dump_dir
    local dump_file="$PG_DUMP_DIR/dump_$(date +%Y%m%d_%H%M%S).dump"
    log_info "Dumping $PGDATABASE from $PGHOST to $dump_file"
    if pg_dump -h "$PGHOST" -U "$PGUSER" -Fc "$PGDATABASE" > "$dump_file"; then
        log_success "Dump created: $dump_file ($(du -h "$dump_file" | cut -f1))"
    else
        log_error "pg_dump failed"
        rm -f "$dump_file"
        exit 1
    fi
}

list_dumps() {
    require_dump_dir
    if [ -z "$(ls -A "$PG_DUMP_DIR"/*.dump 2>/dev/null)" ]; then
        log_info "No dumps found in $PG_DUMP_DIR"
        return 0
    fi
    log_info "Dumps in $PG_DUMP_DIR:"
    for dump in "$PG_DUMP_DIR"/*.dump; do
        [ -f "$dump" ] || continue
        printf "  %-40s %-8s %s\n" "$(basename "$dump")" "$(du -h "$dump" | cut -f1)" "$(date -r "$dump" 2>/dev/null || stat -f %Sm "$dump")"
    done
}

restore_dump() {
    local dump_file="$1"
    if [ -z "$dump_file" ]; then
        log_error "A dump file is required"
        echo "Usage: $SCRIPT_NAME restore <file>"
        exit 1
    fi
    [ "${dump_file:0:1}" = "/" ] || dump_file="$PG_DUMP_DIR/$dump_file"
    if [ ! -f "$dump_file" ]; then
        log_error "Dump not found: $dump_file"
        exit 1
    fi

    log_warning "This will overwrite data in database '$PGDATABASE' on $PGHOST!"
    read -p "Restore from '$dump_file'? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    log_info "Restoring $dump_file into $PGDATABASE on $PGHOST"
    if pg_restore -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" --clean --if-exists "$dump_file"; then
        log_success "Restore completed"
    else
        log_error "pg_restore reported errors (some are expected for objects that don't exist yet)"
    fi
}

cleanup_dumps() {
    require_dump_dir
    local count
    count=$(find "$PG_DUMP_DIR" -maxdepth 1 -type f -name "*.dump" | wc -l | tr -d ' ')
    if [ "$count" -le "$MAX_DUMPS" ]; then
        log_info "Nothing to clean up ($count dump(s), keeping $MAX_DUMPS)"
        return 0
    fi
    local to_remove=$((count - MAX_DUMPS))
    log_info "Removing $to_remove old dump(s) from $PG_DUMP_DIR, keeping $MAX_DUMPS"
    find "$PG_DUMP_DIR" -maxdepth 1 -type f -name "*.dump" -print0 \
        | xargs -0 ls -t \
        | tail -n "$to_remove" \
        | while read -r old_dump; do
            log_info "Removing $(basename "$old_dump")"
            rm -f "$old_dump"
        done
    log_success "Cleanup completed"
}

show_usage() {
    cat << EOF
PostgreSQL Dump Manager

Usage: $SCRIPT_NAME <command> [options]

Commands:
  create           Create a logical dump (pg_dump -Fc) of $PGDATABASE
  list             List available dumps
  restore <file>   Restore a dump (destructive, asks for confirmation)
  cleanup          Delete dumps beyond MAX_DUMPS ($MAX_DUMPS), oldest first

Environment Variables:
  PG_DUMP_DIR      Dump directory (default: /var/lib/postgresql-dumps)
  MAX_DUMPS        Dumps to keep on cleanup (default: 7)
EOF
}

main() {
    local command="$1"
    shift || true

    case "$command" in
        create)  create_dump ;;
        list)    list_dumps ;;
        restore) restore_dump "$1" ;;
        cleanup) cleanup_dumps ;;
        help|--help|-h|"") show_usage ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
