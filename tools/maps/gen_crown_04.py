"""Draft layout of the mission map «Корона 4. Хойнице, 1454» (map_crown_04), 150×100.

    python3 -m tools.maps.gen_crown_04      # writes maps/map_crown_04/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Walls, the gate, the
royal camp, the wagenburg and the units are not in the map: missions/crown_04/mission.json
places them on the cells named below.

From the mission card (section «Карта»): September, a clear day. Chojnice on the west edge,
the field before the town with a dry middle and wet edges, the Order's wagenburg on a rise in
the north, the forest in the north where Zinnenberg's army comes out, the king's camp in the
rear of the Polish army, bogs and lakes in the east and the one causeway of logs through them
to Toruń. Sizes and distances are a game assumption.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 150
H = 100
SEED = 1454
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_crown_04" / "terrain.txt"

# Places of power (top-left of the 2×2 site): the wayside cross on the road to Tuchola, the
# little chapel by the lake, the old oak at the edge of the bog.
PLACES = [("pp_wayside", 82, 30), ("pp_spring", 80, 80), ("pp_old_tree", 88, 48)]
# Chojnice inside its walls (walls on the border of the box, set by the mission).
TOWN = (6, 34, 26, 58)
# The king's camp, the Order's rise, the bog and the causeway (rows CAUSEWAY_Y, +1).
CAMP = (46, 66, 11)
RISE = (64, 13, 6)
BOG_X = 94
CAUSEWAY_Y = 65
ROADS = [
    [(27, 46), (40, 58), (46, 66), (70, 66), (BOG_X - 1, CAUSEWAY_Y)],  # Gdańsk gate to the bog
    [(60, 54), (84, 32), (90, 8)],  # the road to Tuchola, into the forest
    [(27, 40), (48, 30), (62, 20)],  # the town to the rise
]
LAKES = [(87, 86, 4), (112, 40, 7), (124, 82, 6), (134, 30, 5)]


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
    # Stubble fields round the town, copses on the dry ground.
    for _ in range(40):
        blob(g, rng.randrange(28, 90), rng.randrange(8, 96), rng.randrange(3, 6), ",")
    for _ in range(16):
        blob(g, rng.randrange(0, 40), rng.randrange(62, 100), rng.randrange(3, 6), "f")
    # The forest in the north the Order's relief comes out of.
    for y in range(0, 7):
        for x in range(20, BOG_X + 30):
            if y < 4 + 2 * math.sin(x * 0.17):
                g[y][x] = "f"
    # Old forest north of the bog: no way round it.
    for y in range(0, 18):
        for x in range(BOG_X - 2, W):
            g[y][x] = "F"
    # Wet edges of the field: a boggy hollow on each side.
    for x, y, r in [(32, 22, 3), (88, 22, 3), (34, 86, 3)]:
        blob(g, x, y, r, "b")
    # The bog in the east: a band of wet bog, then quagmire and lakes to the east bank.
    for y in range(18, H):
        for x in range(BOG_X, W - 5):
            edge = BOG_X + 6 + 2 * math.sin(y * 0.3)
            g[y][x] = "b" if x < edge else "B"
    for cx, cy, r in LAKES:
        blob(g, cx, cy, r, "~", keep=())
    # Tussocks: wet bog islands in the quagmire.
    for _ in range(14):
        blob(g, rng.randrange(BOG_X + 10, W - 8), rng.randrange(22, H - 4), rng.randrange(1, 3), "b", keep=("~",))
    # The causeway of logs (two cells wide) with a rim of wet bog along it.
    for x in range(BOG_X - 1, W):
        for y in (CAUSEWAY_Y - 1, CAUSEWAY_Y + 2):
            if g[y][x] in "B~":
                g[y][x] = "b"
        g[CAUSEWAY_Y][x] = "#"
        g[CAUSEWAY_Y + 1][x] = "#"
    # The east bank, firm ground towards Toruń.
    for y in range(18, H):
        for x in range(W - 5, W):
            if g[y][x] != "#":
                g[y][x] = "."
    # The rise of the wagenburg.
    hx, hy, hr = RISE
    for y in range(hy - hr, hy + hr + 1):
        for x in range(hx - hr, hx + hr + 1):
            if (x - hx) ** 2 + (y - hy) ** 2 <= hr * hr:
                g[y][x] = "h"
    # The town: open ground inside and a clear ring round the walls.
    for y in range(TOWN[1] - 3, TOWN[3] + 4):
        for x in range(max(0, TOWN[0] - 3), TOWN[2] + 4):
            g[y][x] = "."
    cx, cy, cr = CAMP
    clear(g, cx, cy, cr)
    for points in ROADS:
        line(g, points, "#", width=2 if points[0] == (27, 46) else 1, keep=("~",))
    for _kind, px, py in PLACES:
        for y in range(py - 1, py + 3):
            for x in range(px - 1, px + 3):
                if g[y][x] in "fFbB~#":
                    g[y][x] = "."
    return ["".join(row) for row in g]


def write(rows: list[str]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        f"; map_crown_04 «Корона 4. Хойнице, 1454» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_crown_04.py, seed {SEED}; edit by hand from here.",
        "; Chojnice on the west edge (walls on x 6-26, y 34-58, the Gdańsk gate east), the field",
        "; (x 28-92, y 8-56), the Order's rise (64, 13), the king's camp (46, 66), the bog from",
        f"; x {BOG_X} east and the causeway on rows {CAUSEWAY_Y}-{CAUSEWAY_Y + 1} to the east bank.",
        "; Walls, buildings and units: missions/crown_04/mission.json. Legend: core/nav/map_text.gd.",
    ]
    for kind, px, py in PLACES:
        head.append(f"@place {kind} {px} {py}")
    OUT.write_text("\n".join(head + rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write(generate())
