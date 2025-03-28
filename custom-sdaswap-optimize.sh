#!/bin/bash
set -e  # Exit immediately if any command fails
exec > >(tee install.log) 2>&1  # Log all output

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 1. User creation
# 1. User creation
# 1. User creation

echo -e "${GREEN}Creating users...${NC}"
sudo adduser ubuntu --gecos "" --disabled-password
sudo adduser hosting --gecos "" --disabled-password

# Set passwords
echo "ubuntu:egan1337" | sudo chpasswd
echo "hosting:egan1337" | sudo chpasswd

# Add to sudo
sudo usermod -aG sudo ubuntu
sudo usermod -aG sudo hosting

# 2. DNS Configuration
# 2. DNS Configuration
# 2. DNS Configuration

echo -e "${GREEN}Configuring DNS...${NC}"
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL
sudo chattr +i /etc/resolv.conf

# 3. Create Swap Partition
# 3. Create Swap Partition
# 3. Create Swap Partition

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
sudo sysctl -p

# 4. Optimize
# 4. Optimize
# 4. Optimize

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
