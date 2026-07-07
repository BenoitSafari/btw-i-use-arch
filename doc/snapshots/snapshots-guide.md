# Snapper / Btrfs Snapshots - Guide complet

## Architecture en place

Le systeme utilise **Btrfs** avec les subvolumes suivants :

| Subvolume    | Point de montage | Role                |
|-------------|------------------|---------------------|
| `@`         | `/`              | Systeme racine      |
| `@home`     | `/home`          | Donnees utilisateur |
| `@snapshots`| `/.snapshots`    | Stockage snapshots  |

**Snapper** gere les snapshots automatiques (1/jour, retention 7 jours).
**grub-btrfs** rend les snapshots bootables dans le menu GRUB.

---

## 1. Creer un snapshot manuel

```bash
# Snapshot avec description datee automatiquement
sudo snapper -c root create --description "manual-$(date +%Y-%m-%d)"

# Mettre a jour GRUB pour voir le snapshot au boot
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Script : `snapshot-create.sh`

```bash
#!/bin/bash
# Cree un snapshot Btrfs manuel via Snapper et met a jour GRUB.
# Usage : sudo ./snapshot-create.sh [description optionnelle]

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Erreur : ce script doit etre lance en root (sudo)."
    exit 1
fi

DATE=$(date +%Y-%m-%d_%H%M)
DESC="${1:-manual-$DATE}"

echo "=> Creation du snapshot : $DESC"
SNAP_NUM=$(snapper -c root create --description "$DESC" --print-number)
echo "   Snapshot #$SNAP_NUM cree."

echo "=> Mise a jour de GRUB..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "=> Termine. Snapshot #$SNAP_NUM ($DESC) disponible au prochain boot."
```

---

## 2. Voir les snapshots dans GRUB (pas dans le BIOS)

> **Important** : Les snapshots n'apparaissent **jamais dans le BIOS/UEFI**.
> Ils apparaissent dans le **menu GRUB**, qui s'affiche apres le BIOS.

### Diagnostiquer pourquoi les snapshots ne s'affichent pas dans GRUB

```bash
# 1. Verifier que grub-btrfsd tourne
systemctl status grub-btrfsd

# 2. Verifier que des snapshots existent
sudo snapper -c root list

# 3. Verifier que les timers snapper tournent
systemctl status snapper-timeline.timer
systemctl status snapper-cleanup.timer

# 4. Regenerer le menu GRUB manuellement
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 5. Verifier que le sous-menu snapshots existe dans grub.cfg
grep -c "snapshot" /boot/grub/grub.cfg
```

### Script : `snapshot-diagnose.sh`

```bash
#!/bin/bash
# Diagnostique l'etat du systeme de snapshots et de GRUB.
# Usage : sudo ./snapshot-diagnose.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Erreur : ce script doit etre lance en root (sudo)."
    exit 1
fi

echo "============================================"
echo " Diagnostic Snapshots / GRUB"
echo "============================================"

echo ""
echo "--- Services ---"
for svc in grub-btrfsd snapper-timeline.timer snapper-cleanup.timer; do
    STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
    echo "  $svc : $STATUS"
done

echo ""
echo "--- Snapshots existants ---"
snapper -c root list

echo ""
echo "--- Subvolumes Btrfs ---"
btrfs subvolume list /

echo ""
echo "--- Point de montage /.snapshots ---"
findmnt /.snapshots || echo "  ERREUR : /.snapshots n'est pas monte !"

echo ""
echo "--- Entrees snapshots dans GRUB ---"
COUNT=$(grep -c "snapshot" /boot/grub/grub.cfg 2>/dev/null || echo "0")
echo "  $COUNT references trouvees dans grub.cfg"

if [[ "$COUNT" -eq 0 ]]; then
    echo ""
    echo "=> Aucun snapshot dans GRUB. Regeneration..."
    grub-mkconfig -o /boot/grub/grub.cfg
    NEW_COUNT=$(grep -c "snapshot" /boot/grub/grub.cfg 2>/dev/null || echo "0")
    echo "  Apres regeneration : $NEW_COUNT references."
fi

echo ""
echo "============================================"
echo " Diagnostic termine."
echo "============================================"
```

### Causes frequentes

| Probleme | Solution |
|----------|----------|
| `grub-btrfsd` inactif | `sudo systemctl enable --now grub-btrfsd` |
| Aucun snapshot | Lancer `snapshot-create.sh` |
| Snapshots existent mais pas dans GRUB | `sudo grub-mkconfig -o /boot/grub/grub.cfg` |
| `/.snapshots` pas monte | Verifier `/etc/fstab` contient le montage du subvolume `@snapshots` |

---

## 3. Valider un snapshot apres restauration

Quand on boot sur un snapshot via GRUB (grub-btrfs), le systeme demarre en
**lecture seule** depuis le snapshot. Ce n'est pas permanent : au prochain
reboot sans selectionner le snapshot, on revient a l'etat precedent.

Pour **rendre la restauration permanente**, il faut remplacer le subvolume
`@` actuel par le contenu du snapshot.

### Script : `snapshot-validate.sh`

```bash
#!/bin/bash
# Valide (rend permanent) le snapshot actuellement boote.
# A lancer APRES avoir boote sur un snapshot via GRUB.
# Usage : sudo ./snapshot-validate.sh
#
# Ce que fait ce script :
#   1. Detecte le snapshot en cours
#   2. Remonte la partition Btrfs racine
#   3. Renomme l'ancien @ en @.broken
#   4. Cree un snapshot rw du snapshot restaure comme nouveau @
#   5. Regenere GRUB et propose un reboot

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Erreur : ce script doit etre lance en root (sudo)."
    exit 1
fi

# Detecter le device racine Btrfs
ROOT_DEV=$(findmnt -n -o SOURCE / | cut -d'[' -f1)
echo "Device racine : $ROOT_DEV"

# Verifier qu'on est sur Btrfs
FSTYPE=$(findmnt -n -o FSTYPE /)
if [[ "$FSTYPE" != "btrfs" ]]; then
    echo "Erreur : le filesystem racine n'est pas Btrfs ($FSTYPE)."
    exit 1
fi

# Detecter le subvolume actuel
CURRENT_SUBVOL=$(btrfs subvolume show / 2>/dev/null | head -1 | xargs)
echo "Subvolume actuel : $CURRENT_SUBVOL"

# Si on est deja sur @, rien a valider
if [[ "$CURRENT_SUBVOL" == "@" ]]; then
    echo "Vous etes deja sur le subvolume @ principal."
    echo "Rien a valider. Si vous voulez restaurer un snapshot,"
    echo "bootez d'abord dessus via le menu GRUB."
    exit 0
fi

echo ""
echo "============================================"
echo " ATTENTION - Operation irreversible"
echo "============================================"
echo ""
echo "Ce script va :"
echo "  1. Renommer @ en @.broken (sauvegarde)"
echo "  2. Creer un nouveau @ a partir du snapshot actuel"
echo "  3. Regenerer GRUB"
echo ""
read -rp "Continuer ? (oui/non) : " CONFIRM
if [[ "$CONFIRM" != "oui" ]]; then
    echo "Annule."
    exit 0
fi

# Monter la racine Btrfs (sans subvolume) dans un point temporaire
TMPDIR=$(mktemp -d)
mount -o subvolid=5 "$ROOT_DEV" "$TMPDIR"
echo "=> Partition Btrfs montee sur $TMPDIR"

# Renommer l'ancien @
BACKUP_NAME="@.broken-$(date +%Y%m%d-%H%M%S)"
if [[ -d "$TMPDIR/@" ]]; then
    mv "$TMPDIR/@" "$TMPDIR/$BACKUP_NAME"
    echo "=> Ancien @ renomme en $BACKUP_NAME"
fi

# Detecter le chemin du snapshot dans le montage
# Les snapshots snapper sont dans @snapshots/<num>/snapshot
SNAP_PATH=""
for dir in "$TMPDIR"/@snapshots/*/snapshot; do
    if [[ -d "$dir" ]]; then
        # Verifier si c'est le bon snapshot en comparant les subvolume IDs
        SNAP_ID=$(btrfs subvolume show "$dir" 2>/dev/null | grep "Subvolume ID" | awk '{print $3}')
        CURRENT_ID=$(btrfs subvolume show / 2>/dev/null | grep "Subvolume ID" | awk '{print $3}')
        if [[ "$SNAP_ID" == "$CURRENT_ID" ]]; then
            SNAP_PATH="$dir"
            break
        fi
    fi
done

if [[ -z "$SNAP_PATH" ]]; then
    echo "Erreur : impossible de trouver le snapshot source."
    echo "Restauration de @ depuis le backup..."
    mv "$TMPDIR/$BACKUP_NAME" "$TMPDIR/@"
    umount "$TMPDIR"
    rmdir "$TMPDIR"
    exit 1
fi

echo "=> Snapshot source : $SNAP_PATH"

# Creer un snapshot rw comme nouveau @
btrfs subvolume snapshot "$SNAP_PATH" "$TMPDIR/@"
echo "=> Nouveau @ cree depuis le snapshot."

# Nettoyage
umount "$TMPDIR"
rmdir "$TMPDIR"

# Regenerer GRUB
echo "=> Regeneration de GRUB..."
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "============================================"
echo " Validation terminee."
echo "============================================"
echo ""
echo "L'ancien systeme est conserve dans : $BACKUP_NAME"
echo "Pour le supprimer plus tard :"
echo "  mount -o subvolid=5 $ROOT_DEV /mnt"
echo "  btrfs subvolume delete /mnt/$BACKUP_NAME"
echo "  umount /mnt"
echo ""
read -rp "Redemarrer maintenant ? (oui/non) : " REBOOT
if [[ "$REBOOT" == "oui" ]]; then
    reboot
fi
```

---

## Resume des commandes rapides

| Action | Commande |
|--------|----------|
| Lister les snapshots | `sudo snapper -c root list` |
| Creer un snapshot | `sudo ./snapshot-create.sh` |
| Diagnostiquer | `sudo ./snapshot-diagnose.sh` |
| Supprimer un snapshot | `sudo snapper -c root delete <numero>` |
| Comparer 2 snapshots | `sudo snapper -c root diff <n1>..<n2>` |
| Restaurer (boot) | Selectioner le snapshot dans GRUB > Arch Linux snapshots |
| Valider la restauration | `sudo ./snapshot-validate.sh` (apres boot sur le snapshot) |
