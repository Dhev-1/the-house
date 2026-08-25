pragma Singleton

import QtQuick
import Quickshell

// Open-state for the power menu popout: PowerButton in the bar, PowerMenu as
// its own surface. The same split as ClockPanel, for the same reason.
Singleton {
    id: root

    property bool open: false

    // Left-click on the power button in the bar.
    function toggle(): void {
        root.open = !root.open;
    }

    function close(): void {
        root.open = false;
    }
}
