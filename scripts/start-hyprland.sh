#!/usr/bin/env bash
# AquaOS — Hyprland Launcher
# Ensures all required XDG environment variables are set before starting Hyprland.
# NEVER run Hyprland with sudo. This script must run as your regular user.

set -euo pipefail

# ── Refuse to run as root ─────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run Hyprland as root (sudo)."
    echo "Hyprland must run as your regular user."
    echo ""
    echo "Usage: bash ~/.local/bin/start-hyprland.sh"
    echo "   or: select 'Hyprland' from your display manager"
    exit 1
fi

# ── Ensure XDG_RUNTIME_DIR ────────────────────────────────────────────────────
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    echo "WARNING: XDG_RUNTIME_DIR was not set. Defaulting to: $XDG_RUNTIME_DIR"
fi

# Create the runtime directory if it doesn't exist
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
elif [ "$(stat -c '%u' "$XDG_RUNTIME_DIR" 2>/dev/null)" != "$(id -u)" ]; then
    echo "ERROR: $XDG_RUNTIME_DIR exists but is not owned by you (uid $(id -u))."
    echo "Fix with: sudo chown $(id -u):$(id -g) $XDG_RUNTIME_DIR"
    exit 1
fi

# ── Ensure other XDG variables ────────────────────────────────────────────────
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# ── Qt / Wayland environment ──────────────────────────────────────────────────
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}"
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"

# ── Launch Hyprland ───────────────────────────────────────────────────────────
exec Hyprland "$@"
