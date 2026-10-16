"""Building kit: the shared materials of the visual assets doc (log, thatch, shingle, brick,
roof tile, plaster with timber framing, stone) and the parts buildings are put together from.

Conventions: a builder makes its model around the origin, the footprint centred on it; the
camera looks from +X/-Y, so the faces it sees are -Y (front left on screen) and +X (front
right): doors, windows and yards go there."""

import math
import random

from tools.art import shapes as S


def mats():
    return {
        "logs": S.mat("logs", "#8a6b47", 0.85, noise=0.35),
        "logs_old": S.mat("logs_old", "#6f5a42", 0.9, noise=0.35),
        "plank": S.mat("plank", "#9a7a52", 0.85, noise=0.3),
        "earth": S.mat("earth", "#6f5a3d", 1.0, noise=0.3),
        "stone": S.mat("stone", "#7d776c", 0.9, noise=0.35),
        "thatch": S.mat("thatch", "#b19a5c", 1.0, noise=0.45),
        "shingle": S.mat("shingle", "#6e5a3f", 0.9, noise=0.4),
        "brick": S.brick("brick", "#9c3f27"),
        "brick_dark": S.brick("brick_dark", "#6e2c1c", "#9e9080"),
        "tile": S.brick("roof_tile", "#b04e2c", "#5a2a18", width=0.3, row=0.22, rough=0.7),
        "plaster": S.mat("plaster", "#e2dccb", 0.95, noise=0.12),
        "timber": S.mat("timber", "#3e2c1e", 0.85, noise=0.2),
        "dark": S.mat("dark", "#1d1712", 1.0),
        "door": S.mat("door", "#4a3624", 0.9, noise=0.2),
        "iron": S.mat("iron", "#5c5e60", 0.45, metal=0.8),
        "rope": S.mat("rope", "#c9b98e", 1.0),
        "straw": S.mat("straw", "#d2b56a", 1.0, noise=0.4),
        "hay": S.mat("hay", "#b8a24f", 1.0, noise=0.5),
        "sack": S.mat("sack", "#c2ad86", 1.0, noise=0.2),
        "clay": S.mat("clay", "#9a6a48", 1.0, noise=0.35),
        "charcoal": S.mat("charcoal", "#222020", 1.0, noise=0.3),
        "fire": S.mat("fire_glow", "#ff9a2a", 0.5),
        "green": S.mat("field_green", "#5f8a35", 1.0, noise=0.4),
        "grain": S.mat("field_grain", "#b39a4e", 1.0, noise=0.45),
        "soil": S.mat("soil", "#5a4630", 1.0, noise=0.35),
        "ash": S.mat("ash", "#3d3833", 1.0, noise=0.4),
        "team": S.team_mat(),
    }


def yard(half_w, half_d, material):
    """Trodden ground under a building, a little larger than its footprint (named "yard" so
    stages leave it alone)."""
    return S.box("yard", (half_w * 2 + 0.3, half_d * 2 + 0.3, 0.04), (0, 0, 0.02), material)


def gable_roof(name, w, d, h, over, z, material, parent=None, along_y=False, thick=0.1):
    """Gable roof over a w x d (x, y) body; the ridge runs along X, or along Y."""
    holder = S.empty(name, (0, 0, z), parent)
    if along_y:
        roof = S.prism_roof(name + "_roof", d, w, h, over, (0, 0, 0), material, holder)
        roof.rotation_euler = (0, 0, math.pi / 2)
    else:
        roof = S.prism_roof(name + "_roof", w, d, h, over, (0, 0, 0), material, holder)
    S.solidify(roof, thick)
    return holder


def hip_roof(name, w, d, h, over, z, material, parent=None):
    """Hipped (four-slope) roof; a pyramid when w == d."""
    hw, hd = w / 2 + over, d / 2 + over
    r = max(0.0, (hw - hd)) if w >= d else 0.0
    q = max(0.0, (hd - hw)) if d > w else 0.0
    verts = [(-hw, -hd, 0), (hw, -hd, 0), (hw, hd, 0), (-hw, hd, 0), (-r, -q, h), (r, q, h)]
    faces = [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4), (0, 3, 2, 1)]
    if d > w:
        faces = [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5), (0, 3, 2, 1)]
    roof = S.poly(name + "_roof", verts, faces, material, parent, (0, 0, z))
    S.solidify(roof, 0.08)
    return roof


def gable_wall(name, w, h, loc, rot_z, material, parent=None, thick=0.12):
    """Triangular gable filling (in the local XZ plane, turned by rot_z)."""
    g = S.poly(name, [(-w / 2, 0, 0), (w / 2, 0, 0), (0, 0, h)], [(0, 1, 2)], material, parent, loc)
    g.rotation_euler = (0, 0, rot_z)
    S.solidify(g, thick)
    return g


def stepped_gable(name, w, h, loc, rot_z, m, parent=None, steps=5, thick=0.35):
    """Brick stepped gable of the Backsteingotik with white plastered blind niches."""
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = (0, 0, rot_z)
    sh = h / steps
    # The plain gable behind the steps, so no gap shows between the steps and the roof.
    gable_wall(f"{name}_gable_back", w - 0.1, h, (0, thick * 0.3, 0), 0.0, m["brick"], holder, thick=0.12)
    for i in range(steps):
        sw = w * (1.0 - i / steps) - 0.1
        S.box(f"{name}_gable_{i}", (sw, thick, sh + 0.25), (0, 0, i * sh + sh / 2 + 0.12), m["brick"], holder)
        # Each step ends in a little pinnacle.
        for x in (-sw / 2 + 0.1, sw / 2 - 0.1):
            S.cyl(f"{name}_gable_pin_{i}_{x:.1f}", 0.09, 0.02, 0.35, (x, 0, (i + 1) * sh + 0.2), m["brick"],
                  holder, seg=4, smooth=False)
    count = max(1, int(w / 0.9))
    for k in range(count):
        x = -w / 2 + (k + 0.5) * w / count
        top = (h - h / steps) * (1.0 - abs(x) / (w / 2)) - 0.3
        if top > 0.6:
            S.box(f"{name}_gable_niche_{k}", (0.32, 0.04, top - 0.3), (x, -thick / 2 - 0.02, 0.3 + (top - 0.3) / 2),
                  m["plaster"], holder)
    return holder


def window(name, w, h, loc, rot_z, material, parent=None, pointed=False):
    """A dark opening on a wall face (local XZ), pointed for a Gothic window."""
    verts = [(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h)]
    if pointed:
        verts = [(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h * 0.7), (0, 0, h), (-w / 2, 0, h * 0.7)]
    win = S.poly(name, verts, [tuple(range(len(verts)))], material, parent, loc)
    win.rotation_euler = (0, 0, rot_z)
    S.solidify(win, 0.04)
    return win


def front_openings(prefix, w, d, z, m, parent, door_x=0.0, windows=(), pointed=False, door=True,
                   east=()):
    """Door and windows on the -Y face (front left) and windows on the +X face (front right)."""
    if door:
        dw, dh = 0.8, 1.5 if not pointed else 1.8
        window(f"{prefix}_door", dw, dh, (door_x, -d / 2 - 0.03, z), 0.0, m["door"], parent, pointed)
    for i, (x, wz) in enumerate(windows):
        window(f"{prefix}_win_{i}", 0.4, 0.55 if not pointed else 1.0, (x, -d / 2 - 0.03, z + wz), 0.0,
               m["dark"], parent, pointed)
    for i, (y, wz) in enumerate(east):
        window(f"{prefix}_ewin_{i}", 0.4, 0.55 if not pointed else 1.0, (w / 2 + 0.03, y, z + wz), math.pi / 2,
               m["dark"], parent, pointed)


def fachwerk(prefix, w, d, h, z0, m, parent=None, bay=0.9):
    """Half-timbered walls: a plastered body with dark posts, rails and braces on every face."""
    body = S.empty(prefix, (0, 0, z0), parent)
    S.box(f"{prefix}_body", (w, d, h), (0, 0, h / 2), m["plaster"], body)
    t = 0.12
    faces = [((0, -d / 2 - 0.03), 0.0, w), ((0, d / 2 + 0.03), 0.0, w),
             ((-w / 2 - 0.03, 0), math.pi / 2, d), ((w / 2 + 0.03, 0), math.pi / 2, d)]
    for fi, ((cx, cy), rz, length) in enumerate(faces):
        side = S.empty(f"{prefix}_face_{fi}", (cx, cy, 0), body)
        side.rotation_euler = (0, 0, rz)
        n = max(1, round(length / bay))
        for k in range(n + 1):
            x = -length / 2 + k * length / n
            S.box(f"{prefix}_post_{fi}_{k}", (t, 0.06, h), (x, 0, h / 2), m["timber"], side)
        for z in (t / 2, h * 0.5, h - t / 2):
            S.box(f"{prefix}_rail_{fi}_{z:.2f}", (length + t, 0.06, t), (0, 0, z), m["timber"], side)
        for k in range(n):
            if k % 2 == 0:
                x0 = -length / 2 + k * length / n
                x1 = x0 + length / n
                ang = math.atan2(h * 0.5, x1 - x0)
                S.box(f"{prefix}_brace_{fi}_{k}", (math.hypot(x1 - x0, h * 0.5), 0.06, t * 0.8),
                      ((x0 + x1) / 2, 0, h * 0.25), m["timber"], side, rot=(0, -ang, 0))
    return body


def posts_shed(prefix, w, d, h, roof_mat, parent=None, loc=(0, 0, 0), m=None, lean=True, posts_mat=None):
    """Open shed on posts under a lean-to (or gable) roof."""
    m = m or mats()
    holder = S.empty(prefix, loc, parent)
    pm = posts_mat or m["logs"]
    for x in (-w / 2, 0, w / 2) if w > 3 else (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            hh = h if (not lean or y < 0) else h + 0.35
            S.cyl(f"{prefix}_post_{x:.1f}_{y:.1f}", 0.09, 0.08, hh, (x, y, 0), pm, holder, seg=7)
    if lean:
        hw, hd = w / 2 + 0.3, d / 2 + 0.35
        roof = S.poly(f"{prefix}_roof", [(-hw, -hd, h - 0.05), (hw, -hd, h - 0.05), (hw, hd, h + 0.65),
                                         (-hw, hd, h + 0.65)], [(0, 1, 2, 3)], roof_mat, holder)
        S.solidify(roof, 0.1)
    else:
        gable_roof(f"{prefix}_roof", w, d, 0.9, 0.3, h, roof_mat, holder)
    return holder


def rail_fence(prefix, pts, material, parent=None, h=0.95, closed=False):
    """Post-and-rail fence along a polyline of ground points."""
    holder = S.empty(prefix, (0, 0, 0), parent)
    seq = list(pts) + ([pts[0]] if closed else [])
    k = 0
    for (x0, y0), (x1, y1) in zip(seq, seq[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        n = max(1, round(length / 1.4))
        for i in range(n + 1):
            t = i / n
            S.cyl(f"{prefix}_post_{k}", 0.06, 0.05, h, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0), material,
                  holder, seg=6)
            k += 1
        for z in (h * 0.45, h * 0.85):
            S.cyl(f"{prefix}_rail_{k}_{z:.2f}", 0.035, 0.035, length, (x0, y0, z), material, holder,
                  rot=(0, math.pi / 2, ang), seg=5)
            # rot about Y then Z: the cylinder lies along +X turned by ang.
            k += 1
    return holder


def wattle(prefix, pts, m, parent=None, h=0.8):
    """Woven wattle fence: stakes with a continuous band of twigs."""
    holder = S.empty(prefix, (0, 0, 0), parent)
    for i, ((x0, y0), (x1, y1)) in enumerate(zip(pts, pts[1:])):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        S.box(f"{prefix}_band_{i}", (length, 0.06, h * 0.75), ((x0 + x1) / 2, (y0 + y1) / 2, h * 0.45),
              S.mat("wattle", "#7d6440", 1.0, noise=0.6), holder, rot=(0, 0, ang))
        n = max(1, round(length / 0.6))
        for k in range(n + 1):
            t = k / n
            S.cyl(f"{prefix}_stake_{i}_{k}", 0.035, 0.03, h, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0),
                  m["logs"], holder, seg=5)
    return holder


def barrel(name, loc, m, parent=None, r=0.28, h=0.75):
    b = S.cyl(name, r * 0.85, r * 0.85, h, loc, S.mat("barrel", "#7c5a36", 0.8, noise=0.3), parent, seg=12)
    mid = S.cyl(name + "_belly", r, r, h * 0.5, (0, 0, h * 0.25), b.data.materials[0], b, seg=12)
    for z in (0.08, h - 0.12):
        S.cyl(f"{name}_hoop_{z:.2f}", r * 0.88, r * 0.88, 0.05, (0, 0, z), m["iron"], b, seg=12)
    return mid


def sack(name, loc, m, parent=None, s=1.0):
    return S.ball(name, 0.22 * s, (loc[0], loc[1], loc[2] + 0.2 * s), m["sack"], parent, scale=(1.0, 0.85, 1.25))


def log_pile(prefix, loc, rot_z, length, count, m, parent=None, r=0.13):
    holder = S.empty(prefix, loc, parent)
    holder.rotation_euler = (0, 0, rot_z)
    n = count
    width = 1
    while n > 0:
        width += 1
        n -= width
    per = width
    i = 0
    z = 0
    while i < count:
        for k in range(per):
            if i >= count:
                break
            y = (k - (per - 1) / 2) * 2 * r
            S.cyl(f"{prefix}_{i}", r, r, length, (-length / 2, y, r + z * 1.7 * r), m["logs"], holder,
                  rot=(0, math.pi / 2, 0), seg=8)
            i += 1
        per -= 1
        z += 1
        if per <= 0:
            break
    return holder


def stump(name, loc, m, parent=None, r=0.25, seed=0):
    rng = random.Random(seed)
    s = S.cyl(name, r, r * 0.85, rng.uniform(0.25, 0.45), loc, m["logs_old"], parent, seg=8)
    return s


def flag(parent, loc, height, m, banner=False):
    """Pole with a player-colour flag (or a hanging banner on a crossbar)."""
    pole = S.cyl("flag_pole", 0.04, 0.03, height, loc, m["logs"], parent, seg=6)
    if banner:
        S.cyl("flag_bar", 0.02, 0.02, 0.8, (-0.4, 0, height - 0.15), m["logs"], pole, rot=(0, math.pi / 2, 0), seg=5)
        S.solidify(S.poly("flag", [(-0.38, 0, height - 0.15), (0.38, 0, height - 0.15), (0.38, 0, height - 1.0),
                                   (0, 0, height - 1.2), (-0.38, 0, height - 1.0)], [(0, 1, 2, 3, 4)], m["team"], pole),
                   0.02)
    else:
        S.solidify(S.poly("flag", [(0, 0, height - 0.05), (0.85, 0.05, height - 0.2), (0.8, 0.0, height - 0.47),
                                   (0, 0, height - 0.5)], [(0, 1, 2, 3)], m["team"], pole), 0.02)
    return pole


def cross_flag(parent, loc, height, m):
    """The Order's banner: white with a black cross, the player colour on the pole's pennon."""
    pole = S.cyl("flag_pole", 0.04, 0.03, height, loc, m["logs"], parent, seg=6)
    white = S.mat("order_white", "#ecebe4", 0.9)
    black = S.mat("order_black", "#151515", 0.9)
    S.solidify(S.poly("flag", [(0, 0, height - 0.1), (0.9, 0, height - 0.1), (0.9, 0, height - 0.75),
                               (0, 0, height - 0.75)], [(0, 1, 2, 3)], white, pole), 0.02)
    S.box("flag_cross_v", (0.14, 0.05, 0.55), (0.45, 0, height - 0.42), black, pole)
    S.box("flag_cross_h", (0.6, 0.05, 0.14), (0.45, 0, height - 0.42), black, pole)
    S.solidify(S.poly("flag_pennon", [(0, 0, height - 0.8), (0.55, 0, height - 0.88), (0, 0, height - 1.0)],
                      [(0, 1, 2)], m["team"], pole), 0.02)
    return pole
