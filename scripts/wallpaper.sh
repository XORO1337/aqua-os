#!/usr/bin/env bash
# AquaOS — Wallpaper Manager
# Subcommands: set <path> | next | prev | random | current

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/macos-mirror"
WALLPAPER_DIR="${HOME}/Pictures/wallpapers"
CURRENT_FILE="${CACHE_DIR}/current-wallpaper"
LIST_FILE="${CACHE_DIR}/wallpaper-list"

mkdir -p "$CACHE_DIR" "$WALLPAPER_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────

build_list() {
    find "$WALLPAPER_DIR" -maxdepth 2 \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.webp" -o -iname "*.bmp" \) \
        | sort > "$LIST_FILE" || true
}

apply_wallpaper() {
    local path="$1"
    [ -f "$path" ] || { echo "Error: file not found: $path" >&2; exit 1; }

    swww img "$path" \
        --transition-type  grow        \
        --transition-pos   "0.5,0.5"   \
        --transition-duration 1.5      \
        --transition-fps   60          \
        --transition-bezier ".25,1,.5,1" || true

    echo "$path" > "$CURRENT_FILE"

    # Apply matugen colors if available
    if command -v matugen &>/dev/null; then
        matugen image "$path" 2>/dev/null || true
    fi

    # Notify
    local name
    name=$(basename "$path")
    notify-send "Wallpaper" "Changed to: $name" \
        --icon=preferences-desktop-wallpaper --expire-time=3000 2>/dev/null || true
}

get_current_index() {
    local current
    current=$(cat "$CURRENT_FILE" 2>/dev/null || echo "")
    [ -f "$LIST_FILE" ] || build_list
    grep -n "^${current}$" "$LIST_FILE" | cut -d: -f1 | head -1 || echo "1"
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd="${1:-current}"

case "$cmd" in
    set)
        [ -n "${2:-}" ] || { echo "Usage: wallpaper.sh set <path>" >&2; exit 1; }
        apply_wallpaper "$2"
        ;;

    current)
        current=$(cat "$CURRENT_FILE" 2>/dev/null || echo "")
        if [ -f "$current" ]; then
            apply_wallpaper "$current"
        else
            # Fall back to first wallpaper found
            build_list
            first=$(head -1 "$LIST_FILE" 2>/dev/null || echo "")
            if [ -f "$first" ]; then
                apply_wallpaper "$first"
            else
                echo "No wallpapers found in $WALLPAPER_DIR" >&2
                exit 1
            fi
        fi
        ;;

    next)
        build_list
        total=$(wc -l < "$LIST_FILE")
        [ "$total" -eq 0 ] && { echo "No wallpapers found." >&2; exit 1; }
        idx=$(get_current_index)
        next_idx=$(( (idx % total) + 1 ))
        next=$(sed -n "${next_idx}p" "$LIST_FILE")
        apply_wallpaper "$next"
        ;;

    prev)
        build_list
        total=$(wc -l < "$LIST_FILE")
        [ "$total" -eq 0 ] && { echo "No wallpapers found." >&2; exit 1; }
        idx=$(get_current_index)
        prev_idx=$(( (idx - 2 + total) % total + 1 ))
        prev=$(sed -n "${prev_idx}p" "$LIST_FILE")
        apply_wallpaper "$prev"
        ;;

    random)
        build_list
        [ -s "$LIST_FILE" ] || { echo "No wallpapers found." >&2; exit 1; }
        rand=$(shuf -n 1 "$LIST_FILE")
        apply_wallpaper "$rand"
        ;;

    list)
        build_list
        cat "$LIST_FILE"
        ;;

    *)
        echo "Usage: wallpaper.sh {set <path>|next|prev|random|current|list}" >&2
        exit 1
        ;;
esac
