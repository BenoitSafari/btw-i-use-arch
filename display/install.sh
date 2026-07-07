#!/bin/bash
###############################################################
# [BTW-I-USE-ARCH] Installing display mode switchers
# Deploys the scripts + launchers into ~/.local/share/display
# and creates the symlinks for the K menu / KRunner.
###############################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/display"
APPS="$HOME/.local/share/applications"

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing display mode switchers."
echo "###############################################################"

mkdir -p "$DEST" "$APPS"

# Executable scripts
install -Dm755 "$SCRIPT_DIR/desktop-mode.sh" "$DEST/desktop-mode.sh"
install -Dm755 "$SCRIPT_DIR/tv-mode.sh"      "$DEST/tv-mode.sh"

# .desktop launchers (source of truth in ~/.local/share/display)
install -Dm755 "$SCRIPT_DIR/display-desktop-mode.desktop" "$DEST/display-desktop-mode.desktop"
install -Dm755 "$SCRIPT_DIR/display-tv-mode.desktop"      "$DEST/display-tv-mode.desktop"

# K menu / KRunner integration via symlinks
ln -sf "$DEST/display-desktop-mode.desktop" "$APPS/display-desktop-mode.desktop"
ln -sf "$DEST/display-tv-mode.desktop"      "$APPS/display-tv-mode.desktop"

# Refresh the launcher cache (if available)
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" || true

echo "Installed in: $DEST"
echo "Launchers   : $APPS/display-{desktop,tv}-mode.desktop"
echo "Search for \"Desktop Mode\" or \"TV Mode\" in KRunner (Alt+Space)."
