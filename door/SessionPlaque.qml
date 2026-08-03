import QtQuick
import "Palette.js" as Palette

// The session picker, as the gold plaque screwed to the rail in front of your
// seat. Click it and the list of what this machine can deal comes up off the
// rail; click a line to take it.
//
// Sessions are the one control here that is genuinely a list - there can be a
// dozen installed - so this is the one place the theme uses a plain list rather
// than dressing it up as something from the table. A stack of cards you have to
// read the small print on is worse than a menu.
Item {
    id: root

    property int index: 0
    property string fontFamily: "JetBrainsMono Nerd Font"

    // Layout scale, handed down from Main so the rail furniture grows with the
    // rest of the table rather than staying laptop-sized on a big panel.
    property real u: 1

    signal picked(int index)

    // The selected session's name, published out of the Repeater below by the
    // same Binding trick the seats use.
    property string label: ""

    implicitWidth: plaque.width
    implicitHeight: plaque.height

    // --- the plaque -----------------------------------------------------------
    Rectangle {
        id: plaque

        width: plaqueRow.width + Math.round(30 * root.u)
        height: Math.round(34 * root.u)
        radius: Math.round(5 * root.u)
        color: Qt.rgba(0, 0, 0, menu.open ? 0.45 : 0.28)
        border.width: 1
        border.color: Palette.alpha(Palette.gold, menu.open || hover.hovered ? 0.75 : 0.35)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        Row {
            id: plaqueRow

            anchors.centerIn: parent
            spacing: Math.round(9 * root.u)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // nf-fa-window_restore: a session is a desktop, and this is the
                // one glyph that says desktop without saying Linux.
                text: ""
                color: Palette.gold
                font.family: root.fontFamily
                font.pixelSize: Math.round(13 * root.u)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label.toUpperCase()
                color: hover.hovered || menu.open ? Palette.goldBright : Palette.gold
                font.family: root.fontFamily
                font.pixelSize: Math.round(12 * root.u)
                font.letterSpacing: 3
            }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            onTapped: menu.open = !menu.open
        }
    }

    // --- the list -------------------------------------------------------------
    // Off the rail and up onto the cloth, because there is nothing below the
    // rail to open into.
    Rectangle {
        id: menu

        property bool open: false

        anchors.left: plaque.left
        anchors.bottom: plaque.top
        anchors.bottomMargin: 10

        width: Math.max(plaque.width, Math.round(240 * root.u))
        height: menuColumn.height + 14
        radius: 6
        color: Qt.rgba(0.02, 0.06, 0.04, 0.96)
        border.width: 1
        border.color: Palette.alpha(Palette.gold, 0.45)

        visible: opacity > 0
        opacity: open ? 1 : 0
        // Grows up out of the plaque rather than fading in on top of it.
        transform: Scale {
            origin.x: 0
            origin.y: menu.height
            xScale: 1
            yScale: menu.open ? 1 : 0.85
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Column {
            id: menuColumn

            anchors.centerIn: parent
            width: parent.width - 14

            Repeater {
                model: sessionModel

                Rectangle {
                    id: line

                    required property int index
                    required property string name

                    readonly property bool chosen: index === root.index

                    // Publish the chosen session's name up to the plaque.
                    Binding {
                        target: root
                        property: "label"
                        value: line.name
                        when: line.chosen
                    }

                    width: menuColumn.width
                    height: Math.round(30 * root.u)
                    radius: 4
                    color: lineHover.hovered ? Palette.alpha(Palette.gold, 0.16) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.name
                        color: line.chosen ? Palette.goldBright : Palette.text
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(13 * root.u)
                    }

                    // The tick on the one you are already using.
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.chosen
                        text: "♠"
                        color: Palette.gold
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(12 * root.u)
                    }

                    HoverHandler {
                        id: lineHover
                    }

                    TapHandler {
                        onTapped: {
                            root.picked(line.index);
                            menu.open = false;
                        }
                    }
                }
            }
        }
    }
}
