"""Silver for Malbork («Корона 5. Серебро для Мальборка, 1457»: the Żuławy, autumn 1456 to
spring 1457), on the figure of people.py, the horse of beasts.py, the boat hull of
folk_1514.py and the pieces of folk_crown_chojnice.py (the war hammer), folk_crown_baltic.py
(the crossbow), folk_crown_malbork.py (the burgher's gown, the letter) and buildings_pl.py
(the Crown's flag) (visual assets doc, «Герои Короны и их противники», `pl_river_boat`,
`dock`; the mission card docs/03-missions/16-crown_05_silver_for_malbork_1457.md).
Family arms are not drawn.

Heroes:
- hero_barbara (template `lady`, on foot; idle and walk only): pani Barbara, Jaśko's
  granddaughter, about 25, a Gdańsk merchant's wife: a gown of good dark blue wool to the
  ground with fur at the hem, cuffs and collar, a married
  townswoman's white linen headdress (a padded roll under the linen, a veil down the back
  and a wimple under the chin), the counting book in her left hand, keys and a purse at a
  girdle in the player colour. No weapons.
- hero_czerwenka (`mounted`): Oldřich Červenka of Ledce, the Bohemian captain of the
  mercenaries in Malbork, «деловой, в доспехе без шлема»: bareheaded (short dark hair, a
  moustache), a breastplate with a short fauld and pauldrons over a doublet of dark wine-red
  velvet whose sleeves and skirt show, a gold chain, a war hammer (attack `swing`), a sword at
  the hip, a dark bay horse with a team saddle cloth and no caparison. No arms drawn.
- hero_k5_civil (`civilian`; idle and walk only): the Gdańsk councillor, an elderly rich
  burgher: a long dark gown to the ankles edged with fur down the front, a fur collar, a
  gold chain of office, a tall tapering hat in a deep fur brim, a grey beard, a slight stoop; a folded letter
  with a hanging red seal held out in his right hand.

The boat:
- pl_river_boat («Речная лодка с арбалетчиками»): a long flat-bottomed Vistula boat of
  planks (a szkuta-like river boat, 6.4 m) with raked ends, sitting in the water to its lower
  strakes (only the hull above the waterline is built, foam along it, so the sprite lies on
  the water tiles). Two rowers on the thwarts, each pulling a pair of
  oars, a steersman standing at the stern with the long steering oar, a crossbowman in the
  bow behind small pavises set along the gunwale (red with a white field and a team band),
  three iron-bound chests of silver and a barrel amidships, a team pennon on a short staff at
  the stern. Idle: it rocks at rest, the oars lifted. Walk: the stroke (oars dipped and swept
  back, the rowers leaning), the boat surging, a bow wave and a wake. Attack: the
  crossbowman shoots over the bow (`crossbow`).

The building:
- pl_dock («Пристань», 3×3): a timber landing: a plank quay on piles over a small basin of
  water cut into the right (+X, the river side) of the footprint, the pier running on out
  past its edge; a shingled store shed on posts with plank walls on the land side, a timber
  jib crane on the quay with a chest hanging from its rope, barrels, chests, sacks and a coil
  of rope, a punt moored at the pier, mooring posts, the Crown's flag.

The map prop:
- prop_piles: the stumps of the piles of the old broken bridge over the Nogat, standing out
  of the water: dark wet oak piles in two rows, some broken off short, one leaning, a cap
  beam still pinned across two of them, a broken plank and a tangle of driftwood caught
  against them, green slime at the waterline and pale foam rings round their feet. No
  ground is drawn: it sits on the water tiles. A bigger frame (`PROP_FRAMES`).

pl_merc_horse has no model: SpriteDB.ALIASES draws the Crown's hired horse as the Order's
to_merc_horse (Корона 4): the same mercenaries sold their swords to either side.
"""

import math
import random

from tools.art import beasts, folk, kit, people
from tools.art import shapes as S
from tools.art.buildings_pl import _m as _m_pl
from tools.art.buildings_pl import crown_flag
from tools.art.folk_1514 import _hull
from tools.art.folk_crown_1410 import _sword_hip
from tools.art.folk_crown_baltic import _crossbow, _sit
from tools.art.folk_crown_chojnice import _m as _m_k4
from tools.art.folk_crown_chojnice import _war_hammer
from tools.art.folk_crown_malbork import _burgher


def _m():
    m = _m_k4()
    m.update({
        "gown_wool": S.mat("barbara_gown", "#233047", 0.92, noise=0.12),
        "headdress": S.mat("linen_headdress", "#f1eee6", 0.9, noise=0.06),
        "keys": S.mat("keys_iron", "#6a6c6e", 0.4, metal=0.8),
        "wine": S.mat("wine_velvet", "#5a1a2c", 0.75, noise=0.1),
        "councillor": S.mat("councillor_gown", "#2a2836", 0.9, noise=0.1),
        "hat_dark": S.mat("tall_hat", "#1e1a1c", 0.9, noise=0.1),
        "dark_bay": S.mat("dark_bay", "#4a3020", 0.9, noise=0.25),
    })
    return m


def _boat_m():
    m = {**kit.mats(), **_m()}
    m.update({
        "hull": S.mat("boat_hull", "#6a5238", 0.85, noise=0.35),
        "tar": S.mat("boat_tar", "#2c241e", 0.7, noise=0.25),
        "chest": S.mat("silver_chest", "#4e3424", 0.8, noise=0.25),
        "pavise_red": S.mat("pavise_red", "#a82420", 0.85, noise=0.12),
        "foam": S.mat("foam", "#dfe8e8", 0.9, noise=0.4),
        "water": S.mat("dock_water", "#3e5a62", 0.25, noise=0.18),
        "wet": S.mat("wet_pile", "#352a22", 0.55, noise=0.4),
        "slime": S.mat("pile_slime", "#3e4a2c", 0.6, noise=0.5),
        "drift": S.mat("driftwood", "#7a6c5a", 0.95, noise=0.45),
    })
    return m


# --- heroes --------------------------------------------------------------------------------

def _headdress(f, m):
    """A married townswoman's linen headdress of the 1450s: a padded roll round the crown of the
    head under white linen, the veil falling down the back over the shoulders, a wimple under
    the chin."""
    white = m["headdress"]
    S.ball("coif", 0.14, (0, -0.045, 0.045), white, f.head, scale=(1.02, 0.98, 1.08))
    roll = S.cyl("roll", 0.145, 0.15, 0.09, (0, -0.03, 0.1), white, f.head, rot=(math.radians(-14), 0, 0), seg=14)
    roll.scale = (1.0, 0.95, 1.0)
    S.ball("roll_top", 0.13, (0, -0.05, 0.17), white, f.head, scale=(1.0, 0.95, 0.55))
    S.cyl("veil", 0.17, 0.2, 0.34, (0, -0.07, -0.3), white, f.head, seg=12).scale = (1.0, 0.75, 1.0)
    S.box("wimple_chin", (0.17, 0.06, 0.1), (0, 0.085, -0.105), white, f.head)
    S.cyl("wimple_neck", 0.1, 0.12, 0.14, (0, 0.0, 0.42), white, f.chest, seg=10)


def _ledger(f, m, side="l"):
    """The counting book held against the body."""
    if side == "l":
        f.held_l = True
    else:
        f.held_r = True
    book = S.empty("ledger", (0, 0.04, -0.04), f.j(f"hand_{side}"))
    book.rotation_euler = (math.radians(-75), 0, 0)
    S.box("ledger_cover", (0.22, 0.07, 0.28), (0.02, 0.0, 0.06), m["book"], book)
    S.box("ledger_pages", (0.21, 0.075, 0.26), (0.03, 0.0, 0.06), m["paper"], book)
    S.box("ledger_strap", (0.03, 0.08, 0.05), (0.13, 0.0, 0.06), m["leather"], book)
    return book


def hero_barbara():
    m = _m()
    f = people.Figure("hero_barbara")
    gown = m["gown_wool"]
    f.root.scale = (0.95, 0.95, 0.95)
    f.body(m["skin"], gown, gown, m["leather"], sleeve=gown)
    # A gown to the ground, its fur-lined hem turned out, fur at the cuffs.
    f.skirt("gown_skirt", 0.06, -0.9, 0.2, 0.36, gown)
    f.skirt("gown_hem", -0.84, -0.9, 0.36, 0.37, m["fur"])
    for side in ("l", "r"):
        S.cyl(f"cuff_{side}", 0.07, 0.075, 0.06, (0, 0, -0.25), m["fur"], f.j(f"elbow_{side}"), seg=8)
    # A fur collar over the shoulders.
    S.cyl("gown_collar", 0.25, 0.2, 0.08, (0, -0.03, 0.42), m["fur"], f.chest, seg=12).scale = (1.0, 0.85, 1.0)
    _headdress(f, m)
    # The girdle in the player colour, the keys and the purse hanging from it.
    folk._belt(f, m["team"], r=0.215)
    S.cyl("key_ring", 0.035, 0.035, 0.012, (0.19, 0.08, -0.06), m["keys"], f.hips, rot=(math.pi / 2, 0, 0), seg=10)
    for k in range(3):
        S.box(f"key_{k}", (0.014, 0.012, 0.11), (0.17 + 0.02 * k, 0.09, -0.13), m["keys"], f.hips,
              rot=(0, math.radians(-12 + 12 * k), 0))
    S.box("purse", (0.09, 0.05, 0.11), (-0.2, 0.08, -0.1), m["leather"], f.hips)
    S.box("purse_flap", (0.095, 0.055, 0.035), (-0.2, 0.08, -0.04), m["boots"], f.hips)
    _ledger(f, m, "l")
    return f


def hero_czerwenka():
    m = _m()
    r = beasts._rider("rider", m["wine"], m["hose_dark"], m["boots"], m, m["dark_hair"], beard=False)
    # Half armour: a breastplate with a ridge, two lames of fauld, pauldrons; the wine-red
    # velvet doublet shows at the arms and below the fauld.
    plate = m["plate"]
    S.cyl("breastplate", 0.2, 0.245, 0.38, (0, 0.012, 0.08), plate, r.chest, seg=12).scale = (1.0, 0.8, 1.0)
    S.box("breast_ridge", (0.03, 0.03, 0.3), (0, 0.2, 0.24), plate, r.chest, rot=(math.radians(-10), 0, 0))
    for k in range(2):
        r.skirt(f"fauld_{k}", 0.04 - 0.1 * k, -0.06 - 0.1 * k, 0.24 + 0.01 * k, 0.255 + 0.012 * k, plate)
    r.skirt("doublet_skirt", -0.12, -0.34, 0.26, 0.31, m["wine"])
    for side in ("l", "r"):
        S.ball(f"pauldron_{side}", 0.11, (0, 0, -0.02), plate, r.j(f"shoulder_{side}"), scale=(1.0, 1.0, 0.8))
        S.ball(f"puff_{side}", 0.085, (0, 0, -0.14), m["wine"], r.j(f"shoulder_{side}"), scale=(1.0, 1.0, 1.2))
    S.cyl("gold_chain", 0.21, 0.19, 0.025, (0, 0.035, 0.36), m["gold"], r.chest, rot=(math.radians(-12), 0, 0),
          seg=12).scale = (1.0, 0.85, 1.0)
    folk._belt(r, m["team"], r=0.26)
    # Bareheaded: short dark hair, a heavy moustache.
    S.box("moustache", (0.13, 0.03, 0.028), (0, 0.125, -0.045), m["dark_hair"], r.head)
    _war_hammer(r, m)
    _sword_hip(r, m)
    # A dark bay with a plain harness, no caparison: a hired captain, not a lord.
    h = beasts.horse("horse", m["dark_bay"], size=1.06)
    return beasts.Mounted("hero_czerwenka", h, r, m["team"])


def hero_k5_civil():
    m = _m()
    f = _burgher("hero_k5_civil", m, m["councillor"], m["grey_hair"])
    f.stoop = math.radians(6)
    f.skirt("gown_long", 0.06, -0.86, 0.22, 0.35, m["councillor"])
    # Fur down the open front of the gown and round the hem, a fur collar.
    f.skirt("fur_hem", -0.8, -0.86, 0.35, 0.36, m["fur"])
    S.cyl("fur_collar", 0.28, 0.2, 0.1, (0, -0.01, 0.43), m["fur"], f.chest, seg=12)
    S.cyl("office_chain", 0.21, 0.19, 0.025, (0, 0.04, 0.34), m["gold"], f.chest, rot=(math.radians(-14), 0, 0),
          seg=12).scale = (1.0, 0.85, 1.0)
    S.ball("chain_pendant", 0.035, (0, 0.2, 0.22), m["gold"], f.chest, scale=(1.0, 0.5, 1.0))
    # A tall hat of the 1450s: a high tapering crown with a rounded top in a deep fur brim.
    S.cyl("hat_brim", 0.17, 0.15, 0.11, (0, -0.01, 0.04), m["fur"], f.head, seg=14)
    S.cyl("hat_crown", 0.085, 0.125, 0.2, (0, -0.03, 0.12), m["hat_dark"], f.head, rot=(math.radians(-8), 0, 0),
          seg=12)
    S.ball("hat_top", 0.088, (0, -0.06, 0.31), m["hat_dark"], f.head, scale=(1.0, 1.0, 0.7))
    # The letter held out: a folded sheet with a hanging red seal.
    f.held_r = True
    let = S.empty("letter", (0, 0.05, -0.04), f.j("hand_r"))
    S.box("letter_sheet", (0.2, 0.02, 0.14), (0, 0.02, 0.02), m["paper"], let)
    S.cyl("letter_cord", 0.004, 0.004, 0.08, (0, 0.03, -0.09), m["seal"], let, seg=3)
    S.cyl("letter_seal", 0.032, 0.032, 0.014, (0, 0.03, -0.11), m["seal"], let, rot=(math.pi / 2, 0, 0), seg=10)
    return f


# --- the river boat ------------------------------------------------------------------------

def _boatman(name, m, coat, cap=True):
    f = people.Figure(name)
    f.body(m["skin"], coat, m["hose_brown"], m["boots"])
    f.hair(m["hair"])
    folk._legs_skirt(f, coat, -0.3, 0.28)
    if cap:
        S.ball("cap", 0.135, (0, -0.01, 0.06), m["knit"], f.head, scale=(1.0, 1.0, 0.75))
    folk._belt(f, m["leather"], r=0.23)
    return f


def _chest(name, loc, rot_z, m, parent, w=0.55, d=0.38, h=0.32):
    c = S.box(name, (w, d, h), loc, m["chest"], parent, rot=(0, 0, rot_z))
    for k, x in enumerate((-w * 0.3, w * 0.3)):
        S.box(f"{name}_band_{k}", (0.04, d + 0.02, h + 0.02), (x, 0, 0), m["black_iron"], c)
    S.box(f"{name}_lock", (0.07, 0.03, 0.08), (0, -d / 2 - 0.01, h * 0.15), m["iron"], c)
    return c


def _pavise_small(name, loc, side, m, parent):
    """A small pavise hung on the gunwale: red, a white field, a team band at the top."""
    p = S.empty(name, loc, parent)
    p.rotation_euler = (0, side * math.radians(8), 0)
    S.box(f"{name}_board", (0.05, 0.42, 0.62), (0, 0, 0.31), m["pavise_red"], p)
    S.box(f"{name}_field", (0.055, 0.2, 0.26), (0, 0, 0.3), m["eagle_white"], p)
    S.box(f"{name}_band", (0.056, 0.42, 0.07), (0, 0, 0.58), m["team"], p)
    return p


class RiverBoat:
    """The river boat with crossbowmen: a long punt in the water, two rowers with a pair of
    oars each, a steersman, a crossbowman behind pavises in the bow, chests of silver."""

    LENGTH, WIDTH, DEPTH = 6.4, 1.7, 0.55  # the hull above the waterline (z = 0)

    def __init__(self, name="pl_river_boat"):
        m = _boat_m()
        self.root = S.empty(name)
        # The hull rocks on a pivot at the waterline; its length runs along +Y (the bow). Only
        # the part above the water is built: its bottom is the waterline.
        self.hull = S.empty("hull", (0, 0, 0), self.root)
        h = self.hull
        _hull("boat", h, (0, 0, 0), (0, 0, math.pi / 2), m, length=self.LENGTH, width=self.WIDTH, depth=self.DEPTH)
        top = self.DEPTH
        hl, hw = self.LENGTH / 2, self.WIDTH / 2
        bl, bw = hl - 0.55, hw - 0.12  # the bottom outline (the waterline), as in _hull

        def side_at(t):  # half width and half length of the hull at height t * DEPTH
            return bw + (hw - bw) * t, bl + (hl - bl) * t

        # A tarred strake at the waterline, a team band under the gunwale.
        for s in (-1, 1):
            x, y = side_at(0.12)
            S.box(f"tar_strake_{s}", (0.03, 2 * y - 0.3, 0.1), (s * (x + 0.015), 0, 0.06), m["tar"], h)
            x, y = side_at(0.82)
            S.box(f"team_band_{s}", (0.03, 2 * y - 0.4, 0.06), (s * (x + 0.02), 0, top * 0.82), m["team"], h)
        # A plank floor inside.
        floor = 0.14
        S.box("floor_boards", (2 * bw - 0.2, 2 * bl - 0.3, 0.04), (0, 0, floor - 0.02), m["plank"], h)
        # Cargo amidships between the rowers: three iron-bound chests of silver; a barrel in the bow.
        _chest("chest_a", (-0.27, -0.15, floor + 0.16), 0.05, m, h)
        _chest("chest_b", (0.28, -0.12, floor + 0.16), -0.04, m, h)
        _chest("chest_c", (0.0, -0.15, floor + 0.46), 0.1, m, h, w=0.48, d=0.34, h=0.28)
        kit.barrel("barrel", (0.45, 1.4, floor), m, h, r=0.18, h=0.48)
        # Pavises along both gunwales at the bow and one across the stem.
        for s in (-1, 1):
            for k, y in enumerate((1.45, 2.0)):
                x, _ = side_at(1.0)
                _pavise_small(f"pavise_{s}_{k}", (s * (x - 0.03), y, top - 0.15), s, m, h)
        _pavise_small("pavise_bow", (0, 2.75, top - 0.1), 0, m, h).rotation_euler = (0, 0, math.pi / 2)
        # The team pennon on a short staff at the stern.
        staff = S.cyl("pennon_staff", 0.03, 0.025, 2.4, (-0.5, -2.7, floor), m["wood"], h, seg=6)
        S.solidify(S.poly("pennon", [(0, 0, 2.35), (0.0, -0.8, 2.2), (0, 0, 1.98)], [(0, 1, 2)], m["team"], staff),
                   0.02)
        # Two rowers on the thwarts facing the stern, each pulling a pair of oars.
        self.rowers, self.oars = [], []
        seat = top - 0.12 + 0.03
        for k, (y, coat) in enumerate(((0.9, m["hussite_jack"]), (-0.9, m["wool_dark"]))):
            row = _boatman(f"rower_{k}", m, coat)
            row.root.parent = h
            row.root.location = (0, y + 0.05, seat + 0.05 - people.HIP_Z)
            row.root.rotation_euler = (0, 0, math.pi)
            self.rowers.append(row)
            for s in (-1, 1):
                x, _ = side_at(1.0)
                lock = S.empty(f"oarlock_{k}_{s}", (s * (x + 0.02), y - 0.4, top + 0.03), h)
                S.box(f"thole_{k}_{s}", (0.04, 0.04, 0.14), (0, 0, 0.05), m["wood"], lock)
                arm = S.empty(f"oar_{k}_{s}", (0, 0, 0), lock)
                S.cyl(f"oar_loom_{k}_{s}", 0.026, 0.024, 2.8, (-s * 0.75, 0, 0), m["wood"], arm,
                      rot=(0, s * math.pi / 2, 0), seg=6)
                S.box(f"oar_blade_{k}_{s}", (0.55, 0.035, 0.16), (s * 1.8, 0, 0), m["plank"], arm)
                self.oars.append((arm, s))
        # The steersman at the stern with the long steering oar over the stern.
        st = _boatman("steersman", m, m["town_jack"], cap=False)
        S.cyl("hat", 0.15, 0.13, 0.1, (0, -0.01, 0.06), m["felt_hat"], st.head, seg=12)
        st.root.parent = h
        st.root.location = (0.1, -2.2, floor)
        st.held_l = True
        st.held_r = True
        self.steersman = st
        sweep = S.empty("sweep", (0.45, -2.85, top + 0.05), h)
        S.cyl("sweep_loom", 0.035, 0.03, 3.3, (0, 1.05, 0.38), m["wood"], sweep, rot=(math.radians(109), 0, 0), seg=6)
        S.box("sweep_blade", (0.04, 0.75, 0.24), (0, -1.6, -0.55), m["plank"], sweep, rot=(math.radians(19), 0, 0))
        self.sweep = sweep
        # The crossbowman standing in the bow.
        cb = people.Figure("crossbowman")
        cb.body(m["skin"], m["town_white"], m["town_hose"], m["boots"], sleeve=m["court_red"])
        cb.hair(m["fair_hair"], beard=False)
        folk._legs_skirt(cb, m["town_white"], -0.34, 0.29)
        folk._belt(cb, m["team"], r=0.24)
        folk._chapel(cb, m["iron"])
        _crossbow(cb, m)
        cb.attack_style = "crossbow"
        cb.root.parent = h
        cb.root.location = (-0.15, 1.95, floor)
        self.crossbowman = cb
        # Foam along the waterline; a bow wave and a wake while it moves.
        S.box("waterline_foam", (2 * bw + 0.16, 2 * bl + 0.2, 0.012), (0, 0, 0.004), m["foam"], self.root)
        self.wake = [
            S.box("bow_wave_l", (0.1, 1.1, 0.012), (-0.65, bl + 0.75, 0.006), m["foam"], self.root, rot=(0, 0, -0.5)),
            S.box("bow_wave_r", (0.1, 1.1, 0.012), (0.65, bl + 0.75, 0.006), m["foam"], self.root, rot=(0, 0, 0.5)),
            S.box("wake_l", (0.08, 1.5, 0.012), (-0.95, -bl - 0.8, 0.006), m["foam"], self.root, rot=(0, 0, 0.3)),
            S.box("wake_r", (0.08, 1.5, 0.012), (0.95, -bl - 0.8, 0.006), m["foam"], self.root, rot=(0, 0, -0.3)),
            S.box("wake_mid", (0.5, 1.2, 0.012), (0.0, -bl - 0.7, 0.006), m["foam"], self.root),
        ]

    def pose(self, anim, frame, frames):
        r = math.radians
        p = 2 * math.pi * frame / frames
        walk = anim == "walk"
        # The hull rocks gently; under way it surges with the stroke.
        self.hull.location.z = (0.02 if walk else 0.012) * math.sin(p)
        self.hull.rotation_euler = (r(1.0) * math.sin(p + 0.8) if walk else r(0.5) * math.sin(p),
                                    r(1.0) * math.sin(p + 1.7), 0)
        for o in self.wake:
            o.hide_render = not walk
        # Oars: under way a stroke (dip at the catch, sweep aft in the water, lift, swing
        # forward); at rest lifted clear of the water. Y tilts the blade end down, Z sweeps it.
        for arm, s in self.oars:
            if walk:
                sweep = r(30) * math.cos(p)
                tilt = r(19) if math.sin(p) > 0 else r(8)
            else:
                sweep, tilt = r(-8), r(7)
            arm.rotation_euler = (0, s * tilt, s * sweep)
        for row in self.rowers:
            row.pose("idle", frame, frames)
            _sit(row)
            pull = math.cos(p) if walk else 0.0  # 1 at the catch (reaching aft), -1 at the finish
            row.chest.rotation_euler = (r(4) + r(16) * pull, 0, 0)
            for side in ("l", "r"):
                row.j(f"shoulder_{side}").rotation_euler = (r(62) + r(20) * pull, r(14) * (1 if side == "l" else -1), 0)
                row.j(f"elbow_{side}").rotation_euler = (r(25) + r(35) * max(0.0, -pull), 0, 0)
        self.steersman.pose("idle", (frame + 2) % frames, frames)
        self.sweep.rotation_euler = (0, 0, r(5) * math.sin(p) if walk else 0.0)
        self.crossbowman.pose("attack" if anim == "attack" else "idle", frame, frames)


def pl_river_boat():
    return RiverBoat("pl_river_boat")


# --- the dock ------------------------------------------------------------------------------

def _pile(name, loc, h, m, parent, r=0.12, tilt=(0.0, 0.0), mat=None):
    return S.cyl(name, r, r * 0.9, h, loc, mat or m["logs_old"], parent, rot=(tilt[0], tilt[1], 0), seg=8)


def pl_dock():
    rng = random.Random(1457)
    m = {**_m_pl(), **_boat_m()}
    root = S.empty("pl_dock")
    # Trodden ground on the land side (left two thirds), the water of the basin on the right.
    S.box("yard", (4.0, 6.3, 0.04), (-1.15, 0, 0.02), S.mat("trodden_mud", "#6c6040", 1.0, noise=0.35), root)
    S.box("yard_water", (2.55, 6.3, 0.03), (1.88, 0, 0.012), m["water"], root)
    # The timber revetment along the basin's edge: a sill beam on a row of piles.
    S.box("quay_sill", (0.2, 6.2, 0.22), (0.6, 0, 0.11), m["logs_old"], root)
    for k in range(9):
        _pile(f"quay_pile_{k}", (0.68, -2.9 + k * 0.72, 0), 0.38, m, root, r=0.09)
    # The pier on piles running out over the basin and past the footprint.
    deck_z = 0.62
    x0, x1, py = 0.5, 3.9, -0.55
    for k, x in enumerate((1.0, 1.8, 2.6, 3.4)):
        for s in (-1, 1):
            _pile(f"pier_pile_{k}_{s}", (x, py + s * 0.62, 0), deck_z + (0.32 if x > 3 else 0.0), m, root, r=0.1,
                  mat=m["wet"] if k > 0 else None)
        S.box(f"pier_cap_{k}", (0.16, 1.45, 0.12), (x, py, deck_z - 0.06), m["logs_old"], root)
    for k in range(14):
        x = x0 + (k + 0.5) * (x1 - x0) / 14
        S.box(f"pier_plank_{k}", ((x1 - x0) / 14 - 0.02, 1.5, 0.05), (x, py, deck_z + 0.025), m["plank"], root,
              rot=(0, 0, rng.uniform(-0.02, 0.02)))
    # The ramp up onto the pier from the yard.
    S.box("pier_ramp", (0.9, 1.4, 0.05), (0.05, py, deck_z / 2), m["plank"], root, rot=(0, -math.atan2(deck_z, 0.9), 0))
    # A punt moored along the pier's left side, a rope to a post.
    _hull("moored_boat", root, (1.9, py + 1.45, 0.0), (0, 0, 0.03), m, length=2.4, width=0.95, depth=0.36)
    S.cyl("mooring_rope", 0.012, 0.012, 0.9, (1.45, py + 1.4, 0.32), m["rope"], root,
          rot=(0, math.pi / 2, math.radians(-30)), seg=3)
    # The jib crane on the quay: a post, a brace, a beam swung out over the water, a rope and
    # a chest on the hook.
    cx, cy = 0.35, 1.2
    S.cyl("crane_post", 0.13, 0.12, 3.1, (cx, cy, 0), m["logs"], root, seg=8)
    S.box("crane_base_a", (1.1, 0.18, 0.18), (cx, cy, 0.09), m["logs_old"], root)
    S.box("crane_base_b", (0.18, 1.1, 0.18), (cx, cy, 0.09), m["logs_old"], root)
    S.box("crane_jib", (2.3, 0.14, 0.16), (cx + 0.95, cy, 3.0), m["logs"], root, rot=(0, math.radians(-6), 0))
    S.box("crane_brace", (1.35, 0.1, 0.1), (cx + 0.5, cy, 2.45), m["logs"], root, rot=(0, math.radians(-42), 0))
    S.cyl("crane_rope", 0.012, 0.012, 1.55, (cx + 1.95, cy, 1.55), m["rope"], root, seg=3)
    S.cyl("crane_drum", 0.12, 0.12, 0.3, (cx - 0.15, cy, 1.0), m["logs_old"], root, rot=(math.pi / 2, 0, 0), seg=8)
    _chest("crane_chest", (cx + 1.95, cy, 1.35), 0.2, m, root, w=0.5, d=0.34, h=0.3)
    # The store shed on the land side: plank walls under a shingled roof, the door to the front.
    sx, sy, sw, sd, sh = -1.85, 1.3, 2.2, 2.4, 1.7
    S.box("shed_floor", (sw + 0.15, sd + 0.15, 0.2), (sx, sy, 0.1), m["stone"], root)
    for k in range(3):
        S.box(f"shed_walls_{k}", (sw, sd, sh / 3 + 0.002), (sx, sy, 0.2 + sh / 3 * (k + 0.5)),
              m["plank"] if k % 2 == 0 else m["logs"], root)
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        S.box(f"shed_corner_{i}", (0.14, 0.14, sh), (sx + x * sw / 2, sy + y * sd / 2, 0.2 + sh / 2), m["timber"],
              root)
    kit.window("shed_door", 0.9, 1.4, (sx + 0.2, sy - sd / 2 - 0.03, 0.2), 0.0, m["door"], root)
    kit.window("shed_hatch", 0.5, 0.45, (sx + sw / 2 + 0.03, sy + 0.2, 1.1), math.pi / 2, m["dark"], root)
    kit.gable_roof("shed_roof", sw, sd, 0.95, 0.25, 0.2 + sh, m["shingle"], root, along_y=True)
    S.box("shed_band", (sw + 0.02, 0.04, 0.1), (sx, sy - sd / 2 - 0.02, 0.2 + sh - 0.1), m["team"], root)
    # Goods on the quay: barrels, chests, sacks, a coil of rope, a cart's worth of silver.
    for k, (x, y) in enumerate(((-0.35, -1.6), (-0.85, -1.85), (-0.55, -2.4))):
        kit.barrel(f"barrel_{k}", (x, y, 0), m, root, r=0.25, h=0.68)
    _chest("chest_a", (-0.65, 0.3, 0.16), 0.1, m, root)
    _chest("chest_b", (-1.6, -1.55, 0.16), -0.15, m, root)
    _chest("chest_c", (-1.6, -1.5, 0.48), 0.05, m, root, w=0.48, d=0.33, h=0.28)
    for k, (x, y) in enumerate(((-2.4, -1.4), (-2.6, -1.95), (-2.15, -2.1))):
        kit.sack(f"sack_{k}", (x, y, 0), m, root)
    S.cyl("rope_coil", 0.24, 0.24, 0.1, (0.15, -2.3, 0.0), m["rope"], root, seg=12)
    for k, y in enumerate((-2.55, 2.55)):  # mooring posts on the quay edge
        _pile(f"mooring_post_{k}", (0.45, y, 0), 0.9, m, root, r=0.11)
    crown_flag(root, (-2.7, -0.75, 0), 3.6, m)
    return root


# --- the map prop --------------------------------------------------------------------------

def prop_piles():
    """The stumps of the old bridge's piles in the water: two rows of dark wet oak piles, some
    broken short, one leaning, a cap beam pinned across two, a broken plank and driftwood
    caught against them, slime at the waterline, foam round their feet."""
    rng = random.Random(1456)
    m = _boat_m()
    root = S.empty("prop_piles")
    heights = {(0, 0): 1.25, (0, 1): 1.2, (0, 2): 0.5, (0, 3): 1.5, (1, 0): 0.85, (1, 1): 0.4, (1, 3): 0.65}
    for row, x in enumerate((-0.45, 0.45)):
        for k, y in enumerate((-1.1, -0.35, 0.4, 1.15)):
            if (row, k) not in heights:
                continue  # one gone altogether
            h = heights[(row, k)]
            tilt = (rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05))
            if (row, k) == (0, 3):
                tilt = (math.radians(-18), math.radians(10))  # leaning over
            loc = (x + rng.uniform(-0.06, 0.06), y + rng.uniform(-0.06, 0.06), -0.1)
            if (row, k) in ((0, 0), (0, 1)):
                loc = (x, y, -0.1)  # these two still carry the cap beam
            p = _pile(f"pile_{row}_{k}", loc, h + 0.1, m, root, r=rng.uniform(0.12, 0.16), tilt=tilt, mat=m["wet"])
            S.cyl(f"pile_slime_{row}_{k}", 0.17, 0.17, 0.22, (0, 0, 0.0), m["slime"], p, seg=8).scale = (0.95, 0.95, 1)
            # A broken, splintered top.
            S.cyl(f"pile_top_{row}_{k}", 0.1, 0.02, 0.14, (0.02, 0.01, h + 0.1), m["drift"], p,
                  rot=(rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0), seg=5, smooth=False)
            S.cyl(f"foam_{row}_{k}", 0.21, 0.21, 0.01, (loc[0], loc[1], 0.004), m["foam"], root, seg=12)
    # The cap beam still pinned across the two tallest piles of the first row.
    S.box("cap_beam", (0.22, 1.1, 0.2), (-0.45, -0.72, 1.2), m["wet"], root, rot=(math.radians(8), 0, 0.05))
    S.cyl("cap_peg", 0.03, 0.03, 0.3, (-0.45, -0.35, 1.15), m["drift"], root, seg=5)
    # A broken plank hanging off it into the water, and a stringer lying slantwise.
    S.box("hanging_plank", (0.3, 0.05, 1.2), (-0.62, -1.18, 0.62), m["drift"], root,
          rot=(math.radians(10), math.radians(-28), 0))
    S.box("stringer", (0.18, 2.2, 0.16), (0.5, -0.2, 0.3), m["wet"], root,
          rot=(math.radians(12), math.radians(6), 0.18))
    # Driftwood and branches caught against the piles.
    for k in range(6):
        a = rng.uniform(0, math.tau)
        S.cyl(f"drift_{k}", 0.04, 0.025, rng.uniform(0.6, 1.2),
              (0.0 + rng.uniform(-0.2, 0.6), 0.4 + rng.uniform(-0.3, 0.6), 0.03), m["drift"], root,
              rot=(math.pi / 2 - 0.08, 0, a), seg=5)
    S.box("debris_mat", (0.7, 0.45, 0.05), (0.05, 0.85, 0.02), S.mat("debris", "#5a5038", 1.0, noise=0.6), root,
          rot=(0, 0, 0.4))
    return root


UNITS = {"hero_barbara": hero_barbara, "hero_k5_civil": hero_k5_civil}
MOUNTED_UNITS = {"hero_czerwenka": hero_czerwenka}
BOATS = {"pl_river_boat": pl_river_boat}
BUILDINGS = {"pl_dock": (pl_dock, (3, 3), 6)}
PROPS = {"prop_piles": prop_piles}
## The piles are spread over about 3 by 3 m (the default prop frame holds one cell).
PROP_FRAMES = {"prop_piles": (440, 440, (220, 280))}
