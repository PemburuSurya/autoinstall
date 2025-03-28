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

# 1. Aktifkan IP Forwarding
echo "🔧 Mengaktifkan IP forwarding..."
sudo tee -a /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
vm.overcommit_memory=1
EOF

# Terapkan perubahan sysctl
sudo sysctl -p

# 2. Setup iptables dasar
echo "🔧 Mengatur iptables..."
sudo modprobe iptable_nat

# 3. Konfigurasi X11 Forwarding
echo "🔧 Mengaktifkan X11 Forwarding di SSH..."
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config

# Install xauth jika belum ada
if ! command -v xauth &> /dev/null; then
    echo "🔧 Memasang xauth..."
    sudo apt-get update
    sudo apt-get install -y xauth
fi

# 4. Atur iptables untuk X11 dan forwarding
echo "🔧 Mengatur firewall untuk X11 dan forwarding..."
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  # Ganti eth0 dengan interface yang sesuai
sudo iptables -A INPUT -p tcp --dport 6000:6007 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 6000:6007 -j ACCEPT

# 5. Simpan aturan iptables dan aktifkan persistensi
echo "🔧 Menyimpan konfigurasi iptables..."
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent

# 6. Restart service SSH
echo "🔧 Restarting SSH service..."
sudo systemctl restart ssh
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

# Unduh Anaconda installer
cd /tmp
echo "Mengunduh Anaconda installer..."
curl https://repo.anaconda.com/archive/Anaconda3-2021.11-Linux-x86_64.sh --output anaconda.sh

# Berikan izin eksekusi pada installer
chmod +x anaconda.sh

# Periksa apakah instalasi Anaconda sudah ada
if [[ -d "$HOME/anaconda3" ]]; then
    echo "Anaconda sudah terinstal di $HOME/anaconda3."
    echo "Memperbarui instalasi Anaconda yang sudah ada..."
    bash anaconda.sh -u -b -p $HOME/anaconda3
else
    echo "Menginstal Anaconda..."
    bash anaconda.sh -b -p $HOME/anaconda3
fi

# Cari path anaconda3 atau miniconda3
CONDA_PATH=$(find $HOME -type d -name "anaconda3" -o -name "miniconda3" 2>/dev/null | head -n 1)

# Jika ditemukan, tambahkan ke ~/.bashrc
if [[ -n $CONDA_PATH ]]; then
    echo "Menemukan Conda di: $CONDA_PATH"
    echo "export PATH=\"$CONDA_PATH/bin:\$PATH\"" >> ~/.bashrc
    source ~/.bashrc
    echo "Conda telah ditambahkan ke PATH."
else
    echo "Conda tidak ditemukan di sistem."
    exit 1
fi

# Inisialisasi Conda
echo "Menginisialisasi Conda..."
eval "$($CONDA_PATH/bin/conda shell.bash hook)"
source ~/.bashrc

# Perbarui Conda ke versi terbaru
echo "Memperbarui Conda..."
conda update -n base -c defaults conda -y

# Periksa versi Conda
echo "Memeriksa versi Conda..."
conda --version

# Install pip menggunakan Conda
echo "Menginstal pip menggunakan Conda..."
conda install pip -y

# Perbaiki masalah pip (jika ada)
echo "Memperbaiki masalah pip..."
pip uninstall pyodbc -y 2>/dev/null  # Hapus pyodbc jika bermasalah
pip install --upgrade pip

# Buat lingkungan virtual Python menggunakan Conda
echo "Membuat lingkungan virtual Python menggunakan Conda..."
conda create -n myenv python=3.9 -y

# Aktifkan lingkungan virtual
echo "Mengaktifkan lingkungan virtual..."
conda activate myenv

# Verifikasi lingkungan virtual
echo "Verifikasi lingkungan virtual..."
conda info --envs

echo "================================================"
echo "Instalasi selesai!"
echo "- Docker dan Docker Compose telah diinstal."
echo "- Anaconda telah diinstal/diperbarui dan lingkungan virtual 'myenv' telah dibuat."
echo "- Rust, Visual Studio Code, dan alat-alat pengembangan lainnya telah diinstal."
echo "================================================"#!/bin/bash
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

# 1. Aktifkan IP Forwarding
echo "🔧 Mengaktifkan IP forwarding..."
sudo tee -a /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
vm.overcommit_memory=1
EOF

# Terapkan perubahan sysctl
sudo sysctl -p

# 2. Setup iptables dasar
echo "🔧 Mengatur iptables..."
sudo modprobe iptable_nat

# 3. Konfigurasi X11 Forwarding
echo "🔧 Mengaktifkan X11 Forwarding di SSH..."
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11DisplayOffset 10/X11DisplayOffset 10/g' /etc/ssh/sshd_config
sudo sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config

# Install xauth jika belum ada
if ! command -v xauth &> /dev/null; then
    echo "🔧 Memasang xauth..."
    sudo apt-get update
    sudo apt-get install -y xauth
fi

# 4. Atur iptables untuk X11 dan forwarding
echo "🔧 Mengatur firewall untuk X11 dan forwarding..."
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  # Ganti eth0 dengan interface yang sesuai
sudo iptables -A INPUT -p tcp --dport 6000:6007 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 6000:6007 -j ACCEPT

# 5. Simpan aturan iptables dan aktifkan persistensi
echo "🔧 Menyimpan konfigurasi iptables..."
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent

# 6. Restart service SSH
echo "🔧 Restarting SSH service..."
sudo systemctl restart ssh
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

# Unduh Anaconda installer
cd /tmp
echo "Mengunduh Anaconda installer..."
curl https://repo.anaconda.com/archive/Anaconda3-2021.11-Linux-x86_64.sh --output anaconda.sh

# Berikan izin eksekusi pada installer
chmod +x anaconda.sh

# Periksa apakah instalasi Anaconda sudah ada
if [[ -d "$HOME/anaconda3" ]]; then
    echo "Anaconda sudah terinstal di $HOME/anaconda3."
    echo "Memperbarui instalasi Anaconda yang sudah ada..."
    bash anaconda.sh -u -b -p $HOME/anaconda3
else
    echo "Menginstal Anaconda..."
    bash anaconda.sh -b -p $HOME/anaconda3
fi

# Cari path anaconda3 atau miniconda3
CONDA_PATH=$(find $HOME -type d -name "anaconda3" -o -name "miniconda3" 2>/dev/null | head -n 1)

# Jika ditemukan, tambahkan ke ~/.bashrc
if [[ -n $CONDA_PATH ]]; then
    echo "Menemukan Conda di: $CONDA_PATH"
    echo "export PATH=\"$CONDA_PATH/bin:\$PATH\"" >> ~/.bashrc
    source ~/.bashrc
    echo "Conda telah ditambahkan ke PATH."
else
    echo "Conda tidak ditemukan di sistem."
    exit 1
fi

# Inisialisasi Conda
echo "Menginisialisasi Conda..."
eval "$($CONDA_PATH/bin/conda shell.bash hook)"
source ~/.bashrc

# Perbarui Conda ke versi terbaru
echo "Memperbarui Conda..."
conda update -n base -c defaults conda -y

# Periksa versi Conda
echo "Memeriksa versi Conda..."
conda --version

# Install pip menggunakan Conda
echo "Menginstal pip menggunakan Conda..."
conda install pip -y

# Perbaiki masalah pip (jika ada)
echo "Memperbaiki masalah pip..."
pip uninstall pyodbc -y 2>/dev/null  # Hapus pyodbc jika bermasalah
pip install --upgrade pip

# Buat lingkungan virtual Python menggunakan Conda
echo "Membuat lingkungan virtual Python menggunakan Conda..."
conda create -n myenv python=3.9 -y

# Aktifkan lingkungan virtual
echo "Mengaktifkan lingkungan virtual..."
conda activate myenv

# Verifikasi lingkungan virtual
echo "Verifikasi lingkungan virtual..."
conda info --envs

echo "================================================"
echo "Instalasi selesai!"
echo "- Docker dan Docker Compose telah diinstal."
echo "- Anaconda telah diinstal/diperbarui dan lingkungan virtual 'myenv' telah dibuat."
echo "- Rust, Visual Studio Code, dan alat-alat pengembangan lainnya telah diinstal."
echo "================================================"
