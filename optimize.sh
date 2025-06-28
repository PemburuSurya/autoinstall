#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
status() { echo -e "\n${BLUE}>>> $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; exit 1; }

# Check root
if [ "$(id -u)" -ne 0 ]; then
    error "Script must be run as root. Use sudo or switch to root user."
fi

# Check system
if [ ! -f /etc/os-release ]; then
    error "Unsupported Linux distribution"
fi

# 1. System Limits Optimization
status "Optimizing system limits..."

# Configure system-wide limits
if ! grep -q "# Ethereum Node Optimization" /etc/security/limits.conf; then
    cat <<EOF >> /etc/security/limits.conf

# Ethereum Node Optimization
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65536
* hard nproc 65536
* soft memlock unlimited
* hard memlock unlimited
root soft nofile 1048576
root hard nofile 1048576
root soft nproc unlimited
root hard nproc unlimited
root soft memlock unlimited
root hard memlock unlimited
EOF
    success "Added limits to /etc/security/limits.conf"
else
    success "System limits already configured (skipped)"
fi

# Configure systemd limits
mkdir -p /etc/systemd/system.conf.d/
cat <<EOF > /etc/systemd/system.conf.d/limits.conf
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65536
DefaultLimitMEMLOCK=infinity
EOF

# Configure pam limits
if [ -f /etc/pam.d/common-session ] && ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

# 2. Kernel Parameters Optimization
status "Optimizing kernel parameters..."

cat <<EOF > /etc/sysctl.d/99-ethereum.conf
# Network
net.core.somaxconn=8192
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=16384
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fastopen=3
net.ipv4.ip_local_port_range=1024 65535

# Memory
vm.swappiness=1
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.overcommit_memory=1
vm.overcommit_ratio=100
vm.max_map_count=262144

# File handles
fs.file-max=2097152
fs.nr_open=2097152
fs.aio-max-nr=1048576

# Connection tracking
net.netfilter.nf_conntrack_max=1000000
net.nf_conntrack_max=1000000

# Other
kernel.pid_max=4194304
kernel.threads-max=999999
EOF

sysctl -p /etc/sysctl.d/99-ethereum.conf >/dev/null 2>&1

# 3. Ethereum-Specific Optimizations
status "Applying Ethereum-specific optimizations..."

# CPU Performance Governor
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
fi

# Disk I/O Scheduler
for disk in /sys/block/sd*; do
    if [ -e "$disk/queue/scheduler" ]; then
        echo "deadline" > "$disk/queue/scheduler" 2>/dev/null || \
        echo "none" > "$disk/queue/scheduler" 2>/dev/null
    fi
done

# Time Synchronization (critical for consensus)
timedatectl set-ntp true
systemctl restart systemd-timesyncd

# 4. Disable Unnecessary Services
status "Disabling unnecessary services..."

services_to_disable=(
    avahi-daemon
    cups
    cups-browsed
    bluetooth
    ModemManager
    whoopsie
    apport
    apt-daily
    apt-daily-upgrade
    unattended-upgrades
)

for service in "${services_to_disable[@]}"; do
    if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
        systemctl disable --now "$service" >/dev/null 2>&1 && \
            success "Disabled $service" || \
            warning "Failed to disable $service"
    fi
done

# 5. Filesystem Optimizations
status "Configuring filesystem optimizations..."

# Add noatime to fstab
if ! grep -q "noatime" /etc/fstab; then
    sed -i 's/\(ext4.*\)defaults/\1defaults,noatime,nodiratime,errors=remount-ro/' /etc/fstab
fi

# Increase inotify watches (useful for Geth)
echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.d/99-ethereum.conf

# 6. Network Time Protocol (NTP) Configuration
status "Configuring NTP..."

cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=ntp.ubuntu.com
RootDistanceMaxSec=1
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF

systemctl restart systemd-timesyncd

# 7. Apply All Changes
status "Applying all changes..."
sysctl --system >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1

# 8. Verification
status "Verification..."
echo -e "\n${GREEN}✔ Optimization complete!${NC}"
echo -e "\n${BLUE}=== Verification Commands ===${NC}"
echo -e "1. Limits: ${GREEN}ulimit -a${NC}"
echo -e "2. Kernel: ${GREEN}sysctl net.core.somaxconn vm.swappiness fs.file-max${NC}"
echo -e "3. CPU Gov: ${GREEN}cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor${NC}"
echo -e "4. Time: ${GREEN}timedatectl status${NC}"
echo -e "5. Services: ${GREEN}systemctl list-unit-files | grep -E 'avahi|cups|bluetooth|ModemManager'${NC}"

echo -e "\n${YELLOW}⚠ Some changes require a reboot to take full effect.${NC}"
echo -e "Run: ${GREEN}reboot${NC} then verify with above commands.\n"

echo -e "${BLUE}For Ethereum node monitoring consider installing:${NC}"
echo -e "1. Prometheus: ${GREEN}apt install prometheus${NC}"
echo -e "2. Node Exporter: ${GREEN}apt install prometheus-node-exporter${NC}"
echo -e "3. Grafana: ${GREEN}apt install grafana${NC}"
