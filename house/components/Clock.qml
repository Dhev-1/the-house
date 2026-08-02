import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// The clock at the foot of the bar: HH over mm. Left-click opens the time+date
// card, right-click opens the calendar - both drawn by ClockPopout, toggled
// through the ClockPanel singleton.
MouseArea {
    id: root

    implicitWidth: col.implicitWidth + 12
    implicitHeight: col.implicitHeight + 8

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            ClockPanel.toggleCalendar();
        else
            ClockPanel.toggleTime();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Lit while hovered, and while its card is open.
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.containsMouse || ClockPanel.mode !== "none" ? Config.colours.idle : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    ColumnLayout {
        id: col

        anchors.centerIn: parent
        spacing: -2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH")
            color: Config.colours.text
            font.family: Config.font
            font.pointSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: Config.colours.subtext
            font.family: Config.font
            font.pointSize: 11
        }
    }
}
