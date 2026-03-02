#!/bin/bash

shouldFormatEfi=0
partswap=""
partroot=""
partefi=""

for arg in "$@"; do
    case $arg in
        --part-efi=*)
            partefi="${arg#*=}"
            shift
            ;;
        --part-root=*)
            partroot="${arg#*=}"
            shift
            ;;
        --part-swap=*)
            partswap="${arg#*=}"
            shift
            ;;
        --format-efi=*)
            shouldFormatEfi="${arg#*=}"
            shift
            ;;
    esac
done

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Setup your partitions."
echo "###############################################################"
echo "This script will format and mount partitions for Arch Linux."

if [[ -n "$partroot" && -n "$partswap" && -n "$partefi" ]]; then
    echo "------------------------------------------------"
    echo "ARGUMENTS DETECTED - AUTOMATED SETUP MODE"
    echo "------------------------------------------------"
    echo "  Root Partition: $partroot"
    echo "  Swap Partition: $partswap"
    echo "  EFI Partition:  $partefi"
    echo "  Format EFI?:    $shouldFormatEfi (1=Yes, 0=No)"
    echo "------------------------------------------------"
    read -r -p "Is this configuration correct? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        echo "Reverting to manual mode..."
        partroot=""
        partswap=""
        partefi=""
        shouldFormatEfi=0
    fi
fi

if [[ -z "$partroot" || -z "$partswap" || -z "$partefi" ]]; then
    echo "Entering manual partition selection..."
    lsblk
    
    disk=""
    while [[ -z "$disk" ]]; do
        read -r -p "Enter the disk to partition (e.g., /dev/sda): " disk
        if [[ ! -b "$disk" ]]; then
            echo "Invalid disk. Please try again."
            disk=""
            continue
        fi
        
        echo "You have selected disk: $disk"
        read -r -p "Is this correct? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            disk=""
        fi
    done

    gdisk $disk

    while [[ -z "$partroot" || -z "$partswap" || -z "$partefi" ]]; do
        read -r -p "Enter the root partition (e.g., /dev/sda2): " partroot
        if [[ ! -b "$partroot" ]]; then
            echo "Invalid partition."
            partroot=""
        fi
        read -r -p "Enter the swap partition (e.g., /dev/sda3): " partswap
        if [[ ! -b "$partswap" ]]; then
            echo "Invalid partition."
            partswap=""
        fi
        read -r -p "Enter the EFI partition (e.g., /dev/sda1): " partefi
        if [[ ! -b "$partefi" ]]; then
            echo "Invalid partition."
            partefi=""
        fi

        echo "Setup will proceed with:"
        echo "  Root Partition: $partroot"
        echo "  Swap Partition: $partswap"
        echo "  EFI Partition:  $partefi"
        read -r -p "Are these correct? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            partroot=""
            partswap=""
            partefi=""
        fi
    done

    echo "By default, the EFI partition will NOT be formatted."
    read -r -p "Do you need to format the EFI partition $partefi? (y/n): " formatEfi
    if [[ "$formatEfi" == "y" ]]; then
        shouldFormatEfi=1
    else
        shouldFormatEfi=0
    fi
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Will now format partitions."
echo "###############################################################"

mkswap "$partswap"
swapon "$partswap"
mkfs.btrfs -f "$partroot"

if [[ $shouldFormatEfi -eq 1 ]]; then
    echo "Formatting EFI partition..."
    mkfs.fat -F 32 "$partefi"
else
    echo "Skipping EFI format (keeping existing data)."
fi

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Creating Btrfs subvolumes and mounting partitions."
echo "###############################################################"
mount "$partroot" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
umount -R /mnt

mount -o compress=zstd,subvol=@ "$partroot" /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots}

mount -o compress=zstd,subvol=@home "$partroot" /mnt/home
mount -o compress=zstd,subvol=@snapshots "$partroot" /mnt/.snapshots
mount "$partefi" /mnt/boot/efi

echo "Partitions formatted and mounted successfully."