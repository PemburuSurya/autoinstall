#!/bin/bash
set -e  # Menghentikan skrip jika ada perintah yang gagal

# Menambahkan pengguna ubuntu dan hosting
sudo adduser kubuntu --gecos "" --disabled-password
sudo adduser hosting --gecos "" --disabled-password

# Mengatur password untuk yuni1 dan yuni2
echo "kubuntu:egan1337" | sudo chpasswd
echo "hosting:egan1337" | sudo chpasswd

# Memberikan akses root ke yuni1 dan yuni2
sudo usermod -aG sudo ubuntu
sudo usermod -aG sudo hosting
