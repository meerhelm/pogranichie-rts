"""Button icons for the HUD from the rendered sprites: every prototype building (finished,
the `done` stage) and every unit a building trains, as 128×128 PNG tiles in
ui/icons/buildings and ui/icons/units. A tile is the sprite with its shadow and the team
mask tinted in the faction colour, fitted over a dark ground plate with a soft light.
Hand-drawn SVG icons (orders, techs, ages, spells) live beside them in ui/icons.
The list of all icons is the «Иконки интерфейса» doc (docs/07-ui-icons.md).

    python3 -m tools.art.icons            # all tiles
    python3 -m tools.art.icons gdl_house  # only these ids
"""

import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPRITES = os.path.join(ROOT, "art", "sprites")
OUT = os.path.join(ROOT, "ui", "icons")
SIZE = 128
MARGIN = 6
## Team mask colour per faction: the Duchy's red (player 1 in a skirmish), the Order's white.
FACTION_TEAM = {"gdl": (217, 51, 38), "to": (242, 242, 230), "nt": (180, 180, 180)}
## Units are shown turned three-quarters to the viewer (UnitView.facing 3 = south-west).
UNIT_FACING = 3
## No upscaling beyond this, so small figures stay crisp.
MAX_UNIT_SCALE = 1.35


def _tint(team: Image.Image, rgb) -> Image.Image:
    solid = Image.new("RGBA", team.size, rgb + (255,))
    out = ImageChops.multiply(team, solid)
    out.putalpha(team.getchannel("A"))
    return out


def _compose(color: Image.Image, team: Image.Image | None, shadow: Image.Image, rgb) -> Image.Image:
    out = Image.new("RGBA", color.size, (0, 0, 0, 0))
    sh = shadow.copy()
    sh.putalpha(sh.getchannel("A").point(lambda a: int(a * 0.7)))
    out.alpha_composite(sh)
    out.alpha_composite(color)
    if team is not None:
        out.alpha_composite(_tint(team, rgb))
    return out


def _plate(kind: str) -> Image.Image:
    """Dark ground with a light from the upper left: olive for buildings, slate for units."""
    top, bottom = ((74, 82, 52), (34, 36, 24)) if kind == "building" else ((70, 72, 74), (30, 30, 34))
    plate = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(plate)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        draw.line([(0, y), (SIZE, y)], fill=c + (255,))
    glow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(glow).ellipse((-30, -40, SIZE - 10, SIZE - 30), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(24))
    light = Image.new("RGBA", (SIZE, SIZE), (255, 236, 190, 0))
    light.putalpha(glow)
    plate.alpha_composite(light)
    return plate


def _fit(img: Image.Image, kind: str) -> Image.Image:
    box = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    img = img.crop(box)
    room = SIZE - 2 * MARGIN
    scale = min(room / img.width, room / img.height)
    if kind == "unit":
        scale = min(scale, MAX_UNIT_SCALE)
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    img = img.resize(size, Image.LANCZOS)
    tile = _plate(kind)
    x = (SIZE - img.width) // 2
    y = SIZE - MARGIN - img.height if kind == "unit" else (SIZE - img.height) // 2
    tile.alpha_composite(img, (x, y))
    return tile


def _load(prefix: str):
    color = Image.open(prefix + "color.png").convert("RGBA")
    team = Image.open(prefix + "team.png").convert("RGBA") if os.path.exists(prefix + "team.png") else None
    shadow = Image.open(prefix + "shadow.png").convert("RGBA")
    return color, team, shadow


def building_icon(def_id: str) -> Image.Image:
    color, team, shadow = _load(os.path.join(SPRITES, "buildings", f"{def_id}_done_"))
    return _fit(_compose(color, team, shadow, FACTION_TEAM[def_id.split("_")[0]]), "building")


def unit_icon(type_id: str) -> Image.Image:
    folder = os.path.join(SPRITES, "units", type_id)
    meta = json.load(open(os.path.join(folder, "sheet.json")))
    fw, fh = meta["frame"]
    row = meta["anims"]["idle"]["row"] + UNIT_FACING
    color, team, shadow = _load(folder + "/")
    box = (0, row * fh, fw, (row + 1) * fh)
    parts = [p.crop(box) if p is not None else None for p in (color, team, shadow)]
    rgb = FACTION_TEAM.get(type_id.split("_")[0], (217, 51, 38))
    return _fit(_compose(parts[0], parts[1], parts[2], rgb), "unit")


def _prototype():
    proto = json.load(open(os.path.join(ROOT, "tools", "catalog", "prototype.json")))
    buildings = list(proto["buildings"])
    units = [u for u in proto["units"] if u.startswith(("gdl_", "to_"))]
    return buildings, units


def main(ids: list[str]) -> None:
    buildings, units = _prototype()
    os.makedirs(os.path.join(OUT, "buildings"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "units"), exist_ok=True)
    for b in buildings:
        if not ids or b in ids:
            building_icon(b).save(os.path.join(OUT, "buildings", b + ".png"), optimize=True)
    for u in units:
        if not ids or u in ids:
            unit_icon(u).save(os.path.join(OUT, "units", u + ".png"), optimize=True)


if __name__ == "__main__":
    main(sys.argv[1:])
