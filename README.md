# AutoInstall Script

AutoInstall adalah skrip otomatis untuk menginstal berbagai layanan seperti DNS Swap, Proxy Squid, Chromium, RDP, dan AdsPower. Skrip ini membantu mempermudah konfigurasi dengan hanya beberapa langkah sederhana.

## Cara Menggunakan

Clone repository ini dan pindah ke direktori autoinstall:

```bash
git clone https://github.com/PemburuSurya/autoinstall.git
cd autoinstall
```

### Custom

Untuk mengubah DNS dan menambah virtual memory, jalankan perintah berikut:

```bash
chmod +x custom.sh
./custom.sh

### Afterinstall

Untuk mengubah DNS dan menambah virtual memory, jalankan perintah berikut:

```bash
chmod +x afterinstall.sh
./afterinstall.sh
```

### Mengubah DNS & Menambah Virtual Memory

Untuk mengubah DNS dan menambah virtual memory, jalankan perintah berikut:

```bash
chmod +x dns-swap.sh
./dns-swap.sh
```

### Proxy Squid

Menginstal dan mengonfigurasi proxy Squid:

```bash
chmod +x squid.sh
./squid.sh
```

### Chromium

Menginstal Chromium:

```bash
chmod +x chromium.sh
./chromium.sh
```

### RDP & AdsPower

Menginstal RDP dan AdsPower:

```bash
chmod +x rdp-adspower.sh
./rdp-adspower.sh
```

## Kontribusi

Silakan buat *pull request* atau buka *issue* jika Anda menemukan bug atau ingin menambahkan fitur baru.

## Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE).

