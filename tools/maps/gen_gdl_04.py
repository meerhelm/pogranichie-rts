"""Draft layout of the mission map «ВКЛ 4. Вилькомир, 1435» (map_gdl_04), 160×120.

    python3 -m tools.maps.gen_gdl_04      # writes maps/map_gdl_04/terrain.txt

The map file is the source of truth once it exists; this script only made the first draft
and can be re-run to try another one. Legend: core/nav/map_text.gd. Buildings and units are
not in the map: missions/gdl_04/mission.json places them on the cells named below.

From the mission card (section «Карта»): lake Žirnajai stretches from south to north and
splits the map, Sigismund's camp on the east shore, Švitrigaila's on the west. A boggy stream
runs out of the lake's northern end and crosses the road to Vilkomir that the column takes
north along the west shore; three fords cross it, the middle one right into the column's
middle. North of the lake's end, between it and the river Šventoji, lies the only dry way round
the lake. The Šventoji closes the northern edge; the road crosses it by a ford. Late summer:
stubble fields, copses (the card's own assumption: the sources name no woods). Places of power:
the footprint stone on the east shore (Sigismund's from the start), the spring on the island
(reached over shallows from the east shore), the kurgan by the road on the west shore.
The layout follows the card, not a survey of the field near Pabaiskas.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W = 160
H = 120
SEED = 1435
OUT = Path(__file__).resolve().parents[2] / "maps" / "map_gdl_04" / "terrain.txt"

# Top-left cells of the 2×2 sites, in the card's order: stone, spring, kurgan.
PLACES = [
    ("pp_footprint_stone", 110, 46),
    ("pp_spring", 84, 71),
    ("pp_kurgan", 58, 60),
]
RIVER = [(0, 5), (30, 5), (50, 8), (64, 14), (76, 22), (84, 25), (94, 22), (108, 14), (126, 8), (160, 5)]
STREAM = [(81, 38), (68, 38), (56, 37), (46, 35), (34, 37), (20, 38), (0, 37)]
ROAD = [(22, 104), (30, 92), (40, 80), (48, 66), (52, 52), (50, 44), (46, 35), (40, 26), (32, 16), (25, 8), (25, 0)]
# x of the three fords over the stream: west, middle, east.
FORDS = [25, 56, 70]
EAST_CAMP = (126, 58)
WEST_CAMP = (26, 96)


def blob(grid, cx, cy, r, ch, keep=("~", "=", "#")):
    for y in range(max(0, int(cy - r - 2)), min(H, int(cy + r + 3))):
        for x in range(max(0, int(cx - r - 2)), min(W, int(cx + r + 3))):
            wobble = r * (0.75 + 0.25 * math.sin(x * 0.7 + y * 0.4 + cx))
            if (x - cx) ** 2 + (y - cy) ** 2 <= wobble**2 and grid[y][x] not in keep:
                grid[y][x] = ch


def line(grid, points, ch, width=1, keep=(), offset=0):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps) + offset
            y = round(y0 + (y1 - y0) * i / steps) + offset
            for dy in range(width):
                for dx in range(width):
                    if 0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx] not in keep:
                        grid[y + dy][x + dx] = ch


def river_y(x: float) -> float:
    for (x0, y0), (x1, y1) in zip(RIVER, RIVER[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return RIVER[-1][1]


def lake_half(y: int) -> float:
    """Half width of the lake at row y (0: no lake)."""
    if y < 38:
        return 0.0
    return min((y - 38) * 0.7 + 1.5, 6.5) + 0.8 * math.sin(y / 5.0)


def lake_x(y: int) -> float:
    return 84 + 2.0 * math.sin(y / 9.0)


def generate(seed: int = SEED) -> list[str]:
    rng = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]
    # Stubble fields over most of the open land.
    for _ in range(60):
        x, y = rng.randrange(0, W), rng.randrange(10, H)
        blob(g, x, y, rng.randrange(3, 8), ",")
    # Copses, kept off the camps, the road's line and the dry strip north of the lake.
    for _ in range(46):
        x, y = rng.randrange(0, W), rng.randrange(0, H)
        if abs(x - EAST_CAMP[0]) < 16 and abs(y - EAST_CAMP[1]) < 14:
            continue
        if abs(x - WEST_CAMP[0]) < 16 and abs(y - WEST_CAMP[1]) < 14:
            continue
        if 60 <= x <= 104 and 20 <= y <= 44:
            continue
        if 26 <= x <= 62 and 10 <= y <= 70:
            continue
        blob(g, x, y, rng.randrange(2, 5), "f")
    # Forest beyond the river and along the far edges.
    for x in range(W):
        for y in range(0, max(0, int(river_y(x)) - 2)):
            if (x * 7 + y * 3) % 5 != 0:
                g[y][x] = "f"
    # Low hills: the kurgan's rise, the east shore's ridge over the camp.
    blob(g, 59, 61, 3, "h")
    blob(g, 132, 44, 4, "h")
    blob(g, 18, 70, 4, "h")
    # The river Šventoji, 4 cells of water.
    for x in range(W):
        c = int(round(river_y(x)))
        for y in range(c - 1, c + 3):
            if 0 <= y < H:
                g[y][x] = "~"
    # Lake Žirnajai.
    for y in range(H):
        half = lake_half(y)
        if half <= 0:
            continue
        cx = lake_x(y)
        for x in range(W):
            if abs(x - cx) <= half:
                g[y][x] = "~"
    # The island with the spring, and the shallows to the east shore.
    blob(g, 85, 72, 3.2, ".", keep=())
    for y in (71, 72, 73):
        for x in range(87, 96):
            if g[y][x] == "~":
                g[y][x] = "="
    # The boggy stream: a bog flood plain 5 cells wide, a channel 1 cell wide.
    line(g, STREAM, "b", width=5, keep=("~",), offset=-2)
    line(g, STREAM, "~", width=1)
    # Three fords: firm ground across the plain, a ford cell over the channel.
    for fx in FORDS:
        for y in range(30, 44):
            for x in range(fx - 1, fx + 2):
                if g[y][x] == "b":
                    g[y][x] = "."
                elif g[y][x] == "~" and 33 <= y <= 40:
                    g[y][x] = "="
    # The dry strip north of the lake's end: open ground, no fields.
    for y in range(24, 38):
        for x in range(62, 104):
            if g[y][x] in "f,h":
                g[y][x] = "."
    # The camps stand on open ground.
    for cx, cy in (EAST_CAMP, WEST_CAMP):
        for y in range(cy - 9, cy + 10):
            for x in range(cx - 11, cx + 12):
                if 0 <= x < W and 0 <= y < H and g[y][x] in "fh":
                    g[y][x] = "."
    # The road to Vilkomir, a causeway over the stream and a ford over the river.
    line(g, ROAD, "#", width=2, keep=())
    for x in range(W):
        for y in range(H):
            if g[y][x] == "#" and abs(y - river_y(x) - 0.5) <= 2.0:
                g[y][x] = "="
    # Clearings for the places of power.
    for kind, x, y in PLACES:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                if g[y + dy][x + dx] in "f,b":
                    g[y + dy][x + dx] = "h" if kind == "pp_kurgan" else "."
    return ["".join(r) for r in g]


def main() -> None:
    rows = generate()
    header = [
        f"; map_gdl_04 «ВКЛ 4. Вилькомир, 1435» (mission), {W}x{H}.",
        f"; First draft by tools/maps/gen_gdl_04.py, seed {SEED}; edit by hand from here.",
        "; Lake Žirnajai in the middle (Sigismund's camp east of it, Švitrigaila's in the",
        "; south-west), the boggy stream out of its northern end with three fords and the road's",
        "; causeway, the dry strip between the lake's end and the Šventoji, the river on the north.",
        "; Buildings and units: missions/gdl_04/mission.json. Legend: core/nav/map_text.gd.",
    ]
    places = [f"@place {kind} {x} {y}" for kind, x, y in PLACES]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
