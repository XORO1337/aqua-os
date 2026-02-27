// AquaOS — Dock Content
// Magnification via cosine proximity; running indicators; bounce animation.

import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var bus   // EventBus instance

    // Track global mouse X for proximity magnification
    property real globalMouseX: 0

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPositionChanged: root.globalMouseX = mouseX
        onExited: root.globalMouseX = -9999
    }

    // ── Dock container ───────────────────────────────────────────────────

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 64

        // Glass pill background
        Rectangle {
            id: dockBg
            anchors { top: parent.top; bottom: parent.bottom; left: row.left; right: row.right }
            anchors.leftMargin:  -14
            anchors.rightMargin: -14
            radius: 18
            color: Qt.rgba(0.12, 0.12, 0.14, 0.55)
            border.width: 0.5
            border.color: Qt.rgba(1, 1, 1, 0.15)

            // Top highlight line
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.22)
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            // ── Pinned apps ───────────────────────────────────────────────

            ListModel {
                id: pinnedApps
                ListElement { name: "Finder";   icon: "system-file-manager"; appClass: "org.gnome.Nautilus"; cmd: "nautilus" }
                ListElement { name: "Ghostty";  icon: "com.mitchellh.ghostty"; appClass: "ghostty";           cmd: "ghostty" }
                ListElement { name: "Kitty";    icon: "kitty";                 appClass: "kitty";             cmd: "kitty" }
                ListElement { name: "Firefox";  icon: "firefox";               appClass: "firefox";           cmd: "firefox" }
                ListElement { name: "Code";     icon: "code";                  appClass: "code";              cmd: "code" }
                ListElement { name: "Spotify";  icon: "spotify";               appClass: "spotify";           cmd: "spotify" }
                ListElement { name: "Discord";  icon: "discord";               appClass: "discord";           cmd: "discord" }
                ListElement { name: "Obsidian"; icon: "obsidian";              appClass: "obsidian";          cmd: "obsidian" }
                ListElement { name: "Settings"; icon: "gnome-control-center";  appClass: "gnome-control-center"; cmd: "gnome-control-center" }
            }

            Repeater {
                model: pinnedApps
                delegate: DockItem {
                    required property var modelData
                    itemName:   modelData.name
                    itemIcon:   modelData.icon
                    itemClass:  modelData.appClass
                    itemCmd:    modelData.cmd
                    bus:        root.bus
                    dockMouseX: root.globalMouseX
                    dockX:      x + row.x + dockBg.x
                }
            }

            // Separator
            Rectangle {
                width: 1
                height: 40
                color: Qt.rgba(1, 1, 1, 0.18)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Downloads stack
            DownloadsStack { bus: root.bus }

            // Separator
            Rectangle {
                width: 1
                height: 40
                color: Qt.rgba(1, 1, 1, 0.18)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Trash
            DockItem {
                itemName:   "Trash"
                itemIcon:   "user-trash"
                itemClass:  "trash"
                itemCmd:    "nautilus trash://"
                bus:        root.bus
                dockMouseX: root.globalMouseX
                dockX:      x + row.x + dockBg.x
            }
        }
    }

    // ── DockItem component ────────────────────────────────────────────────

    component DockItem: Item {
        id: item
        required property string itemName
        required property string itemIcon
        required property string itemClass
        required property string itemCmd
        required property var    bus
        required property real   dockMouseX
        required property real   dockX

        property bool isHovered: false

        // Cosine magnification: base 44, max 62
        property real distToCenter: Math.abs(dockMouseX - (dockX + width / 2))
        property real magnetRadius: 80
        property real iconSize: {
            if (dockMouseX < 0) return 44
            var t = Math.max(0, 1 - distToCenter / magnetRadius)
            return 44 + 18 * Math.cos((1 - t) * Math.PI * 0.5)
        }

        width: 52
        height: 64

        // Bounce animation on click
        SequentialAnimation {
            id: bounceAnim
            NumberAnimation { target: iconImg; property: "anchors.bottomMargin"; to: 14; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconImg; property: "anchors.bottomMargin"; to: 2;  duration: 200; easing.type: Easing.OutBounce }
        }

        Image {
            id: iconImg
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
            width:  item.iconSize
            height: item.iconSize
            source: "image://icon/" + item.itemIcon
            smooth: true
            Behavior on width  { NumberAnimation { duration: 80 } }
            Behavior on height { NumberAnimation { duration: 80 } }
        }

        // Running indicator dot
        Rectangle {
            visible: item.bus.isAppRunning(item.itemClass)
            anchors { bottom: parent.bottom; bottomMargin: 0; horizontalCenter: parent.horizontalCenter }
            width: 4; height: 4; radius: 2
            color: "#0a84ff"
        }

        // Tooltip
        Rectangle {
            visible: item.isHovered
            anchors { bottom: parent.top; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
            width: tipText.implicitWidth + 16
            height: 22
            radius: 6
            color: Qt.rgba(0.1, 0.1, 0.12, 0.9)
            border.width: 0.5
            border.color: Qt.rgba(1, 1, 1, 0.2)
            z: 100

            Text {
                id: tipText
                anchors.centerIn: parent
                text: item.itemName
                font.pixelSize: 12
                font.family: "Inter"
                color: "#e0e0e0"
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: item.isHovered = true
            onExited:  item.isHovered = false
            onClicked: {
                bounceAnim.start()
                Quickshell.execDetached(item.itemCmd.split(" "))
            }
            cursorShape: Qt.PointingHandCursor
        }
    }
}
