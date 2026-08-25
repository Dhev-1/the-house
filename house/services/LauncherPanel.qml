pragma Singleton

import QtQuick
import Quickshell

// Open-state for the launcher overlay - opened by a keybind through shell.qml's
// IpcHandler. The same split as ClockPanel, for the same reason.
//
// There is no query in this singleton on purpose. The overlay is per-monitor and
// the bet belongs to the one you are typing into, not to the shell.
Singleton {
    id: root

    property bool open: false

    function toggle(): void {
        root.open = !root.open;
    }

    function close(): void {
        root.open = false;
    }
}
