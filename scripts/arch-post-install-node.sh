echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing Node.js and npm."
echo "###############################################################"

sudo pacman -S --noconfirm --needed nodejs npm

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring minimum-release-age (3 days)."
echo "###############################################################"

# Supply-chain mitigation: only install package versions published >= 3 days ago.
# npm uses 'min-release-age' (days) in ~/.npmrc.
# pnpm (>=10) reads 'minimumReleaseAge' (minutes) from ~/.config/pnpm/config.yaml only.

NPMRC="$HOME/.npmrc"
touch "$NPMRC"

# User-local npm prefix so global installs don't require sudo and don't collide with pacman files.
if ! grep -q "^prefix=" "$NPMRC"; then
    echo "prefix=$HOME/.local" >> "$NPMRC"
fi

if ! grep -q "^min-release-age=" "$NPMRC"; then
    echo "min-release-age=3" >> "$NPMRC"
fi

PNPM_CONFIG_DIR="$HOME/.config/pnpm"
PNPM_CONFIG="$PNPM_CONFIG_DIR/config.yaml"
mkdir -p "$PNPM_CONFIG_DIR"
if [ ! -f "$PNPM_CONFIG" ] || ! grep -q "^minimumReleaseAge:" "$PNPM_CONFIG"; then
    echo "minimumReleaseAge: 4320" >> "$PNPM_CONFIG"
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing pnpm globally via npm."
echo "###############################################################"

# Done after the .npmrc above so this install is itself subject to min-release-age.
npm install -g pnpm
