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
// With nothing typed the hand is the house regulars - the five apps Apps has
// counted most, so it opens on what you actually run.
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

    // Which five of the shoe are on the table. The hand is a page into the
    // matches rather than the first five of them: walk off the end of it and
    // the table is swept and the next five are dealt, and off the end of the
    // shoe it comes back round to the top. So every match is reachable on the
    // arrows, without the hand ever being longer than a hand.
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

    // Step along the hand, turning to the next or previous one at its edges.
    //
    // A single page still wraps, and that is a different move: there is no
    // second hand to deal, so the selection just comes back round to the other
    // end of the one on the table rather than sweeping five cards to replace
    // them with the same five.
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

    // The dim backdrop. Clicking it folds.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.reveal * 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: LauncherPanel.close()
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

                // The bet. Keys land here first - it holds focus while the
                // overlay is up - so the handler below takes the ones that
                // drive the hand and lets everything else fall through to the
                // editor as typing.
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

                    // Left and right walk the hand rather than the caret. That
                    // is a real trade - there is no moving back through what
                    // you typed - and it is the right one for a bet that is
                    // two or three characters long and sits above five cards
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
                        default:
                            return; // typing
                        }
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

            implicitWidth: table.seats * Config.launcherCardWidth + (table.seats - 1) * Config.launcherCardGap
            implicitHeight: Config.launcherCardHeight + 56

            Behavior on implicitWidth {
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
            // hand: the delegates are the places at the table, and they outlive
            // any particular hand dealt into them. Bound to the results instead,
            // every keystroke would tear five cards down and build five more,
            // and each new one would run its own pitch - the whole table coming
            // out of the shoe again for one more character typed.
            Repeater {
                model: Config.launcherSeats

                Rectangle {
                    id: card

                    required property int index

                    // The app in this seat, or nothing if the hand is short.
                    readonly property var entry: root.hand[card.index] ?? null
                    readonly property bool selected: card.index === root.index && card.entry
                    readonly property string suit: root.suits[card.index % root.suits.length]
                    readonly property bool redSuit: card.suit === "♥" || card.suit === "♦"
                    readonly property color suitColour: card.redSuit ? Config.colours.urgent : Config.colours.accent

                    // Icon by desktop-entry name, checked: an unresolvable
                    // source makes IconImage paint Qt's magenta checkerboard,
                    // so an app the theme has no icon for falls back to the
                    // suit pip below instead of drawing that.
                    //
                    // Empty is also how Config.launcherIcons turns the icons
                    // off outright - the pip is already the no-icon path, so
                    // the switch just takes every card down it rather than
                    // being a second way to draw a card face.
                    readonly property string iconSource: Config.launcherIcons && card.entry?.icon ? Quickshell.iconPath(card.entry.icon, true) : ""

                    // 1 while the card is still in the dealer's hand, 0 once it
                    // has landed. Everything about the pitch rides on this.
                    property real pitch: 1

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

                    // The seat's own place at the table, plus however far this
                    // card still is from it - on the side it is coming in from.
                    // The two are independent: the hand can be spreading under a
                    // card that is still arriving.
                    x: card.index * (Config.launcherCardWidth + Config.launcherCardGap) + card.pitch * Config.launcherPitch * root.dealFrom
                    opacity: card.entry ? 1 - card.pitch * Config.launcherDealFade : 0

                    // The fan: pivot on the bottom edge, a few degrees per seat
                    // off-centre. The selected card stands upright and lifts out
                    // of the hand; an arriving one is still at the angle it was
                    // pitched at, leaning the way it is travelling.
                    transformOrigin: Item.Bottom
                    rotation: card.selected ? 0 : (card.index - (table.seats - 1) / 2) * Config.launcherFan + card.pitch * 14 * root.dealFrom
                    y: card.selected ? 4 : 30

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    Behavior on rotation {
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

                    // Corner indices: rank over suit, mirrored bottom-right.
                    // The rank is the seat, so the fourth card is always the
                    // four - the hand reads as a hand rather than as a list
                    // that happens to be drawn on cards.
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

                    MouseArea {
                        anchors.fill: parent
                        enabled: card.entry
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Hover picks the card up, click deals it in.
                        onEntered: root.index = card.index
                        onClicked: root.confirm()
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "←→ pick · ↑↓ hands · ⏎ deal · esc fold"
            color: Config.colours.subtext
            font.family: Config.font
            font.pointSize: 8
        }
    }
}
