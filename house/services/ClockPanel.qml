pragma Singleton

import QtQuick
import Quickshell

// Shared open-state for the clock popout. The clock lives in the bar (one layer
// surface) and the popout is another (ClockPopout), so the click and the panel
// can't be the same window - they talk through here.
//
// mode is one of "none", "time" or "calendar". Opening one closes the other,
// because it's a single value rather than two independent flags.
Singleton {
    id: root

    property string mode: "none"

    // Left-click on the clock.
    function toggleTime(): void {
        root.mode = root.mode === "time" ? "none" : "time";
    }

    // Right-click on the clock.
    function toggleCalendar(): void {
        root.mode = root.mode === "calendar" ? "none" : "calendar";
    }

    function close(): void {
        root.mode = "none";
    }
}
