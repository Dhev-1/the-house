import QtQuick

// The showdown. Five cards pitched out of the shoe one at a time, then turned
// over together-ish once PAM has answered.
//
// The stagger is the whole effect. Five cards arriving at once is a transition;
// five cards arriving 70ms apart is a deal, because that is the rhythm a dealer
// actually pitches at. Same for the turn: they come face up left to right, so
// the hand resolves the way you read it.
Item {
    id: root

    // [{ rank, suit }, ...]. Main.qml swaps the whole array between the winning
    // and losing hands the instant the verdict lands, which is fine - the cards
    // are face down at that point and nobody has seen the old one.
    property var cards: []

    property bool dealing: false
    property bool faceUp: false
    property string fontFamily: "JetBrainsMono Nerd Font"

    property int cardWidth: 88
    property int gap: 14

    readonly property int cardHeight: Math.round(cardWidth * 1.42)

    implicitWidth: cards.length * cardWidth + Math.max(0, cards.length - 1) * gap
    implicitHeight: cardHeight + 40

    Repeater {
        model: root.cards

        Card {
            id: dealtCard

            required property int index
            required property var modelData

            width: root.cardWidth
            fontFamily: root.fontFamily
            rank: modelData.rank
            suit: modelData.suit

            faceUp: root.faceUp
            // Turned over left to right rather than all at once.
            flipDelay: index * 90

            // Out of frame to the dealer's left when there is no hand, in place
            // when there is. Everything else here follows from those two.
            x: root.dealing ? index * (root.cardWidth + root.gap) : -360
            y: root.dealing ? 0 : 46
            opacity: root.dealing ? 1 : 0
            // A pitched card does not land perfectly square, and five that do
            // look printed on rather than dealt.
            rotation: root.dealing ? (index - 2) * 1.6 : -14

            Behavior on x {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.index * 70 : 0
                    }
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on y {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.index * 70 : 0
                    }
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.index * 70 : 0
                    }
                    NumberAnimation {
                        duration: 200
                    }
                }
            }

            Behavior on rotation {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.index * 70 : 0
                    }
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
