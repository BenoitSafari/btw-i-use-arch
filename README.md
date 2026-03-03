# BTW I use Arch

Automated Arch Linux installation and post-installation scripts with Btrfs, GNOME, Snapper snapshots and a curated selection of developer tools.

## Prerequisites

Boot into the **archiso** live image, then configure keyboard and network:

```bash
loadkeys fr-latin9
```

*If using Wi-Fi:*
```bash
iwctl --passphrase [password] station wlan0 connect [network]
ping -c4 www.archlinux.org
```

## Installation

```bash
git clone https://github.com/BenoitSafari/btw-i-use-arch.git
cd ./btw-i-use-arch
chmod +x arch-install.sh
bash arch-install.sh
```

Or with arguments for automated partition setup:

```bash
bash arch-install.sh --part-efi=/dev/nvme0n1p1 --part-root=/dev/nvme0n1p6 --part-swap=/dev/nvme0n1p5 --format-efi=0 --gpu-profile=nvidia
```

### Arguments

| Argument | Description | Example | Default |
|---|---|---|---|
| `--part-efi=<dev>` | EFI system partition | `--part-efi=/dev/nvme0n1p1` | Interactive prompt |
| `--part-root=<dev>` | Root partition (will be formatted as Btrfs) | `--part-root=/dev/nvme0n1p6` | Interactive prompt |
| `--part-swap=<dev>` | Swap partition | `--part-swap=/dev/nvme0n1p5` | Interactive prompt |
| `--format-efi=<0\|1>` | Format the EFI partition (`1` = yes, `0` = no) | `--format-efi=0` | `0` (no format) |
| `--gpu-profile=<profiles>` | GPU driver(s) to install, comma-separated | `--gpu-profile=nvidia,intel` | Auto-detect via `lspci` |

**GPU profiles disponibles** : `nvidia`, `amd`, `intel`

## Partitioning with gdisk

If no partition arguments are provided, the script will launch `gdisk` interactively. Here's a quick reference for creating partitions:

### Key commands

| Command | Description |
|---|---|
| `n` | Create a new partition |
| `p` | Print the current partition table |
| `d` | Delete a partition |
| `w` | Write changes and exit |
| `q` | Quit without saving |

### Partition type codes

| Code | Type | Usage |
|---|---|---|
| `ef00` | EFI System | Boot partition (`/boot/efi`), FAT32, ~512 MB |
| `8300` | Linux filesystem | Root partition (`/`), formatted as Btrfs |
| `8200` | Linux swap | Swap partition, recommended = RAM size |

### Example layout

```
Number  Size      Code  Name
   1    512 MiB   ef00  EFI System
   2    16 GiB    8200  Linux swap
   3    remainder 8300  Linux root
```

## Post-installation

After rebooting into your fresh Arch install, clone the repo again and run:

```bash
git clone https://github.com/BenoitSafari/btw-i-use-arch.git
cd ./btw-i-use-arch
chmod +x arch-post-install.sh
bash arch-post-install.sh
```

This installs yay, snapd, pamac, various dev tools, GNOME extensions, themes, and Node.js.
