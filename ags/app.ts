import { App } from "astal/gtk4"
import style from "./style.scss"
import NotificationCenter, { toggleNotificationCenter } from "./widgets/NotificationCenter"
import ControlCenter, { toggleControlCenter } from "./widgets/ControlCenter"
import Launcher, { toggleLauncher } from "./widgets/Launcher"
import SystemMonitor from "./widgets/SystemMonitor"
import PowerMenu, { togglePowerMenu } from "./widgets/PowerMenu"
import OSD from "./widgets/OSD"
import MediaPlayer from "./widgets/MediaPlayer"
import CalendarWidget, { toggleCalendar } from "./widgets/Calendar"

App.start({
    css: style,
    instanceName: "macos-mirror",
    requestHandler(request: string, respond: (r: string) => void) {
        const handlers: Record<string, () => void> = {
            "toggle control-center":       toggleControlCenter,
            "toggle launcher":             toggleLauncher,
            "toggle power-menu":           togglePowerMenu,
            "toggle calendar":             toggleCalendar,
            "toggle notification-center":  toggleNotificationCenter,
            "reload-css": () => App.apply_css(style, true),
        }
        const handler = handlers[request]
        handler ? (handler(), respond("ok")) : respond(`unknown: ${request}`)
    },
    main() {
        for (const monitor of App.get_monitors()) {
            NotificationCenter(monitor)
            ControlCenter(monitor)
            Launcher(monitor)
            SystemMonitor(monitor)
            PowerMenu(monitor)
            OSD(monitor)
            MediaPlayer(monitor)
            CalendarWidget(monitor)
        }
    },
})
