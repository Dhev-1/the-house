import QtQuick
import "Palette.js" as Palette

// One clay chip, face on, for the power controls on the rail. The bet stack
// draws its own edge-on chips, a different shape entirely - see ChipStack.qml.
//
// Plain Rectangles rather than a Canvas or an SVG: a disc, a ring, six edge
// spots and an inlay are all rectangles with a radius once you can rotate them,
// which keeps the whole thing animatable.
Item {
    id: root

    // The clay. Any of Palette.chips, or the power-chip pair.
    property color body: Palette.chips[0].body
    property color spot: Palette.chips[0].spot
    property color ink: Palette.chips[0].ink

    // What is moulded into the middle. A denomination, a suit, a power glyph.
    property string label: ""
    property real labelSize: root.width * 0.30
    property string fontFamily: "JetBrainsMono Nerd Font"

    // Edge spots. Six is the standard mould; three reads as a roulette chip.
    property int spots: 6

    implicitWidth: 64
    implicitHeight: 64

    // The clay body, and the shadow it casts on whatever it is lying on.
    Rectangle {
        id: clay

        anchors.fill: parent
        radius: width / 2
        color: root.body

        // A disc catching light from above: top edge lifted, bottom in shade.
        // An overlay rather than colours mixed into `body`, so a caller only
        // names one colour per chip.
        Rectangle {
            anchors.fill: parent
            radius: width / 2

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, 0.16)
                }
                GradientStop {
                    position: 0.5
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.28)
                }
            }
        }
    }

    // The edge spots. Each is a small rounded rectangle at the top of a
    // full-size item rotated into place - less arithmetic than positioning on a
    // circle, and square to the rim for free.
    Repeater {
        model: root.spots

        Item {
            required property int index

            anchors.fill: parent
            rotation: index * (360 / root.spots)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height * 0.045
                width: root.width * 0.20
                height: root.height * 0.115
                radius: height * 0.35
                color: root.spot
                opacity: 0.92
            }
        }
    }

    // The inlay: the printed centre, inset from the rim, a shade off the clay so
    // the rim still reads as raised around it.
    Rectangle {
        anchors.centerIn: parent
        width: root.width * 0.62
        height: width
        radius: width / 2
        color: Qt.darker(root.body, 1.18)

        // The hairline where the inlay is let in.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, root.width * 0.018)
            border.color: Qt.rgba(root.spot.r, root.spot.g, root.spot.b, 0.55)
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: root.labelSize
        font.bold: true
        // Denominations are moulded, not printed - a touch of letter spacing
        // stops "100" from reading as a word.
        font.letterSpacing: root.label.length > 1 ? 0.5 : 0
    }
}
