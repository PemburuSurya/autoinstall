#!/bin/bash

# ASCII Art with color
echo -e "\e[36m   ______ _____   ___  ____  __________  __ ____  _____ \e[0m"
echo -e "\e[36m  / __/ // / _ | / _ \/ __/ /  _/_  __/ / // / / / / _ )\e[0m"
echo -e "\e[36m _\ \/ _  / __ |/ , _/ _/  _/ /  / /   / _  / /_/ / _  |\e[0m"
echo -e "\e[36m/___/_//_/_/ |_/_/|_/___/ /___/ /_/   /_//_/\____/____/ \e[0m"
echo -e "\e[33m               SUBSCRIBE MY CHANNEL                     \e[0m"
echo ""

# Function to display error messages
error_msg() {
    echo -e "\e[31m[ERROR] $1\e[0m"
}

# Function to display success messages
success_msg() {
    echo -e "\e[32m[SUCCESS] $1\e[0m"
}

# Function to display info messages
info_msg() {
    echo -e "\e[34m[INFO] $1\e[0m"
}

# Enhanced process killer function
kill_aios_processes() {
    info_msg "Terminating all aios-cli processes..."
    pkill -9 -f "aios-cli" 2>/dev/null
    # Additional cleanup for zombie processes
    sleep 2
    if pgrep -f "aios-cli" >/dev/null; then
        error_msg "Failed to kill all aios-cli processes"
        return 1
    else
        success_msg "All aios-cli processes terminated"
        return 0
    fi
}

# Kill running aios-cli processes
kill_aios_processes

# List all screen sessions
info_msg "Menampilkan daftar screen yang ada..."
screen_list=$(screen -ls | grep -o '[0-9]*\..*' | awk '{print $1}')
if [[ -z "$screen_list" ]]; then
    info_msg "Tidak ada sesi screen yang ditemukan."
else
    echo -e "\e[35mDaftar Screen:\e[0m"
    i=1
    while IFS= read -r line; do
        screen_id=$(echo "$line" | cut -d. -f1)
        screen_name=$(echo "$line" | cut -d. -f2-)
        echo "$i. $screen_name (ID: $screen_id)"
        ((i++))
    done <<< "$screen_list"
fi

# Screen deletion section
read -p "Apakah Anda ingin menghapus screen yang ada? (y/n): " delete_choice
if [[ "$delete_choice" =~ [yY] ]]; then
    read -p "Masukkan nomor urut screen yang ingin dihapus (pisahkan dengan koma jika lebih dari 1): " screens_to_delete
    
    IFS=',' read -ra screens_array <<< "$screens_to_delete"
    for screen_number in "${screens_array[@]}"; do
        screen_number=$(echo "$screen_number" | xargs) # Trim whitespace
        screen_info=$(echo "$screen_list" | sed -n "${screen_number}p")
        
        if [[ -n "$screen_info" ]]; then
            screen_id=$(echo "$screen_info" | cut -d. -f1)
            screen_name=$(echo "$screen_info" | cut -d. -f2-)
            
            info_msg "Menghapus screen '$screen_name' dengan ID '$screen_id'..."
            if screen -S "$screen_id" -X quit; then
                success_msg "Screen '$screen_name' berhasil dihapus."
            else
                error_msg "Gagal menghapus screen '$screen_name'."
            fi
        else
            error_msg "Screen dengan nomor urut '$screen_number' tidak ditemukan."
        fi
    done
fi

# Model deletion section
read -p "Apakah Anda ingin menghapus model yang ada sebelumnya? (y/n): " delete_model_choice
if [[ "$delete_model_choice" =~ [yY] ]]; then
    info_msg "Menghapus model yang ada sebelumnya..."
    rm -rf /root/.cache/hyperspace/models/* || error_msg "Gagal menghapus model"
    sleep 1
fi

# Private key input
read -p "Apakah Anda ingin memasukkan private key sekarang? (y/n): " choice
if [[ "$choice" =~ [yY] ]]; then
    echo "Masukkan private key Anda (tekan Enter lalu CTRL+D setelah selesai):"
    cat > .pem || error_msg "Gagal menyimpan private key"
else
    info_msg "Langkah private key dilewati."
fi

clear

# Generate automatic screen name with timestamp
screen_name="aios_$(date +%Y%m%d_%H%M%S)"
info_msg "Membuat sesi screen otomatis dengan nama '$screen_name'..."

# Create screen session with enhanced auto-reconnect
info_msg "Membuat screen session dengan auto-reconnect yang ditingkatkan..."
screen -S "$screen_name" -dm bash -c "
    while true; do
        if ! pgrep -x 'aios-cli' >/dev/null; then
            echo '[$(date +'%Y-%m-%d %H:%M:%S')] Memulai aios-cli...';
            aios-cli start --connect;
            exit_status=\$?;
            if [ \$exit_status -eq 0 ]; then
                echo '[$(date +'%Y-%m-%d %H:%M:%S')] AIOS berhenti dengan normal. Restarting dalam 10 detik...';
                sleep 1000;
            else
                echo '[$(date +'%Y-%m-%d %H:%M:%S')] Koneksi terputus! Mencoba reconnect dalam 15 detik...';
                sleep 15000;
            fi
        else
            echo '[$(date +'%Y-%m-%d %H:%M:%S')] Instance aios-cli sudah berjalan. Menunggu 30 detik...';
            sleep 30000;
        fi
    done
"

if screen -ls | grep -q "$screen_name"; then
    success_msg "Screen '$screen_name' berhasil dibuat dengan auto-reconnect!"
    echo -e "\n\e[33mUntuk memantau:\e[0m"
    echo "  screen -r $screen_name"
    echo -e "\n\e[33mUntuk detach dari screen:\e[0m Tekan \e[1mCtrl+A D\e[0m"
else
    error_msg "Gagal membuat screen session!"
    exit 1
fi

# Model download section
read -p "Apakah Anda ingin mengunduh model baru? (y/n): " download_model_choice
if [[ "$download_model_choice" =~ [yY] ]]; then
    url="https://huggingface.co/afrideva/Tiny-Vicuna-1B-GGUF/resolve/main/tiny-vicuna-1b.q8_0.gguf"
    model_folder="/root/.cache/hyperspace/models/hf__afrideva___Tiny-Vicuna-1B-GGUF__tiny-vicuna-1b.q8_0.gguf"
    model_path="$model_folder/tiny-vicuna-1b.q8_0.gguf"

    if [[ ! -d "$model_folder" ]]; then
        info_msg "Membuat folder $model_folder..."
        mkdir -p "$model_folder" || error_msg "Gagal membuat folder model"
    fi

    if [[ ! -f "$model_path" ]]; then
        info_msg "Mengunduh model dari $url..."
        wget -q --show-progress "$url" -O "$model_path"
        if [[ -f "$model_path" ]]; then
            success_msg "Model berhasil diunduh dan disimpan di $model_path"
        else
            error_msg "Gagal mengunduh model."
        fi
    else
        info_msg "Model sudah ada, melewati pengunduhan."
    fi
else
    info_msg "Langkah pengunduhan model dilewati."
fi

# Inference section
read -p "Apakah Anda ingin menjalankan inferensi? (y/n): " user_choice
if [[ "$user_choice" =~ [yY] ]]; then
    infer_prompt="What is SHARE IT HUB ? Describe the airdrop community"
    info_msg "Menjalankan inferensi dengan prompt: '$infer_prompt'"
    if aios-cli infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
        success_msg "Inferensi berhasil."
    else
        error_msg "Gagal menjalankan inferensi."
    fi
else
    info_msg "Langkah inferensi dilewati."
fi

# Hive operations
info_msg "Menjalankan operasi Hive..."
aios-cli hive import-keys ./.pem || error_msg "Gagal mengimpor kunci Hive"
sleep 1

aios-cli hive login || error_msg "Gagal login ke Hive"
sleep 1

aios-cli hive select-tier 3 || error_msg "Gagal memilih tier"
sleep 1

# Enhanced Hive connection with retry logic
info_msg "Mencoba terhubung ke Hive..."
max_retries=3
retry_delay=15
for ((i=1; i<=$max_retries; i++)); do
    if aios-cli hive connect; then
        success_msg "Berhasil terhubung ke Hive"
        break
    else
        error_msg "Gagal terhubung ke Hive (Percobaan $i/$max_retries)"
        if [ $i -lt $max_retries ]; then
            info_msg "Menunggu $retry_delay detik sebelum mencoba lagi..."
            sleep $retry_delay
        else
            error_msg "Gagal terhubung ke Hive setelah $max_retries percobaan"
        fi
    fi
done

read -p "Apakah Anda ingin menjalankan inferensi Hive? (y/n): " hive_choice
if [[ "$hive_choice" =~ [yY] ]]; then
    infer_prompt="What is SHARE IT HUB ? Describe the airdrop community"
    info_msg "Jangan lupa Subscribe Channel Youtube dan Telegram : SHARE IT HUB"
    if aios-cli hive infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
        success_msg "Hive inferensi berhasil."
    else
        error_msg "Gagal menjalankan Hive inferensi."
    fi
else
    info_msg "Langkah Hive inferensi dilewati."
fi

echo -e "\e[33m\n[INFO] Proses selesai.\e[0m"
echo -e "\e[32mDONE. Untuk mengakses screen, gunakan perintah: screen -r \"$screen_name\"\e[0m"
echo -e "\e[33mOriginal Script by SHARE IT HUB\e[0m"

exit 0
