#!/bin/bash
set -euo pipefail  # Lebih strict error handling

# Fungsi untuk menampilkan pesan dengan warna
function message() {
    echo -e "\033[0;32m$1\033[0m"
}

# Fungsi untuk menampilkan error dengan warna
function error() {
    echo -e "\033[0;31m$1\033[0m" >&2
}

# 1. Verifikasi device yang akan digunakan
message "Memverifikasi device disk..."
declare -a devices=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf")
declare -a verified_devices=()

for dev in "${devices[@]}"; do
    if [ -b "$dev" ]; then
        verified_devices+=("$dev")
        message " - $dev ditemukan"
    else
        error " - $dev tidak ditemukan, akan dilewati"
    fi
done

if [ ${#verified_devices[@]} -eq 0 ]; then
    error "Tidak ada device yang tersedia!"
    exit 1
fi

# 2. Konfirmasi sebelum eksekusi
message "\nDevice yang akan digunakan untuk LVM:"
for dev in "${verified_devices[@]}"; do
    lsblk "$dev"
done

read -rp "Lanjutkan setup LVM? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    message "Operasi dibatalkan"
    exit 0
fi

# 3. Setup LVM menggunakan UUID
message "\nMembuat Physical Volumes..."
for dev in "${verified_devices[@]}"; do
    sudo pvcreate "$dev"
done

message "\nMembuat Volume Group..."
sudo vgcreate vg_var "${verified_devices[@]}"

message "\nMembuat Logical Volume..."
sudo lvcreate -l 100%FREE -n lv_var vg_var

# 4. Format dengan filesystem dan dapatkan UUID
message "\nMemformat Logical Volume..."
sudo mkfs.ext4 /dev/vg_var/lv_var
UUID=$(sudo blkid -s UUID -o value /dev/vg_var/lv_var)
if [ -z "$UUID" ]; then
    error "Gagal mendapatkan UUID logical volume"
    exit 1
fi

# 5. Backup data /var
message "\nMembuat backup /var..."
sudo mkdir -p /mnt/var_backup
sudo rsync -aAXv /var/ /mnt/var_backup/ || {
    error "Gagal backup /var"
    exit 1
}

# 6. Mount sementara dan restore data
message "\nMenyiapkan mount sementara..."
sudo mkdir -p /mnt/new_var
sudo mount /dev/vg_var/lv_var /mnt/new_var
sudo chmod 755 /mnt/new_var

message "Restore data ke logical volume baru..."
sudo rsync -aAXv /mnt/var_backup/ /mnt/new_var/ || {
    error "Gagal restore data"
    sudo umount /mnt/new_var
    exit 1
}
sudo umount /mnt/new_var

# 7. Update fstab dengan UUID
message "\nMemperbarui /etc/fstab..."
if grep -q "/dev/vg_var/lv_var" /etc/fstab; then
    sudo sed -i "\@/dev/vg_var/lv_var@d" /etc/fstab
fi

if grep -q "$UUID" /etc/fstab; then
    sudo sed -i "\@$UUID@d" /etc/fstab
fi

echo "UUID=$UUID /var ext4 defaults,noatime,nodiratime 0 2" | sudo tee -a /etc/fstab

# 8. Migrasi /var
message "\nMigrasi /var..."
sudo mkdir -p /var.old
sudo mv /var /var.old
sudo mkdir /var

message "Mount logical volume ke /var..."
sudo mount /var || {
    error "Gagal mount /var"
    exit 1
}

# 9. Verifikasi
message "\nVerifikasi hasil:"
df -h /var
lsblk -f /dev/vg_var/lv_var

# 10. Cleanup
message "\nPembersihan sementara..."
sudo rm -rf /mnt/new_var

message "\n=========================================="
message "Script berhasil dijalankan!"
message "Logical Volume dibuat dan di-mount ke /var"
message "Original /var data disimpan di /var.old"
message ""
message "Setelah verifikasi, Anda bisa menghapus /var.old dengan:"
message "sudo rm -rf /var.old"
message ""
message "Untuk mengembalikan jika ada masalah:"
message "1. sudo umount /var"
message "2. sudo rm -rf /var"
message "3. sudo mv /var.old /var"
message "4. Hapus entry terakhir di /etc/fstab"
message "=========================================="
