#!/usr/bin/env bash
# AquaOS — macOS-Mirror Event Daemon
# Zero-poll, event-driven. Single process, multiple background listeners.
# All output is JSON lines to stdout.

set -euo pipefail

# ── Cache directory ───────────────────────────────────────────────────────────

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/macos-mirror"
mkdir -p "$CACHE_DIR"

# ── Helper functions ──────────────────────────────────────────────────────────

get_volume() {
    local raw
    raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || { echo '{"volume":0,"muted":false}'; return; }
    local vol muted
    vol=$(echo "$raw"  | awk '{print $2}')
    muted="false"
    echo "$raw" | grep -q '\[MUTED\]' && muted="true"
    printf '{"volume":%s,"muted":%s}' "$vol" "$muted"
}

get_network() {
    local type name
    # Check for active WiFi connection
    name=$(nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null \
           | awk -F: '$3=="activated"{print $1; exit}')
    if nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
       | grep -q "wifi:connected"; then
        type="wifi"
    elif nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
         | grep -q "ethernet:connected"; then
        type="ethernet"
    else
        type="disconnected"
        name=""
    fi
    printf '{"type":"%s","name":"%s"}' "$type" "${name:-}"
}

get_battery() {
    local path capacity status
    for p in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
        [ -f "$p/capacity" ] && path="$p" && break
    done
    if [ -z "${path:-}" ]; then
        echo '{"hasBattery":false,"capacity":0,"status":"Unknown"}'
        return
    fi
    capacity=$(cat "$path/capacity" 2>/dev/null || echo "0")
    status=$(cat "$path/status"   2>/dev/null || echo "Unknown")
    printf '{"hasBattery":true,"capacity":%d,"status":"%s"}' "$capacity" "$status"
}

# ── Full state snapshot ───────────────────────────────────────────────────────

emit_state() {
    local vol net bat
    vol=$(get_volume)
    net=$(get_network)
    bat=$(get_battery)

    local volume muted netType netName hasBat cap batSt
    volume=$(echo "$vol" | grep -o '"volume":[0-9.]*'    | cut -d: -f2)
    muted=$(echo  "$vol" | grep -o '"muted":[a-z]*'       | cut -d: -f2)
    netType=$(echo "$net" | grep -o '"type":"[^"]*"'       | cut -d\" -f4)
    netName=$(echo "$net" | grep -o '"name":"[^"]*"'       | cut -d\" -f4)
    hasBat=$(echo  "$bat" | grep -o '"hasBattery":[a-z]*'  | cut -d: -f2)
    cap=$(echo     "$bat" | grep -o '"capacity":[0-9]*'     | cut -d: -f2)
    batSt=$(echo   "$bat" | grep -o '"status":"[^"]*"'      | cut -d\" -f4)

    printf '{"event":"state","volume":%s,"muted":%s,"netType":"%s","netName":"%s","hasBattery":%s,"capacity":%s,"batStatus":"%s"}\n' \
        "${volume:-0}" "${muted:-false}" "${netType:-disconnected}" "${netName:-}" \
        "${hasBat:-false}" "${cap:-0}" "${batSt:-Unknown}"
}

# ── Hyprland socket listener ──────────────────────────────────────────────────

listen_hyprland() {
    local sock
    sock="${HYPRLAND_INSTANCE_SIGNATURE:+/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock}"
    [ -z "$sock" ] && return
    [ -S "$sock" ] || return

    socat -u "UNIX-CONNECT:$sock" - 2>/dev/null | while IFS= read -r line; do
        local event data
        event="${line%%>>*}"
        data="${line#*>>}"
        case "$event" in
            activewindow)
                local class title
                class="${data%%,*}"
                title="${data#*,}"
                # Truncate before escaping to avoid mid-sequence corruption
                title="${title:0:120}"
                printf '{"event":"activewindow","class":"%s","title":"%s"}\n' \
                    "$(echo "$class" | sed 's/"/\\"/g')" \
                    "$(echo "$title" | sed 's/"/\\"/g')"
                ;;
            workspace)
                printf '{"event":"workspace","workspace":"%s"}\n' "$data"
                ;;
            openwindow)
                local winclass
                winclass=$(echo "$data" | cut -d, -f2)
                printf '{"event":"openwindow","class":"%s"}\n' \
                    "$(echo "$winclass" | sed 's/"/\\"/g')"
                ;;
            closewindow)
                printf '{"event":"closewindow","address":"%s"}\n' "$data"
                ;;
        esac
    done
}

# ── Volume listener ───────────────────────────────────────────────────────────

listen_volume() {
    pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" | while IFS= read -r _; do
        local vol
        vol=$(get_volume)
        local volume muted
        volume=$(echo "$vol" | grep -o '"volume":[0-9.]*' | cut -d: -f2)
        muted=$(echo  "$vol" | grep -o '"muted":[a-z]*'   | cut -d: -f2)
        printf '{"event":"volume","volume":%s,"muted":%s}\n' \
            "${volume:-0}" "${muted:-false}"
    done
}

# ── Network listener ──────────────────────────────────────────────────────────

listen_network() {
    nmcli monitor 2>/dev/null | grep --line-buffered -v "^$" | while IFS= read -r _; do
        local net netType netName
        net=$(get_network)
        netType=$(echo "$net" | grep -o '"type":"[^"]*"' | cut -d\" -f4)
        netName=$(echo "$net" | grep -o '"name":"[^"]*"' | cut -d\" -f4)
        printf '{"event":"network","type":"%s","name":"%s"}\n' \
            "${netType:-disconnected}" "${netName:-}"
    done
}

# ── Battery listener ──────────────────────────────────────────────────────────

listen_battery() {
    upower --monitor 2>/dev/null | grep --line-buffered "battery" | while IFS= read -r _; do
        local bat hasBat cap batSt
        bat=$(get_battery)
        hasBat=$(echo "$bat" | grep -o '"hasBattery":[a-z]*' | cut -d: -f2)
        cap=$(echo    "$bat" | grep -o '"capacity":[0-9]*'    | cut -d: -f2)
        batSt=$(echo  "$bat" | grep -o '"status":"[^"]*"'     | cut -d\" -f4)
        printf '{"event":"battery","hasBattery":%s,"capacity":%s,"status":"%s"}\n' \
            "${hasBat:-false}" "${cap:-0}" "${batSt:-Unknown}"
    done
}

# ── Downloads listener ────────────────────────────────────────────────────────

listen_downloads() {
    local dl_dir="$HOME/Downloads"
    mkdir -p "$dl_dir"
    inotifywait -m -e close_write,moved_to,moved_from,delete "$dl_dir" 2>/dev/null \
    | while IFS= read -r _; do
        printf '{"event":"downloads"}\n'
    done
}

# ── Launch all listeners in background ───────────────────────────────────────

listen_hyprland  &
listen_volume    &
listen_network   &
listen_battery   &
listen_downloads &

# ── Emit initial state ────────────────────────────────────────────────────────

emit_state

# ── Heartbeat loop (60 s) ─────────────────────────────────────────────────────

while true; do
    sleep 60
    emit_state
done
