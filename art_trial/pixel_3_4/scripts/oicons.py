"""64x64 order icons: stop/aggressive/defensive/stand_ground from Retro Diffusion, formations drawn here
(the model could not count dots); all on a dark steel plaque."""
from pathlib import Path
from PIL import Image, ImageDraw
G = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01")
RAW, O = G / "icons_raw", G / "icons/orders"; O.mkdir(parents=True, exist_ok=True)
N = 64; TOP, BOT, RIM = (0x5a, 0x5e, 0x5c), (0x2a, 0x2c, 0x2c), (0x14, 0x14, 0x12)
OUTL, BR_D, BR, BR_L, HI = (0x2a, 0x1c, 0x14), (0x8a, 0x4a, 0x22), (0xa8, 0x63, 0x2e), (0xd8, 0xc9, 0x5a), (0xe6, 0xd6, 0xa4)


def plate():
    p = Image.new("RGBA", (N, N)); d = ImageDraw.Draw(p)
    for y in range(N):
        k = y / (N - 1); d.line((0, y, N - 1, y), fill=tuple(int(TOP[i] * (1 - k) + BOT[i] * k) for i in range(3)) + (255,))
    d.rectangle((0, 0, N - 1, N - 1), outline=RIM); d.line((1, 1, N - 2, 1), fill=(0x84, 0x88, 0x84))
    return p


def dot(d, cx, cy):
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=OUTL)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=BR)
    d.point((cx + 1, cy + 1), fill=BR_D); d.point((cx + 2, cy), fill=BR_D); d.point((cx, cy + 2), fill=BR_D)
    d.point((cx - 1, cy - 1), fill=BR_L); d.point((cx - 1, cy - 2), fill=HI)


def arrow(d, cx, y):
    d.polygon(((cx, y - 4), (cx - 5, y + 2), (cx + 5, y + 2)), fill=OUTL)
    d.polygon(((cx, y - 2), (cx - 3, y + 1), (cx + 3, y + 1)), fill=HI)


def formation(name):
    p = plate(); d = ImageDraw.Draw(p)
    if name == "line":
        arrow(d, 32, 14)
        for r, y in enumerate((30, 42)):
            for i in range(5):
                dot(d, 12 + i * 10, y)
    elif name == "column":
        arrow(d, 32, 8)
        for r in range(5):
            for c in range(2):
                dot(d, 27 + c * 10, 18 + r * 9)
    elif name == "wedge":
        k = 0
        for r in range(4):
            for c in range(r + 1):
                dot(d, 32 - r * 6 + c * 12, 14 + r * 11)
    return p


for n in ("stop", "aggressive", "defensive", "stand_ground"):
    im = Image.open(RAW / f"{n}.png").convert("RGBA"); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]; px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    im = im.crop(im.getbbox())
    s = min(52 / im.width, 52 / im.height)
    if s < 1:
        im = im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST)
    p = plate(); p.alpha_composite(im, ((N - im.width) // 2, (N - im.height) // 2)); p.save(O / f"{n}.png")
for n in ("line", "column", "wedge"):
    formation(n).save(O / f"{n}.png")
names = ["stop", "aggressive", "defensive", "stand_ground", "line", "column", "wedge"]
sheet = Image.new("RGBA", (len(names) * 68, 68), (30, 30, 20, 255))
for i, n in enumerate(names):
    sheet.alpha_composite(Image.open(O / f"{n}.png"), (i * 68 + 2, 2))
sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(G / "icons/sheet_icons_orders_x3.png")
