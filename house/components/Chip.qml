import QtQuick
import Quickshell
import qs

// A poker chip, wearing the active table. A sprite rather than a rectangle, so
// there is nothing to bind a colour to: one chip is baked per table by
// scripts/make-chips.py, and this picks the file. Re-run that after adding a
// table or changing an existing one's surface / text / accent.
//
// Config.activeName, not themeName, so it follows the picker's live preview -
// at the cost of a file load per flick, so the swap steps rather than crossfades.
//
// The source art is 33x33: that grid and its multiples stay crisp, anything
// else resamples. smooth is off to keep the pixels hard at those sizes.
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
