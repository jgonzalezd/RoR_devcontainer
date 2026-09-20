#!/bin/bash -l
set -o pipefail

# Claude Code (`claude`) and Pi (`pi`) are installed at image build time in
# .devcontainer/Dockerfile, not here. Installing them on attach re-downloaded
# roughly 397 MB on every attach and hid build failures.

# Ensure RVM is loaded and Rails is available
[ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm"
rvm use default
echo "✅ Ruby: $(ruby --version 2>/dev/null || echo 'not found')"

if command -v rails &>/dev/null; then
  echo "✅ Rails: $(rails --version)"
else
  echo "❌ Rails: not found"
  echo "   Rails is installed at image build time (see .devcontainer/Dockerfile)."
  echo "   A missing Rails here usually means a bind mount is hiding the RVM"
  echo "   gem directory that build step installed into, not that the build failed."
  echo "   Fix: rebuild the devcontainer (Dev Containers: Rebuild Container)."
  echo "   This script no longer runs 'gem install rails' automatically:"
  echo "   that hid the real problem and reinstalled on every attach."
fi
