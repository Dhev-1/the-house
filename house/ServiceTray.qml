import qs
import qs.services

// Wires the generic ButtonTray up to systemd --user units: it turns each entry
// in Config.trayServices into an icon coloured by whether the unit is running,
// and toggles that unit when its button is pressed.
//
// This is the only place that knows the tray drives services at all. The widget
// itself (ButtonTray) carries none of it, so it can be lifted out on its own.
ButtonTray {
    buttons: Config.trayServices.map(s => ({
                icon: Systemd.isRunning(s.unit) ? s.iconOn : s.iconOff,
                active: Systemd.isRunning(s.unit)
            }))

    onActivated: index => Systemd.toggle(Config.trayServices[index].unit)
}
