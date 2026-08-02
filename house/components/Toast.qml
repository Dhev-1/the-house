pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification, drawn the way the old dunstrc drew it: square, flat, and
// coloured by urgency. The mouse bindings are dunst's too - left closes this one,
// right closes all of them, middle runs the default action and then closes.
MouseArea {
    id: root

    required property Notification modelData

    readonly property QtObject palette: Notifications.palette(modelData)
    readonly property int duplicates: Notifications.count(modelData)

    // Volume, brightness and copy dialogs report progress as a `value` hint. -1
    // stands for "no progress", which is not the same as 0.
    readonly property int progress: modelData.hints?.value ?? -1

    // show_age_threshold: a notification that has been up for a while says so,
    // which only ever happens to critical ones, since they never expire.
    readonly property double created: Date.now()
    readonly property int age: Math.floor((Notifications.now.getTime() - root.created) / 1000)

    // "default" is what activating the notification body does, so it answers to
    // the middle click rather than getting a button of its own.
    readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default" && a.text)

    readonly property string iconUrl: "image://icon/"

    // An app can send its icon as a theme name or as a path, and Quickshell wraps
    // either in an image://icon/ url without checking a name is one the theme
    // actually has. A name it doesn't have loads as Qt's magenta checkerboard, so
    // unwrap and re-check names; paths and real urls are fine as they are.
    // iconPath with check returns "" for a name the theme lacks, hiding the slot.
    readonly property string iconSource: {
        const raw = modelData.image || modelData.appIcon;
        if (!raw)
            return "";

        const name = raw.startsWith(root.iconUrl) ? raw.slice(root.iconUrl.length) : raw;

        // A bare path needs the scheme spelled out, or Image resolves it against
        // the QML document and looks for it inside qrc:/ instead of on disk.
        if (name.startsWith("/"))
            return `file://${name}`;
        if (name.includes("://"))
            return raw;

        return Quickshell.iconPath(name, true);
    }

    Layout.fillWidth: true
    implicitHeight: background.implicitHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: event => {
        if (event.button === Qt.RightButton) {
            Notifications.dismissAll();
            return;
        }

        if (event.button === Qt.MiddleButton)
            root.defaultAction?.invoke();

        root.modelData.dismiss();
    }

    // Critical notifications never expire (timeout = 0), as in dunst. Hovering
    // holds the timer so a toast can't vanish out from under the cursor mid-read.
    //
    // The tracked check matters: a notification closed from elsewhere (dismissAll,
    // or the app withdrawing it) can outlive this delegate by a frame, and
    // expiring an already-closed one is an error.
    Timer {
        running: root.modelData.tracked && !root.containsMouse && interval > 0
        interval: {
            if (root.palette === Config.notifCritical)
                return 0;

            // Seconds; -1 asks for our default, 0 asks to never expire.
            const asked = root.modelData.expireTimeout;
            if (asked === 0)
                return 0;
            if (asked > 0)
                return asked * 1000;

            const fallback = root.palette === Config.notifLow ? Config.notifTimeoutLow : Config.notifTimeoutNormal;
            return fallback * 1000;
        }
        onTriggered: root.modelData.expire()
    }

    // Dealt onto the table: the card slides in from the bar side, straightens
    // out of a slight tilt, and fades up - all on the background, so the layout
    // height (which the stack animates separately) never jumps.
    Component.onCompleted: dealIn.start()

    ParallelAnimation {
        id: dealIn

        NumberAnimation {
            target: background
            property: "x"
            from: 48
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: background
            property: "rotation"
            from: 4
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: background
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }
    }

    Rectangle {
        id: background

        anchors.fill: parent

        implicitHeight: layout.implicitHeight + Config.notifPadding * 2

        color: root.palette.background
        radius: Config.notifRadius

        border.width: Config.notifFrameWidth
        border.color: root.palette.frame

        // The inner hairline of a card back, inset inside the frame.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Math.max(2, Config.notifRadius - 3)
            color: "transparent"
            border.width: 1
            border.color: root.palette.frame
            opacity: 0.45
        }

        // The corner pip, indexed by urgency like a card's rank: clubs are
        // small talk, spades the table standard, hearts the high stakes. The
        // heart beats, because a critical card never leaves on its own.
        Text {
            id: pip

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 5
            anchors.rightMargin: 8
            text: root.palette === Config.notifCritical ? "♥" : root.palette === Config.notifLow ? "♣" : "♠"
            color: root.palette.accent
            font.family: Config.notifFont
            font.pointSize: Config.notifFontSize - 1

            SequentialAnimation on scale {
                running: root.palette === Config.notifCritical
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1
                    to: 1.35
                    duration: 500
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    from: 1.35
                    to: 1
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
            }
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Config.notifPadding
            anchors.rightMargin: Config.notifPadding + 14 // room for the pip
            spacing: Config.notifPadding

            // icon_position = left, vertical_alignment = center.
            IconImage {
                Layout.alignment: Qt.AlignVCenter
                implicitSize: Config.notifIconSize
                asynchronous: true
                visible: root.iconSource !== ""
                source: root.iconSource
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                // The format string: a bold summary, then the progress percentage
                // beside it. The age and the duplicate count go here too, since
                // dunst appended both to the summary line.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.modelData.summary
                        color: root.palette.title
                        font.family: Config.notifFont
                        font.pointSize: Config.notifFontSize
                        font.bold: true
                        elide: Text.ElideMiddle
                    }

                    Text {
                        visible: root.duplicates > 1
                        text: `(${root.duplicates})`
                        color: root.palette.accent
                        font.family: Config.notifFont
                        font.pointSize: Config.notifFontSize
                    }

                    Text {
                        visible: root.progress >= 0
                        text: `${root.progress}%`
                        color: root.palette.accent
                        font.family: Config.notifFont
                        font.pointSize: Config.notifFontSize
                    }

                    Text {
                        visible: root.age >= Config.notifAgeThreshold
                        text: root.age >= 3600 ? `${Math.floor(root.age / 3600)}h` : `${Math.floor(root.age / 60)}m`
                        color: root.palette.accent
                        font.family: Config.notifFont
                        font.pointSize: Config.notifFontSize
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.modelData.body
                    color: root.palette.body
                    font.family: Config.notifFont
                    font.pointSize: Config.notifFontSize

                    // markup = full: the body arrives as Pango-flavoured HTML.
                    textFormat: Text.RichText
                    wrapMode: Config.notifWordWrap ? Text.Wrap : Text.NoWrap
                    maximumLineCount: Config.notifBodyLines
                    elide: Text.ElideRight
                }

                // progress_bar: drawn only when the app sent a value hint.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.progress >= 0

                    implicitHeight: Config.notifProgressHeight
                    radius: 3
                    color: "transparent"
                    border.width: Config.notifProgressFrame
                    border.color: root.palette.frame

                    // highlight: deep teal into a lighter tint of the same hue.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: Config.notifProgressFrame

                        width: (parent.width - Config.notifProgressFrame * 2) * Math.min(100, Math.max(0, root.progress)) / 100

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Config.notifProgress.low
                            }

                            GradientStop {
                                position: 0.5
                                color: Config.notifProgress.mid
                            }

                            GradientStop {
                                position: 1
                                color: Config.notifProgress.high
                            }
                        }
                    }
                }

                // dunst only hinted that actions existed (show_indicators) and put
                // them behind a context menu. Buttons say the same thing and can
                // be clicked directly.
                RowLayout {
                    Layout.topMargin: 4
                    visible: root.buttons.length > 0
                    spacing: 6

                    Repeater {
                        model: root.buttons

                        MouseArea {
                            id: button

                            required property NotificationAction modelData

                            implicitWidth: buttonLabel.implicitWidth + 12
                            implicitHeight: buttonLabel.implicitHeight + 6

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            // Invoking an action closes the notification unless the
                            // app marked it resident, which the server honours.
                            onClicked: button.modelData.invoke()

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: button.containsMouse ? root.palette.frame : "transparent"
                                border.width: 1
                                border.color: root.palette.frame
                            }

                            Text {
                                id: buttonLabel

                                anchors.centerIn: parent
                                text: button.modelData.text
                                color: button.containsMouse ? root.palette.background : root.palette.accent
                                font.family: Config.notifFont
                                font.pointSize: Config.notifFontSize
                            }
                        }
                    }
                }
            }
        }
    }
}
