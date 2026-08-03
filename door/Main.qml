import QtQuick

// The Door — an SDDM greeter.
//
// The conceit is that logging in is a hand of cards. You are a card, the
// session is a card, your password is a bet: every character you type drops a
// clay chip onto a stack, and pressing enter pushes the bet into the pot and
// deals a showdown. Get in and it is a royal flush. Get it wrong and the hand
// is mucked and the table is swept.
//
// Deliberately not connected to the four tables the desktop inside can wear.
// See Palette.qml for why.
//
// Layout, top to bottom: the marquee (house name and clock), the players' cards
// (one per account, fanned, face up on the selected one), the pit (betting
// circle, bet, and where the showdown lands), and the mahogany rail carrying
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
    color: Palette.feltDeep

    // --- configuration --------------------------------------------------------
    // theme.conf, with a working default for every key so the theme still runs
    // if the file is missing (which is what happens when someone copies just
    // the qml out of here).
    readonly property string face: config.fontFamily || "JetBrainsMono Nerd Font"
    readonly property bool clock24h: (config.clock24h || "true") === "true"
    readonly property bool showdown: (config.showdown || "true") === "true"
    readonly property int maxStack: parseInt(config.maxStack || "14")
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
    // Fixed hands, not random: the point is that the outcome is legible in half
    // a second by anyone who has seen a deck before. A royal flush in spades is
    // the best hand there is; seven-two off is famously the worst, and the rest
    // of the losing hand is chosen to miss every draw.
    readonly property var winHand: [
        {
            rank: "A",
            suit: "♠"
        },
        {
            rank: "K",
            suit: "♠"
        },
        {
            rank: "Q",
            suit: "♠"
        },
        {
            rank: "J",
            suit: "♠"
        },
        {
            rank: "10",
            suit: "♠"
        }
    ]
    readonly property var loseHand: [
        {
            rank: "7",
            suit: "♦"
        },
        {
            rank: "2",
            suit: "♣"
        },
        {
            rank: "9",
            suit: "♥"
        },
        {
            rank: "4",
            suit: "♠"
        },
        {
            rank: "J",
            suit: "♦"
        }
    ]
    readonly property var hand: verdict === "win" ? winHand : loseHand

    // --- the deal -------------------------------------------------------------

    function deal(): void {
        if (root.phase !== "bet")
            return;

        root.pitBoss = "";
        root.verdict = "";
        root.dealt = false;
        root.phase = "deal";

        if (root.showdown)
            dealClock.start();
        else
            root.dealt = true; // nothing to wait for; reveal() lands on the answer

        sddm.login(root.seatName, bet.text, root.sessionIndex);
    }

    // Called twice - once when the cards have finished sliding out, once when
    // PAM answers - and does its work on whichever call is the second one.
    function reveal(): void {
        if (!root.dealt || root.verdict === "")
            return;
        root.phase = root.verdict === "win" ? "in" : "denied";
        if (root.phase === "denied")
            sweepClock.start();
    }

    // Everything back to an empty table: chips off, cards in the muck, bet
    // cleared. Also the escape key, so a half-typed password can be abandoned
    // without holding backspace.
    function sweep(): void {
        bet.text = "";
        root.verdict = "";
        root.dealt = false;
        root.phase = "bet";
        bet.forceActiveFocus();
    }

    Timer {
        id: dealClock

        // Long enough for five cards to slide out and settle - Hand.qml staggers
        // them 70ms apart with a 320ms travel, so the last one lands at 600.
        interval: 620
        onTriggered: {
            root.dealt = true;
            root.reveal();
        }
    }

    Timer {
        id: sweepClock

        // How long a losing hand stays face up before the table is cleared. Long
        // enough to read the cards, short enough not to be a punishment.
        interval: 1600
        onTriggered: root.sweep()
    }

    Connections {
        target: sddm

        function onLoginSucceeded(): void {
            root.verdict = "win";
            root.reveal();
        }

        function onLoginFailed(): void {
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
            color: Palette.brass
            font.family: root.face
            font.pixelSize: 15
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
            font.pixelSize: 62
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
            font.pixelSize: 13
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
        y: table.height * 0.28
        width: fan.width
        height: 190

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
            spacing: userModel.count > 1 ? -22 : 0

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
                        width: 104
                        fontFamily: root.face

                        // The rank is the first letter of the account name and
                        // the suit follows the seat, so every player gets a card
                        // that is recognisably theirs without a photo.
                        rank: (seatCard.realName || seatCard.name).charAt(0).toUpperCase()
                        suit: ["♠", "♥", "♦", "♣"][seatCard.index % 4]
                        picture: seatCard.chosen ? seatCard.icon : ""
                        faceUp: seatCard.chosen

                        // The chosen card is pulled out of the fan and stood
                        // slightly proud; the others lie back at a fan angle.
                        y: seatCard.chosen ? 0 : 26
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

    // The name on the brass, under the fan.
    Text {
        id: nameplate

        anchors.horizontalCenter: table.horizontalCenter
        anchors.top: seats.bottom
        anchors.topMargin: 10
        text: root.seatRealName.toUpperCase()
        color: Palette.brassBright
        font.family: root.face
        font.pixelSize: 16
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
        y: table.height * 0.70
        width: 460
        height: 200

        // The circle. An ellipse, not a circle: everything else in this room is
        // drawn as though seen from a player's chair, including the chips, and a
        // true circle here would be the one thing lying flat.
        Rectangle {
            id: circle

            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            width: 300
            height: 108
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.18)
            border.width: 2
            border.color: Qt.rgba(Palette.brass.r, Palette.brass.g, Palette.brass.b, 0.40)

            // The inner ring the chips actually go inside.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 9
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Palette.brass.r, Palette.brass.g, Palette.brass.b, 0.22)
            }
        }

        // The instruction, inside the empty circle. Gone the moment the first
        // chip lands - it is a prompt, not a label.
        Text {
            anchors.centerIn: circle
            text: "PLACE YOUR BET"
            color: Palette.muted
            font.family: root.face
            font.pixelSize: 12
            font.letterSpacing: 4
            opacity: (root.phase === "bet" && bet.text.length === 0) ? 0.75 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        // The bet. Wrapped so the whole stack can be pushed into the pot on a
        // deal, or swept off the felt on a refusal, without ChipStack itself
        // having to know about either.
        Item {
            id: betStack

            anchors.horizontalCenter: circle.horizontalCenter
            anchors.bottom: circle.verticalCenter
            anchors.bottomMargin: -18
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
                maxStack: root.maxStack
                chipWidth: 84
            }
        }

        // The showdown.
        Hand {
            id: showdownHand

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: circle.top
            anchors.bottomMargin: -30
            fontFamily: root.face
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
        color: root.phase === "denied" ? Palette.hot : Palette.muted
        font.family: root.face
        font.pixelSize: 13
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
        anchors.bottomMargin: 18
        spacing: 10
        opacity: keyboard.capsLock ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Chip {
            width: 22
            height: 22
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
            font.pixelSize: 12
            font.letterSpacing: 4
            font.bold: true
        }
    }

    // --- the rail -------------------------------------------------------------
    // Session on the left, power on the right, both sitting on the mahogany.
    SessionPlaque {
        id: sessionPlaque

        anchors.left: parent.left
        anchors.leftMargin: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (felt.railHeight - height) / 2
        fontFamily: root.face
        index: root.sessionIndex
        onPicked: index => {
            root.sessionIndex = index;
            bet.forceActiveFocus();
        }
    }

    PowerChips {
        id: power

        anchors.right: parent.right
        anchors.rightMargin: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (felt.railHeight - height) / 2
        fontFamily: root.face
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
        enabled: root.phase === "bet"

        onAccepted: root.deal()

        Keys.onEscapePressed: root.sweep()

        Keys.onPressed: event => {
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
