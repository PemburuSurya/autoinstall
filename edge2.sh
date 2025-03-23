#!/bin/bash

# Update package list and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y curl build-essential

# Remove old Go installation
sudo rm -rf /usr/local/go

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

# Install Rust and cargo
if ! command -v cargo &> /dev/null; then
    echo "Installing Rust and cargo..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    source ~/.bashrc
else
    echo "Rust and cargo are already installed."
fi

# Install the Risc0 toolchain if not installed
if ! command -v rzup &> /dev/null; then
    echo "Installing the Risc0 toolchain..."
    curl -L https://risczero.com/install | bash
    export PATH="$HOME/.risc0/bin:$PATH"
    echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> ~/.bashrc
    source $HOME/.cargo/env
    source ~/.bashrc
    if ! command -v rzup &> /dev/null; then
        echo "Risc0 toolchain installation failed. Please check the logs."
        exit 1
    fi
    rzup install
else
    echo "Risc0 toolchain is already installed."
fi

# Clone the repository (if not already cloned)
if [ ! -d "light-node" ]; then
    echo "Cloning the repository..."
    git clone https://github.com/Layer-Edge/light-node.git
    cd light-node
else
    echo "Repository already cloned."
    cd light-node
fi

# Prompt for PRIVATE_KEY input
read -p "Enter your PRIVATE_KEY: " PRIVATE_KEY

# Configure environment variables
echo "Configuring environment variables..."
cat <<EOL > .env
GRPC_URL=https://grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY=$PRIVATE_KEY
EOL

# Build and run the Risc0 Merkle Service
echo "Building and running Risc0 Merkle Service..."
cd risc0-merkle-service
cargo clean
cargo build
if [ $? -eq 0 ]; then
    echo "Risc0 Merkle Service built successfully."
    cargo run &
else
    echo "Failed to build Risc0 Merkle Service. Please check the logs."
    exit 1
fi

# Wait for the Risc0 server to start
sleep 5

# Update go.mod to use the correct Go version
echo "Updating go.mod to use Go $GO_VERSION..."
sed -i 's/^go 1.*/go '"$GO_VERSION"'/' go.mod

# Clean Go module cache
echo "Cleaning Go module cache..."
go clean -modcache

# Update dependencies
echo "Updating dependencies..."
go mod tidy

# Build the project
echo "Building the project..."
cd /root/light-node
go build
if [ $? -eq 0 ]; then
    echo "Project built successfully."
else
    echo "Failed to build the project. Please check the logs."
    exit 1
fi

# Run the project
echo "Running the project..."
./light-node
