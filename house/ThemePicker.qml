pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The theme picker: a centred overlay of theme tiles, one per entry in
// Config.themes. Opened by the palette button in the bar or the `theme` keybind
// (shell.qml wires that IPC call to ThemePanel).
//
// Move the selection with the arrows / hjkl / number keys, or hover a tile, and
// the whole shell previews that theme live - Config.preview re-tints everything
// without writing to disk. Enter or a click keeps it (Config.setTheme persists);
// escape or a click outside reverts to the theme you started on.
//
// A full-screen layer surface: it dims the desktop behind the card and, while
// open, takes exclusive keyboard focus so the keys land here without a click.
PanelWindow {
    id: root

    // Not PanelWindow.screen directly - a hidden layer surface gets its screen
    // reassigned by the compositor, same reasoning as ClockPopout and Popups.
    required property ShellScreen monitor

    // Only on the monitor in use, or every screen pops its own copy.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name
    readonly property bool open: root.active && ThemePanel.open

    // How far open, 0..1. The scrim and card animate off this.
    property real reveal: root.open ? 1 : 0

    // The highlighted tile, and whether we're closing because a choice was
    // committed (so the close handler leaves it be) or cancelled (so it reverts).
    property int index: 0
    property bool committing: false

    readonly property int columns: 2

    // The grid scrolls: a fixed window of visibleRows rows (so ~8 tiles) shows at
    // once, the rest reached by wheel or by arrowing past the edge. Tile geometry
    // lives here because the scroll maths - which row a tile is on, how far to
    // scroll to bring it into view - is built from it.
    readonly property int tileHeight: 62
    readonly property int rowSpacing: 10
    readonly property int visibleRows: 4
    readonly property real viewportHeight: visibleRows * tileHeight + (visibleRows - 1) * rowSpacing

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
            // Fresh open: start on the saved theme, drop any stale commit flag,
            // and take focus so keys land immediately.
            root.committing = false;
            root.index = root.indexOfName(Config.themeName);
            root.ensureVisible(root.index);
            keys.forceActiveFocus();
        } else if (!root.committing) {
            // Closed without choosing - revert the live preview.
            Config.clearPreview();
        }
    }

    // A move of the selection previews that theme across the whole shell, and
    // scrolls the grid so the newly-selected tile is in view.
    onIndexChanged: {
        if (root.open)
            Config.preview(Config.themes[root.index].name);
        root.ensureVisible(root.index);
    }

    // Nudge the flickable so tile `i` sits fully inside the viewport: scroll up to
    // it if it's above the top, down to it if it's below the bottom, else leave it.
    function ensureVisible(i: int): void {
        const row = Math.floor(i / root.columns);
        const top = row * (root.tileHeight + root.rowSpacing);
        const bottom = top + root.tileHeight;
        if (top < flick.contentY)
            flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }

    function indexOfName(name: string): int {
        for (let i = 0; i < Config.themes.length; i++)
            if (Config.themes[i].name === name)
                return i;
        return 0;
    }

    // Clamp a step through the grid so the arrows can't run off the ends.
    function move(delta: int): void {
        const n = Config.themes.length;
        root.index = Math.max(0, Math.min(n - 1, root.index + delta));
    }

    function confirm(): void {
        root.committing = true;
        Config.setTheme(Config.themes[root.index].name);
        ThemePanel.close();
    }

    function cancel(): void {
        ThemePanel.close(); // onOpenChanged reverts the preview
    }

    // The dim backdrop. Clicking it (anywhere but the card) cancels.
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
                root.move(1);
                break;
            case Qt.Key_Left:
            case Qt.Key_H:
                root.move(-1);
                break;
            case Qt.Key_Down:
            case Qt.Key_J:
                root.move(root.columns);
                break;
            case Qt.Key_Up:
            case Qt.Key_K:
                root.move(-root.columns);
                break;
            case Qt.Key_Home:
                root.index = 0;
                break;
            case Qt.Key_End:
                root.index = Config.themes.length - 1;
                break;
            default:
                // 1..9 jump straight to a theme.
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const n = event.key - Qt.Key_1;
                    if (n < Config.themes.length)
                        root.index = n;
                }
                return;
            }
            event.accepted = true;
        }

        Rectangle {
            id: card

            anchors.centerIn: parent

            implicitWidth: Config.themePanelWidth
            implicitHeight: content.implicitHeight + Config.themePanelPadding * 2

            radius: Config.themePanelRadius
            color: Config.colours.surface
            border.width: 1
            border.color: Config.colours.idle

            opacity: root.reveal
            // A small rise + settle as it opens, off the same 0..1.
            scale: 0.96 + root.reveal * 0.04
            transform: Translate {
                y: (1 - root.reveal) * 10
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Config.themePanelPadding

                spacing: 10

                // Title, with the key hints trailing on the right.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Theme"
                        color: Config.colours.text
                        font.family: Config.font
                        font.pointSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "↑↓ preview · ⏎ keep · esc cancel"
                        color: Config.colours.subtext
                        font.family: Config.font
                        font.pointSize: 8
                    }
                }

                // The tiles, in a scrolling window: visibleRows rows show at once,
                // the wheel or arrowing past the edge reveals the rest, and a thin
                // thumb on the right hints there's more when the list overflows.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.viewportHeight

                    Flickable {
                        id: flick

                        anchors.fill: parent
                        clip: true

                        contentWidth: width
                        contentHeight: grid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height // nothing to flick when it all fits

                        Grid {
                            id: grid

                            width: flick.width
                            columns: root.columns
                            columnSpacing: 10
                            rowSpacing: root.rowSpacing

                            // A gutter on the right leaves room for the scroll thumb.
                            readonly property real tileWidth: (grid.width - 10 - (root.columns - 1) * columnSpacing) / root.columns

                            Repeater {
                                model: Config.themes

                                Rectangle {
                                    id: tile

                                    required property int index
                                    required property var modelData

                                    readonly property bool selected: tile.index === root.index

                                    width: grid.tileWidth
                                    implicitHeight: root.tileHeight
                                    radius: 12

                                    // The tile wears the theme it stands for.
                                    color: tile.modelData.surface
                                    border.width: tile.selected ? 2 : 1
                                    border.color: tile.selected ? tile.modelData.accent : Qt.rgba(1, 1, 1, 0.08)
                                    scale: tile.selected ? 1.03 : 1

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        anchors.topMargin: 10
                                        anchors.bottomMargin: 10
                                        spacing: 8

                                        Text {
                                            Layout.fillWidth: true
                                            text: tile.modelData.label
                                            elide: Text.ElideRight
                                            color: tile.modelData.text
                                            font.family: Config.font
                                            font.pointSize: 11
                                            font.weight: tile.selected ? Font.DemiBold : Font.Normal
                                        }

                                        // The role colours as dots, in the palette's
                                        // read order: accent, text, subtext, idle, urgent.
                                        Row {
                                            spacing: 5

                                            Repeater {
                                                model: [tile.modelData.accent, tile.modelData.text, tile.modelData.subtext, tile.modelData.idle, tile.modelData.urgent]

                                                Rectangle {
                                                    required property var modelData

                                                    width: 12
                                                    height: 12
                                                    radius: 6
                                                    color: modelData
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        // Hover previews, click keeps.
                                        onEntered: root.index = tile.index
                                        onClicked: root.confirm()
                                    }
                                }
                            }
                        }
                    }

                    // Scroll thumb: height and position track the flickable, shown
                    // only while there's something to scroll.
                    Rectangle {
                        id: thumb

                        readonly property real ratio: flick.height / Math.max(flick.contentHeight, 1)

                        visible: flick.interactive
                        width: 4
                        radius: 2
                        color: Config.colours.subtext
                        opacity: 0.4

                        anchors.right: parent.right
                        height: Math.max(24, flick.height * thumb.ratio)
                        y: flick.contentY * thumb.ratio
                    }
                }
            }
        }
    }
}
