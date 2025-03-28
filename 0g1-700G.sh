#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

# Fungsi untuk menampilkan pesan status
function status_message() {
    echo -e "\033[0;32m$1\033[0m"
}

# Fungsi untuk menampilkan pesan peringatan
function warning_message() {
    echo -e "\033[0;33m$1\033[0m"
}

# Fungsi untuk menampilkan pesan error
function error_message() {
    echo -e "\033[0;31m$1\033[0m"
}

# 1. Memastikan swap tidak terpasang
status_message "Memastikan semua swap tidak terpasang..."
sudo swapoff -a || true

# 2. Mencari perangkat disk yang sesuai
DISK=""
if [ -b /dev/sda ]; then
    DISK="/dev/sda"
elif [ -b /dev/vda ]; then
    DISK="/dev/vda"
elif [ -b /dev/nvme0n1 ]; then
    DISK="/dev/nvme0n1"
else
    error_message "Tidak dapat menemukan perangkat disk yang cocok!"
    exit 1
fi

status_message "Menggunakan perangkat disk: $DISK"

# 3. Menghapus signature filesystem
status_message "Menghapus signature filesystem dari $DISK..."
sudo wipefs --all "$DISK"

# 4. Membuat partisi swap baru
status_message "Membuat partisi swap baru di $DISK..."
sudo parted "$DISK" --script mklabel gpt
sudo parted "$DISK" --script mkpart primary linux-swap 1MiB 100%

# Tentukan partisi swap yang baru dibuat
if [[ "$DISK" =~ /dev/nvme ]]; then
    SWAP_PARTITION="${DISK}p1"
else
    SWAP_PARTITION="${DISK}1"
fi

# Tunggu sebentar untuk memastikan partisi terbentuk
sleep 2

# 5. Memformat partisi sebagai swap dengan label
status_message "Memformat $SWAP_PARTITION sebagai swap..."
sudo mkswap -f "$SWAP_PARTITION"
sudo swaplabel -L SWAP_PARTITION "$SWAP_PARTITION"

# 6. Mendapatkan UUID partisi swap
SWAP_UUID=$(sudo blkid -s UUID -o value "$SWAP_PARTITION")
if [ -z "$SWAP_UUID" ]; then
    error_message "Gagal mendapatkan UUID partisi swap!"
    exit 1
fi

status_message "UUID partisi swap: $SWAP_UUID"

# 7. Mengaktifkan swap
status_message "Mengaktifkan swap..."
sudo swapon "$SWAP_PARTITION"

# 8. Menambahkan swap ke /etc/fstab menggunakan UUID
status_message "Menambahkan swap ke /etc/fstab menggunakan UUID..."
FSTAB_LINE="UUID=$SWAP_UUID none swap sw 0 0"

if grep -q "SWAP_PARTITION" /etc/fstab; then
    warning_message "Entri swap dengan label SWAP_PARTITION sudah ada di /etc/fstab, memperbarui..."
    sudo sed -i "/SWAP_PARTITION/c\\$FSTAB_LINE" /etc/fstab
elif grep -q "$SWAP_PARTITION" /etc/fstab; then
    warning_message "Entri untuk $SWAP_PARTITION sudah ada di /etc/fstab, memperbarui..."
    sudo sed -i "/$SWAP_PARTITION/c\\$FSTAB_LINE" /etc/fstab
elif grep -q "$SWAP_UUID" /etc/fstab; then
    warning_message "Entri untuk UUID $SWAP_UUID sudah ada di /etc/fstab, melewati..."
else
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
fi

# 9. Mengatur parameter kernel
status_message "Mengatur parameter kernel..."
SYSCTL_SETTINGS=(
    "vm.overcommit_memory=1"
    "vm.swappiness=10"
    "vm.dirty_ratio=60"
    "vm.dirty_background_ratio=2"
    "net.core.somaxconn=65535"
    "net.core.netdev_max_backlog=65535"
    "net.ipv4.tcp_max_syn_backlog=65535"
)

for setting in "${SYSCTL_SETTINGS[@]}"; do
    KEY=$(echo "$setting" | cut -d'=' -f1)
    VALUE=$(echo "$setting" | cut -d'=' -f2)
    
    # Set nilai saat ini
    sudo sysctl -w "$KEY=$VALUE"
    
    # Set nilai permanen
    if grep -q "^$KEY=" /etc/sysctl.conf; then
        sudo sed -i "s/^$KEY=.*/$setting/" /etc/sysctl.conf
    else
        echo "$setting" | sudo tee -a /etc/sysctl.conf
    fi
done

# 10. Memuat ulang pengaturan sysctl
sudo sysctl -p

# Unmount volumes
sudo umount /mnt/volume_sgp1_02
sudo umount /mnt/volume_sgp1_03
sudo umount /mnt/volume_sgp1_04
sudo umount /mnt/volume_sgp1_05
sudo umount /mnt/volume_sgp1_06
sudo umount /mnt/volume_sgp1_07
sudo umount /mnt/volume_sgp1_08

# Create Physical Volumes
sudo pvcreate /dev/sdb
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg
sudo pvcreate /dev/sdh

# Create Volume Group
sudo vgcreate vg_home /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh

# Create Logical Volume
sudo lvcreate -l 100%FREE -n lv_home vg_home

# Format Logical Volume
sudo mkfs.ext4 /dev/vg_home/lv_home

# Mount Logical Volume to /home
sudo mount /dev/vg_home/lv_home /home

# Sync data from /mnt/home to /home
sudo rsync -avx /home/ /mnt/home/

# Add entry to /etc/fstab
echo '/dev/vg_home/lv_home  /home  ext4  defaults  0  2' | sudo tee -a /etc/fstab

# Menambahkan pengguna ubuntu dan hosting
sudo adduser ubuntu --gecos "" --disabled-password
sudo adduser hosting --gecos "" --disabled-password

# Mengatur password untuk yuni1 dan yuni2
echo "ubuntu:egan1337" | sudo chpasswd
echo "hosting:egan1337" | sudo chpasswd

# Memberikan akses root ke yuni1 dan yuni2
sudo usermod -aG sudo ubuntu
sudo usermod -aG sudo hosting

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

# 11. Verifikasi
status_message "Memverifikasi konfigurasi swap..."
echo -e "\033[0;36mInformasi swap:\033[0m"
sudo swapon --show
echo -e "\033[0;36mPenggunaan memori dan swap:\033[0m"
free -h
echo -e "\033[0;36mKonfigurasi fstab:\033[0m"
grep -i swap /etc/fstab
df -h | grep /home

status_message "Konfigurasi swap selesai. Partisi swap akan tetap bekerja meskipun nama perangkat berubah setelah reboot."
