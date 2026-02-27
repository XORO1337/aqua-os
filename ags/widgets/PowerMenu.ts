// AquaOS — Power Menu Widget
// Full-screen scrim, 5 actions, two-click confirmation, keyboard navigation.
import GLib from "gi://GLib"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable, execAsync } from "astal"

const visible  = Variable(false)
const confirm  = Variable<string | null>(null)
const focused  = Variable(0)

export function togglePowerMenu() {
    visible.set(!visible.get())
    confirm.set(null)
    focused.set(0)
}

interface Action {
    id:       string
    icon:     string
    label:    string
    sublabel: string
    color:    string
    exec:     () => void
}

const ACTIONS: Action[] = [
    {
        id:       "lock",
        icon:     "󰌾",
        label:    "Lock",
        sublabel: "hyprlock",
        color:    "#4a9eff",
        exec:     () => execAsync(["hyprlock"]).catch(() => {}),
    },
    {
        id:       "logout",
        icon:     "󰍃",
        label:    "Log Out",
        sublabel: "End session",
        color:    "#30d158",
        exec:     () => execAsync(["hyprctl", "dispatch", "exit"]).catch(() => {}),
    },
    {
        id:       "sleep",
        icon:     "󰒲",
        label:    "Sleep",
        sublabel: "Suspend",
        color:    "#5ac8fa",
        exec:     () => execAsync(["systemctl", "suspend"]).catch(() => {}),
    },
    {
        id:       "restart",
        icon:     "󰑓",
        label:    "Restart",
        sublabel: "Reboot",
        color:    "#ffd60a",
        exec:     () => execAsync(["systemctl", "reboot"]).catch(() => {}),
    },
    {
        id:       "shutdown",
        icon:     "󰐥",
        label:    "Shut Down",
        sublabel: "Power off",
        color:    "#ff453a",
        exec:     () => execAsync(["systemctl", "poweroff"]).catch(() => {}),
    },
]

function PowerButton(action: Action, idx: number) {
    return (
        <button
            cssClasses={confirm(c =>
                c === action.id ? ["power-button", "confirm"]
                : focused(f => f === idx ? ["power-button", "selected"] : ["power-button"])
            )}
            onClicked={() => {
                if (confirm.get() === action.id) {
                    visible.set(false)
                    action.exec()
                    confirm.set(null)
                } else {
                    confirm.set(action.id)
                }
            }}
        >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4} halign={Gtk.Align.CENTER}>
                <box
                    cssClasses={["power-icon-container"]}
                    halign={Gtk.Align.CENTER}
                    // Inline style approximation via CSS color var
                >
                    <label cssClasses={["power-icon"]} label={action.icon} />
                </box>
                <label cssClasses={["power-label"]} label={
                    confirm(c => c === action.id ? "Click to confirm" : action.label)
                } />
            </box>
        </button>
    )
}

export default function PowerMenu(monitor: Gdk.Monitor) {
    return (
        <window
            cssClasses={["power-menu-scrim"]}
            application={App}
            monitor={monitor}
            anchor={
                Astal.WindowAnchor.TOP |
                Astal.WindowAnchor.BOTTOM |
                Astal.WindowAnchor.LEFT |
                Astal.WindowAnchor.RIGHT
            }
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.IGNORE}
            visible={visible()}
            keymode={Astal.Keymode.EXCLUSIVE}
            onKeyPressed={(_, key) => {
                const cur = focused.get()
                switch (key) {
                    case Gdk.KEY_Escape:
                        if (confirm.get()) {
                            confirm.set(null)
                        } else {
                            visible.set(false)
                        }
                        break
                    case Gdk.KEY_Left:
                        focused.set(Math.max(0, cur - 1))
                        break
                    case Gdk.KEY_Right:
                        focused.set(Math.min(ACTIONS.length - 1, cur + 1))
                        break
                    case Gdk.KEY_Return:
                    case Gdk.KEY_space: {
                        const action = ACTIONS[cur]
                        if (action) {
                            if (confirm.get() === action.id) {
                                visible.set(false)
                                action.exec()
                                confirm.set(null)
                            } else {
                                confirm.set(action.id)
                            }
                        }
                        break
                    }
                }
            }}
            onButtonPressed={() => {
                confirm.set(null)
                visible.set(false)
            }}
        >
            <box
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                onButtonPressed={(_, event) => {
                    // Prevent scrim click from closing when clicking inside
                    event.get_event()
                }}
            >
                <box cssClasses={["power-menu-container"]} orientation={Gtk.Orientation.VERTICAL} spacing={20}>
                    <label cssClasses={["power-menu-title"]} label={"  AquaOS"} xalign={0} />
                    <box orientation={Gtk.Orientation.HORIZONTAL} spacing={12} homogeneous>
                        {ACTIONS.map((a, i) => PowerButton(a, i))}
                    </box>
                </box>
            </box>
        </window>
    )
}
