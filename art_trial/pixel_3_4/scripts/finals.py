"""Pick final `done` sources from buildings_raw into buildings_src (recolour stray teal to brown on wood,
crop gates to one cell, assemble palisade joints, vertical gates and the abatis)."""
import json
from pathlib import Path
from PIL import Image, ImageOps

G = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01")
RAW, SRC, OUT = G / "buildings_raw", G / "buildings_src", G / "buildings"
SRC.mkdir(exist_ok=True); OUT.mkdir(exist_ok=True)
TEAL = {(29, 60, 70): (42, 28, 20), (37, 85, 92): (74, 52, 36), (47, 108, 106): (107, 76, 50), (74, 138, 128): (138, 104, 68)}
PICK = {"gdl_town_center": "gdl_town_center", "gdl_house": "gdl_house", "gdl_farm": "gdl_farm", "gdl_bort": "gdl_bort",
        "gdl_granary": "gdl_granary_v2", "gdl_lumber_yard": "gdl_lumber_yard_v5", "gdl_mine": "gdl_mine_v2",
        "gdl_barracks": "gdl_barracks", "gdl_range": "gdl_range", "gdl_stable": "gdl_stable", "gdl_shrine": "gdl_shrine",
        "gdl_tower": "gdl_tower_v5", "to_castle": "to_castle", "to_house": "to_house", "to_shrine": "to_shrine",
        "to_gate": "to_gate_v2", "rubble_wood": "rubble_wood", "rubble_brick": "rubble_brick"}
NO_RECOLOUR = {"gdl_shrine"}


def load(n):
    im = Image.open(RAW / f"{n}.png").convert("RGBA"); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def brown(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] and p[:3] in TEAL:
                px[x, y] = TEAL[p[:3]] + (255,)
    return im


def trim(im):
    return im.crop(im.getbbox())


for uid, n in PICK.items():
    im = load(n)
    if uid.startswith(("gdl_", "rubble_wood")) and uid not in NO_RECOLOUR:
        brown(im)
    trim(im).save(SRC / f"{uid}.png")

# gate: the two posts and the door, one cell wide (40 px with the posts' overhang)
gate = brown(load("gdl_gate_v5")); trim(gate.crop((12, 0, 52, 64))).save(SRC / "gdl_gate.png")
post = trim(gate.crop((13, 0, 23, 64)))           # one thick gate post (side view of the gate)
tgate = load("to_gate_v2"); tpost = trim(tgate.crop((2, 0, 12, 48)))

# palisade: one stake and a 32 px run (stake shadow strip at the bottom is dropped)
pal = load("gdl_palisade_v2")
body = pal.crop((0, 0, 96, 38))
trim(body.crop((8, 0, 40, 38))).save(SRC / "gdl_palisade.png")
stake = trim(body.crop((12, 0, 21, 38)))
shade = stake.copy(); _p = shade.load()
for _y in range(shade.height):
    for _x in range(shade.width):
        r, g, b, a = _p[_x, _y]
        if a:
            _p[_x, _y] = (int(r * 0.8), int(g * 0.8), int(b * 0.8), a)

# abatis: three piles of felled branches side by side (horizontal) or one behind another (vertical)
rub = trim(load("rubble_wood")); brown(rub)
pile = rub.resize((40, 30), Image.NEAREST)
z = Image.new("RGBA", (104, 32))
for i, x in enumerate((0, 32, 64)):
    z.alpha_composite(pile if i % 2 == 0 else ImageOps.mirror(pile), (x, 1))
trim(z).save(SRC / "gdl_zaseka.png")
zv = Image.new("RGBA", (40, 32 * 3 + 16))
for i in range(3):
    zv.alpha_composite(pile if i % 2 else ImageOps.mirror(pile), (0, i * 32 + 8))
trim(zv).save(SRC / "gdl_zaseka_v.png")

# one-cell pieces drawn into a fixed 32×64 cell canvas: the footprint is the bottom 32 rows,
# the cell centre is (16, 48). Joints: post + arms toward the neighbours that are walls too.
CW, CH, CX, CY = 32, 64, 16, 48


def put(c, spr, cx, foot_y):
    """sprite bottom-centre at (cx, foot_y)"""
    c.alpha_composite(spr, (cx - spr.width // 2, foot_y - spr.height + 1))


def arm(d):
    c = Image.new("RGBA", (CW, CH))
    if d in "ew":
        run = body.crop((8, 0, 40, 38)); run = trim(run)
        half = run.crop((run.width // 2, 0, run.width, run.height)) if d == "e" else run.crop((0, 0, run.width // 2, run.height))
        c.alpha_composite(half, (CX if d == "e" else CX - half.width, CY + 4 - half.height + 1))
    else:  # stakes one behind another, 4 px apart, far ones first
        ys = range(CY - 16, CY + 1, 3) if d == "n" else range(CY, CY + 17, 3)
        for y in ys:  # stakes zigzag a little so their tips read as separate stakes
            put(c, stake if (y // 3) % 2 else shade, CX + (2 if (y // 3) % 2 else -2), y + 4)
    return c


def side_gate(p):
    c = Image.new("RGBA", (CW, CH))
    for y in list(range(CY - 16, CY - 7, 3)):
        put(c, stake if (y // 3) % 2 else shade, CX + (2 if (y // 3) % 2 else -2), y + 4)
    put(c, p, CX, CY - 6 + 4)                     # far post
    for y in list(range(CY + 8, CY + 17, 3)):
        put(c, stake if (y // 3) % 2 else shade, CX + (2 if (y // 3) % 2 else -2), y + 4)
    put(c, p, CX, CY + 8 + 4)                     # near post
    return c


pieces = {"gdl_palisade_post": Image.new("RGBA", (CW, CH))}
put(pieces["gdl_palisade_post"], stake, CX, CY + 4)
for d in "ewns":
    pieces[f"gdl_palisade_{d}"] = arm(d)
pieces["gdl_gate_v"] = side_gate(post)
pieces["to_gate_v"] = side_gate(tpost)
for k, im in pieces.items():
    im.save(SRC / f"{k}_cell.png")
print("ok", sorted(p.name for p in SRC.iterdir()))
