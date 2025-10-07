#!/bin/bash

# Script to add dotfiles to new Rails projects
# Usage: ./add_dot_files.sh <project_name_or_path>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <project_name_or_path>"
    exit 1
fi

INPUT=$1

# Check if the input is a full path or just a project name
if [[ "$INPUT" == *"/"* ]]; then
    PROJECT_DIR="$INPUT"
    PROJECT_NAME=$(basename "$INPUT")
else
    PROJECT_DIR="/workspace/projects_own/$INPUT"
    PROJECT_NAME="$INPUT"
fi

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory $PROJECT_DIR does not exist."
    exit 1
fi

# Detect current Ruby version
RUBY_VERSION=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
if [ -z "$RUBY_VERSION" ]; then
    echo "Could not detect Ruby version. Using default 3.3.7"
    RUBY_VERSION="3.3.7"
fi

echo "Using Ruby version: $RUBY_VERSION"

# Navigate to the project directory
cd "$PROJECT_DIR"

# Remove existing Gemfile and create new one
rm -f Gemfile Gemfile.lock
bundle init

# Create .ruby-version file
echo "$RUBY_VERSION" > .ruby-version

# Create .ruby-gemset file (for RVM)
echo "$PROJECT_NAME" > .ruby-gemset

# Create .rvmrc file (alternative RVM config)
echo "rvm use $RUBY_VERSION@$PROJECT_NAME --create" > .rvmrc

echo "Dotfiles added to $PROJECT_NAME successfully."
