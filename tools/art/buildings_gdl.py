"""Buildings of the Grand Duchy (visual assets doc, «Общие здания» and «Особые здания»):
wood everywhere, log frames (срубы), palisades, shingle and thatch.

- gdl_granary: a log granary on posts, sacks at the door.
- gdl_farm: «Подсека», a field among stumps and burnt ground.
- gdl_lumber_yard: a shed, stacks of logs, trestles for sawing.
- gdl_mine: «Рудница», a bloomery furnace, baskets of bog ore, charcoal.
- gdl_barracks: «Ратный двор», a long log house, racks with spears and shields.
- gdl_range: a shooting ground: a shed, straw targets, bows on racks.
- gdl_stable: a long log stable, a paddock, hay.
- gdl_shrine: «Алка», a sacred grove: an oak, stones, a fire, a fence, offerings; no idols.
- gdl_palisade: sharpened logs; a cell is a post cluster plus arms toward its neighbours.
- gdl_zaseka: an abatis of trees felled with their crowns toward the enemy, sharpened boughs.
- gdl_siege_workshop: a shed, an unfinished cart, logs, ropes, wheels.
- gdl_bort: a living pine with a hollowed hive closed by a board, a rope and a climbing iron.
- gdl_gate: a wooden gate in the palisade with a platform over it.
"""

import math
import random

from tools.art import kit
from tools.art import shapes as S


def _stakes_line(prefix, x0, y0, x1, y1, m, parent, seed=0, h=1.55, r=0.13):
    """Sharpened logs standing side by side from (x0, y0) to (x1, y1)."""
    rng = random.Random(seed)
    length = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(length / (r * 1.9)))
    for i in range(n):
        t = (i + 0.5) / n
        hgt = h + rng.uniform(-0.12, 0.12)
        st = S.cyl(f"{prefix}_{i}", r, r * 0.9, hgt, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0),
                   m["logs"], parent, seg=7)
        S.cyl(f"{prefix}_{i}_tip", r * 0.9, 0.01, 0.3, (0, 0, hgt), m["logs"], st, seg=7)


def palisade_piece(arm):
    """One piece of a palisade cell: "" is the post cluster in the middle, "e", "w", "n", "s"
    the half-cell arm toward that neighbour (+X, -X, +Y, -Y)."""

    def build():
        m = kit.mats()
        root = S.empty("palisade")
        if arm == "":
            for i, (x, y) in enumerate([(0, 0), (0.18, 0.12), (-0.15, -0.14)]):
                st = S.cyl(f"post_{i}", 0.15, 0.14, 1.75 - i * 0.12, (x, y, 0), m["logs"], root, seg=7)
                S.cyl(f"post_{i}_tip", 0.14, 0.01, 0.32, (0, 0, 1.75 - i * 0.12), m["logs"], st, seg=7)
            return root
        dx, dy = {"e": (1, 0), "w": (-1, 0), "n": (0, 1), "s": (0, -1)}[arm]
        _stakes_line("stake", dx * 0.15, dy * 0.15, dx * 1.0, dy * 1.0, m, root, seed=ord(arm))
        # A rail binding the stakes on the inside.
        S.cyl("rail", 0.05, 0.05, 0.85, (dx * 0.15 - dy * 0.12, dy * 0.15 + dx * 0.12, 1.0), m["logs_old"],
              root, rot=(0, math.pi / 2, math.atan2(dy, dx)), seg=5)
        return root

    return build


def gate(vertical=False):
    def build():
        m = kit.mats()
        root = S.empty("gdl_gate")
        g = S.empty("gate", (0, 0, 0), root)
        g.rotation_euler = (0, 0, math.pi / 2 if vertical else 0.0)
        for x in (-0.92, 0.92):
            S.cyl(f"gate_post_{x}", 0.19, 0.18, 3.1, (x, 0, 0), m["logs"], g, seg=8)
        # Two closed leaves of planks with a brace.
        for x in (-0.42, 0.42):
            S.box(f"gate_leaf_{x}", (0.8, 0.1, 1.9), (x, -0.05, 1.0), m["plank"], g)
            S.box(f"gate_brace_{x}", (0.85, 0.06, 0.1), (x, -0.12, 1.0), m["logs_old"], g,
                  rot=(0, math.radians(35 if x < 0 else -35), 0))
        # Platform over the gate on beams, with a railing and a small roof.
        S.box("gate_floor", (2.3, 1.2, 0.14), (0, 0, 2.55), m["plank"], g)
        for x in (-1.1, 1.1):
            S.cyl(f"gate_railpost_{x}", 0.05, 0.05, 0.85, (x, -0.55, 2.62), m["logs"], g, seg=5)
            S.cyl(f"gate_roofpost_{x}", 0.05, 0.05, 1.5, (x, 0.5, 2.62), m["logs"], g, seg=5)
        S.box("gate_rail", (2.3, 0.08, 0.45), (0, -0.56, 3.1), m["plank"], g)
        kit.gable_roof("gate_roof", 2.4, 1.3, 0.55, 0.15, 4.05, m["shingle"], g)
        S.box("gate_mark", (0.5, 0.04, 0.3), (0, -0.62, 3.1), m["team"], g)
        return root

    return build


def gdl_granary():
    m = kit.mats()
    root = S.empty("gdl_granary")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    body = S.empty("granary", (0, 0.2, 0), root)
    for x in (-1.1, 0, 1.1):
        for y in (-0.9, 0.9):
            S.cyl(f"stilt_{x}_{y}", 0.13, 0.11, 0.6, (x, y, 0), m["logs_old"], body, seg=7)
            S.cyl(f"stilt_cap_{x}_{y}", 0.22, 0.2, 0.08, (x, y, 0.6), m["stone"], body, seg=8)
    S.box("floor", (2.7, 2.2, 0.12), (0, 0, 0.72), m["plank"], body)
    from tools.art.models import _srub
    _srub("wall", 2.5, 2.0, 1.5, 0.12, 0.78, m["logs"], body, seed=41)
    kit.gable_wall("gable_s", 2.2, 1.0, (0, -1.0, 2.3), 0.0, m["plank"], body)
    kit.gable_wall("gable_n", 2.2, 1.0, (0, 1.0, 2.3), 0.0, m["plank"], body)
    kit.gable_roof("roof", 2.5, 2.0, 1.05, 0.35, 2.3, m["shingle"], body, along_y=True)
    kit.window("door", 0.7, 1.15, (0.35, -1.13, 0.85), 0.0, m["door"], body)
    for i in range(3):
        S.box(f"step_{i}", (0.8, 0.28, 0.1), (0.35, -1.35 - i * 0.24, 0.6 - i * 0.2), m["plank"], body)
    for i, (x, y) in enumerate([(-0.6, -1.65), (-0.95, -1.5), (-0.75, -1.25), (1.4, -1.5)]):
        kit.sack(f"sack_{i}", (x, y, 0), m, root, s=1.0 - 0.1 * (i % 2))
    S.box("sack_band", (0.3, 0.05, 0.06), (-0.6, -1.86, 0.32), m["team"], root)
    kit.flag(root, (1.7, 1.7, 0), 3.0, m)
    return root


def gdl_farm():
    """Slash-and-burn field: rows of rye on dark soil, stumps and charred patches around."""
    rng = random.Random(5)
    m = kit.mats()
    root = S.empty("gdl_farm")
    S.box("yard", (5.9, 5.9, 0.04), (0, 0, 0.02), m["soil"])
    S.box("yard_ash", (1.4, 0.9, 0.02), (-2.1, 2.2, 0.05), m["ash"]).parent = root
    # Rye in rows of tufts: ripe ears over a greener stalk base.
    stalk = S.mat("rye_stalk", "#8a8a3c", 1.0, noise=0.4)
    for i in range(9):
        y = -2.3 + i * 0.56
        S.box(f"furrow_{i}", (4.5, 0.36, 0.1), (0.1, y, 0.05), stalk, root)
        for k in range(16):
            x = -2.05 + k * 0.29 + rng.uniform(-0.06, 0.06)
            hgt = rng.uniform(0.38, 0.55)
            S.cyl(f"rye_{i}_{k}", 0.1, 0.15, hgt, (x, y + rng.uniform(-0.05, 0.05), 0.04), m["grain"], root,
                  rot=(rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0), seg=6)
    for i in range(14):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(2.55, 2.9)
        x, y = math.cos(a) * d, math.sin(a) * d
        x, y = max(-2.85, min(2.85, x)), max(-2.85, min(2.85, y))
        kit.stump(f"stump_{i}", (x, y, 0), m, root, r=rng.uniform(0.15, 0.26), seed=i)
    for i in range(3):
        S.cyl(f"burnt_log_{i}", 0.12, 0.11, 1.6, (-2.7 + i * 0.25, 1.5 + i * 0.2, 0.12), m["charcoal"], root,
              rot=(0, math.pi / 2, 0.3 + i * 0.4), seg=7)
    # Sheaves in a stook, and a boundary stake with the owner's rag.
    for i in range(4):
        a = i * math.pi / 2
        S.cyl(f"sheaf_{i}", 0.17, 0.08, 0.75, (2.3 + 0.12 * math.cos(a), -2.3 + 0.12 * math.sin(a), 0), m["straw"],
              root, rot=(0.25 * math.sin(a), -0.25 * math.cos(a), 0), seg=8)
    st = S.cyl("mark_stake", 0.04, 0.035, 1.3, (-2.75, -2.75, 0), m["logs"], root, seg=5)
    S.box("mark_rag", (0.3, 0.03, 0.22), (0.15, 0, 1.12), m["team"], st)
    return root


def gdl_lumber_yard():
    m = kit.mats()
    root = S.empty("gdl_lumber_yard")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    kit.posts_shed("shed", 3.2, 1.5, 2.0, m["shingle"], root, (0, 0.95, 0), m)
    kit.log_pile("logs_a", (0.0, 1.0, 0), 0.0, 2.8, 9, m, root)
    kit.log_pile("logs_b", (-1.2, -0.8, 0), math.pi / 2, 1.8, 6, m, root)
    # Sawhorse with a log across.
    for x in (0.4, 1.4):
        for s in (-1, 1):
            S.box(f"trestle_{x}_{s}", (0.08, 0.08, 1.0), (x, -0.9 + s * 0.15, 0.45), m["logs_old"], root,
                  rot=(s * 0.35, 0, 0))
    S.cyl("sawlog", 0.15, 0.15, 1.9, (-0.05, -0.9, 0.95), m["logs"], root, rot=(0, math.pi / 2, 0), seg=8)
    kit.stump("chop", (1.3, -1.6, 0), m, root, r=0.28)
    S.box("chips", (0.9, 0.7, 0.03), (1.0, -1.45, 0.05), m["straw"], root)
    kit.flag(root, (-1.75, 1.75, 0), 3.0, m)
    return root


def gdl_mine():
    m = kit.mats()
    root = S.empty("gdl_mine")
    kit.yard(2.0, 2.0, m["earth"]).parent = root
    kit.posts_shed("shed", 1.8, 1.2, 1.9, m["shingle"], root, (-1.0, 1.25, 0), m)
    # Bloomery: a clay shaft furnace with a glowing mouth, bellows beside it.
    furnace = S.cyl("furnace", 0.62, 0.36, 1.55, (0.55, -0.1, 0), m["clay"], root, seg=12)
    S.cyl("furnace_top", 0.36, 0.3, 0.12, (0, 0, 1.55), m["charcoal"], furnace, seg=12)
    S.box("furnace_mouth", (0.32, 0.1, 0.3), (0.0, -0.55, 0.3), m["fire"], furnace)
    S.box("bellows", (0.5, 0.35, 0.18), (-0.8, -0.05, 0.4), S.mat("leather", "#5a3e28", 0.8), root,
          rot=(0, 0, 0.3))
    # Baskets of bog ore and a heap of charcoal.
    ore = S.mat("bog_ore", "#7a3f1e", 0.95, noise=0.5)
    wicker = S.mat("wicker", "#8e7346", 1.0, noise=0.6)
    for i, (x, y) in enumerate([(1.3, -0.9), (1.6, -0.35), (0.8, -1.5)]):
        S.cyl(f"basket_{i}", 0.26, 0.3, 0.42, (x, y, 0), wicker, root, seg=10)
        for k in range(4):
            S.rock(f"basket_ore_{i}_{k}", 0.1, (x + 0.1 * math.cos(k * 1.7), y + 0.1 * math.sin(k * 1.7), 0.44), ore,
                   root, seed=i * 9 + k)
    S.cyl("charcoal_heap", 0.75, 0.05, 0.6, (-1.1, -1.0, 0), m["charcoal"], root, seg=9, smooth=False)
    for i in range(5):
        S.rock(f"bloom_{i}", 0.12, (0.9 + i * 0.16, 0.95, 0.06), m["iron"], root, seed=70 + i)
    S.box("ore_band", (0.35, 0.05, 0.08), (1.3, -1.2, 0.3), m["team"], root)
    kit.flag(root, (1.75, 1.75, 0), 3.0, m)
    return root


def _spear_rack(prefix, loc, rot_z, m, parent, count=5):
    rack = S.empty(prefix, loc, parent)
    rack.rotation_euler = (0, 0, rot_z)
    for x in (-0.7, 0.7):
        S.cyl(f"{prefix}_post_{x}", 0.05, 0.05, 1.2, (x, 0, 0), m["logs"], rack, seg=5)
    S.cyl(f"{prefix}_bar", 0.04, 0.04, 1.5, (-0.75, 0, 1.1), m["logs"], rack, rot=(0, math.pi / 2, 0), seg=5)
    for i in range(count):
        x = -0.55 + i * 1.1 / max(1, count - 1)
        sp = S.cyl(f"{prefix}_spear_{i}", 0.018, 0.016, 2.1, (x, -0.25, 0), m["logs_old"], rack,
                   rot=(-0.12, 0, 0), seg=5)
        S.cyl(f"{prefix}_spear_{i}_head", 0.04, 0.0, 0.25, (0, 0, 2.1), m["iron"], sp, seg=4, smooth=False)
    return rack


def _shield(name, loc, rot_z, m, parent, lean=0.25):
    """A Lithuanian hand shield (60-70 cm trapezoid with a groove) leaning on something."""
    holder = S.empty(name, loc, parent)
    holder.rotation_euler = (lean, 0, rot_z)
    hide = S.mat("hide", "#8c6a45", 0.75, noise=0.3)
    h, wt, wb, g = 0.66, 0.21, 0.16, 0.035
    for part in (
        S.poly(f"{name}_l", [(-wb, 0, 0), (-0.04, -g, 0), (-0.04, -g, h), (-wt, 0, h)], [(0, 1, 2, 3)], hide, holder),
        S.poly(f"{name}_r", [(0.04, -g, 0), (wb, 0, 0), (wt, 0, h), (0.04, -g, h)], [(0, 1, 2, 3)], hide, holder),
        S.poly(f"{name}_band", [(-0.04, -g, 0), (0.04, -g, 0), (0.04, -g, h), (-0.04, -g, h)], [(0, 1, 2, 3)],
               m["team"], holder),
    ):
        S.solidify(part, 0.02)
    return holder


def gdl_barracks():
    m = kit.mats()
    from tools.art.models import _srub
    root = S.empty("gdl_barracks")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    hall = S.empty("hall", (-0.2, 1.0, 0), root)
    S.box("hall_base", (5.0, 2.8, 0.3), (0, 0, 0.15), m["stone"], hall)
    _srub("hall", 4.8, 2.6, 2.0, 0.13, 0.3, m["logs"], hall, seed=51)
    kit.gable_roof("hall_roof", 4.8, 2.6, 1.5, 0.4, 2.3, m["shingle"], hall)
    for x in (-2.4, 2.4):
        kit.gable_wall(f"hall_gable_{x}", 2.7, 1.45, (x, 0, 2.3), math.pi / 2, m["logs"], hall)
    kit.front_openings("hall", 4.8, 2.6, 0.3, m, hall, door_x=0.6, windows=[(-1.5, 1.0), (1.7, 1.0)])
    _spear_rack("rack_a", (-1.3, -1.2, 0), 0.0, m, root)
    _spear_rack("rack_b", (2.3, -0.6, 0), math.pi / 2, m, root, count=4)
    for i in range(3):
        _shield(f"shield_{i}", (-2.0 + i * 0.5, -1.55, 0), 0.0, m, root)
    # A chopping post for practice and a log bench.
    S.cyl("pell", 0.12, 0.11, 1.5, (1.3, -2.2, 0), m["logs_old"], root, seg=7)
    S.cyl("bench", 0.14, 0.14, 1.6, (-2.6, -2.4, 0.14), m["logs"], root, rot=(0, math.pi / 2, 0.1), seg=7)
    kit.flag(root, (2.6, 2.6, 0), 4.2, m, banner=True)
    return root


def _target(name, loc, m, parent):
    t = S.empty(name, loc, parent)
    for a in (0, 2.1, 4.2):
        S.cyl(f"{name}_leg_{a}", 0.03, 0.03, 1.4, (0.25 * math.cos(a), 0.25 * math.sin(a) + 0.1, 0), m["logs"], t,
              rot=(-0.2 * math.sin(a), 0.2 * math.cos(a), 0), seg=5)
    disc = S.cyl(f"{name}_disc", 0.45, 0.45, 0.16, (0, -0.1, 1.05), m["straw"], t, rot=(math.pi / 2 + 0.2, 0, 0),
                 seg=14)
    S.cyl(f"{name}_ring", 0.16, 0.16, 0.02, (0, 0, 0.16), m["team"], disc, seg=12)
    return t


def gdl_range():
    m = kit.mats()
    root = S.empty("gdl_range")
    kit.yard(3.0, 3.0, S.mat("meadow", "#6e7a45", 1.0, noise=0.3)).parent = root
    kit.posts_shed("shed", 3.4, 1.6, 2.1, m["shingle"], root, (1.0, 1.9, 0), m)
    # Bows on a rack under the shed.
    rack = S.empty("bow_rack", (1.0, 1.6, 0), root)
    S.cyl("bow_bar", 0.04, 0.04, 2.4, (-1.2, 0, 1.3), m["logs"], rack, rot=(0, math.pi / 2, 0), seg=5)
    bow = S.mat("bow", "#5b3b22", 0.6)
    for i in range(5):
        S.cyl(f"bow_{i}", 0.02, 0.015, 1.7, (-1.0 + i * 0.5, -0.05, 0.4), bow, rack, rot=(0.08, 0, 0), seg=5)
    for i in range(3):
        _target(f"target_{i}", (-2.2 + i * 0.25, 1.9 - i * 1.6, 0), m, root)
    for i in range(3):
        S.box(f"bale_{i}", (0.8, 0.5, 0.45), (-2.5, 2.4 - i * 1.6, 0.22), m["hay"], root)
    # The shooting line: a rail fence on the front side.
    kit.rail_fence("line", [(2.6, -2.7), (2.6, 0.6)], m["logs"], root, h=0.8)
    for i in range(4):
        S.cyl(f"arrow_{i}", 0.01, 0.01, 0.8, (-1.95 + i * 0.05, -1.5 + i * 0.1, 1.05), m["logs"], root,
              rot=(0, math.pi / 2 + 0.1, math.pi), seg=4)
    kit.flag(root, (2.7, 2.7, 0), 3.6, m)
    return root


def gdl_stable():
    m = kit.mats()
    from tools.art.models import _srub, _thatch_roof
    root = S.empty("gdl_stable")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    st = S.empty("stable", (-0.2, 1.6, 0), root)
    _srub("wall", 5.2, 2.2, 1.7, 0.12, 0.04, m["logs"], st, seed=61)
    _thatch_roof("roof", 5.2, 2.2, 1.3, 0.4, 1.75, st)
    for x in (-2.6, 2.6):
        kit.gable_wall(f"gable_{x}", 2.3, 1.25, (x, 0, 1.75), math.pi / 2, m["logs"], st)
    for i, x in enumerate((-1.6, 0.0, 1.6)):
        kit.window(f"stall_{i}", 0.9, 1.3, (x, -1.13, 0.1), 0.0, m["dark"], st)
    pts = [(-2.8, 0.2), (-2.8, -2.8), (2.8, -2.8), (2.8, 0.2)]
    kit.rail_fence("paddock", pts, m["logs_old"], root)
    S.cyl("haystack", 0.9, 0.12, 1.7, (1.8, -1.6, 0), m["hay"], root, seg=10)
    S.cyl("haypole", 0.04, 0.04, 2.1, (1.8, -1.6, 0), m["logs"], root, seg=5)
    S.box("trough", (1.2, 0.4, 0.35), (-1.2, -0.6, 0.18), m["logs_old"], root)
    S.box("trough_water", (1.05, 0.28, 0.02), (-1.2, -0.6, 0.35), S.mat("water", "#2c3a40", 0.1), root)
    kit.flag(root, (2.7, 2.7, 0), 3.6, m)
    return root


def gdl_shrine():
    """Alka: an old oak in a ring of stones with a fire on a flat altar stone, offerings and
    ribbons on the branches, a low wattle fence."""
    rng = random.Random(8)
    m = kit.mats()
    root = S.empty("gdl_shrine")
    S.box("yard", (4.2, 4.2, 0.04), (0, 0, 0.02), S.mat("meadow", "#6e7a45", 1.0, noise=0.3))
    bark = S.mat("oak_bark", "#4f4030", 0.95, noise=0.4)
    leaves = S.mat("oak_leaves", "#3f6a2c", 0.9, noise=0.45)
    oak = S.empty("oak", (-0.7, 0.8, 0), root)
    S.cyl("oak_trunk", 0.48, 0.32, 3.4, (0, 0, 0), bark, oak, seg=10)
    for i, (a, tilt) in enumerate([(0.4, 0.7), (2.3, 0.8), (4.2, 0.65)]):
        S.cyl(f"oak_bough_{i}", 0.22, 0.1, 2.0, (0, 0, 2.9), bark, oak,
              rot=(tilt * math.sin(a), -tilt * math.cos(a), 0), seg=7)
    for i in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.6, 1.6)
        S.ball(f"oak_crown_{i}", rng.uniform(1.0, 1.4), (math.cos(a) * d, math.sin(a) * d, 4.3 + rng.uniform(-0.3, 0.8)),
               leaves, oak, scale=(1, 1, 0.75), seg=10)
    for i, (x, y, z) in enumerate([(0.9, -0.6, 2.9), (-0.8, -0.7, 3.1), (0.2, -1.2, 3.3)]):
        S.box(f"ribbon_{i}", (0.06, 0.04, 0.45), (x, y, z), m["team"], oak)
    # A ring of field stones around the altar stone and its fire.
    for i in range(9):
        a = i * math.tau / 9
        S.rock(f"stone_{i}", rng.uniform(0.2, 0.3), (0.6 + math.cos(a) * 1.05, -0.5 + math.sin(a) * 1.05, 0.08),
               m["stone"], root, seed=i + 3)
    S.rock("altar", 0.5, (0.6, -0.5, 0.15), m["stone"], root, seed=99, squash=0.45, jitter=0.15)
    for i in range(4):
        S.cyl(f"fire_wood_{i}", 0.05, 0.05, 0.5, (0.6 - 0.25 * math.cos(i * 1.6), -0.5 - 0.25 * math.sin(i * 1.6), 0.36),
              m["charcoal"], root, rot=(0, math.pi / 2 - 0.35, i * 1.6), seg=5)
    S.cyl("fire", 0.18, 0.02, 0.45, (0.6, -0.5, 0.38), m["fire"], root, seg=6, smooth=False)
    # Offerings: a bowl and bread on the stone, a sheaf.
    S.cyl("bowl", 0.12, 0.16, 0.08, (0.2, -0.85, 0.32), m["clay"], root, seg=10)
    S.cyl("sheaf", 0.14, 0.07, 0.6, (1.5, 0.3, 0), m["straw"], root, seg=8)
    pts = [(-1.9, -1.9), (1.9, -1.9), (1.9, 1.9)]
    kit.wattle("fence", pts, m, root, h=0.6)
    return root


def zaseka(vertical=False):
    def build():
        rng = random.Random(4)
        m = kit.mats()
        bark = S.mat("pine_bark", "#7a4a2c", 0.9, noise=0.35)
        bough = S.mat("bough", "#5b4630", 0.9, noise=0.3)
        needles = S.mat("pine_needles_dry", "#3d5532", 0.95, noise=0.4)
        root = S.empty("gdl_zaseka")
        line = S.empty("abatis", (0, 0, 0), root)
        line.rotation_euler = (0, 0, math.pi / 2 if vertical else 0.0)
        for i in range(7):
            x = -2.6 + i * 0.87 + rng.uniform(-0.15, 0.15)
            tree = S.empty(f"tree_{i}", (x, 0.75, 0.15 + (i % 2) * 0.25), line)
            # Felled with the crown toward the enemy (-Y, the front), trunk lying on the ground.
            tree.rotation_euler = (math.pi / 2 - 0.12, 0, math.pi + rng.uniform(-0.45, 0.45))
            S.cyl(f"trunk_{i}", 0.16, 0.07, 2.4, (0, 0, -0.3), bark, tree, seg=7)
            for k in range(7):
                z = 0.5 + k * 0.25
                a = rng.uniform(0, math.tau)
                b = S.cyl(f"bough_{i}_{k}", 0.05, 0.005, 1.0, (0, 0, z), bough, tree,
                          rot=(0.75 * math.cos(a), 0.75 * math.sin(a), 0), seg=4, smooth=False)
                if k % 2 == 0:
                    S.ball(f"needles_{i}_{k}", 0.22, (0, 0, 0.4), needles, b, scale=(1, 1, 1.4), seg=6)
        S.box("abatis_mark", (0.4, 0.05, 0.12), (1.8, 0.95, 0.35), m["team"], line)
        return root

    return build


def gdl_siege_workshop():
    m = kit.mats()
    root = S.empty("gdl_siege_workshop")
    kit.yard(3.0, 3.0, m["earth"]).parent = root
    kit.posts_shed("shed", 4.6, 2.8, 2.6, m["shingle"], root, (0, 1.2, 0), m, lean=False)
    # An unfinished cart frame and wheels leaning on the posts.
    frame = S.empty("cart", (0.2, 1.1, 0.55), root)
    for y in (-0.55, 0.55):
        S.box(f"cart_beam_{y}", (2.8, 0.14, 0.14), (0, y, 0), m["plank"], frame)
    for x in (-1.2, -0.4, 0.4, 1.2):
        S.box(f"cart_cross_{x}", (0.12, 1.25, 0.1), (x, 0, 0.1), m["plank"], frame)
    wood = m["logs_old"]
    for i, (x, y, rz) in enumerate([(-1.0, 0.45, 0.0), (1.4, 0.45, 0.0), (2.6, -0.6, math.pi / 2)]):
        w = S.cyl(f"wheel_{i}", 0.55, 0.55, 0.1, (x, y, 0.55), wood, root, rot=(math.pi / 2 - 0.15, 0, rz), seg=14)
        S.cyl(f"wheel_hub_{i}", 0.12, 0.12, 0.2, (0, 0, -0.05), m["logs"], w, seg=8)
    kit.log_pile("timber", (-1.3, -1.6, 0), 0.0, 2.6, 6, m, root)
    S.cyl("rope_coil", 0.3, 0.3, 0.12, (1.3, -1.3, 0), m["rope"], root, seg=12)
    S.cyl("rope_coil2", 0.24, 0.24, 0.12, (1.3, -1.3, 0.12), m["rope"], root, seg=12)
    kit.flag(root, (2.7, -2.7, 0), 3.4, m)
    return root


def gdl_bort():
    """A bortnik's tree: a living pine with a hollowed hive (борть) high on the trunk, closed
    by a board (должея), a rope with a climbing seat and the owner's sign cut in the bark."""
    rng = random.Random(3)
    m = kit.mats()
    bark = S.mat("pine_bark", "#7a4a2c", 0.9, noise=0.35)
    needles = S.mat("pine_needles", "#2f5233", 0.9, noise=0.35)
    root = S.empty("gdl_bort")
    h = 8.0
    S.cyl("trunk", 0.32, 0.12, h, (0, 0, 0), bark, root, seg=9)
    for i in range(6):
        z = h * (0.6 + 0.065 * i)
        a = rng.uniform(0, math.tau)
        off = 0.35 * (1 - i / 6)
        S.ball(f"crown_{i}", (1.25 - i * 0.14) * rng.uniform(0.85, 1.1), (math.cos(a) * off, math.sin(a) * off, z),
               needles, root, scale=(1.0, 1.0, 0.55), seg=10)
    # The hive faces the front (-Y): a long board closing the hollow, two pegs.
    S.box("hive_board", (0.2, 0.06, 0.9), (0, -0.29, 3.6), m["plank"], root)
    S.box("hive_slot", (0.05, 0.03, 0.12), (0.0, -0.33, 3.65), m["dark"], root)
    for z in (3.25, 3.95):
        S.cyl(f"hive_peg_{z}", 0.02, 0.02, 0.18, (0, -0.25, z), m["logs"], root, rot=(math.pi / 2, 0, 0), seg=4)
    S.box("bort_sign", (0.2, 0.04, 0.22), (0.0, -0.31, 1.6), m["team"], root)
    # Climbing rope from a bough, with the seat board.
    S.cyl("rope", 0.012, 0.012, 3.0, (0.35, -0.2, 1.0), m["rope"], root, seg=4)
    S.box("seat", (0.4, 0.15, 0.04), (0.35, -0.2, 1.0), m["plank"], root)
    for i in range(6):
        S.ball(f"bee_{i}", 0.03, (rng.uniform(-0.3, 0.3), -0.45 - rng.uniform(0, 0.3), 3.4 + rng.uniform(0, 0.6)),
               S.mat("bee", "#2a2010", 0.9), root, seg=4)
    return root


BUILDINGS = {
    "gdl_granary": (gdl_granary, (2, 2), 5),
    "gdl_farm": (gdl_farm, (3, 3), 2),
    "gdl_lumber_yard": (gdl_lumber_yard, (2, 2), 5),
    "gdl_mine": (gdl_mine, (2, 2), 5),
    "gdl_barracks": (gdl_barracks, (3, 3), 6),
    "gdl_range": (gdl_range, (3, 3), 5),
    "gdl_stable": (gdl_stable, (3, 3), 5),
    "gdl_shrine": (gdl_shrine, (2, 2), 7),
    "gdl_zaseka": (zaseka(), (3, 1), 3),
    "gdl_zaseka_v": (zaseka(True), (1, 3), 3),
    "gdl_siege_workshop": (gdl_siege_workshop, (3, 3), 6),
    "gdl_bort": (gdl_bort, (1, 1), 10),
    "gdl_gate": (gate(), (1, 1), 6),
    "gdl_gate_v": (gate(True), (1, 1), 6),
    "gdl_palisade": (palisade_piece(""), (1, 1), 3),
}
for _arm in "ewns":
    BUILDINGS[f"gdl_palisade_{_arm}"] = (palisade_piece(_arm), (1, 1), 3)
