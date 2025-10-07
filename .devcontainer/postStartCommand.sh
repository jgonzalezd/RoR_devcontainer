#!/bin/bash -l

echo "📊 Container started. PostgreSQL data persisted at .DB_data/"
echo ""

# Run full environment verification
echo ""
/workspace/verify-environment.sh
