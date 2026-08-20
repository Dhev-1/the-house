import QtQuick
import QtQuick.Window
import "Palette.js" as Palette

// Throwaway harness for eyeballing ChipStack outside the greeter. Delete when done.
Window {
    id: win

    visible: true
    width: 900
    height: 620
    color: Palette.tableLit
    title: "chipstack"

    property int n: 1

    Timer {
        interval: 80
        running: win.n < 36
        repeat: true
        onTriggered: win.n += 1
    }

    ChipStack {
        id: stack

        anchors.centerIn: parent
        count: win.n
        chipWidth: 96

        Component.onCompleted: console.log("HARNESS implicit", stack.implicitWidth, stack.implicitHeight, "wh", stack.width, stack.height, "cap", stack.capacity, "heights", JSON.stringify(stack.stackHeights))
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        color: Palette.gold
        text: "count " + win.n + "  shown " + stack.shown + "  used " + stack.stacksUsed + "  size " + stack.width + "x" + stack.height
    }
}
