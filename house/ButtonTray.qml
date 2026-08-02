pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

// A tray of icon buttons that drops down from the top edge of the screen: a
// handle sits under the top border near the right corner, and clicking it slides
// a small column of buttons out beneath it.
//
// Deliberately dumb. It is handed a list of buttons - each just an icon and
// whether it reads as active - and it emits activated(index) when one is pressed.
// It has no idea what the buttons do; that is wired up by whoever fills it, so
// the widget itself carries none of the service specifics and stays reusable.
PanelWindow {
    id: root

    // [{ icon: string, active: bool }]. Rebuild it to repaint - the caller does
    // this from whatever state the buttons reflect.
    property var buttons: []

    // Which button was pressed, by its index in `buttons`.
    signal activated(int index)

    property bool expanded: false

    // Height of the button stack once open, worked out from the button count.
    readonly property int cardHeight: root.buttons.length === 0 ? 0 : Config.trayPadding * 2 + root.buttons.length * Config.trayButtonSize + (root.buttons.length - 1) * Config.trayButtonSpacing

    // How far the stack is out, 0..cardHeight. Everything below rides on this.
    property real reveal: expanded ? root.cardHeight : 0

    anchors.top: true
    anchors.right: true

    // Just left of the bar, hanging from the very top edge so it grows out of the
    // top border rather than floating below it.
    margins.right: Config.barWidth + Config.trayInset
    margins.top: 0

    // Fixed, so the layer surface isn't resized on every frame of the slide; the
    // panel inside is what grows.
    implicitWidth: Config.trayWidth
    implicitHeight: Config.trayTabHeight + root.cardHeight

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-tray"

    Behavior on reveal {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // Only the drawn part takes clicks; the rest of the surface is transparent and
    // would otherwise eat clicks meant for the desktop.
    mask: Region {
        width: root.width
        height: Config.trayTabHeight + root.reveal
    }

    Rectangle {
        id: panel

        width: parent.width
        height: Config.trayTabHeight + root.reveal

        // Square against the top edge so it reads as part of the border it hangs
        // from; rounded where it juts down into the desktop.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Config.trayRounding
        bottomRightRadius: Config.trayRounding

        color: Config.colours.surface
        clip: true

        // The handle: always visible, and the click target that opens and shuts
        // the stack. Its chevron flips to point the way the stack will move.
        MouseArea {
            id: handle

            width: parent.width
            height: Config.trayTabHeight

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded

            Text {
                anchors.centerIn: parent
                text: "" // chevron; down to pull open, up to push shut
                rotation: root.expanded ? 180 : 0
                color: handle.containsMouse ? Config.colours.accent : Config.colours.subtext
                font.family: Config.font
                font.pointSize: 12

                Behavior on rotation {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        // The buttons, unrolled below the handle as the panel grows into them.
        ColumnLayout {
            anchors.top: handle.bottom
            anchors.topMargin: Config.trayPadding
            anchors.horizontalCenter: parent.horizontalCenter

            spacing: Config.trayButtonSpacing

            Repeater {
                model: root.buttons

                Rectangle {
                    id: button

                    required property var modelData
                    required property int index

                    readonly property bool on: button.modelData.active === true

                    implicitWidth: Config.trayButtonSize
                    implicitHeight: Config.trayButtonSize
                    radius: 10

                    // Transparent until hovered, delineated by the border - the same
                    // restraint as the clock button in the bar.
                    color: press.containsMouse ? Config.colours.idle : "transparent"
                    border.width: 1
                    border.color: button.on ? Config.trayOn : Config.colours.idle

                    Text {
                        anchors.centerIn: parent
                        text: button.modelData.icon ?? ""
                        color: button.on ? Config.trayOn : Config.trayOff
                        font.family: Config.font
                        font.pointSize: 16

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activated(button.index)
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
}
