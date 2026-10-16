"""People on foot (visual assets doc, «Юниты»), on the figure of people.py.

- gdl_forest_archer: green-brown clothes, a hood, a longbow, a quiver, a knife; no armour.
- gdl_znakharka: an old woman: linen shirt and belt, dark svita, white namitka, herbs, staff.
- gdl_castle_archer: chapel-de-fer, quilted coat, longbow, red cloak.
- gdl_camp_servant: short svita, an axe in the belt, a shovel, a sack on the back.
- to_peasant: German village clothes: a gugel hood, hose, leather shoes.
- to_halfbrother: grey cloak with a black T-cross, mail, chapel helmet, spear.
- to_knecht: open bascinet, mail over a gambeson, spear, shield with a black cross.
- to_crossbow: a crossbowman, a black cross on the tabard, a pavise on the back.
- to_priest: the Order's white cloak over dark vestments, tonsure, a book.
- to_tithe_collector: a dry official in a dark cloak, a black cross on the sleeve, a tally
  board, a sack.
- nt_villager: a local peasant.
- hero_rumbaudas: a Samogitian hunter in a sheepskin coat, with a bow and an axe.
- hero_keeper: a woman in white linen with a dark cloak, greying hair.
"""

import math

from tools.art import people
from tools.art import shapes as S
from tools.art.models import _palette


def _m():
    m = _palette()
    m.update({
        "forest": S.mat("forest_cloth", "#5a5e3a", 0.95, noise=0.2),
        "forest_dark": S.mat("forest_dark", "#4a3f2c", 0.95, noise=0.2),
        "dark_svita": S.mat("dark_svita", "#3f362e", 0.95, noise=0.18),
        "white_linen": S.mat("white_linen", "#e8e2d2", 0.9, noise=0.1),
        "red_cloak": S.mat("red_cloak", "#8e2a22", 0.9, noise=0.15),
        "mail": S.mat("mail", "#7d8085", 0.5, noise=0.5, metal=0.7),
        "steel": S.mat("steel", "#a4a8ad", 0.3, metal=0.9),
        "gambeson": S.mat("gambeson", "#b7a582", 0.95, noise=0.25),
        "order_white": S.mat("order_white", "#ecebe4", 0.9),
        "order_grey": S.mat("order_grey", "#8a877f", 0.95, noise=0.15),
        "order_black": S.mat("order_black", "#151515", 0.9),
        "vestment": S.mat("vestment", "#2c2a2e", 0.95, noise=0.1),
        "german_tunic": S.mat("german_tunic", "#6a6f80", 0.95, noise=0.18),
        "hose": S.mat("hose", "#6b4c38", 0.95, noise=0.15),
        "leather": S.mat("leather", "#5a3e28", 0.8, noise=0.2),
        "ochre": S.mat("ochre_hood", "#9a7a3a", 0.95, noise=0.2),
        "sheepskin": S.mat("sheepskin", "#d4c3a0", 1.0, noise=0.5),
        "fur": S.mat("fur", "#6b5034", 1.0, noise=0.5),
        "grey_hair": S.mat("grey_hair", "#a8a196", 0.9, noise=0.2),
        "fair_hair": S.mat("fair_hair", "#b89a62", 0.9, noise=0.2),
        "bow": S.mat("bow", "#5b3b22", 0.6),
        "herb": S.mat("herb", "#5e7a3a", 1.0, noise=0.4),
        "sack": S.mat("sack", "#c2ad86", 1.0, noise=0.2),
        "book": S.mat("book", "#5a2a1e", 0.7),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _belt(f, mat, r=0.22):
    b = S.cyl("belt", r, r, 0.06, (0, 0, 0.03), mat, f.hips, seg=12)
    b.scale = (1.0, 0.8, 1.0)
    return b


def _cloak(f, mat, bottom=-0.85, r_bottom=0.4, front_open=True):
    """A cloak hanging from the shoulders down to the knees (z relative to the chest)."""
    c = S.cyl("cloak", r_bottom, 0.27, 0.5 - bottom, (0, -0.03, bottom), mat, f.chest, seg=14)
    c.scale = (1.0, 0.82, 1.0)
    return c


def _cross(name, parent, loc, size, mat, rot=(0, 0, 0), tau=False):
    """A black cross (or the half-brothers' T) on a surface facing -Y of `parent` space."""
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = rot
    w = size * 0.28
    S.box(f"{name}_h", (size, 0.02, w), (0, 0, size * (0.5 - w / size / 2) if tau else 0), mat, holder)
    S.box(f"{name}_v", (w, 0.02, size), (0, 0, 0), mat, holder)
    return holder


def _hood(f, mat, cape=None):
    """A gugel: a hood with a shoulder cape."""
    # Pushed back so the face shows.
    S.ball("hood", 0.145, (0, -0.065, 0.025), mat, f.head, scale=(1.0, 1.0, 1.08))
    S.cyl("hood_cape", 0.3, 0.12, 0.2, (0, 0, 0.36), cape or mat, f.chest, seg=12)


def _chapel(f, mat):
    """Chapel-de-fer: a domed iron hat with a wide brim."""
    S.cyl("chapel_brim", 0.25, 0.24, 0.025, (0, 0, 0.05), mat, f.head, seg=16)
    S.ball("chapel_dome", 0.14, (0, 0, 0.07), mat, f.head, scale=(1, 1, 0.9))


def _bascinet(f, mat, visor=False):
    S.ball("bascinet", 0.145, (0, -0.01, 0.03), mat, f.head, scale=(1.0, 1.05, 1.25))
    S.cyl("aventail", 0.22, 0.13, 0.17, (0, 0, -0.17), S.mat("mail", "#7d8085", 0.5, noise=0.5, metal=0.7),
          f.head, seg=12)
    if visor:
        S.cyl("visor", 0.07, 0.01, 0.17, (0, 0.13, -0.02), mat, f.head, rot=(-math.pi / 2, 0, 0), seg=8)


def _longbow(f, m):
    """A longbow held upright in the left hand."""
    f.held_l = True
    hand = f.j("hand_l")
    bow = S.empty("bow", (0, 0.02, -0.03), hand)
    bow.rotation_euler = (math.radians(-75), 0, 0)
    for s in (-1, 1):
        S.cyl(f"bow_limb_{s}", 0.02, 0.012, 0.85, (0, 0, 0), m["bow"], bow, rot=(0, math.radians(8) * s,
                                                                                  0 if s > 0 else math.pi), seg=5)
    S.cyl("bow_string", 0.004, 0.004, 1.6, (0.0, -0.1, -0.8), m["white_linen"], bow, seg=3)


def _quiver(f, m):
    q = S.cyl("quiver", 0.06, 0.07, 0.55, (0.1, -0.17, 0.0), m["leather"], f.chest, rot=(0.25, -0.3, 0), seg=8)
    for i in range(3):
        S.cyl(f"fletch_{i}", 0.012, 0.012, 0.12, (0.02 * i - 0.02, 0, 0.55), m["white_linen"], q, seg=3)
    return q


def _spear(f, m, length=2.2, pennon=None):
    f.held_r = True
    hand = f.j("hand_r")
    spear = S.empty("spear", (0, 0, -0.02), hand)
    spear.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("shaft", 0.018, 0.016, length, (0, 0, -0.85), m["wood"], spear, seg=8)
    S.cyl("spear_head", 0.035, 0.0, 0.25, (0, 0, length - 0.85), m["steel"], spear, seg=4, smooth=False)
    if pennon is not None:
        S.solidify(S.poly("pennon", [(0, 0, length - 0.95), (0.35, 0, length - 1.02), (0, 0, length - 1.15)],
                          [(0, 1, 2)], pennon, spear), 0.01)
    return spear


def _heater(f, face, m, cross=True):
    """A heater shield on the left forearm: `face` colour, black cross, a team rim."""
    f.held_l = True
    holder = S.empty("shield", (-0.24, 0.27, -0.14), f.chest)
    holder.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    pts = [(-0.24, 0, 0.62), (0.24, 0, 0.62), (0.23, 0, 0.3), (0.0, 0, 0.0), (-0.23, 0, 0.3)]
    S.solidify(S.poly("shield_rim", pts, [(0, 1, 2, 3, 4)], m["team"], holder), 0.025)
    inner = [(x * 0.84, -0.02, 0.06 + z * 0.86) for x, _, z in pts]
    S.solidify(S.poly("shield_face", inner, [(0, 1, 2, 3, 4)], face, holder), 0.02)
    if cross:
        S.box("shield_cross_v", (0.07, 0.03, 0.42), (0, -0.04, 0.33), m["order_black"], holder)
        S.box("shield_cross_h", (0.32, 0.03, 0.07), (0, -0.04, 0.44), m["order_black"], holder)
    return holder


def _legs_skirt(f, mat, bottom=-0.4, r=0.3):
    return f.skirt("coat_skirt", 0.06, bottom, 0.22, r, mat)


# --- units ---------------------------------------------------------------------------------

def gdl_forest_archer():
    m = _m()
    f = people.Figure("gdl_forest_archer")
    f.body(m["skin"], m["forest"], m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["hair"])
    _legs_skirt(f, m["forest"], -0.33, 0.29)
    f.skirt("hem", -0.29, -0.35, 0.29, 0.295, m["team"])
    _belt(f, m["leather"])
    _hood(f, m["forest_dark"])
    S.box("knife", (0.03, 0.03, 0.2), (0.17, 0.12, -0.08), m["leather"], f.hips)
    _quiver(f, m)
    _longbow(f, m)
    return f


def gdl_znakharka():
    m = _m()
    f = people.Figure("gdl_znakharka")
    f.body(m["skin"], m["dark_svita"], m["white_linen"], m["lapti"], sleeve=m["dark_svita"])
    f.skirt("shirt", 0.06, -0.86, 0.2, 0.3, m["white_linen"])
    f.skirt("svita_skirt", 0.06, -0.7, 0.22, 0.33, m["dark_svita"])
    _belt(f, m["team"])
    # Namitka: a white linen wrap over the head and down the shoulders.
    S.ball("namitka", 0.15, (0, -0.065, 0.025), m["white_linen"], f.head, scale=(1.0, 1.0, 1.1))
    S.cyl("namitka_drape", 0.24, 0.12, 0.3, (0, -0.02, 0.33), m["white_linen"], f.chest, seg=12)
    for i, x in enumerate((-0.15, 0.0, 0.14)):
        S.cyl(f"herbs_{i}", 0.03, 0.06, 0.2, (x, 0.17, -0.18), m["herb"], f.hips, rot=(math.pi, 0, 0), seg=6)
    f.held_r = True
    hand = f.j("hand_r")
    staff = S.empty("staff", (0, 0, -0.02), hand)
    staff.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("staff_pole", 0.022, 0.018, 1.7, (0, 0, -0.85), m["wood"], staff, seg=6)
    S.ball("staff_knot", 0.04, (0, 0, 0.85), m["wood"], staff)
    # Stooped: the chest leans forward a little in every pose.
    f.stoop = math.radians(10)
    return f


def gdl_castle_archer():
    m = _m()
    f = people.Figure("gdl_castle_archer")
    f.body(m["skin"], m["quilt"], m["trousers"], m["leather"])
    f.hair(m["hair"])
    _legs_skirt(f, m["quilt"], -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    _belt(f, m["team"])
    _cloak(f, m["red_cloak"], bottom=-0.55, r_bottom=0.36)
    _chapel(f, m["iron"])
    _quiver(f, m)
    _longbow(f, m)
    return f


def gdl_camp_servant():
    m = _m()
    f = people.Figure("gdl_camp_servant")
    f.body(m["skin"], m["svita"], m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["hair"])
    _legs_skirt(f, m["svita"], -0.22, 0.27)
    _belt(f, m["team"])
    S.cyl("cap", 0.135, 0.12, 0.09, (0, 0, 0.05), m["felt"], f.head, seg=12)
    S.ball("sack_back", 0.2, (0, -0.24, 0.25), m["sack"], f.chest, scale=(1.1, 0.8, 1.3))
    S.cyl("belt_axe", 0.014, 0.014, 0.45, (0.2, 0.05, -0.3), m["wood"], f.hips, rot=(0.3, 0, 0), seg=5)
    S.box("belt_axe_head", (0.02, 0.12, 0.08), (0.2, 0.0, 0.1), m["iron"], f.hips)
    f.held_r = True
    hand = f.j("hand_r")
    shovel = S.empty("shovel", (0, 0, -0.02), hand)
    shovel.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("shovel_haft", 0.018, 0.016, 1.4, (0, 0, -0.95), m["wood"], shovel, seg=6)
    S.box("shovel_blade", (0.2, 0.03, 0.28), (0, 0, -1.05), m["wood"], shovel)
    return f


def to_peasant():
    m = _m()
    f = people.Figure("to_peasant")
    f.body(m["skin"], m["german_tunic"], m["hose"], m["leather"])
    f.hair(m["hair"], beard=False)
    _legs_skirt(f, m["german_tunic"], -0.3, 0.28)
    f.skirt("hem", -0.26, -0.32, 0.28, 0.285, m["team"])
    _belt(f, m["leather"])
    _hood(f, m["ochre"], cape=m["team"])
    hand = f.j("hand_r")
    S.cyl("hoe_haft", 0.016, 0.016, 1.2, (0, 0.0, -0.45), m["wood"], hand, rot=(math.radians(-15), 0, 0), seg=6)
    S.box("hoe_blade", (0.14, 0.12, 0.03), (0, 0.06, -0.48), m["iron"], hand)
    return f


def to_halfbrother():
    m = _m()
    f = people.Figure("to_halfbrother")
    f.body(m["skin"], m["mail"], m["mail"], m["leather"])
    f.hair(m["hair"])
    _legs_skirt(f, m["mail"], -0.36, 0.29)
    _cloak(f, m["order_grey"], bottom=-0.8)
    _cross("tau", f.chest, (-0.11, 0.24, 0.28), 0.17, m["order_black"], tau=True)
    _belt(f, m["team"], r=0.24)
    _chapel(f, m["steel"])
    _spear(f, m, pennon=m["team"])
    return f


def to_knecht():
    m = _m()
    f = people.Figure("to_knecht")
    f.body(m["skin"], m["mail"], m["gambeson"], m["leather"], sleeve=m["mail"])
    f.hair(m["hair"])
    _legs_skirt(f, m["gambeson"], -0.38, 0.3)
    f.skirt("mail_skirt", 0.06, -0.24, 0.23, 0.31, m["mail"])
    _belt(f, m["leather"], r=0.24)
    _bascinet(f, m["steel"])
    _spear(f, m)
    _heater(f, m["order_white"], m)
    return f


def to_crossbow():
    m = _m()
    f = people.Figure("to_crossbow")
    f.body(m["skin"], m["gambeson"], m["hose"], m["leather"])
    f.hair(m["hair"])
    _legs_skirt(f, m["gambeson"], -0.36, 0.3)
    # Tabard: white with a black cross, a team-coloured edge.
    S.box("tabard", (0.42, 0.36, 0.72), (0, 0.0, 0.1), m["order_white"], f.chest)
    S.box("tabard_edge", (0.43, 0.37, 0.06), (0, 0, -0.27), m["team"], f.chest)
    _cross("cross", f.chest, (0, 0.19, 0.18), 0.22, m["order_black"])
    _chapel(f, m["steel"])
    # Pavise on the back: a tall board with a ridge, white with the cross.
    pav = S.empty("pavise", (0, -0.25, -0.35), f.chest)
    pav.rotation_euler = (math.radians(8), 0, 0)
    S.box("pavise_board", (0.5, 0.06, 1.0), (0, 0, 0.45), m["order_white"], pav)
    S.box("pavise_ridge", (0.12, 0.08, 1.0), (0, -0.03, 0.45), m["team"], pav)
    S.box("pavise_cross_h", (0.36, 0.09, 0.07), (0, -0.04, 0.68), m["order_black"], pav)
    # Crossbow held in both hands across the body, the bow forward.
    f.held_r = True
    f.held_l = True
    hand = f.j("hand_r")
    cb = S.empty("crossbow", (0, 0.0, 0.0), hand)
    cb.rotation_euler = (math.radians(-70), 0, math.radians(20))
    S.box("cb_stock", (0.06, 0.06, 0.75), (0, 0, 0.2), S.mat("crossbow", "#6b4a2c", 0.7), cb)
    S.box("cb_prod", (0.7, 0.05, 0.05), (0, 0, 0.52), m["steel"], cb, rot=(0, 0, 0))
    return f


def to_priest():
    m = _m()
    f = people.Figure("to_priest")
    f.body(m["skin"], m["vestment"], m["vestment"], m["leather"])
    f.skirt("robe", 0.06, -0.86, 0.22, 0.32, m["vestment"])
    _cloak(f, m["order_white"], bottom=-1.05, r_bottom=0.42)
    _cross("cross", f.chest, (-0.12, 0.25, 0.28), 0.17, m["order_black"])
    # Tonsure: a ring of hair round a bare crown.
    S.cyl("tonsure", 0.135, 0.125, 0.08, (0, -0.01, -0.01), m["hair"], f.head, seg=14)
    # A stole in the player colour, and a book in both hands.
    S.box("stole_l", (0.06, 0.02, 0.5), (-0.07, 0.2, 0.15), m["team"], f.chest)
    S.box("stole_r", (0.06, 0.02, 0.5), (0.07, 0.2, 0.15), m["team"], f.chest)
    f.held_r = True
    S.box("book", (0.2, 0.06, 0.26), (-0.05, 0.08, 0.0), m["book"], f.j("hand_r"))
    return f


def to_tithe_collector():
    m = _m()
    f = people.Figure("to_tithe_collector")
    f.body(m["skin"], m["dark_svita"], m["hose"], m["leather"])
    f.hair(m["grey_hair"], beard=False)
    f.skirt("coat", 0.06, -0.6, 0.22, 0.3, m["dark_svita"])
    _cloak(f, m["dark_svita"], bottom=-0.75)
    # The black cross on a white patch on the left sleeve.
    S.box("sleeve_patch", (0.04, 0.12, 0.12), (-0.07, 0.0, -0.12), m["order_white"], f.j("shoulder_l"))
    S.box("sleeve_cross_v", (0.045, 0.03, 0.1), (-0.07, 0.0, -0.12), m["order_black"], f.j("shoulder_l"))
    S.box("sleeve_cross_h", (0.045, 0.1, 0.03), (-0.07, 0.0, -0.12), m["order_black"], f.j("shoulder_l"))
    S.cyl("hat", 0.15, 0.13, 0.12, (0, 0, 0.06), m["vestment"], f.head, seg=12)
    _belt(f, m["leather"])
    S.ball("purse", 0.07, (0.2, 0.08, -0.08), m["team"], f.hips, scale=(1, 0.8, 1.2))
    f.held_r = True
    S.box("tally_board", (0.05, 0.22, 0.32), (0.0, 0.08, 0.0), m["wood"], f.j("hand_r"))
    S.ball("sack_back", 0.2, (0.05, -0.24, 0.2), m["sack"], f.chest, scale=(1.0, 0.8, 1.3))
    return f


def nt_villager():
    m = _m()
    f = people.Figure("nt_villager")
    f.body(m["skin"], S.mat("homespun", "#8c7a5e", 0.95, noise=0.2), m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["fair_hair"])
    f.skirt("shirt_hem", 0.05, -0.43, 0.2, 0.27, m["linen"])
    _belt(f, m["team"])
    hand = f.j("hand_r")
    S.cyl("basket", 0.14, 0.17, 0.2, (0, 0.05, -0.2), S.mat("wicker", "#8e7346", 1.0, noise=0.6), hand, seg=10)
    return f


def hero_rumbaudas():
    m = _m()
    f = people.Figure("hero_rumbaudas")
    f.body(m["skin"], m["sheepskin"], m["trousers"], m["leather"], wraps=m["wraps"])
    f.hair(m["hair"])
    f.skirt("kozhukh", 0.06, -0.5, 0.24, 0.34, m["sheepskin"])
    f.skirt("kozhukh_hem", -0.44, -0.52, 0.335, 0.345, m["team"])
    _belt(f, m["leather"], r=0.25)
    S.cyl("fur_cap", 0.15, 0.13, 0.14, (0, 0, 0.03), m["fur"], f.head, seg=12)
    S.cyl("belt_axe", 0.016, 0.016, 0.55, (-0.21, 0.05, -0.35), m["wood"], f.hips, rot=(0.25, 0, 0), seg=5)
    S.box("belt_axe_head", (0.025, 0.15, 0.1), (-0.21, 0.0, 0.15), m["iron"], f.hips)
    _quiver(f, m)
    _longbow(f, m)
    return f


def hero_keeper():
    m = _m()
    f = people.Figure("hero_keeper")
    f.body(m["skin"], m["white_linen"], m["white_linen"], m["lapti"])
    f.skirt("dress", 0.06, -0.86, 0.2, 0.32, m["white_linen"])
    _cloak(f, m["dark_svita"], bottom=-1.0, r_bottom=0.42)
    _belt(f, m["team"])
    S.ball("hair", 0.135, (0, -0.02, 0.02), m["grey_hair"], f.head, scale=(0.98, 1.0, 0.98))
    S.cyl("braid", 0.04, 0.03, 0.45, (0, -0.13, -0.45), m["grey_hair"], f.head, seg=6)
    S.cyl("wreath", 0.14, 0.14, 0.04, (0, 0, 0.07), m["herb"], f.head, seg=12)
    f.held_r = True
    hand = f.j("hand_r")
    staff = S.empty("staff", (0, 0, -0.02), hand)
    staff.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("staff_pole", 0.022, 0.018, 1.9, (0, 0, -0.85), m["wood"], staff, seg=6)
    return f


UNITS = {
    "gdl_forest_archer": gdl_forest_archer,
    "gdl_znakharka": gdl_znakharka,
    "gdl_castle_archer": gdl_castle_archer,
    "gdl_camp_servant": gdl_camp_servant,
    "to_peasant": to_peasant,
    "to_halfbrother": to_halfbrother,
    "to_knecht": to_knecht,
    "to_crossbow": to_crossbow,
    "to_priest": to_priest,
    "to_tithe_collector": to_tithe_collector,
    "nt_villager": nt_villager,
    "hero_rumbaudas": hero_rumbaudas,
    "hero_keeper": hero_keeper,
}
