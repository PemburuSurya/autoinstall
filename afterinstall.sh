#!/bin/bash
set -euo pipefail  # More strict error handling

# ==========================================
# Configuration Variables
# ==========================================
GO_VERSION="1.24.2"
GO_ARCH="linux-amd64"
DOCKER_COMPOSE_VERSION="v2.20.2"
USERNAME=$(whoami)  # Get current username

# ==========================================
# Utility Functions
# ==========================================
function info() {
    echo -e "\033[1;32m[INFO] $1\033[0m"
}

function warn() {
    echo -e "\033[1;33m[WARN] $1\033[0m"
}

function error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
    exit 1
}

function install_packages() {
    info "Installing packages: $*"
    if ! sudo apt install -y "$@"; then
        error "Failed to install packages: $*"
    fi
}

# ==========================================
# System Update
# ==========================================
info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# ==========================================
# Install Essential Packages
# ==========================================
info "Installing essential build tools..."
install_packages \
    git clang cmake build-essential openssl pkg-config libssl-dev \
    wget htop tmux jq make gcc tar ncdu protobuf-compiler \
    default-jdk aptitude squid apache2-utils file lsof \
    iptables iptables-persistent openssh-server sed lz4 aria2 pv \
    python3 python3-venv python3-pip python3-dev screen snapd flatpak \
    nano automake autoconf nvme-cli libgbm1 libleveldb-dev bsdmainutils unzip

# ==========================================
# Docker Installation
# ==========================================
info "Setting up Docker..."
install_packages \
    apt-transport-https ca-certificates curl software-properties-common lsb-release gnupg2

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
install_packages docker-ce docker-ce-cli containerd.io

# ==========================================
# Docker Compose Installation
# ==========================================
info "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install as Docker CLI plugin
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

# ==========================================
# User Configuration
# ==========================================
info "Configuring user groups..."
sudo groupadd -f docker
for user in $USERNAME rumiyah hosting; do
    if id "$user" &>/dev/null; then
        sudo usermod -aG docker "$user"
    fi
done

# ==========================================
# Development Tools
# ==========================================
info "Installing development tools..."

# Visual Studio Code
sudo snap install code --classic

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# OpenJDK
sudo add-apt-repository ppa:openjdk-r/ppa -y
sudo apt update
install_packages openjdk-11-jdk

# ==========================================
# Go Installation (Improved)
# ==========================================
info "Installing Go ${GO_VERSION}..."
GO_TAR_FILE="go${GO_VERSION}.${GO_ARCH}.tar.gz"
curl -OL "https://go.dev/dl/${GO_TAR_FILE}"

# Verify the download is a valid tar.gz file
if tar -tzf "$GO_TAR_FILE" >/dev/null 2>&1; then
    sudo tar -C /usr/local -xzf "$GO_TAR_FILE"
    rm "$GO_TAR_FILE"
    
    # Add to PATH
    export PATH=$PATH:/usr/local/go/bin
    grep -qxF 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc || echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    
    # Verify
    if ! command -v go &> /dev/null; then
        error "Go installation failed"
    else
        info "Go installed: $(go version)"
    fi
else
    error "Invalid Go download (file is not a valid tar.gz archive)"
fi

# ==========================================
# Rust Installation (Improved)
# ==========================================
info "Installing Rust..."
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"

# Install Rust non-interactively
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# Add to PATH in a way that works for all shells
{
    echo 'export CARGO_HOME="$HOME/.cargo"'
    echo 'export RUSTUP_HOME="$HOME/.rustup"'
    echo 'export PATH="$CARGO_HOME/bin:$PATH"'
} >> ~/.bashrc

# Source the environment immediately
source "$CARGO_HOME/env"

# ==========================================
# Node.js Installation
# ==========================================
info "Cleaning up any existing Node.js/npm installations..."
sudo apt remove --purge nodejs npm -y || warn "No existing Node.js to remove"
sudo rm -rf /etc/apt/sources.list.d/nodesource.list
sudo rm -rf /usr/lib/node_modules
sudo rm -rf ~/.npm
sudo apt autoremove -y

info "Installing Node.js 22.x from NodeSource..."
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
info "Verifying Node.js installation..."
NODE_VERSION=$(node -v)
if [ -z "$NODE_VERSION" ]; then
    error "Node.js installation failed"
else
    info "Node.js ${NODE_VERSION} installed successfully"
fi

# ==========================================
# npm Configuration
# ==========================================
info "Configuring npm..."
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

# Add to PATH if not already present
if ! grep -q "npm-global" ~/.bashrc; then
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
fi

# Update npm to latest version
info "Updating npm to latest version..."
npm install -g npm@latest

# ==========================================
# Yarn Installation
# ==========================================
info "Installing Yarn..."
npm install -g yarn

# Verify Yarn installation
info "Verifying Yarn installation..."
YARN_VERSION=$(yarn -v)
if [ -z "$YARN_VERSION" ]; then
    warn "Yarn installation via npm failed, trying alternative method..."
    
    # Alternative installation method
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update
    sudo apt-get install -y yarn
    
    YARN_VERSION=$(yarn -v)
    if [ -z "$YARN_VERSION" ]; then
        error "Yarn installation failed completely"
    fi
fi

info "Yarn ${YARN_VERSION} installed successfully"

# ==========================================
# Final Configuration: Fix PS1 error
# ==========================================
info "Fixing PS1 error in .bashrc..."
# Ensure PS1 is only set if not already set
if ! grep -q 'PS1' ~/.bashrc; then
    echo 'if [ -z "${PS1+x}" ]; then PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "; fi' >> ~/.bashrc
fi

# Reload .bashrc to apply changes
source ~/.bashrc

# ==========================================
# Completion Message
# ==========================================
cat <<EOF
================================================
INSTALLATION COMPLETE!
- System updated and essential packages installed
- Docker and Docker Compose ${DOCKER_COMPOSE_VERSION} installed
- Development tools (Go ${GO_VERSION}, Rust, Node.js, etc.) installed
- Node.js $NODE_VERSION installed
- Yarn $YARN_VERSION installed
- Visual Studio Code installed via Snap
================================================

IMPORTANT NEXT STEPS:
1. Run this command or restart your shell to apply changes:
   source ~/.bashrc

2. Verify Rust installation:
   rustc --version
   cargo --version

3. For Docker to work without sudo, you may need to log out and back in.

4. Verify Go installation:
   go version
   
5. Other Verification commands:
node -v
yarn -v
npm -v
EOF
