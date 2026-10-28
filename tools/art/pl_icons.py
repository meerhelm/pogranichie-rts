"""Pixel-art HUD icons of techs and spells from PixelLab (art_src/pixellab/icons).

Each id has 16 variants (art_src/pixellab/icons/<id>/icon_<i>.png, 64x64 on transparency, made
by /generate-with-style-v2 with our pixel order icons as the style); picks.json names the chosen
one (0 when missing). The icon is the picked variant on the slate plate of the unit portraits,
enlarged in whole pixels to 128x128: ui/icons/techs/<id>.png, ui/icons/spells/<id>.png or, for
an order (an id without a t_ / sp_ prefix), ui/icons/orders/<id>.png. IconDB prefers these PNGs
to the older hand-drawn SVGs.

Unit and hero portraits come the same way from art_src/pixellab/portraits (--portraits) and go
to ui/icons/units/<id>.png, replacing the crops of the sprites.

    python3 -m tools.art.pl_icons [--portraits] [id ...]  # write the icons
    python3 -m tools.art.pl_icons --sheet out.png [id ...]  # every variant, numbered, for picking
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from tools.art import icons as ic

SRC = Path("art_src/pixellab/icons")
OUT = Path("ui/icons")
MARGIN = 8


def variants(uid: str) -> list[Path]:
    return sorted((SRC / uid).glob("icon_*.png"), key=lambda p: int(p.stem.split("_")[1]))


def icon(variant: Path) -> Image.Image:
    """The variant on the plate, cropped to its figure and enlarged in whole pixel steps."""
    fig = Image.open(variant).convert("RGBA")
    box = fig.getchannel("A").point(lambda a: 255 if a > 100 else 0).getbbox()
    tile = ic._plate("unit")
    if box is None:
        return tile
    fig = fig.crop(box)
    room = ic.SIZE - 2 * MARGIN
    k = max(1, min(room // fig.width, room // fig.height))
    fig = fig.resize((fig.width * k, fig.height * k), Image.NEAREST)
    if fig.width > room or fig.height > room:  # bigger than the room even at 1x: shrink to fit
        fig.thumbnail((room, room), Image.NEAREST)
    tile.alpha_composite(fig, ((ic.SIZE - fig.width) // 2, (ic.SIZE - fig.height) // 2))
    return tile


def sheet(ids: list[str], out: str) -> None:
    cell = 72
    rows = [(uid, variants(uid)) for uid in ids]
    im = Image.new("RGBA", (cell * 16 + 170, cell * len(rows)), (24, 24, 24, 255))
    d = ImageDraw.Draw(im)
    for r, (uid, vs) in enumerate(rows):
        d.text((4, r * cell + cell // 2 - 6), uid, fill=(255, 220, 0))
        for i, v in enumerate(vs):
            im.alpha_composite(icon(v).resize((cell - 6, cell - 6), Image.NEAREST), (170 + i * cell, r * cell + 3))
            d.text((170 + i * cell + 2, r * cell + 2), str(i), fill=(255, 255, 0))
    im.save(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet")
    ap.add_argument("--portraits", action="store_true", help="unit portraits, not tech/spell/order icons")
    ap.add_argument("ids", nargs="*")
    a = ap.parse_args()
    global SRC
    if a.portraits:
        SRC = Path("art_src/pixellab/portraits")
    ids = a.ids or sorted(p.name for p in SRC.iterdir() if p.is_dir() and variants(p.name))
    if a.sheet:
        sheet(ids, a.sheet)
        return
    picks_path = SRC / "picks.json"
    picks = json.loads(picks_path.read_text()) if picks_path.exists() else {}
    for uid in ids:
        vs = variants(uid)
        if not vs:
            continue
        if a.portraits:
            kind = "units"
        else:
            kind = "spells" if uid.startswith("sp_") else "techs" if uid.startswith("t_") else "orders"
        icon(vs[min(picks.get(uid, 0), len(vs) - 1)]).save(OUT / kind / f"{uid}.png", optimize=True)
        print(uid, "->", kind)


if __name__ == "__main__":
    main()
