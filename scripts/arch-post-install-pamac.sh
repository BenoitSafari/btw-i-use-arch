#!/bin/bash

# Installs Pamac (GUI + CLI) and enables its AUR / Snap / Flatpak backends.
# Expects yay to be available — arch-post-install.sh installs it first.

PAMAC_CONF="/etc/pamac.conf"

pamac_pkgs=(
    libpamac-full          # core library, with AUR/Snap/Flatpak support
    pamac-all              # the GUI (pamac-manager, "Add/Remove Software")
    pamac-cli              # the command line frontend
    pamac-tray-plasma-git  # update notifier for Plasma
)

# Backend for the EnableFlatpak option below; snapd is installed by the caller.
extra_pkgs=(
    flatpak
)

if ! command -v yay &> /dev/null; then
    echo "yay not found — run arch-post-install.sh instead of this script directly." >&2
    exit 1
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing Pamac."
echo "###############################################################"

sudo pacman -S --noconfirm --needed "${extra_pkgs[@]}"
yay -S --noconfirm --needed "${pamac_pkgs[@]}"

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring Pamac features."
echo "###############################################################"

# Uncomments an option in pamac.conf, appending it if the key is absent
# altogether. Anchored at the start of the line so the surrounding prose
# comments are left alone.
enable_option() {
    local key="$1"

    if grep -qE "^${key}([[:space:]]|=|$)" "$PAMAC_CONF"; then
        echo "$key already enabled."
    elif grep -qE "^#[[:space:]]*${key}([[:space:]]|=|$)" "$PAMAC_CONF"; then
        sudo sed -i -E "s/^#[[:space:]]*(${key}([[:space:]]|=|$).*)$/\1/" "$PAMAC_CONF"
        echo "$key enabled."
    else
        echo "$key" | sudo tee -a "$PAMAC_CONF" > /dev/null
        echo "$key appended."
    fi
}

if [ ! -f "$PAMAC_CONF" ]; then
    echo "Config file not found. Creating a new one..."
    sudo tee "$PAMAC_CONF" > /dev/null <<EOF
### Pamac Configuration Created by arch-post-install-pamac.sh
EnableAUR
CheckAURUpdates
EnableSnap
EnableFlatpak
EOF
else
    echo "Config file found. Enabling features..."
    enable_option EnableAUR
    enable_option CheckAURUpdates
    enable_option EnableSnap
    enable_option EnableFlatpak
fi
