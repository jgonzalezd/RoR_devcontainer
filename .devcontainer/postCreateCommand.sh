#!/bin/bash -l
set -o pipefail

echo "🎉 DevContainer created successfully!"
echo ""
echo "Verifying build-time tools..."

MISSING_TOOLS=()

# Runs a version command and prints a check mark on success or a cross mark
# on failure. Does not exit non-zero on a missing tool: postCreateCommand
# must always succeed so the container comes up and can be debugged.
check_tool() {
  local name="$1"
  shift
  local version_output
  if version_output="$("$@" 2>/dev/null)"; then
    echo "✅ $name: $version_output"
  else
    echo "❌ $name: not found"
    MISSING_TOOLS+=("$name")
  fi
}

check_tool "Ruby" ruby --version
check_tool "Rails" rails --version
check_tool "Node.js" node --version
check_tool "npm" npm --version
check_tool "yarn" yarn --version
check_tool "Vue CLI" vue --version
check_tool "Claude Code" claude --version
check_tool "Pi" pi --version

echo ""
if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
  echo "⚠️  Missing tools: ${MISSING_TOOLS[*]}"
else
  echo "✅ All build-time tools found."
fi

echo ""
echo "📝 Note: Full environment verification (including PostgreSQL) will run after container starts."

# Add aliases and custom configurations only if not already present
if ! grep -q "parse_git_branch" ~/.bashrc 2>/dev/null; then
  echo "alias ra=./bin/dev" >> ~/.bashrc
  echo "alias rs='./bin/rails server'" >> ~/.bashrc 

  # Append custom terminal configurations to .bashrc
  cat << 'EOF' >> ~/.bashrc
# Custom PS1 prompt with Git branch and colors
parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\e[33m\]\W\[\e[m\]\[\e[36m\]$(parse_git_branch)\[\e[m\] \$ '

# Git aliases for common commands
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'
alias gd='git diff'
alias gl='git log --oneline --graph --all'

# Terminal enhancement aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
alias h='history'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
EOF
else
  echo "Custom bash configurations already present in ~/.bashrc, skipping..."
fi
