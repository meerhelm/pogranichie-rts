"""Units of the Grunwald mission (ВКЛ 2, 1410), on the figure of people.py and the horse of
beasts.py (visual assets doc, «Юниты» and «Герои»).

On foot:
- gdl_samogitian: hides over linen, a Lithuanian shield on the arm, a spear and a battle axe
  at the belt; no Christian signs, no mail.
- pl_spearman: a town spearman: chapel-de-fer, quilted coat, cloth hose, spear, a heater
  shield in town colours (blue and white).
- pl_crossbow: chapel-de-fer, red brigandine, a steel-bowed crossbow, the belt hook and a
  quiver of bolts at the hip; the base of to_crossbow without the Order's cross and pavise.
Mounted:
- nt_steppe_archer: a Tatar horse archer, like gdl_tatar but simpler: no helmet, a sheepskin
  coat, a fur-rimmed cap, a composite bow, the saadak and a sabre, a small steppe horse.
- pl_kopia: a knight's lance: pointed-visor bascinet, plate arms over a brigandine, shield and
  caparison with a family coat of arms (Topór: a white axe on red), a long lance with a pennon.
- to_guest_knight: a western crusader in his own bright arms (or, a bend gules) on surcoat,
  shield and caparison, a crest on the helmet; not the Order's white cloak.
Heroes (doc «Герои»; `sovereign` is a rider with a standard-bearer beside him):
- hero_vytautas: the Grand Duke about 60, armour and a red cloak, grey beard, a gold circlet
  on an open bascinet; his bearer carries the Pogoń banner.
- hero_lengvenis: an elderly prince, son of Algirdas, leading the Smolensk banners: mail and
  plate, a pointed helmet, a gold Orthodox cross on the chest, a lance with a pennon.
- hero_wallenrode: the Grand Marshal, a knight brother in the white cloak on a big horse.
- hero_jungingen: the Grand Master about 50 in the white cloak with the Grand Master's arms
  (black cross, gold cross fleury, a gold escutcheon with the black eagle), which his bearer
  also carries on the banner.
Machines:
- to_wagon: the GDL wagon with a white cover and black crosses, a German driver.
- to_bombard: a thick wrought-iron barrel with hoops on a wooden bed (колода) without wheels,
  stone balls, a crew of three; it fires with a flash, smoke and recoil.
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.models import _lithuanian_shield


def _m():
    m = folk._m()
    m.update({
        "gold": S.mat("gold", "#c9a03a", 0.4, metal=0.8),
        "red_cloth": S.mat("red_cloth", "#a3261e", 0.9, noise=0.12),
        "white_cloth": S.mat("white_cloth", "#e9e6dc", 0.9, noise=0.08),
        "yellow_cloth": S.mat("yellow_cloth", "#d7a72e", 0.9, noise=0.1),
        "blue_cloth": S.mat("blue_cloth", "#2f4f8a", 0.9, noise=0.12),
        "brigandine": S.mat("pl_brigandine", "#7a2420", 0.8, noise=0.15),
        "stone": S.mat("stone_ball", "#9a958a", 0.95, noise=0.4),
        "black_iron": S.mat("black_iron", "#3c3a38", 0.5, noise=0.3, metal=0.7),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _plate_arms(f, m):
    for side in ("l", "r"):
        S.limb(f"plate_arm_{side}", 0.085, 0.07, 0.3, m["steel"], f.j(f"shoulder_{side}"))
        S.limb(f"plate_fore_{side}", 0.072, 0.06, 0.28, m["steel"], f.j(f"elbow_{side}"))


def _rider(name, body_mat, legs_mat, shoes, m, hair=None, beard=True):
    return beasts._rider(name, body_mat, legs_mat, shoes, m, hair, beard)


def _sword(f, m):
    """A sword held point up in the right hand (it swings with the arm)."""
    f.held_r = True
    sword = S.empty("sword", (0, 0, 0), f.j("hand_r"))
    sword.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("sword_blade", 0.022, 0.01, 0.9, (0, 0, 0.05), m["steel"], sword, seg=4, smooth=False)
    S.box("sword_guard", (0.2, 0.03, 0.03), (0, 0, 0.05), m["steel"], sword)
    return sword


def _axe_charge(name, parent, loc, size, mat):
    """Topór: an axe as a heraldic charge, in the plane of `parent`'s XZ (thin along Y)."""
    h = S.empty(name, loc, parent)
    S.box(f"{name}_haft", (0.05 * size, 0.03, 0.9 * size), (0.05 * size, 0, -0.1 * size), mat, h,
          rot=(0, math.radians(-15), 0))
    S.box(f"{name}_blade", (0.32 * size, 0.03, 0.34 * size), (-0.12 * size, 0, 0.25 * size), mat, h)
    return h


def _bend(name, parent, loc, w, h, mat):
    """A diagonal band across a field of w x h (XZ plane of `parent`)."""
    band = S.box(name, (math.hypot(w, h) * 0.95, 0.03, min(w, h) * 0.28), loc, mat, parent,
                 rot=(0, -math.atan2(h, w), 0))
    return band


def _grand_master_cross(name, parent, loc, size, m):
    """The Grand Master's arms over a white field: the black cross, a gold cross fleury on it
    and a gold escutcheon with the black eagle in the middle (thin along Y)."""
    h = S.empty(name, loc, parent)
    w = size * 0.26
    S.box(f"{name}_bv", (w, 0.03, size), (0, 0, 0), m["order_black"], h)
    S.box(f"{name}_bh", (size, 0.03, w), (0, 0, 0), m["order_black"], h)
    g = size * 0.08
    S.box(f"{name}_gv", (g, 0.04, size * 0.86), (0, 0, 0), m["gold"], h)
    S.box(f"{name}_gh", (size * 0.86, 0.04, g), (0, 0, 0), m["gold"], h)
    for k, (x, z) in enumerate(((0, 1), (0, -1), (1, 0), (-1, 0))):
        S.box(f"{name}_lis_{k}", (g * 2.2, 0.04, g * 2.2), (x * size * 0.43, 0, z * size * 0.43), m["gold"], h,
              rot=(0, math.pi / 4, 0))
    S.box(f"{name}_shield", (size * 0.3, 0.05, size * 0.32), (0, 0, 0), m["gold"], h)
    S.box(f"{name}_eagle", (size * 0.16, 0.06, size * 0.18), (0, 0, 0.01), m["order_black"], h)
    return h


def _pogon(name, parent, loc, size, mat):
    """The Pogoń: a white rider with a raised sword, as a simple silhouette (XZ plane)."""
    h = S.empty(name, loc, parent)
    S.box(f"{name}_horse", (0.5 * size, 0.03, 0.2 * size), (0, 0, 0), mat, h)
    S.box(f"{name}_head", (0.12 * size, 0.03, 0.22 * size), (-0.28 * size, 0, 0.12 * size), mat, h,
          rot=(0, math.radians(30), 0))
    for k, x in enumerate((-0.2, -0.08, 0.1, 0.2)):
        S.box(f"{name}_leg_{k}", (0.05 * size, 0.03, 0.25 * size), (x * size, 0, -0.2 * size), mat, h,
              rot=(0, math.radians(25 if k % 2 else -25), 0))
    S.box(f"{name}_rider", (0.12 * size, 0.03, 0.3 * size), (0.02 * size, 0, 0.22 * size), mat, h)
    S.box(f"{name}_sword", (0.04 * size, 0.03, 0.32 * size), (-0.12 * size, 0, 0.45 * size), mat, h,
          rot=(0, math.radians(-30), 0))
    S.box(f"{name}_shield", (0.1 * size, 0.035, 0.12 * size), (-0.08 * size, 0, 0.2 * size), mat, h)
    return h


def _orthodox_cross(name, parent, loc, size, mat):
    """An eight-pointed cross: a short top bar, the main bar, a slanted foot bar."""
    h = S.empty(name, loc, parent)
    t = size * 0.14
    S.box(f"{name}_v", (t, 0.02, size), (0, 0, 0), mat, h)
    S.box(f"{name}_top", (size * 0.36, 0.02, t * 0.8), (0, 0, size * 0.3), mat, h)
    S.box(f"{name}_main", (size * 0.6, 0.02, t), (0, 0, size * 0.15), mat, h)
    S.box(f"{name}_foot", (size * 0.4, 0.02, t * 0.8), (0, 0, -size * 0.28), mat, h, rot=(0, math.radians(-20), 0))
    return h


def _banner(f, m, field, decorate, width=0.75, height=0.6, length=3.2):
    """A banner on a pole held upright in the right hand; the cloth hangs from a crossbar
    toward -X (away from the bearer's lord), a team-coloured streamer above it.
    `decorate(holder)` draws the arms on the cloth (its XZ plane, centred)."""
    f.held_r = True
    pole = S.empty("banner", (0, 0, -0.02), f.j("hand_r"))
    pole.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("banner_pole", 0.02, 0.018, length, (0, 0, -0.85), m["wood"], pole, seg=6)
    top = length - 0.85
    S.cyl("banner_finial", 0.03, 0.0, 0.14, (0, 0, top), m["gold"], pole, seg=4, smooth=False)
    S.cyl("banner_bar", 0.012, 0.012, width + 0.06, (0.03, 0, top - 0.08), m["wood"], pole,
          rot=(0, -math.pi / 2, 0), seg=4)
    cloth = S.empty("banner_cloth", (-width / 2 - 0.02, 0, top - 0.08 - height / 2), pole)
    S.box("banner_field", (width, 0.015, height), (0, 0, 0), field, cloth)
    # Two tails under the field, in the player colour (the arms keep their colours).
    for k, x in enumerate((-width * 0.3, width * 0.3)):
        S.solidify(S.poly(f"banner_tail_{k}", [(x - width * 0.18, 0, -height / 2), (x + width * 0.18, 0, -height / 2),
                                               (x, 0, -height / 2 - 0.28)], [(0, 1, 2)], m["team"], cloth), 0.015)
    decorate(cloth)
    return pole


class Sovereign(beasts.Mounted):
    """The `sovereign` hero template: the lord on horseback with a standard-bearer on foot at
    his left, who walks when the horse walks."""

    def __init__(self, name, horse_beast, rider, saddle_cloth, bearer):
        super().__init__(name, horse_beast, rider, saddle_cloth)
        self.bearer = bearer
        bearer.root.parent = self.root
        bearer.root.location = (-0.95, 0.35, 0)

    def pose(self, anim, frame, frames):
        super().pose(anim, frame, frames)
        self.bearer.pose("walk" if anim == "walk" else "idle", frame, frames)


def _bearer(m, coat, legs, hair, helmet=True):
    b = people.Figure("bearer")
    b.body(m["skin"], m["mail"], legs, m["leather"], sleeve=m["mail"])
    b.hair(hair)
    b.skirt("coat_skirt", 0.06, -0.4, 0.22, 0.3, coat)
    S.box("tabard", (0.4, 0.34, 0.66), (0, 0.0, 0.12), coat, b.chest)
    folk._belt(b, m["team"], r=0.24)
    if helmet:
        folk._chapel(b, m["steel"])
    return b


# --- on foot -------------------------------------------------------------------------------

def gdl_samogitian():
    m = _m()
    f = people.Figure("gdl_samogitian")
    hides = S.mat("hides", "#7a5a3a", 1.0, noise=0.5)
    f.body(m["skin"], hides, m["trousers"], m["lapti"], sleeve=m["linen"], wraps=m["wraps"])
    f.hair(m["fair_hair"])
    f.skirt("shirt_hem", 0.05, -0.45, 0.2, 0.28, m["linen"])
    f.skirt("hide_skirt", 0.06, -0.3, 0.23, 0.31, hides)
    # A shaggy hide over the shoulders, the belt in the player colour.
    S.cyl("hide_cape", 0.31, 0.14, 0.2, (0, -0.02, 0.35), S.mat("fur", "#6b5034", 1.0, noise=0.5), f.chest, seg=12)
    folk._belt(f, m["team"], r=0.24)
    S.cyl("felt_cap", 0.135, 0.11, 0.1, (0, 0, 0.05), m["felt"], f.head, seg=12)
    # The battle axe at the belt, the spear in the hand, the Lithuanian shield on the arm.
    S.cyl("belt_axe", 0.016, 0.016, 0.6, (0.21, 0.06, -0.4), m["wood"], f.hips, rot=(0.25, 0, 0), seg=5)
    S.box("belt_axe_head", (0.025, 0.17, 0.12), (0.21, 0.0, 0.14), m["iron"], f.hips)
    folk._spear(f, m, length=2.3)
    f.held_l = True
    _lithuanian_shield(f.chest, m)
    return f


def pl_spearman():
    m = _m()
    f = people.Figure("pl_spearman")
    f.body(m["skin"], m["gambeson"], S.mat("pl_hose", "#5a6a48", 0.95, noise=0.15), m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["gambeson"], -0.38, 0.3)
    f.skirt("hem", -0.34, -0.4, 0.3, 0.305, m["team"])
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["iron"])
    folk._spear(f, m, length=2.4)
    # The town's shield: per pale white and blue (town colours, not the player colour).
    sh = folk._heater(f, m["white_cloth"], m, cross=False)
    S.box("shield_half", (0.19, 0.03, 0.52), (0.1, -0.035, 0.33), m["blue_cloth"], sh)
    S.box("shield_half_tip", (0.1, 0.03, 0.2), (0.05, -0.035, 0.14), m["blue_cloth"], sh, rot=(0, math.radians(-30), 0))
    return f


def pl_crossbow():
    m = _m()
    f = people.Figure("pl_crossbow")
    f.body(m["skin"], m["brigandine"], S.mat("pl_hose", "#5a4a3a", 0.95, noise=0.15), m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["gambeson"], -0.36, 0.3)
    f.skirt("brig_skirt", 0.06, -0.18, 0.23, 0.29, m["brigandine"])
    # Rivet rows of the brigandine.
    for i, z in enumerate((0.1, 0.22, 0.34)):
        S.cyl(f"rivets_{i}", 0.2 - 0.01 * i, 0.2 - 0.01 * i, 0.015, (0, 0, z), m["gold"], f.chest, seg=12).scale = (
            1.0, 0.76, 1.0)
    folk._belt(f, m["team"], r=0.24)
    folk._chapel(f, m["steel"])
    # The spanning hook at the belt, a quiver of bolts at the right hip.
    S.box("belt_hook", (0.06, 0.05, 0.1), (0.0, 0.19, -0.04), m["iron"], f.hips)
    q = S.box("bolt_quiver", (0.1, 0.1, 0.32), (0.22, 0.02, -0.15), m["leather"], f.hips, rot=(0.2, 0, 0))
    for i in range(3):
        S.cyl(f"bolt_{i}", 0.01, 0.01, 0.08, (0.03 * i - 0.03, 0, 0.16), m["white_linen"], q, seg=3)
    f.held_r = True
    f.held_l = True
    cb = S.empty("crossbow", (0, 0.0, 0.0), f.j("hand_r"))
    cb.rotation_euler = (math.radians(-70), 0, math.radians(20))
    S.box("cb_stock", (0.06, 0.06, 0.75), (0, 0, 0.2), S.mat("crossbow", "#6b4a2c", 0.7), cb)
    S.box("cb_prod", (0.7, 0.05, 0.05), (0, 0, 0.52), m["steel"], cb)
    S.box("cb_stirrup", (0.14, 0.02, 0.1), (0, 0, 0.6), m["iron"], cb)
    return f


# --- mounted -------------------------------------------------------------------------------

def _composite_bow(f, m):
    """A short Tatar bow with recurved tips, held in the left hand."""
    f.held_l = True
    bow = S.empty("bow", (0, 0.02, -0.03), f.j("hand_l"))
    bow.rotation_euler = (math.radians(-75), 0, 0)
    for s in (-1, 1):
        limb = S.empty(f"bow_limb_{s}", (0, 0, 0), bow)
        limb.rotation_euler = (0, math.radians(10) * s, 0 if s > 0 else math.pi)
        S.cyl(f"bow_limb_mesh_{s}", 0.022, 0.014, 0.5, (0, 0, 0), m["bow"], limb, seg=5)
        S.cyl(f"bow_tip_{s}", 0.013, 0.008, 0.14, (0, 0, 0.5), m["bow"], limb, rot=(0, math.radians(-35), 0), seg=4)
    S.cyl("bow_string", 0.004, 0.004, 1.02, (0.0, -0.08, -0.51), m["white_linen"], bow, seg=3)


def nt_steppe_archer():
    m = _m()
    r = _rider("rider", m["sheepskin"], m["trousers"], m["leather"], m, m["hair"])
    r.skirt("kozhukh", 0.06, -0.42, 0.24, 0.33, m["sheepskin"])
    folk._belt(r, m["team"], r=0.25)
    # A cloth cap with a fur rim, no helmet.
    S.cyl("cap_fur", 0.155, 0.15, 0.08, (0, 0, 0.02), m["fur"], r.head, seg=12)
    S.cyl("cap_top", 0.13, 0.04, 0.16, (0, 0, 0.09), m["red_cloak"], r.head, seg=10)
    # The saadak (bow case and quiver) at the left hip, a sabre on the right.
    S.box("saadak", (0.05, 0.16, 0.3), (-0.25, -0.02, -0.12), m["leather"], r.hips, rot=(0.4, 0, 0))
    q = S.cyl("quiver", 0.06, 0.07, 0.45, (0.26, -0.12, -0.35), m["leather"], r.hips, rot=(-0.3, 0, 0), seg=8)
    for i in range(3):
        S.cyl(f"fletch_{i}", 0.012, 0.012, 0.1, (0.02 * i - 0.02, 0, 0.45), m["white_linen"], q, seg=3)
    S.cyl("sabre", 0.016, 0.012, 0.75, (0.24, 0.12, -0.6), m["steel"], r.hips, rot=(0.5, 0, 0), seg=4, smooth=False)
    _composite_bow(r, m)
    h = beasts.horse("horse", S.mat("steppe_horse", "#6a5236", 0.9, noise=0.3), small=True,
                     mane=S.mat("mane", "#3a2a1c", 1.0, noise=0.4))
    return beasts.Mounted("nt_steppe_archer", h, r, m["team"])


def pl_kopia():
    m = _m()
    blue = S.mat("kopia_brig", "#2f3f66", 0.8, noise=0.15)
    r = _rider("rider", blue, m["steel"], m["steel"], m)
    _plate_arms(r, m)
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    folk._bascinet(r, m["steel"])
    # The pointed «hounskull» visor.
    S.cyl("visor_point", 0.09, 0.0, 0.24, (0, 0.11, -0.03), m["steel"], r.head, rot=(-math.pi / 2, 0, 0), seg=8)
    beasts._lance(r, m, length=3.9, pennon=m["team"])
    sh = folk._heater(r, m["red_cloth"], m, cross=False)
    white = m["white_cloth"]
    _axe_charge("shield_axe", sh, (0.0, -0.05, 0.36), 0.55, white)
    h = beasts.horse("horse", S.mat("chestnut", "#7a4a2a", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, m["red_cloth"], m["team"])
    for s in (-1, 1):  # the axe on both flanks of the caparison
        _axe_charge(f"cap_axe_{s}", h.body, (s * (h.rx + 0.07), 0.0, -0.2), 0.7, white).rotation_euler = (
            0, 0, math.pi / 2)
    return beasts.Mounted("pl_kopia", h, r, m["team"])


def to_guest_knight():
    m = _m()
    yellow, red = m["yellow_cloth"], m["red_cloth"]
    r = _rider("rider", m["mail"], m["steel"], m["steel"], m)
    _plate_arms(r, m)
    # A surcoat in his own arms: or, a bend gules.
    S.box("surcoat", (0.44, 0.36, 0.62), (0, 0.0, 0.16), yellow, r.chest)
    r.skirt("surcoat_skirt", 0.06, -0.42, 0.24, 0.33, yellow)
    _bend("surcoat_bend", r.chest, (0, 0.19, 0.18), 0.4, 0.55, red)
    folk._bascinet(r, m["steel"], visor=True)
    # A crest: a fan in his colours on a team-coloured wreath (torse).
    S.cyl("torse", 0.12, 0.11, 0.05, (0, -0.01, 0.17), m["team"], r.head, seg=10)
    fan = S.poly("crest", [(0, -0.12, 0.2), (0, 0.1, 0.2), (0, 0.14, 0.42), (0, 0.0, 0.5), (0, -0.16, 0.4)],
                 [(0, 1, 2, 3, 4)], yellow, r.head)
    S.solidify(fan, 0.03)
    S.box("crest_edge", (0.035, 0.05, 0.28), (0, 0.0, 0.36), red, r.head, rot=(math.radians(-25), 0, 0))
    beasts._lance(r, m, length=3.9, pennon=m["team"])
    sh = folk._heater(r, yellow, m, cross=False)
    S.box("shield_bend", (0.5, 0.03, 0.11), (0.0, -0.045, 0.34), red, sh, rot=(0, math.radians(-50), 0))
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, yellow, m["team"])
    for s in (-1, 1):
        S.box(f"cap_bend_band_{s}", (0.03, 1.4, 0.16), (s * (h.rx + 0.075), 0, -0.25), red, h.body,
              rot=(math.radians(-25 * s), 0, 0))
    return beasts.Mounted("to_guest_knight", h, r, m["team"])


# --- heroes --------------------------------------------------------------------------------

def hero_vytautas():
    m = _m()
    grey = m["grey_hair"]
    r = _rider("rider", m["brigandine"], m["steel"], m["steel"], m, grey)
    _plate_arms(r, m)
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    folk._cloak(r, m["red_cloak"], bottom=-0.6, r_bottom=0.4)
    S.cyl("cloak_clasp", 0.04, 0.04, 0.02, (0, 0.2, 0.4), m["gold"], r.chest, rot=(-math.pi / 2, 0, 0), seg=8)
    # An open bascinet with a gold circlet over the grey hair and beard.
    S.ball("bascinet", 0.15, (0, -0.02, 0.05), m["steel"], r.head, scale=(1.0, 1.05, 1.2))
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], r.head)
    S.cyl("circlet", 0.152, 0.152, 0.04, (0, -0.02, 0.04), m["gold"], r.head, seg=14)
    _sword(r, m)
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.04)
    beasts.caparison(h, m["red_cloth"], m["team"])
    b = _bearer(m, m["red_cloth"], m["trousers"], m["hair"])
    _banner(b, m, m["red_cloth"], lambda c: _pogon("banner_pogon", c, (0, 0, 0.02), 0.6, m["white_cloth"]))
    return Sovereign("hero_vytautas", h, r, m["team"], b)


def hero_lengvenis():
    m = _m()
    r = _rider("rider", m["mail"], m["steel"], m["steel"], m, m["grey_hair"])
    _plate_arms(r, m)
    r.skirt("mail_skirt", 0.06, -0.3, 0.23, 0.3, m["mail"])
    # A breastplate under a short dark-green cloak thrown back, a gold Orthodox cross.
    S.cyl("breastplate", 0.19, 0.235, 0.36, (0, 0.012, 0.1), m["steel"], r.chest, seg=12).scale = (1.0, 0.76, 1.0)
    S.cyl("cloak_back", 0.36, 0.26, 0.9, (0, -0.1, -0.4), S.mat("green_cloak", "#2f4a34", 0.9, noise=0.15), r.chest,
          seg=12).scale = (1.0, 0.55, 1.0)
    _orthodox_cross("orthodox_cross", r.chest, (0, 0.2, 0.3), 0.16, m["gold"])
    # A tall pointed helmet with an aventail, the elder's grey beard below it.
    S.cyl("helmet", 0.145, 0.02, 0.3, (0, 0, 0.03), m["steel"], r.head, seg=12)
    S.cyl("aventail", 0.2, 0.14, 0.16, (0, -0.03, -0.15), m["mail"], r.head, seg=12)
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], r.head)
    S.ball("long_beard", 0.09, (0, 0.08, -0.13), m["grey_hair"], r.head, scale=(1.0, 0.8, 1.4))
    beasts._lance(r, m, length=3.4, pennon=m["team"])
    sh = folk._heater(r, m["red_cloth"], m, cross=False)
    _orthodox_cross("shield_cross", sh, (0, -0.05, 0.38), 0.32, m["gold"])
    h = beasts.horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25), size=1.04)
    return beasts.Mounted("hero_lengvenis", h, r, m["team"])


def hero_wallenrode():
    m = _m()
    r = _rider("rider", m["mail"], m["steel"], m["steel"], m)
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.3, m["order_black"])
    folk._bascinet(r, m["steel"], visor=True)
    # The marshal's lance with a long team-coloured pennon.
    beasts._lance(r, m, length=4.0, pennon=m["team"])
    folk._heater(r, m["order_white"], m)
    h = beasts.horse("horse", S.mat("dark_bay", "#4a3020", 0.9, noise=0.25), size=1.1)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    return beasts.Mounted("hero_wallenrode", h, r, m["team"])


def hero_jungingen():
    m = _m()
    r = _rider("rider", m["mail"], m["steel"], m["steel"], m, m["hair"])
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    _grand_master_cross("cloak_arms", r.chest, (-0.12, 0.25, 0.28), 0.2, m)
    _grand_master_cross("cloak_arms_back", r.chest, (0, -0.24, 0.2), 0.32, m)
    # An open bascinet: the face of the Grand Master shows.
    S.ball("bascinet", 0.15, (0, -0.02, 0.05), m["steel"], r.head, scale=(1.0, 1.05, 1.2))
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], r.head)
    S.cyl("aventail", 0.22, 0.13, 0.17, (0, 0, -0.17), m["mail"], r.head, seg=12)
    _sword(r, m)
    sh = folk._heater(r, m["order_white"], m, cross=False)
    _grand_master_cross("shield_arms", sh, (0, -0.05, 0.36), 0.4, m)
    h = beasts.horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25), size=1.08)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    b = _bearer(m, m["order_white"], m["mail"], m["hair"])
    folk._cross("bearer_cross", b.chest, (0, 0.18, 0.25), 0.2, m["order_black"])
    _banner(b, m, m["order_white"], lambda c: _grand_master_cross("banner_arms", c, (0, 0, 0.0), 0.5, m))
    return Sovereign("hero_jungingen", h, r, m["team"], b)


# --- machines ------------------------------------------------------------------------------

def _order_cover(cart, m):
    """Black crosses on the white cover: on top (deep enough to follow its curve) and on
    both sides."""
    black = m["order_black"]
    S.box("cover_cross_top_x", (0.5, 0.13, 0.1), (0, 0.5, 1.63), black, cart)
    S.box("cover_cross_top_y", (0.13, 0.5, 0.06), (0, 0.5, 1.645), black, cart)
    for s in (-1, 1):
        S.box(f"cover_cross_v_{s}", (0.06, 0.09, 0.28), (s * 0.6, 0.45, 1.2), black, cart)
        S.box(f"cover_cross_h_{s}", (0.06, 0.3, 0.09), (s * 0.61, 0.45, 1.22), black, cart)


def _german_driver(d, m):
    d.body(m["skin"], m["german_tunic"], m["hose"], m["leather"])
    d.hair(m["hair"])
    folk._belt(d, m["team"])
    folk._hood(d, m["ochre"])


def to_wagon():
    return beasts.Wagon("to_wagon", cover="#e6e3d8", dress=_german_driver, mark=_order_cover, coat="#4a3020")


class Bombard:
    """The bombard on its bed with a crew of three. Walk: the crew walks beside it (it is
    dragged on its skids); attack: a flash, smoke and the recoil of the whole bed."""

    def __init__(self, name="to_bombard"):
        m = _m()
        beam = S.mat("bed_beam", "#6e5236", 0.85, noise=0.35)
        self.root = S.empty(name)
        self.bed = S.empty("bed", (0, 0, 0), self.root)
        # The bed: a heavy hewn log trough on two skids, a stop beam behind.
        for x in (-0.38, 0.38):
            S.box(f"skid_{x}", (0.16, 2.6, 0.14), (x, -0.1, 0.07), beam, self.bed)
        S.box("trough", (0.8, 2.2, 0.32), (0, -0.05, 0.3), beam, self.bed)
        for x in (-0.36, 0.36):
            S.box(f"cheek_{x}", (0.1, 1.9, 0.28), (x, 0.0, 0.58), beam, self.bed)
        S.box("stop_beam", (1.1, 0.22, 0.5), (0, -1.25, 0.4), beam, self.bed)
        S.box("bed_band", (0.82, 0.08, 0.34), (0, 0.9, 0.3), m["team"], self.bed)
        # The barrel: a narrow powder chamber behind, the wide flight in front, iron hoops.
        barrel = S.empty("barrel", (0, -0.75, 0.8), self.bed)
        barrel.rotation_euler = (-math.pi / 2 + math.radians(6), 0, 0)
        self.barrel = barrel
        S.cyl("chamber", 0.22, 0.22, 0.7, (0, 0, 0), m["black_iron"], barrel, seg=14)
        S.cyl("flight", 0.33, 0.33, 1.25, (0, 0, 0.7), m["black_iron"], barrel, seg=16)
        for k in range(4):
            S.cyl(f"hoop_{k}", 0.35, 0.35, 0.07, (0, 0, 0.78 + k * 0.36), m["iron"], barrel, seg=16)
        for k in range(3):
            S.cyl(f"chamber_hoop_{k}", 0.24, 0.24, 0.05, (0, 0, 0.1 + k * 0.22), m["iron"], barrel, seg=14)
        S.cyl("bore", 0.24, 0.24, 0.02, (0, 0, 1.94), S.mat("bore", "#0c0b0a", 1.0), barrel, seg=14)
        # Stone balls beside it.
        for k, (x, y) in enumerate(((0.72, 0.35), (0.92, 0.55), (0.8, 0.5))):
            S.ball(f"stone_{k}", 0.2, (x, y, 0.2 + (0.15 if k == 2 else 0.0)), m["stone"], self.bed)
        # A pennant on a stake at the back: white with the black cross, a team tail.
        stake = S.cyl("pennant_pole", 0.025, 0.02, 2.1, (-0.5, -1.3, 0.0), m["wood"], self.bed, seg=6)
        S.box("pennant", (0.5, 0.015, 0.34), (-0.26, 0, 1.9), m["order_white"], stake)
        folk._cross("pennant_cross", stake, (-0.26, 0, 1.9), 0.22, m["order_black"])
        S.solidify(S.poly("pennant_tail", [(-0.51, 0, 2.07), (-0.95, 0, 1.9), (-0.51, 0, 1.73)], [(0, 1, 2)],
                          m["team"], stake), 0.015)
        # Flash and smoke at the muzzle, hidden until it fires.
        smoke_mat = S.mat("smoke", "#b9b6ae", 1.0, noise=0.3)
        self.flash = S.ball("flash", 0.3, (0, 0, 2.15), S.mat("flash", "#ffcf5a", 0.6), barrel)
        self.smoke = [S.ball(f"smoke_{k}", 0.35, (0, 0.1 * k, 2.3 + 0.35 * k), smoke_mat, barrel)
                      for k in range(3)]
        for o in [self.flash, *self.smoke]:
            o.visible_shadow = False
        self.crew = []
        for k, (x, y, turn, dress) in enumerate((
                (0.7, -1.0, 0.0, "gunner"), (-0.75, 0.35, 0.0, "loader"), (-0.7, -0.75, 0.0, "mate"))):
            c = self._crewman(f"crew_{k}", m, dress)
            c.root.parent = self.root
            c.root.location = (x, y, 0)
            c.root.rotation_euler = (0, 0, turn)
            self.crew.append(c)

    def _crewman(self, name, m, role):
        c = people.Figure(name)
        c.body(m["skin"], m["gambeson"], m["hose"], m["leather"])
        c.hair(m["hair"], beard=role != "loader")
        folk._legs_skirt(c, m["gambeson"], -0.34, 0.29)
        c.skirt("hem", -0.3, -0.36, 0.29, 0.295, m["team"])
        folk._belt(c, m["leather"])
        if role == "gunner":
            S.cyl("cap", 0.14, 0.12, 0.1, (0, 0, 0.05), m["felt"], c.head, seg=12)
            # The linstock: a staff with a smouldering match.
            c.held_r = True
            ls = S.empty("linstock", (0, 0, -0.02), c.j("hand_r"))
            ls.rotation_euler = (math.radians(-80), 0, 0)
            S.cyl("linstock_staff", 0.016, 0.014, 1.3, (0, 0, -0.6), m["wood"], ls, seg=6)
            S.ball("match", 0.03, (0, 0, 0.72), S.mat("match_glow", "#e0702a", 0.6), ls)
        elif role == "loader":
            folk._chapel(c, m["iron"])
            c.held_r = True
            rm = S.empty("rammer", (0, 0, -0.02), c.j("hand_r"))
            rm.rotation_euler = (math.radians(-80), 0, 0)
            S.cyl("rammer_pole", 0.02, 0.02, 1.9, (0, 0, -0.9), m["wood"], rm, seg=6)
            S.cyl("rammer_head", 0.09, 0.09, 0.14, (0, 0, 1.0), m["wood"], rm, seg=10)
        else:
            folk._hood(c, m["ochre"], cape=m["team"])
            S.ball("powder_keg", 0.14, (0.0, 0.25, -0.1), S.mat("barrel", "#7c5a36", 0.8, noise=0.3), c.hips,
                   scale=(1.0, 0.9, 1.2))
        return c

    def pose(self, anim, frame, frames):
        t = frame / frames
        for i, c in enumerate(self.crew):
            c.pose("walk" if anim == "walk" else "idle", (frame + i * 3) % frames, frames)
        kick = 0.0
        flash = 0.0
        smoke = [0.0, 0.0, 0.0]
        if anim == "attack":
            # Fires on the second frame: flash, then the smoke grows and drifts as it recoils.
            kick = 0.0 if t < 0.12 else math.exp(-(t - 0.12) * 5.0)
            flash = 1.0 if 0.12 <= t < 0.3 else 0.0
            for k in range(3):
                age = t - 0.12 - 0.08 * k
                smoke[k] = 0.0 if age <= 0 else min(1.0, age * 4.0) * (1.0 - 0.5 * max(0.0, age - 0.4))
            for c in self.crew:  # they flinch away from the blast
                c.chest.rotation_euler.x -= math.radians(10) * kick
        self.bed.location.y = -0.18 * kick
        self.bed.location.z = 0.01 * math.sin(4 * math.pi * t) if anim == "walk" else 0.0
        self.flash.scale = (flash or 0.001,) * 3
        for k, o in enumerate(self.smoke):
            s = max(0.001, smoke[k] * (1.0 + 0.4 * k))
            o.scale = (s, s, s)


def to_bombard():
    return Bombard("to_bombard")


UNITS = {
    "gdl_samogitian": gdl_samogitian,
    "pl_spearman": pl_spearman,
    "pl_crossbow": pl_crossbow,
}
MOUNTED_UNITS = {
    "nt_steppe_archer": nt_steppe_archer,
    "pl_kopia": pl_kopia,
    "to_guest_knight": to_guest_knight,
    "hero_vytautas": hero_vytautas,
    "hero_lengvenis": hero_lengvenis,
    "hero_wallenrode": hero_wallenrode,
    "hero_jungingen": hero_jungingen,
}
WAGONS = {"to_wagon": to_wagon, "to_bombard": to_bombard}
