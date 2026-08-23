pragma Singleton

import QtQuick
import Quickshell

// Open-state for the launcher overlay, the same split as ClockPanel,
// ThemePanel and PowerPanel: the thing that opens it (a keybind through
// shell.qml's IpcHandler today) is not the surface that draws it, so they talk
// through here.
//
// There is no query in this singleton on purpose. The overlay is per-monitor
// and the bet belongs to the one you are typing into, not to the shell.
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
