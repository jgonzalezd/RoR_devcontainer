# DevContainer Verification Guide

This document explains how the devcontainer is configured and how to verify it works correctly after rebuild.

## Architecture Overview

### Shell Initialization Chain

1. **Login Shells** (e.g., `bash -l`, `su -`)
   - Read `/etc/profile` → sources all `/etc/profile.d/*.sh`
   - Read `~/.bash_profile` → sources `~/.bashrc`
   - Result: RVM, NVM, Ruby, Node, Rails available

2. **Interactive Non-Login Shells** (e.g., `bash`)
   - Read `~/.bashrc` directly
   - Result: RVM, NVM, Ruby, Node, Rails available

3. **VS Code Terminals**
   - Configured as login shells via `args: ["-l"]` in devcontainer.json
   - Follow login shell path above

### Key Components

#### 1. System-Wide Profile Hooks
- **Location**: `/etc/profile.d/nvm.sh` and `/etc/profile.d/rvm.sh`
- **Created**: During container build (Dockerfile lines 124-134)
- **Purpose**: Ensure RVM and NVM load for all users in all login shells
- **Permissions**: 644 (readable by all)

#### 2. User Profile Files
- **`~/.bashrc`**: Contains RVM/NVM loading for interactive shells
- **`~/.bash_profile`**: Sources `~/.bashrc` for login shells
- **`~/.rvmrc`**: Enables RVM gemset auto-switching per project

#### 3. Environment Variables
- **Build-time**: `RUBY_VERSION`, `NODE_VERSION`, `POSTGRES_VERSION`
- **Runtime**: `DATABASE_URL`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **PATH**: Pre-configured with RVM bin and Node bin directories

## Verification Steps

### After Rebuild

1. **Open a new terminal in VS Code**

2. **Verify Ruby/RVM**
   ```bash
   which rvm
   # Expected: /home/vscode/.rvm/bin/rvm
   
   which ruby
   # Expected: /home/vscode/.rvm/rubies/ruby-3.3.7/bin/ruby
   
   ruby --version
   # Expected: ruby 3.3.7 (2025-01-15 revision be31f993d7) [architecture]
   
   rvm current
   # Expected: ruby-3.3.7
   ```

3. **Verify Rails**
   ```bash
   which rails
   # Expected: /home/vscode/.rvm/gems/ruby-3.3.7/bin/rails
   
   rails --version
   # Expected: Rails 8.x.x (or latest installed version)
   ```

4. **Verify Node/NVM**
   ```bash
   which node
   # Expected: /home/vscode/.nvm/versions/node/v22.x.x/bin/node
   
   node --version
   # Expected: v22.x.x
   
   npm --version
   # Expected: 10.x.x (or corresponding npm version)
   
   yarn --version
   # Expected: 1.x.x (or latest)
   ```

5. **Verify PostgreSQL**
   ```bash
   pg_isready -h localhost -p 5432
   # Expected: /var/run/postgresql:5432 - accepting connections
   
   psql -h localhost -U dbuser -d postgres -c "SELECT version();"
   # Expected: PostgreSQL 15.x version string
   ```

6. **Test in Different Shell Types**
   ```bash
   # Test non-login shell
   bash -c "which rails && rails --version"
   # Should work
   
   # Test login shell
   bash -l -c "which rails && rails --version"
   # Should work
   
   # Test new terminal
   # Open new terminal in VS Code and run: rails --version
   # Should work
   ```

7. **Run Environment Verification Script**
   ```bash
   /workspace/verify-environment.sh
   ```
   Should display all services as ✅ ready

## Common Issues and Solutions

### Issue: `rails: command not found`

**Cause**: RVM not loaded in current shell

**Solution**:
```bash
source ~/.rvm/scripts/rvm
rvm use default
rails --version  # Should work now
```

**Permanent Fix**: Rebuild container - profile.d scripts should handle this automatically

### Issue: Profile.d scripts not found

**Cause**: Container built from old Dockerfile

**Solution**: Rebuild container from updated Dockerfile

**Verify**:
```bash
ls -la /etc/profile.d/
# Should show: nvm.sh and rvm.sh
```

### Issue: Wrong Ruby version

**Cause**: Multiple Ruby versions or gemset issues

**Solution**:
```bash
rvm list
rvm use 3.3.7 --default
gem list rails
```

## Lifecycle Scripts

### postCreateCommand.sh
- **When**: Once after container creation
- **What**: Runs `/workspace/verify-environment.sh`
- **Purpose**: Verify environment is correctly set up

### postStartCommand.sh
- **When**: Every container start
- **What**: Displays PostgreSQL data location
- **Purpose**: Inform developer about persistent data

### postAttachCommand.sh
- **When**: Every time you attach to container
- **What**: Ensures RVM loaded, verifies Rails, installs if missing
- **Purpose**: Guarantee Rails availability in every session

## Best Practices

1. **Always use login shells** for Rails commands
   - VS Code terminal: Already configured as login shell
   - Command line: Use `bash -l` or `source ~/.bash_profile`

2. **Use project-specific gemsets**
   - `.rvmrc` already configured for auto-switching
   - Each project gets isolated gems

3. **Verify after rebuild**
   - Run verification script
   - Test `rails new` in a test directory
   - Ensure PostgreSQL is accessible

4. **Keep versions updated**
   - Edit `devcontainer.json` build args
   - Rebuild container
   - Version changes propagate automatically

## Maintenance

### Updating Ruby Version

1. Edit `.devcontainer/devcontainer.json`:
   ```json
   "RUBY_VERSION": "3.3.8"
   ```

2. Edit `.devcontainer/Dockerfile` line 133:
   ```dockerfile
   'rvm use 3.3.8 --default >/dev/null 2>&1 || true' \
   ```

3. Rebuild container

### Updating Node Version

1. Edit `.devcontainer/devcontainer.json`:
   ```json
   "NODE_VERSION": "23"
   ```

2. Rebuild container (profile.d/nvm.sh uses `$HOME/.nvm` dynamically)

### Updating PostgreSQL Version

1. Edit `.devcontainer/devcontainer.json`:
   ```json
   "POSTGRES_VERSION": "16"
   ```

2. Rebuild container

3. **Warning**: Data migration may be required if upgrading major version

## Architecture Benefits

✅ **Consistency**: All shells (login, non-login, VS Code) have same environment
✅ **Maintainability**: Centralized configuration in profile.d
✅ **Extensibility**: Easy to add more tools following same pattern
✅ **Reliability**: Build-time installation ensures tools always available
✅ **Performance**: Pre-installed tools, no wait time on attach
✅ **Isolation**: Per-project gemsets via RVM, NVM for Node versions

## Related Files

- `/workspace/.devcontainer/Dockerfile` - Container build configuration
- `/workspace/.devcontainer/devcontainer.json` - VS Code integration
- `/workspace/.devcontainer/postCreateCommand.sh` - Post-creation script
- `/workspace/.devcontainer/postStartCommand.sh` - Post-start script
- `/workspace/.devcontainer/postAttachCommand.sh` - Post-attach script
- `/workspace/verify-environment.sh` - Environment verification script
- `/etc/profile.d/nvm.sh` - System-wide NVM loader
- `/etc/profile.d/rvm.sh` - System-wide RVM loader
- `~/.bashrc` - User interactive shell config
- `~/.bash_profile` - User login shell config
- `~/.rvmrc` - RVM trust configuration

---

**Last Updated**: Based on Dockerfile with profile.d integration
**Maintained By**: DevContainer configuration team

