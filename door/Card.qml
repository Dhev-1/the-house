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
    // What you are actually looking at for most of a showdown. The cards are
    // pitched face down and only turn at the very end, so the back is on screen
    // for the whole deal and the face for about a second of it - which is the
    // wrong way round from how much drawing each used to get.
    //
    // A real back is one printed pattern run edge to edge, and it has to survive
    // two things this one does. It is seen in a fanned overlap, where all you get
    // of the cards underneath is a strip down one side, so the pattern has to
    // read from any sliver of it rather than from the middle. And it is seen
    // upside down by half the table, so it is built to turn: the weave is
    // symmetric about both axes and the medallion sits dead centre, and a card
    // rotated 180 degrees is the same card.
    Rectangle {
        anchors.fill: parent
        visible: root.flip < 90
        radius: root.width * 0.08
        color: Palette.cardBack
        // A dim gold edge rather than the black one this used to have. Black on
        // black cloth gave a face-down card no outline at all - a hole in the
        // table rather than a card lying on it - and a hand of them ran together
        // into one shape. Same problem the court card's gold edge solves, same
        // fix.
        border.width: 1
        border.color: Palette.alpha(Palette.gold, 0.30)

        // The double rule. Two lines rather than one, at the same inset as the
        // two round the court panel, so a card that turns over keeps its frame
        // and changes only what is inside it.
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

        // The weave: two families of hairlines at right angles, crossing into a
        // fine diamond mesh. The same diamond as the lattice on the cloth and
        // the lozenge below, so the deck and the table are printed by the same
        // house - but woven rather than scattered.
        //
        // What was here before was twenty-four separate diamonds on a 4x6 grid,
        // each about a tenth of the card across. At the size a card actually
        // gets drawn that is not a pattern, it is two dozen specks, and in a
        // fanned hand a sliver of it showed one speck and a lot of black.
        // Crossed lines have no such problem: any strip of them is the pattern.
        Item {
            id: weave

            anchors.fill: parent
            anchors.margins: root.width * 0.105
            clip: true

            // Spacing measured along the horizontal, so the mesh the eye sees is
            // this over root two - about a sixteenth of the card, fine enough to
            // read as texture instead of as lines you could count.
            readonly property real step: root.width * 0.085

            // Long enough that a line pinned at the centre still runs past both
            // corners once it is turned, and enough of them to sweep the whole
            // diagonal extent.
            readonly property real span: (weave.width + weave.height) * 1.2

            // Floored at zero because anchors.fill plus a margin on a parent
            // that has not been sized yet gives a negative width and height, and
            // for the frame before the card gets its real size that makes the
            // count negative - which the Repeater complains about by name.
            readonly property int lines: Math.max(0, Math.ceil((weave.width + weave.height) / weave.step))

            // Each family is one Repeater of horizontal hairlines, turned as a
            // whole. Offsetting a turned line's centre along x alone still walks
            // it across the card perpendicular to itself, so there is no
            // trigonometry here beyond the rotation.
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

        // The medallion: a lozenge cut out of the weave with the house's spade
        // in it. The weave is even all over and has no centre, and a back with no
        // centre reads as wallpaper - this is what makes it a card.
        //
        // Filled with the stock rather than left transparent, so it masks the
        // hairlines running underneath instead of sitting on top of them.
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

            // Always the spade, never this card's own suit. A back that told you
            // anything about the face in front of it would be a marked deck, and
            // the spade is the house's own mark - the same one on the button that
            // opens the table picker inside.
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
            id: topIndex

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

            // Narrow enough to pass between the two corner indices rather than
            // through them, which is what a fixed fraction of the width did: the
            // panel's top-left corner landed inside the suit in the top-left
            // corner and the gold line ran straight across the glyph.
            //
            // Measured off the index rather than guessed at, because the suits
            // are symbol glyphs and how wide one actually is depends on which
            // font fontconfig hands back - a number that looks clear against
            // JetBrains Mono is not clear against whatever a machine without it
            // falls back to. The floor is there so a pathologically wide glyph
            // gives a cramped panel rather than a negative one.
            //
            // Only the width has to give. Clearing them vertically instead would
            // mean a panel little more than half the card tall, and the tall
            // narrow cartouche is what makes this read as a court card at all.
            width: Math.max(root.width * 0.30, root.width - 2 * (root.width * 0.09 + topIndex.width + root.width * 0.035))
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
