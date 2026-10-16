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

from tools.art import models, rig
from tools.art import shapes as S

UNIT_FRAME = (160, 144)
UNIT_PIVOT = (64, 104)
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
    rig.setup(*UNIT_FRAME, UNIT_PIVOT, samples=16 if preview else 24)
    figure = models.UNITS[uid]()
    passes = Passes(rig.shadow_catcher())
    dest = os.path.join(out, "units", uid)
    os.makedirs(dest, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix=uid)
    anims = [("walk", 12, 15)] if preview else ANIMS
    rows: dict[str, list[list[str]]] = {p: [] for p in PASSES}
    meta = {"frame": list(UNIT_FRAME), "pivot": list(UNIT_PIVOT), "scale": 0.5, "anims": {}}
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
        _sheet(rows[p], UNIT_FRAME, os.path.join(dest, f"{p}.png"))
    meta["rows_per_anim"] = 8
    meta["facing"] = "row offset = UnitView.facing (0 east, clockwise, 2 south)"
    with open(os.path.join(dest, "sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)


def render_static(kind: str, uid: str, builder, cells: int, out: str, preview: bool) -> None:
    """One view of a building (cells x cells) or a tree (one cell)."""
    rig.reset()
    S.reset_materials()
    if kind == "buildings":
        width = 128 * cells + 32
        height = {2: 300, 4: 580}.get(cells, 128 * cells + 200)
        pivot = (width // 2, height - 32 - 32 * cells)
    else:
        width, height = 160, 400
        pivot = (64, 360)
    rig.setup(width, height, pivot, samples=24 if preview else 48)
    builder()
    passes = Passes(rig.shadow_catcher())
    dest = os.path.join(out, kind)
    os.makedirs(dest, exist_ok=True)
    for p in PASSES:
        if p == "team" and kind == "trees":
            continue  # nothing of a tree takes the player colour
        passes.use(p)
        rig.render(os.path.join(dest, f"{uid}_{p}.png"))
    meta_path = os.path.join(dest, f"{uid}.json")
    with open(meta_path, "w") as fh:
        json.dump({"size": [width, height], "pivot": list(pivot), "cells": cells, "scale": 0.5,
                   "pivot_is": "centre of the footprint"}, fh, indent=1)


def main(argv: list[str]) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--out", default="art/sprites")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args(argv)
    for uid in args.ids:
        if uid in models.UNITS:
            render_unit(uid, args.out, args.preview)
        elif uid in models.BUILDINGS:
            builder, cells = models.BUILDINGS[uid]
            render_static("buildings", uid, builder, cells, args.out, args.preview)
        elif uid in models.TREES:
            render_static("trees", uid, models.TREES[uid], 1, args.out, args.preview)
        else:
            sys.exit(f"unknown asset id {uid}")
        print("rendered", uid, flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
