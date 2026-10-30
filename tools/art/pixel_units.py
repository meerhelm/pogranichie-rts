"""Pixel-art unit sheets from Retro Diffusion animations (art_src/pixel_iso/full/units).

Each source is an animated GIF on white, 64x64: `<id>_<anim>_g<facing>.gif`, made by the
"advanced animation" styles (idle, walking, attack) from one view of the unit's 8-way turn
(rd_advanced_animation__rotate). Facings follow UnitView.facing (0 east, clockwise, 2 south);
only 0, 1, 2, 6, 7 are generated, 3, 4, 5 are their mirrors (SW = SE, W = E, NW = NE).

Writes art/sprites/units/<id>/{color,team,shadow}.png + sheet.json + pick.json at map scale
("scale": 1.0, drawn 1:1 with nearest filter):
- the white background is cut away (every near-white pixel);
- every facing is shifted so its feet stand on the pivot;
- team: a belt band across the waist (the player colour, shaded by the cloth under it);
- shadow: the figure thrown down-right along the ground, as the pixel buildings do;
- the panel icon ui/icons/units/<id>.png: head and shoulders, enlarged in whole pixels.

    python3 -m tools.art.pixel_units --src art_src/pixel_iso/full/units --out art/sprites [id ...]
"""

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

from tools.art.pick import write_pick
from tools.art.pixel_iso import shadow_of

FRAME = (80, 72)
PIVOT = (40, 56)  # feet; 16 px below for the down-right shadow
# riders are generated at 96x96: a bigger frame, room for the longer shadow
RIDER = ((128, 120), (56, 92))
# How far a rider's lowest hoof stands below the pivot, by generated facing: the pivot is the
# middle of the horse on the ground, not its nearest hoof, or the horse floats over its spot and
# its shadow; side on (east) the hooves are nearly in a row, head or tail on they spread far
# (the Blender riders had 2.5 and 6 to 8 px at their smaller size).
RIDER_SINK = {0: 3, 1: 8, 2: 8, 6: 10, 7: 10}
GENERATED = (0, 1, 2, 6, 7)
MIRROR = {3: 1, 4: 0, 5: 7}
# anim: fps; "work" may reuse another anim's source
UNITS = {
    "gdl_peasant": {"idle": 6, "walk": 10, "work": ("attack", 9), "attack": 12},
    "gdl_spearman": {"idle": 6, "walk": 10, "attack": 12},
    "gdl_forest_archer": {"idle": 6, "walk": 10, "attack": 10},
    "pl_crossbow": {"idle": 6, "walk": 10, "attack": 10},
    "to_knight_brother": {"idle": 6, "walk": 10, "attack": 12},
    "hero_vytautas": {"idle": 6, "walk": 10, "attack": 12},
    "pl_kmet": {"idle": 6, "walk": 10, "work": ("attack", 9), "attack": 12},
    "to_peasant": {"idle": 6, "walk": 10, "work": ("attack", 9), "attack": 12},
    "to_knecht": {"idle": 6, "walk": 10, "attack": 12},
    "pl_spearman": {"idle": 6, "walk": 10, "attack": 12},
    "to_crossbow": {"idle": 6, "walk": 10, "attack": 10},
    "gdl_burgher": {"idle": 6, "walk": 10, "work": ("attack", 9), "attack": 12},
    "gdl_camp_servant": {"idle": 6, "walk": 10, "work": ("attack", 9), "attack": 12},
    "gdl_castle_archer": {"idle": 6, "walk": 10, "attack": 10},
    "gdl_samogitian": {"idle": 6, "walk": 10, "attack": 12},
    "gdl_hakownica": {"idle": 6, "walk": 10, "attack": 10},
    "pl_bowman": {"idle": 6, "walk": 10, "attack": 10},
    "pl_drab": {"idle": 6, "walk": 10, "attack": 12},
    "pl_foot_servant": {"idle": 6, "walk": 10, "attack": 12},
    "pl_handgunner": {"idle": 6, "walk": 10, "attack": 10},
    "to_halfbrother": {"idle": 6, "walk": 10, "attack": 12},
    "to_handgunner": {"idle": 6, "walk": 10, "attack": 10},
    "to_soldner": {"idle": 6, "walk": 10, "attack": 12},
    "gdl_light_horse": {"idle": 6, "walk": 10, "attack": 12},
    "gdl_lit_lance": {"idle": 6, "walk": 10, "attack": 12},
    "gdl_szlachta_lance": {"idle": 6, "walk": 10, "attack": 12},
    "pl_hussar": {"idle": 6, "walk": 10, "attack": 12},
    "pl_kopia": {"idle": 6, "walk": 10, "attack": 12},
    "pl_light_horse": {"idle": 6, "walk": 10, "attack": 12},
    "pl_pospolite": {"idle": 6, "walk": 10, "attack": 12},
    "to_merc_horse": {"idle": 6, "walk": 10, "attack": 12},
    "to_prussian_rider": {"idle": 6, "walk": 10, "attack": 12},
    "mo_boyar": {"idle": 6, "walk": 10, "attack": 12},
    "mo_syn_boyarsky": {"idle": 6, "walk": 10, "attack": 12},
    "mo_storozha": {"idle": 6, "walk": 10, "attack": 12},
    "mo_inok": {"idle": 6, "walk": 10, "attack": 12},
    "hero_keeper": {"idle": 6, "walk": 10},
    "hero_rumbaudas": {"idle": 6, "walk": 10, "attack": 12},
    "hero_anastasia": {"idle": 6, "walk": 10},
    "hero_ostrogski": {"idle": 6, "walk": 10, "attack": 12},
    "hero_jakub_kobylany": {"idle": 6, "walk": 10, "attack": 12},
    "hero_jungingen": {"idle": 6, "walk": 10, "attack": 12},
    "hero_stach": {"idle": 6, "walk": 10, "attack": 12},
    "hero_jagiello": {"idle": 6, "walk": 10, "attack": 12},
    "hero_gintaut": {"idle": 6, "walk": 10, "attack": 12},
    "hero_zyndram": {"idle": 6, "walk": 10, "attack": 12},
    "hero_wallenrode": {"idle": 6, "walk": 10, "attack": 12},
    "hero_lengvenis": {"idle": 6, "walk": 10, "attack": 12},
    "hero_plauen": {"idle": 6, "walk": 10, "attack": 12},
    "hero_casimir": {"idle": 6, "walk": 10, "attack": 12},
    "hero_kuchmeister": {"idle": 6, "walk": 10, "attack": 12},
    "hero_mikolaj": {"idle": 6, "walk": 10, "attack": 12},
}
RIDERS = {
    "to_knight_brother", "hero_vytautas", "gdl_light_horse", "gdl_lit_lance", "gdl_szlachta_lance",
    "pl_hussar", "pl_kopia", "pl_light_horse", "pl_pospolite", "to_merc_horse", "to_prussian_rider",
    "mo_boyar",
    "mo_syn_boyarsky",
    "mo_storozha",
    "hero_ostrogski",
    "hero_jakub_kobylany",
    "hero_jungingen",
    "hero_stach",
    "hero_jagiello",
    "hero_gintaut",
    "hero_zyndram",
    "hero_wallenrode",
    "hero_lengvenis",
    "hero_plauen",
    "hero_casimir",
    "hero_kuchmeister",
    "hero_mikolaj",
}
WHITE_CLAD = {
    "to_knight_brother", "to_knecht", "pl_spearman", "to_crossbow", "gdl_lit_lance", "pl_kopia",
    "pl_foot_servant", "hero_jungingen", "hero_wallenrode", "hero_kuchmeister", "hero_plauen",
    "hero_casimir", "hero_keeper", "hero_anastasia",
}  # white cloth, shields


def frame_of(uid: str) -> tuple[tuple[int, int], tuple[int, int]]:
    """Frame size and pivot (feet) of a unit's sheet."""
    return RIDER if uid in RIDERS else (FRAME, PIVOT)


def frames_of(gif: Path) -> list[np.ndarray]:
    return [np.array(f.convert("RGBA")) for f in ImageSequence.Iterator(Image.open(gif))]


def cut_white(a: np.ndarray, inner: bool = True) -> np.ndarray:
    """Alpha 0 on the white background: the near-white reached from the border and, with
    `inner`, every other near-white pixel too (the white between a bow and the body); units
    in white cloaks keep their inner white."""
    rgb = a[..., :3].astype(int)
    near = (rgb >= 232).all(-1)
    h, w = near.shape
    bg = np.zeros((h, w), bool)
    q = deque((y, x) for y in range(h) for x in (0, w - 1) if near[y, x])
    q.extend((y, x) for x in range(w) for y in (0, h - 1) if near[y, x])
    for y, x in q:
        bg[y, x] = True
    while q:
        y, x = q.popleft()
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < h and 0 <= xx < w and near[yy, xx] and not bg[yy, xx]:
                bg[yy, xx] = True
                q.append((yy, xx))
    if inner:
        bg |= near  # also the white caught between a bow and the body
    out = a.copy()
    out[..., 3] = np.where(bg | (a[..., 3] < 128), 0, 255)
    out[out[..., 3] == 0, :3] = 0
    return out


def feet(a: np.ndarray) -> tuple[int, int]:
    """Centre x of the figure and the row under its lowest pixel."""
    m = a[..., 3] > 0
    ys, xs = np.nonzero(m)
    return (int(xs.min()) + int(xs.max()) + 1) // 2, int(ys.max()) + 1


def place(a: np.ndarray, dx: int, dy: int, frame: tuple[int, int] = FRAME) -> np.ndarray:
    out = np.zeros((frame[1], frame[0], 4), np.uint8)
    h, w = a.shape[:2]
    x0, y0 = dx, dy
    sx0, sy0 = max(0, -x0), max(0, -y0)
    tx0, ty0 = max(0, x0), max(0, y0)
    cw = min(w - sx0, frame[0] - tx0)
    ch = min(h - sy0, frame[1] - ty0)
    out[ty0:ty0 + ch, tx0:tx0 + cw] = a[sy0:sy0 + ch, sx0:sx0 + cw]
    return out


def team_of(a: np.ndarray) -> np.ndarray:
    """LA mask: a 3 px belt band at the waist, lit by the cloth under it; skin is left out."""
    la = np.zeros(a.shape[:2] + (2,), np.uint8)
    m = a[..., 3] > 0
    if not m.any():
        return la
    ys = np.nonzero(m.any(1))[0]
    top, bottom = int(ys[0]), int(ys[-1])
    wy = top + int((bottom - top) * 0.52)
    r, g, b = (a[..., i].astype(int) for i in range(3))
    skin = (r > 150) & (r - b > 45) & (g > 90) & (r > g)
    band = np.zeros_like(m)
    band[wy - 1: wy + 2] = True
    sel = band & m & ~skin
    lum = (0.3 * r + 0.59 * g + 0.11 * b)
    la[..., 0] = np.clip(150 + lum * 0.45, 0, 255).astype(np.uint8)
    la[..., 1] = np.where(sel, 255, 0)
    return la


def build(src: Path, out: Path, uid: str) -> None:
    spec = UNITS[uid]
    frame, pivot = frame_of(uid)
    names = list(spec)
    cols = 0
    rows: dict[tuple[str, int], list[np.ndarray]] = {}
    for anim in names:
        source = spec[anim][0] if isinstance(spec[anim], tuple) else anim
        for g in GENERATED:
            fr = [cut_white(f, uid not in WHITE_CLAD) for f in frames_of(src / f"{uid}_{source}_g{g}.gif")]
            rows[(anim, g)] = fr
            cols = max(cols, len(fr))
    # one shift per facing, from the first idle frame, so the feet stay put across anims
    shift = {}
    for g in GENERATED:
        fx, fy = feet(rows[("idle", g)][0])
        sink = RIDER_SINK[g] if uid in RIDERS else 0
        shift[g] = (pivot[0] - fx, pivot[1] - fy + sink)
    color = np.zeros((frame[1] * 8 * len(names), frame[0] * cols, 4), np.uint8)
    team = np.zeros(color.shape[:2] + (2,), np.uint8)
    shadow = np.zeros(color.shape[:2] + (2,), np.uint8)
    meta_anims = {}
    tops = []
    for ai, anim in enumerate(names):
        fps = spec[anim][1] if isinstance(spec[anim], tuple) else spec[anim]
        n = len(rows[(anim, GENERATED[0])])
        meta_anims[anim] = {"row": ai * 8, "frames": n, "fps": fps}
        for facing in range(8):
            g = MIRROR.get(facing, facing)
            dx, dy = shift[g]
            for i in range(n):
                fr = rows[(anim, g)][min(i, len(rows[(anim, g)]) - 1)]
                f = place(fr, dx, dy, frame)
                if facing in MIRROR:
                    f = np.roll(f[:, ::-1], 1, axis=1).copy()  # mirror about the pivot column
                y0, x0 = (ai * 8 + facing) * frame[1], i * frame[0]
                color[y0:y0 + frame[1], x0:x0 + frame[0]] = f
                team[y0:y0 + frame[1], x0:x0 + frame[0]] = team_of(f)
                im = Image.fromarray(f, "RGBA")
                shadow[y0:y0 + frame[1], x0:x0 + frame[0]] = np.array(shadow_of(im, pivot[1]))
                ys = np.nonzero((f[..., 3] > 0).any(1))[0]
                if len(ys):
                    tops.append(int(ys[0]))
    dest = out / "units" / uid
    dest.mkdir(parents=True, exist_ok=True)
    Image.fromarray(color, "RGBA").save(dest / "color.png", optimize=True)
    Image.fromarray(team, "LA").save(dest / "team.png", optimize=True)
    Image.fromarray(shadow, "LA").save(dest / "shadow.png", optimize=True)
    meta = {"frame": list(frame), "pivot": list(pivot), "scale": 1.0, "anims": meta_anims,
            "bar_y": pivot[1] - int(np.percentile(tops, 10)) + 3,  # px above the feet, as render.py "rows_per_anim": 8,
            "facing": "row offset = UnitView.facing (0 east, clockwise, 2 south)"}
    (dest / "sheet.json").write_text(json.dumps(meta, indent=1))
    write_pick(str(dest))
    print(f"{uid}: {color.shape[1]}x{color.shape[0]}, {meta_anims}")


def portrait(out: Path, icons: Path, uid: str) -> None:
    """Panel icon (ui/icons/units/<id>.png, 128x128): head and shoulders of the unit facing
    south, enlarged in whole pixel steps (no smoothing) on the units' slate plate, the belt
    in the faction colour."""
    from tools.art import icons as ic

    dest = out / "units" / uid
    meta = json.loads((dest / "sheet.json").read_text())
    fw, fh = meta["frame"]
    row = meta["anims"]["idle"]["row"] + 2
    box = (0, row * fh, fw, (row + 1) * fh)
    color = Image.open(dest / "color.png").convert("RGBA").crop(box)
    team = Image.open(dest / "team.png").convert("RGBA").crop(box)
    rgb = ic.FACTION_TEAM.get(uid.split("_")[0], (217, 51, 38))
    fig = Image.alpha_composite(color, ic._tint(team, rgb))
    bb = fig.getchannel("A").getbbox()
    top = bb[1]
    h = int((bb[3] - bb[1]) * 0.62)  # head to the belt and a little below
    left, right = bb[0], bb[2]
    if uid in RIDERS:  # the rider from the helmet to the saddle, centred on the head
        h = int((bb[3] - bb[1]) * 0.42)
        a = np.array(fig.getchannel("A"))[top:top + 6] > 0
        hx = int(np.nonzero(a.any(0))[0].mean())
        left, right = max(bb[0], hx - h // 2 - 4), min(bb[2], hx + h // 2 + 4)
    fig = fig.crop((left, top, right, top + h))
    k = max(1, min((ic.SIZE - 8) // fig.width, (ic.SIZE - 4) // fig.height))
    fig = fig.resize((fig.width * k, fig.height * k), Image.NEAREST)
    tile = ic._plate("unit")
    tile.alpha_composite(fig, ((ic.SIZE - fig.width) // 2, ic.SIZE - fig.height))
    tile.save(icons / "units" / f"{uid}.png", optimize=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="art_src/pixel_iso/full/units")
    ap.add_argument("--out", default="art/sprites")
    ap.add_argument("--icons", default="ui/icons")
    ap.add_argument("ids", nargs="*")
    a = ap.parse_args()
    for uid in a.ids or [u for u in UNITS if (Path(a.src) / f"{u}_idle_g0.gif").exists()]:
        build(Path(a.src), Path(a.out), uid)
        if not (Path("art_src/pixellab/portraits") / uid).is_dir():  # PixelLab portraits win (pl_icons)
            portrait(Path(a.out), Path(a.icons), uid)


if __name__ == "__main__":
    main()
