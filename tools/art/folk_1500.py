"""Units of the battle of Vedrosha (ВКЛ 5, 14 July 1500): the Duchy's noble lancer and field
gun, the first Muscovite troops and the heroes, on the figure of people.py, the horse of
beasts.py and the templates of folk_1410.py (visual assets doc, «Юниты», «Московское
государство», «Герои ВКЛ и их противники»; armour of 1490–1514: gothic plate, sallets,
guns on wheeled carriages; for Muscovy tegilyai and saadak, no berdysh, no streltsy kaftans,
no zertsalo).

The Duchy:
- gdl_szlachta_lance: full plate of about 1500, a sallet with a bevor, a red tunic over the
  plate, a long lance with a two-tailed pennon, the heavy horse with a chanfron.
- gdl_field_gun: a bronze barrel on a two-wheeled carriage with a trail, two gunners; on the
  march a horse pulls it trail first; it fires with a flash, smoke and recoil.
Muscovy (no colours of its own existed in the art yet; these are new: a blue-grey tegilyai,
dark red and blue cloth, gilt on the rich):
- mo_syn_boyarsky: pomestie horseman: a quilted tegilyai with a high collar, a spheroconical
  helmet, the saadak with a composite bow, a sabre, short stirrups, a small horse, an
  eastern saddle with a high pommel.
- mo_boyar: rich mail with a bakhterets of small plates, a shishak with a mail barmitsa, a
  lance, a sabre, a round shield, a coloured chaprak.
- mo_inok: a monk on foot in a black ryasa and klobuk with its veil, a long beard, an icon
  in a kiot on a pole (the spell «Икона перед войском»; the face is not drawn, at this scale
  it is a spot); `cast` raises the icon over his head.
Heroes:
- hero_andrei: Andrei Gintovt, about 20, the khorunzhy of the land nobility of Ostrogski:
  plate of about 1500 under a long green kaftan, an open sallet, his family's woven belt,
  a small gold Orthodox cross, the khorugv in his hand with the (placeholder) Gintovt arms
  of folk_1435 (a white zigzag on green), the same arms on the caparison.
- hero_ostrogski: Prince Konstanty Ostrogski, hetman, about 40, dark beard, rich plate under
  a crimson kaftan with gold, an open gilt-rimmed sallet, a gold Orthodox cross, the
  hetman's bulawa. His arms are not drawn (not verified): a plain dark saddle cloth.
- hero_shchenya (`sovereign`): the voivode Daniil Shchenya, mature, full beard, a gilt
  shishak, a bakhterets over mail under a red ferjaz, a pernach; his bearer on foot in a
  tegilyai carries a dark red banner with the rider spearing the serpent (coa_mo: the rider
  of the seals of Ivan III, without the later eagle).
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1410 import Sovereign, _banner, _composite_bow, _orthodox_cross
from tools.art.folk_1435 import _gintovt_arms, _gintovt_horse, _m as _m1435, _woven_belt


def _m():
    m = _m1435()
    m.update({
        "bronze": S.mat("bronze", "#a87a3c", 0.35, metal=0.85),
        "plate": S.mat("plate_1500", "#b4b8bc", 0.25, metal=0.92),
        "tunic_red": S.mat("tunic_red", "#9a2a22", 0.9, noise=0.12),
        "tegilyai": S.mat("tegilyai", "#56607a", 0.95, noise=0.3),
        "tegilyai_seam": S.mat("tegilyai_seam", "#3e465a", 0.95, noise=0.2),
        "mo_red": S.mat("mo_red", "#7c1e1a", 0.9, noise=0.12),
        "ferjaz": S.mat("ferjaz_red", "#a8241e", 0.8, noise=0.1),
        "chaprak_blue": S.mat("chaprak_blue", "#2e4a7a", 0.9, noise=0.12),
        "crimson": S.mat("crimson", "#6e1c2a", 0.85, noise=0.1),
        "black_robe": S.mat("black_robe", "#1c1a1d", 0.95, noise=0.08),
        "icon_dark": S.mat("icon_dark", "#3a2418", 0.8, noise=0.2),
        "carriage": S.mat("carriage", "#6a4a2e", 0.85, noise=0.3),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _sallet(f, m, mat, bevor=True, open_face=False):
    """A sallet: a rounded bowl with a long tail over the neck; with a bevor over the chin
    and a visor slit, or open over the face."""
    S.ball("sallet", 0.15, (0, -0.01, 0.04), mat, f.head, scale=(1.0, 1.08, 1.05))
    S.cyl("sallet_tail", 0.13, 0.07, 0.2, (0, -0.06, 0.0), mat, f.head, rot=(math.radians(112), 0, 0), seg=10)
    if open_face:
        S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.03), m["skin"], f.head)
    else:
        S.box("sallet_slit", (0.17, 0.03, 0.022), (0, 0.15, 0.02), S.mat("slit", "#141414", 1.0), f.head)
    if bevor:
        S.cyl("bevor", 0.13, 0.17, 0.2, (0, 0.04, -0.2), mat, f.head, seg=12)


def _shishak(f, m, mat=None, rim=None, barmitsa=True):
    """A tall pointed Russian helmet with a spike, a mail barmitsa over the neck."""
    mat = mat or m["steel"]
    S.cyl("shishak", 0.15, 0.03, 0.24, (0, 0, 0.02), mat, f.head, seg=12)
    S.cyl("shishak_spike", 0.03, 0.004, 0.16, (0, 0, 0.25), mat, f.head, seg=6)
    if rim is not None:
        S.cyl("shishak_rim", 0.153, 0.15, 0.04, (0, 0, 0.02), rim, f.head, seg=12)
    if barmitsa:
        S.cyl("barmitsa", 0.21, 0.145, 0.17, (0, -0.03, -0.15), m["mail"], f.head, seg=12)
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], f.head)


def _spheroconical(f, m):
    """A low spheroconical helmet: a dome rising into a short point, a small aventail."""
    S.ball("helmet_dome", 0.145, (0, 0, 0.04), m["iron"], f.head, scale=(1.0, 1.0, 0.85))
    S.cyl("helmet_point", 0.1, 0.01, 0.15, (0, 0, 0.1), m["iron"], f.head, seg=12)
    S.cyl("aventail", 0.19, 0.14, 0.12, (0, -0.04, -0.1), m["mail"], f.head, seg=12)


def _plate_harness(f, m, mat=None, faulds=3):
    """Plate of about 1500: a breastplate with a ridge, a fauld of lames, plate arms."""
    mat = mat or m["plate"]
    for side in ("l", "r"):
        S.limb(f"plate_arm_{side}", 0.085, 0.07, 0.3, mat, f.j(f"shoulder_{side}"))
        S.limb(f"plate_fore_{side}", 0.072, 0.06, 0.28, mat, f.j(f"elbow_{side}"))
        S.ball(f"pauldron_{side}", 0.11, (0, 0, -0.02), mat, f.j(f"shoulder_{side}"), scale=(1.0, 1.0, 0.8))
    S.cyl("breastplate", 0.19, 0.24, 0.38, (0, 0.012, 0.08), mat, f.chest, seg=12).scale = (1.0, 0.78, 1.0)
    S.box("breast_ridge", (0.03, 0.03, 0.3), (0, 0.19, 0.24), mat, f.chest, rot=(math.radians(-10), 0, 0))
    for k in range(faulds):
        f.skirt(f"fauld_{k}", 0.04 - 0.1 * k, -0.06 - 0.1 * k, 0.235 + 0.01 * k, 0.25 + 0.012 * k, mat)


def _kaftan(f, m, mat, long=True, buttons=None, collar=None):
    """A long kaftan over the armour, buttoned down the front, its skirt over the saddle."""
    S.cyl("kaftan", 0.205, 0.25, 0.42, (0, 0.0, 0.06), mat, f.chest, seg=12).scale = (1.0, 0.8, 1.0)
    f.skirt("kaftan_skirt", 0.06, -0.6 if long else -0.35, 0.25, 0.35, mat)
    if buttons is not None:
        for k in range(5):
            S.ball(f"kaftan_button_{k}", 0.017, (0, 0.205, 0.4 - k * 0.08), buttons, f.chest)
    if collar is not None:
        S.cyl("kaftan_collar", 0.25, 0.17, 0.1, (0, -0.02, 0.43), collar, f.chest, seg=12)


def _tegilyai(f, m, mat=None):
    """A thick quilted coat with a high standing collar and short sleeves, below the knee;
    quilting seams run round it."""
    mat = mat or m["tegilyai"]
    S.cyl("tegilyai", 0.2, 0.25, 0.44, (0, 0.0, 0.05), mat, f.chest, seg=12).scale = (1.0, 0.8, 1.0)
    f.skirt("tegilyai_skirt", 0.06, -0.48, 0.25, 0.34, mat)
    for k, z in enumerate((0.14, 0.26, 0.38)):
        S.cyl(f"tegilyai_seam_{k}", 0.24 - 0.012 * k, 0.24 - 0.012 * k, 0.016, (0, 0.0, z), m["tegilyai_seam"],
              f.chest, seg=12).scale = (1.0, 0.8, 1.0)
    for k, z in enumerate((-0.12, -0.3)):
        rad = 0.25 + (0.06 - z) / 0.54 * 0.09 + 0.006
        f.skirt(f"tegilyai_skirt_seam_{k}", z + 0.01, z - 0.01, rad, rad, m["tegilyai_seam"])
    S.cyl("tegilyai_collar", 0.17, 0.15, 0.14, (0, -0.01, 0.44), mat, f.chest, seg=12)
    for side in ("l", "r"):
        S.limb(f"tegilyai_sleeve_{side}", 0.095, 0.085, 0.2, mat, f.j(f"shoulder_{side}"))


def _bakhterets(f, m, rows=5, gilt=None):
    """A bakhterets: rows of small steel plates over the mail of the body, with gilt rows
    on the rich."""
    for k in range(rows):
        mat = gilt if gilt is not None and k == rows - 1 else m["steel"]
        z = 0.06 + k * 0.075
        r = 0.235 - 0.008 * k
        S.cyl(f"bakhterets_{k}", r, r - 0.005, 0.06, (0, 0.0, z), mat, f.chest, seg=14).scale = (1.0, 0.8, 1.0)


def _sabre_hip(f, m, side=-1):
    """A sabre in its scabbard at the hip (left by default), hilt forward."""
    holder = S.empty("sabre", (side * 0.25, 0.08, -0.05), f.hips)
    holder.rotation_euler = (math.radians(70), 0, 0)
    S.cyl("sabre_scabbard", 0.02, 0.016, 0.45, (0, 0, -0.45), m["leather"], holder, seg=5)
    S.cyl("sabre_scabbard_tip", 0.016, 0.012, 0.32, (0, 0, -0.75), m["leather"], holder,
          rot=(math.radians(14), 0, 0), seg=5)
    S.cyl("sabre_hilt", 0.016, 0.016, 0.14, (0, 0, 0.0), m["leather"], holder, seg=5)
    S.box("sabre_guard", (0.11, 0.03, 0.02), (0, 0, 0.0), m["steel"], holder)
    return holder


def _saadak(f, m):
    """The saadak: a bow case at the left hip and a quiver of arrows at the right."""
    S.box("saadak", (0.05, 0.18, 0.34), (-0.25, -0.03, -0.12), m["leather"], f.hips, rot=(0.4, 0, 0))
    q = S.cyl("quiver", 0.06, 0.07, 0.45, (0.26, -0.12, -0.35), m["leather"], f.hips, rot=(-0.3, 0, 0), seg=8)
    for i in range(3):
        S.cyl(f"fletch_{i}", 0.012, 0.012, 0.1, (0.02 * i - 0.02, 0, 0.45), m["white_linen"], q, seg=3)


def _mace(f, m, head=None, flanges=0, length=0.62):
    """A mace held head up in the right hand: the hetman's bulawa (a pear-shaped head) or,
    with `flanges`, a pernach."""
    f.held_r = True
    head = head or m["gold"]
    mace = S.empty("mace", (0, 0, 0), f.j("hand_r"))
    mace.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("mace_haft", 0.018, 0.016, length, (0, 0, -0.12), m["wood"] if flanges else head, mace, seg=6)
    top = length - 0.12
    if flanges:
        S.ball("mace_core", 0.035, (0, 0, top), head, mace)
        for k in range(flanges):
            a = k * math.tau / flanges
            S.box(f"mace_flange_{k}", (0.012, 0.06, 0.12), (0.035 * math.cos(a), 0.035 * math.sin(a), top), head,
                  mace, rot=(0, 0, a + math.pi / 2))
    else:
        S.ball("mace_head", 0.07, (0, 0, top + 0.02), head, mace, scale=(1.0, 1.0, 1.25))
        S.ball("mace_knob", 0.025, (0, 0, top + 0.11), head, mace)
    return mace


def _round_shield(f, m, face, boss=None, r=0.28):
    """A round shield on the left forearm: `face`, a team rim, a boss."""
    f.held_l = True
    holder = S.empty("shield", (-0.25, 0.26, -0.08), f.chest)
    holder.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    S.cyl("shield_rim", r, r, 0.03, (0, 0.0, 0.3), m["team"], holder, rot=(-math.pi / 2, 0, 0), seg=16)
    S.cyl("shield_face", r * 0.86, r * 0.86, 0.03, (0, -0.012, 0.3), face, holder, rot=(-math.pi / 2, 0, 0), seg=16)
    S.ball("shield_boss", r * 0.25, (0, -0.03, 0.3), boss or m["steel"], holder, scale=(1.0, 0.6, 1.0))
    return holder


def _two_tailed_pennon(spear, length, mat):
    """A swallow-tailed pennon near the lance head (the spear's own frame, flying to +X)."""
    top = length - 0.95
    S.solidify(S.poly("pennon", [(0, 0, top), (0.42, 0, top - 0.02), (0.22, 0, top - 0.11), (0.42, 0, top - 0.2),
                                 (0, 0, top - 0.22)], [(0, 1, 2, 4), (2, 3, 4)], mat, spear), 0.01)


def _chaprak(h, mat, edge):
    """A big saddle cloth over the back, hanging down both flanks, with an edge."""
    z = h.rz + 0.06
    S.box("chaprak_top", (0.66, 0.85, 0.04), (0, -0.08, z - 0.12), mat, h.body)
    for x in (-1, 1):
        S.box(f"chaprak_side_{x}", (0.03, 0.85, 0.42), (x * (h.rx + 0.03), -0.08, z - 0.33), mat, h.body)
        S.box(f"chaprak_edge_{x}", (0.035, 0.86, 0.05), (x * (h.rx + 0.032), -0.08, z - 0.53), edge, h.body)


def _chanfron(h, mat):
    """A steel chanfron down the horse's face."""
    S.box("chanfron", (0.12, 0.45, 0.05), (0, 0.18, 0.08), mat, h.head)
    S.ball("chanfron_boss", 0.035, (0, 0.05, 0.12), mat, h.head)


class EasternMounted(beasts.Mounted):
    """A rider on an eastern saddle with a high pommel and cantle, riding with short
    stirrups (knees bent high)."""

    def __init__(self, name, horse_beast, rider, saddle_cloth):
        super().__init__(name, horse_beast, rider, saddle_cloth)
        _eastern_saddle(horse_beast)

    def pose(self, anim, frame, frames):
        super().pose(anim, frame, frames)
        _short_stirrups(self.rider)


class EasternSovereign(Sovereign):
    def __init__(self, name, horse_beast, rider, saddle_cloth, bearer):
        super().__init__(name, horse_beast, rider, saddle_cloth, bearer)
        _eastern_saddle(horse_beast)

    def pose(self, anim, frame, frames):
        super().pose(anim, frame, frames)
        _short_stirrups(self.rider)


def _eastern_saddle(h):
    leather = S.mat("leather", "#5a3e28", 0.8, noise=0.2)
    z = h.rz + 0.06
    S.box("saddle_pommel", (0.2, 0.06, 0.16), (0, 0.2, z + 0.04), leather, h.body, rot=(math.radians(-15), 0, 0))
    S.box("saddle_cantle", (0.26, 0.06, 0.12), (0, -0.3, z + 0.02), leather, h.body, rot=(math.radians(20), 0, 0))


def _short_stirrups(r):
    rad = math.radians
    for side, x in (("l", -1), ("r", 1)):
        r.j(f"thigh_{side}").rotation_euler = (rad(66), -x * rad(34), 0)
        r.j(f"knee_{side}").rotation_euler = (-rad(105), 0, 0)


def _icon_pole(f, m, length=1.95):
    """An icon in a gilt kiot on a pole, upright in the right hand; a small canopy over it."""
    f.held_r = True
    pole = S.empty("icon_pole", (0, 0, -0.02), f.j("hand_r"))
    pole.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("icon_shaft", 0.02, 0.018, length, (0, 0, -0.8), m["wood"], pole, seg=6)
    top = length - 0.8
    kiot = S.empty("kiot", (0, 0, top - 0.2), pole)
    S.box("kiot_case", (0.34, 0.06, 0.42), (0, 0, 0), m["gold"], kiot)
    S.box("icon_board", (0.26, 0.07, 0.33), (0, 0, -0.01), m["icon_dark"], kiot)
    S.box("icon_figure", (0.12, 0.075, 0.2), (0, 0, -0.03), m["red_cloth"], kiot)
    S.ball("icon_halo_spot", 0.045, (0, 0.0, 0.09), m["gold"], kiot, scale=(1.0, 0.9, 1.0))
    S.cyl("kiot_roof", 0.22, 0.02, 0.12, (0, 0, 0.21), m["gold"], kiot, seg=4).scale = (1.0, 0.4, 1.0)
    S.cyl("icon_cross", 0.008, 0.008, 0.12, (0, 0, 0.32), m["gold"], kiot, seg=4)
    S.box("icon_cross_bar", (0.07, 0.012, 0.012), (0, 0, 0.4), m["gold"], kiot)
    # A team-coloured cloth (ubrus) hanging under the kiot.
    S.box("icon_cloth", (0.3, 0.02, 0.22), (0, 0.0, -0.32), m["team"], kiot)
    return pole


class Monk(people.Figure):
    """A figure whose `cast` raises the icon pole over his head and keeps it upright."""

    def _attack(self, rot, t):
        chest_x = super()._attack(rot, t)
        self._level("r", rot, chest_x, 0.0)
        return chest_x


def _rider_serpent(name, parent, loc, size, mat):
    """The Muscovite rider spearing the serpent (coa_mo), a simple silhouette (XZ plane)."""
    h = S.empty(name, loc, parent)
    S.box(f"{name}_horse", (0.5 * size, 0.03, 0.2 * size), (0, 0, 0.05 * size), mat, h)
    S.box(f"{name}_head", (0.12 * size, 0.03, 0.22 * size), (-0.28 * size, 0, 0.17 * size), mat, h,
          rot=(0, math.radians(30), 0))
    for k, x in enumerate((-0.2, -0.08, 0.1, 0.2)):
        S.box(f"{name}_leg_{k}", (0.05 * size, 0.03, 0.22 * size), (x * size, 0, -0.12 * size), mat, h,
              rot=(0, math.radians(25 if k % 2 else -25), 0))
    S.box(f"{name}_rider", (0.12 * size, 0.03, 0.28 * size), (0.02 * size, 0, 0.27 * size), mat, h)
    S.box(f"{name}_spear", (0.03 * size, 0.03, 0.75 * size), (-0.2 * size, 0, 0.08 * size), mat, h,
          rot=(0, math.radians(-50), 0))
    for k in range(4):  # the serpent, writhing under the hooves
        S.box(f"{name}_serpent_{k}", (0.18 * size, 0.03, 0.05 * size), ((-0.36 + 0.16 * k) * size, 0,
              -0.3 * size), mat, h, rot=(0, math.radians(25 if k % 2 else -25), 0))
    return h


# --- the Duchy -----------------------------------------------------------------------------

def gdl_szlachta_lance():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["plate"], m["plate"], m)
    _plate_harness(r, m)
    # A short red tunic (waffenrock) over the plate, its skirt over the thighs.
    S.cyl("tunic", 0.2, 0.245, 0.3, (0, 0.0, 0.04), m["tunic_red"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tunic_skirt", 0.06, -0.32, 0.25, 0.33, m["tunic_red"])
    r.skirt("tunic_hem", -0.29, -0.34, 0.33, 0.335, m["team"])
    folk._belt(r, m["leather"], r=0.25)
    _sallet(r, m, m["plate"], bevor=True)
    spear = beasts._lance(r, m, length=4.0)
    _two_tailed_pennon(spear, 4.0, m["team"])
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("bay", "#6e4428", 0.9, noise=0.25), size=1.08)
    _chanfron(h, m["plate"])
    return beasts.Mounted("gdl_szlachta_lance", h, r, m["team"])


class FieldGun:
    """A bronze gun on a two-wheeled carriage with a trail and two gunners. Walk: a horse
    pulls it trail first (the gun turned round), the wheels roll; attack: a flash, smoke and
    the recoil of the carriage."""

    def __init__(self, name="gdl_field_gun", dress=None):
        m = _m()
        wood = m["carriage"]
        self.root = S.empty(name)
        self.gun = S.empty("gun", (0, 0, 0), self.root)
        self.carriage = S.empty("carriage", (0, 0, 0), self.gun)
        c = self.carriage
        # Two cheeks running from the axle down to the trail on the ground, a transom between.
        for x in (-0.17, 0.17):
            S.box(f"cheek_{x}", (0.08, 2.0, 0.2), (x, -0.6, 0.42), wood, c, rot=(math.radians(14), 0, 0))
        S.box("transom", (0.42, 0.14, 0.18), (0, 0.1, 0.62), wood, c)
        S.box("trail_end", (0.32, 0.3, 0.12), (0, -1.55, 0.08), wood, c)
        S.box("carriage_band", (0.44, 0.1, 0.22), (0, -0.55, 0.5), m["team"], c, rot=(math.radians(14), 0, 0))
        S.cyl("axle", 0.05, 0.05, 1.0, (-0.5, 0, 0.5), m["iron"], c, rot=(0, math.pi / 2, 0), seg=8)
        self.wheels = []
        for x in (-0.44, 0.44):
            w = S.empty(f"wheel_{x}", (x, 0, 0.5), c)
            S.cyl(f"wheel_rim_{x}", 0.5, 0.5, 0.07, (-0.035, 0, 0), wood, w, rot=(0, math.pi / 2, 0), seg=16)
            S.cyl(f"wheel_tyre_{x}", 0.505, 0.505, 0.05, (-0.025, 0, 0), m["iron"], w, rot=(0, math.pi / 2, 0),
                  seg=16)
            S.cyl(f"wheel_hub_{x}", 0.08, 0.08, 0.16, (-0.08, 0, 0), wood, w, rot=(0, math.pi / 2, 0), seg=10)
            for k in range(4):
                S.box(f"spoke_{x}_{k}", (0.04, 0.05, 0.92), (0, 0, 0), wood, w, rot=(k * math.pi / 4, 0, 0))
            self.wheels.append(w)
        # The bronze barrel: trunnions on the cheeks, thicker at the breech, a muzzle ring.
        barrel = S.empty("barrel", (0, -0.15, 0.74), c)
        barrel.rotation_euler = (-math.pi / 2 + math.radians(4), 0, 0)
        S.cyl("breech", 0.15, 0.13, 0.5, (0, 0, -0.35), m["bronze"], barrel, seg=14)
        S.ball("cascabel", 0.06, (0, 0, -0.4), m["bronze"], barrel)
        S.cyl("chase", 0.12, 0.095, 1.25, (0, 0, 0.15), m["bronze"], barrel, seg=14)
        S.cyl("muzzle", 0.12, 0.12, 0.1, (0, 0, 1.38), m["bronze"], barrel, seg=14)
        S.cyl("bore", 0.06, 0.06, 0.02, (0, 0, 1.475), S.mat("bore", "#0c0b0a", 1.0), barrel, seg=10)
        for k in range(2):
            S.cyl(f"ring_{k}", 0.14 - 0.015 * k, 0.14 - 0.015 * k, 0.04, (0, 0, 0.1 + 0.55 * k), m["bronze"], barrel,
                  seg=14)
        S.cyl("trunnion", 0.035, 0.035, 0.36, (-0.18, 0.0, 0.0), m["bronze"], barrel, rot=(0, math.pi / 2, 0), seg=8)
        # Balls and a powder keg on the trail.
        for k, (x, y) in enumerate(((0.0, -1.05), (0.0, -1.2))):
            S.ball(f"ball_{k}", 0.07, (x, y, 0.32 - 0.04 * k), m["black_iron"], c)
        # Flash and smoke at the muzzle, hidden until it fires.
        smoke_mat = S.mat("smoke", "#b9b6ae", 1.0, noise=0.3)
        self.flash = S.ball("flash", 0.22, (0, 0, 1.65), S.mat("flash", "#ffcf5a", 0.6), barrel)
        self.smoke = [S.ball(f"smoke_{k}", 0.3, (0, 0.08 * k, 1.8 + 0.3 * k), smoke_mat, barrel) for k in range(3)]
        for o in [self.flash, *self.smoke]:
            o.visible_shadow = False
        # The horse that pulls it on the march, hitched to the trail; hidden at rest.
        self.horse = beasts.horse("gun_horse", S.mat("bay", "#6e4428", 0.9, noise=0.25), small=True)
        self.horse.root.parent = self.root
        S.box("collar", (0.3, 0.12, 0.35), (0, 0.6, 0.25), m["leather"], self.horse.body)
        for x in (-0.22, 0.22):
            S.cyl(f"trace_{x}", 0.012, 0.012, 1.0, (x, 0.3, 0.0), m["leather"], self.horse.body,
                  rot=(math.pi / 2 + 0.25, 0, 0), seg=4)
        self.crew = []
        for k, role in enumerate(("gunner", "loader")):
            g = self._gunner(f"crew_{k}", m, role, dress)
            g.root.parent = self.root
            self.crew.append(g)

    def _gunner(self, name, m, role, dress):
        g = people.Figure(name)
        if dress is not None:
            dress(g, m, role)
            return g
        g.body(m["skin"], m["quilt"], m["trousers"], m["leather"])
        g.hair(m["hair"], beard=role == "gunner")
        folk._legs_skirt(g, m["quilt"], -0.34, 0.29)
        g.skirt("hem", -0.3, -0.36, 0.29, 0.295, m["team"])
        folk._belt(g, m["leather"])
        S.cyl("cap", 0.14, 0.12, 0.1, (0, 0, 0.05), m["felt"], g.head, seg=12)
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
            S.cyl("rammer_head", 0.07, 0.07, 0.12, (0, 0, 0.95), S.mat("sheepskin_mop", "#c8b894", 1.0, noise=0.4), rm,
                  seg=10)
        return g

    def pose(self, anim, frame, frames):
        t = frame / frames
        walk = anim == "walk"
        # On the march the gun is turned round and goes trail first behind the horse.
        self.gun.rotation_euler = (0, 0, math.pi if walk else 0.0)
        self.gun.location = (0, -0.9 if walk else 0.25, 0)
        self.horse.root.scale = (1.0, 1.0, 1.0) if walk else (0.001, 0.001, 0.001)
        self.horse.root.location = (0, 1.6 if walk else 0.0, 0)
        if walk:
            self.horse.pose("walk", frame, frames)
        else:
            self.horse.pose("idle", 0, frames)
        places = [(0.75, -0.2), (-0.75, -0.55)] if walk else [(0.65, -0.95), (-0.65, 0.35)]
        for i, (g, (x, y)) in enumerate(zip(self.crew, places)):
            g.root.location = (x, y, 0)
            g.pose("walk" if walk else "idle", (frame + i * 3) % frames, frames)
        kick = 0.0
        flash = 0.0
        smoke = [0.0, 0.0, 0.0]
        if anim == "attack":
            kick = 0.0 if t < 0.12 else math.exp(-(t - 0.12) * 4.0)
            flash = 1.0 if 0.12 <= t < 0.3 else 0.0
            for k in range(3):
                age = t - 0.12 - 0.08 * k
                smoke[k] = 0.0 if age <= 0 else min(1.0, age * 4.0) * (1.0 - 0.5 * max(0.0, age - 0.4))
            for g in self.crew:  # they flinch away from the blast
                g.chest.rotation_euler.x -= math.radians(10) * kick
        roll = -0.35 * kick
        self.carriage.location.y = roll
        if walk:
            spin = -2 * math.pi * frame / frames  # the gun is turned round
        else:
            spin = roll / 0.5
        for w in self.wheels:
            w.rotation_euler = (spin, 0, 0)
        self.carriage.location.z = 0.01 * math.sin(4 * math.pi * t) if walk else 0.0
        self.flash.scale = (flash or 0.001,) * 3
        for k, o in enumerate(self.smoke):
            s = max(0.001, smoke[k] * (1.0 + 0.4 * k))
            o.scale = (s, s, s)


def gdl_field_gun():
    return FieldGun("gdl_field_gun")


# --- Muscovy -------------------------------------------------------------------------------

def mo_syn_boyarsky():
    m = _m()
    r = beasts._rider("rider", m["tegilyai"], m["trousers"], m["leather"], m, m["hair"])
    _tegilyai(r, m)
    folk._belt(r, m["team"], r=0.255)
    _spheroconical(r, m)
    _saadak(r, m)
    _sabre_hip(r, m, side=1)
    _composite_bow(r, m)
    h = beasts.horse("horse", S.mat("steppe_horse", "#7a5a38", 0.9, noise=0.3), small=True,
                     mane=S.mat("mane", "#3a2a1c", 1.0, noise=0.4))
    return EasternMounted("mo_syn_boyarsky", h, r, m["team"])


def mo_boyar():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["mo_red"], S.mat("boots_green", "#3e5a3a", 0.8, noise=0.2), m,
                      m["dark_hair"])
    r.skirt("mail_skirt", 0.06, -0.36, 0.24, 0.32, m["mail"])
    _bakhterets(r, m, gilt=m["gold"])
    for side in ("l", "r"):
        S.limb(f"vambrace_{side}", 0.07, 0.06, 0.22, m["steel"], r.j(f"elbow_{side}"))
    folk._belt(r, m["team"], r=0.25)
    _shishak(r, m, rim=m["gold"])
    beasts._lance(r, m, length=3.4, pennon=m["team"])
    _sabre_hip(r, m)
    _round_shield(r, m, m["mo_red"], boss=m["gold"])
    h = beasts.horse("horse", S.mat("dark_bay", "#4a3020", 0.9, noise=0.25), size=1.0)
    _chaprak(h, m["chaprak_blue"], m["gold"])  # a coloured chaprak, blue with a gold edge
    return EasternMounted("mo_boyar", h, r, m["team"])


def mo_inok():
    m = _m()
    f = Monk("mo_inok")
    robe = m["black_robe"]
    f.body(m["skin"], robe, robe, m["leather"])
    f.hair(m["grey_hair"])
    S.ball("long_beard", 0.09, (0, 0.08, -0.15), m["grey_hair"], f.head, scale=(1.0, 0.8, 1.6))
    # The ryasa to the ankles with wide sleeves, a leather belt in the player colour.
    f.skirt("ryasa", 0.06, -0.86, 0.21, 0.33, robe)
    for side in ("l", "r"):
        S.limb(f"wide_sleeve_{side}", 0.09, 0.11, 0.28, robe, f.j(f"elbow_{side}"))
    folk._belt(f, m["team"], r=0.215)
    # The klobuk: a black cylindrical cap with the veil hanging down the back.
    S.cyl("klobuk", 0.14, 0.15, 0.2, (0, -0.01, 0.03), robe, f.head, seg=14)
    S.box("klobuk_veil", (0.26, 0.04, 0.42), (0, -0.15, -0.06), robe, f.head, rot=(math.radians(-8), 0, 0))
    _orthodox_cross("chest_cross", f.chest, (0, 0.18, 0.3), 0.12, m["gold"])
    _icon_pole(f, m)
    f.stoop = math.radians(4)
    return f


# --- heroes --------------------------------------------------------------------------------

def hero_andrei():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["plate"], m["leather"], m, m["fair_hair"], beard=False)
    _plate_harness(r, m, faulds=2)
    # A long green kaftan over the armour (the family's green), open to the breastplate.
    _kaftan(r, m, m["gintovt_green"], buttons=m["gold"])
    S.box("kaftan_opening", (0.12, 0.03, 0.36), (0, 0.205, 0.2), m["plate"], r.chest)
    _woven_belt(r, m, r=0.255)
    _orthodox_cross("orthodox_cross", r.chest, (0, 0.225, 0.36), 0.11, m["gold"])
    _sallet(r, m, m["plate"], bevor=False, open_face=True)
    # The khorugv: the Gintovt arms on the cloth, a spear point on the pole.
    _banner(r, m, m["gintovt_green"], lambda c: _gintovt_arms("banner_arms", c, (0, -0.01, 0.0), 0.6, 0.42, m),
            length=3.4)
    _sabre_hip(r, m)
    h = _gintovt_horse(m, S.mat("bay", "#6e4428", 0.9, noise=0.25))
    _chanfron(h, m["plate"])
    return beasts.Mounted("hero_andrei", h, r, m["team"])


def hero_ostrogski():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["plate"], m["plate"], m, m["dark_hair"])
    _plate_harness(r, m)
    # A rich crimson kaftan over the armour with gold buttons and a fur collar.
    _kaftan(r, m, m["crimson"], buttons=m["gold"], collar=m["fur"])
    S.box("kaftan_opening", (0.12, 0.03, 0.36), (0, 0.21, 0.2), m["plate"], r.chest)
    S.cyl("kaftan_hem", 0.355, 0.36, 0.05, (0, 0, -0.61), m["gold"], r.hips, seg=12).scale = (1.0, 0.85, 1.0)
    folk._belt(r, m["gold"], r=0.255)
    _orthodox_cross("orthodox_cross", r.chest, (0, 0.225, 0.36), 0.13, m["gold"])
    S.ball("full_beard", 0.09, (0, 0.08, -0.11), m["dark_hair"], r.head, scale=(1.1, 0.8, 1.25))
    _sallet(r, m, m["plate"], bevor=False, open_face=True)
    S.cyl("sallet_rim", 0.152, 0.152, 0.03, (0, -0.01, -0.01), m["gold"], r.head, seg=14)
    S.ball("plume", 0.06, (0, -0.06, 0.2), m["team"], r.head, scale=(0.7, 1.4, 1.2))
    _mace(r, m)
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.08)
    _chanfron(h, m["plate"])
    _chaprak(h, S.mat("dark_cloth", "#2a2a33", 0.9, noise=0.1), m["gold"])
    return beasts.Mounted("hero_ostrogski", h, r, m["team"])


def _mo_bearer(m):
    b = people.Figure("bearer")
    b.body(m["skin"], m["tegilyai"], m["trousers"], m["leather"])
    b.hair(m["hair"])
    _tegilyai(b, m)
    folk._belt(b, m["team"], r=0.25)
    _spheroconical(b, m)
    return b


def hero_shchenya():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["mo_red"], S.mat("boots_red", "#6a2a1e", 0.8, noise=0.2), m,
                      m["greying_hair"])
    r.skirt("mail_skirt", 0.06, -0.36, 0.24, 0.32, m["mail"])
    _bakhterets(r, m, rows=5, gilt=m["gold"])
    # A rich red ferjaz thrown over the shoulders, long and open at the front.
    S.cyl("ferjaz_back", 0.38, 0.27, 0.95, (0, -0.1, -0.45), m["ferjaz"], r.chest, seg=12).scale = (1.0, 0.55, 1.0)
    r.skirt("ferjaz_skirt", 0.0, -0.55, 0.26, 0.37, m["ferjaz"])
    S.cyl("ferjaz_collar", 0.27, 0.19, 0.09, (0, -0.02, 0.43), m["gold"], r.chest, seg=12)
    folk._belt(r, m["gold"], r=0.25)
    S.ball("full_beard", 0.1, (0, 0.08, -0.12), m["greying_hair"], r.head, scale=(1.15, 0.85, 1.35))
    _shishak(r, m, mat=m["steel"], rim=m["gold"])
    S.cyl("shishak_gilt", 0.1, 0.03, 0.08, (0, 0, 0.16), m["gold"], r.head, seg=12)
    _mace(r, m, head=m["gold"], flanges=6)
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25), size=1.06)
    _chaprak(h, m["mo_red"], m["gold"])
    b = _mo_bearer(m)
    _banner(b, m, m["mo_red"], lambda c: _rider_serpent("banner_rider", c, (0, 0.0, 0.02), 0.62, m["gold"]))
    return EasternSovereign("hero_shchenya", h, r, m["team"], b)


UNITS = {
    "mo_inok": mo_inok,
}
MOUNTED_UNITS = {
    "gdl_szlachta_lance": gdl_szlachta_lance,
    "mo_syn_boyarsky": mo_syn_boyarsky,
    "mo_boyar": mo_boyar,
    "hero_andrei": hero_andrei,
    "hero_ostrogski": hero_ostrogski,
    "hero_shchenya": hero_shchenya,
}
WAGONS = {"gdl_field_gun": gdl_field_gun}
