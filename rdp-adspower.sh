#!/bin/bash

# Define color codes
INFO='\033[0;36m'  # Cyan
BANNER='\033[0;35m' # Magenta
YELLOW='\033[0;33m' # Yellow
RED='\033[0;31m'    # Red
GREEN='\033[0;32m'  # Green
BLUE='\033[0;34m'   # Blue
NC='\033[0m'        # No Color

# Display social details and channel information in large letters manually
echo "========================================"
echo -e "${YELLOW} Script is made by CRYTONODEHINDI${NC}"
echo -e "-------------------------------------"

# Large ASCII Text with BANNER color
echo -e "${BANNER}  CCCCC  RRRRR   Y   Y  PPPP   TTTTT  OOO      N   N   OOO   DDDD  EEEEE      H   H  III  N   N  DDDD   III${NC}"
echo -e "${BANNER} C       R   R    Y Y   P  P     T   O   O     NN  N  O   O  D   D E          H   H   I   NN  N  D   D   I ${NC}"
echo -e "${BANNER} C       RRRRR     Y    PPPP     T   O   O     N N N  O   O  D   D EEEE       HHHHH   I   N N N  D   D   I ${NC}"
echo -e "${BANNER} C       R   R     Y    P        T   O   O     N  NN  O   O  D   D E          H   H   I   N  NN  D   D   I ${NC}"
echo -e "${BANNER}  CCCCC  R    R    Y    P        T    OOO      N   N   OOO   DDDD  EEEEE      H   H  III  N   N  DDDD   III${NC}"

echo "============================================"

# Use different colors for each link to make them pop out more
echo -e "${YELLOW}Telegram: ${GREEN}https://t.me/cryptonodehindi${NC}"
echo -e "${YELLOW}Twitter: ${GREEN}@CryptonodeHindi${NC}"
echo -e "${YELLOW}YouTube: ${GREEN}https://www.youtube.com/@CryptonodesHindi${NC}"
echo -e "${YELLOW}Medium: ${BLUE}https://medium.com/@cryptonodehindi${NC}"

echo "============================================="

# Prompt for username and password
while true; do
    read -p "Enter the username for remote desktop: " USER
    if [[ "$USER" == "root" ]]; then
        echo -e "${RED}Error: 'root' cannot be used as the username. Please choose a different username.${NC}"
    elif [[ "$USER" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${RED}Error: Username contains forbidden characters. Only alphanumeric characters are allowed.${NC}"
    else
        break
    fi
done

while true; do
    read -sp "Enter the password for $USER: " PASSWORD
    echo
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${RED}Error: Password contains forbidden characters. Only alphanumeric characters are allowed.${NC}"
    else
        break
    fi
done

# Update and install required packages
echo -e "${INFO}Updating package list...${NC}"
sudo apt update -y

echo -e "${INFO}Upgrading installed packages...${NC}"
sudo apt upgrade -y

echo -e "${INFO}Installing curl and gdebi for handling .deb files...${NC}"
sudo apt install -y curl gdebi-core

# Download AdsPower .deb package
echo -e "${INFO}Downloading AdsPower package...${NC}"
wget https://version.adspower.net/software/linux-x64-global/AdsPower-Global-7.3.26-x64.deb
wget https://www.abcproxy.com/ABCS5Proxy-1.2.2.deb

# Install AdsPower using gdebi
echo -e "${INFO}Installing AdsPower using gdebi...${NC}"
sudo gdebi -n AdsPower-Global-7.3.26-x64.deb
sudo gdebi -n ABCS5Proxy-1.2.2.deb

# Install XFCE and XRDP with additional required packages
echo -e "${INFO}Installing XFCE Desktop for lower resource usage...${NC}"
sudo apt install -y xfce4 xfce4-goodies xubuntu-desktop xorg dbus-x11 x11-xserver-utils

echo -e "${INFO}Installing XRDP for remote desktop...${NC}"
sudo apt install -y xrdp

# Create user and set password
echo -e "${INFO}Adding the user $USER with the specified password...${NC}"
sudo useradd -m -s /bin/bash $USER
echo "$USER:$PASSWORD" | sudo chpasswd

echo -e "${INFO}Adding $USER to the sudo and xrdp groups...${NC}"
sudo usermod -aG sudo $USER
sudo usermod -aG xrdp $USER
sudo usermod -aG ssl-cert $USER

# Configure XRDP to use XFCE
echo -e "${INFO}Configuring XRDP to use XFCE desktop...${NC}"
echo "startxfce4" | sudo tee /home/$USER/.Xclients
sudo chmod +x /home/$USER/.Xclients
sudo chown $USER:$USER /home/$USER/.Xclients

# Configure XRDP session
echo -e "${INFO}Creating XRDP session configuration...${NC}"
sudo tee /etc/xrdp/startwm.sh > /dev/null <<EOL
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
startxfce4
EOL

sudo chmod +x /etc/xrdp/startwm.sh

# Configure XRDP ini file
echo -e "${INFO}Configuring XRDP settings...${NC}"
sudo sed -i 's/^#xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini
sudo sed -i '/\[xrdp1\]/a max_bpp=16\nxres=1280\nyres=720' /etc/xrdp/xrdp.ini
sudo sed -i 's/^port=3389/port=ask-5910/' /etc/xrdp/xrdp.ini

# Fix permissions
echo -e "${INFO}Fixing permissions...${NC}"
sudo chown -R $USER:$USER /home/$USER
sudo chmod 755 /home/$USER

# Configure Polkit for authentication
echo -e "${INFO}Configuring Polkit for authentication...${NC}"
sudo tee /etc/polkit-1/localauthority.conf.d/02-allow-colord.conf > /dev/null <<EOL
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.color-manager.create-device" ||
         action.id == "org.freedesktop.color-manager.create-profile" ||
         action.id == "org.freedesktop.color-manager.delete-device" ||
         action.id == "org.freedesktop.color-manager.delete-profile" ||
         action.id == "org.freedesktop.color-manager.modify-device" ||
         action.id == "org.freedesktop.color-manager.modify-profile") &&
        subject.isInGroup("users")) {
        return polkit.Result.YES;
    }
});
EOL

# Configure lightdm (if installed)
if [ -f /etc/lightdm/lightdm.conf ]; then
    echo -e "${INFO}Configuring lightdm...${NC}"
    sudo sed -i 's/^#autologin-user=/autologin-user='$USER'/' /etc/lightdm/lightdm.conf
    sudo sed -i 's/^#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
fi

# Configure .xsession
echo -e "${INFO}Configuring .xsession...${NC}"
echo "export XDG_CURRENT_DESKTOP=XFCE" | sudo tee -a /home/$USER/.xsession
echo "export XDG_SESSION_TYPE=x11" | sudo tee -a /home/$USER/.xsession
echo "export XDG_SESSION_DESKTOP=XFCE" | sudo tee -a /home/$USER/.xsession
echo "exec startxfce4" | sudo tee -a /home/$USER/.xsession
sudo chown $USER:$USER /home/$USER/.xsession
sudo chmod 644 /home/$USER/.xsession

# Create Desktop directory if not exists
DESKTOP_DIR="/home/$USER/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    echo -e "${INFO}Creating Desktop directory for $USER...${NC}"
    sudo mkdir -p "$DESKTOP_DIR"
    sudo chown $USER:$USER "$DESKTOP_DIR"
fi

# Create a desktop shortcut for AdsPower
DESKTOP_FILE="$DESKTOP_DIR/AdsPower.desktop"
echo -e "${INFO}Creating desktop shortcut for AdsPower.(Made by cryptonodehindi)${NC}"

sudo tee $DESKTOP_FILE > /dev/null <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=AdsPower
Comment=Launch AdsPower
Exec=/opt/AdsPower/AdsPower
Icon=/opt/AdsPower/resources/app/static/img/icon.png
Terminal=false
StartupNotify=true
Categories=Utility;Application;
EOL

# Set permissions for the desktop file
sudo chmod +x $DESKTOP_FILE
sudo chown $USER:$USER $DESKTOP_FILE

# Restart services
echo -e "${INFO}Restarting XRDP service...${NC}"
sudo systemctl restart xrdp

echo -e "${INFO}Enabling XRDP service at startup...${NC}"
sudo systemctl enable xrdp

# Configure firewall
echo -e "${INFO}Configuring firewall for XRDP...${NC}"
sudo ufw allow 3389/tcp
sudo ufw allow 5910/tcp
sudo ufw reload

# Get the server IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

# Final message
echo -e "${GREEN}XRDP Installation completed successfully!${NC}"
echo -e "${INFO}You can now connect via Remote Desktop with the following details:${NC}"
echo -e "${INFO}IP ADDRESS: ${GREEN}$IP_ADDR${NC}"
echo -e "${INFO}USERNAME: ${GREEN}$USER${NC}"
echo -e "${INFO}PASSWORD: ${GREEN}$PASSWORD${NC}"
echo -e "${INFO}PORT: ${GREEN}3389 (default) or 5910 (alternative)${NC}"
echo -e "${YELLOW}Note: If connection fails, try both ports.${NC}"

# Display thank you message
echo "========================================"
echo -e "${YELLOW} Thanks for using the script${NC}"
echo -e "-------------------------------------"

# Large ASCII Text with BANNER color
echo -e "${BANNER}  CCCCC  RRRRR   Y   Y  PPPP   TTTTT  OOO      N   N   OOO   DDDD  EEEEE      H   H  III  N   N  DDDD   III${NC}"
echo -e "${BANNER} C       R   R    Y Y   P  P     T   O   O     NN  N  O   O  D   D E          H   H   I   NN  N  D   D   I ${NC}"
echo -e "${BANNER} C       RRRRR     Y    PPPP     T   O   O     N N N  O   O  D   D EEEE       HHHHH   I   N N N  D   D   I ${NC}"
echo -e "${BANNER} C       R   R     Y    P        T   O   O     N  NN  O   O  D   D E          H   H   I   N  NN  D   D   I ${NC}"
echo -e "${BANNER}  CCCCC  R    R    Y    P        T    OOO      N   N   OOO   DDDD  EEEEE      H   H  III  N   N  DDDD   III${NC}"

echo "============================================"

# Use different colors for each link to make them pop out more
echo -e "${YELLOW}Telegram: ${GREEN}https://t.me/cryptonodehindi${NC}"
echo -e "${YELLOW}Twitter: ${GREEN}@CryptonodeHindi${NC}"
echo -e "${YELLOW}YouTube: ${GREEN}https://www.youtube.com/@CryptonodesHindi${NC}"
echo -e "${YELLOW}Medium: ${BLUE}https://medium.com/@cryptonodehindi${NC}"

echo "============================================="
