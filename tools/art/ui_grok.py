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


def framed(fill, frame, size):
    """`fill` tiled under `frame` stretched to `size`."""
    out = Image.new("RGBA", size)
    for y in range(0, size[1], fill.height):
        for x in range(0, size[0], fill.width):
            out.alpha_composite(fill, (x, y))
    out.alpha_composite(frame.resize(size, Image.LANCZOS))
    return out


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


def panels():
    """Dark oak boards inside a frame with iron corner brackets (big panels, minimap, portrait)."""
    iron = load("iron_frame.png")
    iron = iron.crop(opaque_bbox(iron, 128))
    dark = load("plank_dark.png")
    x0, y0, x1, y1 = opaque_bbox(dark, 250)
    boards = dark.crop((x0 + 30, y0 + 25, x1 - 30, y1 - 25))
    panel = framed(boards, iron, iron.size)
    save(scaled(panel, 0.5), "panel.png")
    black = Image.new("RGBA", (32, 32), (14, 11, 8, 255))
    save(scaled(framed(black, iron, iron.size), 0.5), "minimap_frame.png")
    save(scaled(framed(black, iron, iron.size), 0.34), "portrait_frame.png")
    well = darker(boards, 0.55).crop((0, 0, 64, 48))
    rim = Image.new("RGBA", well.size)
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
