# AquaOS

🍎 **AquaOS** — A high-fidelity macOS-mirror desktop environment for Linux.  
**Hyprland + Quickshell (QML) + AGS/Astal (TypeScript)**  
Zero-poll, event-driven architecture. Target idle CPU: ~0.1–0.3%.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   User Interface                     │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  TopBar   │  │   Dock   │  │  Widget Center    │  │
│  │(Quickshell│  │(Quickshell│  │  (AGS/Astal)      │  │
│  │   QML)    │  │   QML)   │  │  TypeScript/GJS   │  │
│  └──────────┘  └──────────┘  └───────────────────┘  │
├─────────────────────────────────────────────────────┤
│         Event Daemon (Single bash process)           │
│  socat(hyprland) · pactl · nmcli · upower · inotify │
├─────────────────────────────────────────────────────┤
│             Compositor (Hyprland)                    │
│  blur · animations · window rules · layer shell     │
├─────────────────────────────────────────────────────┤
│          Theme Layer (WhiteSur + matugen)            │
│  GTK · Icons · Cursors · Terminal · VS Code         │
└─────────────────────────────────────────────────────┘
```

---

## Requirements

- **OS**: Arch Linux (recommended), Fedora, Ubuntu/Debian, openSUSE
- **Display Server**: Wayland
- **Compositor**: Hyprland ≥ 0.39
- **GPU**: AMD or Intel recommended (NVIDIA supported with workarounds)

---

## Quick Install (Arch Linux)

```bash
git clone https://github.com/XORO1337/aqua-os.git
cd aqua-os
bash install.sh
```

---

## Manual Install

```bash
# 1. Install packages (see packages.txt)
yay -S $(grep -v '#' packages.txt | grep '\S' | awk '{print $1}')

# 2. Install fonts
make install   # Or run install.sh and choose only fonts

# 3. Install WhiteSur themes
# (done automatically by install.sh)

# 4. Deploy configs
cp -r hypr      ~/.config/hypr
cp -r quickshell ~/.config/quickshell
cp -r ags       ~/.config/ags
cp -r ghostty   ~/.config/ghostty
cp -r kitty     ~/.config/kitty
cp -r alacritty ~/.config/alacritty
cp -r matugen   ~/.config/matugen
cp scripts/macos-mirror-events.sh ~/.local/bin/
cp scripts/wallpaper.sh           ~/.local/bin/
chmod +x ~/.local/bin/macos-mirror-events.sh
chmod +x ~/.local/bin/wallpaper.sh

# 5. Log out and select Hyprland from display manager
```

---

## Verify Installation

```bash
make check
```

---

## Key Bindings

| Binding | Action |
|---------|--------|
| `Super + Return` | Terminal (Ghostty) |
| `Super + Space` | Spotlight Launcher |
| `Super + N` | Notification Center |
| `Super + E` | File Manager (Nautilus) |
| `Super + B` | Browser (Firefox) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + T` | Toggle floating |
| `Super + H/J/K/L` | Focus window (vim-style) |
| `Super + 1-6` | Switch workspace |
| `Super + Shift + 1-6` | Move window to workspace |
| `Super + Shift + 4` | Screenshot area |
| `Super + Shift + 3` | Screenshot screen |
| `Print` | Screenshot area to clipboard |
| `Super + R` | Resize submap |

---

## Terminals

| Terminal | Config | Notes |
|----------|--------|-------|
| **Ghostty** | `ghostty/config` | Primary, GPU-accelerated |
| **Kitty** | `kitty/kitty.conf` | Powerline tab bar |
| **Alacritty** | `alacritty/alacritty.toml` | Lightweight |

All terminals share the same frosty glass palette and JetBrains Mono Nerd Font.

---

## Wallpaper Commands

```bash
wallpaper.sh set ~/Pictures/wallpapers/ocean.jpg   # Set specific
wallpaper.sh next                                   # Next in list
wallpaper.sh prev                                   # Previous
wallpaper.sh random                                 # Random
wallpaper.sh current                                # Restore current
```

Images are read from `~/Pictures/wallpapers/` (jpg/jpeg/png/webp/bmp).  
If `matugen` is installed, colors are regenerated on every wallpaper change.

---

## Dock Customization

Edit `~/.config/quickshell/DockContent.qml`, `pinnedApps` ListModel:

```qml
ListElement { name: "MyApp"; icon: "myapp"; appClass: "myapp"; cmd: "myapp" }
```

---

## Backup & Restore

```bash
make backup     # Saves timestamped backup to ~/.config/aqua-os-backup-*/
make restore    # Restores from the latest backup
```

---

## Known Limitations

- **Genie lamp animation**: Requires `wlr-animation-plugin` (experimental)
- **SF Pro fonts**: Apple proprietary — **Inter** is used instead
- **Electron apps** (Discord, VS Code, Obsidian): Transparency may not work
- **NVIDIA**: Add `nvidia-drm.modeset=1` to kernel cmdline; `install.sh` patches env vars automatically
- **Blur on first launch**: May require a compositor restart (`hyprctl reload`)

---

## File Structure

```
aqua-os/
├── hypr/
│   ├── hyprland.conf       # Main config (sources others)
│   ├── monitors.conf       # Monitor setup
│   ├── keybinds.conf       # Key bindings
│   ├── windowrules.conf    # Window / layer rules
│   ├── autostart.conf      # Startup applications
│   ├── hyprlock.conf       # Lock screen
│   └── hypridle.conf       # Idle daemon
├── quickshell/
│   ├── shell.qml           # Shell root
│   ├── EventBus.qml        # Zero-poll event bus
│   ├── TopBarContent.qml   # macOS-style top bar
│   ├── DockContent.qml     # Magnification dock
│   └── DownloadsStack.qml  # Downloads folder widget
├── ags/
│   ├── app.ts              # Entry point
│   ├── style.scss          # Main styles
│   ├── widgets.scss        # Widget styles
│   └── widgets/
│       ├── NotificationCenter.ts
│       ├── ControlCenter.ts
│       ├── Launcher.ts
│       ├── SystemMonitor.ts
│       ├── PowerMenu.ts
│       ├── OSD.ts
│       ├── MediaPlayer.ts
│       └── Calendar.ts
├── ghostty/config          # Ghostty terminal
├── kitty/kitty.conf        # Kitty terminal
├── alacritty/alacritty.toml# Alacritty terminal
├── matugen/
│   ├── config.toml
│   └── templates/
│       ├── hyprland-colors.conf
│       └── ags-colors.scss
├── firefox/chrome/
│   └── userChrome.css      # Translucent Firefox UI
├── scripts/
│   ├── macos-mirror-events.sh  # Event daemon
│   └── wallpaper.sh            # Wallpaper manager
├── install.sh              # Full installer
├── Makefile                # Build targets
├── packages.txt            # Dependency list
└── README.md
```

---

## Credits

- [Hyprland](https://hyprland.org/) — Tiling Wayland compositor
- [Quickshell](https://quickshell.outfoxxed.me/) — QML shell framework
- [AGS / Astal](https://aylur.github.io/astal/) — GJS widget toolkit
- [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme) — macOS-style GTK theme
- [Matugen](https://github.com/InioX/matugen) — Material You color generation
- [swww](https://github.com/LGFae/swww) — Wayland wallpaper daemon
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/) — Terminal font
- [Inter](https://rsms.me/inter/) — UI font

---

## License

MIT © 2024 AquaOS Contributors

