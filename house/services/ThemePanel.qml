pragma Singleton

import QtQuick
import Quickshell

// Open-state for the theme picker popout, the same split as ClockPanel: the
// trigger (ThemeButton) lives in the bar - one layer surface - and the card
// (ThemePicker) is another, so the click and the panel can't be the same window.
// They talk through here.
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
