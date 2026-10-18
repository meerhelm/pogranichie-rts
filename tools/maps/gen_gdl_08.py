"""Draft layout of the mission map «ВКЛ 8. Орша, 1514» (map_gdl_08), 160×110.

    python3 -m tools.maps.gen_gdl_08      # writes maps/map_gdl_08/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings, units and props
are not in the map: missions/gdl_08/mission.json places them on the cells named below.

From the mission card (section «Карта»): a large map, early autumn. The Dnieper along the south
edge; the army's camp on the south bank, and once it is over the river the Dnieper is at its
back. North of the river the field, further on the Muscovite camp. On one flank the boggy
Kropivna, on the other the forest and the ravine. The layout puts the Kropivna on the east,
where the Muscovite Left Hand stands (it is pressed into it), and the forest with the ravine
before it on the south-east, near the river, where the hidden guns wait for the chase; a big
forest closes the west. Upstream (east) of the two bridge sites is the ford of the light horse;
downstream, far to the west, the bridges at Orsha that the Muscovites guard. The old oak, the
last place of power, stands on a rise above the Kropivna near the ford. Where exactly the
army crossed and where the regiments stood is not a survey: the card's reading, not the field.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 160
H = 110
SEED = 1514
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_08" / "terrain.txt"

# The old oak above the Kropivna (a 2×2 site, top-left cell).
PLACES = [("pp_old_tree", 132, 80)]
# The Dnieper: rows of deep water, the sand on each bank.
RIVER = (88, 93)
# The two bridge sites (columns), the ford of the light horse, the bridges at Orsha.
BRIDGES = [(70, 71), (84, 85)]
FORD = (122, 125)
ORSHA = (8, 9)
# The Kropivna: the middle column of its bog (it wobbles a little), its half width.
KROPIVNA_X = 142
KROPIVNA_HALF = 2
# The ravine (bushes on low ground) and the forest behind it, by the river on the south-east.
RAVINE = (92, 60, 108, 70)
FOREST_SE = (102, 70, 120, 86)
# The Muscovite camp's clearing on the north; the army's camp on the south bank.
MOSCOW_CAMP = (60, 4, 100, 24)
OUR_CAMP = (56, 96, 120, 108)
# The west forest's east edge.
WEST_EDGE = 22


def blob(grid, cx, cy, r, ch, keep=("~", "=", "#", "b", "B")):
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


def kropivna(y: int) -> int:
    """The Kropivna's middle column at row y."""
    return KROPIVNA_X + int(round(1.2 * math.sin(y / 9.0)))


def inside(rect, x, y) -> bool:
    return rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Harvested fields over the open land on both banks.
    for _ in range(60):
        x, y = rng.randrange(WEST_EDGE + 4, KROPIVNA_X - 4), rng.randrange(26, RIVER[0] - 2)
        blob(g, x, y, rng.randrange(3, 7), ",")
    for _ in range(10):
        x, y = rng.randrange(10, W - 10), rng.randrange(RIVER[1] + 4, H)
        blob(g, x, y, rng.randrange(3, 6), ",")
    # The big forest on the west flank, its heart old forest.
    for y in range(0, RIVER[0] - 4):
        edge = WEST_EDGE + int(3 * math.sin(y / 6.0) + 2 * math.sin(y / 2.7))
        for x in range(0, edge):
            g[y][x] = "F" if x < edge - 8 and (x * 5 + y * 3) % 7 != 0 else "f"
    # Woods along the north edge behind the Muscovite camp.
    for x in range(WEST_EDGE, KROPIVNA_X - 3):
        for y in range(0, 3 + int(1.5 * math.sin(x / 5.0))):
            g[y][x] = "f"
    # The forest by the river on the south-east, and the ravine of bushes in front of it.
    for y in range(FOREST_SE[1], FOREST_SE[3] + 1):
        for x in range(FOREST_SE[0], FOREST_SE[2] + 1):
            ragged = (x - FOREST_SE[0]) < 2 and (x + y) % 3 == 0
            g[y][x] = "." if ragged else "f"
    for y in range(RAVINE[1], RAVINE[3] + 1):
        for x in range(RAVINE[0], RAVINE[2] + 1):
            if g[y][x] != "f":
                g[y][x] = "f" if rng.random() < 0.18 else "."
    # Copses on the field.
    for cx, cy in [(48, 54), (60, 34), (124, 58), (100, 30), (36, 66)]:
        blob(g, cx, cy, 2, "f")
    # The rise of the old oak above the Kropivna.
    blob(g, 133, 81, 3, "h")
    # The Muscovite camp's clearing.
    for y in range(MOSCOW_CAMP[1], MOSCOW_CAMP[3] + 1):
        for x in range(MOSCOW_CAMP[0], MOSCOW_CAMP[2] + 1):
            g[y][x] = "."
    # The Kropivna: a bog five cells wide from the north edge to the Dnieper, a quagmire
    # channel down its middle broken by firm places every so often.
    for y in range(0, RIVER[0]):
        c = kropivna(y)
        for x in range(c - KROPIVNA_HALF, c + KROPIVNA_HALF + 1):
            g[y][x] = "b"
        if (y // 6) % 3 != 0:
            g[y][c] = "B"
    # East of the Kropivna: grass and a wood.
    for y in range(0, RIVER[0] - 2):
        for x in range(kropivna(y) + KROPIVNA_HALF + 4, W):
            if (x * 3 + y * 7) % 11 < 4:
                g[y][x] = "f"
    # The Dnieper, sand on both banks.
    for x in range(W):
        for y in range(RIVER[0], RIVER[1] + 1):
            g[y][x] = "~"
        g[RIVER[0] - 1][x] = "s"
        g[RIVER[1] + 1][x] = "s"
    # The ford upstream: shallows the horse can cross (the guns cannot: t_ford is siege-blocked).
    for y in range(RIVER[0], RIVER[1] + 1):
        for x in range(FORD[0], FORD[1] + 1):
            g[y][x] = "="
    # The bridges at Orsha, and the roads to them on both banks.
    for y in range(RIVER[0], RIVER[1] + 1):
        for x in range(ORSHA[0], ORSHA[1] + 1):
            g[y][x] = "#"
    line(g, [(0, 100), (8, 96), (8, 94)], "#", width=2, keep=("~",))
    line(g, [(8, 86), (14, 70), (30, 50), (60, 26), (70, 16)], "#", width=2, keep=("~",))
    line(g, [(10, 100), (56, 102), (120, 102)], "#", width=2, keep=("~",))
    # The army's camp on the south bank stays open ground.
    for y in range(OUR_CAMP[1], OUR_CAMP[3] + 1):
        for x in range(OUR_CAMP[0], OUR_CAMP[2] + 1):
            if g[y][x] in "f,":
                g[y][x] = "."
    # Firm open ground at both ends of each bridge site and the ford.
    for x0, x1 in BRIDGES + [FORD]:
        for y in list(range(RIVER[0] - 6, RIVER[0] - 1)) + list(range(RIVER[1] + 2, RIVER[1] + 7)):
            for x in range(x0 - 3, x1 + 4):
                if g[y][x] in "fhb,":
                    g[y][x] = "."
    # Clearing for the place of power.
    for kind, x, y in PLACES:
        for dy in range(0, 2):
            for dx in range(0, 2):
                g[y + dy][x + dx] = "h"
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_08 «ВКЛ 8. Орша, 1514» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_08.py, seed {SEED}; edit by hand from here.",
        f"; The Dnieper on rows {RIVER[0]}-{RIVER[1]}: the two bridge sites at x {BRIDGES[0][0]}-{BRIDGES[0][1]}"
        f" and {BRIDGES[1][0]}-{BRIDGES[1][1]} (water until laid),",
        f"; the ford at x {FORD[0]}-{FORD[1]}, the bridges at Orsha at x {ORSHA[0]}-{ORSHA[1]}. The Kropivna's bog"
        f" round x {KROPIVNA_X}, the ravine",
        f"; {RAVINE} and the forest {FOREST_SE} by the river, the Muscovite camp in the north.",
        "; Buildings, units and props: missions/gdl_08/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
