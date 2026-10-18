"""The Crown of Poland as a skirmish faction (visual assets doc, «Корона Польская»): the
units it trains that had no model yet, on the figure of people.py, the horse and the wagon of
beasts.py and the pieces of folk_1410/folk_1514 (the White Eagle, the kettle hat, the hood).

- pl_kmet: a peasant (кмет): a linen shirt to the knees, a brown sermięga coat with the
  team hem, leather shoes (поршни) over foot wraps, a cloth cap; an axe (works like
  gdl_peasant, attack `swing`).
- pl_bowman: a hood with a pelerine (a gugel), a quilted coat, a longbow, a quiver of arrows,
  a tesak at the belt (attack `bow`).
- pl_light_horse: mail, a kapalin (kettle hat), a light spear (attack `thrust`), a small shield
  with the White Eagle on red, a small horse without a caparison, a team saddle cloth.
- pl_foot_servant: a knight's servant on foot: a light quilted coat with a mail collar, a
  cheap iron cap, a sulica (short spear, attack `thrust`), a small round shield with his
  knight's colours (a white bend on red here) and a team rim, a hatchet at the belt.
- pl_pavise: a pavise man: kettle hat, quilted coat, a short falchion (attack `swing`), the
  big painted pavise with the White Eagle on red and a team rim carried on his back. `work`
  (the game plays it while the pavise is set up) shows the pavise planted on the ground in front
  of him and the man crouched behind it, peering over its top.
- pl_priest: a priest (ксёндз): a black cassock, a white surplice (komża) to the knees, a stole
  in the team colour, a tonsure, a cross on a staff; `cast` raises the cross over his head
  (taller frame, like mo_inok).
- pl_wagon: the Duchy's wagon (beasts.Wagon) under a white canvas with red hoops and a red
  lower edge, a kmet driving.

Aliases instead of models (SpriteDB.ALIASES): pl_camp_servant -> gdl_camp_servant,
pl_bombard -> to_bombard, pl_field_camp -> gdl_field_camp.
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1500 import Monk
from tools.art.folk_1514 import _m as _m1514
from tools.art.folk_1514 import _white_eagle


def _m():
    m = _m1514()
    m.update({
        "sermiega": S.mat("sermiega", "#6a4e34", 0.95, noise=0.25),
        "porshni": S.mat("porshni", "#5e4430", 0.85, noise=0.25),
        "cloth_cap": S.mat("cloth_cap", "#4e4a40", 0.95, noise=0.15),
        "bow_coat": S.mat("bowman_coat", "#7a6a4a", 0.95, noise=0.25),
        "bow_hood": S.mat("bowman_hood", "#5a5038", 0.95, noise=0.2),
        "servant_coat": S.mat("servant_coat", "#8a7650", 0.95, noise=0.28),
        "servant_hose": S.mat("servant_hose", "#5c4a3a", 0.95, noise=0.15),
        "pavise_coat": S.mat("pavise_coat", "#9a8660", 0.95, noise=0.3),
        "pavise_hose": S.mat("pavise_hose", "#3e4a5a", 0.95, noise=0.15),
        "pavise_board": S.mat("pavise_board", "#a8261e", 0.85, noise=0.1),
        "pavise_back": S.mat("pavise_back", "#7a5a3a", 0.85, noise=0.3),
        "cassock": S.mat("cassock", "#1b1a1e", 0.95, noise=0.06),
        "surplice": S.mat("surplice", "#f1eee6", 0.9, noise=0.06),
        "canvas_white": S.mat("canvas_white", "#ebe7dc", 0.95, noise=0.1),
        "canvas_red": S.mat("canvas_red", "#b02a22", 0.95, noise=0.1),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _eagle_shield(name, parent, loc, m, size=0.5, round_=False):
    """A small shield: the White Eagle on red, a team rim (XZ plane of `parent`, face -Y)."""
    holder = S.empty(name, loc, parent)
    if round_:
        rim = S.cyl(f"{name}_rim", size * 0.5, size * 0.5, 0.03, (0, 0.0, 0), m["team"], holder,
                    rot=(math.pi / 2, 0, 0), seg=16)
        S.cyl(f"{name}_face", size * 0.44, size * 0.44, 0.03, (0, -0.012, 0), m["court_red"], rim, seg=16)
    else:
        pts = [(-0.5 * size, 0, 0.5 * size), (0.5 * size, 0, 0.5 * size), (0.48 * size, 0, -0.05 * size),
               (0.0, 0, -0.55 * size), (-0.48 * size, 0, -0.05 * size)]
        S.solidify(S.poly(f"{name}_rim", pts, [(0, 1, 2, 3, 4)], m["team"], holder), 0.025)
        inner = [(x * 0.84, -0.02, z * 0.86) for x, _, z in pts]
        S.solidify(S.poly(f"{name}_face", inner, [(0, 1, 2, 3, 4)], m["court_red"], holder), 0.02)
    _white_eagle(f"{name}_eagle", holder, (0, -0.045, 0.02 * size), size * 0.62, m)
    return holder


def _kapalin(f, m):
    """A kapalin: a kettle hat with a rounded crown and a sloping brim."""
    S.cyl("kapalin_brim", 0.25, 0.17, 0.06, (0, 0, 0.03), m["iron"], f.head, seg=16)
    S.ball("kapalin_dome", 0.145, (0, 0, 0.07), m["iron"], f.head, scale=(1, 1, 1.0))


def _pavise_board(name, parent, loc, rot, m, scale=1.0):
    """The big pavise: a tall board narrowing to the foot, a team rim round it, the White Eagle
    on red on its face (-Y of the holder), a plain wooden back."""
    s = scale
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = rot
    w, h = 0.66 * s, 1.3 * s
    pts = [(-w / 2, 0, h), (w / 2, 0, h), (w * 0.44, 0, 0.0), (-w * 0.44, 0, 0.0)]
    S.solidify(S.poly(f"{name}_face", pts, [(0, 1, 2, 3)], m["pavise_board"], holder), 0.03)
    back = [(x, 0.035, z) for x, _, z in pts]
    S.solidify(S.poly(f"{name}_back", back, [(3, 2, 1, 0)], m["pavise_back"], holder), 0.03)
    # A team-coloured rim round the face (the ridge would cut the eagle in two).
    for k, (x0, z0, x1, z1) in enumerate([(-w / 2, h, w / 2, h), (w / 2, h, w * 0.44, 0.0), (w * 0.44, 0.0, -w * 0.44, 0.0),
                                          (-w * 0.44, 0.0, -w / 2, h)]):
        length = math.hypot(x1 - x0, z1 - z0)
        S.box(f"{name}_rim_{k}", (length + 0.05 * s, 0.06, 0.06 * s), ((x0 + x1) / 2, -0.025, (z0 + z1) / 2), m["team"],
              holder, rot=(0, -math.atan2(z1 - z0, x1 - x0), 0))
    # The eagle a little higher than the middle, over the ridge; a white border under it.
    _white_eagle(f"{name}_eagle", holder, (0, -0.075, h * 0.62), 0.55 * s, m)
    S.box(f"{name}_band", (w * 0.86, 0.05, 0.06 * s), (0, -0.04, h * 0.2), m["eagle_white"], holder)
    return holder


# --- units ---------------------------------------------------------------------------------

def pl_kmet():
    m = _m()
    f = people.Figure("pl_kmet")
    f.body(m["skin"], m["sermiega"], m["trousers"], m["porshni"], wraps=m["wraps"])
    f.hair(m["fair_hair"])
    f.skirt("shirt_hem", 0.05, -0.45, 0.2, 0.27, m["linen"])
    f.skirt("sermiega_skirt", 0.06, -0.36, 0.22, 0.3, m["sermiega"])
    f.skirt("sermiega_hem", -0.31, -0.38, 0.3, 0.305, m["team"])
    S.cyl("collar", 0.09, 0.085, 0.05, (0, 0, 0.47), m["linen"], f.chest, seg=10)
    folk._belt(f, m["leather"])
    # A cloth cap with a turned-up band.
    S.cyl("cap_band", 0.14, 0.14, 0.06, (0, 0, 0.03), m["cloth_cap"], f.head, seg=12)
    S.ball("cap_top", 0.13, (0, -0.01, 0.1), m["cloth_cap"], f.head, scale=(1, 1, 0.6))
    hand = f.j("hand_r")
    S.cyl("axe_haft", 0.016, 0.016, 0.62, (0, 0.0, -0.2), m["wood"], hand, rot=(math.radians(-15), 0, 0))
    S.box("axe_head", (0.025, 0.14, 0.09), (0, 0.08, -0.25), m["iron"], hand)
    return f


def pl_bowman():
    m = _m()
    f = people.Figure("pl_bowman")
    f.body(m["skin"], m["bow_coat"], m["trousers"], m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["bow_coat"], -0.34, 0.29)
    f.skirt("hem", -0.3, -0.36, 0.29, 0.295, m["team"])
    folk._belt(f, m["leather"])
    # The hood with its pelerine over the shoulders (a gugel), the pelerine edged in the team colour.
    folk._hood(f, m["bow_hood"])
    S.cyl("pelerine_edge", 0.305, 0.3, 0.04, (0, 0, 0.35), m["team"], f.chest, seg=12)
    S.cyl("tesak", 0.016, 0.014, 0.5, (-0.23, 0.06, -0.42), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=4,
          smooth=False)
    folk._quiver(f, m)
    folk._longbow(f, m)
    return f


def pl_foot_servant():
    m = _m()
    f = people.Figure("pl_foot_servant")
    f.body(m["skin"], m["servant_coat"], m["servant_hose"], m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["servant_coat"], -0.32, 0.29)
    f.skirt("hem", -0.28, -0.34, 0.29, 0.295, m["team"])
    folk._belt(f, m["leather"], r=0.23)
    S.cyl("mail_collar", 0.26, 0.12, 0.14, (0, 0, 0.38), m["mail"], f.chest, seg=12)
    # A cheap iron cap: a plain round skull with a rim.
    S.ball("cap", 0.142, (0, 0, 0.04), m["iron"], f.head, scale=(1, 1.04, 0.85))
    S.cyl("cap_rim", 0.15, 0.15, 0.03, (0, 0, 0.0), m["iron"], f.head, seg=14)
    S.cyl("hatchet", 0.014, 0.014, 0.45, (0.21, 0.05, -0.32), m["wood"], f.hips, rot=(0.3, 0, 0), seg=5)
    S.box("hatchet_head", (0.02, 0.12, 0.08), (0.21, 0.0, 0.08), m["iron"], f.hips)
    folk._spear(f, m, length=1.75)
    # A small round shield on the arm: his knight's colours (a white bend on red), a team rim.
    f.held_l = True
    holder = S.empty("shield", (-0.25, 0.27, 0.02), f.chest)
    holder.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    disc = S.cyl("shield_rim", 0.25, 0.25, 0.03, (0, 0, 0), m["team"], holder, rot=(math.pi / 2, 0, 0), seg=16)
    S.cyl("shield_face", 0.21, 0.21, 0.03, (0, 0, 0.012), m["court_red"], disc, seg=16)
    S.box("shield_bend", (0.42, 0.035, 0.08), (0, 0.03, 0), m["eagle_white"], holder, rot=(0, math.radians(-40), 0))
    S.ball("shield_boss", 0.05, (0, 0.05, 0), m["iron"], holder, scale=(1, 0.6, 1))
    return f


class PaviseMan(people.Figure):
    """A figure whose `work` sets the pavise down: the board on his back hides, the planted
    one in front of him shows, and he crouches behind it peering over the top."""

    carried = None
    planted = None

    def pose(self, anim, frame, frames):
        super().pose(anim, frame, frames)
        working = anim == "work"
        if self.carried is not None:
            self.carried.scale = (0.001, 0.001, 0.001) if working else (1.0, 1.0, 1.0)
        if self.planted is not None:
            self.planted.scale = (1.0, 1.0, 1.0) if working else (0.001, 0.001, 0.001)

    def _work(self, rot, t):
        """Crouched on bent knees behind the board, both hands on its top edge; he rises a
        little to look over it and ducks again."""
        r = math.radians
        peek = 0.5 - 0.5 * math.cos(2 * math.pi * t)
        for side, x in (("l", -1), ("r", 1)):
            rot[f"thigh_{side}"] = [r(62) - r(8) * peek, 0.0, 0.0]
            rot[f"knee_{side}"] = [-r(100) + r(14) * peek, 0.0, 0.0]
            rot[f"shoulder_{side}"] = [r(70) + r(6) * peek, -x * r(4), 0.0]
            rot[f"elbow_{side}"] = [r(35) - r(10) * peek, 0.0, 0.0]
        rot["thigh_l"][0] += r(10)
        rot["knee_l"][0] -= r(8)
        chest_x = r(16) - r(6) * peek
        return chest_x, people.HIP_Z - 0.34 + 0.07 * peek


def pl_pavise():
    m = _m()
    f = PaviseMan("pl_pavise")
    f.body(m["skin"], m["pavise_coat"], m["pavise_hose"], m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["pavise_coat"], -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    for k, z in enumerate((0.12, 0.26)):  # quilting seams
        S.cyl(f"quilt_seam_{k}", 0.205 - 0.01 * k, 0.205 - 0.01 * k, 0.014, (0, 0, z), m["leather"], f.chest,
              seg=12).scale = (1.0, 0.76, 1.0)
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["iron"])
    # The short falchion (tasak) point up in the right hand: a broad blade widening to the tip.
    f.held_r = True
    sword = S.empty("falchion", (0, 0, 0), f.j("hand_r"))
    sword.rotation_euler = (math.radians(-80), 0, 0)
    S.solidify(S.poly("falchion_blade", [(-0.025, 0, 0.06), (0.025, 0, 0.06), (0.05, 0, 0.55), (0.0, 0, 0.66),
                                         (-0.03, 0, 0.58)], [(0, 1, 2, 3, 4)], m["steel"], sword), 0.012)
    S.box("falchion_guard", (0.15, 0.03, 0.025), (0, 0, 0.05), m["iron"], sword)
    # The pavise on his back, its face looking behind him, and the same board planted in front
    # for `work`, its face toward the enemy and a prop stick behind it.
    f.carried = _pavise_board("pavise_back", f.chest, (0, -0.24, -0.62), (math.radians(6), 0, 0), m, scale=0.9)
    f.planted = _pavise_board("pavise_planted", f.root, (0, 0.62, 0.0), (math.radians(-8), 0, math.pi), m)
    S.cyl("pavise_prop", 0.02, 0.02, 1.02, (0.22, 0.6, 0.0), m["wood"], f.planted, rot=(math.radians(28), 0, 0),
          seg=5)
    f.planted.scale = (0.001, 0.001, 0.001)
    return f


def pl_priest():
    m = _m()
    f = Monk("pl_priest")
    f.body(m["skin"], m["surplice"], m["cassock"], m["leather"], sleeve=m["surplice"])
    f.skirt("cassock", 0.06, -0.87, 0.21, 0.31, m["cassock"])
    # The surplice (komża): white to the knees with a lace-like hem, over the cassock.
    f.skirt("surplice", 0.08, -0.42, 0.235, 0.35, m["surplice"])
    for side in ("l", "r"):
        S.limb(f"wide_sleeve_{side}", 0.085, 0.115, 0.27, m["surplice"], f.j(f"elbow_{side}"))
    S.cyl("collar", 0.1, 0.09, 0.06, (0, 0, 0.47), m["cassock"], f.chest, seg=10)
    # The stole in the team colour hanging down in front over the surplice.
    for x in (-0.07, 0.07):
        S.box(f"stole_{x}", (0.06, 0.02, 0.62), (x, 0.205, 0.12), m["team"], f.chest)
        S.box(f"stole_end_{x}", (0.075, 0.03, 0.12), (x * 1.15, 0.22, -0.52), m["team"], f.hips)
    # Tonsure: a ring of hair round a bare crown, clean shaven.
    S.cyl("tonsure", 0.135, 0.125, 0.08, (0, -0.01, -0.01), m["hair"], f.head, seg=14)
    # The cross on a staff, upright in the right hand.
    f.held_r = True
    pole = S.empty("cross_staff", (0, 0, -0.02), f.j("hand_r"))
    pole.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("staff_shaft", 0.02, 0.018, 1.95, (0, 0, -0.8), m["wood"], pole, seg=6)
    top = 1.15
    S.box("cross_v", (0.035, 0.035, 0.42), (0, 0, top + 0.18), m["gold"], pole)
    S.box("cross_h", (0.26, 0.035, 0.035), (0, 0, top + 0.26), m["gold"], pole)
    S.ball("cross_knop", 0.035, (0, 0, top - 0.02), m["gold"], pole)
    return f


def pl_light_horse():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["trousers"], m["leather"], m, m["hair"])
    r.skirt("mail_skirt", 0.06, -0.3, 0.23, 0.3, m["mail"])
    r.skirt("coat_hem", -0.26, -0.33, 0.3, 0.305, m["team"])
    folk._belt(r, m["team"], r=0.24)
    _kapalin(r, m)
    folk._spear(r, m, length=2.7, pennon=m["team"])
    r.held_l = True
    sh = _eagle_shield("shield", r.chest, (-0.25, 0.28, 0.0), m, size=0.42)
    sh.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    S.cyl("sword", 0.015, 0.015, 0.8, (-0.22, -0.05, -0.75), m["steel"], r.hips, rot=(-0.3, 0, 0), seg=5)
    h = beasts.horse("horse", S.mat("pl_bay", "#7a4e30", 0.9, noise=0.25), small=True)
    return beasts.Mounted("pl_light_horse", h, r, m["team"])


def _crown_cover(cart, m):
    """Red on the white canvas: three hoops across it and a red lower edge on both sides."""
    red = _m()["canvas_red"]
    for k, y in enumerate((-0.15, 0.25, 1.1)):
        hoop = S.cyl(f"cover_hoop_{k}", 0.63, 0.63, 0.14, (0, y, 1.2), red, cart, rot=(-math.pi / 2, 0, 0), seg=14)
        hoop.scale = (1.0, 0.755, 1.0)
    for s in (-1, 1):
        S.box(f"cover_edge_{s}", (0.04, 1.6, 0.14), (s * 0.615, 0.5, 1.3), red, cart, rot=(0, s * 0.35, 0))


def _kmet_driver(d, m):
    d.body(m["skin"], m["sermiega"], m["trousers"], m["porshni"], wraps=m["wraps"])
    d.hair(m["fair_hair"])
    S.cyl("cap_band", 0.14, 0.14, 0.06, (0, 0, 0.03), m["cloth_cap"], d.head, seg=12)
    S.ball("cap_top", 0.13, (0, -0.01, 0.1), m["cloth_cap"], d.head, scale=(1, 1, 0.6))
    folk._belt(d, m["team"])


def pl_wagon():
    m = _m()
    return beasts.Wagon("pl_wagon", cover="#ebe7dc", dress=lambda d, _m0: _kmet_driver(d, m), mark=_crown_cover,
                        coat="#5e3e26")


UNITS = {
    "pl_kmet": pl_kmet,
    "pl_bowman": pl_bowman,
    "pl_foot_servant": pl_foot_servant,
    "pl_pavise": pl_pavise,
    "pl_priest": pl_priest,
}
MOUNTED_UNITS = {"pl_light_horse": pl_light_horse}
WAGONS = {"pl_wagon": pl_wagon}
