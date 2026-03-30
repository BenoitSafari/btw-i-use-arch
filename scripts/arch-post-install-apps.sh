#!/bin/bash

user_apps_aur=(
    brave-bin
    jre
    rider
    webstorm
    webstorm-jre
    datagrip
    datagrip-jre
    vscodium-bin
    vscodium-marketplace
    vesktop-bin
    teams-for-linux-bin
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
echo "# [BTW-I-USE-ARCH] Installing user apps from official repositories."
echo "###############################################################"
sudo pacman -Syu --noconfirm "${user_apps[@]}"

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing AUR apps."
echo "###############################################################"
yay -S --noconfirm --needed "${user_apps_aur[@]}"
