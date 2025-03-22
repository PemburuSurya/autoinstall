#!/bin/bash

# Warna untuk output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variabel konfigurasi
REPO_URL="https://github.com/Layer-Edge/light-node.git"
GRPC_URL="grpc.testnet.layeredge.io:9090"
CONTRACT_ADDR="cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709"
ZK_PROVER_URL="http://127.0.0.1:3001"
POINTS_API="http://127.0.0.1:8080"
SERVICE_NAME="layer-edge-light-node"
LOG_FILE="/var/log/layer-edge-light-node.log"

# Fungsi untuk memeriksa apakah perintah berhasil dijalankan
function check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Gagal menjalankan perintah sebelumnya.${NC}"
        exit 1
    fi
}

# Fungsi untuk menginstal dependensi
function install_dependencies() {
    echo -e "${GREEN}Menginstal dependensi (Go, Rust, Risc0)...${NC}"
    sudo apt update && sudo apt install -y curl build-essential git pkg-config libssl-dev
    check_command

    # Install Go
    if ! command -v go &> /dev/null; then
        echo -e "${GREEN}Menginstal Go...${NC}"
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
        source .bash_profile
    fi

    # Install Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${GREEN}Menginstal Rust...${NC}"
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source "$HOME/.cargo/env"
        check_command
    fi

    # Install Risc0
    echo -e "${GREEN}Menginstal Risc0...${NC}"
    curl -L https://risczero.com/install | bash
    export PATH="$HOME/.risc0/bin:$PATH"
    rzup install
    check_command
}

# Fungsi untuk clone repository
function clone_repo() {
    echo -e "${GREEN}Mengclone repository Light Node...${NC}"
    cd ~ || exit
    rm -rf light-node
    git clone "$REPO_URL"
    check_command
    cd light-node || exit
}

# Fungsi untuk setup environment variables
function setup_env() {
    echo -e "${GREEN}Menyiapkan file .env...${NC}"
    read -rsp "Masukkan PRIVATE_KEY: " PRIVATE_KEY
    echo ""

    cat <<EOF > .env
GRPC_URL=$GRPC_URL
CONTRACT_ADDR=$CONTRACT_ADDR
ZK_PROVER_URL=$ZK_PROVER_URL
API_REQUEST_TIMEOUT=100
POINTS_API=$POINTS_API
PRIVATE_KEY='$PRIVATE_KEY'
EOF

    echo -e "${GREEN}File .env berhasil dibuat.${NC}"
}

# Fungsi untuk memulai Risc0 Merkle Service
function start_merkle_service() {
    echo -e "${GREEN}Memulai Risc0 Merkle Service...${NC}"
    cd ~/light-node/risc0-merkle-service || exit
    cargo build
    check_command
    cargo run &
    echo -e "${GREEN}Risc0 Merkle Service berjalan di latar belakang.${NC}"
}

# Fungsi untuk membangun Light Node
function build_light_node() {
    echo -e "${GREEN}Membangun Light Node...${NC}"
    cd ~/light-node || exit
    go build
    check_command
    echo -e "${GREEN}Light Node berhasil dibangun.${NC}"
}

# Fungsi untuk membuat systemd service
function create_systemd_service() {
    echo -e "${GREEN}Membuat systemd service...${NC}"
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=LayerEdge Light Node
After=network.target

[Service]
User=root
WorkingDirectory=/root/light-node
ExecStart=/root/light-node/light-node
Restart=always
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}
    sudo systemctl start ${SERVICE_NAME}
    check_command
    echo -e "${GREEN}Systemd service berhasil dibuat dan dijalankan.${NC}"
}

# Fungsi untuk memeriksa status service
function check_service_status() {
    echo -e "${GREEN}Memeriksa status service...${NC}"
    sudo systemctl status ${SERVICE_NAME}
}

# Fungsi untuk melihat log service
function view_service_logs() {
    echo -e "${GREEN}Menampilkan log service...${NC}"
    sudo tail -f $LOG_FILE
}

# Fungsi untuk menghentikan service
function stop_service() {
    echo -e "${GREEN}Menghentikan service...${NC}"
    sudo systemctl stop ${SERVICE_NAME}
    check_command
}

# Fungsi untuk uninstall
function uninstall() {
    echo -e "${GREEN}Menghapus instalasi Light Node...${NC}"
    sudo systemctl stop ${SERVICE_NAME}
    sudo systemctl disable ${SERVICE_NAME}
    sudo rm /etc/systemd/system/${SERVICE_NAME}.service
    sudo rm -rf ~/light-node
    sudo rm -rf ~/.risc0
    sudo rm -rf ~/.cargo
    sudo rm -f $LOG_FILE
    sudo systemctl daemon-reload
    echo -e "${GREEN}Uninstall selesai.${NC}"
}

# Fungsi utama
function main() {
    echo -e "${GREEN}=== LayerEdge Light Node Installer ===${NC}"
    echo "1. Install Dependencies"
    echo "2. Clone Repository"
    echo "3. Setup .env File"
    echo "4. Start Merkle Service"
    echo "5. Build & Start Light Node (Systemd)"
    echo "6. Stop Service"
    echo "7. View Logs"
    echo "8. Check Node Status"
    echo "9. Uninstall"
    echo "10. Exit"
    read -rp "Pilih opsi [1-10]: " choice

    case $choice in
        1) install_dependencies ;;
        2) clone_repo ;;
        3) setup_env ;;
        4) start_merkle_service ;;
        5) build_light_node && create_systemd_service ;;
        6) stop_service ;;
        7) view_service_logs ;;
        8) check_service_status ;;
        9) uninstall ;;
        10) echo "Keluar..."; exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
    esac
}

# Jalankan fungsi utama
while true; do
    main
done
