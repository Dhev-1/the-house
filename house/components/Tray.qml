pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs

ColumnLayout {
    id: root

    readonly property var shown: SystemTray.items.values.filter(i => !Config.trayHiddenIds.includes(i.id))

    spacing: 12
    visible: shown.length > 0

    Repeater {
        model: ScriptModel {
            values: root.shown
        }

        MouseArea {
            id: item

            required property SystemTrayItem modelData

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 18
            implicitHeight: 18

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: event => {
                if (event.button === Qt.LeftButton && !modelData.onlyMenu)
                    modelData.activate();
                else if (modelData.hasMenu)
                    menu.open();
            }

            IconImage {
                anchors.fill: parent
                source: item.modelData.icon
                asynchronous: true
            }

            QsMenuAnchor {
                id: menu

                menu: item.modelData.menu

                anchor.item: item
                anchor.edges: Edges.Left | Edges.Top
                anchor.gravity: Edges.Left | Edges.Bottom
            }
        }
    }
}
