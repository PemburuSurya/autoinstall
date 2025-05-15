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
# =============================================
# 4. ETHEREUM-SPECIFIC OPTIMIZATIONS
# =============================================
status "Applying Ethereum-specific optimizations..."

# 4.1 Create dedicated users
if ! id geth &>/dev/null; then
    useradd -m -s /bin/bash -U geth
    usermod -aG eth geth
fi

if ! id beacon &>/dev/null; then
    useradd -m -s /bin/bash -U beacon
    usermod -aG eth beacon
fi

# 4.2 JWT secret setup
mkdir -p /var/lib/secrets
chgrp -R eth /var/lib/secrets
chmod 750 /var/lib/secrets
if [ ! -f /var/lib/secrets/jwt.hex ]; then
    openssl rand -hex 32 | tr -d '\n' > /var/lib/secrets/jwt.hex
    chown root:eth /var/lib/secrets/jwt.hex
    chmod 640 /var/lib/secrets/jwt.hex
fi

# =============================================
# 5. FINAL SYSTEM TWEAKS
# =============================================
status "Applying final system tweaks..."

# 5.1 Disable THP (Transparent HugePages)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 5.2 Increase kernel pid max
echo 4194304 > /proc/sys/kernel/pid_max

# 5.3 Update system
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove >/dev/null
apt-get clean >/dev/null

# =============================================
# 6. SERVICE CONFIGURATIONS (GETH + PRYSM)
# =============================================
status "Configuring Geth and Prysm services..."

# 6.1 Geth service (64GB RAM optimized)
cat <<EOF > /etc/systemd/system/geth.service
[Unit]
Description=Geth Execution Client (Sepolia)
After=network.target
Wants=network.target

[Service]
User=geth
Group=geth
Type=simple
Restart=always
RestartSec=5s
OOMScoreAdjust=-1000
Nice=-15
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50
Environment="GOGC=20"
Environment="GOMAXPROCS=8"

# 64GB RAM optimized flags
ExecStart=/usr/bin/geth \\
  --sepolia \\
  --http \\
  --http.addr 0.0.0.0 \\
  --http.port 8545 \\
  --http.api eth,net,engine,admin \\
  --authrpc.addr 127.0.0.1 \\
  --authrpc.port 8551 \\
  --http.corsdomain "*" \\
  --http.vhosts "*" \\
  --datadir /home/geth/geth \\
  --authrpc.jwtsecret /var/lib/secrets/jwt.hex \\
  --cache 20480 \\
  --maxpeers 100 \\
  --txlookuplimit 0 \\
  --syncmode snap \\
  --blobpool.datacap 1073741824 \\
  --gcmode archive \\
  --metrics \\
  --metrics.addr 0.0.0.0 \\
  --metrics.port 6060

[Install]
WantedBy=multi-user.target
EOF

# 6.2 Prysm beacon service (64GB RAM optimized)
cat <<EOF > /etc/systemd/system/beacon.service
[Unit]
Description=Prysm Beacon Chain
After=network.target geth.service
Wants=network.target geth.service

[Service]
User=beacon
Group=beacon
Type=simple
Restart=always
RestartSec=5s
OOMScoreAdjust=-1000
Nice=-15
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50
Environment="JAVA_OPTS=-Xmx48g -Xms24g -XX:MaxDirectMemorySize=8g"
WorkingDirectory=/home/beacon

# 64GB RAM optimized flags
ExecStart=/home/beacon/bin/prysm.sh beacon-chain \\
  --sepolia \\
  --http-web3provider http://127.0.0.1:8551 \\
  --datadir /home/beacon/beacon \\
  --rpc-host 0.0.0.0 \\
  --rpc-port 4000 \\
  --grpc-gateway-host 0.0.0.0 \\
  --grpc-gateway-port 3500 \\
  --execution-endpoint http://127.0.0.1:8551 \\
  --jwt-secret /var/lib/secrets/jwt.hex \\
  --checkpoint-sync-url=https://checkpoint-sync.sepolia.ethpandaops.io/ \\
  --genesis-beacon-api-url=https://checkpoint-sync.sepolia.ethpandaops.io/ \\
  --accept-terms-of-use \\
  --p2p-max-peers 100 \\
  --max-goroutines 1024 \\
  --block-batch-limit 128 \\
  --block-batch-limit-burst-factor 4 \\
  --enable-debug-rpc-endpoints \\
  --subscribe-all-subnets \\
  --historical-slasher-node \\
  --slots-per-archive-point 2048 \\
  --enable-archive

[Install]
WantedBy=multi-user.target
EOF
# =============================================
# 8. FINALIZATION
# =============================================
status "Finalizing optimizations..."

systemctl daemon-reload
ldconfig

echo -e "\n${GREEN}✔ Optimization complete for 64GB RAM Ethereum node!${NC}"
echo -e "${YELLOW}REQUIRED: Reboot the system to apply all changes${NC}\n"

echo -e "${BLUE}Post-reboot verification commands:${NC}"
echo "1. Check limits: ${GREEN}su - geth -c 'ulimit -a'${NC}"
echo "2. Check Geth: ${GREEN}systemctl status geth${NC}"
echo "3. Check Prysm: ${GREEN}systemctl status beacon${NC}"
echo "4. Monitor logs: ${GREEN}journalctl -fu geth -o cat${NC}"
echo "5. Network stats: ${GREEN}ss -tulnp | grep -E '8545|8551|3500|4000'${NC}"
echo -e "\n${GREEN}Recommended: Install monitoring tools (htop, nvtop, netdata)${NC}"
