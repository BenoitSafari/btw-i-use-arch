#!/bin/bash

localdomains="dev.localhost.com dev.localhost.io dev.localhost.fr dev.localhost.de dev.localhost.ch dev.localhost.be dev.localhost.lu"
username="$1"
userpass="$2"

if [[ -z "$username" ]]; then
    echo "Error: User and password are not defined."
    exit 1
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Configuring locale and hostname."
echo "###############################################################"
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_TIME=fr_FR.UTF-8" >> /etc/locale.conf
echo "KEYMAP=fr-latin9" > /etc/vconsole.conf

echo "arch" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts
for domain in $localdomains; do
    echo "127.0.0.1 $domain" >> /etc/hosts
done

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Creating user $username."
echo "###############################################################"
pacman -Syu --noconfirm zsh
useradd -m -G wheel,users -s /usr/bin/zsh "$username"
echo "$username:$userpass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing base packages."
echo "###############################################################"
pacman -Syu --noconfirm \
git base-devel pciutils acpid btrfs-progs iwd llvm networkmanager snapper snap-pac grub-btrfs os-prober efibootmgr \
nss-mdns pacman-contrib ufw unzip p7zip ripgrep plocate cifs-utils exfatprogs gvfs-mtp gvfs-smb rust sof-firmware alsa-firmware alsa-ucm-conf \
ffmpeg poppler iputils fontconfig jq wireless-regdb fzf pipewire-pulse wireplumber bluez go \
kitty fastfetch ffmpegthumbnailer imv man-db tldr nano wget \
noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-bitstream-vera \
ttf-cascadia-mono-nerd ttf-fira-mono ttf-firacode-nerd ttf-liberation \
ttf-opensans ttf-roboto woff2-font-awesome ttf-jetbrains-mono-nerd papirus-icon-theme \
gnome gnome-themes-extra gdm gnome-shell-extensions gnome-browser-connector xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
system-config-printer cups cups-browsed cups-filters networkmanager-openvpn

# Gnome bloatwares removal
sudo pacman -Rs --noconfirm gnome-contacts gnome-weather gnome-characters gnome-music gnome-maps gnome-tour gnome-console epiphany gnome-software

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing detected graphics drivers."
echo "###############################################################"
if lspci | grep -qi nvidia; then
    pacman -Syu --noconfirm nvidia nvidia-utils nvidia-settings
elif lspci | grep -qi "amd\|ati"; then
    pacman -Syu --noconfirm xf86-video-amdgpu vulkan-radeon
elif lspci | grep -qi intel; then
    pacman -Syu --noconfirm xf86-video-intel vulkan-intel
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing Oh My Zsh and plugins for user $username."
echo "###############################################################"
export HOME=/home/$username
sudo -u $username sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended
sudo -u $username git clone https://github.com/zsh-users/zsh-autosuggestions /home/$username/.oh-my-zsh/custom/plugins/zsh-autosuggestions
sudo -u $username git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /home/$username/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing web browsers and multimedia applications."
echo "###############################################################"
pacman -Syu --noconfirm \
chromium firefox vlc vlc-plugins-all

# Theme and font settings
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface font-hinting 'slight'
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
sudo -u $username dbus-launch gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
sudo -u $username dbus-launch gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'
sudo -u $username dbus-launch gsettings set org.gnome.nautilus.list-view default-zoom-level 'small'
sudo -u $username dbus-launch gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
sudo -u $username dbus-launch gsettings set org.gnome.nautilus.preferences migrated-gtk-settings true
sudo -u $username dbus-launch gsettings set org.gnome.mutter center-new-windows true
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface show-battery-percentage true
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface cursor-size 24
sudo -u $username dbus-launch gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'fr')]"

# GDM Keyboard layout
mkdir -p /etc/X11/xorg.conf.d
cat <<EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
EndSection
EOF
mkdir -p /etc/dconf/profile
cat <<EOF > /etc/dconf/profile/gdm
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
mkdir -p /etc/dconf/db/gdm.d
cat <<EOF > /etc/dconf/db/gdm.d/01-keyboard
[org/gnome/desktop/input-sources]
sources=[('xkb', 'fr')]
EOF
dconf update

# Power settings
sudo -u $username dbus-launch gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
sudo -u $username dbus-launch gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
sudo -u $username dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
sudo -u $username dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
sudo -u $username dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
sudo -u $username dbus-launch gsettings set org.gnome.desktop.interface show-battery-percentage true
sudo -u $username dbus-launch gsettings set org.gnome.desktop.session idle-delay 0

# Trackpad settings
sudo -u $username dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad click-method 'areas'
sudo -u $username dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
sudo -u $username dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true

# Nautilus settings
mkdir -p /usr/local/bin
ln -sf /usr/bin/kitty /usr/local/bin/x-terminal-emulator
sudo -u $username dbus-launch gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'

localectl set-x11-keymap fr

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Configuring and enabling services."
echo "###############################################################"
mkdir -p /etc/NetworkManager/conf.d
printf "[device]\nwifi.backend=iwd\n" > /etc/NetworkManager/conf.d/wifi_backend.conf

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable acpid
systemctl enable gdm

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Configuring snapshots."
echo "###############################################################"
umount /.snapshots 2>/dev/null || true
rm -rf /.snapshots
snapper --no-dbus -c root create-config /
rm -rf /.snapshots
mkdir /.snapshots

root_dev=$(findmnt -n -o SOURCE / | cut -d'[' -f1)
mount -o compress=zstd,subvol=@snapshots "$root_dev" /.snapshots

chmod 750 /.snapshots
chown :wheel /.snapshots
snapper --no-dbus -c root set-config "TIMELINE_LIMIT_HOURLY=0" "TIMELINE_LIMIT_DAILY=7" "TIMELINE_LIMIT_WEEKLY=0" "TIMELINE_LIMIT_MONTHLY=0" "TIMELINE_LIMIT_YEARLY=0"

echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd