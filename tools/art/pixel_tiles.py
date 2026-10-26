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

## Cells per repeat of the ground texture (MapView.PERIOD): each atlas holds PERIOD x PERIOD
## tiles. 8 rather than the procedural tiles' 4, so the variants mixed into a texture (see
## VARIANTS) make patches a few cells across before anything repeats.
PERIOD = 8
CELL_PX = 32  # texture pixels per cell side, top-down
TEX = PERIOD * CELL_PX
BLOCK = 4  # cells per side of a redrawn iso block (see unproject())
TILE_W, TILE_H, PAD = proc.TILE_W, proc.TILE_H, proc.PAD
FEATHER = 0.30

## Per terrain: the textures mixed into it (file names in --src, those missing are skipped)
## and each one's share of the ground. A 32 px fill covers one cell, a 128 px texture a 4x4
## block (a redrawn iso block turned back to top-down, see unproject()), a 256 px one the period. They are laid out in
## patches by periodic noise, the borders dithered.
VARIANTS = {
    "t_grass": [("fill_grass_1.png", 0.40), ("tex_grass_lush.png", 0.25), ("tex_grass_dry.png", 0.17),
                ("tex_grass_meadow.png", 0.18)],
    "t_field": [("tex_field.png", 1.0)],
    "t_forest": [("tex_forest_floor.png", 0.6), ("fill_forest_floor_2.png", 0.4)],
    "t_old_forest": [("fill_old_forest_1.png", 0.55), ("fill_old_forest_2.png", 0.45)],
    "t_bog": [("tex_bog.png", 0.6), ("fill_bog_2.png", 0.4)],
    "t_quagmire": [("tex_quagmire.png", 1.0)],
    "t_water": [("fill_water_proc256.png", 1.0)],
    "t_road": [("fill_road_1.png", 0.6), ("fill_road_2.png", 0.4)],
    "t_hill": [("fill_hill_1.png", 0.6), ("fill_hill_2.png", 0.4)],
    "t_sand": [("fill_sand_1.png", 0.6), ("fill_sand_2.png", 0.4)],
}
## A terrain whose files are all missing falls back to its first plain fill, then to tiles.py.
FALLBACK = {"t_grass": "fill_grass_1.png", "t_quagmire": "fill_quagmire_1.png"}

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


def _load(path: str) -> np.ndarray:
    """A texture file as a TEX x TEX periodic texture."""
    t = np.array(Image.open(path).convert("RGB"), dtype=float)
    if t.shape[0] not in (CELL_PX, BLOCK * CELL_PX, TEX):
        t = np.array(Image.fromarray(t.astype(np.uint8)).resize((CELL_PX, CELL_PX), Image.NEAREST), dtype=float)
    k = TEX // t.shape[0]
    return np.tile(t, (k, k, 1))


def _mix(texs: list[np.ndarray], shares: list[float], seed: int) -> np.ndarray:
    """Lays the textures out in patches: periodic noise split at the shares' quantiles, the
    borders jittered by an ordered dither."""
    if len(texs) == 1:
        return texs[0]
    n = proc.noise(seed, beta=2.6, size=TEX, low=1.5)
    n = n + (np.tile(BAYER4, (TEX // 4, TEX // 4)) - 0.5) * 0.08
    cuts = np.quantile(n, np.cumsum(shares)[:-1] / sum(shares))
    pick = np.searchsorted(cuts, n)
    out = np.zeros_like(texs[0])
    for i, t in enumerate(texs):
        out[pick == i] = t[pick == i]
    return out


def texture(tid: str, src: str, pal: np.ndarray, seed: int = 0) -> np.ndarray:
    """TEX x TEX top-down texture of the terrain, periodic."""
    texs, shares = [], []
    for name, share in VARIANTS.get(tid, []):
        p = os.path.join(src, name)
        if os.path.exists(p):
            texs.append(_load(p))
            shares.append(share)
    if not texs and os.path.exists(os.path.join(src, FALLBACK.get(tid, "-"))):
        texs, shares = [_load(os.path.join(src, FALLBACK[tid]))], [1.0]
    if texs:
        return _mix(texs, shares, 300 + seed)
    # Procedural fallback: shrink to the pixel grid, repeat over the period.
    big = proc.TERRAINS[tid]()
    small = np.array(Image.fromarray(np.clip(big, 0, 255).astype(np.uint8)).resize(
        (BLOCK * CELL_PX, BLOCK * CELL_PX), Image.BOX), dtype=float)
    k = TEX // small.shape[0]
    return snap(np.tile(small, (k, k, 1)), pal)


def unproject(iso: np.ndarray) -> np.ndarray:
    """A 4x4-cell block drawn in isometry (256x128, its big diamond touching the edges: the
    fill mapped into it and redrawn by Retro Diffusion img2img) back to the 128x128 top-down
    texture, pixel for pixel (the inverse of the exact mapping used in diamonds())."""
    h, w = BLOCK * TILE_H, BLOCK * TILE_W
    py, px = np.mgrid[0:h, 0:w].astype(float)
    sx = (px + 0.25 - w / 2) / (TILE_W / 2)
    sy = (py + 0.25) / (TILE_H / 2)
    u = (sx + sy) / 2
    v = (sy - sx) / 2
    inside = (u >= 0) & (u < BLOCK) & (v >= 0) & (v < BLOCK)
    tx = np.floor(u * CELL_PX).astype(int)[inside]
    ty = np.floor(v * CELL_PX).astype(int)[inside]
    n = BLOCK * CELL_PX
    out = np.zeros((n, n, 3))
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
            jag = ragged[ty, tx]
            cover = np.clip(1.0 - out / FEATHER + (jag - 0.5) * 1.2 * (out > 0), 0, 1)
            thr = BAYER4[ty % 4, tx % 4]
            alpha = np.where((out <= 0) | (cover > thr), 255.0, 0.0)
            alpha[out > FEATHER * 1.6] = 0
            atlas[cy * th:(cy + 1) * th, cx * tw:(cx + 1) * tw] = np.dstack([rgb, alpha])
    rgb = snap(atlas[..., :3], pal)
    atlas[..., :3] = rgb
    atlas[atlas[..., 3] == 0, :3] = 0
    return Image.fromarray(atlas.astype(np.uint8), "RGBA")


## Worn ground by buildings and along paths (WearLayer): bare earth over the terrain, at three
## levels of cover. Same tile layout as a terrain atlas.
WEAR_COVER = (0.30, 0.58, 0.86)
WEAR_SOURCE = "fill_road_1.png"


def wear(dirt: np.ndarray, patches: np.ndarray, cover: float, pal: np.ndarray) -> Image.Image:
    """Bare earth tiles, opaque where the patch noise is under `cover` (dithered), fading out
    past the cell edge like the terrain rim, so worn cells merge into one trodden patch."""
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
            thr = BAYER4[ty % 4, tx % 4]
            level = cover - out * 1.4 - patches[ty, tx] + 0.5
            alpha = np.where(level > thr, 255.0, 0.0)
            alpha[out > 0.45] = 0
            atlas[cy * th:(cy + 1) * th, cx * tw:(cx + 1) * tw] = np.dstack([dirt[ty, tx], alpha])
    atlas[..., :3] = snap(atlas[..., :3], pal)
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
        tex = texture(tid, args.src, pal, i)
        diamonds(tex, proc.noise(100 + i, beta=1.6, size=TEX), pal).save(os.path.join(args.out, tid + ".png"), optimize=True)
    dirt = _load(os.path.join(args.src, WEAR_SOURCE)) * 0.92
    patches = proc.noise(400, beta=1.8, size=TEX)
    for i, cover in enumerate(WEAR_COVER):
        wear(dirt, patches, cover, pal).save(os.path.join(args.out, "wear_%d.png" % (i + 1)), optimize=True)
    if args.preview:
        proc.preview(args.out, list(proc.TERRAINS))
    print("pixel tiles written to", args.out)


if __name__ == "__main__":
    main()
