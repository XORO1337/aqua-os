// AquaOS — Notification Center Widget
import GLib from "gi://GLib"
import AstalNotifd from "gi://AstalNotifd"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

const notifd = AstalNotifd.get_default()

const visible = Variable(false)

export function toggleNotificationCenter() {
    visible.set(!visible.get())
}

function timeAgo(time: number): string {
    const now = Math.floor(Date.now() / 1000)
    const diff = now - time
    if (diff < 60)    return "just now"
    if (diff < 3600)  return `${Math.floor(diff / 60)}m ago`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
    return `${Math.floor(diff / 86400)}d ago`
}

function NotificationItem(n: AstalNotifd.Notification) {
    return (
        <box cssClasses={["notification-item"]} orientation={Gtk.Orientation.HORIZONTAL} spacing={8}>
            {n.app_icon ? (
                <image
                    cssClasses={["app-icon"]}
                    iconName={n.app_icon}
                    pixelSize={32}
                />
            ) : (
                <image
                    cssClasses={["app-icon"]}
                    iconName={"dialog-information"}
                    pixelSize={32}
                />
            )}
            <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
                <box orientation={Gtk.Orientation.HORIZONTAL}>
                    <label
                        cssClasses={["summary"]}
                        label={n.summary || n.app_name}
                        hexpand
                        xalign={0}
                        ellipsize={3}
                    />
                    <label
                        cssClasses={["time-label"]}
                        label={timeAgo(n.time)}
                    />
                </box>
                {n.body ? (
                    <label
                        cssClasses={["body"]}
                        label={n.body}
                        xalign={0}
                        ellipsize={3}
                        maxWidthChars={42}
                    />
                ) : null}
            </box>
            <button
                cssClasses={["dismiss-btn"]}
                label={"✕"}
                onClicked={() => n.dismiss()}
            />
        </box>
    )
}

export default function NotificationCenter(monitor: Gdk.Monitor) {
    return (
        <window
            cssClasses={["notification-center"]}
            application={App}
            monitor={monitor}
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            margin={8}
            layer={Astal.Layer.OVERLAY}
            visible={visible()}
            keymode={Astal.Keymode.ON_DEMAND}
            onKeyPressed={(_, key) => {
                if (key === Gdk.KEY_Escape) visible.set(false)
            }}
        >
            <box cssClasses={["notification-center"]} orientation={Gtk.Orientation.VERTICAL} spacing={0}>
                {/* Header */}
                <box orientation={Gtk.Orientation.HORIZONTAL} cssClasses={["header"]}>
                    <label label={"Notifications"} hexpand xalign={0} />
                    <button
                        cssClasses={["clear-btn"]}
                        label={"Clear All"}
                        onClicked={() => {
                            for (const n of notifd.get_notifications()) {
                                n.dismiss()
                            }
                        }}
                    />
                </box>

                {/* Notification list */}
                <scrolledwindow cssClasses={["notification-list"]} vexpand maxContentHeight={480}>
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
                        {notifd.notifications.map(n => NotificationItem(n))}
                        {notifd.notifications.length === 0 ? (
                            <label cssClasses={["empty-state"]} label={"No notifications"} />
                        ) : null}
                    </box>
                </scrolledwindow>
            </box>
        </window>
    )
}
