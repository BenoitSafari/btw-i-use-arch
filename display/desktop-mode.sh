#!/bin/bash
###############################################################
# [BTW-I-USE-ARCH] Display — Desktop Mode
# Iiyama (DP-3) only: 3440x1440 @ 120 Hz, TV (HDMI-A-1) off.
###############################################################
set -euo pipefail

# --- Configuration -------------------------------------------------
PRIMARY="DP-3"              # Iiyama ultra-wide
SECONDARY="HDMI-A-1"        # TV (disabled in this mode)
PRIMARY_MODE="3440x1440@120"
PRIMARY_SCALE="1"
# Audio: move sound back to the Iiyama (GPU connector "HDMI 3")
AUDIO_CARD="alsa_card.pci-0000_03_00.1"
AUDIO_PROFILE="output:hdmi-stereo-extra2"
AUDIO_SINK="alsa_output.pci-0000_03_00.1.hdmi-stereo-extra2"
# -------------------------------------------------------------------

notify() { # $1=title $2=body $3=icon
    command -v notify-send >/dev/null 2>&1 \
        && notify-send -a "Display" -i "${3:-video-display}" "$1" "$2" || true
}

is_connected() {
    kscreen-doctor -j 2>/dev/null \
        | jq -e --arg n "$1" '.outputs[] | select(.name==$n) | .connected' >/dev/null 2>&1
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

if ! is_connected "$PRIMARY"; then
    echo "Error: $PRIMARY (Iiyama) not detected." >&2
    notify "Desktop Mode — failed" "$PRIMARY (Iiyama) not detected." "dialog-error"
    exit 1
fi

echo "Switching to Desktop Mode: $PRIMARY @ $PRIMARY_MODE (scale $PRIMARY_SCALE), $SECONDARY off."

# mirror.none breaks any leftover cloning (coming back from TV Mode);
# no-op if the Iiyama was not cloned.
# NB: "mirror.0" does NOT work — kscreen-doctor looks for the output with id 0,
# fails to find it, and leaves the replication in place.
args=(
    output."$PRIMARY".mirror.none
    output."$PRIMARY".enable
    output."$PRIMARY".mode."$PRIMARY_MODE"
    output."$PRIMARY".scale."$PRIMARY_SCALE"
    output."$PRIMARY".position.0,0
    output."$SECONDARY".disable
)

if kscreen-doctor "${args[@]}"; then
    switch_audio
    notify "Desktop Mode" "$PRIMARY · 3440×1440 @ 120 Hz · sound → Iiyama" "video-display"
    echo "OK."
else
    notify "Desktop Mode — failed" "kscreen-doctor returned an error." "dialog-error"
    echo "Failed to apply the configuration." >&2
    exit 1
fi
