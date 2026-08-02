pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The table picker: a dealt hand of cards, one per entry in Config.themes,
// opened by the ♠ button in the bar or the `theme` keybind (shell.qml wires
// that IPC call to ThemePanel).
//
// Each card wears the table it stands for - its surface, its accent, its suit -
// fanned like a hand the dealer just spread. Move the selection with the
// arrows / hjkl / number keys, or hover a card, and the whole shell previews
// that table live - Config.preview re-tints everything without writing to
// disk. Enter or a click keeps it (Config.setTheme persists); escape or a
// click outside reverts to the table you started on.
//
// A full-screen layer surface: it dims the desktop behind the hand and, while
// open, takes exclusive keyboard focus so the keys land here without a click.
PanelWindow {
    id: root

    // Not PanelWindow.screen directly - a hidden layer surface gets its screen
    // reassigned by the compositor, same reasoning as ClockPopout and Popups.
    required property ShellScreen monitor

    // Only on the monitor in use, or every screen pops its own copy.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name
    readonly property bool open: root.active && ThemePanel.open

    // How far open, 0..1. The scrim and the hand animate off this.
    property real reveal: root.open ? 1 : 0

    // The highlighted card, and whether we're closing because a choice was
    // committed (so the close handler leaves it be) or cancelled (so it reverts).
    property int index: 0
    property bool committing: false

    // The hand: card geometry and the fan's spread. The fan pivots each card
    // around its bottom edge by a few degrees per seat off-centre.
    readonly property int cardWidth: 96
    readonly property int cardHeight: 140
    readonly property int cardSpacing: 14
    readonly property real fanDegrees: 4

    // Each table's suit, in bridge order like the workspaces; more tables than
    // suits just cycle. Red suits are drawn in the table's own red.
    readonly property var suits: ["♠", "♣", "♦", "♥"]

    screen: monitor

    // Cover the whole screen: the scrim dims everything and catches the
    // click-outside-to-cancel.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Above the bar and everything else, like the notification stack.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "house-theme"

    // Grab the keyboard while open so the arrows and enter reach us without a
    // click; release it when shut so we're not holding focus off-screen.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Present while open or still animating shut, then gone so it stops being a
    // surface at all.
    visible: root.active && (ThemePanel.open || root.reveal > 0.001)

    Behavior on reveal {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onOpenChanged: {
        if (root.open) {
            // Fresh open: start on the saved table, drop any stale commit flag,
            // and take focus so keys land immediately.
            root.committing = false;
            root.index = root.indexOfName(Config.themeName);
            keys.forceActiveFocus();
        } else if (!root.committing) {
            // Closed without choosing - revert the live preview.
            Config.clearPreview();
        }
    }

    // A move of the selection previews that table across the whole shell.
    onIndexChanged: {
        if (root.open)
            Config.preview(Config.themes[root.index].name);
    }

    function indexOfName(name: string): int {
        for (let i = 0; i < Config.themes.length; i++)
            if (Config.themes[i].name === name)
                return i;
        return 0;
    }

    // Clamp a step along the hand so the arrows can't run off the ends.
    function move(delta: int): void {
        const n = Config.themes.length;
        root.index = Math.max(0, Math.min(n - 1, root.index + delta));
    }

    function confirm(): void {
        root.committing = true;
        Config.playSound("card-flick.wav");
        Config.setTheme(Config.themes[root.index].name);
        ThemePanel.close();
    }

    function cancel(): void {
        ThemePanel.close(); // onOpenChanged reverts the preview
    }

    // The dim backdrop. Clicking it (anywhere but a card) cancels.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.reveal * 0.5

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Keyboard lands here. focus is taken in onOpenChanged; forwarding to the
    // window's content item isn't needed since we hold exclusive focus.
    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.cancel();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.confirm();
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Down:
            case Qt.Key_J:
                root.move(1);
                break;
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Up:
            case Qt.Key_K:
                root.move(-1);
                break;
            case Qt.Key_Home:
                root.index = 0;
                break;
            case Qt.Key_End:
                root.index = Config.themes.length - 1;
                break;
            default:
                // 1..9 jump straight to a card.
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const n = event.key - Qt.Key_1;
                    if (n < Config.themes.length)
                        root.index = n;
                }
                return;
            }
            event.accepted = true;
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            opacity: root.reveal
            // A small rise + settle as it opens, off the same 0..1.
            transform: Translate {
                y: (1 - root.reveal) * 14
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "pick your table"
                color: "#e8e2d0"
                font.family: Config.font
                font.pointSize: 13
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: "#000000"
            }

            // The hand. Extra height absorbs the fan's tilt and the selected
            // card's lift, so nothing clips or crowds the hint below.
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: hand.implicitWidth
                implicitHeight: root.cardHeight + 64

                Row {
                    id: hand

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.cardSpacing

                    Repeater {
                        model: Config.themes

                        Rectangle {
                            id: card

                            required property int index
                            required property var modelData

                            readonly property bool selected: card.index === root.index
                            readonly property string suit: root.suits[card.index % root.suits.length]
                            readonly property bool redSuit: suit === "♥" || suit === "♦"
                            readonly property color suitColour: redSuit ? card.modelData.urgent : card.modelData.accent

                            width: root.cardWidth
                            height: root.cardHeight
                            radius: 10

                            // The card wears the table it stands for.
                            color: card.modelData.surface
                            border.width: card.selected ? 2 : 1
                            border.color: card.selected ? card.modelData.accent : Qt.rgba(1, 1, 1, 0.14)

                            // The fan: pivot around the bottom edge, a few degrees
                            // per seat off-centre; the chosen card stands upright
                            // and lifts out of the hand. Row only manages x, so
                            // the lift rides on y (anchors are off-limits inside
                            // a positioner).
                            transformOrigin: Item.Bottom
                            rotation: card.selected ? 0 : (card.index - (Config.themes.length - 1) / 2) * root.fanDegrees
                            y: card.selected ? 10 : 36

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

                            // Corner indices: suit top-left, mirrored bottom-right.
                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 8
                                text: card.suit
                                color: card.suitColour
                                font.family: Config.font
                                font.pointSize: 10
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 8
                                rotation: 180
                                text: card.suit
                                color: card.suitColour
                                font.family: Config.font
                                font.pointSize: 10
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                // The big centre pip.
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: card.suit
                                    color: card.suitColour
                                    font.family: Config.font
                                    font.pointSize: 26
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.cardWidth - 20
                                    Layout.maximumWidth: root.cardWidth - 20
                                    text: card.modelData.label
                                    color: card.modelData.text
                                    font.family: Config.font
                                    font.pointSize: 8
                                    font.weight: card.selected ? Font.DemiBold : Font.Normal
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // The role colours as chips: accent, text, subtext,
                                // idle, urgent.
                                Row {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4

                                    Repeater {
                                        model: [card.modelData.accent, card.modelData.text, card.modelData.subtext, card.modelData.idle, card.modelData.urgent]

                                        Rectangle {
                                            required property var modelData

                                            width: 9
                                            height: 9
                                            radius: 4.5
                                            color: modelData
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Hover previews, click keeps.
                                onEntered: root.index = card.index
                                onClicked: root.confirm()
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "←→ preview · ⏎ keep · esc fold"
                color: "#9a917e"
                font.family: Config.font
                font.pointSize: 8
                style: Text.Raised
                styleColor: "#000000"
            }
        }
    }
}
