#!/bin/bash
set -e  # Exit immediately if any command fails
exec > >(tee install.log) 2>&1  # Log all output

# Constants
GO_VERSION="1.22.4"
DOCKER_COMPOSE_VERSION="v2.24.5"
ANACONDA_VERSION="2023.09-0"

# Header
echo "================================================"
echo "⚙️  Comprehensive System Setup Script"
echo "================================================"
echo "📅 Started at: $(date)"
echo "💻 System: $(uname -a)"
echo "================================================"

# Initial checks
check_dependencies() {
    echo "🔍 Performing pre-flight checks..."
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ Please run as root or with sudo"
        exit 1
    fi

    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        echo "❌ No internet connection detected"
        exit 1
    fi

    # Detect primary network interface
    DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}')
    if [ -z "$DEFAULT_IFACE" ]; then
        echo "❌ Could not detect primary network interface"
        exit 1
    fi
    echo "✔️ Detected primary interface: $DEFAULT_IFACE"
}

# System updates
system_update() {
    echo "🔄 Updating and upgrading system..."
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --with-new-pkgs
    apt-get install -y \
        git clang cmake build-essential openssl pkg-config libssl-dev \
        apt-transport-https ca-certificates curl software-properties-common \
        snapd wget htop tmux jq make gcc tar ncdu protobuf-compiler \
        nodejs flatpak default-jdk aptitude squid apache2-utils \
        iptables iptables-persistent openssh-server jq sed lz4 aria2 pv
}

# Docker installation
install_docker() {
    echo "🐳 Installing Docker..."
    
    # Add Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Install Docker Compose V2
    echo "🐳 Installing Docker Compose $DOCKER_COMPOSE_VERSION..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
        -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

    # Add user to docker group
    usermod -aG docker $USER
    echo "✔️ Docker installed. Note: You may need to logout/login for group changes to take effect."
}

# Go installation
install_go() {
    echo "🐹 Installing Go $GO_VERSION..."
    
    GO_ARCH="linux-amd64"
    GO_URL="https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"
    
    echo "⬇️ Downloading Go..."
    curl -OL $GO_URL
    
    # Verify download
    EXPECTED_SIZE="148MB"  # Adjust for specific version
    ACTUAL_SIZE=$(du -h go$GO_VERSION.$GO_ARCH.tar.gz | awk '{print $1}')
    if [ "$ACTUAL_SIZE" != "$EXPECTED_SIZE" ]; then
        echo "❌ Download size mismatch! Expected $EXPECTED_SIZE, got $ACTUAL_SIZE"
        exit 1
    fi

    echo "📦 Extracting Go..."
    rm -rf /usr/local/go && tar -C /usr/local -xzf go$GO_VERSION.$GO_ARCH.tar.gz
    
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    source /etc/profile
    
    echo "✔️ Go installed: $(go version)"
}

# Rust installation
install_rust() {
    echo "🦀 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo "✔️ Rust installed: $(rustc --version)"
}

# Anaconda installation
install_anaconda() {
    echo "🐍 Installing Anaconda..."
    
    ANACONDA_URL="https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh"
    INSTALL_DIR="$HOME/anaconda3"
    
    echo "⬇️ Downloading Anaconda..."
    curl $ANACONDA_URL --output anaconda.sh
    
    echo "🔒 Verifying installer..."
    ACTUAL_SIZE=$(du -h anaconda.sh | awk '{print $1}')
    if [ "$ACTUAL_SIZE" != "1.1G" ]; then  # Adjust for version
        echo "❌ Download size mismatch! Expected ~1.1GB, got $ACTUAL_SIZE"
        exit 1
    fi

    echo "🚀 Installing Anaconda..."
    bash anaconda.sh -b -p $INSTALL_DIR
    rm anaconda.sh
    
    # Initialize conda
    eval "$($INSTALL_DIR/bin/conda shell.bash hook)"
    conda init
    source ~/.bashrc
    
    echo "🆙 Updating conda..."
    conda update -n base -c defaults conda -y
    
    echo "🧑‍🔧 Creating Python environment..."
    conda create -n myenv python=3.9 -y
    
    echo "✔️ Anaconda installed: $(conda --version)"
    echo "   Virtual environment 'myenv' created"
}

# System configuration
configure_system() {
    echo "⚙️ Configuring system settings..."
    
    # IP Forwarding
    echo "🔧 Enabling IP forwarding..."
    cat <<EOF | tee -a /etc/sysctl.conf
net.ipv4.ip_forward=1
vm.overcommit_memory=1
EOF
    sysctl -p

    # X11 Forwarding
    echo "🖥️ Configuring X11 Forwarding..."
    sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
    sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
    sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config
    
    # Install xauth if missing
    if ! command -v xauth &> /dev/null; then
        apt-get install -y xauth
    fi

    # Firewall Configuration
    echo "🔥 Configuring firewall..."
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -A POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
    iptables -A INPUT -p tcp --dport 6000:6007 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 6000:6007 -j ACCEPT
    
    # Save iptables rules
    netfilter-persistent save
    systemctl enable netfilter-persistent
    
    # Restart services
    systemctl restart ssh
}

# Install additional tools
install_tools() {
    echo "� Installing additional tools..."
    
    # Visual Studio Code
    snap install code --classic
    
    # Flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # OpenJDK
    add-apt-repository ppa:openjdk-r/ppa -y
    apt-get update
    apt-get install -y openjdk-17-jdk
    
    echo "✔️ Additional tools installed"
}

# Cleanup
cleanup() {
    echo "🧹 Cleaning up..."
    apt-get autoremove -y
    rm -f go*.tar.gz anaconda.sh
    echo "✔️ Cleanup complete"
}

# Main execution
main() {
    check_dependencies
    system_update
    install_docker
    install_go
    install_rust
    install_anaconda
    configure_system
    install_tools
    cleanup
    
    echo "================================================"
    echo "✅ Installation completed successfully!"
    echo "================================================"
    echo "🔹 Docker Version: $(docker --version)"
    echo "🔹 Docker Compose Version: $(docker compose version)"
    echo "🔹 Go Version: $(go version)"
    echo "🔹 Rust Version: $(rustc --version)"
    echo "🔹 Conda Version: $(conda --version)"
    echo "================================================"
    echo "ℹ️ Important Notes:"
    echo "- You may need to logout/login for Docker group changes"
    echo "- To activate Anaconda environment: 'conda activate myenv'"
    echo "- X11 Forwarding is configured for SSH connections"
    echo "================================================"
    echo "📋 Installation log saved to: install.log"
    echo "================================================"
}

main
