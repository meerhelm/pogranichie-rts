"""Assemble map_gdl_01 (ВКЛ 1) from Retro Diffusion tiles on a dual grid, with trees and the
mission's buildings. Tiles of Smolino are reused where the ground is the same."""
import json, random, sys, zlib
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts")
G = ROOT / ".rd-trial/gdl01"
SM = G / "from_smolina"
T = 32
MAP = ROOT / "maps/map_gdl_01/terrain.txt"
MISSION = ROOT / "missions/gdl_01/mission.json"
CH = {".": "grass", ",": "field", "f": "forest", "F": "old_forest", "b": "bog", "B": "quagmire", "=": "ford",
      "~": "water", "i": "water", "#": "road", "h": "hill", "s": "sand", "a": "grass",
      "o": "bog", "$": "hill", "%": "grass"}
LAYOUT = {(0, 0): "0000", (0, 1): "0001", (0, 2): "0011", (0, 3): "0010",
          (1, 0): "0000", (1, 1): "0101", (1, 2): "1111", (1, 3): "1010",
          (2, 0): "0000", (2, 1): "0100", (2, 2): "1100", (2, 3): "1000",
          (3, 0): "1111", (3, 1): "1110", (3, 2): "1101", (3, 3): "0110",
          (4, 0): "1111", (4, 1): "1011", (4, 2): "0111", (4, 3): "1001"}
PAIRS = {  # name -> (outside, inside, folder)
    "grass_forest": ("grass", "forest", SM), "grass_road": ("grass", "road", SM), "grass_bog": ("grass", "bog", SM),
    "grass_sand": ("grass", "sand", SM), "sand_water": ("sand", "water", SM), "grass_hill": ("grass", "hill", SM),
    "grass_water": ("grass", "water", SM), "grass_field": ("grass", "field", SM),
    "forest_road": ("forest", "road", G), "forest_old_forest": ("forest", "old_forest", G),
    "grass_old_forest": ("grass", "old_forest", G), "forest_sand": ("forest", "sand", G),
    "bog_quagmire": ("bog", "quagmire", G), "forest_bog": ("forest", "bog", G),
    "forest_field": ("forest", "field", G), "hill_old_forest": ("hill", "old_forest", G)}
LAYERS = ["field", "road", "sand", "bog", "quagmire", "hill", "water", "forest", "old_forest"]
COVER = {"sand": {"sand", "water"}, "bog": {"bog", "quagmire"}}
OWN = {"forest": "grass_forest", "road": "grass_road", "bog": "grass_bog", "sand": "grass_sand", "hill": "grass_hill",
       "field": "grass_field", "old_forest": "grass_old_forest", "quagmire": "bog_quagmire"}
FOOT = {"gdl_town_center": (4, 4), "gdl_house": (2, 2), "to_shrine": (2, 2), "to_castle": (4, 4), "to_house": (2, 2),
        "to_gate": (1, 1)}


def h(*a):
    return zlib.crc32(repr(a).encode())


def load_tileset(path):
    im = Image.open(path).convert("RGBA")
    tiles = {}
    for (r, c), key in LAYOUT.items():
        tiles.setdefault(key, []).append(im.crop((c * T, r * T, c * T + T, r * T + T)))
    cols = lambda boxes: set(p for b in boxes for p in im.crop(b).convert("RGB").getdata())
    cout = cols([(0, r * T, T, r * T + T) for r in range(3)])
    cin = cols([(2 * T, T, 3 * T, 2 * T), (0, 3 * T, T, 4 * T), (0, 4 * T, T, 5 * T)])
    oo = cout - cin
    masked = {}
    for key, lst in tiles.items():
        masked[key] = []
        for tile in lst:
            m = Image.new("L", (T, T), 0); rgb = tile.convert("RGB")
            for y in range(T):
                for x in range(T):
                    if rgb.getpixel((x, y)) not in oo:
                        m.putpixel((x, y), 255)
            masked[key].append((tile, m))
    return tiles, masked


def darker(im, k):
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and not (r < 40 and g < 40 and b < 30 and a < 200):
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return im


def main():
    rows = [l.strip() for l in MAP.read_text().splitlines() if l.strip() and l[0] not in ";@"]
    H, W = len(rows), len(rows[0])
    terr = [[CH[ch] for ch in row] for row in rows]
    rterr = [["water" if t == "ford" else t for t in row] for row in terr]
    sets, masks = {}, {}
    for n, (_, _, folder) in PAIRS.items():
        sets[n], masks[n] = load_tileset(folder / f"ts_{n}.png")
    grass = Image.open(SM / "fill_grass_3.png").convert("RGBA")
    water = Image.open(SM / "fill_water_proc256.png").convert("RGBA")

    def fill_tile(t, i, j):
        if t == "grass":
            return grass
        if t == "water":
            return water.crop(((i % 8) * T, (j % 8) * T, (i % 8) * T + T, (j % 8) * T + T))
        v = sets[OWN[t]]["1111"]
        return v[h(t, i, j) % len(v)]

    def mask_set(L):
        for n, (o, inn, _) in PAIRS.items():
            if inn == L and o == "grass":
                return n
        for n, (o, inn, _) in PAIRS.items():
            if inn == L:
                return n

    def cell(x, y):
        return rterr[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)]

    canvas = Image.new("RGBA", ((W + 1) * T, (H + 1) * T))
    stats = {"fill": 0, "pair": 0, "layered": 0}
    for j in range(H + 1):
        for i in range(W + 1):
            c = [cell(i - 1, j - 1), cell(i, j - 1), cell(i - 1, j), cell(i, j)]
            s = set(c)
            if len(s) == 1:
                tile = fill_tile(c[0], i, j); stats["fill"] += 1
            else:
                pair = None
                for n, (o, inn, _) in PAIRS.items():
                    if s <= {o, inn}:
                        pair = (n, o, inn); break
                if pair:
                    n, o, inn = pair
                    key = "".join("1" if t == inn else "0" for t in c)
                    v = sets[n][key]; tile = v[h(n, i, j) % len(v)]
                    stats["pair"] += 1
                else:
                    tile = fill_tile("grass", i, j).copy()
                    for L in LAYERS:
                        cov = COVER.get(L, {L})
                        if not (s & cov):
                            continue
                        key = "".join("1" if t in cov else "0" for t in c)
                        if key == "1111":
                            tile.paste(fill_tile(L, i, j), (0, 0)); continue
                        ms = masks[mask_set(L)][key]
                        tl, m = ms[h(L, i, j) % len(ms)]
                        tile.paste(tl, (0, 0), m)
                    stats["layered"] += 1
            canvas.paste(tile, (i * T, j * T))
    ground = canvas.crop((T // 2, T // 2, T // 2 + W * T, T // 2 + H * T))
    d = ImageDraw.Draw(ground)

    # rusty puddles in the bog (only well inside it)
    RUST, RUST_L, MUD = (0x8a, 0x4a, 0x22), (0xa8, 0x63, 0x2e), (0x4a, 0x34, 0x24)
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if terr[y][x] != "bog" or any(terr[y + dy][x + dx] not in ("bog", "quagmire") for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            r = random.Random(h("pud", x, y))
            for _ in range(r.choice((0, 1, 1, 2))):
                cx, cy = x * T + r.randint(6, 25), y * T + r.randint(6, 25)
                rx, ry = r.randint(3, 6), r.randint(2, 4)
                d.ellipse((cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1), fill=MUD)
                d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=RUST)
                d.line((cx - rx + 2, cy - ry + 1, cx, cy - ry + 1), fill=RUST_L)
    # fords: shallow light water with pebbles
    LIGHT, STONES = (0x4a, 0x8a, 0x80, 120), [(0x8f, 0x8d, 0x82), (0xb0, 0xad, 0x9f), (0x6e, 0x6e, 0x66)]
    over = Image.new("RGBA", ground.size); od = ImageDraw.Draw(over)
    for y in range(H):
        for x in range(W):
            if terr[y][x] != "ford":
                continue
            od.rectangle((x * T, y * T, x * T + T - 1, y * T + T - 1), fill=LIGHT)
            r = random.Random(h("ford", x, y))
            for _ in range(10):
                px, py = x * T + r.randint(1, 29), y * T + r.randint(1, 29)
                od.rectangle((px, py, px + r.randint(1, 2), py + 1), fill=r.choice(STONES) + (255,))
    ground.alpha_composite(over)

    # trees and buildings, drawn together by their foot line
    def load(glob, folder):
        return [Image.open(p).convert("RGBA") for p in sorted(folder.glob(glob))]
    pines, birches = load("tree_pine_shadow_*.png", SM), load("tree_birch_shadow_*.png", SM)
    oaks, spruces = load("tree_oak_shadow_*.png", G), load("tree_spruce_shadow_*.png", G)
    dark = {id(s): darker(s, 0.82) for s in spruces + oaks + pines}
    sprites = []
    occupied = set()
    mission = json.loads(MISSION.read_text())
    BDIR = G / "buildings"
    walls = set()
    for w in mission["setup"].get("walls", []):
        (x0, y0), (x1, y1) = w["from"], w["to"]
        for yy in range(min(y0, y1), max(y0, y1) + 1):
            for xx in range(min(x0, x1), max(x0, x1) + 1):
                walls.add((xx, yy))
    gates = {tuple(b["at"]) for b in mission["setup"]["buildings"] if b["type"].endswith("_gate")}
    for b in mission["setup"]["buildings"]:
        t = b["type"]; ax, ay = b["at"]
        if t.endswith("_gate") and ((ax, ay - 1) in walls | gates or (ax, ay + 1) in walls | gates) \
                and not ((ax - 1, ay) in walls | gates or (ax + 1, ay) in walls | gates):
            t += "_v"
        meta = json.loads((BDIR / f"{t}.json").read_text())
        fw, fh = meta["cells"]
        for yy in range(ay, ay + fh):
            for xx in range(ax, ax + fw):
                occupied.add((xx, yy))
        spr = Image.open(BDIR / f"{t}_done.png").convert("RGBA")
        fx0, fy0 = meta["footprint_px"][0], meta["footprint_px"][1]
        sprites.append(((ay + fh) * T, ax * T - fx0, ay * T - fy0, spr))
    order = {"n": 0, "w": 1, "post": 2, "e": 3, "s": 4}
    piece = {k: Image.open(BDIR / f"gdl_palisade_{k}.png").convert("RGBA") for k in order}
    link = walls | gates
    for (x, y) in walls:
        if (x, y) in gates:
            continue
        occupied.add((x, y))
        parts = ["post"] + [d for d, (dx, dy) in (("e", (1, 0)), ("w", (-1, 0)), ("n", (0, -1)), ("s", (0, 1)))
                            if (x + dx, y + dy) in link]
        cellim = Image.new("RGBA", (T, 2 * T))
        for k in sorted(parts, key=order.get):
            cellim.alpha_composite(piece[k])
        sprites.append(((y + 1) * T, x * T, y * T - T, cellim))
    for y in range(H):
        for x in range(W):
            t = terr[y][x]
            if t not in ("forest", "old_forest") or any((x + dx, y + dy) in occupied for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            r = random.Random(h("tree", x, y))
            n = r.choice((2, 2, 3)) if t == "forest" else 3
            for k in range(n):
                if t == "forest":
                    q = r.random()
                    spr = r.choice(pines) if q < 0.5 else r.choice(birches) if q < 0.75 else r.choice(spruces or pines) if q < 0.9 else r.choice(oaks or pines)
                else:
                    q = r.random()
                    base = r.choice(spruces or pines) if q < 0.55 else r.choice(oaks or pines) if q < 0.9 else r.choice(pines)
                    spr = dark[id(base)]
                bb = spr.getbbox()
                fx = (bb[0] + bb[2]) // 2; fy = bb[3] - 4
                cx = x * T + r.randint(3, 29); cy = y * T + r.randint(4, 30)
                sprites.append((cy, cx - fx, cy - fy, spr))
    sprites.sort(key=lambda p: p[0])
    for _, px, py, spr in sprites:
        if px >= 0 and py >= 0:
            ground.alpha_composite(spr, (px, py))
        else:
            ground.paste(spr, (px, py), spr)
    ground = ground.convert("RGB")
    full = ground.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    full.save(G / "map_full.png", optimize=True)
    ground.resize((1280, 1280), Image.LANCZOS).save(G / "map_small.png", optimize=True)
    for name, (x0, y0) in {"map_crop_village_x2.png": (103, 4), "map_crop_castle_x2.png": (78, 110),
                           "map_crop_grove_x2.png": (60, 62)}.items():
        c = ground.crop((x0 * T, y0 * T, (x0 + 40) * T, (y0 + 25) * T))
        c.resize((c.width * 2, c.height * 2), Image.NEAREST).save(G / name, optimize=True)
    print(stats, "sprites", len(sprites))


if __name__ == "__main__":
    main()
