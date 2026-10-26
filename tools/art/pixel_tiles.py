"""Pixel-art ground tiles for the isometric view, from seamless top-down pixel textures
(Retro Diffusion, 32 px per 2 m cell, 30-colour palette).

Same atlas layout as tools/art/tiles.py, so MapView needs no change: per terrain a
PERIOD x PERIOD grid of 96x48 tiles (64x32 diamond + PAD rim). Differences:
- nearest-neighbour sampling, no supersampling: pixels stay crisp;
- the rim is not a soft fade but an ordered dither (alpha is 0 or 255), the usual way pixel
  art blends two ground types;
- the result is snapped to the palette.
A terrain without a pixel texture uses the procedural one from tiles.py, shrunk to 32 px per
cell and snapped to the palette, so the whole map has one look.

    python3 -m tools.art.pixel_tiles --src art_src/pixel_iso/ground --palette art_src/pixel_iso/palette.png
"""

import argparse
import os

import numpy as np
from PIL import Image

from tools.art import tiles as proc

PERIOD = proc.PERIOD
CELL_PX = 32  # texture pixels per cell side, top-down
TEX = PERIOD * CELL_PX
TILE_W, TILE_H, PAD = proc.TILE_W, proc.TILE_H, proc.PAD
FEATHER = 0.30

## Source texture per terrain (file names in --src, first that exists wins).
SOURCES = {
    "t_grass": ["fill_grass_1.png"],
    "t_field": ["tex_field.png", "fill_field_1.png"],
    "t_forest": ["tex_forest_floor.png", "fill_forest_floor_1.png"],
    "t_old_forest": ["fill_old_forest_1.png"],
    "t_bog": ["tex_bog.png", "fill_bog_1.png"],
    "t_quagmire": ["fill_quagmire_1.png"],
    "t_water": ["fill_water_proc32.png", "fill_water_v2_1.png", "fill_water_1.png"],
    "t_road": ["fill_road_1.png"],
    "t_hill": ["fill_hill_1.png"],
    "t_sand": ["fill_sand_1.png"],
}

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


def load_palette(path: str) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    px = np.array(im).reshape(-1, 4)
    px = px[px[:, 3] > 0][:, :3]
    return np.unique(px, axis=0).astype(float)


def snap(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    flat = rgb.reshape(-1, 3)
    d = ((flat[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
    return pal[d.argmin(1)].reshape(rgb.shape)


def texture(tid: str, src: str, pal: np.ndarray) -> np.ndarray:
    """TEX x TEX top-down texture of the terrain, periodic."""
    for name in SOURCES.get(tid, []):
        p = os.path.join(src, name)
        if os.path.exists(p):
            t = np.array(Image.open(p).convert("RGB"), dtype=float)
            if t.shape[0] == TEX:  # a whole period (a redrawn 4x4 block, see unproject())
                return t
            if t.shape[0] != CELL_PX:
                t = np.array(Image.fromarray(t.astype(np.uint8)).resize((CELL_PX, CELL_PX), Image.NEAREST), dtype=float)
            return np.tile(t, (PERIOD, PERIOD, 1))
    # Procedural fallback: shrink to the pixel grid (box filter keeps it periodic).
    big = proc.TERRAINS[tid]()
    k = proc.TEX // TEX
    small = big[: TEX * k, : TEX * k].reshape(TEX, k, TEX, k, 3).mean((1, 3))
    return snap(small, pal)


def unproject(iso: np.ndarray) -> np.ndarray:
    """A 4x4-cell block drawn in isometry (256x128, its big diamond touching the edges: the
    fill mapped into it and redrawn by Retro Diffusion img2img) back to the TEX x TEX top-down
    texture, pixel for pixel (the inverse of the exact mapping used in diamonds())."""
    h, w = PERIOD * TILE_H, PERIOD * TILE_W
    py, px = np.mgrid[0:h, 0:w].astype(float)
    sx = (px + 0.25 - w / 2) / (TILE_W / 2)
    sy = (py + 0.25) / (TILE_H / 2)
    u = (sx + sy) / 2
    v = (sy - sx) / 2
    inside = (u >= 0) & (u < PERIOD) & (v >= 0) & (v < PERIOD)
    tx = np.floor(u * CELL_PX).astype(int)[inside]
    ty = np.floor(v * CELL_PX).astype(int)[inside]
    out = np.zeros((TEX, TEX, 3))
    out[ty, tx] = iso[inside][:, :3]
    return out


def heal_seams(tex: np.ndarray) -> np.ndarray:
    """Makes a texture whose wrap edges do not match periodic: near the edges its pixels are
    taken, by an ordered dither, from the copy shifted by half a period (whose own seam lies in
    the middle, where the original is kept)."""
    n = tex.shape[0]
    half = np.roll(np.roll(tex, n // 2, 0), n // 2, 1)
    i = np.arange(n)
    d = np.minimum(i, n - 1 - i) / (n / 2)  # 0 at the edges, 1 in the middle
    w = np.clip(np.minimum.outer(d, d) * 2.5, 0, 1)
    thr = np.tile(BAYER4, (n // 4, n // 4))
    return np.where((w > thr)[..., None], tex, half)


def diamonds(tex: np.ndarray, ragged: np.ndarray, pal: np.ndarray) -> Image.Image:
    tw, th = TILE_W + 2 * PAD, TILE_H + PAD
    atlas = np.zeros((PERIOD * th, PERIOD * tw, 4))
    py, px = np.mgrid[0:th, 0:tw].astype(float)
    sx = (px + 0.25 - PAD - TILE_W / 2) / (TILE_W / 2)
    sy = (py + 0.25 - PAD / 2) / (TILE_H / 2)
    u = (sx + sy) / 2
    v = (sy - sx) / 2
    out = np.maximum.reduce([-u, u - 1, -v, v - 1, np.zeros_like(u)])
    for cy in range(PERIOD):
        for cx in range(PERIOD):
            tx = (np.floor((cx + u) * CELL_PX) % TEX).astype(int)
            ty = (np.floor((cy + v) * CELL_PX) % TEX).astype(int)
            rgb = tex[ty, tx]
            # Dither threshold in texture space, so neighbours' rims interlock the same way.
            jag = ragged[ty * proc.TEX // TEX, tx * proc.TEX // TEX]
            cover = np.clip(1.0 - out / FEATHER + (jag - 0.5) * 1.2 * (out > 0), 0, 1)
            thr = BAYER4[ty % 4, tx % 4]
            alpha = np.where((out <= 0) | (cover > thr), 255.0, 0.0)
            alpha[out > FEATHER * 1.6] = 0
            atlas[cy * th:(cy + 1) * th, cx * tw:(cx + 1) * tw] = np.dstack([rgb, alpha])
    rgb = snap(atlas[..., :3], pal)
    atlas[..., :3] = rgb
    atlas[atlas[..., 3] == 0, :3] = 0
    return Image.fromarray(atlas.astype(np.uint8), "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="folder with fill_*.png textures")
    ap.add_argument("--palette", required=True)
    ap.add_argument("--out", default="art/tiles")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--unproject", nargs=2, metavar=("ISO_PNG", "OUT_PNG"),
                    help="turn a redrawn 256x128 iso block into a 128x128 texture and exit")
    args = ap.parse_args()
    pal = load_palette(args.palette)
    if args.unproject:
        iso = np.array(Image.open(args.unproject[0]).convert("RGB"), dtype=float)
        tex = heal_seams(snap(unproject(iso), pal))
        Image.fromarray(tex.astype(np.uint8)).save(args.unproject[1])
        return
    os.makedirs(args.out, exist_ok=True)
    for i, tid in enumerate(proc.TERRAINS):
        tex = texture(tid, args.src, pal)
        diamonds(tex, proc.noise(100 + i, beta=1.6), pal).save(os.path.join(args.out, tid + ".png"), optimize=True)
    if args.preview:
        proc.preview(args.out, list(proc.TERRAINS))
    print("pixel tiles written to", args.out)


if __name__ == "__main__":
    main()
