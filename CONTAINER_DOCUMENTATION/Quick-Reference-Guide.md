# PostgreSQL Management - Quick Reference Guide

This guide provides quick commands for common PostgreSQL management tasks in the devcontainer.

## Quick Commands

### Status & Health

```bash
# Check PostgreSQL status
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh status

# Run comprehensive health check
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh health

# Check if PostgreSQL is accepting connections
docker exec <container-name> /usr/lib/postgresql/15/bin/pg_isready
```

### Backup Operations

```bash
# Create a backup
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create

# List all available backups
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh list

# Restore from backup (interactive)
docker exec -it <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh restore <backup-name>

# Clean up old backups
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh cleanup
```

### Maintenance

```bash
# Restart PostgreSQL
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh restart

# Create manual backup
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh backup

# List backups
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh list-backups
```

### Troubleshooting

```bash
# View PostgreSQL logs (last 50 lines)
docker exec <container-name> tail -50 /var/log/postgresql/postgresql.log

# View container startup logs
docker logs <container-name>

# Check data directory
docker exec <container-name> ls -la /var/lib/postgresql-data/

# Check backup directory
docker exec <container-name> ls -la /var/lib/postgresql-backup/
```

### Database Operations

```bash
# Connect to PostgreSQL as dbuser
docker exec -it <container-name> psql -U dbuser -d postgres

# Connect as postgres superuser
docker exec -it <container-name> sudo -u postgres psql

# List all databases
docker exec <container-name> sudo -u postgres psql -c "\l"

# Check database size
docker exec <container-name> sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('postgres'));"
```

## Common Scenarios

### Scenario: Container won't start

```bash
# 1. Check container logs
docker logs <container-name>

# 2. If data corruption is suspected, remove corrupted data
rm -rf .DB_data/*

# 3. Restart container (will reinitialize automatically)
docker restart <container-name>
```

### Scenario: PostgreSQL performance issues

```bash
# 1. Run health check
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh health

# 2. Check for long-running queries
docker exec <container-name> sudo -u postgres psql -c "SELECT pid, now() - query_start as duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC;"

# 3. Check disk usage
docker exec <container-name> df -h /var/lib/postgresql-data
```

### Scenario: Need to restore from backup

```bash
# 1. List available backups
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh list

# 2. Restore from chosen backup
docker exec -it <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh restore data_20231201_120000

# 3. Verify restoration
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh status
```

### Scenario: Before major database changes

```bash
# 1. Create a manual backup
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create

# 2. Verify backup was created
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh list

# 3. Proceed with your changes

# 4. If needed, restore from backup
docker exec -it <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh restore <backup-name>
```

## File Locations

| Path | Description |
|------|-------------|
| `.DB_data/` | PostgreSQL data directory (host) |
| `.DB_logs/` | PostgreSQL logs (host) |
| `.DB_backups/` | Backup storage (host) |
| `/var/lib/postgresql-data/` | PostgreSQL data directory (container) |
| `/var/log/postgresql/` | PostgreSQL logs (container) |
| `/var/lib/postgresql-backup/` | Backup storage (container) |

## Environment Variables

Set these when running the container:

```bash
-e POSTGRES_VERSION=15
-e DATABASE_USERNAME=dbuser
-e DATABASE_PASSWORD=password
-e DISABLED_SERVICES=mongodb
```

## Default Credentials

| Component | Username | Password |
|-----------|----------|----------|
| PostgreSQL Superuser | postgres | password |
| Application User | dbuser | password |

## Connection Strings

```
# From within container
postgresql://dbuser:password@localhost:5432/

# From host machine (if port forwarded)
postgresql://dbuser:password@localhost:5432/
```

## Health Check Indicators

| Status | Meaning | Action |
|--------|---------|--------|
| ✅ PostgreSQL is running | Normal operation | None |
| ❌ PostgreSQL is not running | Service down | Check logs, restart |
| ⚠️ High disk usage (>80%) | Low space warning | Clean up data or backups |
| ⚠️ Long-running queries | Performance issue | Investigate queries |

## Tips

1. **Always create backups before major operations**
2. **Run health checks regularly**
3. **Monitor disk usage in `.DB_data/`**
4. **Keep at least 3 recent backups**
5. **Check logs when issues occur**
6. **Use proper container shutdown (avoid force kill)**

## Emergency Procedures

### Complete Reset

```bash
# Stop container
docker stop <container-name>

# Remove all data (WARNING: Data loss!)
rm -rf .DB_data/* .DB_logs/* .DB_backups/*

# Start container (will reinitialize)
docker start <container-name>
```

### Recover from Crash

```bash
# Container automatically recovers on startup
# If needed, manually trigger recovery:
docker restart <container-name>
```

## Getting Help

1. Check container logs: `docker logs <container-name>`
2. Check PostgreSQL logs: `docker exec <container-name> tail -50 /var/log/postgresql/postgresql.log`
3. Run health check: `maintenance.sh health`
4. Consult full documentation: `PostgreSQL-Data-Corruption-Prevention.md`

---

**Last Updated**: October 17, 2025

