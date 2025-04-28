#!/bin/bash

# Buat file .pem
echo "Membuat file .pem..."
cat > /root/.pem <<EOF
ISI_PRIVATE_KEY_DISINI
EOF

# Set permission file .pem
chmod 600 /root/.pem

# Jalankan hyperspace node
echo "Menjalankan hyperspace node di screen session 'hyperspace'..."
screen -dmS hyperspace bash -c 'source /root/.bashrc && aios-cli start'

# Informasi ke user
echo "✅ Hyperspace node telah berjalan di screen."
echo "Untuk melihat node jalannya, ketik: screen -r hyperspace"
echo "Untuk keluar dari screen tanpa menghentikan node, tekan: Ctrl+A lalu D"
