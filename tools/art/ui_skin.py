"""Generates the interface skin (ui/skin/*.png): dark oak panels with an old-bronze rim,
wooden buttons, parchment for tooltips and hints. Procedural (numpy noise), so it can be
re-tuned and regenerated: `python3 -m tools.art.ui_skin`.

Every texture is a nine-patch: the rim lives in the outer MARGIN pixels, the middle tiles.
"""

import os

import numpy as np
from PIL import Image, ImageFilter

OUT = "ui/skin"
MARGIN = 12


def _noise(w, h, scale_x, scale_y, seed, octaves=4):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gx = max(2, int(w / scale_x * 2**o))
        gy = max(2, int(h / scale_y * 2**o))
        grid = rng.random((gy + 1, gx + 1))
        # Tile seamlessly: wrap the last row and column.
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, dtype=float) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def wood(w, h, base, seed, grain=0.22):
    """Wood with long horizontal grain and a few darker streaks."""
    n = _noise(w, h, 64, 3, seed)
    streak = _noise(w, h, 128, 1.5, seed + 7, octaves=2)
    v = 1.0 + grain * (n - 0.5) * 2 - 0.12 * (streak > 0.62)
    rgb = np.clip(np.array(base, dtype=float)[None, None, :] * v[..., None], 0, 255)
    return rgb


def parchment(w, h, seed):
    n = _noise(w, h, 40, 40, seed)
    fine = _noise(w, h, 6, 6, seed + 3, octaves=2)
    v = 1.0 + 0.10 * (n - 0.5) * 2 + 0.05 * (fine - 0.5)
    base = np.array([233, 220, 188], dtype=float)
    return np.clip(base[None, None, :] * v[..., None], 0, 255)


def rim(rgb, outer, metal, inner, width=3, rivets=True):
    """Dark outer line, a bronze band with a highlight on top/left, a dark inner line."""
    h, w, _ = rgb.shape
    out = rgb.copy()

    def frame(d, color):
        out[d, d:w - d] = color
        out[h - 1 - d, d:w - d] = color
        out[d:h - d, d] = color
        out[d:h - d, w - 1 - d] = color

    frame(0, outer)
    for d in range(1, 1 + width):
        shade = 1.15 - 0.1 * (d - 1)
        frame(d, np.clip(np.array(metal) * shade, 0, 255))
    # Light from the top left: brighter top and left of the band, darker bottom and right.
    hi = np.clip(np.array(metal) * 1.35, 0, 255)
    lo = np.array(metal) * 0.7
    out[1, 1:w - 1] = hi
    out[1:h - 1, 1] = hi
    out[h - 2, 1:w - 1] = lo
    out[1:h - 1, w - 2] = lo
    frame(1 + width, inner)
    if rivets:
        for cx, cy in ((5, 5), (w - 6, 5), (5, h - 6), (w - 6, h - 6)):
            for y in range(cy - 2, cy + 3):
                for x in range(cx - 2, cx + 3):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= 5:
                        lit = 1.5 if (x - cx) + (y - cy) < 0 else 0.8
                        out[y, x] = np.clip(np.array(metal) * lit, 0, 255)
    return out


def vignette(rgb, strength):
    h, w, _ = rgb.shape
    y, x = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)) / (MARGIN * 1.5)
    k = 1.0 - strength * np.clip(1.0 - d, 0, 1)
    return rgb * k[..., None]


def save(name, rgb, alpha=None):
    os.makedirs(OUT, exist_ok=True)
    a = np.full(rgb.shape[:2], 255, dtype=np.uint8) if alpha is None else alpha
    img = Image.fromarray(np.dstack([rgb.astype(np.uint8), a]), "RGBA")
    img.save(os.path.join(OUT, name + ".png"), optimize=True)


BRONZE = (168, 131, 74)
GOLD = (222, 184, 104)
DARK = (22, 16, 11)


def main():
    # Panels: dark oak boards.
    p = wood(128, 128, (52, 38, 27), 1)
    save("panel", rim(vignette(p, 0.35), DARK, BRONZE, (30, 22, 15)))
    # The HUD bars: a slimmer rim without rivets.
    bar = wood(128, 64, (44, 32, 23), 2)
    save("bar", rim(vignette(bar, 0.25), DARK, BRONZE, (26, 19, 13), width=2, rivets=False))
    # Buttons.
    btn = wood(96, 48, (92, 68, 46), 3, grain=0.18)
    grad = np.linspace(1.12, 0.86, 48)[:, None, None]
    save("button", rim(btn * grad, DARK, BRONZE, (40, 29, 20), width=2, rivets=False))
    save("button_hover", rim(np.clip(btn * grad * 1.14, 0, 255), DARK, GOLD, (52, 38, 26), width=2, rivets=False))
    save("button_pressed", rim(btn * grad[::-1] * 0.78, DARK, (130, 100, 58), (30, 22, 15), width=2, rivets=False))
    grey = btn.mean(axis=2, keepdims=True).repeat(3, axis=2) * 0.75
    save("button_disabled", rim(grey * grad, DARK, (100, 92, 80), (40, 36, 32), width=2, rivets=False))
    # Focus: only a gold rim, transparent inside.
    f = np.zeros((48, 96, 3))
    fr = rim(f, GOLD, GOLD, GOLD, width=1, rivets=False)
    a = np.zeros((48, 96), dtype=np.uint8)
    a[:3, :] = a[-3:, :] = 255
    a[:, :3] = a[:, -3:] = 255
    save("focus", fr, a)
    # Parchment: tooltips and the advisor's hints.
    save("parchment", rim(vignette(parchment(128, 128, 5), 0.25), DARK, (120, 88, 52), (150, 120, 80), width=2, rivets=False))
    # Inset well (minimap, lists): darker, sunk.
    well = wood(64, 64, (24, 18, 13), 6, grain=0.1)
    save("well", rim(well, (70, 54, 36), (14, 10, 7), (10, 7, 5), width=1, rivets=False))
    print("skin written to", OUT)


if __name__ == "__main__":
    main()
