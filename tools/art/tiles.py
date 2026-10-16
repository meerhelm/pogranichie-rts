"""Ground tiles for every terrain of the catalog (visual assets doc, «Путь 2D»: a seamless
top-down texture, turned 45° and squashed in half). Each terrain gets a texture that repeats
every PERIOD cells; cutting it per cell gives PERIOD x PERIOD diamond variants that join without
seams when the map uses variant (x % PERIOD, y % PERIOD).

    python3 -m tools.art.tiles [--out art/tiles]

Writes art/tiles/<terrain id>.png: a PERIOD x PERIOD grid of tiles (column = x % 4,
row = y % 4), each a 64x32 diamond with a PAD-pixel fading rim (96x48 in all).
"""

import argparse
import os

import numpy as np
from PIL import Image

PERIOD = 4
CELL_PX = 48  # texture pixels per cell side, top-down
TEX = PERIOD * CELL_PX
TILE_W, TILE_H = 64, 32
## Each tile reaches this far beyond its diamond (pixels each side, horizontally; half
## vertically) with a ragged fading edge, so neighbouring terrains blend instead of meeting
## in a zigzag. Same-terrain neighbours overlap with identical pixels.
PAD = 16
FEATHER = 0.32  # cells beyond the edge where the fade ends


# --- periodic noise --------------------------------------------------------------------------

def noise(seed, beta=2.0, size=TEX, low=1.0):
    """Periodic fractal noise in 0..1 (white noise shaped by 1/f^beta in the frequency domain,
    so it tiles exactly). `low` damps the lowest frequencies (bigger = finer)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx**2 + fy**2)
    r[0, 0] = 1.0
    spec = np.fft.fft2(white) / (r ** (beta / 2.0))
    spec *= 1.0 - np.exp(-((r * size / low) ** 2))
    spec[0, 0] = 0
    out = np.real(np.fft.ifft2(spec))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def col(hex_color):
    h = hex_color.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def specks(seed, density, size=TEX):
    """Sparse dots (periodic by construction)."""
    rng = np.random.default_rng(seed)
    return (rng.random((size, size)) < density).astype(float)


def blur(a, passes=1):
    for _ in range(passes):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5
    return a


def strokes(seed, count, length, size=TEX):
    """Short blades/needles: random short lines, wrapped around the edges."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        x, y = rng.integers(0, size, 2)
        a = rng.uniform(0, np.pi)
        dx, dy = np.cos(a), np.sin(a)
        for t in range(length):
            out[int(y + dy * t) % size, int(x + dx * t) % size] = 1.0
    return out


def coord():
    y, x = np.mgrid[0:TEX, 0:TEX].astype(float)
    return x, y


def shade(rgb, light):
    return np.clip(rgb * light[..., None], 0, 255)


# --- terrains ----------------------------------------------------------------------------

def t_grass(seed=1):
    n = noise(seed)
    fine = noise(seed + 1, beta=1.0)
    rgb = mix(col("#4f6b31"), col("#78913f"), n)
    rgb = mix(rgb, col("#435c29"), blur((fine > 0.6) * 1.0, 1) * 0.6)
    blades = strokes(seed + 2, 900, 3)
    rgb = mix(rgb, col("#93ad55"), blades * 0.45)
    rgb = mix(rgb, col("#3f5726"), strokes(seed + 3, 600, 2) * 0.4)
    flowers = specks(seed + 4, 0.0016)
    rgb = mix(rgb, col("#e8dc8a"), flowers)
    return shade(rgb, 0.92 + 0.16 * noise(seed + 5))


def t_field(seed=2):
    x, y = coord()
    furrow = 0.5 + 0.5 * np.sin(y / TEX * 2 * np.pi * 16 + noise(seed, beta=2.5) * 3.0)
    soil = mix(col("#6e5636"), col("#9a7a4c"), noise(seed + 1))
    rgb = mix(soil * 0.88, soil * 1.06, furrow)
    stubble = strokes(seed + 2, 700, 3) * (furrow > 0.5)
    rgb = mix(rgb, col("#c9ac62"), stubble * 0.8)
    return shade(rgb, 0.94 + 0.12 * noise(seed + 3))


def _forest_floor(seed, base, moss, dark):
    n = noise(seed)
    rgb = mix(col(base), col(moss), blur(noise(seed + 1, beta=2.4), 1) > 0.55)
    rgb = mix(rgb, col(dark), n * 0.5)
    needles = strokes(seed + 2, 1600, 3)
    rgb = mix(rgb, col("#8a6a3a"), needles * 0.35)
    rgb = mix(rgb, col("#20301a"), specks(seed + 3, 0.01) * 0.6)
    return shade(rgb, 0.85 + 0.2 * noise(seed + 4))


def t_forest(seed=3):
    return _forest_floor(seed, "#3e5128", "#4d6a2c", "#2a3a1c")


def t_old_forest(seed=4):
    return _forest_floor(seed, "#2c3d22", "#3d5a2a", "#1a2614")


def t_bog(seed=5):
    n = noise(seed)
    pools = blur(noise(seed + 1, beta=2.6), 2)
    rgb = mix(col("#5f6a3a"), col("#7a7f45"), n)
    rgb = mix(rgb, col("#8f8a4a"), strokes(seed + 2, 900, 3) * 0.5)  # sedge
    water = pools > 0.6
    rgb = mix(rgb, col("#33443e"), water * 0.85)
    rgb = mix(rgb, col("#6b8a8a"), (pools > 0.68) * 0.35)  # sky in the water
    rgb = mix(rgb, col("#3b3a22"), ((pools > 0.56) & ~water) * 0.6)  # wet rim
    return shade(rgb, 0.9 + 0.15 * noise(seed + 3))


def t_quagmire(seed=6):
    n = noise(seed)
    pools = blur(noise(seed + 1, beta=2.4), 2)
    rgb = mix(col("#3c3626"), col("#544a32"), n)
    rgb = mix(rgb, col("#232a26"), (pools > 0.5) * 0.85)
    rgb = mix(rgb, col("#4c5d58"), (pools > 0.62) * 0.3)
    rgb = mix(rgb, col("#6b6a3a"), strokes(seed + 2, 300, 3) * 0.5)
    return shade(rgb, 0.9 + 0.15 * noise(seed + 3))


def _water(seed, deep, light, ripple_k):
    x, y = coord()
    warp = noise(seed, beta=2.2) * 6.0
    rip = 0.5 + 0.5 * np.sin((x * 0.5 + y) / TEX * 2 * np.pi * ripple_k + warp)
    rgb = mix(col(deep), col(light), noise(seed + 1) * 0.6 + 0.2)
    rgb = mix(rgb, rgb * 1.18, (rip > 0.93) * 0.8)
    return rgb


def t_water(seed=7):
    return _water(seed, "#1f3d5c", "#2f5878", 10)


def t_ford(seed=8):
    stones = blur(noise(seed + 2, beta=1.2, low=6.0), 1)
    rgb = _water(seed, "#3f6670", "#5d8a88", 12)
    pebbles = stones > 0.66
    rgb = mix(rgb, col("#8c8a7a"), pebbles * 0.75)
    rgb = mix(rgb, col("#b8b4a0"), (stones > 0.75) * 0.6)
    return rgb


def t_ice(seed=9):
    n = noise(seed)
    ridge = 1.0 - np.abs(noise(seed + 1, beta=1.8) * 2 - 1)
    rgb = mix(col("#b9cfd9"), col("#e2edf1"), n)
    rgb = mix(rgb, col("#8aa6b4"), (ridge > 0.93) * 0.9)
    rgb = mix(rgb, col("#ffffff"), specks(seed + 2, 0.004) * 0.7)
    return rgb


def t_road(seed=10):
    n = noise(seed)
    rgb = mix(col("#7d6546"), col("#9a8058"), n)
    rgb = mix(rgb, col("#5f4c34"), blur(noise(seed + 1, beta=1.5), 1) > 0.65)
    rgb = mix(rgb, col("#b0a080"), specks(seed + 2, 0.006))
    rgb = mix(rgb, col("#4a3a26"), specks(seed + 3, 0.004))
    return shade(rgb, 0.92 + 0.12 * noise(seed + 4))


def t_hill(seed=11):
    rgb = t_grass(seed + 20)
    rgb = mix(rgb, col("#8c9a52"), noise(seed) * 0.35)  # drier grass
    rocks = blur(noise(seed + 1, beta=1.6, low=3.0), 1)
    stone = mix(col("#7a776c"), col("#a29e90"), noise(seed + 2))
    rgb = mix(rgb, stone, (rocks > 0.64) * 0.95)
    rgb = mix(rgb, col("#55524a"), ((rocks > 0.61) & (rocks <= 0.64)) * 0.7)
    return rgb


def t_sand(seed=12):
    x, y = coord()
    rip = 0.5 + 0.5 * np.sin((x + y * 0.3) / TEX * 2 * np.pi * 14 + noise(seed, beta=2.4) * 4)
    rgb = mix(col("#c8b383"), col("#ddc999"), noise(seed + 1))
    rgb = mix(rgb, rgb * 0.9, (rip > 0.7) * 0.6)
    rgb = mix(rgb, col("#8a7a5a"), specks(seed + 2, 0.004))
    return rgb


def t_ash(seed=13):
    n = noise(seed)
    rgb = mix(col("#3c3936"), col("#5e5a55"), n)
    rgb = mix(rgb, col("#1c1a18"), (blur(noise(seed + 1, beta=1.8), 1) > 0.66) * 0.8)
    rgb = mix(rgb, col("#c8692a"), specks(seed + 2, 0.0015))  # embers
    rgb = mix(rgb, col("#2a2018"), strokes(seed + 3, 250, 4) * 0.7)  # charred sticks
    return rgb


TERRAINS = {
    "t_grass": t_grass, "t_field": t_field, "t_forest": t_forest, "t_old_forest": t_old_forest,
    "t_bog": t_bog, "t_quagmire": t_quagmire, "t_ford": t_ford, "t_water": t_water,
    "t_ice": t_ice, "t_road": t_road, "t_hill": t_hill, "t_sand": t_sand, "t_ash": t_ash,
}


# --- projection --------------------------------------------------------------------------

def diamonds(tex: np.ndarray, ragged: np.ndarray) -> Image.Image:
    """Cuts the top-down texture into PERIOD x PERIOD isometric tiles, as an atlas whose
    column is the cell x and row the cell y within the period. A tile is its 64x32 diamond,
    opaque, plus PAD pixels around it fading out along `ragged` (periodic noise, so the fade
    of one tile matches its neighbours'). Bilinear sampling, 4x4 supersampling."""
    tw, th = TILE_W + 2 * PAD, TILE_H + PAD
    atlas = np.zeros((PERIOD * th, PERIOD * tw, 4))
    ss = 4
    sub = (np.arange(ss) + 0.5) / ss
    py, px = np.mgrid[0:th, 0:tw].astype(float)
    for cy in range(PERIOD):
        for cx in range(PERIOD):
            acc = np.zeros((th, tw, 3))
            cover = np.zeros((th, tw))
            for oy in sub:
                for ox in sub:
                    # Screen point relative to the cell's top corner -> cell units (Iso).
                    sx = (px + ox - PAD - TILE_W / 2) / (TILE_W / 2)
                    sy = (py + oy - PAD / 2) / (TILE_H / 2)
                    u = (sx + sy) / 2
                    v = (sy - sx) / 2
                    tx = ((cx + u) * CELL_PX) % TEX
                    ty = ((cy + v) * CELL_PX) % TEX
                    acc += _bilinear(tex, tx, ty)
                    out = np.maximum.reduce([-u, u - 1, -v, v - 1, np.zeros_like(u)])
                    jag = _bilinear(ragged[..., None], tx, ty)[..., 0]
                    cover += np.clip(1.0 - out / FEATHER + (jag - 0.5) * 1.6 * (out > 0), 0, 1)
            # Inside the diamond every pixel is opaque, so same-terrain neighbours join with
            # identical pixels; outside it the fade lets the next terrain show through.
            rgb = acc / (ss * ss)
            alpha = np.clip(cover / (ss * ss), 0, 1) * 255.0
            tile = np.dstack([rgb, alpha])
            atlas[cy * th:(cy + 1) * th, cx * tw:(cx + 1) * tw] = tile
    return Image.fromarray(np.clip(atlas, 0, 255).astype(np.uint8), "RGBA")


def _bilinear(tex, x, y):
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    x1 = (x0 + 1) % TEX
    y1 = (y0 + 1) % TEX
    x0 %= TEX
    y0 %= TEX
    a = tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx
    b = tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx
    return a * (1 - fy) + b * fy


def preview(out_dir: str, ids: list[str]) -> None:
    """Each terrain as an 8x8 patch of the map, side by side."""
    n = 8
    w, h = n * TILE_W, n * TILE_H
    sheet = Image.new("RGBA", (w * 4 + 30, (h + 10) * ((len(ids) + 3) // 4)), (30, 30, 30, 255))
    for i, tid in enumerate(ids):
        atlas = Image.open(os.path.join(out_dir, tid + ".png"))
        patch = Image.new("RGBA", (w, h))
        tw, th = TILE_W + 2 * PAD, TILE_H + PAD
        for y in range(n):
            for x in range(n):
                tile = atlas.crop(((x % PERIOD) * tw, (y % PERIOD) * th,
                                   (x % PERIOD + 1) * tw, (y % PERIOD + 1) * th))
                sx = (x - y) * TILE_W // 2 + w // 2 - TILE_W // 2 - PAD
                sy = (x + y) * TILE_H // 2 - PAD // 2
                if sx >= 0 and sy >= 0 and sx + tw <= w and sy + th <= h:
                    patch.alpha_composite(tile, (sx, sy))
        sheet.alpha_composite(patch, ((i % 4) * (w + 10), (i // 4) * (h + 10)))
    sheet.save(os.path.join(out_dir, "preview.png"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="art/tiles")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for i, (tid, make) in enumerate(TERRAINS.items()):
        diamonds(make(), noise(100 + i, beta=1.6)).save(os.path.join(args.out, tid + ".png"), optimize=True)
    print("tiles written to", args.out)


if __name__ == "__main__":
    main()
