#!/usr/bin/env bash
# AquaOS — Installer (~400 lines)
# Installs all dependencies, fonts, themes, and configuration files.

set -uo pipefail

# ── Color codes ───────────────────────────────────────────────────────────────

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m';     RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────

log()     { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
info()    { echo -e "${BLUE}[i]${RESET} $*"; }
section() { echo -e "\n${BOLD}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}  $*${RESET}"; \
            echo -e "${BOLD}══════════════════════════════════════════${RESET}"; }

confirm() {
    local prompt="${1:-Continue?}"
    read -rp "$(echo -e "${YELLOW}[?]${RESET} ${prompt} [Y/n] ")" ans
    case "${ans,,}" in
        n|no) return 1 ;;
        *)    return 0 ;;
    esac
}

# ── Detect distribution ───────────────────────────────────────────────────────

DISTRO=""
detect_distro() {
    if   [ -f /etc/arch-release ];     then DISTRO="arch"
    elif [ -f /etc/fedora-release ];   then DISTRO="fedora"
    elif [ -f /etc/debian_version ];   then DISTRO="debian"
    elif [ -f /etc/lsb-release ] && grep -qi ubuntu /etc/lsb-release; then DISTRO="ubuntu"
    elif [ -f /etc/opensuse-release ]; then DISTRO="opensuse"
    elif [ -f /etc/nixos/configuration.nix ]; then DISTRO="nixos"
    else DISTRO="unknown"
    fi
    info "Detected distribution: ${BOLD}$DISTRO${RESET}"
}

# ── Detect hardware ───────────────────────────────────────────────────────────

GPU=""
HAS_BATTERY="false"
BACKLIGHT_IFACE=""
DISPLAY_SERVER=""

detect_hardware() {
    # GPU
    if lspci 2>/dev/null | grep -qi nvidia;  then GPU="nvidia"
    elif lspci 2>/dev/null | grep -qi amd;   then GPU="amd"
    elif lspci 2>/dev/null | grep -qi intel; then GPU="intel"
    else GPU="unknown"; fi

    # Battery
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ] \
        && HAS_BATTERY="true"

    # Backlight
    for p in /sys/class/backlight/*/brightness; do
        [ -f "$p" ] && BACKLIGHT_IFACE=$(basename "$(dirname "$p")") && break
    done

    # Display server
    [ -n "${WAYLAND_DISPLAY:-}" ] && DISPLAY_SERVER="wayland" || DISPLAY_SERVER="x11"

    info "GPU: $GPU | Battery: $HAS_BATTERY | Backlight: ${BACKLIGHT_IFACE:-none} | Display: $DISPLAY_SERVER"
}

# ── Package lists ─────────────────────────────────────────────────────────────

ARCH_PACKAGES=(
    hyprland hyprlock hypridle
    swww brightnessctl playerctl
    wl-clipboard cliphist grim slurp
    nautilus pipewire wireplumber
    bluez bluez-utils networkmanager
    jq socat inotify-tools upower
    kitty alacritty
    polkit-gnome
    inter-font ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
    xdg-utils xdg-user-dirs
    libnotify
    qt6-wayland
)
ARCH_AUR_PACKAGES=(
    quickshell-git
    aylurs-gtk-shell-git
    matugen-bin
    grimblast-git
    ghostty-git
    whitesur-gtk-theme-git
    whitesur-icon-theme-git
    whitesur-cursor-theme-git
)

FEDORA_PACKAGES=(
    hyprland hyprlock hypridle
    swww brightnessctl playerctl
    wl-clipboard grim slurp
    nautilus pipewire wireplumber
    bluez NetworkManager
    jq socat inotify-tools upower
    kitty alacritty
    polkit-gnome
    google-noto-fonts noto-fonts-emoji
)

UBUNTU_PACKAGES=(
    brightnessctl playerctl
    wl-clipboard grim slurp
    nautilus pipewire wireplumber
    bluez network-manager
    jq socat inotify-tools upower
    kitty alacritty
    policykit-1-gnome
    fonts-inter fonts-noto-color-emoji
    xdg-utils xdg-user-dirs
    libnotify-bin
)

# ── Install packages ──────────────────────────────────────────────────────────

install_packages() {
    section "Installing packages"
    case "$DISTRO" in
        arch)
            # Ensure yay (AUR helper) is available
            if ! command -v yay &>/dev/null; then
                info "Installing yay AUR helper..."
                sudo pacman -S --needed --noconfirm base-devel git || true
                git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin || true
                (cd /tmp/yay-bin && makepkg -si --noconfirm) || true
            fi
            sudo pacman -Syu --needed --noconfirm "${ARCH_PACKAGES[@]}" || true
            yay -S --needed --noconfirm "${ARCH_AUR_PACKAGES[@]}" || true
            ;;
        fedora)
            sudo dnf install -y "${FEDORA_PACKAGES[@]}" || true
            ;;
        ubuntu|debian)
            sudo apt update -y || true
            sudo apt install -y "${UBUNTU_PACKAGES[@]}" || true
            ;;
        opensuse)
            sudo zypper install -y hyprland kitty alacritty brightnessctl \
                wl-clipboard grim jq socat upower || true
            ;;
        nixos)
            warn "NixOS detected — please manage packages via configuration.nix."
            warn "Required packages: ${ARCH_PACKAGES[*]}"
            ;;
        *)
            warn "Unknown distribution. Please install packages manually."
            warn "See packages.txt for the full list."
            ;;
    esac
    log "Packages installed."
}

# ── Install fonts ─────────────────────────────────────────────────────────────

FONT_DIR="${HOME}/.local/share/fonts"

install_fonts() {
    section "Installing fonts"
    mkdir -p "$FONT_DIR"

    # Inter
    if ! fc-list | grep -qi "Inter"; then
        info "Downloading Inter font..."
        local url="https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"
        wget -qO /tmp/Inter.zip "$url" || true
        unzip -qo /tmp/Inter.zip -d /tmp/Inter || true
        find /tmp/Inter -name "*.otf" -o -name "*.ttf" | xargs -I{} cp {} "$FONT_DIR/" || true
        log "Inter font installed."
    else
        log "Inter font already present."
    fi

    # JetBrains Mono Nerd Font
    if ! fc-list | grep -qi "JetBrains Mono Nerd"; then
        info "Downloading JetBrains Mono Nerd Font..."
        local jb_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        wget -qO /tmp/JBMono.zip "$jb_url" || true
        unzip -qo /tmp/JBMono.zip -d "$FONT_DIR/JetBrainsMono" || true
        log "JetBrains Mono Nerd Font installed."
    else
        log "JetBrains Mono Nerd Font already present."
    fi

    # Symbols Nerd Font
    if ! fc-list | grep -qi "Symbols Nerd Font"; then
        info "Downloading Symbols Nerd Font..."
        local sym_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
        wget -qO /tmp/Symbols.zip "$sym_url" || true
        unzip -qo /tmp/Symbols.zip -d "$FONT_DIR/SymbolsNF" || true
        log "Symbols Nerd Font installed."
    else
        log "Symbols Nerd Font already present."
    fi

    fc-cache -f "$FONT_DIR" || true
    log "Font cache refreshed."
}

# ── Install themes ────────────────────────────────────────────────────────────

THEME_DIR="${HOME}/.local/share/themes"
ICON_DIR="${HOME}/.local/share/icons"

install_themes() {
    section "Installing WhiteSur themes"
    mkdir -p "$THEME_DIR" "$ICON_DIR"

    # GTK theme
    if [ ! -d "$THEME_DIR/WhiteSur-Dark" ]; then
        info "Cloning WhiteSur GTK theme..."
        git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git \
            /tmp/WhiteSur-gtk-theme || true
        (cd /tmp/WhiteSur-gtk-theme && bash install.sh -d "$THEME_DIR" \
            --opacity normal --color Dark --theme default --icon apple || true)
        log "WhiteSur GTK theme installed."
    else
        log "WhiteSur GTK theme already present."
    fi

    # Icon theme
    if [ ! -d "$ICON_DIR/WhiteSur-dark" ]; then
        info "Cloning WhiteSur icon theme..."
        git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git \
            /tmp/WhiteSur-icon-theme || true
        (cd /tmp/WhiteSur-icon-theme && bash install.sh -d "$ICON_DIR" || true)
        log "WhiteSur icon theme installed."
    else
        log "WhiteSur icon theme already present."
    fi

    # Cursor theme
    if [ ! -d "$ICON_DIR/WhiteSur-cursors" ]; then
        info "Cloning WhiteSur cursor theme..."
        git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git \
            /tmp/WhiteSur-cursors || true
        (cd /tmp/WhiteSur-cursors && bash install.sh || true)
        log "WhiteSur cursor theme installed."
    else
        log "WhiteSur cursor theme already present."
    fi
}

# ── Backup existing configs ───────────────────────────────────────────────────

backup_configs() {
    section "Backing up existing configurations"
    local backup_dir="${HOME}/.config/aqua-os-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    for dir in hypr quickshell ags ghostty kitty alacritty matugen; do
        if [ -d "${HOME}/.config/${dir}" ]; then
            cp -r "${HOME}/.config/${dir}" "${backup_dir}/" || true
            log "Backed up ~/.config/${dir}"
        fi
    done

    log "Backup saved to $backup_dir"
}

# ── Deploy configurations ─────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deploy_configs() {
    section "Deploying configurations"
    local cfg="${HOME}/.config"
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "$bin_dir"

    # Copy config directories
    for dir in hypr quickshell ags ghostty kitty alacritty matugen firefox; do
        if [ -d "${SCRIPT_DIR}/${dir}" ]; then
            mkdir -p "${cfg}/${dir}"
            cp -r "${SCRIPT_DIR}/${dir}/." "${cfg}/${dir}/" || true
            log "Deployed ${dir}"
        fi
    done

    # NVIDIA env vars
    if [ "$GPU" = "nvidia" ]; then
        warn "NVIDIA GPU detected — patching Hyprland env vars..."
        cat >> "${cfg}/hypr/hyprland.conf" << 'EOF'

# NVIDIA workarounds
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = GBM_BACKEND,nvidia-drm
EOF
        log "NVIDIA env vars added."
    fi

    # Patch backlight interface in OSD.ts
    if [ -n "$BACKLIGHT_IFACE" ] && [ -f "${cfg}/ags/widgets/OSD.ts" ]; then
        sed -i "s|/sys/class/backlight/[^/]*/brightness|/sys/class/backlight/${BACKLIGHT_IFACE}/brightness|g" \
            "${cfg}/ags/widgets/OSD.ts" || true
        log "Patched backlight path to: ${BACKLIGHT_IFACE}"
    fi

    # AGS types generation
    if command -v ags &>/dev/null; then
        ags types -d "${cfg}/ags" -o "${cfg}/ags/env.d.ts" 2>/dev/null || true
        log "AGS types generated."
    fi

    # Firefox userChrome
    local ff_profile
    ff_profile=$(find "${HOME}/.mozilla/firefox" -name "*.default-release" -type d 2>/dev/null | head -1 || echo "")
    if [ -n "$ff_profile" ]; then
        mkdir -p "${ff_profile}/chrome"
        cp "${SCRIPT_DIR}/firefox/chrome/userChrome.css" "${ff_profile}/chrome/" || true
        log "Firefox userChrome.css deployed to $ff_profile"
    else
        warn "Firefox profile not found — skipping userChrome."
    fi

    # Deploy scripts
    for f in macos-mirror-events wallpaper; do
        if [ -f "${SCRIPT_DIR}/scripts/${f}.sh" ]; then
            cp "${SCRIPT_DIR}/scripts/${f}.sh" "${bin_dir}/${f}.sh"
            chmod +x "${bin_dir}/${f}.sh"
            log "Deployed ${f}.sh to ${bin_dir}"
        fi
    done

    # Default wallpaper directory
    mkdir -p "${HOME}/Pictures/wallpapers"

    log "All configurations deployed."
}

# ── Apply GTK / cursor settings ───────────────────────────────────────────────

apply_settings() {
    section "Applying system settings"

    # GTK settings
    gsettings set org.gnome.desktop.interface gtk-theme    'WhiteSur-Dark'   || true
    gsettings set org.gnome.desktop.interface icon-theme   'WhiteSur-dark'   || true
    gsettings set org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors'|| true
    gsettings set org.gnome.desktop.interface cursor-size  24                || true
    gsettings set org.gnome.desktop.interface font-name    'Inter 11'        || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono Nerd Font 11' || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'     || true
    log "GTK settings applied."

    # GTK 3
    local gtk3="${HOME}/.config/gtk-3.0"
    mkdir -p "$gtk3"
    cat > "${gtk3}/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
gtk-cursor-theme-name=WhiteSur-cursors
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
EOF
    log "GTK 3 settings.ini written."

    # GTK 4
    local gtk4="${HOME}/.config/gtk-4.0"
    mkdir -p "$gtk4"
    cat > "${gtk4}/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
gtk-cursor-theme-name=WhiteSur-cursors
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
EOF
    log "GTK 4 settings.ini written."

    # Cursor index.theme
    local icon_default="${HOME}/.local/share/icons/default"
    mkdir -p "$icon_default"
    cat > "${icon_default}/index.theme" << 'EOF'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=WhiteSur-cursors
EOF
    log "Default cursor theme set."
}

# ── Print summary ─────────────────────────────────────────────────────────────

print_summary() {
    section "Installation Complete!"
    echo ""
    info "Next steps:"
    echo "  1. Log out of your current session"
    echo "  2. Select Hyprland from your display manager"
    echo "  3. AquaOS will start automatically"
    echo ""
    info "Key bindings:"
    echo "  Super+Return   → Terminal (Ghostty)"
    echo "  Super+Space    → Spotlight Launcher"
    echo "  Super+N        → Notification Center"
    echo "  Super+Q        → Close window"
    echo "  Super+F        → Fullscreen"
    echo "  Super+1-6      → Switch workspace"
    echo "  Super+Shift+4  → Screenshot area"
    echo ""
    info "Wallpaper:"
    echo "  Place images in ~/Pictures/wallpapers/"
    echo "  Use: wallpaper.sh {next|prev|random|set <path>}"
    echo ""
    info "Config locations:"
    echo "  ~/.config/hypr/       → Hyprland"
    echo "  ~/.config/quickshell/ → Dock & Top Bar"
    echo "  ~/.config/ags/        → Widgets"
    echo ""
    warn "Known limitations:"
    echo "  - Genie lamp animation requires wlr-animation-plugin"
    echo "  - SF Pro fonts are Apple proprietary (Inter is used instead)"
    echo "  - Electron apps (Discord, VS Code) may not support transparency"
    echo "  - NVIDIA requires nvidia-drm.modeset=1 kernel parameter"
    echo ""
    log "Enjoy AquaOS! 🍎"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'BANNER'
  ___                   ___  ____
 / _ \                 / _ \/ ___|
| | | |  __ _ _   _  | | | \___ \
| |_| | / _` | | | | | |_| |___) |
 \__\_\/_/ \__,_|_|_|_|\___/|____/

  macOS-Mirror Linux Desktop Environment
BANNER
    echo -e "${RESET}"

    detect_distro
    detect_hardware

    echo ""
    info "This installer will:"
    echo "  1. Install packages"
    echo "  2. Install fonts"
    echo "  3. Install WhiteSur themes"
    echo "  4. Back up existing configs"
    echo "  5. Deploy AquaOS configuration"
    echo "  6. Apply system settings"
    echo ""

    confirm "Proceed with installation?" || { info "Aborted."; exit 0; }

    confirm "Install packages?" && install_packages || warn "Skipping packages."
    confirm "Install fonts?" && install_fonts || warn "Skipping fonts."
    confirm "Install WhiteSur themes?" && install_themes || warn "Skipping themes."
    confirm "Back up existing configs?" && backup_configs || warn "Skipping backup."
    confirm "Deploy AquaOS configs?" && deploy_configs || warn "Skipping config deployment."
    confirm "Apply GTK/cursor settings?" && apply_settings || warn "Skipping settings."

    print_summary
}

main "$@"
