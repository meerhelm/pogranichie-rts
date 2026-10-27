"""Building cards: every building sprite on a patch of grass with its catalog data, for review.

Step 1 (this script) draws each finished building (`done` stage: colour, shadow, team mask in
the faction colour) on grass tiles at map scale, enlarged 2x in whole pixels, and writes
`cards.json` beside the pictures with the catalog's name, faction, age, cost, build time, HP,
armour and effect. Step 2 (`building_cards.gd`, needs a display) lays each one out in the game's
own frame and theme and saves the card; step 3 zips them.

    python3 -m tools.art.building_cards /tmp/cards
    godot -s tools/art/building_cards.gd -- /tmp/cards
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "art" / "sprites" / "buildings"
TILES = ROOT / "art" / "tiles" / "t_grass.png"
CATALOG = ROOT / "tools" / "catalog" / "catalog.json"
TEAM = {"gdl": (217, 51, 38), "to": (242, 242, 230), "pl": (168, 24, 48), "mo": (40, 90, 170)}
## Line pieces drawn as a short run: the post and both arms.
LINES = ("palisade", "wall")
TILE_W, TILE_H, PERIOD = 96, 48, 8


def catalog_rows() -> dict[str, dict]:
    """Catalog data per sprite id (faction prefix + base id, or the faction's own building)."""
    c = json.loads(CATALOG.read_text())
    rows: dict[str, dict] = {}
    common = {b["id"]: b for b in c["common_buildings"]}
    for fac in ("gdl", "pl", "to", "mo"):
        for bid, b in common.items():
            rows[f"{fac}_{bid}"] = {"name": b.get(f"name_{fac}", ""), "age": b["age"], "cost": b["cost"],
                                    "build_time": b["build_time"], "hp": b["hp"], "armor": b["armor"],
                                    "effect": b["effect"], "faction": fac}
    for b in c["buildings"]:
        bid = b["id"]
        if bid.endswith("*"):  # a faction's replacement of a common building
            base = bid[:-1]
            row = dict(rows[f"{b['faction']}_{base}"])
            row.update(name=b["name"], age=b["age"], build_time=b["build_time"], hp=b["hp"],
                       armor=b["armor"], effect=b["effect"])
            if not b["cost"].startswith("как"):
                row["cost"] = b["cost"]
            rows[f"{b['faction']}_{base}"] = row
        else:
            rows[bid] = {"name": b["name"], "age": b["age"], "cost": b["cost"], "build_time": b["build_time"],
                         "hp": b["hp"], "armor": b["armor"], "effect": b["effect"], "faction": b["faction"]}
    rows["pl_shrine_chapel"] = dict(rows.get("pl_shrine", {}), name="Каплица",
                                    effect="Придорожный крест, освящённый ксендзом: " + rows.get("pl_shrine", {}).get("effect", ""))
    return {k: v for k, v in rows.items() if v.get("name")}, c["factions"]


def tint(team: Image.Image, rgb) -> Image.Image:
    t = team.convert("LA")
    lum = t.getchannel("L")
    out = Image.merge("RGBA", [lum.point(lambda v, k=k: v * k // 255) for k in rgb] + [t.getchannel("A")])
    return out


def view(sid: str) -> tuple[Image.Image, tuple[int, int], float, list[int]]:
    meta = json.loads((SPRITES / f"{sid}.json").read_text())
    pre = SPRITES / f"{sid}_done_"
    color = Image.open(f"{pre}color.png").convert("RGBA")
    shadow = Image.open(f"{pre}shadow.png").convert("LA")
    out = Image.new("RGBA", color.size)
    sh = Image.new("RGBA", color.size, (0, 0, 0, 0))
    sh.putalpha(shadow.getchannel("A").point(lambda a: int(a * 0.7)))
    out.alpha_composite(sh)
    out.alpha_composite(color)
    team = Path(f"{pre}team.png")
    fac = sid.split("_")[0]
    if team.exists() and fac in TEAM:
        out.alpha_composite(tint(Image.open(team), TEAM[fac]))
    return out, tuple(meta["pivot"]), float(meta.get("scale", 1.0)), meta["cells"]


def ground(cells_w: int, cells_h: int, margin: int = 2) -> tuple[Image.Image, tuple[int, int]]:
    """Grass from cell -margin to cells+margin; returns it and the screen point of cell (0, 0)."""
    atlas = Image.open(TILES).convert("RGBA")
    xs = range(-margin, cells_w + margin)
    ys = range(-margin, cells_h + margin)
    pts = [((x - y) * 32, (x + y) * 16) for x in xs for y in ys]
    minx = min(p[0] for p in pts) - TILE_W // 2
    maxx = max(p[0] for p in pts) + TILE_W // 2
    miny = min(p[1] for p in pts) - TILE_H // 2
    maxy = max(p[1] for p in pts) + TILE_H // 2
    im = Image.new("RGBA", (maxx - minx, maxy - miny))
    for y in ys:
        for x in xs:
            tx, ty = x % PERIOD, y % PERIOD
            tile = atlas.crop((tx * TILE_W, ty * TILE_H, (tx + 1) * TILE_W, (ty + 1) * TILE_H))
            sx, sy = (x - y) * 32 - minx - TILE_W // 2, (x + y) * 16 - miny - TILE_H // 2 + 16
            im.alpha_composite(tile, (sx, sy))
    return im, (-minx, -miny)


def card_image(sid: str) -> Image.Image:
    base = sid.split("_", 1)[1]
    _, _, _, cells = view(sid)
    w, h = cells if isinstance(cells, list) else (cells, cells)
    run = 3 if base in LINES else 1
    grass, origin = ground(max(w, run), h)
    canvas_pad = 160
    canvas = Image.new("RGBA", (grass.width + 2 * canvas_pad, grass.height + 2 * canvas_pad))
    canvas.alpha_composite(grass, (canvas_pad, canvas_pad))
    ox, oy = origin[0] + canvas_pad, origin[1] + canvas_pad
    placed = []
    if base in LINES:
        for cx in range(run):
            for p in ([f"{sid}_w"] if cx > 0 else []) + [sid] + ([f"{sid}_e"] if cx < run - 1 else []):
                placed.append((p, cx + 0.5, 0.5))
        placed.sort(key=lambda t: t[1])
    else:
        placed.append((sid, w / 2, h / 2))
    for p, cx, cy in placed:
        im, pv, sc, _ = view(p)
        if sc != 1.0:
            im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
            pv = (round(pv[0] * sc), round(pv[1] * sc))
        sx = ox + round((cx - cy) * 32) - pv[0]
        sy = oy + round((cx + cy) * 16) - pv[1]
        canvas.alpha_composite(im, (sx, sy))
    bb = canvas.getbbox()
    canvas = canvas.crop(bb)
    return canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST)


def ids() -> list[str]:
    out = []
    for j in sorted(SPRITES.glob("*.json")):
        sid = j.stem
        if re.search(r"_(e|w|n|s|v)$", sid) or not (SPRITES / f"{sid}_done_color.png").exists():
            continue
        out.append(sid)
    return out


def main(dest: str) -> None:
    out = Path(dest)
    (out / "img").mkdir(parents=True, exist_ok=True)
    rows, factions = catalog_rows()
    cards = []
    for sid in ids():
        row = rows.get(sid)
        if row is None:
            print("no catalog row for", sid)
            continue
        card_image(sid).save(out / "img" / f"{sid}.png")
        _, _, scale, cells = view(sid)
        w, h = cells if isinstance(cells, list) else (cells, cells)
        cost = re.findall(r"\d+", row["cost"].split(",")[0])
        cards.append({"id": sid, "img": str((out / "img" / f"{sid}.png").resolve()), "name": row["name"].rstrip("*"),
                      "faction": factions[row["faction"]]["name"], "age": row["age"],
                      "cost": [int(x) for x in cost[:4]] if len(cost) >= 4 else [],
                      "cost_note": row["cost"] if len(cost) < 4 or "," in row["cost"] else "",
                      "build_time": row["build_time"], "hp": row["hp"], "armor": row["armor"],
                      "effect": row["effect"], "cells": f"{w}×{h}", "pixel": scale == 1.0})
    (out / "cards.json").write_text(json.dumps(cards, ensure_ascii=False, indent=1))
    print(len(cards), "cards")


if __name__ == "__main__":
    main(sys.argv[1])
