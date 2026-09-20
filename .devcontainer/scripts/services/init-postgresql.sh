#!/bin/bash
#
# PostgreSQL Initialization Script for Dev Container
#
# This script initializes and starts a PostgreSQL instance in a dev container.
# It handles both first-time initialization and subsequent container restarts.
#
# Environment Variables:
#   POSTGRES_VERSION      - PostgreSQL major version (default: 15)
#   DATABASE_USERNAME     - Application database user (default: dbuser)
#   DATABASE_PASSWORD     - Application user password (default: password)
#   POSTGRES_PASSWORD     - PostgreSQL superuser password (default: DATABASE_PASSWORD)
#
# Exit codes:
#   0 - Success
#   1 - PostgreSQL failed to start or connect
#

set -e

# =============================================================================
# Configuration
# =============================================================================

readonly PGDATA="/var/lib/postgresql-data"
readonly PGVER="${POSTGRES_VERSION:-15}"
readonly DATABASE_USERNAME="${DATABASE_USERNAME:-dbuser}"
readonly DATABASE_PASSWORD="${DATABASE_PASSWORD:-password}"
readonly POSTGRES_PASSWORD_EFFECTIVE="${POSTGRES_PASSWORD:-${DATABASE_PASSWORD}}"
readonly PG_LOG="/var/log/postgresql/postgresql.log"
readonly STARTUP_TIMEOUT=30

# =============================================================================
# Helper Functions
# =============================================================================

run_as_postgres() {
    sudo -u postgres "$@"
}

log_info() {
    echo "🔧 [PostgreSQL] $*"
}

log_success() {
    echo "✅ [PostgreSQL] $*"
}

log_error() {
    echo "❌ [PostgreSQL] $*" >&2
}

log_waiting() {
    echo "⏳ [PostgreSQL] $*"
}

# Wait for PostgreSQL to be ready
# Returns: 0 if ready, 1 if timeout
wait_for_postgres() {
    local timeout=$1
    local attempt=0
    
    while [ $attempt -lt "$timeout" ]; do
        if run_as_postgres pg_isready -q; then
            return 0
        fi
        attempt=$((attempt + 1))
        log_waiting "Waiting for server... ($attempt/$timeout)"
        sleep 1
    done
    
    return 1
}

# Display PostgreSQL logs on error
show_postgres_logs() {
    if [ -f "$PG_LOG" ]; then
        echo "📋 Last 20 lines of PostgreSQL log:"
        tail -20 "$PG_LOG" || true
    else
        echo "📋 Log file not found: $PG_LOG"
    fi
}

# Verify PostgreSQL binaries exist
check_postgres_binaries() {
    local pg_bin="/usr/lib/postgresql/${PGVER}/bin"
    
    if [ ! -d "$pg_bin" ]; then
        log_error "PostgreSQL ${PGVER} binaries not found at: $pg_bin"
        log_error "Available versions:"
        ls -1 /usr/lib/postgresql/ 2>/dev/null || echo "  None found"
        exit 1
    fi
    
    for cmd in initdb pg_ctl psql; do
        if [ ! -x "${pg_bin}/${cmd}" ]; then
            log_error "Required binary not found or not executable: ${pg_bin}/${cmd}"
            exit 1
        fi
    done
}

# Start PostgreSQL server with retry logic
start_postgres() {
    local pg_ctl="/usr/lib/postgresql/${PGVER}/bin/pg_ctl"
    local max_retries=3
    local retry_count=0

    log_info "Starting PostgreSQL server..."

    while [ $retry_count -lt $max_retries ]; do
        if run_as_postgres "$pg_ctl" -D "$PGDATA" -l "$PG_LOG" start 2>/dev/null; then
            if wait_for_postgres "$STARTUP_TIMEOUT"; then
                log_success "PostgreSQL is ready"
                return 0
            fi
        fi

        retry_count=$((retry_count + 1))
        log_info "PostgreSQL start attempt $retry_count failed, retrying in 5 seconds..."

        # Stop any partially started process
        run_as_postgres "$pg_ctl" -D "$PGDATA" stop -m fast 2>/dev/null || true

        if [ $retry_count -lt $max_retries ]; then
            sleep 5
        fi
    done

    log_error "Failed to start PostgreSQL after $max_retries attempts"
    show_postgres_logs
    exit 1
}

# Setup directory with correct permissions
setup_directory() {
    local dir=$1
    local mode=$2
    local description=$3
    
    if [ ! -d "$dir" ]; then
        log_info "Creating ${description}..."
        sudo mkdir -p "$dir"
    fi
    
    sudo chown postgres:postgres "$dir" || true
    sudo chmod "$mode" "$dir" || true
}

# Initialize a new PostgreSQL cluster
initialize_cluster() {
    local pg_bin="/usr/lib/postgresql/${PGVER}/bin"
    
    # Clean out any default cluster remnants
    if [ -d "/var/lib/postgresql/${PGVER}/main" ]; then
        log_info "Removing default cluster at /var/lib/postgresql/${PGVER}/main"
        sudo rm -rf "/var/lib/postgresql/${PGVER}/main"
    fi
    
    log_info "Initializing new PostgreSQL cluster..."
    if ! run_as_postgres "${pg_bin}/initdb" -D "$PGDATA" --encoding=UTF8 --locale=C.UTF-8; then
        log_error "Failed to initialize PostgreSQL cluster"
        exit 1
    fi
    
    log_info "Writing PostgreSQL configuration..."
    cat <<EOF | sudo tee -a "$PGDATA/postgresql.conf" > /dev/null
# Dev container configuration
listen_addresses = 'localhost'
port = 5432
unix_socket_directories = '/var/run/postgresql'
EOF

    log_info "Writing authentication configuration..."
    sudo -u postgres tee "$PGDATA/pg_hba.conf" > /dev/null <<EOF
# PostgreSQL Client Authentication Configuration
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Allow postgres superuser via peer authentication (local socket)
local   all             postgres                                peer

# Allow application user via trust (dev environment only)
local   all             ${DATABASE_USERNAME}                    trust
host    all             ${DATABASE_USERNAME}    127.0.0.1/32    trust
host    all             ${DATABASE_USERNAME}    ::1/128         trust

# All other users require password
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

    start_postgres
    
    log_info "Creating database users..."
    
    # Set postgres superuser password
    if ! run_as_postgres psql -c "ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD_EFFECTIVE}';"; then
        log_error "Failed to set postgres user password"
        exit 1
    fi
    
    # Create application user (ignore if exists)
    if run_as_postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='${DATABASE_USERNAME}'" | grep -q 1; then
        log_info "User ${DATABASE_USERNAME} already exists, updating password..."
        run_as_postgres psql -c "ALTER USER ${DATABASE_USERNAME} PASSWORD '${DATABASE_PASSWORD}';"
    else
        log_info "Creating user ${DATABASE_USERNAME}..."
        if ! run_as_postgres createuser -s "${DATABASE_USERNAME}"; then
            log_error "Failed to create user ${DATABASE_USERNAME}"
            exit 1
        fi
        run_as_postgres psql -c "ALTER USER ${DATABASE_USERNAME} PASSWORD '${DATABASE_PASSWORD}';"
    fi
    
    log_success "Initial cluster configured"
}

# Start an existing cluster
start_existing_cluster() {
    local version
    version=$(cat "$PGDATA/PG_VERSION")
    log_success "Using existing cluster (version ${version})"
    
    # Check if PostgreSQL is already running
    if run_as_postgres pg_isready -q; then
        log_success "PostgreSQL is already running"
        return 0
    fi
    
    # Remove stale PID file if present (only when not running)
    if [ -f "$PGDATA/postmaster.pid" ]; then
        log_info "Removing stale PID file..."
        sudo rm -f "$PGDATA/postmaster.pid"
    fi
    
    start_postgres
}

# Check data directory integrity
check_data_integrity() {
    log_info "Checking data directory integrity..."

    # Check for critical system catalog files
    local critical_files=("PG_VERSION" "global/pg_control" "postgresql.conf")
    local missing_files=()

    for file in "${critical_files[@]}"; do
        if [ ! -f "$PGDATA/$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Data directory corruption detected. Missing files: ${missing_files[*]}"
        log_info "Data directory will be reinitialized..."
        return 1
    fi

    # Check if we can read the control file (basic sanity check)
    if ! run_as_postgres test -r "$PGDATA/global/pg_control"; then
        log_error "Cannot read PostgreSQL control file. Data corruption suspected."
        return 1
    fi

    log_success "Data directory integrity check passed"
    return 0
}

# Create backup of data directory before risky operations
create_backup() {
    local backup_dir="/var/lib/postgresql-backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [ -d "$PGDATA" ] && [ "$(ls -A $PGDATA 2>/dev/null)" ]; then
        log_info "Creating backup before recovery..."
        sudo mkdir -p "$backup_dir"
        sudo cp -r "$PGDATA" "$backup_dir/data_$timestamp"
        log_success "Backup created at $backup_dir/data_$timestamp"
    fi
}

# Verify PostgreSQL connection and display info
verify_connection() {
    log_info "Verifying connection..."

    if ! run_as_postgres psql -c "SELECT version();" >/dev/null 2>&1; then
        log_error "Failed to connect to PostgreSQL"
        show_postgres_logs
        exit 1
    fi

    log_success "Connection verified"

    # Create a backup after successful startup (only if this is the first time)
    if [ ! -f "/tmp/backup_created" ]; then
        log_info "Creating initial backup after successful startup..."
        if /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create >/dev/null 2>&1; then
            log_success "Initial backup created successfully"
            touch /tmp/backup_created
        else
            echo "⚠️  [PostgreSQL] Failed to create initial backup, but PostgreSQL is working"
        fi
    fi

    echo "📊 [PostgreSQL] Info:"
    echo "   - Version: $(run_as_postgres psql -t -c 'SELECT version();' | head -n1 | xargs)"
    echo "   - Data directory: $PGDATA"
    echo "   - Port: 5432"
    echo "   - User: ${DATABASE_USERNAME}"
    echo "   - Connection: postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@localhost:5432/"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "Initializing (version: ${PGVER}, data: ${PGDATA})"

    # Verify PostgreSQL installation
    check_postgres_binaries

    # Setup directories
    setup_directory "/var/log/postgresql" "755" "log directory"
    setup_directory "/var/run/postgresql" "775" "runtime socket directory"
    setup_directory "$PGDATA" "700" "data directory"

    # Check if this is a new or existing cluster
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        log_info "No existing cluster found, initializing new cluster"
        initialize_cluster
    else
        log_info "Existing cluster found, checking integrity..."

        # Check data integrity before proceeding
        if ! check_data_integrity; then
            log_error "Data integrity check failed, recovering cluster..."

            # Create backup before recovery (if data exists)
            create_backup

            # Remove corrupted data
            log_info "Removing corrupted data directory..."
            sudo rm -rf "$PGDATA"/*

            # Reinitialize cluster
            initialize_cluster
        else
            log_success "Data integrity check passed, starting existing cluster"
            start_existing_cluster
        fi
    fi

    # Verify everything works
    verify_connection
}

# Run main function
main "$@"
