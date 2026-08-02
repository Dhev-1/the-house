pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// The notification stack: separate cards, each framed and rounded on its own.
//
// origin = top-right, but the offset counts from the bar rather than from the
// screen edge, because 20px from the true edge would be underneath the bar.
PanelWindow {
    id: root

    // Not PanelWindow.screen: a hidden layer surface has its screen reassigned by
    // the compositor, so a `visible` binding that reads it feeds back into itself.
    required property ShellScreen monitor

    // follow = mouse: only draw on the monitor being used, or every screen shows
    // its own copy of the same notification.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name

    screen: monitor

    anchors.top: true
    anchors.right: true

    visible: Notifications.shown.length > 0 && root.active

    margins.top: Config.notifOffsetY
    margins.right: Config.barWidth + Config.notifOffsetX

    implicitWidth: Config.notifWidth
    // A zero-height layer surface is a protocol error, so never fall below 1.
    implicitHeight: Math.max(1, column.implicitHeight)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Above the bar and the border, and above fullscreen windows, which is dunst's
    // default layer: a critical notification should never arrive behind something.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "house-notifications"

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: Config.notifSpacing

        Repeater {
            model: ScriptModel {
                values: Notifications.shown
            }

            Toast {}
        }
    }
}
