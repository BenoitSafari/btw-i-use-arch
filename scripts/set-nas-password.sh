#!/bin/bash
# Stores the NAS password in KWallet via DBus.
# Workaround: kwallet-query -w is broken on some installs (returns 0 without writing).
# Usage: ./scripts/set-nas-password.sh

set -e

CONFIG="$HOME/.config/btw-i-use-arch/nas.json"
if [[ ! -f "$CONFIG" ]]; then
    echo "Config missing: $CONFIG" >&2
    exit 1
fi

USER=$(jq -r '.user // ""' "$CONFIG")
if [[ -z "$USER" ]]; then
    echo "user field missing in $CONFIG" >&2
    exit 1
fi

FOLDER="asustor-${USER}-pwd"
KEY="nas_password"
APPID="btw-i-use-arch"

read -rs -p "NAS password for ${USER}: " PASSWORD
echo

WID=$(qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.open kdewallet 0 "$APPID")
if [[ -z "$WID" || "$WID" == "-1" ]]; then
    echo "Failed to open kdewallet (locked?)" >&2
    exit 1
fi

if [[ "$(qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.hasFolder "$WID" "$FOLDER" "$APPID")" != "true" ]]; then
    qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.createFolder "$WID" "$FOLDER" "$APPID" >/dev/null
fi

RC=$(qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.writePassword "$WID" "$FOLDER" "$KEY" "$PASSWORD" "$APPID")
if [[ "$RC" != "0" ]]; then
    echo "writePassword returned $RC" >&2
    exit 1
fi

# Verify via kwallet-query (read side works fine)
if VERIFY=$(kwallet-query -r "$KEY" -f "$FOLDER" kdewallet 2>/dev/null) && [[ "$VERIFY" == "$PASSWORD" ]]; then
    echo "OK: stored in kdewallet / $FOLDER / $KEY"
else
    echo "Stored but verification failed" >&2
    exit 1
fi
