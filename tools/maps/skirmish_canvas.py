"""Drawing kit for the skirmish maps (tools/maps/gen_skirmish.py), 2026-10-19.

Every stroke is drawn twice: where asked and turned half a circle about the map's centre
(x, y → W-1-x, H-1-y). So a map comes out point-symmetric: both sides find the same ground, the
same resources and the same places of power, as netplay needs, and the skirmish AI's guess of the
enemy start (the cell opposite its own across the centre, ai/ai_military.gd) is right.
Legend: core/nav/map_text.gd.
"""

from __future__ import annotations

import math
from collections import deque

# Cells nobody walks on (water, primeval forest, quagmire) and map objects (they block too).
IMPASSABLE = set("~FB")
OBJECTS = set("o$%")
TC = 4  # town centre size in cells (data/buildings/*_town_center.tres)


class Canvas:
    def __init__(self, w: int, h: int, fill: str = ".") -> None:
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]
        self.places: list[tuple[str, int, int]] = []

    # --- cells ------------------------------------------------------------------------------

    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def mirror(self, x: int, y: int) -> tuple[int, int]:
        return self.w - 1 - x, self.h - 1 - y

    def put(self, x: int, y: int, ch: str, keep: str = "") -> None:
        for px, py in ((x, y), self.mirror(x, y)):
            if self.inside(px, py) and self.g[py][px] not in keep:
                self.g[py][px] = ch

    def get(self, x: int, y: int) -> str:
        return self.g[y][x]

    # --- strokes ----------------------------------------------------------------------------

    def blob(self, cx: float, cy: float, r: float, ch: str, keep: str = "", wobble: float = 0.25,
             sx: float = 1.0, sy: float = 1.0) -> None:
        """A roundish patch of radius r (stretched by sx, sy), its edge wavy by `wobble`."""
        span = int(r * max(sx, sy)) + 3
        for y in range(int(cy) - span, int(cy) + span + 1):
            for x in range(int(cx) - span, int(cx) + span + 1):
                if not self.inside(x, y):
                    continue
                rr = r * (1 - wobble + wobble * math.sin(x * 0.7 + y * 0.4 + cx * 0.3 + cy))
                dx, dy = (x - cx) / sx, (y - cy) / sy
                if dx * dx + dy * dy <= rr * rr:
                    self.put(x, y, ch, keep)

    def disc(self, cx: float, cy: float, r: float, ch: str, keep: str = "") -> None:
        self.blob(cx, cy, r, ch, keep, wobble=0.0)

    def rect(self, x0: int, y0: int, x1: int, y1: int, ch: str, keep: str = "") -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch, keep)

    def line(self, points: list[tuple[float, float]], ch: str, width: int = 1,
             keep: str = "") -> None:
        """A polyline `width` cells thick (a square brush centred on the line)."""
        lo = -(width // 2)
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(steps + 1):
                x = round(x0 + (x1 - x0) * i / steps)
                y = round(y0 + (y1 - y0) * i / steps)
                for dy in range(lo, lo + width):
                    for dx in range(lo, lo + width):
                        self.put(x + dx, y + dy, ch, keep)

    def river(self, points, water: int = 3, bank: str = "s", bank_w: int = 2, keep: str = "") -> None:
        """Water `water` cells wide between banks (sand or bog) `bank_w` wide each side."""
        self.line(points, bank, water + 2 * bank_w, keep)
        self.line(points, "~", water, keep)

    def crossing(self, x: int, y: int, ch: str, along: str, length: int, width: int = 2,
                 over: str = "~sbB") -> None:
        """A ford ('=') or bridge ('#') across the water at (x, y): `along` 'x' or 'y' is the
        direction the crossing runs; it covers the water and banks it meets."""
        for i in range(-length, length + 1):
            for j in range(width):
                px, py = (x + i, y + j) if along == "x" else (x + j, y + i)
                if self.inside(px, py) and self.g[py][px] in over:
                    self.put(px, py, ch)

    def place(self, kind: str, x: int, y: int) -> None:
        """A place of power: its 2x2 site (top-left x, y) on open grass with a clear ring."""
        self.rect(x - 1, y - 1, x + 2, y + 2, ".")
        self.places.append((kind, x, y))
        mx, my = self.w - 2 - x, self.h - 2 - y
        if (mx, my) != (x, y):
            self.places.append((kind, mx, my))

    # --- the start of a side ----------------------------------------------------------------

    def base(self, x: int, y: int, clear: int = 9) -> None:
        """Open ground for a town centre at (x, y) (top-left) and the peasants below it."""
        cx, cy = x + TC / 2 - 0.5, y + TC / 2 - 0.5
        self.disc(cx, cy, clear, ".")
        self.rect(x - 1, y - 1, x + TC, y + 6, ".")

    def ore(self, x: int, y: int, along: str = "x", side: int = 1) -> None:
        """Three bog-ore deposits in a row at the edge of a small bog; the bog lies on `side`
        (+1: below or right of the row, -1: above or left)."""
        dx, dy = (1, 0) if along == "x" else (0, 1)
        ox, oy = (0, 2 * side) if along == "x" else (2 * side, 0)
        self.blob(x + dx + ox, y + dy + oy, 2.6, "b", wobble=0.1)
        for i in range(3):
            self.put(x + dx * i, y + dy * i, "o")

    def silver(self, x: int, y: int) -> None:
        """Two silver mines on a small hill."""
        self.blob(x + 0.5, y + 1, 2.5, "h", wobble=0.1)
        self.put(x, y, "$")
        self.put(x + 1, y, "$")

    def salt(self, x: int, y: int) -> None:
        self.disc(x, y, 1.5, ".")
        self.put(x, y, "%")

    # --- output and checks ------------------------------------------------------------------

    def rows(self) -> list[str]:
        return ["".join(r) for r in self.g]

    def symmetric(self) -> bool:
        return all(
            self.g[y][x] == self.g[self.h - 1 - y][self.w - 1 - x]
            for y in range(self.h) for x in range(self.w)
        )

    def walkable(self, x: int, y: int) -> bool:
        return self.inside(x, y) and self.g[y][x] not in IMPASSABLE | OBJECTS

    def reach(self, x: int, y: int) -> set[tuple[int, int]]:
        """Cells a man on foot reaches from (x, y) (8 neighbours, no corner cutting)."""
        seen = {(x, y)}
        todo = deque([(x, y)])
        while todo:
            cx, cy = todo.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in seen or not self.walkable(nx, ny):
                        continue
                    if dx and dy and not (self.walkable(cx + dx, cy) and self.walkable(cx, cy + dy)):
                        continue
                    seen.add((nx, ny))
                    todo.append((nx, ny))
        return seen

    def count(self, ch: str) -> int:
        return sum(r.count(ch) for r in self.g)

    def count_near(self, ch: str, cx: int, cy: int, r: int) -> int:
        return sum(
            1 for y in range(max(0, cy - r), min(self.h, cy + r + 1))
            for x in range(max(0, cx - r), min(self.w, cx + r + 1))
            if self.g[y][x] == ch
        )

    def routes(self, a: tuple[int, int], b: tuple[int, int], apart: int = 4, home: int = 14,
               most: int = 6) -> list[list[tuple[int, int]]]:
        """Separate ways on foot from a to b: the shortest way, then the shortest that keeps
        `apart` cells off every way found before (outside `home` cells of either start), and so
        on, up to `most` ways."""
        taken: set[tuple[int, int]] = set()
        found = []
        for _ in range(most):
            path = self._path(a, b, taken)
            if path is None:
                break
            found.append(path)
            for x, y in path:
                if max(abs(x - a[0]), abs(y - a[1])) <= home or max(abs(x - b[0]), abs(y - b[1])) <= home:
                    continue
                for dy in range(-apart, apart + 1):
                    for dx in range(-apart, apart + 1):
                        taken.add((x + dx, y + dy))
        return found

    def _path(self, a, b, taken):
        prev = {a: None}
        todo = deque([a])
        while todo:
            cur = todo.popleft()
            if cur == b:
                out = []
                while cur is not None:
                    out.append(cur)
                    cur = prev[cur]
                return out[::-1]
            cx, cy = cur
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (cx + dx, cy + dy)
                    if n in prev or n in taken or not self.walkable(*n):
                        continue
                    if dx and dy and not (self.walkable(cx + dx, cy) and self.walkable(cx, cy + dy)):
                        continue
                    prev[n] = cur
                    todo.append(n)
        return None
