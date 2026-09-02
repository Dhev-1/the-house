import QtQuick
import "Palette.js" as Palette

// The Door — an SDDM greeter. Logging in is a hand of blackjack: every
// character typed drops a clay chip onto a stack, enter pushes the bet into the
// pot and deals. Right password and the hand is twenty-one; wrong and it is
// seventeen, the house hits you, and you bust.
//
// Not connected to the desktop's four tables - see Palette.js for why.
//
// Top to bottom: the marquee (house name and clock), the players' cards (one
// per account), the pit (betting circle, bet, showdown), and the lacquered rail
// carrying the session plaque and the power chips.
//
// Keys:
//   type            place a chip
//   backspace       take one back
//   enter           deal
//   ctrl+left/right change seat, when there is more than one account
//   f2              cycle the session
//   escape          sweep the table and start over
Rectangle {
    id: root

    // SDDM does not resize the theme to the view; the theme states its size.
    width: Screen.width
    height: Screen.height
    color: Palette.tableDeep

    // Everything here is laid out in pixels against a 1080p table and scaled by
    // this. A greeter has no user and no session, so no scale factor to inherit
    // - a fixed layout would be tiny on 4K and clipped on a laptop. Clamped at
    // both ends: past 1.6 the cards start reading as posters.
    readonly property real u: Math.max(0.8, Math.min(1.6, height / 1080))

    // --- configuration --------------------------------------------------------
    // theme.conf, with a working default for every key so the theme still runs
    // if the file is missing (which is what happens when someone copies just
    // the qml out of here).
    readonly property string face: config.fontFamily || "JetBrainsMono Nerd Font"
    readonly property bool clock24h: (config.clock24h || "true") === "true"
    readonly property bool showdown: (config.showdown || "true") === "true"
    // "10,4,9,7,5" -> [10, 4, 9, 7, 5], falling back to the default shape, so a
    // typo in theme.conf costs the arrangement rather than the password field.
    //
    // Forced through a string first because SDDM splits any comma-bearing value
    // into a list before the theme sees it - without that .split is missing, the
    // binding throws, and ChipStack renders nothing with no visible error.
    readonly property var stackHeights: {
        var spec = config.stackHeights;
        var raw = (spec === undefined || spec === null ? "" : "" + spec).split(",");
        var out = [];
        for (var i = 0; i < raw.length; ++i) {
            var n = parseInt(raw[i]);
            if (n > 0)
                out.push(n);
        }
        return out.length > 0 ? out : [10, 4, 9, 7, 5];
    }
    readonly property string houseName: config.houseName || (sddm.hostName || "the house")

    // --- state ----------------------------------------------------------------
    // bet    waiting for a password. The only state that accepts typing.
    // deal   login submitted; cards on their way out, result not in yet.
    // in     accepted. The hand is a royal flush and SDDM is starting a session.
    // denied refused. The hand is junk; the table sweeps itself in a moment.
    property string phase: "bet"

    // "" until PAM answers, then "win" or "lose". Held separately from `phase`
    // because the deal animation and the answer race each other - whichever
    // lands second calls reveal().
    property string verdict: ""
    property bool dealt: false

    // Whether the losing hand has taken its third card. The bust is two beats:
    // seventeen on the table, then the card that kills it.
    property bool hit: false

    // Which seat and which session. Both start where SDDM says they last were.
    property int seat: userModel.lastIndex
    property int sessionIndex: sessionModel.lastIndex

    // Published by the Bindings in the seat Repeater below, so the rest of the
    // theme can name the selected player without indexing into the model.
    property string seatName: ""
    property string seatRealName: ""
    property url seatIcon: ""

    // Whatever PAM last had to say ("Login failed", a password expiry warning).
    property string pitBoss: ""

    // --- the hands ------------------------------------------------------------
    // Fixed, not random, so the outcome is legible at a glance. Both open on two
    // cards, so nothing on the way out tells you what is coming.
    readonly property var winHand: [
        {
            rank: "A",
            suit: "♠"
        },
        {
            rank: "K",
            suit: "♠"
        }
    ]
    readonly property var loseHand: [
        {
            rank: "K",
            suit: "♦"
        },
        {
            rank: "7",
            suit: "♣"
        }
    ]
    // The card that busts it: eight, so seventeen goes to twenty-two.
    readonly property var bustCard: ({
            rank: "8",
            suit: "♠"
        })

    readonly property var hand: verdict === "win" ? winHand : (hit ? loseHand.concat([bustCard]) : loseHand)

    // What the pot reads once the hand turns over. Blank until then: the count
    // is the verdict, and would give it away before the cards do.
    readonly property string count: {
        if (root.phase !== "in" && root.phase !== "denied")
            return "";
        if (root.verdict === "win")
            return "21";
        return root.hit ? "22" : "17";
    }
    readonly property string countLabel: {
        if (root.verdict === "win" && root.phase === "in")
            return "BLACKJACK";
        return root.hit ? "BUST" : "";
    }

    // --- the deal -------------------------------------------------------------

    function deal(): void {
        if (root.phase !== "bet")
            return;

        root.pitBoss = "";
        root.verdict = "";
        root.dealt = false;
        root.hit = false;
        root.phase = "deal";

        if (root.showdown)
            dealClock.start();
        else
            root.dealt = true; // nothing to wait for; reveal() lands on the answer

        // Start counting. Everything from here until PAM answers is a phase the
        // table cannot leave on its own - see stallClock.
        stallClock.restart();

        sddm.login(root.seatName, bet.text, root.sessionIndex);
    }

    // Called twice - once when the cards have finished sliding out, once when
    // PAM answers - and does its work on whichever call is the second one.
    function reveal(): void {
        if (!root.dealt || root.verdict === "")
            return;
        root.phase = root.verdict === "win" ? "in" : "denied";
        // A losing hand sits at seventeen for a beat and takes its third card
        // before the table clears.
        if (root.phase === "denied")
            hitClock.start();
    }

    // Everything back to an empty table: chips off, cards in the muck, bet
    // cleared. Also the escape key, so a half-typed password can be abandoned
    // without holding backspace.
    function sweep(): void {
        // Every clock, not just the ones that have fired: escape works in any
        // phase, and one left running would land on the swept table a beat
        // later and turn a card over on a hand nobody is playing.
        dealClock.stop();
        hitClock.stop();
        sweepClock.stop();
        stallClock.stop();

        bet.text = "";
        root.verdict = "";
        root.dealt = false;
        root.hit = false;
        root.phase = "bet";
        bet.forceActiveFocus();
    }

    Timer {
        id: dealClock

        // Both cards out and settled: Hand.qml staggers them 70ms apart with a
        // 320ms travel, so the second lands at 390, plus margin.
        interval: 460
        onTriggered: {
            root.dealt = true;
            root.reveal();
        }
    }

    Timer {
        id: hitClock

        // Long enough to read seventeen before the house hits it.
        interval: 620
        onTriggered: {
            root.hit = true;
            sweepClock.start();
        }
    }

    Timer {
        id: sweepClock

        // How long the busted hand stays face up before the table clears.
        interval: 1500
        onTriggered: root.sweep()
    }

    Timer {
        id: stallClock

        // The watchdog: only onLoginSucceeded and onLoginFailed bring the table
        // back to `bet`, so a PAM stack that answers neither - a module blocking
        // on an absent directory server, a wedged sddm-helper - would leave the
        // greeter in `deal` forever with a VT switch as the only way out.
        // Thirty seconds is past any honest PAM stack.
        interval: 30000
        onTriggered: {
            // The one message here deliberately not in character: the reader
            // needs to know the machine is not broken and their password was
            // never judged.
            root.pitBoss = "no answer from the house - the bet has been returned. try again.";
            root.sweep();
        }
    }

    Connections {
        target: sddm

        // Stopped here rather than in reveal(), which returns early on its
        // first call and would leave the clock running whenever the answer
        // beats the deal animation.
        function onLoginSucceeded(): void {
            stallClock.stop();
            root.verdict = "win";
            root.reveal();
        }

        function onLoginFailed(): void {
            stallClock.stop();
            root.verdict = "lose";
            root.reveal();
        }

        function onInformationMessage(message: string): void {
            root.pitBoss = message;
        }
    }

    // --- the room -------------------------------------------------------------
    Felt {
        id: felt

        anchors.fill: parent
    }

    // Everything above the rail lives in here, so nothing has to know the rail's
    // height to centre itself in what is left.
    Item {
        id: table

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: felt.railHeight
    }

    // --- the marquee ----------------------------------------------------------
    Column {
        id: marquee

        anchors.horizontalCenter: table.horizontalCenter
        y: table.height * 0.07
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.houseName.toUpperCase()
            color: Palette.gold
            font.family: root.face
            font.pixelSize: Math.round(15 * root.u)
            // Wide tracking is what makes this read as signage, not a label.
            font.letterSpacing: 7
            font.bold: true
        }

        Text {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            color: Palette.text
            font.family: root.face
            font.pixelSize: Math.round(62 * root.u)
            font.letterSpacing: 2

            // Rebuilt every second rather than bound to a ticking property -
            // this is the only thing on screen that has to keep time.
            function tick(): void {
                text = Qt.formatTime(new Date(), root.clock24h ? "HH:mm" : "h:mm AP");
            }

            Component.onCompleted: tick()

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.tick()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dddd d MMMM").toLowerCase()
            color: Palette.muted
            font.family: root.face
            font.pixelSize: Math.round(13 * root.u)
            font.letterSpacing: 3
        }
    }

    // --- the seats ------------------------------------------------------------
    // One card per account, fanned. The selected one is face up and lifted; the
    // rest stay face down rather than announcing every account to the room.
    Item {
        id: seats

        anchors.horizontalCenter: table.horizontalCenter
        y: table.height * 0.30
        width: fan.width
        height: Math.round(200 * root.u)

        // Out of the way while the hand is dealt - the showdown is the set of
        // cards that matters at that moment.
        opacity: root.phase === "bet" ? 1 : 0.25

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Row {
            id: fan

            anchors.centerIn: parent
            // Negative, so the cards overlap. Card.qml's corner index is placed
            // to survive exactly this.
            spacing: userModel.count > 1 ? Math.round(-22 * root.u) : 0

            Repeater {
                model: userModel

                Item {
                    id: seatCard

                    required property int index
                    required property string name
                    required property string realName
                    required property string icon

                    readonly property bool chosen: index === root.seat

                    width: card.width
                    height: seats.height
                    z: chosen ? 10 : 0

                    // Publish the selected account outward. A Binding rather
                    // than an assignment, so it re-resolves if the model
                    // changes underneath us.
                    Binding {
                        target: root
                        property: "seatName"
                        value: seatCard.name
                        when: seatCard.chosen
                    }
                    Binding {
                        target: root
                        property: "seatRealName"
                        value: seatCard.realName || seatCard.name
                        when: seatCard.chosen
                    }
                    Binding {
                        target: root
                        property: "seatIcon"
                        value: seatCard.icon
                        when: seatCard.chosen
                    }

                    Card {
                        id: card

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(122 * root.u)
                        fontFamily: root.face

                        // See Card.qml's `court` for why a seat is a court card.
                        court: true

                        // The suit follows the seat, so every account gets a
                        // recognisable card without a photo. The rank is set
                        // even though a court card does not print it, so the
                        // card is still whole if `court` is turned off.
                        rank: (seatCard.realName || seatCard.name).charAt(0).toUpperCase()
                        suit: ["♠", "♥", "♦", "♣"][seatCard.index % 4]
                        faceUp: seatCard.chosen

                        // The chosen card stands proud of the fan.
                        y: seatCard.chosen ? 0 : Math.round(26 * root.u)
                        rotation: seatCard.chosen ? 0 : (seatCard.index - root.seat) * 5

                        Behavior on y {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.phase === "bet"
                        onClicked: {
                            root.seat = seatCard.index;
                            bet.text = "";
                            bet.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // The name on the gold, under the fan.
    Text {
        id: nameplate

        anchors.horizontalCenter: table.horizontalCenter
        anchors.top: seats.bottom
        anchors.topMargin: Math.round(10 * root.u)
        text: root.seatRealName.toUpperCase()
        color: Palette.goldBright
        font.family: root.face
        font.pixelSize: Math.round(16 * root.u)
        font.letterSpacing: 5
        font.bold: true
        opacity: root.phase === "bet" ? 1 : 0.3

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    // --- the pit --------------------------------------------------------------
    // The betting circle, the bet standing in it, and where the showdown lands -
    // all three share this spot on the cloth and take turns.
    Item {
        id: pit

        anchors.horizontalCenter: table.horizontalCenter
        y: table.height * 0.60
        width: Math.round(460 * root.u)
        height: Math.round(200 * root.u)

        // An ellipse, not a circle: the room is drawn from a player's chair, so
        // a true circle would be the one thing lying flat.
        Rectangle {
            id: circle

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(120 * root.u)
            width: Math.round(300 * root.u)
            height: Math.round(108 * root.u)
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.18)
            border.width: 2
            border.color: Palette.alpha(Palette.gold, 0.40)

            // The inner ring the chips actually go inside.
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(9 * root.u)
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Palette.alpha(Palette.gold, 0.22)
            }
        }

        // A prompt, not a label: gone the moment the first chip lands.
        Text {
            anchors.centerIn: circle
            text: "PLACE YOUR BET"
            color: Palette.muted
            font.family: root.face
            font.pixelSize: Math.round(12 * root.u)
            font.letterSpacing: 4
            opacity: (root.phase === "bet" && bet.text.length === 0) ? 0.75 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        // What the hand came to, printed in the spot the bet occupied a moment
        // ago: you put chips in, and this is what came back out.
        Column {
            anchors.centerIn: circle
            spacing: Math.round(2 * root.u)
            opacity: root.count.length ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.count
                color: root.verdict === "win" ? Palette.goldBright : Palette.hot
                font.family: root.face
                font.pixelSize: Math.round(40 * root.u)
                font.bold: true
                font.letterSpacing: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.countLabel
                color: root.verdict === "win" ? Palette.gold : Palette.hot
                font.family: root.face
                font.pixelSize: Math.round(11 * root.u)
                font.letterSpacing: 4
                visible: text.length > 0
            }
        }

        // The bet, wrapped so the stack can be pushed into the pot or swept off
        // the felt without ChipStack knowing about either.
        Item {
            id: betStack

            anchors.horizontalCenter: circle.horizontalCenter
            anchors.bottom: circle.verticalCenter
            anchors.bottomMargin: Math.round(-18 * root.u)
            width: chips.width
            height: chips.height

            // deal: forward into the pot and gone. denied: swept off to the left
            // by the dealer's arm. bet: sitting in the circle.
            x: root.phase === "denied" ? -520 : 0
            y: root.phase === "deal" || root.phase === "in" ? -34 : 0
            opacity: root.phase === "bet" ? 1 : 0
            rotation: root.phase === "denied" ? -14 : 0

            Behavior on x {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.InCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
            Behavior on rotation {
                NumberAnimation {
                    duration: 420
                }
            }

            ChipStack {
                id: chips

                count: bet.text.length
                stackHeights: root.stackHeights
                chipWidth: Math.round(96 * root.u)
            }
        }

        // The showdown.
        Hand {
            id: showdownHand

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: circle.top
            // Clear of the circle: a total printed under the corner of a king
            // reads as neither the hand nor the pot.
            anchors.bottomMargin: Math.round(16 * root.u)
            fontFamily: root.face
            cardWidth: Math.round(100 * root.u)
            gap: Math.round(14 * root.u)
            cards: root.hand
            // On the table for every phase but "bet"; dropping back to "bet" is
            // what pulls the cards into the muck.
            dealing: root.phase !== "bet"
            faceUp: root.phase === "in" || root.phase === "denied"
        }
    }

    // --- what the pit boss says ----------------------------------------------
    // PAM's own words, which are the only useful thing on the screen when
    // something has gone wrong that is not simply a wrong password (an expired
    // account, a locked one, no session to start).
    Text {
        anchors.horizontalCenter: table.horizontalCenter
        anchors.top: pit.bottom
        anchors.topMargin: 4
        width: table.width * 0.6
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.pitBoss
        // PAM hands over a message, not markup. The default AutoText sniffs the
        // string and switches to the HTML engine if it looks like tags, and
        // that engine resolves <img src>.
        textFormat: Text.PlainText
        color: root.phase === "denied" ? Palette.hot : Palette.muted
        font.family: root.face
        font.pixelSize: Math.round(13 * root.u)
        font.letterSpacing: 1
        opacity: text.length ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // --- caps lock ------------------------------------------------------------
    Row {
        anchors.horizontalCenter: table.horizontalCenter
        anchors.bottom: table.bottom
        anchors.bottomMargin: Math.round(18 * root.u)
        spacing: Math.round(10 * root.u)
        opacity: keyboard.capsLock ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Chip {
            width: Math.round(22 * root.u)
            height: Math.round(22 * root.u)
            body: Palette.powerChipHot.body
            spot: Palette.powerChipHot.spot
            ink: Palette.powerChipHot.ink
            spots: 6
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CAPS LOCK"
            color: Palette.hot
            font.family: root.face
            font.pixelSize: Math.round(12 * root.u)
            font.letterSpacing: 4
            font.bold: true
        }
    }

    // --- the rail -------------------------------------------------------------
    // Session on the left, power on the right, both sitting on the lacquer.
    SessionPlaque {
        id: sessionPlaque

        anchors.left: parent.left
        anchors.leftMargin: Math.round(34 * root.u)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (felt.railHeight - height) / 2
        fontFamily: root.face
        u: root.u
        index: root.sessionIndex
        onPicked: index => {
            root.sessionIndex = index;
            bet.forceActiveFocus();
        }
    }

    PowerChips {
        id: power

        anchors.right: parent.right
        anchors.rightMargin: Math.round(34 * root.u)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (felt.railHeight - height) / 2
        fontFamily: root.face
        u: root.u
    }

    // --- the keyboard ---------------------------------------------------------
    // The password field, never seen: it holds the text and the focus, and the
    // chip stack is its only display. echoMode stays Password so the string
    // never lands in a paint buffer, and it is one transparent pixel rather
    // than `visible: false`, since an invisible item cannot hold focus.
    TextInput {
        id: bet

        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password
        // A password is not text you select, drag or spell-check.
        selectByMouse: false
        activeFocusOnPress: false
        focus: true

        // readOnly, not `enabled`. A disabled item gets no key events at all,
        // so escape would be dead in precisely the phases somebody reaches for
        // it; readOnly refuses the edit but keeps the focus and the keys.
        readOnly: root.phase !== "bet"

        onAccepted: root.deal()

        Keys.onEscapePressed: root.sweep()

        Keys.onPressed: event => {
            // Said out loud because the field keeps its keys through a hand
            // (see readOnly): otherwise f2 would shuffle the session under a
            // login already in flight.
            if (root.phase !== "bet")
                return;

            if (event.key === Qt.Key_F2) {
                root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount());
                event.accepted = true;
                return;
            }
            // Ctrl, so the plain arrows stay with the text field rather than
            // stealing a key people press by reflex.
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_Left) {
                    root.seat = (root.seat - 1 + userModel.count) % userModel.count;
                    bet.text = "";
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.seat = (root.seat + 1) % userModel.count;
                    bet.text = "";
                    event.accepted = true;
                }
            }
        }
    }

    // Opens with the field live, and any click on the felt puts the focus back
    // - losing it silently is the one failure mode a login screen must not have.
    Component.onCompleted: bet.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        // Behind everything, so the cards, plaque and chips take clicks first.
        z: -1
        onClicked: bet.forceActiveFocus()
    }
}
