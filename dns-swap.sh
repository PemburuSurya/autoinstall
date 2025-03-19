#!/bin/bash

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

# Nonaktifkan semua swap yang sedang aktif
echo -e "\033[0;32mMenonaktifkan swap yang sedang aktif...\033[0m"
sudo swapoff -a

# Buat swapfile baru dengan ukuran 64GB
echo -e "\033[0;32mMembuat swapfile baru dengan ukuran 64GB...\033[0m"
sudo fallocate -l 16G /swapfile

# Set permission swapfile agar hanya bisa diakses oleh root
echo -e "\033[0;32mMengatur permission swapfile...\033[0m"
sudo chmod 600 /swapfile

# Format swapfile sebagai area swap
echo -e "\033[0;32mMemformat swapfile sebagai area swap...\033[0m"
sudo mkswap /swapfile

# Aktifkan swapfile
echo -e "\033[0;32mMengaktifkan swapfile...\033[0m"
sudo swapon /swapfile

# Set vm.overcommit_memory ke 1 secara langsung
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1...\033[0m"
sudo sysctl -w vm.overcommit_memory=1

# Set vm.overcommit_memory ke 1 secara permanen
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 secara permanen...\033[0m"
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf

# Selesai
echo -e "\033[0;32mSemua proses telah selesai.\033[0m"
