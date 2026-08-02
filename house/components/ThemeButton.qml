import QtQuick
import Quickshell
import qs
import qs.services

// The palette button near the foot of the bar. Click to open the theme picker,
// drawn by ThemePicker and toggled through the ThemePanel singleton - the same
// wiring as the clock and its popout.
MouseArea {
    id: root

    implicitWidth: glyph.implicitWidth + 12
    implicitHeight: glyph.implicitHeight + 8

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: ThemePanel.toggle()

    // Lit while hovered, and while its card is open - matches the clock button.
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.containsMouse || ThemePanel.open ? Config.colours.idle : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Text {
        id: glyph

        anchors.centerIn: parent
        text: "♠" // pick your table
        color: root.containsMouse || ThemePanel.open ? Config.colours.accent : Config.colours.subtext
        font.family: Config.font
        font.pointSize: 16
        scale: root.pressed ? 0.85 : 1

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
    }
}
