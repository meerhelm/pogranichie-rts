"""The siege of Malbork («Корона 2. Мальборк, 1410»), on the figure of people.py, the horse of
beasts.py and the pieces of folk_1410.py / folk_crown_1410.py (armour of 1410), the brick of
kit.py and the tents of buildings_gdl.py (visual assets doc, «Юниты», «Герои», «Здания»; the
mission card docs/03-missions/13-crown_02_malbork_1410.md).

Units:
- hero_plauen (`sovereign`): Heinrich von Plauen, komtur of Świecie, the defender of Malbork, a
  man of about forty: a lean, hard, tired face (hollow cheeks, a heavy brow, a short grizzled
  beard, the shoulders a little bowed), an open bascinet, plate arms over mail, the knight
  brother's white mantle with the black cross and nothing else: no rank insignia, a plain
  white shield, the lance with a team pennon (attack `thrust`, like hero_order_k1), a dark
  bay horse under a white caparison with the cross. Beside him on foot a grey-mantled
  half-brother (the T cross of folk.to_halfbrother) with the Order's banner, white with the
  black cross.
- hero_town_envoys (`civilian`, like folk_1410.Envoys): three burghers of the Prussian towns
  walking as one unit in good dark cloth: an elder in a long black-blue gown with a fur
  collar and a chaperon, holding out a letter with a hanging red seal; one in a dark brown
  gown with a felt hat; one in a dark green gown with a hood. No town arms are drawn (the
  card names four towns; whose envoys these are the game does not say). Idle and walk only.
- nt_gdansk_shipwright: a Gdańsk shipman of the garrison: a short tunic of dark wool, a
  leather apron to the knees, a knitted cap with a rolled brim, a broad shipwright's axe in
  the right hand and a hammer in the left (works and attacks with a `swing`: the work is his
  spiking of a bombard). Team belt and hem.

Buildings:
- to_wall (1x1): the Order's brick town wall: Gothic red brick on a dark brick plinth,
  crenellated on both sides of the fighting walk, a whitewashed frieze band in the player
  colour, arrow slits. Built like gdl_wall: the middle pier (`to_wall`) and the half-cell arm
  toward each neighbour in the line (`to_wall_e/w/n/s`), joined by BuildingLayer. The lower
  courses are separate bands (the site rises band by band); the upper wall with its parapet is
  one joined block, so a damaged wall loses it whole instead of leaving merlons floating.
- pl_lazaret (2x2, as the catalog footprint; the visual doc says 3x3): the field infirmary:
  a long ridge tent with red and white trim, a smaller tent, two stretchers, a cauldron over
  a fire on a tripod and a kettle on stones, linen drying on a line, a water barrel, straw
  bedding, the Crown's flag.

Map props (one view, colour and shadow; bigger frames in PROP_FRAMES):
- prop_church: St John's parish church of the burned town (it survived the fire of 24 July):
  a brick Gothic hall under a tall tile roof, buttresses, pointed windows, a stepped east
  gable, a square west tower under a tile pyramid; soot above the windows and the west half
  of the nave roof burned to black rafters.
- prop_ruins: what is left of burned town houses: a blackened brick gable wall with a ragged
  top and an empty window, a broken side wall, charred beams leaning and fallen, a heap of
  brick rubble and ash.
"""

import math
import random

from tools.art import beasts, buildings_gdl, folk, kit, people
from tools.art import shapes as S
from tools.art.buildings_pl import _bands, crown_flag
from tools.art.buildings_pl import _m as _m_pl
from tools.art.folk_1410 import Envoys, Sovereign, _banner, _plate_arms
from tools.art.folk_crown_1410 import _m as _m_k1
from tools.art.folk_crown_1410 import _open_bascinet, _sword_hip


def _m():
    m = _m_k1()
    m.update({
        "grizzled": S.mat("grizzled_hair", "#5e5649", 0.9, noise=0.3),
        "gaunt": S.mat("gaunt_shadow", "#8e6650", 0.7),
        "gown_blue": S.mat("burgher_gown_blue", "#1f2430", 0.9, noise=0.1),
        "gown_brown": S.mat("burgher_gown_brown", "#3e2c22", 0.9, noise=0.12),
        "gown_green": S.mat("burgher_gown_green", "#25332a", 0.9, noise=0.12),
        "hose_dark": S.mat("hose_dark", "#2a2622", 0.9, noise=0.1),
        "felt_hat": S.mat("felt_hat", "#2b2520", 0.9, noise=0.12),
        "hood_grey": S.mat("burgher_hood", "#4a4640", 0.95, noise=0.15),
        "paper": S.mat("paper", "#e2d6b4", 0.9, noise=0.1),
        "seal": S.mat("seal_red", "#8e1e1a", 0.6),
        "wool_dark": S.mat("wool_dark", "#33363c", 1.0, noise=0.3),
        "knit": S.mat("knit_cap", "#5a4a3c", 1.0, noise=0.55),
        "apron": S.mat("leather_apron", "#6a4a30", 0.75, noise=0.3),
    })
    return m


# --- units ---------------------------------------------------------------------------------

def _hard_face(f, m):
    """A lean, tired face: hollow cheeks, a heavy brow, a short grizzled beard."""
    for x in (-1, 1):
        S.box(f"cheek_hollow_{x}", (0.03, 0.02, 0.05), (x * 0.06, 0.112, -0.04), m["gaunt"], f.head)
    S.box("brow", (0.13, 0.03, 0.022), (0, 0.118, 0.03), m["grizzled"], f.head)
    S.box("mouth", (0.05, 0.012, 0.01), (0, 0.124, -0.06), S.mat("lips_hard", "#6a4032", 0.8), f.head)
    S.ball("short_beard", 0.075, (0, 0.075, -0.095), m["grizzled"], f.head, scale=(1.0, 0.75, 0.75))


def hero_plauen():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m, m["grizzled"], beard=False)
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.3, m["order_black"])
    _open_bascinet(r, m)
    _hard_face(r, m)
    r.stoop = math.radians(5)  # weary, a little bowed
    beasts._lance(r, m, length=4.0, pennon=m["team"])
    folk._heater(r, m["order_white"], m, cross=False)  # a plain shield: no arms, no rank
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("dark_bay", "#4a3020", 0.9, noise=0.25), size=1.08)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    # The half-brother with the Order's banner on foot beside him.
    b = people.Figure("bearer")
    b.body(m["skin"], m["mail"], m["hose"], m["leather"], sleeve=m["mail"])
    b.hair(m["hair"])
    folk._legs_skirt(b, m["mail"], -0.36, 0.29)
    folk._cloak(b, m["order_grey"], bottom=-0.8)
    folk._cross("bearer_tau", b.chest, (-0.11, 0.24, 0.28), 0.17, m["order_black"], tau=True)
    folk._belt(b, m["team"], r=0.24)
    folk._chapel(b, m["steel"])

    def order_cross(cloth):  # on both faces of the cloth
        for k, y in enumerate((-0.012, 0.012)):
            folk._cross(f"banner_cross_{k}", cloth, (0, y, 0.0), 0.46, m["order_black"])

    _banner(b, m, m["order_white"], order_cross, width=0.7, height=0.62)
    return Sovereign("hero_plauen", h, r, m["team"], b)


def _burgher(name, m, gown, hair, beard=True):
    f = people.Figure(name)
    f.body(m["skin"], gown, m["hose_dark"], m["leather"], sleeve=gown)
    f.hair(hair, beard=beard)
    # A long gown to the ankles, belted, full sleeves.
    f.skirt("gown_skirt", 0.06, -0.8, 0.22, 0.34, gown)
    for side in ("l", "r"):
        S.cyl(f"sleeve_cuff_{side}", 0.085, 0.1, 0.12, (0, 0, -0.26), gown, f.j(f"elbow_{side}"), seg=8)
    folk._belt(f, m["team"], r=0.225)
    return f


def hero_town_envoys():
    m = _m()
    elder = _burgher("envoy_elder", m, m["gown_blue"], m["grey_hair"])
    S.cyl("fur_collar", 0.27, 0.2, 0.1, (0, -0.01, 0.43), m["fur"], elder.chest, seg=12)
    # A chaperon: a padded roll with the cloth falling to one side.
    S.cyl("chaperon_roll", 0.15, 0.15, 0.07, (0, -0.01, 0.07), m["gown_blue"], elder.head, seg=12)
    S.ball("chaperon_crown", 0.13, (0, -0.01, 0.09), m["gown_blue"], elder.head, scale=(1.0, 1.0, 0.6))
    S.box("chaperon_tail", (0.1, 0.06, 0.24), (0.13, -0.06, -0.05), m["gown_blue"], elder.head,
          rot=(0, math.radians(-12), 0))
    # The towns' letter held out: a folded sheet with a hanging red seal.
    elder.held_r = True
    let = S.empty("letter", (0, 0.05, -0.04), elder.j("hand_r"))
    S.box("letter_sheet", (0.2, 0.02, 0.14), (0, 0.02, 0.02), m["paper"], let)
    S.cyl("letter_cord", 0.004, 0.004, 0.08, (0, 0.03, -0.09), m["seal"], let, seg=3)
    S.cyl("letter_seal", 0.032, 0.032, 0.014, (0, 0.03, -0.11), m["seal"], let, rot=(math.pi / 2, 0, 0), seg=10)

    second = _burgher("envoy_hat", m, m["gown_brown"], m["hair"])
    S.cyl("hat_brim", 0.22, 0.21, 0.025, (0, -0.01, 0.07), m["felt_hat"], second.head, seg=16)
    S.cyl("hat_crown", 0.13, 0.12, 0.13, (0, -0.01, 0.08), m["felt_hat"], second.head, seg=12)

    third = _burgher("envoy_hood", m, m["gown_green"], m["dark_hair"], beard=False)
    folk._hood(third, m["hood_grey"])
    third.held_r = True
    S.box("purse", (0.08, 0.05, 0.1), (0, 0.04, -0.08), m["leather"], third.j("hand_r"))
    return Envoys("hero_town_envoys", [(elder, (0.42, 0.1)), (second, (-0.4, 0.05)), (third, (0.0, -0.45))])


def nt_gdansk_shipwright():
    m = _m()
    f = people.Figure("nt_gdansk_shipwright")
    wool = m["wool_dark"]
    f.body(m["skin"], wool, m["hose_dark"], m["leather"], sleeve=wool)
    f.hair(m["fair_hair"])
    folk._legs_skirt(f, wool, -0.34, 0.29)
    f.skirt("hem", -0.3, -0.36, 0.29, 0.295, m["team"])
    # A leather apron from the chest to the knees, tied at the neck.
    S.box("apron_bib", (0.26, 0.03, 0.34), (0, 0.17, 0.14), m["apron"], f.chest)
    S.box("apron_skirt", (0.36, 0.03, 0.52), (0, 0.255, -0.24), m["apron"], f.hips, rot=(math.radians(-6), 0, 0))
    S.cyl("apron_strap", 0.012, 0.012, 0.2, (0, 0.12, 0.36), m["leather"], f.chest, seg=4)
    folk._belt(f, m["team"], r=0.235)
    # A knitted cap: a rolled brim, a soft crown.
    S.cyl("cap_roll", 0.142, 0.142, 0.055, (0, -0.01, 0.04), m["knit"], f.head, seg=14)
    S.ball("cap_crown", 0.135, (0, -0.02, 0.07), m["knit"], f.head, scale=(1.0, 1.0, 0.8))
    # The broad shipwright's axe in the right hand, a hammer in the left.
    hand = f.j("hand_r")
    S.cyl("axe_haft", 0.018, 0.018, 0.72, (0, 0.0, -0.22), m["wood"], hand, rot=(math.radians(-15), 0, 0))
    S.box("axe_head", (0.025, 0.2, 0.11), (0, 0.1, -0.28), m["iron"], hand)
    S.box("axe_beard", (0.022, 0.06, 0.16), (0, 0.19, -0.33), m["iron"], hand)
    left = f.j("hand_l")
    S.cyl("hammer_haft", 0.014, 0.014, 0.36, (0, 0.0, -0.17), m["wood"], left, rot=(math.radians(-10), 0, 0), seg=6)
    S.box("hammer_head", (0.05, 0.14, 0.05), (0, 0.04, -0.17), m["iron"], left)
    return f


# --- the brick wall ------------------------------------------------------------------------

WALL_H = 3.8  # top of the wall body (the fighting walk)
WALL_D = 0.95  # thickness


LOW_H = 1.9  # the lower courses rise and fall band by band; above them the wall is one block


def _join(name, objs):
    """Joins meshes into one object, so the building stages take or keep the upper wall with its
    parapet whole (a parapet left floating over a missing course looked wrong)."""
    import bpy
    with bpy.context.temp_override(active_object=objs[0], object=objs[0], selected_objects=objs,
                                   selected_editable_objects=objs):
        bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def _merlons(prefix, xs, half_d, m, parent, w=0.3):
    """Merlons on both edges of the walk at `xs` (local X); returns them."""
    return [S.box(f"{prefix}_merlon_{x:.2f}_{side}", (w, 0.24, 0.62), (x, side * (half_d - 0.12), WALL_H + 0.81),
                  m["brick"], parent) for x in xs for side in (-1, 1)]


def _wall_arm(prefix, dx, dy, m, parent):
    """The half-cell arm from the pier toward (dx, dy): a brick wall in courses, the frieze, a
    breast wall with merlons on both sides."""
    ang = math.atan2(dy, dx)
    holder = S.empty(prefix, (dx * 0.75, dy * 0.75, 0), parent)
    holder.rotation_euler = (0, 0, ang)
    length = 0.5
    S.box(f"{prefix}_plinth", (length + 0.02, WALL_D + 0.12, 0.45), (0, 0, 0.225), m["brick_dark"], holder)
    _bands(f"{prefix}_course", length + 0.02, WALL_D, LOW_H - 0.45, 0.45, m["brick"], holder, bands=2)
    upper = [S.box(f"{prefix}_upper", (length + 0.02, WALL_D, WALL_H - LOW_H), (0, 0, (LOW_H + WALL_H) / 2),
                   m["brick"], holder)]
    for side in (-1, 1):
        upper.append(S.box(f"{prefix}_frieze_{side}", (length + 0.02, 0.02, 0.16),
                           (0, side * (WALL_D / 2 + 0.01), WALL_H - 0.35), m["team"], holder))
        upper.append(S.box(f"{prefix}_breast_{side}", (length + 0.02, 0.24, 0.5),
                           (0, side * (WALL_D / 2 - 0.12), WALL_H + 0.25), m["brick"], holder))
    upper.append(S.box(f"{prefix}_walk", (length + 0.02, WALL_D - 0.48, 0.06), (0, 0, WALL_H + 0.03), m["plank"],
                       holder))
    # One merlon per arm, centred so the crenels come out even along a line of cells.
    upper += _merlons(prefix, (0.03,), WALL_D / 2, m, holder)
    _join(f"{prefix}_upper", upper)
    return holder


def wall_piece(arm):
    """One piece of a brick wall cell: "" the middle pier, "e", "w", "n", "s" the half-cell arm
    toward that neighbour (+X, -X, +Y, -Y)."""

    def build():
        m = kit.mats()
        root = S.empty("to_wall")
        if arm == "":
            s = 1.02
            S.box("pier_plinth", (s + 0.14, s + 0.14, 0.45), (0, 0, 0.225), m["brick_dark"], root)
            _bands("pier_course", s, s, LOW_H - 0.45, 0.45, m["brick"], root, bands=2)
            upper = [S.box("pier_upper", (s, s, WALL_H - LOW_H), (0, 0, (LOW_H + WALL_H) / 2), m["brick"], root)]
            for i, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
                upper.append(S.box(f"pier_breast_{i}", (0.42, 0.42, 0.5),
                                   (x * (s / 2 - 0.21), y * (s / 2 - 0.21), WALL_H + 0.25), m["brick"], root))
                upper.append(S.box(f"pier_merlon_{i}", (0.3, 0.3, 0.62),
                                   (x * (s / 2 - 0.15), y * (s / 2 - 0.15), WALL_H + 0.81), m["brick"], root))
            upper.append(S.box("pier_walk", (s - 0.2, s - 0.2, 0.06), (0, 0, WALL_H + 0.03), m["plank"], root))
            for i, (x, y, rz) in enumerate(((0, -s / 2 - 0.01, 0.0), (s / 2 + 0.01, 0, math.pi / 2),
                                            (0, s / 2 + 0.01, 0.0), (-s / 2 - 0.01, 0, math.pi / 2))):
                upper.append(S.box(f"pier_frieze_{i}", (s + 0.02, 0.02, 0.16), (x, y, WALL_H - 0.35), m["team"],
                                   root, rot=(0, 0, rz)))
                # An arrow slit on each face (those toward the arms are hidden by them).
                upper.append(kit.window(f"pier_slit_{i}", 0.09, 0.6, (x * 1.02, y * 1.02, 2.2), rz, m["dark"], root))
            _join("pier_upper", upper)
            return root
        dx, dy = {"e": (1, 0), "w": (-1, 0), "n": (0, 1), "s": (0, -1)}[arm]
        _wall_arm("arm", dx, dy, m, root)
        return root

    return build


# --- the field infirmary -------------------------------------------------------------------

def _tent_trim(name, tent, w, d, h, mat):
    """A trim band along the foot of both slopes of a buildings_gdl._ridge_tent (named as its
    roof, so the stages treat it the same)."""
    t = 0.1
    ang = math.atan2(h, d / 2)
    for k, sgn in enumerate((-1, 1)):
        y, z = sgn * d / 2 * (1 - t), h * t
        n = (sgn * math.sin(ang), math.cos(ang))  # outward normal in (y, z)
        S.box(f"{name}_roof_trim_{k}", (w + 0.01, 0.025, 0.24), (0, y + n[0] * 0.03, z + n[1] * 0.03), mat, tent,
              rot=(sgn * (math.pi / 2 - ang), 0, 0))


def _stretcher(name, loc, rot_z, m, parent, blanket=None):
    s = S.empty(name, loc, parent)
    s.rotation_euler = (0, 0, rot_z)
    for y in (-0.27, 0.27):
        S.cyl(f"{name}_pole_{y}", 0.025, 0.025, 1.9, (-0.95, y, 0.12), m["logs"], s, rot=(0, math.pi / 2, 0), seg=6)
    for x in (-0.55, 0.55):
        for y in (-0.22, 0.22):
            S.box(f"{name}_foot_{x}_{y}", (0.04, 0.04, 0.1), (x, y, 0.05), m["logs"], s)
    S.box(f"{name}_canvas", (1.3, 0.52, 0.02), (0, 0, 0.13), m["sack"], s)
    if blanket is not None:
        S.box(f"{name}_blanket", (0.7, 0.5, 0.06), (-0.2, 0, 0.17), blanket, s)
        S.ball(f"{name}_pillow", 0.12, (0.5, 0, 0.18), m["straw"], s, scale=(1.0, 1.6, 0.5))
    return s


def pl_lazaret():
    rng = random.Random(1410)
    m = _m_pl()
    canvas = m["canvas"]
    linen = S.mat("linen_drying", "#efece3", 0.95, noise=0.08)
    root = S.empty("pl_lazaret")
    kit.yard(2.0, 2.0, S.mat("trodden_grass", "#6f7444", 1.0, noise=0.35)).parent = root
    # The long tent of the sick at the back, open to the front right; a smaller one at the left.
    big = buildings_gdl._ridge_tent("tent_big", (-0.25, 0.75, 0), 0.0, 2.7, 1.9, 1.8, canvas, m, root)
    _tent_trim("tent_big", big, 2.7, 1.9, 1.8, m["court_red"])
    small = buildings_gdl._ridge_tent("tent_small", (-1.3, -0.95, 0), -math.pi / 2, 1.3, 1.2, 1.2, canvas, m, root)
    _tent_trim("tent_small", small, 1.3, 1.2, 1.2, m["court_red"])
    # Straw bedding and a sick man's blanket showing at the big tent's mouth.
    S.box("straw_bed", (0.7, 1.1, 0.1), (0.75, 0.75, 0.05), m["straw"], root, rot=(0, 0, 0.05))
    # Two stretchers in front, one with a blanket.
    _stretcher("stretcher_a", (0.3, -1.35, 0), 0.04, m, root, blanket=S.mat("blanket", "#7a6a52", 1.0, noise=0.3))
    _stretcher("stretcher_b", (0.4, -1.85, 0), -0.06, m, root)
    # The cauldron over the fire on a tripod, a kettle on stones beside it.
    fx, fy = 1.35, -0.5
    for i in range(7):
        a = i * math.tau / 7
        S.rock(f"fire_stone_{i}", 0.1, (fx + math.cos(a) * 0.33, fy + math.sin(a) * 0.33, 0.04), m["stone"], root,
               seed=i + 40)
    S.cyl("fire", 0.16, 0.02, 0.4, (fx, fy, 0.06), m["fire"], root, seg=6, smooth=False)
    for i in range(3):
        a = i * math.tau / 3 + 0.4
        S.cyl(f"tripod_{i}", 0.022, 0.02, 1.3, (fx + math.cos(a) * 0.42, fy + math.sin(a) * 0.42, 0), m["logs_old"],
              root, rot=(math.sin(a) * 0.33, -math.cos(a) * 0.33, 0), seg=5)
    S.cyl("cauldron_chain", 0.008, 0.008, 0.35, (fx, fy, 0.85), m["iron"], root, seg=3)
    pot = S.mat("cauldron", "#2e2c2a", 0.5, metal=0.6)
    S.cyl("cauldron", 0.24, 0.2, 0.3, (fx, fy, 0.55), pot, root, seg=12)
    S.cyl("cauldron_broth", 0.21, 0.21, 0.01, (fx, fy, 0.82), S.mat("broth", "#6a5a3a", 0.3), root, seg=12)
    S.cyl("kettle", 0.13, 0.11, 0.18, (1.75, -1.3, 0.0), pot, root, seg=10)
    for i in range(3):
        a = i * math.tau / 3
        S.rock(f"kettle_stone_{i}", 0.07, (1.75 + math.cos(a) * 0.15, -1.3 + math.sin(a) * 0.15, 0.03), m["stone"],
               root, seed=i + 60)
    # Linen drying on a line between two posts along the right side.
    lx, y0, y1 = 1.8, 0.0, 1.85
    for y in (y0, y1):
        S.cyl(f"line_post_{y}", 0.035, 0.03, 1.45, (lx, y, 0), m["logs"], root, seg=6)
    S.cyl("line_rope", 0.008, 0.008, y1 - y0, (lx, y0, 1.38), m["rope"], root, rot=(-math.pi / 2, 0, 0), seg=3)
    for k, (yc, wd, hg) in enumerate(((0.3, 0.42, 0.62), (0.82, 0.48, 0.72), (1.38, 0.4, 0.55))):
        S.box(f"linen_{k}", (0.02, wd, hg), (lx, yc, 1.38 - hg / 2), linen, root, rot=(0, rng.uniform(-0.06, 0.06), 0))
    # Water barrel, a basket of rags, a pile of folded linen by the small tent.
    kit.barrel("barrel", (-0.55, -0.2, 0), m, root, r=0.24, h=0.65)
    S.cyl("basket", 0.2, 0.17, 0.22, (-0.5, -1.75, 0), m["wicker"], root, seg=10)
    for k in range(3):
        S.box(f"folded_linen_{k}", (0.32, 0.26, 0.06), (-1.75, 0.15, 0.03 + 0.06 * k), linen, root,
              rot=(0, 0, 0.1 * k))
    crown_flag(root, (-1.8, 1.8, 0), 3.4, m)
    return root


# --- map props -----------------------------------------------------------------------------

def _burnt_brick():
    return S.brick("brick_burnt", "#5a2a1e", "#4a4440")


def _sooty_brick():
    return S.brick("brick_sooty", "#332019", "#3a3430")


def _ash_patch(name, rx, ry, loc, parent, seed=0, color="#433d36"):
    """A flat patch of ash and burnt ground with a ragged edge."""
    rng = random.Random(seed)
    n = 18
    verts = [(0, 0, 0)] + [(math.cos(i * math.tau / n) * rx * rng.uniform(0.75, 1.05),
                            math.sin(i * math.tau / n) * ry * rng.uniform(0.75, 1.05), 0) for i in range(n)]
    faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
    S.solidify(S.poly(name, verts, faces, S.mat(f"{name}_ash", color, 1.0, noise=0.5), parent, loc), 0.02)


def _soot_plume(name, x, y, z, w, h, rz, parent):
    """Soot licked up a wall face from an opening: a dark tongue widening upward."""
    mat = S.mat("soot_plume", "#45342c", 1.0, noise=0.7)
    outline = [(-w * 0.12, 0, 0), (w * 0.12, 0, 0), (w * 0.45, 0, h * 0.45), (w * 0.2, 0, h), (-w * 0.1, 0, h * 0.7),
               (-w * 0.4, 0, h * 0.5)]
    p = S.poly(name, outline, [(0, 1, 2, 3, 4, 5)], mat, parent, (x, y, z))
    p.rotation_euler = (0, 0, rz)
    S.solidify(p, 0.02)


def prop_church():
    m = _m_pl()
    char = S.mat("charred_beam", "#1e1a17", 1.0, noise=0.4)
    root = S.empty("prop_church")
    _ash_patch("ground_ash", 7.0, 4.2, (-0.6, 0, 0.0), root, seed=5, color="#55503f")
    # The nave along X: a brick hall, its east end with the stepped gable toward the front right.
    nx, w, d, h, rh = 0.9, 8.0, 5.0, 5.6, 5.4
    nave = S.empty("nave", (nx, 0, 0), root)
    S.box("nave_plinth", (w + 0.15, d + 0.15, 0.4), (0, 0, 0.2), m["brick_dark"], nave)
    S.box("nave_walls", (w, d, h), (0, 0, h / 2), m["brick"], nave)
    kit.stepped_gable("east_gable", d + 0.2, rh + 0.6, (w / 2, 0, h), math.pi / 2, m, nave, steps=6)
    # The roof: the east half tiled, the west half burned down to black rafters on charred
    # tiles, a few rafters broken.
    half = w / 2
    east = kit.gable_roof("roof_east", half, d, rh, 0.15, h, m["tile"], nave)
    east.location.x = half / 2
    ang = math.atan2(d / 2, rh)
    slope = math.hypot(rh, d / 2)
    burnt_tile = S.mat("tile_charred", "#3a2a22", 1.0, noise=0.6)

    def on_slope(name, x, size_x, side, f0, f1, thick, mat, lift=0.0):
        """A board on the west slope `side` from fraction f0 to f1 of the way eave to ridge."""
        fm = (f0 + f1) / 2
        y, z = side * d / 2 * (1 - fm), h + rh * fm
        y += side * math.cos(ang) * lift
        z += math.sin(ang) * lift
        S.box(name, (size_x, thick, slope * (f1 - f0)), (x, y, z), mat, nave, rot=(side * ang, 0, 0))

    S.box("nave_burnt_inside", (half, d - 0.1, 0.05), (-half / 2, 0, h + 0.02), char, nave)
    for side in (-1, 1):
        on_slope(f"roof_burnt_eave_{side}", -half / 2 + 0.3, half - 0.6, side, 0.0, 0.3, 0.1, burnt_tile)
        on_slope(f"roof_burnt_patch_{side}", -0.7, 1.2, side, 0.25, 0.75, 0.1, burnt_tile)
    for k in range(7):
        x = -half + 0.3 + k * 0.55
        for side in (-1, 1):
            if (k, side) in ((2, -1), (5, -1)):
                continue  # gaps where rafters fell in
            f1 = 0.55 if (k, side) in ((1, -1), (4, 1)) else 1.0
            on_slope(f"rafter_{k}_{side}", x, 0.12, side, 0.0, f1, 0.12, char, lift=0.1)
    S.box("ridge_beam_burnt", (half * 0.7, 0.14, 0.14), (-half * 0.55, 0, h + rh + 0.05), char, nave)
    # Buttresses and tall pointed windows on the south (-Y) and east faces; soot above them.
    for i in range(4):
        x = -w / 2 + 1.0 + i * 2.0
        S.box(f"buttress_{i}", (0.45, 0.55, h * 0.8), (x, -d / 2 - 0.25, h * 0.4), m["brick_dark"], nave)
        if i < 3:
            wx = x + 1.0
            kit.window(f"win_{i}", 0.75, 2.6, (wx, -d / 2 - 0.03, 1.6), 0.0, m["dark"], nave, pointed=True)
            S.box(f"win_{i}_frame", (0.95, 0.03, 0.1), (wx, -d / 2 - 0.02, 1.55), m["limestone"], nave)
            _soot_plume(f"win_{i}_soot", wx, -d / 2 - 0.035, 4.05, 0.9, 1.3, 0.0, nave)
    kit.window("east_win", 1.0, 3.2, (w / 2 + 0.03, 0, 1.5), math.pi / 2, m["dark"], nave, pointed=True)
    kit.window("south_door", 1.0, 2.0, (half - 0.2, -d / 2 - 0.03, 0.0), 0.0, m["door"], nave, pointed=True)
    _soot_plume("south_door_soot", half - 0.2, -d / 2 - 0.035, 1.95, 1.1, 1.4, 0.0, nave)
    # The west tower: square, under a tile pyramid, blind niches, the belfry openings.
    tx, ts, th = nx - w / 2 - 1.5, 3.0, 12.0
    tw = S.empty("tower", (tx, 0, 0), root)
    S.box("tower_plinth", (ts + 0.2, ts + 0.2, 0.5), (0, 0, 0.25), m["brick_dark"], tw)
    S.box("tower_shaft", (ts, ts, th), (0, 0, th / 2), m["brick"], tw)
    S.box("tower_cornice", (ts + 0.2, ts + 0.2, 0.25), (0, 0, th + 0.1), m["brick_dark"], tw)
    for z in (3.5, 6.5):
        for k, (x, y, rz) in enumerate(((-0.6, -ts / 2 - 0.02, 0.0), (0.6, -ts / 2 - 0.02, 0.0))):
            kit.window(f"tower_niche_{z}_{k}", 0.6, 2.0, (x, y, z), rz, m["plaster"], tw, pointed=True)
    for k in (-0.55, 0.55):
        kit.window(f"tower_bell_s_{k}", 0.45, 1.5, (k, -ts / 2 - 0.03, 9.6), 0.0, m["dark"], tw, pointed=True)
        kit.window(f"tower_bell_e_{k}", 0.45, 1.5, (ts / 2 + 0.03, k, 9.6), math.pi / 2, m["dark"], tw, pointed=True)
    kit.window("tower_door", 1.1, 2.3, (0, -ts / 2 - 0.03, 0.0), 0.0, m["door"], tw, pointed=True)
    _soot_plume("tower_soot", 0, -ts / 2 - 0.035, 2.25, 1.4, 1.1, 0.0, tw)
    kit.hip_roof("tower_roof", ts, ts, 3.6, 0.2, th + 0.2, m["tile"], tw)
    S.box("tower_cross_v", (0.08, 0.08, 0.8), (0, 0, th + 4.1), m["iron"], tw)
    S.box("tower_cross_h", (0.45, 0.08, 0.08), (0, 0, th + 4.25), m["iron"], tw)
    # Rubble of the burned houses against the churchyard.
    rng = random.Random(24)
    bb = _burnt_brick()
    for i in range(10):
        S.rock(f"rubble_{i}", rng.uniform(0.15, 0.3), (rng.uniform(-3, 5), rng.uniform(-3.5, -3.0), 0.05), bb, root,
               seed=i + 100)
    return root


def prop_ruins():
    rng = random.Random(1410)
    bb = _burnt_brick()
    sooty = _sooty_brick()
    char = S.mat("charred_beam", "#1e1a17", 1.0, noise=0.4)
    root = S.empty("prop_ruins")
    _ash_patch("ash_ground", 1.6, 1.4, (0, 0, 0), root, seed=3)
    # The gable wall of a burned house along X at the back: narrow columns of brick with a
    # ragged top under the slope of the lost gable, soot-black above, an empty window.
    wall = S.empty("gable_wall", (0.0, 0.7, 0), root)
    cols, width = 16, 2.6
    for k in range(cols):
        x = -width / 2 + (k + 0.5) * width / cols
        top = 3.1 - abs(x) * 1.5 + rng.uniform(-0.45, 0.2)
        if 3 <= k <= 4:
            top -= 1.1  # a bite out of the wall
        top = max(0.35, top)
        low = min(top, 0.9 + rng.uniform(0, 0.6))
        S.box(f"gable_col_{k}", (width / cols + 0.005, 0.34, low), (x, 0, low / 2), bb, wall)
        if top > low:
            S.box(f"gable_col_{k}_top", (width / cols + 0.005, 0.34, top - low), (x, 0, low + (top - low) / 2), sooty,
                  wall)
    kit.window("gable_window", 0.42, 0.75, (0.35, -0.19, 1.3), 0.0, S.mat("hole_dark", "#120f0d", 1.0), wall)
    S.box("gable_lintel", (0.66, 0.38, 0.1), (0.35, 0, 2.1), char, wall)
    # A broken side wall coming forward on the left, lower toward the front.
    for k in range(8):
        y = 0.5 - k * 0.2
        top = max(0.2, 1.8 - k * 0.22 + rng.uniform(-0.3, 0.2))
        S.box(f"side_col_{k}", (0.32, 0.205, top), (-1.24, y, top / 2), bb if top < 1.1 else sooty, root)
    # Charred beams: one leaning on the gable, one fallen across the rubble, stubs of joists.
    S.box("beam_lean", (0.15, 0.15, 2.5), (0.9, 0.1, 1.05), char, root, rot=(math.radians(30), math.radians(10), 0.3))
    S.box("beam_fallen", (2.0, 0.14, 0.14), (0.0, -0.75, 0.22), char, root, rot=(0, math.radians(-7), 0.45))
    for k, x in enumerate((-0.75, 0.0)):
        S.box(f"joist_stub_{k}", (0.11, 0.42, 0.11), (x, 0.36, 1.75 - abs(x) * 0.3), char, root,
              rot=(math.radians(rng.uniform(-12, 12)), 0, 0))
    # A heap of rubble: broken brick, a few blackened tiles, dust.
    S.ball("rubble_heap", 0.75, (0.3, -0.2, 0.0), S.mat("rubble_dust", "#4e3c32", 1.0, noise=0.6), root,
           scale=(1.15, 0.9, 0.6))
    for i in range(26):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 0.85)
        x, y = 0.3 + math.cos(a) * r, -0.2 + math.sin(a) * r * 0.8
        z = max(0.04, 0.42 - r * 0.45)
        S.rock(f"rubble_{i}", rng.uniform(0.1, 0.2), (x, y, z), bb if i % 4 else sooty, root, seed=i + 7)
    tile = S.mat("tile_charred", "#3a2a22", 1.0, noise=0.6)
    for i in range(6):
        S.box(f"tile_shard_{i}", (0.22, 0.16, 0.025), (rng.uniform(-0.9, 1.2), rng.uniform(-1.2, -0.4), 0.05), tile,
              root, rot=(rng.uniform(-0.3, 0.3), 0, rng.uniform(0, 3)))
    return root


UNITS = {"hero_town_envoys": hero_town_envoys, "nt_gdansk_shipwright": nt_gdansk_shipwright}
MOUNTED_UNITS = {"hero_plauen": hero_plauen}
## id: (builder, cells, metres of height the frame must hold)
BUILDINGS = {"to_wall": (wall_piece(""), (1, 1), 6), "pl_lazaret": (pl_lazaret, (2, 2), 5)}
for _arm in "ewns":
    BUILDINGS[f"to_wall_{_arm}"] = (wall_piece(_arm), (1, 1), 6)
PROPS = {"prop_church": prop_church, "prop_ruins": prop_ruins}
## The church and its tower need a big frame; the ruins a little more room than the default.
PROP_FRAMES = {"prop_church": (860, 980, (300, 660)), "prop_ruins": (400, 480, (160, 320))}
