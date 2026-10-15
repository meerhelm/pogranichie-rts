"""Draft layout of the skirmish map «Жемайтское порубежье» (map_proto_samogitia), 120×120.

    python3 -m tools.maps.gen_proto_samogitia      # writes maps/map_proto_samogitia/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
(M3) and can be re-run with another seed to try a different one. Legend: core/nav/map_text.gd.

Idea from the catalog: GDL (north-west) has forests and bogs, the Order (south-east) has the
river and roads; a grove in the middle. Places of power, resources and bases come in later
milestones; here only terrain.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

SIZE = 120
SEED = 1409
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_proto_samogitia" / "terrain.txt"


def blob(grid, rng, cx, cy, r, ch, keep=("~", "=", "#")):
    for y in range(max(0, int(cy - r - 2)), min(SIZE, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(SIZE, int(cx + r + 3))):
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
                    if 0 <= x + dx < SIZE and 0 <= y + dy < SIZE and grid[y + dy][x + dx] not in keep:
                        grid[y + dy][x + dx] = ch


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(SIZE)] for _ in range(SIZE)]
    # GDL side (north-west): forests, old forest cores, bogs with quagmire.
    for _ in range(26):
        x, y = rng.randrange(0, 70), rng.randrange(0, 70)
        if x + y > 100 or (x < 26 and y < 26):
            continue
        blob(g, rng, x, y, rng.randrange(4, 9), "f")
    for _ in range(5):
        x, y = rng.randrange(8, 60), rng.randrange(8, 60)
        if x < 30 and y < 30:
            continue
        blob(g, rng, x, y, rng.randrange(2, 4), "F")
    for cx, cy in ((48, 18), (18, 52), (40, 44)):
        blob(g, rng, cx, cy, 6, "b")
        blob(g, rng, cx, cy, 2, "B")
    # River from north to south on the Order's side, with sandy banks and three fords.
    river = [(88, 0), (84, 20), (90, 40), (82, 62), (86, 84), (78, 104), (82, 119)]
    line(g, river, "s", width=5)
    line(g, [(x + 1, y) for x, y in river], "~", width=3)
    for fy in (30, 66, 98):
        for x in range(SIZE):
            if g[fy][x] == "~" or g[fy + 1][x] == "~" or g[fy + 2][x] == "~":
                for dy in range(3):
                    if g[fy + dy][x] in "~s":
                        g[fy + dy][x] = "="
    # Order side (south-east): fields, hills, roads to the fords.
    for _ in range(10):
        blob(g, rng, rng.randrange(92, 118), rng.randrange(50, 118), rng.randrange(3, 6), ",")
    for _ in range(5):
        blob(g, rng, rng.randrange(95, 115), rng.randrange(60, 110), rng.randrange(2, 4), "h")
    for _ in range(4):
        blob(g, rng, rng.randrange(60, 80), rng.randrange(40, 110), rng.randrange(3, 6), "f")
    line(g, [(104, 104), (96, 98), (84, 99), (70, 96)], "#", keep=("~",))
    # The middle road crosses on a bridge (road over the river): carts cannot use fords.
    line(g, [(104, 104), (98, 80), (90, 67), (76, 66), (62, 60)], "#", width=2)
    line(g, [(104, 104), (104, 60), (94, 31), (80, 31), (66, 34)], "#", keep=("~",))
    # Grove in the middle: a ring of forest around a clearing.
    blob(g, rng, 60, 60, 7, "f", keep=("~", "=", "#", "b", "B"))
    blob(g, rng, 60, 60, 3, ".", keep=())
    # Open start areas.
    blob(g, rng, 14, 14, 11, ".", keep=())
    blob(g, rng, 104, 104, 11, ".", keep=("#",))
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        "; map_proto_samogitia «Жемайтское порубежье» (prototype skirmish), 120x120.",
        f"; First draft by tools/maps/gen_proto_samogitia.py, seed {SEED}; edit by hand from here.",
        "; GDL starts north-west, the Order south-east. Legend: core/nav/map_text.gd.",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
