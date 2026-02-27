// AquaOS — Launcher / Spotlight Widget
import AstalApps from "gi://AstalApps"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

const apps = AstalApps.Apps.new()

const visible = Variable(false)

export function toggleLauncher() {
    visible.set(!visible.get())
}

export default function Launcher(monitor: Gdk.Monitor) {
    const query    = Variable("")
    const selected = Variable(0)

    const results = query.derive(q => {
        if (!q.trim()) return apps.list.slice(0, 8)
        return apps.fuzzy_query(q).slice(0, 8)
    })

    function launchSelected() {
        const list = results.get()
        const idx  = selected.get()
        if (list[idx]) {
            list[idx].launch()
            visible.set(false)
            query.set("")
            selected.set(0)
        }
    }

    return (
        <window
            cssClasses={["launcher"]}
            application={App}
            monitor={monitor}
            anchor={Astal.WindowAnchor.TOP}
            marginTop={80}
            layer={Astal.Layer.OVERLAY}
            visible={visible()}
            keymode={Astal.Keymode.EXCLUSIVE}
            onKeyPressed={(_, key) => {
                const list = results.get()
                const cur  = selected.get()
                switch (key) {
                    case Gdk.KEY_Escape:
                        visible.set(false)
                        query.set("")
                        selected.set(0)
                        break
                    case Gdk.KEY_Return:
                        launchSelected()
                        break
                    case Gdk.KEY_Up:
                        selected.set(Math.max(0, cur - 1))
                        break
                    case Gdk.KEY_Down:
                        selected.set(Math.min(list.length - 1, cur + 1))
                        break
                }
            }}
        >
            <box cssClasses={["launcher"]} orientation={Gtk.Orientation.VERTICAL} spacing={8}>

                {/* Search row */}
                <overlay>
                    <entry
                        cssClasses={["search-entry"]}
                        placeholderText={"Spotlight Search"}
                        hexpand
                        text={query()}
                        onChanged={(self) => {
                            query.set(self.text)
                            selected.set(0)
                        }}
                        onActivate={() => launchSelected()}
                    />
                    <label
                        cssClasses={["search-icon"]}
                        label={"󰍉"}
                        halign={Gtk.Align.START}
                        marginStart={10}
                    />
                </overlay>

                <separator />

                {/* Results */}
                <box cssClasses={["results-list"]} orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                    {results(list =>
                        list.length === 0 ? (
                            <label cssClasses={["empty-state"]} label={"No results"} />
                        ) : (
                            list.map((app, i) => (
                                <button
                                    cssClasses={selected(s => s === i ? ["result-item", "selected"] : ["result-item"])}
                                    onClicked={() => {
                                        selected.set(i)
                                        launchSelected()
                                    }}
                                >
                                    <box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
                                        <image
                                            iconName={app.icon_name || "application-x-executable"}
                                            pixelSize={32}
                                        />
                                        <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                                            <label
                                                cssClasses={["result-name"]}
                                                label={app.name}
                                                xalign={0}
                                            />
                                            {app.description ? (
                                                <label
                                                    cssClasses={["result-desc"]}
                                                    label={app.description}
                                                    xalign={0}
                                                    ellipsize={3}
                                                    maxWidthChars={50}
                                                />
                                            ) : null}
                                        </box>
                                    </box>
                                </button>
                            ))
                        )
                    )}
                </box>
            </box>
        </window>
    )
}
