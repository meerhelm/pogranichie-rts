"""The battle of Chojnice («Корона 4. Хойнице, 1454», 18 September 1454), on the figure of
people.py, the horse of beasts.py and the pieces of folk.py, folk_1410.py (the sword, the
banner, `Sovereign`), folk_1500.py (the plate harness, the sallet, the mace, the pennon),
folk_1514.py (the handgunner's shot, the White Eagle) and folk_crown_1410.py (the open
bascinet, the crown) (visual assets doc, «Корона Польская», «Тевтонский орден», «Герои Короны
и их противники», the period table: gothic plate, sallets; the Order's hired army is German
and Czech, not landsknechts; the mission card docs/03-missions/15-crown_04_chojnice_1454.md).
Family arms are not drawn: we are not sure of them.

The Crown:
- pl_pospolite: a nobleman of the Great Polish levy in whatever he owns: an old red
  brigandine with rivets over mail, mail sleeves, an old open bascinet with its aventail, a
  plain shield of painted wood (the doc's family arms are not drawn; the doc's three random
  variants are one model here), a lance with a team pennon (attack `thrust`), a sword at the
  hip, a plain bay horse, smaller than a knight's, with only a saddle cloth.

The Order's hired army:
- to_soldner: a German or Czech mercenary foot soldier of the 1450s: an open sallet, a
  brigandine of blue-grey cloth with rivet rows over a green doublet, particoloured hose
  (one leg ochre, one dark), a long spear held like a pike (attack `thrust`; the wide frame
  of pl_drab), a short falchion at the belt. Motley, but no landsknecht slashes.
- to_handgunner: a Bohemian handgunner in the Order's pay, no Hussite chalice: a grey quilted
  coat, a kettle hat, the hand-gun on a wooden tiller with the match (folk_1514.Gunner: aim,
  a flash and a puff of smoke, attack `crossbow` like pl_handgunner, the same wide frame), a
  powder bag and a horn flask, a tesák at the belt.
- to_merc_horse: a mercenary horseman in half armour: breastplate, pauldrons and plate arms,
  a two-lame fauld, a sallet with a bevor, leather riding boots and dark hose (no leg plate),
  a short ochre tunic over the breastplate edged in dark green, a lance with a two-tailed
  team pennon (attack `thrust`), a dun horse of middle weight with a team saddle cloth.

Heroes of the Crown:
- hero_stach (template `mounted`): Stach of Łęczyca, Jaśko's grandson, 19: a bright new
  breastplate with a ridge and new pauldrons that he is trying on in the opening scene, plate
  arms, a red brigandine skirt below it, an open sallet over a young beardless face with fair
  hair, a lance with a team pennon (attack `thrust`), a small plain shield like his
  grandfather's (the doc's «дедов герб» is not drawn), a chestnut horse with a team saddle
  cloth.
- hero_casimir (`sovereign`): King Casimir IV Jagiellon, 27: young and clean shaven, long
  brown hair under an open bascinet with a gold crown, plate of the 1450s under a crimson
  royal mantle with an ermine collar, a sword (attack `swing`; the card has him fighting); a
  dark grey horse under a crimson caparison. Beside him on foot the bearer of the royal
  banner: the crowned White Eagle on red (the Kingdom's arms; the banner the German sources
  say was taken), mail, a red tabard, a kettle hat.
- hero_k4_lords (`mounted`, one model for Bniński, Górka and Szarlejski): a Great Polish
  magnate of the 1450s in full bright plate with plate legs, a sallet with the bevor and the
  face open, a short crimson velvet tabard edged in gold, a gold chain, a mace (attack
  `swing`), a bay horse under a crimson caparison with a team trim. No family arms.

Heroes of the Order:
- hero_reuss_plauen (`mounted`): Heinrich Reuss von Plauen, the Grand Hospitaller holding
  Chojnice, about 50, a different man from the Plauen of Malbork: a full, square, clean-shaven
  face, greying hair, a sallet with the bevor, plate of the 1450s under the knight brother's
  white mantle with the black cross, a white shield with the cross, a sword (attack `swing`:
  he leads the sortie), a black horse under a white caparison with the cross.
- hero_k4_order (`mounted`, one model for Bernhard of Zinnenberg and Duke Rudolf of Żagań):
  a rich secular captain of mercenaries: bright plate with gilt edges, a sallet with a bevor
  and a tall team plume, a short dark blue tabard edged in gold, a war hammer (attack `swing`),
  a grey horse with a chanfron and a dark blue caparison with a team trim. No arms.
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1410 import Sovereign, _banner, _bearer, _sword
from tools.art.folk_1500 import _mace, _plate_harness, _sallet, _two_tailed_pennon
from tools.art.folk_1514 import Gunner, _pike, _white_eagle
from tools.art.folk_crown_1410 import _crown, _open_bascinet, _sword_hip
from tools.art.folk_crown_baltic import _m as _m_k3


def _m():
    m = _m_k3()
    m.update({
        "old_brig": S.mat("old_brigandine", "#6a2a22", 0.85, noise=0.3),
        "old_iron": S.mat("old_iron", "#7c7e80", 0.6, noise=0.35, metal=0.7),
        "levy_shield": S.mat("levy_shield", "#5a6a7a", 0.9, noise=0.3),
        "bright": S.mat("bright_plate", "#c4c8cc", 0.2, metal=0.95),
        "stach_brig": S.mat("stach_brigandine", "#8e2620", 0.8, noise=0.12),
        "soldner_brig": S.mat("soldner_brigandine", "#46546a", 0.85, noise=0.18),
        "doublet_green": S.mat("doublet_green", "#4a5a32", 0.9, noise=0.15),
        "hose_ochre": S.mat("hose_ochre", "#b08a3a", 0.95, noise=0.15),
        "hose_dark": S.mat("hose_dark_k4", "#2e2a30", 0.95, noise=0.12),
        "quilt_grey": S.mat("quilt_grey", "#8a8474", 0.95, noise=0.3),
        "hose_brown": S.mat("hose_brown", "#5a4430", 0.95, noise=0.15),
        "tunic_green": S.mat("tunic_green_dark", "#2e4232", 0.9, noise=0.12),
        "crimson_velvet": S.mat("crimson_velvet", "#7a1622", 0.75, noise=0.08),
        "ermine": S.mat("ermine", "#f2efe6", 0.95, noise=0.1),
        "royal_hair": S.mat("royal_hair", "#5a3e26", 0.9, noise=0.2),
        "blue_velvet": S.mat("blue_velvet", "#1e2c52", 0.75, noise=0.08),
        "face_full": S.mat("face_full", "#c99a7e", 0.7),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _rivets(f, m, mat=None, rows=(0.1, 0.22, 0.34)):
    """Rivet rows round the chest of a brigandine."""
    for i, z in enumerate(rows):
        S.cyl(f"rivets_{i}", 0.2 - 0.01 * i, 0.2 - 0.01 * i, 0.015, (0, 0, z), mat or m["iron"], f.chest,
              seg=12).scale = (1.0, 0.76, 1.0)


def _particoloured(f, mat):
    """The right leg of the hose in another colour (thigh and shin over the body's own)."""
    S.limb("hose_thigh_r", 0.103, 0.085, 0.46, mat, f.j("thigh_r"))
    S.limb("hose_shin_r", 0.081, 0.067, 0.36, mat, f.j("knee_r"))


def _falchion_hip(f, m):
    S.cyl("falchion", 0.022, 0.016, 0.55, (-0.24, 0.06, -0.48), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=4,
          smooth=False)
    S.box("falchion_guard", (0.03, 0.12, 0.02), (-0.24, 0.08, -0.04), m["steel"], f.hips)


def _plate_legs(r, m, mat):
    """Cuisses, poleyns and greaves over a rider's legs."""
    for side in ("l", "r"):
        S.limb(f"cuisse_{side}", 0.106, 0.088, 0.44, mat, r.j(f"thigh_{side}"))
        S.ball(f"poleyn_{side}", 0.07, (0, 0.03, -0.45), mat, r.j(f"thigh_{side}"))
        S.limb(f"greave_{side}", 0.082, 0.068, 0.4, mat, r.j(f"knee_{side}"))


def _war_hammer(f, m, head=None):
    """A horseman's war hammer held up in the right hand: a hammer face and a back spike."""
    f.held_r = True
    head = head or m["steel"]
    w = S.empty("war_hammer", (0, 0, 0), f.j("hand_r"))
    w.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("hammer_haft", 0.017, 0.015, 0.8, (0, 0, -0.14), m["wood"], w, seg=6)
    top = 0.62
    S.box("hammer_head", (0.07, 0.07, 0.08), (0.06, 0, top), head, w)
    S.cyl("hammer_spike", 0.03, 0.0, 0.16, (-0.08, 0, top), head, w, rot=(0, -math.pi / 2, 0), seg=4, smooth=False)
    S.cyl("hammer_top", 0.02, 0.0, 0.1, (0, 0, top + 0.05), head, w, seg=4, smooth=False)
    return w


def _handgun(f, m):
    """The hand-gun in both hands: a short iron barrel on a wooden tiller, the serpentine with
    the glowing match by the breech; the flash and the smoke for folk_1514.Gunner."""
    f.held_r = True
    f.held_l = True
    gun = S.empty("handgun", (0, 0, 0), f.j("hand_r"))
    gun.rotation_euler = (math.radians(-70), 0, math.radians(20))
    S.box("tiller", (0.06, 0.07, 0.55), (0, 0, 0.02), m["wood"], gun)
    S.cyl("barrel", 0.03, 0.026, 0.7, (0, 0.0, 0.26), m["black_iron"], gun, seg=8)
    S.cyl("muzzle", 0.036, 0.036, 0.05, (0, 0.0, 0.94), m["black_iron"], gun, seg=8)
    S.box("serpentine", (0.015, 0.08, 0.12), (0.04, -0.04, 0.24), m["iron"], gun, rot=(math.radians(30), 0, 0))
    S.ball("match_glow", 0.02, (0.04, -0.07, 0.3), m["match"], gun)
    f.flash = S.ball("flash", 0.11, (0, 0, 1.08), m["flash"], gun)
    f.smoke = [S.ball(f"smoke_{k}", 0.16, (0.04 * k, 1.35 + 0.18 * k, 1.42 + 0.05 * k), m["smoke"], f.root)
               for k in range(3)]
    for o in [f.flash, *f.smoke]:
        o.visible_shadow = False
    return gun


def _plain_small_shield(r, m, face):
    sh = folk._heater(r, face, m, cross=False)
    sh.scale = (0.82, 0.82, 0.82)
    S.ball("shield_boss", 0.04, (0, -0.05, 0.36), m["iron"], sh, scale=(1.0, 0.6, 1.0))
    return sh


# --- the Crown -----------------------------------------------------------------------------

def pl_pospolite():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["hose"], m["boots"], m, m["hair"])
    r.skirt("mail_skirt", 0.06, -0.32, 0.23, 0.3, m["mail"])
    # The old brigandine: faded red cloth, rivet rows, its skirt over the mail.
    S.cyl("brigandine", 0.2, 0.24, 0.4, (0, 0.0, 0.06), m["old_brig"], r.chest, seg=12).scale = (1.0, 0.78, 1.0)
    r.skirt("brig_skirt", 0.06, -0.16, 0.24, 0.29, m["old_brig"])
    _rivets(r, m, m["old_iron"])
    for side in ("l", "r"):  # an odd old couter on each elbow
        S.ball(f"couter_{side}", 0.07, (0, 0, 0.0), m["old_iron"], r.j(f"elbow_{side}"))
    folk._belt(r, m["team"], r=0.245)
    _open_bascinet(r, m, m["old_iron"])
    S.box("moustache", (0.12, 0.03, 0.025), (0, 0.125, -0.045), m["hair"], r.head)
    beasts._lance(r, m, length=3.6, pennon=m["team"])
    _plain_small_shield(r, m, m["levy_shield"])
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("levy_bay", "#74482c", 0.95, noise=0.3), size=0.96)
    return beasts.Mounted("pl_pospolite", h, r, m["team"])


# --- the Order's hired army ----------------------------------------------------------------

def to_soldner():
    m = _m()
    f = people.Figure("to_soldner")
    f.body(m["skin"], m["doublet_green"], m["hose_dark"], m["leather"])
    f.hair(m["hair"])
    _particoloured(f, m["hose_ochre"])
    S.cyl("brigandine", 0.2, 0.24, 0.4, (0, 0.0, 0.06), m["soldner_brig"], f.chest, seg=12).scale = (1.0, 0.76, 1.0)
    f.skirt("brig_skirt", 0.06, -0.2, 0.235, 0.29, m["soldner_brig"])
    f.skirt("hem", -0.16, -0.22, 0.29, 0.295, m["team"])
    _rivets(f, m)
    folk._belt(f, m["leather"], r=0.245)
    _sallet(f, m, m["steel"], bevor=False, open_face=True)
    _falchion_hip(f, m)
    _pike(f, m, length=3.4)
    return f


def to_handgunner():
    m = _m()
    f = Gunner("to_handgunner")
    f.body(m["skin"], m["quilt_grey"], m["hose_brown"], m["leather"])
    f.hair(m["dark_hair"])
    folk._legs_skirt(f, m["quilt_grey"], -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    for k, z in enumerate((0.12, 0.26)):  # quilting seams
        S.cyl(f"quilt_seam_{k}", 0.205 - 0.01 * k, 0.205 - 0.01 * k, 0.014, (0, 0, z), m["leather"], f.chest,
              seg=12).scale = (1.0, 0.76, 1.0)
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["iron"])
    S.box("powder_bag", (0.08, 0.16, 0.18), (0.24, 0.06, -0.14), m["leather"], f.hips)
    S.cyl("flask", 0.045, 0.035, 0.14, (-0.23, 0.12, -0.2), S.mat("horn", "#8a7a5a", 0.6, noise=0.2), f.hips, seg=8)
    S.cyl("tesak", 0.018, 0.014, 0.45, (-0.24, -0.06, -0.42), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=4,
          smooth=False)
    _handgun(f, m)
    return f


def to_merc_horse():
    m = _m()
    r = beasts._rider("rider", m["tunic_green"], m["hose_dark"], m["boots"], m, m["hair"])
    _plate_harness(r, m, mat=m["plate"], faulds=2)
    # A short ochre tunic over the breastplate (a German waffenrock), its skirt edged in green.
    S.cyl("tunic", 0.2, 0.245, 0.3, (0, 0.0, 0.04), m["hose_ochre"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tunic_skirt", 0.06, -0.32, 0.25, 0.33, m["hose_ochre"])
    r.skirt("tunic_hem", -0.28, -0.34, 0.33, 0.335, m["tunic_green"])
    folk._belt(r, m["team"], r=0.258)
    _sallet(r, m, m["plate"], bevor=True)
    spear = beasts._lance(r, m, length=3.8)
    _two_tailed_pennon(spear, 3.8, m["team"])
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("dun", "#8a6a44", 0.9, noise=0.25))
    return beasts.Mounted("to_merc_horse", h, r, m["team"])


# --- heroes of the Crown -------------------------------------------------------------------

def hero_stach():
    m = _m()
    bright = m["bright"]
    r = beasts._rider("rider", m["stach_brig"], m["hose"], m["boots"], m, m["fair_hair"], beard=False)
    # The new harness: a bright ridged breastplate and pauldrons, plate arms; the red
    # brigandine shows below as a skirt.
    _plate_harness(r, m, mat=bright, faulds=1)
    r.skirt("brig_skirt", -0.04, -0.3, 0.25, 0.31, m["stach_brig"])
    for side in ("l", "r"):  # the new pauldron's straps
        S.box(f"pauldron_strap_{side}", (0.03, 0.2, 0.025), (0, 0, 0.04), m["leather"], r.j(f"shoulder_{side}"))
    folk._belt(r, m["team"], r=0.255)
    _sallet(r, m, bright, bevor=False, open_face=True)
    beasts._lance(r, m, length=3.7, pennon=m["team"])
    _plain_small_shield(r, m, m["plain_shield"])
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("chestnut", "#8a4a26", 0.9, noise=0.25), size=1.0)
    return beasts.Mounted("hero_stach", h, r, m["team"])


def _ermine_collar(f, m):
    S.cyl("ermine_collar", 0.27, 0.2, 0.09, (0, -0.02, 0.44), m["ermine"], f.chest, seg=12)
    for k in range(6):
        a = math.pi * (0.15 + 0.7 * k / 5)
        S.box(f"ermine_tail_{k}", (0.025, 0.025, 0.04), (0.25 * math.cos(a), 0.2 * math.sin(a) - 0.02, 0.44),
              m["order_black"], f.chest)


def hero_casimir():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["plate"], m["plate"], m, m["royal_hair"], beard=False)
    _plate_harness(r, m)
    _plate_legs(r, m, m["plate"])
    folk._cloak(r, m["crimson_velvet"], bottom=-0.65, r_bottom=0.42)
    _ermine_collar(r, m)
    S.cyl("cloak_clasp", 0.04, 0.04, 0.02, (0, 0.2, 0.4), m["gold"], r.chest, rot=(-math.pi / 2, 0, 0), seg=8)
    folk._belt(r, m["team"], r=0.255)
    _open_bascinet(r, m, m["plate"])
    S.ball("long_hair", 0.11, (0, -0.1, -0.12), m["royal_hair"], r.head, scale=(1.2, 0.8, 1.2))  # down the neck
    _crown(r, m)
    _sword(r, m)
    h = beasts.horse("horse", S.mat("dark_grey_horse", "#5e5a56", 0.9, noise=0.25), size=1.06)
    beasts.caparison(h, m["crimson_velvet"], m["team"])
    # The bearer of the royal banner: the crowned White Eagle on red.
    b = _bearer(m, m["red_cloth"], m["trousers"], m["hair"])

    def eagles(cloth):  # on both faces of the cloth
        _white_eagle("banner_eagle", cloth, (0, -0.012, 0.03), 0.95, m)
        _white_eagle("banner_eagle_back", cloth, (0, 0.012, 0.03), 0.95, m).rotation_euler = (0, 0, math.pi)

    _banner(b, m, m["court_red"], eagles, width=0.75, height=0.64)
    return Sovereign("hero_casimir", h, r, m["team"], b)


def hero_k4_lords():
    m = _m()
    bright = m["bright"]
    r = beasts._rider("rider", bright, bright, bright, m, m["dark_hair"])
    _plate_harness(r, m, mat=bright)
    _plate_legs(r, m, bright)
    # A short tabard of crimson velvet edged in gold over the plate, a gold chain.
    S.cyl("tabard", 0.2, 0.245, 0.26, (0, 0.0, 0.02), m["crimson_velvet"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tabard_skirt", 0.06, -0.3, 0.25, 0.33, m["crimson_velvet"])
    r.skirt("tabard_hem", -0.27, -0.32, 0.33, 0.335, m["gold"])
    S.cyl("gold_chain", 0.22, 0.2, 0.025, (0, 0.03, 0.36), m["gold"], r.chest, rot=(math.radians(-12), 0, 0),
          seg=12).scale = (1.0, 0.85, 1.0)
    folk._belt(r, m["team"], r=0.255)
    _sallet(r, m, bright, bevor=True, open_face=True)
    S.box("moustache", (0.12, 0.03, 0.025), (0, 0.125, -0.045), m["dark_hair"], r.head)
    _mace(r, m, head=m["gold"])
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("bay", "#6e4026", 0.9, noise=0.25), size=1.08)
    beasts.caparison(h, m["crimson_velvet"], m["team"])
    return beasts.Mounted("hero_k4_lords", h, r, m["team"])


# --- heroes of the Order -------------------------------------------------------------------

def hero_reuss_plauen():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["plate"], m["plate"], m, m["greying_hair"], beard=False)
    _plate_harness(r, m)
    _plate_legs(r, m, m["plate"])
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._cross("cloak_cross_back", r.chest, (0, -0.24, 0.2), 0.3, m["order_black"])
    _sallet(r, m, m["plate"], bevor=True, open_face=True)
    # A full, square, clean-shaven face: heavy jaw, not Plauen of Malbork's hollow cheeks.
    S.box("jaw", (0.17, 0.05, 0.05), (0, 0.11, -0.07), m["face_full"], r.head)
    _sword(r, m)
    folk._heater(r, m["order_white"], m)
    _sword_hip(r, m)
    h = beasts.horse("horse", m["black_horse"], size=1.08)
    beasts.caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    return beasts.Mounted("hero_reuss_plauen", h, r, m["team"])


def hero_k4_order():
    m = _m()
    bright = m["bright"]
    r = beasts._rider("rider", bright, bright, bright, m, m["hair"])
    _plate_harness(r, m, mat=bright)
    _plate_legs(r, m, bright)
    for side in ("l", "r"):  # gilt edges on the pauldrons
        S.cyl(f"pauldron_gilt_{side}", 0.112, 0.112, 0.02, (0, 0, -0.04), m["gold"], r.j(f"shoulder_{side}"), seg=12)
    S.cyl("tabard", 0.2, 0.245, 0.24, (0, 0.0, 0.0), m["blue_velvet"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tabard_skirt", 0.06, -0.28, 0.25, 0.32, m["blue_velvet"])
    r.skirt("tabard_hem", -0.25, -0.3, 0.32, 0.325, m["gold"])
    folk._belt(r, m["gold"], r=0.255)
    _sallet(r, m, bright, bevor=True, open_face=True)
    # A tall plume in the player colour from a socket on the sallet.
    S.cyl("plume_socket", 0.02, 0.02, 0.06, (0, -0.06, 0.18), m["gold"], r.head, seg=6)
    S.ball("plume", 0.06, (0, -0.1, 0.3), m["team"], r.head, scale=(0.7, 1.4, 2.0))
    S.box("moustache", (0.12, 0.03, 0.025), (0, 0.125, -0.045), m["hair"], r.head)
    _war_hammer(r, m)
    _sword_hip(r, m)
    h = beasts.horse("horse", m["grey_horse"], size=1.08)
    S.box("chanfron", (0.12, 0.45, 0.05), (0, 0.18, 0.08), bright, h.head)
    beasts.caparison(h, m["blue_velvet"], m["team"])
    return beasts.Mounted("hero_k4_order", h, r, m["team"])


UNITS = {"to_soldner": to_soldner, "to_handgunner": to_handgunner}
MOUNTED_UNITS = {
    "pl_pospolite": pl_pospolite,
    "to_merc_horse": to_merc_horse,
    "hero_stach": hero_stach,
    "hero_casimir": hero_casimir,
    "hero_k4_lords": hero_k4_lords,
    "hero_reuss_plauen": hero_reuss_plauen,
    "hero_k4_order": hero_k4_order,
}
