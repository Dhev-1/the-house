import QtQuick
import "Palette.js" as Palette

// A playing card that can turn over.
//
// Used for three different jobs, which is why it takes a rank and a suit rather
// than an image: the user you are logging in as, the session you are logging
// into, and the showdown hand dealt when you press enter.
//
// The flip is a rotation about the card's own vertical axis with the two faces
// swapped at the halfway point. There is no perspective projection here - Qt
// would need a full matrix for that - so the card squashes rather than turning
// in space. At this size and speed the difference does not read.
Item {
    id: root

    property string rank: "A"
    property string suit: "♠" // ♠ ♥ ♦ ♣
    property bool faceUp: false
    property string fontFamily: "JetBrainsMono Nerd Font"

    // A face-up card can carry a picture instead of a pip - the user cards use
    // this for an avatar, and fall back to the big centre pip when there isn't
    // one (which is the common case: most machines have no /var/lib/AccountsService
    // icon for their users at all).
    property url picture: ""

    // Print this one as a court card: the framed panel, mirrored top to bottom,
    // that a real jack, queen or king carries instead of a rank's worth of pips.
    //
    // The seat cards use it and nothing else does. Every other card on this
    // table is one you were dealt, and a dealt card is worth what its rank says;
    // a seat card is not in the hand at all, it is the person sitting in front of
    // it, and the court cards are the only ones in a deck that have a person on
    // them. Same stock, same ink, same deck as the showdown - it is not a
    // different kind of object, it is the card in that deck which happens to be
    // a portrait.
    //
    // The mirroring is the real tell, and it is not decoration: a court card is
    // drawn twice, head to head, so that it reads the same to the player holding
    // it and the player across the table. That is the one thing about a face
    // card everybody recognises without being able to name it.
    property bool court: false

    // Hearts and diamonds are red. The one rule the whole deck runs on.
    readonly property color inkColour: (suit === "♥" || suit === "♦") ? Palette.cardRed : Palette.cardInk

    // What this card is printed on, and what it is printed in.
    //
    // A number card is ivory with black or red ink, like every card ever dealt.
    // A court card is black with gold rule and white figures - the room's own
    // colours, so it reads as part of the table rather than as something dealt
    // onto it.
    //
    // Kept as strings rather than as `color`, because Palette.alpha() works on
    // the hex text and silently has nothing to say to a QColor.
    readonly property string stock: root.court ? Palette.courtStock : Palette.ivory
    readonly property string figure: root.court ? Palette.courtFigure : "#000000"

    // What the corner indices are set in: the suit's own ink on a number card,
    // the figure colour on a court card, where black or red ink on blue or
    // purple clay would be a smudge.
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
    Rectangle {
        anchors.fill: parent
        visible: root.flip < 90
        radius: root.width * 0.08
        color: Palette.cardBack
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.45)

        // The gold frame printed inside the edge.
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.width * 0.07
            radius: root.width * 0.04
            color: "transparent"
            border.width: 1
            border.color: Palette.alpha(Palette.gold, 0.55)
        }

        // The lattice inside the frame - the same diamond grid as the cloth, so
        // the deck and the table are printed by the same house.
        Item {
            id: backGrid

            anchors.fill: parent
            anchors.margins: root.width * 0.13
            clip: true

            readonly property int cols: 4
            readonly property int rows: 6

            Repeater {
                model: backGrid.cols * backGrid.rows

                Rectangle {
                    required property int index

                    readonly property int col: index % backGrid.cols
                    readonly property int row: Math.floor(index / backGrid.cols)

                    width: backGrid.width / backGrid.cols * 0.5
                    height: width
                    x: (col + 0.5) * backGrid.width / backGrid.cols - width / 2 + (row % 2 ? backGrid.width / backGrid.cols / 2 : 0)
                    y: (row + 0.5) * backGrid.height / backGrid.rows - height / 2
                    rotation: 45
                    color: "transparent"
                    border.width: 1
                    border.color: Palette.cardBackLine
                }
            }
        }
    }

    // --- the face -------------------------------------------------------------
    // Counter-rotated: the parent has already turned this past 90 degrees, so
    // without a second flip the face arrives mirrored.
    //
    // The stock, the ink and the corner indices are the same whatever the card
    // is; only the middle differs, and it differs the way a real deck differs -
    // pips on the numbers, a portrait on the court.
    Rectangle {
        anchors.fill: parent
        visible: root.flip >= 90
        radius: root.width * 0.08
        color: root.stock
        border.width: 1
        // Gold all the way round on a court card. A number card is edged in a
        // shadow because ivory stock on dark cloth needs separating from it; a
        // black card on dark cloth needs the opposite, an edge with some light
        // in it, or the card has no outline at all and reads as a hole in the
        // table. It also closes the set: the gold on the edge, the two gold
        // lines round the panel, and the gold rule at the waist are the same
        // frame at three depths.
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

        // The corner index, top left. Rank over suit, the way a real card is
        // printed, so it still reads when the cards are fanned and overlapping.
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.width * 0.09
            anchors.topMargin: root.width * 0.07
            spacing: -root.width * 0.04

            Text {
                // Not on a court card. The rank on a dealt card is what it is
                // worth and has to be legible from under the card next to it,
                // which is the whole reason the index is printed twice in
                // opposite corners. A seat card is worth nothing and is never in
                // a fanned hand you are reading values off - the letter there
                // was only ever your initial, and the name is set in gold
                // underneath the card in type four times the size.
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
                // A shade larger once it is alone in the corner, so the corner
                // still has something in it rather than a stray mark.
                font.pixelSize: root.width * (root.court ? 0.24 : 0.20)
            }
        }

        // And the same again, upside down in the opposite corner.
        Column {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.width * 0.09
            anchors.bottomMargin: root.width * 0.07
            spacing: -root.width * 0.04
            rotation: 180

            Text {
                // Not on a court card. The rank on a dealt card is what it is
                // worth and has to be legible from under the card next to it,
                // which is the whole reason the index is printed twice in
                // opposite corners. A seat card is worth nothing and is never in
                // a fanned hand you are reading values off - the letter there
                // was only ever your initial, and the name is set in gold
                // underneath the card in type four times the size.
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
                // A shade larger once it is alone in the corner, so the corner
                // still has something in it rather than a stray mark.
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
            width: root.width * 0.66
            height: root.height * 0.70

            // The panel itself: the stock darkened, so it reads as a recess cut
            // into the card rather than as a box drawn on top of it. With the
            // middle left empty that difference is the whole panel - a black
            // rectangle the same black as the card is not there at all.
            Rectangle {
                anchors.fill: parent
                color: Qt.darker(root.stock, 1.45)
                border.width: 1
                border.color: Palette.alpha(Palette.gold, 0.65)
            }

            // The gold line inside it. Two lines rather than one because the
            // card back has a gold frame in the same place, so a card that turns
            // over keeps its proportions and only changes what is inside them.
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

                    // The panel is left empty on purpose, and this is where the
                    // portrait would go.
                    //
                    // An avatar was the obvious thing and it is the wrong thing:
                    // almost no machine has an icon for its users, so the common
                    // case is a fallback pretending to be a design, and on the
                    // machine that does have one it is a snapshot dropped into an
                    // engraved card - the only element on this table that came
                    // from outside the room. A big monogram was the next obvious
                    // thing and it is only slightly less wrong, because the
                    // corner indices already carry that letter twice and a third
                    // copy of it at four times the size is the card shouting.
                    //
                    // So: the frame, the rule, the suit, and nothing in the
                    // middle. The room is two colours and mostly empty; the card
                    // that stands for the room should be too.
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

                // The lower half: the same one again, turned over. Not a
                // continuation of the upper half and not a reflection of it -
                // the identical printing rotated 180, which is how a real court
                // card is made and why one is the right way up from either side
                // of the table.
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
