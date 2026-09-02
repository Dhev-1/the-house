import QtQuick
import "Palette.js" as Palette

// A playing card that can turn over. Takes a rank and a suit rather than an
// image because it does three jobs: the user, the session, and the showdown
// hand dealt on enter.
//
// The flip rotates about the card's vertical axis, swapping the faces at the
// halfway point. No perspective projection (Qt would need a full matrix), so it
// squashes rather than turning in space - invisible at this size and speed.
Item {
    id: root

    property string rank: "A"
    property string suit: "♠" // ♠ ♥ ♦ ♣
    property bool faceUp: false
    property string fontFamily: "JetBrainsMono Nerd Font"

    // A face-up card can carry a picture instead of a pip, falling back to the
    // centre pip when there isn't one - the common case, since most machines
    // have no /var/lib/AccountsService icon for their users.
    property url picture: ""

    // Print this one as a court card: the framed panel, mirrored top to bottom,
    // that a jack, queen or king carries instead of pips. Only the seat cards
    // use it - the court cards are the only ones in a deck with a person on them.
    property bool court: false

    readonly property color inkColour: (suit === "♥" || suit === "♦") ? Palette.cardRed : Palette.cardInk

    // A number card is ivory with black or red ink; a court card is the room's
    // own black, gold and white. Kept as strings, not `color`: Palette.alpha()
    // works on the hex text and silently has nothing to say to a QColor.
    readonly property string stock: root.court ? Palette.courtStock : Palette.ivory
    readonly property string figure: root.court ? Palette.courtFigure : "#000000"

    // The suit's own ink on a number card, the figure colour on a court card -
    // black or red ink on court stock would be a smudge.
    readonly property color indexInk: root.court ? root.figure : root.inkColour

    // 0 = back to the room, 180 = face to the room.
    property real flip: faceUp ? 180 : 0

    // How long this card waits before it turns. Hand.qml walks this up across
    // the five so a showdown resolves left to right instead of all at once.
    property int flipDelay: 0

    implicitWidth: 96
    implicitHeight: Math.round(width * 1.42) // near enough the real 2.5 x 3.5

    Behavior on flip {
        SequentialAnimation {
            PauseAnimation {
                duration: root.flipDelay
            }
            NumberAnimation {
                duration: 420
                easing.type: Easing.InOutQuad
            }
        }
    }

    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        axis {
            x: 0
            y: 1
            z: 0
        }
        angle: root.flip
    }

    // --- the back -------------------------------------------------------------
    // Two constraints. Seen in a fanned overlap, only a strip down one side
    // shows, so the pattern has to read from any sliver of it. And it is seen
    // upside down from across the table, so the weave is symmetric about both
    // axes and the medallion sits dead centre.
    Rectangle {
        anchors.fill: parent
        visible: root.flip < 90
        radius: root.width * 0.08
        color: Palette.cardBack
        // Gold, not black: on black cloth a black edge gives a face-down card
        // no outline, and a hand of them runs together into one shape.
        border.width: 1
        border.color: Palette.alpha(Palette.gold, 0.30)

        // The double rule, at the same inset as the court panel's, so a card
        // that turns over keeps its frame and changes only what is inside it.
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.width * 0.055
            radius: root.width * 0.05
            color: "transparent"
            border.width: 1
            border.color: Palette.alpha(Palette.gold, 0.55)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.width * 0.085
            radius: root.width * 0.035
            color: "transparent"
            border.width: 1
            border.color: Palette.alpha(Palette.gold, 0.26)
        }

        // Two families of hairlines at right angles, crossing into a diamond
        // mesh. Discrete diamonds on a grid fail the sliver test above - at the
        // size a card is drawn they are specks; any strip of crossed lines is
        // the whole pattern.
        Item {
            id: weave

            anchors.fill: parent
            anchors.margins: root.width * 0.105
            clip: true

            // Measured along the horizontal, so the mesh the eye sees is this
            // over root two.
            readonly property real step: root.width * 0.085

            // Long enough that a line pinned at the centre still runs past both
            // corners once it is turned.
            readonly property real span: (weave.width + weave.height) * 1.2

            // Floored at zero: anchors.fill plus a margin on a parent that has
            // not been sized yet gives a negative width, and the Repeater
            // complains about a negative count by name.
            readonly property int lines: Math.max(0, Math.ceil((weave.width + weave.height) / weave.step))

            // One Repeater of horizontal hairlines per family, turned as a
            // whole - offsetting a turned line along x alone still walks it
            // across the card perpendicular to itself.
            Repeater {
                model: weave.lines

                Rectangle {
                    required property int index

                    width: weave.span
                    height: 1
                    x: (index - weave.lines / 2) * weave.step + weave.width / 2 - width / 2
                    y: weave.height / 2
                    rotation: 45
                    color: Palette.cardBackLine
                    opacity: 0.5
                }
            }

            Repeater {
                model: weave.lines

                Rectangle {
                    required property int index

                    width: weave.span
                    height: 1
                    x: (index - weave.lines / 2) * weave.step + weave.width / 2 - width / 2
                    y: weave.height / 2
                    rotation: -45
                    color: Palette.cardBackLine
                    opacity: 0.5
                }
            }
        }

        // The medallion: a lozenge cut out of the weave, which is otherwise
        // even all over and reads as wallpaper. Filled with the stock rather
        // than left transparent, so it masks the hairlines underneath.
        Item {
            anchors.centerIn: parent
            width: root.width * 0.36
            height: width

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.74
                height: width
                rotation: 45
                color: Palette.cardBack
                border.width: 1
                border.color: Palette.alpha(Palette.gold, 0.7)
            }

            // Always the spade, never this card's own suit - a back that told
            // you anything about its face would be a marked deck.
            Text {
                anchors.centerIn: parent
                text: "♠"
                color: Palette.alpha(Palette.gold, 0.85)
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.15
            }
        }
    }

    // --- the face -------------------------------------------------------------
    // Counter-rotated: the parent has already turned this past 90 degrees, so
    // without a second flip the face arrives mirrored. Only the middle differs
    // between a number card and a court one.
    Rectangle {
        anchors.fill: parent
        visible: root.flip >= 90
        radius: root.width * 0.08
        color: root.stock
        border.width: 1
        // Ivory stock on dark cloth needs a shadow to separate it; a black
        // court card needs the opposite, or it reads as a hole in the table.
        border.color: root.court ? Palette.gold : Qt.rgba(0, 0, 0, 0.35)

        transform: Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis {
                x: 0
                y: 1
                z: 0
            }
            angle: 180
        }

        // The corner index: rank over suit, so it still reads when the cards
        // are fanned and overlapping.
        Column {
            id: topIndex

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.width * 0.09
            anchors.topMargin: root.width * 0.07
            spacing: -root.width * 0.04

            Text {
                // Not on a court card: a seat card is worth nothing, and the
                // name is already set in gold underneath it.
                visible: !root.court
                text: root.rank
                color: root.indexInk
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.26
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suit
                color: root.indexInk
                font.family: root.fontFamily
                // A shade larger once it is alone in the corner.
                font.pixelSize: root.width * (root.court ? 0.24 : 0.20)
            }
        }

        // The same again, upside down in the opposite corner.
        Column {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.width * 0.09
            anchors.bottomMargin: root.width * 0.07
            spacing: -root.width * 0.04
            rotation: 180

            Text {
                visible: !root.court
                text: root.rank
                color: root.indexInk
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.26
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suit
                color: root.indexInk
                font.family: root.fontFamily
                font.pixelSize: root.width * (root.court ? 0.24 : 0.20)
            }
        }

        // --- the middle, on a number card ---------------------------------------
        // An avatar if the card has one, the suit pip if not.
        Text {
            anchors.centerIn: parent
            visible: !root.court && avatar.status !== Image.Ready
            text: root.suit
            color: root.inkColour
            font.family: root.fontFamily
            font.pixelSize: root.width * 0.52
        }

        Image {
            id: avatar

            anchors.centerIn: parent
            width: root.width * 0.58
            height: width
            source: root.picture
            fillMode: Image.PreserveAspectCrop
            visible: !root.court && status === Image.Ready
            asynchronous: true
            // Absent avatars are the norm, not a fault; the pip above covers it.
            onStatusChanged: {}
        }

        // --- the middle, on a court card ----------------------------------------
        // The portrait panel: a double gold frame divided at the waist, and
        // inside it nothing but the suit, printed twice head to head.
        Item {
            id: portrait

            anchors.centerIn: parent
            visible: root.court

            // Measured off the corner index rather than a fixed fraction of the
            // width, which ran the gold line straight through the suit glyph.
            // The suits are symbol glyphs, so their width depends on what
            // fontconfig hands back; the floor keeps a pathologically wide one
            // from giving a negative panel. Only the width gives - clearing them
            // vertically would lose the tall cartouche the court card needs.
            width: Math.max(root.width * 0.30, root.width - 2 * (root.width * 0.09 + topIndex.width + root.width * 0.035))
            height: root.height * 0.70

            // The stock darkened, so the panel reads as a recess rather than a
            // box drawn on top - with the middle left empty, that is the whole
            // panel.
            Rectangle {
                anchors.fill: parent
                color: Qt.darker(root.stock, 1.45)
                border.width: 1
                border.color: Palette.alpha(Palette.gold, 0.65)
            }

            // The inner gold line, matching the card back's frame, so a card
            // that turns over keeps its proportions.
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.width * 0.025
                color: "transparent"
                border.width: 1
                border.color: Palette.alpha(Palette.gold, 0.45)
            }

            // Inside the frames, and clipped to them, so nothing printed here
            // ever runs under the gold.
            Item {
                id: plate

                anchors.fill: parent
                anchors.margins: root.width * 0.045

                // The upper half.
                Item {
                    id: upper

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: plate.height / 2
                    clip: true

                    // Left empty on purpose. An avatar would be a fallback
                    // pretending to be a design on almost every machine, and a
                    // monogram repeats what the corner indices already say.
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: root.width * 0.03
                        anchors.topMargin: root.width * 0.02
                        text: root.suit
                        color: Palette.gold
                        font.family: root.fontFamily
                        font.pixelSize: root.width * 0.15
                    }
                }

                // The lower half: the identical printing rotated 180, not a
                // reflection - which is why a court card is the right way up
                // from either side of the table.
                Item {
                    id: lower

                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: plate.height / 2
                    clip: true
                    rotation: 180

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: root.width * 0.03
                        anchors.topMargin: root.width * 0.02
                        text: root.suit
                        color: Palette.gold
                        font.family: root.fontFamily
                        font.pixelSize: root.width * 0.15
                    }
                }

                // The rule at the waist, where the two figures meet.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Palette.alpha(Palette.gold, 0.65)
                }
            }
        }
    }
}
