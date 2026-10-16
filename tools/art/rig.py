"""Render rig for isometric sprites (visual assets doc, «Технические спецификации»).

Orthographic camera at X 60°, Z 45° (ground square -> 2:1 diamond), one sun from the
upper left of the screen at 60° to the ground (the doc says 45°; raised 2026-10-16 for
shorter, tidier shadows) plus a weak sky fill, transparent film.
Scale: 45.25 px per metre, so a 2 m map cell is a 128x64 diamond; the game draws cells
64x32 and shows sprites at half size (sharp when zoomed in).

World axes: +X runs down-right on screen (cell x), -Y runs down-left (cell y).
Run with Blender's Python module: `pip install bpy==5.2.2`.
"""

import math
import os

import bpy
from mathutils import Euler, Vector

PX_PER_M = 45.25
SUN_ELEVATION = 60.0
CELL_M = 2.0
SQ = math.sqrt(0.5)

# Screen basis of the camera (right and up, in world space).
RIGHT = Vector((SQ, SQ, 0.0))
UP = Vector((-0.5 * SQ, 0.5 * SQ, math.cos(math.radians(30))))
VIEW = Vector((-math.sin(math.radians(60)) * SQ, math.sin(math.radians(60)) * SQ, -0.5))


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def ground_dir(screen_angle: float) -> Vector:
    """Ground vector whose screen image points at `screen_angle` (0 east, pi/2 south)."""
    sx, sy = math.cos(screen_angle), math.sin(screen_angle)
    # screen x = SQ * (gx + gy); screen y (down) = 0.5 * SQ * (gx - gy)
    a = sx / SQ
    b = sy / (0.5 * SQ)
    v = Vector(((a + b) / 2.0, (a - b) / 2.0, 0.0))
    return v.normalized()


def heading_for_facing(facing: int) -> float:
    """Z rotation for a model whose front is +Y so it faces game direction `facing`
    (8 steps clockwise from screen east, as UnitView.facing)."""
    g = ground_dir(facing * math.pi / 4.0)
    return math.atan2(g.y, g.x) - math.pi / 2.0


def setup(width: int, height: int, pivot: tuple[float, float], samples: int = 24) -> None:
    """Scene, camera and lights. `pivot` is the pixel (x, y from top-left) where the world
    origin lands in the frame."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    if os.environ.get("ART_THREADS"):  # several renders side by side share the cores
        scene.render.threads_mode = "FIXED"
        scene.render.threads = int(os.environ["ART_THREADS"])
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filter_size = 1.0
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.65, 0.8, 1.0)
    bg.inputs["Strength"].default_value = 0.55

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width, height) / PX_PER_M
    cam_data.clip_start = 0.1
    cam_data.clip_end = 200.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.rotation_euler = Euler((math.radians(60), 0.0, math.radians(45)))
    # Shift so the origin lands on the pivot pixel.
    dx = (pivot[0] - width / 2.0) / PX_PER_M
    dy = (pivot[1] - height / 2.0) / PX_PER_M
    cam.location = -VIEW * 50.0 - RIGHT * dx + UP * dy

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(6)
    sun_data.color = (1.0, 0.95, 0.86)
    sun = bpy.data.objects.new("sun", sun_data)
    scene.collection.objects.link(sun)
    # Upper left, 60° over the ground: shadows are 0.58 of the height.
    to_sun = ground_dir(math.radians(225)) + Vector((0, 0, math.tan(math.radians(SUN_ELEVATION))))
    sun.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()


def shadow_catcher(size: float = 30.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane.name = "shadow_catcher"
    plane.is_shadow_catcher = True
    return plane


def render(path: str) -> None:
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
