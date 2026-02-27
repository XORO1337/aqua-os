// AquaOS — Top Bar Content
// Pure-QML, zero forks. Clock uses a JS Date() timer.

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    required property var bus   // EventBus instance

    // ── Glass background ─────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.08, 0.08, 0.10, 0.72)

        // Bottom border separator
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 0.5
            color: Qt.rgba(1, 1, 1, 0.12)
        }
    }

    // ── Clock Timer (pure JS, 15 s interval, zero forks) ─────────────────

    property string clockText: ""
    property string ampm:      ""

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var h = d.getHours()
            var m = d.getMinutes()
            root.ampm  = h >= 12 ? "PM" : "AM"
            h = h % 12 || 12
            root.clockText = h + ":" + (m < 10 ? "0" + m : m) + " " + root.ampm
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left: Apple logo + active window ─────────────────────────────

        Item { width: 8 }

        // Apple logo — click opens power menu
        Text {
            text: ""
            font.pixelSize: 16
            color: "#e0e0e0"
            leftPadding: 4
            rightPadding: 8

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["ags", "request", "toggle power-menu"])
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Active window title (max 35 chars)
        Text {
            text: {
                var t = bus.activeWindowTitle || "Desktop"
                return t.length > 35 ? t.substring(0, 32) + "…" : t
            }
            font.pixelSize: 13
            font.family: "Inter"
            color: "#e0e0e0"
            elide: Text.ElideRight
            Layout.preferredWidth: 160
        }

        // ── Menu bar items ────────────────────────────────────────────────

        Item { width: 12 }

        Repeater {
            model: ["File", "Edit", "View", "Window", "Help"]
            delegate: Item {
                width: menuLabel.implicitWidth + 16
                height: parent.height

                property bool hovered: false

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: parent.hovered ? Qt.rgba(1,1,1,0.12) : "transparent"
                }

                Text {
                    id: menuLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 13
                    font.family: "Inter"
                    color: "#e0e0e0"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.hovered = true
                    onExited:  parent.hovered = false
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // ── Spacer ────────────────────────────────────────────────────────

        Item { Layout.fillWidth: true }

        // ── System tray ──────────────────────────────────────────────────

        RowLayout {
            spacing: 6
            rightPadding: 8

            // Network icon
            Text {
                text: {
                    switch(bus.networkType) {
                        case "wifi":       return "󰤨"
                        case "ethernet":   return "󰈀"
                        default:           return "󰤭"
                    }
                }
                font.pixelSize: 14
                font.family: "Symbols Nerd Font"
                color: bus.networkType === "disconnected" ? "#ff453a" : "#e0e0e0"
                ToolTip.visible: networkHover.containsMouse
                ToolTip.text: bus.networkName || bus.networkType

                MouseArea { id: networkHover; anchors.fill: parent; hoverEnabled: true }
            }

            // Volume icon
            Text {
                text: {
                    if (bus.muted || bus.volume === 0) return "󰖁"
                    if (bus.volume < 33)  return "󰕿"
                    if (bus.volume < 66)  return "󰖀"
                    return "󰕾"
                }
                font.pixelSize: 14
                font.family: "Symbols Nerd Font"
                color: bus.muted ? "#ff453a" : "#e0e0e0"
                ToolTip.visible: volHover.containsMouse
                ToolTip.text: bus.muted ? "Muted" : bus.volume + "%"

                MouseArea { id: volHover; anchors.fill: parent; hoverEnabled: true }
            }

            // Battery (auto-hide when no battery)
            Text {
                visible: bus.hasBattery
                text: {
                    var c = bus.batteryCapacity
                    if (bus.batteryStatus === "Charging") return "󰂄 " + c + "%"
                    if (c >= 90) return "󰁹 " + c + "%"
                    if (c >= 70) return "󰂂 " + c + "%"
                    if (c >= 50) return "󰁾 " + c + "%"
                    if (c >= 30) return "󰁼 " + c + "%"
                    if (c >= 15) return "󰁺 " + c + "%"
                    return "󰂎 " + c + "%"
                }
                font.pixelSize: 13
                font.family: "Symbols Nerd Font"
                color: bus.batteryCapacity < 15 ? "#ff453a" : "#e0e0e0"
            }

            // Clock
            Text {
                text: root.clockText
                font.pixelSize: 13
                font.family: "Inter"
                color: "#e0e0e0"
            }

            // Control center toggle
            Text {
                text: "󰓓"
                font.pixelSize: 15
                font.family: "Symbols Nerd Font"
                color: "#e0e0e0"
                rightPadding: 4

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["ags", "request", "toggle control-center"])
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
