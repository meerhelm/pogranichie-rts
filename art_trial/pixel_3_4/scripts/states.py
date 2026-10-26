"""Seven building stages from one generated `done` sprite (pixel art, 32 px cells).
usage: states.py RAW_DIR OUT_DIR"""
import json, random, sys
from pathlib import Path
from PIL import Image, ImageDraw

C = 32
STAGES = ["found", "build_33", "build_66", "done", "damaged_1", "damaged_2", "rubble"]
OUTL = (0x2a, 0x1c, 0x14, 255)
WOOD = (0x8a, 0x68, 0x44, 255); WOOD_D = (0x4a, 0x34, 0x24, 255); DUST = (0xc4, 0xa6, 0x79, 255)
PAD = (0x6b, 0x4c, 0x32, 120); SHADOW = (20, 24, 12, 100); INNER = (0x14, 0x12, 0x10, 255); CHAR = (0x3a, 0x2a, 0x20, 255)
# id: (footprint w, h, faction, rubble)
BUILD = {
    "gdl_town_center": (4, 4, "gdl", "wood"), "gdl_house": (2, 2, "gdl", "wood"),
    "gdl_granary": (2, 2, "gdl", "wood"), "gdl_lumber_yard": (2, 2, "gdl", "wood"),
    "gdl_mine": (2, 2, "gdl", "wood"), "gdl_shrine": (2, 2, "gdl", "wood"), "gdl_farm": (3, 3, "gdl", "wood"),
    "gdl_barracks": (3, 3, "gdl", "wood"), "gdl_range": (3, 3, "gdl", "wood"), "gdl_stable": (3, 3, "gdl", "wood"),
    "gdl_bort": (1, 1, "gdl", "wood"), "gdl_palisade": (1, 1, "gdl", "wood"), "gdl_gate": (1, 1, "gdl", "wood"),
    "gdl_gate_v": (1, 1, "gdl", "wood"), "gdl_tower": (1, 1, "gdl", "wood"), "gdl_zaseka": (3, 1, "gdl", "wood"),
    "gdl_zaseka_v": (1, 3, "gdl", "wood"), "to_castle": (4, 4, "to", "brick"), "to_house": (2, 2, "to", "wood"),
    "to_gate": (1, 1, "to", "wood"), "to_gate_v": (1, 1, "to", "wood"), "to_shrine": (2, 2, "to", "brick"),
}


def clean(im):
    """Hard alpha (pixel art) and trim."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im.crop(im.getbbox())


def opaque(im):
    a = im.getchannel("A")
    return {(x, y) for y in range(im.height) for x in range(im.width) if a.getpixel((x, y))}


def with_shadow(im):
    """Cast shadow to the lower right: the silhouette shifted (+3, +2), behind."""
    out = Image.new("RGBA", (im.width + 4, im.height + 3), (0, 0, 0, 0))
    sil = opaque(im)
    for (x, y) in sil:
        for d in ((3, 2), (2, 1), (3, 1)):
            q = (x + d[0], y + d[1])
            if (q[0], q[1]) not in sil:
                out.putpixel(q, SHADOW)
    out.alpha_composite(im, (0, 0))
    return out


def canvas_for(done, fw, fh):
    W = max(done.width, fw * C) + 8
    H = max(done.height, fh * C) + 8
    return W, H


def place(done, W, H, fw, fh):
    """Sprite bottom-centre on the footprint bottom-centre."""
    return ((W - done.width) // 2, H - 4 - done.height)


def foot_rect(W, H, fw, fh):
    x0 = (W - fw * C) // 2
    y1 = H - 4
    return (x0, y1 - fh * C, x0 + fw * C - 1, y1 - 1)


def stake(d, x, y, h=7):
    d.rectangle((x - 1, y - h, x, y), fill=WOOD); d.line((x - 2, y - h, x - 2, y), fill=OUTL)
    d.line((x + 1, y - h, x + 1, y), fill=OUTL); d.point((x - 1, y - h - 1), fill=OUTL); d.point((x, y - h - 1), fill=OUTL)


def logs(d, x, y, n=3):
    for i in range(n):
        d.rectangle((x, y - i * 3, x + 12, y - i * 3 + 2), fill=WOOD, outline=OUTL)


def found(W, H, fw, fh):
    im = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = foot_rect(W, H, fw, fh)
    d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=PAD)
    d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=DUST)
    for (x, y) in ((x0 + 3, y0 + 4), (x1 - 3, y0 + 4), (x0 + 3, y1 - 3), (x1 - 3, y1 - 3)):
        stake(d, x, y)
    if fw * fh >= 4:
        logs(d, x0 + 6, y1 - 6)
    return im


def scaffold(d, bbox, top, ground):
    x0, x1 = bbox[0] - 1, bbox[2]
    for a, b in ((x0, x0 + 6), (x1 - 6, x1)):
        for x in (a, b):
            d.line((x, top, x, ground), fill=WOOD); d.line((x + 1, top, x + 1, ground), fill=WOOD_D)
        for y in range(ground - 7, top + 2, -11):
            d.line((a, y, b + 1, y), fill=WOOD); d.line((a, y + 1, b + 1, y + 1), fill=WOOD_D)
            d.line((a, y + 1, b, y - 8), fill=WOOD_D)


def building(done, frac, W, H, fw, fh, rnd):
    im = found(W, H, fw, fh)
    ox, oy = place(done, W, H, fw, fh)
    keep_from = int(done.height * (1 - frac))
    part = done.copy()
    ImageDraw.Draw(part).rectangle((0, 0, done.width, keep_from - 1), fill=(0, 0, 0, 0))
    # ragged top edge: drop a few pixels on the cut row
    for x in range(done.width):
        if rnd.random() < 0.4:
            for y in range(keep_from, min(done.height, keep_from + rnd.randint(1, 3))):
                part.putpixel((x, y), (0, 0, 0, 0))
    im.alpha_composite(part, (ox, oy))
    b = part.getbbox()
    if b:
        d = ImageDraw.Draw(im)
        scaffold(d, (b[0] + ox, b[1] + oy, b[2] + ox, b[3] + oy), oy + keep_from - 4, H - 6)
    return im


def soot(im, blobs, k, rnd, holes):
    px = im.load(); sil = [p for p in opaque(im)]
    if not sil:
        return im
    for _ in range(blobs):
        cx, cy = rnd.choice(sil); r = rnd.randint(3, 6)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if 0 <= x < im.width and 0 <= y < im.height and (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    p = px[x, y]
                    if p[3] and rnd.random() < 0.85:
                        px[x, y] = (int(p[0] * k), int(p[1] * k), int(p[2] * k), 255)
    for _ in range(holes):
        cx, cy = rnd.choice(sil)
        for x, y in ((cx, cy), (cx + 1, cy), (cx, cy + 1), (cx + 1, cy + 1)):
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3]:
                px[x, y] = INNER
    return im


def broken(im, rnd):
    """Part of the roof caved in: a jagged hole in the upper third, dark inside, beams across."""
    b = im.getbbox(); px = im.load()
    w = b[2] - b[0]; hgt = b[3] - b[1]
    cx = b[0] + int(w * rnd.uniform(0.35, 0.65)); cy = b[1] + int(hgt * 0.3)
    rx, ry = max(4, w // 5), max(3, hgt // 7)
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3]:
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 + rnd.uniform(-0.25, 0.25):
                    px[x, y] = INNER
    # charred rim and a couple of fallen rafters across the hole
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] and px[x, y] != INNER:
                if any(0 <= x + dx < im.width and 0 <= y + dy < im.height and px[x + dx, y + dy] == INNER
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px[x, y] = CHAR
    d = ImageDraw.Draw(im)
    d.line((cx - rx + 1, cy - ry + 2, cx + rx - 2, cy + 1), fill=WOOD_D)
    d.line((cx - rx + 3, cy + ry - 1, cx + 1, cy - ry + 1), fill=CHAR)
    # nibble the silhouette at the top edge
    for x in range(b[0], b[2]):
        if rnd.random() < 0.25:
            for y in range(b[1], b[1] + rnd.randint(1, 4)):
                if px[x, y][3]:
                    px[x, y] = (0, 0, 0, 0)
    return im


def team_mask(im, faction):
    m = Image.new("L", im.size, 0); px = im.load()
    h = im.height
    for y in range(h):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if faction == "gdl" and r > 140 and g < 90 and b < 80:
                m.putpixel((x, y), 255)
            if faction == "to" and r > 200 and g > 200 and b > 190 and y < h * 0.45:
                m.putpixel((x, y), 255)
    return m


def outline(im):
    sil = opaque(im)
    for (x, y) in list(sil):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if 0 <= q[0] < im.width and 0 <= q[1] < im.height and q not in sil:
                im.putpixel(q, OUTL)
    return im


def main():
    raw, out = Path(sys.argv[1]), Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
    rubble = {k: clean(Image.open(raw / f"rubble_{k}.png")) for k in ("wood", "brick") if (raw / f"rubble_{k}.png").exists()}
    for uid, (fw, fh, fac, rub) in BUILD.items():
        src = raw / f"{uid}.png"
        if not src.exists():
            src = raw / f"{uid}_cell.png"
        if not src.exists():
            print("missing", uid); continue
        rnd = random.Random(uid)
        done = clean(Image.open(src))
        W, H = canvas_for(done, fw, fh)
        ox, oy = place(done, W, H, fw, fh)
        st = {}
        st["found"] = found(W, H, fw, fh)
        st["build_33"] = building(done, 0.33, W, H, fw, fh, rnd)
        st["build_66"] = building(done, 0.66, W, H, fw, fh, rnd)
        base = Image.new("RGBA", (W, H)); base.alpha_composite(done, (ox, oy))
        st["done"] = base
        st["damaged_1"] = soot(base.copy(), 4 + fw * fh // 2, 0.6, rnd, 3 + fw * fh)
        st["damaged_2"] = broken(soot(base.copy(), 7 + fw * fh, 0.45, rnd, 5 + fw * fh), rnd)
        r = Image.new("RGBA", (W, H))
        if rub in rubble:
            rb = rubble[rub]
            s = (fw * C) / rb.width
            rh = min(int(rb.height * s * 0.55), fh * C + 8, H - 8)  # a low heap, never taller than the canvas
            rb2 = rb.resize((max(8, int(rb.width * s)), max(6, rh)), Image.NEAREST)
            fr = foot_rect(W, H, fw, fh)
            r.alpha_composite(found(W, H, fw, fh) if False else Image.new("RGBA", (W, H)))
            r.alpha_composite(rb2, ((W - rb2.width) // 2, fr[3] - rb2.height + 2))
        st["rubble"] = r
        for name, im in st.items():
            im = with_shadow(outline(im) if name in ("damaged_2",) else im)
            im.save(out / f"{uid}_{name}.png")
            team_mask(im, fac).save(out / f"{uid}_{name}_team.png")
        fr = foot_rect(W, H, fw, fh)
        json.dump({"cells": [fw, fh], "cell_px": C, "footprint_px": list(fr),
                   "pivot": [(fr[0] + fr[2] + 1) / 2, (fr[1] + fr[3] + 1) / 2], "pivot_is": "centre of the footprint",
                   "stages": STAGES}, open(out / f"{uid}.json", "w"), indent=1)
        print("ok", uid, (W, H))
    for d in ("post", "e", "w", "n", "s"):  # palisade joints: done only, fixed 32x64 cell canvas
        uid = f"gdl_palisade_{d}"
        im = Image.open(raw / f"{uid}_cell.png").convert("RGBA")
        im.save(out / f"{uid}.png"); team_mask(im, "gdl").save(out / f"{uid}_team.png")
        json.dump({"cells": [1, 1], "cell_px": C, "footprint_px": [0, 32, 31, 63], "pivot": [16, 48],
                   "pivot_is": "centre of the footprint", "stages": ["done"],
                   "compose": "draw gdl_palisade_post plus one arm per neighbouring wall cell (e, w, n, s)"},
                  open(out / f"{uid}.json", "w"), indent=1)


main()
