#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
status() { echo -e "\n${BLUE}>>> $*${NC}" >&2; }
success() { echo -e "${GREEN}✓ $*${NC}" >&2; }
warning() { echo -e "${YELLOW}⚠ $*${NC}" >&2; }
error() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# Check root
if [ "$(id -u)" -ne 0 ]; then
    error "Script must be run as root. Use sudo or switch to root user."
fi

# Cloud Environment Detection
is_cloud() {
    if [ -f /sys/hypervisor/uuid ] || 
       [ -d /var/lib/cloud ] || 
       curl -s --max-time 2 http://169.254.169.254/ >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 1. System Limits Optimization
status "Optimizing system limits..."

# Configure system-wide limits
if ! grep -q "# Kuzco Optimization" /etc/security/limits.conf; then
    cat <<EOF >> /etc/security/limits.conf

# Kuzco Optimization
* soft nofile 1048576
* hard nofile 1048576
* soft nproc unlimited
* hard nproc unlimited
root soft nofile 1048576
root hard nofile 1048576
root soft nproc unlimited
root hard nproc unlimited
EOF
    success "Added limits to /etc/security/limits.conf"
else
    success "System limits already configured (skipped)"
fi

# Configure systemd limits
if [ ! -f /etc/systemd/system.conf.d/limits.conf ]; then
    mkdir -p /etc/systemd/system.conf.d/
    cat <<EOF > /etc/systemd/system.conf.d/limits.conf
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=infinity
EOF
    success "Added systemd limits configuration"
else
    success "Systemd limits already configured (skipped)"
fi

# Configure pam limits
if [ -f /etc/pam.d/common-session ] && ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
    success "Added PAM limits configuration"
elif [ ! -f /etc/pam.d/common-session ]; then
    warning "PAM common-session file not found"
else
    success "PAM limits already configured (skipped)"
fi

# 2. Kernel Parameters Optimization
status "Optimizing kernel parameters..."

if [ ! -f /etc/sysctl.d/99-kuzco.conf ]; then
    cat <<EOF > /etc/sysctl.d/99-kuzco.conf
# Network
net.core.somaxconn=8192
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# Memory
vm.swappiness=10
vm.dirty_ratio=60
vm.dirty_background_ratio=2

# File handles
fs.file-max=1048576
fs.nr_open=1048576

# Other
kernel.pid_max=4194304
EOF
    sysctl -p /etc/sysctl.d/99-kuzco.conf >/dev/null 2>&1 || warning "Failed to apply some kernel parameters"
    success "Kernel parameters optimized"
else
    success "Kernel parameters already optimized (skipped)"
fi

# 3. Cloud-Specific Optimizations
if is_cloud; then
    status "Applying cloud-specific optimizations..."
    
    # Virtual disk optimization
    for disk in /sys/block/vd* /sys/block/nvme*; do
        if [ -e "$disk/queue/scheduler" ]; then
            if echo "none" > "$disk/queue/scheduler" 2>/dev/null; then
                success "Optimized $(basename "$disk") I/O scheduler"
            else
                warning "Could not optimize $(basename "$disk") I/O scheduler"
            fi
        fi
        [ -e "$disk/queue/nr_requests" ] && echo "256" > "$disk/queue/nr_requests" 2>/dev/null
    done
    
    # Network optimization
    cat <<EOF > /etc/sysctl.d/99-cloud.conf
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_window_scaling=1
EOF
    sysctl -p /etc/sysctl.d/99-cloud.conf >/dev/null 2>&1 || warning "Some cloud network optimizations failed"
    success "Cloud network optimizations applied"
    
    warning "CPU frequency control not available in cloud environment"
else
    # Physical Server CPU Optimizations
    status "Applying CPU optimizations..."
    
    if [ -d /sys/devices/system/cpu/cpufreq ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -f "$cpu" ]; then
                if echo "performance" > "$cpu" 2>/dev/null; then
                    success "Set $(dirname "$cpu" | xargs basename) to performance governor"
                else
                    warning "Failed to set governor for $(dirname "$cpu" | xargs basename)"
                fi
            fi
        done
        
        if [ ! -f /etc/systemd/system/cpu-performance.service ]; then
            cat <<EOF > /etc/systemd/system/cpu-performance.service
[Unit]
Description=Set CPU Governor to Performance
After=syslog.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "[ -d /sys/devices/system/cpu/cpufreq ] && for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -f \$cpu ] && echo performance > \$cpu || true; done"

[Install]
WantedBy=multi-user.target
EOF
            if systemctl enable cpu-performance.service >/dev/null 2>&1; then
                success "CPU governor persistence configured"
            else
                warning "Failed to configure CPU governor persistence"
            fi
        fi
    else
        warning "CPU frequency scaling not available"
    fi
fi

# 4. Disable Unnecessary Services
status "Disabling unnecessary services..."

services_to_disable=(
    avahi-daemon
    cups
    bluetooth
    ModemManager
    thermald
)

for service in "${services_to_disable[@]}"; do
    if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
        if systemctl disable --now "$service" >/dev/null 2>&1; then
            success "Disabled $service"
        else
            warning "Failed to disable $service"
        fi
    else
        success "$service already disabled (skipped)"
    fi
done

# 5. Final System Updates
status "Performing final system updates..."

if command -v apt-get >/dev/null 2>&1; then
    if apt-get update >/dev/null 2>&1 && \
       apt-get upgrade -y >/dev/null 2>&1 && \
       apt-get autoremove -y >/dev/null 2>&1; then
        success "System updated (apt)"
    else
        warning "System update failed (apt)"
    fi
elif command -v yum >/dev/null 2>&1; then
    if yum update -y >/dev/null 2>&1 && \
       yum autoremove -y >/dev/null 2>&1; then
        success "System updated (yum)"
    else
        warning "System update failed (yum)"
    fi
elif command -v dnf >/dev/null 2>&1; then
    if dnf update -y >/dev/null 2>&1 && \
       dnf autoremove -y >/dev/null 2>&1; then
        success "System updated (dnf)"
    else
        warning "System update failed (dnf)"
    fi
else
    warning "Package manager not found (skipping updates)"
fi

# 6. Apply All Changes
status "Applying all changes..."
if systemctl daemon-reload >/dev/null 2>&1; then
    success "Systemd daemon reloaded"
else
    warning "Failed to reload systemd daemon"
fi

echo -e "\n${GREEN}✔ Optimization complete!${NC}" >&2
echo -e "${YELLOW}Some changes require a reboot to take full effect.${NC}" >&2
echo -e "Run this command to reboot: ${GREEN}reboot${NC}" >&2

echo -e "\n${BLUE}Verification commands:${NC}" >&2
echo "1. File limits: ${GREEN}ulimit -n${NC} (should show 1048576)" >&2
echo "2. Kernel settings: ${GREEN}sysctl -a | grep -e file_max -e swappiness -e dirty_${NC}" >&2
if is_cloud; then
    echo "3. Cloud disk settings: ${GREEN}for d in /sys/block/vd*/queue/scheduler /sys/block/nvme*/queue/scheduler; do echo \"\$d: \$(cat \$d)\"; done${NC}" >&2
else
    echo "3. CPU governor: ${GREEN}cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor${NC}" >&2
fi
echo "4. Services: ${GREEN}systemctl list-unit-files | grep -E 'avahi|cups|bluetooth|ModemManager|thermald'${NC}" >&2

exit 0
