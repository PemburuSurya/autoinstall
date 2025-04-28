#!/bin/bash
# Auto install hyperspace node

# Install hyperspace
echo "Downloading and installing hyperspace..."
curl -s https://download.hyper.space/api/install | bash

# Reload bash profile
echo "Reloading bash profile..."
source /root/.bashrc
