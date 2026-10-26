import json
from pathlib import Path
from PIL import Image, ImageDraw
G = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01"); B = G / "buildings"
ST = ["found", "build_33", "build_66", "done", "damaged_1", "damaged_2", "rubble"]
ids = sorted(p.stem for p in B.glob("*.json") if "palisade_" not in p.stem)
grass = Image.open(G / "from_smolina/fill_grass_3.png").convert("RGBA")
rows = []
for u in ids:
    ims = [Image.open(B / f"{u}_{s}.png").convert("RGBA") for s in ST]
    rows.append((u, ims))
CWD = 150; LBL = 120
def tinted(im, mask, col=(40, 90, 200)):
    im = im.copy(); m = mask.load(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if m[x, y]:
                r, g, b, a = px[x, y]; l = (r + g + b) / 3 / 255
                px[x, y] = (int(col[0] * l * 1.6), int(col[1] * l * 1.6), int(min(255, col[2] * l * 1.6)), a)
    return im
H = sum(max(i.height for i in ims) + 14 for _, ims in rows) + 230
sheet = Image.new("RGBA", (LBL + CWD * 8, H), (60, 66, 44, 255)); d = ImageDraw.Draw(sheet)
for k, s in enumerate(ST + ["done, team blue"]):
    d.text((LBL + k * CWD + 4, 4), s, fill=(240, 230, 200))
y = 20
for u, ims in rows:
    h = max(i.height for i in ims)
    d.text((4, y + h // 2), u, fill=(240, 230, 200))
    for k, im in enumerate(ims + [tinted(ims[3], Image.open(B / f"{u}_done_team.png"))]):
        bg = Image.new("RGBA", im.size)
        for gy in range(0, im.height, 32):
            for gx in range(0, im.width, 32):
                bg.paste(grass, (gx, gy))
        bg.alpha_composite(im)
        sheet.alpha_composite(bg, (LBL + k * CWD, y + h - im.height))
    y += h + 14
# palisade joints demo: a small ring with a gate
d.text((4, y + 4), "palisade joints", fill=(240, 230, 200))
ring = Image.new("RGBA", (8 * 32, 6 * 32 + 32))
for gy in range(0, ring.height, 32):
    for gx in range(0, ring.width, 32):
        ring.paste(grass, (gx, gy))
cells = {(x, 0) for x in range(1, 7)} | {(x, 4) for x in range(1, 7)} | {(1, y) for y in range(5)} | {(6, y) for y in range(5)}
gate_h, gate_v = (3, 4), (6, 2)
for (cx, cy) in sorted(cells, key=lambda c: (c[1], c[0])):
    ox, oy = cx * 32, cy * 32 + 32 - 32
    if (cx, cy) == gate_h:
        g = Image.open(B / "gdl_gate_done.png").convert("RGBA"); m = json.load(open(B / "gdl_gate.json"))
        ring.alpha_composite(g, (ox - m["footprint_px"][0], cy * 32 + 32 - m["footprint_px"][1])); continue
    if (cx, cy) == gate_v:
        g = Image.open(B / "gdl_gate_v_done.png").convert("RGBA"); m = json.load(open(B / "gdl_gate_v.json"))
        ring.alpha_composite(g, (ox - m["footprint_px"][0], cy * 32 + 32 - m["footprint_px"][1])); continue
    parts = ["post"] + [dn for dn, (dx, dy) in (("e", (1, 0)), ("w", (-1, 0)), ("n", (0, -1)), ("s", (0, 1))) if (cx + dx, cy + dy) in cells]
    for p in sorted(parts, key=lambda p: {"n": 0, "w": 1, "post": 2, "e": 3, "s": 4}[p]):
        ring.alpha_composite(Image.open(B / f"gdl_palisade_{p}.png").convert("RGBA"), (ox, cy * 32 + 32 - 32))
sheet.alpha_composite(ring, (LBL, y + 4))
sheet = sheet.crop((0, 0, sheet.width, y + ring.height + 10))
sheet.convert("RGB").save(G / "sheet_buildings.png", optimize=True)
print(sheet.size)
