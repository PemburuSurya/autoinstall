#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

sudo umount /mnt/volume_sgp1_01

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

# Tambahkan swap ke /etc/fstab
echo -e "\033[0;32mMenambahkan swap ke /etc/fstab...\033[0m"
if ! grep -q "/dev/sda1" /etc/fstab; then
    echo '/dev/sda1 none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo -e "\033[0;33m/dev/sda1 sudah ada di /etc/fstab, melewati...\033[0m"
fi

# Set vm.overcommit_memory ke 1 secara langsung
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1...\033[0m"
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w vm.swappiness=30

# Set vm.overcommit_memory ke 1 secara permanen
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 secara permanen...\033[0m"
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf

# Verifikasi swap
echo -e "\033[0;32mMemverifikasi swap...\033[0m"
echo -e "\033[0;36mInformasi swap:\033[0m"
sudo swapon --show
echo -e "\033[0;36mPenggunaan memori dan swap:\033[0m"
free -h

# Selesai
echo -e "\033[0;32mSemua proses telah selesai.\033[0m"
echo -e "\033[0;32mProses selesai! Swap berhasil diatur.\033[0m"
