pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The deal: the app launcher as a hand of cards. A bet line and five seats -
// type and the matches are pitched out of the shoe left to right, the arrows
// walk the hand, enter deals the selected card in. With nothing typed the hand
// is the house regulars.
//
// A full-screen layer surface, as ThemePicker: it dims the desktop, catches the
// click-outside, and takes exclusive keyboard focus so the bet lands without a
// click first.
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

    // The bet. The TextInput owns the string, so the caret and the hand cannot
    // disagree about what has been typed.
    readonly property string query: bet.text
    readonly property var shoe: Apps.deal(root.query)

    // A page into the matches, not the first five: walking off the end sweeps
    // the table for the next five and wraps at the end of the shoe, so every
    // match is reachable on the arrows without the hand growing.
    property int page: 0

    readonly property int pages: Math.max(1, Math.ceil(root.shoe.length / Config.launcherSeats))
    readonly property var hand: root.shoe.slice(root.page * Config.launcherSeats, (root.page + 1) * Config.launcherSeats)

    // The highlighted seat. Kept in range by move() and reset by
    // onQueryChanged, so a hand that just shrank cannot leave the selection
    // pointing at a card that is gone.
    property int index: 0

    // Which side the cards come in from: -1 from the left (a fresh bet, or a
    // hand turned back), +1 from the right (the next hand). So a page turn moves
    // the way the selection was moving when it ran off the end.
    property int dealFrom: -1

    // Seat ranks and suits. Five seats, four suits, so the fifth wears the
    // first suit again - the same cycle the workspaces use.
    readonly property var ranks: ["A", "2", "3", "4", "5"]
    readonly property var suits: ["♠", "♥", "♦", "♣"]

    // ---- The tray ---------------------------------------------------------
    // Your own five, tucked into the bottom-left edge. Held rather than dealt:
    // the table answers the bet, the tray never changes. alt+1..5 plays one
    // without the caret leaving the bet.

    readonly property real trayCardWidth: Math.round(Config.launcherCardWidth * Config.launcherTrayScale)
    readonly property real trayCardHeight: Math.round(Config.launcherCardHeight * Config.launcherTrayScale)

    // Everything inside a tray card scales with the card, so a full-size card
    // does not end up wearing thumbnail furniture.
    readonly property real trayIconSize: Math.round(Config.launcherIconSize * Config.launcherTrayScale)
    readonly property int trayRadius: Math.round(10 * Config.launcherTrayScale)
    readonly property int trayInset: Math.round(4 * Config.launcherTrayScale)
    readonly property int trayPad: Math.round(8 * Config.launcherTrayScale)
    readonly property int trayIconTop: root.trayPad + Math.round(14 * Config.launcherTrayScale)

    // Floored: past a point a shrunken tray should lose its text rather than
    // keep an illegible version of it.
    readonly property int trayFont: Math.max(7, Math.round(9 * Config.launcherTrayScale))
    readonly property int trayPipFont: Math.max(12, Math.round(26 * Config.launcherTrayScale))

    // How far the tray has to rise to stand clear of the edge, given how much of
    // it is already showing.
    readonly property real trayFullLift: root.trayCardHeight - Config.launcherTrayPeek + Config.launcherTrayLift

    // Alt held: the whole tray comes up with its names, and drops back on
    // release - the same key already used to play one.
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

    // Let go. Over a slot the card goes in it; anywhere else a card dragged out
    // of the tray is released, and one dragged off the table just goes back.
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
        // Fresh open: a clean table, so it never reopens on a hand you did not
        // ask for.
        bet.text = "";
        root.page = 0;
        root.index = 0;
        root.dealFrom = -1;
        // Clear a tray left standing, or a card left in mid-air, from a close
        // on an alt or a drag that never got its release.
        root.peek = false;
        root.pointerY = -1;
        root.cancelDrag();
        bet.forceActiveFocus();
    }

    // A new bet is a new shoe, so the page it left off on means nothing.
    onQueryChanged: {
        root.page = 0;
        root.index = 0;
        root.dealFrom = -1;
    }

    // How many cards a page actually has. Only the last is ever short, which is
    // why the walk cannot just compare against the seat count - a hand of two
    // must turn over on the second card, not the fifth.
    function pageLength(p: int): int {
        return Math.max(0, Math.min(Config.launcherSeats, root.shoe.length - p * Config.launcherSeats));
    }

    // Turn to another hand, landing on the end the selection arrives from.
    // Wraps both ways, so holding an arrow walks the whole match list.
    function turn(delta: int): void {
        // Without this, paging a hand that is the whole answer would sweep the
        // table and deal the same five cards back.
        if (root.pages === 1)
            return;

        root.dealFrom = delta;
        root.page = (root.page + delta + root.pages) % root.pages;
        root.index = delta > 0 ? 0 : Math.max(0, root.pageLength(root.page) - 1);
    }

    // Step along the hand, turning to the next or previous one at its edges. A
    // single page wraps in place instead.
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

    // Deal the highlighted card in. An empty hand does nothing rather than
    // closing the table on a miss.
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
        // Hovering the tray itself never reaches here; it takes its own hover.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onClicked: LauncherPanel.close()
            onPositionChanged: mouse => root.pointerY = mouse.y

            // Deliberately no onExited: moving onto the tray counts as leaving
            // the scrim, so clearing the reading here would drop the nudge just
            // as the pointer arrives, sliding the tray out from under it and
            // back onto the scrim - which reads near the edge and nudges it up
            // again. Leaving the last reading standing avoids the flicker;
            // onOpenChanged clears it between opens.
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
        // As wide as a full hand whatever is on the table, so the line does not
        // breathe in and out as cards come and go under it.
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

                // The bet. Holds focus while the overlay is up, so the handler
                // below takes the keys that drive the hand and lets the rest
                // fall through as typing.
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

                    // Left and right walk the hand rather than the caret, so
                    // there is no moving back through what you typed.
                    // Backspace still edits.
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
                        // Alt arrives as a press of its own, before the number
                        // that usually follows it.
                        case Qt.Key_Alt:
                            root.peek = true;
                            break;
                        // The tray's numbers. Bare, these are digits being typed
                        // into the bet - the modifier is what makes them slots.
                        case Qt.Key_1:
                        case Qt.Key_2:
                        case Qt.Key_3:
                        case Qt.Key_4:
                        case Qt.Key_5:
                            {
                                const slot = event.key - Qt.Key_1;
                                // Ctrl assigns the selected card, alt plays
                                // what is there. Ctrl wins when both are down,
                                // so ctrl+alt+N assigns while peeking.
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

                    // The other half of the peek - without this the tray stays
                    // up after the alt that raised it.
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
                // fit on the table.
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
        // The extra height absorbs the fan's tilt and the selected card's lift.
        Item {
            id: table

            Layout.alignment: Qt.AlignHCenter

            readonly property int seats: Math.max(1, root.hand.length)

            // The table stays a full hand wide and the cards are inset into it,
            // rather than the table shrinking to fit: an animated implicitWidth
            // is a layout property, so spreading the hand would re-polish the
            // whole column every frame. This offset the seats add to their own
            // x, and the layout never hears about it.
            property real spread: (Config.launcherSeats - table.seats) * (Config.launcherCardWidth + Config.launcherCardGap) / 2

            implicitWidth: Config.launcherSeats * Config.launcherCardWidth + (Config.launcherSeats - 1) * Config.launcherCardGap
            implicitHeight: Config.launcherCardHeight + 56

            Behavior on spread {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            // A bet nobody can cover: one card face down, rather than an empty
            // space that reads as a failure to draw.
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

            // A fixed Repeater over the seat count, not over the hand: the
            // delegates are places at the table and outlive any hand dealt into
            // them. Bound to the results, every keystroke would tear five cards
            // down and build five more.
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

                    // Checked: an unresolvable source makes IconImage paint Qt's
                    // magenta checkerboard. Empty falls through to the suit pip,
                    // which is also how launcherIcons turns icons off.
                    readonly property string iconSource: Config.launcherIcons && card.entry?.icon ? Apps.icon(card.entry.icon) : ""

                    // 1 while the card is still in the dealer's hand, 0 once it
                    // has landed. Everything about the pitch rides on this.
                    property real pitch: 1

                    // The only two things that want easing, so the only two with
                    // a Behavior. Everything the pitch drives is composed on top
                    // of them without one: a Behavior on a property another
                    // animation writes every frame restarts every frame, never
                    // reaching its target, just chasing it.
                    property real fan: card.selected ? 0 : (card.index - (table.seats - 1) / 2) * Config.launcherFan
                    property real presence: card.entry ? 1 : 0

                    // A seat re-pitches when the app in it changes, so a
                    // keystroke reads as a fresh deal rather than as five cards
                    // quietly changing their labels.
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
                    // off-centre. The selected card stands upright and lifts;
                    // an arriving one leans the way it is travelling.
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

                    // Staggered in the order they travel, so a hand dealt from
                    // the right lands right to left and the cards never cross.
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

                    // Corner indices, mirrored bottom-right. The rank is the
                    // seat, so the fourth card is always the four.
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

                        // "Web Browser" under Firefox. Only on the selected
                        // card: five at once is a paragraph, one is a label.
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

                    // Hover selects, click deals in, and a press that travels
                    // past the threshold becomes a drag toward the tray - the
                    // threshold is what keeps a click a click when the mouse
                    // shifts a pixel under it.
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
    // Five slots at the bottom-left edge, outside the centred column entirely,
    // so the hand does not move when the tray does.
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

        // Which slot a window-coordinate point is over, or -1. Generous on
        // purpose - this is a drop target for a card in flight, not a button.
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

                // How far this card stands proud of the tray as a whole - a
                // hovered card comes up alone, and nothing extra when the tray
                // is already up. Not readonly: the Behavior writes it on the
                // way to the bound value, as `fan` does on the table.
                property real extra: Math.max(0, ((hover.containsMouse && slot.entry) || slot.dropTarget ? root.trayFullLift : 0) - root.trayLift)

                // 1 below the edge, 0 landed. Dealt after the table's hand, so
                // opening reads as one deal ending with your own cards.
                property real arrive: 1

                x: slot.index * (root.trayCardWidth + Config.launcherTrayGap)
                y: -slot.extra + slot.arrive * (root.trayCardHeight + Config.launcherTrayLift)

                width: root.trayCardWidth
                height: root.trayCardHeight
                radius: root.trayRadius

                // An empty slot is a card back, so the tray is always visibly
                // five wide.
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

                    // Behind the whole table: its last card has to land before
                    // these start, or the deal reads as two things at once.
                    PauseAnimation {
                        duration: Config.launcherSeats * Config.launcherDealStagger + Config.launcherDealDuration + slot.index * Config.launcherDealStagger
                    }

                    NumberAnimation {
                        target: slot
                        property: "arrive"
                        from: 1
                        to: 0
                        duration: 260
                        // Overshoots the tuck and settles back into it.
                        easing.type: Easing.OutBack
                    }
                }

                // The hairline of a card face, not drawn on an empty slot.
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

                // The corner index doubles as the slot's number, so alt+3 is
                // taught by the card itself. Above the fold at rest.
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

                // The mirrored index, below the fold at rest.
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

                // The pip stands in for a missing icon, as on the table; for an
                // empty slot it is the whole card back.
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

                // Below the fold, so it is only read when the tray is up.
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

                // Same press-and-travel as the table, so a slot is emptied the
                // way it was filled. Click plays it.
                MouseArea {
                    id: hover

                    property point origin

                    // Not anchors.fill: a hit area that moves with the lift
                    // feeds back on itself - the lift slides the bottom edge
                    // past the pointer, which unhovers, which drops the card
                    // back under it, which hovers. So the area is the union of
                    // where the card rests and where it rises to, pinning the
                    // bottom edge the loop was running on.
                    x: 0
                    y: 0
                    width: slot.width
                    height: slot.height + slot.extra

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

    // The card in flight. Last, so it is over everything, and transparent to
    // the mouse - a ghost that could be hovered would take the drop target off
    // the tray.
    Item {
        x: root.dragX
        y: root.dragY
        visible: root.dragging
        z: 100

        Rectangle {
            // Held near its top-left corner rather than centred on the pointer,
            // so it does not hide the slot being aimed at.
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
