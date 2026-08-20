#!/usr/bin/env python3
"""Bake the bet stack's chips from the pixel sprite.

ChipStack.qml draws the bet as sprites rather than as rectangles, and a sprite
has no colours to bind to - so the four denominations in Palette.js are baked
into files here instead, and the stack picks one by name.

    python3 door/make-chips.py

Input is assets/chip-src.png: one 29x14 chip in three-quarter view, five
colours, top face on rows 0-6 and the near rim on rows 7-13. Output is twelve
files, assets/chip-<denomination><variant>.png - four denominations wide, three
variants deep.

Why three variants. A sprite stack is the same image repeated, so every chip's
edge spots land at the same x and the stack reads as vertical stripes running
down it rather than as discs lying on each other - the basketwork the drawn
version avoided by rolling each chip's banding (see the note in ChipStack.qml).
The sprite is left-right symmetric, so mirroring alternate chips does nothing.
Rolling the rim bands does: each variant slides the spot pattern a few pixels
round the rim, ChipStack picks between them off the chip's index, and no two
neighbours are clocked the same way.

Run this after changing Palette.chips, or after redrawing chip-src.png.
"""

import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow: pacman -S python-pillow")

DOOR = Path(__file__).resolve().parent
ASSETS = DOOR / "assets"
PALETTE = DOOR / "Palette.js"
SRC = ASSETS / "chip-src.png"

# The five colours in the source art, and what each one is.
OUTLINE = (5, 1, 0)      # the silhouette, all the way round
RECESS = (0, 0, 0)       # the moulded inlay ring, and the shade under the face
BODY = (255, 43, 0)      # the clay
SHADE = (255, 0, 0)      # the clay where the rim turns away from the light
SPOT = (255, 255, 255)   # the edge spots

VARIANTS = ["a", "b", "c"]

# How far each variant slides the rim bands round, in pixels. Coprime-ish with
# the ~9px spot period so the three do not collapse back onto each other.
ROLLS = [0, 3, 6]

# A band has to be this long to count as rim rather than as one of the small
# lobes at the chip's left and right, which are shading and must not move.
MIN_BAND = 10


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def luminance(rgb):
    """Rec. 709 relative luminance, 0..255."""
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def read_chips(path):
    """Pull body and spot out of Palette.js's chips array, in order.

    Deliberately dumb, the same way house/scripts/make-chips.py is: the entries
    are plain literal blocks in a fixed key order, so a scan for the two keys is
    enough. If Palette.js's shape ever changes this comes up short rather than
    silently wrong, and the caller checks the count.
    """
    src = path.read_text()
    block = re.search(r"var chips = \[(.*?)\n\];", src, re.S)
    if not block:
        sys.exit(f"no chips array found in {path}")

    chips = []
    for m in re.finditer(
        r'body:\s*"(#[0-9a-fA-F]{6})".*?spot:\s*"(#[0-9a-fA-F]{6})"',
        block.group(1),
        re.S,
    ):
        chips.append({
            "body": hex_to_rgb(m.group(1)),
            "spot": hex_to_rgb(m.group(2)),
        })
    return chips


def palette_for(chip):
    """Map the source art's five colours onto one denomination.

    The art is built the way a mould is: a near-black skeleton - the silhouette
    and the ring around the inlay - holding bright clay and pale spots. That
    contrast is the whole drawing, so the skeleton has to stay much darker than
    the body it is drawn on, whatever colour the body is. Tinting it toward the
    body by a fixed fraction does not do that: at 70% a light clay's outline
    comes out mid-grey, which against light clay is a pencil line, and the chip
    goes soft. 85% keeps it a skeleton.

    The black chip inverts the problem. Its body is darker than the felt it is
    lying on, so a dark skeleton on it is a dark line on a dark disc on a dark
    cloth - three shades of nothing. That one lifts its skeleton toward its own
    spot colour instead: the mould reads as light-on-dark rather than
    dark-on-light, and the chip keeps an edge.

    A fifth of the way and no further. The skeleton is the largest area in the
    drawing - more of the sprite than the clay is - so a lift big enough to be
    obvious stops being an outline on a black chip and becomes a grey chip. At
    0.42, which is what this was while the spots were gold, white spots take the
    skeleton to mid-grey and the black chip disappears from its own stack. It
    only has to clear the cloth, and the white spots do the rest.

    The threshold is 32 rather than something nearer the middle of the range
    because the two cases are not evenly spread. Of the current four, black sits
    at 17 and red, blue and purple all land between 68 and 75 - so anything
    short of genuinely near-black wants the dark skeleton, and a line drawn just
    above black is the one that does not flip a chip into the wrong treatment
    the next time somebody nudges a hex code.
    """
    body, spot = chip["body"], chip["spot"]
    if luminance(body) > 32:
        outline = mix(body, (0, 0, 0), 0.85)
        recess = mix(body, (0, 0, 0), 0.55)
    else:
        outline = mix(body, spot, 0.20)
        recess = mix(body, spot, 0.07)

    return {
        OUTLINE: outline,
        RECESS: recess,
        BODY: body,
        SHADE: mix(body, (0, 0, 0), 0.18),
        SPOT: spot,
    }


def bands(row):
    """The runs of clay in one row of the sprite, as (start, end) pairs.

    A run is bounded by the outline or by transparency, and is only a rim band
    if it holds no recess pixels - the rows through the inlay ring have their
    own structure and rolling them would smear it round the chip.
    """
    out = []
    start = None
    for x, px in enumerate(row + [None]):
        solid = px is not None and px[3] > 0 and px[:3] != OUTLINE
        if solid and start is None:
            start = x
        elif not solid and start is not None:
            run = row[start:x]
            if x - start >= MIN_BAND and all(p[:3] != RECESS for p in run):
                out.append((start, x))
            start = None
    return out


def roll(src, amount):
    """Slide the rim bands round the chip by `amount` pixels.

    Only the colours move: each band's pixels are rotated within the span they
    already occupy, so the silhouette, the outline and the inlay are all exactly
    where they were and only the spots are clocked differently.
    """
    if amount == 0:
        return src.copy()

    out = src.copy()
    w, h = src.size
    px = out.load()
    for y in range(h):
        row = [src.getpixel((x, y)) for x in range(w)]
        for start, end in bands(row):
            span = row[start:end]
            n = len(span)
            for i in range(n):
                px[start + i, y] = span[(i - amount) % n]
    return out


def paint(src, mapping):
    """Recolour the sprite, one source colour to one destination colour."""
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    w, h = src.size
    dst = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src.getpixel((x, y))
            if a == 0:
                continue
            colour = mapping.get((r, g, b))
            if colour is None:
                sys.exit(f"unmapped colour {(r, g, b)} at {x},{y} in {SRC.name}")
            dst[x, y] = colour + (255,)
    return out


def main():
    if not SRC.exists():
        sys.exit(f"missing source sprite: {SRC}")

    src = Image.open(SRC).convert("RGBA")
    if src.size != (29, 14):
        sys.exit(f"expected a 29x14 sprite, got {src.size[0]}x{src.size[1]}")

    chips = read_chips(PALETTE)
    if not chips:
        sys.exit(f"no chips parsed out of {PALETTE}")

    written = 0
    for i, chip in enumerate(chips):
        mapping = palette_for(chip)
        for variant, amount in zip(VARIANTS, ROLLS):
            art = paint(roll(src, amount), mapping)
            dest = ASSETS / f"chip-{i}{variant}.png"
            art.save(dest)
            written += 1
        print(f"  chip-{i}[{''.join(VARIANTS)}].png  "
              f"body=#{'%02x%02x%02x' % chip['body']} "
              f"spot=#{'%02x%02x%02x' % chip['spot']} "
              f"outline=#{'%02x%02x%02x' % mapping[OUTLINE]}")

    print(f"baked {written} sprites into {ASSETS.relative_to(DOOR.parent)}")


if __name__ == "__main__":
    main()
