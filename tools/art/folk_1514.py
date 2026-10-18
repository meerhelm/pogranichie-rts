"""The battle of Orsha (ВКЛ 8, 8 September 1514): the Crown's mercenary foot and light hussars,
the Polish and Muscovite commanders, the chronicler Maciej Gintowt and the props of the
crossing, on the figure of people.py, the horse of beasts.py and the pieces of folk_1500.py
(visual assets doc, «Корона Польская», «Герои ВКЛ и их противники», the period table: gothic
and early Maximilian plate, sallets and armets, Serbian light horse with the tarcza, hand-guns
with a match; no winged hussars, no kontusz; for Muscovy no berdysh and no zertsalo; the mission
card docs/03-missions/10-gdl_08_orsha_1514.md; main reference the painting «Битва под Оршей»).

Crown units:
- pl_drab: a hired foot soldier of the Bohemian and Silesian infantry at Orsha. The doc: «салад
  или шапель, стёганка, длинное копьё, лопата за спиной»: a kettle hat (chapel-de-fer), a
  quilted coat with the team hem, a long pike (attack `thrust`), a spade slung on the back
  (he digs the ditch at the tabor). A wider and taller frame: the pike reaches far.
- pl_handgunner: «ручница — короткий ствол на деревянной ложе, фитиль, пороховая сумка,
  шапель»: a quilted coat, a kettle hat, a short iron barrel on a wooden tiller, the match in a
  serpentine by the breech, a powder bag and a flask at the belt. Attack `crossbow` as the
  hakownica of folk_1508 (aim, kick, lower), plus a muzzle flash and a puff of smoke that
  hangs where the shot went (the doc's «дым»).
- pl_hussar: the light Serbian-style hussar of about 1500, «без крыльев и лат»: a long
  red cloth coat, a tall cloth cap with a fur band and a feather, the asymmetric wooden tarcza
  with its point raised at the top of the leading edge (painted, a team rim), a long light lance
  with a pennon (attack `thrust`), a sabre, a small light horse with a team saddle cloth.

Heroes:
- hero_swierczowski: Janusz (the doc: Jan) Świerczowski. The doc: «солдатский тип, полулаты,
  берет», the card: he led the Polish mercenary horse. A mercenary captain in blackened half
  armour (breast, back, pauldrons, arms, a fauld; the legs in hose and riding boots, no leg
  plate), a wide black beret with a white feather, a short beard, a straight sword drawn (attack
  `swing`), a plain bay with a red and white saddle cloth. His arms are not drawn.
- hero_sampolinski: Wojciech Sampoliński, rotmistrz of the royal court banners (the doc:
  «доспех около 1510; герб не проверен»): bright full plate with plate legs, a round armet with
  the visor raised and a red and white plume (not a sallet, unlike the Duchy's lancers), a short
  crimson tabard, the court banner in his hand: the White Eagle crowned in gold on red (the
  king's own arms, not his family's; attack `thrust` like hero_andrei), a grey horse with a
  chanfron and a crimson saddle cloth edged in white.
- hero_chelyadnin: Ivan Chelyadnin, boyar and master of the horse (конюший), commander of the
  Large Regiment. The doc: «просторная ферязь, шишак»: mail and a bakhterets with gilt rows
  under a wide dark green ferjaz with gold edging (Shchenya's is red), a gilt-rimmed tall
  shishak with a mail barmitsa, a dark full beard, a drawn sabre (attack `swing`), a white horse
  of the master of the horse with a crimson chaprak edged in gold, the eastern saddle.
- hero_bulgakov: Prince Mikhail Bulgakov-Golitsa, voivode of the Right Hand: mature, greying,
  «богатый доспех»: a kolontar of large steel plates with gilt rows over mail, gilt vambraces,
  a short blue kaftan skirt, a shishak with a small team-coloured yalovets on the spike, a lance
  with a pennon (attack `thrust`), a dark bay with a blue chaprak edged in silver.
- hero_maciej: Maciej Gintowt, the chronicler, scribe with the hetman, a Samogitian Catholic:
  a long dark blue-black coat to the ankles (a delia-like overcoat over a żupan), a soft black
  scholar's cap, a quill behind the cap, an inkwell and a pen case at the belt, a small Catholic
  cross, the book held in his left hand. Face and colours are invented; a civilian: idle and
  walk only.

Map props (one view, color and shadow, no team pass, like trees):
- prop_boats: two flat-bottomed river boats (плоскодонки) of planks pulled up on the bank for
  the pontoon bridge, one upright with thwarts, oars and a pole, one turned keel up beside it.
- prop_logs: a stack of trimmed logs for the bridge (the card: «лодки + бочки + брёвна»), a
  pile of planks, stakes, an axe in a log, a coil of rope.
- prop_oak: «старый дуб над Кропивной», the last place of power of the campaign: a very old,
  wide oak, about 12 m high with a crown some 10 m across (a pine is 7.5 m), a thick buttressed
  trunk with a hollow, heavy crooked limbs, one dead bough, the crown green going yellow in
  September. It needs a bigger frame than the other props (registry.PROP_FRAMES).
"""

import math
import random

from mathutils import Vector

from tools.art import beasts, folk, kit, people
from tools.art import shapes as S
from tools.art.folk_1410 import _banner, _sword
from tools.art.folk_1435 import _neck_cross
from tools.art.folk_1500 import (EasternMounted, _bakhterets, _chanfron, _chaprak, _kaftan, _m as _m1500,
                                 _plate_harness, _sabre_hip, _shishak, _two_tailed_pennon)
from tools.art.folk_1507 import _sabre_drawn, _scabbard


def _m():
    m = _m1500()
    m.update({
        "drab_quilt": S.mat("drab_quilt", "#a08a62", 0.95, noise=0.3),
        "drab_hose": S.mat("drab_hose", "#6a3a30", 0.95, noise=0.15),
        "gunner_quilt": S.mat("gunner_quilt", "#8a7c5e", 0.95, noise=0.3),
        "gunner_hose": S.mat("gunner_hose", "#4e5a44", 0.95, noise=0.15),
        "hussar_red": S.mat("hussar_red", "#9a2a22", 0.9, noise=0.12),
        "hussar_cap": S.mat("hussar_cap", "#7a1e1a", 0.9, noise=0.12),
        "tarcza_face": S.mat("tarcza_face", "#c8b07a", 0.85, noise=0.25),
        "black_plate": S.mat("black_plate", "#34363a", 0.4, noise=0.1, metal=0.75),
        "beret": S.mat("beret_black", "#1e1c1e", 0.95, noise=0.08),
        "feather": S.mat("feather_white", "#eeece4", 0.9, noise=0.05),
        "doublet": S.mat("doublet_red", "#8e2622", 0.9, noise=0.12),
        "hose_white": S.mat("hose_white", "#d8d2c4", 0.95, noise=0.1),
        "boots": S.mat("riding_boots", "#3a2a1e", 0.8, noise=0.2),
        "court_red": S.mat("court_red", "#b0201c", 0.9, noise=0.08),
        "eagle_white": S.mat("eagle_white", "#f0eee8", 0.85),
        "ferjaz_green": S.mat("ferjaz_green", "#24503a", 0.85, noise=0.12),
        "kaftan_blue": S.mat("kaftan_blue", "#24406e", 0.85, noise=0.12),
        "silver": S.mat("silver", "#c8ccd0", 0.3, metal=0.9),
        "white_horse": S.mat("white_horse", "#d8d4cc", 0.9, noise=0.2),
        "scribe_coat": S.mat("scribe_coat", "#23242e", 0.95, noise=0.1),
        "scribe_zupan": S.mat("scribe_zupan", "#5a4a3a", 0.95, noise=0.12),
        "ink": S.mat("ink_horn", "#2a1e16", 0.5),
        "paper": S.mat("paper", "#e2d6b4", 0.9, noise=0.1),
        "smoke": S.mat("smoke", "#b9b6ae", 1.0, noise=0.3),
        "flash": S.mat("flash", "#ffcf5a", 0.6),
        "match": S.mat("match_glow", "#e0702a", 0.6),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _pike(f, m, length=3.6):
    """A long pike in the right hand: a thin ash shaft, a small leaf head with langets."""
    spear = folk._spear(f, m, length=length)
    S.cyl("pike_langet", 0.022, 0.022, 0.3, (0, 0, length - 1.15), m["iron"], spear, seg=4)
    return spear


def _spade_on_back(f, m):
    """A wooden spade with an iron edge slung across the back, blade up."""
    sp = S.empty("spade", (0.05, -0.2, 0.15), f.chest)
    sp.rotation_euler = (math.radians(-8), math.radians(28), 0)
    S.cyl("spade_haft", 0.016, 0.016, 1.0, (0, 0, -0.45), m["wood"], sp, seg=6)
    S.box("spade_blade", (0.2, 0.03, 0.26), (0, 0, 0.66), m["wood"], sp)
    S.box("spade_edge", (0.2, 0.035, 0.04), (0, 0, 0.79), m["iron"], sp)
    S.box("spade_strap", (0.04, 0.02, 0.62), (0.0, 0.19, 0.0), m["leather"], f.chest,
          rot=(0, math.radians(-38), 0))


def _foot_dress(f, m, quilt, hose):
    f.body(m["skin"], quilt, hose, m["leather"])
    f.hair(m["hair"])
    folk._legs_skirt(f, quilt, -0.36, 0.3)
    f.skirt("hem", -0.32, -0.38, 0.3, 0.305, m["team"])
    for k, z in enumerate((0.12, 0.26)):  # quilting seams
        S.cyl(f"quilt_seam_{k}", 0.205 - 0.01 * k, 0.205 - 0.01 * k, 0.014, (0, 0, z), m["leather"], f.chest,
              seg=12).scale = (1.0, 0.76, 1.0)
    folk._belt(f, m["leather"], r=0.24)
    folk._chapel(f, m["iron"])


def _tarcza(f, m):
    """The hussar's tarcza on the left arm: a wooden shield, taller at the leading edge, whose
    upper corner rises into a point; painted, a team-coloured rim."""
    f.held_l = True
    holder = S.empty("tarcza", (-0.25, 0.27, -0.12), f.chest)
    holder.rotation_euler = (math.radians(-6), 0, math.pi + math.radians(25))
    pts = [(-0.22, 0, 0.0), (0.2, 0, 0.06), (0.24, 0, 0.6), (0.14, 0, 0.98), (0.06, 0, 0.72), (-0.24, 0, 0.6)]
    face = [(0, 1, 2, 4, 5), (2, 3, 4)]
    S.solidify(S.poly("tarcza_rim", pts, face, m["team"], holder), 0.03)
    inner = [(x * 0.84, -0.02, 0.06 + z * 0.88) for x, _, z in pts]
    S.solidify(S.poly("tarcza_face", inner, face, m["tarcza_face"], holder), 0.02)
    # A painted red band down the shield and a small boss.
    S.box("tarcza_band", (0.12, 0.03, 0.56), (0.02, -0.04, 0.34), m["hussar_red"], holder)
    S.ball("tarcza_boss", 0.04, (0.02, -0.05, 0.36), m["iron"], holder, scale=(1.0, 0.6, 1.0))
    return holder


def _beret(f, m):
    """A wide flat beret worn tilted, a white ostrich feather lying over the brim."""
    b = S.cyl("beret", 0.21, 0.2, 0.05, (0, -0.01, 0.08), m["beret"], f.head, rot=(math.radians(-8), math.radians(10),
                                                                                       0), seg=16)
    S.ball("beret_crown", 0.13, (0, 0, 0.04), m["beret"], b, scale=(1.0, 1.0, 0.45))
    S.ball("beret_feather", 0.05, (0.12, -0.04, 0.08), m["feather"], b, scale=(0.7, 2.6, 0.8))


def _armet(f, m, mat, plume):
    """A round armet of about 1510: a rounded skull, a visor raised over the brow, cheek pieces,
    a plume on a socket at the back."""
    S.ball("armet", 0.152, (0, -0.005, 0.03), mat, f.head, scale=(1.0, 1.05, 1.05))
    S.cyl("armet_comb", 0.012, 0.012, 0.3, (0, -0.15, 0.1), mat, f.head, rot=(-math.pi / 2, 0, 0), seg=4)
    S.box("armet_cheeks", (0.27, 0.12, 0.14), (0, 0.06, -0.1), mat, f.head)
    S.box("face_open", (0.14, 0.05, 0.08), (0, 0.13, -0.01), m["skin"], f.head)
    S.cyl("armet_visor", 0.1, 0.06, 0.12, (0, 0.11, 0.1), mat, f.head, rot=(math.radians(-60), 0, 0), seg=8)
    S.cyl("bevor_neck", 0.15, 0.16, 0.12, (0, 0.0, -0.22), mat, f.head, seg=12)
    S.ball("plume", 0.07, (0, -0.1, 0.2), plume, f.head, scale=(0.7, 1.6, 1.0))
    S.ball("plume_tip", 0.05, (0, -0.2, 0.22), m["feather"], f.head, scale=(0.6, 1.4, 0.8))


def _white_eagle(name, parent, loc, size, m):
    """The crowned White Eagle (the Crown's arms) as a flat silhouette in the XZ plane."""
    white, gold = m["eagle_white"], m["gold"]
    h = S.empty(name, loc, parent)
    s = size
    S.box(f"{name}_body", (0.16 * s, 0.03, 0.34 * s), (0, 0, -0.02 * s), white, h)
    S.box(f"{name}_head", (0.1 * s, 0.03, 0.1 * s), (0.02 * s, 0, 0.22 * s), white, h)
    S.box(f"{name}_crown", (0.12 * s, 0.035, 0.06 * s), (0.02 * s, 0, 0.3 * s), gold, h)
    for x in (-1, 1):
        wing = [(x * 0.06 * s, 0, 0.12 * s), (x * 0.44 * s, 0, 0.3 * s), (x * 0.46 * s, 0, 0.06 * s),
                (x * 0.3 * s, 0, -0.12 * s), (x * 0.06 * s, 0, -0.08 * s)]
        S.solidify(S.poly(f"{name}_wing_{x}", wing, [(0, 1, 2, 3, 4)] if x > 0 else [(4, 3, 2, 1, 0)], white, h),
                   0.02)
        S.box(f"{name}_leg_{x}", (0.04 * s, 0.03, 0.14 * s), (x * 0.08 * s, 0, -0.24 * s), gold, h,
              rot=(0, x * math.radians(25), 0))
    S.solidify(S.poly(f"{name}_tail", [(-0.1 * s, 0, -0.18 * s), (0.1 * s, 0, -0.18 * s), (0.0, 0, -0.4 * s)],
                      [(0, 1, 2)], white, h), 0.02)
    return h


class Gunner(people.Figure):
    """A figure whose shot shows: a flash at the muzzle as it kicks and a puff of smoke that
    grows and hangs in front of him while he lowers the gun."""

    flash = None
    smoke: list = []

    def pose(self, anim, frame, frames):
        for o in [self.flash, *self.smoke]:
            if o is not None:
                o.scale = (0.001, 0.001, 0.001)
        super().pose(anim, frame, frames)
        if anim != "attack":
            return
        t = frame / frames
        if 0.3 <= t < 0.42 and self.flash is not None:
            self.flash.scale = (1.0, 1.0, 1.0)
        for k, o in enumerate(self.smoke):
            age = t - 0.3 - 0.06 * k
            if age > 0:
                s = min(1.0, age * 4.0) * (1.0 + 0.5 * k) * (1.0 - 0.35 * max(0.0, age - 0.35))
                o.scale = (s, s, s)


# --- the Crown -----------------------------------------------------------------------------

def pl_drab():
    m = _m()
    f = people.Figure("pl_drab")
    _foot_dress(f, m, m["drab_quilt"], m["drab_hose"])
    S.cyl("tesak", 0.016, 0.014, 0.55, (-0.24, 0.06, -0.45), m["steel"], f.hips, rot=(-0.3, 0, 0), seg=4,
          smooth=False)
    _spade_on_back(f, m)
    _pike(f, m)
    return f


def pl_handgunner():
    m = _m()
    f = Gunner("pl_handgunner")
    _foot_dress(f, m, m["gunner_quilt"], m["gunner_hose"])
    # The powder bag and the flask at the belt, the spare match coiled on the left hip.
    S.box("powder_bag", (0.08, 0.16, 0.18), (0.24, 0.06, -0.14), m["leather"], f.hips)
    S.cyl("flask", 0.045, 0.035, 0.14, (-0.23, 0.12, -0.2), S.mat("horn", "#8a7a5a", 0.6, noise=0.2), f.hips, seg=8)
    S.cyl("match_coil", 0.07, 0.07, 0.03, (-0.24, -0.04, -0.06), S.mat("rope", "#c9b98e", 1.0), f.hips,
          seg=10, rot=(math.pi / 2, 0, 0))
    # The hand-gun in both hands: a short iron barrel on a wooden tiller, the serpentine with
    # the glowing match by the breech.
    f.held_r = True
    f.held_l = True
    gun = S.empty("handgun", (0, 0, 0), f.j("hand_r"))
    gun.rotation_euler = (math.radians(-70), 0, math.radians(20))
    S.box("tiller", (0.06, 0.07, 0.55), (0, 0, 0.02), m["wood"], gun)
    S.cyl("barrel", 0.028, 0.024, 0.72, (0, 0.0, 0.26), m["iron"], gun, seg=8)
    S.cyl("muzzle", 0.034, 0.034, 0.04, (0, 0.0, 0.96), m["iron"], gun, seg=8)
    S.box("serpentine", (0.015, 0.08, 0.12), (0.04, -0.04, 0.24), m["iron"], gun, rot=(math.radians(30), 0, 0))
    S.ball("match_glow", 0.02, (0.04, -0.07, 0.3), m["match"], gun)
    f.flash = S.ball("flash", 0.11, (0, 0, 1.08), m["flash"], gun)
    f.smoke = [S.ball(f"smoke_{k}", 0.16, (0.04 * k, 1.35 + 0.18 * k, 1.42 + 0.05 * k), m["smoke"], f.root)
               for k in range(3)]
    for o in [f.flash, *f.smoke]:
        o.visible_shadow = False
    return f


def pl_hussar():
    m = _m()
    coat = m["hussar_red"]
    r = beasts._rider("rider", coat, m["trousers"], S.mat("boots_yellow", "#a07a2a", 0.8, noise=0.2), m,
                      m["dark_hair"], beard=False)
    S.ball("moustache", 0.05, (0, 0.11, -0.06), m["dark_hair"], r.head, scale=(1.6, 0.6, 0.5))
    _kaftan(r, m, coat, long=False, buttons=m["leather"])
    folk._belt(r, m["team"], r=0.255)
    # The tall cloth cap: a high crown, a fur band, a feather at the front.
    S.cyl("cap_crown", 0.13, 0.1, 0.28, (0, -0.01, 0.04), m["hussar_cap"], r.head, seg=12,
          rot=(math.radians(-8), 0, 0))
    S.cyl("cap_fur", 0.152, 0.148, 0.08, (0, -0.01, 0.02), m["fur"], r.head, seg=14)
    S.ball("cap_feather", 0.035, (0, 0.06, 0.26), m["feather"], r.head, scale=(0.6, 0.8, 2.4))
    spear = beasts._lance(r, m, length=3.8)
    _two_tailed_pennon(spear, 3.8, m["team"])
    _tarcza(r, m)
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("light_bay", "#86583a", 0.9, noise=0.25), small=True)
    return beasts.Mounted("pl_hussar", h, r, m["team"])


# --- heroes --------------------------------------------------------------------------------

def hero_swierczowski():
    m = _m()
    plate = m["black_plate"]
    r = beasts._rider("rider", m["doublet"], m["hose_white"], m["boots"], m, m["hair"])
    S.ball("short_beard", 0.08, (0, 0.08, -0.1), m["hair"], r.head, scale=(1.05, 0.8, 1.05))
    # Half armour: breast and back, pauldrons, plate arms and a short fauld; no leg plate.
    _plate_harness(r, m, mat=plate, faulds=2)
    S.cyl("backplate", 0.2, 0.235, 0.36, (0, -0.02, 0.08), plate, r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    for side in ("l", "r"):  # the red sleeves of the doublet show at the elbow
        S.ball(f"sleeve_puff_{side}", 0.075, (0, 0, -0.29), m["doublet"], r.j(f"shoulder_{side}"))
    r.skirt("doublet_skirt", -0.12, -0.3, 0.27, 0.31, m["doublet"])
    folk._belt(r, m["team"], r=0.258)
    S.box("sash_knot", (0.08, 0.04, 0.16), (0.15, 0.2, -0.06), m["team"], r.hips)
    _beret(r, m)
    _sword(r, m)
    S.cyl("scabbard", 0.02, 0.015, 0.8, (-0.24, -0.05, -0.75), m["leather"], r.hips, rot=(-0.3, 0, 0), seg=5)
    h = beasts.horse("horse", S.mat("bay", "#6e4428", 0.9, noise=0.25), size=1.04)
    _chaprak(h, m["court_red"], m["white_cloth"])
    return beasts.Mounted("hero_swierczowski", h, r, m["team"])


def hero_sampolinski():
    m = _m()
    r = beasts._rider("rider", m["plate"], m["plate"], m["plate"], m, m["fair_hair"], beard=False)
    _plate_harness(r, m)
    S.cyl("tabard", 0.2, 0.245, 0.24, (0, 0.0, 0.0), m["crimson"], r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    r.skirt("tabard_skirt", 0.06, -0.28, 0.25, 0.32, m["crimson"])
    r.skirt("tabard_hem", -0.25, -0.3, 0.32, 0.325, m["gold"])
    folk._belt(r, m["team"], r=0.25)
    _armet(r, m, m["plate"], m["court_red"])
    _banner(r, m, m["court_red"], lambda c: _white_eagle("banner_eagle", c, (0, -0.012, 0.03), 0.95, m),
            width=0.7, height=0.62, length=3.4)
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25), size=1.08)
    _chanfron(h, m["plate"])
    _chaprak(h, m["crimson"], m["eagle_white"])
    return beasts.Mounted("hero_sampolinski", h, r, m["team"])


def hero_chelyadnin():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["mo_red"], S.mat("boots_red", "#6a2a1e", 0.8, noise=0.2), m,
                      m["dark_hair"])
    r.skirt("mail_skirt", 0.06, -0.36, 0.24, 0.32, m["mail"])
    _bakhterets(r, m, rows=5, gilt=m["gold"])
    # The wide ferjaz: long, open at the front, falling over the horse's back, gold edging and
    # a gold collar; its long sleeves hang behind the shoulders.
    green = m["ferjaz_green"]
    S.cyl("ferjaz_back", 0.42, 0.28, 1.0, (0, -0.11, -0.5), green, r.chest, seg=12).scale = (1.0, 0.58, 1.0)
    r.skirt("ferjaz_skirt", 0.0, -0.6, 0.27, 0.42, green)
    r.skirt("ferjaz_hem", -0.56, -0.62, 0.42, 0.425, m["gold"])
    S.cyl("ferjaz_collar", 0.28, 0.2, 0.1, (0, -0.02, 0.43), m["gold"], r.chest, seg=12)
    for side, x in (("l", -1), ("r", 1)):
        S.box(f"hanging_sleeve_{side}", (0.1, 0.06, 0.6), (x * 0.3, -0.16, 0.1), green, r.chest,
              rot=(math.radians(10), 0, 0))
    for k in range(5):
        S.ball(f"loop_button_{k}", 0.018, (0, 0.21, 0.36 - k * 0.08), m["gold"], r.chest)
    folk._belt(r, m["team"], r=0.25)
    S.ball("full_beard", 0.1, (0, 0.08, -0.12), m["dark_hair"], r.head, scale=(1.15, 0.85, 1.4))
    _shishak(r, m, mat=m["steel"], rim=m["gold"])
    S.cyl("shishak_gilt_band", 0.12, 0.08, 0.06, (0, 0, 0.1), m["gold"], r.head, seg=12)
    _sabre_drawn(r, m)
    _scabbard(r, m)
    h = beasts.horse("horse", m["white_horse"], size=1.06, mane=S.mat("mane_light", "#e4e0d8", 1.0, noise=0.3))
    _chaprak(h, m["crimson"], m["gold"])
    return EasternMounted("hero_chelyadnin", h, r, m["team"])


def hero_bulgakov():
    m = _m()
    r = beasts._rider("rider", m["mail"], m["kaftan_blue"], S.mat("boots_green", "#3e5a3a", 0.8, noise=0.2), m,
                      m["greying_hair"])
    r.skirt("kaftan_skirt", 0.06, -0.42, 0.25, 0.34, m["kaftan_blue"])
    r.skirt("kaftan_hem", -0.38, -0.44, 0.34, 0.345, m["silver"])
    r.skirt("mail_skirt", 0.06, -0.2, 0.255, 0.3, m["mail"])
    # The kolontar: big steel plates in rows on breast and back, every other row gilt.
    for k in range(4):
        z = 0.06 + k * 0.1
        rad = 0.24 - 0.01 * k
        S.cyl(f"kolontar_{k}", rad, rad - 0.006, 0.085, (0, 0.0, z), m["gold"] if k % 2 else m["steel"], r.chest,
              seg=14).scale = (1.0, 0.82, 1.0)
    for side in ("l", "r"):
        S.limb(f"vambrace_{side}", 0.072, 0.062, 0.24, m["gold"], r.j(f"elbow_{side}"))
        S.ball(f"shoulder_plate_{side}", 0.1, (0, 0, -0.02), m["steel"], r.j(f"shoulder_{side}"),
               scale=(1.0, 1.0, 0.7))
    folk._belt(r, m["team"], r=0.26)
    S.ball("full_beard", 0.1, (0, 0.08, -0.12), m["greying_hair"], r.head, scale=(1.1, 0.85, 1.3))
    _shishak(r, m, mat=m["steel"], rim=m["silver"])
    # The yalovets: a small cloth pennon on the helmet's spike.
    S.solidify(S.poly("yalovets", [(0, -0.01, 0.4), (0, -0.2, 0.36), (0, -0.01, 0.3)], [(0, 1, 2)], m["team"],
                      r.head), 0.012)
    beasts._lance(r, m, length=3.6, pennon=m["team"])
    _sabre_hip(r, m)
    h = beasts.horse("horse", S.mat("dark_bay", "#4a3020", 0.9, noise=0.25), size=1.04)
    _chaprak(h, m["chaprak_blue"], m["silver"])
    return EasternMounted("hero_bulgakov", h, r, m["team"])


def hero_maciej():
    m = _m()
    f = people.Figure("hero_maciej")
    coat = m["scribe_coat"]
    f.body(m["skin"], m["scribe_zupan"], m["trousers"], m["boots"], sleeve=coat)
    f.hair(m["hair"], beard=False)
    S.ball("short_beard", 0.075, (0, 0.08, -0.1), m["hair"], f.head, scale=(1.0, 0.8, 0.9))
    # The long overcoat to the ankles, open over the żupan, a dark fur collar.
    folk._cloak(f, coat, bottom=-0.9, r_bottom=0.32)
    f.skirt("zupan_skirt", 0.06, -0.8, 0.22, 0.3, m["scribe_zupan"])
    S.cyl("coat_collar", 0.25, 0.18, 0.08, (0, -0.02, 0.44), m["fur"], f.chest, seg=12)
    folk._belt(f, m["team"], r=0.225)
    _neck_cross(f, m)
    # The soft scholar's cap with a quill stuck in it.
    S.ball("cap", 0.14, (0, -0.02, 0.06), m["beret"], f.head, scale=(1.05, 1.05, 0.7))
    S.cyl("cap_band", 0.14, 0.14, 0.04, (0, -0.01, 0.02), m["beret"], f.head, seg=14)
    S.cyl("quill", 0.008, 0.002, 0.24, (0.12, -0.06, 0.06), m["feather"], f.head, rot=(math.radians(-25),
                                                                                        math.radians(30), 0), seg=4)
    # The inkwell (an ink horn) and a pen case hanging at the belt.
    S.cyl("inkwell", 0.04, 0.035, 0.09, (0.21, 0.1, -0.14), m["ink"], f.hips, seg=8)
    S.cyl("inkwell_lid", 0.03, 0.02, 0.03, (0.21, 0.1, -0.05), m["gold"], f.hips, seg=8)
    S.cyl("pen_case", 0.02, 0.02, 0.24, (0.24, 0.02, -0.28), m["leather"], f.hips, rot=(0.15, 0, 0), seg=6)
    # The book in the left hand, held against him.
    f.held_l = True
    book = S.empty("book", (0, 0.04, -0.04), f.j("hand_l"))
    book.rotation_euler = (math.radians(-75), 0, 0)
    S.box("book_cover", (0.2, 0.06, 0.26), (0.02, 0.0, 0.06), m["book"], book)
    S.box("book_pages", (0.19, 0.065, 0.24), (0.025, 0.0, 0.06), m["paper"], book)
    S.box("book_clasp", (0.03, 0.07, 0.04), (0.12, 0.0, 0.06), m["gold"], book)
    return f


# --- map props -----------------------------------------------------------------------------

def _hull(name, parent, loc, rot, m, length=4.2, width=1.2, depth=0.5):
    """A flat-bottomed plank boat with raked ends (a punt), open on top; ribs and thwarts."""
    b = S.empty(name, loc, parent)
    b.rotation_euler = rot
    hl, hw = length / 2, width / 2
    bl, bw = hl - 0.55, hw - 0.12  # the bottom is shorter and narrower than the gunwale
    v = [(-bl, -bw, 0), (bl, -bw, 0), (bl, bw, 0), (-bl, bw, 0),
         (-hl, -hw, depth), (hl, -hw, depth), (hl, hw, depth), (-hl, hw, depth)]
    faces = [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    S.solidify(S.poly(f"{name}_shell", v, faces, m["plank"], b), 0.05)
    # Plank seams along the sides, the gunwale rails.
    for side in (-1, 1):
        for k, t in enumerate((0.35, 0.68)):
            z = depth * t
            y = side * (bw + (hw - bw) * t)
            S.box(f"{name}_seam_{side}_{k}", (2 * (bl + (hl - bl) * t), 0.02, 0.025), (0, y + side * 0.02, z),
                  m["logs_old"], b)
        S.box(f"{name}_gunwale_{side}", (length, 0.07, 0.06), (0, side * (hw + 0.01), depth), m["logs_old"], b)
    for k, x in enumerate((-0.9, 0.0, 0.9)):
        S.box(f"{name}_thwart_{k}", (0.22, width - 0.1, 0.05), (x, 0, depth - 0.12), m["plank"], b)
    return b


def prop_boats():
    m = kit.mats()
    root = S.empty("prop_boats")
    # One boat upright, its bow up the bank, oars and a pole laid in it.
    up = _hull("boat_up", root, (0.2, -0.4, 0.0), (0, math.radians(-4), math.radians(20)), m)
    for k, y in enumerate((-0.2, 0.15)):
        oar = S.empty(f"oar_{k}", (-0.3, y, 0.5), up)
        oar.rotation_euler = (0, math.radians(88), math.radians(6 - 10 * k))
        S.cyl(f"oar_loom_{k}", 0.025, 0.025, 2.4, (0, 0, -1.2), m["logs"], oar, seg=6)
        S.box(f"oar_blade_{k}", (0.03, 0.16, 0.5), (0, 0, 1.3), m["plank"], oar)
    S.cyl("pole", 0.03, 0.03, 4.4, (-2.2, 0.35, 0.42), m["logs_old"], up, rot=(0, math.radians(89), 0), seg=6)
    # The other turned keel up beside it, on two chocks.
    S.box("chock_0", (0.2, 1.2, 0.12), (-1.3, 1.25, 0.06), m["logs_old"], root, rot=(0, 0, math.radians(14)))
    S.box("chock_1", (0.2, 1.2, 0.12), (0.9, 1.75, 0.06), m["logs_old"], root, rot=(0, 0, math.radians(14)))
    _hull("boat_over", root, (-0.2, 1.5, 0.62), (math.pi, 0, math.radians(14)), m, length=3.8, width=1.1)
    kit.barrel("barrel", (1.9, -1.2, 0), m, root, r=0.26, h=0.7)
    S.cyl("rope_coil", 0.22, 0.22, 0.09, (-1.8, -1.1, 0), m["rope"], root, seg=12)
    return root


def prop_logs():
    m = kit.mats()
    root = S.empty("prop_logs")
    # The main stack of trimmed logs between two pairs of stakes.
    kit.log_pile("logs", (0.0, 0.0, 0), math.radians(10), 4.0, 10, m, root, r=0.15)
    for x in (-1.6, 1.6):
        for s in (-1, 1):
            at = (x * math.cos(math.radians(10)) - s * 0.7 * math.sin(math.radians(10)),
                  x * math.sin(math.radians(10)) + s * 0.7 * math.cos(math.radians(10)), 0)
            S.cyl(f"stake_{x}_{s}", 0.05, 0.04, 1.0, at, m["logs_old"], root, seg=6)
    # Planks for the deck, a short stack across two sleepers.
    deck = S.empty("planks", (0.6, -1.6, 0), root)
    deck.rotation_euler = (0, 0, math.radians(10))
    for x in (-1.0, 1.0):
        S.box(f"sleeper_{x}", (0.16, 0.9, 0.12), (x, 0, 0.06), m["logs_old"], deck)
    for k in range(4):
        S.box(f"plank_{k}", (2.8, 0.3, 0.05), (0.03 * k, 0.04 * (k % 2), 0.15 + 0.055 * k), m["plank"], deck,
              rot=(0, 0, math.radians(2 * (k % 2) - 1)))
    # A loose log with an axe in it, a rope coil.
    S.cyl("loose_log", 0.16, 0.15, 2.6, (-1.4, -1.5, 0.16), m["logs"], root,
          rot=(0, math.radians(90), math.radians(-30)), seg=8)
    axe = S.empty("axe", (-0.6, -1.95, 0.3), root)
    axe.rotation_euler = (math.radians(-35), 0, math.radians(-30))
    S.box("axe_head", (0.04, 0.16, 0.12), (0, 0, 0.0), m["iron"], axe)
    S.cyl("axe_haft", 0.018, 0.018, 0.6, (0, -0.04, 0.0), m["logs"], axe, seg=5)
    S.cyl("rope_coil", 0.24, 0.24, 0.1, (1.9, 0.9, 0), m["rope"], root, seg=12)
    return root


def _limb_to(name, parent, start, end, r0, r1, mat, seg=9):
    """A bough from `start` to `end` (world-like coordinates of `parent`), tapering r0 -> r1."""
    a, b = Vector(start), Vector(end)
    v = b - a
    rot = v.to_track_quat("Z", "Y").to_euler()
    return S.cyl(name, r0, r1, v.length, tuple(a), mat, parent, rot=tuple(rot), seg=seg)


def prop_oak():
    rng = random.Random(1514)
    bark = S.mat("oak_bark", "#4e4236", 0.95, noise=0.5)
    bark_dark = S.mat("oak_bark_dark", "#2e2620", 1.0, noise=0.3)
    dead = S.mat("dead_wood", "#8a8072", 0.95, noise=0.4)
    leaves = [S.mat("oak_leaves", "#3f5a2a", 0.9, noise=0.4), S.mat("oak_leaves_dark", "#33492a", 0.9, noise=0.4),
              S.mat("oak_leaves_autumn", "#5e6a30", 0.9, noise=0.45)]
    root = S.empty("prop_oak")
    # The trunk: thick, short, leaning a little, buttress roots spreading on the ground.
    trunk_h = 3.6
    S.cyl("trunk", 0.95, 0.72, trunk_h, (0, 0, 0), bark, root, seg=14)
    S.ball("trunk_burl", 0.55, (0.55, -0.45, 1.6), bark, root, scale=(0.8, 0.8, 1.2))
    S.ball("hollow", 0.32, (0.42, -0.72, 1.1), bark_dark, root, scale=(0.7, 0.4, 1.3))
    for k in range(7):
        a = k * math.tau / 7 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(1.6, 2.1)
        _limb_to(f"root_{k}", root, (0.6 * math.cos(a), 0.6 * math.sin(a), 0.5),
                 (rr * math.cos(a), rr * math.sin(a), -0.05), 0.42, 0.12, bark)
    # Heavy crooked limbs out of the top, each in two pieces, ending in the crown.
    top = (0.0, 0.0, trunk_h - 0.2)
    ends = []
    for k in range(6):
        a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
        mid = (2.0 * math.cos(a), 2.0 * math.sin(a), trunk_h + 1.6 + rng.uniform(-0.3, 0.4))
        end = (3.9 * math.cos(a + 0.2), 3.9 * math.sin(a + 0.2), trunk_h + 3.6 + rng.uniform(-0.6, 0.8))
        _limb_to(f"limb_{k}_a", root, top, mid, 0.42, 0.3, bark)
        _limb_to(f"limb_{k}_b", root, mid, end, 0.3, 0.12, bark)
        ends.append(end)
    _limb_to("leader", root, top, (0.3, 0.2, trunk_h + 5.2), 0.45, 0.18, bark)
    # One dead bough sticking out bare on the side toward the camera.
    _limb_to("dead_bough", root, (1.2, -1.2, trunk_h + 1.3), (3.4, -4.4, trunk_h + 2.6), 0.16, 0.04, dead, seg=6)
    _limb_to("dead_twig", root, (2.6, -3.4, trunk_h + 2.1), (2.6, -4.6, trunk_h + 3.4), 0.06, 0.02, dead, seg=5)
    # The crown: a wide low dome of clumps over the limbs, a few yellowing.
    for k, (x, y, z) in enumerate(ends):
        S.ball(f"crown_end_{k}", rng.uniform(1.5, 1.9), (x, y, z + 0.4), leaves[k % 2], root,
               scale=(1.0, 1.0, 0.7), seg=12)
    for k in range(22):
        a = rng.uniform(0, math.tau)
        d = math.sqrt(rng.uniform(0.0, 1.0)) * 4.0
        z = trunk_h + 4.6 + 1.3 * (1 - (d / 4.0) ** 2) + rng.uniform(-0.4, 0.4)
        mat = leaves[2] if rng.random() < 0.12 else leaves[rng.randrange(2)]
        S.ball(f"crown_{k}", rng.uniform(1.3, 1.9), (d * math.cos(a), d * math.sin(a), z), mat, root,
               scale=(1.0, 1.0, 0.72), seg=12)
    # Acorns and fallen leaves are too small to show at this scale; a few stones among the roots.
    for k in range(4):
        a = rng.uniform(0, math.tau)
        S.rock(f"stone_{k}", rng.uniform(0.15, 0.25), (2.3 * math.cos(a), 2.3 * math.sin(a), 0.05),
               S.mat("stone", "#7d776c", 0.9, noise=0.35), root, seed=k)
    return root


UNITS = {
    "pl_drab": pl_drab,
    "pl_handgunner": pl_handgunner,
    "hero_maciej": hero_maciej,
}
MOUNTED_UNITS = {
    "pl_hussar": pl_hussar,
    "hero_swierczowski": hero_swierczowski,
    "hero_sampolinski": hero_sampolinski,
    "hero_chelyadnin": hero_chelyadnin,
    "hero_bulgakov": hero_bulgakov,
}
PROPS = {"prop_boats": prop_boats, "prop_logs": prop_logs, "prop_oak": prop_oak}
## Props bigger than the usual 320x560 render frame: (width, height, pivot).
PROP_FRAMES = {"prop_oak": (840, 940, (300, 600))}
