"""Draft layout of the mission map «Корона 5. Серебро для Мальборка, 1457» (map_crown_05), 150×120.

    python3 -m tools.maps.gen_crown_05      # writes maps/map_crown_05/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Gdańsk, Tczew, Malbork,
the villages and the units are not in the map: missions/crown_05/mission.json places them on
the cells named below.

From the mission card (section «Карта»): the flat delta of the Żuławy between the Vistula in
the west and the Nogat in the east, polders, dikes and canals. Gdańsk in the north-west and
Tczew in the south-west on the left bank of the Vistula, Malbork on the right bank of the Nogat
in the south-east, the Order's land east of the Nogat. Sizes and distances are a game
assumption; the canal across the middle stands for the many ditches of the Żuławy.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 150
H = 120
SEED = 1457
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_crown_05" / "terrain.txt"

# Places of power (top-left of the 2×2 site): the cross by the ferry, the chapel on the dike.
PLACES = [("pp_wayside", 74, 64), ("pp_wayside", 60, 86)]
# The canal across the delta (rows CANAL, +1), its crossings (dike bridges and the ferry).
CANAL = 60
CROSSINGS = [50, 70, 71, 90]
# Fords of the Nogat the Order's riders use (rows), the castle bridge (rows).
FORDS = [14, 15, 112, 113]
CASTLE_BRIDGE = [92, 93]
# Ferries over the Vistula: Gdańsk, Tczew (rows).
VISTULA_FERRIES = [22, 23, 102, 103]
# Towns kept clear: Gdańsk, Tczew, Malbork (x0, y0, x1, y1).
TOWNS = [(2, 2, 30, 30), (6, 92, 26, 114), (107, 82, 128, 104)]
VILLAGES = [(52, 36), (84, 34), (88, 72), (54, 78), (72, 96), (44, 100)]
STATION = (68, 54)
PIER = (110, 38)
ROADS = [
    [(30, 22), (44, 22), (52, 36), (68, 50), (84, 34), (108, 38)],  # Gdańsk ferry to the pier
    [(68, 50), (70, 59), (70, 66), (54, 78), (44, 100), (36, 102)],  # station south, Tczew
    [(70, 66), (88, 72), (98, 92)],  # to the castle bridge
    [(54, 78), (72, 96), (98, 93)],
    [(50, 40), (50, 70)],
    [(90, 40), (90, 70)],
]


def vistula(y: int) -> int:
    return 38 - 8 * y // (H - 1)


def nogat(y: int) -> int:
    return 124 - 26 * y // (H - 1)


def blob(grid, cx, cy, r, ch, keep=("~", "#", "=")):
    for y in range(max(0, int(cy - r - 2)), min(H, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(W, int(cx + r + 3))):
            wobble = r * (0.75 + 0.25 * math.sin(x * 0.7 + y * 0.4 + cx))
            if (x - cx) ** 2 + (y - cy) ** 2 <= wobble**2 and grid[y][x] not in keep:
                grid[y][x] = ch


def line(grid, points, ch, keep=("~",)):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            if 0 <= x < W and 0 <= y < H and grid[y][x] not in keep:
                grid[y][x] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Polder fields and a few willow copses in the delta; wet hollows.
    for _ in range(46):
        blob(g, rng.randrange(40, 108), rng.randrange(4, 116), rng.randrange(3, 6), ",")
    for _ in range(10):
        blob(g, rng.randrange(42, 100), rng.randrange(4, 116), rng.randrange(1, 3), "f")
    for _ in range(8):
        blob(g, rng.randrange(44, 100), rng.randrange(6, 114), rng.randrange(2, 4), "b")
    # Woods on the high left bank behind the towns, and the Order's forests east of the Nogat.
    for _ in range(14):
        blob(g, rng.randrange(0, 28), rng.randrange(32, 92), rng.randrange(3, 6), "f")
    for _ in range(26):
        blob(g, rng.randrange(126, W), rng.randrange(0, H), rng.randrange(3, 7), "f")
    for x0, y0, x1, y1 in TOWNS:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = "."
    # The rivers: the Vistula five cells wide, the Nogat four; the canal two.
    for y in range(H):
        for x in range(vistula(y) - 2, vistula(y) + 3):
            g[y][x] = "~"
        for x in range(nogat(y) - 2, nogat(y) + 2):
            g[y][x] = "~"
    for y in (CANAL, CANAL + 1):
        for x in range(vistula(y) + 3, nogat(y) - 2):
            g[y][x] = "~"
    for _kind, px, py in PLACES:
        for y in range(py - 1, py + 3):
            for x in range(px - 1, px + 3):
                g[y][x] = "."
    for vx, vy in VILLAGES:
        for y in range(vy - 3, vy + 4):
            for x in range(vx - 3, vx + 4):
                if g[y][x] != "~":
                    g[y][x] = "."
    for cx, cy in (STATION, PIER):
        for y in range(cy - 4, cy + 6):
            for x in range(cx - 4, cx + 6):
                if g[y][x] != "~":
                    g[y][x] = "."
    for points in ROADS:
        line(g, points, "#")
    # Crossings: dike bridges and the ferry over the canal, the Vistula ferries, the castle
    # bridge (roads over the water), and the fords of the Nogat.
    for x in CROSSINGS:
        for y in (CANAL - 1, CANAL, CANAL + 1, CANAL + 2):
            g[y][x] = "#"
    for y in VISTULA_FERRIES:
        for x in range(vistula(y) - 6, vistula(y) + 7):
            g[y][x] = "#"
    for y in CASTLE_BRIDGE:
        for x in range(nogat(y) - 5, nogat(y) + 5):
            g[y][x] = "#"
    for y in FORDS:
        for x in range(nogat(y) - 2, nogat(y) + 2):
            g[y][x] = "="
    return ["".join(row) for row in g]


def write(rows: list[str]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        f"; map_crown_05 «Корона 5. Серебро для Мальборка, 1457» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_crown_05.py, seed {SEED}; edit by hand from here.",
        "; The Żuławy between the Vistula (x 30-40) and the Nogat (x 96-126): Gdańsk (x 2-30,",
        "; y 2-30) and Tczew (x 6-26, y 92-114) on the left bank of the Vistula, Malbork",
        "; (x 107-128, y 82-104) on the right bank of the Nogat, the canal on rows 60-61,",
        "; the station by the ferry (68, 54), the pier on the Nogat (110, 38), the fords of the",
        "; Nogat on rows 14-15 and 112-113, the castle bridge on rows 92-93.",
        "; Buildings and units: missions/crown_05/mission.json. Legend: core/nav/map_text.gd.",
    ]
    for kind, px, py in PLACES:
        head.append(f"@place {kind} {px} {py}")
    OUT.write_text("\n".join(head + rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write(generate())
