"""Heroes of the battle of Wiłkomierz (ВКЛ 4, 1435), on the figure of people.py, the horse of
beasts.py and the `sovereign` template of folk_1410.py (visual assets doc, «Герои ВКЛ и их
противники»).

- hero_mikolaj: Mikołaj Gintovt, Gintaut's elder son, about 22: an open bascinet with an
  aventail, a breastplate under green cloth (a covered cuirass), plate arms, a gold Catholic
  cross on the neck, the woven belt of his mother at the waist, the family arms on shield
  and caparison, a sword.
- hero_jurij_gintovt: his younger brother with the same head, in Ruthenian dress of a
  Švitrigaila man: a long red kaftan over mail, a pointed helmet with an aventail, a fur
  collar, the same family arms; on his lance under the pennon the woven belt is tied, its
  ends hanging (the «Братин знак» of the mission).
- hero_mikhail_sigismundovich: the young prince in rich plate of the 1430s, gilt edges, a
  gold coronet on a visored bascinet, the Pogoń on a red shield and caparison, a sword.
- hero_jakub_kobylany: a mature Polish knight commanding the Crown corps, dark beard, visor
  raised, plate over a brigandine, a lance with a pennon. His arms are not verified (doc:
  «родовой герб сверить»), so no charge is drawn: shield per fess white and red, the
  caparison red with a white band (neutral Polish colours).
- hero_nesselrode: a knight brother of the Livonian Order: the white cloak with the black
  cross, visored bascinet, a lance with a pennon, a white caparison (as hero_wallenrode).
- hero_kerskorf: the Livonian Master, mature, grey beard, an open bascinet, the white cloak
  and the black cross, a sword; his bearer on foot carries the Order's banner (white, black
  cross). No personal arms are drawn (not verified).

The Gintovt arms are a placeholder until checked against an armorial (the doc only says «герб
рода»): vert, a fess dancetty argent, a white zigzag on green that echoes the woven belt.
"""

import math

from tools.art import beasts, folk
from tools.art import shapes as S
from tools.art.folk_1410 import Sovereign, _banner, _bearer, _m as _m1410, _plate_arms, _pogon, _sword


def _m():
    m = _m1410()
    m.update({
        "gintovt_green": S.mat("gintovt_green", "#346a44", 0.9, noise=0.12),
        "kaftan": S.mat("kaftan_red", "#8a2a24", 0.9, noise=0.14),
        "woven_red": S.mat("woven_red", "#a8342a", 0.95, noise=0.3),
        "woven_white": S.mat("woven_white", "#e6dcc4", 0.95, noise=0.2),
        "dark_hair": S.mat("dark_hair", "#3a2a1c", 0.9, noise=0.2),
        "greying_hair": S.mat("greying_hair", "#7e766a", 0.9, noise=0.25),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _gintovt_arms(name, parent, loc, w, h, m):
    """The (placeholder) Gintovt arms in the XZ plane of `parent`, thin along Y: a green field
    w x h with a white zigzag fess across the middle."""
    holder = S.empty(name, loc, parent)
    S.box(f"{name}_field", (w, 0.03, h), (0, 0, 0), m["gintovt_green"], holder)
    n = 4
    seg = w / n
    for k in range(n):
        up = 1 if k % 2 == 0 else -1
        S.box(f"{name}_zig_{k}", (seg / math.cos(math.radians(40)), 0.04, h * 0.14),
              (-w / 2 + seg * (k + 0.5), 0, 0), m["white_cloth"], holder, rot=(0, math.radians(40) * up, 0))
    return holder


def _woven_belt(f, m, r=0.24):
    """The mother's woven belt: red with a white pattern band, worn at the waist."""
    folk._belt(f, m["woven_red"], r=r)
    band = S.cyl("belt_pattern", r + 0.004, r + 0.004, 0.022, (0, 0, 0.03), m["woven_white"], f.hips, seg=12)
    band.scale = (1.0, 0.8, 1.0)
    S.box("belt_end", (0.05, 0.02, 0.2), (0.08, r * 0.8, -0.08), m["woven_red"], f.hips)


def _neck_cross(f, m, mat=None):
    """A small gold Catholic cross on a chain, on the chest."""
    holder = S.empty("neck_cross", (0, 0.2, 0.3), f.chest)
    mat = mat or m["gold"]
    S.box("neck_cross_v", (0.025, 0.02, 0.1), (0, 0, 0), mat, holder)
    S.box("neck_cross_h", (0.065, 0.02, 0.022), (0, 0, 0.018), mat, holder)
    return holder


def _open_bascinet(f, m, aventail=True):
    S.ball("bascinet", 0.15, (0, -0.02, 0.05), m["steel"], f.head, scale=(1.0, 1.05, 1.2))
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], f.head)
    if aventail:
        S.cyl("aventail", 0.22, 0.13, 0.17, (0, 0, -0.17), m["mail"], f.head, seg=12)


def _gintovt_shield(f, m):
    sh = folk._heater(f, m["gintovt_green"], m, cross=False)
    _gintovt_arms("shield_arms", sh, (0, -0.045, 0.4), 0.36, 0.3, m)
    return sh


def _gintovt_horse(m, coat, name="horse"):
    h = beasts.horse(name, coat)
    beasts.caparison(h, m["gintovt_green"], m["team"])
    for s in (-1, 1):
        _gintovt_arms(f"cap_arms_{s}", h.body, (s * (h.rx + 0.07), 0.0, -0.22), 0.7, 0.42, m).rotation_euler = (
            0, 0, math.pi / 2)
    return h


# --- heroes --------------------------------------------------------------------------------

def hero_mikolaj():
    m = _m()
    r = beasts._rider("rider", m["gintovt_green"], m["steel"], m["steel"], m, m["fair_hair"], beard=False)
    _plate_arms(r, m)
    # The cuirass under cloth: a green covered breastplate, a short green skirt over tassets.
    S.cyl("covered_cuirass", 0.19, 0.24, 0.38, (0, 0.012, 0.08), m["gintovt_green"], r.chest, seg=12).scale = (
        1.0, 0.78, 1.0)
    r.skirt("tassets", 0.06, -0.3, 0.23, 0.3, m["steel"])
    r.skirt("cloth_skirt", 0.06, -0.2, 0.235, 0.305, m["gintovt_green"])
    _woven_belt(r, m)
    _neck_cross(r, m)
    _open_bascinet(r, m)
    _sword(r, m)
    _gintovt_shield(r, m)
    h = _gintovt_horse(m, S.mat("bay", "#6e4428", 0.9, noise=0.25))
    return beasts.Mounted("hero_mikolaj", h, r, m["team"])


def hero_jurij_gintovt():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["trousers"], m["leather"], m, m["fair_hair"], beard=False)
    # A long red kaftan over mail, buttoned down the front, a fur collar.
    S.cyl("kaftan", 0.2, 0.245, 0.42, (0, 0.0, 0.06), m["kaftan"], r.chest, seg=12).scale = (1.0, 0.78, 1.0)
    r.skirt("kaftan_skirt", 0.06, -0.55, 0.24, 0.34, m["kaftan"])
    for k in range(4):
        S.ball(f"kaftan_button_{k}", 0.018, (0, 0.2, 0.36 - k * 0.09), m["gold"], r.chest)
    S.cyl("fur_collar", 0.26, 0.18, 0.1, (0, -0.02, 0.43), m["fur"], r.chest, seg=12)
    folk._belt(r, m["leather"], r=0.245)
    # A pointed Ruthenian helmet (шишак) with an aventail.
    S.cyl("helmet", 0.145, 0.02, 0.3, (0, 0, 0.03), m["steel"], r.head, seg=12)
    S.cyl("helmet_spike", 0.012, 0.004, 0.1, (0, 0, 0.32), m["steel"], r.head, seg=4)
    S.cyl("aventail", 0.2, 0.14, 0.16, (0, -0.03, -0.15), m["mail"], r.head, seg=12)
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], r.head)
    # The banner lance: a pennon, the woven belt tied under it with its two ends hanging.
    spear = beasts._lance(r, m, length=3.6, pennon=m["team"])
    knot_z = 3.6 - 1.25
    S.cyl("lance_belt", 0.03, 0.03, 0.06, (0, 0, knot_z), m["woven_red"], spear, seg=8)
    S.cyl("lance_belt_band", 0.032, 0.032, 0.02, (0, 0, knot_z), m["woven_white"], spear, seg=8)
    for k, (dx, tilt) in enumerate(((0.03, 8), (-0.02, -5))):
        end = S.empty(f"lance_belt_end_{k}", (dx, 0, knot_z), spear)
        end.rotation_euler = (0, math.radians(tilt), 0)
        S.box(f"lance_belt_tail_{k}", (0.045, 0.012, 0.42), (0, 0, -0.22), m["woven_red"], end)
        S.box(f"lance_belt_stripe_{k}", (0.047, 0.014, 0.04), (0, 0, -0.3), m["woven_white"], end)
    _gintovt_shield(r, m)
    h = _gintovt_horse(m, S.mat("dun", "#9a8058", 0.9, noise=0.25))
    return beasts.Mounted("hero_jurij_gintovt", h, r, m["team"])


def hero_mikhail_sigismundovich():
    m = _m()
    r = beasts._rider("rider", m["steel"], m["steel"], m["steel"], m, m["hair"], beard=False)
    _plate_arms(r, m)
    # Full plate with gilt edges: breastplate, fauld of lames, gold rims.
    S.cyl("breastplate", 0.19, 0.24, 0.38, (0, 0.012, 0.08), m["steel"], r.chest, seg=12).scale = (1.0, 0.78, 1.0)
    S.cyl("breast_rim", 0.195, 0.195, 0.03, (0, 0.012, 0.44), m["gold"], r.chest, seg=12).scale = (1.0, 0.78, 1.0)
    for k in range(3):
        r.skirt(f"fauld_{k}", 0.04 - 0.1 * k, -0.06 - 0.1 * k, 0.235 + 0.01 * k, 0.25 + 0.012 * k, m["steel"])
    r.skirt("fauld_rim", -0.26, -0.29, 0.272, 0.274, m["gold"])
    folk._belt(r, m["gold"], r=0.245)
    # A short red cloak thrown back, held by a gold clasp.
    S.cyl("cloak_back", 0.34, 0.26, 0.75, (0, -0.1, -0.25), m["red_cloak"], r.chest, seg=12).scale = (1.0, 0.55, 1.0)
    # A visored bascinet with a gold coronet and a team plume.
    folk._bascinet(r, m["steel"], visor=True)
    S.cyl("coronet", 0.148, 0.15, 0.05, (0, -0.01, 0.06), m["gold"], r.head, seg=14)
    for k in range(6):
        a = k * math.tau / 6
        S.cyl(f"coronet_point_{k}", 0.02, 0.0, 0.06, (0.15 * math.cos(a), -0.01 + 0.15 * math.sin(a), 0.11),
              m["gold"], r.head, seg=4, smooth=False)
    S.ball("plume", 0.07, (0, -0.06, 0.24), m["team"], r.head, scale=(0.7, 1.4, 1.2))
    _sword(r, m)
    sh = folk._heater(r, m["red_cloth"], m, cross=False)
    _pogon("shield_pogon", sh, (0, -0.05, 0.38), 0.42, m["white_cloth"])
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, m["red_cloth"], m["team"])
    for s in (-1, 1):
        _pogon(f"cap_pogon_{s}", h.body, (s * (h.rx + 0.075), 0.0, -0.3), 0.55, m["white_cloth"]).rotation_euler = (
            0, 0, math.pi / 2 * s)
    return beasts.Mounted("hero_mikhail_sigismundovich", h, r, m["team"])


def hero_jakub_kobylany():
    m = _m()
    r = beasts._rider("rider", m["brigandine"], m["steel"], m["steel"], m, m["dark_hair"])
    _plate_arms(r, m)
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    for i, z in enumerate((0.1, 0.22, 0.34)):
        S.cyl(f"rivets_{i}", 0.2 - 0.01 * i, 0.2 - 0.01 * i, 0.015, (0, 0, z), m["gold"], r.chest, seg=12).scale = (
            1.0, 0.76, 1.0)
    folk._belt(r, m["leather"], r=0.24)
    # A bascinet with the visor raised over the face: the mature commander's beard shows.
    _open_bascinet(r, m)
    S.cyl("visor_raised", 0.07, 0.01, 0.17, (0, 0.04, 0.2), m["steel"], r.head, rot=(-math.radians(30), 0, 0), seg=8)
    beasts._lance(r, m, length=3.9, pennon=m["team"])
    # Arms not verified: a plain shield per fess white and red, no charge.
    sh = folk._heater(r, m["red_cloth"], m, cross=False)
    S.box("shield_chief", (0.4, 0.03, 0.25), (0, -0.045, 0.47), m["white_cloth"], sh)
    h = beasts.horse("horse", S.mat("chestnut", "#7a4a2a", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, m["red_cloth"], m["team"])
    band = S.cyl("cap_band", 1.0, 1.0, 0.12, (0, 0, -0.38), m["white_cloth"], h.body, seg=16)
    band.scale = (h.rx + 0.056, h.half + 0.066, 1.0)
    return beasts.Mounted("hero_jakub_kobylany", h, r, m["team"])


def hero_nesselrode():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m)
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.3, m["order_black"])
    folk._bascinet(r, m["steel"], visor=True)
    beasts._lance(r, m, length=3.9, pennon=m["team"])
    folk._heater(r, m["order_white"], m)
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    return beasts.Mounted("hero_nesselrode", h, r, m["team"])


def hero_kerskorf():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m, m["greying_hair"])
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.2, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.32, m["order_black"])
    _open_bascinet(r, m)
    S.ball("long_beard", 0.085, (0, 0.08, -0.12), m["greying_hair"], r.head, scale=(1.0, 0.8, 1.3))
    _sword(r, m)
    folk._heater(r, m["order_white"], m)
    h = beasts.horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25), size=1.08)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    b = _bearer(m, m["order_white"], m["mail"], m["hair"])
    folk._cross("bearer_cross", b.chest, (0, 0.18, 0.25), 0.2, m["order_black"])
    _banner(b, m, m["order_white"], lambda c: folk._cross("banner_cross", c, (0, 0, 0.0), 0.45, m["order_black"]))
    return Sovereign("hero_kerskorf", h, r, m["team"], b)


UNITS: dict = {}
MOUNTED_UNITS = {
    "hero_mikolaj": hero_mikolaj,
    "hero_jurij_gintovt": hero_jurij_gintovt,
    "hero_mikhail_sigismundovich": hero_mikhail_sigismundovich,
    "hero_jakub_kobylany": hero_jakub_kobylany,
    "hero_nesselrode": hero_nesselrode,
    "hero_kerskorf": hero_kerskorf,
}
