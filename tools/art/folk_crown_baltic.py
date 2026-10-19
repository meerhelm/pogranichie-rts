"""The march to the Baltic («Корона 3. Балтийская вода, 1433»), on the figure of people.py,
the horse and the wagon of beasts.py and the pieces of folk.py, folk_1410.py (pl_crossbow,
the plate arms, the sword), folk_1500.py (the plate harness, the sallet, the field gun's fire),
folk_1514.py (the handgunner's shot) and folk_crown_1410.py (the open bascinet, the surcoat)
(visual assets doc, «Юниты», «Герои»; the mission card
docs/03-missions/14-crown_03_baltic_water_1433.md). Arms we are not sure of are not drawn.

Heroes (template `mounted`):
- hero_mikolaj_michalow: Mikołaj of Michałów, the Crown's commander of the march, a lord of
  the 1430s in full white plate (a breastplate with a ridge, a fauld, plate arms) under a
  plain red surcoat with a white hem (the Crown's colours; his family arms are not drawn), an
  open bascinet over a dark greying beard, a sword raised in the hand (he stops the killing
  of the prisoners and knights the men on the shore; attack `swing`), a grey horse under a red
  caparison with a team trim.
- hero_capek: Jan Čapek of Sány, the captain of the Czech orphans: no lord's finery, a dark
  brigandine over mail, plain plate arms, an open sallet, a dark beard; a lance with the
  Hussite banner (a red chalice on black, team tails; attack `thrust`), a small white shield
  with the red chalice, a black horse with only a team saddle cloth.

On foot:
- nt_hussite_flail: an orphans' footman: a grey-brown padded jack with quilting seams, a kettle
  hat, a red chalice on the chest, the iron-bound war flail upright in the hand (its swingle
  hangs from a short chain and flies out straight in the blow: `FlailMan`, attack `swing`),
  three sulice (javelins) slung on the back, a knife at the belt.
- nt_gdansk_militia: a burgher of the Gdańsk militia: a red padded jack with white sleeves (the
  town's colours), dark hose, a kettle hat, a spear (attack `thrust`), a heater shield with the
  arms of Gdańsk: two white crosses one above the other on red, without the crown (granted
  only in 1457).
- nt_gdansk_crossbow: the town's crossbowman, pl_crossbow in town clothes: a white tunic with
  red sleeves and the small red shield of Gdańsk (two white crosses) on the chest, a kettle
  hat, the steel-bowed crossbow, the belt hook and a quiver of bolts (attack `crossbow`).

Wagons (the wagon frame):
- nt_hussite_wagon: the orphans' war wagon: a heavy cart with high plank side boards and
  loopholes, a low front board, a red chalice on a white field painted on each side, a team
  band along the top, chains hanging at the corners for linking the tabor; two horses, a
  driver in a padded jack. Inside stand a handgunner (folk_1514.Gunner: he fires over the
  boards with a flash and a puff of smoke, attack `fire`) and a man with a flail.
- nt_hussite_gun: a short wide-mouthed iron houfnice with hoops on a wooden bed in a light
  cart with low sides, its muzzle over the tail board; two horses. On the march the horses
  pull it forward; standing and firing, the whole wagon is turned round so the muzzle faces
  the enemy (like folk_1500.FieldGun, it never unhitches): a flash, smoke and the recoil of
  the barrel's bed. A gunner with the linstock and a loader with the rammer on foot beside it.
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1410 import _plate_arms, _sword
from tools.art.folk_1500 import _plate_harness, _sallet
from tools.art.folk_1514 import Gunner
from tools.art.folk_crown_1410 import _open_bascinet, _sword_hip
from tools.art.folk_crown_malbork import _m as _m_k2


def _m():
    m = _m_k2()
    m.update({
        "chalice_red": S.mat("chalice_red", "#b3221c", 0.8, noise=0.08),
        "hussite_black": S.mat("hussite_black", "#1e1c1e", 0.9, noise=0.08),
        "hussite_jack": S.mat("hussite_jack", "#857659", 0.95, noise=0.3),
        "hussite_hose": S.mat("hussite_hose", "#4a4238", 0.95, noise=0.15),
        "hussite_cap": S.mat("hussite_cap", "#5a4c3c", 0.95, noise=0.18),
        "capek_brig": S.mat("capek_brigandine", "#3a302c", 0.8, noise=0.15),
        "gdansk_red": S.mat("gdansk_red", "#a8221c", 0.9, noise=0.1),
        "town_jack": S.mat("town_jack_red", "#9a2a22", 0.95, noise=0.22),
        "town_white": S.mat("town_white", "#e6e2d6", 0.92, noise=0.1),
        "town_hose": S.mat("town_hose", "#33343c", 0.95, noise=0.12),
        "board": S.mat("wagon_board", "#8a6a44", 0.85, noise=0.35),
        "board_dark": S.mat("wagon_board_dark", "#6e5234", 0.85, noise=0.35),
        "chain": S.mat("chain_iron", "#55575a", 0.45, metal=0.8),
        "slit": S.mat("loophole", "#141210", 1.0),
        "grey_horse": S.mat("pl_grey_horse", "#8d867c", 0.9, noise=0.25),
        "black_horse": S.mat("black_horse", "#2a221c", 0.85, noise=0.25),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _chalice(name, parent, loc, size, mat, rot=(0, 0, 0)):
    """The Hussite chalice as a flat silhouette in the XZ plane of `parent` (thin along Y):
    a wide cup, a stem with a knop, a spreading foot."""
    h = S.empty(name, loc, parent)
    h.rotation_euler = rot
    s = size
    cup = [(-0.3 * s, 0, 0.46 * s), (0.3 * s, 0, 0.46 * s), (0.25 * s, 0, 0.22 * s), (0.1 * s, 0, 0.1 * s),
           (-0.1 * s, 0, 0.1 * s), (-0.25 * s, 0, 0.22 * s)]
    S.solidify(S.poly(f"{name}_cup", cup, [(0, 1, 2, 3, 4, 5)], mat, h), 0.02)
    S.box(f"{name}_stem", (0.07 * s, 0.025, 0.38 * s), (0, 0, -0.08 * s), mat, h)
    S.box(f"{name}_knop", (0.15 * s, 0.025, 0.07 * s), (0, 0, -0.04 * s), mat, h)
    foot = [(-0.25 * s, 0, -0.42 * s), (0.25 * s, 0, -0.42 * s), (0.05 * s, 0, -0.26 * s), (-0.05 * s, 0, -0.26 * s)]
    S.solidify(S.poly(f"{name}_foot", foot, [(0, 1, 2, 3)], mat, h), 0.02)
    return h


def _gdansk_crosses(name, parent, x, z_top, z_bottom, y, size, m):
    """The arms of Gdańsk without the crown: two white crosses one above the other."""
    for k, z in enumerate((z_top, z_bottom)):
        folk._cross(f"{name}_cross_{k}", parent, (x, y, z), size, m["town_white"])


def _quilting(f, m, mat=None):
    for k, z in enumerate((0.12, 0.26)):
        S.cyl(f"quilt_seam_{k}", 0.205 - 0.01 * k, 0.205 - 0.01 * k, 0.014, (0, 0, z), mat or m["leather"], f.chest,
              seg=12).scale = (1.0, 0.76, 1.0)


def _hussite_dress(f, m, hat="kettle", beard=True, hair=None):
    """The orphans' foot dress: a padded jack to mid-thigh with a team hem, dark hose, a kettle
    hat (or a cloth cap), a red chalice on the chest."""
    f.body(m["skin"], m["hussite_jack"], m["hussite_hose"], m["leather"])
    f.hair(hair or m["hair"], beard=beard)
    folk._legs_skirt(f, m["hussite_jack"], -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    _quilting(f, m)
    folk._belt(f, m["leather"], r=0.24)
    if hat == "kettle":
        folk._chapel(f, m["iron"])
    else:
        S.cyl("cap_band", 0.14, 0.14, 0.06, (0, 0, 0.03), m["hussite_cap"], f.head, seg=12)
        S.ball("cap_top", 0.13, (0, -0.01, 0.1), m["hussite_cap"], f.head, scale=(1, 1, 0.6))
    _chalice("chest_chalice", f.chest, (0, 0.165, 0.22), 0.26, m["chalice_red"])


def _flail(f, m, haft=1.25):
    """The war flail upright in the right hand: an ash haft with an iron ferrule, a short chain,
    an iron-bound swingle hanging from the top (returns the swingle's empty)."""
    f.held_r = True
    holder = S.empty("flail", (0, 0, -0.02), f.j("hand_r"))
    holder.rotation_euler = (math.radians(-80), 0, 0)
    top = haft - 0.45
    S.cyl("flail_haft", 0.02, 0.018, haft, (0, 0, -0.45), m["wood"], holder, seg=6)
    S.cyl("flail_ferrule", 0.026, 0.026, 0.08, (0, 0, top - 0.06), m["iron"], holder, seg=6)
    for k in range(3):
        S.box(f"flail_link_{k}", (0.02, 0.012, 0.035), (0, 0, top + 0.03 + 0.03 * k), m["chain"], holder,
              rot=(0, 0, k * math.pi / 2))
    swingle = S.empty("flail_swingle", (0, 0, top + 0.1), holder)
    S.cyl("swingle_wood", 0.032, 0.032, 0.5, (0, 0, 0.0), m["wood"], swingle, seg=6)
    for k in range(3):
        S.cyl(f"swingle_band_{k}", 0.038, 0.038, 0.04, (0, 0, 0.08 + 0.16 * k), m["iron"], swingle, seg=6)
    for k in range(4):  # iron spikes
        a = k * math.pi / 2
        S.cyl(f"swingle_spike_{k}", 0.012, 0.0, 0.06, (math.cos(a) * 0.03, math.sin(a) * 0.03, 0.3), m["iron"],
              swingle, rot=(-math.sin(a) * math.pi / 2, math.cos(a) * math.pi / 2, 0), seg=4, smooth=False)
    swingle.rotation_euler = (math.pi, 0, 0)  # hanging down along the haft
    return swingle


class FlailMan(people.Figure):
    """A figure whose flail's swingle hangs at rest and flies out straight in the blow."""

    swingle = None

    def pose(self, anim, frame, frames):
        super().pose(anim, frame, frames)
        if self.swingle is None:
            return
        t = frame / frames
        hang = math.pi - math.radians(6) * math.sin(2 * math.pi * t) if anim == "walk" else math.pi
        if anim == "attack":
            # Trailing in the wind-up, straight out through the blow, falling back after it.
            out = math.sin(math.pi * min(1.0, max(0.0, (t - 0.3) / 0.6)))
            hang = math.pi * (1.0 - 0.95 * out)
        self.swingle.rotation_euler = (hang, 0, 0)


def _sulice_on_back(f, m, n=3):
    """A bundle of javelins slung on the back, points up."""
    b = S.empty("sulice", (-0.08, -0.19, 0.05), f.chest)
    b.rotation_euler = (math.radians(14), math.radians(-24), 0)
    for k in range(n):
        x = (k - (n - 1) / 2) * 0.035
        S.cyl(f"sulica_{k}", 0.012, 0.011, 1.3, (x, 0.01 * k, -0.6), m["wood"], b, seg=5)
        S.cyl(f"sulica_head_{k}", 0.022, 0.0, 0.16, (x, 0.01 * k, 0.7), m["steel"], b, seg=4, smooth=False)
    S.box("sulice_strap", (0.04, 0.02, 0.6), (0.0, 0.19, 0.08), m["leather"], f.chest, rot=(0, math.radians(32), 0))
    return b


def _crossbow(f, m):
    """pl_crossbow's steel-bowed crossbow in both hands, the belt hook and the bolt quiver."""
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
    return cb


# --- heroes --------------------------------------------------------------------------------

def hero_mikolaj_michalow():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["plate"], m["steel"], m, m["greying_hair"])
    _plate_harness(r, m)
    # A plain red surcoat with a white hem over the plate: the Crown's colours, no arms.
    S.box("surcoat", (0.5, 0.41, 0.5), (0, 0.0, 0.1), m["red_cloth"], r.chest)
    S.box("surcoat_hem", (0.51, 0.42, 0.05), (0, 0.0, -0.15), m["white_cloth"], r.chest)
    r.skirt("surcoat_skirt", 0.0, -0.36, 0.25, 0.34, m["red_cloth"])
    r.skirt("surcoat_skirt_hem", -0.31, -0.38, 0.335, 0.345, m["white_cloth"])
    folk._belt(r, m["team"], r=0.25)
    _open_bascinet(r, m, m["plate"])
    S.box("moustache", (0.12, 0.03, 0.025), (0, 0.125, -0.045), m["greying_hair"], r.head)
    _sword(r, m)
    _sword_hip(r, m)  # the scabbard
    h = beasts.horse("horse", m["grey_horse"], size=1.04)
    beasts.caparison(h, m["red_cloth"], m["team"])
    return beasts.Mounted("hero_mikolaj_michalow", h, r, m["team"])


def hero_capek():
    m = _m()
    r = beasts._rider("rider", m["capek_brig"], m["mail"], m["boots"], m, m["dark_hair"])
    r.skirt("mail_skirt", 0.06, -0.32, 0.23, 0.3, m["mail"])
    r.skirt("brig_skirt", 0.06, -0.16, 0.235, 0.29, m["capek_brig"])
    for i, z in enumerate((0.1, 0.22, 0.34)):  # rivet rows of the brigandine
        S.cyl(f"rivets_{i}", 0.2 - 0.01 * i, 0.2 - 0.01 * i, 0.015, (0, 0, z), m["iron"], r.chest, seg=12).scale = (
            1.0, 0.76, 1.0)
    _plate_arms(r, m)
    folk._belt(r, m["team"], r=0.24)
    _sallet(r, m, m["steel"], bevor=False, open_face=True)
    # The lance with the orphans' banner: a red chalice on black, two team tails.
    spear = folk._spear(r, m, length=3.6)
    top = 3.6 - 0.95
    w, hgt = 0.5, 0.36
    cloth = S.empty("hussite_banner", (w / 2 + 0.02, 0, top - hgt / 2), spear)
    S.box("banner_field", (w, 0.015, hgt), (0, 0, 0), m["hussite_black"], cloth)
    for k, y in enumerate((-0.012, 0.012)):
        _chalice(f"banner_chalice_{k}", cloth, (0, y, 0.0), 0.32, m["chalice_red"])
    for k, z in enumerate((hgt * 0.27, -hgt * 0.27)):
        tail = [(w / 2, 0, z + hgt * 0.2), (w / 2 + 0.3, 0, z), (w / 2, 0, z - hgt * 0.2)]
        S.solidify(S.poly(f"banner_tail_{k}", tail, [(0, 1, 2)], m["team"], cloth), 0.015)
    # A small white shield with the red chalice.
    sh = folk._heater(r, m["white_cloth"], m, cross=False)
    sh.scale = (0.85, 0.85, 0.85)
    _chalice("shield_chalice", sh, (0, -0.045, 0.36), 0.42, m["chalice_red"])
    _sword_hip(r, m)
    h = beasts.horse("horse", m["black_horse"])
    return beasts.Mounted("hero_capek", h, r, m["team"])


# --- on foot -------------------------------------------------------------------------------

def nt_hussite_flail():
    m = _m()
    f = FlailMan("nt_hussite_flail")
    _hussite_dress(f, m)
    S.box("knife", (0.03, 0.03, 0.22), (-0.2, 0.1, -0.1), m["leather"], f.hips)
    _sulice_on_back(f, m)
    f.swingle = _flail(f, m)
    return f


def nt_gdansk_militia():
    m = _m()
    f = people.Figure("nt_gdansk_militia")
    f.body(m["skin"], m["town_jack"], m["town_hose"], m["leather"], sleeve=m["town_white"])
    f.hair(m["fair_hair"])
    folk._legs_skirt(f, m["town_jack"], -0.38, 0.3)
    f.skirt("hem", -0.34, -0.4, 0.3, 0.305, m["team"])
    _quilting(f, m, m["town_white"])
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["iron"])
    folk._spear(f, m, length=2.5)
    sh = folk._heater(f, m["gdansk_red"], m, cross=False)
    sh.location = (sh.location.x - 0.03, sh.location.y + 0.07, sh.location.z)  # clear of the forearm
    # The forearm and fist are behind the shield; the white sleeve showed through its upper cross.
    for o in [*f.j("elbow_l").children, *f.j("hand_l").children]:
        if o.name.startswith(("fore_l", "fist_l")):
            o.scale = (0.001, 0.001, 0.001)
    _gdansk_crosses("shield", sh, 0.0, 0.43, 0.22, -0.06, 0.14, m)
    return f


def nt_gdansk_crossbow():
    m = _m()
    f = people.Figure("nt_gdansk_crossbow")
    f.body(m["skin"], m["town_white"], m["town_hose"], m["leather"], sleeve=m["town_jack"])
    f.hair(m["hair"])
    folk._legs_skirt(f, m["gambeson"], -0.36, 0.3)
    f.skirt("tunic_skirt", 0.06, -0.2, 0.23, 0.29, m["town_white"])
    f.skirt("hem", -0.16, -0.22, 0.29, 0.295, m["team"])
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["steel"])
    # The town's badge on the chest: a small red shield with the two white crosses.
    badge = S.empty("badge", (0.0, 0.16, 0.22), f.chest)
    pts = [(-0.09, 0, 0.11), (0.09, 0, 0.11), (0.085, 0, -0.02), (0.0, 0, -0.12), (-0.085, 0, -0.02)]
    S.solidify(S.poly("badge_field", pts, [(0, 1, 2, 3, 4)], m["gdansk_red"], badge), 0.02)
    _gdansk_crosses("badge", badge, 0.0, 0.055, -0.035, 0.025, 0.07, m)
    _crossbow(f, m)
    return f


# --- the war wagon -------------------------------------------------------------------------

def _wheels(cart, m, xs, ys, r=0.46, wood=None):
    wood = wood or m["board"]
    wheels = []
    for x in xs:
        for y in ys:
            w = S.empty(f"wheel_{x}_{y}", (x, y, r + 0.02), cart)
            S.cyl(f"wheel_rim_{x}_{y}", r, r, 0.08, (-0.04, 0, 0), wood, w, rot=(0, math.pi / 2, 0), seg=14)
            S.cyl(f"wheel_hub_{x}_{y}", 0.07, 0.07, 0.14, (-0.07, 0, 0), m["wood"], w, rot=(0, math.pi / 2, 0), seg=8)
            for k in range(3):
                S.box(f"spoke_{x}_{y}_{k}", (0.07, 0.07, r * 1.85), (0, 0, 0), m["wood"], w,
                      rot=(k * math.pi / 3, 0, 0))
            wheels.append(w)
    return wheels


def _team(root, cart, m, y=1.35, coat="#5e4632"):
    """Two horses at the pole in front of the cart."""
    S.cyl("pole", 0.04, 0.04, 1.9, (0, 1.2, 0.7), m["wood"], cart, rot=(-math.pi / 2 + 0.12, 0, 0), seg=6)
    horses = []
    for x in (-0.42, 0.42):
        h = beasts.horse(f"horse_{x}", S.mat("hussite_horse", coat, 0.9, noise=0.25), small=True)
        h.root.parent = root
        h.root.location = (x, y, 0)
        S.box(f"collar_{x}", (0.3, 0.12, 0.35), (0, 0.6, 0.25), m["leather"], h.body)
        horses.append(h)
    return horses


def _chain(name, parent, start, n, m, step=0.07):
    """A hanging chain of `n` links from `start` (cart space) straight down."""
    for k in range(n):
        S.box(f"{name}_{k}", (0.035 if k % 2 else 0.012, 0.012 if k % 2 else 0.035, 0.075),
              (start[0], start[1], start[2] - k * step), m["chain"], parent)


def _sit(figure):
    r = math.radians
    for side in ("l", "r"):
        figure.j(f"thigh_{side}").rotation_euler = (r(85), 0, 0)
        figure.j(f"knee_{side}").rotation_euler = (-r(85), 0, 0)


class HussiteWagon:
    """The orphans' war wagon: high plank sides with loopholes, two horses, a driver and two
    men standing inside; in the attack the handgunner fires over the boards."""

    def __init__(self, name="nt_hussite_wagon"):
        m = _m()
        self.root = S.empty(name)
        self.cart = S.empty("cart", (0, -1.0, 0), self.root)
        c = self.cart
        length, width, bed_z = 2.6, 1.3, 0.78
        S.box("bed", (width, length, 0.1), (0, 0, bed_z), m["board_dark"], c)
        S.box("bed_beam", (0.2, length + 0.2, 0.14), (0, 0, bed_z - 0.1), m["wood"], c)
        top = 1.85  # top of the high boards
        for s in (-1, 1):
            side = S.empty(f"side_{s}", (s * width / 2, 0, bed_z + 0.05), c)
            side.rotation_euler = (0, s * math.radians(5), 0)  # leaning out a little
            h = top - bed_z
            for k in range(3):  # three wide planks
                S.box(f"side_{s}_plank_{k}", (0.07, length, h / 3 - 0.015), (0, 0, h / 6 + k * h / 3),
                      m["board"] if k % 2 == 0 else m["board_dark"], side)
            for k, y in enumerate((-1.22, 0.1, 1.22)):  # uprights outside
                S.box(f"side_{s}_stake_{k}", (0.09, 0.1, h + 0.12), (s * 0.04, y, h / 2 + 0.02), m["wood"], side)
            for k, y in enumerate((-0.95, -0.45, 0.45, 0.95)):  # loopholes
                S.box(f"side_{s}_loop_{k}", (0.08, 0.16, 0.1), (s * 0.01, y, h * 0.77), m["slit"], side)
            S.box(f"side_{s}_band", (0.08, length + 0.02, 0.08), (s * 0.01, 0, h - 0.02), m["team"], side)
            # The chalice on a whitewashed field in the middle of the side.
            S.box(f"side_{s}_field", (0.08, 0.5, 0.48), (s * 0.012, -0.45, h * 0.42), m["white_cloth"], side)
            _chalice(f"side_{s}_chalice", side, (s * 0.06, -0.45, h * 0.42), 0.42, m["chalice_red"],
                     rot=(0, 0, math.pi / 2))
        # The tail board as high as the sides, a low board at the front for the driver.
        S.box("tail_board", (width + 0.1, 0.08, top - bed_z), (0, -length / 2, (top + bed_z) / 2), m["board"], c)
        S.box("tail_band", (width + 0.12, 0.09, 0.08), (0, -length / 2, top - 0.04), m["team"], c)
        S.box("front_board", (width + 0.1, 0.08, 0.45), (0, length / 2, bed_z + 0.25), m["board"], c)
        # Chains for linking the tabor hanging at the rear corners and the front.
        for s in (-1, 1):
            _chain(f"chain_rear_{s}", c, (s * (width / 2 + 0.12), -length / 2 + 0.08, 1.4), 7, m)
            _chain(f"chain_front_{s}", c, (s * (width / 2 + 0.12), length / 2 - 0.1, 1.25), 5, m)
        self.wheels = _wheels(c, m, (-0.78, 0.78), (-0.85, 0.85))
        self.horses = _team(self.root, c, m)
        # The driver on the front of the bed.
        d = people.Figure("driver")
        _hussite_dress(d, m, hat="cap")
        d.root.parent = c
        d.root.location = (0, 1.0, bed_z + 0.08 - 0.3)
        self.driver = d
        # The handgunner standing inside behind the side board, and a man with a flail.
        g = Gunner("gunner")
        _hussite_dress(g, m, beard=False)
        g.held_r = True
        g.held_l = True
        g.attack_style = "crossbow"
        gun = S.empty("handgun", (0, 0, 0), g.j("hand_r"))
        gun.rotation_euler = (math.radians(-70), 0, math.radians(20))
        S.box("tiller", (0.06, 0.07, 0.55), (0, 0, 0.02), m["wood"], gun)
        S.cyl("barrel", 0.028, 0.024, 0.72, (0, 0.0, 0.26), m["iron"], gun, seg=8)
        S.cyl("muzzle", 0.034, 0.034, 0.04, (0, 0.0, 0.96), m["iron"], gun, seg=8)
        S.ball("match_glow", 0.02, (0.04, -0.07, 0.3), m["match"], gun)
        g.flash = S.ball("flash", 0.11, (0, 0, 1.08), m["flash"], gun)
        g.smoke = [S.ball(f"smoke_{k}", 0.16, (0.04 * k, 1.35 + 0.18 * k, 1.42 + 0.05 * k), m["smoke"], g.root)
                   for k in range(3)]
        for o in [g.flash, *g.smoke]:
            o.visible_shadow = False
        g.root.parent = c
        g.root.location = (0.28, 0.15, bed_z + 0.05)
        self.gunner = g
        fl = FlailMan("flailman")
        _hussite_dress(fl, m, hair=m["fair_hair"])
        fl.swingle = _flail(fl, m)
        fl.root.parent = c
        fl.root.location = (-0.3, -0.75, bed_z + 0.05)
        self.flailman = fl

    def pose(self, anim, frame, frames):
        walk = anim == "walk"
        for i, h in enumerate(self.horses):
            h.pose("walk" if walk else "idle", (frame + i * frames // 4) % frames, frames)
        self.driver.pose("idle", frame, frames)
        _sit(self.driver)
        r = math.radians
        for side in ("l", "r"):
            self.driver.j(f"shoulder_{side}").rotation_euler = (r(40), 0, 0)
        self.gunner.pose("attack" if anim == "attack" else "idle", frame, frames)
        self.flailman.pose("idle", (frame + 3) % frames, frames)
        spin = 2 * math.pi * frame / frames if walk else 0.0
        for w in self.wheels:
            w.rotation_euler = (spin, 0, 0)
        self.cart.location.z = 0.012 * math.sin(4 * math.pi * frame / frames) if walk else 0.0


def nt_hussite_wagon():
    return HussiteWagon("nt_hussite_wagon")


# --- the gun on a wagon --------------------------------------------------------------------

class HussiteGun:
    """A houfnice on a light cart. Walk: the horses pull it forward, the crew walks beside;
    idle and attack: the wagon is turned round, the muzzle over the tail board toward the
    enemy (the horses stay hitched behind it); the attack fires with a flash, smoke and the
    recoil of the gun's bed."""

    def __init__(self, name="nt_hussite_gun"):
        m = _m()
        self.root = S.empty(name)
        self.body = S.empty("wagon", (0, 0, 0), self.root)
        self.cart = S.empty("cart", (0, -0.85, 0), self.body)
        c = self.cart
        length, width, bed_z = 2.3, 1.2, 0.72
        S.box("bed", (width, length, 0.1), (0, 0, bed_z), m["board_dark"], c)
        S.box("bed_beam", (0.2, length + 0.2, 0.14), (0, 0, bed_z - 0.1), m["wood"], c)
        for s in (-1, 1):
            S.box(f"side_{s}", (0.07, length, 0.42), (s * width / 2, 0, bed_z + 0.25), m["board"], c)
            S.box(f"side_band_{s}", (0.08, length + 0.02, 0.07), (s * width / 2, 0, bed_z + 0.43), m["team"], c)
            for k, y in enumerate((-0.8, 0.0, 0.8)):
                S.box(f"side_{s}_stake_{k}", (0.09, 0.09, 0.55), (s * (width / 2 + 0.04), y, bed_z + 0.25), m["wood"],
                      c)
            S.box(f"side_{s}_field", (0.08, 0.36, 0.3), (s * (width / 2 + 0.01), 0.45, bed_z + 0.25), m["white_cloth"],
                  c)
            _chalice(f"side_{s}_chalice", c, (s * (width / 2 + 0.05), 0.45, bed_z + 0.25), 0.27, m["chalice_red"],
                     rot=(0, 0, math.pi / 2))
        S.box("front_board", (width + 0.08, 0.07, 0.42), (0, length / 2, bed_z + 0.25), m["board"], c)
        S.box("tail_board", (width + 0.08, 0.07, 0.26), (0, -length / 2, bed_z + 0.17), m["board"], c)
        # The gun's bed: a hewn block lying along the cart; the barrel on it, muzzle to the tail.
        self.gun_bed = S.empty("gun_bed", (0, -0.35, bed_z + 0.05), c)
        g = self.gun_bed
        S.box("block", (0.46, 1.3, 0.26), (0, 0, 0.13), m["carriage"], g)
        S.box("block_wedge", (0.4, 0.3, 0.16), (0, 0.45, 0.3), m["carriage"], g)
        for k, y in enumerate((-0.35, 0.3)):
            S.box(f"block_strap_{k}", (0.5, 0.06, 0.28), (0, y, 0.14), m["black_iron"], g)
        barrel = S.empty("barrel", (0, -0.2, 0.42), g)
        barrel.rotation_euler = (math.pi / 2 - math.radians(8), 0, 0)  # toward -Y, a little raised
        S.cyl("chamber", 0.13, 0.13, 0.42, (0, 0, -0.4), m["black_iron"], barrel, seg=12)
        S.cyl("flight", 0.2, 0.22, 0.62, (0, 0, 0.0), m["black_iron"], barrel, seg=14)
        for k in range(3):
            S.cyl(f"hoop_{k}", 0.225, 0.225, 0.05, (0, 0, 0.08 + 0.22 * k), m["iron"], barrel, seg=14)
        S.cyl("bore", 0.15, 0.15, 0.02, (0, 0, 0.615), S.mat("bore", "#0c0b0a", 1.0), barrel, seg=12)
        for k in range(3):  # stone shot and a powder keg in the cart
            S.ball(f"shot_{k}", 0.1, (0.38, 0.55 + 0.17 * k, bed_z + 0.13), m["stone"], c)
        S.cyl("keg", 0.14, 0.14, 0.3, (-0.36, 0.7, bed_z + 0.05), S.mat("barrel", "#7c5a36", 0.8, noise=0.3), c, seg=10)
        smoke_mat = m["smoke"]
        self.flash = S.ball("flash", 0.24, (0, 0, 0.85), m["flash"], barrel)
        self.smoke = [S.ball(f"smoke_{k}", 0.3, (0, 0.08 * k, 1.0 + 0.3 * k), smoke_mat, barrel) for k in range(3)]
        for o in [self.flash, *self.smoke]:
            o.visible_shadow = False
        self.wheels = _wheels(c, m, (-0.72, 0.72), (-0.75, 0.75), r=0.42)
        self.horses = _team(self.body, c, m, y=1.25, coat="#6a4a30")
        # The gunner with the linstock and the loader with the rammer, on foot.
        self.crew = []
        for k, role in enumerate(("gunner", "loader")):
            p = people.Figure(f"crew_{k}")
            _hussite_dress(p, m, hat="kettle" if role == "loader" else "cap", beard=role == "gunner",
                           hair=m["fair_hair"] if role == "loader" else None)
            p.held_r = True
            tool = S.empty("linstock" if role == "gunner" else "rammer", (0, 0, -0.02), p.j("hand_r"))
            tool.rotation_euler = (math.radians(-80), 0, 0)
            if role == "gunner":
                S.cyl("linstock_staff", 0.016, 0.014, 1.3, (0, 0, -0.6), m["wood"], tool, seg=6)
                S.ball("match", 0.03, (0, 0, 0.72), m["match"], tool)
            else:
                S.cyl("rammer_pole", 0.02, 0.02, 1.8, (0, 0, -0.85), m["wood"], tool, seg=6)
                S.cyl("rammer_head", 0.07, 0.07, 0.12, (0, 0, 0.95), S.mat("sheepskin_mop", "#c8b894", 1.0, noise=0.4),
                      tool, seg=10)
            p.root.parent = self.body
            self.crew.append(p)

    def pose(self, anim, frame, frames):
        t = frame / frames
        walk = anim == "walk"
        self.body.rotation_euler = (0, 0, 0.0 if walk else math.pi)
        for i, h in enumerate(self.horses):
            h.pose("walk" if walk else "idle", (frame + i * frames // 4) % frames, frames)
        # Walking beside the cart; at rest by the tail board, one on each side.
        places = [(0.95, 0.2), (-0.95, -0.6)] if walk else [(0.9, -1.9), (-0.9, -1.75)]
        for i, (p, (x, y)) in enumerate(zip(self.crew, places)):
            p.root.location = (x, y, 0)
            p.root.rotation_euler = (0, 0, 0.0 if walk else math.pi)
            p.pose("walk" if walk else "idle", (frame + i * 3) % frames, frames)
        kick = flash = 0.0
        smoke = [0.0, 0.0, 0.0]
        if anim == "attack":
            kick = 0.0 if t < 0.12 else math.exp(-(t - 0.12) * 4.0)
            flash = 1.0 if 0.12 <= t < 0.3 else 0.0
            for k in range(3):
                age = t - 0.12 - 0.08 * k
                smoke[k] = 0.0 if age <= 0 else min(1.0, age * 4.0) * (1.0 - 0.5 * max(0.0, age - 0.4))
            for p in self.crew:  # they flinch away from the blast
                p.chest.rotation_euler.x -= math.radians(10) * kick
        self.gun_bed.location.y = -0.35 + 0.16 * kick  # recoil toward the front of the cart
        spin = 2 * math.pi * frame / frames if walk else 0.0
        for w in self.wheels:
            w.rotation_euler = (spin, 0, 0)
        self.cart.location.z = 0.012 * math.sin(4 * math.pi * t) if walk else 0.0
        self.flash.scale = (flash or 0.001,) * 3
        for k, o in enumerate(self.smoke):
            s = max(0.001, smoke[k] * (1.0 + 0.4 * k))
            o.scale = (s, s, s)


def nt_hussite_gun():
    return HussiteGun("nt_hussite_gun")


UNITS = {
    "nt_hussite_flail": nt_hussite_flail,
    "nt_gdansk_militia": nt_gdansk_militia,
    "nt_gdansk_crossbow": nt_gdansk_crossbow,
}
MOUNTED_UNITS = {"hero_mikolaj_michalow": hero_mikolaj_michalow, "hero_capek": hero_capek}
WAGONS = {"nt_hussite_wagon": nt_hussite_wagon, "nt_hussite_gun": nt_hussite_gun}
