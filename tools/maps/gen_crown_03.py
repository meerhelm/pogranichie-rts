"""Draft layout of the mission map «Корона 3. Балтийская вода, 1433» (map_crown_03), 100×220.

    python3 -m tools.maps.gen_crown_03      # writes maps/map_crown_03/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Walls, gates, towns, the
monasteries, the villages and the units are not in the map: missions/crown_03/mission.json
places them on the cells named below.

From the mission card (section «Карта»): one long map, two screens wide and five deep, south to
north; late summer, dry, reaped fields in the lowlands. Chojnice with the siege camp at the south
edge, the valley of the Wierzyca road with its villages north of it, the Cistercian abbey of
Pelplin, Tczew on the high bank of the Vistula with its wooden suburb west of the wall, the
Bishop's hill above Gdańsk, the villages around Gdańsk, the abbey of Oliwa by the sea and the
shore at Oliwa. The Vistula runs along the east edge into the sea. Sizes and distances are a
game assumption.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 100
H = 220
SEED = 1433
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_crown_03" / "terrain.txt"

# Places of power (top-left of the 2×2 site): the wayside cross by Tczew, the well of the
# Pelplin monks, the boulder on the shore at Oliwa.
PLACES = [("pp_wayside", 48, 116), ("pp_spring", 36, 146), ("pp_footprint_stone", 46, 10)]
# Walled towns (walls on the border of these boxes, set by the mission).
CHOJNICE = (36, 204, 64, 216)
TCZEW = (72, 94, 86, 112)
GDANSK = (64, 16, 86, 36)
# The suburb of Tczew west of its wall, the camps, the Bishop's hill.
SUBURB = (56, 95, 70, 111)
CAMPS = [(50, 168), (50, 140), (44, 104), (52, 46)]
HILL = (52, 46, 8)
ROADS = [
    [(50, 203), (50, 168), (50, 140), (46, 118), (44, 104), (48, 80), (52, 54), (52, 40), (40, 24), (30, 14)],
    [(44, 104), (71, 103)],  # to Tczew's gate
    [(52, 40), (63, 26)],  # to Gdańsk's west gate
    [(75, 37), (66, 60), (52, 54)],  # Gdańsk's south gate
    [(50, 140), (34, 140)],  # to Pelplin
    [(0, 168), (50, 168)],  # the raiders' track from the west
]
VILLAGES = [(64, 162), (34, 168), (66, 126), (30, 120), (30, 40), (24, 60), (70, 56), (40, 76)]
PELPLIN = (30, 137)
OLIWA = (22, 18)


def blob(grid, cx, cy, r, ch, keep=("~", "#", "h", "s")):
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


def inside(box, x, y, pad=0):
    return box[0] - pad <= x <= box[2] + pad and box[1] - pad <= y <= box[3] + pad


def clear(grid, cx, cy, r, ch="."):
    for y in range(max(0, cy - r), min(H, cy + r + 1)):
        for x in range(max(0, cx - r), min(W, cx + r + 1)):
            if grid[y][x] in "fF,b":
                grid[y][x] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Reaped fields in the lowlands, woods west of the road (Kashubia) and copses east of it.
    for _ in range(70):
        blob(g, rng.randrange(8, W - 12), rng.randrange(14, H - 18), rng.randrange(3, 7), ",")
    for _ in range(46):
        x, y = rng.randrange(0, 22), rng.randrange(14, H - 20)
        blob(g, x, y, rng.randrange(3, 7), "f")
    for _ in range(18):
        x, y = rng.randrange(58, 86), rng.randrange(40, 200)
        blob(g, x, y, rng.randrange(2, 4), "f")
    # A boggy hollow or two in the valley.
    for x, y, r in [(70, 176, 3), (26, 96, 3), (78, 72, 3)]:
        blob(g, x, y, r, "b")
    # The sea in the north and the Vistula along the east edge.
    for y in range(H):
        for x in range(W):
            sea = 6 + 1.5 * math.sin(x * 0.21)
            river = 90 + 1.6 * math.sin(y * 0.09)
            if y < sea or x >= river:
                g[y][x] = "~"
            elif y < sea + 5 and x < 62:
                g[y][x] = "s"
            elif x >= river - 1:
                g[y][x] = "s"
    # The Bishop's hill.
    hx, hy, hr = HILL
    for y in range(hy - hr, hy + hr + 1):
        for x in range(hx - hr, hx + hr + 1):
            if (x - hx) ** 2 + (y - hy) ** 2 <= hr * hr and g[y][x] != "~":
                g[y][x] = "h"
    # Towns: open ground inside, a clear ring round the walls.
    for box in (CHOJNICE, TCZEW, GDANSK):
        for y in range(box[1] - 2, box[3] + 3):
            for x in range(box[0] - 2, box[2] + 3):
                if 0 <= x < W and 0 <= y < H and g[y][x] not in "~":
                    g[y][x] = "."
    # The suburb, the camps, the monasteries and the villages stand on open ground.
    for y in range(SUBURB[1] - 1, SUBURB[3] + 2):
        for x in range(SUBURB[0] - 1, SUBURB[2] + 2):
            g[y][x] = "."
    for cx, cy in CAMPS:
        clear(g, cx, cy, 7)
    for cx, cy in VILLAGES:
        clear(g, cx + 1, cy + 1, 3, ",")
    clear(g, PELPLIN[0] + 1, PELPLIN[1] + 1, 5)
    clear(g, OLIWA[0] + 1, OLIWA[1] + 1, 4)
    # The siege camp before Chojnice.
    clear(g, 50, 192, 12)
    for points in ROADS:
        line(g, points, "#", keep=("~",))
    # Sites of the places of power.
    for _kind, px, py in PLACES:
        for y in range(py - 1, py + 3):
            for x in range(px - 1, px + 3):
                if g[y][x] in "fFb#~":
                    g[y][x] = "s" if py < 20 else "."
    return ["".join(row) for row in g]


def write(rows: list[str]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        f"; map_crown_03 «Корона 3. Балтийская вода, 1433» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_crown_03.py, seed {SEED}; edit by hand from here.",
        "; South to north: Chojnice and the siege camp (y 186-216), the Wierzyca road and its",
        "; villages, Pelplin (x 30, y 137), Tczew inside x 72-86, y 94-112 with its suburb west",
        "; of the wall, the Bishop's hill (52, 46) above Gdańsk (x 64-86, y 16-36), Oliwa and the",
        "; shore. The Vistula along the east edge. Walls, buildings and units:",
        "; missions/crown_03/mission.json. Legend: core/nav/map_text.gd.",
    ]
    for kind, px, py in PLACES:
        head.append(f"@place {kind} {px} {py}")
    OUT.write_text("\n".join(head + rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write(generate())
