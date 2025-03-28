#!/bin/bash
set -e  # Exit immediately if any command fails
exec > >(tee install.log) 2>&1  # Log all output

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# User creation
echo -e "${GREEN}Creating users...${NC}"
sudo adduser ubuntu --gecos "" --disabled-password
sudo adduser hosting --gecos "" --disabled-password

# Set passwords
echo "ubuntu:egan1337" | sudo chpasswd
echo "hosting:egan1337" | sudo chpasswd

# Add to sudo
sudo usermod -aG sudo ubuntu
sudo usermod -aG sudo hosting

# DNS Configuration
echo -e "${GREEN}Configuring DNS...${NC}"
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL
sudo chattr +i /etc/resolv.conf

# Swap Configuration
echo -e "${GREEN}Setting up swap...${NC}"

# Check if swap already exists
if swapon --show | grep -q "/dev/sda1"; then
    echo -e "${YELLOW}Swap already exists on /dev/sda1, skipping creation${NC}"
else
    # Create swap
    sudo swapoff /dev/sda1 2>/dev/null || true
    sudo wipefs --all /dev/sda
    
    echo -e "${GREEN}Creating swap partition...${NC}"
    sudo fdisk /dev/sda <<EOF
n
p
1


t
82
w
EOF

    sudo mkswap /dev/sda1
    sudo swapon /dev/sda1
    
    # Add to fstab if not exists
    if ! grep -q "/dev/sda1" /etc/fstab; then
        echo '/dev/sda1 none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
fi

# Kernel tuning
echo -e "${GREEN}Optimizing kernel parameters...${NC}"
sudo tee -a /etc/sysctl.conf > /dev/null <<EOL
vm.overcommit_memory=1
vm.swappiness=10
vm.dirty_ratio=60
vm.dirty_background_ratio=2
net.core.somaxconn=65535
net.core.netdev_max_backlog=65535
net.ipv4.tcp_max_syn_backlog=65535
EOL
sudo sysctl -p

# System updates
echo -e "${GREEN}Updating system...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential

# CPU limits
echo -e "${GREEN}Increasing limits...${NC}"
sudo tee -a /etc/security/limits.conf > /dev/null <<EOL
* soft nofile 65535
* hard nofile 65535
* soft nproc unlimited
* hard nproc unlimited
EOL

ulimit -n 65536
ulimit -u unlimited

# Disable Intel P-State if exists
if grep -q "intel_pstate=disable" /etc/default/grub; then
    echo -e "${YELLOW}Intel P-State already disabled${NC}"
else
    echo -e "${GREEN}Disabling Intel P-State...${NC}"
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&intel_pstate=disable /' /etc/default/grub
    sudo update-grub
fi

# Install Docker
echo -e "${GREEN}Installing Docker...${NC}"
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
echo -e "${GREEN}Installing Docker Compose...${NC}"
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Go
echo -e "${GREEN}Installing Go...${NC}"
GO_VERSION="1.22.4"
curl -OL https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Install Rust
echo -e "${GREEN}Installing Rust...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install Anaconda
echo -e "${GREEN}Installing Anaconda...${NC}"
curl -O https://repo.anaconda.com/archive/Anaconda3-2023.09-0-Linux-x86_64.sh
bash Anaconda3-2023.09-0-Linux-x86_64.sh -b
echo 'export PATH="$HOME/anaconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
conda init
conda create -n myenv python=3.9 -y

# Install additional tools
echo -e "${GREEN}Installing additional tools...${NC}"
sudo apt install -y \
    git clang cmake openssl pkg-config libssl-dev \
    snapd wget htop tmux jq make gcc tar ncdu \
    nodejs flatpak default-jdk aptitude squid \
    apache2-utils iptables-persistent openssh-server \
    jq sed lz4 aria2 pv

# Install VS Code
sudo snap install code --classic

# Configure X11 Forwarding
echo -e "${GREEN}Configuring X11 Forwarding...${NC}"
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Cleanup
echo -e "${GREEN}Cleaning up...${NC}"
rm -f go*.tar.gz Anaconda*.sh
sudo apt autoremove -y

echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "Please reboot your system for all changes to take effect."
