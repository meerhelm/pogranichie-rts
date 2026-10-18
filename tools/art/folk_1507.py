"""The Wolf Trail (ВКЛ 6, late August–September 1507): Ostrogski's flight from Muscovite
service, the Muscovite border watch and the chase, on the figure of people.py, the horse of
beasts.py and the pieces of folk_1500.py (visual assets doc, «Московское государство», «Герои
ВКЛ и их противники», «Здания»; the mission card docs/03-missions/08-gdl_06_wolf_trail_1507.md).

Units:
- hero_ostrogski_fugitive: Prince Konstanty Ostrogski in flight, about 47, greyed beard. The
  doc: «простая одежда, без доспеха»; the card: «Кафтан оставь. В чём пришёл, в том и уйду»,
  so no Muscovite kaftan and no armour: a plain dark riding coat to below the knee, a fur cap,
  a sabre drawn in the hand (attack `swing`), a plain horse (a chestnut) with an ordinary
  saddle and the team saddle cloth. Cut and colours of the coat are a guess (nothing in the
  sources): kept plain and dark, no gold, no arms.
- mo_storozha: a Muscovite border watchman on a small horse: a quilted tegilyai as on
  mo_syn_boyarsky but of faded undyed cloth, a cloth cap with a fur band instead of a helmet,
  the composite bow in hand (attack `bow`), the saadak, a sabre. The doc's one or two dogs
  beside him are not drawn (there is no dog model yet; they would be a separate unit).
- hero_nezhdan: the fictional centurion (сотник) leading the chase (the card: «Вымышлено:
  ... сотник Неждан»): a richer syn boyarsky, a spheroconical helmet with a gilt rim and
  point, a dark red tegilyai, a fur-edged collar, saadak, bow (attack `bow`), sabre, a better
  horse with a small blue chaprak. Everything about his looks is invented.

Building:
- mo_watchtower (1x1): «Сторожевая вышка» of the doc, «высокая вышка на четырёх столбах,
  навес, сигнальный костёр в бочке»: four leaning log posts with cross braces and a ladder, a
  plank platform with a railing, a small hipped plank roof on posts, the signal barrel on the
  platform (unlit), unpainted wood; the team colour on a pennant over the roof and a cloth
  hung on the railing. Height and bracing are a plain generic guess.

Map props (one view, color and shadow, no team pass, like trees: `props/<id>_*`):
- prop_chapel: a small Orthodox roadside chapel (часовня) of logs under a steep shingle roof,
  a small onion dome on a drum on the ridge, an eight-pointed cross, a door with a small icon
  over it. A generic wooden chapel; no particular building is meant.
- prop_campfire: a ring of stones, crossed logs, a few still flames with a warm glow on the
  ground (an emissive, half-transparent disc).
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Vector

from tools.art import beasts, folk, kit
from tools.art import shapes as S
from tools.art.folk_1410 import _composite_bow, _orthodox_cross
from tools.art.folk_1500 import (EasternMounted, _chaprak, _eastern_saddle, _kaftan, _m as _m1500, _saadak,
                                 _sabre_hip, _spheroconical, _tegilyai)
from tools.art.models import _srub


def _m():
    m = _m1500()
    m.update({
        "travel_coat": S.mat("travel_coat", "#3b3530", 0.95, noise=0.18),
        "coat_dark": S.mat("coat_dark", "#2a2622", 0.95, noise=0.15),
        "cap_cloth": S.mat("cap_cloth", "#33302e", 0.95, noise=0.15),
        "tegilyai_poor": S.mat("tegilyai_poor", "#7a705c", 0.95, noise=0.35),
        "tegilyai_poor_seam": S.mat("tegilyai_poor_seam", "#5a5242", 0.95, noise=0.25),
        "tegilyai_red": S.mat("tegilyai_red", "#6e1e1a", 0.9, noise=0.2),
        "tegilyai_red_seam": S.mat("tegilyai_red_seam", "#4a1412", 0.9, noise=0.15),
    })
    return m


# --- pieces --------------------------------------------------------------------------------

def _fur_cap(f, m, crown=None, tall=0.14):
    """A cloth cap with a thick fur band round it."""
    S.cyl("cap_crown", 0.13, 0.1, tall, (0, -0.01, 0.06), crown or m["cap_cloth"], f.head, seg=12)
    S.ball("cap_top", 0.1, (0, -0.01, 0.06 + tall), crown or m["cap_cloth"], f.head, scale=(1.0, 1.0, 0.5))
    S.cyl("cap_fur", 0.155, 0.15, 0.09, (0, -0.01, 0.02), m["fur"], f.head, seg=14)


def _sabre_drawn(f, m):
    """A sabre held point up in the right hand, its blade curving back (swings with the arm)."""
    f.held_r = True
    sabre = S.empty("sabre_drawn", (0, 0, 0), f.j("hand_r"))
    sabre.rotation_euler = (math.radians(-80), 0, 0)
    S.cyl("sabre_grip", 0.016, 0.016, 0.13, (0, 0, -0.07), m["leather"], sabre, seg=5)
    S.box("sabre_cross", (0.12, 0.03, 0.02), (0, 0, 0.06), m["steel"], sabre)
    # Three straight pieces, each bent a little further back: the curve of the blade.
    z, y, ang = 0.07, 0.0, 0.0
    for k, length in enumerate((0.3, 0.28, 0.24)):
        ang += math.radians(7)
        S.box(f"sabre_blade_{k}", (0.012, 0.035 - 0.006 * k, length),
              (0, y - math.sin(ang) * length / 2, z + math.cos(ang) * length / 2), m["steel"], sabre,
              rot=(ang, 0, 0))
        z += math.cos(ang) * length
        y -= math.sin(ang) * length


def _scabbard(f, m, side=-1):
    """An empty scabbard at the hip (the sabre is drawn)."""
    holder = S.empty("scabbard", (side * 0.25, 0.08, -0.05), f.hips)
    holder.rotation_euler = (math.radians(70), 0, 0)
    S.cyl("scabbard_body", 0.02, 0.016, 0.45, (0, 0, -0.45), m["leather"], holder, seg=5)
    S.cyl("scabbard_tip", 0.016, 0.012, 0.32, (0, 0, -0.75), m["leather"], holder,
          rot=(math.radians(14), 0, 0), seg=5)
    S.cyl("scabbard_mouth", 0.024, 0.024, 0.04, (0, 0, -0.02), m["steel"], holder, seg=6)
    return holder


def _poor_m(m):
    """The palette with a faded, undyed tegilyai."""
    p = dict(m)
    p["tegilyai"], p["tegilyai_seam"] = m["tegilyai_poor"], m["tegilyai_poor_seam"]
    return p


def _red_m(m):
    p = dict(m)
    p["tegilyai"], p["tegilyai_seam"] = m["tegilyai_red"], m["tegilyai_red_seam"]
    return p


# --- units ---------------------------------------------------------------------------------

def hero_ostrogski_fugitive():
    m = _m()
    coat = m["travel_coat"]
    r = beasts._rider("rider", coat, m["trousers"], m["leather"], m, m["greying_hair"])
    # A plain long riding coat, dark wooden buttons, no fur and no gold; a team sash.
    _kaftan(r, m, coat, buttons=m["coat_dark"])
    folk._belt(r, m["team"], r=0.255)
    S.ball("full_beard", 0.09, (0, 0.08, -0.11), m["greying_hair"], r.head, scale=(1.1, 0.8, 1.25))
    _fur_cap(r, m, tall=0.16)
    _sabre_drawn(r, m)
    _scabbard(r, m)
    h = beasts.horse("horse", S.mat("chestnut", "#7a4a2a", 0.9, noise=0.25), size=1.0)
    return beasts.Mounted("hero_ostrogski_fugitive", h, r, m["team"])


def mo_storozha():
    m = _m()
    p = _poor_m(m)
    r = beasts._rider("rider", p["tegilyai"], m["trousers"], m["leather"], m, m["hair"])
    _tegilyai(r, p)
    folk._belt(r, m["team"], r=0.255)
    _fur_cap(r, m, crown=m["felt"])
    _saadak(r, m)
    _sabre_hip(r, m, side=1)
    _composite_bow(r, m)
    h = beasts.horse("horse", S.mat("mouse_dun", "#6e6250", 0.9, noise=0.3), small=True,
                     mane=S.mat("mane", "#3a2a1c", 1.0, noise=0.4))
    return EasternMounted("mo_storozha", h, r, m["team"])


def hero_nezhdan():
    m = _m()
    p = _red_m(m)
    r = beasts._rider("rider", p["tegilyai"], m["mo_red"], S.mat("boots_red", "#6a2a1e", 0.8, noise=0.2), m,
                      m["dark_hair"])
    _tegilyai(r, p)
    S.cyl("collar_fur", 0.2, 0.17, 0.06, (0, -0.01, 0.52), m["fur"], r.chest, seg=12)
    for k in range(4):
        S.ball(f"loop_button_{k}", 0.018, (0, 0.205, 0.36 - k * 0.08), m["gold"], r.chest)
    folk._belt(r, m["team"], r=0.255)
    S.ball("full_beard", 0.09, (0, 0.08, -0.11), m["dark_hair"], r.head, scale=(1.05, 0.8, 1.2))
    _spheroconical(r, m)
    S.cyl("helmet_rim", 0.148, 0.146, 0.035, (0, 0, -0.01), m["gold"], r.head, seg=14)
    S.cyl("helmet_gilt_point", 0.045, 0.006, 0.08, (0, 0, 0.18), m["gold"], r.head, seg=8)
    _saadak(r, m)
    _sabre_hip(r, m, side=1)
    _composite_bow(r, m)
    h = beasts.horse("horse", S.mat("bay", "#6e4428", 0.9, noise=0.25), size=0.98,
                     mane=S.mat("mane", "#3a2a1c", 1.0, noise=0.4))
    _chaprak(h, m["chaprak_blue"], m["gold"])
    return EasternMounted("hero_nezhdan", h, r, m["team"])


# --- the watchtower ------------------------------------------------------------------------

def mo_watchtower():
    m = kit.mats()
    root = S.empty("mo_watchtower")
    kit.yard(0.95, 0.95, S.mat("trodden_grass", "#6f7444", 1.0, noise=0.35)).parent = root
    t = S.empty("tower", (0, 0, 0), root)
    base, top, z0 = 0.8, 0.55, 5.6  # half-spread of the posts at the ground and at the platform
    lean = math.atan2(base - top, z0)
    # Each post in three lengths (scarfed), so a fallen tower leaves short logs, not whole posts.
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        rot = Euler((y * lean, -x * lean, 0))
        axis = rot.to_matrix() @ Vector((0, 0, 1))
        length = (z0 + 0.15) / axis.z / 3
        for k in range(3):
            at = Vector((x * base, y * base, 0)) + axis * (length * k)
            S.cyl(f"post_{i}_{k}", 0.13 - 0.01 * k, 0.12 - 0.01 * k, length + 0.02, tuple(at), m["logs"], t,
                  rot=tuple(rot), seg=8)
    # Cross braces on the two faces the camera sees and on the back ones, two tiers.
    for tier, (za, zb) in enumerate(((0.4, 2.8), (2.8, 5.2))):
        ha = base - (base - top) * za / z0
        hb = base - (base - top) * zb / z0
        for face, (ax, ay) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
            for d in (-1, 1):
                # From one corner low to the other corner high, along the face.
                p0 = Vector((ax * ha - ay * d * ha, ay * ha + ax * d * ha, za))
                p1 = Vector((ax * hb + ay * d * hb, ay * hb - ax * d * hb, zb))
                v = p1 - p0
                rot = v.to_track_quat("Z", "Y").to_euler()
                S.cyl(f"brace_{tier}_{face}_{d}", 0.055, 0.055, v.length, tuple(p0), m["logs_old"], t, rot=rot, seg=6)
        hz = base - (base - top) * zb / z0
        for face, (ax, ay) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
            S.box(f"girt_{tier}_{face}", (2 * hz + 0.2 if ay else 0.12, 2 * hz + 0.2 if ax else 0.12, 0.12),
                  (ax * hz, ay * hz, zb), m["logs_old"], t)
    # A ladder up the front right (+X) face to a hatch in the floor.
    lad = S.empty("ladder", (base + 0.25, -0.15, 0), t)
    lad.rotation_euler = (0, -math.radians(6), 0)
    for y in (-0.22, 0.22):
        for k in range(3):
            S.cyl(f"ladder_rail_{y}_{k}", 0.035, 0.035, (z0 + 0.2) / 3, (0, y, k * (z0 + 0.2) / 3), m["plank"], lad,
                  seg=5)
    for k in range(13):
        S.cyl(f"ladder_rung_{k}", 0.025, 0.025, 0.44, (0, -0.22, 0.35 + k * 0.42), m["plank"], lad,
              rot=(-math.pi / 2, 0, 0), seg=4)
    # The platform: beams, a plank floor wider than the posts, a railing of planks.
    g = 0.95
    for i, x in enumerate((-0.45, 0.45)):
        S.box(f"beam_{i}", (2 * g + 0.2, 0.16, 0.16), (0, x, z0 - 0.08), m["logs_old"], t)
    S.box("floor", (2 * g, 2 * g, 0.1), (0, 0, z0 + 0.05), m["plank"], t)
    for i, (x, y, w, d) in enumerate(((0, -g, 2 * g, 0.06), (0, g, 2 * g, 0.06), (-g, 0, 0.06, 2 * g),
                                      (g, 0, 0.06, 2 * g))):
        S.box(f"rail_{i}", (w, d, 0.18), (x, y, z0 + 0.95), m["plank"], t)
        S.box(f"rail_low_{i}", (w, d, 0.12), (x, y, z0 + 0.45), m["plank"], t)
    S.box("watch_cloth", (0.42, 0.03, 0.55), (0.35, -g - 0.04, z0 + 0.72), m["team"], t)
    # The roof (навес) on four posts, a hipped roof of boards.
    for i, (x, y) in enumerate(((-g, -g), (g, -g), (g, g), (-g, g))):
        S.cyl(f"roof_post_{i}", 0.06, 0.06, 1.75, (x * 0.94, y * 0.94, z0 + 0.1), m["logs"], t, seg=6)
    kit.hip_roof("roof", 2 * g, 2 * g, 1.05, 0.22, z0 + 1.85, m["shingle"], t)
    # The signal fire: a tarred barrel with brushwood, ready to be lit.
    kit.barrel("signal_barrel", (-0.35, 0.3, z0 + 0.1), m, t, r=0.24, h=0.6)
    for k in range(5):
        a = k * math.tau / 5
        S.cyl(f"brush_{k}", 0.025, 0.012, 0.45, (-0.35 + 0.08 * math.cos(a), 0.3 + 0.08 * math.sin(a), z0 + 0.62),
              m["logs_old"], t, rot=(0.35 * math.sin(a), -0.35 * math.cos(a), 0), seg=4)
    kit.flag(t, (0, 0, z0 + 2.75), 1.3, m)
    return root


# --- map props -----------------------------------------------------------------------------

def _lathe(name, profile, material, parent, loc=(0, 0, 0), seg=16):
    """A surface of revolution round Z from a profile of (radius, z) points, bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-4:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        rings.append([bm.verts.new((r * math.cos(i * math.tau / seg), r * math.sin(i * math.tau / seg), z))
                      for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(seg):
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[(i + 1) % seg]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[(i + 1) % seg], b[0]))
            else:
                bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = S._mesh_obj(name, bm)
    o.location = loc
    return S._finish(o, material, parent, smooth=True)


def prop_chapel():
    m = kit.mats()
    root = S.empty("prop_chapel")
    w, d, h, z0 = 1.35, 1.55, 1.55, 0.18
    S.box("footing", (w + 0.25, d + 0.25, z0), (0, 0, z0 / 2), m["stone"], root)
    _srub("walls", w, d, h, 0.1, z0, m["logs"], root, seed=31)
    top = z0 + h + 0.05
    # A steep gable roof with its ridge along Y (the gable and door face -Y, front left).
    kit.gable_roof("roof", w, d, 1.35, 0.22, top, m["shingle"], root, along_y=True)
    kit.gable_wall("gable_front", w + 0.08, 1.3, (0, -d / 2, top), 0.0, m["plank"], root, thick=0.06)
    kit.gable_wall("gable_back", w + 0.08, 1.3, (0, d / 2, top), 0.0, m["plank"], root, thick=0.06)
    kit.window("door", 0.55, 1.15, (0, -d / 2 - 0.11, z0), 0.0, m["door"], root)
    # A small icon in a little case over the door, under the gable.
    S.box("icon_case", (0.26, 0.05, 0.32), (0, -d / 2 - 0.1, top + 0.32), m["logs_old"], root)
    S.box("icon_board", (0.18, 0.05, 0.23), (0, -d / 2 - 0.12, top + 0.32), S.mat("icon_dark", "#3a2418", 0.8), root)
    S.ball("icon_halo", 0.035, (0, -d / 2 - 0.145, top + 0.37), S.mat("gold", "#c9a03a", 0.4, metal=0.8), root)
    kit.window("side_window", 0.25, 0.3, (w / 2 + 0.11, 0.1, z0 + 0.85), math.pi / 2, m["dark"], root)
    # The drum and onion dome on the ridge, covered with aspen shingle (лемех), the cross.
    dome_z = top + 1.2
    aspen = S.mat("aspen_shingle", "#9a9286", 0.9, noise=0.35)
    S.cyl("drum", 0.15, 0.15, 0.32, (0, 0.05, dome_z), m["plank"], root, seg=12)
    _lathe("dome", [(0.17, 0.0), (0.23, 0.1), (0.24, 0.18), (0.2, 0.3), (0.11, 0.42), (0.04, 0.52), (0.0, 0.6)],
           aspen, root, (0, 0.05, dome_z + 0.32))
    cross = _orthodox_cross("cross", root, (0, 0.05, dome_z + 1.15), 0.5, m["iron"])
    cross.rotation_euler = (0, 0, math.radians(45))
    S.cyl("cross_stem", 0.015, 0.015, 0.2, (0, 0.05, dome_z + 0.88), m["iron"], root, seg=4)
    return root


def _glow_mat(name, color, strength, alpha_edge=True):
    """An emissive material; with `alpha_edge`, transparent toward the edge of a disc of
    radius 1 in object space (a soft glow on the ground)."""
    mt = bpy.data.materials.new(name)
    mt.use_nodes = True
    nt = mt.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = S.srgb(color)
    em.inputs["Strength"].default_value = strength
    if not alpha_edge:
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        return mt
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.9
    ramp.color_ramp.elements[1].color = (0.75, 0.75, 0.75, 1)
    nt.links.new(coord.outputs["Object"], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mt


def prop_campfire():
    rng = random.Random(5)
    m = kit.mats()
    root = S.empty("prop_campfire")
    # The warm glow on the ground, under everything (casts no shadow).
    glow = S.cyl("glow", 1.0, 1.0, 0.01, (0, 0, 0.005), _glow_mat("fire_ground_glow", "#ff8a2a", 1.6), root, seg=24)
    glow.scale = (0.85, 0.85, 1.0)
    glow.visible_shadow = False
    S.cyl("ash", 0.3, 0.3, 0.02, (0, 0, 0.0), m["ash"], root, seg=12)
    for i in range(9):
        a = i * math.tau / 9 + rng.uniform(-0.1, 0.1)
        S.rock(f"stone_{i}", rng.uniform(0.09, 0.12), (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.04), m["stone"], root,
               seed=i + 40)
    # Crossed logs leaning together over the fire.
    logs = S.mat("firewood", "#7e5c3c", 0.9, noise=0.35)
    for i in range(4):
        a = i * math.tau / 4 + 0.4
        S.cyl(f"log_{i}", 0.055, 0.045, 0.52, (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.02), logs, root,
              rot=(math.sin(a) * 1.05, -math.cos(a) * 1.05, 0), seg=6)
    for i in range(2):
        S.cyl(f"ember_log_{i}", 0.05, 0.05, 0.42, (-0.21, (i - 0.5) * 0.12, 0.05), m["charcoal"], root,
              rot=(0, math.pi / 2, (i - 0.5) * 0.5), seg=6)
    # Still flames: a few cones, a bright core.
    flame = _glow_mat("flame", "#ff6a10", 2.2, alpha_edge=False)
    core = _glow_mat("flame_core", "#ffb030", 3.5, alpha_edge=False)
    for i, (x, y, r, hh) in enumerate(((0.0, 0.0, 0.12, 0.48), (0.08, -0.05, 0.07, 0.34), (-0.08, 0.04, 0.07, 0.3),
                                       (0.03, 0.09, 0.06, 0.26))):
        fl = S.cyl(f"flame_{i}", r, 0.01, hh, (x, y, 0.04), flame, root, seg=7, smooth=False)
        fl.rotation_euler = (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), rng.uniform(0, math.tau))
        fl.visible_shadow = False
    c = S.cyl("flame_core", 0.06, 0.01, 0.24, (0, 0, 0.04), core, root, seg=6, smooth=False)
    c.visible_shadow = False
    return root


UNITS: dict = {}
MOUNTED_UNITS = {
    "hero_ostrogski_fugitive": hero_ostrogski_fugitive,
    "mo_storozha": mo_storozha,
    "hero_nezhdan": hero_nezhdan,
}
## id: (builder, cells, metres of height the frame must hold)
BUILDINGS = {"mo_watchtower": (mo_watchtower, (1, 1), 10)}
PROPS = {"prop_chapel": prop_chapel, "prop_campfire": prop_campfire}
