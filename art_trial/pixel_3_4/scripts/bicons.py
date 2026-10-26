"""64x64 building icons from the `done` sprites on an olive gradient plaque (team colour: GDL red, Order white)."""
from pathlib import Path
from PIL import Image, ImageDraw
G = Path("/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01")
B, O = G / "buildings", G / "icons/buildings"; O.mkdir(parents=True, exist_ok=True)
N = 64; TOP, BOT, RIM = (0x8a, 0x8a, 0x4a), (0x4a, 0x4a, 0x24), (0x2a, 0x2a, 0x14)
TEAM = {"gdl": (0xc8, 0x46, 0x3a), "to": (0xe8, 0xe4, 0xd6)}
ids = sorted(p.stem for p in B.glob("*.json") if "palisade_" not in p.stem)
done = []
for u in ids:
    plate = Image.new("RGBA", (N, N)); d = ImageDraw.Draw(plate)
    for y in range(N):
        k = y / (N - 1); d.line((0, y, N - 1, y), fill=tuple(int(TOP[i] * (1 - k) + BOT[i] * k) for i in range(3)) + (255,))
    d.rectangle((0, 0, N - 1, N - 1), outline=RIM); d.line((1, 1, N - 2, 1), fill=(0xa8, 0xa8, 0x66))
    im = Image.open(B / f"{u}_done.png").convert("RGBA")
    team = Image.open(B / f"{u}_done_team.png").convert("L")
    col = TEAM[u.split("_")[0]]; px = im.load(); tm = team.load()
    for y in range(im.height):
        for x in range(im.width):
            if tm[x, y] and px[x, y][3]:
                r, g, b, a = px[x, y]; l = (r + g + b) / 3 / 200
                px[x, y] = tuple(min(255, int(c * l)) for c in col) + (a,)
    im = im.crop(im.getbbox())
    s = min((N - 8) / im.width, (N - 8) / im.height)
    if s >= 1:
        s = int(s)                      # integer upscale keeps the pixels square
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)
    plate.alpha_composite(im, ((N - im.width) // 2, N - 4 - im.height))
    plate.save(O / f"{u}.png"); done.append(plate)
cols = 8; sheet = Image.new("RGBA", (cols * (N + 4), ((len(done) + cols - 1) // cols) * (N + 4)), (30, 30, 20, 255))
for i, p in enumerate(done):
    sheet.alpha_composite(p, ((i % cols) * (N + 4) + 2, (i // cols) * (N + 4) + 2))
sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(G / "icons/sheet_icons_buildings_x2.png")
print(len(done), ids)
