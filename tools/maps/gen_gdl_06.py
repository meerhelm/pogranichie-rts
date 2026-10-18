"""Draft layout of the mission map «ВКЛ 6. Волчья тропа, 1507» (map_gdl_06), 160×90.

    python3 -m tools.maps.gen_gdl_06      # writes maps/map_gdl_06/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings, units and props
are not in the map: missions/gdl_06/mission.json places them on the cells named below.

From the mission card (section «Карта»): a medium map stretched from east to west, early
autumn, all forest, bogs, zaseki, a couple of villages. The card leaves the place unnamed (the
route of the escape is not in the sources); the decision taken with it is «the forests of the
Smolensk borderland towards Mstislavl», so the map is that kind of country and has no names.
East to west: the border camp where the prince serves (the start), the chapel by the road, the
zaseka with its watch across the forest (a wall of felled trees and old forest with one gap on
the road), the village with the stable, the boulder in the stream by the road the chase takes,
the bog with the island in it (only the gať crosses it, the road goes round to the south), and
the border ford over the river into Lithuania. Hidden places of power: the old pine with cuts
east of the zaseka, the boulder in the stream, the island in the bog; each opens a trail
(«Волчья тропа») through old forest or quagmire, listed in mission.json rules.stealth.paths.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 160
H = 90
SEED = 1507
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_06" / "terrain.txt"

# Top-left cells of the 2×2 sites, in the card's order: the old pine, the boulder, the island.
PLACES = [
    ("pp_old_tree", 116, 30),
    ("pp_footprint_stone", 76, 60),
    ("pp_bog_island", 44, 44),
]
# The border river (x RIVER..RIVER+2) and its ford rows.
RIVER = 14
FORD_ROWS = (44, 45, 46)
# The road: from the camp west through the zaseka's gap, past the village and the old forest,
# round the bog to the south and up to the ford.
ROAD = [(159, 46), (120, 46), (100, 46), (62, 46), (60, 50), (60, 80), (30, 80), (24, 60), (17, 45)]
# The zaseka: a wall across the forest at x ZASEKA..ZASEKA+2 (felled trees placed as buildings
# from row 30 to 60, old forest beyond), the gap on the road rows.
ZASEKA = 106
GAP_ROWS = (45, 46)
# The bog: quagmire between these columns, a rim of bog round it.
BOG_X = (31, 58)
BOG_Y = (20, 74)
# The old forest west of the boulder: a wall the boulder's trail cuts through.
OLD_WOOD_X = (64, 72)
OLD_WOOD_Y = (51, 90)
CAMP = (146, 44)
VILLAGE = (90, 28)


def blob(g, cx, cy, r, ch, keep=("~", "=", "#")):
    for y in range(max(0, int(cy - r - 2)), min(H, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(W, int(cx + r + 3))):
            wobble = r * (0.75 + 0.25 * math.sin(x * 0.7 + y * 0.4 + cx))
            if (x - cx) ** 2 + (y - cy) ** 2 <= wobble**2 and g[y][x] not in keep:
                g[y][x] = ch


def line(g, points, ch, width=1, keep=()):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            for dy in range(width):
                for dx in range(width):
                    if 0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] not in keep:
                        g[y + dy][x + dx] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    # Mostly forest: the borderland is woods with clearings.
    g = [["f" for _ in range(W)] for _ in range(H)]
    # Clearings and meadows, more of them in the east by the camp and round the village.
    for _ in range(70):
        x, y = rng.randrange(18, W), rng.randrange(0, H)
        blob(g, x, y, rng.randrange(3, 7), ".")
    for _ in range(14):
        x, y = rng.randrange(80, 100), rng.randrange(18, 40)
        blob(g, x, y, rng.randrange(2, 5), ",")
    # The camp's ground and the field before it.
    for y in range(32, 62):
        for x in range(128, W):
            g[y][x] = "."
    for y in range(36, 56):
        for x in range(150, W):
            g[y][x] = ","
    # The village in its fields.
    for y in range(VILLAGE[1] - 8, VILLAGE[1] + 10):
        for x in range(VILLAGE[0] - 10, VILLAGE[0] + 12):
            g[y][x] = "," if (x + y) % 9 else "."
    # The zaseka: old forest across the map, forest under the felled trees, the gap on the road.
    for y in range(H):
        for x in range(ZASEKA - 2, ZASEKA + 5):
            g[y][x] = "F"
        if 30 <= y <= 60:
            for x in range(ZASEKA, ZASEKA + 3):
                g[y][x] = "f"
            for x in (ZASEKA - 2, ZASEKA - 1, ZASEKA + 3, ZASEKA + 4):
                g[y][x] = "."
    # The old forest west of the boulder, with a stream by its east side.
    for y in range(OLD_WOOD_Y[0], OLD_WOOD_Y[1]):
        for x in range(OLD_WOOD_X[0], OLD_WOOD_X[1] + 1):
            g[y][x] = "F"
    for y in range(40, H):
        x = 79 + int(round(1.2 * math.sin(y / 6.0)))
        g[y][x] = "="
    # The bog: a rim of bog, the quagmire inside, the island in the middle.
    for y in range(BOG_Y[0] - 2, BOG_Y[1] + 3):
        for x in range(BOG_X[0] - 2, BOG_X[1] + 3):
            wob = int(1.5 * math.sin(y / 3.0) + math.sin(x / 2.3))
            inside = BOG_X[0] + wob <= x <= BOG_X[1] - wob and BOG_Y[0] <= y <= BOG_Y[1]
            g[y][x] = "B" if inside else "b"
    blob(g, 45, 45, 3, "b", keep=())
    # A belt of old forest north of the bog and the zaseka's woods, so the way round the bog in
    # the north is a long forest track.
    for y in range(0, 6):
        for x in range(26, 64):
            g[y][x] = "F"
    # The river into Lithuania: deep water, the ford, a sandy west bank, meadows beyond.
    for y in range(H):
        for x in range(RIVER, RIVER + 3):
            g[y][x] = "=" if y in FORD_ROWS else "~"
        g[y][RIVER - 1] = "s" if y not in FORD_ROWS else "."
    for y in range(H):
        for x in range(0, RIVER - 1):
            g[y][x] = "." if (x * 3 + y * 5) % 11 else "f"
    # Meadows between the bog and the river.
    for y in range(30, 62):
        for x in range(RIVER + 3, BOG_X[0] - 3):
            if g[y][x] in "fF":
                g[y][x] = "." if (x + 2 * y) % 7 else "f"
    # The road (over the stream it stays a ford).
    line(g, ROAD, "#", width=2, keep=("~", "=", "B"))
    for y in GAP_ROWS:
        for x in range(ZASEKA - 2, ZASEKA + 5):
            g[y][x] = "#"
    # Clearings for the places of power (the island stays bog).
    for kind, x, y in PLACES:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                if kind == "pp_bog_island":
                    g[y + dy][x + dx] = "b"
                elif g[y + dy][x + dx] in "F,B":
                    g[y + dy][x + dx] = "f" if kind == "pp_old_tree" else "."
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_06 «ВКЛ 6. Волчья тропа, 1507» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_06.py, seed {SEED}; edit by hand from here.",
        "; East to west: the border camp, the chapel, the zaseka with its gap on the road",
        f"; (x {ZASEKA}-{ZASEKA + 2}, rows {GAP_ROWS[0]}-{GAP_ROWS[1]}), the village, the old forest, the bog with the",
        f"; island, the border ford (x {RIVER}-{RIVER + 2}, rows {FORD_ROWS[0]}-{FORD_ROWS[-1]}); no names: the route is not known.",
        "; Buildings, units and props: missions/gdl_06/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
