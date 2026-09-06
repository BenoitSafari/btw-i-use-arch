# BTW I use Arch

Automated Arch Linux installation and post-installation scripts with Btrfs, KDE Plasma, Snapper snapshots and a curated selection of developer tools.

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

## Partitioning with cfdisk

If no partition arguments are provided, the script will launch `cfdisk` interactively. Navigate with the arrow keys, pick actions from the bottom menu. On an empty disk, choose the `gpt` label when prompted — `dos` will not boot in UEFI mode.

### Key actions

| Action | Description |
|---|---|
| `New` | Create a partition in the selected free space |
| `Type` | Set the partition type |
| `Delete` | Remove the selected partition |
| `Write` | Commit changes to disk — asks for a literal `yes` |
| `Quit` | Exit without saving |

### Partition types

| Type | Usage |
|---|---|
| `EFI System` | Boot partition (`/boot/efi`), FAT32, ~512 MB |
| `Linux swap` | Swap partition, recommended = RAM size |
| `Linux filesystem` | Root partition (`/`), formatted as Btrfs |

### Example layout

```
Device       Size        Type
/dev/sda1    512M        EFI System
/dev/sda2    16G         Linux swap
/dev/sda3    remainder   Linux filesystem
```

## Post-installation

After rebooting into your fresh Arch install, clone the repo again and run:

```bash
git clone https://github.com/BenoitSafari/btw-i-use-arch.git
cd ./btw-i-use-arch
chmod +x arch-post-install.sh
bash arch-post-install.sh
```

This installs yay, snapd, pamac, various dev tools and the Node.js stack (nodejs, npm, pnpm) with a `minimum-release-age` of 3 days as a supply-chain mitigation.

## Desktop layout

Reproduces the reference KDE Plasma 6 desktop — panels, global theme, fonts, wallpaper, screen locking, SDDM login screen and every custom widget — on a fresh install. Run it from inside a Plasma session (not as root):

```bash
bash apply-benoit-layout.sh
```

The previous configuration is backed up to `~/.local/share/btw-i-use-arch/kde-backup-<timestamp>/` before anything is touched.

| Argument | Description | Default |
|---|---|---|
| `--dry-run` | Print the rendered layout and every change without applying it | off |
| `--no-packages` | Skip the pacman dependency install | install |
| `--no-icons` | Skip the Tela icon theme download | install |
| `--no-widgets` | Skip the custom + third-party plasmoids | install |
| `--no-nas` | Leave the NAS disk usage widget out of the top panel | included |
| `--no-login-screen` | Skip the SDDM setup — the only step needing `sudo` beyond packages | configure |
| `--keep-bigscreen` | Keep `plasma-bigscreen` instead of removing it | remove |
| `--panel-margin=<px>` | Side margin of the top panel | `40` |
| `--thermal-sensor=<id>` | ksystemstats sensor for the Thermal Monitor widget | `cpu/all/averageTemperature` |

Panel length, wallpaper fill mode and the secondary-screen containment adapt to the target display setup. The reference desktop (3440x1440, discrete GPU) is reproduced with:

```bash
bash apply-benoit-layout.sh --thermal-sensor=gpu/gpu1/temperature
```

The layout itself lives in [`conf/plasma/appletsrc.tpl`](conf/plasma/appletsrc.tpl) — edit that file to change what sits in the panels.

> **Plasma Bigscreen:** the Arch `plasma` group installed by `arch-install-chroot.sh` includes `plasma-bigscreen`, which adds a TV-oriented session to SDDM. Picking it once (directly or through its "Swap session" launcher) replaces the whole desktop with a big-tile interface and none of the layout below applies. The script removes the package unless `--keep-bigscreen` is passed; log out and back in afterwards.
