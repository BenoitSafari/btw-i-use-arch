#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VSCODIUM_DIR="$HOME/.config/VSCodium/User"
CONF_DIR="$REPO_DIR/conf/vscodium"

profiles=(
    "default"
    "csharp:C# Dotnet:vscode"
    "typestazion:Typestazion:rocket"
    "react:React:code"
)

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring VSCodium profiles."
echo "###############################################################"

mkdir -p "$VSCODIUM_DIR"

cp "$CONF_DIR/default/settings.json" "$VSCODIUM_DIR/settings.json"
cp "$CONF_DIR/default/keybindings.json" "$VSCODIUM_DIR/keybindings.json"
echo "Default profile configured."

profile_entries=""

for entry in "${profiles[@]}"; do
    [[ "$entry" == "default" ]] && continue

    IFS=':' read -r folder name icon <<< "$entry"
    profile_id=$(echo -n "$name" | md5sum | cut -c1-8)
    profile_dir="$VSCODIUM_DIR/profiles/$profile_id"

    mkdir -p "$profile_dir"

    if [[ -f "$CONF_DIR/$folder/settings.json" ]]; then
        cp "$CONF_DIR/$folder/settings.json" "$profile_dir/settings.json"
    fi

    if [[ -n "$profile_entries" ]]; then
        profile_entries="$profile_entries,"
    fi
    profile_entries="$profile_entries{\"location\":\"$profile_id\",\"name\":\"$name\",\"icon\":\"$icon\",\"useDefaultFlags\":{\"keybindings\":true}}"

    echo "Profile '$name' configured in $profile_dir"
done

mkdir -p "$VSCODIUM_DIR/globalStorage"
STORAGE_FILE="$VSCODIUM_DIR/globalStorage/storage.json"

if [[ -f "$STORAGE_FILE" ]]; then
    tmp=$(mktemp)
    jq --argjson profiles "[$profile_entries]" '.userDataProfiles = $profiles' "$STORAGE_FILE" > "$tmp" && mv "$tmp" "$STORAGE_FILE"
else
    cat > "$STORAGE_FILE" <<EOF
{
    "userDataProfiles": [$profile_entries]
}
EOF
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing VSCodium extensions."
echo "###############################################################"

install_extensions() {
    local profile_name="$1"
    local ext_file="$2"

    if [[ ! -f "$ext_file" ]]; then
        return
    fi

    while IFS= read -r ext_id; do
        ext_id=$(echo "$ext_id" | tr -d '[:space:]')
        [[ -z "$ext_id" ]] && continue
        if [[ "$profile_name" == "Default" ]]; then
            codium --install-extension "$ext_id" --force 2>/dev/null
        else
            codium --profile "$profile_name" --install-extension "$ext_id" --force 2>/dev/null
        fi
    done < "$ext_file"
    echo "Extensions installed for profile '$profile_name'."
}

install_extensions "Default" "$CONF_DIR/default/extensions.txt"

for entry in "${profiles[@]}"; do
    [[ "$entry" == "default" ]] && continue
    IFS=':' read -r folder name icon <<< "$entry"
    install_extensions "$name" "$CONF_DIR/$folder/extensions.txt"
done
