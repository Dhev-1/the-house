pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// The card the clock opens: a big time+date read-out on left-click, a month
// calendar on right-click. It hangs off the bar next to the clock and slides
// out to the left.
//
// A separate layer surface from the bar because the bar is only barWidth wide -
// anything reaching in from it has to be its own window. State comes from the
// ClockPanel singleton, which the clock in the bar pokes.
PanelWindow {
    id: root

    // Not PanelWindow.screen directly - a hidden layer surface gets its screen
    // reassigned by the compositor, same reasoning as Popups.
    required property ShellScreen monitor

    // Only on the monitor being used, or every screen pops its own copy.
    readonly property bool active: Hyprland.focusedMonitor?.name === root.monitor.name
    readonly property bool open: root.active && ClockPanel.mode !== "none"

    // Which view to draw. Held through the close animation so the card doesn't
    // blank out as it slides away, and updated on a mode switch while open (a
    // right-click while the time is showing, say) - open doesn't change then, so
    // onOpenChanged alone wouldn't catch it.
    property string view: "time"

    // How far open, 0..1. Everything visible animates off this.
    property real reveal: root.open ? 1 : 0

    screen: monitor

    anchors.right: true
    anchors.bottom: true

    // Against the bar, resting on the bottom bar so the card's foot sits just
    // above it, by the clock.
    margins.right: Config.barWidth
    margins.bottom: Config.bottomBarWidth

    // Fixed so the surface isn't resized as the card animates or the view swaps.
    // Tall enough for the calendar; the shorter time card just anchors to the
    // bottom of the same canvas.
    implicitWidth: Config.clockPanelWidth
    implicitHeight: 320

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-clock"

    // Present while open or still animating shut, then gone so it stops being a
    // surface at all.
    visible: root.active && (ClockPanel.mode !== "none" || root.reveal > 0.001)

    Behavior on reveal {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // The transparent canvas is bigger than the card, so mask only the card or
    // it eats clicks meant for the desktop. Zero size while shut = no mask.
    mask: Region {
        x: card.x
        y: card.y
        width: root.reveal > 0.001 ? card.width : 0
        height: root.reveal > 0.001 ? card.height : 0
    }

    Connections {
        target: ClockPanel

        function onModeChanged(): void {
            if (ClockPanel.mode === "calendar")
                root.monthOffset = 0; // always open on the current month
            if (ClockPanel.mode !== "none")
                root.view = ClockPanel.mode;
        }
    }

    // Ticks only while the card is up: the bar has its own clock for the time it
    // always shows, this one is just for the seconds and the live date in here.
    SystemClock {
        id: clock

        enabled: root.visible
        precision: SystemClock.Seconds
    }

    readonly property date now: clock.date

    // Calendar paging, in whole months from the current one. Reset to 0 each
    // time the calendar opens (above).
    property int monthOffset: 0

    readonly property date shownMonth: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1)
    readonly property int shownYear: root.shownMonth.getFullYear()
    readonly property int shownMonthIndex: root.shownMonth.getMonth()
    readonly property bool viewingThisMonth: root.shownYear === root.now.getFullYear() && root.shownMonthIndex === root.now.getMonth()

    // A flat list of day cells, Monday-first: leading 0s for the blanks before
    // the 1st, then the days of the month.
    readonly property var cells: {
        const lead = (new Date(root.shownYear, root.shownMonthIndex, 1).getDay() + 6) % 7;
        const days = new Date(root.shownYear, root.shownMonthIndex + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++)
            out.push(0);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }

    Rectangle {
        id: card

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        implicitWidth: Config.clockPanelWidth
        implicitHeight: content.implicitHeight + Config.clockPanelPadding * 2

        radius: Config.clockPanelRadius
        color: Config.colours.surface
        border.width: 1
        border.color: Config.colours.idle

        opacity: root.reveal
        transform: Translate {
            y: (1 - root.reveal) * 12
        }

        // One column, one of the two views shown at a time.
        Item {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Config.clockPanelPadding

            implicitHeight: root.view === "calendar" ? calendar.implicitHeight : time.implicitHeight

            // --- Time + date ---
            ColumnLayout {
                id: time

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                visible: root.view === "time"
                spacing: 4

                RowLayout {
                    spacing: 6

                    Text {
                        text: Qt.formatDateTime(root.now, "HH:mm")
                        color: Config.colours.text
                        font.family: Config.font
                        font.pointSize: 30
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 6
                        text: Qt.formatDateTime(root.now, "ss")
                        color: Config.colours.accent
                        font.family: Config.font
                        font.pointSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: Qt.formatDateTime(root.now, "dddd")
                    color: Config.colours.text
                    font.family: Config.font
                    font.pointSize: 13
                }

                Text {
                    text: Qt.formatDateTime(root.now, "d MMMM yyyy")
                    color: Config.colours.subtext
                    font.family: Config.font
                    font.pointSize: 11
                }
            }

            // --- Calendar ---
            ColumnLayout {
                id: calendar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                visible: root.view === "calendar"
                spacing: 8

                // Month, with paging arrows either side.
                RowLayout {
                    Layout.fillWidth: true

                    Arrow {
                        text: "‹" // ‹
                        onActivated: root.monthOffset--
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                        color: Config.colours.text
                        font.family: Config.font
                        font.pointSize: 12
                        font.weight: Font.DemiBold
                    }

                    Arrow {
                        text: "›" // ›
                        onActivated: root.monthOffset++
                    }
                }

                // Weekday headings, Monday-first.
                Grid {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Item {
                            required property string modelData

                            implicitWidth: root.cellSize
                            implicitHeight: root.cellSize * 0.8

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Config.colours.subtext
                                font.family: Config.font
                                font.pointSize: 9
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                // The days.
                Grid {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7

                    Repeater {
                        model: root.cells

                        Item {
                            id: cell

                            required property int modelData
                            readonly property bool isToday: root.viewingThisMonth && cell.modelData === root.now.getDate()

                            implicitWidth: root.cellSize
                            implicitHeight: root.cellSize

                            // Today's marker.
                            Rectangle {
                                anchors.centerIn: parent
                                width: root.cellSize - 6
                                height: width
                                radius: width / 2
                                visible: cell.isToday
                                color: Config.colours.accent
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cell.modelData > 0 // blanks are 0
                                text: cell.modelData
                                color: cell.isToday ? Config.colours.surface : Config.colours.text
                                font.family: Config.font
                                font.pointSize: 10
                                font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }
        }
    }

    // Cell size for the 7-wide grid, from the card's inner width.
    readonly property real cellSize: (Config.clockPanelWidth - Config.clockPanelPadding * 2) / 7

    // A paging arrow.
    component Arrow: MouseArea {
        id: arrow

        property alias text: glyph.text

        signal activated

        implicitWidth: glyph.implicitWidth + 10
        implicitHeight: glyph.implicitHeight

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: arrow.activated()

        Text {
            id: glyph

            anchors.centerIn: parent
            color: arrow.containsMouse ? Config.colours.accent : Config.colours.subtext
            font.family: Config.font
            font.pointSize: 16

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }
    }
}
