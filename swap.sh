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
message "Memulai konfigurasi swapfile"

# Cek root
if [[ $EUID -ne 0 ]]; then
    error "Script harus dijalankan sebagai root"
fi

# Skip if already optimized by optimize_fixed.sh
if [ -f /etc/sysctl.d/99-kuzco.conf ]; then
    message "Deteksi sistem sudah dioptimasi oleh optimize_fixed.sh"
    message "Script ini hanya akan mengatur swapfile saja"
fi

# ==========================================
# 2. Konfigurasi Swapfile
# ==========================================
SWAPFILE="/swapfile"
SWAP_SIZE="16G"  # Ukuran swapfile

# Hitung kebutuhan swap dinamis
TOTAL_RAM=$(free -g | awk '/Mem:/ {print $2}')
if [[ $TOTAL_RAM -lt 2 ]]; then
    SWAP_SIZE="4G"
elif [[ $TOTAL_RAM -lt 8 ]]; then
    SWAP_SIZE="8G"
fi

message "\nKonfigurasi swapfile:"
echo " - Lokasi: $SWAPFILE"
echo " - Ukuran: $SWAP_SIZE (RAM: ${TOTAL_RAM}GB)"

read -rp "Lanjutkan setup swapfile? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    message "Operasi dibatalkan"
    exit 0
fi

# ==========================================
# 3. Setup Swapfile
# ==========================================

# Nonaktifkan swap yang ada
message "\nMenonaktifkan swap yang aktif..."
swapoff -a 2>/dev/null || warning "Tidak ada swap aktif"

# Hapus swapfile lama jika ada
if [[ -f "$SWAPFILE" ]]; then
    message "Menghapus swapfile lama..."
    rm -f "$SWAPFILE" || error "Gagal menghapus swapfile lama"
fi

# Buat swapfile baru
message "Membuat swapfile baru ($SWAP_SIZE)..."
if ! fallocate -l "$SWAP_SIZE" "$SWAPFILE"; then
    warning "fallocate gagal, mencoba dd..."
    dd if=/dev/zero of="$SWAPFILE" bs=1G count=${SWAP_SIZE/G} status=progress || 
        error "Gagal membuat swapfile"
fi

# Set permission
chmod 600 "$SWAPFILE" || error "Gagal mengatur permission swapfile"

# Format sebagai swap
mkswap "$SWAPFILE" || error "Gagal memformat swapfile"
swapon "$SWAPFILE" || error "Gagal mengaktifkan swapfile"

# ==========================================
# 4. Konfigurasi Permanen
# ==========================================

# Backup fstab
message "\nMembackup /etc/fstab..."
cp /etc/fstab "/etc/fstab.backup_$(date +%Y%m%d_%H%M%S)"

# Update fstab
if ! grep -q "^$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    message "Swapfile ditambahkan ke /etc/fstab"
else
    message "Swapfile sudah terdaftar di /etc/fstab"
fi

# ==========================================
# 5. Verifikasi
# ==========================================
message "\nVerifikasi hasil:"

message "1. Status swap:"
swapon --show || error "Swap tidak aktif"

message "\n2. Penggunaan memori:"
free -h

message "\n3. Detail swapfile:"
ls -lh "$SWAPFILE"

# ==========================================
# 6. Selesai
# ==========================================
cat <<EOF

==========================================
KONFIGURASI SWAPFILE SELESAI

Detail:
- Lokasi: $SWAPFILE
- Ukuran: $SWAP_SIZE
- RAM: ${TOTAL_RAM}GB

Untuk verifikasi:
free -h
swapon --show

Jika ada masalah:
1. Nonaktifkan: swapoff -a
2. Hapus: rm -f $SWAPFILE
3. Pulihkan fstab dari backup
==========================================
EOF

message "Script swapfile selesai dijalankan"
