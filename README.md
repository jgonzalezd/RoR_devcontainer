# DevContainer Configuration

This document describes a development environment provisioned within a DevContainer. It focuses on consistent environment management, persistent data, and streamlined developer workflows.

## Features and Benefits

### Environment Provisioning
The DevContainer is built on `ubuntu:22.04` and configured to provide a consistent and isolated development environment. It includes:
- **Version Management**: Utilizes build arguments and environment variables for managing core software versions, including Ruby (via RVM), Node.js (via NVM), and PostgreSQL.
- **Non-Root User Operations**: A dedicated `vscode` user with `sudo` privileges ensures secure development practices.
- **SSH Integration**: Configures SSH for seamless integration with version control systems.
- **Shell Consistency**: Employs system-wide and user-specific shell initialization scripts (`.bashrc`, `.bash_profile`, `/etc/profile.d/nvm.sh`, `/etc/profile.d/rvm.sh`) to guarantee consistent environment loading across all shell sessions (login and non-login).

### AI Coding Agent CLIs
Two agent CLIs are installed into the image at build time, so no container start re-downloads them:

| Command | Package | Pinned by |
|---|---|---|
| `claude` | `@anthropic-ai/claude-code` | `CLAUDE_CODE_VERSION` build arg |
| `pi` | `@earendil-works/pi-coding-agent` ([pi.dev](https://pi.dev)) | `PI_VERSION` build arg |

Both build args default to `latest`, so a rebuild picks up the current release. Set either to an exact version in the `args` block of `.devcontainer/devcontainer.json` to pin it.

The two packages need different `npm` flags. Claude Code downloads its native binary in a postinstall script, so install scripts must stay enabled; installing it with `--ignore-scripts` appears to succeed and then fails at runtime with `Error: claude native binary not installed`. Pi's own documentation at pi.dev specifies `--ignore-scripts`. The Dockerfile applies each flag to the correct package.

Neither CLI is authenticated by the build. Claude Code stores its credentials under `~/.claude` inside the container and Pi requires model-provider API keys, so both need signing in again after a rebuild unless you mount a credentials directory.

### Persistent Data Management
The DevContainer ensures data persistence across container lifecycles (restarts and rebuilds) through named Docker volumes and bind mounts:
- **Database Data**: PostgreSQL data is persisted in the named Docker volume `postgres-data`, mounted at `/var/lib/postgresql-data`.
- **Logs**: PostgreSQL logs are mounted to a local directory (`.DB_logs/`) for debugging and analysis.
- **Backups**: A dedicated directory (`.DB_backups/`) is configured for PostgreSQL backup storage.
- **Dependency Caching**: Ruby gems are cached in the named Docker volume `rvm-gems`, mounted at `/home/vscode/.rvm/gems`, to significantly accelerate container rebuilds and dependency installations.
- **SSH Keys**: User SSH keys are mounted from the host for secure access to external services.

### Container Storage

What lives in a named Docker volume versus a bind mount to the repo:

| Data | Storage | Mounted at (container) |
|------|---------|-------------------------|
| PostgreSQL data | named volume `postgres-data` | `/var/lib/postgresql-data` |
| Ruby gems | named volume `rvm-gems` | `/home/vscode/.rvm/gems` |
| PostgreSQL logs | bind mount `.DB_logs/` | `/var/log/postgresql` |
| PostgreSQL backups | bind mount `.DB_backups/` | `/var/lib/postgresql-backup` |
| Playwright cache | bind mount `.playwright-cache/` | `/home/vscode/.cache/ms-playwright` |

PostgreSQL data and Ruby gems use named volumes rather than bind mounts for two reasons. This repo lives under `Library/Mobile Documents/com~apple~CloudDocs`, an iCloud Drive path that can evict files it has not synced, and PostgreSQL data files must not sit on a filesystem that can do that. A bind mount for gems also hides the image's own gem directory, which is how `rails` and `bundler` went missing from a running container even though both were installed at build time.

### Service Orchestration and Database Management
The container integrates modular service management scripts for automated setup and maintenance:
- **PostgreSQL Lifecycle**: The `init-postgresql.sh` script handles comprehensive PostgreSQL cluster initialization, configuration, user management, and automatic startup. It includes data integrity checks and recovery mechanisms with pre-recovery backups to prevent data loss.
- **Backup and Recovery**: The `backup-postgresql.sh` script provides robust backup creation, listing, restoration, and automated cleanup of old backups based on a defined retention policy.
- **Database Maintenance**: The `maintenance.sh` script centralizes PostgreSQL operational tasks, offering commands for status checks, health monitoring, and service restarts.
- **Extensible Service Architecture**: A modular `scripts/services` directory allows for easy integration of additional database or service initialization routines (e.g., `init-mongodb.sh` as a placeholder).

### Development Workflow Enhancements
- **Automated Lifecycle Hooks**: `postCreateCommand.sh`, `postStartCommand.sh`, and `postAttachCommand.sh` scripts automate initial tool verification, environment checks, and ensure tool availability upon container creation, startup, and attachment, respectively.
- **Port Forwarding**: Essential development ports (e.g., 3000, 3001, 5432, 8080, 5173) are automatically forwarded to the host machine for seamless application access and testing.
- **Integrated Verification**: A `VERIFICATION.md` document outlines the DevContainer's architecture, shell initialization chain, key components, and provides detailed steps for verifying the environment's integrity and functionality.
- **Troubleshooting Guidance**: The `VERIFICATION.md` also includes solutions for common issues and best practices for environment management and version updates.

## Version Management

Version numbers for Ruby, Node.js, and PostgreSQL are configured in `.devcontainer/devcontainer.json`. To modify these versions, edit the `args` section within the `build` object in this file and then rebuild the container.

## Commands

### Environment Verification
To ensure all services and tools are correctly configured, execute:
```bash
/workspace/verify-environment.sh
```

### PostgreSQL Management
For database status, backups, and health checks, utilize the maintenance script:
```bash
/usr/local/bin/devcontainer-scripts/services/maintenance.sh <command>
# Example: /usr/local/bin/devcontainer-scripts/services/maintenance.sh status
```

For backup specific operations:
```bash
/usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh <command>
# Example: /usr/local/bin/devcontainer-scripts/services/backup-postgresql.sh create
```

## Architecture Principles

This DevContainer is designed with the following principles:
- **Consistency**: Uniform environment across all shell types and container lifecycles.
- **Maintainability**: Centralized configuration and modular scripting.
- **Extensibility**: Facilitates integration of new services and tools.
- **Reliability**: Automated verification, data integrity checks, and recovery mechanisms.
- **Performance**: Optimized builds with dependency caching and pre-installed tools.
- **Isolation**: Project-specific dependency management.

## Contributing

To modify this DevContainer:
1. Edit relevant configuration files in `.devcontainer/`.
2. Rebuild the container.
3. Verify changes using `/workspace/verify-environment.sh`.
4. Document any architectural or functional changes within this README and `VERIFICATION.md`.


