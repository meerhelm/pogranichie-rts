"""Draft layout of the mission map «Корона 6. Свецино, 1462» (map_crown_06), 140×100.

    python3 -m tools.maps.gen_crown_06      # writes maps/map_crown_06/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. The wagons, the ditch,
the village and the units are not in the map: missions/crown_06/mission.json places them on
the cells named below (the ditch is dug in the game, rules.swiecino.ditch).

From the mission card (section «Карта»): September, clear, hot and dusty by noon. The open
field between the two wagon forts, water on the edges: the little lake (Rogoźnica in the
sources) on the left of the Polish line, its shore in reeds where the Gdańsk crossbowmen
stand; the long Lake Żarnowiec along the east edge with the road to Żarnowiec on its shore;
the Order's wagon fort on a rise across the field (hill 82 in the Polish local histories, some
500–600 m from the Polish camp); the forest road in the west the Pomeranian peasants come out
of; the wayside cross at Świecino, the little chapel on the lake shore and the boulder at the
ford. Sizes and distances are a game assumption.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 140
H = 100
SEED = 1462
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_crown_06" / "terrain.txt"

# Places of power (top-left of the 2×2 site): the wayside cross at Świecino, the little
# chapel on the shore of Lake Żarnowiec, the boulder at the ford of the brook.
PLACES = [("pp_wayside", 88, 58), ("pp_spring", 104, 34), ("pp_footprint_stone", 82, 88)]
# The Polish camp (centre, half-size of the clear ground) and the Order's rise.
CAMP = (46, 74, 12)
RISE = (74, 20, 7)
# The little lake and its reeds (the crossbowmen's cover).
LITTLE_LAKE = (22, 64, 7)
REEDS = (29, 56, 35, 72)
# Lake Żarnowiec: its west shore wobbles round this column.
SHORE_X = 116
# The brook from the south-west into the lake, and its ford.
BROOK_Y = 91
FORD_X = (78, 80)
ROADS = [
    [(0, 24), (30, 23), (62, 21)],  # the west forest road to the Order's rise
    [(SHORE_X - 6, 0), (SHORE_X - 7, 50), (SHORE_X - 8, H - 1)],  # the shore road to Żarnowiec
    [(56, 76), (79, 86), (79, H - 1)],  # the Polish camp to the ford and south
    [(81, 24), (SHORE_X - 7, 30)],  # the rise to the shore road
]


def blob(grid, cx, cy, r, ch, keep=("~", "#", "h")):
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


def clear(grid, cx, cy, r, ch="."):
    for y in range(max(0, cy - r), min(H, cy + r + 1)):
        for x in range(max(0, cx - r), min(W, cx + r + 1)):
            if grid[y][x] in "fF,b":
                grid[y][x] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Stubble fields round Świecino, copses of pine on the dry sand.
    for _ in range(36):
        blob(g, rng.randrange(20, 110), rng.randrange(8, 96), rng.randrange(3, 6), ",")
    for _ in range(10):
        blob(g, rng.randrange(84, 110), rng.randrange(40, 96), rng.randrange(2, 4), "s")
    # The forest: along the north edge and the west edge, round the forest road.
    for y in range(H):
        for x in range(W):
            if y < 6 + 2 * math.sin(x * 0.15) and x < SHORE_X - 10:
                g[y][x] = "f"
            if x < 7 + 2 * math.sin(y * 0.2):
                g[y][x] = "f"
    for _ in range(12):
        blob(g, rng.randrange(0, 18), rng.randrange(6, 96), rng.randrange(3, 6), "f")
    for _ in range(8):
        blob(g, rng.randrange(84, 108), rng.randrange(66, 96), rng.randrange(2, 4), "f")
    # Lake Żarnowiec along the east edge, a reedy margin on its shore.
    for y in range(H):
        edge = SHORE_X + 3 * math.sin(y * 0.11) + 1.5 * math.sin(y * 0.37)
        for x in range(W):
            if x >= edge:
                g[y][x] = "~"
            elif x >= edge - 1 and g[y][x] != "#":
                g[y][x] = "b"
    # The little lake with reeds on its east shore.
    lx, ly, lr = LITTLE_LAKE
    blob(g, lx, ly, lr + 2, "b", keep=())
    blob(g, lx, ly, lr, "~", keep=())
    x0, y0, x1, y1 = REEDS
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if g[y][x] != "~" and (x - lx) ** 2 + (y - ly) ** 2 <= (lr + 8) ** 2:
                g[y][x] = "b"
    # The brook into the lake, with its ford.
    for x in range(30, W):
        y = BROOK_Y + round(1.5 * math.sin(x * 0.12))
        if g[y][x] == "~":
            break
        g[y][x] = "~"
        g[y + 1][x] = "~"
        if FORD_X[0] <= x <= FORD_X[1]:
            g[y][x] = "="
            g[y + 1][x] = "="
    # The rise of the Order's wagon fort.
    hx, hy, hr = RISE
    for y in range(hy - hr, hy + hr + 1):
        for x in range(hx - hr, hx + hr + 1):
            if (x - hx) ** 2 + (y - hy) ** 2 <= hr * hr:
                g[y][x] = "h"
    # The Polish camp and the field: open, dry ground.
    cx, cy, cr = CAMP
    clear(g, cx, cy, cr)
    for y in range(30, 62):
        for x in range(36, 100):
            if g[y][x] in "fb":
                g[y][x] = "."
    for points in ROADS:
        line(g, points, "#", width=2 if points[0] == (0, 24) else 1, keep=("~", "="))
    for _kind, px, py in PLACES:
        for y in range(py - 1, py + 3):
            for x in range(px - 1, px + 3):
                if g[y][x] in "fFbB~#":
                    g[y][x] = "."
    return ["".join(row) for row in g]


def write(rows: list[str]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        f"; map_crown_06 «Корона 6. Свецино, 1462» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_crown_06.py, seed {SEED}; edit by hand from here.",
        f"; The Polish camp ({CAMP[0]}, {CAMP[1]}) with the little lake west of it and its reeds",
        f"; (x {REEDS[0]}-{REEDS[2]}, y {REEDS[1]}-{REEDS[3]}), the field (y 30-62), the Order's rise",
        f"; ({RISE[0]}, {RISE[1]}), the west forest road (row 24), Lake Żarnowiec from x ~{SHORE_X}",
        f"; with the shore road, the brook on row ~{BROOK_Y} and its ford (x {FORD_X[0]}-{FORD_X[1]}).",
        "; Wagons, the ditch, buildings and units: missions/crown_06/mission.json.",
        "; Legend: core/nav/map_text.gd.",
    ]
    for kind, px, py in PLACES:
        head.append(f"@place {kind} {px} {py}")
    OUT.write_text("\n".join(head + rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write(generate())
