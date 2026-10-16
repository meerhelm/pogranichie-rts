"""Building stages from a finished model (visual assets doc, «Здания: состояния»):
found (stakes and string on the ground), build_33 and build_66 (walls rising log by log, no
roof yet, timber stacked by the site), done, damaged_1 (soot, a few logs gone), damaged_2
(breaches, the roof sagging and half burnt), rubble (charred logs on the ground).

Works on any model made of separate parts: parts are judged by the height of their centre, so
horizontal wall logs come and go course by course."""

import math
import random

import bpy
from mathutils import Matrix, Vector

from tools.art import shapes as S

STAGES = ["found", "build_33", "build_66", "done", "damaged_1", "damaged_2", "rubble"]


def _meshes(root):
    out = []
    stack = [root]
    while stack:
        o = stack.pop()
        if o.type == "MESH":
            out.append(o)
        stack.extend(o.children)
    return out


def _bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _detach(obj):
    """Unparent keeping the world transform (children of removed holders survive)."""
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw


def _remove(obj):
    for c in list(obj.children):
        _detach(c)
    bpy.data.objects.remove(obj, do_unlink=True)


def _is_ground(obj):
    return obj.name.startswith("yard") or obj.name.startswith("shadow")


def _char():
    return S.mat("charred", "#2a221c", 1.0, noise=0.4)


def _soot():
    return S.mat("sooty", "#4a3a2c", 1.0, noise=0.45)


def _scorched():
    """Thatch with burnt patches."""
    return S.mat("thatch_scorched", "#6e5f3a", 1.0, noise=0.85)


def _recolor(obj, material):
    for slot in obj.material_slots:
        if slot.material is not None and slot.material.name != S.TEAM:
            slot.material = material


def _timber_stack(at, count, length, rng):
    logs = S.mat("logs", "#8a6b47", 0.85, noise=0.35)
    for i in range(count):
        row = i // 4
        S.cyl(f"stack_{at[0]}_{i}", 0.12, 0.12, length,
              (at[0] - length / 2, at[1] + (i % 4) * 0.25 - 0.4 + row * 0.12, 0.12 + row * 0.2),
              logs, rot=(0, math.pi / 2, rng.uniform(-0.05, 0.05)), seg=7)


def _stakes(half):
    wood = S.mat("stake", "#b08a5a", 0.9, noise=0.2)
    rope = S.mat("rope", "#d8c9a0", 1.0)
    corners = [(-half, -half), (half, -half), (half, half), (-half, half)]
    for i, (x, y) in enumerate(corners):
        S.cyl(f"stake_{i}", 0.05, 0.03, 0.55, (x, y, 0), wood, seg=6)
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        length = math.hypot(x1 - x0, y1 - y0)
        S.cyl(f"string_{i}", 0.012, 0.012, length, (x0, y0, 0.42), rope,
              rot=(0, math.pi / 2, math.atan2(y1 - y0, x1 - x0)), seg=4)


def apply(stage: str, root, cells: int, seed: int = 3) -> None:
    """Turns the finished model under `root` into `stage` in place."""
    if stage == "done":
        return
    bpy.context.view_layer.update()
    rng = random.Random(seed)
    half = cells  # metres: a cell is 2 m, so the footprint spans -cells..cells
    names = [o.name for o in _meshes(root) if not _is_ground(o)]
    top = max(_bounds(bpy.data.objects[n])[1].z for n in names) if names else 1.0

    def alive():
        """Parts not removed yet (removing a part only unparents its children)."""
        return [bpy.data.objects[n] for n in names if n in bpy.data.objects]

    def centre_z(o):
        lo, hi = _bounds(o)
        return (lo.z + hi.z) / 2

    if stage == "found":
        for o in alive():
            _remove(o)
        _stakes(half * 0.82)
        _timber_stack((half * 0.2, -half * 0.55), 6, half * 0.9, rng)
        return
    if stage in ("build_33", "build_66"):
        cut = top * (0.28 if stage == "build_33" else 0.55)
        for o in alive():
            if centre_z(o) > cut or any(k in o.name for k in ("roof", "flag", "gable")):
                _remove(o)
        # Scaffold poles at the corners and stacked timber for what is still to come.
        wood = S.mat("stake", "#b08a5a", 0.9, noise=0.2)
        for i, (x, y) in enumerate([(-1, -1), (1, -1), (1, 1), (-1, 1)]):
            S.cyl(f"scaffold_{i}", 0.06, 0.05, cut + 1.2, (x * half * 0.7, y * half * 0.7, 0), wood, seg=6)
        _timber_stack((half * 0.35, -half * 0.88), 8 if stage == "build_33" else 4, half * 0.8, rng)
        return
    if stage == "damaged_1":
        for o in alive():
            r = rng.random()
            if r < 0.05 and "flag" not in o.name:
                _remove(o)
            elif "roof" in o.name:
                _recolor(o, _scorched())
            elif r < 0.22:
                _recolor(o, _soot())
        return
    if stage == "damaged_2":
        for o in alive():
            z = centre_z(o) / top
            r = rng.random()
            if "roof" in o.name and o.type == "MESH" and o.parent is not None and "ridge" not in o.name:
                _detach(o)
                o.rotation_euler.rotate_axis("X", math.radians(rng.choice((-14, 14))))
                o.location.z -= 0.6
                _recolor(o, _char())
            elif r < 0.2 + 0.25 * z:
                _remove(o)
            elif r < 0.6:
                _recolor(o, _char())
        return
    if stage == "rubble":
        for o in alive():
            lo, hi = _bounds(o)
            if "flag" in o.name or lo.z > 1.2 or rng.random() < 0.35:
                _remove(o)
                continue
            _detach(o)
            _recolor(o, _char())
            if hi.z - lo.z > 0.8:
                # Tall pieces (stakes, posts) fall over.
                o.rotation_euler = (math.pi / 2, 0, rng.uniform(0, math.tau))
                o.location.z = 0.12
            else:
                o.location.z = min(o.location.z, 0.1 + rng.uniform(0, 0.25))
                o.rotation_euler.z += rng.uniform(-0.3, 0.3)
        return
    raise ValueError(stage)
