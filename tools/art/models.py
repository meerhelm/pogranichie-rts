"""Trial batch of code-built assets, keyed by catalog id (visual assets doc, queue П).

Each builder makes its model at the origin; units face +Y. Descriptions follow the doc:
- gdl_peasant: linen shirt to the knees with a belt, grey woollen svita, bast shoes with
  foot wraps, felt cap; an axe in hand.
- gdl_spearman: quilted jacket, plain iron cap, rogatina (broad head with a crossbar),
  Lithuanian hand shield (60-70 cm trapezoid with a long groove, on the arm), bast shoes.
- gdl_house: smoke hut (курная изба) of logs under thatch, no chimney, 2x2 cells.
- gdl_town_center: «Двор» of the first age: big log house on a raised basement, palisade
  with a gate and a watchtower, thatch, 4x4 cells.
- nt_pine / nt_birch: trees for forest cells.
"""

import math
import random

from tools.art import people
from tools.art import shapes as S


def _palette():
    return {
        "skin": S.mat("skin", "#c99a7a", 0.6),
        "hair": S.mat("hair", "#5a3e26", 0.9, noise=0.2),
        "linen": S.mat("linen", "#ddd3bb", 0.9, noise=0.12),
        "svita": S.mat("svita", "#77736b", 0.95, noise=0.18),
        "wraps": S.mat("wraps", "#bdb4a0", 0.95, noise=0.15),
        "lapti": S.mat("lapti", "#a88a52", 0.9, noise=0.35),
        "felt": S.mat("felt", "#6b5440", 0.95, noise=0.15),
        "trousers": S.mat("trousers", "#5c5548", 0.95, noise=0.15),
        "quilt": S.mat("quilt", "#9a7b4f", 0.95, noise=0.3),
        "iron": S.mat("iron", "#8a8c8e", 0.38, metal=0.85),
        "wood": S.mat("wood", "#7a5a3a", 0.8, noise=0.25),
        "hide": S.mat("hide", "#8c6a45", 0.75, noise=0.3),
        "team": S.team_mat(),
    }


def gdl_peasant():
    m = _palette()
    f = people.Figure("gdl_peasant")
    f.body(m["skin"], m["svita"], m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["hair"])
    f.skirt("shirt_hem", 0.05, -0.43, 0.2, 0.27, m["linen"])
    f.skirt("svita_skirt", 0.06, -0.3, 0.21, 0.29, m["svita"])
    f.skirt("svita_hem", -0.27, -0.33, 0.29, 0.295, m["team"])
    S.cyl("collar", 0.09, 0.085, 0.05, (0, 0, 0.47), m["linen"], f.chest, seg=10)
    belt = S.cyl("belt", 0.22, 0.22, 0.07, (0, 0, 0.03), m["team"], f.hips, seg=12)
    belt.scale = (1.0, 0.78, 1.0)
    S.cyl("cap", 0.135, 0.12, 0.09, (0, 0, 0.05), m["felt"], f.head, seg=12)
    S.ball("cap_top", 0.12, (0, 0, 0.14), m["felt"], f.head, scale=(1, 1, 0.55))
    # Axe in the right hand, head forward.
    hand = f.j("hand_r")
    S.cyl("axe_haft", 0.016, 0.016, 0.62, (0, 0.0, -0.2), m["wood"], hand, rot=(math.radians(-15), 0, 0))
    S.box("axe_head", (0.025, 0.14, 0.09), (0, 0.08, -0.25), m["iron"], hand)
    return f


def _lithuanian_shield(parent, m):
    """Trapezoid 0.66 m tall, 0.42 at the top and 0.32 at the bottom, its middle pressed
    into a long groove; a player-colour band runs down the groove."""
    h, wt, wb, g = 0.66, 0.21, 0.16, 0.035
    holder = S.empty("shield", (-0.24, 0.27, -0.14), parent)
    holder.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    # Halves bent back toward the centre line, which sits `g` deeper than the edges.
    left = S.poly("shield_l", [(-wb, 0, 0), (-0.04, g, 0), (-0.04, g, h), (-wt, 0, h)],
                  [(0, 1, 2, 3)], m["hide"], holder)
    right = S.poly("shield_r", [(0.04, g, 0), (wb, 0, 0), (wt, 0, h), (0.04, g, h)],
                   [(0, 1, 2, 3)], m["hide"], holder)
    band = S.poly("shield_band", [(-0.04, g, 0), (0.04, g, 0), (0.04, g, h), (-0.04, g, h)],
                  [(0, 1, 2, 3)], m["team"], holder)
    for part in (left, right, band):
        S.solidify(part, 0.02)
    return holder


def gdl_spearman():
    m = _palette()
    f = people.Figure("gdl_spearman")
    f.body(m["skin"], m["quilt"], m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["hair"])
    f.skirt("quilt_skirt", 0.06, -0.36, 0.22, 0.3, m["quilt"])
    belt = S.cyl("belt", 0.23, 0.23, 0.05, (0, 0, 0.04), m["hide"], f.hips, seg=12)
    belt.scale = (1.0, 0.8, 1.0)
    # Plain iron cap: a low cone over a brim ring.
    S.cyl("cap_rim", 0.142, 0.138, 0.045, (0, 0, 0.03), m["iron"], f.head, seg=14)
    S.cyl("cap", 0.138, 0.02, 0.18, (0, 0, 0.07), m["iron"], f.head, seg=14)
    # Rogatina held upright in the right hand (forearm forward), point up.
    f.held_r = True
    hand = f.j("hand_r")
    spear = S.empty("rogatina", (0, 0, -0.02), hand)
    spear.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("shaft", 0.019, 0.017, 2.05, (0, 0, -0.85), m["wood"], spear, seg=8)
    S.poly("spear_head",
           [(0, 0, 1.2), (0.05, 0, 1.33), (0, 0, 1.55), (-0.05, 0, 1.33)],
           [(0, 1, 2, 3)], m["iron"], spear)
    S.solidify(spear.children[-1], 0.012)
    S.cyl("crossbar", 0.012, 0.012, 0.22, (-0.11, 0, 1.15), m["wood"], spear,
          rot=(0, math.pi / 2, 0), seg=6)
    f.held_l = True
    _lithuanian_shield(f.chest, m)
    return f


# --- buildings ---------------------------------------------------------------------------

def _thatch_roof(name, w, d, h, over, z, parent=None):
    thatch = S.mat("thatch", "#b19a5c", 1.0, noise=0.45)
    roof = S.prism_roof(name, w, d, h, over, (0, 0, z), thatch, parent)
    S.solidify(roof, 0.12)
    ridge = S.mat("thatch_ridge", "#8f7b45", 1.0, noise=0.4)
    S.cyl(name + "_ridge", 0.09, 0.09, w + 2 * over, (-(w / 2 + over), 0, h - 0.02),
          ridge, roof, rot=(0, math.pi / 2, 0), seg=8)
    return roof


def _srub(prefix, w, d, h, r, z0, logs, parent=None, seed=0):
    """Four log walls of a w x d frame starting at height z0."""
    S.log_wall(prefix + "_s", w, h, r, (0, -d / 2, z0), 0.0, logs, parent, seed)
    S.log_wall(prefix + "_n", w, h, r, (0, d / 2, z0), 0.0, logs, parent, seed + 1)
    S.log_wall(prefix + "_w", d, h, r, (-w / 2, 0, z0 + r * 0.9), math.pi / 2, logs, parent, seed + 2)
    S.log_wall(prefix + "_e", d, h, r, (w / 2, 0, z0 + r * 0.9), math.pi / 2, logs, parent, seed + 3)


def _gable(name, w, h, loc, rot_z, material, parent=None):
    """Triangular boarded gable standing at `loc` (in the XZ plane, turned by rot_z)."""
    g = S.poly(name, [(-w / 2, 0, 0), (w / 2, 0, 0), (0, 0, h)], [(0, 1, 2)], material, parent, loc)
    g.rotation_euler = (0, 0, rot_z)
    S.solidify(g, 0.06)
    return g


def _flag(parent, loc, height, m):
    pole = S.cyl("flag_pole", 0.03, 0.025, height, loc, m["wood"], parent, seg=6)
    S.poly("flag", [(0, 0, height - 0.05), (0.75, 0.05, height - 0.18), (0.7, 0.0, height - 0.42),
                    (0, 0, height - 0.45)], [(0, 1, 2, 3)], m["team"], pole).location = (0, 0, 0)
    S.solidify(pole.children[-1], 0.02)
    return pole


def _ground_patch(name, half, material):
    """Trodden earth under a building, slightly larger than its footprint."""
    return S.box(name, (half * 2 + 0.3, half * 2 + 0.3, 0.04), (0, 0, 0.02), material)


def gdl_house():
    m = _palette()
    logs = S.mat("logs", "#8a6b47", 0.85, noise=0.35)
    earth = S.mat("earth", "#6f5a3d", 1.0, noise=0.3)
    root = S.empty("gdl_house")
    _ground_patch("yard", 2.0, earth).parent = root
    w, d = 3.1, 2.8
    _srub("wall", w, d, 1.75, 0.13, 0.04, logs, root, seed=3)
    for y in (-d / 2, d / 2):
        _gable(f"gable_{y}", w + 0.2, 1.5, (0, y, 1.85), 0.0, logs, root)
    roof = _thatch_roof("roof", d, w, 1.55, 0.35, 1.85, root)
    roof.rotation_euler = (0, 0, math.pi / 2)  # ridge along Y: gable faces the viewer
    S.box("door", (0.62, 0.06, 1.15), (0.55, -d / 2 - 0.12, 0.62), S.mat("door", "#4a3624", 0.9, noise=0.2), root)
    # Smoke-blackened lintel over the door of a smoke hut.
    S.box("soot", (0.8, 0.05, 0.25), (0.55, -d / 2 - 0.13, 1.35), S.mat("soot", "#2e2620", 1.0), root)
    S.box("window", (0.3, 0.05, 0.2), (-0.7, -d / 2 - 0.12, 1.05), S.mat("dark", "#1d1712", 1.0), root)
    S.cyl("stump", 0.22, 0.2, 0.4, (1.55, -1.75, 0.0), logs, root, seg=9)
    for i in range(5):
        S.cyl(f"firewood_{i}", 0.08, 0.08, 0.9, (-1.75 + i * 0.17, -1.6, 0.08 + (i % 2) * 0.13),
              logs, root, rot=(math.pi / 2, 0, 0), seg=7)
    _flag(root, (1.75, 1.6, 0), 3.2, m)
    return root


def _palisade(prefix, half, gate_w, logs, parent):
    rng = random.Random(11)
    stake_r = 0.13
    step = stake_r * 1.9
    for side in range(4):
        n = int(2 * half / step)
        for i in range(n):
            t = -half + (i + 0.5) * step
            if side == 0 and abs(t) < gate_w / 2:
                continue
            x, y = [(t, -half), (half, t), (-t, half), (-half, -t)][side]
            hgt = 1.55 + rng.uniform(-0.12, 0.12)
            st = S.cyl(f"{prefix}_{side}_{i}", stake_r, stake_r * 0.9, hgt, (x, y, 0), logs, parent, seg=7)
            S.cyl(f"{prefix}_{side}_{i}_tip", stake_r * 0.9, 0.01, 0.3, (0, 0, hgt), logs, st, seg=7)


def gdl_town_center():
    m = _palette()
    logs = S.mat("logs", "#8a6b47", 0.85, noise=0.35)
    earth = S.mat("earth", "#6f5a3d", 1.0, noise=0.3)
    stone = S.mat("stone", "#7d776c", 0.9, noise=0.35)
    root = S.empty("gdl_town_center")
    _ground_patch("yard", 4.0, earth).parent = root
    _palisade("pal", 3.85, 1.9, logs, root)
    # Gate: two posts and a lintel with a small roof in the south (front-left) wall.
    for x in (-1.0, 1.0):
        S.cyl(f"gate_post_{x}", 0.17, 0.16, 2.6, (x, -3.85, 0), logs, root, seg=8)
    S.box("gate_beam", (2.4, 0.3, 0.25), (0, -3.85, 2.55), logs, root)
    gate_roof = S.prism_roof("gate_roof", 2.6, 0.6, 0.45, 0.15, (0, -3.85, 2.67), S.mat("shingle", "#6e5a3f", 0.9, noise=0.4), root)
    S.solidify(gate_roof, 0.06)
    # Main house on a raised basement (подклеть) of stones and logs.
    house = S.empty("hall", (0.3, 0.6, 0), root)
    S.box("basement", (4.2, 3.4, 0.55), (0, 0, 0.28), stone, house)
    _srub("hall", 4.0, 3.2, 2.3, 0.14, 0.55, logs, house, seed=21)
    _thatch_roof("hall_roof", 4.0, 3.2, 1.9, 0.45, 2.95, house)
    for x in (-2.0, 2.0):
        _gable(f"hall_gable_{x}", 3.4, 1.85, (x, 0, 2.95), math.pi / 2, logs, house)
    # Porch with steps on the long side facing the viewer.
    S.box("porch", (1.2, 0.8, 0.5), (0.4, -2.0, 0.27), logs, house)
    for i in range(3):
        S.box(f"step_{i}", (1.0, 0.25, 0.12), (0.4, -2.5 - i * 0.22, 0.42 - i * 0.14), logs, house)
    S.box("hall_door", (0.7, 0.06, 1.3), (0.4, -1.75, 1.2), S.mat("door", "#4a3624", 0.9, noise=0.2), house)
    for x in (-1.2, 1.4):
        S.box(f"hall_win_{x}", (0.35, 0.06, 0.25), (x, -1.75, 1.9), S.mat("dark", "#1d1712", 1.0), house)
    # Watchtower in the north-west (back-left) corner, with a flag.
    tower = S.empty("tower", (-2.85, 2.85, 0), root)
    for dx in (-0.5, 0.5):
        for dy in (-0.5, 0.5):
            S.cyl(f"tw_leg_{dx}_{dy}", 0.1, 0.09, 5.0, (dx, dy, 0), logs, tower, seg=7)
    S.box("tw_floor", (1.5, 1.5, 0.15), (0, 0, 4.4), logs, tower)
    for side, (x, y, sx, sy) in enumerate([(0, -0.7, 1.5, 0.1), (0, 0.7, 1.5, 0.1), (-0.7, 0, 0.1, 1.5), (0.7, 0, 0.1, 1.5)]):
        S.box(f"tw_rail_{side}", (sx, sy, 0.75), (x, y, 4.85), logs, tower)
    tw_roof = S.cyl("tw_roof", 1.15, 0.05, 1.1, (0, 0, 5.3), S.mat("shingle", "#6e5a3f", 0.9, noise=0.4), tower, seg=4, smooth=False)
    tw_roof.rotation_euler = (0, 0, math.pi / 4)
    for dx, dy in ((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)):
        S.cyl(f"tw_post_{dx}_{dy}", 0.06, 0.06, 0.9, (dx, dy, 4.45), logs, tower, seg=6)
    _flag(tower, (0, 0, 6.2), 1.4, m)
    # Yard clutter: a well and a cart wheel against the fence.
    S.cyl("well", 0.45, 0.45, 0.6, (2.3, -2.2, 0), logs, root, seg=10)
    S.cyl("well_water", 0.36, 0.36, 0.02, (2.3, -2.2, 0.55), S.mat("dark", "#1d1712", 1.0), root, seg=10)
    return root


# --- trees -------------------------------------------------------------------------------

def nt_pine(seed=1):
    rng = random.Random(seed)
    bark = S.mat("pine_bark", "#7a4a2c", 0.9, noise=0.35)
    needles = S.mat("pine_needles", "#2f5233", 0.9, noise=0.35)
    root = S.empty("nt_pine")
    h = 7.5 + rng.uniform(-1.0, 1.0)
    S.cyl("trunk", 0.22, 0.1, h, (0, 0, 0), bark, root, seg=8)
    # Scots pine: bare trunk, crown as a few uneven clumps near the top.
    for i in range(6):
        z = h * (0.58 + 0.07 * i)
        a = rng.uniform(0, math.tau)
        rr = (1.25 - i * 0.14) * rng.uniform(0.85, 1.1)
        off = 0.35 * (1 - i / 6)
        S.ball(f"crown_{i}", rr, (math.cos(a) * off, math.sin(a) * off, z), needles, root,
               scale=(1.0, 1.0, 0.55), seg=10)
    return root


def nt_birch(seed=2):
    rng = random.Random(seed)
    bark = S.mat("birch_bark", "#e2ddd2", 0.8, noise=0.45)
    leaves = S.mat("birch_leaves", "#6f8f3a", 0.9, noise=0.4)
    root = S.empty("nt_birch")
    h = 6.0 + rng.uniform(-0.6, 0.6)
    S.cyl("trunk", 0.16, 0.06, h, (0, 0, 0), bark, root, seg=8)
    for i in range(7):
        z = h * rng.uniform(0.5, 0.95)
        a = rng.uniform(0, math.tau)
        off = rng.uniform(0.2, 0.7)
        S.ball(f"crown_{i}", rng.uniform(0.7, 1.0), (math.cos(a) * off, math.sin(a) * off, z),
               leaves, root, scale=(1.0, 1.0, 1.25), seg=10)
    return root


UNITS = {"gdl_peasant": gdl_peasant, "gdl_spearman": gdl_spearman}
BUILDINGS = {"gdl_house": (gdl_house, 2), "gdl_town_center": (gdl_town_center, 4)}
TREES = {"nt_pine": nt_pine, "nt_birch": nt_birch}
