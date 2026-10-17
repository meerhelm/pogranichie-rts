"""Draft layout of the mission map «ВКЛ 5. Ведроша, 1500» (map_gdl_05), 160×100.

    python3 -m tools.maps.gen_gdl_05      # writes maps/map_gdl_05/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings and units are
not in the map: missions/gdl_05/mission.json places them on the cells named below.

From the mission card (section «Карта»): a medium map stretched from west to east, July, dry,
dusty roads. In the west the road from Yelnya comes in (the start and the field camp), the
shallow Vedrosha crosses it; in the middle the river Trosna with its one bridge; beyond it
Mitkovo field and the Muscovite camp, Dorogobuzh far off in the east. The Dnieper closes the
south, a thick forest the north: the ambush regiment stands in it. Below the bridge (towards
the Dnieper, downstream) the card's invented ford over a boggy bank, the way out once the
bridge is gone. Places of power: the kurgan by the road near the start, the spring in the
forest near the ambush. The layout follows the card's reading «Mitkovo field by Dorogobuzh»,
not a survey; where the battle was is disputed.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 160
H = 100
SEED = 1500
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_05" / "terrain.txt"

# Top-left cells of the 2×2 sites, in the card's order: kurgan, spring.
PLACES = [
    ("pp_kurgan", 30, 38),
    ("pp_spring", 112, 10),
]
# The road from Yelnya, west to east, over the Vedrosha and the bridge, to Dorogobuzh.
ROAD = [(0, 50), (20, 50), (44, 49), (66, 49), (80, 49), (110, 50), (140, 50), (160, 50)]
# The Trosna: columns of water, the bridge's rows, the ford's rows below it.
TROSNA_X = 71
TROSNA_W = 3
BRIDGE_ROWS = (49, 50)
FORD_ROWS = (74, 75)
VEDROSHA_X = 44
DNIEPER_Y = 91
# The forest of the ambush: north of this row from the Trosna to the Muscovite camp.
FOREST_EDGE = 30
START = (20, 54)
MOSCOW_CAMP = (148, 50)


def blob(grid, cx, cy, r, ch, keep=("~", "=", "#")):
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


def forest_edge(x: int) -> int:
    """The forest's southern edge at column x (rows above it are forest)."""
    return FOREST_EDGE + int(3 * math.sin(x / 7.0) + 2 * math.sin(x / 3.1))


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Dry stubble and hay fields over much of the open land.
    for _ in range(55):
        x, y = rng.randrange(0, W), rng.randrange(30, DNIEPER_Y)
        blob(g, x, y, rng.randrange(3, 8), ",")
    # The thick forest on the north flank, east of the Trosna: forest, its heart old forest.
    for x in range(TROSNA_X + TROSNA_W + 1, 142):
        edge = forest_edge(x)
        for y in range(0, edge):
            g[y][x] = "F" if y < edge - 12 and (x * 5 + y * 3) % 7 != 0 else "f"
    # A ride through the forest's heart, so the ambush can come out in force.
    for x in range(84, 126):
        for y in range(10, 24):
            if g[y][x] == "F":
                g[y][x] = "f"
    # Woods west of the Trosna on the north edge, copses by the start.
    for x in range(0, TROSNA_X - 1):
        for y in range(0, 12 + int(4 * math.sin(x / 6.0))):
            if (x * 7 + y * 3) % 5 != 0:
                g[y][x] = "f"
    for _ in range(14):
        x, y = rng.randrange(0, TROSNA_X - 4), rng.randrange(14, DNIEPER_Y - 4)
        if abs(x - START[0]) < 14 and abs(y - START[1]) < 12:
            continue
        if abs(y - 50) < 5:
            continue
        blob(g, x, y, rng.randrange(2, 4), "f")
    # Copses on Mitkovo field's south side, by the Dnieper's bank.
    for _ in range(8):
        x, y = rng.randrange(80, 140), rng.randrange(78, DNIEPER_Y - 2)
        blob(g, x, y, rng.randrange(2, 3), "f")
    # A low rise on the field, where the Large Regiment stands.
    blob(g, 122, 52, 4, "h")
    blob(g, 30, 39, 3, "h")
    # The Muscovite camp on open ground in the east.
    for y in range(MOSCOW_CAMP[1] - 12, MOSCOW_CAMP[1] + 13):
        for x in range(MOSCOW_CAMP[0] - 10, W):
            if g[y][x] in "fFh":
                g[y][x] = "."
    # The Dnieper on the south edge, a sandy bank above it.
    for x in range(W):
        top = DNIEPER_Y + int(round(1.5 * math.sin(x / 11.0)))
        for y in range(top, H):
            g[y][x] = "~"
        if top - 1 >= 0:
            g[top - 1][x] = "s"
    # The Vedrosha: shallow all along (ford cells), a stream into the Dnieper.
    for y in range(0, H):
        x = VEDROSHA_X + int(round(1.2 * math.sin(y / 8.0)))
        if g[y][x] != "~":
            g[y][x] = "="
    # The Trosna: three cells of deep water from the forest to the Dnieper, boggy banks below
    # the bridge.
    for y in range(0, H):
        for x in range(TROSNA_X, TROSNA_X + TROSNA_W):
            g[y][x] = "~"
        if 60 <= y < DNIEPER_Y - 1:
            for x in (TROSNA_X - 2, TROSNA_X - 1, TROSNA_X + TROSNA_W, TROSNA_X + TROSNA_W + 1):
                if g[y][x] not in "~":
                    g[y][x] = "b"
    # The road; over the Vedrosha it stays a ford, over the Trosna it is the bridge.
    line(g, ROAD, "#", width=2, keep=("~",))
    for y in BRIDGE_ROWS:
        for x in range(TROSNA_X, TROSNA_X + TROSNA_W):
            g[y][x] = "#"
    # The ford below the bridge: firm ground through the bog, shallows over the channel.
    for y in FORD_ROWS:
        for x in range(TROSNA_X - 3, TROSNA_X + TROSNA_W + 3):
            g[y][x] = "=" if TROSNA_X <= x < TROSNA_X + TROSNA_W else "."
    # The field camp's ground stays open.
    for y in range(START[1] - 8, START[1] + 9):
        for x in range(max(0, START[0] - 12), START[0] + 13):
            if g[y][x] in "fh":
                g[y][x] = "."
    # Clearings for the places of power.
    for kind, x, y in PLACES:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                if g[y + dy][x + dx] in "fF,b":
                    g[y + dy][x + dx] = "h" if kind == "pp_kurgan" else "."
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_05 «ВКЛ 5. Ведроша, 1500» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_05.py, seed {SEED}; edit by hand from here.",
        "; The road from Yelnya in the west over the Vedrosha and the one bridge on the Trosna",
        f"; (x {TROSNA_X}-{TROSNA_X + TROSNA_W - 1}, rows {BRIDGE_ROWS[0]}-{BRIDGE_ROWS[1]}) to Mitkovo field and the",
        f"; Muscovite camp; the ford below the bridge (rows {FORD_ROWS[0]}-{FORD_ROWS[1]}), the forest of the ambush",
        "; on the north, the Dnieper on the south.",
        "; Buildings and units: missions/gdl_05/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
