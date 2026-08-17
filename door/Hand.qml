import QtQuick

// The showdown: a blackjack hand, pitched out of the shoe one card at a time.
//
// Two cards, not five, and that is a timing decision rather than a taste one.
// SDDM starts the session the instant PAM says yes and tears the greeter down
// as soon as it is ready, so everything after a correct password is a race we
// do not control - on a fast machine there is under a second before this is
// gone. Two cards deal and turn inside that budget; five do not, and a poker
// hand cut off halfway through its reveal reads as a glitch rather than a win.
//
// A hand can also grow: a bust takes a third card after the first two are
// already face up, so the delegate has to handle a card that arrives when the
// hand is mid-deal rather than only at the start. That is what `entry` is for.
Item {
    id: root

    // [{ rank, suit }, ...]. Main.qml swaps the whole array when the verdict
    // lands, which is safe - the cards are face down at that point - and appends
    // to it when the hand is hit.
    property var cards: []

    property bool dealing: false
    property bool faceUp: false
    property string fontFamily: "JetBrainsMono Nerd Font"

    property int cardWidth: 96
    property int gap: 16

    readonly property int cardHeight: Math.round(cardWidth * 1.42)

    // Grows with the hand, and Main centres this item, so taking a third card
    // slides the first two apart to make room - which is what a dealer's hand
    // does, and it costs nothing to get for free from the layout.
    implicitWidth: cards.length * cardWidth + Math.max(0, cards.length - 1) * gap
    implicitHeight: cardHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // The model is the *count*, not the array. A Repeater bound straight to a JS
    // array throws away every delegate and builds new ones whenever the array is
    // reassigned - so the two cards already lying on the table would pitch in
    // from the shoe a second time and turn over again the moment the hand is
    // hit. Bound to the length, delegates 0 and 1 survive and only the third one
    // is created; the rank and suit still update, because reassigning `cards`
    // re-evaluates the bindings below.
    Repeater {
        model: root.cards.length

        Card {
            id: dealtCard

            required property int index

            readonly property var modelData: root.cards[index] || ({
                    rank: "",
                    suit: "♠"
                })

            // 1 while this card is still in the dealer's hand, 0 once pitched.
            // Animated on creation, so a card that appears while the hand is
            // already on the table still travels to get there - without it the
            // third card of a bust would simply materialise.
            property real entry: 1

            width: root.cardWidth
            fontFamily: root.fontFamily
            rank: modelData.rank
            suit: modelData.suit

            // Face up only once this card has actually arrived. The bust card
            // is dealt onto a hand that is already face up, so without the
            // entry check it turns over while it is still crossing the table -
            // and since it travels from the dealer's left, it spends that
            // flight in front of the cards it is meant to land beside, reading
            // as though the hand came out in the wrong order.
            faceUp: root.faceUp && dealtCard.entry === 0
            // Turned over left to right rather than all at once.
            flipDelay: index * 90

            // Two independent movements on the same axis: the deal (driven by
            // `dealing`, animated by the Behavior) and the pitch of this
            // individual card (driven by `entry`). They sum, so a card can be
            // arriving while the hand as a whole is also moving.
            x: (root.dealing ? index * (root.cardWidth + root.gap) : -360) - entry * 300
            y: root.dealing ? 0 : 46
            opacity: root.dealing ? 1 : 0
            // A pitched card does not land perfectly square, and a hand of them
            // all at the same angle looks printed on rather than dealt.
            rotation: root.dealing ? (index - 1) * 2.2 : -14

            Component.onCompleted: pitch.start()

            SequentialAnimation {
                id: pitch

                PauseAnimation {
                    duration: dealtCard.index * 70
                }
                NumberAnimation {
                    target: dealtCard
                    property: "entry"
                    from: 1
                    to: 0
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

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
