#!/bin/bash

user_apps_aur=(
    brave-bin
    p7zip-gui
    pinta
    jetbrains-toolbox
    vscodium-bin
    vscodium-marketplace
)
user_apps=(
    qbittorrent 
    bitwarden
    podman 
    podman-desktop
    dotnet-sdk-6.0
    dotnet-sdk-8.0
    dotnet-sdk-9.0
    dotnet-sdk
    aspnet-runtime-6.0
    aspnet-runtime-8.0
    aspnet-runtime-9.0
    aspnet-runtime
    jdk8-openjdk
)
user_ext=(
    gnome-shell-extension-appindicator 
    gnome-shell-extension-blur-my-shell
)

if [ "$(id -u)" -eq 0 ]; then
    echo "################################################################"
    echo "# [ARCH-INSTALL-SCRIPT]"
    echo "# This script should not be used as root!"
    echo "################################################################"
    exit 1
fi

username=$(whoami)
echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing user apps from official repositories."
echo "###############################################################"
sudo pacman -Syu --noconfirm "${user_apps[@]}"

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

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing AUR apps."
echo "###############################################################"
yay -S --noconfirm --needed "${user_apps_aur[@]}"

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing user desktop extensions."
echo "###############################################################"
yay -S --noconfirm ${user_ext[@]}

wallpaper_path="/home/$username/Pictures/wallpaper.jpg"
cp .wallpaper.jpg/ $wallpaper_path
gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_path"
gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path"
gsettings set org.gnome.desktop.background picture-options 'zoom'

gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com || true
gnome-extensions enable ubuntu-appindicators@ubuntu.com || true
gnome-extensions enable blur-my-shell@aunetx || true
gnome-extensions enable 'system-monitor@gnome-shell-extensions.gcampax.github.com'
gnome-extensions enable 'launch-new-instance@gnome-shell-extensions.gcampax.github.com'
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.appindicator"; then
    gsettings set org.gnome.shell.extensions.appindicator icon-size 16
fi
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.blur-my-shell"; then
    gsettings set org.gnome.shell.extensions.blur-my-shell hacks-level 1
    gsettings set org.gnome.shell.extensions.blur-my-shell settings-version 2
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder brightness 0.5
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder sigma 100
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder style-dialogs 1
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications blur true
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications enable-all false
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications dynamic-opacity false
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications sigma 60
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications whitelist "['kitty']"
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur true
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel brightness 0.6
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel sigma 100
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel override-background true
    
    BLUR_PIPELINES="{'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.59999999999999998>}>}>, <{'type': <'noise'>, 'id': <'effect_86633551428100'>, 'params': <@a{sv} {}>}>]>}}"
    gsettings set org.gnome.shell.extensions.blur-my-shell pipelines "$BLUR_PIPELINES"
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Overriding desktop entries."
echo "###############################################################"
cp ./desktop-overrides/kitty.desktop ~/.local/share/applications/kitty.desktop

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing Node (Node Version Switcher)."
echo "###############################################################"
chmod +x ./arch-post-install-node.sh
./arch-post-install-node.sh

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Post-install complete!"
echo "###############################################################"