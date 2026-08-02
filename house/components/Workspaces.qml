pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs

ColumnLayout {
    id: root

    spacing: 8

    MouseArea {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: suits.implicitWidth
        implicitHeight: suits.implicitHeight

        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? -1 : 1;
            Hyprland.dispatch(`workspace r${dir > 0 ? "+" : ""}${dir}`);
        }

        ColumnLayout {
            id: suits

            anchors.centerIn: parent
            spacing: root.spacing

            Repeater {
                model: Config.workspacesShown

                Text {
                    id: suit

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: Hyprland.focusedWorkspace?.id === wsId
                    readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === suit.wsId && w.lastIpcObject.windows > 0)

                    // One suit per table, dealt in bridge order; the fifth seat is
                    // the joker's star. Workspaces past five cycle back through.
                    readonly property var glyphs: ["♠", "♥", "♦", "♣", "★"]

                    Layout.alignment: Qt.AlignHCenter

                    text: glyphs[index % glyphs.length]
                    font.family: Config.font
                    font.pixelSize: active ? 20 : 14
                    color: active ? Config.colours.accent : occupied ? Config.colours.subtext : Config.colours.idle

                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${suit.wsId}`)
                    }
                }
            }
        }
    }
}
