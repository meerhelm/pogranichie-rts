"""Main menu background: a Lithuanian court at the forest edge in the evening sun, built from
the same code models as the sprites, through a low perspective camera.
`python3 -m tools.art.menu_scene [out.jpg] [--samples N] [--small]`"""

import math
import random
import sys

import bpy
from mathutils import Vector

from tools.art import models, rig
from tools.art import shapes as S


def _place(obj, loc, rot_z=0.0, scale=1.0):
    obj.location = loc
    obj.rotation_euler = (0, 0, rot_z)
    obj.scale = (scale, scale, scale)


def build() -> None:
    rig.reset()
    S.reset_materials()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    # Evening sky: warm at the horizon, cool blue above (by the height of the view ray).
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, S.srgb("#f0b070")
    els[1].position, els[1].color = 0.45, S.srgb("#3c4f78")
    mid = els.new(0.08)
    mid.color = S.srgb("#d99a78")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    bg = nt.nodes["Background"]
    bg.inputs["Strength"].default_value = 0.9
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.5
    sun_data.color = (1.0, 0.62, 0.36)
    sun_data.angle = math.radians(2)
    sun = bpy.data.objects.new("sun", sun_data)
    scene.collection.objects.link(sun)
    to_sun = Vector((0.75, 0.55, 0.28)).normalized()  # low, to the right and behind the court
    sun.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
    scene.view_settings.exposure = -0.15

    grass = S.mat("grass", "#56713a", 1.0, noise=0.35)
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.data.materials.append(grass)
    road = S.mat("road", "#7a6648", 1.0, noise=0.3)
    S.box("road", (3.0, 60, 0.02), (6, -18, 0.01), road).rotation_euler = (0, 0, math.radians(-25))

    # Player colour of the scene: the Grand Duchy's red on flags and belts.
    S.team_mat().node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = S.srgb("#9e2a20")
    rng = random.Random(7)
    _place(models.gdl_town_center(), (4, 6, 0), math.radians(-20))
    for loc, rz in [((-9, 2, 0), 0.4), ((-5, -6, 0), -0.3), ((15, -3, 0), 0.9), ((-14, 12, 0), 0.1)]:
        _place(models.gdl_house(), loc, rz)
    # Forest behind and to the sides.
    for i in range(140):
        a = rng.uniform(-0.3, 1.0) * math.pi
        r = rng.uniform(20, 55)
        x, y = math.cos(a) * r, math.sin(a) * r + 10
        if y < 4:
            continue
        builder = models.nt_pine if rng.random() < 0.6 else models.nt_birch
        _place(builder(seed=i), (x, y, 0), rng.uniform(0, math.tau), rng.uniform(0.9, 1.25))
    # A troop of spearmen on the road and peasants by the court.
    for i in range(9):
        f = models.gdl_spearman()
        f.pose("walk", (i * 3) % 12, 12)
        _place(f.root, (3.5 + (i % 3) * 1.1 - i // 3 * 0.6, -9 - (i // 3) * 1.3, 0), math.radians(200))
    for i, (x, y) in enumerate([(-2, -1), (-3.5, 0.5), (9, -1.5)]):
        f = models.gdl_peasant()
        f.pose("idle", i * 2, 8)
        _place(f.root, (x, y, 0), rng.uniform(0, math.tau))

    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 32
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -22, 3.2)
    target = Vector((5, 4, 3.4))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def main(argv: list[str]) -> None:
    out = argv[0] if argv and not argv[0].startswith("--") else "ui/art/menu_background.png"
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 64
    build()
    scene = bpy.context.scene
    scene.cycles.samples = samples
    small = "--small" in argv
    scene.render.resolution_x = 960 if small else 1920
    scene.render.resolution_y = 540 if small else 1080
    scene.render.image_settings.file_format = "PNG"
    rig.render(out)


if __name__ == "__main__":
    main(sys.argv[1:])
