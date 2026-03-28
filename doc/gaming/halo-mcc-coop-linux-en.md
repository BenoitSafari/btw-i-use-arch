# Halo: The Master Chief Collection — Online Co-op Campaign on Linux

This guide details how to play Halo MCC's campaign in online co-op between Linux machines using Steam and Proton.

---

## 1. Co-op Campaign Support per Title

| Game | Online Co-op Players |
|---|---|
| Halo: CE Anniversary | 2 |
| Halo 2: Anniversary | 2 |
| Halo 3 | 4 |
| Halo 3: ODST | 4 |
| Halo: Reach | 4 |
| Halo 4 | 4 |

All titles support online co-op campaign on PC. Each player needs their own copy of the game.

---

## 2. Launching Without Easy Anti-Cheat (EAC)

EAC does not work under Proton/Wine. When launching Halo MCC from Steam, select **"Play Halo: The Master Chief Collection Anti-Cheat Disabled"** in the launch dialog.

This disables public matchmaking but **online co-op campaign and private matches still work**. Both players must launch without anti-cheat.

---

## 3. Installing Protontricks

Protontricks is a wrapper around Winetricks that lets you apply fixes to Proton game prefixes. It is needed to fix a desync issue in Halo MCC co-op.

### Install from the AUR

Using `yay` (or any AUR helper):

```bash
yay -S protontricks
```

This pulls in the required dependencies (`winetricks`, `python`, etc.) automatically.

### Verify the installation

```bash
protontricks --version
```

---

## 4. Fixing Co-op Desync

By default, Proton ships its own `ucrtbase.dll` which causes desynchronization during co-op campaign sessions. The fix is to replace it with the official Microsoft version.

Run the following command (**the game must have been launched at least once** so the Proton prefix exists):

```bash
protontricks 976730 vcrun2019
```

`976730` is Halo MCC's Steam App ID. This installs the Visual C++ 2019 runtime into the game's Wine prefix, replacing `ucrtbase.dll` with Microsoft's version.

> **Note:** Do **not** manually copy DLLs into the prefix — it will break the game. Use protontricks.

Both Linux players must apply this fix.

---

## 5. Playing Together

1. Both players launch the game with **Anti-Cheat Disabled**
2. One player hosts a co-op campaign lobby via the in-game menu
3. The other player joins through the friends list or invite

No port forwarding is needed — Steam handles the networking.

---

## 6. Troubleshooting

| Issue | Solution |
|---|---|
| Game won't launch after protontricks | Try `protontricks 976730 --force vcrun2019` or delete the prefix (`~/.local/share/Steam/steamapps/compatdata/976730`) and relaunch the game, then reapply the fix |
| Desync still happens | Make sure **both** players applied the vcrun2019 fix |
| Can't see friend's lobby | Both players must be using Anti-Cheat Disabled mode |
| vcrun2019 conflicts with vcrun2022 | Uninstall vcrun2022 first: `protontricks 976730 --force vcrun2019` |
