// AquaOS — Media Player Widget
// Uses AstalMpris; position update tracked and cleaned up on destroy.
import GLib from "gi://GLib"
import AstalMpris from "gi://AstalMpris"
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

function formatTime(seconds: number): string {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, "0")}`
}

function PlayerCard(player: AstalMpris.Player, activeTimers: number[]) {
    const position = Variable(player.position)

    const posTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        position.set(player.position)
        return GLib.SOURCE_CONTINUE
    })
    activeTimers.push(posTimer)

    return (
        <box cssClasses={["media-player-container"]} orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            {/* Top row: art + info */}
            <box orientation={Gtk.Orientation.HORIZONTAL} spacing={12}>
                {player.coverArt ? (
                    <image
                        cssClasses={["album-art"]}
                        file={player.coverArt}
                        pixelSize={64}
                    />
                ) : (
                    <box cssClasses={["album-art"]} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                        <label label={"󰎇"} />
                    </box>
                )}
                <box orientation={Gtk.Orientation.VERTICAL} spacing={3} vexpand valign={Gtk.Align.CENTER}>
                    <label
                        cssClasses={["track-title"]}
                        label={player.title || "Unknown Title"}
                        xalign={0}
                        ellipsize={3}
                        maxWidthChars={28}
                    />
                    <label
                        cssClasses={["track-artist"]}
                        label={player.artist || "Unknown Artist"}
                        xalign={0}
                        ellipsize={3}
                        maxWidthChars={28}
                    />
                    <label
                        cssClasses={["track-album"]}
                        label={player.album || ""}
                        xalign={0}
                        ellipsize={3}
                        maxWidthChars={28}
                    />
                </box>
            </box>

            {/* Progress */}
            <box orientation={Gtk.Orientation.HORIZONTAL} spacing={6}>
                <label
                    cssClasses={["time-label"]}
                    label={position(p => formatTime(p))}
                    xalign={0}
                />
                <slider
                    cssClasses={["progress-bar"]}
                    hexpand
                    value={position(p => player.length > 0 ? p / player.length : 0)}
                    min={0} max={1}
                    onValueChanged={(self) => {
                        player.position = self.value * player.length
                    }}
                />
                <label
                    cssClasses={["time-label"]}
                    label={formatTime(player.length)}
                    xalign={1}
                />
            </box>

            {/* Controls */}
            <box orientation={Gtk.Orientation.HORIZONTAL} spacing={8} halign={Gtk.Align.CENTER}>
                <button
                    cssClasses={["media-btn"]}
                    label={"󰒮"}
                    onClicked={() => player.previous()}
                    sensitive={player.canGoPrevious}
                />
                <button
                    cssClasses={["play-btn"]}
                    label={player.playbackStatus === AstalMpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"}
                    onClicked={() => player.play_pause()}
                    sensitive={player.canControl}
                />
                <button
                    cssClasses={["media-btn"]}
                    label={"󰒭"}
                    onClicked={() => player.next()}
                    sensitive={player.canGoNext}
                />
            </box>
        </box>
    )
}

export default function MediaPlayer(monitor: Gdk.Monitor) {
    const mpris = AstalMpris.get_default()
    const activeTimers: number[] = []

    return (
        <window
            cssClasses={["media-player-container"]}
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
            <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                {mpris.players.length === 0 ? (
                    <label cssClasses={["empty-state"]} label={"No media playing"} />
                ) : (
                    mpris.players.map(p => PlayerCard(p, activeTimers))
                )}
            </box>
        </window>
    )
}
