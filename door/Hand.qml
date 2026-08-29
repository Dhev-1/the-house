import QtQuick

// The showdown: a blackjack hand, pitched out of the shoe one card at a time.
//
// Two cards, not five, for timing rather than taste. SDDM starts the session
// the instant PAM says yes and tears the greeter down as soon as it is ready -
// on a fast machine there is under a second. Two cards deal and turn inside that
// budget; five do not, and a hand cut off halfway through its reveal reads as a
// glitch rather than a win.
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

    // One row per card on the felt, so a card's delegate survives the hand
    // growing under it.
    //
    // Binding the Repeater to `cards.length` does not: a number is a whole new
    // model every time it changes, so a Repeater handed 3 where it had 2 tears
    // down both existing delegates and rebuilds three, each running its own
    // pitch on creation - the two cards already lying face up come out of the
    // shoe a second time and turn over again.
    //
    // A list model appends instead, leaving rows 0 and 1 alone.
    //
    // The rows are empty; the hand is still read out of the `cards` array below.
    // This is a count that can grow by one without resetting, not a second copy
    // that could disagree with the first.
    ListModel {
        id: places
    }

    // Grow on a hit, and never shrink here. When the table is swept the array
    // drops back to two while the third card is still sliding off, and taking
    // its row away at that moment would snatch it off the felt mid-muck instead
    // of letting it leave with the rest of the hand. A spare row costs nothing
    // in the meantime: with `dealing` false every card in it is transparent and
    // off the table anyway.
    function place(): void {
        while (places.count < root.cards.length)
            places.append({});
    }

    // Clearing the spares is the deal's job, because the start of a deal is the
    // one moment the felt is known to be empty.
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

            // How long this card waits before it moves, so the hand comes out
            // one card at a time rather than all at once. Floored, because a row
            // that is being taken away reports an index of -1 on its way out and
            // every pause below is measured off it - without the floor that is a
            // "duration of < 0" warning per animation per removal.
            readonly property int stagger: Math.max(0, dealtCard.index) * 70

            // What this place is showing. Assigned by the Binding below rather
            // than bound directly, so that a place which has outlived its card
            // goes on showing it: the row for the bust card is still on screen
            // for the length of the muck after the hand has gone back to two,
            // and a plain binding would blank the eight of spades while it was
            // still on its way off the table.
            property var spec: ({
                    rank: "",
                    suit: "♠"
                })

            Binding {
                target: dealtCard
                property: "spec"
                value: root.cards[dealtCard.index]
                // The lower bound is not paranoia: a row being taken away
                // reports -1 first, and cards[-1] is undefined, which would
                // strip the rank and suit off a card that is still on screen.
                when: dealtCard.index >= 0 && dealtCard.index < root.cards.length
                // Leaves the last card in place instead of putting the blank
                // back when the hand shrinks.
                restoreMode: Binding.RestoreNone
            }

            // 1 while this card is still in the dealer's hand, 0 once pitched.
            // Animated on creation, so a card that appears while the hand is
            // already on the table still travels to get there - without it the
            // third card of a bust would simply materialise.
            property real entry: 1

            // Delegates outlive a hand, so a card is pitched twice: on creation,
            // which is the only way the bust card can arrive, and at the start
            // of every later deal. Without the second, `entry` is left at 0 by
            // the previous hand and every hand but the first slides out from the
            // edge of the table rather than the dealer's hand.
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

            // Face up only once this card has arrived. The bust card is dealt
            // onto a hand that is already face up, so without the entry check it
            // turns over while still crossing the table - in front of the cards
            // it is meant to land beside, reading as the wrong order.
            faceUp: root.faceUp && dealtCard.entry === 0
            // Turned over left to right rather than all at once.
            flipDelay: index * 90

            // Two independent movements on the same axis: the deal (driven by
            // `dealing`, animated by the Behavior) and the pitch of this
            // individual card (driven by `entry`). They sum, so a card can be
            // arriving while the hand as a whole is also moving.
            //
            // Which only works if they are kept apart. The seat is the behaviour'd
            // half and holds the Behavior; `entry` is written every frame by the
            // pitch below and is composed on top of it without one. Summed into a
            // single behaviour'd x, the pitch would re-trigger the Behavior on
            // every frame it moved - and since that Behavior opens with a pause,
            // each re-trigger restarts the pause, so the deal never actually got
            // under way until the pitch had finished. The two did not sum; the
            // longer one swallowed the other.
            property real seat: root.dealing ? index * (root.cardWidth + root.gap) : -360

            x: dealtCard.seat - dealtCard.entry * 300
            y: root.dealing ? 0 : 46
            opacity: root.dealing ? 1 : 0
            // A pitched card does not land perfectly square, and a hand of them
            // all at the same angle looks printed on rather than dealt.
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
