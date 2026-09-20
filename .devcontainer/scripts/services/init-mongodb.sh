#!/bin/bash
set -e

echo "🔧 [MongoDB] Initialization stub"

if ! command -v mongod >/dev/null 2>&1; then
    echo "ℹ️  [MongoDB] mongod not installed in this image. Skipping."
    exit 0
fi

echo "➡️  [MongoDB] Detected mongod, but no setup defined yet. Skipping."
exit 0


