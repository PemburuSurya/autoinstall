#!/bin/bash
set -euo pipefail  # Strict error handling

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

# Cek distribusi Linux
if ! command -v lsb_release >/dev/null 2>&1; then
    warning "lsb_release tidak ditemukan, asumsikan sistem kompatibel"
else
    message "Sistem terdeteksi: $(lsb_release -ds)"
fi

# ==========================================
# 2. Konfigurasi Awal
# ==========================================
SWAPFILE="/swapfile"
SWAP_SIZE="10G"  # Ukuran swapfile (sesuaikan dengan kebutuhan)
MIN_RAM=2  # Minimum RAM dalam GB untuk penentuan swappiness

# Hitung swappiness dinamis berdasarkan RAM
TOTAL_RAM=$(free -g | awk '/Mem:/ {print $2}')
if [[ $TOTAL_RAM -lt $MIN_RAM ]]; then
    SWAPPINESS=30
else
    SWAPPINESS=10
fi

message "\nKonfigurasi yang akan diterapkan:"
echo " - Lokasi swapfile: $SWAPFILE"
echo " - Ukuran swapfile: $SWAP_SIZE"
echo " - Nilai swappiness: $SWAPPINESS (RAM: ${TOTAL_RAM}GB)"
echo " - Parameter kernel lainnya akan dioptimasi"

read -rp "Lanjutkan setup swapfile? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    message "Operasi dibatalkan"
    exit 0
fi

# ==========================================
# 3. Setup Swapfile
# ==========================================

# Nonaktifkan semua swap
message "\nMenonaktifkan swap yang aktif..."
swapoff -a || warning "Gagal menonaktifkan beberapa swap"

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

# Set permission yang aman
chmod 600 "$SWAPFILE" || error "Gagal mengatur permission swapfile"

# Format sebagai swap
message "Memformat swapfile..."
mkswap "$SWAPFILE" || error "Gagal memformat swapfile"

# Aktifkan swap
message "Mengaktifkan swapfile..."
swapon "$SWAPFILE" || error "Gagal mengaktifkan swapfile"

# ==========================================
# 4. Konfigurasi Permanen
# ==========================================

# Backup fstab
message "\nMembackup /etc/fstab..."
cp /etc/fstab "/etc/fstab.backup_$(date +%Y%m%d_%H%M%S)"

# Update fstab
message "Memperbarui /etc/fstab..."
if grep -q "$SWAPFILE" /etc/fstab; then
    # Hapus entry yang ada
    grep -v "$SWAPFILE" /etc/fstab > /tmp/fstab.tmp
    mv /tmp/fstab.tmp /etc/fstab
fi

echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab

# ==========================================
# 5. Optimasi Kernel
# ==========================================
message "\nMengoptimasi parameter kernel..."

# Daftar parameter kernel
declare -A SYSCTL_PARAMS=(
    ["vm.overcommit_memory"]="1"
    ["vm.swappiness"]="$SWAPPINESS"
    ["vm.dirty_ratio"]="60"
    ["vm.dirty_background_ratio"]="2"
    ["net.core.somaxconn"]="65535"
    ["net.core.netdev_max_backlog"]="65535"
    ["net.ipv4.tcp_max_syn_backlog"]="65535"
)

# Atur parameter
for param in "${!SYSCTL_PARAMS[@]}"; do
    value="${SYSCTL_PARAMS[$param]}"
    message " - $param = $value"
    
    # Atur untuk sesi saat ini
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

message "\n3. Swapfile:"
ls -lh "$SWAPFILE"

message "\n4. Parameter kernel:"
for param in "${!SYSCTL_PARAMS[@]}"; do
    echo "$param = $(sysctl -n $param)"
done

# ==========================================
# 7. Selesai
# ==========================================
cat <<EOF

==========================================
KONFIGURASI SWAPFILE SELESAI

Penting:
1. Lokasi swapfile: $SWAPFILE
2. Ukuran swapfile: $SWAP_SIZE
3. Nilai swappiness: $SWAPPINESS (disesuaikan dengan RAM ${TOTAL_RAM}GB)
4. Backup fstab: /etc/fstab.backup_*

Untuk memverifikasi setelah reboot:
- Jalankan: free -h; swapon --show

Jika ada masalah:
1. Nonaktifkan swap: swapoff -a
2. Hapus swapfile: rm -f $SWAPFILE
3. Pulihkan fstab dari backup
==========================================
EOF

message "Script selesai dijalankan"
