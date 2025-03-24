#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

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

# Set vm.overcommit_memory dan vm.swappiness secara permanen
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 dan vm.swappiness ke 10 secara permanen...\033[0m"
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

#Menaikan batasan
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

# Verifikasi swap
echo -e "\033[0;32mMemverifikasi swap...\033[0m"
echo -e "\033[0;36mInformasi swap:\033[0m"
sudo swapon --show
echo -e "\033[0;36mPenggunaan memori dan swap:\033[0m"
free -h

# Reboot untuk menerapkan perubahan jika Intel P-State diubah
echo -e "\033[0;32mSelesai! Sistem akan reboot untuk menerapkan perubahan.\033[0m"
echo -e "\033[0;32mPastikan swap dan pengaturan lainnya aktif setelah reboot.\033[0m"
sudo reboot
