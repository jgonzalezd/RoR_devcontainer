#!/bin/bash -l

echo "🎉 DevContainer created successfully!"
echo ""
echo "Verifying build-time tools..."
echo "✅ Ruby: $(ruby --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Rails: $(rails --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Node.js: $(node --version 2>/dev/null || echo '❌ Not found')"
echo "✅ npm: $(npm --version 2>/dev/null || echo '❌ Not found')"
echo "✅ yarn: $(yarn --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Vue CLI: $(vue --version 2>/dev/null || echo '❌ Not found')"
echo ""
echo "📝 Note: Full environment verification (including PostgreSQL) will run after container starts."

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
