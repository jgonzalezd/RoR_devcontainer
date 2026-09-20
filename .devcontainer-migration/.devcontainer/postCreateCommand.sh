#!/bin/bash -l
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

echo "🎉 DevContainer created successfully!"
echo ""

# --- Toolchain bootstrap -----------------------------------------------------
# Ruby and Node are NOT baked into the image. They are installed here, into the
# mise-data named volume, from the versions declared in /workspace/mise.toml.
# The image deliberately ships no toolchain: a named volume seeds from the image
# only while it is empty, so a baked-in Ruby plus a mounted mise-data volume
# would let a stale volume shadow the image, and version bumps would silently do
# nothing.
#
# `mise trust` is required before mise will read a project-level mise.toml.
# Without it mise reports "Config files are not trusted" and resolves nothing.
if [ -f /workspace/mise.toml ]; then
  echo "Trusting and installing toolchains from mise.toml..."
  mise trust /workspace/mise.toml
  mise install
  # Regenerate the shims after installing. `mise exec -- <cmd>` resolves a tool
  # without a shim, but a bare `ruby` on PATH needs one, and on a first install
  # into an empty mise-data volume the shim may not be in place yet. That split
  # produced a run where `gem install` succeeded and the verification that
  # followed still reported "Ruby: not found". reshim is idempotent and cheap.
  mise reshim
else
  echo "⚠️  /workspace/mise.toml not found; skipping toolchain install."
fi

# bundler is installed WITHOUT a version pin. The previous image ran
# `gem install bundler:2.3.26`, but `bundle --version` reported 2.5.22, so the
# pinned gem was installed and then never used. Bundler resolves its own version
# from each project's Gemfile.lock, which is the mechanism that should decide it.
# The rails pin stays: RAILS_VERSION controls what `rails new` scaffolds.
echo "Installing bundler and Rails ${RAILS_VERSION}..."
mise exec -- gem install bundler "rails:${RAILS_VERSION}" --no-document

# This assertion deliberately does NOT exit non-zero, unlike the version in the
# migration plan. devcontainer.json sets waitFor: postCreateCommand, so a
# non-zero exit here blocks attach completely, and a broken Rails install is
# exactly when you need a shell to debug from.
if ! mise exec -- rails --version >/dev/null 2>&1; then
  echo "❌ Rails did not install. Run 'mise exec -- gem install rails:${RAILS_VERSION}' after attaching."
fi

echo ""
echo "Verifying build-time tools..."

MISSING_TOOLS=()

# check_tool and DEV_TOOLS come from lib/common.sh. This script must always
# exit 0 even when tools are missing: devcontainer.json sets
# waitFor: postCreateCommand, so a non-zero exit here would block attach
# entirely, and the user needs to attach in order to debug a missing tool.
# Do not "fix" this to exit non-zero on MISSING_TOOLS — that would lock the
# user out of the container they need to fix it from.
for entry in "${DEV_TOOLS[@]}"; do
  name="${entry%%|*}"
  cmd="${entry#*|}"
  if ! check_tool "$name" $cmd; then
    MISSING_TOOLS+=("$name")
  fi
done

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
