"""Draft layout of the mission map «ВКЛ 2. Грюнвальд» (map_gdl_02), 160×176.

    python3 -m tools.maps.gen_gdl_02      # writes maps/map_gdl_02/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Units are not in the map:
missions/gdl_02/mission.json places them on the cells named below.

From the mission card (section «Карта»): a hilly plain with copses and boggy streams after the
night's rain, forest at the edges; the Order in the north, the forest the allies came out of in
the south. The Lithuanian wing (the player) stands on the right, against Wallenrode; the Polish
centre by Stębark; the Smolensk banners at the joint; the Order's bombards in front of its left
wing; the forest in the south-east is the rally point after the retreat; the wagenburg is in the
Order's rear by Grunwald. Places of power: a lone oak on a hill nearest the start, a spring in a
hollow behind Wallenrode's line, a kurgan by Ludwikowo in the Order's rear on the reserve's way.
The layout follows the card, not a survey of the field (the card leaves Ekdahl's reconstruction
open).
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 160
H = 176
SEED = 1410
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_02" / "terrain.txt"

# Top-left cells of the 2×2 sites: lone oak, spring, kurgan.
PLACES = [
    ("pp_old_tree", 127, 95),
    ("pp_spring", 121, 41),
    ("pp_kurgan", 44, 37),
]


def blob(grid, cx, cy, r, ch, keep=("~", "=", "#")):
    for y in range(max(0, int(cy - r - 2)), min(H, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(W, int(cx + r + 3))):
            wobble = r * (0.75 + 0.25 * math.sin(x * 0.7 + y * 0.4 + cx))
            if (x - cx) ** 2 + (y - cy) ** 2 <= wobble**2 and grid[y][x] not in keep:
                grid[y][x] = ch


def line(grid, points, ch, width=1, keep=()):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            for dy in range(width):
                for dx in range(width):
                    if 0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx] not in keep:
                        grid[y + dy][x + dx] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Forest along the edges: thick in the south (where the allies came from) and the
    # south-east (the rally point), thinner in the west and north.
    for x in range(W):
        south = 150 + round(4 * math.sin(x / 9.0))
        for y in range(south, H):
            g[y][x] = "f"
        for y in range(0, 3 + round(2 * math.sin(x / 7.0))):
            g[y][x] = "f"
    for y in range(H):
        for x in range(0, 4 + round(2 * math.sin(y / 6.0))):
            g[y][x] = "f"
        for x in range(W - 3 - round(2 * math.sin(y / 5.0)), W):
            g[y][x] = "f"
    # The south-east forest: the rally point after the retreat, with a clearing at its edge.
    blob(g, 148, 152, 18, "f")
    blob(g, 150, 160, 9, "F")
    blob(g, 138, 142, 5, ".", keep=())
    # Copses on the plain, kept off the two battle lines and the valley's middle.
    for _ in range(26):
        x, y = rng.randrange(8, W - 8), rng.randrange(10, 145)
        if 52 <= y <= 74 or 104 <= y <= 122:
            continue
        blob(g, x, y, rng.randrange(2, 5), "f")
    # Boggy streams across the valley after the night's rain, with firm crossings.
    for pts in (
        [(20, 80), (45, 86), (70, 82), (92, 90)],
        [(96, 96), (112, 88), (140, 92), (156, 84)],
    ):
        line(g, pts, "b", width=3)
    for cx, cy in ((58, 84), (104, 93), (130, 90)):
        blob(g, cx, cy, 2, ".", keep=())
    # Low wet hollows.
    for cx, cy in ((34, 98), (80, 100)):
        blob(g, cx, cy, 4, "b")
    # Fields of the villages: Grunwald in the Order's rear, Stębark by the Polish centre,
    # Ludwikowo behind the Order's right.
    for cx, cy, r in ((64, 18, 9), (70, 132, 7), (36, 24, 6)):
        blob(g, cx, cy, r, ",")
    # Hills: the lone oak by the start, the bombards' rise, the kurgan, the king's hill.
    blob(g, 128, 96, 5, "h")
    blob(g, 114, 64, 6, "h", keep=("~",))
    blob(g, 45, 38, 3, "h", keep=())
    blob(g, 76, 140, 5, "h")
    # The spring in a hollow behind Wallenrode's line.
    blob(g, 122, 42, 4, ".", keep=())
    g[44][124] = "~"
    g[44][125] = "~"
    # The wagenburg's ground by Grunwald: open, flat.
    blob(g, 66, 30, 8, ".", keep=())
    # Roads: Grunwald to Stębark across the field, and the road the reserve takes.
    line(g, [(64, 10), (66, 30), (68, 60), (70, 100), (70, 150)], "#", width=2, keep=("~",))
    line(g, [(36, 20), (52, 30), (66, 30), (100, 28), (150, 20)], "#", width=2, keep=("~",))
    # The two lines stand on open ground.
    for y in range(54, 73):
        for x in range(10, 150):
            if g[y][x] in "fF":
                g[y][x] = "."
    for y in range(104, 124):
        for x in range(10, 150):
            if g[y][x] in "fF":
                g[y][x] = "."
    # Clearings for the places of power.
    for _, x, y in PLACES:
        blob(g, x + 1, y + 1, 2, "h" if (x, y) != (121, 41) else ".", keep=("~", "#"))
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_02 «ВКЛ 2. Грюнвальд» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_02.py, seed {SEED}; edit by hand from here.",
        "; The Order in the north (Wallenrode's wing on the east, bombards before it, the",
        "; wagenburg by Grunwald), the allies in the south (Lithuanians on the east, Smolensk at",
        "; the joint, the Polish centre), the rally forest in the south-east.",
        "; Units: missions/gdl_02/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
