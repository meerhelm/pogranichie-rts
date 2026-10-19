"""Draft layout of the mission map «Корона 2. Мальборк, 1410» (map_crown_02), 140×120.

    python3 -m tools.maps.gen_crown_02      # writes maps/map_crown_02/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Walls, gates, the castle,
the camps, the ruins and the units are not in the map: missions/crown_02/mission.json places
them on the cells named below.

From the mission card (section «Карта»): 3×3 screens, late summer, north up, the Nogat flowing
south to north along the left edge. The High and Middle castle stand on the east bank (the
river washes their west wall), the burned town south of them inside its own walls, the bridge
over the Nogat from the castle's west gate to the old bridgehead on the west bank. The king's
camp on the hill above the Nogat by Wielbark and St George's church south of the town, the
mill canal running from the south-east to the town (water drawn below the town is foul),
Vytautas's camp on the Elbląg road in the north-east, the Tatars on the meadows by the Nogat
north of the castle. Roads to Gdańsk (north), Elbląg (north-east), Braniewo (east) and Toruń
(south) at the edges, the road to Sztum leaves by the south edge. A crossing over the Nogat in
the south (a ferry road) lets the guns reach the old bridgehead. Sizes and distances are a game
assumption.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 140
H = 120
SEED = 1410
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_crown_02" / "terrain.txt"

# Places of power (top-left of the 2×2 site): the wayside cross on the Wielbark road and the
# well by St George's church.
PLACES = [("pp_wayside", 78, 102), ("pp_spring", 33, 101)]
# The Nogat: water in these columns, sand on the banks.
RIVER = (16, 22)
# The castle (its walls on the border of this box) and the burned town south of it.
CASTLE = (24, 26, 46, 50)
TOWN = (24, 50, 46, 76)
# The bridge from the castle's west gate over the Nogat, and the ferry road in the south.
BRIDGE_ROWS = (38, 39)
FERRY_ROWS = (108, 109)
# The king's hill by Wielbark.
HILL = (44, 100, 10)
CANAL = [(139, 96), (100, 84), (72, 76), (47, 68)]
ROADS = [
    [(30, 119), (36, 104), (42, 98)],  # to Toruń
    [(42, 98), (60, 100), (78, 104), (110, 106), (139, 108)],  # Wielbark road east
    [(60, 100), (80, 110), (100, 119)],  # to Sztum
    [(35, 77), (38, 88), (42, 96)],  # the town gate to the camp
    [(47, 38), (70, 32), (100, 22), (139, 10)],  # to Elbląg
    [(60, 0), (58, 18), (52, 30), (48, 37)],  # to Gdańsk
    [(139, 50), (100, 62), (72, 84), (58, 98)],  # to Braniewo
    [(47, 64), (56, 70), (60, 86), (60, 98)],  # the town's east gate to the camp
    [(0, 39), (15, 39)],  # the old bridgehead
    [(0, 109), (15, 109), (23, 108), (34, 104)],  # the ferry road
]
VYTAUTAS = (106, 28)
COPSE = (75, 39, 4)
TATARS = (36, 10)


def blob(grid, cx, cy, r, ch, keep=("~", "#", "h", "=")):
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


def clear(grid, cx, cy, r):
    for y in range(max(0, cy - r), min(H, cy + r + 1)):
        for x in range(max(0, cx - r), min(W, cx + r + 1)):
            if grid[y][x] in "fF,":
                grid[y][x] = "."


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Żuławy fields on the west bank and the meadows and fields east of the camps.
    for _ in range(26):
        blob(g, rng.randrange(0, 14), rng.randrange(0, H), rng.randrange(3, 6), ",")
    for _ in range(40):
        x, y = rng.randrange(56, W), rng.randrange(0, 70)
        blob(g, x, y, rng.randrange(3, 7), ",")
    # Woods: the south-east (where the camps cut wood), copses in the east, a strip on the west
    # bank.
    for _ in range(36):
        x, y = rng.randrange(84, W - 2), rng.randrange(66, H - 2)
        blob(g, x, y, rng.randrange(3, 6), "f")
    for _ in range(10):
        x, y = rng.randrange(66, W - 2), rng.randrange(40, 66)
        blob(g, x, y, rng.randrange(2, 4), "f")
    for y in range(H):
        for x in range(0, 5):
            if (x * 7 + y * 3) % 4 != 0 and not 30 <= y <= 48:
                g[y][x] = "f"
    # The copse east of the castle where the camp by the batteries cuts its wood.
    blob(g, COPSE[0], COPSE[1], COPSE[2], "f")
    # The king's hill.
    hx, hy, hr = HILL
    blob(g, hx, hy, hr, "h", keep=("~",))
    # Open ground round the castle, in the town (ash), at the camps.
    for y in range(H):
        for x in range(W):
            if inside(CASTLE, x, y, 6) or inside(TOWN, x, y, 5):
                if g[y][x] in "fF,":
                    g[y][x] = "."
            if inside(TOWN, x, y) and not inside(CASTLE, x, y):
                g[y][x] = "a"
    for cx, cy, r in ((VYTAUTAS[0], VYTAUTAS[1], 12), (TATARS[0], TATARS[1], 9), (64, 100, 8)):
        clear(g, cx, cy, r)
    # The Nogat.
    for y in range(H):
        for x in range(RIVER[0], RIVER[1] + 1):
            g[y][x] = "~"
        if g[y][RIVER[0] - 1] not in "~":
            g[y][RIVER[0] - 1] = "s"
        if not inside(CASTLE, RIVER[1] + 1, y, 1) and not inside(TOWN, RIVER[1] + 1, y):
            g[y][RIVER[1] + 1] = "s"
    # The mill canal: shallow water a man wades (a ford cell; guns only cross by the roads).
    line(g, CANAL, "=", keep=("~",))
    # The roads (over the canal they are its bridges).
    for pts in ROADS:
        line(g, pts, "#", keep=("~",))
    # The bridge from the castle and the ferry road over the Nogat.
    for y in BRIDGE_ROWS:
        for x in range(RIVER[0], RIVER[1] + 1):
            g[y][x] = "#"
    for y in FERRY_ROWS:
        for x in range(RIVER[0], RIVER[1] + 1):
            g[y][x] = "#"
    # The wall lines and the castle courtyard are plain ground (the mission builds the walls).
    for y in range(H):
        for x in range(W):
            on_wall = (
                (inside(CASTLE, x, y) or inside(TOWN, x, y))
                and (x in (CASTLE[0], CASTLE[2]) or y in (CASTLE[1], CASTLE[3], TOWN[3]))
            )
            if on_wall or (inside(CASTLE, x, y) and not inside(TOWN, x, y)):
                g[y][x] = "."
    # Places of power stand on open ground.
    for _kind, x, y in PLACES:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                if g[y + dy][x + dx] not in "#":
                    g[y + dy][x + dx] = "."
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_crown_02 «Корона 2. Мальборк, 1410» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_crown_02.py, seed {SEED}; edit by hand from here.",
        f"; The Nogat in columns {RIVER[0]}-{RIVER[1]}; the castle inside x {CASTLE[0]}-{CASTLE[2]},"
        f" y {CASTLE[1]}-{CASTLE[3]} (walls on its border),",
        f"; the burned town south of it to y {TOWN[3]}, the bridge on rows {BRIDGE_ROWS[0]}-"
        f"{BRIDGE_ROWS[1]}, the ferry road on rows {FERRY_ROWS[0]}-{FERRY_ROWS[1]},",
        "; the king's hill by Wielbark at the south, the mill canal from the south-east.",
        "; Walls, buildings, ruins and units: missions/crown_02/mission.json. Legend:",
        "; core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
