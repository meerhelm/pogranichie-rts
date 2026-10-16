"""Buildings of the Teutonic Order (visual assets doc, «Общие здания» and «Особые здания»):
red brick of the Backsteingotik with stepped gables and white blind niches, roof tiles; the
colonists' houses and barns are half-timbered under high thatch.

- to_town_center: «Орденский двор», a brick farmyard with a stepped-gable hall, tiles.
- to_house: a colonist's house, half-timbered, high thatch roof.
- to_granary: a half-timbered granary.
- to_farm: a ploughed field in straight furrows.
- to_lumber_yard: a shed under tiles, stacks of logs, trestles.
- to_mine: the bloomery with a brick furnace.
- to_barracks: «Кнехтский дом», brick and tiles; spears and pavises by the wall.
- to_range: the shooting ground with crossbows and a brick shed.
- to_stable: «Конный завод», long brick stables round a yard, a fenced paddock.
- to_shrine: a small brick Gothic chapel.
- to_tower: a brick tower; to_market: «Ганзейская контора», a brick warehouse with a
  stepped gable, a hoist beam, barrels, cloth and scales; to_smithy: a brick smithy;
  to_temple: «Конвентская церковь», brick Gothic; to_castle: «Комтурский замок», a square
  brick convent round a court; to_brickworks: a kiln, drying sheds, stacks of bricks, a
  clay pit; to_siege_workshop, to_palisade, to_gate: as the Duchy's, under tiles.
"""

import math
import random

from tools.art import buildings_gdl, kit
from tools.art import shapes as S


def _hall(prefix, w, d, h, m, parent, loc=(0, 0, 0), roof_h=None, gables=(True, True), door_x=0.0,
          windows=(), east=(), pointed=False):
    """Brick hall: walls, a tile roof with the ridge along X, stepped gables at the X ends."""
    hall = S.empty(prefix, loc, parent)
    roof_h = roof_h if roof_h is not None else d * 0.85
    S.box(f"{prefix}_walls", (w, d, h), (0, 0, h / 2), m["brick"], hall)
    S.box(f"{prefix}_plinth", (w + 0.1, d + 0.1, 0.35), (0, 0, 0.17), m["brick_dark"], hall)
    kit.gable_roof(f"{prefix}_roof", w, d, roof_h, 0.12, h, m["tile"], hall)
    for x, on in ((-w / 2, gables[0]), (w / 2, gables[1])):
        if on:
            kit.stepped_gable(f"{prefix}_sg_{x:.1f}", d + 0.2, roof_h + 0.5, (x, 0, h), math.pi / 2, m, hall)
        else:
            kit.gable_wall(f"{prefix}_gw_{x:.1f}", d, roof_h, (x, 0, h), math.pi / 2, m["brick"], hall, thick=0.2)
    kit.front_openings(prefix, w, d, 0.3, m, hall, door_x=door_x, windows=windows, east=east, pointed=pointed)
    return hall


def _brick_wall(prefix, pts, h, m, parent, gap=None):
    """A low brick wall along a polyline; `gap` (x0, x1) leaves a gate opening on the first leg."""
    for i, ((x0, y0), (x1, y1)) in enumerate(zip(pts, pts[1:])):
        segs = [((x0, y0), (x1, y1))]
        if i == 0 and gap is not None:
            segs = [((x0, y0), (gap[0], y0)), ((gap[1], y0), (x1, y1))]
        for k, ((a0, b0), (a1, b1)) in enumerate(segs):
            length = math.hypot(a1 - a0, b1 - b0)
            ang = math.atan2(b1 - b0, a1 - a0)
            S.box(f"{prefix}_{i}_{k}", (length + 0.35, 0.35, h), ((a0 + a1) / 2, (b0 + b1) / 2, h / 2), m["brick"],
                  parent, rot=(0, 0, ang))
            S.box(f"{prefix}_{i}_{k}_cap", (length + 0.45, 0.45, 0.12), ((a0 + a1) / 2, (b0 + b1) / 2, h + 0.06),
                  m["tile"], parent, rot=(0, 0, ang))


def _pavise(name, loc, rot_z, m, parent):
    """A big standing shield (павеза) leaning on a wall: the Order's white with a black cross."""
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = (0.28, 0, rot_z)
    white = S.mat("order_white", "#ecebe4", 0.9)
    black = S.mat("order_black", "#151515", 0.9)
    S.box(f"{name}_board", (0.62, 0.08, 1.15), (0, 0, 0.58), white, holder)
    S.box(f"{name}_ridge", (0.14, 0.12, 1.15), (0, -0.04, 0.58), m["team"], holder)
    S.box(f"{name}_cross_v", (0.08, 0.13, 0.45), (0, -0.05, 0.75), black, holder)
    S.box(f"{name}_cross_h", (0.4, 0.13, 0.08), (0, -0.05, 0.8), black, holder)
    return holder


def to_town_center():
    m = kit.mats()
    root = S.empty("to_town_center")
    kit.yard(4.0, 4.0, S.mat("cobble", "#77705f", 1.0, noise=0.5)).parent = root
    _brick_wall("wall", [(-3.85, -3.85), (3.85, -3.85), (3.85, 3.85), (-3.85, 3.85), (-3.85, -3.85)], 1.5, m,
                root, gap=(-0.8, 0.8))
    for x in (-0.95, 0.95):
        S.box(f"gate_pier_{x}", (0.5, 0.5, 2.4), (x, -3.85, 1.2), m["brick"], root)
    S.box("gate_arch", (2.4, 0.5, 0.5), (0, -3.85, 2.55), m["brick"], root)
    kit.gable_roof("gate_roof", 2.5, 0.7, 0.5, 0.1, 2.8, m["tile"], root)
    _hall("hall", 5.4, 3.2, 3.8, m, root, loc=(0.7, 1.6, 0), door_x=-0.6,
          windows=[(-1.9, 1.6), (0.8, 1.6), (1.9, 1.6), (-1.9, 2.8), (0.8, 2.8)], east=[(0.0, 2.6)])
    barn = S.empty("barn", (-2.4, -1.3, 0), root)
    kit.fachwerk("barn_fw", 2.2, 3.0, 2.2, 0.0, m, barn)
    kit.gable_roof("barn_roof", 2.2, 3.0, 2.0, 0.35, 2.2, m["thatch"], barn, along_y=True, thick=0.14)
    for y in (-1.5, 1.5):
        kit.gable_wall(f"barn_gable_{y}", 2.2, 2.0, (0, y, 2.2), 0.0, m["plaster"], barn)
    kit.window("barn_door", 1.0, 1.6, (1.13, -0.3, 0.0), math.pi / 2, m["door"], barn)
    S.cyl("well", 0.45, 0.45, 0.7, (2.4, -2.2, 0), m["brick"], root, seg=12)
    S.cyl("well_water", 0.36, 0.36, 0.02, (2.4, -2.2, 0.65), m["dark"], root, seg=10)
    kit.cross_flag(root, (3.5, 3.5, 0), 6.5, m)
    return root


def to_house():
    m = kit.mats()
    root = S.empty("to_house")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    house = S.empty("house", (0.1, 0.3, 0), root)
    kit.fachwerk("fw", 3.0, 2.4, 2.1, 0.0, m, house)
    kit.gable_roof("roof", 3.0, 2.4, 2.4, 0.4, 2.1, m["thatch"], house, thick=0.16)
    for x in (-1.5, 1.5):
        kit.gable_wall(f"gable_{x}", 2.4, 2.35, (x, 0, 2.1), math.pi / 2, m["plaster"], house)
    kit.front_openings("house", 3.0, 2.4, 0.0, m, house, door_x=0.5, windows=[(-0.7, 1.0)], east=[(0.0, 1.0)])
    kit.wattle("garden", [(-1.9, -1.9), (0.3, -1.9)], m, root, h=0.7)
    kit.barrel("barrel", (1.5, -1.4, 0), m, root)
    kit.flag(root, (1.8, 1.8, 0), 3.0, m)
    return root


def to_granary():
    m = kit.mats()
    root = S.empty("to_granary")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    g = S.empty("granary", (0, 0.2, 0), root)
    S.box("footing", (3.1, 2.5, 0.45), (0, 0, 0.22), m["stone"], g)
    kit.fachwerk("fw", 3.0, 2.4, 2.3, 0.45, m, g)
    kit.gable_roof("roof", 3.0, 2.4, 1.6, 0.3, 2.75, m["tile"], g)
    for x in (-1.5, 1.5):
        kit.gable_wall(f"gable_{x}", 2.4, 1.55, (x, 0, 2.75), math.pi / 2, m["plank"], g)
    kit.window("door", 0.9, 1.4, (0.3, -1.24, 0.45), 0.0, m["door"], g)
    kit.window("hatch", 0.6, 0.6, (1.54, 0.0, 3.1), math.pi / 2, m["dark"], g)
    S.box("hoist", (0.9, 0.12, 0.12), (1.9, 0.2, 4.1), m["timber"], root)
    for i, (x, y) in enumerate([(-0.9, -1.6), (-0.5, -1.7), (-0.7, -1.35), (1.5, -1.6)]):
        kit.sack(f"sack_{i}", (x, y, 0), m, root)
    S.box("sack_band", (0.3, 0.05, 0.06), (-0.9, -1.81, 0.32), m["team"], root)
    kit.cross_flag(root, (-1.7, 1.7, 0), 3.6, m)
    return root


def to_farm():
    rng = random.Random(9)
    m = kit.mats()
    root = S.empty("to_farm")
    S.box("yard", (5.9, 5.9, 0.04), (0, 0, 0.02), m["soil"])
    stalk = S.mat("wheat_stalk", "#7f8a3a", 1.0, noise=0.4)
    for i in range(10):
        y = -2.55 + i * 0.56
        S.box(f"ridge_{i}", (5.4, 0.3, 0.12), (0, y, 0.06), stalk, root)
        for k in range(18):
            x = -2.5 + k * 0.29 + rng.uniform(-0.04, 0.04)
            S.cyl(f"wheat_{i}_{k}", 0.1, 0.14, rng.uniform(0.4, 0.5), (x, y, 0.05), m["grain"], root, seg=6)
    plough = S.empty("plough", (2.3, -2.75, 0.1), root)
    S.cyl("plough_beam", 0.05, 0.05, 1.6, (0, 0, 0.3), m["logs_old"], plough, rot=(0, math.pi / 2 - 0.25, 2.4), seg=6)
    S.box("plough_share", (0.35, 0.12, 0.08), (0, 0, 0.05), m["iron"], plough)
    st = S.cyl("mark_stake", 0.04, 0.035, 1.3, (-2.8, -2.8, 0), m["logs"], root, seg=5)
    S.box("mark_rag", (0.3, 0.03, 0.22), (0.15, 0, 1.12), m["team"], st)
    return root


def to_lumber_yard():
    m = kit.mats()
    root = S.empty("to_lumber_yard")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    kit.posts_shed("shed", 3.2, 1.5, 2.1, m["tile"], root, (0, 0.95, 0), m, posts_mat=m["timber"])
    kit.log_pile("logs_a", (0.0, 1.0, 0), 0.0, 2.8, 9, m, root)
    S.box("boards", (1.8, 0.9, 0.35), (-1.0, -0.9, 0.18), m["plank"], root)
    for x in (0.5, 1.4):
        for s in (-1, 1):
            S.box(f"trestle_{x}_{s}", (0.08, 0.08, 1.0), (x, -1.0 + s * 0.15, 0.45), m["timber"], root,
                  rot=(s * 0.35, 0, 0))
    S.cyl("sawlog", 0.15, 0.15, 1.8, (0.05, -1.0, 0.95), m["logs"], root, rot=(0, math.pi / 2, 0), seg=8)
    S.box("saw", (1.1, 0.02, 0.18), (0.95, -1.0, 1.25), m["iron"], root, rot=(0, 0.2, 0))
    kit.cross_flag(root, (-1.75, 1.75, 0), 3.4, m)
    return root


def to_mine():
    m = kit.mats()
    root = S.empty("to_mine")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    furnace = S.empty("furnace", (0.4, 0.3, 0), root)
    S.box("furnace_body", (1.4, 1.4, 1.9), (0, 0, 0.95), m["brick"], furnace)
    S.box("furnace_chimney", (0.7, 0.7, 1.1), (0, 0, 2.45), m["brick_dark"], furnace)
    kit.window("furnace_mouth", 0.5, 0.55, (0, -0.73, 0.15), 0.0, m["fire"], furnace, pointed=True)
    S.box("bellows", (0.6, 0.4, 0.2), (-1.0, -0.2, 0.5), S.mat("leather", "#5a3e28", 0.8), root, rot=(0, 0, 0.3))
    kit.posts_shed("shed", 1.6, 1.2, 1.8, m["tile"], root, (-1.1, 1.3, 0), m, posts_mat=m["timber"])
    ore = S.mat("bog_ore", "#7a3f1e", 0.95, noise=0.5)
    wicker = S.mat("wicker", "#8e7346", 1.0, noise=0.6)
    for i, (x, y) in enumerate([(1.4, -1.1), (0.8, -1.6)]):
        S.cyl(f"basket_{i}", 0.26, 0.3, 0.42, (x, y, 0), wicker, root, seg=10)
        for k in range(4):
            S.rock(f"basket_ore_{i}_{k}", 0.1, (x + 0.1 * math.cos(k * 1.7), y + 0.1 * math.sin(k * 1.7), 0.44), ore,
                   root, seed=i * 9 + k)
    S.cyl("charcoal_heap", 0.7, 0.05, 0.55, (-1.1, -1.1, 0), m["charcoal"], root, seg=9, smooth=False)
    S.box("ore_band", (0.35, 0.05, 0.08), (1.4, -1.4, 0.3), m["team"], root)
    kit.cross_flag(root, (1.8, 1.8, 0), 3.6, m)
    return root


def to_barracks():
    m = kit.mats()
    root = S.empty("to_barracks")
    kit.yard(3.0, 3.0, S.mat("cobble", "#77705f", 1.0, noise=0.5)).parent = root
    _hall("hall", 5.2, 3.0, 4.0, m, root, loc=(0.0, 1.1, 0), door_x=0.8,
          windows=[(-1.6, 1.5), (-0.4, 1.5), (1.9, 1.5), (-1.6, 2.9), (-0.4, 2.9), (0.8, 2.9), (1.9, 2.9)],
          east=[(-0.6, 2.6), (0.6, 2.6)])
    buildings_gdl._spear_rack("rack", (-1.4, -1.0, 0), 0.0, m, root)
    for i in range(3):
        _pavise(f"pavise_{i}", (1.4 + i * 0.7, -0.75, 0), 0.0, m, root)
    S.cyl("pell", 0.12, 0.11, 1.5, (-2.3, -2.3, 0), m["logs_old"], root, seg=7)
    kit.cross_flag(root, (2.7, -2.6, 0), 4.5, m)
    return root


def to_range():
    m = kit.mats()
    root = S.empty("to_range")
    kit.yard(3.0, 3.0, S.mat("meadow", "#6e7a45", 1.0, noise=0.3)).parent = root
    _hall("shed", 2.6, 2.0, 2.4, m, root, loc=(1.5, 1.8, 0), roof_h=1.4, gables=(False, True), door_x=0.3,
          windows=[], east=[])
    rack = S.empty("rack", (1.2, 0.3, 0), root)
    for x in (-0.9, 0.9):
        S.cyl(f"rack_post_{x}", 0.05, 0.05, 1.2, (x, 0, 0), m["timber"], rack, seg=5)
    S.cyl("rack_bar", 0.04, 0.04, 2.0, (-1.0, 0, 1.1), m["timber"], rack, rot=(0, math.pi / 2, 0), seg=5)
    stock = S.mat("crossbow", "#6b4a2c", 0.7)
    for i in range(4):
        cb = S.empty(f"crossbow_{i}", (-0.6 + i * 0.4, -0.12, 0.25), rack)
        cb.rotation_euler = (-0.15, 0, 0)
        S.box(f"cb_stock_{i}", (0.06, 0.06, 0.85), (0, 0, 0.42), stock, cb)
        S.box(f"cb_bow_{i}", (0.65, 0.05, 0.05), (0, 0, 0.8), m["iron"], cb)
    for i in range(3):
        buildings_gdl._target(f"target_{i}", (-2.2 + i * 0.25, 1.9 - i * 1.6, 0), m, root)
        S.box(f"bale_{i}", (0.8, 0.5, 0.45), (-2.5, 2.4 - i * 1.6, 0.22), m["hay"], root)
    kit.rail_fence("line", [(2.6, -2.7), (2.6, 0.2)], m["timber"], root, h=0.8)
    kit.cross_flag(root, (2.7, -2.7, 0), 3.8, m)
    return root


def to_stable():
    m = kit.mats()
    root = S.empty("to_stable")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    _hall("stable", 5.6, 1.9, 2.4, m, root, loc=(0.0, 2.0, 0), roof_h=1.4, door_x=-1.8,
          windows=[(-0.6, 1.2), (0.6, 1.2), (1.8, 1.2)])
    wing = S.empty("wing", (-2.0, -0.6, 0), root)
    S.box("wing_walls", (1.8, 3.4, 2.2), (0, 0, 1.1), m["brick"], wing)
    kit.gable_roof("wing_roof", 1.8, 3.4, 1.3, 0.12, 2.2, m["tile"], wing, along_y=True)
    kit.gable_wall("wing_gable", 1.8, 1.3, (0, -1.7, 2.2), 0.0, m["brick"], wing, thick=0.2)
    for i, y in enumerate((-1.0, 0.2, 1.2)):
        kit.window(f"wing_stall_{i}", 0.8, 1.2, (0.93, y, 0.1), math.pi / 2, m["dark"], wing)
    kit.rail_fence("paddock", [(-1.0, -2.8), (2.8, -2.8), (2.8, 0.9)], m["timber"], root)
    S.cyl("haystack", 0.8, 0.12, 1.5, (1.6, -0.3, 0), m["hay"], root, seg=10)
    S.box("trough", (1.2, 0.4, 0.35), (0.5, -1.8, 0.18), m["logs_old"], root)
    kit.cross_flag(root, (2.7, 2.6, 0), 4.0, m)
    return root


def to_shrine():
    m = kit.mats()
    root = S.empty("to_shrine")
    kit.yard(2.0, 2.0, S.mat("meadow", "#6e7a45", 1.0, noise=0.3)).parent = root
    ch = S.empty("chapel", (0.0, 0.2, 0), root)
    w, d, h = 2.2, 3.0, 3.0
    S.box("walls", (w, d, h), (0, 0, h / 2), m["brick"], ch)
    kit.gable_roof("roof", w, d, 2.4, 0.1, h, m["tile"], ch, along_y=True)
    for y, rz in ((-d / 2, 0.0), (d / 2, math.pi)):
        kit.stepped_gable(f"sg_{y:.1f}", w + 0.2, 2.8, (0, y, h), rz, m, ch, steps=4)
    for x in (-w / 2 - 0.12, w / 2 + 0.12):
        for y in (-1.0, 1.0):
            S.box(f"buttress_{x:.1f}_{y}", (0.25, 0.3, 2.2), (x, y, 1.1), m["brick_dark"], ch)
    kit.window("door", 0.8, 1.7, (0, -d / 2 - 0.03, 0.0), 0.0, m["door"], ch, pointed=True)
    kit.window("rose", 0.5, 0.9, (0, -d / 2 - 0.25, 3.6), 0.0, m["dark"], ch, pointed=True)
    for i, y in enumerate((-0.5, 0.6)):
        kit.window(f"ewin_{i}", 0.4, 1.3, (w / 2 + 0.03, y, 1.0), math.pi / 2, m["dark"], ch, pointed=True)
    # A ridge turret with a spire and a cross.
    S.box("turret", (0.5, 0.5, 0.8), (0, 0.6, h + 2.0), m["timber"], ch)
    spire = S.cyl("spire", 0.38, 0.02, 1.6, (0, 0.6, h + 2.4), m["tile"], ch, seg=8, smooth=False)
    S.box("cross_v", (0.06, 0.06, 0.5), (0, 0, 1.75), m["iron"], spire)
    S.box("cross_h", (0.3, 0.06, 0.06), (0, 0, 1.85), m["iron"], spire)
    S.box("banner", (0.5, 0.04, 0.6), (-0.55, -1.56, 2.0), m["team"], ch)
    return root


def to_tower():
    m = kit.mats()
    root = S.empty("to_tower")
    t = S.empty("tower", (0, 0, 0), root)
    S.box("base", (2.3, 2.3, 0.5), (0, 0, 0.25), m["brick_dark"], t)
    S.box("shaft", (2.0, 2.0, 7.0), (0, 0, 3.5), m["brick"], t)
    S.box("parapet", (2.4, 2.4, 0.7), (0, 0, 7.35), m["brick"], t)
    for i in range(3):
        for side in range(4):
            a = side * math.pi / 2
            off = -0.8 + i * 0.8
            x, y = math.cos(a) * 1.2 - math.sin(a) * off, math.sin(a) * 1.2 + math.cos(a) * off
            S.box(f"merlon_{side}_{i}", (0.42, 0.42, 0.5), (x, y, 7.95), m["brick"], t)
    for z in (2.0, 4.5):
        kit.window(f"slit_s_{z}", 0.14, 0.7, (0.3, -1.03, z), 0.0, m["dark"], t)
        kit.window(f"slit_e_{z}", 0.14, 0.7, (1.03, -0.3, z), math.pi / 2, m["dark"], t)
    kit.window("door", 0.7, 1.4, (-0.4, -1.03, 0.5), 0.0, m["door"], t, pointed=True)
    S.box("niche", (1.0, 0.05, 1.6), (0.2, -1.04, 5.4), m["plaster"], t)
    kit.cross_flag(t, (0, 0, 7.7), 2.4, m)
    return root


def to_market():
    m = kit.mats()
    root = S.empty("to_market")
    kit.yard(3.0, 3.0, S.mat("cobble", "#77705f", 1.0, noise=0.5)).parent = root
    # The warehouse's gable faces the front right (+X) with its hoist beam and loading doors.
    hall = _hall("kontor", 4.6, 3.0, 4.6, m, root, loc=(-0.4, 1.2, 0), roof_h=3.0, door_x=-0.8,
                 windows=[(0.9, 1.4), (-0.8, 3.0), (0.9, 3.0)], east=[(0.0, 0.0)])
    kit.window("loading_1", 0.7, 0.9, (2.33, 0.0, 2.6), math.pi / 2, m["door"], hall)
    kit.window("loading_2", 0.6, 0.8, (2.33, 0.0, 4.4), math.pi / 2, m["door"], hall)
    S.box("hoist_beam", (0.9, 0.14, 0.14), (2.7, 0.0, 6.0), m["timber"], hall)
    S.cyl("hoist_rope", 0.015, 0.015, 3.0, (3.05, 0.0, 3.0), m["rope"], hall, seg=4)
    for i, (x, y) in enumerate([(2.2, -0.9), (2.6, -1.5), (1.7, -1.6), (2.1, -2.2)]):
        kit.barrel(f"barrel_{i}", (x, y, 0), m, root)
    for i in range(3):
        S.box(f"cloth_{i}", (0.9, 0.5, 0.3), (-1.8, -1.2 - 0.0 * i, 0.15 + 0.3 * i), m["team"] if i == 1 else
              S.mat(f"cloth_{i}", ["#3d4f7a", "#c8bfa8", "#7a3030"][i], 0.95, noise=0.2), root)
    scales = S.empty("scales", (0.1, -2.0, 0), root)
    S.cyl("scale_post", 0.06, 0.05, 1.6, (0, 0, 0), m["timber"], scales, seg=6)
    S.box("scale_beam", (1.1, 0.06, 0.06), (0, 0, 1.6), m["timber"], scales)
    for x in (-0.5, 0.5):
        S.cyl(f"scale_pan_{x}", 0.18, 0.2, 0.05, (x, 0, 1.0), m["iron"], scales, seg=10)
    kit.cross_flag(root, (2.7, 2.7, 0), 4.0, m)
    return root


def to_smithy():
    m = kit.mats()
    root = S.empty("to_smithy")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    _hall("smithy", 3.6, 2.6, 2.8, m, root, loc=(-0.7, 1.4, 0), roof_h=1.6, door_x=-0.6, windows=[(0.8, 1.2)])
    S.box("chimney", (0.6, 0.6, 2.2), (0.6, 1.9, 3.4), m["brick_dark"], root)
    kit.posts_shed("canopy", 2.4, 1.8, 2.2, m["tile"], root, (1.6, -0.9, 0), m, posts_mat=m["timber"])
    S.box("forge", (1.0, 0.8, 0.8), (1.9, -0.6, 0.4), m["brick"], root)
    S.box("forge_fire", (0.6, 0.5, 0.06), (1.9, -0.6, 0.82), m["fire"], root)
    S.cyl("anvil_block", 0.22, 0.25, 0.5, (1.1, -1.4, 0), m["logs_old"], root, seg=8)
    S.box("anvil", (0.45, 0.18, 0.2), (1.1, -1.4, 0.6), m["iron"], root)
    kit.barrel("quench", (2.5, -1.6, 0), m, root)
    for i in range(3):
        S.box(f"bar_{i}", (0.05, 0.05, 1.0), (-0.4 + i * 0.1, -1.6, 0.5), m["iron"], root, rot=(0.25, 0, 0))
    S.box("sign", (0.5, 0.05, 0.4), (0.9, -0.15, 2.2), m["team"], root)
    kit.cross_flag(root, (-2.7, -2.6, 0), 3.8, m)
    return root


def to_temple():
    m = kit.mats()
    root = S.empty("to_temple")
    kit.yard(3.0, 3.0, S.mat("meadow", "#6e7a45", 1.0, noise=0.3)).parent = root
    # Nave along X, the chancel's stepped gable to the front right (east), the tower at the back.
    nave = _hall("nave", 4.4, 3.0, 5.0, m, root, loc=(0.6, 0.6, 0), roof_h=3.4, gables=(False, True),
                 door_x=0.2, windows=[(-1.1, 1.4), (1.4, 1.4)], east=[(0.0, 1.2)], pointed=True)
    for x in (-1.6, 0.0, 1.6):
        S.box(f"buttress_{x}", (0.3, 0.35, 3.6), (x + 0.6, 0.6 - 1.65, 1.8), m["brick_dark"], root)
    tw = S.empty("tower", (-2.2, 0.6, 0), root)
    S.box("tower_shaft", (1.9, 1.9, 9.0), (0, 0, 4.5), m["brick"], tw)
    for z in (4.0, 6.5):
        S.box(f"tower_niche_{z}", (0.9, 0.05, 1.6), (0, -0.97, z), m["plaster"], tw)
    kit.window("tower_bell", 0.5, 1.2, (0, -0.98, 7.6), 0.0, m["dark"], tw, pointed=True)
    spire = S.cyl("spire", 1.4, 0.03, 3.6, (0, 0, 9.0), m["tile"], tw, seg=4, smooth=False)
    spire.rotation_euler = (0, 0, math.pi / 4)
    S.box("cross_v", (0.08, 0.08, 0.7), (0, 0, 3.9), m["iron"], spire)
    S.box("cross_h", (0.4, 0.08, 0.08), (0, 0, 4.0), m["iron"], spire)
    S.box("banner", (0.6, 0.04, 0.9), (-0.9, -1.56, 2.4), m["team"], nave)
    return root


def siege_workshop():
    m = kit.mats()
    root = S.empty("to_siege_workshop")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    kit.posts_shed("shed", 4.6, 2.8, 2.6, m["tile"], root, (0, 1.2, 0), m, lean=False, posts_mat=m["timber"])
    frame = S.empty("cart", (0.2, 1.1, 0.55), root)
    for y in (-0.55, 0.55):
        S.box(f"cart_beam_{y}", (2.8, 0.14, 0.14), (0, y, 0), m["plank"], frame)
    for x in (-1.2, -0.4, 0.4, 1.2):
        S.box(f"cart_cross_{x}", (0.12, 1.25, 0.1), (x, 0, 0.1), m["plank"], frame)
    for i, (x, y, rz) in enumerate([(-1.0, 0.45, 0.0), (1.4, 0.45, 0.0), (2.6, -0.6, math.pi / 2)]):
        w = S.cyl(f"wheel_{i}", 0.55, 0.55, 0.1, (x, y, 0.55), m["logs_old"], root,
                  rot=(math.pi / 2 - 0.15, 0, rz), seg=14)
        S.cyl(f"wheel_hub_{i}", 0.12, 0.12, 0.2, (0, 0, -0.05), m["iron"], w, seg=8)
    kit.log_pile("timber", (-1.3, -1.6, 0), 0.0, 2.6, 6, m, root)
    S.cyl("rope_coil", 0.3, 0.3, 0.12, (1.3, -1.3, 0), m["rope"], root, seg=12)
    kit.cross_flag(root, (2.7, -2.7, 0), 3.6, m)
    return root


def to_castle():
    """A Komturei: four brick wings round a square court, a tall tower in the back corner,
    a gate tower in the front wing, tile roofs."""
    m = kit.mats()
    root = S.empty("to_castle")
    kit.yard(4.0, 4.0, m["earth"]).parent = root
    s, dep, h = 7.4, 1.9, 5.6
    half = s / 2
    wings = [((0, -half + dep / 2), (s, dep), False), ((0, half - dep / 2), (s, dep), False),
             ((-half + dep / 2, 0), (dep, s - 2 * dep), True), ((half - dep / 2, 0), (dep, s - 2 * dep), True)]
    for i, ((x, y), (w, d), along_y) in enumerate(wings):
        wing = S.empty(f"wing_{i}", (x, y, 0), root)
        S.box(f"wing_{i}_walls", (w, d, h), (0, 0, h / 2), m["brick"], wing)
        S.box(f"wing_{i}_plinth", (w + 0.15, d + 0.15, 0.5), (0, 0, 0.25), m["brick_dark"], wing)
        kit.gable_roof(f"wing_{i}_roof", w, d, 1.8, 0.1, h, m["tile"], wing, along_y=along_y)
    # Windows on the two faces the camera sees.
    for i, x in enumerate((-2.6, -1.3, 1.3, 2.6)):
        kit.window(f"s_win_{i}", 0.4, 1.0, (x, -half - 0.03, 3.2), 0.0, m["dark"], root, pointed=True)
        kit.window(f"e_win_{i}", 0.4, 1.0, (half + 0.03, x, 3.2), math.pi / 2, m["dark"], root, pointed=True)
    for i, x in enumerate((-2.0, 0.0, 2.0)):
        S.box(f"s_frieze_{i}", (1.4, 0.05, 0.5), (x, -half - 0.04, 4.9), m["plaster"], root)
        S.box(f"e_frieze_{i}", (0.05, 1.4, 0.5), (half + 0.04, x, 4.9), m["plaster"], root)
    # Gate tower in the front wing.
    gt = S.empty("gate_tower", (0.0, -half + 0.6, 0), root)
    S.box("gate_tower_body", (2.0, 1.6, 7.4), (0, 0, 3.7), m["brick"], gt)
    kit.window("gate_arch", 1.2, 2.4, (0, -0.83, 0.0), 0.0, m["door"], gt, pointed=True)
    kit.stepped_gable("gate_sg", 2.0, 1.8, (0, -0.65, 7.4), 0.0, m, gt, steps=3)
    kit.gable_roof("gate_roof", 2.0, 1.6, 1.6, 0.05, 7.4, m["tile"], gt, along_y=True)
    # Main tower in the back corner, square, crenellated, with a pyramid roof.
    tw = S.empty("main_tower", (-half + 1.1, half - 1.1, 0), root)
    S.box("main_tower_shaft", (2.4, 2.4, 10.5), (0, 0, 5.25), m["brick"], tw)
    for z in (6.0, 8.5):
        S.box(f"main_tower_niche_{z}", (1.4, 0.05, 1.6), (0, -1.23, z), m["plaster"], tw)
    roof = S.cyl("main_tower_roof", 1.85, 0.03, 2.6, (0, 0, 10.5), m["tile"], tw, seg=4, smooth=False)
    roof.rotation_euler = (0, 0, math.pi / 4)
    kit.cross_flag(tw, (0, 0, 12.8), 2.6, m)
    # Corner turrets on the front corners.
    for i, (x, y) in enumerate([(half, -half), (-half, -half), (half, half)]):
        S.cyl(f"turret_{i}", 0.6, 0.55, h + 1.2, (x, y, 0), m["brick"], root, seg=8)
        S.cyl(f"turret_{i}_roof", 0.75, 0.02, 1.6, (x, y, h + 1.2), m["tile"], root, seg=8, smooth=False)
    S.box("banner", (0.7, 0.05, 1.3), (1.6, -half - 0.05, 2.8), m["team"], root)
    return root


def to_brickworks():
    m = kit.mats()
    root = S.empty("to_brickworks")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    kiln = S.empty("kiln", (-0.7, 0.7, 0), root)
    S.box("kiln_body", (2.0, 1.8, 1.7), (0, 0, 0.85), m["brick_dark"], kiln)
    S.box("kiln_top", (1.6, 1.4, 0.35), (0, 0, 1.85), m["brick"], kiln)
    S.box("kiln_chimney", (0.5, 0.5, 1.2), (-0.5, 0.4, 2.2), m["brick_dark"], kiln)
    kit.window("kiln_mouth", 0.5, 0.6, (0.2, -0.93, 0.1), 0.0, m["fire"], kiln, pointed=True)
    kit.window("kiln_mouth_e", 0.5, 0.6, (1.03, 0.0, 0.1), math.pi / 2, m["fire"], kiln, pointed=True)
    # Drying shed with rows of raw bricks.
    kit.posts_shed("dry", 1.6, 1.1, 1.5, m["thatch"], root, (1.1, 1.2, 0), m, posts_mat=m["timber"])
    raw = S.mat("raw_brick", "#b08a64", 1.0, noise=0.2)
    for i in range(3):
        S.box(f"raw_{i}", (1.3, 0.25, 0.25), (1.1, 0.9 + i * 0.3, 0.12), raw, root)
    # Stacks of fired bricks and the clay pit.
    for i, (x, y) in enumerate([(0.9, -0.9), (1.5, -0.4), (1.4, -1.5)]):
        S.box(f"stack_{i}", (0.6, 0.45, 0.55 + 0.1 * i), (x, y, 0.3), m["brick"], root)
    S.box("clay_pit", (1.0, 0.9, 0.03), (-1.2, -1.2, 0.04), S.mat("wet_clay", "#7c5a42", 0.3, noise=0.3), root)
    S.cyl("spade", 0.02, 0.02, 1.1, (-0.6, -1.4, 0), m["logs"], root, rot=(0.3, 0.3, 0), seg=5)
    S.box("stack_band", (0.62, 0.05, 0.08), (0.9, -1.13, 0.4), m["team"], root)
    kit.cross_flag(root, (-1.8, -1.8, 0), 3.4, m)
    return root


def _palisade(arm):
    return buildings_gdl.palisade_piece(arm)


BUILDINGS = {
    "to_town_center": (to_town_center, (4, 4), 9),
    "to_house": (to_house, (2, 2), 6),
    "to_granary": (to_granary, (2, 2), 6),
    "to_farm": (to_farm, (3, 3), 2),
    "to_lumber_yard": (to_lumber_yard, (2, 2), 5),
    "to_mine": (to_mine, (2, 2), 6),
    "to_barracks": (to_barracks, (3, 3), 9),
    "to_range": (to_range, (3, 3), 6),
    "to_stable": (to_stable, (3, 3), 6),
    "to_shrine": (to_shrine, (2, 2), 8),
    "to_tower": (to_tower, (1, 1), 11),
    "to_market": (to_market, (3, 3), 10),
    "to_smithy": (to_smithy, (3, 3), 7),
    "to_temple": (to_temple, (3, 3), 14),
    "to_siege_workshop": (siege_workshop, (3, 3), 6),
    "to_castle": (to_castle, (4, 4), 16),
    "to_brickworks": (to_brickworks, (2, 2), 5),
    "to_gate": (buildings_gdl.gate(), (1, 1), 6),
    "to_gate_v": (buildings_gdl.gate(True), (1, 1), 6),
    "to_palisade": (_palisade(""), (1, 1), 3),
}
for _arm in "ewns":
    BUILDINGS[f"to_palisade_{_arm}"] = (_palisade(_arm), (1, 1), 3)
