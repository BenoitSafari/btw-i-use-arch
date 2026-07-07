# Sunshine — Remote Desktop Streaming Setup on Arch Linux (KDE Plasma)

This guide details how to install and configure **Sunshine** (by LizardByte) on Arch Linux for game/desktop streaming via **Moonlight**, including automatic resolution switching on client connect/disconnect.

---

## 1. Adding the LizardByte Pacman Repository

LizardByte provides an official pacman repository. **Do not use the AUR package** — it is not maintained by LizardByte.

Add the following to `/etc/pacman.conf`:

```ini
[lizardbyte]
SigLevel = Optional
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download
```

Then sync the repos:

```bash
sudo pacman -Sy
```

---

## 2. Installing Sunshine

```bash
sudo pacman -S lizardbyte/sunshine
```

---

## 3. Enabling the Sunshine Service

Sunshine runs as a user service:

```bash
systemctl --user enable --now sunshine
```

The web UI is then accessible at `https://localhost:47990` to pair with Moonlight clients and configure applications.

---

## 4. Resolution Switching Hook (KDE Plasma)

When a Moonlight client connects, Sunshine exposes environment variables describing the client's display. We use these with `kscreen-doctor` to automatically match the host resolution to the client, and revert on disconnect.

### Available Sunshine Environment Variables

| Variable | Description |
|---|---|
| `$SUNSHINE_CLIENT_WIDTH` | Client horizontal resolution |
| `$SUNSHINE_CLIENT_HEIGHT` | Client vertical resolution |
| `$SUNSHINE_CLIENT_FPS` | Client requested framerate |

### Setup

In the Sunshine web UI (`https://localhost:47990`), edit your application (or the default `Desktop` entry) and add a **Command Preparation** entry:

| Field | Command |
|---|---|
| **Do** (on connect) | `kscreen-doctor output.DP-1.mode.${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}` |
| **Undo** (on disconnect) | `kscreen-doctor output.DP-1.mode.2560x1440@165` |

> **Note:** Replace `DP-1` with your actual output name (check with `kscreen-doctor -o`). Replace `2560x1440@165` in the Undo command with your monitor's native resolution and refresh rate.

### Finding Your Output Name

```bash
kscreen-doctor -o
```

This lists all connected outputs with their current mode. Use the output name (e.g. `DP-1`, `HDMI-A-1`, `eDP-1`) in the commands above.

---

## 5. Firewall Rules (Optional)

If you run a firewall, Sunshine needs the following ports open:

| Port | Protocol | Purpose |
|---|---|---|
| 47984 | TCP | HTTPS / Web UI |
| 47989 | TCP | HTTP |
| 47990 | TCP | Web UI |
| 48010 | TCP | RTSP |
| 47998-48000 | UDP | Video/Audio/Control stream |

Example with `ufw`:

```bash
sudo ufw allow 47984/tcp
sudo ufw allow 47989/tcp
sudo ufw allow 47990/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47998:48000/udp
```

---

## 6. Pairing with Moonlight

1. Open the Sunshine web UI at `https://localhost:47990`
2. On your client device, open Moonlight and add the host IP
3. Moonlight will display a PIN — enter it in the Sunshine web UI to pair

Once paired, launching a stream will trigger the resolution hook automatically.
