#!/bin/bash
set -e

# =============================================
# CONFIGURATION
# =============================================
# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ethereum node user (change if needed)
ETH_USER="ethereum"
ETH_GROUP="ethereum"

# =============================================
# FUNCTIONS
# =============================================
status() { echo -e "\n${BLUE}>>> $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; exit 1; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Script must be run as root. Use sudo or switch to root user."
    fi
}

# =============================================
# 1. INITIAL SETUP
# =============================================
check_root

# Check kernel version
KERNEL_VER=$(uname -r)
status "Detected kernel version: $KERNEL_VER"
if [[ $KERNEL_VER =~ ^3\. ]]; then
    warning "Old kernel detected (v3.x) - some optimizations may not be available"
fi

# =============================================
# 2. SYSTEM PREPARATION
# =============================================
status "Preparing system for Ethereum node optimization..."

# Update system first
status "Updating system packages..."
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove >/dev/null
apt-get clean >/dev/null

# Install basic dependencies
status "Installing basic dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git jq bc pv htop iotop iftop sysstat \
    libssl-dev cmake build-essential clang >/dev/null

# =============================================
# 3. SYSTEM LIMITS & KERNEL OPTIMIZATION
# =============================================
status "Optimizing system limits and kernel parameters..."

# 3.1 Create ethereum user if not exists
if ! id "$ETH_USER" &>/dev/null; then
    useradd -r -s /bin/false -m -d "/home/$ETH_USER" "$ETH_USER"
    success "Created user: $ETH_USER"
fi

# 3.2 System-wide limits
cat <<EOF > /etc/security/limits.d/99-ethereum.conf
# Ethereum node optimization
* soft nofile 1048576
* hard nofile 1048576
* soft memlock unlimited
* hard memlock unlimited
* soft nproc 65536
* hard nproc 65536
* soft stack unlimited
* hard stack unlimited
EOF

# 3.3 Systemd limits
mkdir -p /etc/systemd/system.conf.d/
cat <<EOF > /etc/systemd/system.conf.d/ethereum-limits.conf
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65536
DefaultLimitMEMLOCK=infinity
DefaultLimitSTACK=infinity
EOF

# 3.4 Kernel parameters (optimized for high throughput)
cat <<EOF > /etc/sysctl.d/99-ethereum.conf
# Network
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=32768
net.ipv4.tcp_fastopen=3
net.core.netdev_max_backlog=32768
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535

# Memory
vm.swappiness=1
vm.dirty_ratio=5
vm.dirty_background_ratio=1
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.overcommit_memory=1
vm.overcommit_ratio=99
vm.max_map_count=1048576
vm.min_free_kbytes=1048576

# File system
fs.file-max=1048576
fs.nr_open=1048576
fs.aio-max-nr=1048576
fs.inotify.max_user_watches=524288

# ETH-specific
kernel.pid_max=4194304
kernel.threads-max=999999
EOF

# Conditionally add sched_migration_cost_ns if supported
if [ -e /proc/sys/kernel/sched_migration_cost_ns ]; then
    echo "kernel.sched_migration_cost_ns=5000000" >> /etc/sysctl.d/99-ethereum.conf
fi

# Apply kernel settings
if ! sysctl -p /etc/sysctl.d/99-ethereum.conf >/dev/null 2>&1; then
    warning "Some sysctl parameters could not be applied (expected on some kernels)"
else
    success "Kernel parameters applied"
fi

# =============================================
# 4. DISABLE UNNECESSARY SERVICES
# =============================================
status "Disabling unnecessary services..."

services_to_disable=(
    avahi-daemon
    cups
    bluetooth
    ModemManager
    apt-daily
    apt-daily-upgrade
    unattended-upgrades
)

for service in "${services_to_disable[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        systemctl disable --now "$service" >/dev/null
        success "Disabled $service"
    else
        warning "$service already disabled"
    fi
done

# =============================================
# 5. CPU & DISK OPTIMIZATION
# =============================================
status "Optimizing CPU and disk performance..."

# 5.1 Set CPU governor to performance
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    success "Set CPU to performance mode"
else
    warning "Cannot set CPU governor (cloud VPS detected)"
fi

# 5.2 SSD/NVMe tuning
if lsblk -d -o rota | grep -q '0'; then
    cat <<EOF > /etc/udev/rules.d/60-ssd.rules
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none", ATTR{queue/nr_requests}="256", ATTR{queue/read_ahead_kb}="4096"
EOF
    udevadm trigger
    success "Applied SSD/NVMe optimizations"
fi

# 5.3 Disable Transparent HugePages
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
cat <<EOF >> /etc/rc.local
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOF
chmod +x /etc/rc.local

# =============================================
# 6. FINAL SYSTEM TWEAKS
# =============================================
status "Applying final system tweaks..."

# 6.1 Increase journald storage
mkdir -p /etc/systemd/journald.conf.d
cat <<EOF > /etc/systemd/journald.conf.d/99-ethereum.conf
[Journal]
SystemMaxUse=4G
RuntimeMaxUse=4G
EOF

# 6.2 Enable NTP time sync
timedatectl set-ntp true
systemctl restart systemd-timesyncd

# 6.3 Reload all changes
systemctl daemon-reload
systemctl restart systemd-journald

# =============================================
# COMPLETION
# =============================================
echo -e "\n${GREEN}✔ System optimization complete!${NC}"
echo -e "${YELLOW}REQUIRED: You must reboot the system to apply all changes${NC}\n"

echo -e "${BLUE}Verification commands after reboot:${NC}"
echo "1. Check limits: ${GREEN}ulimit -n${NC} (should show 1048576)"
echo "2. Check kernel settings: ${GREEN}sysctl net.core.somaxconn vm.swappiness${NC}"
echo "3. Check CPU governor: ${GREEN}cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor${NC}"
echo "4. Check hugepages: ${GREEN}cat /sys/kernel/mm/transparent_hugepage/enabled${NC}"

echo -e "\n${RED}Important:${NC} Run this command to reboot: ${GREEN}reboot${NC}"
echo -e "\n${BLUE}After reboot, you can proceed with Ethereum client installation.${NC}"
