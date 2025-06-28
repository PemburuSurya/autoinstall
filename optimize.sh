#!/bin/bash
set -e

# ==================== CONFIGURASI ====================
MAX_OPEN_FILES=1048576          # 1 juta file descriptors
SWAPINESS=5                     # Lebih rendah dari default (60)
DIRTY_RATIO=40                  # Balance between IO dan memory
TCP_MAX_SYN_BACKLOG=16384       # Untuk high traffic
KERNEL_PID_MAX=4194304          # Untuk high concurrency

# ==================== FUNGSI ====================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
status() { echo -e "\n${BLUE}>>> $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; exit 1; }

# ==================== OPTIMASI SISTEM ====================
optimize_limits() {
    status "Mengoptimasi system limits..."
    
    # System-wide limits
    cat > /etc/security/limits.d/99-kuzco.conf <<EOF
* soft nofile $MAX_OPEN_FILES
* hard nofile $MAX_OPEN_FILES
* soft nproc unlimited
* hard nproc unlimited
* soft memlock unlimited
* hard memlock unlimited
EOF

    # Systemd service limits
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/limits.conf <<EOF
[Manager]
DefaultLimitNOFILE=$MAX_OPEN_FILES
DefaultLimitNPROC=infinity
DefaultLimitMEMLOCK=infinity
EOF

    # Kernel limits
    cat > /etc/sysctl.d/99-kuzco.conf <<EOF
# Network
net.core.somaxconn=$TCP_MAX_SYN_BACKLOG
net.ipv4.tcp_max_syn_backlog=$TCP_MAX_SYN_BACKLOG
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# Memory
vm.swappiness=$SWAPINESS
vm.dirty_ratio=$DIRTY_RATIO
vm.dirty_background_ratio=5

# File
fs.file-max=$MAX_OPEN_FILES
fs.nr_open=$MAX_OPEN_FILES

# Process
kernel.pid_max=$KERNEL_PID_MAX
kernel.threads-max=$KERNEL_PID_MAX
vm.max_map_count=262144
EOF

    sysctl -p /etc/sysctl.d/99-kuzco.conf >/dev/null
    ulimit -n $MAX_OPEN_FILES
    success "Limit optimasi selesai"
}

# ==================== OPTIMASI SERVICE ====================
optimize_services() {
    status "Mengoptimasi system services..."
    
    local services=(
        avahi-daemon cups bluetooth ModemManager
        NetworkManager-wait-online systemd-networkd-wait-online
    )
    
    for srv in "${services[@]}"; do
        if systemctl is-enabled "$srv" &>/dev/null; then
            systemctl disable --now "$srv" && \
            success "Disabled $srv" || \
            warning "Gagal disable $srv"
        fi
    done
    
    # Optimasi journald
    cat > /etc/systemd/journald.conf.d/99-kuzco.conf <<EOF
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxFileSec=3day
EOF
    
    systemctl restart systemd-journald
    success "Service optimasi selesai"
}

# ==================== OPTIMASI SCHEDULER ====================
optimize_scheduler() {
    status "Mengoptimasi task scheduler..."
    
    # CPU scheduler
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$governor"
    done
    
    # Disk scheduler
    for disk in /sys/block/sd*/queue/scheduler; do
        echo "none" > "$disk" 2>/dev/null || \
        echo "kyber" > "$disk" 2>/dev/null || \
        echo "mq-deadline" > "$disk"
    done
    
    # VM scheduler
    echo 1000 > /proc/sys/vm/dirty_writeback_centisecs
    echo 50 > /proc/sys/vm/vfs_cache_pressure
    
    success "Scheduler optimasi selesai"
}

# ==================== MAIN EXECUTION ====================
main() {
    # Validasi root
    [[ $(id -u) -ne 0 ]] && error "Harus run sebagai root"
    
    optimize_limits
    optimize_services
    optimize_scheduler
    
    # Final touch
    status "Verifikasi optimasi:"
    echo -e "${GREEN}Open files: $(ulimit -n) (harus $MAX_OPEN_FILES)${NC}"
    echo -e "${GREEN}CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)${NC}"
    
    echo -e "\n${GREEN}✔ OPTIMASI SELESAI!${NC}"
    echo -e "${YELLOW}Beberapa perubahan membutuhkan reboot untuk efektif${NC}"
    echo -e "Reboot dengan: ${GREEN}reboot now${NC}"
}

main "$@"
