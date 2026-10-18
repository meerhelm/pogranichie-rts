"""The siege of Slutsk (ВКЛ 7, 1508): the townsfolk and lords of Slutsk, Glinski's envoy, the
Muscovite light gun, the castle wall and the rebels' ladders, on the figure of
people.py, the horse of beasts.py and the pieces of folk_1500.py (visual assets doc, «Юниты»,
«Герои ВКЛ и их противники», «Здания»; the mission card docs/03-missions/09-gdl_07_slutsk_1508.md).

Units:
- gdl_burgher: a townsman in a long cloth kaftan and a cap; the doc: «вёдра на коромысле или
  багор; в осаде топор». Drawn with a wooden bucket in the left hand and an axe in the right
  (attack `swing`, work: he douses fires and carries water).
- gdl_hakownica: a gunner with a heavy hook gun (гаковница) on his shoulder, the hook under
  the barrel; in battle he levels it (attack `crossbow`: aim, kick, lower). The doc's helper
  with the match is not drawn: one figure carries the gun and a smouldering match cord.
- hero_anastasia: Princess Anastasia of Slutsk, a mature widow: a dark rich dress to the
  ground, the white widow's kerchief and povoi, a short fur cloak over it. No portrait of her
  exists (the doc: do not take late drawings as a base): the face and colours are a guess.
  She does not fight: idle and walk only.
- hero_yuri_olelkovich: Prince Yuri, her son, about 16 (b. c. 1492), «доспех не по росту»: a
  slight rider in a too-big breastplate and an open sallet, a sabre drawn (attack `swing`), a
  grey horse with the team cloth.
- hero_glinski_envoy: Glinski's messenger: a rich travelling coat, a sword at the belt, a
  sealed charter (грамота) in the hand. A civilian: idle and walk only.
- mo_cannon: the Muscovite light gun: folk_1500.FieldGun with its two gunners dressed in
  undyed quilted tegilyai and fur-banded caps. The carriage is the same model (unpainted wood).

Buildings:
- gdl_wall (1x1): «Городня»: a wooden castle wall of log cribs (срубные клети) filled with
  earth, a fighting walk on top behind a plank breastwork with loopholes, a little roof over
  it. Built as palisade is: a middle piece (`gdl_wall`) and the half-cell arm toward each
  neighbour in the line (`gdl_wall_e/w/n/s`), joined in the game by BuildingLayer.

Map props:
- prop_well: a log well-frame (зруб) with a sweep (журавль), a bucket on the pole.
- prop_barrels: barrels and tubs of water stood ready on the walls against fire, a bucket.
- prop_ladders: the rebels' assault ladders by their workshops (the card: «мастерская лестниц»;
  the workshop itself is the Duchy's siege workshop): ladders leaning on a trestle and lying in
  a stack, poles, rope.
"""

import math
import random

from tools.art import beasts, folk, kit, people
from tools.art import shapes as S
from tools.art.folk_1500 import FieldGun, _kaftan, _m as _m1500, _sallet, _sabre_hip, _tegilyai
from tools.art.folk_1507 import _fur_cap, _sabre_drawn, _scabbard


def _m():
    m = _m1500()
    m.update({
        "burgher_cloth": S.mat("burgher_cloth", "#5a4a3a", 0.95, noise=0.2),
        "burgher_cap": S.mat("burgher_cap", "#4a3c30", 0.95, noise=0.2),
        "widow_dress": S.mat("widow_dress", "#2a1e26", 0.85, noise=0.08),
        "widow_white": S.mat("widow_white", "#ecebe4", 0.9, noise=0.05),
        "envoy_coat": S.mat("envoy_coat", "#2e4a5a", 0.85, noise=0.12),
        "grey_horse": S.mat("grey_horse", "#a8a49c", 0.9, noise=0.25),
        "bucket": S.mat("bucket", "#8a6a44", 0.9, noise=0.3),
        "match": S.mat("match_glow", "#e0702a", 0.6),
        "seal": S.mat("seal_red", "#8e1e1a", 0.6),
        "paper": S.mat("paper", "#e2d6b4", 0.9, noise=0.1),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _bucket(name, parent, loc, m, r=0.1, h=0.2):
    b = S.cyl(name, r, r * 0.85, h, loc, m["bucket"], parent, seg=10)
    S.cyl(f"{name}_hoop", r + 0.006, r + 0.006, 0.02, (0, 0, h * 0.75), m["iron"], b, seg=10)
    S.cyl(f"{name}_water", r * 0.92, r * 0.92, 0.01, (0, 0, h * 0.85), S.mat("water_dark", "#3a5a6a", 0.2), b,
          seg=10)
    return b


def _axe_in_hand(f, m):
    f.held_r = True
    hand = f.j("hand_r")
    S.cyl("axe_haft", 0.016, 0.016, 0.62, (0, 0.0, -0.2), m["wood"], hand, rot=(math.radians(-15), 0, 0))
    S.box("axe_head", (0.025, 0.14, 0.09), (0, 0.08, -0.25), m["iron"], hand)


# --- units ---------------------------------------------------------------------------------

def gdl_burgher():
    m = _m()
    f = people.Figure("gdl_burgher")
    cloth = m["burgher_cloth"]
    f.body(m["skin"], cloth, m["trousers"], m["leather"], sleeve=cloth)
    f.hair(m["hair"])
    _kaftan(f, m, cloth, buttons=m["leather"])
    folk._belt(f, m["team"])
    S.cyl("cap", 0.14, 0.13, 0.1, (0, -0.01, 0.05), m["burgher_cap"], f.head, seg=12)
    S.cyl("cap_band", 0.15, 0.15, 0.05, (0, -0.01, 0.03), m["fur"], f.head, seg=12)
    _axe_in_hand(f, m)
    f.held_l = True
    _bucket("bucket", f.j("hand_l"), (0, 0, -0.26), m)
    S.cyl("bucket_bail", 0.006, 0.006, 0.22, (0, 0, -0.08), m["iron"], f.j("hand_l"), seg=4)
    return f


def gdl_hakownica():
    m = _m()
    f = people.Figure("gdl_hakownica")
    f.body(m["skin"], m["quilt"], m["trousers"], m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["quilt"], -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    folk._belt(f, m["leather"])
    S.cyl("cap_rim", 0.142, 0.138, 0.045, (0, 0, 0.03), m["iron"], f.head, seg=14)
    S.cyl("cap", 0.138, 0.02, 0.16, (0, 0, 0.07), m["iron"], f.head, seg=14)
    # Powder flask and the match cord coiled at the belt.
    S.cyl("flask", 0.05, 0.04, 0.16, (0.22, 0.1, -0.2), m["leather"], f.hips, seg=8)
    S.cyl("match_coil", 0.07, 0.07, 0.03, (-0.22, 0.12, -0.08), m["rope"] if "rope" in m else m["leather"], f.hips,
          seg=10, rot=(math.pi / 2, 0, 0))
    # The heavy gun in both hands: a long iron barrel on a wooden stock, the hook under it.
    f.held_r = True
    f.held_l = True
    gun = S.empty("hakownica", (0, 0, 0), f.j("hand_r"))
    gun.rotation_euler = (math.radians(-70), 0, math.radians(20))
    S.box("stock", (0.07, 0.08, 0.6), (0, 0, -0.05), m["wood"], gun)
    S.cyl("barrel", 0.035, 0.03, 1.15, (0, 0.0, 0.2), m["iron"], gun, seg=8)
    S.cyl("muzzle", 0.042, 0.042, 0.05, (0, 0.0, 1.33), m["iron"], gun, seg=8)
    S.box("hook", (0.03, 0.16, 0.04), (0, 0.08, 0.95), m["iron"], gun)
    S.box("hook_tip", (0.03, 0.04, 0.1), (0, 0.15, 0.9), m["iron"], gun)
    S.ball("match_glow", 0.02, (0.04, -0.05, 0.2), m["match"], gun)
    return f


def hero_anastasia():
    m = _m()
    f = people.Figure("hero_anastasia")
    dress = m["widow_dress"]
    f.body(m["skin"], dress, dress, m["leather"], sleeve=dress)
    # A dress to the ground in two tiers, a gold-edged hem.
    f.skirt("dress_skirt", 0.06, -0.9, 0.21, 0.36, dress)
    f.skirt("dress_hem", -0.86, -0.9, 0.36, 0.365, m["gold"])
    folk._belt(f, m["team"])
    # The widow's white kerchief (плат) over the povoi, down over the shoulders and chest.
    S.ball("povoi", 0.15, (0, -0.06, 0.03), m["widow_white"], f.head, scale=(1.0, 1.0, 1.1))
    S.cyl("plat_drape", 0.25, 0.13, 0.32, (0, -0.02, 0.32), m["widow_white"], f.chest, seg=12)
    S.box("plat_chin", (0.16, 0.05, 0.1), (0, 0.11, -0.1), m["widow_white"], f.head)
    # A short fur-lined cloak (to the waist) over the dress.
    c = S.cyl("fur_cloak", 0.33, 0.25, 0.42, (0, -0.04, 0.0), m["crimson"], f.chest, seg=14)
    c.scale = (1.0, 0.82, 1.0)
    S.cyl("fur_cloak_edge", 0.335, 0.335, 0.05, (0, -0.04, 0.0), m["fur"], f.chest, seg=14).scale = (1.0, 0.82, 1.0)
    from tools.art.folk_1410 import _orthodox_cross
    _orthodox_cross("cross", f.chest, (0, 0.23, 0.3), 0.1, m["gold"])
    return f


def hero_yuri_olelkovich():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["trousers"], m["leather"], m, m["fair_hair"], beard=False)
    # A slight youth: smaller than a grown rider, his breastplate too big for him.
    r.root.scale = (0.92, 0.92, 0.92)
    S.cyl("breastplate", 0.25, 0.27, 0.42, (0, 0.01, 0.06), m["plate"], r.chest, seg=14).scale = (1.05, 0.85, 1.0)
    r.skirt("tunic_skirt", 0.06, -0.3, 0.23, 0.3, m["crimson"])
    folk._belt(r, m["team"], r=0.27)
    _sallet(r, m, m["plate"], bevor=False, open_face=True)
    _sabre_drawn(r, m)
    _scabbard(r, m)
    h = beasts.horse("horse", m["grey_horse"], size=0.97, mane=S.mat("mane_light", "#d8d4cc", 1.0, noise=0.3))
    return beasts.Mounted("hero_yuri_olelkovich", h, r, m["team"])


def hero_glinski_envoy():
    m = _m()
    f = people.Figure("hero_glinski_envoy")
    coat = m["envoy_coat"]
    f.body(m["skin"], coat, m["trousers"], S.mat("boots_yellow", "#a07a2a", 0.8, noise=0.2), sleeve=coat)
    f.hair(m["dark_hair"])
    _kaftan(f, m, coat, buttons=m["gold"], collar=m["fur"])
    folk._belt(f, m["gold"])
    _fur_cap(f, m, crown=m["crimson"])
    S.cyl("sword_hip", 0.015, 0.015, 0.8, (-0.24, -0.05, -0.55), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=5)
    S.box("sword_guard", (0.14, 0.03, 0.02), (-0.24, 0.0, 0.0), m["steel"], f.hips)
    # The charter: a rolled sheet with a hanging red seal, held out in the right hand.
    f.held_r = True
    ch = S.empty("charter", (0, 0.04, -0.04), f.j("hand_r"))
    S.cyl("charter_roll", 0.03, 0.03, 0.3, (-0.15, 0, 0), m["paper"], ch, rot=(0, math.pi / 2, 0), seg=8)
    S.cyl("charter_seal", 0.035, 0.035, 0.015, (0, 0.0, -0.1), m["seal"], ch, rot=(math.pi / 2, 0, 0), seg=10)
    return f


def _mo_crew_dress(g, m, role):
    poor = dict(m)
    poor["tegilyai"] = S.mat("tegilyai_poor", "#7a705c", 0.95, noise=0.35)
    poor["tegilyai_seam"] = S.mat("tegilyai_poor_seam", "#5a5242", 0.95, noise=0.25)
    g.body(m["skin"], poor["tegilyai"], m["trousers"], m["leather"])
    g.hair(m["hair"], beard=role == "gunner")
    _tegilyai(g, poor)
    folk._belt(g, m["team"])
    _fur_cap(g, m, crown=m["felt"])
    _sabre_hip(g, m, side=1)
    g.held_r = True
    if role == "gunner":
        ls = S.empty("linstock", (0, 0, -0.02), g.j("hand_r"))
        ls.rotation_euler = (math.radians(-80), 0, 0)
        S.cyl("linstock_staff", 0.016, 0.014, 1.3, (0, 0, -0.6), m["wood"], ls, seg=6)
        S.ball("match", 0.03, (0, 0, 0.72), S.mat("match_glow", "#e0702a", 0.6), ls)
    else:
        rm = S.empty("rammer", (0, 0, -0.02), g.j("hand_r"))
        rm.rotation_euler = (math.radians(-80), 0, 0)
        S.cyl("rammer_pole", 0.02, 0.02, 1.8, (0, 0, -0.85), m["wood"], rm, seg=6)


def mo_cannon():
    return FieldGun("mo_cannon", dress=_mo_crew_dress)


# --- the castle wall -------------------------------------------------------------------------

WALL_H = 2.6  # top of the crib (the fighting walk)


def _crib(prefix, x0, y0, x1, y1, m, parent, seed=0):
    """Log cribs filled with earth from (x0, y0) to (x1, y1): the face toward -Y/+X shows logs
    laid crosswise, a plank breastwork with loopholes on top, a lean-to roof over the walk."""
    rng = random.Random(seed)
    length = math.hypot(x1 - x0, y1 - y0)
    ang = math.atan2(y1 - y0, x1 - x0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    holder = S.empty(prefix, (cx, cy, 0), parent)
    holder.rotation_euler = (0, 0, ang)
    depth = 1.2
    logs = int(WALL_H / 0.26)
    for k in range(logs):
        z = 0.13 + k * 0.26
        for side in (-1, 1):
            S.cyl(f"{prefix}_log_{side}_{k}", 0.13, 0.13, length + 0.04, (-length / 2 - 0.02, side * depth / 2, z),
                  m["logs"] if rng.random() > 0.25 else m["logs_old"], holder, rot=(0, math.pi / 2, 0), seg=7)
    S.box(f"{prefix}_fill", (length, depth - 0.1, 0.2), (0, 0, WALL_H - 0.1), m["earth"], holder)
    S.box(f"{prefix}_walk", (length, depth, 0.08), (0, 0, WALL_H + 0.02), m["plank"], holder)
    # Breastwork of planks on the outer side with loopholes (gaps), the team band along it.
    n = max(1, int(length / 0.45))
    for i in range(n):
        if i % 3 == 1:
            continue
        x = -length / 2 + (i + 0.5) * length / n
        S.box(f"{prefix}_breast_{i}", (length / n - 0.02, 0.08, 0.95), (x, -depth / 2, WALL_H + 0.5), m["plank"],
              holder)
    S.box(f"{prefix}_breast_top", (length, 0.1, 0.1), (0, -depth / 2, WALL_H + 1.0), m["logs_old"], holder)
    S.box(f"{prefix}_band", (length, 0.03, 0.12), (0, -depth / 2 - 0.05, WALL_H + 0.3), m["team"], holder)
    # Lean-to roof over the walk from the breastwork to posts on the inner side.
    S.box(f"{prefix}_roof", (length + 0.05, depth + 0.3, 0.06), (0, 0.0, WALL_H + 1.45), m["shingle"], holder,
          rot=(math.radians(-14), 0, 0))
    for i in range(max(1, int(length / 0.9))):
        x = -length / 2 + (i + 0.5) * length / max(1, int(length / 0.9))
        S.cyl(f"{prefix}_post_{i}", 0.04, 0.04, 1.2, (x, depth / 2 - 0.05, WALL_H), m["logs"], holder, seg=5)
    return holder


def wall_piece(arm):
    """One piece of a wall cell: "" is the middle (a corner post of the cribs), "e", "w", "n",
    "s" the half-cell arm toward that neighbour (+X, -X, +Y, -Y)."""

    def build():
        m = kit.mats()
        root = S.empty("gdl_wall")
        if arm == "":
            S.box("crib_core", (1.0, 1.0, WALL_H), (0, 0, WALL_H / 2), m["logs"], root)
            S.box("crib_core_top", (1.1, 1.1, 0.1), (0, 0, WALL_H + 0.05), m["plank"], root)
            for i, (x, y) in enumerate(((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5))):
                S.cyl(f"corner_{i}", 0.15, 0.14, WALL_H + 0.2, (x, y, 0), m["logs_old"], root, seg=7)
            kit.hip_roof("core_roof", 1.3, 1.3, 0.5, 0.1, WALL_H + 1.2, m["shingle"], root)
            for i, (x, y) in enumerate(((-0.55, -0.55), (0.55, -0.55), (0.55, 0.55), (-0.55, 0.55))):
                S.cyl(f"core_post_{i}", 0.04, 0.04, 1.2, (x, y, WALL_H), m["logs"], root, seg=5)
            return root
        dx, dy = {"e": (1, 0), "w": (-1, 0), "n": (0, 1), "s": (0, -1)}[arm]
        _crib("crib", dx * 0.5, dy * 0.5, dx * 1.0, dy * 1.0, m, root, seed=ord(arm))
        return root

    return build


# --- the ladders ----------------------------------------------------------------------------

def _ladder(name, parent, loc, length, rot, m):
    lad = S.empty(name, loc, parent)
    lad.rotation_euler = rot
    for y in (-0.25, 0.25):
        S.cyl(f"{name}_rail_{y}", 0.045, 0.04, length, (0, y, 0), m["logs_old"], lad, seg=6)
    for k in range(int(length / 0.4)):
        S.cyl(f"{name}_rung_{k}", 0.025, 0.025, 0.5, (0, -0.25, 0.3 + k * 0.4), m["plank"], lad,
              rot=(-math.pi / 2, 0, 0), seg=4)
    return lad


def prop_ladders():
    m = kit.mats()
    root = S.empty("prop_ladders")
    # Finished assault ladders leaning on a trestle, two more lying in a stack, poles and rope.
    for x in (-0.6, 0.6):
        for y in (0.5, 1.1):
            S.cyl(f"trestle_{x}_{y}", 0.05, 0.05, 1.6, (x, y, 0), m["logs"], root, seg=5)
        S.box(f"trestle_bar_{x}", (0.1, 0.8, 0.1), (x, 0.8, 1.6), m["plank"], root)
    for i, x in enumerate((-0.7, 0.0, 0.7)):
        _ladder(f"ladder_lean_{i}", root, (x, -0.4, 0.0), 3.6, (math.radians(-22), 0, 0), m)
    for i in range(2):
        _ladder(f"ladder_lie_{i}", root, (-1.6, -1.3 - 0.62 * i, 0.06 + 0.09 * i), 3.2, (0, math.pi / 2, 0), m)
    kit.log_pile("poles", (1.4, -1.2, 0), math.pi / 2, 2.0, 4, m, root, r=0.07)
    S.cyl("rope_coil", 0.25, 0.25, 0.1, (1.2, 0.9, 0), m["rope"], root, seg=12)
    return root


# --- map props -----------------------------------------------------------------------------

def prop_well():
    m = kit.mats()
    mm = _m()
    root = S.empty("prop_well")
    # A low log frame with a lid half open.
    for i, (x, y, rot) in enumerate(((0, -0.45, 0.0), (0, 0.45, 0.0), (-0.45, 0, math.pi / 2), (0.45, 0, math.pi / 2))):
        S.log_wall(f"well_wall_{i}", 1.0, 0.75, 0.1, (x, y, 0.0 + (0.08 if i >= 2 else 0.0)), rot, m["logs"], root,
                   seed=i + 7)
    S.box("well_water", (0.8, 0.8, 0.02), (0, 0, 0.5), S.mat("water_dark", "#2a3a44", 0.2), root)
    S.box("well_lid", (0.9, 0.45, 0.05), (0, 0.22, 0.85), m["plank"], root)
    # The sweep: a forked post, the long pole, a bucket on a rod at its end.
    S.cyl("sweep_post", 0.08, 0.07, 2.4, (1.3, 0.6, 0), m["logs_old"], root, seg=7)
    pole = S.empty("sweep_pole", (1.3, 0.6, 2.35), root)
    pole.rotation_euler = (0, math.radians(-62), math.radians(200))
    S.cyl("sweep_beam", 0.05, 0.035, 4.2, (0, 0, -1.4), m["logs_old"], pole, seg=6)
    S.box("sweep_weight", (0.25, 0.25, 0.3), (0, 0, -1.45), m["stone"], pole)
    S.cyl("sweep_rod", 0.015, 0.015, 1.6, (0.0, -0.1, 0.0), m["logs"], root, seg=4)
    _bucket("sweep_bucket", root, (0.0, -0.1, 0.9), mm)
    return root


def prop_barrels():
    m = kit.mats()
    mm = _m()
    root = S.empty("prop_barrels")
    kit.barrel("barrel_0", (-0.35, 0.1, 0), m, root)
    kit.barrel("barrel_1", (0.3, 0.3, 0), m, root, r=0.26, h=0.7)
    S.cyl("tub", 0.4, 0.36, 0.35, (0.2, -0.45, 0), mm["bucket"], root, seg=14)
    S.cyl("tub_water", 0.36, 0.36, 0.01, (0.2, -0.45, 0.3), S.mat("water_dark", "#3a5a6a", 0.2), root, seg=14)
    _bucket("bucket", root, (-0.45, -0.5, 0), mm)
    S.cyl("hook_pole", 0.025, 0.025, 2.2, (0.7, -0.1, 0.05), m["logs_old"], root, rot=(0, math.radians(84), 0.3),
          seg=5)
    return root


UNITS = {
    "gdl_burgher": gdl_burgher,
    "gdl_hakownica": gdl_hakownica,
    "hero_anastasia": hero_anastasia,
    "hero_glinski_envoy": hero_glinski_envoy,
}
MOUNTED_UNITS = {"hero_yuri_olelkovich": hero_yuri_olelkovich}
WAGONS = {"mo_cannon": mo_cannon}
## id: (builder, cells, metres of height the frame must hold)
BUILDINGS = {"gdl_wall": (wall_piece(""), (1, 1), 5)}
for _arm in ("e", "w", "n", "s"):
    BUILDINGS[f"gdl_wall_{_arm}"] = (wall_piece(_arm), (1, 1), 5)
PROPS = {"prop_well": prop_well, "prop_barrels": prop_barrels, "prop_ladders": prop_ladders}
