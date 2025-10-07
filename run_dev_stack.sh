#!/bin/bash

# Rails + Vue.js Development Stack Bootstrap Script
# Usage: ./run_dev_stack.sh <project_directory>
# Example: ./run_dev_stack.sh quick_wins

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables for process management
NPM_WATCH_PID=""
RAILS_PID=""
PROJECT_DIR=""

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}================================"
    echo -e "$1"
    echo -e "================================${NC}\n"
}

# Cleanup function - called on script exit
cleanup() {
    print_header "🧹 CLEANING UP DEVELOPMENT PROCESSES"
    
    if [ ! -z "$NPM_WATCH_PID" ]; then
        print_status "Stopping npm build:watch (PID: $NPM_WATCH_PID)"
        kill $NPM_WATCH_PID 2>/dev/null || true
        wait $NPM_WATCH_PID 2>/dev/null || true
        print_success "npm build:watch stopped"
    fi
    
    if [ ! -z "$RAILS_PID" ]; then
        print_status "Stopping Rails server (PID: $RAILS_PID)"
        kill $RAILS_PID 2>/dev/null || true
        wait $RAILS_PID 2>/dev/null || true
        print_success "Rails server stopped"
    fi
    
    # Kill any remaining npm/node processes for this project
    if [ ! -z "$PROJECT_DIR" ]; then
        print_status "Cleaning up any remaining build processes..."
        
        # Find and kill processes by working directory
        CLEANUP_NPM=$(pgrep -f "npm.*build" 2>/dev/null | while read pid; do
            if [ "$(pwdx $pid 2>/dev/null | grep "$PROJECT_DIR")" ]; then
                echo $pid
            fi
        done)
        CLEANUP_NODE=$(pgrep -f "node.*esbuild" 2>/dev/null | while read pid; do
            if [ "$(pwdx $pid 2>/dev/null | grep "$PROJECT_DIR")" ]; then
                echo $pid
            fi
        done)
        
        if [ ! -z "$CLEANUP_NPM" ]; then
            print_status "Killing remaining npm processes: $CLEANUP_NPM"
            kill -TERM $CLEANUP_NPM 2>/dev/null || true
            sleep 1
            kill -9 $CLEANUP_NPM 2>/dev/null || true
        fi
        
        if [ ! -z "$CLEANUP_NODE" ]; then
            print_status "Killing remaining node processes: $CLEANUP_NODE"
            kill -TERM $CLEANUP_NODE 2>/dev/null || true
            sleep 1
            kill -9 $CLEANUP_NODE 2>/dev/null || true
        fi
    fi
    
    print_success "✅ All development processes cleaned up!"
    print_status "💾 PostgreSQL database left running for future use"
    print_status "🔍 If you experienced issues, check JAVASCRIPT_DEBUGGING_GUIDE.md in the root folder"
    echo
}

# Set trap for cleanup on script exit
trap cleanup EXIT INT TERM

# Validate parameters
if [ $# -eq 0 ]; then
    print_error "Usage: $0 <project_directory>"
    print_error "Example: $0 quick_wins"
    exit 1
fi

PROJECT_DIR="$1"

print_header "🚀 RAILS + VUE.JS DEVELOPMENT STACK"
print_status "Project: $PROJECT_DIR"
print_status "Timestamp: $(date)"

# Validate project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Project directory '$PROJECT_DIR' does not exist!"
    exit 1
fi

cd "$PROJECT_DIR"
print_success "Changed to project directory: $(pwd)"

# Check if this looks like a Rails project
if [ ! -f "Gemfile" ] || [ ! -f "config/application.rb" ]; then
    print_error "This doesn't appear to be a Rails project!"
    print_error "Missing Gemfile or config/application.rb"
    exit 1
fi

# Check if this has Vue.js setup
if [ ! -f "package.json" ] || [ ! -d "app/javascript" ]; then
    print_error "This doesn't appear to have Vue.js setup!"
    print_error "Missing package.json or app/javascript directory"
    exit 1
fi

print_header "🗃️ DATABASE SETUP"

# Check PostgreSQL service
print_status "Checking PostgreSQL service status..."
if ! pgrep -x postgres >/dev/null 2>&1; then
    print_warning "PostgreSQL is not running. Starting PostgreSQL..."
    sudo service postgresql start
    sleep 3
    
    if pgrep -x postgres >/dev/null 2>&1; then
        print_success "PostgreSQL started successfully"
    else
        print_error "Failed to start PostgreSQL"
        exit 1
    fi
else
    print_success "PostgreSQL is already running"
fi

# Test database connection
print_status "Testing database connection..."
if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
    print_success "Database connection successful"
else
    print_error "Cannot connect to PostgreSQL database"
    exit 1
fi

print_header "💎 RUBY DEPENDENCIES"

# Check if gems are actually installed and up to date
print_status "Checking Ruby gem dependencies..."
if bundle check >/dev/null 2>&1; then
    print_success "Ruby gems are up to date"
else
    print_status "Installing/updating Ruby gems..."
    bundle install
    print_success "Ruby gems installed"
fi

print_header "🗃️ DATABASE MIGRATION"

# Check if database exists and run migrations
print_status "Setting up database..."
if bundle exec rails db:version >/dev/null 2>&1; then
    print_status "Database exists, checking for pending migrations..."
    bundle exec rails db:migrate
else
    print_status "Database doesn't exist, creating and setting up..."
    bundle exec rails db:create
    bundle exec rails db:migrate
fi
print_success "Database is ready"

print_header "📦 NODE.JS DEPENDENCIES"

# Check if Node.js packages are actually installed and up to date
print_status "Checking Node.js package dependencies..."
if [ -d "node_modules" ] && npm list --depth=0 >/dev/null 2>&1; then
    print_success "Node.js packages are up to date"
else
    print_status "Installing/updating Node.js packages..."
    npm install
    print_success "Node.js packages installed"
fi

print_header "🏗️ FRONTEND BUILD SETUP"

# Clear Rails cache to prevent asset pipeline issues
print_status "Clearing Rails cache and temporary files..."
bundle exec rails tmp:clear >/dev/null 2>&1
rm -rf tmp/cache/ 2>/dev/null || true
print_success "Rails cache cleared"

# Clean up any existing build artifacts to ensure fresh build
print_status "Cleaning existing build artifacts..."
rm -rf app/assets/builds/* 2>/dev/null || true
rm -f .esbuild-* 2>/dev/null || true
rm -rf node_modules/.cache/esbuild/* 2>/dev/null || true
print_success "Build artifacts cleaned"

# Verify manifest.js includes builds directory
if ! grep -q "link_tree ../builds" app/assets/config/manifest.js 2>/dev/null; then
    print_warning "Rails asset manifest missing builds directory"
    print_status "Adding //= link_tree ../builds to manifest.js"
    echo "//= link_tree ../builds" >> app/assets/config/manifest.js
    print_success "Asset manifest updated"
fi

# Build frontend assets
print_status "Building frontend assets..."
npm run build

# Verify assets were built successfully
if [ ! -f "app/assets/builds/application.js" ]; then
    print_error "Frontend build failed - application.js not found!"
    print_error "Check for build errors in the output above"
    exit 1
fi

# Check if asset file has content (not empty)
ASSET_SIZE=$(stat -f%z "app/assets/builds/application.js" 2>/dev/null || stat -c%s "app/assets/builds/application.js" 2>/dev/null || echo "0")
if [ "$ASSET_SIZE" -eq 0 ]; then
    print_error "Frontend build produced empty application.js file!"
    print_error "This usually indicates a build configuration issue"
    exit 1
fi

print_success "Frontend assets built successfully (${ASSET_SIZE} bytes)"

# Test asset serving capability 
print_status "Verifying asset pipeline configuration..."
if bundle exec rails assets:precompile --trace >/dev/null 2>&1; then
    print_success "Asset pipeline configuration verified"
else
    print_warning "Asset precompilation failed, but continuing..."
    print_warning "You may need to run 'rails assets:precompile' manually if assets don't load"
fi

print_header "🎯 STARTING DEVELOPMENT SERVICES"

# Check for existing npm build processes and stop them
print_status "Checking for existing build processes..."
# Check for npm build processes in this directory by using cwd
EXISTING_NPM_PIDS=$(pgrep -f "npm.*build" 2>/dev/null | while read pid; do
    if [ "$(pwdx $pid 2>/dev/null | grep "$(pwd)")" ]; then
        echo $pid
    fi
done)
# Also check for node esbuild processes in this directory 
EXISTING_NODE_PIDS=$(pgrep -f "node.*esbuild" 2>/dev/null | while read pid; do
    if [ "$(pwdx $pid 2>/dev/null | grep "$(pwd)")" ]; then
        echo $pid
    fi
done)

if [ ! -z "$EXISTING_NPM_PIDS" ] || [ ! -z "$EXISTING_NODE_PIDS" ]; then
    print_warning "Found existing build processes. Stopping them..."
    
    if [ ! -z "$EXISTING_NPM_PIDS" ]; then
        for pid in $EXISTING_NPM_PIDS; do
            print_status "Stopping npm process (PID: $pid)"
            kill $pid 2>/dev/null || true
        done
    fi
    
    if [ ! -z "$EXISTING_NODE_PIDS" ]; then
        for pid in $EXISTING_NODE_PIDS; do
            print_status "Stopping node/esbuild process (PID: $pid)"
            kill $pid 2>/dev/null || true
        done
    fi
    
    # Wait for processes to stop
    sleep 3
    
    # Verify processes are actually stopped
    REMAINING_NPM=$(pgrep -f "npm.*build.*$(basename $(pwd))" 2>/dev/null || true)
    REMAINING_NODE=$(pgrep -f "node.*esbuild.*$(basename $(pwd))" 2>/dev/null || true)
    
    if [ ! -z "$REMAINING_NPM" ] || [ ! -z "$REMAINING_NODE" ]; then
        print_warning "Some processes still running. Force killing..."
        [ ! -z "$REMAINING_NPM" ] && kill -9 $REMAINING_NPM 2>/dev/null || true
        [ ! -z "$REMAINING_NODE" ] && kill -9 $REMAINING_NODE 2>/dev/null || true
        sleep 1
    fi
    
    print_success "Existing build processes stopped"
else
    print_success "No existing build processes found"
fi

# Clean up any potential lock files or temporary build artifacts
print_status "Cleaning up remaining build artifacts..."
rm -f .esbuild-* 2>/dev/null || true

# Check for existing Rails server and stop it
if [ -f "tmp/pids/server.pid" ]; then
    EXISTING_PID=$(cat tmp/pids/server.pid 2>/dev/null)
    if [ ! -z "$EXISTING_PID" ] && kill -0 $EXISTING_PID 2>/dev/null; then
        print_warning "Existing Rails server found (PID: $EXISTING_PID). Stopping it..."
        kill $EXISTING_PID 2>/dev/null || true
        sleep 2
        rm -f tmp/pids/server.pid
        print_success "Existing Rails server stopped"
    else
        # Remove stale pid file
        rm -f tmp/pids/server.pid
    fi
fi

print_status "Starting npm build:watch in background..."
npm run build:watch &
NPM_WATCH_PID=$!
print_success "npm build:watch started (PID: $NPM_WATCH_PID)"

# Give npm build a moment to start
sleep 2

print_status "Starting Rails development server..."

# Start Rails server in background first
bundle exec rails server &
RAILS_PID=$!

# Wait for Rails server to start up
print_status "Waiting for Rails server to start up..."
sleep 5

# Test asset serving by checking actual content delivery (not headers)
print_status "Testing asset serving..."
ACTUAL_CONTENT_SIZE=$(curl -s http://localhost:3000/assets/application.js 2>/dev/null | wc -c || echo "0")

if [ "$ACTUAL_CONTENT_SIZE" -lt 10000 ]; then
    print_warning "Assets may not be serving correctly (only $ACTUAL_CONTENT_SIZE bytes received)!"
    print_status "Running emergency asset precompilation..."
    bundle exec rails assets:precompile
    
    # Test again after precompilation
    sleep 2
    ACTUAL_CONTENT_SIZE_RETRY=$(curl -s http://localhost:3000/assets/application.js 2>/dev/null | wc -c || echo "0")
    
    if [ "$ACTUAL_CONTENT_SIZE_RETRY" -lt 10000 ]; then
        print_error "Asset serving still failing after precompilation!"
        print_error "Manual intervention required - check asset pipeline configuration"
        print_error "Try: rails assets:precompile && rails server"
    else
        print_success "Assets now serving correctly ($ACTUAL_CONTENT_SIZE_RETRY bytes delivered)"
    fi
else
    print_success "Assets serving correctly ($ACTUAL_CONTENT_SIZE bytes delivered)"
fi

print_success "🌟 Development stack is ready!"
echo
print_status "📱 Application will be available at: http://localhost:3000"
print_status "🔧 Frontend builds automatically on file changes"
print_status "🛑 Press Ctrl+C to stop all services"
print_status "📊 Check Rails logs to verify Vue.js API calls (proves frontend is working)"
echo

# Wait for Rails server and handle its exit
wait $RAILS_PID 