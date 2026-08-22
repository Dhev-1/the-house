import QtQuick
import "Palette.js" as Palette

// The Door — an SDDM greeter.
//
// The conceit is that logging in is a hand of blackjack. You are a card, your
// password is a bet: every character you type drops a clay chip onto a stack,
// and pressing enter pushes the bet into the pot and deals. Get it right and
// the hand is twenty-one. Get it wrong and it is seventeen, the house makes you
// take a third card, and you bust.
//
// Deliberately not connected to the four tables the desktop inside can wear.
// See Palette.js for why.
//
// Layout, top to bottom: the marquee (house name and clock), the players' cards
// (one per account, fanned, face up on the selected one), the pit (betting
// circle, bet, and where the showdown lands), and the lacquered rail carrying
// the session plaque and the power chips.
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

    // Everything on this screen is laid out in pixels against a 1080p table and
    // then multiplied by this. A greeter is the one surface with no user, no
    // session and therefore no scale factor to inherit - it gets whatever panel
    // the machine happens to have - so a fixed layout is a layout that is tiny
    // on a 4K monitor and clipped on a laptop. Clamped at both ends: past 1.6
    // the cards stop reading as cards and start reading as posters.
    readonly property real u: Math.max(0.8, Math.min(1.6, height / 1080))

    // --- configuration --------------------------------------------------------
    // theme.conf, with a working default for every key so the theme still runs
    // if the file is missing (which is what happens when someone copies just
    // the qml out of here).
    readonly property string face: config.fontFamily || "JetBrainsMono Nerd Font"
    readonly property bool clock24h: (config.clock24h || "true") === "true"
    readonly property bool showdown: (config.showdown || "true") === "true"
    // "10,4,9,7,5" -> [10, 4, 9, 7, 5]. Anything that does not parse to a
    // positive number is dropped, and an empty result falls back to the default
    // shape, so a typo in theme.conf costs the arrangement rather than the
    // password field.
    //
    // Forced through a string first, and that is not belt and braces. Every
    // other key here arrives as a string, but SDDM splits any value with a comma
    // in it into a list before the theme ever sees it - so this one key comes
    // back as a list of "10", "4", ... with no .split on it, the binding throws
    // TypeError, and the property is left undefined rather than defaulted.
    // ChipStack then cannot read .length of it and the bet renders as nothing at
    // all: no chips, no missing-file warning, and the error only visible if you
    // happen to have Qt's logging pointed somewhere you can read. Stringifying
    // first collapses both shapes onto one path, because the list stringifies
    // back to exactly the "10,4,9,7,5" that was written in the file.
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

    // Whether the losing hand has taken its third card yet. The bust is two
    // beats, not one - seventeen on the table, then the card that kills it -
    // because a hand that is simply born bust is a picture, and a hand that is
    // made to take another card is a decision being made about you.
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
    // Fixed hands, not random. The whole point is that the outcome is legible
    // in half a second to anyone who has ever seen a deck: ace and a king is
    // twenty-one and there is no better hand in the game, and a seventeen that
    // gets hit is the most familiar way in the world to lose.
    //
    // Both hands open on two cards, so the deal is identical either way until
    // they turn over - nothing about the cards on their way out tells you what
    // is coming.
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
    // The card that busts it. Eight, so seventeen goes to twenty-two: over by
    // the smallest margin the hand allows, which stings more than being over by
    // six and is the closest a login screen gets to a joke about a typo.
    readonly property var bustCard: ({
            rank: "8",
            suit: "♠"
        })

    readonly property var hand: verdict === "win" ? winHand : (hit ? loseHand.concat([bustCard]) : loseHand)

    // What the pot reads once the hand is turned over. Blank until then - the
    // count is the verdict, and showing it early would give the game away
    // before the cards do.
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
        // A losing hand is not swept straight away: it sits at seventeen for a
        // beat, takes the third card, and only then does the table clear.
        if (root.phase === "denied")
            hitClock.start();
    }

    // Everything back to an empty table: chips off, cards in the muck, bet
    // cleared. Also the escape key, so a half-typed password can be abandoned
    // without holding backspace.
    function sweep(): void {
        // Every clock, not only the ones that have already fired. This used to
        // be reachable from one place - the end of a hand, by which point the
        // deal and the hit were long done - and it is now reachable from the
        // middle of one, because escape works in every phase and the stall
        // watchdog can call it with the cards still in the air. A timer left
        // running would land on the swept table a beat later and turn a card
        // over on a hand nobody is playing.
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

        // Long enough for both cards to slide out and settle - Hand.qml staggers
        // them 70ms apart with a 320ms travel, so the second lands at 390. The
        // margin on top is deliberate: this races the session starting, and a
        // reveal that begins before the cards have stopped moving reads worse
        // than one that begins a moment late.
        interval: 460
        onTriggered: {
            root.dealt = true;
            root.reveal();
        }
    }

    Timer {
        id: hitClock

        // Seventeen on the table, then the house hits it. Long enough to read
        // the two cards and understand you are not being let in yet.
        interval: 620
        onTriggered: {
            root.hit = true;
            sweepClock.start();
        }
    }

    Timer {
        id: sweepClock

        // How long the busted hand stays face up before the table is cleared.
        // Long enough to read the third card, short enough not to be a
        // punishment - you are going to be typing again in a moment.
        interval: 1500
        onTriggered: root.sweep()
    }

    Timer {
        id: stallClock

        // The dealer has to say something. Every other clock on this table
        // measures a beat in an animation; this one measures the house not
        // answering at all.
        //
        // sddm.login() hands the bet to PAM, and the only things that bring the
        // table back to `bet` are onLoginSucceeded and onLoginFailed. A PAM
        // stack that answers neither - a module blocking on a directory server
        // that is not there, a wedged sddm-helper - leaves the greeter sitting
        // in `deal` forever with nothing on screen moving. There is no second
        // login screen to fall back on and no session to alt-tab to: it is a VT
        // switch or the power button, and on a machine whose whole front door
        // this is, that is the one failure worth spending a timer on.
        //
        // Thirty seconds is past any honest PAM stack - a remote directory that
        // is going to answer has answered - and short of the point where
        // somebody decides the machine is broken and holds the button.
        interval: 30000
        onTriggered: {
            // Said plainly. This is the one message on this screen that is not
            // in character, because the person reading it needs to know the
            // machine is not broken and their password was never judged.
            root.pitBoss = "no answer from the house - the bet has been returned. try again.";
            root.sweep();
        }
    }

    Connections {
        target: sddm

        // The house answered, so the watchdog has nothing left to catch. Stopped
        // here rather than in reveal(), which is the wrong place twice over: it
        // runs on whichever of the two calls is the second one, so an answer
        // that beats the deal animation would leave the clock running for
        // another half second; and it returns early on the first call, before
        // it would ever reach the stop.
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
            // Wide tracking is what makes six lowercase letters read as signage
            // rather than as a label.
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

            // Rebuilt every second rather than bound to a ticking property: the
            // greeter can sit here for days and this is the only thing on screen
            // that has to keep time.
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
    // rest are face down, because whose machine this is is not a thing a login
    // screen should be announcing to the room.
    Item {
        id: seats

        anchors.horizontalCenter: table.horizontalCenter
        y: table.height * 0.30
        width: fan.width
        height: Math.round(200 * root.u)

        // Out of the way while the hand is being dealt: two sets of cards on a
        // table at once reads as a mess, and the showdown is the one that
        // matters at that moment.
        opacity: root.phase === "bet" ? 1 : 0.25

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Row {
            id: fan

            anchors.centerIn: parent
            // Negative, so the cards overlap the way a fan does. The corner index
            // on Card.qml is placed to survive exactly this.
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

                    // Publish the selected account outward. A Binding rather than
                    // an assignment in a signal handler, so it re-resolves if the
                    // model changes underneath us.
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

                        // A court card. Every other card on this table is one you
                        // were dealt; this one is the person sitting in front of
                        // it, and the court cards are the only ones in a deck
                        // with a person on them.
                        court: true

                        // The suit follows the seat, so every account gets a card
                        // that is recognisably its own without a photo. The rank
                        // is the account's first letter and a court card does not
                        // print it - it is set here so the card is still a whole
                        // card if `court` is ever turned off, and because the
                        // name is already spelled out in gold under the fan.
                        rank: (seatCard.realName || seatCard.name).charAt(0).toUpperCase()
                        suit: ["♠", "♥", "♦", "♣"][seatCard.index % 4]
                        // No picture: a court card carries a monogram, not a
                        // photograph. See the note in Card.qml.
                        faceUp: seatCard.chosen

                        // The chosen card is pulled out of the fan and stood
                        // slightly proud; the others lie back at a fan angle.
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
    // The betting circle, the bet standing in it, and where the showdown lands.
    // All three share this spot on the cloth and take turns: chips are pushed
    // into the pot, then the cards come out over them.
    Item {
        id: pit

        anchors.horizontalCenter: table.horizontalCenter
        y: table.height * 0.60
        width: Math.round(460 * root.u)
        height: Math.round(200 * root.u)

        // The circle. An ellipse, not a circle: everything else in this room is
        // drawn as though seen from a player's chair, including the chips, and a
        // true circle here would be the one thing lying flat.
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

        // The instruction, inside the empty circle. Gone the moment the first
        // chip lands - it is a prompt, not a label.
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

        // What the hand came to, printed in the pot the chips just went into.
        // The same spot the bet occupied a moment ago, which is the point: you
        // put chips in, and this is what came back out.
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

        // The bet. Wrapped so the whole stack can be pushed into the pot on a
        // deal, or swept off the felt on a refusal, without ChipStack itself
        // having to know about either.
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
            // Clear of the circle, not overlapping it: the cards are the hand
            // and the circle is what it paid, and a total printed under the
            // corner of a king reads as neither.
            anchors.bottomMargin: Math.round(16 * root.u)
            fontFamily: root.face
            cardWidth: Math.round(100 * root.u)
            gap: Math.round(14 * root.u)
            cards: root.hand
            // The hand is on the table for every phase but "bet"; dropping back
            // to "bet" is what pulls the cards back off it, which is the muck.
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
        // Whatever PAM hands over is a message, not markup. The default here is
        // AutoText, which sniffs the string and quietly switches to the HTML
        // engine if it looks like tags - and that engine resolves <img src>,
        // which is a thing no string arriving at a login screen should be able
        // to ask for. The messages are root's own, so this is closing a door
        // nobody is at rather than one standing open.
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
    // The one genuinely useful warning on a login screen, and the reason people
    // stare at a password field wondering what they are typing wrong.
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
    // The actual password field, which is never seen. It holds the text and the
    // focus; the chip stack above is its only display. echoMode is still Password
    // so the string never lands in a paint buffer, and the field is one pixel of
    // fully transparent nothing rather than `visible: false` - an invisible item
    // cannot hold focus.
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

        // readOnly, not `enabled: root.phase === "bet"`, and the difference is
        // the whole of the way out of a hand.
        //
        // A disabled item is not sent key events at all - that is what disabled
        // means - so with `enabled` off this field stopped listening the instant
        // the cards went out, and the Keys.onEscapePressed below was dead in
        // precisely the phases somebody would be reaching for it. Escape only
        // worked when there was nothing to escape from. readOnly refuses the
        // edit and keeps the focus and the keys, so escape reaches sweep() from
        // any phase, and a hand that is going nowhere can be abandoned by hand
        // rather than waited out.
        readOnly: root.phase !== "bet"

        onAccepted: root.deal()

        Keys.onEscapePressed: root.sweep()

        Keys.onPressed: event => {
            // The seat and the session only move while the table is open for
            // bets. They were unreachable during a hand as a side effect of the
            // field being disabled; now that it keeps its keys, that has to be
            // said out loud, or f2 would shuffle the session under a login that
            // is already in flight.
            if (root.phase !== "bet")
                return;

            if (event.key === Qt.Key_F2) {
                root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount());
                event.accepted = true;
                return;
            }
            // Ctrl, so the plain arrows stay with the text field - moving the
            // caret in a password you cannot see is not useful, but nor is
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

    // The greeter opens with the field live, so you can start typing into a
    // screen you have only just looked at. And any click on the felt puts the
    // focus back, since losing it silently is the one failure mode a login
    // screen must not have.
    Component.onCompleted: bet.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        // Behind everything: the cards, the plaque and the chips all take their
        // clicks first.
        z: -1
        onClicked: bet.forceActiveFocus()
    }
}
