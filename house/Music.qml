pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.services

// The music tab, on the right edge against the bar: transport controls on the
// strip itself, and a card that slides out to the left with the track on it.
//
// The strip and the card are one shape, not two that touch - two would leave a
// seam down the join. The outline is traced once around both, and the flare
// curving the strip into the bar is scaled away as the card opens.
//
// The whole window comes and goes with the player, so there is no tab to click
// when nothing is running.
PanelWindow {
    id: root

    property bool expanded: false

    readonly property MprisPlayer player: Player.active

    // A player reports its position when asked and not a moment sooner, so this
    // binding only moves when something pokes it. The timer below does the poking.
    readonly property real position: root.player?.position ?? 0

    // How far the card is out. The outline is traced from this, so the whole shape
    // deforms open rather than a second shape appearing beside the first.
    property real reveal: expanded ? Config.musicWidth : 0
    readonly property real progress: root.reveal / Config.musicWidth

    readonly property real tabLeft: width - Config.musicTabWidth
    readonly property real cardLeft: root.tabLeft - root.reveal

    // Shut, the strip curves into the bar over this many pixels. Open, there is
    // nothing to curve into: the card's edges run straight out to the bar, and a
    // flare would only put a kink back into the join that fusing them removed.
    readonly property real flare: Config.musicTabFlare * (1 - root.progress)
    readonly property real corner: Math.min(Config.musicRounding, root.reveal / 2)

    anchors.right: true

    visible: Player.available
    margins.right: Config.barWidth

    // Fixed, so the layer surface isn't resized on every frame of the animation.
    implicitWidth: Config.musicTabWidth + Config.musicWidth
    implicitHeight: Config.musicTabHeight

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-music"

    Behavior on reveal {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // The window is as wide as strip and card together even when shut, and the
    // part of it that isn't painted is transparent - which is not the same as
    // absent. Without a mask it would eat every click meant for the desktop.
    mask: Region {
        x: root.tabLeft
        width: Config.musicTabWidth
        height: root.height

        Region {
            x: root.cardLeft
            width: root.reveal
            height: root.height
        }
    }

    // Collapse when the player goes away, or it would slide back out already open
    // the next time one appears.
    onVisibleChanged: if (!visible)
        root.expanded = false

    // Emitting positionChanged() is what makes the player re-read its position;
    // nothing else does, so without this the bar sits wherever the track started.
    // Only while the card is open - there is nothing to update behind a shut one.
    Timer {
        running: root.visible && root.expanded && (root.player?.positionSupported ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    Shape {
        anchors.fill: parent

        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: shape

            fillColor: hover.containsMouse ? Config.colours.idle : Config.colours.surface
            strokeColor: "transparent"
            strokeWidth: 0

            // The bar edge, top.
            startX: root.width
            startY: 0

            // Out of the bar and onto the strip, on an arc centred on the bar edge
            // itself. The material lies outside the arc, so the corner is filled
            // rather than cut: the strip doesn't sit against the bar, it runs out
            // of it, the way a drip leaves a surface. At full reveal the radius is
            // zero and the edge just carries on across the card.
            PathArc {
                x: root.tabLeft
                y: root.flare
                radiusX: Config.musicTabWidth
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }

            // Across the top of the card. Zero length when it's shut.
            PathLine {
                x: root.cardLeft + root.corner
                y: root.flare
            }

            PathArc {
                x: root.cardLeft
                y: root.flare + root.corner
                radiusX: root.corner
                radiusY: root.corner
                direction: PathArc.Clockwise
            }

            // The far side of the card - its only outside edge.
            PathLine {
                x: root.cardLeft
                y: root.height - root.flare - root.corner
            }

            PathArc {
                x: root.cardLeft + root.corner
                y: root.height - root.flare
                radiusX: root.corner
                radiusY: root.corner
                direction: PathArc.Clockwise
            }

            // Back across the bottom of the card.
            PathLine {
                x: root.tabLeft
                y: root.height - root.flare
            }

            // And back into the bar, mirrored.
            PathArc {
                x: root.width
                y: root.height
                radiusX: Config.musicTabWidth
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: root.width
                y: 0
            }

            Behavior on fillColor {
                ColorAnimation {
                    duration: 120
                }
            }
        }
    }

    // Under the controls, so they take their own clicks first: this is the rest of
    // the strip, and clicking it is what opens and shuts the card.
    MouseArea {
        id: hover

        x: root.tabLeft
        width: Config.musicTabWidth
        height: root.height

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        x: root.tabLeft
        width: Config.musicTabWidth
        height: root.height

        spacing: 26

        Control {
            Layout.alignment: Qt.AlignHCenter
            text: "󰒮"
            enabled: root.player?.canGoPrevious ?? false
            onActivated: root.player?.previous()
        }

        Control {
            Layout.alignment: Qt.AlignHCenter
            text: root.player?.isPlaying ? "󰏤" : "󰐊"
            enabled: root.player?.canTogglePlaying ?? false
            accented: root.player?.isPlaying ?? false
            onActivated: root.player?.togglePlaying()
        }

        Control {
            Layout.alignment: Qt.AlignHCenter
            text: "󰒭"
            enabled: root.player?.canGoNext ?? false
            onActivated: root.player?.next()
        }
    }

    // Clipped to what the outline has actually opened, so the contents are
    // revealed by the card rather than squashed as it grows.
    Item {
        x: root.cardLeft
        width: root.reveal
        height: root.height

        clip: true

        Item {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: Config.musicWidth
            implicitHeight: content.implicitHeight

            // The controls live on the strip, so the card is only what won't fit
            // there: the art, the track, and how far through it is.
            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Config.musicPadding
                spacing: Config.musicPadding

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.musicPadding

                    // Rounded off, because album art is square and everything else
                    // here isn't.
                    ClippingRectangle {
                        Layout.alignment: Qt.AlignVCenter

                        implicitWidth: Config.musicArtSize
                        implicitHeight: Config.musicArtSize

                        color: Config.colours.idle
                        radius: 6

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            source: root.player?.trackArtUrl ?? ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.player?.trackTitle || "Nothing playing"
                            color: Config.colours.text
                            font.family: Config.font
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.player?.trackArtist ?? ""
                            color: Config.colours.subtext
                            font.family: Config.font
                            font.pointSize: 10
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.player?.trackAlbum ?? ""
                            color: Config.colours.subtext
                            font.family: Config.font
                            font.pointSize: 9
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                }

                // Along the bottom, the full width of the card. Only drawn when the
                // player says how long the track is, which rules out livestreams
                // and some web players.
                Rectangle {
                    Layout.fillWidth: true
                    visible: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0

                    implicitHeight: 5
                    radius: 2.5
                    color: Config.colours.idle

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        width: parent.width * Math.min(1, Math.max(0, root.position / Math.max(1, root.player?.length ?? 1)))
                        height: parent.height
                        radius: parent.radius
                        color: Config.colours.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    component Control: MouseArea {
        id: control

        property alias text: label.text

        // Playing, in the case of the play button: it stays lit rather than only
        // colouring under the cursor.
        property bool accented: false

        signal activated

        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.activated()

        Text {
            id: label

            anchors.centerIn: parent
            color: !control.enabled ? Config.colours.idle : control.containsMouse || control.accented ? Config.colours.accent : Config.colours.text
            font.family: Config.font
            font.pointSize: 15
            scale: control.pressed ? 0.85 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }
}
