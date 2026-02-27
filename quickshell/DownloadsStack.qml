// AquaOS — Downloads Stack
// Shows recent downloads with file-type emoji, badge count, and a popup grid.

import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var bus   // EventBus instance

    width: 52
    height: 64

    property bool stackOpen: false

    // ── Downloads icon + badge ────────────────────────────────────────────

    Item {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
        width: 44; height: 44

        Image {
            anchors.fill: parent
            source: "image://icon/folder-downloads"
            smooth: true
        }

        // Badge count
        Rectangle {
            visible: bus.downloadCount > 0
            anchors { top: parent.top; right: parent.right; topMargin: -4; rightMargin: -4 }
            width: Math.max(18, badgeText.implicitWidth + 8)
            height: 18
            radius: 9
            color: "#ff453a"

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: bus.downloadCount > 99 ? "99+" : bus.downloadCount.toString()
                font.pixelSize: 10
                font.bold: true
                font.family: "Inter"
                color: "white"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.stackOpen = !root.stackOpen
    }

    // ── Popup grid ────────────────────────────────────────────────────────

    Rectangle {
        id: popup
        visible: root.stackOpen
        anchors { bottom: parent.top; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
        width: 220
        height: contentCol.implicitHeight + 16
        radius: 14
        color: Qt.rgba(0.10, 0.10, 0.12, 0.92)
        border.width: 0.5
        border.color: Qt.rgba(1, 1, 1, 0.15)
        z: 200

        // Arrow pointer
        Canvas {
            anchors { top: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 16; height: 8
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = Qt.rgba(0.10, 0.10, 0.12, 0.92)
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(8, 8)
                ctx.lineTo(16, 0)
                ctx.closePath()
                ctx.fill()
            }
        }

        // Entrance animation
        scale: root.stackOpen ? 1.0 : 0.85
        opacity: root.stackOpen ? 1.0 : 0.0

        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Column {
            id: contentCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            spacing: 6

            // File grid
            Grid {
                columns: 3
                spacing: 4
                width: parent.width

                Repeater {
                    model: bus.recentDownloads

                    delegate: Rectangle {
                        required property string modelData
                        width: (contentCol.width - 8) / 3
                        height: 56
                        radius: 8
                        color: fileHover.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: getFileEmoji(modelData)
                                font.pixelSize: 22
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    var n = modelData
                                    return n.length > 10 ? n.substring(0, 9) + "…" : n
                                }
                                font.pixelSize: 9
                                font.family: "Inter"
                                color: "#c0c0c0"
                            }
                        }

                        MouseArea {
                            id: fileHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Downloads/" + modelData])
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: bus.recentDownloads.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No recent downloads"
                font.pixelSize: 12
                font.family: "Inter"
                color: "#808080"
                topPadding: 8
                bottomPadding: 8
            }

            // "Open in Finder" button
            Rectangle {
                width: parent.width
                height: 28
                radius: 8
                color: finderHover.containsMouse ? Qt.rgba(0.04, 0.52, 1.0, 0.3) : Qt.rgba(0.04, 0.52, 1.0, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: "Open in Finder"
                    font.pixelSize: 12
                    font.family: "Inter"
                    color: "#0a84ff"
                }

                MouseArea {
                    id: finderHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.stackOpen = false
                        Quickshell.execDetached(["nautilus", Quickshell.env("HOME") + "/Downloads"])
                    }
                }
            }
        }
    }

    // ── File emoji mapping ────────────────────────────────────────────────

    function getFileEmoji(filename) {
        if (!filename) return "📄"
        var ext = filename.split(".").pop().toLowerCase()
        var map = {
            // Documents
            "pdf": "📕", "doc": "📝", "docx": "📝", "odt": "📝",
            "xls": "📊", "xlsx": "📊", "ods": "📊", "csv": "📊",
            "ppt": "📽", "pptx": "📽", "odp": "📽",
            "txt": "📄", "md": "📄", "rtf": "📄",
            // Archives
            "zip": "🗜", "tar": "🗜", "gz": "🗜", "bz2": "🗜",
            "7z": "🗜", "rar": "🗜", "xz": "🗜",
            // Images
            "jpg": "🖼", "jpeg": "🖼", "png": "🖼", "gif": "🎞",
            "svg": "🎨", "webp": "🖼", "bmp": "🖼", "ico": "🖼",
            "tiff": "🖼", "raw": "📷",
            // Video
            "mp4": "🎬", "mkv": "🎬", "mov": "🎬", "avi": "🎬",
            "webm": "🎬", "flv": "🎬", "wmv": "🎬",
            // Audio
            "mp3": "🎵", "flac": "🎵", "wav": "🎵", "ogg": "🎵",
            "aac": "🎵", "opus": "🎵", "m4a": "🎵",
            // Code
            "js": "⚡", "ts": "⚡", "py": "🐍", "rs": "🦀",
            "go": "🐹", "java": "☕", "c": "⚙", "cpp": "⚙",
            "sh": "🔧", "bash": "🔧", "zsh": "🔧",
            // Packages
            "deb": "📦", "rpm": "📦", "pkg": "📦", "dmg": "💿",
            "iso": "💿", "appimage": "📦",
            // Font
            "ttf": "🔤", "otf": "🔤", "woff": "🔤", "woff2": "🔤",
        }
        return map[ext] || "📄"
    }
}
