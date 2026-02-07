#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo "################################################################"
    echo "# [ARCH-INSTALL-SCRIPT]"
    echo "# This script should not be used as root!"
    echo "################################################################"
    exit 1
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Install/Update yay AUR helper."
echo "###############################################################"
if ! command -v yay &> /dev/null; then
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing & Configuring Snapd (AUR)."
echo "###############################################################"
yay -S --noconfirm --needed snapd
sudo systemctl enable --now snapd.socket
if [ ! -L /snap ]; then
    echo "Creating /snap symlink..."
    sudo ln -s /var/lib/snapd/snap /snap
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing pamac."
echo "###############################################################"
yay -S --noconfirm libpamac-full pamac-cli pamac

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Configuring Pamac features."
echo "###############################################################"
PAMAC_CONF="/etc/pamac.conf"

if [ ! -f "$PAMAC_CONF" ]; then
    echo "Config file not found. Creating a new one..."
    sudo tee "$PAMAC_CONF" > /dev/null <<EOF
### Pamac Configuration Created by arch-post-install.sh
EnableAUR
CheckAURUpdates
EnableSnap
EnableFlatpak
EOF

else
    echo "Config file found. Enabling features..."
    sudo sed -i 's/#EnableAUR/EnableAUR/' "$PAMAC_CONF"
    sudo sed -i 's/#CheckAURUpdates/CheckAURUpdates/' "$PAMAC_CONF"
    sudo sed -i 's/#EnableSnap/EnableSnap/' "$PAMAC_CONF"
    sudo sed -i 's/#EnableFlatpak/EnableFlatpak/' "$PAMAC_CONF"
fi

# Custom parts
cp ./desktop-overrides/kitty.desktop ~/.local/share/applications/kitty.desktop
chmod +x ./arch-post-install-*.sh
./arch-post-install-apps.sh
./arch-post-install-theme.sh
./arch-post-install-node.sh

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Post-install complete!"
echo "###############################################################"
echo "You can now reboot your machine and brag about being an Arch user!"