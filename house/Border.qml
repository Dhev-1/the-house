import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs

// Full screen surface painted everywhere except a rounded cutout, so the
// desktop appears inside a frame. Input passes straight through it.
PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-border"

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Config.colours.surface
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0

            PathRectangle {
                width: root.width
                height: root.height
            }

            // The cutout. Its right edge stops where the bar starts.
            PathRectangle {
                x: Config.borderThickness
                y: Config.borderThickness
                width: root.width - Config.borderThickness - Config.barWidth
                height: root.height - Config.borderThickness * 2
                radius: Config.borderRounding
            }
        }
    }
}
