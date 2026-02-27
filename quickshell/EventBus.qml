// AquaOS — Event Bus
// Single process reads the event daemon stdout; exposes reactive properties
// to all UI components. No independent polling anywhere.

import Quickshell
import QtQuick

Item {
    id: root

    // ── Reactive Properties ───────────────────────────────────────────────

    property string activeWindowTitle: ""
    property string activeWindowClass: ""
    property int    activeWorkspace: 1

    // Set of running app classes (updated only on close events)
    property var    runningClasses: ({})

    // Audio
    property int    volume: 50
    property bool   muted:  false

    // Network
    property string networkType: "disconnected"   // "wifi" | "ethernet" | "disconnected"
    property string networkName: ""

    // Battery
    property bool   hasBattery:      false
    property int    batteryCapacity: 100
    property string batteryStatus:   "Unknown"    // "Charging" | "Discharging" | "Full"

    // Downloads
    property int    downloadCount:   0
    property var    recentDownloads: []

    // ── Event Daemon Process ──────────────────────────────────────────────

    Process {
        id: daemonProc
        command: ["bash", "-c", Quickshell.env("HOME") + "/.local/bin/macos-mirror-events.sh"]

        stdout: SplitParser {
            onRead: function(line) { root.handleEvent(line) }
        }

        onExited: function(code, status) {
            console.warn("EventBus: daemon exited with code", code, "— restarting in 3s")
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            console.log("EventBus: restarting daemon")
            daemonProc.running = true
        }
    }

    // ── refreshRunningProc — only on closewindow ──────────────────────────

    Process {
        id: refreshRunningProc
        command: ["bash", "-c", "hyprctl clients -j | jq -r '.[].class' | sort -u"]

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") {
                    var updated = root.runningClasses
                    updated[line.trim()] = true
                    root.runningClasses = updated
                }
            }
        }

        onExited: function() {
            // Ensure property change notification fires
            root.runningClassesChanged()
        }
    }

    // ── refreshDownloadsProc — only on downloads event ────────────────────

    Process {
        id: refreshDownloadsProc
        command: ["bash", "-c", "ls -tp ~/Downloads | grep -v '/$' | head -9"]

        property var collected: []

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") {
                    refreshDownloadsProc.collected.push(line.trim())
                }
            }
        }

        onExited: function() {
            root.recentDownloads = refreshDownloadsProc.collected
            root.downloadCount   = refreshDownloadsProc.collected.length
            refreshDownloadsProc.collected = []
        }
    }

    // ── JSON Event Handler ────────────────────────────────────────────────

    function handleEvent(line) {
        if (!line || line.trim() === "") return
        var ev
        try {
            ev = JSON.parse(line)
        } catch (e) {
            return
        }

        switch (ev.event) {
            case "activewindow":
                root.activeWindowTitle = ev.title  || ""
                root.activeWindowClass = ev.class_ || ev["class"] || ""
                break

            case "workspace":
                root.activeWorkspace = parseInt(ev.workspace) || 1
                break

            case "openwindow":
                // Add newly opened class
                var open = root.runningClasses
                open[ev.class_ || ev["class"] || ""] = true
                root.runningClasses = open
                break

            case "closewindow":
                // Full refresh is cheaper than tracking individual closes
                refreshRunningProc.running = true
                break

            case "volume":
                root.volume = Math.round((parseFloat(ev.volume) || 0) * 100)
                root.muted  = ev.muted === true || ev.muted === "true"
                break

            case "network":
                root.networkType = ev.type || "disconnected"
                root.networkName = ev.name || ""
                break

            case "battery":
                root.hasBattery      = true
                root.batteryCapacity = parseInt(ev.capacity)  || 0
                root.batteryStatus   = ev.status || "Unknown"
                break

            case "downloads":
                refreshDownloadsProc.collected = []
                refreshDownloadsProc.running   = true
                break

            case "state":
                // Full heartbeat snapshot — update all fields
                if (ev.volume    !== undefined) root.volume    = Math.round((parseFloat(ev.volume) || 0) * 100)
                if (ev.muted     !== undefined) root.muted     = ev.muted === true || ev.muted === "true"
                if (ev.netType   !== undefined) root.networkType = ev.netType
                if (ev.netName   !== undefined) root.networkName = ev.netName
                if (ev.hasBattery !== undefined) root.hasBattery = ev.hasBattery
                if (ev.capacity  !== undefined) root.batteryCapacity = parseInt(ev.capacity) || 0
                if (ev.batStatus !== undefined) root.batteryStatus = ev.batStatus
                break

            default:
                break
        }
    }

    // ── isAppRunning — fuzzy match ────────────────────────────────────────

    function isAppRunning(appName) {
        var lower = appName.toLowerCase()
        for (var cls in root.runningClasses) {
            if (cls.toLowerCase().indexOf(lower) !== -1 || lower.indexOf(cls.toLowerCase()) !== -1) {
                return true
            }
        }
        return false
    }

    // ── Initial bootstrap ─────────────────────────────────────────────────

    Component.onCompleted: {
        daemonProc.running           = true
        refreshRunningProc.running   = true
        refreshDownloadsProc.collected = []
        refreshDownloadsProc.running = true
    }
}
