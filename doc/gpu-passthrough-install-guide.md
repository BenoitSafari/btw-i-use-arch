# Dual GPU Passthrough — Guide d'installation

> **Contexte** : Arch Linux (GNOME/Wayland) sur iGPU Radeon (Ryzen 7 7700X) + passthrough dynamique de la RTX 3080 vers une VM Windows 11. La RTX reste utilisable sous Linux via `prime-run` en dehors de la VM.
>
> **Pré-requis** : Installation fraîche d'Arch Linux via `arch-install.sh` + `arch-post-install.sh` (yay disponible).

---

## Phase 1 — BIOS (UEFI MSI MAG B850)

Accès via la touche `Suppr` au POST. Configurer les paramètres suivants :

| Catégorie | Paramètre | Valeur |
|---|---|---|
| Advanced CPU Configuration | SVM Mode | **Enabled** |
| Advanced CPU Configuration / AMD CBS | IOMMU | **Enabled** |
| PCI Subsystem Settings | Above 4G Decoding | **Enabled** |
| PCI Subsystem Settings | Re-Size BAR Support | **Enabled** |
| Boot Configuration | CSM Support | **Disabled** |
| Integrated Graphics Configuration | Initiate Graphic Adapter | **IGD** |
| Integrated Graphics Configuration | Integrated Graphics | **Force** |

Sauvegarder (`F10`) et redémarrer. L'écran connecté à la carte mère doit afficher GRUB.

---

## Phase 2 — Paquets de virtualisation

```bash
sudo pacman -Syu qemu-full libvirt virt-manager virt-viewer dnsmasq bridge-utils \
  iptables-nft swtpm edk2-ovmf dkms linux-headers
```

> - `qemu-full` : hyperviseur KVM
> - `libvirt` + `virt-manager` : API de gestion + interface graphique GTK (s'intègre à GNOME)
> - `swtpm` : émulateur TPM 2.0 (requis par Windows 11)
> - `edk2-ovmf` : firmware UEFI pour VM (requis par Windows 11)

```bash
sudo usermod -aG libvirt,kvm,input $USER
sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd
```

Se déconnecter/reconnecter pour prendre en compte les groupes.

---

## Phase 3 — IOMMU noyau

### 3.1 — Paramètres GRUB

Éditer `/etc/default/grub`, ajouter à `GRUB_CMDLINE_LINUX_DEFAULT` :

```
amd_iommu=on iommu=pt
```

Régénérer la config :

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Charger les modules VFIO au boot — créer `/etc/modules-load.d/vfio.conf` :

```
vfio
vfio_iommu_type1
vfio_pci
```

**Redémarrer.**

### 3.2 — Valider les groupes IOMMU

Après redémarrage, vérifier que la RTX 3080 est isolée dans son propre groupe :

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

Chercher la RTX 3080 (2 devices : VGA + Audio HDMI). Ils doivent être **seuls** dans leur groupe. Noter les adresses PCI (ex: `01:00.0` et `01:00.1`).

---

## Phase 4 — Pilotes NVIDIA + PRIME

Le script `arch-install.sh` avec `--gpu-profile=nvidia,amd` installe déjà les pilotes de base. Pour le passthrough dynamique, il vaut mieux utiliser la version DKMS :

```bash
sudo pacman -S nvidia-dkms nvidia-utils lib32-nvidia-utils prime-run
```

Utilisation : lancer une app sur la RTX avec `prime-run <commande>` (ex: `prime-run steam`). Sans `prime-run`, la RTX reste en veille (D3) — c'est ce qui rend le détachement dynamique possible.

---

## Phase 5 — Hooks libvirt (bascule dynamique)

### 5.1 — Arborescence

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/prepare/begin
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/release/end
```

### 5.2 — Dispatcher

Télécharger le routeur de hooks standard :

```bash
sudo wget -O /etc/libvirt/hooks/qemu \
  https://raw.githubusercontent.com/PassthroughPOST/VFIO-tools/master/libvirt_hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

### 5.3 — Script de démarrage

Créer `/etc/libvirt/hooks/qemu.d/win11/prepare/begin/start.sh` :

> **Adapter** `GPU_VGA` et `GPU_AUDIO` avec les adresses PCI trouvées en phase 3.2.
> Le format libvirt remplace les `:` et `.` par des `_` et préfixe `pci_0000_`.

```bash
#!/bin/bash
set -x

GPU_VGA="pci_0000_01_00_0"
GPU_AUDIO="pci_0000_01_00_1"

if fuser -s /dev/nvidia* /dev/dri/card1 2>/dev/null; then
    fuser -k -9 /dev/nvidia* /dev/dri/card1
    sleep 2
fi

modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia

virsh nodedev-detach $GPU_VGA
virsh nodedev-detach $GPU_AUDIO

modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
```

### 5.4 — Script d'arrêt

Créer `/etc/libvirt/hooks/qemu.d/win11/release/end/revert.sh` :

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

## Phase 6 — Création de la VM Windows 11

### 6.1 — Pré-requis

Télécharger :
- **ISO Windows 11** : [microsoft.com](https://www.microsoft.com/software-download/windows11)
- **ISO VirtIO** : [fedorapeople.org](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) — contient les pilotes disque/réseau pour Windows en VM

### 6.2 — Créer le disque virtuel

**Option A — Même disque que Linux :**

```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 100G
```

**Option B — Disque/partition dédié :**

```bash
sudo qemu-img create -f qcow2 /chemin/vers/autre/disque/win11.qcow2 100G
```

> Le format `qcow2` est dynamique : le fichier ne fait que quelques Ko au départ et grossit au fur et à mesure. Les 100 Go ne sont pas alloués immédiatement.

### 6.3 — Assistant virt-manager

1. Lancer **virt-manager** (chercher "Virtual Machine Manager" dans GNOME)
2. **File → New Virtual Machine**
3. Choisir **Local install media (ISO image)** → sélectionner l'ISO Windows 11
4. RAM : **32768 MiB** (32 Go) — libérée quand la VM est éteinte
5. CPU : **8** (la moitié du 7700X, les 8 autres restent pour Linux)
6. Stockage : **Select or create custom storage** → naviguer vers le `.qcow2` créé
7. Nommer la VM **win11**
8. **⚠️ Cocher "Customize configuration before install"**

### 6.4 — Configuration pré-installation

Dans la fenêtre de personnalisation :

| Section | Action |
|---|---|
| **Overview** | Firmware : `UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd` — Chipset : **Q35** |
| **CPUs** | Cocher **Copy host CPU configuration** (mode host-passthrough) |
| **Add Hardware → TPM** | Model: **CRB**, Backend: **Emulated** (swtpm fournit le TPM 2.0 requis par Win11) |
| **Add Hardware → Storage** | Device type: **CDROM**, sélectionner l'ISO `virtio-win.iso` |
| **Add Hardware → PCI Host Device** | Sélectionner la **RTX 3080** (VGA) |
| **Add Hardware → PCI Host Device** | Sélectionner la **RTX 3080** (Audio HDMI) |

#### Édition XML du CPU

Cliquer sur **Overview → XML**, chercher la balise `<cpu>` et s'assurer qu'elle ressemble à :

```xml
<cpu mode="host-passthrough" check="none">
  <topology sockets="1" dies="1" cores="8" threads="1"/>
</cpu>
```

> Retirer l'attribut `migratable` s'il est présent — il cause des crashs avec IVSHMEM.

### 6.5 — Installation de Windows

1. Cliquer **Begin Installation** — la VM s'affiche dans la console Spice de virt-manager
2. L'installateur Windows démarre en UEFI
3. Quand il demande de choisir un disque : **aucun disque n'apparaît** (c'est normal)
4. Cliquer **Load driver** → parcourir le CD-ROM VirtIO → `viostor\w11\amd64` → installer le pilote
5. Le disque virtuel apparaît, procéder à l'installation normale
6. Une fois dans Windows : installer les pilotes VirtIO restants via `virtio-win-guest-tools.exe` depuis le CD-ROM
7. Télécharger et installer les **pilotes NVIDIA officiels** depuis [nvidia.com](https://www.nvidia.com/Download/index.aspx) (pas GeForce Experience)

---

## Phase 7 — Looking Glass

Le GPU rend l'image dans la VM mais aucun écran n'est branché dessus. Looking Glass transfère les frames via mémoire partagée vers l'hôte, sans compression, sans latence.

### 7.1 — Installation (hôte Arch)

```bash
yay -S looking-glass-rc kvmfr-dkms
```

### 7.2 — Module KVMFR

Créer `/etc/modprobe.d/kvmfr.conf` :

```
options kvmfr static_size_mb=128
```

> 128 Mo pour supporter jusqu'à 3840×2160 (4K TV). Formule : `largeur × hauteur × 4 × 2`, arrondi à la puissance de 2 supérieure.

Créer `/etc/udev/rules.d/99-kvmfr.rules` (remplacer `votrenom`) :

```
SUBSYSTEM=="kvmfr", OWNER="votrenom", GROUP="kvm", MODE="0660"
```

Charger le module :

```bash
sudo modprobe kvmfr
```

Pour le charger automatiquement au boot, créer `/etc/modules-load.d/kvmfr.conf` :

```
kvmfr
```

### 7.3 — IVSHMEM dans la VM

```bash
virsh edit win11
```

Ajouter dans `<devices>` :

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>
```

### 7.4 — Côté Windows (dans la VM)

1. Installer **IddSampleDriver** — simule un écran virtuel branché sur la RTX (puisqu'aucun câble n'y est connecté). Télécharger depuis [GitHub](https://github.com/ge9/IddSampleDriver/releases)
2. Installer l'application hôte **Looking Glass Host** — capture les frames et les pousse dans l'IVSHMEM. Télécharger depuis [looking-glass.io](https://looking-glass.io/downloads)
3. Dans les paramètres d'affichage Windows : désactiver l'écran Spice QXL, ne garder que l'écran virtuel IddSampleDriver

### 7.5 — Client Looking Glass (hôte Arch)

Créer `~/.looking-glass-client.ini` :

```ini
[app]
renderer=opengl
shmFile=/dev/kvmfr0

[win]
fullScreen=yes
```

Lancer :

```bash
looking-glass-client
```

> Le `renderer=opengl` évite les artefacts visuels sous Mutter/Wayland (scintillements avec EGL).

---

## Phase 8 — Audio (PipeWire)

La VM envoie le son à travers la sortie audio de l'hôte Linux (pas de câble HDMI sur la RTX nécessaire).

```bash
virsh edit win11
```

Modifier la balise `<sound>` existante (ou l'ajouter dans `<devices>`) :

```xml
<sound model="ich9">
  <audio id="1"/>
</sound>
<audio id="1" type="pipewire" runtimeDir="/run/user/1000">
  <input mixingEngine="yes"/>
  <output mixingEngine="yes"/>
</audio>
```

> Remplacer `1000` par votre UID (`id -u`). Le son de Windows sort directement dans PipeWire, mixé avec le son Linux.

Pour que libvirt accède au socket PipeWire de l'utilisateur, éditer `/etc/libvirt/qemu.conf` :

```
user = "votrenom"
group = "kvm"
```

Redémarrer libvirtd :

```bash
sudo systemctl restart libvirtd
```

---

## Phase 9 — Presse-papiers (SPICE)

Le canal SPICE reste actif même sans affichage Spice, il sert au presse-papiers et à la souris.

Dans virt-manager :
1. Vérifier qu'un **Channel spice** (Type: `spicevmc`) est présent dans les devices
2. Le **Display Spice** : mettre le Listen Type sur **None** (désactive la fenêtre vidéo, garde le canal)

Dans Windows : les `virtio-win-guest-tools` installés en phase 6.5 incluent le service `vdagent` qui synchronise le presse-papiers automatiquement.

---

## Phase 10 — Partage de fichiers (Virtio-FS)

Permet de monter un dossier Linux natif dans Windows, sans overhead réseau.

### 10.1 — Mémoire partagée (hôte)

```bash
virsh edit win11
```

Ajouter à la racine du `<domain>` (pas dans `<devices>`) :

```xml
<memoryBacking>
  <access mode='shared'/>
</memoryBacking>
```

### 10.2 — Filesystem (virt-manager)

Dans virt-manager : **Add Hardware → Filesystem**

| Champ | Valeur |
|---|---|
| Driver | **virtiofs** |
| Source path | `/home/votrenom/PartageVM` |
| Target path | `host_share` |

Créer le dossier côté Linux si nécessaire :

```bash
mkdir -p ~/PartageVM
```

### 10.3 — Côté Windows

1. Installer **WinFSP** depuis [winfsp.dev](https://winfsp.dev/rel/) (option Core suffisante)
2. Ouvrir un **cmd Administrateur** :

```dos
sc.exe create VirtioFsSvc binpath="C:\Program Files\Virtio-Win\VioFS\virtiofs.exe" start=auto depend="WinFsp.Launcher/VirtioFsDrv" DisplayName="Virtio FS Service"
sc start VirtioFsSvc
```

Le dossier `~/PartageVM` apparaît comme un lecteur dans l'explorateur Windows (généralement `Z:`).

---

## Phase 11 — USB Hotplug

Pour passer dynamiquement des périphériques USB à la VM pendant qu'elle tourne :

1. Dans **virt-manager**, VM allumée → **Virtual Machine → Redirect USB device**
2. Sélectionner le périphérique à envoyer à Windows (clavier, souris, manette...)
3. Pour le retirer : décocher le périphérique dans le même menu

> Pas besoin de passthrough de contrôleur USB entier. Le hotplug SPICE est suffisant pour un usage au cas par cas.

---

## Résumé de l'architecture

```
┌─────────────────────────────────────────────────────┐
│                   Arch Linux (Hôte)                 │
│                                                     │
│  iGPU Radeon ──► Wayland/GNOME ──► Écran 3440×1440  │
│                                                     │
│  RTX 3080 : prime-run (Linux) ◄──► vfio-pci (VM)   │
│       ▲                                ▲            │
│       │          Hooks libvirt         │            │
│       └────── start.sh / revert.sh ────┘            │
│                                                     │
│  ┌──────────────────────────────────────────┐       │
│  │          VM Windows 11 (QEMU/KVM)        │       │
│  │  RTX 3080 passthrough ──► Looking Glass  │       │
│  │  Audio ──► PipeWire (hôte)               │       │
│  │  Disque ──► VirtIO (qcow2)               │       │
│  │  Fichiers ──► Virtio-FS (~/PartageVM)    │       │
│  │  Clipboard ──► SPICE vdagent             │       │
│  └──────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

---

## Références

- [Arch Wiki — PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Looking Glass](https://looking-glass.io/)
- [VFIO-Tools (hooks)](https://github.com/PassthroughPOST/VFIO-Tools)
- [VirtIO-Win drivers](https://github.com/virtio-win/virtio-win-pkg-scripts)
- [IddSampleDriver](https://github.com/ge9/IddSampleDriver)
- [WinFSP](https://winfsp.dev/)
