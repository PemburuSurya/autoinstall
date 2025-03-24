#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

# Fungsi untuk mengecek apakah suatu perintah sudah terinstal
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Nonaktifkan semua swap yang sedang aktif
if swapon --show | grep -q .; then
    echo -e "\033[0;32mMenonaktifkan swap yang sedang aktif...\033[0m"
    sudo swapoff -a
fi

# Buat swapfile baru dengan ukuran 32GB jika belum ada
if [ ! -f /swapfile ]; then
    echo -e "\033[0;32mMembuat swapfile baru dengan ukuran 32GB...\033[0m"
    sudo fallocate -l 16G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
else
    echo -e "\033[0;33mSwapfile sudah ada, melewati...\033[0m"
fi

# Set vm.overcommit_memory ke 1 secara langsung
echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1...\033[0m"
sudo sysctl -w vm.overcommit_memory=1

# Set vm.overcommit_memory ke 1 secara permanen
if ! grep -q "vm.overcommit_memory=1" /etc/sysctl.conf; then
    echo -e "\033[0;32mMengatur vm.overcommit_memory ke 1 secara permanen...\033[0m"
    echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
else
    echo -e "\033[0;33mvm.overcommit_memory sudah diatur, melewati...\033[0m"
fi

# Update dan upgrade sistem
echo "Memperbarui dan mengupgrade sistem..."
sudo apt update && sudo apt upgrade -y

# Instal paket yang diperlukan untuk Docker jika belum terinstal
if ! command_exists docker; then
    echo "Menginstal dependensi Docker..."
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

    echo "Menambahkan kunci GPG Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "Menambahkan repositori Docker..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Menginstal Docker..."
    sudo apt update
    sudo apt install docker-ce docker-ce-cli containerd.io -y
else
    echo -e "\033[0;33mDocker sudah terinstal, melewati...\033[0m"
fi

# Mengunduh Docker Compose jika belum terinstal
if ! command_exists docker-compose; then
    echo "Mengunduh Docker Compose..."
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo -e "\033[0;33mDocker Compose sudah terinstal, melewati...\033[0m"
fi

# Tambahkan pengguna saat ini ke grup Docker jika belum
if ! groups $USER | grep -q docker; then
    echo "Menambahkan pengguna ke grup Docker..."
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
else
    echo -e "\033[0;33mPengguna sudah berada di grup Docker, melewati...\033[0m"
fi

# Instal berbagai alat pengembangan dan utilitas jika belum terinstal
echo "Menginstal alat-alat pengembangan dan utilitas..."
sudo apt install snapd wget htop tmux jq make gcc tar ncdu protobuf-compiler npm nodejs flatpak default-jdk aptitude squid apache2-utils iptables iptables-persistent openssh-server jq sed lz4 aria2 pv -y

# Instal Visual Studio Code melalui Snap jika belum terinstal
if ! command_exists code; then
    echo "Menginstal Visual Studio Code..."
    sudo snap install code --classic
else
    echo -e "\033[0;33mVisual Studio Code sudah terinstal, melewati...\033[0m"
fi

# Tambahkan repositori Flatpak jika belum ada
if ! flatpak remote-list | grep -q flathub; then
    echo "Menambahkan repositori Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
    echo -e "\033[0;33mRepositori Flatpak sudah ada, melewati...\033[0m"
fi

# Tambahkan PPA untuk OpenJDK jika belum ada
if ! grep -q "openjdk-r" /etc/apt/sources.list.d/*; then
    echo "Menambahkan PPA OpenJDK..."
    sudo add-apt-repository ppa:openjdk-r/ppa -y
    sudo apt update
else
    echo -e "\033[0;33mPPA OpenJDK sudah ada, melewati...\033[0m"
fi

# Aktifkan dan mulai layanan netfilter-persistent jika belum aktif
if ! systemctl is-active --quiet netfilter-persistent; then
    echo "Mengaktifkan dan memulai netfilter-persistent..."
    sudo systemctl enable netfilter-persistent
    sudo systemctl start netfilter-persistent
else
    echo -e "\033[0;33mnetfilter-persistent sudah aktif, melewati...\033[0m"
fi

# Instal Go jika belum terinstal
if ! command_exists go; then
    GO_VERSION="1.22.4"
    GO_ARCH="linux-amd64"
    echo "Menginstal Go $GO_VERSION untuk $GO_ARCH..."
    curl -OL https://go.dev/dl/go$GO_VERSION.$GO_ARCH.tar.gz

    if file go$GO_VERSION.$GO_ARCH.tar.gz | grep -q "gzip compressed data"; then
        echo "Go download verified successfully."
        sudo tar -C /usr/local -xzf go$GO_VERSION.$GO_ARCH.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
        echo "Go installed successfully."
        go version
    else
        echo "Failed to download Go. The file is not valid."
        exit 1
    fi
else
    echo -e "\033[0;33mGo sudah terinstal, melewati...\033[0m"
fi

# Instal Rust jika belum terinstal
if ! command_exists rustc; then
    echo "Menginstal Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
else
    echo -e "\033[0;33mRust sudah terinstal, melewati...\033[0m"
fi

# Instal Anaconda jika belum terinstal
if ! command_exists conda; then
    echo "Mengunduh Anaconda installer..."
    curl https://repo.anaconda.com/archive/Anaconda3-2021.11-Linux-x86_64.sh --output anaconda.sh
    chmod +x anaconda.sh
    bash anaconda.sh -b -p $HOME/anaconda3
    echo 'export PATH="$HOME/anaconda3/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
else
    echo -e "\033[0;33mAnaconda sudah terinstal, melewati...\033[0m"
fi

# Buat lingkungan virtual Python menggunakan Conda jika belum ada
if conda info --envs | grep -q myenv; then
    echo -e "\033[0;33mLingkungan virtual 'myenv' sudah ada, melewati...\033[0m"
else
    echo "Membuat lingkungan virtual Python menggunakan Conda..."
    conda create -n myenv python=3.9 -y
fi

echo "================================================"
echo "Instalasi selesai!"
echo "- Docker dan Docker Compose telah diinstal."
echo "- Anaconda telah diinstal/diperbarui dan lingkungan virtual 'myenv' telah dibuat."
echo "- Rust, Visual Studio Code, dan alat-alat pengembangan lainnya telah diinstal."
echo "================================================"
