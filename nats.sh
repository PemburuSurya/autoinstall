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

# Step 1: Unduh Biner NATS Server
echo "Mengunduh NATS Server..."
wget -q --show-progress https://github.com/nats-io/nats-server/releases/latest/download/nats-server-linux-amd64.zip

# Step 2: Ekstrak Biner NATS Server
echo "Mengekstrak NATS Server..."
unzip -o nats-server-linux-amd64.zip
rm -f nats-server-linux-amd64.zip

# Step 3: Pindahkan Biner ke Direktori Sistem
echo "Memindahkan biner ke /usr/local/bin/..."
mv nats-server /usr/local/bin/

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
wget -q --show-progress https://github.com/nats-io/natscli/releases/latest/download/nats-linux-amd64.zip
unzip -o nats-linux-amd64.zip
rm -f nats-linux-amd64.zip
mv nats /usr/local/bin/

# Step 10: Tes Publikasi dan Subskripsi
echo "Tes Subskripsi NATS..."
nats sub -s nats://localhost:4222 test &

echo "Tes Publikasi NATS..."
nats pub -s nats://localhost:4222 test "Hello NATS!"

echo "Instalasi dan konfigurasi NATS selesai!"
