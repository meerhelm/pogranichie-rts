"""Draft layout of the mission map «ВКЛ 3. Крещение» (map_gdl_03), 160×160.

    python3 -m tools.maps.gen_gdl_03      # writes maps/map_gdl_03/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings and units are
not in the map: missions/gdl_03/mission.json places them on the cells named below.

From the mission card (section «Карта»): Samogitia, middle size; hills, forests, bogs, a river
with fords. The border with the Order is in the west (the border river with the border ford and
a northern ford for the Order's riders), the road to Medininkai leaves the map in the east;
the trail to the sea leaves it in the north.
Gintaut's yard is in the middle, the sacred grove with the alka west of it by the road; a
stream comes down from the north-east past the yard, with the hill over it (the best place for
the church). The lake island in the north-east, the footprint stone by the border in the
south-west next to the pagans' farmstead, the bog spring by the trail in the north-west. Three
villages lie on the envoys' way from the ford to the Medininkai road (chapter 4), and a way
round the grove goes over the southern hills.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

SIZE = 160
SEED = 1413
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_03" / "terrain.txt"

# Top-left cells of the 2×2 sites, in the card's order (place 1 … 5).
PLACES = [
    ("pp_oak_grove", 66, 80),
    ("pp_hillfort", 92, 47),
    ("pp_bog_island", 134, 27),
    ("pp_footprint_stone", 38, 128),
    ("pp_spring", 58, 18),
]
YARD = (100, 74)
FORD = (28, 100)
NORTH_FORD = (28, 32)
VILLAGES = [(50, 104), (104, 112), (132, 92)]
HUTOR = (46, 144)
HILLS = (76, 126)


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
    # Mixed forest everywhere, old forest cores, bogs.
    for _ in range(120):
        x, y = rng.randrange(0, SIZE), rng.randrange(0, SIZE)
        blob(g, x, y, rng.randrange(4, 9), "f")
    for _ in range(8):
        x, y = rng.randrange(40, 150), rng.randrange(10, 150)
        blob(g, x, y, rng.randrange(2, 4), "F")
    for cx, cy in ((58, 20), (120, 140), (80, 30), (146, 120)):
        blob(g, cx, cy, 7, "b")
        blob(g, cx, cy, 3, "B")
    # The Order's bank in the west: open fields and a road to the ford.
    rect(g, 0, 0, 22, SIZE - 1, ".")
    for cx, cy in ((10, 60), (12, 120), (8, 20), (14, 150)):
        blob(g, cx, cy, rng.randrange(5, 8), ",")
    # The border river from north to south with sand banks, two fords.
    for y in range(SIZE):
        x0 = 25 + round(2 * math.sin(y / 17.0))
        g[y][x0 - 1] = "s"
        for x in range(x0, x0 + 4):
            g[y][x] = "~"
        g[y][x0 + 4] = "s"
    for fx, fy in (FORD, NORTH_FORD):
        for y in range(fy - 1, fy + 3):
            for x in range(18, 36):
                if g[y][x] in "~s":
                    g[y][x] = "="
    # A stream from the north-east down past the yard to the border river, one ford on the road.
    stream = [(150, 0), (126, 24), (104, 40), (86, 56), (60, 64), (30, 70)]
    line(g, stream, "s", width=3, keep=("=",))
    line(g, [(x + 1, y + 1) for x, y in stream], "~", width=2, keep=("=",))
    for x in range(SIZE):
        for y in range(SIZE):
            if g[y][x] == "~" and 98 <= x <= 103 and 40 <= y <= 50:
                g[y][x] = "="
            if g[y][x] == "~" and 70 <= x <= 76 and 57 <= y <= 66:
                g[y][x] = "="
    # The hill over the stream (place 2).
    blob(g, 93, 49, 5, "h", keep=("~", "=", "s"))
    # The lake in the north-east and its island (place 3), reached by a ford from the south.
    blob(g, 135, 28, 9, "~", keep=())
    blob(g, 135, 28, 3, ".", keep=())
    line(g, [(135, 31), (135, 40)], "=", width=2)
    # The pagans' farmstead in the south-west, by the footprint stone (place 4).
    blob(g, HUTOR[0], HUTOR[1], 9, ".", keep=("~", "=", "s"))
    blob(g, 39, 129, 4, ".", keep=("~", "=", "s"))
    # The bog spring (place 5): firm ground in the bog by the trail.
    blob(g, 59, 19, 2, ".", keep=())
    # Gintaut's yard: a big clearing with fields; the villages; the southern hills.
    blob(g, YARD[0], YARD[1], 14, ".", keep=("~", "=", "s"))
    for cx, cy in ((114, 66), (112, 82)):
        blob(g, cx, cy, 4, ",", keep=("~", "=", "s", "#"))
    for vx, vy in VILLAGES:
        blob(g, vx, vy, 8, ".", keep=("~", "=", "s"))
        blob(g, vx + 4, vy - 3, 3, ",", keep=("~", "=", "s"))
    blob(g, HILLS[0], HILLS[1], 7, "h", keep=("~", "=", "s"))
    # Deposits: bog ore south-east of the yard, a silver hill to the north-east.
    blob(g, 122, 104, 4, "b", keep=())
    for x, y in ((121, 103), (123, 104), (122, 106)):
        g[y][x] = "o"
    blob(g, 118, 52, 3, "h", keep=())
    g[52][118] = "$"
    g[53][119] = "$"
    # Roads: the Order's road to the ford; ford → village 1 → grove → yard → village 3 → east;
    # the yard to village 2; the way round over the hills; the trail to the sea by the north
    # ford; a path to the farmstead.
    line(g, [(0, 100), (18, 100)], "#", width=2)
    line(g, [(34, 101), (50, 104), (66, 92), (70, 86), (84, 78), (100, 76)], "#", width=2, keep=("~",))
    line(g, [(100, 76), (116, 84), (132, 92), (148, 84), (159, 80)], "#", width=2, keep=("~",))
    line(g, [(100, 78), (104, 96), (104, 112), (118, 102), (132, 92)], "#", width=2, keep=("~",))
    line(g, [(50, 104), (62, 118), (76, 126), (92, 120), (104, 112)], "#", width=2, keep=("~",))
    # The trail to the sea crosses the stream by a log bridge (road cells over the water: a cart
    # cannot take a ford) and leaves the map in the north; a path from it to the northern ford.
    line(g, [(96, 70), (84, 60), (74, 56), (60, 44), (50, 28), (45, 12), (45, 0)], "#", width=2)
    line(g, [(52, 32), (40, 33), (34, 33)], "#", width=2, keep=("~",))
    line(g, [(18, 33), (0, 33)], "#", width=2)
    line(g, [(50, 106), (46, 126), (46, 136)], "#", width=1, keep=("~",))
    # Clearings for the places of power.
    for _, x, y in PLACES:
        blob(g, x + 1, y + 1, 3, "h" if (x, y) == (92, 47) else ".", keep=("~", "=", "#"))
    blob(g, 135, 28, 3, ".", keep=())
    # The grove: old oaks round the clearing, open to the road in the east.
    for y in range(72, 92):
        for x in range(58, 78):
            d = math.hypot(x - 67, y - 81)
            if 5 <= d <= 9 and g[y][x] in ".f," and not (x > 68 and 78 <= y <= 84):
                g[y][x] = "F"
    blob(g, 67, 81, 4, ".", keep=("#",))
    rect(g, 69, 79, 80, 83, ".", keep=("#",))
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        "; map_gdl_03 «ВКЛ 3. Крещение» (mission), 160x160.",
        f"; First draft by tools/maps/gen_gdl_03.py, seed {SEED}; edit by hand from here.",
        "; The Order's bank and the border river in the west (border ford, north ford on the",
        "; trail to the sea), Gintaut's yard in the middle, the Medininkai road in the east,",
        "; three villages on the envoys' way, the pagans' farmstead in the south-west.",
        "; Places: 1 grove, 2 hill over the stream, 3 lake island, 4 footprint stone, 5 bog spring.",
        "; Buildings and units: missions/gdl_03/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
