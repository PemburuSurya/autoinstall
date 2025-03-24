# Hapus file resolv.conf yang ada
echo -e "\033[0;32mMenghapus file /etc/resolv.conf...\033[0m"
sudo rm /etc/resolv.conf

# Buat file resolv.conf baru dan tambahkan nameserver
echo -e "\033[0;32mMembuat file /etc/resolv.conf baru...\033[0m"
sudo tee /etc/resolv.conf > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL

# Lock file resolv.conf agar tidak bisa diubah
echo -e "\033[0;32mMengunci file /etc/resolv.conf...\033[0m"
sudo chattr +i /etc/resolv.conf
