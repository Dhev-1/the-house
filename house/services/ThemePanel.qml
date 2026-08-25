pragma Singleton

import QtQuick
import Quickshell

// Open-state for the theme picker popout: ThemeButton in the bar, ThemePicker
// as its own surface. The same split as ClockPanel, for the same reason.
Singleton {
    id: root

    property bool open: false

    // Left-click on the palette button in the bar.
    function toggle(): void {
        root.open = !root.open;
    }

    function close(): void {
        root.open = false;
    }
}
