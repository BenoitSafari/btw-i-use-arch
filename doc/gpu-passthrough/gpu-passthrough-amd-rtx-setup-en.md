# Installation Guide — Static GPU Passthrough (NVIDIA RTX 3080) on AMD Host

This guide details the steps to configure an Arch Linux host using **exclusively an AMD iGPU** and a Windows 11 virtual machine using an **NVIDIA RTX 3080 dGPU** via PCI Passthrough. The NVIDIA card will be permanently reserved (static) for the VM.

---

## 1. BIOS / UEFI (Prerequisites)

Before starting, access your BIOS and configure the following:

| Parameter | Recommended Value |
|---|---|
| SVM Mode (CPU Virtualization) | **Enabled** |
| IOMMU (AMD CBS) | **Enabled** |
| Above 4G Decoding | **Enabled** |
| Re-Size BAR Support | **Enabled** |
| CSM Support / Legacy Boot | **Disabled** (UEFI mandatory) |
| Primary Video / Initiate Graphic Adapter | **IGD** (Integrated Graphics) |

Ensure your main monitor is plugged into the motherboard (AMD iGPU) and not the NVIDIA graphics card.

---

## 2. Installing AMD iGPU drivers and QEMU

On your Arch Linux host, start by installing the AMD drivers to ensure host display, then the virtualization packages.

```bash
# Drivers for the AMD iGPU
sudo pacman -Syu mesa vulkan-radeon xf86-video-amdgpu libva-mesa-driver lib32-libva-mesa-driver

# Virtualization tools
sudo pacman -S qemu-full libvirt virt-manager virt-viewer dnsmasq iptables-nft swtpm edk2-ovmf
```

> - `swtpm` is required to emulate TPM 2.0 (required by Windows 11).
> - `edk2-ovmf` provides the UEFI firmware (OVMF) for the VM.

Enable and start Libvirt services:

```bash
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd
sudo usermod -aG libvirt,kvm $USER
```
*(Log out and log back into your session to apply the groups).*

---

## 3. Static isolation of the NVIDIA card (VFIO)

The goal is to prevent Linux (via the `nouveau` or `nvidia` drivers) from claiming the RTX 3080 at boot, and to force its assignment to the `vfio-pci` driver.

### 3.1 Identify the NVIDIA PCI IDs
List your PCI devices to find the identifiers (Vendor ID:Device ID) of the NVIDIA RTX 3080:

```bash
lspci -nn | grep -i nvidia
```

You will get a result similar to:
```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
```
Note the IDs in brackets at the end of each line (e.g., `10de:2206` and `10de:1aef`).

### 3.2 Kernel parameters (GRUB)
Edit `/etc/default/grub` and add `amd_iommu=on`, `iommu=pt`, and the VFIO assignment to the `GRUB_CMDLINE_LINUX_DEFAULT` variable:

```text
GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on iommu=pt vfio-pci.ids=10de:2206,10de:1aef"
```
*(Replace `10de:2206,10de:1aef` with the IDs found in the previous step)*

Generate the new GRUB configuration:
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### 3.3 Load VFIO very early at boot (mkinitcpio)
Edit `/etc/mkinitcpio.conf` and modify the `MODULES` line to load the VFIO modules (note: `vfio_virqfd` was merged and is no longer needed on recent kernels):

```text
MODULES=(vfio_pci vfio vfio_iommu_type1)
```

Generate the initramfs:
```bash
sudo mkinitcpio -P
```

**Restart your PC.** 

Upon reboot, verify that the RTX 3080 is properly isolated and using the `vfio-pci` driver:
```bash
lspci -nnk -d 10de:2206
```
*(The line `Kernel driver in use:` must imperatively show `vfio-pci`)*

---

## 4. Windows 11 VM Creation (48 GB RAM)

### 4.1 ISO Prerequisites
Download:
- Official Windows 11 ISO from the Microsoft website.
- **VirtIO-win** ISO (vital KVM drivers for Windows): [Fedora Link - virtio-win.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)

### 4.2 Initial configuration (virt-manager)
1. Open **virt-manager** and create a new VM (Local install media).
2. Select the Windows 11 ISO.
3. RAM (Memory): **49152 MiB** (exactly 48 GB). 
4. CPUs: Allocate the necessary cores based on your CPU (e.g., half or more of the threads).
5. **Storage volume creation (Hard Drive)**:
   - Indicate the maximum allocated size (e.g., **100 GB**).
   - Leave the default format **`qcow2`**. This format is **dynamic** (thin-provisioned): the file will only take up the space actually used by Windows on the Linux host. It will automatically expand as needed until it reaches the set maximum limit. *(Warning: in virt-manager, ensure the "Allocate entire disk now" option is **not** checked)*.
6. ⚠️ Very important: **Check the box "Customize configuration before install"** at the last step.

### 4.3 Customization and GPU Passthrough
In the VM hardware details window:

- **Overview** : 
  - Firmware : choose `UEFI x86_64: .../OVMF_CODE.secboot.fd`. 
  - Chipset : `Q35`.
- **CPUs** : Check "Copy host CPU configuration" (Model: `host-passthrough`).
- **TPM (Add Hardware)** : 
  - *Note: virt-manager often adds a "TPM v1.2" by default (*`TIS`*). **Remove it first** (right click -> Remove Hardware).*
  - Click on "Add Hardware" -> "TPM".
  - Model : `CRB`
  - Backend : `Emulated` Type `2.0` (virt-manager will automatically select `swtpm` in the background).
- **Storage (Add Hardware)** : Add a `CDROM` containing the downloaded `virtio-win.iso`.
- **NVIDIA GPU (Add Hardware)** :
  - Click on "Add Hardware" -> "PCI Host Device" -> Select the VGA device for the RTX 3080.
  - Repeat to add the Audio chip for the RTX 3080.

*Note: Leave the virtual screen "Display Spice" and the existing network card to facilitate the installation.*

Start the Windows installation. At the disk selection (which will appear empty), click on **Load driver** and navigate in the VirtIO-win CD to the `amd64\w11` folder and install the virtual storage controller.

Once Windows is installed, install the `virtio-win-guest-tools.exe` utility from the VirtIO ISO, as well as the **official NVIDIA drivers**. You can then plug your monitor directly into your RTX 3080 via DisplayPort and switch the monitor input to see the VM natively.

---

## 5. Host/VM Folder Sharing (Virtio-FS)

To share a high-performance Linux folder with Windows 11 (without network performance loss):

### 5.1 Arch Host Side (virt-manager)
1. In virt-manager, with the VM powered off, go to the **Memory** tab and check **Enable shared memory**. 
   *Direct XML alternative (global VM XML tab):*
   ```xml
   <memoryBacking>
     <access mode='shared'/>
   </memoryBacking>
   ```
2. Still in the VM hardware details view, click on **Add Hardware -> Filesystem**.
   - Driver: `virtiofs`
   - Source path: `/home/YourUser/Shared_Folder` (The absolute path on the Linux side)
   - Target path: `shared_mount` (An export name of your choice)
   
*(Replace `/home/YourUser/Shared_Folder` with the desired folder, and create it on Linux: `mkdir -p ~/Shared_Folder`)*

### 5.2 VM Side (Windows 11)
1. Download and install **WinFSP** from [winfsp.dev](https://winfsp.dev/rel/).
2. Open an administrator terminal (`cmd.exe` as administrator) in Windows and start the service:
   ```cmd
   sc.exe start VirtioFsSvc
   ```
The shared folder should immediately appear in the Windows file explorer as a new network drive `Z:`.

---

## 6. USB Port Sharing & Hardware KVM

Since we are outputting both GPUs (AMD for Linux, NVIDIA for Windows) to a single monitor, you can switch between Linux and Windows simply by changing your monitor's video input source (e.g., HDMI to DP).

However, you also need your keyboard and mouse to follow this switch seamlessly. 

### 6.1 Using your Monitor's Built-in KVM Switch

If your monitor features a built-in KVM switch, it expects two separate desktop computers. Since you only have one physical PC, we will trick the monitor by routing two USB connections to the same machine.

#### The Dual Upstream Cable Setup
A KVM monitor uses "Upstream" USB cables (often USB-B or USB-C) to send the keyboard/mouse signals back to the computer. 
1. Connect **two** upstream cables from the monitor to two distinct USB ports on the back of your motherboard.
2. **Cable 1 (Linux Host):** Leave this port managed natively by Arch Linux. It will be active when the monitor is set to the AMD iGPU input.
3. **Cable 2 (Windows VM):** You must bind this specific port to your Windows VM. It will be active when you press the KVM switch on your monitor to switch to the NVIDIA dGPU input.

### 6.2 PCIe USB Controller Passthrough (Highly Recommended)

Passing individual USB cables (via USB Host Device) can sometimes cause hot-plug glitches when using a physical KVM switch. Furthermore, if you want your Windows VM to natively read USB-C inputs or complex hubs (like those on your monitor), the most robust method is to pass an **entire physical USB controller** to the VM.

Your motherboard contains several USB controllers, each managing a group of physical ports on the back panel.

1. **Identify your USB Controllers:**
   Run this command on Arch Linux to list all USB controllers:
   ```bash
   lspci -nn | grep USB
   ```
   *(You will see lines like `USB 3.1 xHCI` or `800 Series Chipset USB 3.x`, with their IDs at the end).*
2. **Locate the target ports:**
   Find the block of USB ports on the back of your motherboard that you want to dedicate exclusively to Windows. (Make sure your Linux keyboard/mouse is **not** plugged into this block).
3. **Plug your devices:**
   Plug the **Cable 2** from your KVM monitor, as well as any joysticks or USB-C headsets you want to use in Windows, into this specific block of ports.
4. **Pass the controller in virt-manager:**
   - Power off the VM and open the hardware details.
   - Click on **Add Hardware -> PCI Host Device**.
   - Select the USB controller you suspect controls that block of ports (e.g., `0000:0d:00:3`) and click Finish.
5. **Test :**
   Boot Windows and press your KVM switch. If the mouse and keyboard work, you have found the right controller! If not, shut down the VM, remove that PCI Host Device from virt-manager, and test the next USB controller from the list.

### 6.3 Passing other controllers (Gamepads, Audio)
For peripherals that don't need to switch inputs (e.g., an Xbox wireless dongle that you only use in Windows), simply plug it into the dedicated "Windows" USB ports you passed via the PCI USB Controller. They will be natively recognized by Windows with absolute zero latency.
