#!/bin/bash
set -e  # Exit immediately if any command fails
exec > >(tee install.log) 2>&1  # Log all output

# Menambahkan pengguna ubuntu dan hosting
sudo adduser ubuntu --gecos "" --disabled-password
sudo adduser hosting --gecos "" --disabled-password

# Mengatur password untuk yuni1 dan yuni2
echo "ubuntu:egan1337" | sudo chpasswd
echo "hosting:egan1337" | sudo chpasswd

# Memberikan akses root ke yuni1 dan yuni2
sudo usermod -aG sudo ubuntu
sudo usermod -aG sudo hosting

# Hapus file resolv.conf yang ada
echo -e "\033[0;32mMenghapus file /etc/resolv.conf...\033[0m"
sudo rm /etc/resolv.conf

# Buat file resolv.conf baru dan tambahkan nameserver
echo -e "\033[0;32mMembuat file /etc/resolv.conf baru...\033[0m"
sudo tee /etc/resolv.conf > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL

# Lock file resolv.conf agar tidak bisa diubah
echo -e "\033[0;32mMengunci file /etc/resolv.conf...\033[0m"
sudo chattr +i /etc/resolv.conf

# Pastikan partisi swap tidak terpasang
echo -e "\033[0;32mMemastikan swap tidak terpasang...\033[0m"
sudo swapoff /dev/sda1 || true

# Hapus signature filesystem dari /dev/sda
echo -e "\033[0;32mMenghapus signature filesystem dari /dev/sda...\033[0m"
sudo wipefs --all /dev/sda

# Buat partisi baru di /dev/sda
echo -e "\033[0;32mMembuat partisi baru di /dev/sda...\033[0m"
sudo fdisk /dev/sda <<EOF
n
p
1


t
82
w
EOF

# Format partisi sebagai swap
echo -e "\033[0;32mMemformat /dev/sda1 sebagai swap...\033[0m"
sudo mkswap /dev/sda1

# Aktifkan swap
echo -e "\033[0;32mMengaktifkan swap...\033[0m"
sudo swapon /dev/sda1

# Menambahkan swap ke /etc/fstab untuk memastikan swap tetap aktif setelah reboot
echo -e "\033[0;32mMenambahkan swap ke /etc/fstab...\033[0m"
if ! grep -q "/dev/sda1" /etc/fstab; then
    echo '/dev/sda1 none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo -e "\033[0;33m/dev/sda1 sudah ada di /etc/fstab, melewati...\033[0m"
fi

# Set vm.overcommit_memory ke 1 dan vm.swappiness ke 10 secara langsung
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 dan vm.swappiness ke 10...\033[0m"
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w vm.swappiness=10
sudo sysctl -w vm.dirty_ratio=60
sudo sysctl -w vm.dirty_background_ratio=2
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.core.netdev_max_backlog=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535

# Set vm.overcommit_memory dan vm.swappiness secara permanen
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 dan vm.swappiness ke 10 secara permanen...\033[0m"
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=60' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=2' | sudo tee -a /etc/sysctl.conf
echo 'net.core.somaxconn=65535' | sudo tee -a /etc/sysctl.conf
echo 'net.core.netdev_max_backlog=65535' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog=65535' | sudo tee -a /etc/sysctl.conf

# Update dan upgrade sistem
sudo apt update && sudo apt upgrade -y
sudo apt install build-essential -y

# Mengubah batasan CPU di /etc/security/limits.conf
echo "Mengubah batasan CPU dan jumlah file di /etc/security/limits.conf..."
sudo bash -c 'echo -e "\n# Meningkatkan batasan CPU dan file\n* soft nofile 65535\n* hard nofile 65535\n* soft nproc unlimited\n* hard nproc unlimited" >> /etc/security/limits.conf'

# Menaikan batasan
ulimit -n 65536
ulimit -u unlimited

# Menonaktifkan Intel P-State jika diperlukan (opsional)
echo -e "\033[0;32mMenonaktifkan Intel P-State (jika digunakan)...\033[0m"
if grep -q "intel_pstate=disable" /etc/default/grub; then
    echo -e "\033[0;32mIntel P-State sudah dinonaktifkan.\033[0m"
else
    echo -e "\033[0;32mMenonaktifkan Intel P-State...\033[0m"
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_pstate=disable"/' /etc/default/grub
    sudo update-grub
    echo -e "\033[0;32mIntel P-State berhasil dinonaktifkan. Silakan reboot sistem.\033[0m"
fi

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
