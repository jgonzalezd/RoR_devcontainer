# PostgreSQL Data Corruption Prevention & Recovery System

## Overview

This document describes the comprehensive PostgreSQL data corruption prevention and recovery system implemented in the devcontainer environment. The system provides automatic detection, prevention, and recovery from PostgreSQL data corruption issues.

## Problem Statement

PostgreSQL data corruption can occur when containers are stopped improperly or when system files become incomplete. The original issue manifested as:

```
FATAL: could not open file "global/2671": No such file or directory
```

This error indicated missing critical system catalog files, preventing PostgreSQL from starting successfully.

## Solution Architecture

The solution implements a multi-layered approach to prevent, detect, and recover from data corruption:

### 1. Automatic Data Integrity Validation

**Location**: `.devcontainer/scripts/services/init-postgresql.sh`

The `check_data_integrity()` function runs automatically on every container startup before PostgreSQL attempts to start.

**Features**:
- Validates presence of critical system catalog files:
  - `PG_VERSION` - Database version file
  - `global/pg_control` - Critical control file
  - `postgresql.conf` - Configuration file
- Checks file readability and permissions
- Returns failure status if corruption is detected

**Benefits**:
- **Proactive detection** - Identifies issues before PostgreSQL startup fails
- **Zero manual intervention** - Automatically triggers recovery
- **Comprehensive validation** - Checks multiple critical components

### 2. Automatic Recovery System

**Location**: `.devcontainer/scripts/services/init-postgresql.sh`

When corruption is detected, the system automatically:

1. **Creates a backup** of the corrupted data (for forensic analysis)
2. **Removes corrupted files** from the data directory
3. **Reinitializes the cluster** with a fresh PostgreSQL instance
4. **Restarts PostgreSQL** with the new cluster

**Code Flow**:
```bash
if ! check_data_integrity; then
    log_error "Data integrity check failed, recovering cluster..."
    create_backup  # Backup corrupted data
    sudo rm -rf "$PGDATA"/*  # Remove corruption
    initialize_cluster  # Fresh start
fi
```

### 3. Automated Backup Strategy

**Location**: `.devcontainer/scripts/services/backup-postgresql.sh`

The backup system provides:

**Automatic Backups**:
- Created after successful PostgreSQL startup
- Stored in `/var/lib/postgresql-backup/` (mounted to host `.DB_backups/`)
- Named with timestamps: `data_YYYYMMDD_HHMMSS`

**Backup Management**:
- Maintains last 7 backups (configurable via `MAX_BACKUPS`)
- Automatically cleans up older backups
- Preserves backups on host machine for persistence

**Manual Backup Operations**:
```bash
# Create a backup
backup-postgresql.sh create

# List available backups
backup-postgresql.sh list

# Restore from a specific backup
backup-postgresql.sh restore data_20231201_120000

# Clean up old backups
backup-postgresql.sh cleanup
```

### 4. Robust Error Handling & Recovery

**Retry Logic**:
- PostgreSQL startup attempts up to 3 retries with 5-second delays
- Stops partially started processes before retrying
- Provides detailed logging at each step

**Graceful Failure Handling**:
- Captures and logs all errors
- Shows last 20 lines of PostgreSQL logs on failure
- Exits cleanly with appropriate error codes

### 5. Enhanced Maintenance Tools

#### Maintenance Script

**Location**: `/usr/local/bin/devcontainer-scripts/services/maintenance.sh`

**Available Commands**:

```bash
# Check PostgreSQL status
maintenance.sh status

# Run comprehensive health check
maintenance.sh health

# Create manual backup
maintenance.sh backup

# List all backups
maintenance.sh list-backups

# Restart PostgreSQL safely
maintenance.sh restart

# Clean up old backups
maintenance.sh cleanup
```

**Health Check Features**:
- PostgreSQL running status
- Data directory integrity
- Disk usage monitoring (warns at 80%+)
- Long-running query detection (>5 minutes)
- Comprehensive system status report

#### Backup Script

**Location**: `/usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh`

**Available Commands**:

```bash
# Create a new backup
backup-postgresql.sh create

# List all available backups
backup-postgresql.sh list

# Restore from a specific backup
backup-postgresql.sh restore data_20231201_120000

# Manually cleanup old backups
backup-postgresql.sh cleanup

# Show usage information
backup-postgresql.sh help
```

## Implementation Details

### Container Configuration

**Location**: `.devcontainer/devcontainer.json`

**Key Mounts**:
```json
{
  "mounts": [
    {
      "source": "${localWorkspaceFolder}/.DB_data",
      "target": "/var/lib/postgresql-data",
      "type": "bind",
      "consistency": "delegated"
    },
    {
      "source": "${localWorkspaceFolder}/.DB_logs",
      "target": "/var/log/postgresql",
      "type": "bind",
      "consistency": "delegated"
    },
    {
      "source": "${localWorkspaceFolder}/.DB_backups",
      "target": "/var/lib/postgresql-backup",
      "type": "bind",
      "consistency": "delegated"
    }
  ],
  "shutdownAction": "stopContainer"
}
```

**Benefits**:
- Data persists across container restarts
- Logs available for debugging
- Backups stored safely on host
- Proper shutdown handling prevents corruption

### Service Initialization Flow

**Location**: `.devcontainer/scripts/start-services.sh`

**Startup Sequence**:
1. Container starts with ENTRYPOINT
2. Orchestrator script runs all service init scripts
3. Backup script runs (skips if no command provided)
4. PostgreSQL init script runs:
   - Checks for existing cluster
   - Validates data integrity
   - Starts or recovers PostgreSQL
   - Creates automatic backup
5. Container keeps running with `sleep infinity`

### PostgreSQL Initialization Script

**Location**: `.devcontainer/scripts/services/init-postgresql.sh`

**Key Functions**:

| Function | Purpose | Exit on Failure |
|----------|---------|----------------|
| `check_postgres_binaries()` | Verifies PostgreSQL installation | Yes |
| `check_data_integrity()` | Validates data directory | No (triggers recovery) |
| `create_backup()` | Backs up current data | No |
| `initialize_cluster()` | Creates fresh PostgreSQL cluster | Yes |
| `start_existing_cluster()` | Starts existing cluster | Yes |
| `start_postgres()` | Starts PostgreSQL with retries | Yes |
| `verify_connection()` | Tests PostgreSQL connectivity | Yes |

**Environment Variables**:
- `POSTGRES_VERSION` - PostgreSQL major version (default: 15)
- `DATABASE_USERNAME` - Application database user (default: dbuser)
- `DATABASE_PASSWORD` - Application user password (default: password)
- `PGDATA` - PostgreSQL data directory (default: /var/lib/postgresql-data)

## Usage Guide

### Daily Operations

**Checking System Status**:
```bash
# From within the container
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/maintenance.sh status
```

**Running Health Checks**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/maintenance.sh health
```

**Creating Manual Backups**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create
```

**Listing Available Backups**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh list
```

### Recovery Procedures

#### Automatic Recovery (Preferred)

The system handles recovery automatically when corruption is detected on startup. No manual intervention is required.

**What Happens**:
1. Container starts
2. Integrity check detects corruption
3. System creates backup of corrupted data
4. Corrupted files are removed
5. Fresh PostgreSQL cluster is initialized
6. PostgreSQL starts successfully
7. Automatic backup is created

#### Manual Recovery from Backup

If you need to restore from a specific backup:

```bash
# 1. List available backups
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh list

# 2. Restore from specific backup (interactive, requires confirmation)
docker exec -it ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh restore data_20231201_120000
```

**Note**: Restore operations:
- Stop PostgreSQL
- Backup current data before overwriting
- Replace data directory with backup
- Restart PostgreSQL
- Require user confirmation (interactive mode)

### Troubleshooting

#### PostgreSQL Won't Start

**Check logs**:
```bash
docker exec ruby-rails-dev-final tail -50 /var/log/postgresql/postgresql.log
```

**Run health check**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/maintenance.sh health
```

**Manually restart PostgreSQL**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/maintenance.sh restart
```

#### Container Exits on Startup

**Check container logs**:
```bash
docker logs ruby-rails-dev-final
```

**Common issues**:
- Permission problems with mounted directories
- PostgreSQL binaries not found
- Configuration file syntax errors

**Resolution**:
1. Remove corrupted data: `rm -rf .DB_data/*`
2. Restart container (will reinitialize)

#### Backups Not Being Created

**Check backup directory permissions**:
```bash
docker exec ruby-rails-dev-final ls -la /var/lib/postgresql-backup/
```

**Manually trigger backup**:
```bash
docker exec ruby-rails-dev-final /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create
```

**Check PostgreSQL is running**:
```bash
docker exec ruby-rails-dev-final /usr/lib/postgresql/15/bin/pg_isready
```

## Configuration Options

### Backup Retention

**Location**: `.devcontainer/scripts/services/backup-postgresql.sh`

```bash
# Change maximum number of backups to keep
MAX_BACKUPS=7  # Default: 7 days
```

### Retry Behavior

**Location**: `.devcontainer/scripts/services/init-postgresql.sh`

```bash
# PostgreSQL startup retry configuration
local max_retries=3         # Number of retry attempts
local startup_timeout=30     # Seconds to wait for startup
```

### PostgreSQL Version

**Location**: `.devcontainer/devcontainer.json`

```json
{
  "build": {
    "args": {
      "POSTGRES_VERSION": "15"  // Change to desired version
    }
  }
}
```

## Monitoring & Alerts

### Health Check Metrics

The health check monitors:

1. **PostgreSQL Status**: Running/Stopped
2. **Data Directory**: Existence and integrity
3. **Disk Usage**: Warns when >80% full
4. **Query Performance**: Detects long-running queries (>5 minutes)

### Log Locations

| Component | Location | Purpose |
|-----------|----------|---------|
| PostgreSQL | `/var/log/postgresql/postgresql.log` | Database server logs |
| Container | `docker logs <container>` | Container startup logs |
| Backup Logs | Console output | Backup operations |
| Maintenance Logs | Console output | Health checks & maintenance |

## Best Practices

### 1. Regular Backups

- Backups are created automatically on startup
- Create manual backups before major operations
- Keep backups for at least 7 days
- Store critical backups outside the container

### 2. Monitoring

- Run health checks regularly
- Monitor disk usage
- Check PostgreSQL logs for warnings
- Review backup creation logs

### 3. Container Management

- Use `stopContainer` shutdown action
- Never force-kill containers (avoid `-f` flag)
- Allow graceful shutdown time
- Restart containers properly

### 4. Data Persistence

- Never delete `.DB_data/` while container is running
- Keep `.DB_backups/` directory backed up
- Monitor `.DB_logs/` for issues
- Use proper mount configurations

## Technical Details

### File System Layout

```
.devcontainer/
├── scripts/
│   ├── start-services.sh          # Service orchestrator (ENTRYPOINT)
│   └── services/
│       ├── init-postgresql.sh     # PostgreSQL initialization & recovery
│       ├── backup-postgresql.sh   # Backup management system
│       └── maintenance.sh         # Maintenance utilities
├── devcontainer.json             # Container configuration
└── Dockerfile                     # Container image definition

Host Directories (mounted):
├── .DB_data/                      # PostgreSQL data (persistent)
├── .DB_logs/                      # PostgreSQL logs (persistent)
└── .DB_backups/                   # Backup storage (persistent)

Container Directories:
├── /var/lib/postgresql-data/      # Mounted from .DB_data/
├── /var/log/postgresql/           # Mounted from .DB_logs/
├── /var/lib/postgresql-backup/    # Mounted from .DB_backups/
└── /usr/local/bin/devcontainer-scripts/
    ├── start-services.sh
    └── services/
        ├── init-postgresql.sh
        ├── backup-postgresql.sh
        └── maintenance.sh
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `POSTGRES_VERSION` | 15 | PostgreSQL major version |
| `DATABASE_USERNAME` | dbuser | Application database user |
| `DATABASE_PASSWORD` | password | Application user password |
| `PGDATA` | /var/lib/postgresql-data | Data directory path |
| `DISABLED_SERVICES` | mongodb | Services to skip on startup |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General failure (check logs) |
| 127 | Command not found |

## Future Enhancements

Potential improvements for consideration:

1. **Monitoring Integration**
   - Prometheus metrics export
   - Alerting integration (PagerDuty, Slack)
   - Grafana dashboards

2. **Advanced Backup Features**
   - Incremental backups
   - Compression
   - Remote backup storage (S3, etc.)
   - Point-in-time recovery

3. **Performance Optimization**
   - Hot backups (without stopping PostgreSQL)
   - Parallel backup/restore
   - Optimized integrity checks

4. **Enhanced Recovery**
   - Automatic corruption repair attempts
   - Multiple recovery strategies
   - Rollback capabilities

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Dev Containers Specification](https://containers.dev/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## Support

For issues or questions:
1. Check container logs: `docker logs <container>`
2. Run health check: `maintenance.sh health`
3. Review PostgreSQL logs: `/var/log/postgresql/postgresql.log`
4. Consult this documentation

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-17 | Initial implementation with full corruption prevention system |

---

**Last Updated**: October 17, 2025
**Maintained By**: Development Team
**Status**: Production Ready ✅

