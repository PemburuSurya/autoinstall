#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\e[1;31mThis script must be run as root. Use sudo.\e[0m"
    exit 1
fi

# Update package lists
echo "Updating package lists..."
sudo apt update -y || { echo "Update failed"; exit 1; }

# Install OpenSSH Server
echo "Installing OpenSSH Server..."
sudo apt install openssh-server -y || { echo "Installation failed"; exit 1; }

# Generate SSH Key Pair if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH Key Pair (RSA 4096-bit)..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N "" -C "$(whoami)@$(hostname)" || { echo "Key generation failed"; exit 1; }
fi

# Display public key
echo -e "\n\033[1;36mYour public SSH key is:\033[0m"
cat ~/.ssh/id_rsa.pub || { echo "Could not display public key"; exit 1; }

# Set up authorized_keys
echo "Setting up authorized_keys..."
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Get VPS Public IP with fallback
echo -e "\nDetecting VPS IP address..."
VPS_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo -e "\033[1;36mYour VPS IP address is: $VPS_IP\033[0m"

# Ask for username
read -p $'\033[1;33mEnter your VPS username [default: root]: \033[0m' USERNAME
USERNAME=${USERNAME:-root}

# Copy SSH key to VPS
echo -e "\033[1;34mCopying SSH key to VPS...\033[0m"
ssh-copy-id -i ~/.ssh/id_rsa.pub $USERNAME@$VPS_IP || { echo "SSH key copy failed"; exit 1; }

# Backup original SSH config
echo -e "\e[1;33mCreating backup of sshd_config at /etc/ssh/sshd_config.bak...\e[0m"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || { echo "Backup failed"; exit 1; }

# Configure SSH securely
echo -e "\e[1;32mConfiguring SSH security settings...\e[0m"
# Remove existing settings if they exist
sed -i '/^Port/d' /etc/ssh/sshd_config
sed -i '/^PubkeyAuthentication/d' /etc/ssh/sshd_config
sed -i '/^AuthorizedKeysFile/d' /etc/ssh/sshd_config
sed -i '/^PasswordAuthentication/d' /etc/ssh/sshd_config

# Append new settings
cat >> /etc/ssh/sshd_config << EOF
# Custom Security Settings
Port 22
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
EOF

# Restart SSH service
echo -e "\e[1;36mRestarting SSH service...\e[0m"
systemctl daemon-reload
systemctl restart ssh || { echo "Failed to restart SSH"; exit 1; }

# Verify SSH connection
echo -e "\n\033[1;34mTesting SSH connection...\033[0m"
ssh $USERNAME@$VPS_IP "echo -e '\033[1;32mSSH connection successful!\033[0m'" || { echo "SSH test failed"; exit 1; }

echo -e "\n\033[1;32mSetup completed successfully!\033[0m"
echo -e "You can now login to your VPS using:"
echo -e "\033[1;37mssh $USERNAME@$VPS_IP\033[0m"
