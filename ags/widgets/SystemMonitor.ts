// AquaOS — System Monitor Widget
// Reads /proc/stat, /proc/meminfo, /proc/mounts, /sys thermal — no forks.
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

function readFile(path: string): string {
    try {
        const [, bytes] = GLib.file_get_contents(path)
        return new TextDecoder().decode(bytes)
    } catch (_) { return "" }
}

// CPU: read /proc/stat twice, compute delta
let prevIdle = 0, prevTotal = 0

function getCpu(): number {
    const line = readFile("/proc/stat").split("\n")[0]
    const parts = line.trim().split(/\s+/).slice(1).map(Number)
    const idle  = parts[3] + (parts[4] || 0)
    const total = parts.reduce((a, b) => a + b, 0)
    const dIdle  = idle  - prevIdle
    const dTotal = total - prevTotal
    prevIdle  = idle
    prevTotal = total
    if (dTotal === 0) return 0
    return Math.round((1 - dIdle / dTotal) * 100)
}

function getRam(): number {
    const text  = readFile("/proc/meminfo")
    const parse = (key: string) => {
        const m = text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))
        return m ? parseInt(m[1]) : 0
    }
    const total   = parse("MemTotal")
    const free    = parse("MemFree")
    const buffers = parse("Buffers")
    const cached  = parse("Cached")
    if (total === 0) return 0
    return Math.round(((total - free - buffers - cached) / total) * 100)
}

function getDisk(): number {
    try {
        const info = Gio.File.new_for_path("/").query_filesystem_info("filesystem::*", null)
        const total = info.get_attribute_uint64("filesystem::size")
        const free  = info.get_attribute_uint64("filesystem::free")
        if (total === 0) return 0
        return Math.round(((total - free) / total) * 100)
    } catch (_) { return 0 }
}

function getTemp(): number {
    const text = readFile("/sys/class/thermal/thermal_zone0/temp")
    return text ? Math.round(parseInt(text.trim()) / 1000) : 0
}

interface MetricCardProps {
    icon:  string
    value: number
    label: string
    unit:  string
    cls:   string
}

function MetricCard(props: MetricCardProps) {
    return (
        <box cssClasses={["widget-card", props.cls]} orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
            <label cssClasses={["metric-icon"]} label={props.icon} />
            <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                <label
                    cssClasses={["metric-value"]}
                    label={`${props.value}${props.unit}`}
                    xalign={0}
                />
                <label cssClasses={["metric-label"]} label={props.label} xalign={0} />
            </box>
        </box>
    )
}

export default function SystemMonitor(monitor: Gdk.Monitor) {
    const cpu  = Variable(0)
    const ram  = Variable(0)
    const disk = Variable(0)
    const temp = Variable(0)

    const activeTimers: number[] = []

    const timerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
        cpu.set(getCpu())
        ram.set(getRam())
        disk.set(getDisk())
        temp.set(getTemp())
        return GLib.SOURCE_CONTINUE
    })
    activeTimers.push(timerId)

    // Initial read
    cpu.set(getCpu())
    ram.set(getRam())
    disk.set(getDisk())
    temp.set(getTemp())

    const win = (
        <window
            cssClasses={["system-monitor"]}
            application={App}
            monitor={monitor}
            anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            margin={8}
            marginBottom={88}
            layer={Astal.Layer.OVERLAY}
            visible={false}
            onDestroy={() => {
                for (const id of activeTimers) GLib.source_remove(id)
            }}
        >
            <box cssClasses={["system-monitor"]} orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                <label
                    label={"System Monitor"}
                    cssClasses={["section-label"]}
                    xalign={0}
                />
                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={8} homogeneous>
                    {cpu(v  => MetricCard({ icon: "󰻠", value: v,  label: "CPU",  unit: "%", cls: "cpu"  }))}
                    {ram(v  => MetricCard({ icon: "󰍛", value: v,  label: "RAM",  unit: "%", cls: "ram"  }))}
                </box>
                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={8} homogeneous>
                    {disk(v => MetricCard({ icon: "󰋊", value: v,  label: "Disk", unit: "%", cls: "disk" }))}
                    {temp(v => MetricCard({ icon: "󰔏", value: v,  label: "Temp", unit: "°", cls: "temp" }))}
                </box>
            </box>
        </window>
    ) as Gtk.Window

    return win
}
