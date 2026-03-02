# Dual GPU Passthrough — Installation Guide

> [!CAUTION]
> **AI-Generated Draft — Use With Caution**
> This guide was written with AI assistance and has not been fully verified. Steps may be incomplete, incorrect and are specific to a particular hardware configuration. **Always back up your data before following this guide.** The author assumes no responsibility for any data loss or system damage.

---

> **Context**: Arch Linux (GNOME/Wayland) on Radeon iGPU (Ryzen 7 7700X) + dynamic passthrough of the RTX 3080 to a Windows 11 VM. The RTX remains usable under Linux via `prime-run` when the VM is not running.
>
> **Prerequisites**: Fresh Arch Linux installation via `arch-install.sh` + `arch-post-install.sh` (yay available).

---

## Phase 1 — BIOS (UEFI MSI MAG B850)

Access via the `Del` key at POST. Configure the following settings:

| Category | Setting | Value |
|---|---|---|
| Advanced CPU Configuration | SVM Mode | **Enabled** |
| Advanced CPU Configuration / AMD CBS | IOMMU | **Enabled** |
| PCI Subsystem Settings | Above 4G Decoding | **Enabled** |
| PCI Subsystem Settings | Re-Size BAR Support | **Enabled** |
| Boot Configuration | CSM Support | **Disabled** |
| Integrated Graphics Configuration | Initiate Graphic Adapter | **IGD** |
| Integrated Graphics Configuration | Integrated Graphics | **Force** |

Save (`F10`) and reboot. The screen connected to the motherboard should display GRUB.

---

## Phase 2 — Virtualization Packages

```bash
sudo pacman -Syu qemu-full libvirt virt-manager virt-viewer dnsmasq \
  iptables-nft swtpm edk2-ovmf dkms linux-headers
```

> - `qemu-full`: KVM hypervisor
> - `libvirt` + `virt-manager`: management API + GTK graphical interface (integrates with GNOME)
> - `swtpm`: TPM 2.0 emulator (required by Windows 11)
> - `edk2-ovmf`: UEFI firmware for VM (required by Windows 11)

```bash
sudo usermod -aG libvirt,kvm,input $USER
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd
```

Log out and back in for group changes to take effect.

---

## Phase 3 — Kernel IOMMU

### 3.1 — GRUB Parameters

Edit `/etc/default/grub`, add to `GRUB_CMDLINE_LINUX_DEFAULT`:

```
amd_iommu=on iommu=pt nvidia-drm.modeset=1
```

Regenerate the config:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Load VFIO modules at boot — create `/etc/modules-load.d/vfio.conf`:

```
vfio
vfio_iommu_type1
vfio_pci
```

**Reboot.**

### 3.2 — Validate IOMMU Groups

After rebooting, verify that the RTX 3080 is isolated in its own group:

```bash
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done
done
```

Look for the RTX 3080 (2 devices: VGA + HDMI Audio). They must be **alone** in their group. Note the PCI addresses (e.g. `01:00.0` and `01:00.1`).

```
	01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
	01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
```
---

## Phase 4 — NVIDIA Drivers + PRIME

The `arch-install.sh` script with `--gpu-profile=nvidia,amd` already installs the base drivers. For dynamic passthrough, using the DKMS version is preferred:

### 4.1 Enable multilib

Edit `/etc/pacman.conf` and uncomment the `[multilib]` section:

```
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Update packages:

```bash
sudo pacman -Syu
```

### 4.2 Install Drivers

```bash
sudo pacman -S nvidia-dkms lib32-nvidia-utils nvidia-prime
```

Usage: launch an app on the RTX with `prime-run <command>` (e.g. `prime-run steam`). Without `prime-run`, the RTX stays in sleep mode (D3) — this is what makes dynamic detachment possible.

### 4.3 Force GDM onto the AMD iGPU

By default, GDM may choose the RTX as the display GPU even if the BIOS is set to IGD. Two actions are required.

**1. Mask the system GDM udev rule** (which may interfere):

```bash
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
```

**2. Create a udev rule to remove seat access from NVIDIA** — `/etc/udev/rules.d/62-nvidia-no-display.rules`:

```
SUBSYSTEM=="drm", KERNEL=="card*", ATTR{../vendor}=="0x10de", TAG-="seat", TAG-="uaccess"
```

**3. Create `/etc/modprobe.d/nvidia-display.conf`** (enables modeset for PRIME offload):

```
options nvidia-drm modeset=1
```

Reload udev rules + restart GDM:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl restart gdm
```

---

## Phase 5 — Libvirt Hooks (Dynamic Switching)

### 5.1 — Directory Structure

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/prepare/begin
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/release/end
```

### 5.2 — Dispatcher

Download the standard hook router:

```bash
sudo wget -O /etc/libvirt/hooks/qemu \
  https://raw.githubusercontent.com/PassthroughPOST/VFIO-tools/master/libvirt_hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

### 5.3 — Start Script

Create `/etc/libvirt/hooks/qemu.d/win11/prepare/begin/start.sh`:

> **Adapt** `GPU_VGA` and `GPU_AUDIO` with the PCI addresses found in phase 3.2.
> The libvirt format replaces `:` and `.` with `_` and adds the `pci_0000_` prefix.

```bash
#!/bin/bash
set -x

GPU_VGA="pci_0000_01_00_0"
GPU_AUDIO="pci_0000_01_00_1"

modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia

# If modprobe fails silently then try to kill the process
# if fuser -s /dev/nvidia* 2>/dev/null; then
#     fuser -k -9 /dev/nvidia*
#     sleep 2
# fi

virsh nodedev-detach $GPU_VGA
virsh nodedev-detach $GPU_AUDIO

modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
```

### 5.4 — Stop Script

Create `/etc/libvirt/hooks/qemu.d/win11/release/end/revert.sh`:

```bash
#!/bin/bash
set -x

GPU_VGA="pci_0000_01_00_0"
GPU_AUDIO="pci_0000_01_00_1"

modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

virsh nodedev-reattach $GPU_VGA
virsh nodedev-reattach $GPU_AUDIO

modprobe nvidia
modprobe nvidia_uvm
modprobe nvidia_modeset
modprobe nvidia_drm
```

### 5.5 — Permissions

```bash
sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/prepare/begin/start.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/release/end/revert.sh
```

---

## Phase 6 — Creating the Windows 11 VM

### 6.1 — Prerequisites

Download:
- **Windows 11 ISO**: [microsoft.com](https://www.microsoft.com/software-download/windows11)
- **VirtIO ISO**: [fedorapeople.org](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) — contains disk/network drivers for Windows in VM

### 6.2 — Create the Virtual Disk

**Option A — Same disk as Linux:**

```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 100G
```

**Option B — Dedicated disk/partition:**

```bash
sudo qemu-img create -f qcow2 /path/to/other/disk/win11.qcow2 100G
```

> The `qcow2` format is dynamic: the file starts at a few KB and grows as needed. The 100 GB are not immediately allocated.

### 6.3 — virt-manager Wizard

1. Launch **virt-manager** (search "Virtual Machine Manager" in GNOME)
2. **File → New Virtual Machine**
3. Choose **Local install media (ISO image)** → select the Windows 11 ISO
4. RAM: **32768 MiB** (32 GB) — freed when the VM is shut down
5. CPU: **8** (half of the 7700X, the other 8 remain for Linux)
6. Storage: **Select or create custom storage** → browse to the `.qcow2` created above
7. Name the VM **win11**
8. **⚠️ Check "Customize configuration before install"**

### 6.4 — Pre-Installation Configuration

In the customization window:

| Section | Action |
|---|---|
| **Overview** | Firmware: `UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd` — Chipset: **Q35** |
| **CPUs** | Check **Copy host CPU configuration** (host-passthrough mode) |
| **Add Hardware → TPM** | Model: **CRB**, Backend: **Emulated** (swtpm provides the TPM 2.0 required by Win11) |
| **Add Hardware → Storage** | Device type: **CDROM**, select the `virtio-win.iso` |
| **Add Hardware → PCI Host Device** | Select the **RTX 3080** (VGA) |
| **Add Hardware → PCI Host Device** | Select the **RTX 3080** (HDMI Audio) |

#### CPU XML Edit

Click **Overview → XML**, find the `<cpu>` tag and make sure it looks like:

```xml
<cpu mode="host-passthrough" check="none">
  <topology sockets="1" dies="1" cores="<NUMBER_OF_VCPUS_CORE>" threads="1"/>
</cpu>
```

> Remove the `migratable` attribute if present — it causes crashes with IVSHMEM.

### 6.5 — Windows Installation

1. Click **Begin Installation** — the VM appears in virt-manager's Spice console
2. The Windows installer boots in UEFI mode
3. When asked to choose a disk: **no disk appears** (this is normal)
4. Click **Load driver** → browse the VirtIO CD-ROM → `viostor\w11\amd64` → install the driver
5. The virtual disk appears, proceed with the normal installation
6. Once in Windows: install the remaining VirtIO drivers via `virtio-win-guest-tools.exe` from the CD-ROM
7. Download and install the **official NVIDIA drivers** from [nvidia.com](https://www.nvidia.com/Download/index.aspx) (not GeForce Experience)

---

## Phase 7 — Looking Glass

The GPU renders the image inside the VM but no physical screen is connected to it. Looking Glass transfers frames via shared memory to the host, without compression or latency.

### 7.1 — Installation (Arch host)

```bash
yay -S looking-glass-rc kvmfr-dkms
```

### 7.2 — KVMFR Module

Create `/etc/modprobe.d/kvmfr.conf`:

```
options kvmfr static_size_mb=128
```

> 128 MB to support up to 3840×2160 (4K TV). Formula: `width × height × 4 × 2`, rounded up to the next power of 2.

Create `/etc/udev/rules.d/99-kvmfr.rules` (replace `yourusername`):

```
SUBSYSTEM=="kvmfr", OWNER="yourusername", GROUP="kvm", MODE="0660"
```

Load the module:

```bash
sudo modprobe kvmfr
```

To load it automatically at boot, create `/etc/modules-load.d/kvmfr.conf`:

```
kvmfr
```

### 7.3 — IVSHMEM in the VM

```bash
virsh edit win11
```

Add inside `<devices>`:

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>
```

### 7.4 — Windows Side (inside the VM)

1. Install **IddSampleDriver** — simulates a virtual screen connected to the RTX (since no cable is physically connected). Download from [GitHub](https://github.com/ge9/IddSampleDriver/releases)
2. Install the **Looking Glass Host** application — captures frames and pushes them into the IVSHMEM. Download from [looking-glass.io](https://looking-glass.io/downloads)
3. In Windows display settings: disable the Spice QXL screen, keep only the IddSampleDriver virtual screen

### 7.5 — Looking Glass Client (Arch host)

Create `~/.looking-glass-client.ini`:

```ini
[app]
renderer=opengl
shmFile=/dev/kvmfr0

[win]
fullScreen=yes
```

Launch:

```bash
looking-glass-client
```

> The `renderer=opengl` avoids visual artifacts under Mutter/Wayland (flickering with EGL).

---

## Phase 8 — Audio (PipeWire)

The VM sends audio through the Linux host's audio output (no HDMI cable on the RTX needed).

```bash
virsh edit win11
```

Modify the existing `<sound>` tag (or add it inside `<devices>`):

```xml
<sound model="ich9">
  <audio id="1"/>
</sound>
<audio id="1" type="pipewire" runtimeDir="/run/user/1000">
  <input mixingEngine="yes"/>
  <output mixingEngine="yes"/>
</audio>
```

> Replace `1000` with your UID (`id -u`). Windows audio goes directly into PipeWire, mixed with Linux audio.

To allow libvirt to access the user's PipeWire socket, edit `/etc/libvirt/qemu.conf`:

```
user = "yourusername"
group = "kvm"
```

Restart libvirtd:

```bash
sudo systemctl restart libvirtd
```

---

## Phase 9 — Clipboard (SPICE)

The SPICE channel remains active even without a Spice display — it handles clipboard and mouse.

In virt-manager:
1. Verify that a **Channel spice** (Type: `spicevmc`) is present in the devices
2. **Display Spice**: set Listen Type to **None** (disables the video window, keeps the channel)

In Windows: the `virtio-win-guest-tools` installed in phase 6.5 include the `vdagent` service which synchronizes the clipboard automatically.

---

## Phase 10 — File Sharing (Virtio-FS)

Allows mounting a native Linux folder in Windows, without network overhead.

### 10.1 — Shared Memory (host)

```bash
virsh edit win11
```

Add at the root of `<domain>` (not inside `<devices>`):

```xml
<memoryBacking>
  <access mode='shared'/>
</memoryBacking>
```

### 10.2 — Filesystem (virt-manager)

In virt-manager: **Add Hardware → Filesystem**

| Field | Value |
|---|---|
| Driver | **virtiofs** |
| Source path | `/home/yourusername/SharedVM` |
| Target path | `host_share` |

Create the folder on the Linux side if needed:

```bash
mkdir -p ~/SharedVM
```

### 10.3 — Windows Side

1. Install **WinFSP** from [winfsp.dev](https://winfsp.dev/rel/) (Core option is sufficient)
2. Open an **Administrator cmd**:

```dos
sc.exe create VirtioFsSvc binpath="C:\Program Files\Virtio-Win\VioFS\virtiofs.exe" start=auto depend="WinFsp.Launcher/VirtioFsDrv" DisplayName="Virtio FS Service"
sc start VirtioFsSvc
```

The `~/SharedVM` folder appears as a drive in Windows Explorer (usually `Z:`).

---

## Phase 11 — USB Hotplug

To dynamically pass USB devices to the VM while it's running:

1. In **virt-manager**, with the VM running → **Virtual Machine → Redirect USB device**
2. Select the device to send to Windows (keyboard, mouse, gamepad...)
3. To remove it: uncheck the device in the same menu

> No need for full USB controller passthrough. SPICE hotplug is sufficient for occasional use.

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                   Arch Linux (Host)                 │
│                                                     │
│  Radeon iGPU ──► Wayland/GNOME ──► Screen 3440×1440 │
│                                                     │
│  RTX 3080 : prime-run (Linux) ◄──► vfio-pci (VM)   │
│       ▲                                ▲            │
│       │          Libvirt Hooks         │            │
│       └────── start.sh / revert.sh ────┘            │
│                                                     │
│  ┌──────────────────────────────────────────┐       │
│  │          VM Windows 11 (QEMU/KVM)        │       │
│  │  RTX 3080 passthrough ──► Looking Glass  │       │
│  │  Audio ──► PipeWire (host)               │       │
│  │  Disk ──► VirtIO (qcow2)                 │       │
│  │  Files ──► Virtio-FS (~/SharedVM)        │       │
│  │  Clipboard ──► SPICE vdagent             │       │
│  └──────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

---

## References

- [Arch Wiki — PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Looking Glass](https://looking-glass.io/)
- [VFIO-Tools (hooks)](https://github.com/PassthroughPOST/VFIO-tools)
- [VirtIO-Win drivers](https://github.com/virtio-win/virtio-win-pkg-scripts)
- [IddSampleDriver](https://github.com/ge9/IddSampleDriver)
- [WinFSP](https://winfsp.dev/)
