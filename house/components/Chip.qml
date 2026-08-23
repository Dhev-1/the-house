import QtQuick
import Quickshell
import qs

// A poker chip, wearing the active table.
//
// The rest of the shell re-tints live off Config.colours, but this is a sprite
// rather than a rectangle, so there is nothing to bind a colour to. Instead one
// chip is baked per table (scripts/make-chips.py writes assets/chip-<table>.png)
// and this picks the file. Re-run that script after adding a table or changing
// an existing one's surface / text / accent.
//
// Config.activeName, not themeName: activeName follows the theme picker's live
// preview, so flicking through the hand swaps the chip along with everything
// else. It costs a file load per flick rather than a colour animation, so the
// swap lands in one step instead of crossfading like the rectangles do.
//
// The source art is 33x33. That is the native grid, so 33 and its multiples
// stay crisp; anything else resamples. smooth is left off to keep the pixels
// hard at those sizes - set it true on the instance if you need an odd size and
// would rather have it soft than uneven.
Image {
    id: root

    // Drawn size, square. Defaults to the sprite's own resolution.
    property int size: 33

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    smooth: false
    asynchronous: true

    // shellPath, not Qt.resolvedUrl: a relative url from inside a component
    // that quickshell has compiled into its qrc resolves against qrc:/ and
    // never reaches the disk - the same trap Config.pitRepos documents. This
    // takes the path from where the shell was launched instead, so it works
    // wherever the repo is cloned.
    source: "file://" + Quickshell.shellPath("assets/chip-" + Config.activeName + ".png")
}
