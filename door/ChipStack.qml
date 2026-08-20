import QtQuick
import "Palette.js" as Palette

// The bet. One chip per character typed, stacked edge on.
//
// This is the password field. There is no row of asterisks anywhere on this
// theme - the stack is the only feedback that a key landed, which means it has
// to be unambiguous at a glance and has to move, so a chip drops in with a
// bounce and the bet is visibly bigger than it was.
//
// Ten to a stack, then a new stack beside it, four stacks at the most. That is
// how chips are actually handled: you build to a round number, you cap it, you
// start the next one. It also keeps the bet from ever climbing off the top of
// the screen without having to squash the chips together to do it - the earlier
// version tucked them closer and closer as the password grew, and a stack that
// changes its own spacing while you type reads as the drawing breaking rather
// than as the bet growing.
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

    // Ten high, four wide. Both are knobs in theme.conf.
    property int chipsPerStack: 10
    property int maxStacks: 4

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
    // purpose: four stacks standing this close read as one bet spread out,
    // where four stacks a chip's width apart read as four separate bets.
    readonly property int spriteGap: 3

    // How many screen pixels to one source pixel. Snapped to a whole number and
    // never below 1: at 3.3x a 29-wide sprite lands on a fractional boundary and
    // the outline that holds the whole drawing together goes to mush, which is
    // the one thing pixel art cannot survive. The stack is a few pixels off the
    // width it was asked for instead, which nothing can see.
    readonly property int scale: Math.max(1, Math.round(chipWidth / spriteWidth))

    readonly property int chipHeight: spriteHeight * root.scale

    // Fixed, both of them. The vertical gap is one rim, always - see the note
    // about squashing above. The horizontal one is a whole chip plus the air.
    readonly property int pitch: spriteRim * root.scale
    readonly property int stackPitch: (spriteWidth + spriteGap) * root.scale

    // How many chips actually get drawn. Past four full stacks the bet stops
    // changing: the password keeps taking characters, the felt just stops
    // reporting them. Forty is far past the point where anyone is counting
    // chips, and a bet that grew forever would either leave the screen or go
    // back to squashing itself.
    readonly property int shown: Math.min(count, chipsPerStack * maxStacks)

    // How many stacks those fill. At least one, so an empty bet still has a
    // width to be centred on rather than collapsing.
    readonly property int stacks: Math.max(1, Math.ceil(shown / chipsPerStack))

    // The left edge of the block of stacks.
    //
    // The item is always as wide as four stacks, and the stacks in use are
    // centred inside it. That is what keeps the bet centred in the betting
    // circle no matter how many stacks are out, without the item's own width
    // changing underneath whatever is laying it out. The cost is that opening a
    // new stack shifts the existing ones left by half a stack - which is a real
    // moment worth seeing, so the chips slide rather than jump.
    readonly property int originX: Math.round((width - (stacks * stackPitch - spriteGap * root.scale)) / 2)

    // Which denomination the chip at `i` is, as an index into Palette.chips.
    //
    // Off the chip's place in the whole bet, not its place in its own stack, so
    // the colour keeps climbing straight across the gap from one stack into the
    // next and the four stacks read as one long bet broken into columns. Three
    // chips to a colour: one apiece is a stripe, three is a band you can see.
    function denom(i: int): int {
        return Math.floor(i / 3) % Palette.chips.length;
    }

    // Which of the three bakes of that denomination to use.
    //
    // A sprite stack is one image repeated, so left alone every chip's edge
    // spots land at the same x and the stack reads as stripes running down it
    // rather than as discs lying on each other - the basketwork problem. The
    // sprite is left-right symmetric, so mirroring alternate chips does nothing
    // about it; make-chips.py bakes three copies with the rim clocked round by
    // different amounts instead. Cycling them by the same index the colour uses
    // means no chip is ever the same bake as the one it is sitting on.
    function variant(i: int): string {
        return ["a", "b", "c"][i % 3];
    }

    implicitWidth: maxStacks * stackPitch - spriteGap * root.scale
    implicitHeight: chipHeight + pitch * Math.max(0, chipsPerStack - 1)

    Repeater {
        model: root.shown

        Image {
            id: chip

            required property int index

            // Which stack this chip is in, and how high up that stack.
            readonly property int stack: Math.floor(chip.index / root.chipsPerStack)
            readonly property int row: chip.index % root.chipsPerStack

            // 1 while the chip is still in the air, 0 once it is on the stack.
            property real drop: 1

            source: "assets/chip-" + root.denom(chip.index) + root.variant(chip.index) + ".png"

            // The sprite is drawn at a whole multiple of its own size and must
            // not be interpolated on the way up - that is the difference between
            // pixel art and a blurry photograph of pixel art.
            smooth: false

            width: root.spriteWidth * root.scale
            height: root.chipHeight

            // Stacked from the bottom of the item upward, so the stacks grow
            // toward the top of the screen and their bases stay put on the felt.
            // Squarely on top of each other within a stack, with no lateral
            // wobble: the chips are all one sprite on one pixel grid, and
            // knocking every other one sideways does not read as a hand-dealt
            // stack leaning the way a real one does, it reads as a column that
            // has been rendered wrong. The three bakes carry the variation
            // instead - see `variant`.
            x: root.originX + chip.stack * root.stackPitch
            y: Math.round(root.height - root.chipHeight - chip.row * root.pitch - chip.drop * root.chipHeight * 3)
            opacity: 1 - chip.drop
            // Later chips sit in front of earlier ones, so the near rim of each
            // chip overlaps the one below it rather than being hidden by it.
            z: chip.index

            // Only ever fires when a new stack opens or closes and the block
            // re-centres; a Behavior does not run on a property's first value,
            // so a chip being dealt still arrives at its x directly and falls
            // straight down.
            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Component.onCompleted: land.start()

            NumberAnimation {
                id: land

                target: chip
                property: "drop"
                from: 1
                to: 0
                // Short, and it bounces. A chip is clay on wood: it arrives, it
                // rattles once, it stops. Anything slower than this and fast
                // typing turns the stack into soup.
                duration: 260
                easing.type: Easing.OutBounce
            }
        }
    }
}
