#!/bin/bash

# Infinite loop to keep retrying the script if any part fails
while true; do
    printf "\n"
    cat <<EOF

██████╗░░█████╗░░█████╗░██████╗░
██╔══██╗██╔══██╗██╔══██╗██╔══██╗
██████╦╝██║░░██║██║░░██║██████╦╝
██╔══██╗██║░░██║██║░░██║██╔══██╗
██████╦╝╚█████╔╝╚█████╔╝██████╦╝
╚═════╝░░╚════╝░░╚════╝░╚═════╝░

EOF

    printf "\n\n"

    # Banner Links
    GREEN="\033[0;32m"
    RESET="\033[0m"
    printf "${GREEN}"
    printf "Stay connected for updates:\n"
    printf "   • Telegram: https://t.me/uangdrop\n"
    printf "   • X (formerly Twitter): https://x.com/uangdrop\n"
    printf "${RESET}"

    # Step 1: Install HyperSpace CLI
    echo "🚀 Installing HyperSpace CLI..."

    while true; do
        curl -s https://download.hyper.space/api/install | bash | tee /root/hyperspace_install.log

        if ! grep -q "Failed to parse version from release data." /root/hyperspace_install.log; then
            echo "✅ HyperSpace CLI installed successfully!"
            break
        else
            echo "❌ Installation failed. Retrying in 10 seconds..."
            sleep 10
        fi
    done

    # Step 2: Add aios-cli to PATH
    echo "🔄 Adding aios-cli path to .bashrc..."
    echo 'export PATH=$PATH:$HOME/.aios' >> ~/.bashrc
    export PATH=$PATH:$HOME/.aios
    source ~/.bashrc

    # Step 3: Start Hyperspace Node in screen
    echo "🚀 Starting the Hyperspace node in background..."
    screen -S hyperspace -d -m bash -c "$HOME/.aios/aios-cli start"

    echo "⏳ Waiting for the Hyperspace node to start..."
    sleep 10

    # Step 4: Confirm aios-cli available
    echo "🔍 Checking aios-cli..."
    if ! command -v aios-cli &> /dev/null; then
        echo "❌ aios-cli not found. Retrying..."
        continue
    fi

    echo "🔍 Checking node status..."
    aios-cli status

    # Step 5: Download model
    echo "🔄 Downloading model..."

    while true; do
        aios-cli models add hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf | tee /root/model_download.log

        if grep -q "Download complete" /root/model_download.log; then
            echo "✅ Model downloaded successfully!"
            break
        else
            echo "❌ Model download failed. Retrying in 10 seconds..."
            sleep 10
        fi
    done

    # Step 6: Input private key
    echo "🔑 Enter your private key:"
    read -p "Private Key: " private_key
    echo $private_key > /root/my.pem
    echo "✅ Private key saved to /root/my.pem"

    # Step 7: Import key, login
    echo "🔑 Importing key..."
    aios-cli hive import-keys /root/my.pem

    echo "🔐 Logging in..."
    aios-cli hive login

    # Step 8: Select Hive Tier
    echo "🏆 Selecting Hive Tier 5..."
    aios-cli hive select-tier 5

    # --- RECONNECT LOOP BAGIAN PENTING ---
    while true; do
        echo "🌐 Connecting to Hive..."
        aios-cli hive connect

        echo "✅ Connected! Fetching points every 10 seconds..."

        while true; do
            if aios-cli hive points; then
                sleep 10
            else
                echo "⚠️ Connection lost. Reconnecting in 10 minutes..."
                sleep 600 # 10 menit
                break # keluar dari inner loop dan reconnect
            fi
        done

    done

done
