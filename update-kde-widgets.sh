#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="kpackagetool6"
TYPE="Plasma/Applet"

WIDGETS=(
    "com.benoitsafari.ipdisplay:plasma/ip-display"
    "com.benoitsafari.systemmonitorbar:plasma/system-monitor-bar"
    "com.benoitsafari.diskusage:plasma/disk-usage"
    "com.benoitsafari.nasdiskusage:plasma/nas-disk-usage"
)

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing/Updating KDE Plasma widgets."
echo "###############################################################"

for entry in "${WIDGETS[@]}"; do
    ID="${entry%%:*}"
    PATH_REL="${entry##*:}"

    if $TOOL --type "$TYPE" --show "$ID" &>/dev/null; then
        echo "Removing $ID..."
        $TOOL --type "$TYPE" --remove "$ID"
    fi

    echo "Installing $ID..."
    $TOOL --type "$TYPE" --install "$SCRIPT_DIR/$PATH_REL"

    INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$ID"
    if [[ -d "$INSTALL_DIR/contents/scripts" ]]; then
        find "$INSTALL_DIR/contents/scripts" -type f -name "*.sh" -exec chmod +x {} \;
    fi
done

echo "KDE widgets installed. You may need to run 'plasmashell --replace &' to see changes."
