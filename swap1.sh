#!/bin/bash
set -euo pipefail  # Lebih strict error handling

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
message "Memulai konfigurasi swap"

# Cek root
if [[ $EUID -ne 0 ]]; then
    error "Script harus dijalankan sebagai root"
fi

# Cek device target
TARGET_DEVICE="/dev/sda"
if [ ! -b "$TARGET_DEVICE" ]; then
    error "Device $TARGET_DEVICE tidak ditemukan"
fi

# ==========================================
# 2. Konfirmasi sebelum eksekusi
# ==========================================
message "\nInformasi device yang akan digunakan:"
lsblk "$TARGET_DEVICE"

read -rp "Lanjutkan setup swap pada $TARGET_DEVICE? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    message "Operasi dibatalkan"
    exit 0
fi

# ==========================================
# 3. Setup Swap
# ==========================================

# Nonaktifkan swap yang ada di device target
message "\nMenonaktifkan swap yang ada..."
swapoff "${TARGET_DEVICE}1" 2>/dev/null || true

# Hapus signature
message "Membersihkan device..."
wipefs --all "$TARGET_DEVICE" || error "Gagal membersihkan device"

# Buat partisi swap
message "Membuat partisi swap..."
echo -e "n\np\n1\n\n\nt\n82\nw" | fdisk "$TARGET_DEVICE" || error "Gagal membuat partisi"

# Tunggu hingga partisi tersedia
sleep 2
partprobe "$TARGET_DEVICE"

# Verifikasi partisi dibuat
if [ ! -b "${TARGET_DEVICE}1" ]; then
    error "Partisi ${TARGET_DEVICE}1 gagal dibuat"
fi

# Format sebagai swap
message "Memformat partisi swap..."
mkswap "${TARGET_DEVICE}1" || error "Gagal memformat swap"

# Aktifkan swap
message "Mengaktifkan swap..."
swapon "${TARGET_DEVICE}1" || error "Gagal mengaktifkan swap"

# ==========================================
# 4. Konfigurasi Permanen
# ==========================================

# Backup fstab
message "\nMembackup /etc/fstab..."
cp /etc/fstab "/etc/fstab.backup_$(date +%Y%m%d_%H%M%S)"

# Dapatkan UUID partisi
UUID=$(blkid -s UUID -o value "${TARGET_DEVICE}1")
if [ -z "$UUID" ]; then
    warning "Gagal mendapatkan UUID, menggunakan device path sebagai fallback"
    SWAP_ENTRY="${TARGET_DEVICE}1 none swap sw 0 0"
else
    SWAP_ENTRY="UUID=$UUID none swap sw 0 0"
fi

# Update fstab
message "Memperbarui /etc/fstab..."
if grep -q "${TARGET_DEVICE}1" /etc/fstab || grep -q "$UUID" /etc/fstab; then
    # Hapus entry yang ada
    grep -v "${TARGET_DEVICE}1" /etc/fstab | grep -v "$UUID" > /tmp/fstab.tmp
    mv /tmp/fstab.tmp /etc/fstab
fi

echo "$SWAP_ENTRY" >> /etc/fstab

# ==========================================
# 5. Optimasi Kernel
# ==========================================
message "\nMengoptimasi parameter kernel..."

# Daftar parameter yang akan diatur
declare -A SYSCTL_PARAMS=(
    ["vm.overcommit_memory"]="1"
    ["vm.swappiness"]="10"
    ["vm.dirty_ratio"]="60"
    ["vm.dirty_background_ratio"]="2"
    ["net.core.somaxconn"]="65535"
    ["net.core.netdev_max_backlog"]="65535"
    ["net.ipv4.tcp_max_syn_backlog"]="65535"
)

# Atur parameter secara langsung dan permanen
for param in "${!SYSCTL_PARAMS[@]}"; do
    value="${SYSCTL_PARAMS[$param]}"
    message " - $param = $value"
    sysctl -w "$param=$value"
    
    # Update sysctl.conf
    if grep -q "^$param" /etc/sysctl.conf; then
        sed -i "s/^$param.*/$param = $value/" /etc/sysctl.conf
    else
        echo "$param = $value" >> /etc/sysctl.conf
    fi
done

# Apply perubahan
sysctl -p

# ==========================================
# 6. Verifikasi Akhir
# ==========================================
message "\nVerifikasi hasil konfigurasi:"

message "\n1. Informasi swap:"
swapon --show || error "Swap tidak aktif"

message "\n2. Penggunaan memori:"
free -h

message "\n3. Partisi yang dibuat:"
lsblk -f "$TARGET_DEVICE"

message "\n4. Entry fstab:"
grep -E "swap|${TARGET_DEVICE}1|$UUID" /etc/fstab || warning "Entry swap tidak ditemukan di fstab"

# ==========================================
# 7. Selesai
# ==========================================
cat <<EOF

==========================================
KONFIGURASI SWAP SELESAI

Penting:
1. Device yang digunakan: $TARGET_DEVICE
2. UUID partisi swap: $UUID
3. Backup fstab: /etc/fstab.backup_*

Untuk memverifikasi setelah reboot:
- Jalankan: free -h; swapon --show

Jika ada masalah:
1. Cek partisi: lsblk -f $TARGET_DEVICE
2. Pulihkan fstab dari backup
3. Aktifkan swap manual: swapon ${TARGET_DEVICE}1
==========================================
EOF

message "Script selesai dijalankan"
