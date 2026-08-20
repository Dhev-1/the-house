import QtQuick
import "Palette.js" as Palette

// The bet. One chip per character typed, stacked edge on.
//
// This is the password field. There is no row of asterisks anywhere on this
// theme - the stack is the only feedback that a key landed, which means it has
// to be unambiguous at a glance and has to move, so a chip drops in with a
// bounce and the bet is visibly bigger than it was.
//
// Five stacks, and deliberately not five of the same height - 10, 4, 9, 7, 5.
// A rack of identical columns is a bar chart with nothing to say; real chips in
// front of a real player are whatever height the last few hands left them, and
// the uneven skyline is most of what makes this read as a table rather than as
// a progress bar. It also means the bet's shape is recognisable at a glance, so
// you can see roughly how far in you are without reading anything.
//
// The stacks sit on a circle rather than in a straight row - see `riseAt`.
//
// Sprites, not rectangles. The chip is a 29x14 pixel drawing in three-quarter
// view (assets/chip-src.png): the top face on rows 0-6, the near rim on rows
// 7-13. That split is the whole reason a stack of them works - lay each chip a
// rim's height above the one below and every chip shows its rim while only the
// top one shows its face, which is what a real stack does.
//
// A sprite has no colours to bind to, so the four denominations in Palette.js
// are baked into files by make-chips.py rather than tinted here. Re-run that
// after changing Palette.chips or redrawing the source.
Item {
    id: root

    // How many chips are in. Bind straight to the password length.
    property int count: 0

    // How tall each stack is allowed to get, left to right. The length of this
    // is how many stacks there are; the sum is how long a password the felt can
    // report. A knob in theme.conf.
    property var stackHeights: [10, 4, 9, 7, 5]

    property int chipWidth: 76

    // The sprite's own grid. Everything below is a whole multiple of this, so
    // the pixels stay square.
    readonly property int spriteWidth: 29
    readonly property int spriteHeight: 14

    // The rim, in source pixels: what one chip shows once another is lying on
    // it, and so the gap from one chip to the next.
    //
    // Five, which is the near rim of the drawing - rows 9-13, the spotted band
    // and the outline under it. Seven, the whole lower half, is the number the
    // geometry suggests and it is wrong: it leaves the shaded band under each
    // top face showing, and a stack of that reads as a column of separate discs
    // hanging in the air rather than as chips resting on each other. Five sits
    // them down on one another.
    readonly property int spriteRim: 5

    // The air between one stack and the next, in source pixels. Small on
    // purpose: stacks standing this close read as one bet spread out, where
    // stacks a chip's width apart read as separate bets.
    readonly property int spriteGap: 3

    // The radius of the circle the stacks stand on, in source pixels, centred
    // far below the felt. See `riseAt`.
    readonly property int spriteRadius: 110

    // How many screen pixels to one source pixel. Snapped to a whole number and
    // never below 1: at 3.3x a 29-wide sprite lands on a fractional boundary and
    // the outline that holds the whole drawing together goes to mush, which is
    // the one thing pixel art cannot survive. The stack is a few pixels off the
    // width it was asked for instead, which nothing can see.
    readonly property int scale: Math.max(1, Math.round(chipWidth / spriteWidth))

    readonly property int chipHeight: spriteHeight * root.scale

    // Fixed, both of them. One rim between chips, one chip plus the air between
    // stacks. An earlier version squeezed the vertical gap once the bet got
    // long, and a stack that changes its own spacing while you type reads as the
    // drawing breaking rather than as the bet growing; spreading sideways into
    // the next stack does the same job without touching the chips.
    readonly property int pitch: spriteRim * root.scale
    readonly property int stackPitch: (spriteWidth + spriteGap) * root.scale

    // The longest password the felt can report, and how much of `count` it is
    // actually showing. Past capacity the bet stops changing: the password keeps
    // taking characters, the felt just stops counting them.
    readonly property int capacity: {
        var t = 0;
        for (var s = 0; s < root.stackHeights.length; ++s)
            t += root.stackHeights[s];
        return t;
    }

    readonly property int shown: Math.min(count, capacity)

    // How many stacks have anything in them. At least one, so an empty bet still
    // has a width to be centred on rather than collapsing to nothing.
    readonly property int stacksUsed: {
        var t = 0;
        for (var s = 0; s < root.stackHeights.length; ++s) {
            t += root.stackHeights[s];
            if (root.shown <= t)
                return s + 1;
        }
        return root.stackHeights.length;
    }

    // The left edge of the block of stacks in use.
    //
    // The item is always as wide as every stack it could have, and the ones in
    // use are centred inside it. That is what keeps the bet centred in the
    // betting circle no matter how many stacks are out, without the item's own
    // width changing underneath whatever is laying it out. The cost is that
    // opening a new stack shifts the existing ones left - which is a real moment
    // worth seeing, so they slide rather than jump.
    readonly property int originX: Math.round((width - (stacksUsed * stackPitch - spriteGap * root.scale)) / 2)

    // How many chips are in the stacks to the left of `s`. The chip's place in
    // the whole bet, which is what picks its colour.
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

    // How far stack `s` of `n` is lifted off the baseline, in screen pixels.
    //
    // The stacks stand on a circle rather than in a straight line: one big
    // circle centred a long way below the felt, so the middle stack sits at the
    // bottom of it and the outer ones ride up the sides. Concave, the way chips
    // pushed out around the near edge of a betting circle sit - the felt is
    // round, so a row of stacks laid across it should be too, and a dead
    // straight row is the one arrangement that gives away that the table is
    // flat.
    //
    // A fixed radius rather than a fixed lift for the outermost stack. Radius
    // means one circle, and every stack sits where that circle actually puts it,
    // so the arc gets deeper as the bet spreads instead of being re-fitted to
    // whatever is currently out. Two stacks barely bend at all, which is right -
    // re-fitting would throw the whole bet upward the moment a second stack
    // opened, for no reason a player could see.
    //
    // 110 source pixels puts the outermost of five about twenty pixels up, and
    // the pair inside them about four. It wants to be roughly this tight: at 176
    // the arc is real but the stacks are all different heights anyway, so a lift
    // that small disappears into the skyline and the row just looks slightly
    // crooked. Turn it down for a deeper bowl, up for a flatter one; negate the
    // result for a dome instead.
    function riseAt(s: int, n: int): int {
        var dx = (s - (n - 1) / 2) * (root.spriteWidth + root.spriteGap);
        var r = root.spriteRadius;
        if (Math.abs(dx) >= r)
            return 0;
        return Math.round((r - Math.sqrt(r * r - dx * dx)) * root.scale);
    }

    implicitWidth: stackHeights.length * stackPitch - spriteGap * root.scale

    // Tall enough for the tallest stack standing at its full lift, so the item's
    // height is a constant of the arrangement rather than something that grows
    // while the bet is being typed.
    implicitHeight: {
        var m = 0;
        for (var s = 0; s < root.stackHeights.length; ++s) {
            var h = root.chipHeight + root.pitch * (root.stackHeights[s] - 1) + root.riseAt(s, root.stackHeights.length);
            if (h > m)
                m = h;
        }
        return m;
    }

    // One item per stack, holding that stack's chips.
    //
    // Nested rather than one flat run of chips because the two movements have to
    // stay out of each other's way: a stack slides and lifts as the arrangement
    // changes, and a chip drops as it is dealt. Sliding the stack and letting
    // the chips sit still inside it means the drop animation owns the chip's y
    // outright, with no Behaviour fighting it for the same property.
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

                    // Where this chip falls in the whole bet, not in its own
                    // stack: the colour keeps climbing straight across the gap
                    // from one stack into the next, so the stacks read as one
                    // long bet broken into columns rather than as five separate
                    // ones. Three chips to a colour - one apiece is a stripe,
                    // three is a band you can see.
                    readonly property int place: root.offsetOf(column.index) + chip.index

                    // 1 while the chip is still in the air, 0 once it is down.
                    property real drop: 1

                    source: "assets/chip-" + (Math.floor(chip.place / 3) % Palette.chips.length) + ["a", "b", "c"][chip.place % 3] + ".png"

                    // The sprite is drawn at a whole multiple of its own size
                    // and must not be interpolated on the way up - that is the
                    // difference between pixel art and a blurry photograph of
                    // pixel art.
                    smooth: false

                    width: root.spriteWidth * root.scale
                    height: root.chipHeight

                    // Stacked from the bottom of the column upward, squarely on
                    // top of each other, with no lateral wobble: the chips are
                    // all one sprite on one pixel grid, and knocking every other
                    // one sideways does not read as a hand-dealt stack leaning
                    // the way a real one does, it reads as a column that has
                    // been rendered wrong. The three bakes carry the variation
                    // instead - see the source above.
                    x: 0
                    y: Math.round(column.height_ - root.chipHeight - chip.index * root.pitch - chip.drop * root.chipHeight * 3)
                    opacity: 1 - chip.drop
                    // Later chips sit in front of earlier ones, so the near rim
                    // of each overlaps the one below rather than being hidden.
                    z: chip.index

                    Component.onCompleted: land.start()

                    NumberAnimation {
                        id: land

                        target: chip
                        property: "drop"
                        from: 1
                        to: 0
                        // Short, and it bounces. A chip is clay on wood: it
                        // arrives, it rattles once, it stops. Anything slower
                        // and fast typing turns the stack into soup.
                        duration: 260
                        easing.type: Easing.OutBounce
                    }
                }
            }
        }
    }
}
