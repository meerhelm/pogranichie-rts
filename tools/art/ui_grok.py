"""Builds the interface skin ui/skin/grok/*.png from pieces of Grok's UI mock-ups.

Sources are hand-picked cut-outs in art_src/ui_grok/ (oak planks, a bronze frame, iron corner
brackets, a folk ornament band, parchment). Every output is a nine-patch for ui/theme.tres:
the rim lives in the outer margin, the middle stretches or tiles. Re-run after changing a
source or a scale: `python3 -m tools.art.ui_grok`.
"""

import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

SRC = "art_src/ui_grok"
OUT = "ui/skin/grok"


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def scaled(img, factor):
    w, h = img.size
    return img.resize((max(1, round(w * factor)), max(1, round(h * factor))), Image.LANCZOS)


def darker(img, k):
    rgb = ImageEnhance.Brightness(img.convert("RGB")).enhance(k)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name), optimize=True)
    print(f"{OUT}/{name} {img.size}")


def opaque_bbox(img, threshold=200):
    a = np.asarray(img.getchannel("A")) >= threshold
    ys, xs = np.nonzero(a)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def buttons():
    """Oak plank with rivets: normal, hover (bronze frame), pressed (darker), disabled (grey)."""
    plank = load("plank.png")
    plank = plank.crop(opaque_bbox(plank, 250))
    frame = load("gold_frame.png").resize(plank.size, Image.LANCZOS)
    f = 0.5
    normal = scaled(plank, f)
    hover = plank.copy()
    hover.alpha_composite(frame)
    pressed = darker(plank, 0.7)
    pressed.alpha_composite(darker(frame, 0.8))
    gray = load("plank_gray.png")
    gray = gray.crop(opaque_bbox(gray, 250)).resize(plank.size, Image.LANCZOS)
    save(normal, "button.png")
    save(scaled(hover, f), "button_hover.png")
    save(scaled(pressed, f), "button_pressed.png")
    save(scaled(gray, f), "button_disabled.png")
    focus = Image.new("RGBA", plank.size)
    focus.alpha_composite(frame)
    save(scaled(focus, f), "focus.png")


def command_buttons():
    """Square order buttons: a small framed oak tile, hover/pressed/disabled like the planks."""
    sq = load("square.png")
    sq = sq.crop(opaque_bbox(sq, 250))
    frame = load("gold_frame.png")
    # The bronze frame is wide; keep its rim width by cutting the corners out of it.
    w, h = sq.size
    m = 14
    fr = Image.new("RGBA", (w, h))
    src = frame
    sw, sh = src.size
    fr.paste(src.crop((0, 0, m, m)), (0, 0))
    fr.paste(src.crop((sw - m, 0, sw, m)), (w - m, 0))
    fr.paste(src.crop((0, sh - m, m, sh)), (0, h - m))
    fr.paste(src.crop((sw - m, sh - m, sw, sh)), (w - m, h - m))
    fr.paste(src.crop((m, 0, sw - m, m)).resize((w - 2 * m, m)), (m, 0))
    fr.paste(src.crop((m, sh - m, sw - m, sh)).resize((w - 2 * m, m)), (m, h - m))
    fr.paste(src.crop((0, m, m, sh - m)).resize((m, h - 2 * m)), (0, m))
    fr.paste(src.crop((sw - m, m, sw, sh - m)).resize((m, h - 2 * m)), (w - m, m))
    normal = darker(sq, 0.8)
    hover = normal.copy()
    hover.alpha_composite(fr)
    pressed = darker(sq, 0.55)
    pressed.alpha_composite(darker(fr, 0.8))
    gray = ImageEnhance.Color(darker(sq, 0.6)).enhance(0.15)
    save(normal, "cmd.png")
    save(hover, "cmd_hover.png")
    save(pressed, "cmd_pressed.png")
    save(gray, "cmd_disabled.png")


def periodic(img, period, axis):
    """`img` cut to `period` along `axis` (0 = x, 1 = y) so that it tiles without a seam: the
    part past the period is cross-faded into the start. `img` must be longer than `period`."""
    a = np.asarray(img).astype(float)
    if axis == 1:
        a = a.transpose(1, 0, 2)
    extra = a.shape[1] - period
    out = a[:, :period].copy()
    t = np.linspace(0.0, 1.0, extra + 2)[1:-1][None, :, None]
    out[:, :extra] = a[:, period:] * (1 - t) + a[:, :extra] * t
    if axis == 1:
        out = out.transpose(1, 0, 2)
    return Image.fromarray(out.round().astype(np.uint8))


# The iron-bound frame, rebuilt from two clean pieces of Grok's iron_frame.png (its top right
# bracket is drawn wrong and its left beam is patchy): the bottom left bracket, flipped into
# all four corners, and a stretch of the right beam (mirrored for the left one) and of the
# bottom beam (flipped for the top one). Sizes in source pixels; the margins are the nine-patch
# margins, the beams between them repeat every PERIOD so that they tile in the theme.
FRAME_BRACKET = (0, 142, 46, 181)   # bottom left iron bracket, with its beam ends
FRAME_SIDE = (152, 45, 192, 125)    # right beam between the brackets, no rivet
FRAME_BOTTOM = (50, 142, 140, 181)  # bottom beam between the brackets, same rows as the bracket
FRAME_MARGIN = (48, 48)
FRAME_PERIOD = 64


def _band(img, axis, start, end):
    """`img`'s alpha kept only from `start` to `end` along `axis` (0 = x, 1 = y)."""
    a = np.asarray(img.getchannel("A")).copy()
    if axis == 0:
        a[:, :start] = 0
        a[:, end:] = 0
    else:
        a[:start, :] = 0
        a[end:, :] = 0
    return Image.fromarray(a)


def iron_frame(fill):
    """The frame over `fill` (a FRAME_PERIOD-square tile laid under it, phase-matched to the
    nine-patch middle), as a nine-patch of 2 * FRAME_MARGIN + FRAME_PERIOD source pixels."""
    src = load("iron_frame.png")
    mx, my = FRAME_MARGIN
    n = FRAME_PERIOD
    w, h = 2 * mx + n, 2 * my + n
    out = Image.new("RGBA", (w, h))
    # Under the frame: the fill, over the whole rectangle.
    for y in range(my - 2 * n, h, n):
        for x in range(mx - 2 * n, w, n):
            out.paste(fill, (x, y))
    # Beams: one period each in the nine-patch middle. The right and bottom ones are laid,
    # then mirrored onto the left and top.
    side = periodic(src.crop(FRAME_SIDE), n, 1)
    bottom = periodic(src.crop(FRAME_BOTTOM), n, 0)
    right = Image.new("RGBA", (w, h))
    for y in range(my - 2 * n, h, n):
        right.paste(side, (w - side.width + 4, y))
    low = Image.new("RGBA", (w, h))
    for x in range(mx - 2 * n, w, n):
        low.paste(bottom, (x, h - bottom.height))
    bl = src.crop(FRAME_BRACKET)
    bw, bh = bl.size
    # Beam ends stop under the brackets, not past them.
    right.putalpha(_band(right, 1, bh - 8, h - bh + 8))
    low.putalpha(_band(low, 0, bw - 8, w - bw + 8))
    beams = Image.alpha_composite(right, right.transpose(Image.FLIP_LEFT_RIGHT))
    beams.alpha_composite(low)
    beams.alpha_composite(low.transpose(Image.FLIP_TOP_BOTTOM))
    out.alpha_composite(beams)
    # Brackets: the bottom left one in every corner.
    out.alpha_composite(bl, (0, h - bh))
    out.alpha_composite(bl.transpose(Image.FLIP_LEFT_RIGHT), (w - bw, h - bh))
    out.alpha_composite(bl.transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
    out.alpha_composite(bl.transpose(Image.ROTATE_180), (w - bw, 0))
    return out


def panels():
    """Dark oak boards inside a frame with iron corner brackets (big panels, minimap, portrait)."""
    dark = load("plank_dark.png")
    x0, y0, x1, y1 = opaque_bbox(dark, 250)
    boards = dark.crop((x0 + 30, y0 + 25, x1 - 30, y1 - 25))
    n = FRAME_PERIOD
    tile = boards.crop((40, 0, 40 + n + 14, boards.height)).resize((n + 14, n + 14), Image.LANCZOS)
    tile = periodic(periodic(tile, n, 0), n, 1)
    save(scaled(iron_frame(tile), 0.5), "panel.png")
    black = Image.new("RGBA", (n, n), (14, 11, 8, 255))
    save(scaled(iron_frame(black), 0.5), "minimap_frame.png")
    save(scaled(iron_frame(black), 0.375), "portrait_frame.png")
    well = darker(boards, 0.55).crop((0, 0, 64, 48))
    a = np.zeros((well.height, well.width, 4), np.uint8)
    a[:2, :] = (8, 6, 4, 255)
    a[:, :2] = (8, 6, 4, 255)
    a[-2:, :] = (120, 92, 52, 255)
    a[:, -2:] = (120, 92, 52, 255)
    rim = Image.fromarray(a)
    well.alpha_composite(rim)
    save(well, "well.png")


def top_bar():
    """The top strip: its ends and a clean stretch of the middle (Grok baked the counters in)."""
    bar = load("top_bar.png")
    w, h = bar.size
    left = bar.crop((0, 0, 18, h))
    mid = bar.crop((890, 0, 1000, h))
    right = bar.crop((w - 18, 0, w, h))
    out = Image.new("RGBA", (18 + 110 + 18, h))
    out.paste(left, (0, 0))
    out.paste(mid, (18, 0))
    out.paste(right, (128, 0))
    # Drop the ragged, half-clear rows at the top and bottom edge (they show as dashes).
    a = np.asarray(out.getchannel("A"))[:, 20:-20].min(axis=1)
    rows = np.nonzero(a >= 250)[0]
    out = out.crop((0, rows[0], out.width, rows[-1] + 1))
    save(scaled(out, 0.8), "top_bar.png")


def hp_bar():
    """Gold bar for HP: an empty dark frame and the warm gold fill."""
    frame = load("bar_frame.png")
    frame = frame.crop(opaque_bbox(frame, 128))
    inside = Image.new("RGBA", frame.size, (20, 15, 10, 255))
    inside.alpha_composite(frame)
    f = 18 / frame.height
    save(scaled(inside, f), "bar_bg.png")
    gold = load("gold_bar.png")
    gold = gold.crop(opaque_bbox(gold, 250))
    # ProgressBar draws the fill over the whole bar, so the fill carries a clear border as
    # wide as the frame's rim and sits inside it.
    fill = scaled(gold, 10 / gold.height)
    padded = Image.new("RGBA", (fill.width + 8, fill.height + 8))
    padded.paste(fill, (4, 4))
    save(padded, "bar_fill.png")


def ornament():
    """The folk sash band: one repeat of the pattern, found by autocorrelation, for tiling."""
    band = load("ornament.png")
    band = band.crop(opaque_bbox(band, 250))
    w, h = band.size
    g = np.asarray(band.convert("L"), float)[h // 4: 3 * h // 4]
    best, period = 1e18, w // 3
    for p in range(60, w // 2):
        d = np.mean((g[:, 10: w - p - 10] - g[:, 10 + p: w - 10]) ** 2)
        if d < best:
            best, period = d, p
    start = 10
    tile = band.crop((start, 0, start + period, h))
    f = 22 / h
    save(scaled(tile, f), "ornament.png")
    print("ornament period", period)


def parchment():
    """Parchment: the clean sheet from Grok's UI kit picture."""
    kit = load("ui_kit.jpg")
    sheet = kit.crop((497, 321, 867, 577))
    save(scaled(sheet, 0.5), "parchment.png")


def menu_background():
    """Grok's main menu picture without its baked-in title and button column: the left part
    sinks into a blurred, darkened copy, under the menu's own title and panel."""
    img = Image.open(os.path.join(SRC, "main_menu.jpg")).convert("RGB")
    img = img.resize((1920, 1080), Image.LANCZOS)
    dark = ImageEnhance.Brightness(img.filter(ImageFilter.GaussianBlur(28))).enhance(0.38)
    w, h = img.size
    x = np.arange(w, dtype=float)
    a0, a1 = 690.0, 900.0  # opaque cover up to a0, fades out by a1
    t = np.clip((a1 - x) / (a1 - a0), 0.0, 1.0)
    alpha = t * t * (3 - 2 * t)
    mask = Image.fromarray((np.tile(alpha, (h, 1)) * 255).astype(np.uint8))
    out = Image.composite(dark, img, mask)
    path = "ui/art/menu_background_grok.jpg"
    out.save(path, quality=90)
    print(path, out.size)


def main():
    buttons()
    command_buttons()
    panels()
    top_bar()
    hp_bar()
    ornament()
    parchment()
    menu_background()


if __name__ == "__main__":
    main()
