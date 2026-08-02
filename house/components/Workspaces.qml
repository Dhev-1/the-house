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

                    // Two hands of suits, dealt in bridge order (1-4 and 5-8),
                    // then plain chips for the last two seats.
                    readonly property var glyphs: ["♠", "♥", "♦", "♣"]
                    readonly property bool isChip: index >= 8

                    // The heart renders visually heavier than the other suits at
                    // the same pixel size, so it alone keeps the original scale.
                    readonly property bool isHeart: !isChip && index % 4 === 1

                    Layout.alignment: Qt.AlignHCenter

                    // The first five seats are always dealt; the rest only sit
                    // at the table while something occupies them (or is focused
                    // there). Hiding collapses the slot, so the column never
                    // holds space for empty back seats.
                    visible: wsId <= 5 || occupied || active

                    text: isChip ? "●" : glyphs[index % glyphs.length]
                    font.family: Config.font
                    font.pixelSize: isChip ? (active ? 14 : 9) : isHeart ? (active ? 20 : 14) : (active ? 24 : 17)
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
