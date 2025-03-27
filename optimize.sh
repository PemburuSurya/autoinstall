#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

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
