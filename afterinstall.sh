#!/bin/bash
set -euo pipefail  # More strict error handling

# ==========================================
# Configuration Variables
# ==========================================
GO_VERSION="1.22.4"
GO_ARCH="linux-amd64"
DOCKER_COMPOSE_VERSION="v2.20.2"
USERNAME=$(whoami)  # Get current username

# ==========================================
# Utility Functions
# ==========================================
function info() {
    echo -e "\033[1;32m[INFO] $1\033[0m"
}

function error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
    exit 1
}

function install_packages() {
    info "Installing packages: $*"
    sudo apt install -y "$@"
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
    npm nodejs default-jdk aptitude squid apache2-utils \
    iptables iptables-persistent openssh-server sed lz4 aria2 pv \
    python3 python3-venv python3-pip screen snapd flatpak

# ==========================================
# Docker Installation
# ==========================================
info "Setting up Docker..."
install_packages \
    apt-transport-https ca-certificates curl software-properties-common

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
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# ==========================================
# User Configuration
# ==========================================
info "Configuring user groups..."
sudo groupadd -f docker
for user in $USERNAME ubuntu hosting; do
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

# Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
install_packages yarn

# ==========================================
# Go Installation
# ==========================================
info "Installing Go ${GO_VERSION}..."
curl -OL "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"

if file "go${GO_VERSION}.${GO_ARCH}.tar.gz" | grep -q "gzip compressed data"; then
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.${GO_ARCH}.tar.gz"
    rm "go${GO_VERSION}.${GO_ARCH}.tar.gz"
    
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
    error "Invalid Go download"
fi

# ==========================================
# Rust Installation
# ==========================================
info "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
grep -qxF 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# ==========================================
# Final Configuration
# ==========================================
info "Final system configuration..."
sudo systemctl enable --now netfilter-persistent

# ==========================================
# Completion Message
# ==========================================
cat <<EOF

================================================
INSTALLATION COMPLETE!
- System updated and essential packages installed
- Docker and Docker Compose ${DOCKER_COMPOSE_VERSION} installed
- Development tools (Go ${GO_VERSION}, Rust, Node.js, etc.) installed
- Visual Studio Code installed via Snap
================================================

You may need to log out and back in for group changes to take effect.
EOF
