#!/bin/bash
# Buat file .pem (isi manual di sini atau edit nanti)
echo "Membuat file .pem..."
cat > /root/.pem <<EOF
ISI_PRIVATE_KEY_DISINI
EOF

# Pastikan .pem file punya permission yang benar
chmod 600 /root/.pem

# Start hyperspace node
echo "Menjalankan hyperspace node..."
screen -dmS hyperspace bash -c 'aios-cli start'

echo "🚀 Hyperspace node telah dijalankan di dalam screen session 'hyperspace'!"
echo "Gunakan perintah berikut untuk attach ke screen:"
echo "screen -r hyperspace"
