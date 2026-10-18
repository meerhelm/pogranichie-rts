"""The mission map «Корона 1. Грюнвальд» (map_crown_01): the field of «ВКЛ 2» (map_gdl_02) with
the oak grove the Polish wing waits in.

    python3 -m tools.maps.gen_crown_01      # writes maps/map_crown_01/terrain.txt

The card (docs/03-missions/12-crown_01_grunwald_1410.md) shares the map with «ВКЛ 2»; its
opening scene puts the Polish banners «в тени дубравы» while the Order stands in the sun. So
the map is map_gdl_02 cell for cell, with one grove behind the Polish left wing, by Stębark.
Re-run it after map_gdl_02 changes. Legend: core/nav/map_text.gd. Units are not in the map:
missions/crown_01/mission.json places them.
"""

from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "maps" / "map_gdl_02" / "terrain.txt"
OUT = ROOT / "maps" / "map_crown_01" / "terrain.txt"

# The grove: an oval behind the left wing, with ragged edges.
GROVE = (28, 126, 17, 4)


def generate() -> tuple[list[str], list[str]]:
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    places = [ln for ln in lines if ln.startswith("@")]
    rows = [list(ln) for ln in lines if not ln.startswith((";", "@"))]
    cx, cy, rx, ry = GROVE
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            wobble = 1.0 + 0.18 * math.sin(x * 0.9 + y * 0.5)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= wobble and rows[y][x] == ".":
                rows[y][x] = "f"
    return places, ["".join(r) for r in rows]


def main() -> None:
    places, rows = generate()
    header = [
        f"; map_crown_01 «Корона 1. Грюнвальд» (mission), {len(rows[0])}x{len(rows)}.",
        "; Made by tools/maps/gen_crown_01.py from map_gdl_02 plus the oak grove behind the",
        "; Polish left wing; re-run it rather than editing by hand.",
        "; Units: missions/crown_01/mission.json. Legend: core/nav/map_text.gd.",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(header + places + rows) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
