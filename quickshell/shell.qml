// AquaOS — Quickshell Shell Root
pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    EventBus { id: eventBus }

    // ── Top Bar (one per screen) ───────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: topBarWindow
            required property var modelData

            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 32
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell"
            WlrLayershell.exclusiveZone: 32

            TopBarContent {
                anchors.fill: parent
                bus: eventBus
            }
        }
    }

    // ── Dock (one per screen) ─────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow
            required property var modelData

            screen: modelData
            anchors { bottom: true; left: true; right: true }
            implicitHeight: 80
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell"
            WlrLayershell.exclusiveZone: 80

            DockContent {
                anchors.fill: parent
                bus: eventBus
            }
        }
    }
}
