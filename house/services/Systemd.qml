pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// State and control for the systemd --user units the service tray exposes.
//
// This is the QML port of the waybar custom modules it replaced: the *-toggle.sh
// and vb-toggle.sh both polled `systemctl --user is-active` on a 5s timer and
// flipped the unit with start/stop on click. Same contract, one probe covering
// every unit at once rather than a script per module.
Singleton {
    id: root

    // Unit id -> true while running. Absent until the first probe lands, which
    // isRunning() reads as stopped.
    property var state: ({})

    readonly property var units: Config.trayServices.map(s => s.unit)

    // Unit id -> true when the unit exists on this machine. is-active cannot
    // tell a stopped unit from a missing one - both read "inactive" - so a
    // config listing a unit you do not have would leave a permanently dead
    // button. Probed once; the tray drops whatever is not here.
    property var loaded: ({})

    function isRunning(unit: string): bool {
        return root.state[unit] === true;
    }

    function isLoaded(unit: string): bool {
        return root.loaded[unit] === true;
    }

    readonly property var presentUnits: Config.trayServices.filter(s => root.isLoaded(s.unit))

    function toggle(unit: string): void {
        Quickshell.execDetached(["systemctl", "--user", root.isRunning(unit) ? "stop" : "start", unit]);
        // systemd needs a beat to act; re-probe once it (probably) has so the
        // button flips without waiting on the next scheduled poll.
        settle.restart();
    }

    function poll(): void {
        if (root.units.length > 0)
            probe.running = true;
    }

    // is-active prints one line per unit - "active", "inactive", "failed", ... -
    // and exits non-zero when any is not active. Only the text matters here, so
    // the non-zero exit is expected rather than a failure.
    Process {
        id: probe

        command: ["systemctl", "--user", "is-active"].concat(root.units)

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const next = {};
                for (let i = 0; i < root.units.length; i++)
                    next[root.units[i]] = lines[i] === "active";
                root.state = next;
            }
        }
    }

    // LoadState is "loaded" or "not-found", one line per unit, blank-separated.
    Process {
        id: presence

        running: root.units.length > 0
        command: ["systemctl", "--user", "show", "--property=LoadState", "--value"].concat(root.units)

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.trim().length > 0);
                const next = {};
                for (let i = 0; i < root.units.length; i++)
                    next[root.units[i]] = lines[i] === "loaded";
                root.loaded = next;
            }
        }
    }

    // The cadence the waybar scripts ran at, kept.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // One-shot, restarted by toggle() so a click reads back the new state.
    Timer {
        id: settle

        interval: 400
        onTriggered: root.poll()
    }
}
