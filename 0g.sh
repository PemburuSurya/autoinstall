#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

# Update dan upgrade sistem
sudo apt update && sudo apt upgrade -y
sudo apt install build-essential -y

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
#!/bin/bash

# Unmount volumes
sudo umount /mnt/volume_sgp1_02
sudo umount /mnt/volume_sgp1_03
sudo umount /mnt/volume_sgp1_04
sudo umount /mnt/volume_sgp1_05
sudo umount /mnt/volume_sgp1_06

# Create Physical Volumes
sudo pvcreate /dev/sdb
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf

# Create Volume Group
sudo vgcreate vg_home /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf

# Create Logical Volume
sudo lvcreate -l 100%FREE -n lv_home vg_home

# Format Logical Volume
sudo mkfs.ext4 /dev/vg_home/lv_home

# Create /home directory and Mount
sudo mkdir /home

# Mount Logical Volume to /home
sudo mount /dev/vg_home/lv_home /home

# Sync data from /mnt/home to /home
sudo rsync -avx /home/ /mnt/home/

# Add entry to /etc/fstab
echo '/dev/vg_home/lv_home  /home  ext4  defaults  0  2' | sudo tee -a /etc/fstab

# Verify the mount
df -h | grep /home

# Pesan akhir
echo "=========================================="
echo "Skrip berhasil dijalankan tanpa kegagalan!"
echo "Logical Volume berhasil dibuat dan dipasang ke /home."
echo "=========================================="

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
