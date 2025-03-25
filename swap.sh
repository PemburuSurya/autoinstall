#!/bin/bash

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

# Selesai
echo -e "\033[0;32mSemua proses telah selesai.\033[0m"
