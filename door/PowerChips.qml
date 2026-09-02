import QtQuick
import "Palette.js" as Palette

// Power controls as chips on the rail — cash out, re-buy, step away.
//
// Deliberately not in the denominations - dark clay with a gold inlay, so
// colour says "not part of the bet".
//
// Each one only appears if logind will actually do it: a suspend chip on a
// machine that cannot suspend is a button that lies.
Row {
    id: root

    property string fontFamily: "JetBrainsMono Nerd Font"

    // Layout scale, handed down from Main - see SessionPlaque.
    property real u: 1

    property int chipSize: Math.round(44 * u)

    spacing: Math.round(12 * u)

    // The label rides above whichever chip is under the pointer, so four chips
    // on a rail are not four mystery glyphs.
    property string hovered: ""

    Text {
        anchors.bottom: parent.top
        anchors.bottomMargin: Math.round(8 * root.u)
        anchors.right: parent.right
        text: root.hovered.toUpperCase()
        color: Palette.gold
        font.family: root.fontFamily
        font.pixelSize: Math.round(11 * root.u)
        font.letterSpacing: 3
        opacity: root.hovered.length ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    Repeater {
        model: [
            {
                name: "suspend",
                glyph: "󰤄",
                enabled: sddm.canSuspend,
                hot: false
            },
            {
                name: "hibernate",
                glyph: "󰤁",
                enabled: sddm.canHibernate,
                hot: false
            },
            {
                name: "restart",
                glyph: "",
                enabled: sddm.canReboot,
                hot: false
            },
            {
                name: "cash out",
                glyph: "",
                enabled: sddm.canPowerOff,
                hot: true
            }
        ]

        Item {
            id: slot

            required property var modelData

            visible: modelData.enabled
            width: visible ? root.chipSize : 0
            height: root.chipSize

            Chip {
                id: chip

                anchors.fill: parent
                fontFamily: root.fontFamily
                label: slot.modelData.glyph
                labelSize: root.chipSize * 0.36

                // The shutdown chip goes red the moment you reach for it. It is
                // the one control on this screen that loses work.
                readonly property var clay: (slot.modelData.hot && chipHover.hovered) ? Palette.powerChipHot : Palette.powerChip

                body: clay.body
                spot: clay.spot
                ink: chipHover.hovered ? Palette.goldBright : clay.ink

                // Lifts off the rail on hover, presses into it on click - a chip
                // you are picking up, then putting down.
                y: chipHover.hovered ? -5 : 0
                scale: chipTap.pressed ? 0.92 : 1

                Behavior on y {
                    NumberAnimation {
                        duration: 130
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 90
                    }
                }
                Behavior on body {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Behavior on spot {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.hovered = hovered ? slot.modelData.name : ""
            }

            TapHandler {
                id: chipTap

                onTapped: {
                    switch (slot.modelData.name) {
                    case "suspend":
                        sddm.suspend();
                        break;
                    case "hibernate":
                        sddm.hibernate();
                        break;
                    case "restart":
                        sddm.reboot();
                        break;
                    default:
                        sddm.powerOff();
                        break;
                    }
                }
            }
        }
    }
}
