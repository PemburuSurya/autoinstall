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
message "Memulai migrasi /var ke LVM"

# Cek root
if [[ $EUID -ne 0 ]]; then
    error "Script harus dijalankan sebagai root"
fi

# Cek distribusi Linux (Debian/Ubuntu/RHEL)
if ! command -v lsb_release >/dev/null 2>&1; then
    warning "lsb_release tidak ditemukan, asumsikan sistem kompatibel"
else
    distro=$(lsb_release -is)
    case $distro in
        Ubuntu|Debian|CentOS|RedHatEnterpriseServer)
            message "Sistem terdeteksi: $distro"
            ;;
        *)
            warning "Distribusi $distro belum sepenuhnya diuji"
            ;;
    esac
fi

# ==========================================
# 2. Deteksi dan Verifikasi Device
# ==========================================
declare -a devices=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf")
declare -a verified_devices=()
declare -a device_ids=()

message "Memindai device yang tersedia..."
for dev in "${devices[@]}"; do
    if [ -b "$dev" ]; then
        # Dapatkan ID fisik device yang lebih stabil
        dev_id=$(ls -l /dev/disk/by-id/ | grep -E "$(basename $(readlink -f "$dev"))" | head -1 | awk '{print $9}')
        if [ -n "$dev_id" ]; then
            message " - Ditemukan: $dev -> /dev/disk/by-id/$dev_id"
            verified_devices+=("$dev")
            device_ids+=("/dev/disk/by-id/$dev_id")
        else
            warning " - Device $dev ditemukan tetapi tidak memiliki ID fisik, akan dilewati"
        fi
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
echo " - Volume Group: vg_var"
echo " - Logical Volume: lv_var"
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
# 4. Setup LVM dengan Konfigurasi Kuat
# ==========================================
message "\nMenyiapkan LVM..."

# Hapus signature yang mungkin ada
for dev in "${verified_devices[@]}"; do
    message " - Membersihkan device $dev..."
    sudo wipefs -a "$dev" || warning "Gagal membersihkan $dev (lanjut saja)"
done

# Buat Physical Volume
for dev in "${verified_devices[@]}"; do
    message " - Membuat PV pada $dev..."
    sudo pvcreate "$dev" || error "Gagal membuat PV di $dev"
done

# Buat Volume Group dengan semua device
message "\nMembuat Volume Group..."
sudo vgcreate vg_var "${verified_devices[@]}" || error "Gagal membuat VG"

# Buat Logical Volume
message "\nMembuat Logical Volume..."
sudo lvcreate -l 100%FREE -n lv_var vg_var || error "Gagal membuat LV"

# ==========================================
# 5. Konfigurasi Filesystem
# ==========================================
message "\nMembuat filesystem..."
sudo mkfs.ext4 -m 1 -O ^has_journal /dev/vg_var/lv_var || error "Gagal membuat filesystem"

# Dapatkan UUID
UUID=$(sudo blkid -s UUID -o value /dev/vg_var/lv_var)
if [ -z "$UUID" ]; then
    error "Gagal mendapatkan UUID logical volume"
fi

# Optimalkan filesystem
message "Mengoptimalkan filesystem..."
sudo tune2fs -o journal_data_writeback /dev/vg_var/lv_var
sudo tune2fs -O ^has_journal /dev/vg_var/lv_var

# ==========================================
# 6. Backup Data /var
# ==========================================
message "\nMembuat backup /var..."
backup_dir="/mnt/var_backup_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$backup_dir"
sudo rsync -aAXv --delete --info=progress2 /var/ "$backup_dir/" || {
    error "Gagal backup /var"
}

# Verifikasi backup
if [ ! -f "$backup_dir/etc/fstab" ]; then
    error "Backup tidak valid, file penting tidak ditemukan"
fi

# ==========================================
# 7. Migrasi Data ke LV Baru
# ==========================================
message "\nMemigrasi data ke logical volume baru..."

# Mount sementara
mount_point="/mnt/new_var"
sudo mkdir -p "$mount_point"
sudo mount /dev/vg_var/lv_var "$mount_point" || error "Gagal mount LV"

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

# Update fstab dengan semua opsi mount
fstab_entry=(
    "# /var pada LVM"
    "UUID=$UUID /var ext4 defaults,noatime,nodiratime,data=writeback,barrier=0 0 2"
    "/dev/vg_var/lv_var /var ext4 defaults,noatime,nodiratime,data=writeback,barrier=0 0 2"
    "# Fallback device: ${device_ids[0]}"
    "${device_ids[0]} /var ext4 defaults,noatime,nodiratime,data=writeback,barrier=0 0 2"
)

for line in "${fstab_entry[@]}"; do
    if ! grep -q "$line" /etc/fstab; then
        echo "$line" | sudo tee -a /etc/fstab >/dev/null
    fi
done

# ==========================================
# 9. Konfigurasi LVM untuk Boot
# ==========================================
message "\nMengkonfigurasi LVM untuk boot..."

# Buat initramfs baru
if command -v update-initramfs >/dev/null 2>&1; then
    sudo update-initramfs -u -k all || warning "Gagal update initramfs"
elif command -v dracut >/dev/null 2>&1; then
    sudo dracut -f || warning "Gagal update initramfs"
fi

# Konfigurasi lvm.conf
sudo sed -i 's/obtain_device_list_from_udev = [0-9]/obtain_device_list_from_udev = 1/' /etc/lvm/lvm.conf
sudo sed -i 's/^\( *\)filter = .*/\1filter = [ "a|.*|" ]/' /etc/lvm/lvm.conf

# ==========================================
# 10. Eksekusi Migrasi
# ==========================================
message "\nMelakukan migrasi akhir..."

# Pindahkan /var lama
sudo mv /var /var.old
sudo mkdir /var

# Mount /var baru
sudo mount /var || {
    # Jika gagal, coba mount manual
    warning "Mount otomatis gagal, mencoba mount manual..."
    sudo vgchange -ay
    sudo mount /dev/vg_var/lv_var /var || error "Gagal mount /var"
}

# ==========================================
# 11. Verifikasi Akhir
# ==========================================
message "\nVerifikasi akhir..."

# Cek mount
if ! mountpoint -q /var; then
    error "/var tidak ter-mount dengan benar"
fi

# Cek kapasitas
var_size=$(df -h /var | awk 'NR==2 {print $2}')
if [[ "$var_size" == "1.0M" ]]; then
    error "Ukuran /var tidak normal, kemungkinan mount gagal"
fi

# Cek isi
if [ ! -f /var/backups ]; then
    warning "Direktori /var/backups tidak ditemukan, kemungkinan data tidak lengkap"
fi

# ==========================================
# 12. Finalisasi
# ==========================================
message "\nMigrasi berhasil diselesaikan!"

cat <<EOF
==========================================
TINDAKAN SELANJUTNYA:
1. Verifikasi sistem:
   - df -h /var
   - lsblk
   - sudo lvs
   - sudo vgs

2. Jika semua berfungsi setelah reboot, Anda dapat menghapus backup:
   - sudo rm -rf /var.old
   - sudo rm -rf /mnt/var_backup_*

3. Jika ada masalah:
   - Boot ke rescue mode
   - Mount root filesystem
   - Pulihkan /etc/fstab dari backup
   - Pulihkan /var dari /var.old

4. Reboot sistem untuk menguji:
   sudo reboot
==========================================
EOF
