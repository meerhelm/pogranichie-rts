"""Buildings of the Crown of Poland (visual assets doc, «Общие здания», «Особые здания» and
the faction table: «кирпично-каменная готика, деревянные хаты, костёлы с высокой крышей»):
whitewashed timber under thatch and shingle for the village and the yard, red brick Gothic with
white stone details and red tiles for the church and the castle; red and white with the White
Eagle on flags, gates and pavises, the team colour on pennons, bands and cloths. So the Crown
reads apart from the Duchy (bare logs) and the Order (brick and fachwerk, black and white).

- pl_town_center: «Двор», a noble manor: a whitewashed timber house on a stone basement under a
  high shingled hipped roof, a porch (ganek) on columns with a gable over the door, two brick
  chimneys; a small brick treasury (lamus) under tiles, a plank fence with a roofed gate, a
  well sweep (żuraw), the Crown's flag.
- pl_house: «Хата», a whitewashed cottage under a high hipped thatch, a wattle fence with clay
  pots on its stakes, a bench by the door.
- pl_granary: a granary on stilts with a shingled roof carried forward over posts (podcień).
- pl_farm: strip fields of the three-field system: ripe rye, young green corn and a ploughed
  fallow side by side, grass balks between them, a stook of sheaves, a wooden harrow.
- pl_lumber_yard: a shingled shed, stacks of logs, boards, a trestle, an axe in the block.
- pl_mine: a shaft with a windlass (kołowrót) under a small roof, a bucket, heaps of grey lead
  and silver ore (Olkusz), baskets, a shed.
- pl_barracks: «Оружейный двор», a log hall on a stone plinth under shingles, pavises with the
  White Eagle along the wall, a spear rack, a pell.
- pl_range: a shingled shed, racks of bows and crossbows, straw targets, a shooting line.
- pl_stable: a long log stable under thatch, an open hay barn, a paddock, a trough.
- pl_shrine: «Придорожный крест», a tall wooden cross with a little roof over the arms and a
  team sash, on a low mound with field stones inside a small picket fence.
- pl_shrine_chapel: the same site after the priest makes it a «каплица»: a small whitewashed
  chapel with red brick quoins under a steep shingle roof, a little bell turret with a spire on
  the ridge; the cross stays beside it.
- pl_palisade (+ arms _e/_w/_n/_s): the Duchy's sharpened logs (one model with gdl_palisade).
- pl_gate / pl_gate_v: the palisade gate with a platform under shingles and the White Eagle on
  a red field on the leaves.
- pl_tower: «Башня», a fieldstone foot, a brick shaft with white stone bands, an overhanging
  timber hoarding with loopholes and a steep shingle pyramid roof.
- pl_market: «Рынок», a timber cloth hall (sukiennice) with an arcade, stalls under red and
  white awnings, bolts of cloth, scales, barrels.
- pl_smithy: a log smithy with a stone chimney, an open forge under a shingled canopy.
- pl_temple: «Костёл», a brick Gothic church: a nave under a steep red tile roof, a lower
  chancel, buttresses and pointed windows, white plastered blind niches, a square west tower
  with a tall green copper octagonal spire.
- pl_siege_workshop: a shingled shed, a bombard barrel on trestles, stone balls, a wheel.
- pl_castle: «Замок», a royal castle of Casimir the Great's kind: curtain walls on a stone foot,
  crenellated, round corner towers, a tall round keep with a conical roof at the back, a
  gatehouse with a stone portal and the Eagle over it, a brick palace with a high red tile roof
  and white stone window frames inside the court; unlike the Order's closed square Komturei.
- pl_salt_works: «Соляная жупа», a boiling house with steam rising from its roof vent, a horse
  capstan (kierat) over the brine well, barrels and white salt cones.
- pl_battery: a half ring of wicker gabions filled with earth round a plank floor, a pyramid
  of stone balls, a rammer on the planks.
"""

import math
import random

from mathutils import Vector

from tools.art import buildings_gdl, kit
from tools.art import shapes as S
from tools.art.folk_1514 import _white_eagle
from tools.art.models import _srub, _thatch_roof


def _m():
    m = kit.mats()
    m.update({
        "whitewash": S.mat("whitewash", "#ebe6d8", 0.95, noise=0.1),
        "court_red": S.mat("court_red", "#b0201c", 0.9, noise=0.08),
        "eagle_white": S.mat("eagle_white", "#f0eee8", 0.85),
        "gold": S.mat("gold", "#c9a03a", 0.4, metal=0.8),
        "limestone": S.mat("limestone", "#d2c9b2", 0.9, noise=0.25),
        "copper": S.mat("copper_green", "#5f8f78", 0.6, noise=0.2, metal=0.3),
        "meadow": S.mat("meadow", "#6e7a45", 1.0, noise=0.3),
        "cobble": S.mat("cobble", "#77705f", 1.0, noise=0.5),
        "wicker": S.mat("wicker", "#8e7346", 1.0, noise=0.6),
        "canvas": S.mat("canvas_white", "#ebe7dc", 0.95, noise=0.1),
        "salt": S.mat("salt", "#f3f2ec", 0.7, noise=0.08),
        "steam": S.mat("steam", "#e4e4e0", 1.0, noise=0.2),
        "stone_ball": S.mat("stone_ball", "#9a958a", 0.95, noise=0.4),
        "black_iron": S.mat("black_iron", "#3c3a38", 0.5, noise=0.3, metal=0.7),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def crown_flag(parent, loc, height, m):
    """The Crown's flag: the White Eagle on red, a team pennon under it."""
    pole = S.cyl("flag_pole", 0.04, 0.03, height, loc, m["logs"], parent, seg=6)
    S.solidify(S.poly("flag", [(0, 0, height - 0.1), (0.9, 0, height - 0.1), (0.9, 0, height - 0.72),
                               (0, 0, height - 0.72)], [(0, 1, 2, 3)], m["court_red"], pole), 0.02)
    _white_eagle("flag_eagle", pole, (0.45, -0.035, height - 0.42), 0.6, m)
    S.solidify(S.poly("flag_pennon", [(0, 0, height - 0.78), (0.6, 0, height - 0.86), (0, 0, height - 0.98)],
                      [(0, 1, 2)], m["team"], pole), 0.02)
    return pole


def _bands(name, w, d, h, z0, material, parent, bands=3):
    """A wall body as stacked boxes (at least `bands`, none taller than 0.75 m), so a building
    site rises band by band and a ruin keeps low courses lying about, not whole walls."""
    bands = max(bands, math.ceil(h / 0.75))
    for k in range(bands):
        bh = h / bands
        S.box(f"{name}_{k}", (w, d, bh + 0.002), (0, 0, z0 + bh * (k + 0.5)), material, parent)


def _chata(prefix, w, d, h, m, parent, loc=(0, 0, 0), z0=0.0, base="stone", base_h=0.3, quoins=None):
    """A whitewashed timber body: a stone (or log) sill, white walls, dark corner posts and a
    top plate; `quoins` puts brick corners instead of the posts. Returns the holder; the walls
    start at z0 + base_h."""
    holder = S.empty(prefix, loc, parent)
    S.box(f"{prefix}_sill", (w + 0.12, d + 0.12, base_h), (0, 0, z0 + base_h / 2), m[base], holder)
    zb = z0 + base_h
    _bands(f"{prefix}_walls", w, d, h, zb, m["whitewash"], holder)
    for i, (x, y) in enumerate([(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]):
        if quoins is not None:
            for k in range(int(h / 0.5)):
                s = 0.32 if k % 2 == 0 else 0.22
                S.box(f"{prefix}_quoin_{i}_{k}", (s, s, 0.22), (x, y, zb + 0.13 + k * 0.5), m[quoins], holder)
        else:
            S.box(f"{prefix}_corner_{i}", (0.16, 0.16, h), (x, y, zb + h / 2), m["timber"], holder)
    S.box(f"{prefix}_plate", (w + 0.1, d + 0.1, 0.12), (0, 0, zb + h + 0.06), m["timber"], holder)
    return holder


def _openings(prefix, w, d, z, m, parent, door_x=None, windows=(), east=(), shutters=True):
    """Door and small windows with team-free blue-grey shutters on the -Y face, windows on +X."""
    if door_x is not None:
        kit.window(f"{prefix}_door", 0.8, 1.55, (door_x, -d / 2 - 0.03, z), 0.0, m["door"], parent)
    shutter = S.mat("shutter", "#5a6a74", 0.85, noise=0.2)
    for i, (x, wz) in enumerate(windows):
        kit.window(f"{prefix}_win_{i}", 0.42, 0.5, (x, -d / 2 - 0.03, z + wz), 0.0, m["dark"], parent)
        if shutters:
            for s in (-1, 1):
                S.box(f"{prefix}_shut_{i}_{s}", (0.2, 0.03, 0.5), (x + s * 0.32, -d / 2 - 0.05, z + wz + 0.25), shutter,
                      parent)
    for i, (y, wz) in enumerate(east):
        kit.window(f"{prefix}_ewin_{i}", 0.42, 0.5, (w / 2 + 0.03, y, z + wz), math.pi / 2, m["dark"], parent)


def _thatch_hip(name, w, d, h, over, z, m, parent):
    roof = kit.hip_roof(name, w, d, h, over, z, m["thatch"], parent)
    roof.modifiers["solid"].thickness = 0.16
    return roof


def _pavise_prop(name, loc, rot_z, m, parent):
    """A big pavise leaning on a wall: red with the White Eagle, a team ridge."""
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = (0.28, 0, rot_z)
    S.box(f"{name}_board", (0.62, 0.08, 1.2), (0, 0, 0.6), m["court_red"], holder)
    S.box(f"{name}_ridge", (0.1, 0.12, 1.2), (0, -0.03, 0.6), m["team"], holder)
    _white_eagle(f"{name}_eagle", holder, (0, -0.1, 0.78), 0.5, m)
    return holder


def _picket(prefix, pts, m, parent, h=0.75):
    """A low picket fence (sztachety): a rail and pointed palings."""
    holder = S.empty(prefix, (0, 0, 0), parent)
    for i, ((x0, y0), (x1, y1)) in enumerate(zip(pts, pts[1:])):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        S.box(f"{prefix}_rail_{i}", (length, 0.05, 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, h * 0.6), m["plank"], holder,
              rot=(0, 0, ang))
        n = max(1, round(length / 0.22))
        for k in range(n + 1):
            t = k / n
            p = S.box(f"{prefix}_pale_{i}_{k}", (0.07, 0.03, h), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, h / 2),
                      m["plank"], holder, rot=(0, 0, ang))
    return holder


def _wooden_cross(name, loc, height, m, parent, roofed=True, sash=True):
    """A tall wayside cross of squared beams, a little gabled roof over the arms, a sash."""
    holder = S.empty(name, loc, parent)
    t = 0.14
    S.box(f"{name}_v", (t, t, height), (0, 0, height / 2), m["logs_old"], holder)
    arm = height * 0.42
    za = height * 0.76
    S.box(f"{name}_h", (arm, t, t), (0, 0, za), m["logs_old"], holder)
    if roofed:
        # The little gabled roof capping the post, its ridge pointing out of the cross.
        kit.gable_roof(f"{name}_roof", 0.62, 0.42, 0.24, 0.04, height - 0.08, m["shingle"], holder, along_y=True,
                       thick=0.04)
    S.cyl(f"{name}_tin", 0.05, 0.05, 0.03, (0, -0.08, za), m["gold"], holder, rot=(math.pi / 2, 0, 0), seg=8)
    if sash:
        S.box(f"{name}_sash_a", (0.09, 0.03, 0.75), (arm * 0.38, -0.09, za - 0.4), m["team"], holder)
        S.box(f"{name}_sash_b", (0.09, 0.03, 0.6), (-arm * 0.38, -0.09, za - 0.33), m["eagle_white"], holder)
    return holder


# --- the village ---------------------------------------------------------------------------

def pl_house():
    m = _m()
    root = S.empty("pl_house")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    w, d, h = 3.0, 2.3, 1.85
    house = _chata("house", w, d, h, m, root, loc=(0.15, 0.35, 0), base="logs_old", base_h=0.22)
    _thatch_hip("roof", w, d, 2.3, 0.45, 0.22 + h + 0.1, m, house)
    _openings("house", w, d, 0.22, m, house, door_x=0.55, windows=[(-0.65, 0.75)], east=[(0.1, 0.75)])
    S.cyl("bench", 0.1, 0.1, 1.1, (-1.05, -0.9, 0.3), m["plank"], house, rot=(0, math.pi / 2, 0), seg=6)
    kit.wattle("garden", [(-1.9, -0.6), (-1.9, -1.9), (0.6, -1.9)], m, root, h=0.75)
    for i, (x, y) in enumerate([(-1.9, -1.3), (-1.3, -1.9), (-0.1, -1.9)]):
        S.cyl(f"pot_{i}", 0.1, 0.07, 0.16, (x, y, 0.72), m["clay"], root, rot=(math.pi, 0, 0), seg=8)
    S.box("cloth", (0.5, 0.03, 0.35), (0.2, -1.92, 0.55), m["team"], root)
    kit.log_pile("firewood", (1.55, -1.2, 0), math.pi / 2, 0.9, 6, m, root, r=0.09)
    crown_flag(root, (1.8, 1.8, 0), 3.2, m)
    return root


def pl_town_center():
    m = _m()
    root = S.empty("pl_town_center")
    kit.yard(4.0, 4.0, m["earth"]).parent = root
    # The plank fence round the yard, the roofed gate in the front.
    e = 3.85
    _picket("fence_a", [(-e, -e), (-1.0, -e)], m, root, h=1.2)
    _picket("fence_b", [(1.0, -e), (e, -e), (e, e), (-e, e), (-e, -e)], m, root, h=1.2)
    for x in (-1.0, 1.0):
        S.cyl(f"gate_post_{x}", 0.13, 0.12, 2.5, (x, -e, 0), m["timber"], root, seg=8)
    kit.gable_roof("gate_roof", 2.4, 0.7, 0.55, 0.12, 2.45, m["shingle"], root)
    # The manor: a whitewashed timber house on a stone basement, a high hipped shingle roof.
    w, d, h = 5.8, 3.3, 2.6
    house = _chata("manor", w, d, h, m, root, loc=(0.3, 1.25, 0), base="stone", base_h=0.65)
    top = 0.65 + h + 0.12
    kit.hip_roof("manor_roof", w, d, 3.4, 0.5, top, m["shingle"], house)
    for i, x in enumerate((-0.9, 0.9)):
        S.box(f"manor_roof_chimney_{i}", (0.42, 0.42, 1.4), (x, 0.25, top + 3.0), m["brick"], house)
    _openings("manor", w, d, 0.65, m, house, door_x=0.0,
              windows=[(-2.2, 0.8), (-1.2, 0.8), (1.2, 0.8), (2.2, 0.8)], east=[(-0.7, 0.8), (0.7, 0.8)])
    # The ganek: four columns, a gable roof over the porch, steps, the owner's shield in the gable.
    porch = S.empty("ganek", (0.0, -d / 2 - 0.75, 0), house)
    S.box("ganek_floor", (2.0, 1.5, 0.12), (0, 0, 0.6), m["plank"], porch)
    for i in range(3):
        S.box(f"ganek_step_{i}", (1.0, 0.3, 0.2), (0, -0.85 - i * 0.28, 0.5 - i * 0.2), m["stone"], porch)
    for x in (-0.85, -0.4, 0.4, 0.85):
        S.cyl(f"ganek_col_{x}", 0.08, 0.07, 2.4, (x, -0.65, 0.65), m["whitewash"], porch, seg=8)
    kit.gable_roof("ganek_roof", 2.1, 1.6, 1.0, 0.15, 3.05, m["shingle"], porch, along_y=True)
    kit.gable_wall("ganek_gable", 2.1, 1.0, (0, -0.8, 3.05), 0.0, m["whitewash"], porch, thick=0.06)
    S.box("ganek_gable_arms", (0.38, 0.05, 0.42), (0, -0.85, 3.4), m["team"], porch)
    # The lamus: a small brick treasury under tiles at the front left.
    lamus = S.empty("lamus", (-2.55, -1.8, 0), root)
    _bands("lamus_walls", 1.9, 1.9, 3.2, 0.0, m["brick"], lamus)
    S.box("lamus_plinth", (2.0, 2.0, 0.4), (0, 0, 0.2), m["limestone"], lamus)
    kit.hip_roof("lamus_roof", 1.9, 1.9, 1.6, 0.18, 3.2, m["tile"], lamus)
    kit.window("lamus_door", 0.7, 1.4, (0.3, -0.98, 0.3), 0.0, m["door"], lamus, pointed=True)
    kit.window("lamus_win", 0.25, 0.45, (0.98, 0.0, 2.1), math.pi / 2, m["dark"], lamus)
    S.box("lamus_frieze", (1.94, 1.94, 0.2), (0, 0, 2.85), m["limestone"], lamus)
    # The well sweep (żuraw) at the front right.
    wx, wy = 2.6, -2.4
    S.box("well_curb", (0.9, 0.9, 0.6), (wx, wy, 0.3), m["logs"], root)
    S.box("well_water", (0.7, 0.7, 0.02), (wx, wy, 0.6), m["dark"], root)
    S.cyl("sweep_post", 0.09, 0.08, 2.6, (wx + 0.9, wy + 0.5, 0), m["logs_old"], root, seg=7)
    # The pole rocks on the post's fork: one end high over the well, the weighted end low behind.
    tip = Vector((wx, wy, 3.3))
    along = (Vector((wx + 0.9, wy + 0.5, 2.6)) - tip).normalized()
    butt = tip + along * 4.2
    S.cyl("sweep_pole", 0.05, 0.04, 4.2, tuple(butt), m["logs_old"], root,
          rot=tuple((-along).to_track_quat("Z", "Y").to_euler()), seg=6)
    S.box("sweep_weight", (0.3, 0.3, 0.3), tuple(butt + along * -0.2), m["stone"], root)
    S.cyl("sweep_rope", 0.01, 0.01, 2.5, (wx, wy, 0.85), m["rope"], root, seg=3)
    S.cyl("sweep_bucket", 0.12, 0.14, 0.22, (wx, wy, 0.75), S.mat("barrel", "#7c5a36", 0.8, noise=0.3), root, seg=8)
    kit.log_pile("woodpile", (3.0, 0.4, 0), math.pi / 2, 1.6, 6, m, root, r=0.11)
    crown_flag(root, (-3.4, 3.3, 0), 6.5, m)
    return root


def pl_granary():
    m = _m()
    root = S.empty("pl_granary")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    body = S.empty("granary", (0, 0.45, 0), root)
    w, d, z0 = 2.8, 1.9, 0.6
    for x in (-1.2, 0, 1.2):
        for y in (-0.8, 0.8):
            S.cyl(f"stilt_{x}_{y}", 0.13, 0.11, z0, (x, y, 0), m["logs_old"], body, seg=7)
            S.cyl(f"stilt_cap_{x}_{y}", 0.22, 0.2, 0.08, (x, y, z0), m["stone"], body, seg=8)
    S.box("floor", (w + 0.2, d + 0.2, 0.12), (0, 0, z0 + 0.1), m["plank"], body)
    _srub("wall", w, d, 1.55, 0.12, z0 + 0.15, m["logs"], body, seed=81)
    # The roof carried forward over three posts: a covered walk along the front (podcień).
    kit.gable_roof("roof", w, d + 1.1, 1.3, 0.3, z0 + 1.75, m["shingle"], body).location.y = -0.55
    for x in (-w / 2, w / 2):
        kit.gable_wall(f"gable_{x}", d + 1.2, 1.25, (x, -0.55, z0 + 1.75), math.pi / 2, m["plank"], body)
    for x in (-1.3, 0.0, 1.3):
        S.cyl(f"porch_post_{x}", 0.08, 0.07, z0 + 1.75, (x, -1.55, 0), m["logs"], body, seg=6)
        S.box(f"porch_brace_{x}", (0.06, 0.4, 0.06), (x, -1.4, z0 + 1.6), m["logs"], body, rot=(0.8, 0, 0))
    kit.window("door", 0.75, 1.25, (0.4, -d / 2 - 0.14, z0 + 0.2), 0.0, m["door"], body)
    for i in range(3):
        S.box(f"step_{i}", (0.8, 0.28, 0.1), (0.4, -1.3 - i * 0.24, z0 - i * 0.2), m["plank"], body)
    for i, (x, y) in enumerate([(-0.6, -1.6), (-0.95, -1.45), (-0.8, -1.2), (1.45, -1.55)]):
        kit.sack(f"sack_{i}", (x, y, 0), m, root, s=1.0 - 0.1 * (i % 2))
    S.box("sack_band", (0.3, 0.05, 0.06), (-0.6, -1.81, 0.32), m["team"], root)
    crown_flag(root, (1.75, 1.75, 0), 3.4, m)
    return root


def pl_farm():
    """Strips of the three-field system running front to back: ripe rye, young corn and the
    ploughed fallow, grass balks between them."""
    rng = random.Random(21)
    m = _m()
    root = S.empty("pl_farm")
    S.box("yard", (5.9, 5.9, 0.04), (0, 0, 0.02), m["soil"])
    young = S.mat("young_corn", "#6f9a3c", 1.0, noise=0.45)
    stalk = S.mat("rye_stalk", "#8a8a3c", 1.0, noise=0.4)
    strips = [(-2.15, "rye"), (-0.75, "young"), (0.65, "fallow"), (2.05, "rye")]
    for si, (x, kind) in enumerate(strips):
        if si:
            S.box(f"yard_balk_{si}", (0.2, 5.6, 0.06), (x - 0.7, 0, 0.05), m["meadow"], root)
        for k in range(4):
            fx = x - 0.45 + k * 0.3
            if kind == "fallow":
                S.box(f"furrow_{si}_{k}", (0.18, 5.4, 0.1), (fx, 0, 0.06), m["earth"], root)
                continue
            S.box(f"ridge_{si}_{k}", (0.22, 5.4, 0.08), (fx, 0, 0.05), stalk if kind == "rye" else m["soil"], root)
            for j in range(17):
                y = -2.55 + j * 0.32 + rng.uniform(-0.05, 0.05)
                if kind == "rye":
                    S.cyl(f"rye_{si}_{k}_{j}", 0.1, 0.15, rng.uniform(0.42, 0.56), (fx + rng.uniform(-0.04, 0.04), y, 0.04),
                          m["grain"], root, rot=(rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 0), seg=6)
                else:
                    S.cyl(f"corn_{si}_{k}_{j}", 0.09, 0.04, rng.uniform(0.18, 0.26), (fx, y, 0.04), young, root, seg=5)
    # A wooden harrow left on the fallow, a stook of sheaves, the boundary stake with a team rag.
    harrow = S.empty("harrow", (0.75, -1.6, 0.08), root)
    harrow.rotation_euler = (0, 0, 0.3)
    for k in range(4):
        S.box(f"harrow_bar_{k}", (0.07, 1.1, 0.07), (-0.4 + k * 0.27, 0, 0), m["logs_old"], harrow)
    for k in range(3):
        S.box(f"harrow_cross_{k}", (0.95, 0.06, 0.06), (0, -0.4 + k * 0.4, 0.06), m["logs_old"], harrow)
    for i in range(5):
        a = i * math.tau / 5
        S.cyl(f"sheaf_{i}", 0.16, 0.08, 0.75, (2.5 + 0.13 * math.cos(a), -2.45 + 0.13 * math.sin(a), 0), m["straw"],
              root, rot=(0.25 * math.sin(a), -0.25 * math.cos(a), 0), seg=8)
    st = S.cyl("mark_stake", 0.04, 0.035, 1.3, (-2.8, -2.8, 0), m["logs"], root, seg=5)
    S.box("mark_rag", (0.3, 0.03, 0.22), (0.15, 0, 1.12), m["team"], st)
    return root


def pl_lumber_yard():
    m = _m()
    root = S.empty("pl_lumber_yard")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    kit.posts_shed("shed", 3.2, 1.5, 2.1, m["shingle"], root, (0, 0.95, 0), m, posts_mat=m["logs_old"])
    kit.log_pile("logs_a", (0.0, 1.0, 0), 0.0, 2.8, 9, m, root)
    kit.log_pile("logs_b", (-1.3, -0.7, 0), math.pi / 2, 1.6, 5, m, root)
    for i in range(4):
        S.box(f"board_{i}", (1.4, 0.24, 0.05), (0.55, -1.55, 0.03 + i * 0.06), m["plank"], root,
              rot=(0, 0, 0.05 * (i % 2)))
    for x in (0.3, 1.3):
        for s in (-1, 1):
            S.box(f"trestle_{x}_{s}", (0.08, 0.08, 1.0), (x, -0.6 + s * 0.15, 0.45), m["logs_old"], root,
                  rot=(s * 0.35, 0, 0))
    S.cyl("sawlog", 0.15, 0.15, 1.9, (-0.15, -0.6, 0.95), m["logs"], root, rot=(0, math.pi / 2, 0), seg=8)
    S.box("saw", (1.0, 0.02, 0.16), (0.8, -0.6, 1.25), m["iron"], root, rot=(0, 0.25, 0))
    kit.stump("chop", (1.6, -1.0, 0), m, root, r=0.26)
    S.box("axe_head", (0.04, 0.16, 0.1), (1.6, -1.0, 0.45), m["iron"], root)
    S.cyl("axe_haft", 0.016, 0.016, 0.55, (1.6, -0.95, 0.45), m["logs"], root, rot=(-0.9, 0, 0), seg=5)
    S.box("log_band", (0.06, 0.4, 0.06), (1.12, 1.0, 0.35), m["team"], root)
    crown_flag(root, (-1.75, 1.75, 0), 3.4, m)
    return root


def pl_mine():
    m = _m()
    root = S.empty("pl_mine")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    # The shaft: a square log collar round a dark hole, the windlass over it under a little roof.
    sx, sy = 0.2, 0.3
    S.box("shaft_hole", (1.0, 1.0, 0.02), (sx, sy, 0.05), m["dark"], root)
    for i, (x, y, rz) in enumerate([(0, -0.6, 0), (0, 0.6, 0), (-0.6, 0, math.pi / 2), (0.6, 0, math.pi / 2)]):
        S.cyl(f"collar_{i}", 0.12, 0.12, 1.4, (sx + x - 0.7 * math.cos(rz), sy + y - 0.7 * math.sin(rz), 0.12),
              m["logs"], root, rot=(0, math.pi / 2, rz), seg=7)
    for x in (-0.75, 0.75):
        S.box(f"windlass_post_{x}", (0.14, 0.14, 1.7), (sx + x, sy, 0.85), m["logs_old"], root)
    S.cyl("windlass_drum", 0.15, 0.15, 1.4, (sx - 0.7, sy, 1.25), m["logs"], root, rot=(0, math.pi / 2, 0), seg=10)
    S.box("windlass_crank", (0.05, 0.05, 0.4), (sx + 0.85, sy, 1.1), m["iron"], root)
    S.cyl("windlass_rope", 0.012, 0.012, 1.2, (sx, sy, 0.1), m["rope"], root, seg=3)
    S.cyl("windlass_bucket", 0.16, 0.18, 0.3, (sx, sy, 0.3), S.mat("barrel", "#7c5a36", 0.8, noise=0.3), root, seg=8)
    for x in (-0.85, 0.85):
        S.cyl(f"roof_post_{x}", 0.05, 0.05, 2.0, (sx + x, sy + 0.55, 0), m["logs"], root, seg=5)
        S.cyl(f"roof_post_b_{x}", 0.05, 0.05, 2.0, (sx + x, sy - 0.55, 0), m["logs"], root, seg=5)
    kit.gable_roof("windlass_roof", 2.0, 1.4, 0.7, 0.15, 2.0, m["shingle"], root).location = (sx, sy, 2.0)
    # Heaps of grey lead and silver ore, baskets, a small shed for the tools.
    ore = S.mat("galena", "#6f7176", 0.6, noise=0.5, metal=0.4)
    for i in range(10):
        S.rock(f"ore_{i}", 0.14, (1.3 + 0.18 * math.cos(i * 2.1), -1.25 + 0.18 * math.sin(i * 2.1), 0.08 + 0.05 * (i % 3)),
               ore, root, seed=30 + i)
    for i, (x, y) in enumerate([(0.3, -1.5), (-0.3, -1.6)]):
        S.cyl(f"basket_{i}", 0.24, 0.28, 0.4, (x, y, 0), m["wicker"], root, seg=10)
        for k in range(3):
            S.rock(f"basket_ore_{i}_{k}", 0.1, (x + 0.08 * math.cos(k * 2), y + 0.08 * math.sin(k * 2), 0.42), ore,
                   root, seed=50 + i * 3 + k)
    S.box("basket_band", (0.3, 0.05, 0.08), (0.3, -1.77, 0.25), m["team"], root)
    kit.posts_shed("shed", 1.4, 1.0, 1.7, m["shingle"], root, (-1.25, 1.35, 0), m, posts_mat=m["logs_old"])
    for i in range(3):
        S.cyl(f"tool_{i}", 0.02, 0.02, 1.2, (-1.6 + i * 0.25, 1.1, 0), m["logs"], root, rot=(-0.25, 0, 0), seg=4)
    crown_flag(root, (1.8, 1.8, 0), 3.6, m)
    return root


# --- the army ------------------------------------------------------------------------------

def pl_barracks():
    m = _m()
    root = S.empty("pl_barracks")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    hall = S.empty("hall", (-0.2, 1.1, 0), root)
    w, d = 5.0, 2.8
    S.box("hall_plinth", (w + 0.2, d + 0.2, 0.7), (0, 0, 0.35), m["stone"], hall)
    _srub("hall", w, d, 2.1, 0.13, 0.7, m["logs"], hall, seed=91)
    kit.gable_roof("hall_roof", w, d, 1.8, 0.4, 2.85, m["shingle"], hall)
    for x in (-w / 2, w / 2):
        kit.gable_wall(f"hall_gable_{x}", d + 0.1, 1.75, (x, 0, 2.85), math.pi / 2, m["plank"], hall)
    kit.window("hall_door", 0.85, 1.6, (0.9, -d / 2 - 0.14, 0.7), 0.0, m["door"], hall)
    for i, x in enumerate((-1.7, -0.4)):
        kit.window(f"hall_win_{i}", 0.4, 0.45, (x, -d / 2 - 0.14, 1.85), 0.0, m["dark"], hall)
    kit.window("hall_ewin", 0.4, 0.45, (w / 2 + 0.14, 0.0, 1.85), math.pi / 2, m["dark"], hall)
    # Pavises with the White Eagle along the front wall, a spear rack, a pell, a bench.
    for i in range(3):
        _pavise_prop(f"pavise_{i}", (-2.0 + i * 0.75, -0.55, 0.0), 0.0, m, root)
    buildings_gdl._spear_rack("rack", (1.9, -0.6, 0), math.pi / 2, m, root, count=4)
    S.cyl("pell", 0.12, 0.11, 1.5, (1.0, -2.2, 0), m["logs_old"], root, seg=7)
    S.cyl("bench", 0.13, 0.13, 1.5, (-1.6, -2.3, 0.13), m["logs"], root, rot=(0, math.pi / 2, 0.1), seg=7)
    kit.rail_fence("yard_fence", [(-2.9, -1.4), (-2.9, -2.9), (2.9, -2.9), (2.9, -1.2)], m["logs_old"], root, h=0.8)
    crown_flag(root, (2.6, 2.6, 0), 4.6, m)
    return root


def pl_range():
    m = _m()
    root = S.empty("pl_range")
    kit.yard(3.0, 3.0, m["meadow"]).parent = root
    kit.posts_shed("shed", 3.4, 1.6, 2.1, m["shingle"], root, (1.0, 1.9, 0), m, posts_mat=m["logs_old"])
    rack = S.empty("bow_rack", (1.0, 1.6, 0), root)
    S.cyl("bow_bar", 0.04, 0.04, 2.4, (-1.2, 0, 1.3), m["logs"], rack, rot=(0, math.pi / 2, 0), seg=5)
    bow = S.mat("bow", "#5b3b22", 0.6)
    for i in range(3):
        S.cyl(f"bow_{i}", 0.02, 0.015, 1.7, (-1.0 + i * 0.4, -0.05, 0.4), bow, rack, rot=(0.08, 0, 0), seg=5)
    stock = S.mat("crossbow", "#6b4a2c", 0.7)
    for i in range(3):
        cb = S.empty(f"crossbow_{i}", (0.35 + i * 0.35, -0.12, 0.25), rack)
        cb.rotation_euler = (-0.15, 0, 0)
        S.box(f"cb_stock_{i}", (0.06, 0.06, 0.85), (0, 0, 0.42), stock, cb)
        S.box(f"cb_bow_{i}", (0.6, 0.05, 0.05), (0, 0, 0.8), m["iron"], cb)
    for i in range(3):
        buildings_gdl._target(f"target_{i}", (-2.2 + i * 0.25, 1.9 - i * 1.6, 0), m, root)
        S.box(f"bale_{i}", (0.8, 0.5, 0.45), (-2.5, 2.4 - i * 1.6, 0.22), m["hay"], root)
    kit.rail_fence("line", [(2.6, -2.7), (2.6, 0.6)], m["logs_old"], root, h=0.8)
    for i in range(4):
        S.cyl(f"arrow_{i}", 0.01, 0.01, 0.8, (-1.95 + i * 0.05, -1.5 + i * 0.1, 1.05), m["logs"], root,
              rot=(0, math.pi / 2 + 0.1, math.pi), seg=4)
    crown_flag(root, (2.7, 2.7, 0), 3.8, m)
    return root


def pl_stable():
    m = _m()
    root = S.empty("pl_stable")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    st = S.empty("stable", (0.3, 1.7, 0), root)
    _srub("wall", 4.8, 2.1, 1.75, 0.12, 0.04, m["logs"], st, seed=95)
    _thatch_roof("roof", 4.8, 2.1, 1.5, 0.45, 1.8, st)
    for x in (-2.4, 2.4):
        kit.gable_wall(f"gable_{x}", 2.2, 1.45, (x, 0, 1.8), math.pi / 2, m["plank"], st)
    for i, x in enumerate((-1.5, 0.0, 1.5)):
        kit.window(f"stall_{i}", 0.9, 1.3, (x, -1.13, 0.1), 0.0, m["door"] if i == 1 else m["dark"], st)
    # An open hay barn on the left, under thatch.
    kit.posts_shed("barn", 1.6, 2.2, 2.0, m["thatch"], root, (-2.1, 0.1, 0), m, lean=False, posts_mat=m["logs_old"])
    S.box("barn_hay", (1.4, 1.9, 1.1), (-2.1, 0.1, 0.55), m["hay"], root)
    kit.rail_fence("paddock", [(-1.1, -2.8), (2.8, -2.8), (2.8, 0.4)], m["logs_old"], root)
    S.box("trough", (1.2, 0.4, 0.35), (1.0, -0.4, 0.18), m["logs_old"], root)
    S.box("trough_water", (1.05, 0.28, 0.02), (1.0, -0.4, 0.35), S.mat("water", "#2c3a40", 0.1), root)
    S.box("saddle_cloth", (0.5, 0.05, 0.45), (2.83, -1.4, 0.7), m["team"], root)
    crown_flag(root, (2.7, 2.7, 0), 3.8, m)
    return root


# --- faith ---------------------------------------------------------------------------------

def pl_shrine():
    rng = random.Random(12)
    m = _m()
    root = S.empty("pl_shrine")
    S.box("yard", (3.2, 3.2, 0.04), (0, 0, 0.02), m["meadow"])
    S.ball("mound", 1.0, (0.0, 0.0, 0.0), S.mat("mound_grass", "#647040", 1.0, noise=0.35), root,
           scale=(1.15, 1.15, 0.28), seg=16)
    for i in range(7):
        a = i * math.tau / 7 + 0.3
        S.rock(f"stone_{i}", rng.uniform(0.13, 0.2), (1.05 * math.cos(a), 1.05 * math.sin(a), 0.05), m["stone"], root,
               seed=i + 40)
    _wooden_cross("cross", (0, 0, 0.2), 4.0, m, root)
    _picket("fence", [(-1.45, -1.45), (1.45, -1.45), (1.45, 1.45), (-1.45, 1.45), (-1.45, -0.6)], m, root, h=0.6)
    for i, (x, y, c) in enumerate([(-0.45, -0.55, "#d8c040"), (0.4, -0.6, "#c04848"), (0.6, -0.2, "#e8e4d8")]):
        S.ball(f"flowers_{i}", 0.12, (x, y, 0.25), S.mat(f"flower_{i}", c, 0.9, noise=0.3), root, scale=(1, 1, 0.6))
    S.cyl("candle", 0.04, 0.04, 0.16, (0.15, -0.35, 0.27), m["canvas"], root, seg=6)
    return root


def pl_shrine_chapel():
    m = _m()
    root = S.empty("pl_shrine_chapel")
    kit.yard(2.0, 2.0, m["meadow"]).parent = root
    w, d, h = 2.1, 2.7, 2.5
    ch = _chata("chapel", w, d, h, m, root, loc=(0.25, 0.4, 0), base="brick", base_h=0.35, quoins="brick")
    top = 0.35 + h + 0.12
    kit.gable_roof("chapel_roof", w, d, 2.6, 0.25, top, m["shingle"], ch, along_y=True)
    kit.gable_wall("chapel_gable", w + 0.1, 2.55, (0, -d / 2, top), 0.0, m["whitewash"], ch, thick=0.1)
    kit.gable_wall("chapel_gable_back", w + 0.1, 2.55, (0, d / 2, top), 0.0, m["whitewash"], ch, thick=0.1)
    kit.window("chapel_door", 0.8, 1.7, (0, -d / 2 - 0.03, 0.35), 0.0, m["door"], ch, pointed=True)
    S.cyl("chapel_oculus", 0.2, 0.2, 0.06, (0, -d / 2 - 0.07, top + 0.9), m["dark"], ch, rot=(math.pi / 2, 0, 0), seg=12)
    kit.window("chapel_ewin", 0.35, 0.95, (w / 2 + 0.03, 0.2, 1.2), math.pi / 2, m["dark"], ch, pointed=True)
    S.box("chapel_banner", (0.42, 0.04, 0.75), (-0.75, -d / 2 - 0.06, 1.3), m["team"], ch)
    # The little bell turret (sygnaturka) on the front of the ridge, a spire and an iron cross.
    tw = S.empty("turret", (0, -0.55, top + 2.35), ch)
    S.box("turret_roof_base", (0.5, 0.5, 0.75), (0, 0, 0.2), m["shingle"], tw)
    bronze = S.mat("bell_bronze", "#8a6a2e", 0.45, metal=0.8)
    S.cyl("turret_roof_bell", 0.13, 0.06, 0.22, (0, 0, 0.45), bronze, tw, seg=10)
    for i, (x, y) in enumerate(((-0.2, -0.2), (0.2, -0.2), (0.2, 0.2), (-0.2, 0.2))):
        S.cyl(f"turret_roof_post_{i}", 0.035, 0.035, 0.45, (x, y, 0.55), m["logs"], tw, seg=5)
    S.cyl("turret_roof_spire", 0.32, 0.02, 1.1, (0, 0, 1.0), m["shingle"], tw, seg=8, smooth=False)
    S.box("turret_roof_cross_v", (0.05, 0.05, 0.42), (0, 0, 2.25), m["iron"], tw)
    S.box("turret_roof_cross_h", (0.24, 0.05, 0.05), (0, 0, 2.33), m["iron"], tw)
    # The old wayside cross stays at the front left, smaller, with its sash; a short fence.
    _wooden_cross("cross", (-1.35, -1.35, 0), 2.6, m, root)
    _picket("fence", [(-1.9, -0.5), (-1.9, -1.9), (0.6, -1.9)], m, root, h=0.6)
    return root


def pl_temple():
    m = _m()
    root = S.empty("pl_temple")
    kit.yard(3.0, 3.0, m["meadow"]).parent = root
    # The nave along X, the lower chancel to the east (front right), the tower to the west.
    nw, nd, nh = 3.7, 3.0, 4.8
    nave = S.empty("nave", (0.3, 0.5, 0), root)
    S.box("nave_plinth", (nw + 0.15, nd + 0.15, 0.45), (0, 0, 0.22), m["limestone"], nave)
    _bands("nave_walls", nw, nd, nh, 0.0, m["brick"], nave, bands=4)
    kit.gable_roof("nave_roof", nw, nd, 3.9, 0.15, nh, m["tile"], nave)
    S.box("nave_cornice", (nw + 0.1, nd + 0.1, 0.18), (0, 0, nh - 0.1), m["limestone"], nave)
    for x in (-1.2, 0.2):
        kit.window(f"nave_win_{x}", 0.5, 2.1, (x, -nd / 2 - 0.03, 1.5), 0.0, m["dark"], nave, pointed=True)
        S.box(f"nave_buttress_{x}", (0.35, 0.4, 3.4), (x + 0.65, -nd / 2 - 0.2, 1.7), m["brick_dark"], nave)
        S.box(f"nave_buttress_cap_{x}", (0.37, 0.42, 0.12), (x + 0.65, -nd / 2 - 0.2, 3.45), m["limestone"], nave)
    # The porch (kruchta) on the south side with its pointed door and a little gable.
    porch = S.empty("porch", (-1.0 + 0.3, -nd / 2 + 0.5 - 0.9, 0), root)
    _bands("porch_walls", 1.3, 1.0, 2.6, 0.0, m["brick"], porch, bands=2)
    kit.gable_roof("porch_roof", 1.3, 1.0, 1.0, 0.1, 2.6, m["tile"], porch, along_y=True)
    kit.gable_wall("porch_gable", 1.3, 1.0, (0, -0.5, 2.6), 0.0, m["brick"], porch, thick=0.14)
    kit.window("porch_door", 0.7, 1.7, (0, -0.53, 0.0), 0.0, m["door"], porch, pointed=True)
    S.box("porch_niche", (0.25, 0.04, 0.45), (0, -0.62, 2.85), m["whitewash"], porch)
    S.box("banner", (0.5, 0.04, 0.9), (0.95, -nd / 2 - 0.05, 2.3), m["team"], nave)
    # The chancel: lower and narrower, a brick gable with white niches and a cross to the east.
    cw, cd, chh = 1.8, 2.3, 4.0
    chan = S.empty("chancel", (nw / 2 + cw / 2 + 0.3, 0.5, 0), root)
    S.box("chancel_plinth", (cw + 0.15, cd + 0.15, 0.45), (0, 0, 0.22), m["limestone"], chan)
    _bands("chancel_walls", cw, cd, chh, 0.0, m["brick"], chan, bands=3)
    kit.gable_roof("chancel_roof", cw, cd, 3.0, 0.12, chh, m["tile"], chan)
    kit.gable_wall("chancel_gable", cd + 0.24, 3.0, (cw / 2 + 0.05, 0, chh), math.pi / 2, m["brick"], chan, thick=0.2)
    for k, y in enumerate((-0.5, 0.0, 0.5)):
        hh = 1.9 - abs(y) * 1.6
        S.box(f"chancel_gable_niche_{k}", (0.05, 0.26, hh), (cw / 2 + 0.17, y, chh + 0.25 + hh / 2), m["whitewash"],
              chan)
    kit.window("chancel_ewin", 0.45, 1.9, (cw / 2 + 0.03, 0, 1.3), math.pi / 2, m["dark"], chan, pointed=True)
    kit.window("chancel_win", 0.42, 1.8, (0, -cd / 2 - 0.03, 1.3), 0.0, m["dark"], chan, pointed=True)
    S.box("chancel_gable_cross_v", (0.08, 0.08, 0.7), (cw / 2 + 0.05, 0, chh + 3.25), m["iron"], chan)
    S.box("chancel_gable_cross_h", (0.08, 0.36, 0.08), (cw / 2 + 0.05, 0, chh + 3.4), m["iron"], chan)
    # The west tower: square brick in three stages with pairs of white niches, the bell
    # openings, a stone cornice and a tall green copper octagonal spire with a gilt ball.
    tw = S.empty("tower", (-nw / 2 - 0.85 + 0.3, 0.5, 0), root)
    ts, th = 2.1, 9.6
    S.box("tower_plinth", (ts + 0.15, ts + 0.15, 0.5), (0, 0, 0.25), m["limestone"], tw)
    _bands("tower_shaft", ts, ts, th, 0.0, m["brick"], tw, bands=5)
    for z in (3.6, 6.2):
        S.box(f"tower_band_{z}", (ts + 0.08, ts + 0.08, 0.14), (0, 0, z), m["limestone"], tw)
        for x in (-0.45, 0.45):
            S.box(f"tower_niche_s_{z}_{x}", (0.4, 0.05, 1.6), (x, -ts / 2 - 0.02, z + 1.0), m["whitewash"], tw)
            S.box(f"tower_niche_e_{z}_{x}", (0.05, 0.4, 1.6), (ts / 2 + 0.02, x, z + 1.0), m["whitewash"], tw)
    for x in (-0.4, 0.4):
        kit.window(f"tower_bell_s_{x}", 0.36, 1.1, (x, -ts / 2 - 0.03, 7.9), 0.0, m["dark"], tw, pointed=True)
        kit.window(f"tower_bell_e_{x}", 0.36, 1.1, (ts / 2 + 0.03, x, 7.9), math.pi / 2, m["dark"], tw, pointed=True)
    kit.window("tower_door", 0.75, 1.9, (0, -ts / 2 - 0.03, 0.0), 0.0, m["door"], tw, pointed=True)
    S.box("tower_cornice", (ts + 0.2, ts + 0.2, 0.2), (0, 0, th), m["limestone"], tw)
    spire = S.cyl("tower_roof_spire", 1.15, 0.03, 5.2, (0, 0, th + 0.1), m["copper"], tw, seg=8, smooth=False)
    spire.rotation_euler = (0, 0, math.pi / 8)
    S.ball("tower_roof_ball", 0.13, (0, 0, th + 5.35), m["gold"], tw)
    S.box("tower_roof_cross_v", (0.08, 0.08, 0.8), (0, 0, th + 5.8), m["gold"], tw)
    S.box("tower_roof_cross_h", (0.42, 0.08, 0.08), (0, 0, th + 5.95), m["gold"], tw)
    # A wooden cross in the churchyard and a low wall along the front.
    _wooden_cross("yard_cross", (2.5, -2.5, 0), 2.4, m, root, roofed=False, sash=False)
    S.box("yard_wall", (4.0, 0.3, 0.7), (-0.8, -2.85, 0.35), m["stone"], root)
    S.box("yard_wall_cap", (4.1, 0.38, 0.1), (-0.8, -2.85, 0.75), m["tile"], root)
    return root


# --- defence -------------------------------------------------------------------------------

def gate(vertical=False):
    """The palisade gate under a shingle roof, the White Eagle on a red field on the leaves."""

    def build():
        m = _m()
        root = S.empty("pl_gate")
        g = S.empty("gate", (0, 0, 0), root)
        g.rotation_euler = (0, 0, math.pi / 2 if vertical else 0.0)
        for x in (-0.92, 0.92):
            S.cyl(f"gate_post_{x}", 0.19, 0.18, 3.1, (x, 0, 0), m["logs"], g, seg=8)
        for x in (-0.42, 0.42):
            S.box(f"gate_leaf_{x}", (0.8, 0.1, 1.9), (x, -0.05, 1.0), m["plank"], g)
            S.box(f"gate_brace_{x}", (0.85, 0.06, 0.1), (x, -0.12, 0.55), m["logs_old"], g,
                  rot=(0, math.radians(35 if x < 0 else -35), 0))
        S.box("gate_field", (0.9, 0.04, 0.75), (0, -0.13, 1.35), m["court_red"], g)
        _white_eagle("gate_eagle", g, (0, -0.17, 1.37), 0.7, m)
        S.box("gate_floor", (2.3, 1.2, 0.14), (0, 0, 2.55), m["plank"], g)
        for x in (-1.1, 1.1):
            S.cyl(f"gate_railpost_{x}", 0.05, 0.05, 0.85, (x, -0.55, 2.62), m["logs"], g, seg=5)
            S.cyl(f"gate_roofpost_{x}", 0.05, 0.05, 1.5, (x, 0.5, 2.62), m["logs"], g, seg=5)
        S.box("gate_rail", (2.3, 0.08, 0.45), (0, -0.56, 3.1), m["plank"], g)
        kit.gable_roof("gate_roof", 2.4, 1.3, 0.75, 0.15, 4.05, m["shingle"], g)
        S.box("gate_mark", (0.5, 0.04, 0.3), (0, -0.62, 3.1), m["team"], g)
        return root

    return build


def pl_tower():
    m = _m()
    root = S.empty("pl_tower")
    t = S.empty("tower", (0, 0, 0), root)
    S.box("footing", (2.2, 2.2, 1.2), (0, 0, 0.6), m["stone"], t)
    _bands("shaft", 1.9, 1.9, 5.4, 1.2, m["brick"], t, bands=4)
    for z in (1.25, 3.9):
        S.box(f"band_{z}", (1.98, 1.98, 0.14), (0, 0, z), m["limestone"], t)
    for z in (2.6, 4.6):
        kit.window(f"slit_s_{z}", 0.12, 0.6, (0.35, -0.98, z), 0.0, m["dark"], t)
        kit.window(f"slit_e_{z}", 0.12, 0.6, (0.98, -0.35, z), math.pi / 2, m["dark"], t)
    kit.window("door", 0.7, 1.4, (-0.35, -1.13, 0.0), 0.0, m["door"], t, pointed=True)
    # The overhanging timber hoarding with loopholes, a steep shingle pyramid roof.
    g, z0 = 1.3, 6.6
    for i, x in enumerate((-0.6, 0.6)):
        S.box(f"beam_x_{i}", (2 * g + 0.2, 0.16, 0.16), (0, x, z0 - 0.08), m["logs_old"], t)
        S.box(f"beam_y_{i}", (0.16, 2 * g + 0.2, 0.16), (x, 0, z0 - 0.24), m["logs_old"], t)
    S.box("gallery_floor", (2 * g, 2 * g, 0.12), (0, 0, z0 + 0.06), m["plank"], t)
    for i, (x, y, w, d) in enumerate([(0, -g, 2 * g, 0.1), (0, g, 2 * g, 0.1), (-g, 0, 0.1, 2 * g),
                                      (g, 0, 0.1, 2 * g)]):
        S.box(f"gallery_wall_{i}", (w, d, 1.1), (x, y, z0 + 0.65), m["plank"], t)
    for k in (-0.6, 0.0, 0.6):
        kit.window(f"loop_s_{k}", 0.13, 0.35, (k, -g - 0.06, z0 + 0.55), 0.0, m["dark"], t)
        kit.window(f"loop_e_{k}", 0.13, 0.35, (g + 0.06, k, z0 + 0.55), math.pi / 2, m["dark"], t)
    for i, (x, y) in enumerate([(-g, -g), (g, -g), (g, g), (-g, g)]):
        S.cyl(f"roof_post_{i}", 0.06, 0.06, 1.5, (x * 0.95, y * 0.95, z0 + 0.1), m["logs"], t, seg=6)
    kit.hip_roof("roof", 2 * g, 2 * g, 2.6, 0.25, z0 + 1.6, m["shingle"], t)
    S.box("shield_mark", (0.6, 0.05, 0.45), (0, -g - 0.08, z0 + 0.65), m["team"], t)
    crown_flag(t, (0, 0, z0 + 4.0), 1.7, m)
    return root


def pl_castle():
    m = _m()
    root = S.empty("pl_castle")
    kit.yard(4.0, 4.0, m["cobble"]).parent = root
    e = 3.55
    wall_h = 4.2
    stone_h = 1.4

    def curtain(name, x0, y0, x1, y1, out=(0, -1), merlons=True):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        S.box(f"{name}_stone", (length, 0.75, stone_h), (cx, cy, stone_h / 2), m["stone"], root, rot=(0, 0, ang))
        S.box(f"{name}_brick", (length, 0.65, wall_h - stone_h), (cx, cy, stone_h + (wall_h - stone_h) / 2), m["brick"],
              root, rot=(0, 0, ang))
        if merlons:
            n = int(length / 0.7)
            for k in range(n):
                t = (k + 0.5) / n
                S.box(f"{name}_merlon_{k}", (0.38, 0.3, 0.5), (x0 + (x1 - x0) * t + 0.2 * out[0],
                                                                y0 + (y1 - y0) * t + 0.2 * out[1], wall_h + 0.25),
                      m["brick"], root, rot=(0, 0, ang))

    curtain("wall_s_l", -e, -e, -1.1, -e)
    curtain("wall_s_r", 1.1, -e, e, -e)
    curtain("wall_e", e, -e, e, e, out=(1, 0))
    curtain("wall_n", e, e, -e, e, out=(0, 1))
    curtain("wall_w", -e, e, -e, -e, out=(-1, 0))

    def round_tower(name, x, y, h, r=0.95, roof=False):
        S.cyl(f"{name}_foot", r + 0.12, r, stone_h + 0.3, (x, y, 0), m["stone"], root, seg=14)
        S.cyl(f"{name}_shaft", r, r, h - stone_h - 0.3, (x, y, stone_h + 0.3), m["brick"], root, seg=14)
        S.cyl(f"{name}_band", r + 0.08, r + 0.08, 0.16, (x, y, h - 1.4), m["limestone"], root, seg=14)
        for k in range(3):
            a = math.radians(-60 + k * 60)
            kit.window(f"{name}_slit_{k}", 0.12, 0.6, (x + (r + 0.02) * math.cos(a - math.pi / 4),
                                                       y + (r + 0.02) * math.sin(a - math.pi / 4), h * 0.45),
                       a - math.pi / 4 + math.pi / 2, m["dark"], root)
        if roof:
            S.cyl(f"{name}_roof", r + 0.25, 0.02, 3.2, (x, y, h), m["tile"], root, seg=14, smooth=False)
        else:
            S.cyl(f"{name}_parapet", r + 0.15, r + 0.15, 0.5, (x, y, h - 0.2), m["brick"], root, seg=14)
            for k in range(8):
                a = k * math.tau / 8
                S.box(f"{name}_merlon_{k}", (0.32, 0.3, 0.45), (x + (r + 0.05) * math.cos(a), y + (r + 0.05) * math.sin(a),
                                                                h + 0.5), m["brick"], root, rot=(0, 0, a))

    round_tower("tower_se", e, -e, 6.0)
    round_tower("tower_sw", -e, -e, 5.6)
    round_tower("tower_ne", e, e, 5.6)
    # The keep (stołp): tall and round at the back left, a conical red tile roof, the flag.
    round_tower("keep", -e + 0.35, e - 0.35, 10.5, r=1.25, roof=True)
    crown_flag(root, (-e + 0.35, e - 0.35, 13.6), 2.4, m)
    # The palace along the back: brick on a stone foot, a high tile roof, white stone frames.
    pal = S.empty("palace", (0.6, 1.95, 0), root)
    pw, pd, ph = 5.2, 2.5, 6.6
    S.box("palace_foot", (pw + 0.1, pd + 0.1, stone_h), (0, 0, stone_h / 2), m["stone"], pal)
    _bands("palace_walls", pw, pd, ph - stone_h, stone_h, m["brick"], pal, bands=4)
    kit.gable_roof("palace_roof", pw, pd, 3.0, 0.15, ph, m["tile"], pal)
    for x in (-pw / 2, pw / 2):
        kit.gable_wall(f"palace_gable_{x}", pd + 0.05, 3.0, (x, 0, ph), math.pi / 2, m["brick"], pal, thick=0.2)
    S.box("palace_cornice", (pw + 0.12, pd + 0.12, 0.16), (0, 0, ph - 0.1), m["limestone"], pal)
    for i, x in enumerate((-1.8, -0.6, 0.6, 1.8)):
        for z in (3.0, 4.9):
            kit.window(f"palace_win_{i}_{z}", 0.5, 0.9, (x, -pd / 2 - 0.04, z), 0.0, m["dark"], pal)
            S.box(f"palace_frame_{i}_{z}", (0.66, 0.05, 1.06), (x, -pd / 2 - 0.02, z + 0.45), m["limestone"], pal)
    kit.window("palace_door", 0.9, 1.8, (0.0, -pd / 2 - 0.04, 0.0), 0.0, m["door"], pal, pointed=True)
    S.box("palace_door_frame", (1.15, 0.05, 2.1), (0.0, -pd / 2 - 0.02, 1.0), m["limestone"], pal)
    S.box("palace_banner", (0.6, 0.05, 1.3), (2.35, -pd / 2 - 0.06, 3.6), m["team"], pal)
    # A lower service wing along the right wall.
    wing = S.empty("wing", (2.45, -0.6, 0), root)
    _bands("wing_walls", 1.6, 3.2, 3.2, 0.0, m["brick"], wing, bands=2)
    kit.gable_roof("wing_roof", 1.6, 3.2, 1.5, 0.12, 3.2, m["tile"], wing, along_y=True)
    # The gatehouse: a square brick tower on the front wall, a stone pointed portal, the Eagle
    # on a red shield over it, a high hipped tile roof.
    gh = S.empty("gatehouse", (0, -e, 0), root)
    S.box("gatehouse_stone", (2.4, 1.6, stone_h), (0, 0, stone_h / 2), m["stone"], gh)
    _bands("gatehouse_walls", 2.2, 1.5, 6.3 - stone_h, stone_h, m["brick"], gh, bands=3)
    kit.window("gatehouse_arch", 1.2, 2.5, (0, -0.79, 0.0), 0.0, m["door"], gh, pointed=True)
    S.box("gatehouse_portal", (1.6, 0.06, 2.9), (0, -0.77, 1.45), m["limestone"], gh)
    S.box("gatehouse_shield", (0.75, 0.05, 0.85), (0, -0.82, 3.7), m["court_red"], gh)
    _white_eagle("gatehouse_eagle", gh, (0, -0.86, 3.72), 0.75, m)
    S.box("gatehouse_banner", (0.45, 0.05, 0.9), (0.85, -0.82, 4.7), m["team"], gh)
    S.box("gatehouse_cornice", (2.3, 1.6, 0.16), (0, 0, 6.3), m["limestone"], gh)
    kit.hip_roof("gatehouse_roof", 2.2, 1.5, 2.4, 0.15, 6.35, m["tile"], gh)
    return root


def pl_battery():
    """A gun battery: a half ring of wicker gabions filled with earth round a plank floor that
    opens to the back, a pyramid of stone balls, a rammer on the planks."""
    m = _m()
    root = S.empty("pl_battery")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    for i in range(7):
        S.box(f"plank_{i}", (0.42, 2.8, 0.08), (-1.3 + i * 0.43, 0.25, 0.08), m["plank"], root,
              rot=(0, 0, 0.01 * (i % 3 - 1)))
    cx, cy, rad = 0.0, 0.45, 1.55
    fill = S.mat("gabion_earth", "#5e4a32", 1.0, noise=0.4)
    band = S.mat("wicker_band", "#6e5634", 1.0, noise=0.5)
    for i in range(9):
        a = math.radians(170 + i * 25)
        x, y = cx + rad * math.cos(a), cy + rad * math.sin(a)
        S.cyl(f"gabion_{i}", 0.33, 0.33, 1.05, (x, y, 0), m["wicker"], root, seg=12)
        S.cyl(f"gabion_{i}_band", 0.345, 0.345, 0.08, (x, y, 0.55), band, root, seg=12)
        S.ball(f"gabion_{i}_earth", 0.3, (x, y, 1.03), fill, root, scale=(1, 1, 0.35), seg=10)
    S.box("gabion_cloth", (0.05, 0.4, 0.35), (cx + rad + 0.34, cy, 0.7), m["team"], root)
    # The stone balls in a pyramid on the floor, a rammer lying on the planks.
    k = 0
    for layer, n in enumerate((3, 2, 1)):
        for i in range(n):
            for j in range(n):
                S.ball(f"ball_{k}", 0.15, (-0.9 + 0.31 * i + 0.155 * layer, 1.1 + 0.31 * j + 0.155 * layer,
                                           0.27 + 0.25 * layer), m["stone_ball"], root, seg=10)
                k += 1
    rammer = S.cyl("rammer", 0.03, 0.03, 2.0, (-0.2, 0.2, 0.16), m["logs"], root, rot=(0, math.pi / 2, 0.5), seg=5)
    S.cyl("rammer_head", 0.09, 0.09, 0.22, (0, 0, 2.0), m["logs_old"], rammer, seg=8)
    crown_flag(root, (1.75, 1.85, 0), 2.8, m)
    return root


# --- trade and craft -----------------------------------------------------------------------

def _stall(name, loc, rot_z, m, parent, stripe):
    """A market stall: a table, four posts and a sloping awning in red and white stripes."""
    s = S.empty(name, loc, parent)
    s.rotation_euler = (0, 0, rot_z)
    S.box(f"{name}_table", (1.4, 0.7, 0.08), (0, 0, 0.8), m["plank"], s)
    for x in (-0.65, 0.65):
        for y in (-0.3, 0.3):
            S.cyl(f"{name}_leg_{x}_{y}", 0.04, 0.04, 0.8, (x, y, 0), m["logs"], s, seg=5)
            S.cyl(f"{name}_post_{x}_{y}", 0.035, 0.035, 2.0 if y > 0 else 1.7, (x * 1.05, y * 1.4, 0), m["logs"], s,
                  seg=5)
    for k in range(5):
        mat = stripe if k % 2 == 0 else m["canvas"]
        S.box(f"{name}_roof_{k}", (0.3, 1.2, 0.03), (-0.6 + k * 0.3, 0.0, 1.85), mat, s, rot=(-0.25, 0, 0))
    return s


def pl_market():
    m = _m()
    root = S.empty("pl_market")
    kit.yard(3.0, 3.0, m["cobble"]).parent = root
    # The cloth hall (sukiennice): a long whitewashed timber hall with an arcade along its front.
    w, d, h = 4.8, 2.0, 2.6
    hall = _chata("hall", w, d, h, m, root, loc=(-0.1, 1.9, 0), base="stone", base_h=0.3)
    kit.gable_roof("hall_roof", w, d + 1.2, 2.0, 0.3, 0.3 + h + 0.12, m["shingle"], hall).location.y = -0.6
    for x in (-w / 2, w / 2):
        kit.gable_wall(f"hall_gable_{x}", d + 1.2, 1.95, (x, -0.6, 0.3 + h + 0.12), math.pi / 2, m["whitewash"], hall)
    for i, x in enumerate((-2.2, -1.1, 0.0, 1.1, 2.2)):
        S.cyl(f"arcade_post_{i}", 0.09, 0.08, h + 0.42, (x, -d / 2 - 1.15, 0), m["timber"], hall, seg=7)
        if i < 4:
            kit.window(f"hall_door_{i}", 0.7, 1.5, (x + 0.55, -d / 2 - 0.03, 0.3), 0.0, m["door"], hall)
    S.box("arcade_beam", (w + 0.2, 0.16, 0.16), (0, -d / 2 - 1.15, h + 0.38), m["timber"], hall)
    for i, (x, c) in enumerate([(-1.6, "#3d4f7a"), (-1.2, "#c8bfa8"), (0.4, "#7a3030"), (0.8, None)]):
        mat = m["team"] if c is None else S.mat(f"bolt_{i}", c, 0.95, noise=0.2)
        S.cyl(f"bolt_{i}", 0.12, 0.12, 0.7, (x, 0.0 + 0.45, 0.42), mat, root, rot=(0, math.pi / 2, 0), seg=8)
    S.box("bolt_bench", (2.8, 0.5, 0.3), (-0.4, 0.45, 0.15), m["plank"], root)
    _stall("stall_a", (-1.7, -1.4, 0), 0.0, m, root, m["court_red"])
    _stall("stall_b", (1.0, -1.9, 0), 0.0, m, root, m["court_red"])
    for i, (x, y) in enumerate([(2.3, -0.4), (2.6, -0.9), (2.2, 0.3)]):
        kit.barrel(f"barrel_{i}", (x, y, 0), m, root)
    scales = S.empty("scales", (0.0, -0.4, 0), root)
    S.cyl("scale_post", 0.06, 0.05, 1.6, (0, 0, 0), m["timber"], scales, seg=6)
    S.box("scale_beam", (1.1, 0.06, 0.06), (0, 0, 1.6), m["timber"], scales)
    for x in (-0.5, 0.5):
        S.cyl(f"scale_pan_{x}", 0.18, 0.2, 0.05, (x, 0, 1.0), m["iron"], scales, seg=10)
    crown_flag(root, (2.7, 2.7, 0), 4.6, m)
    return root


def pl_smithy():
    m = _m()
    root = S.empty("pl_smithy")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    sm = S.empty("smithy", (-0.8, 1.3, 0), root)
    S.box("smithy_footing", (3.6, 2.8, 0.3), (0, 0, 0.15), m["stone"], sm)
    _srub("smithy", 3.4, 2.6, 2.0, 0.12, 0.3, m["logs"], sm, seed=97)
    kit.gable_roof("smithy_roof", 3.4, 2.6, 1.6, 0.35, 2.3, m["shingle"], sm)
    for x in (-1.7, 1.7):
        kit.gable_wall(f"smithy_gable_{x}", 2.7, 1.55, (x, 0, 2.3), math.pi / 2, m["plank"], sm)
    kit.window("smithy_door", 0.85, 1.5, (-0.6, -1.44, 0.3), 0.0, m["door"], sm)
    S.box("chimney", (0.7, 0.7, 2.4), (0.9, 0.4, 3.0), m["stone"], sm)
    kit.posts_shed("canopy", 2.4, 1.8, 2.2, m["shingle"], root, (1.6, -0.9, 0), m, posts_mat=m["logs_old"])
    S.box("forge", (1.0, 0.8, 0.8), (1.9, -0.6, 0.4), m["stone"], root)
    S.box("forge_fire", (0.6, 0.5, 0.06), (1.9, -0.6, 0.82), m["fire"], root)
    S.box("bellows", (0.6, 0.4, 0.2), (2.6, -0.3, 0.6), S.mat("leather", "#5a3e28", 0.8), root, rot=(0, 0, 0.3))
    S.cyl("anvil_block", 0.22, 0.25, 0.5, (1.1, -1.4, 0), m["logs_old"], root, seg=8)
    S.box("anvil", (0.45, 0.18, 0.2), (1.1, -1.4, 0.6), m["iron"], root)
    kit.barrel("quench", (2.5, -1.7, 0), m, root)
    for i in range(3):
        S.box(f"bar_{i}", (0.05, 0.05, 1.0), (-0.4 + i * 0.1, -1.7, 0.5), m["iron"], root, rot=(0.25, 0, 0))
    kit.log_pile("charcoal_logs", (-2.2, -1.3, 0), 0.3, 1.2, 3, m, root, r=0.1)
    S.box("sign", (0.5, 0.05, 0.4), (0.9, -0.15, 2.2), m["team"], root)
    crown_flag(root, (-2.7, -2.6, 0), 3.8, m)
    return root


def pl_siege_workshop():
    m = _m()
    root = S.empty("pl_siege_workshop")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    kit.posts_shed("shed", 4.6, 2.8, 2.6, m["shingle"], root, (0, 1.2, 0), m, lean=False, posts_mat=m["logs_old"])
    # A bombard barrel with hoops resting on two trestles under the shed.
    for x in (-1.0, 0.9):
        for s in (-1, 1):
            S.box(f"trestle_{x}_{s}", (0.08, 0.08, 0.95), (x, 1.1 + s * 0.15, 0.42), m["logs_old"], root,
                  rot=(s * 0.35, 0, 0))
    barrel = S.cyl("bombard_barrel", 0.36, 0.33, 2.6, (-1.4, 1.1, 1.15), m["black_iron"], root,
                   rot=(0, math.pi / 2, 0), seg=14)
    for k in range(6):
        S.cyl(f"bombard_hoop_{k}", 0.39, 0.39, 0.1, (0, 0, 0.15 + k * 0.45), m["black_iron"], barrel, seg=14)
    S.cyl("bombard_mouth", 0.22, 0.22, 0.02, (0, 0, 2.6), m["dark"], barrel, seg=12)
    # A wooden bed half made, stone balls, a wheel, timber, ropes.
    S.box("bed_beam", (2.4, 0.3, 0.3), (0.3, -0.6, 0.15), m["logs"], root)
    S.box("bed_beam_b", (2.4, 0.3, 0.3), (0.3, -1.2, 0.15), m["logs"], root)
    for i in range(6):
        S.ball(f"ball_{i}", 0.18, (1.9 + 0.36 * (i % 3), -1.0 + 0.36 * (i // 3), 0.18), m["stone_ball"], root, seg=10)
    w = S.cyl("wheel", 0.55, 0.55, 0.1, (2.6, 0.6, 0.55), m["logs_old"], root, rot=(math.pi / 2 - 0.15, 0, math.pi / 2),
              seg=14)
    S.cyl("wheel_hub", 0.12, 0.12, 0.2, (0, 0, -0.05), m["iron"], w, seg=8)
    kit.log_pile("timber", (-1.3, -1.9, 0), 0.0, 2.6, 6, m, root)
    S.cyl("rope_coil", 0.3, 0.3, 0.12, (1.0, -2.3, 0), m["rope"], root, seg=12)
    S.box("rope_band", (0.3, 0.05, 0.08), (-1.3, -2.3, 0.3), m["team"], root)
    crown_flag(root, (2.7, -2.7, 0), 3.6, m)
    return root


def pl_salt_works():
    m = _m()
    root = S.empty("pl_salt_works")
    kit.yard(2.0, 2.0, S.mat("salt_yard", "#8a8070", 1.0, noise=0.35)).parent = root
    # The boiling house: whitewashed timber under shingles, a louvred vent on the ridge, steam.
    w, d, h = 2.6, 1.7, 1.8
    house = _chata("house", w, d, h, m, root, loc=(-0.55, 1.05, 0), base="stone", base_h=0.2)
    top = 0.2 + h + 0.12
    kit.gable_roof("house_roof", w, d, 1.3, 0.3, top, m["shingle"], house)
    for x in (-w / 2, w / 2):
        kit.gable_wall(f"house_gable_{x}", d + 0.1, 1.25, (x, 0, top), math.pi / 2, m["plank"], house)
    S.box("house_roof_vent", (1.2, 0.5, 0.35), (0, 0, top + 1.3), m["timber"], house)
    kit.gable_roof("house_roof_ventcap", 1.3, 0.7, 0.3, 0.08, top + 1.47, m["shingle"], house)
    kit.window("house_door", 0.75, 1.4, (0.5, -d / 2 - 0.03, 0.2), 0.0, m["door"], house)
    S.box("house_glow", (0.6, 0.04, 0.2), (0.5, -d / 2 - 0.05, 0.25), m["fire"], house)
    for k in range(4):
        S.ball(f"house_roof_steam_{k}", 0.32 + 0.12 * k, (0.15 * k - 0.1, 0.1 * k, top + 2.0 + 0.45 * k), m["steam"],
               house, scale=(1.2, 1.0, 0.8), seg=10)
    # The horse capstan over the brine well: a well curb, a drum on a post, a long sweep arm.
    wx, wy = 1.0, -0.8
    S.box("well_curb", (0.8, 0.8, 0.5), (wx, wy, 0.25), m["logs"], root)
    S.box("well_brine", (0.6, 0.6, 0.02), (wx, wy, 0.5), S.mat("brine", "#3a4a4e", 0.15), root)
    S.cyl("capstan_post", 0.1, 0.09, 2.1, (wx + 0.65, wy + 0.65, 0), m["logs_old"], root, seg=8)
    S.cyl("capstan_drum", 0.25, 0.25, 0.5, (wx + 0.65, wy + 0.65, 1.2), m["logs"], root, seg=12)
    S.cyl("capstan_arm", 0.05, 0.05, 2.0, (wx + 0.65, wy + 0.65, 1.0), m["logs_old"], root,
          rot=(0, math.pi / 2, math.radians(200)), seg=6)
    S.cyl("capstan_rope", 0.012, 0.012, 1.0, (wx, wy, 0.45), m["rope"], root, rot=(math.radians(35), 0, math.radians(45)),
          seg=3)
    S.cyl("capstan_ring", 1.35, 1.35, 0.01, (wx + 0.65, wy + 0.65, 0.04), m["earth"], root, seg=24)
    # Barrels and white salt cones (heads of salt) on a plank, a team band on a barrel.
    for i, (x, y) in enumerate([(-1.6, -0.6), (-1.25, -1.0), (-1.65, -1.35)]):
        kit.barrel(f"barrel_{i}", (x, y, 0), m, root, r=0.24, h=0.6)
    S.box("barrel_band", (0.06, 0.4, 0.07), (-1.39, -0.6, 0.35), m["team"], root)
    S.box("cone_board", (1.1, 0.4, 0.06), (-0.3, -1.55, 0.2), m["plank"], root)
    for i in range(4):
        S.cyl(f"salt_cone_{i}", 0.13, 0.03, 0.42, (-0.7 + i * 0.27, -1.55, 0.23), m["salt"], root, seg=10)
    crown_flag(root, (1.8, 1.8, 0), 3.4, m)
    return root


def _palisade(arm):
    return buildings_gdl.palisade_piece(arm)


BUILDINGS = {
    "pl_town_center": (pl_town_center, (4, 4), 9),
    "pl_house": (pl_house, (2, 2), 6),
    "pl_granary": (pl_granary, (2, 2), 6),
    "pl_farm": (pl_farm, (3, 3), 2),
    "pl_lumber_yard": (pl_lumber_yard, (2, 2), 5),
    "pl_mine": (pl_mine, (2, 2), 6),
    "pl_barracks": (pl_barracks, (3, 3), 7),
    "pl_range": (pl_range, (3, 3), 5),
    "pl_stable": (pl_stable, (3, 3), 5),
    "pl_shrine": (pl_shrine, (2, 2), 6),
    "pl_shrine_chapel": (pl_shrine_chapel, (2, 2), 9),
    "pl_gate": (gate(), (1, 1), 6),
    "pl_gate_v": (gate(True), (1, 1), 6),
    "pl_palisade": (_palisade(""), (1, 1), 3),
    "pl_tower": (pl_tower, (1, 1), 13),
    "pl_market": (pl_market, (3, 3), 7),
    "pl_smithy": (pl_smithy, (3, 3), 7),
    "pl_temple": (pl_temple, (3, 3), 17),
    "pl_siege_workshop": (pl_siege_workshop, (3, 3), 6),
    "pl_castle": (pl_castle, (4, 4), 16),
    "pl_salt_works": (pl_salt_works, (2, 2), 7),
    "pl_battery": (pl_battery, (2, 2), 3),
}
for _arm in "ewns":
    BUILDINGS[f"pl_palisade_{_arm}"] = (_palisade(_arm), (1, 1), 3)
