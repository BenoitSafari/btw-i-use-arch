#!/bin/bash
# Applies the reference KDE Plasma 6 desktop look (panels, theme, fonts, custom widgets)
# on a fresh Arch + Plasma install. Idempotent — safe to re-run.
#
# Usage: bash apply-benoit-layout.sh [options]
#   --no-packages           Skip pacman/yay dependency installation
#   --no-icons              Skip the Tela icon theme download
#   --no-widgets            Skip installing the custom + third-party plasmoids
#   --no-nas                Drop the NAS disk usage widget from the top panel
#   --panel-margin=<px>     Side margin of the top panel (default: 40)
#   --thermal-sensor=<id>   ksystemstats sensor for the thermal widget
#                           (default: cpu/all/averageTemperature ;
#                            the reference desktop uses gpu/gpu1/temperature)
#   --dry-run               Print what would change without touching anything
#   -h, --help              Show this help

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/conf/plasma/appletsrc.tpl"
COLORSCHEME_SRC="$SCRIPT_DIR/conf/plasma/color-schemes/AdwaitaDark.colors"
WALLPAPER_SRC="$SCRIPT_DIR/assets/wallpaper.jpg"

APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
WALLPAPER_DEST="$HOME/Pictures/wallpaper.jpg"
BACKUP_DIR="$HOME/.local/share/btw-i-use-arch/kde-backup-$(date +%Y%m%d-%H%M%S)"

INSTALL_PACKAGES=1
INSTALL_ICONS=1
INSTALL_WIDGETS=1
WITH_NAS=1
PANEL_MARGIN=40
THERMAL_SENSOR="cpu/all/averageTemperature"
THERMAL_LABEL="CPU Temperature"
DRY_RUN=0

# Panel 400 applet ids that may be dropped when their widget is unavailable
APPLET_NAS=457
APPLET_THERMAL=461

banner() {
    echo
    echo "###############################################################"
    echo "# [BTW-I-USE-ARCH] $1"
    echo "###############################################################"
}

warn() { echo "  ! $*" >&2; }

run() {
    if (( DRY_RUN )); then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# kwriteconfig6 wrapper honouring --dry-run
kw() { run kwriteconfig6 "$@"; }

for arg in "$@"; do
    case "$arg" in
        --no-packages)      INSTALL_PACKAGES=0 ;;
        --no-icons)         INSTALL_ICONS=0 ;;
        --no-widgets)       INSTALL_WIDGETS=0 ;;
        --no-nas)           WITH_NAS=0 ;;
        --panel-margin=*)   PANEL_MARGIN="${arg#*=}" ;;
        --thermal-sensor=*) THERMAL_SENSOR="${arg#*=}" ;;
        --dry-run)          DRY_RUN=1 ;;
        -h|--help)          awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' \
                                "${BASH_SOURCE[0]}"; exit 0 ;;
        *)                  echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

###############################################################
# Sanity checks
###############################################################

if [ "$(id -u)" -eq 0 ]; then
    echo "This script must not be run as root — it configures the current user's desktop." >&2
    exit 1
fi

for cmd in kwriteconfig6 kpackagetool6 plasma-apply-lookandfeel plasma-apply-colorscheme; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Missing $cmd — is this a KDE Plasma 6 session?" >&2
        exit 1
    fi
done

[[ -f "$TPL" ]] || { echo "Template not found: $TPL" >&2; exit 1; }

if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]]; then
    warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}' — run this from a Plasma session."
fi

###############################################################
# Target machine detection
###############################################################

banner "Detecting target display setup."

SCREEN_WIDTH=1920
SCREEN_COUNT=1
if command -v kscreen-doctor &>/dev/null && command -v jq &>/dev/null; then
    screens_json="$(kscreen-doctor -j 2>/dev/null)"
    if [[ -n "$screens_json" ]]; then
        w="$(jq -r '[.outputs[] | select(.enabled)] | sort_by(.priority) | .[0]
                    | (.size.width / (.scale // 1)) | floor // empty' <<<"$screens_json" 2>/dev/null)"
        c="$(jq -r '[.outputs[] | select(.enabled)] | length' <<<"$screens_json" 2>/dev/null)"
        [[ "$w" =~ ^[0-9]+$ ]] && SCREEN_WIDTH="$w"
        [[ "$c" =~ ^[0-9]+$ ]] && SCREEN_COUNT="$c"
    fi
fi

PANEL_LENGTH=$(( SCREEN_WIDTH - 2 * PANEL_MARGIN ))
(( PANEL_LENGTH < 200 )) && PANEL_LENGTH="$SCREEN_WIDTH"

# The reference desktop pads the 4K wallpaper on a 3440px screen (FillMode 6).
# On anything narrower that would crop hard, so scale-and-crop instead.
if (( SCREEN_WIDTH >= 3440 )); then
    WALLPAPER_FILL=6
else
    WALLPAPER_FILL=2
fi

echo "  Primary screen : ${SCREEN_WIDTH}px logical (${SCREEN_COUNT} enabled output(s))"
echo "  Top panel      : ${PANEL_LENGTH}px, ${PANEL_MARGIN}px side margin"
echo "  Wallpaper fill : $WALLPAPER_FILL ($([ "$WALLPAPER_FILL" = 6 ] && echo 'padded' || echo 'scaled & cropped'))"

ACTIVITY_ID="$(qdbus6 org.kde.ActivityManager /ActivityManager/Activities CurrentActivity 2>/dev/null)"
if [[ ! "$ACTIVITY_ID" =~ ^[0-9a-f-]{36}$ ]]; then
    ACTIVITY_ID="$(grep -m1 -oE '^activityId=[0-9a-f-]{36}$' "$APPLETSRC" 2>/dev/null | cut -d= -f2)"
fi
if [[ ! "$ACTIVITY_ID" =~ ^[0-9a-f-]{36}$ ]]; then
    echo "Could not determine the current Plasma activity UUID." >&2
    echo "Start a Plasma session first, then re-run this script." >&2
    exit 1
fi
echo "  Activity       : $ACTIVITY_ID"

###############################################################
# Backup
###############################################################

banner "Backing up the current KDE configuration."

run mkdir -p "$BACKUP_DIR"
for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kdeglobals kwinrc breezerc \
         krunnerrc plasmarc plasmaparc dolphinrc konsolerc kscreenlockerrc; do
    [[ -f "$HOME/.config/$f" ]] && run cp -a "$HOME/.config/$f" "$BACKUP_DIR/"
done
[[ -d "$HOME/.config/kdedefaults" ]] && run cp -a "$HOME/.config/kdedefaults" "$BACKUP_DIR/"
echo "  Backup: $BACKUP_DIR"

###############################################################
# Dependencies
###############################################################

if (( INSTALL_PACKAGES )); then
    banner "Installing theme, font and widget dependencies."

    pkgs=(
        adwaita-fonts              # Adwaita Sans / Adwaita Mono — UI fonts
        ttf-jetbrains-mono-nerd    # digital clock font
        breeze-gtk kde-gtk-config  # GTK apps follow the Plasma theme
        breeze-icons breeze        # fallback icons + Breeze widget style
        jq curl                    # ip-display / nas-disk-usage widgets
        sshpass                    # nas-disk-usage widget (SSH auth)
        git                        # icon theme + thermalmonitor checkout
        kitty                      # dock launcher
    )
    run sudo pacman -S --needed --noconfirm "${pkgs[@]}"
else
    banner "Skipping dependency installation (--no-packages)."
fi

###############################################################
# Tela icon theme
###############################################################

if (( INSTALL_ICONS )) && [[ ! -d "$HOME/.local/share/icons/Tela" && ! -d /usr/share/icons/Tela ]]; then
    banner "Installing the Tela icon theme."
    tela_tmp="$(mktemp -d)"
    if run git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme.git "$tela_tmp"; then
        run mkdir -p "$HOME/.local/share/icons"
        run bash "$tela_tmp/install.sh" -d "$HOME/.local/share/icons"
    else
        warn "Tela checkout failed — falling back to breeze-dark icons."
        ICON_THEME="breeze-dark"
    fi
    run rm -rf "$tela_tmp"
elif (( INSTALL_ICONS )); then
    banner "Tela icon theme already present — skipping."
fi
ICON_THEME="${ICON_THEME:-Tela}"
if [[ "$ICON_THEME" == "Tela" && ! -d "$HOME/.local/share/icons/Tela" && ! -d /usr/share/icons/Tela ]]; then
    warn "Tela not installed — using breeze-dark instead."
    ICON_THEME="breeze-dark"
fi

###############################################################
# Widgets
###############################################################

HAVE_THERMAL=1
if (( INSTALL_WIDGETS )); then
    banner "Installing the custom Plasma widgets."
    run bash "$SCRIPT_DIR/update-kde-widgets.sh"

    banner "Installing the Thermal Monitor widget (third-party)."
    if kpackagetool6 --type Plasma/Applet --show org.kde.olib.thermalmonitor &>/dev/null; then
        echo "  Already installed."
    else
        thermal_tmp="$(mktemp -d)"
        if run git clone --depth 1 https://invent.kde.org/olib/thermalmonitor.git "$thermal_tmp"; then
            thermal_pkg="$thermal_tmp"
            [[ -f "$thermal_tmp/package/metadata.json" ]] && thermal_pkg="$thermal_tmp/package"
            if ! run kpackagetool6 --type Plasma/Applet --install "$thermal_pkg"; then
                warn "Thermal Monitor install failed — the widget will be left out of the panel."
                HAVE_THERMAL=0
            fi
        else
            warn "Thermal Monitor checkout failed — the widget will be left out of the panel."
            HAVE_THERMAL=0
        fi
        run rm -rf "$thermal_tmp"
    fi
else
    banner "Skipping widget installation (--no-widgets)."
    kpackagetool6 --type Plasma/Applet --show org.kde.olib.thermalmonitor &>/dev/null || HAVE_THERMAL=0
fi

###############################################################
# Wallpaper & color scheme
###############################################################

banner "Installing the wallpaper and the AdwaitaDark color scheme."

if [[ -f "$WALLPAPER_SRC" ]]; then
    run mkdir -p "$HOME/Pictures"
    run cp -f "$WALLPAPER_SRC" "$WALLPAPER_DEST"
    echo "  Wallpaper: $WALLPAPER_DEST"
else
    warn "assets/wallpaper.jpg missing — keeping whatever is at $WALLPAPER_DEST"
fi

run mkdir -p "$HOME/.local/share/color-schemes"
run cp -f "$COLORSCHEME_SRC" "$HOME/.local/share/color-schemes/AdwaitaDark.colors"

###############################################################
# Global theme
###############################################################

banner "Applying the global theme."

# Look-and-feel first: it resets colors, icons and decorations, so everything
# below must be applied after it.
run plasma-apply-lookandfeel --apply org.kde.breezedark.desktop
run plasma-apply-desktoptheme default
run plasma-apply-colorscheme AdwaitaDark
run plasma-apply-cursortheme breeze_cursors

kw --file kdeglobals --group Icons --key Theme "$ICON_THEME"
if [[ -x /usr/lib/plasma-changeicons ]]; then
    run /usr/lib/plasma-changeicons "$ICON_THEME"
fi

# kdedefaults mirrors the look-and-feel package defaults; keep it consistent.
kw --file kdedefaults/kdeglobals --group General --key ColorScheme AdwaitaDark
kw --file kdedefaults/kdeglobals --group Icons   --key Theme breeze-dark
kw --file kdedefaults/kdeglobals --group KDE     --key widgetStyle Breeze
kw --file kdedefaults/plasmarc   --group Theme   --key name default
kw --file kdedefaults/kcminputrc --group Mouse   --key cursorTheme breeze_cursors

###############################################################
# Fonts
###############################################################

banner "Applying fonts (Adwaita Sans / Adwaita Mono)."

UI_FONT="Adwaita Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
SMALL_FONT="Adwaita Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
MONO_FONT="Adwaita Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

kw --file kdeglobals --group General --key font                 "$UI_FONT"
kw --file kdeglobals --group General --key menuFont             "$UI_FONT"
kw --file kdeglobals --group General --key toolBarFont          "$UI_FONT"
kw --file kdeglobals --group General --key smallestReadableFont "$SMALL_FONT"
kw --file kdeglobals --group General --key fixed                "$MONO_FONT"
kw --file kdeglobals --group WM      --key activeFont           "$UI_FONT"

kw --file kdeglobals --group General --key XftAntialias  --type bool true
kw --file kdeglobals --group General --key XftHintStyle  hintslight
kw --file kdeglobals --group General --key XftSubPixel   none

###############################################################
# Workspace behaviour & chrome
###############################################################

banner "Applying workspace appearance settings."

kw --file kdeglobals --group KDE     --key LookAndFeelPackage org.kde.breezedark.desktop
kw --file kdeglobals --group KDE     --key contrast      4
kw --file kdeglobals --group KDE     --key frameContrast 0.2
kw --file kdeglobals --group KDE     --key DndBehavior   MoveIfSameDevice
kw --file kdeglobals --group KDE     --key ShowDeleteCommand --type bool false
kw --file kdeglobals --group General --key LastUsedCustomAccentColor 19,142,211
kw --file kdeglobals --group General --key TerminalApplication kitty
kw --file kdeglobals --group General --key TerminalService     kitty.desktop
kw --file kdeglobals --group Sounds  --key Theme freedesktop

# Breeze window decoration: no borders, rounded corners, medium outline
kw --file breezerc --group Common --key OutlineEnabled   --type bool true
kw --file breezerc --group Common --key OutlineIntensity OutlineMedium
kw --file breezerc --group Common --key RoundedCorners   --type bool true

kw --file kwinrc --group org.kde.kdecoration2 --key library        org.kde.breeze
kw --file kwinrc --group org.kde.kdecoration2 --key theme          Breeze
kw --file kwinrc --group org.kde.kdecoration2 --key BorderSize     None
kw --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto --type bool false

# Desktop effects
kw --file kwinrc --group Effect-blur          --key Saturation   320
kw --file kwinrc --group Effect-translucency  --key MoveResize   100
kw --file kwinrc --group Effect-wobblywindows --key AdvancedMode --type bool true
kw --file kwinrc --group Effect-wobblywindows --key Drag         50
kw --file kwinrc --group Effect-wobblywindows --key Stiffness    50
kw --file kwinrc --group Effect-wobblywindows --key ResizeWobble --type bool false

kw --file kwinrc --group Plugins --key blurEnabled                     --type bool true
kw --file kwinrc --group Plugins --key wobblywindowsEnabled            --type bool true
kw --file kwinrc --group Plugins --key bouncingWindowsEnabled          --type bool true
kw --file kwinrc --group Plugins --key mouseclickEnabled               --type bool true
kw --file kwinrc --group Plugins --key dialogparentEnabled             --type bool false
kw --file kwinrc --group Plugins --key gamecontrollerEnabled           --type bool false
kw --file kwinrc --group Plugins --key overviewEnabled                 --type bool false
kw --file kwinrc --group Plugins --key scaleEnabled                    --type bool false
kw --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled --type bool false

kw --file kwinrc --group TabBox  --key LayoutName     compact
kw --file kwinrc --group TabBox  --key ActivitiesMode 0
kw --file kwinrc --group TabBox  --key DesktopMode    0
kw --file kwinrc --group Windows --key SnapOnlyWhenOverlapping --type bool true

# Free-floating KRunner with immediate completion
kw --file krunnerrc --group General --key FreeFloating    --type bool true
kw --file krunnerrc --group General --key historyBehavior ImmediateCompletion

# Volume OSD
kw --file plasmaparc --group General --key MuteOsd                     --type bool false
kw --file plasmaparc --group General --key MutedMicrophoneReminderOsd  --type bool false

# Lock screen: same wallpaper, and auto-lock disabled like the reference desktop
kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
   --key Image "$WALLPAPER_DEST"
kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
   --key PreviewImage "$WALLPAPER_DEST"
kw --file kscreenlockerrc --group Daemon --key Autolock     --type bool false
kw --file kscreenlockerrc --group Daemon --key LockOnResume --type bool false
kw --file kscreenlockerrc --group Daemon --key Timeout      0

# Dolphin / Konsole chrome
kw --file dolphinrc --group MainWindow --key MenuBar Disabled
kw --file dolphinrc --group General    --key ShowFullPathInTitlebar --type bool true
kw --file dolphinrc --group DetailsMode --key ExpandableFolders --type bool false
kw --file konsolerc --group KonsoleWindow --key RemoveWindowTitleBarAndFrame --type bool true

# GTK applications follow the same theme
for gtk in gtk-3.0 gtk-4.0; do
    run mkdir -p "$HOME/.config/$gtk"
    kw --file "$HOME/.config/$gtk/settings.ini" --group Settings --key gtk-theme-name      Breeze
    kw --file "$HOME/.config/$gtk/settings.ini" --group Settings --key gtk-icon-theme-name "$ICON_THEME"
    kw --file "$HOME/.config/$gtk/settings.ini" --group Settings --key gtk-cursor-theme-name breeze_cursors
    kw --file "$HOME/.config/$gtk/settings.ini" --group Settings --key gtk-font-name       "Adwaita Sans,  10"
    kw --file "$HOME/.config/$gtk/settings.ini" --group Settings --key gtk-application-prefer-dark-theme --type bool true
done

###############################################################
# Panel layout
###############################################################

banner "Building the panel layout."

# Drops every INI section whose header starts with $2 from file $1.
ini_drop_sections() {
    local file="$1" prefix="$2" tmp
    tmp="$(mktemp)"
    awk -v prefix="$prefix" '
        /^\[/ { skip = (substr($0, 1, length(prefix)) == prefix) }
        !skip
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Removes applet id $2 from the AppletOrder key of section $3 in file $1.
# Reads the current value rather than a known one, so repeated calls compose.
applet_order_remove() {
    local file="$1" id="$2" section="$3" tmp
    tmp="$(mktemp)"
    awk -v id="$id" -v section="$section" '
        /^\[/ { in_section = ($0 == section) }
        in_section && /^AppletOrder=/ {
            n = split(substr($0, 13), items, ";")
            out = ""
            for (i = 1; i <= n; i++) {
                if (items[i] == id || items[i] == "") continue
                out = out (out == "" ? "" : ";") items[i]
            }
            print "AppletOrder=" out
            next
        }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

STAGING="$(mktemp)"
THERMAL_SENSORS="[{\"name\":\"$THERMAL_LABEL\",\"sensorId\":\"$THERMAL_SENSOR\"}]"

# Strip the template's documentation header, then expand the placeholders.
sed -e '/^#/d' \
    -e "s|@HOME@|$HOME|g" \
    -e "s|@ACTIVITY_ID@|$ACTIVITY_ID|g" \
    -e "s|@WALLPAPER@|$WALLPAPER_DEST|g" \
    -e "s|@WALLPAPER_FILL@|$WALLPAPER_FILL|g" \
    -e "s|@THERMAL_SENSORS@|$THERMAL_SENSORS|g" \
    "$TPL" | awk 'NF || seen { seen = 1; print }' > "$STAGING"

TOP_PANEL="[Containments][400][General]"

if (( ! WITH_NAS )); then
    echo "  Dropping the NAS disk usage widget (--no-nas)."
    ini_drop_sections "$STAGING" "[Containments][400][Applets][$APPLET_NAS]"
    applet_order_remove "$STAGING" "$APPLET_NAS" "$TOP_PANEL"
fi

if (( ! HAVE_THERMAL )); then
    echo "  Dropping the Thermal Monitor widget (not installed)."
    ini_drop_sections "$STAGING" "[Containments][400][Applets][$APPLET_THERMAL]"
    applet_order_remove "$STAGING" "$APPLET_THERMAL" "$TOP_PANEL"
fi

if (( SCREEN_COUNT < 2 )); then
    echo "  Single display detected — dropping the secondary desktop containment."
    ini_drop_sections "$STAGING" "[Containments][458]"
fi

if (( DRY_RUN )); then
    echo
    echo "  [dry-run] rendered layout would be written to $APPLETSRC:"
    echo "  ---------------------------------------------------------"
    sed 's/^/  /' "$STAGING"
    echo "  ---------------------------------------------------------"
    rm -f "$STAGING"
    banner "Dry run complete — nothing was changed."
    exit 0
fi

###############################################################
# Commit the layout (plasmashell must be stopped first, it
# rewrites its config on exit and would clobber our file)
###############################################################

banner "Restarting Plasma Shell with the new layout."

USE_SYSTEMD=0
if systemctl --user cat plasma-plasmashell.service &>/dev/null; then
    USE_SYSTEMD=1
    systemctl --user stop plasma-plasmashell.service
else
    kquitapp6 plasmashell &>/dev/null || killall plasmashell &>/dev/null
fi

for _ in $(seq 1 40); do
    pgrep -x plasmashell >/dev/null || break
    sleep 0.25
done
pgrep -x plasmashell >/dev/null && warn "plasmashell is still running — the layout may not stick."

mv "$STAGING" "$APPLETSRC"
chmod 600 "$APPLETSRC"

# Panel geometry lives in plasmashellrc, keyed by containment id.
# Wipe stale [PlasmaViews] groups so panels from the default layout do not linger.
PLASMASHELLRC="$HOME/.config/plasmashellrc"
if [[ -f "$PLASMASHELLRC" ]]; then
    tmp="$(mktemp)"
    awk '/^\[/ { skip = (substr($0, 1, 13) == "[PlasmaViews]") } !skip' \
        "$PLASMASHELLRC" > "$tmp" && mv "$tmp" "$PLASMASHELLRC"
fi

# Top panel — 32px, opaque, centered, fixed length
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key alignment       132
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key floating        0
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key floatingApplets 0
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key panelLengthMode 0
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key panelOpacity    1
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --key shell           org.kde.plasma.desktop
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --group Defaults --key maxLength  "$PANEL_LENGTH"
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --group Defaults --key minLength  "$PANEL_LENGTH"
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --group Defaults --key thickness  32
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 400" --group "Horizontal$SCREEN_WIDTH" --key alignment 132

# Bottom dock — 64px, translucent, auto-hide, fits its content, floating applets
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key floating        0
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key floatingApplets 1
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key panelLengthMode 1
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key panelOpacity    2
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key panelVisibility 1
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --key shell           org.kde.plasma.desktop
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 425" --group Defaults --key thickness 64

if (( USE_SYSTEMD )); then
    systemctl --user start plasma-plasmashell.service
else
    kstart plasmashell &>/dev/null &
fi

###############################################################
# Reload the rest of the session
###############################################################

banner "Reloading KWin and the theme cache."

qdbus6 org.kde.KWin /KWin reconfigure &>/dev/null
qdbus6 org.kde.KWin /Compositor suspend &>/dev/null && \
    qdbus6 org.kde.KWin /Compositor resume &>/dev/null
qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig &>/dev/null
qdbus6 org.kde.screensaver /ScreenSaver org.kde.screensaver.configure &>/dev/null

banner "Done."
cat <<EOF
Layout applied. Backup of the previous configuration:
  $BACKUP_DIR

Notes:
  * Widgets are locked (immutability=1), same as the reference desktop.
    Right-click the desktop > "Unlock Widgets" to rearrange anything.
  * Screen auto-lock is off, same as the reference desktop. Meta+L still
    locks manually. Re-enable it in System Settings > Screen Locking.
  * Thermal Monitor is reading '$THERMAL_SENSOR'.
    List the available sensors in the widget's settings if it shows nothing.
  * The NAS widget needs ~/.config/btw-i-use-arch/nas.json plus a KWallet entry:
      bash scripts/set-nas-password.sh
    Re-run with --no-nas to leave it out entirely.
  * Log out and back in for the GTK theme and fonts to apply everywhere.
EOF
