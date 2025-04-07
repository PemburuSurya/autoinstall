#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

# Update dan upgrade sistem
echo "Memperbarui dan mengupgrade sistem..."
sudo apt install git -y
sudo apt update && sudo apt upgrade -y
sudo apt install clang cmake build-essential openssl pkg-config libssl-dev -y

# Instal paket yang diperlukan untuk Docker
echo "Menginstal dependensi Docker..."
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Tambahkan kunci GPG Docker
echo "Menambahkan kunci GPG Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Tambahkan repositori Docker
echo "Menambahkan repositori Docker..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update ulang dan instal Docker
echo "Menginstal Docker..."
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y

# Mengunduh versi terbaru Docker Compose dari GitHub API
echo "Mengunduh Docker Compose..."
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Memberikan izin eksekusi pada binary Docker Compose
chmod +x /usr/local/bin/docker-compose

#Install Docker CLI plugin and make executable
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# Tambahkan pengguna saat ini ke grup Docker
echo "Menambahkan pengguna ke grup Docker..."
sudo groupadd -f docker
sudo usermod -aG docker $USER
sudo usermod -aG docker ubuntu
sudo usermod -aG docker hosting

# Instal berbagai alat pengembangan dan utilitas
echo "Menginstal alat-alat pengembangan dan utilitas..."
sudo apt install snapd wget htop tmux jq make gcc tar ncdu protobuf-compiler npm nodejs flatpak default-jdk aptitude squid apache2-utils iptables iptables-persistent openssh-server jq sed lz4 aria2 pv -y

# Instal Visual Studio Code melalui Snap
echo "Menginstal Visual Studio Code..."
sudo snap install code --classic

# Tambahkan repositori Flatpak
echo "Menambahkan repositori Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Tambahkan PPA untuk OpenJDK
echo "Menambahkan PPA OpenJDK..."
sudo add-apt-repository ppa:openjdk-r/ppa -y
sudo apt update

# Aktifkan dan mulai layanan netfilter-persistent
echo "Mengaktifkan dan memulai netfilter-persistent..."
sudo systemctl enable netfilter-persistent
sudo systemctl start netfilter-persistent

# Download Go 1.22.4 for Linux amd64
GO_VERSION="1.22.4"
GO_ARCH="linux-amd64"
echo "Installing Go $GO_VERSION for $GO_ARCH..."
curl -OL https://go.dev/dl/go$GO_VERSION.$GO_ARCH.tar.gz

# Verify the downloaded file
if file go$GO_VERSION.$GO_ARCH.tar.gz | grep -q "gzip compressed data"; then
    echo "Go download verified successfully."
else
    echo "Failed to download Go. The file is not valid."
    exit 1
fi

# Extract and install Go
sudo tar -C /usr/local -xzf go$GO_VERSION.$GO_ARCH.tar.gz
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify Go installation
if ! command -v go &> /dev/null; then
    echo "Failed to install Go. Please check the installation."
    exit 1
else
    echo "Go installed successfully."
    go version
fi

# Instal Rust menggunakan rustup
echo "Menginstal Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

echo "================================================"
echo "Instalasi selesai!"
echo "- Docker dan Docker Compose telah diinstal."
echo "- Anaconda telah diinstal/diperbarui dan lingkungan virtual 'myenv' telah dibuat."
echo "- Rust, Visual Studio Code, dan alat-alat pengembangan lainnya telah diinstal."
echo "================================================"
