FROM ubuntu:22.04

# Version Configuration
ARG POSTGRES_VERSION=15
ARG RAILS_VERSION=7.2.2
ARG DATABASE_USERNAME=dbuser
ARG DATABASE_PASSWORD=password
ENV POSTGRES_VERSION=${POSTGRES_VERSION}
ENV RAILS_VERSION=${RAILS_VERSION}
ENV DATABASE_USERNAME=${DATABASE_USERNAME}
ENV DATABASE_PASSWORD=${DATABASE_PASSWORD}

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Add PostgreSQL official APT repository for specific version control
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog wget ca-certificates gnupg lsb-release 2>&1 \
    && wget -qO /tmp/pg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg /tmp/pg.asc \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update

# Configure apt and install packages with specific PostgreSQL version.
#
# libyaml-dev, libffi-dev, libgdbm-dev, libncurses5-dev, autoconf and bison
# are here for mise's source builds of Ruby. mise ships precompiled arm64
# binaries for some Ruby versions (e.g. 3.3.7) but not others (e.g. 3.2.0,
# which several of this repo's projects pin), and a source compile fails
# without these on top of build-essential/zlib1g-dev/libssl-dev/libreadline-dev.
RUN apt-get -y install --no-install-recommends \
        git \
        curl \
        wget \
        software-properties-common \
        build-essential \
        libssl-dev \
        libreadline-dev \
        zlib1g-dev \
        libyaml-dev \
        libffi-dev \
        libgdbm-dev \
        libncurses5-dev \
        autoconf \
        bison \
        libsqlite3-dev \
        sqlite3 \
        postgresql-client-${POSTGRES_VERSION} \
        libpq-dev \
        python3 \
        python3-pip \
        vim \
        nano \
        sudo \
        openssh-client \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(ALL:ALL\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set database environment variables (ARG-backed) - already defined above; avoid duplication

# Setup SSH directory with correct permissions
RUN mkdir -p /home/$USERNAME/.ssh \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh \
    && chmod 700 /home/$USERNAME/.ssh

# Install a single system Node from NodeSource, used ONLY to host global CLI
# tools: corepack/yarn, the Vue CLI, and the Claude Code / Pi agent CLIs
# below. These four are developer tooling, not project dependencies, so
# coupling them to a project's own Node version (now managed per-repo by
# mise, see below) would be wrong, and re-downloading them on every
# container creation would undo the build-time install this layer gives us.
# NodeSource is used instead of Ubuntu 22.04's own `nodejs` package, which
# ships Node 12 and is far behind what these CLIs expect.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get -y install --no-install-recommends nodejs \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install yarn (via Node's bundled corepack, so the version is managed by Node)
# and the Vue CLI (provides the `vue` command), against the system Node
# installed above. Verify both here so a failure breaks the build instead of
# surfacing later as "Not found".
# COREPACK_HOME must be a shared, world-readable path. corepack's `yarn` is a
# shim that resolves the real yarn package out of this cache at run time. The
# default is $HOME/.cache/node/corepack, and these layers run as root, so the
# cache would land in /root and the build-time `yarn --version` would pass while
# `yarn` failed for the vscode user at run time. This ENV persists into the
# running container, so the shim finds the same cache there.
ENV COREPACK_HOME=/usr/local/share/corepack
RUN mkdir -p "$COREPACK_HOME" \
    && corepack enable \
    && corepack prepare yarn@stable --activate \
    && chmod -R a+rX "$COREPACK_HOME" \
    && npm install -g @vue/cli \
    && yarn --version \
    && vue --version

# Install mise (https://mise.jdx.dev), replacing RVM and NVM. Project Ruby
# and Node versions now come from each repo's own mise config or idiomatic
# version files (.ruby-version, .node-version), so bumping a project's
# version is a file edit, not an image rebuild.
ARG MISE_VERSION=v2026.9.11
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise MISE_VERSION=${MISE_VERSION} sh \
    && mise --version

# System-wide mise settings, so they survive container recreation: only the
# mise-data and bundle-gems volumes below are durable, /home/vscode itself is
# not, so per-user config under ~/.config/mise would vanish with the home
# directory. idiomatic_version_file_enable_tools makes mise honor each
# project's plain .ruby-version / .node-version files, not only mise.toml.
RUN mkdir -p /etc/mise \
    && printf '%s\n' \
    '[settings]' \
    'idiomatic_version_file_enable_tools = ["ruby", "node"]' \
    > /etc/mise/config.toml \
    && chmod 644 /etc/mise/config.toml

# Deliberately NOT installing a Ruby or Node toolchain here with `mise
# install`. postCreateCommand runs `mise install` instead, against the
# mise-data named volume mounted at /home/vscode/.local/share/mise. A named
# volume is seeded from the image's own contents at that path only when the
# volume is empty. If a toolchain were baked into the image at this path AND
# that same path is then volume-mounted, an existing (possibly stale) volume
# shadows whatever this layer installed, and bumping a Ruby/Node version here
# would silently do nothing on a container that already has the volume.
# Installing at postCreate time instead keeps the volume the single source of
# truth for which versions are actually present.

# Install the AI coding agent CLIs: Claude Code (`claude`) and Pi (`pi`).
#
# The two need DIFFERENT npm flags, and getting this wrong fails quietly:
#
#   - @anthropic-ai/claude-code ships a 184 KB npm package and downloads its
#     real native binary in a postinstall script. Installing it with
#     --ignore-scripts "succeeds" and then every run reports
#     "Error: claude native binary not installed". So scripts must stay ON.
#   - @earendil-works/pi-coding-agent is the package name published at
#     https://pi.dev (repo: github.com/earendil-works/pi, MIT). pi.dev's own
#     install instructions specify --ignore-scripts, so that flag is the
#     vendor's guidance here, not a security workaround.
#
# Both are installed at build time rather than on attach, so no container
# start pays the ~397 MB download again.
#
# These two ARGs are declared HERE rather than at the top of the file on
# purpose. An ARG at the top invalidates every layer below it when its value
# changes. Declared here, a version bump rebuilds only this layer and the ones
# after it, leaving the apt, NodeSource and mise layers above it cached.
# "latest" tracks upstream on each rebuild; set an exact version to pin one.
ARG CLAUDE_CODE_VERSION=latest
ARG PI_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION} \
    && claude --version \
    && pi --version

# Pre-create every path that a named volume will later mount over, owned by
# vscode. A named volume seeds from the image's contents at its mount point,
# ownership included, but only while the volume is still empty. A mount point
# that does not exist in the image is created by Docker as root:root instead,
# and then nothing running as vscode can write to it. That applies to mise's
# toolchain directory and to BUNDLE_PATH.
RUN mkdir -p /home/$USERNAME/.local/share/mise \
             /home/$USERNAME/.bundle-gems \
             /home/$USERNAME/.cache/ms-playwright \
    && chown -R $USERNAME:$USERNAME \
             /home/$USERNAME/.local \
             /home/$USERNAME/.bundle-gems \
             /home/$USERNAME/.cache

# .cache/ms-playwright is created here for a second reason beyond the volume
# seeding above. The playwright bind mount targets /home/vscode/.cache/ms-playwright,
# and Docker creates any MISSING PARENT of a mount point as root:root. That
# silently made /home/vscode/.cache root-owned, and mise keeps its own cache at
# ~/.cache/mise, so every `mise install` failed with
# "failed create_dir_all: ~/.cache/mise/lockfiles: Permission denied".

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Add SSH config template
RUN echo "Host github.com\n  IdentityFile ~/.ssh/id_rsa\n  User git\n\nHost *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null" > /home/$USERNAME/.ssh/config \
    && chmod 600 /home/$USERNAME/.ssh/config

# Ensure login shells load interactive shell config
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.bash_profile

# Removed legacy inline PostgreSQL startup script (now modular in scripts/services)

# Set up the working directory. Ruby/Node version selection comes from each
# repo's own idiomatic version files (.ruby-version, .node-version) via mise,
# not from a generated RVM .rvmrc.
WORKDIR /workspace

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# DATABASE_URL is deliberately NOT set here. PostgreSQL runs in its own Compose
# service, so the hostname is `db`, and only compose.yaml knows that. Setting it
# in the image would bake in `localhost`, which is now wrong and would silently
# override the value Compose supplies.
ENV POSTGRES_VERSION_INFO="PostgreSQL ${POSTGRES_VERSION} (Compose service 'db')"

# Copy the PostgreSQL admin tools. Both are network clients now: PostgreSQL runs
# in the `db` Compose service, so nothing in this image starts or stops it.
USER root
RUN mkdir -p /usr/local/bin/devcontainer-scripts
COPY scripts/pg-backup.sh /usr/local/bin/devcontainer-scripts/pg-backup.sh
COPY scripts/pg-maintenance.sh /usr/local/bin/devcontainer-scripts/pg-maintenance.sh
RUN chmod +x /usr/local/bin/devcontainer-scripts/pg-backup.sh \
    /usr/local/bin/devcontainer-scripts/pg-maintenance.sh

# Create the dump target and give it to vscode BEFORE the `pg-dumps` named
# volume is mounted over it. A named volume seeds from the image's contents at
# its mount point, ownership included, but only while the volume is empty. If
# this directory did not exist in the image, Docker would create the mount
# point as root:root and pg-backup.sh, which runs as vscode, could not write
# a dump into it.
RUN mkdir -p /var/lib/postgresql-dumps \
    && chown vscode:vscode /var/lib/postgresql-dumps

# No ENTRYPOINT. The previous one ran start-services.sh as PID 1 to boot
# PostgreSQL inside this container. It ran under `set -e`, so any failing
# service killed the container before a single lifecycle hook could run, which
# is how a broken database presented as a broken devcontainer. PostgreSQL is now
# PID 1 in its own container, where Docker's SIGTERM reaches the postmaster
# directly and triggers a clean shutdown. compose.yaml supplies
# `command: sleep infinity` for this container.
USER vscode
