import Quickshell
import Quickshell.Wayland
import qs

// The bars reserve the right and bottom edges themselves; these reserve the
// other two so tiled windows sit inside the border instead of under it.
Scope {
    id: root

    required property ShellScreen screen

    Zone {
        anchors.left: true
    }

    Zone {
        anchors.top: true
    }

    component Zone: PanelWindow {
        screen: root.screen
        color: "transparent"
        exclusiveZone: Config.borderThickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1

        WlrLayershell.namespace: "house-exclusion"
    }
}
