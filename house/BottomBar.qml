pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The bottom bar: the right-edge bar's other leg, same breadth, running along
// the bottom so the two make an L. It carries the pit - one chip per game in
// Config.pitGames, lit while that game's process is up; clicking deals the
// game in or folds it, via Pit. The power chip in the far corner rides on its
// own surface (PowerMenu) and visually sits on this bar's left end.
PanelWindow {
    id: root

    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    implicitHeight: Config.bottomBarWidth
    exclusiveZone: Config.bottomBarWidth
    color: Config.colours.surface

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-bottombar"

    // The pit, dealt in from the right - clear of the vertical bar's corner.
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Config.barWidth + Config.trayInset
        anchors.verticalCenter: parent.verticalCenter

        spacing: 18

        Repeater {
            model: Config.pitGames

            Rectangle {
                id: button

                required property var modelData

                readonly property bool on: Pit.isRunning(button.modelData.dir)

                implicitWidth: Config.bottomBarWidth - 4
                implicitHeight: Config.bottomBarWidth - 4
                radius: 6

                // Transparent until hovered, delineated by the border - the
                // same restraint as the buttons in the trays.
                // No chip behind the die at all - running state is the die's
                // own colour, hover is it going gold. Nothing else draws.
                color: "transparent"
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: button.modelData.icon ?? ""
                    // The die lights gold under the pointer, whatever its state.
                    color: press.containsMouse ? Config.colours.accent : button.on ? Config.trayOn : Config.trayOff
                    font.family: Config.font
                    font.pointSize: 10
                    scale: press.containsMouse ? 1.3 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 50
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 70
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pit.toggle(button.modelData)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
