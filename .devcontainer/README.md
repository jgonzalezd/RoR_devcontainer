# DevContainer Configuration

Production-ready development environment for Ruby on Rails + Vue.js + PostgreSQL applications.

## Quick Start

1. **Open in DevContainer**: VS Code will detect the configuration and prompt you to reopen in container
2. **Wait for build**: First build takes ~5-10 minutes (cached after that)
3. **Ready to code**: After container starts, all tools are ready

## What's Included

### Languages & Frameworks
- **Ruby** 3.3.7 (via RVM)
- **Rails** 8.0.3 (latest)
- **Node.js** 22.x (via NVM)
- **npm** 10.x
- **yarn** 1.x
- **Vue CLI** 5.x
- **Vite** (for modern Vue.js apps)

### Database
- **PostgreSQL** 15
- Auto-starts with container
- Persistent data in `.DB_data/`
- User: `dbuser` (superuser)
- Password: `password`
- Connection: `postgresql://dbuser:password@localhost:5432/dbuser`

### Development Tools
- Git
- SSH (keys mounted from host)
- Ruby LSP (Shopify)
- Vue language support (Volar)
- PostgreSQL client tools

## Version Management

### Change Default Versions

Edit `.devcontainer/devcontainer.json`:

```json
{
  "build": {
    "args": {
      "RUBY_VERSION": "3.3.7",    // ← Change here
      "NODE_VERSION": "22",        // ← Change here
      "POSTGRES_VERSION": "15"     // ← Change here
    }
  }
}
```

Then rebuild container: `Cmd/Ctrl + Shift + P` → "Rebuild Container"

### Switch Versions at Runtime

**Node.js:**
```bash
nvm install 20
nvm use 20
nvm use default  # back to default
```

**Ruby:**
```bash
rvm install 3.2.0
rvm use 3.2.0
rvm use default  # back to default
```

## Lifecycle Scripts

### postCreateCommand.sh
- Runs **once** after container is created
- Verifies Ruby, Rails, Node, npm, yarn, Vue CLI
- Quick check that build completed successfully

### postStartCommand.sh  
- Runs **every time** container starts
- Waits for PostgreSQL to be ready
- Runs full environment verification
- Creates default database if needed

### postAttachCommand.sh
- Runs **every time** you attach to the container
- Ensures RVM is loaded
- Verifies Rails availability
- Installs Rails if missing (safety net)

## Database Management

### Create a New Database
```bash
createdb myapp_development
createdb myapp_test
```

### Connect to PostgreSQL
```bash
psql -h localhost -U dbuser
```

### Rails Database Configuration

`config/database.yml`:
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: dbuser
  password: password
  host: localhost

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test
```

## Shell Initialization (Technical)

The devcontainer uses a clean, non-duplicating initialization:

**Login shells** (VS Code terminals):
1. `/etc/profile.d/nvm.sh` → Loads NVM
2. `/etc/profile.d/rvm.sh` → Loads RVM
3. `~/.bash_profile` → Sources `~/.bashrc`
4. `~/.bashrc` → Checks guards, skips if already loaded ✅

**Non-login shells** (e.g., scripts):
1. `~/.bashrc` → Checks guards, loads NVM/RVM ✅

Each tool loads **exactly once** per shell session.

## Persistent Data

### Mounted Directories
- `.DB_data/` → PostgreSQL database files
- `.DB_logs/` → PostgreSQL logs
- `.gems-cache/` → Ruby gems (speeds up rebuilds)
- `~/.ssh/` → SSH keys from host (for git operations)

### Data Survival
- ✅ Survives container restart
- ✅ Survives container rebuild  
- ✅ Survives Docker Desktop restart
- ❌ Lost if you delete `.DB_data/` folder

## Common Commands

### Start a New Rails App
```bash
rails new myapp --database=postgresql
cd myapp
rails db:create
rails server -p 3001
```

### Start a New Vue App
```bash
npm create vue@latest myapp
cd myapp
npm install
npm run dev
```

### Run Rails + Vue Together
Terminal 1:
```bash
cd myapp-api
rails server -p 3001
```

Terminal 2:
```bash
cd myapp-frontend
npm run dev
```

## Troubleshooting

### Rails not found
```bash
source ~/.rvm/scripts/rvm
rvm use default
rails --version
```

### PostgreSQL not ready
Wait ~10 seconds after container starts, or check status:
```bash
pg_isready -h localhost -p 5432
```

### Gems not installing
```bash
bundle install
# or
gem install <gem-name>
```

### Node packages not installing
```bash
npm install
# or
yarn install
```

## Ports

All these ports are forwarded to your host machine:

- **3000** - Default Rails/Vue dev server
- **3001** - Rails API server
- **5432** - PostgreSQL
- **5173** - Vite dev server
- **8080** - Alternative Vue dev server

Access via `http://localhost:<port>` on your host machine.

## Architecture Principles

This devcontainer follows senior engineering best practices:

✅ **Single source of truth**: Versions defined once in `devcontainer.json`  
✅ **No duplication**: Shell initialization guards prevent double-loading  
✅ **Persistent data**: Database survives container lifecycle  
✅ **Fast rebuilds**: Gem cache and layer optimization  
✅ **Developer friendly**: Auto-verification and helpful error messages  
✅ **Production parity**: Same PostgreSQL version as production  

## Contributing

To modify this devcontainer:

1. Edit configuration files in `.devcontainer/`
2. Test with: "Rebuild and Reopen in Container"
3. Verify with: `/workspace/verify-environment.sh`
4. Document changes in this README

---

**Questions?** Check `/workspace/.devcontainer/VERIFICATION.md` for detailed technical documentation.


