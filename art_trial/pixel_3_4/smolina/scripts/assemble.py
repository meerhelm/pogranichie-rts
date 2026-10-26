"""Assemble map_sk_smolina from Retro Diffusion tiles on a dual grid."""
import json, random, sys, zlib
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts")
O = ROOT / ".rd-trial/smolina"
T = 32
MAP = ROOT / "maps/map_sk_smolina/terrain.txt"
CH = {".": "grass", ",": "field", "f": "forest", "F": "forest", "b": "bog", "B": "bog", "=": "water",
      "~": "water", "i": "water", "#": "road", "h": "hill", "s": "sand", "a": "grass",
      "o": "bog", "$": "hill", "%": "grass"}

# Layout of rd_tile__tileset_advanced (4 cols x 5 rows), corners TL,TR,BL,BR, 1 = inside.
LAYOUT = {(0, 0): "0000", (0, 1): "0001", (0, 2): "0011", (0, 3): "0010",
          (1, 0): "0000", (1, 1): "0101", (1, 2): "1111", (1, 3): "1010",
          (2, 0): "0000", (2, 1): "0100", (2, 2): "1100", (2, 3): "1000",
          (3, 0): "1111", (3, 1): "1110", (3, 2): "1101", (3, 3): "0110",
          (4, 0): "1111", (4, 1): "1011", (4, 2): "0111", (4, 3): "1001"}
# tileset name -> (outside terrain, inside terrain)
PAIRS = {"grass_forest": ("grass", "forest"), "grass_road": ("grass", "road"), "grass_bog": ("grass", "bog"),
         "grass_sand": ("grass", "sand"), "sand_water": ("sand", "water"), "grass_hill": ("grass", "hill"),
         "grass_water": ("grass", "water"), "grass_field": ("grass", "field")}


def h(*a):
    return zlib.crc32(repr(a).encode())


def mean(im, box):
    px = list(im.crop(box).convert("RGB").getdata())
    return [sum(p[i] for p in px) / len(px) for i in range(3)]


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b))


MASKED = {}
LAYERS = ["field", "road", "sand", "bog", "hill", "water", "forest"]
COVER = {"sand": {"sand", "water"}}  # a lake sits on its beach


def load_tileset(name):
    im = Image.open(O / f"ts_{name}.png").convert("RGBA")
    tiles, bad = {}, []
    outm = mean(im, (0, 0, T, T)); inm = mean(im, (2 * T, T, 3 * T, 2 * T))
    for (r, c), key in LAYOUT.items():
        tile = im.crop((c * T, r * T, c * T + T, r * T + T))
        # verify the layout: each corner patch is closer to its expected texture
        got = ""
        for cx, cy in [(0, 0), (T - 6, 0), (0, T - 6), (T - 6, T - 6)]:
            m = mean(tile, (cx, cy, cx + 6, cy + 6))
            got += "1" if dist(m, inm) < dist(m, outm) else "0"
        if got != key:
            bad.append(((r, c), key, got))
        tiles.setdefault(key, []).append(tile)
    cols = lambda boxes: set(p for b in boxes for p in im.crop(b).convert("RGB").getdata())
    cout = cols([(0, r * T, T, r * T + T) for r in range(3)])
    cin = cols([(2 * T, T, 3 * T, 2 * T), (0, 3 * T, T, 4 * T), (0, 4 * T, T, 5 * T)])
    outside_only = cout - cin
    masked = {}
    for key, lst in tiles.items():
        out = []
        for tile in lst:
            m = Image.new("L", (T, T), 0)
            rgb = tile.convert("RGB")
            for y in range(T):
                for x in range(T):
                    if rgb.getpixel((x, y)) not in outside_only:
                        m.putpixel((x, y), 255)
            out.append((tile, m))
        masked[key] = out
    MASKED[name] = masked
    return tiles, bad


def main():
    rows = [l.strip() for l in MAP.read_text().splitlines() if l.strip() and l[0] not in ";@"]
    H, W = len(rows), len(rows[0])
    terr = [[CH[ch] for ch in row] for row in rows]
    sets = {}
    for n in PAIRS:
        tiles, bad = load_tileset(n)
        sets[n] = tiles
        if bad:
            print("layout mismatch", n, bad)
    fill = {}
    for t, files in {"grass": ["fill_grass_3"], "forest": ["fill_forest_floor_1", "fill_forest_floor_2"],
                     "road": ["fill_road_1", "fill_road_2"], "bog": ["fill_bog_1", "fill_bog_2"],
                     "sand": ["fill_sand_1", "fill_sand_2"], "hill": ["fill_hill_1", "fill_hill_2"],
                     "field": ["fill_field_2"]}.items():
        fill[t] = [Image.open(O / f"{f}.png").convert("RGBA") for f in files]
    water64 = Image.open(O / "fill_water_proc256.png").convert("RGBA")

    own = {"forest": "grass_forest", "road": "grass_road", "bog": "grass_bog", "sand": "grass_sand",
           "hill": "grass_hill", "field": "grass_field", "water": "grass_water"}
    USE_OWN = "--fills" not in sys.argv

    def fill_tile(t, i, j):
        if USE_OWN and t in own and t != "water":
            v = sets[own[t]]["1111"]
            return v[h(t, i, j) % len(v)]
        if t == "water":
            return water64.crop(((i % 8) * T, (j % 8) * T, (i % 8) * T + T, (j % 8) * T + T))
        v = fill[t]
        return v[h(t, i, j) % len(v)]

    def cell(x, y):
        return terr[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)]

    canvas = Image.new("RGBA", ((W + 1) * T, (H + 1) * T))
    stats = {"fill": 0, "pair": 0, "reduced": 0}
    for j in range(H + 1):
        for i in range(W + 1):
            c = [cell(i - 1, j - 1), cell(i, j - 1), cell(i - 1, j), cell(i, j)]
            s = set(c)
            if len(s) == 1:
                tile = fill_tile(c[0], i, j); stats["fill"] += 1
            else:
                best = None
                for n, (out, inn) in PAIRS.items():
                    off = sum(1 for t in c if t not in (out, inn))
                    score = (off, 0 if out == "grass" else 1)
                    if best is None or score < best[0]:
                        best = (score, n, out, inn)
                (off, _), n, out, inn = best
                if off > 0:
                    # three or more grounds: grass first, then each ground as a masked layer
                    tile = fill_tile("grass", i, j).copy()
                    for L in LAYERS:
                        cov = COVER.get(L, {L})
                        if not (s & cov):
                            continue
                        key = "".join("1" if t in cov else "0" for t in c)
                        if key == "1111":
                            tile.paste(fill_tile(L, i, j), (0, 0)); continue
                        tl, m = MASKED["grass_" + L][key][h(L, i, j) % len(MASKED["grass_" + L][key])]
                        tile.paste(tl, (0, 0), m)
                    stats["layered"] = stats.get("layered", 0) + 1
                    canvas.paste(tile, (i * T, j * T))
                    continue
                stats["pair" if off == 0 else "reduced"] += 1
                key = "".join("1" if t == inn else "0" for t in c)
                if key == "0000":
                    tile = fill_tile(out, i, j)
                elif key == "1111":
                    tile = fill_tile(inn, i, j)
                else:
                    v = sets[n][key]; tile = v[h(n, i, j) % len(v)]
            canvas.paste(tile, (i * T, j * T))
    # dual grid is offset by half a cell; crop back to the cell grid
    ground = canvas.crop((T // 2, T // 2, T // 2 + W * T, T // 2 + H * T))

    # trees
    pines = [Image.open(p).convert("RGBA") for p in sorted(O.glob("tree_pine_shadow_*.png"))]
    birches = [Image.open(p).convert("RGBA") for p in sorted(O.glob("tree_birch_shadow_*.png"))]
    rnd = random.Random(1502)
    placed = []
    for y in range(H):
        for x in range(W):
            if terr[y][x] != "forest" or not pines or not birches:
                continue
            r = random.Random(h("tree", x, y))
            spr = r.choice(pines) if r.random() < 0.65 else r.choice(birches)
            ox, oy = r.randint(-7, 7), r.randint(-6, 6)
            # sprite foot (bottom centre of the opaque box) on the cell centre
            bb = spr.getbbox()
            fx = (bb[0] + bb[2]) // 2; fy = bb[3] - 4
            placed.append((y * T + T // 2 + oy, x * T + T // 2 + ox - fx, y * T + T // 2 + oy - fy, spr))
    placed.sort(key=lambda p: p[0])
    for _, px, py, spr in placed:
        ground.alpha_composite(spr, (px, py)) if px >= 0 and py >= 0 else ground.paste(spr, (px, py), spr)
    ground = ground.convert("RGB")
    ground.save(O / "map_full.png", optimize=True)
    ground.resize((1200, 1200), Image.LANCZOS).save(O / "map_small.png", optimize=True)
    # crop around the left town centre (8,58): 40 x 25 cells
    x0, y0 = 0, 58 - 12
    crop = ground.crop((x0 * T, y0 * T, (x0 + 40) * T, (y0 + 25) * T))
    crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST).save(O / "map_crop_x2.png", optimize=True)
    # second crop: the two lakes and the crossing road in the centre
    c2 = ground.crop((44 * T, 42 * T, 84 * T, 67 * T))
    c2.resize((c2.width * 2, c2.height * 2), Image.NEAREST).save(O / "map_crop_center_x2.png", optimize=True)
    print(stats, "trees", len(placed))


if __name__ == "__main__":
    main()
