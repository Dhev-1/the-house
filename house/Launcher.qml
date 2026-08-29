pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The deal: the app launcher as a hand of cards.
//
// A bet line and five seats. Type, and the apps that answer are pitched out of
// the shoe one at a time, left to right; the arrows walk the hand and the card
// under the selection squares up and lifts out of the fan; enter deals it in.
// With nothing typed the hand is the house regulars, so it opens on what you
// actually run.
//
// The same full-screen layer surface as ThemePicker, for the same reasons: it
// dims the desktop behind the hand, catches the click-outside, and takes
// exclusive keyboard focus while open so the bet lands without a click first.
PanelWindow {
    id: root

    // Not PanelWindow.screen directly - a hidden layer surface gets its screen
    // reassigned by the compositor, same reasoning as ThemePicker and Popups.
    required property ShellScreen monitor

    // Only on the monitor in use, or every screen deals its own hand.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name
    readonly property bool open: root.active && LauncherPanel.open

    // How far open, 0..1. The scrim and the table animate off this.
    property real reveal: root.open ? 1 : 0

    // The bet, and everything that falls out of it. The TextInput owns the
    // string - one source of truth, so there is no way for the caret and the
    // hand to disagree about what has been typed.
    readonly property string query: bet.text
    readonly property var shoe: Apps.deal(root.query)

    // A page into the matches, not the first five of them: walk off the end and
    // the table is swept for the next five, and off the end of the shoe it comes
    // back round. Every match is reachable on the arrows, and the hand is never
    // longer than a hand.
    property int page: 0

    readonly property int pages: Math.max(1, Math.ceil(root.shoe.length / Config.launcherSeats))
    readonly property var hand: root.shoe.slice(root.page * Config.launcherSeats, (root.page + 1) * Config.launcherSeats)

    // The highlighted seat within the hand on the table. Kept in range by
    // move() and reset by onQueryChanged - a hand that just shrank must not
    // leave the selection pointing at a card that is no longer there.
    property int index: 0

    // Which side the cards come in from: -1 out of the dealer's hand on the
    // left (a fresh bet, or a hand turned back), +1 in from the right (the next
    // hand). Read by every seat's pitch, so a page turn moves the same way the
    // selection was moving when it ran off the end.
    property int dealFrom: -1

    // Seat ranks and suits. Five seats, four suits, so the fifth wears the
    // first suit again - the same cycle the workspaces use.
    readonly property var ranks: ["A", "2", "3", "4", "5"]
    readonly property var suits: ["♠", "♥", "♦", "♣"]

    // ---- The tray ---------------------------------------------------------
    //
    // Your own five, tucked into the bottom-left edge. Held rather than dealt:
    // the table answers the bet, the tray does not change at all. It is the
    // corner you learn, so alt+1..5 plays one from anywhere without the caret
    // ever leaving the bet.

    readonly property real trayCardWidth: Math.round(Config.launcherCardWidth * Config.launcherTrayScale)
    readonly property real trayCardHeight: Math.round(Config.launcherCardHeight * Config.launcherTrayScale)

    // Everything inside a tray card, off the same scale as the card itself -
    // so the face grows with the card instead of a full-size card wearing
    // thumbnail furniture. At scale 1 these are the table's own numbers.
    readonly property real trayIconSize: Math.round(Config.launcherIconSize * Config.launcherTrayScale)
    readonly property int trayRadius: Math.round(10 * Config.launcherTrayScale)
    readonly property int trayInset: Math.round(4 * Config.launcherTrayScale)
    readonly property int trayPad: Math.round(8 * Config.launcherTrayScale)
    readonly property int trayIconTop: root.trayPad + Math.round(14 * Config.launcherTrayScale)

    // Floored, because past a certain point smaller type is not smaller, it is
    // unreadable - a shrunken tray should lose its text, not keep an illegible
    // version of it.
    readonly property int trayFont: Math.max(7, Math.round(9 * Config.launcherTrayScale))
    readonly property int trayPipFont: Math.max(12, Math.round(26 * Config.launcherTrayScale))

    // How far the tray has to rise to stand clear of the edge, given how much of
    // it is already showing.
    readonly property real trayFullLift: root.trayCardHeight - Config.launcherTrayPeek + Config.launcherTrayLift

    // Alt held: the whole tray comes up, full cards and names, and drops back the
    // moment you let go. This is what makes a tucked tray honest - the glance you
    // gave up by hiding the names is a quarter-second away on the same key you
    // were already pressing to play one.
    property bool peek: false

    // Where the pointer is, in window coordinates, so the tray can notice it
    // coming down to the edge. -1 while it is nowhere near.
    property real pointerY: -1
    readonly property bool nearEdge: root.pointerY >= 0 && root.pointerY > root.height - Config.launcherTrayProximity

    // The card in flight, if one is. `dragSource` is where it was picked up
    // from: -1 the table, 0..4 the tray slot, -2 nothing in hand.
    property var dragEntry: null
    property int dragSource: -2
    property real dragX: 0
    property real dragY: 0
    readonly property bool dragging: root.dragEntry !== null

    // How far the tray as a whole stands off the edge. One card hovered lifts
    // that card further on its own, below.
    readonly property real trayLift: root.peek ? root.trayFullLift : ((root.nearEdge || root.dragging) ? Config.launcherTrayNudge : 0)

    // Play a slot outright, from whatever the bet happens to be. An empty slot
    // does nothing rather than closing the launcher on a miss.
    function fire(slot: int): void {
        const entry = Apps.heldEntries[slot];
        if (!entry)
            return;
        Apps.play(entry);
        LauncherPanel.close();
    }

    // The keyboard's half of the drag: put the selected card in a slot. Deals
    // the hand again on its own, since a held app leaves the empty-bet shoe.
    function assign(slot: int): void {
        const entry = root.hand[root.index];
        if (!entry)
            return;
        Apps.hold(entry, slot);
    }

    function startDrag(entry: var, source: int, x: real, y: real): void {
        // Coordinates before the entry, so the card in flight is drawn under the
        // pointer on the first frame rather than at the origin for one of them.
        root.dragX = x;
        root.dragY = y;
        root.dragSource = source;
        root.dragEntry = entry;
    }

    // Let go. Over a slot, the card goes in it; anywhere else, a card dragged out
    // of the tray is dropped for good and one dragged off the table just goes
    // back - the table is not somewhere you can lose an app from.
    function drop(): void {
        const slot = tray.slotAt(root.dragX, root.dragY);
        if (slot >= 0)
            Apps.hold(root.dragEntry, slot);
        else if (root.dragSource >= 0)
            Apps.release(root.dragSource);
        root.cancelDrag();
    }

    function cancelDrag(): void {
        root.dragEntry = null;
        root.dragSource = -2;
    }

    screen: monitor

    // The whole screen: the scrim dims everything and catches the click-out.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "house-launcher"

    // Hold the keyboard while open so typing goes into the bet, and let go the
    // moment it shuts - a hidden surface holding focus eats every keystroke.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Present while open or still animating shut, then gone entirely.
    visible: root.active && (LauncherPanel.open || root.reveal > 0.001)

    Behavior on reveal {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onOpenChanged: {
        if (!root.open)
            return;
        // Fresh open: a clean table. The bet is cleared rather than kept,
        // because a launcher that reopens holding the last thing you typed
        // deals a hand you did not ask for and hides the regulars behind it.
        bet.text = "";
        root.page = 0;
        root.index = 0;
        root.dealFrom = -1;
        // A tray left standing up, or a card left in mid-air, because the
        // launcher closed on an alt or a drag that never got its release.
        root.peek = false;
        root.pointerY = -1;
        root.cancelDrag();
        bet.forceActiveFocus();
    }

    // Any change to the bet re-deals from the top: a new bet is a new shoe, so
    // the page it left off on means nothing, and the card the selection was
    // sitting on has moved or gone.
    onQueryChanged: {
        root.page = 0;
        root.index = 0;
        root.dealFrom = -1;
    }

    // How many cards a given page actually has. Only the last one is ever
    // short, and it is the reason the walk cannot just compare against the seat
    // count: a hand of two must turn over on the second card, not the fifth.
    function pageLength(p: int): int {
        return Math.max(0, Math.min(Config.launcherSeats, root.shoe.length - p * Config.launcherSeats));
    }

    // Turn to another hand and land on the end of it the selection is arriving
    // from. Wraps both ways, so the shoe has no ends - holding an arrow down
    // walks the whole match list and comes back round.
    function turn(delta: int): void {
        // Nothing to turn to. Without this, the page keys on a hand that is the
        // whole answer would sweep the table and deal the same five cards back.
        if (root.pages === 1)
            return;

        root.dealFrom = delta;
        root.page = (root.page + delta + root.pages) % root.pages;
        root.index = delta > 0 ? 0 : Math.max(0, root.pageLength(root.page) - 1);
    }

    // Step along the hand, turning to the next or previous one at its edges. A
    // single page wraps instead: with no second hand to deal, the selection comes
    // back round rather than sweeping five cards to replace them with the same
    // five.
    function move(delta: int): void {
        if (root.hand.length === 0)
            return;

        const next = root.index + delta;
        if (next >= 0 && next < root.hand.length) {
            root.index = next;
            return;
        }

        if (root.pages === 1) {
            root.index = next < 0 ? root.hand.length - 1 : 0;
            return;
        }

        root.turn(delta > 0 ? 1 : -1);
    }

    // Deal the highlighted card in, if there is one. An empty hand does
    // nothing: enter on a bet nobody can cover should not close the table.
    function confirm(): void {
        const entry = root.hand[root.index];
        if (!entry)
            return;
        Apps.play(entry);
        LauncherPanel.close();
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.reveal * 0.55

        // Also where the tray watches for the pointer coming down to the edge.
        // Hovering the tray itself never reaches here - the tray is above the
        // scrim and takes its own hover - which is right: by then it is already
        // up on its own account.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onClicked: LauncherPanel.close()
            onPositionChanged: mouse => root.pointerY = mouse.y
            onExited: root.pointerY = -1
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        opacity: root.reveal
        // A small rise as it opens, off the same 0..1 as the scrim.
        transform: Translate {
            y: (1 - root.reveal) * 16
        }

        // ---- The bet line -------------------------------------------------
        //
        // As wide as a full hand, whatever is actually on the table, so the
        // line does not breathe in and out as cards come and go under it.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Config.launcherSeats * Config.launcherCardWidth + (Config.launcherSeats - 1) * Config.launcherCardGap
            implicitHeight: Config.launcherBetHeight

            radius: Config.launcherBetRadius
            color: Config.colours.surface
            border.width: 1
            border.color: Config.colours.accent

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: "♠"
                    color: Config.colours.accent
                    font.family: Config.font
                    font.pointSize: 13
                }

                // The bet. It holds focus while the overlay is up, so the
                // handler below takes the keys that drive the hand and lets the
                // rest fall through as typing.
                TextInput {
                    id: bet

                    Layout.fillWidth: true

                    color: Config.colours.text
                    selectionColor: Config.colours.accent
                    selectedTextColor: Config.colours.surface
                    font.family: Config.font
                    font.pointSize: 12
                    selectByMouse: true
                    focus: true

                    // Left and right walk the hand rather than the caret. A real
                    // trade - no moving back through what you typed - and the
                    // right one for a two-character bet sitting above five cards
                    // the arrows are obviously for. Backspace still edits.
                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            LauncherPanel.close();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.confirm();
                            break;
                        case Qt.Key_Right:
                        case Qt.Key_Tab:
                            root.move(1);
                            break;
                        case Qt.Key_Left:
                        case Qt.Key_Backtab:
                            root.move(-1);
                            break;
                        // A whole hand at a time, without walking the seats to
                        // get there.
                        case Qt.Key_Down:
                        case Qt.Key_PageDown:
                            root.turn(1);
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_PageUp:
                            root.turn(-1);
                            break;
                        case Qt.Key_Home:
                            root.dealFrom = -1;
                            root.page = 0;
                            root.index = 0;
                            break;
                        case Qt.Key_End:
                            root.dealFrom = 1;
                            root.page = root.pages - 1;
                            root.index = Math.max(0, root.pageLength(root.page) - 1);
                            break;
                        // Alt on its own stands the tray up for as long as it is
                        // down. It arrives as a key press of its own, before the
                        // number that usually follows it.
                        case Qt.Key_Alt:
                            root.peek = true;
                            break;
                        // The tray's numbers. Bare, they are digits you are
                        // typing into the bet and nothing else - the modifier is
                        // what makes them slots, which is why the tray could
                        // never have been on the bare keys.
                        case Qt.Key_1:
                        case Qt.Key_2:
                        case Qt.Key_3:
                        case Qt.Key_4:
                        case Qt.Key_5:
                            {
                                const slot = event.key - Qt.Key_1;
                                // Ctrl puts the selected card in the slot, alt
                                // plays what is already there. Ctrl wins when
                                // both are down, because ctrl+alt+N is how you
                                // assign while peeking at the tray.
                                if (event.modifiers & Qt.ControlModifier)
                                    root.assign(slot);
                                else if (event.modifiers & Qt.AltModifier)
                                    root.fire(slot);
                                else
                                    return; // typing
                            }
                            break;
                        default:
                            return; // typing
                        }
                        event.accepted = true;
                    }

                    // The other half of the peek. Without this the tray stays up
                    // after the alt that raised it, which turns a glance into a
                    // mode you have to get back out of.
                    Keys.onReleased: event => {
                        if (event.key !== Qt.Key_Alt)
                            return;
                        root.peek = false;
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: bet.text === ""
                        text: "place your bets"
                        color: Config.colours.subtext
                        font.family: Config.font
                        font.pointSize: 12
                    }
                }

                // Where in the shoe this hand is. Silent when the matches all
                // fit on the table, so it only ever means "there is more, and
                // the arrows will get you there".
                Text {
                    visible: root.pages > 1
                    text: `hand ${root.page + 1}/${root.pages}`
                    color: Config.colours.subtext
                    font.family: Config.font
                    font.pointSize: 9
                }
            }
        }

        // ---- The hand -----------------------------------------------------
        //
        // Wide enough for the cards on the table and no wider, so a two-card
        // hand sits centred instead of stranded at the left; the Behavior makes
        // that spread rather than jump as the bet narrows. The extra height
        // absorbs the fan's tilt and the selected card's lift.
        Item {
            id: table

            Layout.alignment: Qt.AlignHCenter

            readonly property int seats: Math.max(1, root.hand.length)

            // The table is always a full hand wide and the cards are inset into
            // it, rather than the table itself shrinking to fit them. Same
            // picture either way - but an animated implicitWidth is a layout
            // property, so spreading the hand used to re-polish the whole
            // column every frame it moved. This is an offset the seats add to
            // their own x, and the layout never hears about it.
            property real spread: (Config.launcherSeats - table.seats) * (Config.launcherCardWidth + Config.launcherCardGap) / 2

            implicitWidth: Config.launcherSeats * Config.launcherCardWidth + (Config.launcherSeats - 1) * Config.launcherCardGap
            implicitHeight: Config.launcherCardHeight + 56

            Behavior on spread {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            // A bet nobody can cover: one card face down where the hand would
            // have been, rather than an empty space that reads as the launcher
            // having failed to draw.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 30
                width: Config.launcherCardWidth
                height: Config.launcherCardHeight
                radius: 10

                visible: root.hand.length === 0
                color: Config.colours.idle
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)

                Text {
                    anchors.centerIn: parent
                    text: "no dice"
                    color: Config.colours.subtext
                    font.family: Config.font
                    font.pointSize: 10
                }
            }

            // The seats. A fixed Repeater over the seat count, not over the
            // hand: the delegates are places at the table and outlive any hand
            // dealt into them. Bound to the results, every keystroke would tear
            // five cards down, build five more, and re-pitch the lot.
            Repeater {
                model: Config.launcherSeats

                Rectangle {
                    id: card

                    required property int index

                    readonly property var entry: root.hand[card.index] ?? null
                    readonly property bool selected: card.index === root.index && card.entry
                    readonly property string suit: root.suits[card.index % root.suits.length]
                    readonly property bool redSuit: card.suit === "♥" || card.suit === "♦"
                    readonly property color suitColour: card.redSuit ? Config.colours.urgent : Config.colours.accent

                    // Checked, because an unresolvable source makes IconImage
                    // paint Qt's magenta checkerboard. Empty falls through to the
                    // suit pip below, which is also how Config.launcherIcons
                    // turns the icons off - one no-icon path, not two.
                    readonly property string iconSource: Config.launcherIcons && card.entry?.icon ? Apps.icon(card.entry.icon) : ""

                    // 1 while the card is still in the dealer's hand, 0 once it
                    // has landed. Everything about the pitch rides on this.
                    property real pitch: 1

                    // The two things that change on a beat rather than on a
                    // frame: where in the fan this seat sits, and whether there
                    // is a card in it at all. They are split out here because
                    // they are the only parts that want easing.
                    //
                    // Everything the pitch drives is composed on top of them
                    // without a Behavior of its own. A Behavior on a property
                    // that another animation is already writing every frame
                    // restarts itself every frame - it never reaches its target,
                    // it just chases it, and five cards chasing two properties
                    // each is both visibly laggy and a pile of animation
                    // machinery rebuilt 120 times a second.
                    property real fan: card.selected ? 0 : (card.index - (table.seats - 1) / 2) * Config.launcherFan
                    property real presence: card.entry ? 1 : 0

                    // A seat re-pitches whenever the app in it changes, which is
                    // what makes a keystroke read as a fresh deal rather than as
                    // five cards quietly changing their labels.
                    onEntryChanged: {
                        if (!card.entry)
                            return;
                        card.pitch = 1;
                        deal.restart();
                    }

                    Component.onCompleted: deal.start()

                    width: Config.launcherCardWidth
                    height: Config.launcherCardHeight
                    radius: 10

                    color: Config.colours.surface
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Config.colours.accent : Qt.rgba(1, 1, 1, 0.14)

                    // The seat's place at the table, plus however far the card
                    // still is from it. Independent: the hand can be spreading
                    // under a card that is still arriving.
                    x: table.spread + card.index * (Config.launcherCardWidth + Config.launcherCardGap) + card.pitch * Config.launcherPitch * root.dealFrom
                    opacity: card.presence * (1 - card.pitch * Config.launcherDealFade)

                    // The fan: pivot on the bottom edge, a few degrees per seat
                    // off-centre. The selected card stands upright and lifts out
                    // of the hand; an arriving one is still at the angle it was
                    // pitched at, leaning the way it is travelling.
                    transformOrigin: Item.Bottom
                    rotation: card.fan + card.pitch * 14 * root.dealFrom
                    y: card.selected ? 4 : 30

                    Behavior on presence {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    Behavior on fan {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    // One card at a time rather than the whole hand at once,
                    // and in the order they are travelling: a hand dealt from
                    // the right lands right to left, so the cards never appear
                    // to cross each other on the way in.
                    SequentialAnimation {
                        id: deal

                        PauseAnimation {
                            duration: (root.dealFrom > 0 ? Config.launcherSeats - 1 - card.index : card.index) * Config.launcherDealStagger
                        }

                        NumberAnimation {
                            target: card
                            property: "pitch"
                            from: 1
                            to: 0
                            duration: Config.launcherDealDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    // The inner hairline of a card face.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 7
                        color: "transparent"
                        border.width: 1
                        border.color: card.suitColour
                        opacity: 0.35
                    }

                    // Corner indices: rank over suit, mirrored bottom-right. The
                    // rank is the seat, so the fourth card is always the four -
                    // a hand, not a list drawn on cards.
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        text: `${root.ranks[card.index]}${card.suit}`
                        color: card.suitColour
                        font.family: Config.font
                        font.pointSize: 9
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 8
                        rotation: 180
                        text: `${root.ranks[card.index]}${card.suit}`
                        color: card.suitColour
                        font.family: Config.font
                        font.pointSize: 9
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: Config.launcherIconSize
                            visible: card.iconSource !== ""
                            asynchronous: true
                            source: card.iconSource
                        }

                        // No icon: the card's own pip, at the size the icon
                        // would have been.
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: card.iconSource === ""
                            text: card.suit
                            color: card.suitColour
                            font.family: Config.font
                            font.pointSize: 26
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: Config.launcherCardWidth - 20
                            text: card.entry?.name ?? ""
                            color: Config.colours.text
                            font.family: Config.font
                            font.pointSize: 9
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // What the app calls itself when it isn't its own name -
                        // "Web Browser" under Firefox. Only on the selected card:
                        // five of these at once is a paragraph, one is a label.
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: Config.launcherCardWidth - 20
                            visible: card.selected && text !== ""
                            text: card.entry?.genericName ?? ""
                            color: Config.colours.subtext
                            font.family: Config.font
                            font.pointSize: 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Hover picks the card up, click deals it in - and a press
                    // that travels far enough before it lets go is a card taken
                    // off the table to be put in the tray instead. The threshold
                    // is what keeps those two apart: a click is a click even if
                    // the mouse shifts a pixel under it.
                    MouseArea {
                        id: hit

                        property point origin

                        anchors.fill: parent
                        enabled: card.entry
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: root.index = card.index
                        onPressed: mouse => hit.origin = Qt.point(mouse.x, mouse.y)

                        onPositionChanged: mouse => {
                            if (!hit.pressed)
                                return;

                            const p = hit.mapToItem(null, mouse.x, mouse.y);
                            if (root.dragging) {
                                root.dragX = p.x;
                                root.dragY = p.y;
                                return;
                            }

                            if (Math.abs(mouse.x - hit.origin.x) + Math.abs(mouse.y - hit.origin.y) < 10)
                                return;
                            root.startDrag(card.entry, -1, p.x, p.y);
                        }

                        onReleased: {
                            if (root.dragging)
                                root.drop();
                            else
                                root.confirm();
                        }

                        onCanceled: root.cancelDrag()
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "←→ pick · ↑↓ hands · ⏎ deal · alt peek · esc fold"
            color: Config.colours.subtext
            font.family: Config.font
            font.pointSize: 8
        }
    }

    // ---- The tray ---------------------------------------------------------
    //
    // Five slots tucked into the bottom-left edge, outside the centred column
    // entirely - it is furniture, not part of the hand's layout, and the hand
    // must not move when the tray does.
    //
    // Bottom-left because it is your side of the table, and because the hint
    // line already has the bottom middle.
    Item {
        id: tray

        x: Config.launcherTrayMargin
        y: root.height - Config.launcherTrayPeek - root.trayLift

        width: Config.launcherSeats * root.trayCardWidth + (Config.launcherSeats - 1) * Config.launcherTrayGap
        height: root.trayCardHeight

        opacity: root.reveal

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // Which slot a point in window coordinates is over, or -1. Deliberately
        // generous: the gaps between the cards count as the card to their left
        // and there is slack above and below, because this is a drop target for
        // a card in flight, not a button.
        function slotAt(wx: real, wy: real): int {
            const p = tray.mapFromItem(null, wx, wy);
            if (p.y < -30 || p.y > tray.height + 30)
                return -1;
            if (p.x < 0 || p.x > tray.width)
                return -1;

            const slot = Math.floor(p.x / (root.trayCardWidth + Config.launcherTrayGap));
            return slot >= 0 && slot < Config.launcherSeats ? slot : -1;
        }

        Repeater {
            model: Config.launcherSeats

            Rectangle {
                id: slot

                required property int index

                readonly property var entry: Apps.heldEntries[slot.index] ?? null
                readonly property string suit: root.suits[slot.index % root.suits.length]
                readonly property bool redSuit: slot.suit === "♥" || slot.suit === "♦"
                readonly property color suitColour: slot.redSuit ? Config.colours.urgent : Config.colours.accent

                readonly property string iconSource: Config.launcherIcons && slot.entry?.icon ? Apps.icon(slot.entry.icon) : ""

                readonly property bool dropTarget: root.dragging && tray.slotAt(root.dragX, root.dragY) === slot.index

                // How far this card stands proud of wherever the tray as a whole
                // is sitting. One card hovered comes up on its own; when the
                // whole tray is already up, that is nothing extra to do.
                // Not readonly: the Behavior below writes it on its way to the
                // bound value, exactly as `fan` and `presence` do on the table.
                property real extra: Math.max(0, ((hover.containsMouse && slot.entry) || slot.dropTarget ? root.trayFullLift : 0) - root.trayLift)

                // 1 below the edge, 0 landed. The tray is dealt last, after the
                // table has its hand - the table, then these, so opening the
                // launcher reads as one deal that ends with your own cards.
                property real arrive: 1

                x: slot.index * (root.trayCardWidth + Config.launcherTrayGap)
                y: -slot.extra + slot.arrive * (root.trayCardHeight + Config.launcherTrayLift)

                width: root.trayCardWidth
                height: root.trayCardHeight
                radius: root.trayRadius

                // An empty slot is a card back: the tray is always five wide, so
                // you can always see there is room without having to go looking
                // for where a sixth would go.
                color: slot.entry ? Config.colours.surface : Config.colours.idle
                border.width: slot.dropTarget ? 2 : 1
                border.color: slot.dropTarget ? Config.colours.accent : Qt.rgba(1, 1, 1, slot.entry ? 0.14 : 0.08)

                Component.onCompleted: land.start()

                Connections {
                    target: root

                    function onOpenChanged(): void {
                        if (!root.open)
                            return;
                        slot.arrive = 1;
                        land.restart();
                    }
                }

                Behavior on extra {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                SequentialAnimation {
                    id: land

                    // Behind the whole table: its last card has to be pitched
                    // and landed before these start, or the deal reads as two
                    // things happening at once rather than one after the other.
                    PauseAnimation {
                        duration: Config.launcherSeats * Config.launcherDealStagger + Config.launcherDealDuration + slot.index * Config.launcherDealStagger
                    }

                    NumberAnimation {
                        target: slot
                        property: "arrive"
                        from: 1
                        to: 0
                        duration: 260
                        // Overshoots the tuck and settles back into it - a card
                        // put down, rather than a panel sliding into place.
                        easing.type: Easing.OutBack
                    }
                }

                // The hairline of a card face. Not on a card back: an empty slot
                // is a place, and a place with a face drawn on it looks broken.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.trayInset
                    radius: root.trayRadius - Math.round(3 * Config.launcherTrayScale)
                    visible: slot.entry
                    color: "transparent"
                    border.width: 1
                    border.color: slot.suitColour
                    opacity: 0.35
                }

                // The corner index, which is also the slot's number - so alt+3
                // is taught by the card itself, with nothing added to it. Above
                // the fold at rest, along with the icon: the two things you would
                // have glanced at anyway.
                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: root.trayPad
                    text: `${slot.index + 1}${slot.suit}`
                    color: slot.suitColour
                    opacity: slot.entry ? 1 : 0.4
                    font.family: Config.font
                    font.pointSize: root.trayFont
                }

                // The mirrored index, bottom-right, as on a real card. Below the
                // fold at rest - it is the full-size card's flourish, not part of
                // what the tucked strip has to carry.
                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: root.trayPad
                    visible: slot.entry
                    rotation: 180
                    text: `${slot.index + 1}${slot.suit}`
                    color: slot.suitColour
                    font.family: Config.font
                    font.pointSize: root.trayFont
                }

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.trayIconTop
                    implicitSize: root.trayIconSize
                    visible: slot.iconSource !== ""
                    asynchronous: true
                    source: slot.iconSource
                }

                // The pip stands in for a missing icon, exactly as it does on the
                // table - and for an empty slot it is the whole card back.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.trayIconTop
                    visible: slot.iconSource === ""
                    text: slot.entry ? slot.suit : "+"
                    color: slot.entry ? slot.suitColour : Config.colours.subtext
                    opacity: slot.entry ? 1 : (root.dragging ? 0.9 : 0.4)
                    font.family: Config.font
                    font.pointSize: root.trayPipFont
                }

                // Below the fold: only ever read when the tray is up, which is
                // what lets the tucked strip stay as short as it is. At full size
                // there is room for the second line the table's cards get.
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: root.trayPad
                    y: Config.launcherTrayPeek + root.trayInset
                    text: slot.entry?.name ?? ""
                    color: Config.colours.text
                    font.family: Config.font
                    font.pointSize: root.trayFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                // Same press-and-travel as the table, so a slot can be emptied
                // the way it was filled: drag the card out and drop it on the
                // scrim. Click plays it.
                MouseArea {
                    id: hover

                    property point origin

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: slot.entry ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onPressed: mouse => hover.origin = Qt.point(mouse.x, mouse.y)

                    onPositionChanged: mouse => {
                        if (!hover.pressed || !slot.entry)
                            return;

                        const p = hover.mapToItem(null, mouse.x, mouse.y);
                        if (root.dragging) {
                            root.dragX = p.x;
                            root.dragY = p.y;
                            return;
                        }

                        if (Math.abs(mouse.x - hover.origin.x) + Math.abs(mouse.y - hover.origin.y) < 10)
                            return;
                        root.startDrag(slot.entry, slot.index, p.x, p.y);
                    }

                    onReleased: {
                        if (root.dragging)
                            root.drop();
                        else if (slot.entry)
                            root.fire(slot.index);
                    }

                    onCanceled: root.cancelDrag()
                }
            }
        }
    }

    // The card in flight. Last, so it is over everything, and transparent to the
    // mouse - the press that started the drag still owns the pointer, and a
    // ghost that could be hovered would take the drop target off the tray.
    Item {
        x: root.dragX
        y: root.dragY
        visible: root.dragging
        z: 100

        Rectangle {
            // Held near its top-left corner rather than centred on the pointer,
            // so the card hangs off the cursor the way a picked-up card does and
            // does not hide the slot being aimed at.
            x: -18
            y: -14

            width: root.trayCardWidth
            height: root.trayCardHeight
            radius: root.trayRadius
            rotation: -6
            opacity: 0.92

            color: Config.colours.surface
            border.width: 1
            border.color: Config.colours.accent

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.trayIconTop
                implicitSize: root.trayIconSize
                visible: source !== ""
                asynchronous: true
                source: Config.launcherIcons && root.dragEntry?.icon ? Apps.icon(root.dragEntry.icon) : ""
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.trayPad
                y: Config.launcherTrayPeek + root.trayInset
                text: root.dragEntry?.name ?? ""
                color: Config.colours.text
                font.family: Config.font
                font.pointSize: root.trayFont
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
