import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.right: true

    implicitWidth: Config.barWidth
    exclusiveZone: Config.barWidth
    color: Config.colours.surface

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "house-bar"

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Config.borderThickness
        anchors.bottomMargin: Config.borderThickness
        spacing: 14

        Workspaces {
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
        }

        Tray {
            Layout.alignment: Qt.AlignHCenter
        }

        StatusIcons {
            Layout.alignment: Qt.AlignHCenter
        }

        ThemeButton {
            Layout.alignment: Qt.AlignHCenter
        }

        Clock {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
