#!/bin/bash
#
# PostgreSQL Maintenance Script for Dev Container
#
# This script provides easy access to common PostgreSQL maintenance tasks.
#
# Usage:
#   ./maintenance.sh [status|backup|restore|cleanup|health|restart]
#

set -e

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_NAME=$(basename "$0")
readonly PGDATA="${PGDATA:-/var/lib/postgresql-data}"
readonly BACKUP_SCRIPT="./scripts/services/backup-postgresql.sh"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo "🔧 [Maintenance] $*"
}

log_success() {
    echo "✅ [Maintenance] $*"
}

log_error() {
    echo "❌ [Maintenance] $*" >&2
}

log_warning() {
    echo "⚠️  [Maintenance] $*"
}

# Show PostgreSQL status
show_status() {
    log_info "PostgreSQL Status:"
    echo

    # Check if running
    if pg_isready -q 2>/dev/null; then
        log_success "PostgreSQL is running"

        # Show version and connection info
        echo "📊 Database Information:"
        psql -c "SELECT version();" 2>/dev/null | head -2
        echo
        psql -c "SELECT current_database(), current_user, inet_client_addr(), inet_client_port();" 2>/dev/null || true
        echo

        # Show database sizes
        echo "📊 Database Sizes:"
        psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database ORDER BY pg_database_size(datname) DESC;" 2>/dev/null || true
    else
        log_error "PostgreSQL is not running"
        echo
        echo "🔍 Checking logs for errors..."
        tail -20 /var/log/postgresql/postgresql.log 2>/dev/null || echo "No logs available"
    fi
}

# Create a backup
create_backup() {
    log_info "Creating PostgreSQL backup..."
    if [ -f "$BACKUP_SCRIPT" ]; then
        "$BACKUP_SCRIPT" create
    else
        log_error "Backup script not found: $BACKUP_SCRIPT"
        exit 1
    fi
}

# List available backups
list_backups() {
    log_info "Available PostgreSQL backups:"
    if [ -f "$BACKUP_SCRIPT" ]; then
        "$BACKUP_SCRIPT" list
    else
        log_error "Backup script not found: $BACKUP_SCRIPT"
        exit 1
    fi
}

# Restart PostgreSQL
restart_postgres() {
    log_warning "Restarting PostgreSQL..."

    # Stop PostgreSQL
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D "$PGDATA" stop -m fast || true
    sleep 2

    # Start PostgreSQL
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D "$PGDATA" -l /var/log/postgresql/postgresql.log start

    # Wait for it to be ready
    sleep 3
    if /usr/lib/postgresql/15/bin/pg_isready -q; then
        log_success "PostgreSQL restarted successfully"
    else
        log_error "PostgreSQL failed to restart"
        exit 1
    fi
}

# Run health check
health_check() {
    log_info "Running PostgreSQL health check..."

    local issues=0

    # Check if PostgreSQL is running
    if ! /usr/lib/postgresql/15/bin/pg_isready -q 2>/dev/null; then
        log_error "PostgreSQL is not running"
        issues=$((issues + 1))
    else
        log_success "PostgreSQL is running"
    fi

    # Check data directory integrity
    if [ -f "$PGDATA/PG_VERSION" ]; then
        log_success "Data directory exists"
    else
        log_error "Data directory is missing or corrupted"
        issues=$((issues + 1))
    fi

    # Check available disk space
    local disk_usage
    disk_usage=$(df /var/lib/postgresql-data | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 80 ]; then
        log_warning "High disk usage: ${disk_usage}%"
    else
        log_success "Disk usage: ${disk_usage}%"
    fi

    # Check for long-running queries (if running)
    if pg_isready -q 2>/dev/null; then
        local long_queries
        long_queries=$(psql -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes';" -t 2>/dev/null || echo "0")
        if [ "$long_queries" -gt 0 ]; then
            log_warning "Found $long_queries long-running queries (> 5 minutes)"
        else
            log_success "No long-running queries detected"
        fi
    fi

    if [ $issues -eq 0 ]; then
        log_success "Health check completed - all systems normal"
    else
        log_error "Health check found $issues issue(s)"
        return 1
    fi
}

# Cleanup old backups
cleanup_backups() {
    log_info "Cleaning up old PostgreSQL backups..."
    if [ -f "$BACKUP_SCRIPT" ]; then
        "$BACKUP_SCRIPT" cleanup
    else
        log_error "Backup script not found: $BACKUP_SCRIPT"
        exit 1
    fi
}

# Show usage information
show_usage() {
    cat << EOF
PostgreSQL Maintenance Script

Usage: $SCRIPT_NAME <command>

Commands:
  status              Show PostgreSQL status and information
  backup             Create a new backup of PostgreSQL data
  list-backups       List all available backups
  cleanup            Clean up old backups
  restart            Restart PostgreSQL service
  health             Run comprehensive health check

Examples:
  $SCRIPT_NAME status
  $SCRIPT_NAME backup
  $SCRIPT_NAME health
  $SCRIPT_NAME restart

For backup restore operations, use:
  $BACKUP_SCRIPT restore <backup_name>

EOF
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    local command="$1"
    shift || true

    # Check if we're in the right directory (devcontainer context)
    if [ ! -f "/workspace/.devcontainer/devcontainer.json" ]; then
        log_error "Please run this script from within the container"
        exit 1
    fi

    case "$command" in
        status)
            show_status
            ;;
        backup)
            create_backup
            ;;
        list-backups)
            list_backups
            ;;
        cleanup)
            cleanup_backups
            ;;
        restart)
            restart_postgres
            ;;
        health)
            health_check
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
