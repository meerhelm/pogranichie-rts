"""Composites rendered passes the way the game will draw them (shadow, colour, team tint)
over grass, for review: `python3 -m tools.art.preview <sprites dir> <out.png>`."""

import json
import os
import sys

from PIL import Image, ImageChops

TEAM_COLORS = [(217, 51, 38), (51, 102, 230)]
GRASS = (88, 122, 62)


def tint(team: Image.Image, rgb) -> Image.Image:
    solid = Image.new("RGBA", team.size, rgb + (255,))
    out = ImageChops.multiply(team, solid)
    out.putalpha(team.getchannel("A"))
    return out


def compose(color, team, shadow, rgb, bg=GRASS) -> Image.Image:
    base = Image.new("RGBA", color.size, bg + (255,))
    base.alpha_composite(shadow)
    base.alpha_composite(color)
    base.alpha_composite(tint(team, rgb))
    return base


def load(prefix: str):
    return [Image.open(f"{prefix}{p}.png").convert("RGBA") for p in ("color", "team", "shadow")]


def unit_strip(unit_dir: str, rgb, frame_col: int = 0, anim: str = "walk") -> Image.Image:
    meta = json.load(open(os.path.join(unit_dir, "sheet.json")))
    fw, fh = meta["frame"]
    row0 = meta["anims"][anim]["row"]
    sheets = load(unit_dir + "/")
    strip = Image.new("RGBA", (fw * 8, fh))
    for facing in range(8):
        box = (frame_col * fw, (row0 + facing) * fh, (frame_col + 1) * fw, (row0 + facing + 1) * fh)
        parts = [s.crop(box) for s in sheets]
        strip.paste(compose(*parts, rgb), (facing * fw, 0))
    return strip


if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    rows = []
    for uid in sorted(os.listdir(os.path.join(src, "units"))):
        for rgb in TEAM_COLORS:
            rows.append(unit_strip(os.path.join(src, "units", uid), rgb))
    w = max(r.width for r in rows)
    sheet = Image.new("RGBA", (w, sum(r.height for r in rows)), GRASS + (255,))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(out)


def buildings_sheet(src: str, ids: list[str], out: str, stage: str = "done", cols: int = 4,
                    rgb=TEAM_COLORS[1]) -> None:
    """Finished views of buildings side by side on grass, each over its footprint diamond, at
    render size (twice the game's)."""
    from PIL import ImageDraw

    tiles = []
    for uid in ids:
        meta = json.load(open(os.path.join(src, "buildings", f"{uid}.json")))
        color, team, shadow = load(os.path.join(src, "buildings", f"{uid}_{stage}_"))
        img = Image.new("RGBA", color.size, GRASS + (255,))
        d = ImageDraw.Draw(img)
        px, py = meta["pivot"]
        w, h = meta["cells"]
        # Footprint corners: cell x runs down-right (64, 32), cell y down-left (-64, 32).
        pts = [(px + (x - y) * 64 / 2 * 2 / 2, py + (x + y) * 32 / 2 * 2 / 2)
               for x, y in ((-w, -h), (w, -h), (w, h), (-w, h))]
        d.polygon(pts, outline=(60, 80, 40))
        img.alpha_composite(shadow)
        img.alpha_composite(color)
        img.alpha_composite(tint(team, rgb))
        tiles.append(img)
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    width = max(sum(t.width for t in r) for r in rows)
    sheet = Image.new("RGBA", (width, sum(max(t.height for t in r) for r in rows)), GRASS + (255,))
    y = 0
    for r in rows:
        x = 0
        hh = max(t.height for t in r)
        for t in r:
            sheet.paste(t, (x, y + hh - t.height))
            x += t.width
        y += hh
    sheet.save(out)
