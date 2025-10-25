# Container Documentation

This directory contains comprehensive documentation for the Ruby on Rails development container with PostgreSQL data corruption prevention and recovery system.

## Documentation Files

### 📘 [PostgreSQL Data Corruption Prevention](./PostgreSQL-Data-Corruption-Prevention.md)

**Complete technical documentation** covering:
- Problem statement and solution architecture
- Automatic data integrity validation
- Recovery procedures
- Backup strategy
- Maintenance tools
- Configuration options
- Troubleshooting guide
- Best practices

**When to read**: For understanding the complete system architecture and implementation details.

### 🚀 [Quick Reference Guide](./Quick-Reference-Guide.md)

**Fast command reference** including:
- Common commands for status, health checks, and backups
- Troubleshooting commands
- Quick scenario guides
- File locations
- Connection strings
- Emergency procedures

**When to read**: For day-to-day operations and quick command lookups.

## Quick Start

### Check System Health

```bash
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh health
```

### Create a Backup

```bash
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create
```

### View Status

```bash
docker exec <container-name> /usr/local/bin/devcontainer-scripts/services/maintenance.sh status
```

## System Features

### ✅ Automatic Protection

- **Data integrity validation** on every startup
- **Automatic corruption detection** before PostgreSQL starts
- **Self-healing recovery** when corruption is found
- **Automated backups** after successful startup

### 🛠️ Management Tools

- **Health monitoring** with comprehensive checks
- **Backup management** with retention policies
- **Easy restoration** from any backup point
- **Maintenance utilities** for common operations

### 📊 Monitoring

- PostgreSQL status and connection health
- Data directory integrity
- Disk usage monitoring
- Long-running query detection

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **PostgreSQL Init** | `.devcontainer/scripts/services/init-postgresql.sh` | Handles startup, integrity checks, and recovery |
| **Backup System** | `.devcontainer/scripts/services/backup-postgresql.sh` | Manages backups and restoration |
| **Maintenance Tools** | `.devcontainer/scripts/services/maintenance.sh` | Provides health checks and utilities |
| **Service Orchestrator** | `.devcontainer/scripts/start-services.sh` | Coordinates service initialization |

## Directory Structure

```
Container Environment:
├── /var/lib/postgresql-data/      # PostgreSQL data (persistent)
├── /var/log/postgresql/           # PostgreSQL logs
├── /var/lib/postgresql-backup/    # Backup storage
└── /usr/local/bin/devcontainer-scripts/
    └── services/
        ├── init-postgresql.sh     # PostgreSQL initialization
        ├── backup-postgresql.sh   # Backup management
        └── maintenance.sh         # Maintenance utilities

Host Environment:
├── .DB_data/                      # Mounted to /var/lib/postgresql-data/
├── .DB_logs/                      # Mounted to /var/log/postgresql/
└── .DB_backups/                   # Mounted to /var/lib/postgresql-backup/
```

## Common Tasks

### Daily Operations

| Task | Command |
|------|---------|
| Check health | `maintenance.sh health` |
| View status | `maintenance.sh status` |
| Create backup | `backup-postgresql.sh create` |
| List backups | `backup-postgresql.sh list` |

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Container won't start | Check logs: `docker logs <container>` |
| PostgreSQL errors | View logs: `tail -50 /var/log/postgresql/postgresql.log` |
| Data corruption | Automatic recovery on next startup |
| Need to restore | Use `backup-postgresql.sh restore` |

## Support Resources

1. **Full Documentation**: [PostgreSQL-Data-Corruption-Prevention.md](./PostgreSQL-Data-Corruption-Prevention.md)
2. **Quick Reference**: [Quick-Reference-Guide.md](./Quick-Reference-Guide.md)
3. **Container Logs**: `docker logs <container-name>`
4. **PostgreSQL Logs**: `/var/log/postgresql/postgresql.log`

## Best Practices

1. ✅ **Run health checks regularly** to catch issues early
2. ✅ **Create manual backups** before major database operations
3. ✅ **Monitor disk usage** to prevent space issues
4. ✅ **Review logs** when problems occur
5. ✅ **Use proper shutdown** procedures (avoid force kill)
6. ✅ **Keep backups** for at least 7 days

## Emergency Contacts

For critical issues:
1. Check container logs immediately
2. Run health check to assess system state
3. Review PostgreSQL logs for detailed errors
4. Consult troubleshooting section in full documentation

## Version Information

- **System Version**: 1.0.0
- **PostgreSQL Version**: 15
- **Last Updated**: October 17, 2025
- **Status**: Production Ready ✅

## Contributing

When updating this documentation:
1. Keep both guides synchronized
2. Test all commands before documenting
3. Include version numbers for references
4. Update the "Last Updated" date
5. Document any new features or changes

---

**Note**: This documentation is for the Ruby on Rails development container with integrated PostgreSQL data corruption prevention system. For general Docker or PostgreSQL documentation, refer to their official resources.

