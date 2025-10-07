FROM ubuntu:22.04

# Version Configuration
ARG POSTGRES_VERSION=15
ARG RUBY_VERSION=3.3.7
ARG NODE_VERSION=22
ARG DATABASE_USERNAME=dbuser
ARG DATABASE_PASSWORD=password
ENV POSTGRES_VERSION=${POSTGRES_VERSION}
ENV RUBY_VERSION=${RUBY_VERSION}
ENV NODE_VERSION=${NODE_VERSION}
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

# Configure apt and install packages with specific PostgreSQL version
RUN apt-get -y install --no-install-recommends \
        git \
        curl \
        wget \
        software-properties-common \
        build-essential \
        libssl-dev \
        libreadline-dev \
        zlib1g-dev \
        libsqlite3-dev \
        sqlite3 \
        postgresql-${POSTGRES_VERSION} \
        postgresql-contrib-${POSTGRES_VERSION} \
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

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Add SSH config template
RUN echo "Host github.com\n  IdentityFile ~/.ssh/id_rsa\n  User git\n\nHost *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null" > /home/$USERNAME/.ssh/config \
    && chmod 600 /home/$USERNAME/.ssh/config

# Install NVM and Node.js with proper configuration
ENV NVM_DIR=/home/$USERNAME/.nvm
RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default \
    && npm install -g yarn @vue/cli vite

# Install RVM
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB \
    && curl -sSL https://get.rvm.io | bash -s stable

# Load RVM and install Ruby with Rails
SHELL ["/bin/bash", "-lc"]
RUN source ~/.rvm/scripts/rvm \
    && rvm install ${RUBY_VERSION} \
    && rvm use ${RUBY_VERSION} --default \
    && gem install bundler:2.3.26 rails

# Ensure RVM and Node.js are loaded in the shell environment
ENV PATH="/home/vscode/.rvm/bin:/home/vscode/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

# Setup shell initialization with proper guard against double-loading
# Add NVM and RVM loading to .bashrc for interactive shells
RUN printf '%s\n' \
    '# Load NVM if not already loaded' \
    'if [[ -z "${NVM_DIR:-}" ]]; then' \
    '  export NVM_DIR="$HOME/.nvm"' \
    '  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' \
    '  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' \
    'fi' \
    '' \
    '# Load RVM if not already loaded' \
    'if [[ -z "${rvm_loaded_flag:-}" ]] && [[ -s "$HOME/.rvm/scripts/rvm" ]]; then' \
    '  source "$HOME/.rvm/scripts/rvm"' \
    '  rvm use ${RUBY_VERSION} --default >/dev/null 2>&1' \
    'fi' \
    >> ~/.bashrc

# Ensure login shells load interactive shell config
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.bash_profile

# Switch to root to create system-wide profile hooks
USER root

# Provide system-wide profile hooks for login shells ONLY
# These will load before .bash_profile, which then sources .bashrc
RUN printf '%s\n' \
    '# Load NVM for login shells' \
    'export NVM_DIR="$HOME/.nvm"' \
    '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' \
    > /etc/profile.d/nvm.sh && chmod 644 /etc/profile.d/nvm.sh

RUN printf '%s\n' \
    '# Load RVM for login shells' \
    '[ -s "$HOME/.rvm/scripts/rvm" ] && . "$HOME/.rvm/scripts/rvm"' \
    'rvm use default >/dev/null 2>&1 || true' \
    > /etc/profile.d/rvm.sh && chmod 644 /etc/profile.d/rvm.sh

# Switch back to vscode user for remaining operations
USER vscode

# Removed legacy inline PostgreSQL startup script (now modular in scripts/services)

# Create stop script for graceful shutdown
RUN <<-'EOT' cat > /home/vscode/stop-services.sh && chmod +x /home/vscode/stop-services.sh
#!/bin/bash
echo "🛑 Stopping PostgreSQL..."
sudo -u postgres /usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl -D /var/lib/postgresql-data stop -m fast || true
echo "✅ PostgreSQL stopped"
EOT

# Set up the working directory and create .rvmrc
WORKDIR /workspace
RUN echo "rvm use ${RUBY_VERSION}@\${PWD##*/} --create" > /workspace/.rvmrc && \
    echo "rvm_trust_rvmrcs_flag=1" >> ~/.rvmrc

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Set application database URL and informative version string
ENV DATABASE_URL="postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@localhost:5432/"
ENV POSTGRES_VERSION_INFO="PostgreSQL ${POSTGRES_VERSION}"

# for Rails
# ENV DATABASE_URL="postgresql://postgres:password@localhost:5432" 

# Copy modular startup scripts and set orchestrator as entrypoint
# Switch to root to create system directories
USER root
RUN mkdir -p /usr/local/bin/devcontainer-scripts/services
COPY scripts/start-services.sh /usr/local/bin/devcontainer-scripts/start-services.sh
COPY scripts/services/ /usr/local/bin/devcontainer-scripts/services/
RUN chmod +x /usr/local/bin/devcontainer-scripts/start-services.sh /usr/local/bin/devcontainer-scripts/services/*.sh

# Run entrypoint as root to avoid sudo password prompts
USER root
ENTRYPOINT ["/usr/local/bin/devcontainer-scripts/start-services.sh"]
CMD ["sleep", "infinity"]