import QtQuick
import QtQuick.Shapes
import "Palette.js" as Palette

// The room: cloth, lamp, lattice, vignette. Everything with no behaviour.
//
// Drawn rather than shipped as a PNG so it is resolution-independent - the
// greeter runs before anything has told it what monitor it is on.
//
// Shapes' RadialGradient for the lamp, rather than the Qt5Compat effects
// module, which is not guaranteed to be installed on a machine that only has
// sddm.
Item {
    id: root

    // Where the lamp hangs, as a fraction of the screen. Slightly above centre,
    // so the light pools on the cards and the bet.
    readonly property real lampX: 0.5
    readonly property real lampY: 0.42

    // The strip Main.qml parks the session plaque and power chips in. Nothing
    // is drawn there; the cloth runs all the way down.
    readonly property int railHeight: Math.max(84, root.height * 0.11)

    // --- the cloth ------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Palette.tableDeep
    }

    // --- the lamp -------------------------------------------------------------
    // Two cones: a wide soft pool and a tighter hotter one inside it. A single
    // stop reads as a vignette; two read as a light with a filament in it.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeWidth: -1

            fillGradient: RadialGradient {
                centerX: root.width * root.lampX
                centerY: root.height * root.lampY
                centerRadius: Math.max(root.width, root.height) * 0.62
                focalX: centerX
                focalY: centerY

                GradientStop {
                    position: 0.0
                    color: Palette.tableLit
                }
                GradientStop {
                    position: 0.35
                    color: Palette.alpha(Palette.tableLit, 0.55)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }

            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    // --- the lattice ----------------------------------------------------------
    // A diamond grid at the threshold of visible, there to give the light
    // something to fall across: legible under the lamp, gone at the corners.
    Item {
        id: lattice

        anchors.fill: parent
        // Nothing here changes after load, so cache it rather than compositing
        // a few hundred nodes per frame.
        layer.enabled: true

        readonly property int step: 84
        readonly property int cols: Math.ceil(root.width / step) + 1
        readonly property int rows: Math.ceil(root.height / step) + 1

        Repeater {
            model: lattice.cols * lattice.rows

            Rectangle {
                required property int index

                readonly property int col: index % lattice.cols
                readonly property int row: Math.floor(index / lattice.cols)

                // How far this diamond is from the lamp, 0 at the filament and 1
                // out past the corners. The whole grid fades on this.
                readonly property real fall: Math.min(1, Math.hypot(x + width / 2 - root.width * root.lampX, y + height / 2 - root.height * root.lampY) / (Math.max(root.width, root.height) * 0.55))

                // Offset every other row by half a step, so the grid reads as
                // diamonds on point rather than as a chessboard.
                x: col * lattice.step + (row % 2 ? lattice.step / 2 : 0) - width / 2
                y: row * lattice.step - height / 2

                width: 26
                height: 26
                rotation: 45
                color: "transparent"
                border.width: 1
                border.color: Palette.alpha(Palette.tableLine, 0.55 * (1 - fall))
            }
        }
    }

    // --- the vignette ---------------------------------------------------------
    // The cone lights the middle; this puts the corners out. Separate because
    // one adds warmth and the other removes everything - done in one gradient
    // the corners go a dead brown rather than properly black.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeWidth: -1

            fillGradient: RadialGradient {
                centerX: root.width * root.lampX
                centerY: root.height * root.lampY
                centerRadius: Math.max(root.width, root.height) * 0.75
                focalX: centerX
                focalY: centerY

                GradientStop {
                    position: 0.45
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.72)
                }
            }

            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }
}
