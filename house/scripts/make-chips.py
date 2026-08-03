#!/usr/bin/env python3
"""Bake one poker chip per table.

The shell tints everything live off Config.colours, but a chip is a sprite, not
a rectangle - there is nothing to re-colour at runtime without a shader pass.
So the chips are baked instead: one PNG per table, picked by name at load time
(components/Chip.qml). Cheap, no effects dependency, and a table swap is just a
different file.

Run this after adding a table to Config.qml, or after changing an existing
table's surface / text / accent:

    python3 house/scripts/make-chips.py

Input is the three region masks in house/assets - body, stripes and edge, cut
from the 33x33 source sprite. Each is white-on-transparent; this paints them.

The mapping, per table:

    body     accent          the chip's colour, so it reads as that table
    stripes  text or surface whichever of the two is lighter - the edge spots
                             on a real chip are the pale ones, and on the one
                             light table (Daylight Robbery) that is the surface,
                             not the text
    edge     accent darkened the moulded rim. Not surface: on every table the
                             bar behind the chip *is* surface, so a surface rim
                             is an invisible one. A darker shade of the body
                             reads against both the chip and the bar, on light
                             tables and dark ones alike.
"""

import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow: pacman -S python-pillow")

HOUSE = Path(__file__).resolve().parent.parent
ASSETS = HOUSE / "assets"
CONFIG = HOUSE / "Config.qml"

# How far the rim is dragged toward black from the body colour.
EDGE_DARKEN = 0.62


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def luminance(rgb):
    """Rec. 709 relative luminance, 0..255."""
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def darken(rgb, t):
    return tuple(round(c * (1 - t)) for c in rgb)


def read_themes(path):
    """Pull name / surface / text / accent out of Config.qml's themes array.

    Deliberately dumb: the themes are plain literal blocks, each opening with a
    name, so a scan for those four keys in order is enough. If Config.qml's
    shape ever changes this will come up short rather than silently wrong - the
    count is checked by the caller.
    """
    src = path.read_text()
    themes = []
    for block in re.finditer(
        r'name:\s*"(\w+)".*?surface:\s*"(#[0-9a-fA-F]{6})".*?'
        r'text:\s*"(#[0-9a-fA-F]{6})".*?accent:\s*"(#[0-9a-fA-F]{6})"',
        src,
        re.S,
    ):
        name, surface, text, accent = block.groups()
        themes.append({
            "name": name,
            "surface": hex_to_rgb(surface),
            "text": hex_to_rgb(text),
            "accent": hex_to_rgb(accent),
        })
    return themes


def paint(masks, colours):
    """Stack the three masks, each flooded with its colour."""
    size = masks["body"].size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for region in ("body", "stripes", "edge"):
        layer = Image.new("RGBA", size, colours[region] + (255,))
        out.paste(layer, (0, 0), masks[region])
    return out


def main():
    masks = {}
    for region in ("body", "stripes", "edge"):
        p = ASSETS / f"chip-{region}.png"
        if not p.exists():
            sys.exit(f"missing mask: {p}")
        masks[region] = Image.open(p).convert("RGBA").getchannel("A")

    themes = read_themes(CONFIG)
    if not themes:
        sys.exit(f"no themes parsed out of {CONFIG}")

    for t in themes:
        # The pale one of the pair: text on the dark tables, surface on the
        # light one. Keeps the edge spots reading as spots either way.
        stripes = max((t["text"], t["surface"]), key=luminance)
        colours = {
            "body": t["accent"],
            "stripes": stripes,
            "edge": darken(t["accent"], EDGE_DARKEN),
        }
        chip = paint(masks, colours)
        dest = ASSETS / f"chip-{t['name']}.png"
        chip.save(dest)
        print(f"  {dest.relative_to(HOUSE.parent)}  "
              f"body={colours['body']} stripes={colours['stripes']} "
              f"edge={colours['edge']}")

    print(f"baked {len(themes)} chips")


if __name__ == "__main__":
    main()
