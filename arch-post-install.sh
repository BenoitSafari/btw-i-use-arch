#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo "################################################################"
    echo "# [BTW-I-USE-ARCH]"
    echo "# This script should not be used as root!"
    echo "################################################################"
    exit 1
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Install/Update yay AUR helper."
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
echo "# [BTW-I-USE-ARCH] Installing & Configuring Snapd (AUR)."
echo "###############################################################"
yay -S --noconfirm --needed snapd
sudo systemctl enable --now snapd.socket
if [ ! -L /snap ]; then
    echo "Creating /snap symlink..."
    sudo ln -s /var/lib/snapd/snap /snap
fi

chmod +x ./scripts/arch-post-install-*.sh
bash ./scripts/arch-post-install-pamac.sh
bash ./scripts/arch-post-install-apps.sh
bash ./scripts/arch-post-install-vscodium.sh
bash ./scripts/arch-post-install-node.sh

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing KDE Plasma widgets."
echo "###############################################################"
bash ./update-kde-widgets.sh

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Post-install complete!"
echo "###############################################################"
echo "You can now reboot your machine and brag about being an Arch user!"