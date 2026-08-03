import QtQuick
import QtQuick.Shapes

// The room: cloth, lamp, lattice, vignette, rail. Everything with no behaviour.
//
// Drawn rather than shipped as a PNG so it is resolution-independent - the
// greeter runs before anything has told it what monitor it is on, and a baked
// 1920x1080 backdrop on a 4K panel is the first thing you see of the machine.
//
// The lamp is the whole composition. A casino table is lit from directly
// above, hard, and everything the light misses falls away fast; that single
// cone is what stops a flat green rectangle from reading as a flat green
// rectangle. Shapes' RadialGradient does it without pulling in the Qt5Compat
// effects module, which is not guaranteed to be installed on a machine that
// only has sddm.
Item {
    id: root

    // Where the lamp hangs, as a fraction of the screen. Slightly above centre:
    // the light pools on the cards and the bet, and the rail at the bottom is
    // the far edge of the pool rather than in it.
    readonly property real lampX: 0.5
    readonly property real lampY: 0.42

    // The rail's height. Main.qml reads this to park the session plaque and the
    // power chips on it.
    readonly property int railHeight: Math.max(84, root.height * 0.11)

    // --- the cloth ------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Palette.feltDeep
    }

    // --- the lamp -------------------------------------------------------------
    // Two cones rather than one: a wide soft pool that lifts the middle third of
    // the screen, and a tighter hotter one inside it. A single stop from lit to
    // deep reads as a vignette; two reads as a light with a filament in it.
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
                    color: Qt.rgba(Palette.feltLit.r, Palette.feltLit.g, Palette.feltLit.b, 1.0)
                }
                GradientStop {
                    position: 0.35
                    color: Qt.rgba(Palette.feltLit.r, Palette.feltLit.g, Palette.feltLit.b, 0.55)
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
    // The pattern printed on good baize: a diamond grid, at the threshold of
    // visible. It exists to give the light something to fall across - under the
    // lamp you can just make it out, at the corners it is gone entirely, and
    // that difference is most of what sells the cone above as a light source.
    Item {
        id: lattice

        anchors.fill: parent
        // Nothing about this changes after load; caching it hands the whole grid
        // to the GPU once instead of compositing a few hundred nodes per frame.
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
                border.color: Qt.rgba(Palette.feltLine.r, Palette.feltLine.g, Palette.feltLine.b, 0.55 * (1 - fall))
            }
        }
    }

    // --- the vignette ---------------------------------------------------------
    // The cone above lights the middle; this puts the corners out. Separate
    // because they are not the same operation - one adds green, one removes
    // everything, and doing it in one gradient means the corners go dark green
    // rather than dark.
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

    // --- the rail -------------------------------------------------------------
    // The padded mahogany edge. Rounded on all four corners with the bottom two
    // pushed off-screen, which is cheaper and steadier than clipping a shape.
    Rectangle {
        id: rail

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -40
        anchors.leftMargin: -40
        anchors.rightMargin: -40
        height: root.railHeight + 40
        radius: 44

        // The roll of the padding: lit along the top where the lamp catches it,
        // falling to shadow at the bottom where nothing does.
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Palette.railLit
            }
            GradientStop {
                position: 0.35
                color: Palette.rail
            }
            GradientStop {
                position: 1.0
                color: Palette.railShadow
            }
        }
    }

    // The brass beading where the rail meets the cloth. One hairline, and the
    // single brightest edge on the screen - it is the only thing telling you the
    // rail is raised and not just a darker patch of table.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: rail.top
        anchors.bottomMargin: -1
        height: 1
        color: Palette.brass
        opacity: 0.7
    }

    // And the cloth's own shadow falling onto the rail, so the two are not
    // simply stacked.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: rail.top
        height: 22

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.45)
            }
        }
    }
}
