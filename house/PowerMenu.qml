pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The cash-out corner: a small power chip tucked into the border's bottom-left
// nook - the dead space inside the frame's rounding, the same trick as the
// sidebar tab - and the card of three chips (lock, sleep, power off) that
// slides out above it when clicked.
//
// Trigger and card share this one surface; the mask keeps the click region to
// just the chip (and the card while open), so the rest of the transparent
// canvas never eats clicks. State still runs through PowerPanel so the `power`
// IPC keybind works the same.
PanelWindow {
    id: root

    // Not PanelWindow.screen directly - a hidden layer surface gets its screen
    // reassigned by the compositor, same reasoning as Popups.
    required property ShellScreen monitor

    // The card only pops on the monitor being used; the chip shows everywhere.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name
    readonly property bool open: root.active && PowerPanel.open

    // How far open, 0..1. The card animates off this; the chip is always there.
    property real reveal: root.open ? 1 : 0

    screen: monitor

    anchors.left: true
    anchors.bottom: true

    // Room for the card above the chip.
    implicitWidth: 300
    implicitHeight: 200

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-power"

    // Clicks land only on the chip, plus the card while it's up.
    mask: Region {
        x: trigger.x
        y: trigger.y
        width: trigger.width
        height: trigger.height

        regions: [
            Region {
                x: card.x
                y: card.y
                width: root.reveal > 0.001 ? card.width : 0
                height: root.reveal > 0.001 ? card.height : 0
            }
        ]
    }

    Behavior on reveal {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Close the menu, then hand off. Detached, so the action outlives us -
    // which matters for poweroff most of all.
    function cashOut(cmd: var): void {
        PowerPanel.close();
        Quickshell.execDetached(cmd);
    }

    // The trigger: a power chip in the corner nook. The hit area runs all the
    // way into the corner - no inset - so slamming the mouse into the screen
    // corner always lands on it (Fitts); only the drawn circle is inset.
    MouseArea {
        id: trigger

        anchors.left: parent.left
        anchors.bottom: parent.bottom

        width: 25
        height: 25

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PowerPanel.toggle()

        Rectangle {
            id: triggerFace

            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.topMargin: 0
            anchors.rightMargin: 0
            anchors.bottomMargin: 3
            radius: width / 2
            color: trigger.containsMouse || root.open ? Config.colours.idle : Config.colours.surface
            border.width: 1
            border.color: trigger.containsMouse || root.open ? Config.colours.urgent : Config.colours.idle

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        Text {
            anchors.centerIn: triggerFace
            text: "󰐥" // nf-md-power
            color: trigger.containsMouse || root.open ? Config.colours.urgent : Config.colours.subtext
            font.family: Config.font
            font.pointSize: 10
            scale: trigger.pressed ? 0.85 : 1

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

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.borderThickness
        // Above the bottom bar, which the trigger chip rides on.
        anchors.bottomMargin: Config.bottomBarWidth + 8

        implicitWidth: content.implicitWidth + 20
        implicitHeight: content.implicitHeight + 16

        radius: Config.clockPanelRadius
        color: Config.colours.surface
        border.width: 1
        border.color: Config.colours.idle

        opacity: root.reveal
        transform: Translate {
            x: (root.reveal - 1) * 16
        }

        ColumnLayout {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "cash out?"
                color: Config.colours.subtext
                font.family: Config.font
                font.pointSize: 9
            }

            RowLayout {
                spacing: 16

                Chip {
                    glyph: "󰌾" // nf-md-lock
                    label: "lock"
                    tint: Config.colours.accent
                    onActivated: root.cashOut(["hyprlock"])
                }

                Chip {
                    glyph: "󰤄" // nf-md-power_sleep
                    label: "sleep"
                    tint: Config.colours.text
                    onActivated: root.cashOut(["systemctl", "suspend"])
                }

                Chip {
                    glyph: "󰐥" // nf-md-power
                    label: "power off"
                    tint: Config.colours.urgent
                    onActivated: root.cashOut(["systemctl", "poweroff"])
                }
            }
        }
    }

    // A poker chip that acts: a ringed disc with edge inlays, the glyph in its
    // tint until hovered, when the chip fills and the glyph punches through in
    // the surface colour.
    component Chip: ColumnLayout {
        id: chip

        property alias glyph: face.text
        property string label
        property color tint

        signal activated

        spacing: 5

        MouseArea {
            id: press

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 52
            implicitHeight: 52

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: press.containsMouse ? chip.tint : "transparent"
                border.width: 2
                border.color: chip.tint
                scale: press.pressed ? 0.9 : 1

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

            // Edge inlays, like the stripes on a real chip.
            Repeater {
                model: 6

                Item {
                    required property int index

                    anchors.fill: parent
                    rotation: index * 60

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2
                        width: 3
                        height: 6
                        radius: 1.5
                        color: press.containsMouse ? Config.colours.surface : chip.tint
                        opacity: 0.8

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }

            Text {
                id: face

                anchors.centerIn: parent
                color: press.containsMouse ? Config.colours.surface : chip.tint
                font.family: Config.font
                font.pointSize: 17

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: chip.label
            color: Config.colours.subtext
            font.family: Config.font
            font.pointSize: 8
        }
    }
}
