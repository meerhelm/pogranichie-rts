"""Draft layout of the mission map «ВКЛ 1. Жемайтский огонь» (map_gdl_01), 160×160.

    python3 -m tools.maps.gen_gdl_01      # writes maps/map_gdl_01/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
(M9) and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings and units
are not in the map: missions/gdl_01/mission.json places them on the cells named below.

From the mission card (section «Карта»): dense mixed forest with bogs in the north and the
middle, the Neman along the south, the Dubysa coming down to it from the north. The player
starts in the forest in the north-east (Gintaut's village with a bort forest, a lake and a bog
with ore); the sacred grove is a hill in the middle; the Order's wooden castles stand on the
river: Skirsnemune on the high bank with a pier below it, Dubysa at the mouth of the Dubysa.
A forest road comes in from the east (Rumbaudas, phase 3). Seven places of power: the grove,
a spring and a «snake stone» near the two castles (consecrated by the Order), a kurgan, a
footprint stone, an old hillfort and a bog island.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

SIZE = 160
SEED = 1409
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_01" / "terrain.txt"

# Top-left cells of the 2×2 sites. The snake stone has no place kind of its own in the catalog:
# it is a pp_footprint_stone (a stone with marks) until the catalog gets one.
PLACES = [
    ("pp_oak_grove", 79, 75),
    ("pp_spring", 112, 106),
    ("pp_kurgan", 140, 96),
    ("pp_footprint_stone", 108, 6),
    ("pp_hillfort", 20, 40),
    ("pp_bog_island", 66, 34),
    ("pp_footprint_stone", 66, 116),
]


def blob(grid, cx, cy, r, ch, keep=("~", "=", "#")):
    for y in range(max(0, int(cy - r - 2)), min(SIZE, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(SIZE, int(cx + r + 3))):
            wobble = r * (0.75 + 0.25 * math.sin(x * 0.7 + y * 0.4 + cx))
            if (x - cx) ** 2 + (y - cy) ** 2 <= wobble**2 and grid[y][x] not in keep:
                grid[y][x] = ch


def rect(grid, x0, y0, x1, y1, ch, keep=()):
    for y in range(max(0, y0), min(SIZE, y1 + 1)):
        for x in range(max(0, x0), min(SIZE, x1 + 1)):
            if grid[y][x] not in keep:
                grid[y][x] = ch


def line(grid, points, ch, width=1, keep=()):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            for dy in range(width):
                for dx in range(width):
                    if 0 <= x + dx < SIZE and 0 <= y + dy < SIZE and grid[y + dy][x + dx] not in keep:
                        grid[y + dy][x + dx] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(SIZE)] for _ in range(SIZE)]
    # Dense mixed forest in the north and the middle, old forest cores, bogs.
    for _ in range(110):
        x, y = rng.randrange(0, SIZE), rng.randrange(0, 125)
        blob(g, x, y, rng.randrange(4, 10), "f")
    for _ in range(10):
        x, y = rng.randrange(10, 150), rng.randrange(10, 110)
        blob(g, x, y, rng.randrange(2, 4), "F")
    for cx, cy in ((66, 34), (30, 90), (100, 56), (140, 70)):
        blob(g, cx, cy, 7, "b")
        blob(g, cx, cy, 3, "B")
    # The bog island: firm ground in the middle of the bog.
    blob(g, 67, 35, 2, ".", keep=())
    # Half-empty fields of the abandoned farmsteads along the river.
    for cx, cy in ((76, 128), (128, 120), (30, 120), (140, 132)):
        blob(g, cx, cy, rng.randrange(4, 7), ",")
    # The Neman along the south, sand banks, the Prussian bank beyond.
    for x in range(SIZE):
        top = 144 + round(2 * math.sin(x / 13.0))
        for y in range(top - 2, top):
            g[y][x] = "s"
        for y in range(top, min(SIZE, top + 8)):
            g[y][x] = "~"
        for y in range(top + 8, SIZE):
            g[y][x] = "s" if y == top + 8 else "."
    # The Dubysa from the north down to the Neman, with three fords.
    river = [(40, 0), (36, 30), (42, 60), (38, 90), (44, 120), (42, 144)]
    line(g, river, "s", width=5, keep=("~",))
    line(g, [(x + 1, y) for x, y in river], "~", width=3)
    for fy in (30, 76, 116):
        for x in range(SIZE):
            if any(g[fy + dy][x] == "~" for dy in range(3)):
                for dy in range(3):
                    if g[fy + dy][x] in "~s":
                        g[fy + dy][x] = "="
    # Gintaut's village in the north-east: a clearing, a lake, a bog with ore, a bort forest.
    blob(g, 125, 21, 12, ".", keep=())
    blob(g, 141, 37, 5, "~", keep=())
    blob(g, 107, 40, 5, "b", keep=())
    for x, y in ((106, 39), (108, 40), (107, 42)):
        g[y][x] = "o"
    blob(g, 148, 10, 8, "f", keep=("~",))
    blob(g, 147, 9, 3, "F", keep=("~",))
    # The sacred grove: a hill in the middle under old oaks, with a clearing on top.
    blob(g, 80, 76, 10, "F", keep=("~", "=", "#"))
    blob(g, 80, 76, 6, "h", keep=())
    # The high bank of Skirsnemune and the low ground of Dubysa.
    blob(g, 99, 125, 10, "h", keep=("~", "s"))
    blob(g, 56, 128, 9, ".", keep=("~", "s", "="))
    # Roads: from the east to the village, from the village to Skirsnemune and the pier,
    # along the river to Dubysa, and the grove path.
    line(g, [(159, 64), (140, 60), (128, 46), (126, 28)], "#", width=2, keep=("~",))
    line(g, [(124, 30), (112, 60), (104, 96), (100, 117)], "#", width=2, keep=("~",))
    line(g, [(108, 132), (112, 141), (113, 147)], "#", width=2)
    line(g, [(96, 134), (80, 134), (60, 132), (54, 132)], "#", width=2, keep=("~",))
    line(g, [(110, 66), (94, 72), (84, 76)], "#", width=2, keep=("~",))
    # Clearings for the places of power and the start.
    for _, x, y in PLACES:
        blob(g, x + 1, y + 1, 3, "h" if (x, y) == (79, 75) else ".", keep=("~", "#"))
    blob(g, 21, 41, 4, "h", keep=("~", "#", "="))
    blob(g, 67, 35, 2, ".", keep=())
    # The castles' yards are cleared ground (the mission puts palisades around them).
    rect(g, 92, 118, 107, 133, "h")
    rect(g, 48, 121, 62, 135, ".", keep=("~", "s", "="))
    rect(g, 114, 12, 136, 30, ".", keep=("#",))
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        "; map_gdl_01 «ВКЛ 1. Жемайтский огонь» (mission), 160x160.",
        f"; First draft by tools/maps/gen_gdl_01.py, seed {SEED}; edit by hand from here.",
        "; Player north-east (village), grove hill in the middle, Skirsnemune and its pier on the",
        "; Neman in the south, Dubysa castle at the Dubysa mouth in the south-west.",
        "; Buildings and units: missions/gdl_01/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
