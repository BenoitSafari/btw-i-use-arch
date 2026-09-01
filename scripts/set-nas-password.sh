#!/bin/bash
# Stores the NAS password in KWallet, where the nas-disk-usage widget reads it.
# Usage: bash scripts/set-nas-password.sh

set -euo pipefail

CONFIG="$HOME/.config/btw-i-use-arch/nas.json"
KEY="nas_password"

command -v jq >/dev/null || { echo "jq not installed (pacman -S jq)" >&2; exit 1; }
command -v kwallet-query >/dev/null || { echo "kwallet-query not found (pacman -S kwallet)" >&2; exit 1; }

if [[ ! -f "$CONFIG" ]]; then
    echo "Config missing: $CONFIG" >&2
    exit 1
fi

NAS_USER=$(jq -r '.user // ""' "$CONFIG")
if [[ -z "$NAS_USER" ]]; then
    echo "user field missing in $CONFIG" >&2
    exit 1
fi

FOLDER="asustor-${NAS_USER}-pwd"

# read returns non-zero when stdin ends without a newline, even though it did
# fill the variable — so judge on the content, not on the exit status. That
# also makes `printf '%s' secret | set-nas-password.sh` work.
read -rs -p "NAS password for ${NAS_USER}: " PASSWORD || true
echo
if [[ -z "$PASSWORD" ]]; then
    echo "No password entered, nothing stored." >&2
    exit 1
fi

# The password goes over stdin, never as an argument: /proc/<pid>/cmdline is
# world-readable. kwallet-query creates the folder if it does not exist and
# strips the trailing newline.
if ! printf '%s' "$PASSWORD" | kwallet-query -w "$KEY" -f "$FOLDER" kdewallet; then
    echo "Write failed — is kdewallet unlocked?" >&2
    exit 1
fi

if [[ "$(kwallet-query -r "$KEY" -f "$FOLDER" kdewallet 2>/dev/null)" == "$PASSWORD" ]]; then
    echo "OK: stored in kdewallet / $FOLDER / $KEY"
else
    echo "Stored but verification failed" >&2
    exit 1
fi
