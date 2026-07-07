#!/bin/bash

localdomains="dev.localhost.com dev.localhost.io dev.localhost.fr dev.localhost.de dev.localhost.ch dev.localhost.be dev.localhost.lu"
username="$1"
userpass="$2"
gpu_profile="$3"

if [[ -z "$username" ]]; then
    echo "Error: User and password are not defined."
    exit 1
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Enabling multilib repository."
echo "###############################################################"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring locale and hostname."
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
echo "# [BTW-I-USE-ARCH] Creating user $username."
echo "###############################################################"
pacman -Syu --noconfirm zsh
useradd -m -G wheel,users -s /usr/bin/zsh "$username"
echo "$username:$userpass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing base packages."
echo "###############################################################"
pacman -Syu --noconfirm \
git base-devel pciutils acpid btrfs-progs iwd llvm networkmanager snapper grub-btrfs os-prober efibootmgr ntfs-3g \
nss-mdns pacman-contrib ufw unzip p7zip ripgrep plocate cifs-utils exfatprogs gvfs-mtp gvfs-smb rust sof-firmware alsa-firmware alsa-ucm-conf \
ffmpeg poppler iputils fontconfig jq wireless-regdb fzf pipewire-pulse wireplumber bluez go \
kitty fastfetch ffmpegthumbnailer imv man-db tldr nano wget \
noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-bitstream-vera \
ttf-cascadia-mono-nerd ttf-fira-mono ttf-firacode-nerd ttf-liberation \
ttf-opensans ttf-roboto woff2-font-awesome ttf-jetbrains-mono-nerd \
plasma sddm xdg-desktop-portal-kde dolphin konsole spectacle ark okular gwenview kate networkmanager-openvpn

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing graphics drivers."
echo "###############################################################"
has_nvidia=0

install_gpu_nvidia() {
    pacman -Syu --noconfirm linux-headers nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland vulkan-icd-loader lib32-vulkan-icd-loader
    has_nvidia=1
}
install_gpu_amd()    { pacman -Syu --noconfirm xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader; }
install_gpu_intel()  { pacman -Syu --noconfirm xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader; }

if [[ -n "$gpu_profile" ]]; then
    echo "GPU profile(s) specified: $gpu_profile"
    IFS=',' read -ra profiles <<< "$gpu_profile"
    for profile in "${profiles[@]}"; do
        case "$profile" in
            nvidia) install_gpu_nvidia ;;
            amd)    install_gpu_amd ;;
            intel)  install_gpu_intel ;;
            *)      echo "Unknown GPU profile: $profile (skipping)" ;;
        esac
    done
else
    echo "No GPU profile specified, auto-detecting..."
    if lspci | grep -qi nvidia; then
        install_gpu_nvidia
    fi
    if lspci | grep -qi "amd\|ati"; then
        install_gpu_amd
    fi
    if lspci | grep -qi intel; then
        install_gpu_intel
    fi
fi

if [[ $has_nvidia -eq 1 ]]; then
    echo "###############################################################"
    echo "# [BTW-I-USE-ARCH] Configuring NVIDIA kernel parameters."
    echo "###############################################################"
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
        current=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="//;s/"$//')
        for param in nvidia_drm.modeset=1 nvidia_drm.fbdev=1; do
            if ! echo "$current" | grep -q "$param"; then
                current="$current $param"
            fi
        done
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$current\"|" /etc/default/grub
    else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1 nvidia_drm.fbdev=1"' >> /etc/default/grub
    fi

    echo "###############################################################"
    echo "# [BTW-I-USE-ARCH] Configuring NVIDIA early KMS for Wayland."
    echo "###############################################################"
    sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sed -i 's/MODULES=( /MODULES=(/' /etc/mkinitcpio.conf
    mkinitcpio -P
fi

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing Oh My Zsh and plugins for user $username."
echo "###############################################################"
export HOME=/home/$username
sudo -u $username sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended
sudo -u $username git clone https://github.com/zsh-users/zsh-autosuggestions /home/$username/.oh-my-zsh/custom/plugins/zsh-autosuggestions
sudo -u $username git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /home/$username/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing web browsers and multimedia applications."
echo "###############################################################"
pacman -Syu --noconfirm \
chromium firefox vlc vlc-plugins-all

mkdir -p /etc/X11/xorg.conf.d
cat <<EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
EndSection
EOF


mkdir -p /usr/local/bin
ln -sf /usr/bin/kitty /usr/local/bin/x-terminal-emulator

sudo -u $username mkdir -p /home/$username/.config
sudo -u $username kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
sudo -u $username kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring and enabling services."
echo "###############################################################"
mkdir -p /etc/NetworkManager/conf.d
printf "[device]\nwifi.backend=iwd\n" > /etc/NetworkManager/conf.d/wifi_backend.conf

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable acpid
systemctl enable sddm

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Configuring snapshots."
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
snapper --no-dbus -c root set-config \
    "TIMELINE_CREATE=yes" \
    "TIMELINE_LIMIT_HOURLY=0" \
    "TIMELINE_LIMIT_DAILY=7" \
    "TIMELINE_LIMIT_WEEKLY=0" \
    "TIMELINE_LIMIT_MONTHLY=0" \
    "TIMELINE_LIMIT_YEARLY=0"

echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd

mkdir -p /etc/systemd/system/snapper-timeline.timer.d
cat > /etc/systemd/system/snapper-timeline.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=daily
EOF
systemctl daemon-reload
