"""Draft layout of the mission map «ВКЛ 7. Слуцк, 1508» (map_gdl_07), 150×100.

    python3 -m tools.maps.gen_gdl_07      # writes maps/map_gdl_07/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings, walls and units
are not in the map: missions/gdl_07/mission.json places them on the cells named below.

From the mission card (section «Карта»): a medium map, summer, heat. In the middle the castle
hill, round it the posad, on one side the river, beyond the fields the besiegers' camp. Here
the Sluch runs north to south along the west edge; the Upper castle stands on its hill right on
the east bank (the river closes its west side, no wall there), the Lower castle wraps it from
the east, the posad spreads east of the Lower castle's gate along the road, the fields lie
beyond it and the rebels' camp with the ladder workshops is in the north-east, the Muscovite
camp east. The secret passage (тайный ход) of the card comes out on the river bank north of
the castle; the spring (криница) under the castle hill is inside the Lower castle. The layout
is a game assumption: the card says where the parts were, not their sizes.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 150
H = 100
SEED = 1508
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_07" / "terrain.txt"

# Top-left cell of the 2×2 site of the one place of power: the spring under the castle hill.
PLACES = [("pp_spring", 50, 58)]
# The Upper castle (inside its walls) and the Lower castle; walls stand on the rows and
# columns just outside these (mission.json).
UPPER = (23, 39, 37, 57)
LOWER = (39, 33, 61, 63)
# The road from the Lower castle's gate east through the posad, and to the camp.
ROAD = [(63, 48), (80, 48), (100, 49), (150, 50)]
CAMP_ROAD = [(100, 49), (112, 36), (122, 24), (126, 18)]
CAMP = (126, 20)
MOSCOW_CAMP = (131, 45)
TUNNEL_EXIT = (18, 27)


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


def bank(y: int) -> int:
    """The last column of water of the Sluch in row y (its east bank is the next one)."""
    if 35 <= y <= 61:
        return 21  # under the Upper castle the river washes the hill
    return 17 + int(round(1.5 * math.sin(y / 9.0)))


def near_castle(x: int, y: int, pad: int) -> bool:
    return 22 - pad <= x <= 62 + pad and 32 - pad <= y <= 64 + pad


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Summer fields over the open land beyond the posad, and some by the river.
    for _ in range(60):
        x, y = rng.randrange(66, W), rng.randrange(0, H)
        blob(g, x, y, rng.randrange(3, 8), ",")
    for _ in range(10):
        x, y = rng.randrange(24, 64), rng.randrange(70, H)
        blob(g, x, y, rng.randrange(3, 6), ",")
    # Woods: along the west bank of the river, a strip in the north (cover for the way from the
    # secret passage to the camp), copses in the south and east.
    for y in range(H):
        for x in range(0, max(0, bank(y) - 8)):
            if (x * 7 + y * 3) % 5 != 0:
                g[y][x] = "f"
    for x in range(20, 112):
        edge = 9 + int(3 * math.sin(x / 6.0) + 2 * math.sin(x / 2.7))
        for y in range(0, edge):
            g[y][x] = "F" if y < edge - 5 and (x * 5 + y * 3) % 7 != 0 else "f"
    for _ in range(14):
        x, y = rng.randrange(66, W - 4), rng.randrange(60, H - 4)
        blob(g, x, y, rng.randrange(2, 4), "f")
    for _ in range(6):
        x, y = rng.randrange(28, 60), rng.randrange(74, H - 3)
        blob(g, x, y, rng.randrange(2, 4), "f")
    # The castle hill: the Upper castle and the slope round it.
    for y in range(UPPER[1] - 2, UPPER[3] + 3):
        for x in range(UPPER[0] - 1, UPPER[2] + 3):
            g[y][x] = "h"
    # Inside the castles and round them open ground (the posad and the approaches).
    for y in range(0, H):
        for x in range(0, W):
            if near_castle(x, y, 4) and g[y][x] in "fF,":
                g[y][x] = "."
            if 63 <= x <= 98 and 28 <= y <= 72 and g[y][x] in "fF":
                g[y][x] = "."
    # The camps stand on open ground.
    for cx, cy, r in ((CAMP[0], CAMP[1], 14), (MOSCOW_CAMP[0], MOSCOW_CAMP[1], 9)):
        for y in range(max(0, cy - r), min(H, cy + r + 1)):
            for x in range(cx - r - 2, min(W, cx + r + 3)):
                if g[y][x] in "fF":
                    g[y][x] = "."
    # The Sluch: seven cells of water, a sandy east bank (none under the castle).
    for y in range(H):
        b = bank(y)
        for x in range(max(0, b - 7), b + 1):
            g[y][x] = "~"
        if not 35 <= y <= 61 and g[y][b + 1] != "h":
            g[y][b + 1] = "s"
    # The roads.
    line(g, ROAD, "#", width=2, keep=("~",))
    line(g, CAMP_ROAD, "#", width=1, keep=("~",))
    # Where the secret passage comes out: a hollow in the bank below the north wood.
    ex, ey = TUNNEL_EXIT
    for y in range(ey - 2, ey + 3):
        for x in range(ex - 1, ex + 4):
            if g[y][x] not in "~":
                g[y][x] = "s" if x <= ex else "."
    # The spring under the castle hill stays open ground.
    for kind, x, y in PLACES:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                g[y + dy][x + dx] = "."
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_07 «ВКЛ 7. Слуцк, 1508» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_07.py, seed {SEED}; edit by hand from here.",
        "; The Sluch along the west edge; the Upper castle on its hill on the east bank",
        f"; (inside x {UPPER[0]}-{UPPER[2]}, y {UPPER[1]}-{UPPER[3]}), the Lower castle east of it (x {LOWER[0]}-{LOWER[2]},",
        f"; y {LOWER[1]}-{LOWER[3]}), its gate at x 62 on the road, the posad east of it, the rebels' camp in the",
        "; north-east, the Muscovite camp east, the secret passage's mouth on the north bank.",
        "; Buildings, walls and units: missions/gdl_07/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
