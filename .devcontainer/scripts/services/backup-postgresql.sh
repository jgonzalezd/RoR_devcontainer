#!/bin/bash
#
# PostgreSQL Backup Script for Dev Container
#
# This script creates backups of PostgreSQL data and manages backup retention.
#
# Usage:
#   ./backup-postgresql.sh [create|list|restore <backup_name>|cleanup]
#
# Environment Variables:
#   PGDATA                - PostgreSQL data directory (default: /var/lib/postgresql-data)
#   BACKUP_DIR           - Backup directory (default: /var/lib/postgresql-backup)
#   MAX_BACKUPS          - Maximum number of backups to keep (default: 7)
#

set -e

# =============================================================================
# Configuration
# =============================================================================

readonly PGDATA="${PGDATA:-/var/lib/postgresql-data}"
readonly BACKUP_DIR="${BACKUP_DIR:-/var/lib/postgresql-backup}"
readonly MAX_BACKUPS="${MAX_BACKUPS:-7}"
readonly SCRIPT_NAME=$(basename "$0")

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo "🔧 [Backup] $*"
}

log_success() {
    echo "✅ [Backup] $*"
}

log_error() {
    echo "❌ [Backup] $*" >&2
}

log_warning() {
    echo "⚠️  [Backup] $*"
}

# Check if PostgreSQL is running
check_postgres_running() {
    if ! /usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_isready -q 2>/dev/null; then
        log_error "PostgreSQL is not running. Please start PostgreSQL first."
        exit 1
    fi
}

# Create backup directory if it doesn't exist
ensure_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        sudo mkdir -p "$BACKUP_DIR"
        sudo chown postgres:postgres "$BACKUP_DIR"
    fi
}

# Create a new backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="data_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"

    log_info "Creating backup: $backup_name"

    # Ensure backup directory exists
    ensure_backup_dir

    # Stop PostgreSQL for consistent backup
    log_info "Stopping PostgreSQL for backup..."
    sudo -u postgres /usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl -D "$PGDATA" stop -m fast

    # Create the backup
    if sudo cp -r "$PGDATA" "$backup_path"; then
        log_success "Backup created successfully: $backup_path"

        # Start PostgreSQL again
        log_info "Starting PostgreSQL..."
        sudo -u postgres /usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl -D "$PGDATA" -l /var/log/postgresql/postgresql.log start

        # Cleanup old backups
        cleanup_old_backups

        return 0
    else
        log_error "Failed to create backup"
        # Try to restart PostgreSQL
        sudo -u postgres pg_ctl -D "$PGDATA" -l /var/log/postgresql/postgresql.log start || true
        exit 1
    fi
}

# List available backups
list_backups() {
    ensure_backup_dir

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        log_info "No backups found"
        return 0
    fi

    log_info "Available backups:"
    echo

    # List backups with details
    local count=0
    for backup in "$BACKUP_DIR"/data_*; do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            local backup_name=$(basename "$backup")
            local backup_date=$(stat -c %y "$backup" 2>/dev/null || stat -f %Sm "$backup" 2>/dev/null || echo "unknown")
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "unknown")

            printf "  %-20s %-15s %s\n" "$backup_name" "$backup_size" "$backup_date"
        fi
    done

    if [ $count -eq 0 ]; then
        log_info "No valid backups found"
    else
        echo
        log_success "Found $count backup(s)"
    fi
}

# Restore from backup
restore_backup() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        log_error "Backup name is required for restore operation"
        echo "Usage: $SCRIPT_NAME restore <backup_name>"
        exit 1
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_name"
        list_backups
        exit 1
    fi

    log_warning "This will overwrite your current PostgreSQL data!"
    read -p "Are you sure you want to restore from '$backup_name'? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    log_info "Restoring from backup: $backup_name"

    # Stop PostgreSQL
    log_info "Stopping PostgreSQL..."
    sudo -u postgres pg_ctl -D "$PGDATA" stop -m fast || true

    # Create backup of current data (if it exists)
    if [ -d "$PGDATA" ] && [ "$(ls -A $PGDATA 2>/dev/null)" ]; then
        local current_timestamp=$(date +%Y%m%d_%H%M%S)
        local current_backup="$BACKUP_DIR/data_current_$current_timestamp"
        log_info "Creating backup of current data: data_current_$current_timestamp"
        sudo cp -r "$PGDATA" "$current_backup"
    fi

    # Restore from backup
    if sudo rm -rf "$PGDATA"/* && sudo cp -r "$backup_path"/* "$PGDATA"/; then
        log_success "Restore completed successfully"

        # Start PostgreSQL
        log_info "Starting PostgreSQL..."
        sudo -u postgres pg_ctl -D "$PGDATA" -l /var/log/postgresql/postgresql.log start

        # Wait for it to be ready
        sleep 3
        if pg_isready -q; then
            log_success "PostgreSQL is ready after restore"
        else
            log_warning "PostgreSQL may need more time to start after restore"
        fi
    else
        log_error "Failed to restore from backup"
        exit 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    ensure_backup_dir

    local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "data_*" | wc -l)

    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        local to_remove=$((backup_count - MAX_BACKUPS))

        log_info "Cleaning up old backups (keeping $MAX_BACKUPS, removing $to_remove)"

        # List backups by modification time (oldest first)
        find "$BACKUP_DIR" -maxdepth 1 -type d -name "data_*" -printf '%T+ %p\n' | sort | head -n $to_remove | while read -r line; do
            local backup=$(echo "$line" | cut -d' ' -f2-)
            if [ -n "$backup" ] && [ "$backup" != "$BACKUP_DIR" ]; then
                log_info "Removing old backup: $(basename "$backup")"
                sudo rm -rf "$backup"
            fi
        done

        log_success "Cleanup completed"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
PostgreSQL Backup Manager

Usage: $SCRIPT_NAME <command> [options]

Commands:
  create              Create a new backup of current PostgreSQL data
  list               List all available backups
  restore <name>     Restore from a specific backup
  cleanup            Manually cleanup old backups

Environment Variables:
  PGDATA              PostgreSQL data directory (default: /var/lib/postgresql-data)
  BACKUP_DIR          Backup directory (default: /var/lib/postgresql-backup)
  MAX_BACKUPS         Maximum number of backups to keep (default: 7)

Examples:
  $SCRIPT_NAME create
  $SCRIPT_NAME list
  $SCRIPT_NAME restore data_20231201_120000
  $SCRIPT_NAME cleanup

EOF
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    local command="$1"
    shift || true

    # If no command provided, exit silently (for initialization)
    if [ -z "$command" ]; then
        exit 0
    fi

    case "$command" in
        create)
            check_postgres_running
            create_backup
            ;;
        list)
            list_backups
            ;;
        restore)
            restore_backup "$1"
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        help|--help|-h)
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

# Run main function with all arguments
main "$@"
