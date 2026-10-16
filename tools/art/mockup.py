"""A game-scale mock scene from rendered sprites (64x32 cells, sprites at half size), to
judge sizes and readability before wiring: `python3 -m tools.art.mockup <sprites> <out.png>`."""

import json
import os
import random
import sys

from PIL import Image

from tools.art.preview import compose, load

HALF_W, HALF_H = 32, 16
TEAM = {1: (217, 51, 38), 2: (51, 102, 230)}


def cell_to_screen(x: float, y: float) -> tuple[float, float]:
    return ((x - y) * HALF_W, (x + y) * HALF_H)


def half(img: Image.Image) -> Image.Image:
    return img.resize((img.width // 2, img.height // 2), Image.LANCZOS)


def main(src: str, out: str) -> None:
    w, h = 24, 24
    origin = (h * HALF_W + 20, 40)
    canvas = Image.new("RGBA", ((w + h) * HALF_W + 40, (w + h) * HALF_H + 80), (40, 50, 35, 255))
    rng = random.Random(4)
    tile = Image.new("RGBA", (64, 32))
    for ty in range(32):
        for tx in range(64):
            if abs(tx + 0.5 - 32) / 32 + abs(ty + 0.5 - 16) / 16 <= 1.0:
                tile.putpixel((tx, ty), (0, 0, 0, 255))
    forest = {(x, y) for x in range(15, 24) for y in range(0, 9) if (x - 15) + (8 - y) > 4}
    for y in range(h):
        for x in range(w):
            sx, sy = cell_to_screen(x, y)
            g = rng.randint(-6, 6)
            col = (36 + g, 82 + g, 40 + g) if (x, y) in forest else (100 + g, 136 + g, 70 + g)
            solid = Image.new("RGBA", (64, 32), col + (255,))
            canvas.paste(solid, (int(origin[0] + sx - 32), int(origin[1] + sy)), tile)

    items = []  # (sort y, image, top-left)

    def place(img, pivot, at_cell, scale_pivot=True):
        sx, sy = cell_to_screen(*at_cell)
        px, py = (pivot[0] / 2, pivot[1] / 2) if scale_pivot else pivot
        items.append((sy, img, (int(origin[0] + sx - px), int(origin[1] + sy - py))))

    def building(uid, cx, cy, player):
        meta = json.load(open(os.path.join(src, "buildings", uid + ".json")))
        img = half(compose(*load(os.path.join(src, "buildings", uid + "_")), TEAM[player], bg=(0, 0, 0)))
        img = _cut(img, load(os.path.join(src, "buildings", uid + "_")))
        place(img, meta["pivot"], (cx, cy))

    def tree(uid, cx, cy):
        meta = json.load(open(os.path.join(src, "trees", uid + ".json")))
        parts = load(os.path.join(src, "trees", uid + "_"))
        img = _cut(half(compose(*parts, TEAM[1], bg=(0, 0, 0))), parts)
        place(img, meta["pivot"], (cx, cy))

    def unit(uid, cx, cy, facing, player, frame=0, anim="idle"):
        d = os.path.join(src, "units", uid)
        meta = json.load(open(os.path.join(d, "sheet.json")))
        fw, fh = meta["frame"]
        row = meta["anims"][anim]["row"] + facing
        box = (frame * fw, row * fh, (frame + 1) * fw, (row + 1) * fh)
        parts = [p.crop(box) for p in load(d + "/")]
        img = _cut(half(compose(*parts, TEAM[player], bg=(0, 0, 0))), parts)
        place(img, meta["pivot"], (cx, cy))

    building("gdl_town_center", 8, 8, 1)
    building("gdl_house", 4, 13, 1)
    building("gdl_house", 13, 5, 1)
    building("gdl_house", 16, 19, 2)
    for (x, y) in sorted(forest):
        tree("nt_pine" if rng.random() < 0.65 else "nt_birch", x + 0.5 + rng.uniform(-0.2, 0.2),
             y + 0.5 + rng.uniform(-0.2, 0.2))
    for i, (x, y, f) in enumerate([(11.5, 11.2, 2), (12.3, 10.6, 1), (6.4, 12.0, 3), (14.4, 9.6, 0)]):
        unit("gdl_peasant", x, y, f, 1, frame=i * 3 % 12, anim="walk")
    for i in range(6):
        unit("gdl_spearman", 15.5 + (i % 3) * 0.8, 14.0 + (i // 3) * 0.8, 3, 1, frame=i)
    for i in range(3):
        unit("gdl_spearman", 19.0 + i * 0.8, 15.5 + i * 0.3, 5, 2, frame=i * 4, anim="walk")
    for _, img, at in sorted(items, key=lambda t: t[0]):
        canvas.alpha_composite(img, at)
    canvas.save(out)


def _cut(img: Image.Image, parts) -> Image.Image:
    """Alpha of shadow + colour, so the composited sprite drops its background."""
    a = Image.new("L", parts[0].size, 0)
    from PIL import ImageChops

    for p in parts:
        a = ImageChops.lighter(a, p.getchannel("A"))
    a = a.resize(img.size, Image.LANCZOS)
    img = img.copy()
    img.putalpha(a)
    return img


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
