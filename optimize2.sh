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

# CPU Vendor Detection
detect_cpu_vendor() {
    if grep -q "Intel" /proc/cpuinfo; then
        echo "intel"
    elif grep -q "AMD" /proc/cpuinfo; then
        echo "amd"
    else
        echo "unknown"
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
    sysctl -p /etc/sysctl.d/99-kuzco.conf >/dev/null 2>&1
    success "Kernel parameters optimized"
else
    success "Kernel parameters already optimized (skipped)"
fi

# 3. CPU Vendor-Specific Optimization
status "Applying CPU vendor-specific optimizations..."

CPU_VENDOR=$(detect_cpu_vendor)

case $CPU_VENDOR in
    intel)
        # Intel optimizations
        status "Applying Intel-specific optimizations..."
        
        # Disable Intel P-State if exists
        if grep -q "intel_pstate" /proc/cmdline && ! grep -q "intel_pstate=disable" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&intel_pstate=disable /' /etc/default/grub
            if command -v update-grub >/dev/null; then
                update-grub
                success "Intel P-State disabled in GRUB"
            else
                warning "Could not update GRUB"
            fi
        fi
        
        # Disable Intel Turbo Boost if needed (uncomment if required)
        # if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        #     echo "1" > /sys/devices/system/cpu/intel_pstate/no_turbo
        #     success "Intel Turbo Boost disabled"
        # fi
        ;;
        
    amd)
        # AMD optimizations
        status "Applying AMD-specific optimizations..."
        
        # Disable Cool'n'Quiet
        if [ -f /sys/devices/system/cpu/cpufreq/ondemand/ignore_nice_load ]; then
            echo "1" > /sys/devices/system/cpu/cpufreq/ondemand/ignore_nice_load
            success "AMD Cool'n'Quiet disabled"
        fi
        
        # Zen architecture specific optimizations
        if lscpu | grep -q "znver"; then
            echo "vm.nr_hugepages = 1024" >> /etc/sysctl.d/99-kuzco.conf
            sysctl -p /etc/sysctl.d/99-kuzco.conf
            success "AMD Zen hugepages configured"
        fi
        ;;
        
    *)
        warning "Unknown CPU vendor - applying generic optimizations only"
        ;;
esac

# Apply common CPU governor setting
if [ -d /sys/devices/system/cpu/cpufreq ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f $cpu ] && echo "performance" > $cpu 2>/dev/null || true
    done
    success "CPU governor set to performance for all cores"
    
    # Make governor setting persistent
    if [ ! -f /etc/systemd/system/cpu-performance.service ]; then
        cat <<EOF > /etc/systemd/system/cpu-performance.service
[Unit]
Description=Set CPU Governor to Performance
After=syslog.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > \$cpu 2>/dev/null || true; done"

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable cpu-performance.service >/dev/null 2>&1 && \
            success "CPU governor persistence configured" || \
            warning "Failed to configure CPU governor persistence"
    fi
else
    warning "CPU frequency scaling not available - governor not set"
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
        systemctl disable --now "$service" >/dev/null 2>&1 && \
            success "Disabled $service" || \
            warning "Failed to disable $service"
    else
        success "$service already disabled (skipped)"
    fi
done

# 5. Final System Updates
status "Performing final system updates..."

if command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1 && \
    apt-get upgrade -y >/dev/null 2>&1 && \
    apt-get autoremove -y >/dev/null 2>&1 && \
    success "System updated (apt)" || \
    warning "System update failed (apt)"
elif command -v yum >/dev/null 2>&1; then
    yum update -y >/dev/null 2>&1 && \
    yum autoremove -y >/dev/null 2>&1 && \
    success "System updated (yum)" || \
    warning "System update failed (yum)"
elif command -v dnf >/dev/null 2>&1; then
    dnf update -y >/dev/null 2>&1 && \
    dnf autoremove -y >/dev/null 2>&1 && \
    success "System updated (dnf)" || \
    warning "System update failed (dnf)"
else
    warning "Package manager not found (skipping updates)"
fi

# 6. Apply All Changes
status "Applying all changes..."
systemctl daemon-reload >/dev/null 2>&1 && \
    success "Systemd daemon reloaded" || \
    warning "Failed to reload systemd daemon"

echo -e "\n${GREEN}✔ Optimization complete!${NC}"
echo -e "${YELLOW}Some changes require a reboot to take full effect.${NC}"
echo -e "Run this command to reboot: ${GREEN}reboot${NC}"

echo -e "\n${BLUE}Verification commands after reboot:${NC}"
echo "1. Check file limits: ${GREEN}ulimit -n${NC} (should show 1048576)"
echo "2. Check CPU governor: ${GREEN}cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor${NC} (should show 'performance')"
echo "3. Check CPU vendor settings:"
echo "   - Intel: ${GREEN}grep intel_pstate /proc/cmdline${NC} (should show 'intel_pstate=disable')"
echo "   - AMD: ${GREEN}cat /sys/devices/system/cpu/cpufreq/ondemand/ignore_nice_load${NC} (should show '1')"
echo "4. Check kernel settings: ${GREEN}sysctl -a | grep -e file_max -e swappiness -e hugepages${NC}"
echo "5. Check disabled services: ${GREEN}systemctl list-unit-files | grep -E 'avahi|cups|bluetooth|ModemManager|thermald'${NC}"
