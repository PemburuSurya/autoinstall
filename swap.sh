#!/bin/bash

# Nonaktifkan semua swap yang sedang aktif
echo -e "\033[0;32mMenonaktifkan swap yang sedang aktif...\033[0m"
sudo swapoff -a

# Hapus swapfile lama (jika ada)
sudo rm -f /swapfile

# Buat swapfile baru dengan ukuran 6GB (sesuaikan)
echo -e "\033[0;32mMembuat swapfile baru dengan ukuran 6GB...\033[0m"
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile

# Format swapfile sebagai area swap
echo -e "\033[0;32mMemformat swapfile sebagai area swap...\033[0m"
sudo mkswap /swapfile

# Aktifkan swapfile
echo -e "\033[0;32mMengaktifkan swapfile...\033[0m"
sudo swapon /swapfile

# Tambahkan ke /etc/fstab (untuk persistensi setelah reboot)
echo -e "\033[0;32mMenambahkan swapfile ke /etc/fstab...\033[0m"
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Set parameter kernel
echo -e "\033[0;32mMengatur parameter kernel...\033[0m"
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w vm.swappiness=20
sudo sysctl -w vm.dirty_ratio=60
sudo sysctl -w vm.dirty_background_ratio=2
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.core.netdev_max_backlog=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535

# Set parameter kernel secara permanen
echo -e "\033[0;32mMenyimpan parameter kernel secara permanen...\033[0m"
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness=20' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=60' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=2' | sudo tee -a /etc/sysctl.conf
echo 'net.core.somaxconn=65535' | sudo tee -a /etc/sysctl.conf
echo 'net.core.netdev_max_backlog=65535' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog=65535' | sudo tee -a /etc/sysctl.conf

# Selesai
echo -e "\033[0;32mSemua proses telah selesai. Swap akan aktif setelah reboot.\033[0m"
