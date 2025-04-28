#!/bin/bash
echo "==============================================="
echo "🚀 Hyperspace Node Auto-Installer"
echo "==============================================="

# Minta input private key dari user
read -p "Masukkan PRIVATE KEY kamu: " PRIVATE_KEY

# Cek kalau input kosong
if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Private key tidak boleh kosong. Exit."
  exit 1
fi

# Buat file .pem dari input
echo "Membuat file .pem..."
cat > /root/.pem <<EOF
$PRIVATE_KEY
EOF

# Set permission yang benar
chmod 600 /root/.pem

# Jalankan Hyperspace node di dalam screen
echo "Menjalankan Hyperspace node di background (screen)..."
screen -dmS hyperspace bash -c 'aios-cli start'

echo ""
echo "🚀 Hyperspace node telah dijalankan di dalam screen session 'hyperspace'!"
echo "👉 Untuk melihat node: screen -r hyperspace"
echo "👉 Untuk keluar dari screen (tanpa mematikan node): tekan Ctrl+A lalu D"
