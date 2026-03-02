#!/bin/bash

user_apps_aur=(
    brave-bin
    p7zip-gui
    pinta
    jre
    rider
    jetbrains-toolbox
    vscodium-bin
    vscodium-marketplace
    teams-for-linux-bin
)

user_apps_snap=(
    discord
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
    aspnet-targeting-pack
    dotnet-targeting-pack
    steam
    prismlauncher
)

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing user apps from official repositories."
echo "###############################################################"
sudo pacman -Syu --noconfirm "${user_apps[@]}"

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing AUR apps."
echo "###############################################################"
yay -S --noconfirm --needed "${user_apps_aur[@]}"

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing Snap apps."
echo "###############################################################"
sudo snap install "${user_apps_snap[@]}"
