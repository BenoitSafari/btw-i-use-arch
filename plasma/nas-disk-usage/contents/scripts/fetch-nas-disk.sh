#!/bin/bash
# Fetches disk usage from a remote NAS via SSH + df and emits JSON on stdout.
# Authenticates via sshpass, reading the password from KWallet.
#
# Config file (required): ~/.config/btw-i-use-arch/nas.json
#   { "host": "nas.local", "port": 22, "user": "admin", "paths": ["/volume1","/volume2"] }
#   `paths` is optional — if omitted, all /volumeN mounts are reported.
#
# Password must be stored in KWallet under folder "asustor-<user>-pwd", key "nas_password".
# Use the helper, which prompts without echoing and verifies the write:
#   bash scripts/set-nas-password.sh

CONFIG="$HOME/.config/btw-i-use-arch/nas.json"

emit_error() {
    jq -cn --arg msg "$1" '{error: $msg, volumes: []}'
    exit 0
}

command -v jq >/dev/null || { echo '{"error":"jq not installed","volumes":[]}'; exit 0; }
command -v sshpass >/dev/null || emit_error "sshpass not installed (pacman -S sshpass)"
command -v kwallet-query >/dev/null || emit_error "kwallet-query not found"
[[ -f "$CONFIG" ]] || emit_error "config missing: $CONFIG"

HOST=$(jq -r '.host // ""' "$CONFIG")
NAS_USER=$(jq -r '.user // ""' "$CONFIG")
PORT=$(jq -r '.port // 22' "$CONFIG")
PATHS=$(jq -r '.paths // [] | join(" ")' "$CONFIG")

[[ -z "$HOST" ]] && emit_error "host missing in config"
[[ -z "$NAS_USER" ]] && emit_error "user missing in config"

WALLET_FOLDER="asustor-${NAS_USER}-pwd"
if ! PASS=$(kwallet-query -r nas_password -f "$WALLET_FOLDER" kdewallet 2>/dev/null); then
    emit_error "KWallet folder '$WALLET_FOLDER' or key 'nas_password' missing (run: kwallet-query -w nas_password -f $WALLET_FOLDER kdewallet)"
fi
[[ -z "$PASS" ]] && emit_error "empty password in KWallet folder '$WALLET_FOLDER'"

if [[ -n "$PATHS" ]]; then
    REMOTE="df -B1 --output=source,size,used,avail,target $PATHS 2>/dev/null"
else
    REMOTE="df -B1 --output=source,size,used,avail,target | awk 'NR==1 || \$NF ~ /^\\/volume[0-9]+$/'"
fi

SSH_OPTS=(-o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -p "$PORT")
SSH_OUT=$(SSHPASS="$PASS" sshpass -e ssh "${SSH_OPTS[@]}" "$NAS_USER@$HOST" "$REMOTE" 2>/dev/null)
[[ $? -ne 0 ]] && emit_error "SSH connection failed (host=$HOST port=$PORT user=$NAS_USER)"

VOLUMES=$(echo "$SSH_OUT" | awk '
    NR > 1 && NF >= 5 {
        name = $5
        sub("^/volume", "Volume ", name)
        printf "{\"source\":\"%s\",\"size\":%s,\"used\":%s,\"avail\":%s,\"target\":\"%s\",\"name\":\"%s\"}\n", $1, $2, $3, $4, $5, name
    }
' | jq -s '.')

jq -cn --arg host "$HOST" --argjson volumes "$VOLUMES" '{host: $host, volumes: $volumes}'
