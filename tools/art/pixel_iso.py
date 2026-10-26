"""Pixel-art sprites for the isometric view from Retro Diffusion output (art_src/pixel_iso).

Turns raw generated images into the game's sprite folders (art/sprites/...), the same layout
the Blender pipeline writes, but drawn at map scale ("scale": 1.0 in the JSON, so SpriteDB
draws them 1:1 and pixels stay crisp):
- buildings: 7 stages per id (found, build_33, build_66 drawn by script from the finished
  sprite; damaged_1/2 by soot and holes; rubble from a generated heap), colour + shadow (LA)
  + team mask (LA); turned views `<id>_v` are mirrors; palisade post and arms are stamped
  from single stakes cut out of a generated palisade;
- trees: colour + shadow, pivot at the foot of the trunk;
- decals: small ground details (flowers, stones…), shrunk to map size, packed for DecalLayer.

    python3 -m tools.art.pixel_iso --src art_src/pixel_iso/full --out art/sprites
"""

import argparse
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

STAGES = ["found", "build_33", "build_66", "done", "damaged_1", "damaged_2", "rubble"]
OUTL = (0x2A, 0x1C, 0x14, 255)
WOOD = (0x8A, 0x68, 0x44, 255)
WOOD_D = (0x4A, 0x34, 0x24, 255)
DUST = (0xA8, 0x8A, 0x60, 255)
PAD = (0x6B, 0x4C, 0x32, 150)
INNER = (0x14, 0x12, 0x10, 255)
CHAR = (0x3A, 0x2A, 0x20, 255)
## Shadow of a point `h` pixels above the ground: sun upper left, so it falls down-right.
## The silhouette is sheared right by SHADOW_DX per pixel of height and squashed to SHADOW_DY.
SHADOW_DX, SHADOW_DY = 0.6, 0.45

# id: (cells w, h, faction, rubble kind, mirror source or None)
BUILD = {
    "gdl_town_center": (4, 4, "gdl", "wood"),
    "gdl_house": (2, 2, "gdl", "wood"),
    "gdl_granary": (2, 2, "gdl", "wood"),
    "gdl_lumber_yard": (2, 2, "gdl", "wood"),
    "gdl_mine": (2, 2, "gdl", "wood"),
    "gdl_shrine": (2, 2, "gdl", "wood"),
    "gdl_farm": (3, 3, "gdl", "wood"),
    "gdl_barracks": (3, 3, "gdl", "wood"),
    "gdl_range": (3, 3, "gdl", "wood"),
    "gdl_stable": (3, 3, "gdl", "wood"),
    "gdl_bort": (1, 1, "gdl", "wood"),
    "gdl_gate": (1, 1, "gdl", "wood"),
    "gdl_tower": (1, 1, "gdl", "wood"),
    "gdl_zaseka": (3, 1, "gdl", "wood"),
    "to_castle": (4, 4, "to", "brick"),
    "to_house": (2, 2, "to", "wood"),
    "to_gate": (1, 1, "to", "wood"),
    "to_shrine": (2, 2, "to", "brick"),
}
## Turned views: mirror of the base view (a line along y instead of x).
MIRRORS = {"gdl_gate_v": "gdl_gate", "gdl_zaseka_v": "gdl_zaseka", "to_gate_v": "to_gate"}
## Raw file per id when it is not simply <id>_1.png (best pick after review).
PICK: dict[str, str] = {}


# --- basics ----------------------------------------------------------------------------------

def clean(im: Image.Image) -> Image.Image:
    """Hard alpha (pixel art), trimmed to the opaque pixels."""
    a = np.array(im.convert("RGBA"))
    keep = a[..., 3] >= 128
    a[..., 3] = np.where(keep, 255, 0)
    a[~keep, :3] = 0
    out = Image.fromarray(a, "RGBA")
    return out.crop(out.getbbox())


def foot_of(im: Image.Image) -> tuple[int, int]:
    """Bottom corner of the footprint: centre x of the opaque pixels, lowest opaque row near it."""
    a = np.array(im)[..., 3] > 0
    cols = np.nonzero(a.any(0))[0]
    cx = (int(cols[0]) + int(cols[-1]) + 1) // 2
    rows = np.nonzero(a[:, max(0, cx - 3): cx + 4].any(1))[0]
    return cx, int(rows[-1]) + 1 if len(rows) else im.height


def shadow_of(color: Image.Image, base_y: int) -> Image.Image:
    """Ground shadow (LA, white with alpha) of the sprite: every opaque pixel thrown down-right
    along the ground by its height over `base_y`."""
    a = np.array(color)[..., 3] > 0
    h, w = a.shape
    sh = np.zeros((h, w), bool)
    ys, xs = np.nonzero(a)
    hgt = np.maximum(base_y - ys, 0)
    sx = np.round(xs + hgt * SHADOW_DX).astype(int)
    sy = np.round(base_y - hgt * SHADOW_DY).astype(int)
    ok = (sx >= 0) & (sx < w) & (sy >= 0) & (sy < h)
    sh[sy[ok], sx[ok]] = True
    # close pinholes
    sh = sh | (np.roll(sh, 1, 1) & np.roll(sh, -1, 1)) | (np.roll(sh, 1, 0) & np.roll(sh, -1, 0))
    sh &= ~a
    la = np.zeros((h, w, 2), np.uint8)
    la[..., 0] = 0
    la[..., 1] = np.where(sh, 150, 0)
    return Image.fromarray(la, "LA")


def pad_canvas(im: Image.Image, left: int, top: int, right: int, bottom: int) -> Image.Image:
    out = Image.new(im.mode, (im.width + left + right, im.height + top + bottom))
    out.paste(im, (left, top))
    return out


def diamond(d: ImageDraw.ImageDraw, cx: float, top: float, w: int, h: int, **kw) -> None:
    """Footprint of w x h cells with its top corner at (cx, top)."""
    pts = [(cx, top), (cx + w * 32, top + w * 16), (cx + (w - h) * 32, top + (w + h) * 16),
           (cx - h * 32, top + h * 16)]
    d.polygon(pts, **kw)


# --- stages ----------------------------------------------------------------------------------

def found(size, pivot, w, h, rnd) -> Image.Image:
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    cx, cy = pivot
    top = cy - (w + h) * 8
    left = cx - (w - h) * 16
    diamond(d, left, top + 2, w, h, fill=PAD)
    diamond(d, left, top + 4, w, h, outline=DUST)
    corners = [(left, top + 6), (left + w * 32 - 4, top + w * 16 + 2),
               (left + (w - h) * 32, top + (w + h) * 16 - 2), (left - h * 32 + 4, top + h * 16 + 2)]
    for x, y in corners:
        stake(d, int(x), int(y))
    if w * h >= 4:
        logs(d, int(cx - 6), int(cy + 4))
    return im


def stake(d, x, y, hgt=8):
    d.rectangle((x - 1, y - hgt, x, y), fill=WOOD)
    d.line((x - 2, y - hgt, x - 2, y), fill=OUTL)
    d.line((x + 1, y - hgt, x + 1, y), fill=OUTL)
    d.point((x - 1, y - hgt - 1), fill=OUTL)
    d.point((x, y - hgt - 1), fill=OUTL)


def logs(d, x, y, n=3):
    for i in range(n):
        d.rectangle((x, y - i * 3, x + 12, y - i * 3 + 2), fill=WOOD, outline=OUTL)


def scaffold(d, box, top, ground):
    x0, x1 = box[0] - 1, box[2]
    for a, b in ((x0, x0 + 6), (x1 - 6, x1)):
        for x in (a, b):
            d.line((x, top, x, ground), fill=WOOD)
            d.line((x + 1, top, x + 1, ground), fill=WOOD_D)
        for y in range(ground - 7, top + 2, -11):
            d.line((a, y, b + 1, y), fill=WOOD)
            d.line((a, y + 1, b + 1, y + 1), fill=WOOD_D)


def rising(done, frac, size, pivot, w, h, rnd) -> Image.Image:
    """Under construction: the lower `frac` of the building on its site, scaffolds around."""
    im = found(size, pivot, w, h, rnd)
    a = np.array(done)
    rows = np.nonzero(a[..., 3].any(1))[0]
    top, bottom = rows[0], rows[-1]
    cut = int(bottom - (bottom - top) * frac)
    part = a.copy()
    part[:cut] = 0
    for x in range(part.shape[1]):
        if rnd.random() < 0.4:
            part[cut: cut + rnd.randint(1, 3), x] = 0
    pim = Image.fromarray(part, "RGBA")
    im.alpha_composite(pim)
    box = pim.getbbox()
    if box:
        scaffold(ImageDraw.Draw(im), box, cut - 4, bottom - 2)
    return im


def soot(im, blobs, k, holes, rnd):
    a = np.array(im)
    ys, xs = np.nonzero(a[..., 3])
    if len(xs) == 0:
        return im
    for _ in range(blobs):
        i = rnd.randrange(len(xs))
        cx, cy, r = xs[i], ys[i], rnd.randint(3, 6)
        yy, xx = np.ogrid[: a.shape[0], : a.shape[1]]
        m = ((xx - cx) ** 2 + (yy - cy) ** 2 <= r * r) & (a[..., 3] > 0)
        a[m, :3] = (a[m, :3] * k).astype(np.uint8)
    for _ in range(holes):
        i = rnd.randrange(len(xs))
        a[ys[i]: ys[i] + 2, xs[i]: xs[i] + 2] = np.where(
            a[ys[i]: ys[i] + 2, xs[i]: xs[i] + 2, 3:] > 0, np.array(INNER, np.uint8), 0)
    return Image.fromarray(a, "RGBA")


def broken(im, rnd):
    """Roof caved in: a jagged dark hole in the upper third, charred rim, nibbled top edge."""
    a = np.array(im)
    rows = np.nonzero(a[..., 3].any(1))[0]
    cols = np.nonzero(a[..., 3].any(0))[0]
    x0, x1, y0, y1 = cols[0], cols[-1], rows[0], rows[-1]
    cx = int(x0 + (x1 - x0) * rnd.uniform(0.35, 0.65))
    cy = int(y0 + (y1 - y0) * 0.3)
    rx, ry = max(3, (x1 - x0) // 9), max(2, (y1 - y0) // 12)
    yy, xx = np.mgrid[: a.shape[0], : a.shape[1]]
    noise = np.random.default_rng(rnd.randint(0, 9999)).uniform(-0.25, 0.25, a.shape[:2])
    hole = ((((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) <= 1 + noise) & (a[..., 3] > 0)
    rim = np.zeros_like(hole)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0)):
        rim |= np.roll(np.roll(hole, dy, 0), dx, 1)
    rim &= ~hole & (a[..., 3] > 0)
    a[hole] = INNER
    a[rim] = CHAR
    for x in range(x0, x1 + 1):
        if rnd.random() < 0.25:
            col = np.nonzero(a[:, x, 3])[0]
            if len(col):
                a[col[0]: col[0] + rnd.randint(1, 4), x] = 0
    return Image.fromarray(a, "RGBA")


def team_mask(im: Image.Image, faction: str) -> Image.Image:
    """White where the player colour shows: red cloth (Duchy), white flags (Order)."""
    a = np.array(im).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    if faction == "gdl":
        m = (r > 140) & (g < 90) & (b < 80)
    else:
        top = np.zeros_like(r, bool)
        top[: int(a.shape[0] * 0.45)] = True
        m = (r > 200) & (g > 200) & (b > 190) & top
    m &= al > 0
    la = np.zeros(a.shape[:2] + (2,), np.uint8)
    la[..., 0] = 255
    la[..., 1] = np.where(m, 255, 0)
    return Image.fromarray(la, "LA")


# --- writers ---------------------------------------------------------------------------------

def save_view(out_dir: Path, prefix: str, color: Image.Image, base_y: int, faction: str | None):
    color.save(out_dir / f"{prefix}color.png", optimize=True)
    if prefix.endswith("_found_"):  # a flat site casts no shadow (its stakes are tiny)
        Image.new("LA", color.size).save(out_dir / f"{prefix}shadow.png", optimize=True)
    else:
        shadow_of(color, base_y).save(out_dir / f"{prefix}shadow.png", optimize=True)
    if faction:
        team_mask(color, faction).save(out_dir / f"{prefix}team.png", optimize=True)


def building(src: Path, out: Path, uid: str, w: int, h: int, faction: str, rubble_kind: str,
             mirror: bool = False, raw_id: str | None = None) -> None:
    raw_id = raw_id or uid
    raw = src / "buildings" / PICK.get(raw_id, f"{raw_id}_1.png")
    if not raw.exists():
        print("missing", raw)
        return
    done = clean(Image.open(raw))
    if mirror:
        done = done.transpose(Image.FLIP_LEFT_RIGHT)
    # Room for the shadow to the right and below, and for the footprint diamond.
    foot_w = (w + h) * 32
    extra_x = max(0, (foot_w - done.width) // 2 + 2)
    done = pad_canvas(done, extra_x, 4, extra_x + 48, (w + h) * 4 + 8)
    bx, by = foot_of(done)
    pivot = (bx - (w - h) * 16, by - (w + h) * 8)
    size = done.size
    rnd = random.Random(uid)
    rub_raw = src / "buildings" / PICK.get(f"rubble_{rubble_kind}", f"rubble_{rubble_kind}_1.png")
    views = {
        "found": found(size, pivot, w, h, rnd),
        "build_33": rising(done, 0.34, size, pivot, w, h, rnd),
        "build_66": rising(done, 0.67, size, pivot, w, h, rnd),
        "done": done,
        "damaged_1": soot(done.copy(), 5, 0.55, 6, rnd),
        "damaged_2": broken(soot(done.copy(), 10, 0.45, 14, rnd), rnd),
    }
    rub = Image.new("RGBA", size)
    if rub_raw.exists():
        r = clean(Image.open(rub_raw))
        scale = min(1.0, foot_w * 0.9 / r.width)
        if scale < 1.0:
            r = r.resize((max(1, int(r.width * scale)), max(1, int(r.height * scale))), Image.NEAREST)
        rub.alpha_composite(r, (int(pivot[0] - r.width / 2), int(pivot[1] - r.height * 0.6)))
    views["rubble"] = rub
    for stage, im in views.items():
        save_view(out / "buildings", f"{uid}_{stage}_", im, by, faction)
    meta = {"size": list(size), "pivot": list(pivot), "scale": 1.0, "pivot_is": "centre of the footprint",
            "cells": [w, h], "stages": STAGES, "source": "retro diffusion, tools/art/pixel_iso.py"}
    (out / "buildings" / f"{uid}.json").write_text(json.dumps(meta, indent=1))


def tree(src: Path, out: Path, uid: str, raw_name: str) -> None:
    raw = src / "trees" / raw_name
    if not raw.exists():
        print("missing", raw)
        return
    im = clean(Image.open(raw))
    im = pad_canvas(im, 2, 2, 60, 12)
    bx, by = foot_of(im)
    save_view(out / "trees", f"{uid}_", im, by, None)
    meta = {"size": list(im.size), "pivot": [bx, by - 4], "scale": 1.0, "pivot_is": "foot of the trunk",
            "cells": 1, "source": "retro diffusion, tools/art/pixel_iso.py"}
    (out / "trees" / f"{uid}.json").write_text(json.dumps(meta, indent=1))


def shrink(im: Image.Image, k: int) -> Image.Image:
    """Shrink by k with the most common opaque colour of each k x k block (keeps a pixel-art
    look; plain nearest drops details)."""
    a = np.array(im)
    h, w = a.shape[0] // k, a.shape[1] // k
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            blk = a[y * k:(y + 1) * k, x * k:(x + 1) * k].reshape(-1, 4)
            op = blk[blk[:, 3] > 0]
            if len(op) * 2 < len(blk):
                continue
            vals, counts = np.unique(op[:, :3], axis=0, return_counts=True)
            out[y, x, :3] = vals[counts.argmax()]
            out[y, x, 3] = 255
    return Image.fromarray(out, "RGBA")


## Decal id -> (shrink factor, which ground it grows on).
DECALS = {
    "d_flowers_yellow": (4, "grass"), "d_flowers_white": (4, "grass"), "d_flowers_blue": (4, "grass"),
    "d_stone_grey": (4, "any"), "d_stones_small": (4, "any"), "d_tussock": (4, "grass"),
    "d_sedge": (3, "bog"), "d_mushrooms": (4, "forest"), "d_stump": (3, "forest"),
    "d_bush": (3, "grass"), "d_reeds": (3, "bog"), "d_puddle": (3, "bog"), "d_fern": (3, "forest"),
    "d_deadwood": (3, "forest"),
}


def decals(src: Path, out: Path) -> None:
    """All decals in one atlas (art/sprites/decals/decals.png) + JSON of rects and pivots."""
    items = []
    for did, (k, ground) in DECALS.items():
        raw = src / "decals" / PICK.get(did, f"{did}_1.png")
        if not raw.exists():
            print("missing", raw)
            continue
        im = clean(shrink(clean(Image.open(raw)), k))
        items.append((did, ground, im))
    if not items:
        return
    gap = 2
    width = sum(i[2].width + gap for i in items)
    height = max(i[2].height for i in items)
    atlas = Image.new("RGBA", (width, height))
    meta, x = {}, 0
    for did, ground, im in items:
        atlas.alpha_composite(im, (x, 0))
        meta[did] = {"rect": [x, 0, im.width, im.height], "pivot": [im.width // 2, im.height - 1],
                     "ground": ground}
        x += im.width + gap
    (out / "decals").mkdir(parents=True, exist_ok=True)
    atlas.save(out / "decals" / "decals.png", optimize=True)
    (out / "decals" / "decals.json").write_text(json.dumps(meta, indent=1))


def palisade(src: Path, out: Path, uid: str = "gdl_palisade") -> None:
    """Post and arms of a palisade cell, cut from a generated straight palisade three cells
    long that runs along x (screen: upper left to lower right). The post is the stakes by the
    middle; the arm toward +x (e) the next half cell down-right, toward -x (w) up-left; the arms
    along y (s toward +y, n toward -y) are their mirror images. All pieces share one canvas and
    pivot (the middle of the cell on the ground), as BuildingLayer stacks them."""
    raw = src / "buildings" / PICK.get(uid, f"{uid}_1.png")
    if not raw.exists():
        print("missing", raw)
        return
    line = clean(Image.open(raw))
    a = np.array(line)
    cx = line.width // 2
    col = np.nonzero(a[:, cx - 1: cx + 2, 3].any(1))[0]
    gy = int(col[-1])  # foot of the middle stakes
    half = 16  # half a cell along x on screen

    def cut(x0: int, x1: int) -> Image.Image:
        b = a.copy()
        b[:, : max(0, x0)] = 0
        b[:, x1:] = 0
        return Image.fromarray(b, "RGBA")

    pieces = {"": cut(cx - 5, cx + 5), "e": cut(cx + 5, cx + half + 2), "w": cut(cx - half - 2, cx - 5)}
    # One canvas centred on the pivot, wide enough for any arm and its shadow.
    W, H = 2 * half + 65, line.height + 24  # odd width: a mirror keeps the pivot column
    px, py = (W - 1) // 2, line.height + 4
    ox, oy = px - cx, py - gy
    canv = {}
    for k, im in pieces.items():
        c = Image.new("RGBA", (W, H))
        c.alpha_composite(im.crop((max(0, -ox), max(0, -oy), line.width, line.height)), (max(0, ox), max(0, oy)))
        canv[k] = c
    canv["s"] = canv["e"].transpose(Image.FLIP_LEFT_RIGHT)
    canv["n"] = canv["w"].transpose(Image.FLIP_LEFT_RIGHT)
    rnd = random.Random(uid)
    for k, im in canv.items():
        pid = uid if k == "" else f"{uid}_{k}"
        views = {
            "found": Image.new("RGBA", (W, H)),
            "build_33": rising(im, 0.34, (W, H), (px, py), 1, 1, rnd) if k == "" else Image.new("RGBA", (W, H)),
            "build_66": rising(im, 0.67, (W, H), (px, py), 1, 1, rnd) if k == "" else cut_low(im, 0.67),
            "done": im,
            "damaged_1": soot(im.copy(), 1, 0.55, 2, rnd),
            "damaged_2": soot(im.copy(), 2, 0.45, 5, rnd),
            "rubble": Image.new("RGBA", (W, H)),
        }
        if k == "":
            views["found"] = found((W, H), (px, py), 1, 1, rnd)
        for stage, v in views.items():
            save_view(out / "buildings", f"{pid}_{stage}_", v, py, "gdl")
        meta = {"size": [W, H], "pivot": [px, py], "scale": 1.0, "pivot_is": "centre of the footprint",
                "cells": [1, 1], "stages": STAGES, "source": "retro diffusion, tools/art/pixel_iso.py"}
        (out / "buildings" / f"{pid}.json").write_text(json.dumps(meta, indent=1))


def cut_low(im: Image.Image, frac: float) -> Image.Image:
    a = np.array(im)
    rows = np.nonzero(a[..., 3].any(1))[0]
    if len(rows):
        a[: int(rows[-1] - (rows[-1] - rows[0]) * frac)] = 0
    return Image.fromarray(a, "RGBA")


TREES = {"nt_pine": "nt_pine_1.png", "nt_pine_2": "nt_pine_2.png", "nt_birch": "nt_birch_1.png",
         "nt_birch_2": "nt_birch_2.png", "nt_spruce": "nt_spruce_1.png", "nt_oak": "nt_oak_1.png"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="art_src/pixel_iso/full")
    ap.add_argument("--out", default="art/sprites")
    ap.add_argument("--only", nargs="*")
    a = ap.parse_args()
    src, out = Path(a.src), Path(a.out)
    picks = src / "picks.json"
    if picks.exists():
        PICK.update(json.loads(picks.read_text()))
    for sub in ("buildings", "trees"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    for uid, (w, h, fac, rub) in BUILD.items():
        if not a.only or uid in a.only:
            building(src, out, uid, w, h, fac, rub)
    for uid, base in MIRRORS.items():
        w, h, fac, rub = BUILD[base]
        if not a.only or uid in a.only:
            building(src, out, uid, h, w, fac, rub, mirror=True, raw_id=base)
    if not a.only or "gdl_palisade" in a.only:
        palisade(src, out)
    for uid, raw in TREES.items():
        if not a.only or uid in a.only:
            tree(src, out, uid, PICK.get(uid, raw))
    decals(src, out)


if __name__ == "__main__":
    main()
