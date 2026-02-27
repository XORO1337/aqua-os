// AquaOS — Calendar Widget
import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable } from "astal"

const visible = Variable(false)

export function toggleCalendar() {
    visible.set(!visible.get())
}

const DAYS_SHORT   = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
const MONTHS_FULL  = [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
]

function getDaysInMonth(year: number, month: number): number {
    return new Date(year, month + 1, 0).getDate()
}

function getFirstDayOfMonth(year: number, month: number): number {
    return new Date(year, month, 1).getDay()
}

function CalendarGrid(year: number, month: number, today: Date) {
    const firstDay   = getFirstDayOfMonth(year, month)
    const daysInMonth = getDaysInMonth(year, month)
    const daysInPrev  = getDaysInMonth(year, month - 1)

    const cells: { day: number; type: "prev" | "current" | "next" }[] = []

    // Fill leading days from previous month
    for (let i = firstDay - 1; i >= 0; i--) {
        cells.push({ day: daysInPrev - i, type: "prev" })
    }

    // Current month days
    for (let d = 1; d <= daysInMonth; d++) {
        cells.push({ day: d, type: "current" })
    }

    // Fill remaining cells (up to 6 weeks)
    let next = 1
    while (cells.length < 42) {
        cells.push({ day: next++, type: "next" })
    }

    const isToday = (d: number, t: "prev" | "current" | "next") =>
        t === "current" &&
        d === today.getDate() &&
        month === today.getMonth() &&
        year  === today.getFullYear()

    const rows: JSX.Element[] = []
    for (let r = 0; r < 6; r++) {
        const row = cells.slice(r * 7, r * 7 + 7)
        rows.push(
            <box orientation={Gtk.Orientation.HORIZONTAL} spacing={2} homogeneous>
                {row.map(({ day, type }) => (
                    <label
                        cssClasses={[
                            "day-cell",
                            type !== "current" ? "other-month" : "current",
                            isToday(day, type)  ? "today"        : "",
                        ].filter(Boolean)}
                        label={day.toString()}
                        halign={Gtk.Align.CENTER}
                        valign={Gtk.Align.CENTER}
                    />
                ))}
            </box>
        )
    }

    return rows
}

export default function CalendarWidget(monitor: Gdk.Monitor) {
    const now   = new Date()
    const year  = Variable(now.getFullYear())
    const month = Variable(now.getMonth())
    const today = now

    return (
        <window
            cssClasses={["calendar-container"]}
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
            <box cssClasses={["calendar-container"]} orientation={Gtk.Orientation.VERTICAL} spacing={8}>

                {/* Header */}
                <box cssClasses={["calendar-header"]} orientation={Gtk.Orientation.HORIZONTAL}>
                    <button
                        cssClasses={["nav-btn"]}
                        label={"‹"}
                        onClicked={() => {
                            let m = month.get() - 1
                            let y = year.get()
                            if (m < 0) { m = 11; y-- }
                            month.set(m); year.set(y)
                        }}
                    />
                    <label
                        cssClasses={["month-label"]}
                        label={month(m => `${MONTHS_FULL[m]} ${year.get()}`)}
                        hexpand
                        halign={Gtk.Align.CENTER}
                    />
                    <button
                        cssClasses={["nav-btn"]}
                        label={"›"}
                        onClicked={() => {
                            let m = month.get() + 1
                            let y = year.get()
                            if (m > 11) { m = 0; y++ }
                            month.set(m); year.set(y)
                        }}
                    />
                </box>

                {/* Day headers */}
                <box orientation={Gtk.Orientation.HORIZONTAL} spacing={2} homogeneous>
                    {DAYS_SHORT.map(d => (
                        <label cssClasses={["day-header"]} label={d} halign={Gtk.Align.CENTER} />
                    ))}
                </box>

                {/* Calendar grid */}
                <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                    {month(m => (
                        <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                            {CalendarGrid(year.get(), m, today)}
                        </box>
                    ))}
                </box>

                {/* Today button */}
                <button
                    cssClasses={["today-btn"]}
                    label={"Today"}
                    halign={Gtk.Align.CENTER}
                    onClicked={() => {
                        year.set(today.getFullYear())
                        month.set(today.getMonth())
                    }}
                />
            </box>
        </window>
    )
}
