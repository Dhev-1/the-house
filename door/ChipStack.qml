import QtQuick
import "Palette.js" as Palette

// The bet: one chip per character typed, stacked edge on. This is the password
// field - there is no row of asterisks anywhere on this theme.
//
// Sprites, not rectangles. The chip is a 29x14 drawing in three-quarter view
// (assets/chip-src.png): top face on rows 0-6, near rim on rows 7-13. Laying
// each chip a rim's height above the one below is what makes a stack read as a
// stack. A sprite has no colours to bind to, so the four denominations in
// Palette.js are baked into files by make-chips.py - re-run it after changing
// Palette.chips or redrawing the source.
Item {
    id: root

    // How many chips are in. Bind straight to the password length.
    property int count: 0

    // How tall each stack is allowed to get, left to right. The length is how
    // many stacks; the sum is the longest password the felt can report.
    property var stackHeights: [10, 4, 9, 7, 5]

    property int chipWidth: 76

    // The sprite's own grid. Everything below is a whole multiple of this, so
    // the pixels stay square.
    readonly property int spriteWidth: 29
    readonly property int spriteHeight: 14

    // The rim, in source pixels: what one chip shows once another lies on it,
    // and so the gap from one chip to the next. Five is rows 9-13, the spotted
    // band and its outline - not seven (the whole lower half), which leaves the
    // shaded band showing and reads as separate discs hanging in the air.
    readonly property int spriteRim: 5

    // The air between one stack and the next, in source pixels.
    readonly property int spriteGap: 3

    // The radius of the circle the stacks stand on, in source pixels, centred
    // far below the felt. See `riseAt`.
    readonly property int spriteRadius: 110

    // Screen pixels per source pixel. Snapped to a whole number: at 3.3x a
    // 29-wide sprite lands on a fractional boundary and the outline goes to
    // mush. The stack is a few pixels off the width it asked for instead.
    readonly property int scale: Math.max(1, Math.round(chipWidth / spriteWidth))

    readonly property int chipHeight: spriteHeight * root.scale

    // Both fixed: one rim between chips, one chip plus the air between stacks.
    // A stack that squeezes its own spacing as the bet grows reads as the
    // drawing breaking; spreading sideways into the next stack does not.
    readonly property int pitch: spriteRim * root.scale
    readonly property int stackPitch: (spriteWidth + spriteGap) * root.scale

    // Past capacity the bet stops changing: the password keeps taking
    // characters, the felt just stops counting them.
    readonly property int capacity: {
        var t = 0;
        for (var s = 0; s < root.stackHeights.length; ++s)
            t += root.stackHeights[s];
        return t;
    }

    readonly property int shown: Math.min(count, capacity)

    // How many stacks have anything in them. At least one, so an empty bet
    // still has a width to be centred on.
    readonly property int stacksUsed: {
        var t = 0;
        for (var s = 0; s < root.stackHeights.length; ++s) {
            t += root.stackHeights[s];
            if (root.shown <= t)
                return s + 1;
        }
        return root.stackHeights.length;
    }

    // The left edge of the stacks in use. The item is always as wide as every
    // stack it could have, with the ones in use centred inside it, so the bet
    // stays centred without the item's own width moving under the layout.
    readonly property int originX: Math.round((width - (stacksUsed * stackPitch - spriteGap * root.scale)) / 2)

    // Chips in the stacks left of `s` - a chip's place in the whole bet, which
    // is what picks its colour.
    function offsetOf(s: int): int {
        var t = 0;
        for (var i = 0; i < s; ++i)
            t += root.stackHeights[i];
        return t;
    }

    // How many chips are actually in stack `s` right now.
    function chipsIn(s: int): int {
        return Math.max(0, Math.min(root.stackHeights[s], root.shown - root.offsetOf(s)));
    }

    // How far stack `s` of `n` is lifted off the baseline, in screen pixels. The
    // stacks stand on one circle centred far below the felt, so the middle one
    // sits at its bottom and the outer ones ride up the sides.
    //
    // A fixed radius rather than a fixed lift for the outermost stack, so the
    // arc deepens as the bet spreads instead of throwing the whole bet upward
    // the moment a second stack opens. 110 puts the outermost of five about
    // twenty pixels up; down for a deeper bowl, negate for a dome.
    function riseAt(s: int, n: int): int {
        var dx = (s - (n - 1) / 2) * (root.spriteWidth + root.spriteGap);
        var r = root.spriteRadius;
        if (Math.abs(dx) >= r)
            return 0;
        return Math.round((r - Math.sqrt(r * r - dx * dx)) * root.scale);
    }

    implicitWidth: stackHeights.length * stackPitch - spriteGap * root.scale

    // Tall enough for the tallest stack at full lift, so the height is a
    // constant of the arrangement rather than growing as the bet is typed.
    implicitHeight: {
        var m = 0;
        for (var s = 0; s < root.stackHeights.length; ++s) {
            var h = root.chipHeight + root.pitch * (root.stackHeights[s] - 1) + root.riseAt(s, root.stackHeights.length);
            if (h > m)
                m = h;
        }
        return m;
    }

    // One item per stack. Nested rather than one flat run of chips so the two
    // movements stay out of each other's way: the stack slides and lifts as the
    // arrangement changes, leaving the drop animation sole owner of a chip's y
    // with no Behavior fighting it for the same property.
    Repeater {
        model: root.stackHeights.length

        Item {
            id: column

            required property int index

            readonly property int height_: root.chipHeight + root.pitch * Math.max(0, root.stackHeights[column.index] - 1)

            visible: root.chipsIn(column.index) > 0

            width: root.spriteWidth * root.scale
            height: column.height_

            x: root.originX + column.index * root.stackPitch
            y: root.height - column.height_ - root.riseAt(column.index, root.stacksUsed)

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: root.chipsIn(column.index)

                Image {
                    id: chip

                    required property int index

                    // Place in the whole bet, not in its own stack, so the
                    // colour keeps climbing across the gap into the next stack.
                    readonly property int place: root.offsetOf(column.index) + chip.index

                    // 1 while the chip is still in the air, 0 once it is down.
                    property real drop: 1

                    source: "assets/chip-" + (Math.floor(chip.place / 3) % Palette.chips.length) + ["a", "b", "c"][chip.place % 3] + ".png"

                    // Drawn at a whole multiple of its own size and never
                    // interpolated on the way up.
                    smooth: false

                    width: root.spriteWidth * root.scale
                    height: root.chipHeight

                    // Squarely on top of each other, no lateral wobble - one
                    // sprite on one pixel grid. The three bakes (a/b/c in
                    // `source` above) carry the variation instead.
                    x: 0
                    y: Math.round(column.height_ - root.chipHeight - chip.index * root.pitch - chip.drop * root.chipHeight * 3)
                    opacity: 1 - chip.drop
                    // Later chips in front, so each near rim overlaps the one
                    // below rather than being hidden.
                    z: chip.index

                    Component.onCompleted: land.start()

                    NumberAnimation {
                        id: land

                        target: chip
                        property: "drop"
                        from: 1
                        to: 0
                        // Short: anything slower and fast typing turns the
                        // stack into soup.
                        duration: 260
                        easing.type: Easing.OutBounce
                    }
                }
            }
        }
    }
}
