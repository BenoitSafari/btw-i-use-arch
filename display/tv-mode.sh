#!/bin/bash
###############################################################
# [BTW-I-USE-ARCH] Display — TV Mode
# TV (HDMI-A-1) source 3840x2160 @ 60 Hz, Iiyama (DP-3) cloned.
###############################################################
set -euo pipefail

# --- Configuration -------------------------------------------------
SOURCE="HDMI-A-1"          # TV = source screen for rendering
CLONE="DP-3"               # Iiyama = replicates the TV
SOURCE_MODE="3840x2160@60"
SOURCE_SCALE="1.7"         # shared desktop scale (tweak to taste)
# Audio: send sound to the TV (GPU connector "HDMI 4")
AUDIO_CARD="alsa_card.pci-0000_03_00.1"
AUDIO_PROFILE="output:hdmi-stereo-extra3"
AUDIO_SINK="alsa_output.pci-0000_03_00.1.hdmi-stereo-extra3"
# -------------------------------------------------------------------

notify() { # $1=title $2=body $3=icon
    command -v notify-send >/dev/null 2>&1 \
        && notify-send -a "Display" -i "${3:-video-television}" "$1" "$2" || true
}

is_connected() {
    kscreen-doctor -j 2>/dev/null \
        | jq -e --arg n "$1" '.outputs[] | select(.name==$n) | .connected' >/dev/null 2>&1
}

get_output_id() { # kscreen-doctor mirror expects the numeric id of the source
    local name="$1" id=""
    id=$(kscreen-doctor -j 2>/dev/null \
        | jq -r --arg n "$name" 'first(.outputs[] | select(.name==$n) | .id) // empty' 2>/dev/null || true)
    if [[ -z "$id" ]]; then # fallback: text parsing (strip ANSI codes)
        id=$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
            | grep -oP "Output:\s+\K[0-9]+(?=\s+$name)" | head -1 || true)
    fi
    printf '%s' "$id"
}

switch_audio() { # move GPU sound to the right connector (best effort, non-blocking)
    command -v pactl >/dev/null 2>&1 || return 0
    local i s
    # the HDMI/DP audio port only becomes available once the video output is active
    for i in $(seq 1 50); do
        if pactl list cards 2>/dev/null | grep -q "${AUDIO_PROFILE}:.*available: yes"; then break; fi
    done
    pactl set-card-profile "$AUDIO_CARD" "$AUDIO_PROFILE" 2>/dev/null || return 0
    for i in $(seq 1 50); do
        if pactl list sinks short 2>/dev/null | grep -q "$AUDIO_SINK"; then break; fi
    done
    pactl set-default-sink "$AUDIO_SINK" 2>/dev/null || true
    for s in $(pactl list sink-inputs short 2>/dev/null | awk '{print $1}'); do
        pactl move-sink-input "$s" "$AUDIO_SINK" 2>/dev/null || true
    done
}

for out in "$SOURCE" "$CLONE"; do
    if ! is_connected "$out"; then
        echo "Error: $out not detected (is the TV on and plugged in?)." >&2
        notify "TV Mode — failed" "$out not detected." "dialog-error"
        exit 1
    fi
done

SOURCE_ID="$(get_output_id "$SOURCE")"
if [[ -z "$SOURCE_ID" ]]; then
    echo "Error: could not resolve the id of $SOURCE." >&2
    notify "TV Mode — failed" "id of $SOURCE not found." "dialog-error"
    exit 1
fi

echo "Switching to TV Mode: $SOURCE @ $SOURCE_MODE (scale $SOURCE_SCALE), $CLONE cloned (source id $SOURCE_ID)."

if kscreen-doctor \
    output."$SOURCE".enable \
    output."$SOURCE".mode."$SOURCE_MODE" \
    output."$SOURCE".scale."$SOURCE_SCALE" \
    output."$SOURCE".position.0,0 \
    output."$CLONE".enable \
    output."$CLONE".mirror."$SOURCE_ID"; then
    switch_audio
    notify "TV Mode" "TV cloned · 3840×2160 @ 60 Hz · sound → TV" "video-television"
    echo "OK."
else
    notify "TV Mode — failed" "kscreen-doctor returned an error." "dialog-error"
    echo "Failed to apply the configuration." >&2
    exit 1
fi
