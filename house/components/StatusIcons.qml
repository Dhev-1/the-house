pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs

ColumnLayout {
    id: root

    spacing: 10

    // Audio --------------------------------------------------------------
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property int volume: Math.round((root.sink?.audio?.volume ?? 0) * 100)

    // Pipewire nodes only report volume/mute while something is tracking them.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Network ------------------------------------------------------------
    readonly property var activeDevice: Networking.devices.values.find(d => d.connected) ?? null
    readonly property var activeWifi: activeDevice?.type === DeviceType.Wifi ? (activeDevice.networks.values.find(n => n.connected) ?? null) : null

    // Battery ------------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property int batteryPercent: Math.round((battery?.percentage ?? 0) * 100)
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged

    // Bluetooth ----------------------------------------------------------
    readonly property bool btEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)

    Icon {
        visible: root.sink !== null
        text: {
            if (root.sink?.audio?.muted ?? false)
                return "󰝟";
            if (root.volume >= 60)
                return "󰕾";
            if (root.volume >= 20)
                return "󰖀";
            return "󰕿";
        }
        colour: (root.sink?.audio?.muted ?? false) ? Config.colours.subtext : Config.colours.text

        onActivated: {
            if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
        onSecondary: Quickshell.execDetached(["pavucontrol"])
        onScrolled: delta => {
            if (!root.sink?.audio)
                return;
            const step = delta > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }

    Icon {
        visible: root.source !== null
        text: (root.source?.audio?.muted ?? false) ? "󰍭" : "󰍬"
        colour: (root.source?.audio?.muted ?? false) ? Config.colours.subtext : Config.colours.text

        onActivated: {
            if (root.source?.audio)
                root.source.audio.muted = !root.source.audio.muted;
        }
        onSecondary: Quickshell.execDetached(["pavucontrol", "--tab=4"])
        onScrolled: delta => {
            if (!root.source?.audio)
                return;
            const step = delta > 0 ? 0.05 : -0.05;
            root.source.audio.volume = Math.max(0, Math.min(1, root.source.audio.volume + step));
        }
    }

    Icon {
        text: {
            if (!root.activeDevice)
                return "󰤭";
            if (root.activeDevice.type === DeviceType.Wired)
                return "󰈀";
            const s = root.activeWifi?.signalStrength ?? 0;
            if (s >= 80)
                return "󰤨";
            if (s >= 60)
                return "󰤥";
            if (s >= 40)
                return "󰤢";
            if (s >= 20)
                return "󰤟";
            return "󰤯";
        }
        colour: root.activeDevice ? Config.colours.text : Config.colours.subtext
        onActivated: Quickshell.execDetached(["nm-connection-editor"])
    }

    Icon {
        visible: root.btEnabled || root.btConnected
        text: root.btConnected ? "󰂱" : "󰂯"
        colour: root.btConnected ? Config.colours.accent : Config.colours.text
        onActivated: Quickshell.execDetached(["blueman-manager"])
    }

    Icon {
        visible: root.hasBattery
        text: {
            if (root.charging)
                return "󰂄";
            const levels = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
            return levels[Math.min(10, Math.max(0, Math.round(root.batteryPercent / 10)))];
        }
        colour: {
            if (root.charging)
                return Config.colours.accent;
            if (root.batteryPercent <= 15)
                return Config.colours.urgent;
            return Config.colours.text;
        }
    }

    component Icon: MouseArea {
        id: icon

        property alias text: label.text
        property color colour: Config.colours.text

        signal activated
        signal secondary
        signal scrolled(int delta)

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                icon.secondary();
            else
                icon.activated();
        }
        onWheel: event => icon.scrolled(event.angleDelta.y)

        // The chip: hover an icon and a poker chip slides in underneath it and
        // starts a slow spin - six accent inlays around the rim, like the edge
        // stripes on a real one. Pressing "bets" it: a quick extra kick.
        Item {
            id: chip

            anchors.centerIn: parent
            width: 34
            height: 34
            opacity: icon.containsMouse ? 1 : 0
            scale: icon.containsMouse ? 1 : 0.6

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                }
            }

            RotationAnimator on rotation {
                running: icon.containsMouse
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 8000
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Config.colours.idle
                border.color: Config.colours.accent
                border.width: 1
            }

            Repeater {
                model: 6

                Item {
                    required property int index

                    anchors.fill: chip
                    rotation: index * 60

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 1
                        width: 2
                        height: 5
                        radius: 1
                        color: Config.colours.accent
                    }
                }
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            color: icon.containsMouse ? Config.colours.accent : icon.colour
            font.family: Config.font
            font.pointSize: 15
            scale: icon.pressed ? 0.85 : 1

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
