import QtQuick

// The showdown: a blackjack hand, pitched out of the shoe one card at a time.
//
// Two cards, not five, for timing: SDDM starts the session the instant PAM says
// yes and tears the greeter down as soon as it is ready - under a second on a
// fast machine. Two cards deal and turn inside that budget; five do not.
//
// A hand can also grow - a bust takes a third card after the first two are
// already face up - so a delegate has to handle a card arriving mid-deal. That
// is what `entry` is for.
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

    // Grows with the hand, and Main centres this item, so a third card slides
    // the first two apart to make room.
    implicitWidth: cards.length * cardWidth + Math.max(0, cards.length - 1) * gap
    implicitHeight: cardHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // One row per card on the felt, so a delegate survives the hand growing
    // under it. Binding the Repeater to `cards.length` does not: a number is a
    // whole new model every time it changes, so a Repeater handed 3 where it had
    // 2 rebuilds all three and the two already face up come out of the shoe
    // again. A list model appends instead.
    //
    // The rows are empty - the hand is still read out of `cards` below. This is
    // a count that can grow without resetting, not a second copy of the hand.
    ListModel {
        id: places
    }

    // Grow on a hit, never shrink here: on a sweep the array drops back to two
    // while the third card is still sliding off, and taking its row away then
    // would snatch it off the felt mid-muck. A spare row is transparent and off
    // the table anyway while `dealing` is false.
    function place(): void {
        while (places.count < root.cards.length)
            places.append({});
    }

    // Clearing the spares is the deal's job - the start of a deal is the one
    // moment the felt is known to be empty.
    function reshuffle(): void {
        while (places.count > root.cards.length)
            places.remove(places.count - 1);
        root.place();
    }

    onCardsChanged: root.place()
    onDealingChanged: {
        if (root.dealing)
            root.reshuffle();
    }

    Component.onCompleted: root.reshuffle()

    Repeater {
        model: places

        Card {
            id: dealtCard

            required property int index

            // How long this card waits before it moves. Floored because a row
            // being removed reports index -1 on its way out, and every pause
            // below is measured off it - otherwise one "duration of < 0"
            // warning per animation per removal.
            readonly property int stagger: Math.max(0, dealtCard.index) * 70

            // Assigned by the Binding below rather than bound directly, so a
            // place that has outlived its card goes on showing it - the bust
            // card's row is on screen for the length of the muck after the hand
            // has gone back to two.
            property var spec: ({
                    rank: "",
                    suit: "♠"
                })

            Binding {
                target: dealtCard
                property: "spec"
                value: root.cards[dealtCard.index]
                // The lower bound is not paranoia: a row being removed reports
                // -1 first, and cards[-1] is undefined, which would strip the
                // rank and suit off a card still on screen.
                when: dealtCard.index >= 0 && dealtCard.index < root.cards.length
                // Leave the last card in place rather than restoring the blank
                // when the hand shrinks.
                restoreMode: Binding.RestoreNone
            }

            // 1 while still in the dealer's hand, 0 once pitched. Animated on
            // creation too, or the third card of a bust would materialise
            // rather than travel.
            property real entry: 1

            // Delegates outlive a hand, so a card is pitched twice: on creation
            // (the only way the bust card arrives) and at the start of every
            // later deal. Without the second, `entry` is left at 0 by the
            // previous hand and every hand but the first slides out from the
            // edge of the table.
            readonly property bool onTable: root.dealing

            onOnTableChanged: {
                if (!dealtCard.onTable)
                    return;
                dealtCard.entry = 1;
                pitch.restart();
            }

            width: root.cardWidth
            fontFamily: root.fontFamily
            rank: dealtCard.spec.rank
            suit: dealtCard.spec.suit

            // Face up only once arrived: the bust card is dealt onto a hand
            // that is already face up, so without the entry check it turns over
            // while still crossing the table.
            faceUp: root.faceUp && dealtCard.entry === 0
            // Turned over left to right rather than all at once.
            flipDelay: index * 90

            // Two independent movements on the same axis: the deal (`dealing`,
            // via the Behavior) and this card's own pitch (`entry`). They sum
            // only because they are kept apart - summed into one behaviour'd x,
            // the pitch would re-trigger the Behavior every frame, and since
            // that Behavior opens with a pause, each re-trigger restarts it and
            // the longer movement swallows the shorter.
            property real seat: root.dealing ? index * (root.cardWidth + root.gap) : -360

            x: dealtCard.seat - dealtCard.entry * 300
            y: root.dealing ? 0 : 46
            opacity: root.dealing ? 1 : 0
            // A pitched card does not land perfectly square.
            rotation: root.dealing ? (index - 1) * 2.2 : -14

            Component.onCompleted: pitch.start()

            SequentialAnimation {
                id: pitch

                PauseAnimation {
                    duration: dealtCard.stagger
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

            Behavior on seat {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.stagger : 0
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
                        duration: root.dealing ? dealtCard.stagger : 0
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
                        duration: root.dealing ? dealtCard.stagger : 0
                    }
                    NumberAnimation {
                        duration: 200
                    }
                }
            }

            Behavior on rotation {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.dealing ? dealtCard.stagger : 0
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
