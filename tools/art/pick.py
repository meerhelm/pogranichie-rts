"""Writes `pick.json` next to each unit's `sheet.json`: the rectangle around the drawn figure in
every frame, so a click anywhere in it picks the unit (game/world/sprite_db.gd, Sprite.covers).

    python3 -m tools.art.pick art/sprites [unit_id ...]

Frames go row by row of the sheet, then frame by frame; each box is the opaque pixels of
color.png, in sheet pixels (render size) from the frame's corner:
{"cols": C, "boxes": [[x0, y0, x1, y1], ...]} (x1, y1 exclusive); an empty frame is [].
render.py writes it after each unit sheet.
"""

import json
import os
import sys

import numpy as np
from PIL import Image

## Alpha below this is edge haze, not the figure.
CUT = 24


def write_pick(dest: str) -> None:
    with open(os.path.join(dest, "sheet.json")) as fh:
        meta = json.load(fh)
    fw, fh_ = meta["frame"]
    alpha = np.asarray(Image.open(os.path.join(dest, "color.png")).getchannel("A")) >= CUT
    rows = alpha.shape[0] // fh_
    cols = alpha.shape[1] // fw
    boxes = []
    for r in range(rows):
        for c in range(cols):
            cell = alpha[r * fh_:(r + 1) * fh_, c * fw:(c + 1) * fw]
            ys = np.flatnonzero(cell.any(axis=1))
            xs = np.flatnonzero(cell.any(axis=0))
            if ys.size == 0:
                boxes.append([])
            else:
                boxes.append([int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1])
    with open(os.path.join(dest, "pick.json"), "w") as fh:
        json.dump({"cols": cols, "boxes": boxes}, fh, separators=(",", ":"))


def main(root: str, only: list[str]) -> None:
    units = os.path.join(root, "units")
    for uid in sorted(os.listdir(units)):
        if only and uid not in only:
            continue
        if os.path.exists(os.path.join(units, uid, "sheet.json")):
            write_pick(os.path.join(units, uid))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
