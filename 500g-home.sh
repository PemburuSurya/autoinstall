#!/bin/bash
set -euo pipefail

# ==========================================
# Fungsi-fungsi utilitas
# ==========================================
function message() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

function warning() {
    echo -e "\033[0;33m[WARN] $1\033[0m"
}

function error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
    exit 1
}

# ==========================================
# 1. Verifikasi Environment
# ==========================================
message "Memulai migrasi /home ke LVM"

# Cek root
if [[ $EUID -ne 0 ]]; then
    error "Script harus dijalankan sebagai root"
fi

# ==========================================
# 2. Deteksi dan Verifikasi Device
# ==========================================
declare -a devices=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
declare -a verified_devices=()
declare -a device_ids=()

message "Memindai device yang tersedia..."
for dev in "${devices[@]}"; do
    if [ -b "$dev" ]; then
        # Skip jika device sudah menjadi partisi
        if [[ "$dev" =~ [0-9]$ ]]; then
            warning " - $dev adalah partisi, melewati..."
            continue
        fi
        
        # Dapatkan ID fisik
        dev_id=$(ls -l /dev/disk/by-id/ | grep -E "$(basename $(readlink -f "$dev"))" | grep -v -E "part[0-9]+" | head -1 | awk '{print $9}')
        if [ -n "$dev_id" ]; then
            device_ids+=("/dev/disk/by-id/$dev_id")
        else
            warning " - Tidak dapat menemukan ID fisik untuk $dev"
            device_ids+=("$dev")
        fi
        
        verified_devices+=("$dev")
        message " - Ditemukan: $dev (ID Fisik: ${device_ids[-1]})"
    else
        warning " - Device $dev tidak ditemukan"
    fi
done

if [ ${#verified_devices[@]} -eq 0 ]; then
    error "Tidak ada device yang tersedia untuk LVM"
fi

# ==========================================
# 3. Konfirmasi Konfigurasi
# ==========================================
message "\nKonfigurasi yang akan diterapkan:"
echo " - Volume Group: vg_home"
echo " - Logical Volume: lv_home"
echo " - Device yang akan digunakan:"
for ((i=0; i<${#verified_devices[@]}; i++)); do
    echo "   - ${verified_devices[$i]} (ID Fisik: ${device_ids[$i]})"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "${verified_devices[$i]}"
done

read -rp "Lanjutkan setup LVM? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    message "Operasi dibatalkan"
    exit 0
fi

# ==========================================
# 4. Setup LVM
# ==========================================
message "\nMenyiapkan LVM..."

# Hapus VG yang sudah ada jika ada
if vgs vg_home >/dev/null 2>&1; then
    message " - Volume Group vg_home sudah ada, menghapus..."
    sudo vgchange -an vg_home
    sudo vgremove -f vg_home || error "Gagal menghapus VG yang ada"
fi

# Buat Physical Volume
for dev in "${verified_devices[@]}"; do
    message " - Membuat PV pada $dev..."
    sudo pvcreate -ff -y "$dev" || error "Gagal membuat PV di $dev"
done

# Buat Volume Group
message "\nMembuat Volume Group..."
sudo vgcreate vg_home "${verified_devices[@]}" || error "Gagal membuat VG"

# Buat Logical Volume
message "\nMembuat Logical Volume..."
sudo lvcreate -l 100%FREE -n lv_home vg_home || error "Gagal membuat LV"

# ==========================================
# 5. Konfigurasi Filesystem
# ==========================================
message "\nMembuat filesystem..."
sudo mkfs.ext4 -m 1 -F /dev/vg_home/lv_home || error "Gagal membuat filesystem"

# Dapatkan UUID
UUID=$(sudo blkid -s UUID -o value /dev/vg_home/lv_home)
if [ -z "$UUID" ]; then
    error "Gagal mendapatkan UUID logical volume"
fi

# ==========================================
# 6. Backup Data /home
# ==========================================
message "\nMembuat backup /home..."
backup_dir="/mnt/home_backup_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$backup_dir"
sudo rsync -aAXv --delete --info=progress2 /home/ "$backup_dir/" || {
    error "Gagal backup /home"
}

# Verifikasi backup
if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir")" ]; then
    error "Backup tidak valid, direktori kosong"
fi

# ==========================================
# 7. Migrasi Data ke LV Baru
# ==========================================
message "\nMemigrasi data ke logical volume baru..."

# Mount sementara
mount_point="/mnt/new_home"
sudo mkdir -p "$mount_point"
sudo mount /dev/vg_home/lv_home "$mount_point" || error "Gagal mount LV"

# Salin data
sudo rsync -aAXv --delete --info=progress2 "$backup_dir/" "$mount_point/" || {
    sudo umount "$mount_point"
    error "Gagal menyalin data ke LV"
}

# Set permission
sudo chmod 755 "$mount_point"
sudo umount "$mount_point"

# ==========================================
# 8. Konfigurasi Mount Permanen
# ==========================================
message "\nMengkonfigurasi mount permanen..."

# Backup fstab
sudo cp /etc/fstab "/etc/fstab.backup_$(date +%Y%m%d_%H%M%S)"

# Update fstab
fstab_entry="UUID=$UUID /home ext4 defaults,noatime,nodiratime,errors=remount-ro 0 2"
if grep -q "^UUID=$UUID" /etc/fstab; then
    sudo sed -i "s|^UUID=$UUID.*|$fstab_entry|" /etc/fstab
else
    echo "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null
fi

# ==========================================
# 9. Konfigurasi LVM untuk Boot
# ==========================================
message "\nMengkonfigurasi LVM untuk boot..."

# Update initramfs
if command -v update-initramfs >/dev/null 2>&1; then
    sudo update-initramfs -u -k all || warning "Gagal update initramfs"
elif command -v dracut >/dev/null 2>&1; then
    sudo dracut -f || warning "Gagal update initramfs"
fi

# Reload systemd
sudo systemctl daemon-reload

# ==========================================
# 10. Eksekusi Migrasi
# ==========================================
message "\nMelakukan migrasi akhir..."

# Pindahkan /home lama
sudo mv /home /home.old
sudo mkdir /home

# Mount /home baru
sudo mount /home || {
    warning "Mount otomatis gagal, mencoba mount manual..."
    sudo vgchange -ay
    sudo mount /dev/vg_home/lv_home /home || error "Gagal mount /home"
}

# ==========================================
# 11. Verifikasi Akhir
# ==========================================
message "\nVerifikasi akhir..."

# Cek mount
if ! mountpoint -q /home; then
    error "/home tidak ter-mount dengan benar"
fi

# Cek isi
if [ ! -d /home/* ]; then
    warning "Direktori home user tidak ditemukan, kemungkinan data tidak lengkap"
fi

# ==========================================
# 12. Finalisasi
# ==========================================
message "\nMigrasi berhasil diselesaikan!"

cat <<EOF
==========================================
TINDAKAN SELANJUTNYA:
1. Verifikasi sistem:
   - df -h /home
   - lsblk
   - sudo lvs
   - sudo vgs

2. Jika semua berfungsi setelah reboot, Anda dapat menghapus backup:
   - sudo rm -rf /home.old
   - sudo rm -rf $backup_dir

3. Jika ada masalah:
   - Boot ke rescue mode
   - Mount root filesystem
   - Pulihkan /etc/fstab dari backup
   - Pulihkan /home dari /home.old

4. Reboot sistem untuk menguji:
   sudo reboot
==========================================
EOF
