# Rails 7+ Modern Development Setup Guide

A comprehensive guide for building modern Rails 7+ applications with Vue.js frontends using Docker devcontainers. This repository provides everything you need to start developing with Rails, Vue.js, PostgreSQL, and modern JavaScript build tools.

## 🚀 What's Included

- **Rails 7+ Environment** - Ruby 3.2+ with Rails pre-configured
- **Vue.js 3 Support** - Modern frontend development with esbuild or Vite
- **PostgreSQL Database** - Ready-to-use database with version flexibility
- **VS Code DevContainer** - Complete development environment in Docker
- **Multiple Architecture Options** - Monolithic or API-first approaches
- **AI Assistant Integration** - Smart project scope management
- **Production-Ready Configs** - Deployment and scaling considerations

## 📋 Table of Contents

1. [🛠️ DevContainer Setup](#-devcontainer-setup)
2. [🏗️ Project Architecture Options](#-project-architecture-options)
3. [📦 Build System Options](#-build-system-options)
4. [🗄️ Database Configuration](#-database-configuration)
5. [🤖 AI Assistant Integration](#-ai-assistant-integration)
6. [🚀 Development Workflow](#-development-workflow)
7. [🔧 Production Deployment](#-production-deployment)
8. [🔍 Troubleshooting](#-troubleshooting)

---

## 🛠️ DevContainer Setup

### Prerequisites

- [Docker](https://www.docker.com/get-started) installed on your machine
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Getting Started

#### 1. Open in Dev Container

1. Clone this repository or copy the `.devcontainer` folder to your new project
2. Open the project folder in VS Code
3. When prompted, click "Reopen in Container" or:
   - Press `Cmd/Ctrl + Shift + P`
   - Type "Dev Containers: Reopen in Container"
   - Press Enter

#### 2. Container Build Process

The first time you open the project, Docker will build the container:
- **Initial build**: 5-10 minutes (downloads base images, installs Ruby/Node.js)
- **Subsequent starts**: 30-60 seconds (reuses cached layers)
- **Rebuilds**: Only needed when changing `.devcontainer/` configuration

#### 3. Environment Verification

After the container starts, you'll see:
```bash
🔍 Verifying development environment...
Ruby: ruby 3.2.0 (2022-12-25 revision a528908271)
Rails: Rails 7.1.5
Node.js: v18.19.0
Vue CLI: @vue/cli 5.0.8
PostgreSQL: Service started
✅ Environment ready! Database: postgresql://vscode:password@localhost/vscode
```

### Container Configuration

The devcontainer includes:

**Development Stack:**
- Ruby 3.2+ with RVM
- Rails 7.1+ with development gems
- Node.js 18.x LTS with npm/yarn
- PostgreSQL (version configurable)
- Vue CLI and modern build tools

**VS Code Extensions:**
- Ruby LSP for intelligent Ruby support
- Vue.js/TypeScript development tools
- PostgreSQL database management
- Git and GitHub integration

**Auto-forwarded Ports:**
- `3000` - Rails server
- `3001` - Additional Rails services  
- `5173` - Vite dev server
- `5432` - PostgreSQL database
- `8080` - Vue CLI dev server

---

## 🏗️ Project Architecture Options

Choose the architecture that best fits your project needs:

### Option 1: Monolithic Rails + API Namespace

**Best for:** Rapid development, small to medium teams, simple deployment

```
rails_app/
├── app/
│   ├── controllers/
│   │   ├── api/v1/          # API endpoints
│   │   └── pages_controller.rb
│   ├── javascript/          # Vue.js frontend
│   │   ├── application.js
│   │   └── components/
│   └── views/layouts/
│       └── application.html.erb
├── config/routes.rb
├── package.json            # Frontend dependencies
└── esbuild.config.js       # Build configuration
```

**Setup Commands:**
```bash
# crete gemset
rvm gemset use feed --create

#install rails
gem install rails -v "~> 7.1.0" --no-document

# Create Rails application
rails new myapp --database=postgresql -j vue   #Adds jsbundling-rails to gemfile

# install gems
cd myapp
bundle install

# Install Vue.js
npm install vue@^3.4.0 @vue/compiler-sfc@^3.4.0 axios@^1.6.0
npm install --save-dev esbuild@^0.19.0 esbuild-plugin-vue3@^0.4.0

# Setup API namespace
rails generate controller Api::V1::Base --skip-template-engine
```


### Option 2: Separate Frontend + API

**Best for:** Large teams, multiple clients, independent scaling

```
frontend_app/              api_app/
├── src/                   ├── app/
│   ├── components/        │   ├── controllers/api/
│   ├── views/             │   └── models/
│   └── main.js            ├── config/
└── vite.config.js         │   └── routes.rb
                           └── Gemfile
```

**Setup Commands:**
```bash
# Create API-only Rails app
rails new myapi --api --database=postgresql

# Create Vue.js frontend
npm create vue@latest frontend
cd frontend && npm install

# Configure CORS in Rails
echo 'gem "rack-cors"' >> Gemfile
bundle install
```

### Architecture Comparison

| Feature | Monolithic | Separate |
|---------|------------|----------|
| **Development Speed** | ⚡ Fast | 🐌 Moderate |
| **Team Separation** | 👥 Full-stack | 👨‍💻👩‍💻 Specialized |
| **Deployment** | ⚡ Single | 🔧 Coordinated |
| **Scaling** | 🔧 Together | ✅ Independent |
| **Hot Module Replacement** | ❌ Limited | ✅ Full |
| **API Reusability** | 🔧 Limited | ✅ High |


---

## 📦 Build System Options

Choose between two proven JavaScript build systems for your Rails application:

### Option A: esbuild (Fast & Lightweight)

**Best for:** Simple setups, fast builds, minimal configuration

#### Setup esbuild

```bash
# Install esbuild dependencies
npm install --save-dev esbuild@^0.19.0 esbuild-plugin-vue3@^0.4.0
```

#### Configuration Files

**Create JS base directories & files**

```
Directories:
- rails_app/app/javascript/components
- rails_app/app/javascript/config
- rails_app/app/javascript/stores


Files:
- rails_app/app/javascript/application.js
- rails_app/esbuild.config.js
- rails_app/package.json
- rails_app/app/views/home/index.html.erb


mkdir -p app/javascript/components
mkdir app/javascript/config
mkdir app/javascript/stores
touch app/javascript/application.js
```


```
rails_app/
├── app/
│   ├── controllers/
│   │   ├── api/v1/          # API endpoints
│   │   └── pages_controller.rb
│   ├── javascript/          # Vue.js frontend
│   │   ├── application.js
│   │   └── components/
│   └── views/layouts/
│       └── application.html.erb
├── config/routes.rb
├── package.json            # Frontend dependencies
└── esbuild.config.js       # Build configuration
```


**package.json scripts:**
```json
{
  "name": "template",
  "private": true,
  "version": "1.0.0",
  "description": "SPA built with Rails + Vue.js",
  "scripts": {
    "build": "node esbuild.config.js",
    "build:watch": "node esbuild.config.js --watch"
  },
  "dependencies": {
    "vue": "^3.4.0",
    "@vue/compiler-sfc": "^3.4.0",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "esbuild": "^0.19.0",
    "esbuild-plugin-vue3": "^0.4.0"
  }
}
```

**esbuild.config.js:**
```javascript
const esbuild = require('esbuild')
const vue = require('esbuild-plugin-vue3')
const watch = process.argv.includes('--watch')

const buildOptions = {
    entryPoints: ['app/javascript/application.js'],
    bundle: true,
    outdir: 'app/assets/builds',
    publicPath: '/assets',
    plugins: [vue()],
    format: 'iife', // <=== DON'T USE 'esm' app breaks
    target: 'es2020',
    sourcemap: true
}

if (watch) {
    esbuild.context(buildOptions).then(context => {
        context.watch()
        console.log('👀 Watching for changes...')
    }).catch(() => process.exit(1))
} else {
    esbuild.build(buildOptions).catch(() => process.exit(1))
}
```

**app/javascript/application.js**

```javascript
import { createApp } from 'vue'
import DefaultApp from './components/DefaultApp.vue'
import './config/axios' // Initialize axios configuration

import '../assets/stylesheets/application.css'

function initializeApp() {
  console.log('Initializing Vue app...')
  console.log('DOM ready state:', document.readyState)
  
  const appElement = document.getElementById('app')
  console.log('App element found:', appElement)
  
  if (!appElement) {
    console.error('No element with id="app" found!')
    return
  }
  
  try {
    const app = createApp(DefaultApp)
    console.log('Vue app created:', app)
    app.mount('#app')
    console.log('Vue app mounted successfully!')
  } catch (error) {
    console.error('Error mounting Vue app:', error)
  }
}

// Handle both cases: DOM already loaded or still loading
if (document.readyState === 'loading') {
  console.log('DOM still loading, waiting for DOMContentLoaded...')
  document.addEventListener('DOMContentLoaded', initializeApp)
} else {
  console.log('DOM already loaded, initializing immediately...')
  // DOM already loaded, initialize immediately
  initializeApp()
}

console.log('App loaded')
```
**app/javascript/DefaultApp.vue**

```vue
<template>

</template>

<script>
import axios from 'axios'

export default {
    name: 'DefaultApp',
    data() {
        return {
            message: 'Hello, World!',
            records: [],
            isLoading: false,
        }
    },
    mounted() { 
        this.fetchData()
    },
    methods: {
        async fetchData() {
            this.error = null
            try {
                this.isLoading = true
                console.log('Fetching quick wins...')
                const response = await axios.get('/api/data_endpoint')
                this.records = response.data
                console.log('Quick wins loaded:', this.records)
            } catch (error) {
                console.error('Error fetching quick wins:', error)
                this.error = 'Failed to load quick wins. Please try again.'
            } finally {
                this.isLoading = false
            }
        },
    }
}
</script>

<style scoped>
</style>
```

**app/javascript/config/axios.js**
```javascript
import axios from 'axios'

// Get CSRF token from meta tag
const csrfToken = document.querySelector('meta[name="csrf-token"]') ?
                  document.querySelector('meta[name="csrf-token"]').getAttribute('content') :
                  null;

// Configure Axios defaults
if (csrfToken) {
  axios.defaults.headers.common['X-CSRF-Token'] = csrfToken;
}

// This makes sure cookies are sent with requests (for Rails session cookies)
axios.defaults.withCredentials = true;

// Set default content type for requests
axios.defaults.headers.common['Content-Type'] = 'application/json';
axios.defaults.headers.common['Accept'] = 'application/json';

// Add request interceptor for debugging (optional, can be removed in production)
axios.interceptors.request.use(
  (config) => {
    console.log('Making request to:', config.url);
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Add response interceptor for error handling
axios.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    console.error('API request failed:', error.response?.data || error.message);
    return Promise.reject(error);
  }
);

export default axios; 
```

**app/views/home/index.html.erb**

```html
<div id="app">
    <div class="fallback-message" style="text-align: center; padding: 40px; font-family: Arial, sans-serif;">
        <h2>Quick Wins App</h2>
        <p>If you're seeing this message, there might be a JavaScript error preventing the app from loading properly.</p>
        <p>Please check your browser's console for any error messages and try refreshing the page.</p>
        <div style="margin-top: 20px; padding: 15px; background-color: #f8f9fa; border-radius: 5px; border-left: 4px solid #007bff;">
            <strong>Need help?</strong> Make sure JavaScript is enabled in your browser.
        </div>
    </div>
</div>
```


**app/views/layouts/application.html.erb**
```html
<!DOCTYPE html>
<html>
  <head>
    <title>Interview Scheduler</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "application", "data-turbo-track": "reload" %>
  </head>

  <body>
    <%= yield %>
  </body>
</html> 
```




### Option B: Vite (Modern Development)

**Best for:** Hot module replacement, modern dev experience, complex frontends

#### Setup Vite

```bash
# Install via Rails (recommended)
rails javascript:install:vite

# OR manual installation
npm install --save-dev vite@^4.0.0 @vitejs/plugin-vue@^4.0.0
```

#### Configuration Files

**package.json scripts:**
```json
{
  "scripts": {
    "build": "vite build",
    "build:watch": "vite build --watch",
    "dev": "vite"
  }
}
```

**vite.config.js:**
```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'app/assets/builds',
    assetsDir: '',
    rollupOptions: {
      input: 'app/javascript/application.js'
    }
  },
  server: {
    port: 5173
  }
})
```





### Build System Comparison

| Feature | esbuild | Vite |
|---------|---------|------|
| **Setup Complexity** | Simple | Moderate |
| **Hot Module Replacement** | No | Yes |
| **Build Speed** | Very Fast | Fast |
| **Dev Server** | Rails integrated | Separate server |
| **Terminal Count** | 1 (preferred) | 2 (required) |
| **Browser Refresh** | Full page | Component only |




---
## Quickstart using the template folder

### 1. Update the RVM gemset

```bash
cp -r template new_app

# udpate .rvmrc
rvm use 3.2.0@<new_gemset_name> --create  # 
source new_app/.rvmrc
```

### 2. Update the `my_app/config/database.ym` file
(find and replace "template" by "<your_app_name>") Example

```yaml
development:
  <<: *default
  database: <your_app_name>_development
  #database: template_development
```

### Run `./run_dev_stack.sh <your_app_folder>/`

---

## 🗄️ Database Configuration

### PostgreSQL Setup

The devcontainer includes a pre-configured PostgreSQL instance:

**Default Connection Details:**
- **Host:** `localhost`
- **Port:** `5432` 
- **Database:** `vscode`
- **Username:** `vscode`
- **Password:** `password`
- **URL:** `postgresql://vscode:password@localhost/vscode`

### Version Management

PostgreSQL version is configurable via the Dockerfile:

```dockerfile
# .devcontainer/Dockerfile
ARG POSTGRES_VERSION=15  # Change to 12, 13, 14, 15, 16, or 17
```

After changing the version:
```bash
# Rebuild the container
Cmd/Ctrl + Shift + P → "Dev Containers: Rebuild Container"
```

### Rails Database Configuration

**config/database.yml template:**
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: vscode
  password: password
  host: localhost
  port: 5432

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] %>
```

### Database Commands

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Seed data
rails db:seed

# Reset database
rails db:drop db:create db:migrate db:seed

# Direct PostgreSQL access
psql -h localhost -U vscode -d vscode

# Create additional databases
createdb myapp_development
createdb myapp_test
```

---

## 🤖 AI Assistant Integration

This repository includes smart AI assistant integration to help you focus on relevant code.

### Project Scope Management

The `.ai-ignore` file controls what AI tools search through:

**Currently Active Project:** `quick_wins/` (Rails + Vue.js monolithic app)
**Currently Inactive:** `quick_wins_vAPI/` (API-only Rails app)

### 🔄 Switching Active Projects

To change which project AI assistants focus on, simply edit `.ai-ignore`:

**Current Configuration (quick_wins active):**
```bash
# INACTIVE PROJECTS (add # to make active, remove # to make inactive)
quick_wins_vAPI/
# quick_wins/
```

**To switch to quick_wins_vAPI:**
```bash
# INACTIVE PROJECTS (add # to make active, remove # to make inactive)  
# quick_wins_vAPI/
quick_wins/
```

**To work on both projects simultaneously:**
```bash
# INACTIVE PROJECTS (add # to make active, remove # to make inactive)
# quick_wins_vAPI/
# quick_wins/
```

### ✅ Benefits

- **🎯 Focused AI Responses** - AI only sees relevant project code
- **🚀 Faster Searches** - Excludes node_modules, logs, build artifacts
- **👥 Team Consistency** - Everyone gets the same AI behavior
- **💾 Persistent Settings** - Configuration travels with the repository
- **🔧 Easy Switching** - Two-line edit to change project focus

### 📋 What's Excluded

The `.ai-ignore` file automatically excludes:
- Inactive project directories  
- `*/node_modules/`, `*/tmp/`, `*/log/`, `*/storage/`
- Build artifacts (`*/dist/`, `*/build/`, `*/app/assets/builds/`)
- Cache and temporary files
- OS and editor temporary files

**Note:** Build directories are excluded from general searches but can still be explicitly examined for debugging purposes.

---

## 🚀 Development Workflow

### Quick Start Commands

```bash
# 1. Create new Rails application
rails new myapp --database=postgresql
cd myapp

# 2. Add Vue.js support
echo 'gem "jsbundling-rails"' >> Gemfile
bundle install

# 3. Install frontend dependencies
npm install vue@^3.4.0 @vue/compiler-sfc@^3.4.0
npm install --save-dev esbuild@^0.19.0 esbuild-plugin-vue3@^0.4.0

# 4. Setup database
rails db:create
rails db:migrate

# 5. Start development
rails server  # Runs on http://localhost:3000
```

### Development Options

#### Option A: esbuild Workflow (Integrated)

**Single Terminal - Rails Handles Everything:**
```bash
rails server
# ✅ Automatically builds assets when files change
# ✅ Serves application on http://localhost:3000
# ✅ Shows build output in Rails console
# ✅ No additional terminals needed
```

**Two Terminal - Separated Build Process:**
```bash
# Terminal 1: Asset watching
npm run build:watch
# ✅ Dedicated build output
# ✅ Faster rebuilds
# ✅ Independent of Rails restart

# Terminal 2: Rails server
rails server
# ✅ Clean Rails logs
# ✅ Easy server restart
```

#### Option B: Vite Workflow (Modern)

**Two Terminal - Hot Module Replacement:**
```bash
# Terminal 1: Rails API server
rails server
# ✅ Serves backend API on http://localhost:3000
# ✅ Handles database, authentication, business logic

# Terminal 2: Vite development server  
npm run dev
# ✅ Serves frontend with HMR on http://localhost:5173
# ✅ Instant component updates without page reload
# ✅ Enhanced debugging with Vue DevTools
```

### Development Scripts

The `run_dev_stack.sh` script automates the development setup:

```bash
# Run automated development stack
./run_dev_stack.sh quick_wins

# What it does:
# ✅ Checks PostgreSQL service
# ✅ Installs Ruby dependencies
# ✅ Runs database migrations
# ✅ Installs Node.js dependencies
# ✅ Builds frontend assets
# ✅ Starts development servers
```

### File Structure

```
your_rails_app/
├── app/
│   ├── javascript/              # Frontend source code
│   │   ├── application.js       # Entry point
│   │   └── components/          # Vue components
│   │       ├── App.vue
│   │       └── HelloWorld.vue
│   ├── assets/
│   │   ├── builds/             # Built JavaScript (build output)
│   │   ├── config/
│   │   │   └── manifest.js     # Asset manifest
│   │   ├── images/
│   │   └── stylesheets/
│   ├── controllers/            # Rails controllers
│   ├── models/                # Rails models
│   └── views/                 # Rails views
├── config/
│   ├── database.yml           # Database configuration
│   ├── routes.rb              # Application routes
│   └── environments/          # Environment configs
├── package.json               # JavaScript dependencies
├── [esbuild.config.js]        # esbuild config (Option A)
├── [vite.config.js]           # Vite config (Option B)
├── Gemfile                    # Ruby dependencies
└── README.md
```

---

## 🗄️ Database Configuration

### PostgreSQL Setup

The devcontainer includes a pre-configured PostgreSQL instance:

**Default Connection Details:**
- **Host:** `localhost`
- **Port:** `5432` 
- **Database:** `vscode`
- **Username:** `vscode`
- **Password:** `password`
- **URL:** `postgresql://vscode:password@localhost/vscode`

### Version Management

PostgreSQL version is configurable via the Dockerfile:

```dockerfile
# .devcontainer/Dockerfile
ARG POSTGRES_VERSION=15  # Change to 12, 13, 14, 15, 16, or 17
```

After changing the version:
```bash
# Rebuild the container
Cmd/Ctrl + Shift + P → "Dev Containers: Rebuild Container"
```

### Rails Database Configuration

**config/database.yml template:**
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: vscode
  password: password
  host: localhost
  port: 5432

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] %>
```

### Database Commands

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Seed data
rails db:seed

# Reset database
rails db:drop db:create db:migrate db:seed

# Direct PostgreSQL access
psql -h localhost -U vscode -d vscode

# Create additional databases
createdb myapp_development
createdb myapp_test
```

---

## 🔧 Production Deployment

### Build Commands

```bash
# Install dependencies
bundle install --without development test
npm install --production

# Build assets
npm run build
rails assets:precompile

# Database setup
rails db:migrate
```

### Environment Variables

```env
RAILS_ENV=production
DATABASE_URL=postgresql://user:pass@host:5432/database
RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=your_secret_key
```

### Deployment Checklist

- [ ] Ruby and Node.js versions match development
- [ ] Environment variables configured
- [ ] Database accessible and migrated
- [ ] Assets precompiled
- [ ] SSL certificates configured

---

## 🔍 Troubleshooting

### Container Issues

**Container won't start:**
```bash
# Check Docker is running
docker --version

# Rebuild container
Cmd/Ctrl + Shift + P → "Dev Containers: Rebuild Container"

# Check container logs
docker logs <container_name>
```

**Permission issues:**
```bash
sudo chown -R vscode:vscode /workspace
```

### Database Issues

**PostgreSQL not running:**
```bash
# Start PostgreSQL
sudo service postgresql start

# Check status
sudo service postgresql status

# Reset connection
psql -h localhost -U vscode -d vscode
```

**Database connection errors:**
```bash
# Verify DATABASE_URL
echo $DATABASE_URL

# Test connection
pg_isready -h localhost -p 5432

# Reset database
rails db:drop db:create db:migrate
```

### Build Issues

**Assets not building:**
```bash
# Clear cache and rebuild
rails tmp:clear
rm -rf app/assets/builds/*
npm run build
rails server
```

**Vue components not loading:**
```bash
# Check entry point
cat app/javascript/application.js

# Verify imports and .vue extensions
# Check browser console for errors
```

**Node.js/npm issues:**
```bash
# Check versions
node --version  # Should be 18.x+
npm --version

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### Ruby/Rails Issues

**RVM not working:**
```bash
source ~/.rvm/scripts/rvm
rvm use 3.2.0
```

**Bundle install fails:**
```bash
# Update bundler
gem install bundler

# Clean and reinstall
bundle clean --force
bundle install
```

---

## 📚 Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Vue.js Documentation](https://vuejs.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [esbuild Documentation](https://esbuild.github.io/)
- [Vite Documentation](https://vitejs.dev/)
- [jsbundling-rails](https://github.com/rails/jsbundling-rails)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

---

## 📖 Quick Reference

### File Extensions
- `.rb` - Ruby files
- `.vue` - Vue Single File Components  
- `.js` - JavaScript files
- `.erb` - Embedded Ruby templates
- `.yml` - YAML configuration files

### Key Directories
- `app/` - Application code
- `config/` - Configuration files
- `db/` - Database files
- `public/` - Static assets
- `node_modules/` - npm packages
- `vendor/` - Third-party code

### Port Assignments
- `3000` - Rails server
- `3001` - Additional Rails services
- `5173` - Vite dev server
- `5432` - PostgreSQL database
- `8080` - Vue CLI dev server

---

This guide provides everything you need to start building modern Rails applications with Vue.js. The devcontainer setup ensures consistency across development environments, while the multiple architecture and build system options give you flexibility to choose the best approach for your project.
bundle install

# Install JavaScript dependencies (CRITICAL STEP)
npm install              # Reads package.json, creates node_modules/

# Start development
rails server            # Auto-runs npm build process
```

#### **2. Development Build Process**
```
1. Developer writes:         app/javascript/components/MyComponent.vue
                            ↓
2. jsbundling-rails runs:   npm run build --watch
                            ↓  
3. npm uses node_modules:   vue + esbuild to compile source
                            ↓
4. Build outputs to:        app/assets/builds/application.js
                            ↓
5. Rails asset pipeline:    app/assets/builds/ → public/assets/
                            ↓
6. Browser receives:        /assets/application-abc123.js
```

#### **3. Key Commands & Their Purpose**
```bash
# Install JavaScript dependencies
npm install                    # Creates node_modules/ from package.json

# Manual build (usually automatic)
npm run build                  # Compiles app/javascript/ → app/assets/builds/

# Development server (includes auto-build)
rails server                   # Runs npm run build --watch automatically

# Production build
rails assets:precompile        # npm install + npm run build + asset pipeline
```

### 🏗️ jsbundling-rails Integration Magic

#### **Automatic npm Integration**
jsbundling-rails automatically connects npm to Rails commands:

```ruby
# Rails tasks automatically run npm commands:
rails assets:precompile
# Internally runs: npm run build
# Then: Rails asset pipeline processing

rails server  
# Internally runs: npm run build --watch
# Rebuilds when app/javascript/ files change
```

#### **Build Script Configuration**
package.json contains the build commands Rails will execute:

```json
{
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds",
    "build:watch": "npm run build -- --watch"
  },
  "dependencies": {
    "vue": "^3.0.0",
    "esbuild": "^0.19.0"
  }
}
```

### 🚀 CI/CD & Deployment Workflow

#### **Complete Deployment Process**
```bash
# 1. Code checkout
git checkout main

# 2. Install Ruby dependencies
bundle install

# 3. Install JavaScript dependencies (REQUIRED)
npm install                    # Must happen before asset compilation

# 4. Compile all assets
rails assets:precompile        # Includes npm run build automatically

# 5. Deploy static assets
# public/assets/ contains all browser-ready files
```

#### **Critical CI/CD Requirements**

**Environment Setup:**
- ✅ **Ruby** installed (for Rails)
- ✅ **Node.js** installed (for npm)
- ✅ **Both package managers** functional

**Build Dependencies:**
```bash
# These commands must run in sequence:
bundle install     # Ruby gems
npm install        # JavaScript packages (Vue.js, build tools)
rails assets:precompile  # Uses both Ruby gems and npm packages
```

**Common CI/CD Failure Points:**
- ❌ Missing `npm install` step → "Vue is not defined" errors
- ❌ Wrong Node.js version → Build tool compatibility issues  
- ❌ Missing package.json → Rails can't find build scripts
- ❌ node_modules/ in .gitignore but not in CI cache → Slow builds

### 📁 File Responsibilities

#### **package.json (Root Level)**
```json
{
  "name": "rails-app",
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds"
  },
  "dependencies": {
    "vue": "^3.0.0"           // Framework code lives in node_modules/vue/
  }
}
```
- **Purpose:** JavaScript dependency management (like Gemfile for Ruby)
- **Location:** Root level (same level as Gemfile)
- **Usage:** Rails reads this to run build scripts

#### **node_modules/ Directory**
- **Purpose:** Installed JavaScript packages (like vendor/bundle for Ruby)
- **Contents:** Vue.js framework, build tools, utilities
- **Lifecycle:** Created by `npm install`, used by build process
- **Deployment:** Usually not deployed (recreated on server)

#### **app/javascript/ Directory**
- **Purpose:** Your custom frontend source code
- **Contents:** Vue components, application logic, styles
- **Lifecycle:** Written by developers, compiled by build process
- **Deployment:** Source code only (compiled version deployed)

#### **app/assets/builds/ Directory**
- **Purpose:** Compiled JavaScript output (npm build result)
- **Contents:** Bundled, transpiled JavaScript ready for Rails
- **Lifecycle:** Generated by npm run build, consumed by Rails asset pipeline
- **Deployment:** Intermediate files (further processed by Rails)

### ⚙️ Build Process Internals

#### **What npm run build Actually Does**
```bash
# When Rails runs: npm run build
# npm executes: esbuild app/javascript/*.* --bundle --outdir=app/assets/builds

# This process:
1. Reads: app/javascript/application.js (your entry point)
2. Resolves: import Vue from 'vue' → node_modules/vue/dist/vue.js
3. Bundles: All imports into single file
4. Transpiles: Modern JS → Browser-compatible JS  
5. Outputs: app/assets/builds/application.js (complete bundle)
```

#### **What Rails Asset Pipeline Adds**
```bash
# After npm build, Rails processes app/assets/builds/:
1. Fingerprinting: application.js → application-abc123.js
2. Compression: Gzips files for faster transfer
3. Manifest: Creates lookup table for fingerprinted names
4. CDN prep: Organizes for content delivery network
5. Cache headers: Sets up efficient browser caching
```

### 🔍 Troubleshooting Common Issues

#### **"Vue is not defined" Error**
```bash
# Problem: node_modules/ missing or incomplete
# Solution: 
npm install
rails assets:precompile
```

#### **Build Script Not Found**
```bash
# Problem: package.json missing scripts section
# Solution: Add build script to package.json
{
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds"
  }
}
```

#### **Assets Not Updating in Development**
```bash
# Problem: Build watcher not running
# Solution: Restart Rails server or run manual build
npm run build
rails server
```

### 💡 Key Insights

- **node_modules/ is like vendor/bundle** - contains framework libraries
- **package.json is like Gemfile** - defines what to install
- **npm install is like bundle install** - installs dependencies
- **Rails orchestrates everything** - but npm manages JavaScript ecosystem
- **Two-stage build process** - npm compiles, Rails optimizes
- **CI/CD must install both** - Ruby gems AND npm packages

This workflow enables you to use modern JavaScript frameworks within Rails' traditional asset management system, providing a bridge between Rails conventions and modern frontend development practices.

---

## 📚 Technology Stack Examples

### Rails Asset Pipeline + Api:: Stacks

```ruby
# Gemfile
gem 'rails'
gem 'jsbundling-rails'  # or 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
```

```json
// package.json
{
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds"
  },
  "dependencies": {
    "vue": "^3.0.0",
    "@vue/compiler-sfc": "^3.0.0"
  }
}
```

### Standalone Frontend + API Stacks

**Frontend (Vue.js)**
```json
{
  "dependencies": {
    "vue": "^3.0.0",
    "vue-router": "^4.0.0",
    "pinia": "^2.0.0",
    "axios": "^1.0.0"
  },
  "devDependencies": {
    "vite": "^4.0.0",
    "@vitejs/plugin-vue": "^4.0.0"
  }
}
```

**API (Rails API)**
```ruby
# Gemfile
gem 'rails', '~> 7.0', api: true
gem 'rack-cors'
gem 'fast_jsonapi'  # or 'jsonapi-serializer'
```

**API (Grape)**
```ruby
# Gemfile
gem 'grape'
gem 'grape-entity'
gem 'rack-cors'
```

---

## 🔍 Real-World Examples

### Successful Rails Asset Pipeline + Api:: Applications
- **GitHub** (initially)
- **Basecamp** (Hey.com)
- **Shopify Admin** (parts)

### Successful Standalone Frontend + API Applications
- **GitLab** (Vue.js frontend + Rails API)
- **Discord** (React frontend + multiple APIs)
- **Airbnb** (React frontend + Rails API)

---

## 📖 Further Reading

- [Rails Asset Pipeline Guide](https://guides.rubyonrails.org/asset_pipeline.html)
- [jsbundling-rails Documentation](https://github.com/rails/jsbundling-rails)
- [Rails API Documentation](https://guides.rubyonrails.org/api_app.html)
- [Grape API Framework](https://github.com/ruby-grape/grape)
- [Vue.js Guide](https://vuejs.org/guide/)
- [React Documentation](https://react.dev/)

---

## 🤝 Contributing

This guide is meant to evolve with the Rails ecosystem. Please contribute your experiences and updated information through pull requests.

---

## ⚖️ License

This guide is released under the MIT License. Use it freely in your projects and share your learnings with the community. 