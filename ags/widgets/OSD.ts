// AquaOS — On-Screen Display (OSD)
// Volume + brightness with signal-driven updates and proper timer cleanup.
import GLib from "gi://GLib"
import AstalWp from "gi://AstalWp"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

function findBacklightPath(): string | null {
    try {
        const dir = GLib.Dir.open("/sys/class/backlight", 0)
        let name: string | null
        while ((name = dir.read_name()) !== null) {
            if (name && name !== "." && name !== "..") {
                return `/sys/class/backlight/${name}/brightness`
            }
        }
    } catch (_) {}
    return null
}

function readSysfs(path: string): number {
    try {
        const [, bytes] = GLib.file_get_contents(path)
        return parseInt(new TextDecoder().decode(bytes).trim()) || 0
    } catch (_) { return 0 }
}

export default function OSD(monitor: Gdk.Monitor) {
    const icon    = Variable("󰕾")
    const value   = Variable(0)
    const label   = Variable("")
    const visible = Variable(false)

    const activeTimers: number[] = []
    let hideTimer: number | null = null

    function showOSD(ic: string, val: number, lbl: string) {
        icon.set(ic)
        value.set(val)
        label.set(lbl)
        visible.set(true)

        if (hideTimer !== null) {
            GLib.source_remove(hideTimer)
            const idx = activeTimers.indexOf(hideTimer)
            if (idx !== -1) activeTimers.splice(idx, 1)
            hideTimer = null
        }

        hideTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
            visible.set(false)
            hideTimer = null
            return GLib.SOURCE_REMOVE
        })
        activeTimers.push(hideTimer)
    }

    // ── Volume: signal-driven via AstalWp ────────────────────────────────

    const wp = AstalWp.get_default()
    const speaker = wp?.default_speaker

    if (speaker) {
        speaker.connect("notify::volume", () => {
            const vol = Math.round(speaker.volume * 100)
            const ic  = speaker.mute ? "󰖁" : vol < 33 ? "󰕿" : vol < 66 ? "󰖀" : "󰕾"
            showOSD(ic, vol, speaker.mute ? "Muted" : "Volume")
        })
        speaker.connect("notify::mute", () => {
            const vol = Math.round(speaker.volume * 100)
            showOSD(speaker.mute ? "󰖁" : "󰕾", vol, speaker.mute ? "Muted" : "Volume")
        })
    }

    // ── Brightness: low-priority sysfs poll (no fork) ─────────────────────

    const backlightPath = findBacklightPath()
    let prevBrightness  = -1

    if (backlightPath) {
        const maxPath = backlightPath.replace("/brightness", "/max_brightness")
        const maxBrt  = readSysfs(maxPath) || 100

        const brtTimer = GLib.timeout_add(GLib.PRIORITY_LOW, 2000, () => {
            const cur = readSysfs(backlightPath)
            const pct = Math.round((cur / maxBrt) * 100)
            if (pct !== prevBrightness) {
                prevBrightness = pct
                const bic = pct < 33 ? "󰃞" : pct < 66 ? "󰃟" : "󰃠"
                showOSD(bic, pct, "Brightness")
            }
            return GLib.SOURCE_CONTINUE
        })
        activeTimers.push(brtTimer)
    }

    return (
        <window
            cssClasses={["osd-container"]}
            application={App}
            monitor={monitor}
            anchor={Astal.WindowAnchor.BOTTOM}
            marginBottom={96}
            layer={Astal.Layer.OVERLAY}
            visible={visible()}
            onDestroy={() => {
                for (const id of activeTimers) GLib.source_remove(id)
            }}
        >
            <box cssClasses={["osd-container"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
                <label cssClasses={["osd-icon"]} label={icon()} />
                <box orientation={Gtk.Orientation.VERTICAL} spacing={4} hexpand>
                    <label cssClasses={["osd-label"]} label={label()} xalign={0} />
                    <slider
                        cssClasses={["osd-bar"]}
                        value={value(v => v / 100)}
                        min={0} max={1}
                        sensitive={false}
                        hexpand
                    />
                </box>
                <label cssClasses={["osd-percent"]} label={value(v => `${v}%`)} />
            </box>
        </window>
    )
}
