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

    // Hearts and diamonds are red. The one rule the whole deck runs on.
    readonly property color inkColour: (suit === "♥" || suit === "♦") ? Palette.cardRed : Palette.cardInk

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
    Rectangle {
        anchors.fill: parent
        visible: root.flip >= 90
        radius: root.width * 0.08
        color: Palette.ivory
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)

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
                text: root.rank
                color: root.inkColour
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.26
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suit
                color: root.inkColour
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.20
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
                text: root.rank
                color: root.inkColour
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.26
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suit
                color: root.inkColour
                font.family: root.fontFamily
                font.pixelSize: root.width * 0.20
            }
        }

        // The middle: an avatar if the card has one, the suit pip if not.
        Text {
            anchors.centerIn: parent
            visible: avatar.status !== Image.Ready
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
            visible: status === Image.Ready
            asynchronous: true
            // Absent avatars are the norm, not a fault; the pip above covers it.
            onStatusChanged: {}
        }
    }
}
