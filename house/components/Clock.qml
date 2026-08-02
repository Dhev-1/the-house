import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// The clock at the foot of the bar: the time dealt as a two-card hand. The hour
// is the top card (spade pip), the minutes the bottom one (heart pip), each
// tilted a few degrees the way a dealer leaves them. Left-click opens the
// time+date card, right-click the calendar - both drawn by ClockPopout,
// toggled through the ClockPanel singleton.
MouseArea {
    id: root

    implicitWidth: hand.implicitWidth + 10
    implicitHeight: hand.implicitHeight + 10

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
        id: hand

        anchors.centerIn: parent
        spacing: -3

        Card {
            Layout.alignment: Qt.AlignHCenter
            rank: Qt.formatDateTime(clock.date, "HH")
            pip: "♠"
            pipColour: Config.colours.surface
            tilt: root.containsMouse ? -7 : -4
        }

        Card {
            Layout.alignment: Qt.AlignHCenter
            rank: Qt.formatDateTime(clock.date, "mm")
            pip: "♥"
            pipColour: Config.colours.urgent
            tilt: root.containsMouse ? 7 : 4
        }
    }

    // A mini card face: theme text colour for the stock (ivory on the dark
    // tables), the rank centred, the pip tucked in the top-left corner.
    component Card: Rectangle {
        property string rank
        property string pip
        property color pipColour
        property real tilt: 0

        implicitWidth: 26
        implicitHeight: 30
        radius: 5
        color: Config.colours.text
        border.color: Config.colours.idle
        border.width: 1
        rotation: tilt

        Behavior on rotation {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            text: parent.rank
            color: Config.colours.surface
            font.family: Config.font
            font.pointSize: 9
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 1
            anchors.leftMargin: 3
            text: parent.pip
            color: parent.pipColour
            font.family: Config.font
            font.pointSize: 5
        }
    }
}
