"""Portrait icons of units for the HUD buttons, rendered close up in Blender from the same
models as the sprites: head to waist for people on foot, the rider with the horse's head
and neck for mounted units, the whole wagon. Turned three-quarters to the viewer, lit like
the sprites, with the team colour of the faction; laid on the plate of tools/art/icons.py
as 128×128 PNG in ui/icons/units.

    python3 -m tools.art.portraits              # every prototype unit of gdl, to and pl
    python3 -m tools.art.portraits gdl_spearman
"""

import math
import os
import sys
import tempfile

import bpy
from mathutils import Euler, Vector
from PIL import Image

from tools.art import icons, registry, rig
from tools.art import shapes as S

RENDER = 256
## Square framed around a point below the head: (side, drop below the head) in metres.
FOOT = (1.5, 0.42)
MOUNTED = (2.3, 0.7)
## Camera: a little lower than the map's 60° so faces show.
CAMERA_TILT = 72.0
FACING = 3


def _scene() -> None:
    rig.setup(RENDER, RENDER, (RENDER / 2, RENDER / 2), samples=48)
    bpy.context.scene.render.film_transparent = True


def _camera(target: Vector, side: float) -> None:
    cam = bpy.context.scene.camera
    cam.data.ortho_scale = side
    cam.rotation_euler = Euler((math.radians(CAMERA_TILT), 0.0, math.radians(45)))
    view = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    cam.location = target - view * 40.0


def _bbox_centre(root) -> tuple[Vector, float]:
    pts = []
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name == "shadow_catcher":
            continue
        for c in o.bound_box:
            pts.append(o.matrix_world @ Vector(c))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, max(hi - lo)


def render(uid: str, out_dir: str) -> str:
    rig.reset()
    S.reset_materials()
    _scene()
    figure = registry.UNITS[uid].build()
    registry.style(figure, uid)
    team = bpy.data.materials.get(S.TEAM)
    if team is not None:
        rgb = icons.FACTION_TEAM.get(uid.split("_")[0], (217, 51, 38))
        lin = S.srgb("#%02x%02x%02x" % rgb)
        team.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin
    figure.root.rotation_euler = (0, 0, rig.heading_for_facing(FACING))
    figure.pose("idle", 0, 8)
    bpy.context.view_layer.update()
    person = getattr(figure, "rider", None) or (figure if hasattr(figure, "head") and hasattr(figure, "joints") else None)
    if person is None:
        centre, size = _bbox_centre(figure.root)
        _camera(centre, size * 0.95)
    else:
        side, drop = MOUNTED if hasattr(figure, "rider") else FOOT
        head = person.head.matrix_world.translation
        _camera(head - Vector((0, 0, drop)), side)
    path = os.path.join(tempfile.mkdtemp(prefix=uid), "p.png")
    rig.render(path)
    img = Image.open(path).convert("RGBA").resize((icons.SIZE, icons.SIZE), Image.LANCZOS)
    tile = icons._plate("unit")
    tile.alpha_composite(img)
    dest = os.path.join(out_dir, uid + ".png")
    tile.save(dest, optimize=True)
    return dest


def main(ids: list[str]) -> None:
    _, units = icons._prototype()
    out = os.path.join(icons.OUT, "units")
    os.makedirs(out, exist_ok=True)
    for uid in ids or units:
        if uid in registry.UNITS:  # aliases (pl_camp_servant...) use the icon of their art
            print(render(uid, out))


if __name__ == "__main__":
    main(sys.argv[1:])
