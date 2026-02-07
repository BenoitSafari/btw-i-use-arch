echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing Node (Node Version Switcher)."
echo "###############################################################"

export NVS_HOME="$HOME/.nvs"
git clone https://github.com/jasongin/nvs "$NVS_HOME"
source "$NVS_HOME/nvs.sh"

if ! grep -q "export NVS_HOME" "$HOME/.zshrc"; then
    echo "" >> "$HOME/.zshrc"
    echo "# --- NVS Configuration ---" >> "$HOME/.zshrc"
    echo "export NVS_HOME=\"\$HOME/.nvs\"" >> "$HOME/.zshrc"
    echo "[ -s \"\$NVS_HOME/nvs.sh\" ] && . \"\$NVS_HOME/nvs.sh\"" >> "$HOME/.zshrc"
fi

echo "Installing Node.js (LTS)..."
nvs add lts
nvs link lts