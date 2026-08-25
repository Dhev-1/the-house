pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services

// The tab clinging to the left edge: click it to slide the sidebar in or out,
// click an icon to jump straight to that docked window.
PanelWindow {
    id: root

    readonly property int tabPadding: 8
    readonly property int minTabHeight: 90

    anchors.left: true

    implicitWidth: Config.sidebarTabWidth
    implicitHeight: Math.max(minTabHeight, layout.implicitHeight + tabPadding * 2)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-sidebar-tab"

    Rectangle {
        anchors.fill: parent

        color: tabArea.containsMouse ? Config.colours.idle : Config.colours.surface
        topRightRadius: 8
        bottomRightRadius: 8

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        MouseArea {
            id: tabArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Dock.toggle()
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: 8

            // No windows docked yet: just the arrow.
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: Dock.windows.length === 0
                text: Dock.shown ? "◀" : "▶"
                color: Config.colours.subtext
                font.family: Config.font
                font.pointSize: 10
            }

            Repeater {
                model: ScriptModel {
                    values: Dock.windows
                }

                MouseArea {
                    id: entry

                    required property HyprlandToplevel modelData

                    readonly property var desktopEntry: DesktopEntries.heuristicLookup(modelData.lastIpcObject?.class ?? "")
                    readonly property string iconSource: entry.desktopEntry?.icon ? Quickshell.iconPath(entry.desktopEntry.icon, true) : ""
                    readonly property bool active: Hyprland.activeToplevel?.address === modelData.address

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Config.sidebarIconSize
                    implicitHeight: Config.sidebarIconSize

                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: event => {
                        if (event.button === Qt.MiddleButton)
                            Dock.undock(entry.modelData.address);
                        else
                            Dock.focus(entry.modelData.address);
                    }

                    // An unresolvable source makes IconImage paint Qt's magenta
                    // checkerboard, so fall back to a glyph instead of drawing it.
                    IconImage {
                        anchors.fill: parent
                        asynchronous: true
                        visible: entry.iconSource !== ""
                        opacity: entry.active || entry.containsMouse ? 1 : 0.55
                        source: entry.iconSource

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: entry.iconSource === ""
                        text: "󰣆"
                        color: entry.active ? Config.colours.accent : Config.colours.subtext
                        font.family: Config.font
                        font.pointSize: 10
                    }
                }
            }
        }
    }
}
