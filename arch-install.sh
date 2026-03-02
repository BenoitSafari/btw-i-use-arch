#!/bin/bash

country="France"
gpu_profile=""

for arg in "$@"; do
    case $arg in
        --gpu-profile=*)
            gpu_profile="${arg#*=}"
            ;;
    esac
done

timedatectl set-ntp true

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Setup your partitions."
echo "###############################################################"
echo "This script is for French users and will configure the system locale and keyboard accordingly."
source ./scripts/arch-install-partition.sh "$@"

username=""
userpass=""

while true; do
    read -r -p "Please enter the username to create: " username
    if [[ -z "$username" ]]; then
        echo "Username cannot be empty."
        continue
    fi

    read -r -s -p "Please enter the password for $username: " userpass
    echo ""
    read -r -s -p "Please confirm the password for $username: " userpass_confirm
    echo ""

    if [[ "$userpass" != "$userpass_confirm" ]]; then
        echo "Passwords do not match, please try again."
        username=""
        userpass=""
        continue
    fi

    read -r -p "You entered username: $username. Is this correct? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        break
    fi

    username=""
    userpass=""
done

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Arch Linux base installation will begin now."
echo "###############################################################"
pacstrap /mnt base base-devel linux linux-firmware intel-ucode amd-ucode sudo rsync reflector wget util-linux shadow git
genfstab -U /mnt >> /mnt/etc/fstab
timedatectl set-ntp true
reflector --country $country --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Entering chroot to configure the system..."
echo "###############################################################"

script_target=/mnt/root/arch-install-chroot.sh
cp ./scripts/arch-install-chroot.sh $script_target
chmod +x $script_target
arch-chroot /mnt /root/arch-install-chroot.sh "$username" "$userpass" "$gpu_profile"
rm -f $script_target

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Copy configuration files."
echo "###############################################################"
echo "Importing configuration files for user $username."

cp ./assets/.zshrc /mnt/home/"$username"/.zshrc
user_cfg=/mnt/home/"$username"/.config
mkdir -p "$user_cfg"/fastfetch/
mkdir -p "$user_cfg"/kitty/
cp ./conf/fastfetch/config.jsonc "$user_cfg"/fastfetch/config.jsonc
cp ./conf/kitty/kitty.conf "$user_cfg"/kitty/kitty.conf

arch-chroot /mnt chown -R "$username":"$username" /home/"$username"

echo ""
echo ""
echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installation complete."
echo "###############################################################"
echo "Press any key to unmount partitions and reboot into your new Arch Linux system."

read -r
umount -R /mnt
swapoff "$partswap"
reboot