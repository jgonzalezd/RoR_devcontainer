#!/bin/bash
set -e

echo "🔧 Starting service initialization orchestration..."

SCRIPTS_ROOT="/usr/local/bin/devcontainer-scripts"
SERVICES_DIR="$SCRIPTS_ROOT/services"

# Ensure services directory exists (it will after COPY in Dockerfile)
if [ ! -d "$SERVICES_DIR" ]; then
    echo "ℹ️  No services directory found at $SERVICES_DIR. Skipping service initialization."
else
    # Execute all service init scripts in lexical order, respecting DISABLED_SERVICES
    for service_script in "$SERVICES_DIR"/*.sh; do
        service_name=$(basename "$service_script" .sh | sed 's/^init-//')
        if [[ ",${DISABLED_SERVICES}," == *",${service_name},"* ]]; then
            echo "⚪️ [Orchestrator] Skipping disabled service: ${service_name}"
            continue
        fi

        if [ -f "$service_script" ]; then
            echo "➡️  Running $(basename "$service_script")"
            bash "$service_script"
            echo "✅ Completed $(basename "$service_script")"
        fi
    done
fi

echo "✅ Service initialization orchestration complete"

# If no arguments provided, keep container running
if [ $# -eq 0 ]; then
    echo "🔧 No command provided, keeping container alive..."
    exec sleep infinity
else
    # Continue with the provided command
    exec "$@"
fi


