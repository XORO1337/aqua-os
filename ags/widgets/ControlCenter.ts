// AquaOS — Control Center Widget
import GLib from "gi://GLib"
import AstalWp from "gi://AstalWp"
import AstalNetwork from "gi://AstalNetwork"
import AstalBluetooth from "gi://AstalBluetooth"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable, exec, execAsync } from "astal"

const visible = Variable(false)

export function toggleControlCenter() {
    visible.set(!visible.get())
}

function getVolume(): number {
    const wp = AstalWp.get_default()
    return wp ? Math.round((wp.default_speaker?.volume ?? 0) * 100) : 0
}

function getBrightness(): number {
    try {
        const result = exec("brightnessctl -m get").trim().split(",")
        if (result.length >= 4) {
            const pct = result[3].replace("%", "")
            const val = parseInt(pct)
            if (!isNaN(val)) return val
        }
        console.warn("ControlCenter: brightnessctl returned unexpected output, defaulting to 50")
    } catch (e) {
        console.warn("ControlCenter: brightnessctl not available:", e)
    }
    return 50
}

export default function ControlCenter(monitor: Gdk.Monitor) {
    const wp        = AstalWp.get_default()
    const speaker   = wp?.default_speaker
    const network   = AstalNetwork.get_default()
    const bluetooth = AstalBluetooth.get_default()

    const volume     = Variable(getVolume())
    const brightness = Variable(getBrightness())
    const wifiOn     = Variable(network?.wifi?.enabled ?? false)
    const btOn       = Variable(bluetooth?.is_powered ?? false)
    const dnd        = Variable(false)
    const darkMode   = Variable(true)

    // Keep volume in sync with PipeWire
    if (speaker) {
        speaker.connect("notify::volume", () => {
            volume.set(Math.round(speaker.volume * 100))
        })
    }

    return (
        <window
            cssClasses={["control-center"]}
            application={App}
            monitor={monitor}
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            margin={8}
            marginTop={40}
            layer={Astal.Layer.OVERLAY}
            visible={visible()}
            keymode={Astal.Keymode.ON_DEMAND}
            onKeyPressed={(_, key) => {
                if (key === Gdk.KEY_Escape) visible.set(false)
            }}
        >
            <box cssClasses={["control-center"]} orientation={Gtk.Orientation.VERTICAL} spacing={12}>

                {/* Toggle row */}
                <label cssClasses={["section-label"]} label={"CONTROLS"} xalign={0} />
                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={8}>
                    {/* Wi-Fi */}
                    <button
                        cssClasses={wifiOn(on => on ? ["toggle-button", "active"] : ["toggle-button"])}
                        onClicked={() => {
                            const next = !wifiOn.get()
                            wifiOn.set(next)
                            execAsync(["nmcli", "radio", "wifi", next ? "on" : "off"]).catch(() => {})
                        }}
                    >
                        <box spacing={6}>
                            <label label={"󰤨"} />
                            <label label={wifiOn(on => on ? "Wi-Fi" : "Wi-Fi Off")} />
                        </box>
                    </button>

                    {/* Bluetooth */}
                    <button
                        cssClasses={btOn(on => on ? ["toggle-button", "active"] : ["toggle-button"])}
                        onClicked={() => {
                            const next = !btOn.get()
                            btOn.set(next)
                            execAsync(["bluetoothctl", next ? "power on" : "power off"]).catch(() => {})
                        }}
                    >
                        <box spacing={6}>
                            <label label={""} />
                            <label label={"Bluetooth"} />
                        </box>
                    </button>
                </box>

                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={8}>
                    {/* DND */}
                    <button
                        cssClasses={dnd(on => on ? ["toggle-button", "active"] : ["toggle-button"])}
                        onClicked={() => dnd.set(!dnd.get())}
                    >
                        <box spacing={6}>
                            <label label={"󰂛"} />
                            <label label={"Do Not Disturb"} />
                        </box>
                    </button>

                    {/* Dark Mode */}
                    <button
                        cssClasses={darkMode(on => on ? ["toggle-button", "active"] : ["toggle-button"])}
                        onClicked={() => {
                            const next = !darkMode.get()
                            darkMode.set(next)
                            execAsync([
                                "gsettings", "set", "org.gnome.desktop.interface",
                                "color-scheme", next ? "prefer-dark" : "default"
                            ]).catch(() => {})
                        }}
                    >
                        <box spacing={6}>
                            <label label={"󰌕"} />
                            <label label={"Dark Mode"} />
                        </box>
                    </button>
                </box>

                {/* Volume slider */}
                <label cssClasses={["section-label"]} label={"VOLUME"} xalign={0} />
                <box cssClasses={["slider-container"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={8}>
                    <label label={volume(v => v === 0 ? "󰖁" : v < 33 ? "󰕿" : v < 66 ? "󰖀" : "󰕾")} />
                    <slider
                        cssClasses={["osd-bar"]}
                        hexpand
                        value={volume(v => v / 100)}
                        min={0}
                        max={1}
                        onValueChanged={(self) => {
                            const val = Math.round(self.value * 100)
                            volume.set(val)
                            if (speaker) speaker.volume = self.value
                        }}
                    />
                    <label label={volume(v => `${v}%`)} cssClasses={["osd-percent"]} />
                </box>

                {/* Brightness slider */}
                <label cssClasses={["section-label"]} label={"BRIGHTNESS"} xalign={0} />
                <box cssClasses={["slider-container"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={8}>
                    <label label={"󰃞"} />
                    <slider
                        cssClasses={["osd-bar"]}
                        hexpand
                        value={brightness(b => b / 100)}
                        min={0}
                        max={1}
                        onValueChanged={(self) => {
                            const val = Math.round(self.value * 100)
                            brightness.set(val)
                            execAsync(["brightnessctl", "set", `${val}%`]).catch(() => {})
                        }}
                    />
                    <label label={brightness(b => `${b}%`)} cssClasses={["osd-percent"]} />
                </box>
            </box>
        </window>
    )
}
