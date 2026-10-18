"""Heroes of the Crown's Grunwald mission («Корона 1. Грюнвальд, 1410»), on the figure of
people.py, the horse of beasts.py and the pieces of folk_1410.py (armour of 1410: mail,
bascinets, plate arms), folk_1514.py (the White Eagle) and folk_1500.py (the mace). Arms we
are not sure of are not drawn: plain shields and surcoats instead.

- hero_jasko: Jaśko of Łęczyca, a young knight of 22 «in borrowed, not-new armour on a borrowed
  horse»: mail with a few plain plate pieces (forearms, a dull breastplate), an old bascinet with
  its visor, a small plain shield (his arms are unknown), a lance with a team pennon, a plain
  brown horse with only a saddle cloth (attack `thrust`).
- hero_zyndram: Zyndram of Maszkowice, sword-bearer of Kraków, short and stocky (a broad
  breastplate, the figure a little smaller), full armour of 1410 under a plain red surcoat (his
  arms are not drawn), an open bascinet with a dark beard, a mace (attack `swing`), a bay horse
  with a red caparison.
- hero_marcin: Marcin of Wrocimowice with the great banner of the Kingdom: a big red banner with
  the crowned White Eagle on a lance (folk_1514's eagle, the banner of folk_1410), a bascinet,
  plate arms, a red surcoat, a grey horse with a red caparison (attack `thrust`, like
  hero_sampolinski).
- hero_olesnicki (template `light`): Zbigniew Oleśnicki, the king's secretary of 20, no armour:
  a long dark cleric's gown, a dark skullcap over a tonsure-short haircut, no beard, a light
  horse with a plain saddle cloth; in his hand the stump of a broken lance (attack `swing`).
- hero_jagiello (`sovereign`): King Władysław II Jagiełło, about 60, grey, clean shaven: armour
  of 1410 under a red mantle, a gold crown on an open bascinet, a sword (attack `swing`); his
  banner is hidden in the story, so the man on foot beside him is a guard with a spear (mail,
  a kettle hat, a red tabard), not a standard-bearer.
- hero_stranger (`civilian`): the stranger in red, a merry man on foot without armour or
  weapons: a red kaftan to the knees with gold buttons and a team sash, a red cap with a fur
  band, dark hair and a short beard, boots; idle and walk only. Nothing supernatural shows.
- hero_order_k1: Konrad von Lichtenstein, Grand Commander, a knight brother in the white mantle
  with the black cross on a big dark horse with a white caparison, like hero_wallenrode, but
  with an open bascinet and a sword at the hip beside the lance (attack `thrust`).
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1410 import Sovereign, _banner, _plate_arms, _sword
from tools.art.folk_1500 import _mace
from tools.art.folk_1514 import _white_eagle
from tools.art.folk_crown import _m as _m_crown


def _m():
    m = _m_crown()
    m.update({
        "old_steel": S.mat("old_steel", "#878a8c", 0.55, noise=0.3, metal=0.75),
        "plain_shield": S.mat("plain_shield", "#8a7458", 0.9, noise=0.3),
        "surcoat_red": S.mat("surcoat_red", "#a3261e", 0.9, noise=0.12),
        "gown": S.mat("cleric_gown", "#22212a", 0.95, noise=0.1),
        "kaftan_red": S.mat("stranger_kaftan", "#b8261c", 0.85, noise=0.1),
        "dark_hair": S.mat("dark_hair_k1", "#2e2219", 0.9, noise=0.2),
        "red_cloth": S.mat("red_cloth", "#a3261e", 0.9, noise=0.12),
        "white_cloth": S.mat("white_cloth", "#e9e6dc", 0.9, noise=0.08),
        "boots": S.mat("riding_boots", "#3a2a1e", 0.8, noise=0.2),
    })
    return m


def _open_bascinet(f, m, mat=None):
    """A bascinet without its visor, the face showing, a mail aventail on the shoulders."""
    mat = mat or m["steel"]
    S.ball("bascinet", 0.15, (0, -0.02, 0.05), mat, f.head, scale=(1.0, 1.05, 1.2))
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], f.head)
    S.cyl("aventail", 0.22, 0.13, 0.17, (0, 0, -0.17), m["mail"], f.head, seg=12)


def _surcoat(f, mat, bottom=-0.4):
    """A sleeveless surcoat over the armour, its skirt split over the saddle."""
    S.box("surcoat", (0.44, 0.36, 0.6), (0, 0.0, 0.16), mat, f.chest)
    f.skirt("surcoat_skirt", 0.06, bottom, 0.24, 0.33, mat)


def _sword_hip(f, m):
    S.cyl("hip_sword", 0.016, 0.014, 0.85, (-0.23, -0.04, -0.8), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=5)
    S.box("hip_sword_guard", (0.03, 0.16, 0.025), (-0.23, 0.02, -0.02), m["steel"], f.hips)


# --- heroes --------------------------------------------------------------------------------

def hero_jasko():
    m = _m()
    old = m["old_steel"]
    r = beasts._rider("rider", m["mail"], m["mail"], m["leather"], m, m["fair_hair"], beard=False)
    # Mail to the thighs; only the forearms and a dull breastplate are plate (borrowed pieces).
    r.skirt("mail_skirt", 0.06, -0.34, 0.23, 0.3, m["mail"])
    for side in ("l", "r"):
        S.limb(f"plate_fore_{side}", 0.072, 0.06, 0.26, old, r.j(f"elbow_{side}"))
    S.cyl("breastplate", 0.19, 0.235, 0.34, (0, 0.012, 0.1), old, r.chest, seg=10).scale = (1.0, 0.76, 1.0)
    folk._belt(r, m["team"], r=0.24)
    folk._bascinet(r, old, visor=True)
    beasts._lance(r, m, length=3.7, pennon=m["team"])
    # A small plain shield: worn wood with an iron boss, the team rim.
    sh = folk._heater(r, m["plain_shield"], m, cross=False)
    sh.scale = (0.82, 0.82, 0.82)
    S.ball("shield_boss", 0.04, (0, -0.05, 0.36), m["iron"], sh, scale=(1.0, 0.6, 1.0))
    h = beasts.horse("horse", S.mat("plain_brown", "#6a4a32", 0.95, noise=0.3), size=0.98)
    return beasts.Mounted("hero_jasko", h, r, m["team"])


def hero_zyndram():
    m = _m()
    red = m["surcoat_red"]
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m, m["dark_hair"])
    _plate_arms(r, m)
    for side in ("l", "r"):
        S.ball(f"couter_{side}", 0.075, (0, 0, 0.0), m["steel"], r.j(f"elbow_{side}"))
    r.skirt("tassets", 0.06, -0.25, 0.24, 0.31, m["steel"])
    # Short and stocky: a broad chest under the surcoat; the whole man a little smaller.
    S.cyl("broad_chest", 0.22, 0.27, 0.5, (0, 0.0, 0.0), m["steel"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    S.box("surcoat", (0.52, 0.4, 0.58), (0, 0.0, 0.16), red, r.chest)
    r.skirt("surcoat_skirt", 0.06, -0.4, 0.27, 0.35, red)
    folk._belt(r, m["team"], r=0.27)
    _open_bascinet(r, m)
    S.ball("full_beard", 0.09, (0, 0.08, -0.1), m["dark_hair"], r.head, scale=(1.15, 0.85, 1.1))
    _mace(r, m, head=m["steel"], flanges=6)
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("bay", "#6e4026", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, red, m["team"])
    mounted = beasts.Mounted("hero_zyndram", h, r, m["team"])
    s = 0.94
    r.root.scale = (s * 1.04, s * 1.04, s)
    r.root.location.z += people.HIP_Z * (1 - s)
    return mounted


def hero_marcin():
    m = _m()
    red = m["surcoat_red"]
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m, m["hair"], beard=False)
    _plate_arms(r, m)
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    _surcoat(r, red)
    folk._belt(r, m["team"], r=0.25)
    _open_bascinet(r, m)
    # The great banner of the Kingdom: the crowned White Eagle on red, bigger than a court banner.
    def eagles(cloth):  # on both faces of the cloth, so it shows from every side
        _white_eagle("banner_eagle", cloth, (0, -0.012, 0.03), 1.1, m)
        _white_eagle("banner_eagle_back", cloth, (0, 0.012, 0.03), 1.1, m).rotation_euler = (0, 0, math.pi)

    _banner(r, m, m["court_red"], eagles, width=0.9, height=0.78, length=3.6)
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, red, m["team"])
    return beasts.Mounted("hero_marcin", h, r, m["team"])


def _broken_lance(f, m):
    """The stump of a lance held upright: a short shaft ending in splinters."""
    f.held_r = True
    stump = S.empty("lance_stump", (0, 0, -0.02), f.j("hand_r"))
    stump.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("stump_shaft", 0.026, 0.022, 1.2, (0, 0, -0.45), m["wood"], stump, seg=8)
    S.cyl("stump_vamplate", 0.07, 0.03, 0.06, (0, 0, -0.1), m["iron"], stump, seg=8)
    for k, (x, y, tilt, ln) in enumerate(((0.012, 0.0, 12, 0.16), (-0.012, 0.01, -15, 0.12),
                                          (0.0, -0.014, 6, 0.2), (0.0, 0.016, -8, 0.09))):
        S.cyl(f"stump_splinter_{k}", 0.01, 0.001, ln, (x, y, 0.74), m["wood"], stump,
              rot=(math.radians(tilt), math.radians(-tilt), 0), seg=3, smooth=False)
    return stump


def hero_olesnicki():
    m = _m()
    gown = m["gown"]
    r = beasts._rider("rider", gown, gown, m["leather"], m, m["dark_hair"], beard=False)
    # A cleric's long dark gown, its skirt falling over the saddle, a narrow white collar.
    r.skirt("gown_skirt", 0.06, -0.5, 0.22, 0.34, gown)
    S.cyl("gown_collar", 0.07, 0.07, 0.04, (0, 0, 0.47), m["white_cloth"], r.chest, seg=10)
    folk._belt(r, m["team"], r=0.225)
    S.ball("skullcap", 0.132, (0, -0.01, 0.05), m["beret"], r.head, scale=(1.0, 1.0, 0.65))
    _broken_lance(r, m)
    h = beasts.horse("horse", S.mat("light_dun", "#9a7a52", 0.9, noise=0.25), small=True)
    return beasts.Mounted("hero_olesnicki", h, r, m["team"])


def _crown(f, m):
    """A gold crown over the open bascinet: a band with fleurons."""
    S.cyl("crown_band", 0.155, 0.155, 0.05, (0, -0.02, 0.07), m["gold"], f.head, seg=14)
    for k in range(6):
        a = k * math.tau / 6
        S.box(f"crown_fleuron_{k}", (0.05, 0.02, 0.07), (0.15 * math.cos(a), -0.02 + 0.15 * math.sin(a), 0.12),
              m["gold"], f.head, rot=(0, 0, a + math.pi / 2))


def hero_jagiello():
    m = _m()
    grey = m["grey_hair"]
    r = beasts._rider("rider", m["brigandine"], m["steel"], m["steel"], m, grey, beard=False)
    _plate_arms(r, m)
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    folk._cloak(r, m["red_cloak"], bottom=-0.65, r_bottom=0.42)
    S.cyl("cloak_collar", 0.26, 0.2, 0.08, (0, -0.02, 0.44), m["fur"], r.chest, seg=12)
    S.cyl("cloak_clasp", 0.04, 0.04, 0.02, (0, 0.2, 0.4), m["gold"], r.chest, rot=(-math.pi / 2, 0, 0), seg=8)
    _open_bascinet(r, m)
    _crown(r, m)
    _sword(r, m)
    h = beasts.horse("horse", S.mat("white_horse", "#d8d4cc", 0.9, noise=0.2), size=1.04)
    beasts.caparison(h, m["court_red"], m["team"])
    # A guard on foot with a spear (the king's banner is hidden in the story).
    g = people.Figure("guard")
    g.body(m["skin"], m["mail"], m["trousers"], m["leather"], sleeve=m["mail"])
    g.hair(m["hair"])
    g.skirt("coat_skirt", 0.06, -0.4, 0.22, 0.3, m["red_cloth"])
    S.box("tabard", (0.4, 0.34, 0.66), (0, 0.0, 0.12), m["red_cloth"], g.chest)
    folk._belt(g, m["team"], r=0.24)
    folk._chapel(g, m["steel"])
    folk._spear(g, m, length=2.4)
    return Sovereign("hero_jagiello", h, r, m["team"], g)


def hero_stranger():
    m = _m()
    f = people.Figure("hero_stranger")
    red = m["kaftan_red"]
    f.body(m["skin"], red, m["trousers"], m["boots"])
    f.hair(m["dark_hair"], beard=False)
    S.ball("short_beard", 0.08, (0, 0.08, -0.095), m["dark_hair"], f.head, scale=(1.05, 0.8, 0.9))
    # A smile: the mouth line raised at both corners.
    S.box("smile", (0.07, 0.012, 0.012), (0, 0.122, -0.055), S.mat("lips", "#7a3a2a", 0.8), f.head)
    for x in (-1, 1):
        S.box(f"smile_{x}", (0.02, 0.012, 0.012), (x * 0.04, 0.118, -0.048), S.mat("lips", "#7a3a2a", 0.8), f.head,
              rot=(0, x * math.radians(-35), 0))
    # The red kaftan to the knees, gold buttons down the front, a sash in the player colour.
    f.skirt("kaftan_skirt", 0.06, -0.52, 0.23, 0.32, red)
    for k in range(5):
        S.ball(f"kaftan_button_{k}", 0.018, (0, 0.17, 0.36 - k * 0.08), m["gold"], f.chest)
    folk._belt(f, m["team"], r=0.235)
    # A red cap with a fur band, worn tilted.
    cap = S.cyl("cap_fur", 0.145, 0.14, 0.07, (0, -0.01, 0.05), m["fur"], f.head, rot=(0, math.radians(8), 0),
                seg=12)
    S.ball("cap_top", 0.13, (0, 0, 0.05), red, cap, scale=(1.0, 1.0, 0.75))
    return f


def hero_order_k1():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["steel"], m["steel"], m, m["hair"])
    _plate_arms(r, m)
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.3, m["order_black"])
    _open_bascinet(r, m)
    beasts._lance(r, m, length=4.0, pennon=m["team"])
    folk._heater(r, m["order_white"], m)
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25), size=1.1)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    return beasts.Mounted("hero_order_k1", h, r, m["team"])


UNITS = {"hero_stranger": hero_stranger}
MOUNTED_UNITS = {
    "hero_jasko": hero_jasko,
    "hero_zyndram": hero_zyndram,
    "hero_marcin": hero_marcin,
    "hero_olesnicki": hero_olesnicki,
    "hero_jagiello": hero_jagiello,
    "hero_order_k1": hero_order_k1,
}
