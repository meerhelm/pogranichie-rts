"""Stores the shadow and team passes as grey + alpha PNGs (a third of RGBA): the shadow is
black, the team mask is white shaded by light, so neither needs colour channels.

    python3 -m tools.art.shrink art/sprites [skip_dir ...]
"""

import os
import sys

from PIL import Image


def shrink(path: str) -> int:
    before = os.path.getsize(path)
    img = Image.open(path)
    if img.mode != "LA":
        img.convert("LA").save(path, optimize=True)
    return before - os.path.getsize(path)


def main(root: str, skip: list[str]) -> None:
    saved = 0
    for base, _dirs, files in os.walk(root):
        if any(s in base for s in skip):
            continue
        for f in files:
            if f.endswith(("_shadow.png", "_team.png")) or f in ("shadow.png", "team.png"):
                saved += shrink(os.path.join(base, f))
    print(f"saved {saved / 1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
