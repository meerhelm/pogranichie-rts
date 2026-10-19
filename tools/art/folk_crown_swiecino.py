"""The battle of Świecino («Корона 6. Свецино, 1462», 17 September 1462), on the figure of
people.py, the horse of beasts.py and the pieces of folk.py, folk_1500.py (the plate harness,
the sallet, the mace, the pennon, the chanfron) and folk_crown_chojnice.py (the plate legs, the
war hammer, the rivets) (visual assets doc, «Герои Короны и их противники», `nt_pomeranian`;
the mission card docs/03-missions/17-crown_06_swiecino_1462.md). Two hired armies of the
1460s: half armour and sallets on both sides, no landsknechts. Only Dunin's arms are drawn
(the doc names them); the others are not, we are not sure of them.

Heroes of the Crown:
- hero_dunin (`mounted`): Piotr Dunin of Prawkowice, the commander of the royal mercenaries,
  a practical soldier in his late forties: plain steel half armour (breastplate, fauld,
  pauldrons, plate arms; mail at the thighs, riding boots), a short red tabard with his arms
  Łabędź on the chest (a white swan on red), an open sallet with the bevor over a weathered
  face with a greying beard, a pear-headed steel mace (attack `swing`), a small heater shield
  with the swan, a sword at the hip, a bay horse with a team saddle cloth and no caparison:
  the wage-paying captain, not a lord.
- hero_jasienski (`mounted`): Paweł Jasieński, who opens the battle with the heavy horse: full
  bright plate with plate legs, a closed sallet with the bevor and a white plume, a short
  dark green tabard edged in gold, a lance with a two-tailed team pennon (attack `thrust`), a
  big grey horse with a chanfron and a dark green caparison with a team trim. His arms are
  not drawn.

Heroes of the Order:
- hero_raweneck (`mounted`): Fritz Raweneck, the captain of the Order's mercenaries, a
  soldierly type: well-worn dark russeted half armour with plate arms, a mail skirt and
  boots, a short black tabard edged in ochre, an open sallet with the bevor over a lean face
  with a grizzled short beard and a heavy moustache, a sword raised (attack `swing`: he leads
  the charge himself), a dun horse with a team saddle cloth. No arms drawn.
- hero_nostitz (`mounted`): Kaspar Nostitz, the mercenary captain holding Chojnice: the same
  soldierly type with another face and colours: plain steel half armour, a short tabard
  quartered dark red and white, an open sallet without a bevor over a full, clean-shaven face
  with fair hair, a war hammer (attack `swing`), a black horse with a team saddle cloth. His
  family arms are not drawn.

The Order's levy:
- nt_pomeranian («Поморский мужик»): a peasant of Duke Eric II's Pomerania sent to the Order: a
  grey-brown homespun coat to the knee with a team hem, a linen shirt, a hood with a short
  cape over the shoulders, linen leg wraps and bast shoes, a sickle at the rope belt, a
  wooden three-tined pitchfork with iron-shod tines held like a spear (attack `thrust`). The
  doc's flail and scythe are the same man; one model.
"""

import math

from tools.art import beasts, folk, people
from tools.art import shapes as S
from tools.art.folk_1410 import _sword
from tools.art.folk_1500 import _mace, _plate_harness, _sallet, _two_tailed_pennon
from tools.art.folk_crown_1410 import _sword_hip
from tools.art.folk_crown_chojnice import _m as _m_k4
from tools.art.folk_crown_chojnice import _plate_legs, _war_hammer


def _m():
    m = _m_k4()
    m.update({
        "labedz_red": S.mat("labedz_red", "#a01c1c", 0.85, noise=0.1),
        "swan": S.mat("swan_white", "#f2f0ea", 0.85, noise=0.05),
        "beak": S.mat("swan_beak", "#1c1a18", 0.8),
        "worn_steel": S.mat("worn_steel", "#8e9296", 0.45, noise=0.3, metal=0.8),
        "russet": S.mat("russet_plate", "#5c5a58", 0.4, noise=0.3, metal=0.8),
        "green_velvet": S.mat("green_velvet", "#1f3a2a", 0.75, noise=0.08),
        "raw_black": S.mat("raweneck_black", "#1e1c1c", 0.85, noise=0.12),
        "nostitz_red": S.mat("nostitz_red", "#7a2420", 0.8, noise=0.12),
        "tan_face": S.mat("tan_face", "#b78a6a", 0.65),
        "pomer_coat": S.mat("pomeranian_coat", "#6e6450", 0.95, noise=0.25),
        "pomer_hood": S.mat("pomeranian_hood", "#5a4a38", 0.95, noise=0.2),
        "rope": S.mat("rope_belt", "#a08a5a", 0.95, noise=0.4),
        "big_bay": S.mat("dunin_bay", "#6a3c22", 0.9, noise=0.25),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _swan(name, parent, loc, size, m):
    """Łabędź: a white swan swimming to the right, its neck curved up, a black beak; a flat
    silhouette in the XZ plane of `parent`."""
    white, beak = m["swan"], m["beak"]
    h = S.empty(name, loc, parent)
    s = size
    body = [(-0.4 * s, 0, 0.1 * s), (-0.3 * s, 0, -0.04 * s), (-0.1 * s, 0, -0.14 * s), (0.12 * s, 0, -0.13 * s),
            (0.28 * s, 0, -0.04 * s), (0.3 * s, 0, 0.06 * s), (0.12 * s, 0, 0.14 * s), (-0.16 * s, 0, 0.16 * s)]
    S.solidify(S.poly(f"{name}_body", body, [tuple(range(len(body)))], white, h), 0.02)
    # The raised wing over the back.
    wing = [(-0.26 * s, 0, 0.12 * s), (-0.1 * s, 0, 0.34 * s), (0.12 * s, 0, 0.12 * s)]
    S.solidify(S.poly(f"{name}_wing", wing, [(0, 1, 2)], white, h), 0.02)
    # The neck rising in a curve to the head.
    neck = [(0.18 * s, 0, 0.06 * s), (0.3 * s, 0, 0.06 * s), (0.28 * s, 0, 0.28 * s), (0.34 * s, 0, 0.44 * s),
            (0.25 * s, 0, 0.46 * s), (0.19 * s, 0, 0.3 * s)]
    S.solidify(S.poly(f"{name}_neck", neck, [tuple(range(len(neck)))], white, h), 0.02)
    S.box(f"{name}_head", (0.12 * s, 0.03, 0.08 * s), (0.31 * s, 0, 0.47 * s), white, h)
    S.solidify(S.poly(f"{name}_beak", [(0.36 * s, 0, 0.5 * s), (0.48 * s, 0, 0.44 * s), (0.36 * s, 0, 0.43 * s)],
                      [(0, 1, 2)], beak, h), 0.025)
    return h


def _half_armour(r, m, mat, faulds=2):
    """The captain's half armour of the 1460s: folk_1500's harness with a shorter fauld, mail
    under it at the thighs."""
    _plate_harness(r, m, mat=mat, faulds=faulds)
    r.skirt("mail_skirt", -0.1, -0.34, 0.26, 0.31, m["mail"])


def _tabard(r, m, mat, hem, top=0.02):
    S.cyl("tabard", 0.2, 0.245, 0.26, (0, 0.0, top), mat, r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tabard_skirt", 0.06, -0.28, 0.25, 0.32, mat)
    r.skirt("tabard_hem", -0.25, -0.3, 0.32, 0.325, hem)


# --- heroes of the Crown -------------------------------------------------------------------

def hero_dunin():
    m = _m()
    steel = m["worn_steel"]
    r = beasts._rider("rider", m["labedz_red"], m["hose_dark"], m["boots"], m, m["greying_hair"])
    _half_armour(r, m, steel)
    _tabard(r, m, m["labedz_red"], m["team"])
    _swan("chest_swan", r.chest, (0, 0.205, 0.2), 0.42, m)
    folk._belt(r, m["leather"], r=0.258)
    _sallet(r, m, steel, bevor=True, open_face=True)
    # A weathered face: a greying beard over the bevor, a heavy moustache.
    S.box("moustache", (0.13, 0.03, 0.028), (0, 0.125, -0.045), m["greying_hair"], r.head)
    S.ball("short_beard", 0.07, (0, 0.09, -0.09), m["greying_hair"], r.head, scale=(1.1, 0.8, 0.9))
    _mace(r, m, head=steel)
    sh = folk._heater(r, m["labedz_red"], m, cross=False)
    sh.scale = (0.85, 0.85, 0.85)
    _swan("shield_swan", sh, (0, -0.045, 0.38), 0.7, m)
    _sword_hip(r, m)
    h = beasts.horse("horse", m["big_bay"], size=1.06)
    return beasts.Mounted("hero_dunin", h, r, m["team"])


def hero_jasienski():
    m = _m()
    bright = m["bright"]
    r = beasts._rider("rider", bright, bright, bright, m, m["dark_hair"])
    _plate_harness(r, m, mat=bright)
    _plate_legs(r, m, bright)
    _tabard(r, m, m["green_velvet"], m["gold"], top=0.0)
    folk._belt(r, m["team"], r=0.255)
    # A closed sallet with the bevor, a white plume from a socket at the back.
    _sallet(r, m, bright, bevor=True, open_face=False)
    S.cyl("plume_socket", 0.02, 0.02, 0.06, (0, -0.06, 0.18), m["gold"], r.head, seg=6)
    S.ball("plume", 0.06, (0, -0.12, 0.28), m["white_cloth"], r.head, scale=(0.7, 1.6, 1.6))
    lance = beasts._lance(r, m, length=3.9)
    _two_tailed_pennon(lance, 3.9, m["team"])
    _sword_hip(r, m)
    h = beasts.horse("horse", m["grey_horse"], size=1.1)
    S.box("chanfron", (0.12, 0.45, 0.05), (0, 0.18, 0.08), bright, h.head)
    beasts.caparison(h, m["green_velvet"], m["team"])
    return beasts.Mounted("hero_jasienski", h, r, m["team"])


# --- heroes of the Order -------------------------------------------------------------------

def hero_raweneck():
    m = _m()
    black = m["russet"]
    r = beasts._rider("rider", m["raw_black"], m["hose_dark"], m["boots"], m, m["grizzled"])
    _half_armour(r, m, black)
    _tabard(r, m, m["raw_black"], m["hose_ochre"])
    folk._belt(r, m["team"], r=0.258)
    _sallet(r, m, black, bevor=True, open_face=True)
    # A lean, tanned soldier's face: a grizzled short beard, a heavy moustache.
    S.box("face_tan", (0.15, 0.05, 0.11), (0, 0.132, -0.03), m["tan_face"], r.head)
    S.box("moustache", (0.14, 0.03, 0.03), (0, 0.14, -0.045), m["grizzled"], r.head)
    _sword(r, m)
    _sword_hip(r, m)
    h = beasts.horse("horse", S.mat("raweneck_dun", "#7e6040", 0.9, noise=0.25), size=1.04)
    return beasts.Mounted("hero_raweneck", h, r, m["team"])


def hero_nostitz():
    m = _m()
    steel = m["worn_steel"]
    r = beasts._rider("rider", m["nostitz_red"], m["hose_dark"], m["boots"], m, m["fair_hair"], beard=False)
    _half_armour(r, m, steel)
    # A short tabard quartered dark red and white (the colours only, not his arms).
    _tabard(r, m, m["nostitz_red"], m["team"])
    for x, z in ((0.07, 0.24), (-0.07, 0.1)):
        S.box(f"tabard_quarter_{z}", (0.14, 0.02, 0.14), (x, 0.205, z), m["white_cloth"], r.chest)
    folk._belt(r, m["leather"], r=0.258)
    _sallet(r, m, steel, bevor=False, open_face=True)
    # A full, square, clean-shaven face.
    S.box("jaw", (0.17, 0.05, 0.05), (0, 0.11, -0.07), m["face_full"], r.head)
    _war_hammer(r, m)
    _sword_hip(r, m)
    h = beasts.horse("horse", m["black_horse"], size=1.04)
    return beasts.Mounted("hero_nostitz", h, r, m["team"])


# --- the Order's levy ----------------------------------------------------------------------

def _pitchfork(f, m, length=2.0):
    """A wooden pitchfork held like a spear: an ash shaft, a crosspiece, three tines shod with
    iron."""
    f.held_r = True
    fork = S.empty("pitchfork", (0, 0, -0.02), f.j("hand_r"))
    fork.rotation_euler = (math.radians(-80), 0, 0)
    top = length - 0.85
    S.cyl("fork_shaft", 0.019, 0.017, length, (0, 0, -0.85), m["wood"], fork, seg=6)
    S.box("fork_bar", (0.22, 0.03, 0.035), (0, 0, top), m["wood"], fork)
    for k, x in enumerate((-0.09, 0.0, 0.09)):
        S.cyl(f"fork_tine_{k}", 0.012, 0.011, 0.22, (x, 0, top), m["wood"], fork, seg=5)
        S.cyl(f"fork_point_{k}", 0.012, 0.0, 0.1, (x, 0, top + 0.22), m["iron"], fork, seg=4, smooth=False)
    return fork


def nt_pomeranian():
    m = _m()
    f = people.Figure("nt_pomeranian")
    coat = m["pomer_coat"]
    f.body(m["skin"], coat, m["trousers"], m["lapti"], wraps=m["wraps"])
    f.hair(m["fair_hair"])
    f.skirt("shirt_hem", 0.05, -0.4, 0.2, 0.27, m["linen"])
    f.skirt("coat_skirt", 0.06, -0.34, 0.21, 0.3, coat)
    f.skirt("coat_hem", -0.31, -0.37, 0.3, 0.305, m["team"])
    S.cyl("collar", 0.09, 0.085, 0.05, (0, 0, 0.47), m["linen"], f.chest, seg=10)
    folk._belt(f, m["rope"], r=0.22)
    folk._hood(f, m["pomer_hood"], cape=m["pomer_hood"])
    # A sickle hung at the belt.
    S.cyl("sickle_grip", 0.016, 0.016, 0.12, (-0.22, 0.06, -0.1), m["wood"], f.hips, seg=6)
    for k in range(5):  # the blade: a crescent of short pieces hanging from the grip
        a = math.radians(-40 + 45 * k)
        S.box(f"sickle_blade_{k}", (0.012, 0.05, 0.02), (-0.235, 0.12 + 0.1 * math.sin(a), -0.27 + 0.1 * math.cos(a)),
              m["iron"], f.hips, rot=(-a, 0, 0))
    _pitchfork(f, m)
    return f


UNITS = {"nt_pomeranian": nt_pomeranian}
MOUNTED_UNITS = {
    "hero_dunin": hero_dunin,
    "hero_jasienski": hero_jasienski,
    "hero_raweneck": hero_raweneck,
    "hero_nostitz": hero_nostitz,
}
