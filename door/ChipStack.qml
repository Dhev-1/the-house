import QtQuick
import "Palette.js" as Palette

// The bet. One chip per character typed, stacked edge on.
//
// This is the password field. There is no row of asterisks anywhere on this
// theme - the stack is the only feedback that a key landed, which means it has
// to be unambiguous at a glance and has to move, so a chip drops in with a
// bounce and the whole thing is visibly taller than it was.
//
// A chip seen from the side is a shallow cylinder: an ellipse of clay with a
// rim below it. A rounded rectangle whose radius is half its height is close
// enough at this size, and unlike an ellipse it costs one node.
Item {
    id: root

    // How many chips are in. Bind straight to the password length.
    property int count: 0

    // Past this the stack stops growing and starts tucking - see `pitch`.
    property int maxStack: 14

    property int chipWidth: 76

    readonly property int chipHeight: Math.round(chipWidth * 0.26)

    // The vertical gap between one chip and the next. Full pitch until the
    // stack hits maxStack, then squeezed so a forty-character password does not
    // climb off the top of the screen - the chips ride closer together, the way
    // a stack does when you press it down, and the stack keeps its ceiling.
    readonly property real pitch: count <= maxStack ? chipHeight * 0.68 : Math.max(chipHeight * 0.18, chipHeight * 0.68 * maxStack / count)

    // Which denomination the chip at `i` is. Climbing in threes: the stack
    // starts white and works up through the rack, so the colour of the top chip
    // says roughly how long the bet is without anyone counting it.
    function denom(i: int): var {
        return Palette.chips[Math.floor(i / 3) % Palette.chips.length];
    }

    implicitWidth: chipWidth
    implicitHeight: chipHeight + pitch * Math.max(0, maxStack - 1)

    Repeater {
        model: root.count

        Item {
            id: chip

            required property int index

            // Chips are dealt by hand and land where they land. A deterministic
            // wobble off the index rather than Math.random(), so a chip does not
            // jump every time the stack recomposes.
            readonly property real wobble: (((chip.index * 37) % 5) - 2) * 0.8
            readonly property var clay: root.denom(chip.index)

            // 1 while the chip is still in the air, 0 once it is on the stack.
            property real drop: 1

            width: root.chipWidth
            height: root.chipHeight

            // Stacked from the bottom of the item upward, so the stack grows
            // toward the top of the screen and its base stays put on the felt.
            x: wobble
            y: root.height - root.chipHeight - chip.index * root.pitch - chip.drop * 110
            opacity: 1 - chip.drop
            // Later chips sit in front of earlier ones, so the near rim of each
            // chip overlaps the one below it rather than being hidden by it.
            z: chip.index

            Component.onCompleted: land.start()

            NumberAnimation {
                id: land

                target: chip
                property: "drop"
                from: 1
                to: 0
                // Short, and it bounces. A chip is clay on wood: it arrives, it
                // rattles once, it stops. Anything slower than this and fast
                // typing turns the stack into soup.
                duration: 260
                easing.type: Easing.OutBounce
            }

            // The clay, edge on.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: chip.clay.body

                // Lit along the top edge, in shade underneath - the same light
                // the rest of the room is under.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }
                        GradientStop {
                            position: 0.45
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(0, 0, 0, 0.34)
                        }
                    }
                }

                // The edge spots, seen from the side: the inlay banding that
                // runs round the rim, cut into segments. Three visible from any
                // one angle out of the six on the chip.
                //
                // Each chip's banding is rolled round the rim by a different
                // amount. Without that the three bands land at the same three
                // x positions on every chip in the stack and read as continuous
                // vertical stripes - the stack stops looking like discs on top
                // of each other and starts looking like woven basketwork. No
                // two chips in a real stack are clocked the same way, and this
                // is the cheapest way to say so.
                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        readonly property real roll: ((chip.index * 13) % 7) / 7 * 0.28

                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * (0.10 + index * 0.28 + roll)
                        width: parent.width * 0.11
                        height: parent.height * 0.55
                        radius: 1
                        color: chip.clay.spot
                        opacity: 0.62
                    }
                }
            }

            // The shadow this chip drops on the one below it. Without it the
            // stack is a stripe of colours; with it, it has depth.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: -1
                width: parent.width * 0.94
                height: 3
                radius: 1.5
                color: Qt.rgba(0, 0, 0, 0.35)
                z: -1
            }
        }
    }
}
