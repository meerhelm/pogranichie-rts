"""Renders code-built assets into isometric sprite sheets for the game.

    python3 -m tools.art.render gdl_peasant [--out art/sprites] [--preview]

Units: 8 directions x (idle 8 + walk 12 frames) in three passes, packed into
`<out>/units/<id>/{color,team,shadow}.png` (one row per direction and animation) with
`sheet.json`. Buildings and trees: one view in the same three passes.
Passes (visual assets doc): color with alpha; team = the TEAM material alone, lit, white,
for the game to tint with the player colour; shadow = ground shadow alone, so it never
draws over neighbours. `--preview` renders one frame per direction for a quick look.
"""

import argparse
import json
import math
import os
import sys
import tempfile

import bpy
from PIL import Image

from tools.art import registry, rig, shrink, stages
from tools.art import shapes as S

ANIMS = [("idle", 8, 6), ("walk", 12, 15)]  # name, frames, fps
PASSES = ("color", "team", "shadow")


def _meshes():
    return [o for o in bpy.data.objects if o.type == "MESH" and o.name != "shadow_catcher"]


class Passes:
    """Switches the scene between the color, team and shadow passes."""

    def __init__(self, catcher):
        self.catcher = catcher
        self.holdout = bpy.data.materials.new("holdout")
        self.holdout.use_nodes = True
        nt = self.holdout.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        hold = nt.nodes.new("ShaderNodeHoldout")
        nt.links.new(hold.outputs[0], out.inputs["Surface"])
        self.original = {o.name: [s.material for s in o.material_slots] for o in _meshes()}
        team = bpy.data.materials.get(S.TEAM)
        self.team_bsdf = team.node_tree.nodes["Principled BSDF"] if team else None
        self.team_color = tuple(self.team_bsdf.inputs["Base Color"].default_value) if team else None

    def use(self, name: str) -> None:
        self.catcher.hide_render = name != "shadow"
        for o in _meshes():
            o.visible_camera = name != "shadow"
            for slot, m in zip(o.material_slots, self.original[o.name]):
                if name == "team" and (m is None or m.name != S.TEAM):
                    slot.material = self.holdout
                else:
                    slot.material = m
        if self.team_bsdf is not None:
            white = (1.0, 1.0, 1.0, 1.0)
            self.team_bsdf.inputs["Base Color"].default_value = white if name == "team" else self.team_color


def _sheet(frames: list[list[str]], size: tuple[int, int], path: str) -> None:
    cols = max(len(r) for r in frames)
    sheet = Image.new("RGBA", (cols * size[0], len(frames) * size[1]))
    for y, row in enumerate(frames):
        for x, f in enumerate(row):
            sheet.paste(Image.open(f).convert("RGBA"), (x * size[0], y * size[1]))
    sheet.save(path, optimize=True)


def render_unit(uid: str, out: str, preview: bool) -> None:
    rig.reset()
    S.reset_materials()
    spec = registry.UNITS[uid]
    frame, pivot = spec.frame, spec.pivot
    rig.setup(*frame, pivot, samples=16 if preview else 24)
    figure = spec.build()
    passes = Passes(rig.shadow_catcher())
    dest = os.path.join(out, "units", uid)
    os.makedirs(dest, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix=uid)
    anims = [("walk", 12, 15)] if preview else ANIMS
    rows: dict[str, list[list[str]]] = {p: [] for p in PASSES}
    meta = {"frame": list(frame), "pivot": list(pivot), "scale": 0.5, "anims": {}}
    row = 0
    for anim, count, fps in anims:
        meta["anims"][anim] = {"row": row, "frames": count, "fps": fps}
        frame_ids = [3] if preview else list(range(count))
        for facing in range(8):
            figure.root.rotation_euler = (0, 0, rig.heading_for_facing(facing))
            for p in PASSES:
                rows[p].append([])
            for fr in frame_ids:
                figure.pose(anim, fr, count)
                bpy.context.view_layer.update()
                for p in PASSES:
                    passes.use(p)
                    path = os.path.join(tmp, f"{anim}_{facing}_{fr}_{p}.png")
                    rig.render(path)
                    rows[p][-1].append(path)
            row += 1
    for p in PASSES:
        _sheet(rows[p], frame, os.path.join(dest, f"{p}.png"))
        if p != "color":
            shrink.shrink(os.path.join(dest, f"{p}.png"))
    # Height of the HP bar over the anchor (game pixels): just above the tallest frame.
    top = min(_crop_box([f])[1] for r in rows["color"] for f in r)
    meta["bar_y"] = round((pivot[1] - top) * 0.5 + 3)
    meta["rows_per_anim"] = 8
    meta["facing"] = "row offset = UnitView.facing (0 east, clockwise, 2 south)"
    with open(os.path.join(dest, "sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)


def _crop_box(paths: list[str]) -> tuple[int, int, int, int]:
    """Union of the opaque areas of `paths`, with a small margin."""
    box = None
    for path in paths:
        bb = Image.open(path).getchannel("A").point(lambda a: 255 if a > 3 else 0).getbbox()
        if bb is None:
            continue
        box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
    w, h = Image.open(paths[0]).size
    if box is None:
        return (0, 0, w, h)
    m = 2
    return (max(0, box[0] - m), max(0, box[1] - m), min(w, box[2] + m), min(h, box[3] + m))


def render_static(kind: str, uid: str, builder, cells, out: str, preview: bool, tall: float = 8.0,
                  props: bool = True) -> None:
    """One view of a tree (one cell), or of a building (w x h cells) in each of its stages
    (stages.STAGES: `<id>_<stage>_<pass>.png`). Buildings render into a generous frame that is
    then cropped to what all stages cover; the pivot (footprint centre) moves with the crop."""
    if kind == "buildings":
        fw, fh = (cells, cells) if isinstance(cells, int) else cells
        span = fw + fh
        width = 64 * span + 32 + int(tall * 32)
        height = 32 * span + 48 + int(tall * 40)
        pivot = (16 + 32 * span, height - 24 - 16 * span)
        names = ["done"] if preview else stages.STAGES
    else:
        width, height = 160, 400
        pivot = (64, 360)
        names = [""]
    dest = os.path.join(out, kind)
    os.makedirs(dest, exist_ok=True)
    written = []
    for stage in names:
        rig.reset()
        S.reset_materials()
        rig.setup(width, height, pivot, samples=24 if preview else 48)
        root = builder()
        if stage:
            stages.apply(stage, root, (fw, fh), props=props)
        passes = Passes(rig.shadow_catcher())
        prefix = f"{uid}_{stage}_" if stage else f"{uid}_"
        for p in PASSES:
            if p == "team" and kind == "trees":
                continue  # nothing of a tree takes the player colour
            passes.use(p)
            path = os.path.join(dest, f"{prefix}{p}.png")
            rig.render(path)
            written.append(path)
    meta = {"size": [width, height], "pivot": list(pivot), "scale": 0.5, "pivot_is": "centre of the footprint"}
    if kind == "buildings":
        box = _crop_box(written)
        for path in written:
            Image.open(path).crop(box).save(path, optimize=True)
            if not path.endswith("_color.png"):
                shrink.shrink(path)
        meta["size"] = [box[2] - box[0], box[3] - box[1]]
        meta["pivot"] = [pivot[0] - box[0], pivot[1] - box[1]]
        meta["cells"] = [fw, fh]
        meta["stages"] = names
    else:
        meta["cells"] = cells
    with open(os.path.join(dest, f"{uid}.json"), "w") as fh_:
        json.dump(meta, fh_, indent=1)


def render_deposit(uid: str, out: str, preview: bool) -> None:
    """A map resource in DEPOSIT_VARIANTS variants: `deposits/<id>_<v>_{color,shadow}.png`."""
    width, height, pivot = 160, 144, (72, 96)
    dest = os.path.join(out, "deposits")
    os.makedirs(dest, exist_ok=True)
    count = registry.DEPOSIT_VARIANTS[uid]
    for v in range(count):
        rig.reset()
        S.reset_materials()
        rig.setup(width, height, pivot, samples=24 if preview else 48)
        registry.DEPOSITS[uid](seed=v)
        passes = Passes(rig.shadow_catcher())
        for p in ("color", "shadow"):
            passes.use(p)
            rig.render(os.path.join(dest, f"{uid}_{v}_{p}.png"))
    with open(os.path.join(dest, f"{uid}.json"), "w") as fh:
        json.dump({"size": [width, height], "pivot": list(pivot), "scale": 0.5, "variants": count,
                   "pivot_is": "centre of the cell"}, fh, indent=1)


def main(argv: list[str]) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--out", default="art/sprites")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args(argv)
    if args.ids == ["all"]:
        args.ids = [*registry.UNITS, *registry.BUILDINGS, *registry.TREES, *registry.DEPOSITS]
    for uid in args.ids:
        if uid in registry.UNITS:
            render_unit(uid, args.out, args.preview)
        elif uid in registry.BUILDINGS:
            b = registry.BUILDINGS[uid]
            render_static("buildings", uid, b.build, b.cells, args.out, args.preview, b.tall, b.props)
        elif uid in registry.DEPOSITS:
            render_deposit(uid, args.out, args.preview)
        elif uid in registry.TREES:
            render_static("trees", uid, registry.TREES[uid], 1, args.out, args.preview)
        else:
            sys.exit(f"unknown asset id {uid}")
        print("rendered", uid, flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
