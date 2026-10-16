"""Small modelling kit for code-built low-poly assets: materials and primitives that
parent to joints, so a figure is a tree of pivots that animation rotates."""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

_materials: dict[str, bpy.types.Material] = {}

## Name of the player-colour material; the team pass keeps only these surfaces.
TEAM = "TEAM"


def srgb(hex_color: str) -> tuple[float, float, float, float]:
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def mat(name: str, color: str, rough: float = 0.85, noise: float = 0.0, metal: float = 0.0):
    """Principled material; `noise` > 0 adds a fine value-noise variation (wood, cloth, straw)."""
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    base = srgb(color)
    if noise > 0.0:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 18.0
        tex.inputs["Detail"].default_value = 4.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        dark = tuple(c * (1.0 - noise) for c in base[:3]) + (1.0,)
        light = tuple(min(1.0, c * (1.0 + noise * 0.6)) for c in base[:3]) + (1.0,)
        ramp.color_ramp.elements[0].color = dark
        ramp.color_ramp.elements[1].color = light
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.25
        nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Base Color"].default_value = base
    m.diffuse_color = base
    _materials[name] = m
    return m


def team_mat():
    """Player-colour zone: a light neutral in the colour pass, white in the team pass."""
    return mat(TEAM, "#c8c8c8", rough=0.8)


def reset_materials() -> None:
    _materials.clear()


def empty(name: str, loc=(0, 0, 0), parent=None) -> bpy.types.Object:
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if parent is not None:
        o.parent = parent
    return o


def _finish(obj, material, parent, smooth=False):
    obj.data.materials.append(material)
    if parent is not None:
        obj.parent = parent
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def _mesh_obj(name: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def box(name, size, loc, material, parent=None, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    o = _mesh_obj(name, bm)
    o.location = loc
    o.rotation_euler = rot
    return _finish(o, material, parent)


def cyl(name, r1, r2, depth, loc, material, parent=None, rot=(0, 0, 0), seg=10, smooth=True):
    """Tapered cylinder standing on its base at `loc` (base radius r1, top r2)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth
    )
    bmesh.ops.translate(bm, vec=Vector((0, 0, depth / 2.0)), verts=bm.verts)
    o = _mesh_obj(name, bm)
    o.location = loc
    o.rotation_euler = rot
    return _finish(o, material, parent, smooth)


def ball(name, r, loc, material, parent=None, scale=(1, 1, 1), seg=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2 + 1, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    o = _mesh_obj(name, bm)
    o.location = loc
    return _finish(o, material, parent, smooth=True)


def limb(name, r1, r2, length, material, parent, seg=8):
    """Segment hanging down from its parent's pivot (joint at the top)."""
    return cyl(name, r2, r1, length, (0, 0, -length), material, parent, seg=seg)


def poly(name, verts, faces, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    return _finish(o, material, parent, smooth)


def prism_roof(name, w, d, h, overhang, loc, material, parent=None, rot_z=0.0):
    """Gable roof: ridge along X, eaves `overhang` beyond the walls (w along X, d along Y)."""
    hw, hd = w / 2 + overhang, d / 2 + overhang
    verts = [
        (-hw, -hd, 0), (hw, -hd, 0), (hw, hd, 0), (-hw, hd, 0),
        (-hw, 0, h), (hw, 0, h),
    ]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    o = poly(name, verts, faces, material, parent, loc)
    o.rotation_euler = (0, 0, rot_z)
    return o


def solidify(obj, thickness):
    mod = obj.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = thickness
    return obj


def log_wall(prefix, length, height, r, loc, rot_z, material, parent=None, seed=0):
    """Wall of horizontal logs (a srub side) centred at `loc`, running along local X."""
    rng = random.Random(seed)
    holder = empty(prefix, loc, parent)
    holder.rotation_euler = (0, 0, rot_z)
    n = max(1, int(height / (2 * r * 0.92)))
    for i in range(n):
        z = r + i * 2 * r * 0.92
        extra = 0.18 + rng.uniform(0, 0.08)
        lg = cyl(
            f"{prefix}_{i}", r * rng.uniform(0.92, 1.05), r * rng.uniform(0.92, 1.05),
            length + 2 * extra, (-(length / 2 + extra), 0, z), material, holder,
            rot=(0, math.pi / 2, 0), seg=8,
        )
    return holder


def apply_rot_scale(obj):
    obj.data.transform(Matrix.LocRotScale(None, obj.rotation_euler, obj.scale))
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)


def rock(name, r, loc, material, parent=None, seed=0, squash=0.7, jitter=0.28):
    """Irregular boulder: an icosphere with jittered vertices, flat shaded."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-jitter, jitter)
        v.co.z *= squash
    o = _mesh_obj(name, bm)
    o.location = loc
    o.rotation_euler = (0, 0, rng.uniform(0, math.tau))
    return _finish(o, material, parent)


def brick(name: str, color: str, mortar: str = "#b9ab95", width: float = 0.42, row: float = 0.15,
          rough: float = 0.9):
    """Masonry (brick, roof tiles): a brick texture on the walls' horizontal run and height, so
    courses read on every face whatever its direction."""
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    add = nt.nodes.new("ShaderNodeMath")
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    nt.links.new(add.outputs[0], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    tex = nt.nodes.new("ShaderNodeTexBrick")
    base = srgb(color)
    tex.inputs["Color1"].default_value = base
    tex.inputs["Color2"].default_value = tuple(c * 0.78 for c in base[:3]) + (1.0,)
    tex.inputs["Mortar"].default_value = srgb(mortar)
    tex.inputs["Scale"].default_value = 1.0
    tex.inputs["Mortar Size"].default_value = 0.012
    tex.inputs["Brick Width"].default_value = width
    tex.inputs["Row Height"].default_value = row
    tex.offset = 0.5
    nt.links.new(comb.outputs[0], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    m.diffuse_color = base
    _materials[name] = m
    return m
