#!/bin/bash -l

# echo "Installing Claude Code CLI and MCPs..."
# npm install -g @anthropic-ai/claude-code
# npm install -g task-master-ai@latest
# npm install -g bats
# claude mcp add taskmaster "$(which task-master-ai)" || true
# claude mcp add --transport sse context7 https://mcp.context7.com/sse || true
# echo "Claude Code CLI: $(claude --version 2>/dev/null || echo "not installed")"

# Ensure RVM is loaded and Rails is available
[ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm"
rvm use default
echo "✅ Ruby: $(ruby --version 2>/dev/null || echo 'not found')"
echo "✅ Rails: $(rails --version 2>/dev/null || echo 'not found, installing...')"

# Install Rails if not already installed
if ! command -v rails &>/dev/null; then
  echo "📦 Installing Rails..."
  gem install rails
  echo "✅ Rails installed: $(rails --version)"
fi
