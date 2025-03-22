#!/bin/bash

# ==============================
# Script Install dan Setup NATS
# ==============================

# Cek apakah script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo "Script ini harus dijalankan sebagai root!"
   exit 1
fi

echo "Memulai instalasi NATS Server..."

# Step 0: Instal Dependensi
echo "Menginstal dependensi (unzip)..."
apt update && apt install unzip -y

# Step 1: Unduh Biner NATS Server
echo "Mengunduh NATS Server..."
NATS_SERVER_URL="https://github.com/nats-io/nats-server/releases/download/v2.10.11/nats-server-v2.10.11-linux-amd64.zip"
wget -q --show-progress "$NATS_SERVER_URL" -O nats-server-linux-amd64.zip

# Cek apakah file berhasil diunduh
if [[ ! -f "nats-server-linux-amd64.zip" ]]; then
   echo "Gagal mengunduh NATS Server. Periksa koneksi internet atau URL."
   exit 1
fi

# Step 2: Ekstrak Biner NATS Server
echo "Mengekstrak NATS Server..."
unzip -o nats-server-linux-amd64.zip
rm -f nats-server-linux-amd64.zip

# Step 3: Pindahkan Biner ke Direktori Sistem
echo "Memindahkan biner ke /usr/local/bin/..."
mv nats-server-v2.10.11-linux-amd64/nats-server /usr/local/bin/
chmod +x /usr/local/bin/nats-server

# Step 4: Verifikasi Instalasi
echo "Verifikasi instalasi..."
nats-server --version

# Step 5: Membuat Service Systemd
echo "Membuat service systemd untuk NATS..."
cat <<EOF > /etc/systemd/system/nats.service
[Unit]
Description=NATS Server
After=network.target

[Service]
ExecStart=/usr/local/bin/nats-server -js
Restart=always
User=nobody
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Reload Systemd dan Aktifkan Service
echo "Reload systemd dan mengaktifkan service..."
systemctl daemon-reload
systemctl enable nats
systemctl start nats

# Step 7: Cek Status Service
echo "Cek status NATS Server..."
systemctl status nats --no-pager

# Step 8: Uji Koneksi ke NATS
echo "Uji coba koneksi ke NATS Server..."
ss -tuln | grep 4222

# Step 9: Instal NATS CLI (opsional)
echo "Menginstal NATS CLI..."
NATS_CLI_URL="https://github.com/nats-io/natscli/releases/download/v0.2.0/nats-0.2.0-linux-amd64.zip"
wget -q --show-progress "$NATS_CLI_URL" -O nats-linux-amd64.zip

# Cek apakah file berhasil diunduh
if [[ ! -f "nats-linux-amd64.zip" ]]; then
   echo "Gagal mengunduh NATS CLI. Periksa koneksi internet atau URL."
   exit 1
fi

# Ekstrak NATS CLI
echo "Mengekstrak NATS CLI..."
unzip -o nats-linux-amd64.zip
rm -f nats-linux-amd64.zip

# Pindahkan biner NATS CLI ke /usr/local/bin/
echo "Memindahkan biner NATS CLI ke /usr/local/bin/..."
mv nats-0.2.0-linux-amd64/nats /usr/local/bin/
chmod +x /usr/local/bin/nats

# Step 10: Tes Publikasi dan Subskripsi
echo "Tes Subskripsi NATS..."
nats sub -s nats://localhost:4222 test &

echo "Tes Publikasi NATS..."
nats pub -s nats://localhost:4222 test "Hello NATS!"

echo "Instalasi dan konfigurasi NATS selesai!"
