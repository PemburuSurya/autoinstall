echo "   ______ _____   ___  ____  __________  __ ____  _____ "
echo "  / __/ // / _ | / _ \/ __/ /  _/_  __/ / // / / / / _ )"
echo " _\ \/ _  / __ |/ , _/ _/  _/ /  / /   / _  / /_/ / _  |"
echo "/___/_//_/_/ |_/_/|_/___/ /___/ /_/   /_//_/\____/____/ "
echo "               SUBSCRIBE MY CHANNEL                     "

sleep 1

echo " Menghentikan aios-cli yang sedang berjalan agar tidak terjadi error "
aios-cli kill
sleep 1

echo "Menampilkan daftar screen yang ada..."
screen -ls | grep -o '[0-9]*\.' | nl -s '. ' | while read line; do
    screen_id=$(echo $line | awk '{print $2}')
    screen_name=$(screen -ls | grep -E "^\s*$screen_id" | awk -F. '{print $2}')
    echo "$screen_id. $screen_name"
done
sleep 1

read -p "Apakah Anda ingin menghapus screen yang ada? (y/n): " delete_choice
if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
    read -p "Masukkan nomor urut screen yang ingin dihapus (pisahkan dengan koma jika lebih dari 1): " screens_to_delete
    IFS=',' read -ra screens_array <<< "$screens_to_delete"
    
    for screen_number in "${screens_array[@]}"; do
        screen_number=$(echo "$screen_number" | xargs)
        screen_info=$(screen -ls | grep -o '[0-9]*\.' | nl -s '. ' | sed -n "${screen_number}p")
        screen_id=$(echo "$screen_info" | awk '{print $2}')
        screen_name=$(screen -ls | grep -E "^\s*$screen_id" | awk -F. '{print $2}')
        
        if [ -n "$screen_id" ]; then
            echo "Menghapus screen '$screen_name' dengan ID '$screen_id'..."
            screen -S "$screen_id" -X quit
            echo "Screen '$screen_name' berhasil dihapus."
        else
            echo "[ERROR] Screen dengan nomor urut '$screen_number' tidak ditemukan."
        fi
    done
fi

sleep 2

read -p "Apakah Anda ingin menghapus model yang ada sebelumnya? (y/n): " delete_model_choice
if [[ "$delete_model_choice" == "y" || "$delete_model_choice" == "Y" ]]; then
    echo "Menghapus model yang ada sebelumnya..."
    rm -rf /root/.cache/hyperspace/models/*
    sleep 1
fi

read -p "Apakah Anda ingin memasukkan private key sekarang? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    echo "Masukkan private key Anda (Lalu ENTER dan setelahnya tekan dengan CTRL+D):"
    cat > .pem
else
    echo "Langkah ini dilewati."
fi

clear

read -p "Masukkan nama screen: " screen_name

if [[ -z "$screen_name" ]]; then
    echo "Nama screen tidak boleh kosong."
    exit 1
fi

echo "Membuat sesi screen dengan nama '$screen_name'..."
screen -S "$screen_name" -dm
echo "[INFO] Sesi screen '$screen_name' dibuat."

echo "Menjalankan perintah 'aios-cli start' di dalam sesi screen '$screen_name'..."
screen -S "$screen_name" -X stuff "aios-cli start\n"

sleep 1

echo "Keluar dari sesi screen '$screen_name'..."
screen -S "$screen_name" -X detach
sleep 1

if [[ $? -eq 0 ]]; then
    echo "[SUCCESS] Screen dengan nama '$screen_name' berhasil dibuat dan menjalankan perintah aios-cli start."
else
    echo "[ERROR] Gagal membuat screen."
    exit 1
fi

sleep 2

read -p "Apakah Anda ingin mengunduh model baru? (y/n): " download_model_choice
if [[ "$download_model_choice" == "y" || "$download_model_choice" == "Y" ]]; then
    echo "Menambahkan model dengan perintah aios-cli models add..."
    url="https://huggingface.com/afrideva/Tiny-Vicuna-1B-GGUF/resolve/main/tiny-vicuna-1b.q8_0.gguf"
    model_folder="/root/.cache/hyperspace/models/hf__afrideva___Tiny-Vicuna-1B-GGUF__tiny-vicuna-1b.q8_0.gguf"
    model_path="$model_folder/tiny-vicuna-1b.q8_0.gguf"

    if [[ ! -d "$model_folder" ]]; then
        echo "Folder tidak ditemukan, membuat folder $model_folder..."
        mkdir -p "$model_folder"
    else
        echo "Folder sudah ada, melanjutkan..."
    fi

    if [[ ! -f "$model_path" ]]; then
        echo "Mengunduh model dari $url..."
        wget -q --show-progress "$url" -O "$model_path"
        if [[ -f "$model_path" ]]; then
            echo "[SUCCESS] Model berhasil diunduh dan disimpan di $model_path!"
        else
            echo "[ERROR] Terjadi kesalahan saat mengunduh model."
        fi
    else
        echo "[INFO] Model sudah ada di $model_path, melewati proses pengunduhan."
    fi
else
    echo "[INFO] Langkah pengunduhan model dilewati."
fi

echo "[SUCCESS] Model berhasil ditambahkan!"
# ORIGINAL SOURCE BY SHARE IT HUB
echo "Tunggu sampai proses selesai ! - Original Scripts by SHARE IT HUB"
read -p "Apakah Anda ingin menjalankan inferensi? (y/n): " user_choice

if [[ "$user_choice" == "y" || "$user_choice" == "Y" ]]; then
    echo "Tunggu sampai proses selesai ! - Original Scripts by SHARE IT HUB"
    infer_prompt="What is SHARE IT HUB ? Describe the airdrop community"
    echo "[INFO] Proses inferensi dimulai... Mengirim prompt: '$infer_prompt'"
    if aios-cli infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
        echo "[SUCCESS] Inferensi berhasil."
    else
        echo "[ERROR] Terjadi kesalahan saat menjalankan inferensi."
    fi
else
    echo "[INFO] Langkah inferensi dilewati."
fi

echo "Menjalankan perintah import-keys dengan file.pem..."
aios-cli hive import-keys ./.pem

sleep 1

echo "Memulai perintah Hive Login"
aios-cli hive login
sleep 1

echo "Memulai perintah Menggunakan Tier 5"
aios-cli hive select-tier 3
sleep 1

echo "Memulai perintah Hive Connect"
aios-cli hive connect
sleep 1

read -p "Apakah Anda ingin menjalankan inferensi Hive? (y/n): " hive_choice

if [[ "$hive_choice" == "y" || "$hive_choice" == "Y" ]]; then
    infer_prompt="What is SHARE IT HUB ? Describe the airdrop community"
    echo "[INFO] Jangan lupa untuk  Subscribe Channel Youtube dan Telegram : SHARE IT HUB"
    if aios-cli hive infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
        echo "[SUCCESS] Hive Inferensi berhasil."
    else
        echo "[ERROR] Terjadi kesalahan saat menjalankan inferensi Hive."
    fi
else
    echo "[INFO] Langkah Hive inferensi dilewati."
fi

sleep 1

echo "Memulai Menghentikan aios-cli & Menghubungkan ulang "
screen -S "$screen_name" -X stuff "aios-cli start --connect\n"

echo "[INFO] Proses selesai."
echo "DONE. JIKA KALIAN INGIN CHECK GUNAKAN PERINTAH : screen -r \"$screen_name\""
