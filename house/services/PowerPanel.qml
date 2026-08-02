pragma Singleton

import QtQuick
import Quickshell

// Open-state for the power menu popout, the same split as ClockPanel and
// ThemePanel: the trigger (PowerButton) lives in the bar - one layer surface -
// and the card (PowerMenu) is another, so the click and the panel can't be the
// same window. They talk through here.
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
