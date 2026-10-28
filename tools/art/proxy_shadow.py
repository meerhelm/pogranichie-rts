"""Ground shadows of pixel buildings from rough 3D stand-ins ("proxies").

A generated sprite is a flat picture: throwing its silhouette along the ground (`shadow_of` in
pixel_iso.py) treats it as a card facing the camera, so a deep house casts the shadow of a
board and a tall tower's shadow starts in the wrong place. Here each building gets a few
invisible solids (boxes, roofs, cylinders, cones, posts) standing on its footprint; the shadow
is where the sun throws them on the ground. The proxies are never drawn, so they only need to be
roughly right.

Coordinates of a proxy: `u`, `v` in cells from the centre of the footprint (u along the map's x,
screen down-right; v along y, screen down-left), `z` in screen pixels above the ground. On the
sprite a point lands at pivot + ((u - v) * 32, (u + v) * 16 - z). The sun is the one
Blender rig uses (upper left, 60° up): a point z pixels up throws its shadow (SHADOW_DX * z,
SHADOW_DY * z) screen pixels from its foot, down-right, so buildings, trees and units agree. The shadow of a convex part on flat
ground is the convex hull of its corners' shadows; the building's shadow is the union of its
parts'.

Parts (proxies.json, one list per building id):
    {"box": [u0, v0, u1, v1, z0, z1]}                 walls, platforms, a raised cabin
    {"roof": [u0, v0, u1, v1, z_eave, z_ridge], "kind": "gable_u" | "gable_v" | "pyramid" | "flat"}
    {"cyl": [u, v, r, z0, z1]}  {"cone": [u, v, r, z0, z1]}   round towers, tents, haystacks
    {"post": [u, v, z1], "r": 0.05}                   legs, poles, flagstaffs

    python3 -m tools.art.proxy_shadow fit [id ...]     # first guess for ids without a proxy
    python3 -m tools.art.proxy_shadow sheet OUT.png [id ...]   # wireframes + shadows to review
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
PROXIES = ROOT / "art_src" / "pixel_iso" / "proxies.json"
## The sun of the Blender rig (tools/art/rig.py: upper left of the screen, 60° over the ground),
## so these shadows agree with the rendered units: a point z pixels up throws its shadow
## (SHADOW_DX * z, SHADOW_DY * z) screen pixels from its foot, down-right at 45°.
SHADOW_DX, SHADOW_DY = 0.3, 0.3
SHADE = 150  # shadow alpha, as shadow_of
## Ground pixels of the sprite itself (yards, dirt pads) inside the shadow are darkened like the
## game's shadow layer darkens the map: alpha SHADE * SpriteDB.SHADOW_ALPHA (0.7) of black.
GROUND_DARKEN = 1.0 - SHADE / 255 * 0.7
SEGMENTS = 12
## Buildings standing on a painted yard or pad big enough for their shadow to fall on it: there
## the sprite's own ground pixels in the shadow are darkened. Only where the proxy covers the
## whole building, or a part it misses (an annex) would be darkened as if it were ground.
GROUND = {"gdl_stable", "gdl_range", "pl_range", "to_town_center"}


def load() -> dict[str, list[dict]]:
    if PROXIES.exists():
        return json.loads(PROXIES.read_text())
    return {}


# --- geometry --------------------------------------------------------------------------------

def solids(part: dict, zcap: float | None = None) -> list[list[tuple[float, float, float]]]:
    """Corner lists (u, v, z) of the convex solids of a part; heights clamped to `zcap`."""
    out: list[list[tuple[float, float, float]]] = []
    if "box" in part:
        u0, v0, u1, v1, z0, z1 = part["box"]
        out.append([(u, v, z) for u in (u0, u1) for v in (v0, v1) for z in (z0, z1)])
    elif "roof" in part:
        u0, v0, u1, v1, ze, zr = part["roof"]
        base = [(u0, v0, ze), (u1, v0, ze), (u1, v1, ze), (u0, v1, ze)]
        kind = part.get("kind", "gable_u")
        if kind == "gable_u":
            vm = (v0 + v1) / 2
            top = [(u0, vm, zr), (u1, vm, zr)]
        elif kind == "gable_v":
            um = (u0 + u1) / 2
            top = [(um, v0, zr), (um, v1, zr)]
        elif kind == "pyramid":
            top = [((u0 + u1) / 2, (v0 + v1) / 2, zr)]
        else:
            top = [(u, v, zr) for u, v, _ in base]
        out.append(base + top)
    elif "cyl" in part or "cone" in part:
        cone = "cone" in part
        u, v, r, z0, z1 = part["cone" if cone else "cyl"]
        ring = [(u + r * math.cos(a), v + r * math.sin(a)) for a in
                (2 * math.pi * i / SEGMENTS for i in range(SEGMENTS))]
        pts = [(x, y, z0) for x, y in ring]
        pts += [(u, v, z1)] if cone else [(x, y, z1) for x, y in ring]
        out.append(pts)
    elif "post" in part:
        u, v, z1 = part["post"]
        r = part.get("r", 0.05)
        out.append([(u + du, v + dv, z) for du in (-r, r) for dv in (-r, r) for z in (0, z1)])
    if zcap is not None:
        out = [[(u, v, min(z, zcap)) for u, v, z in s] for s in out if min(p[2] for p in s) < zcap]
    return out


def screen(p: tuple[float, float, float], pivot) -> tuple[float, float]:
    u, v, z = p
    return pivot[0] + (u - v) * 32, pivot[1] + (u + v) * 16 - z


def ground(p: tuple[float, float, float], pivot) -> tuple[float, float]:
    u, v, z = p
    return pivot[0] + (u - v) * 32 + SHADOW_DX * z, pivot[1] + (u + v) * 16 + SHADOW_DY * z


def hull(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo: list = []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    up: list = []
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def _fill(size, polys) -> np.ndarray:
    im = Image.new("L", size)
    d = ImageDraw.Draw(im)
    for poly in polys:
        if len(poly) >= 3:
            d.polygon(poly, fill=255)
        elif poly:
            d.line(poly, fill=255, width=2)
    return np.array(im) > 0


def silhouette(parts, size, pivot, zcap=None) -> np.ndarray:
    """Where the proxy itself covers the sprite."""
    return _fill(size, [hull([screen(p, pivot) for p in s]) for part in parts for s in solids(part, zcap)])


def shadow_mask(parts, size, pivot, zcap=None, alpha: np.ndarray | None = None) -> np.ndarray:
    """Shadow of the proxy; with the sprite's `alpha`, of the proxy carved by the picture."""
    if alpha is not None:
        return carved(parts, alpha, pivot, zcap)
    return _fill(size, [hull([ground(p, pivot) for p in s]) for part in parts for s in solids(part, zcap)])


def inside(part: dict, u: np.ndarray, v: np.ndarray, z: float) -> np.ndarray:
    """Which ground points (u, v) of the level z lie in the part."""
    if "box" in part or "post" in part:
        if "box" in part:
            u0, v0, u1, v1, z0, z1 = part["box"]
        else:
            uc, vc, z1 = part["post"]
            r, z0 = part.get("r", 0.05), 0
            u0, v0, u1, v1 = uc - r, vc - r, uc + r, vc + r
        if not z0 <= z <= z1:
            return np.zeros(u.shape, bool)
        return (u >= u0) & (u <= u1) & (v >= v0) & (v <= v1)
    if "roof" in part:
        u0, v0, u1, v1, ze, zr = part["roof"]
        if not ze <= z <= max(ze, zr):
            return np.zeros(u.shape, bool)
        m = (u >= u0) & (u <= u1) & (v >= v0) & (v <= v1)
        kind = part.get("kind", "gable_u")
        if kind == "flat" or zr <= ze:
            return m
        t = (z - ze) / (zr - ze)  # 0 at the eaves, 1 at the ridge
        du = np.abs(u - (u0 + u1) / 2) / max((u1 - u0) / 2, 1e-6)
        dv = np.abs(v - (v0 + v1) / 2) / max((v1 - v0) / 2, 1e-6)
        if kind == "gable_u":
            return m & (dv <= 1 - t)
        if kind == "gable_v":
            return m & (du <= 1 - t)
        return m & (np.maximum(du, dv) <= 1 - t)
    cone = "cone" in part
    uc, vc, r, z0, z1 = part["cone" if cone else "cyl"]
    if not z0 <= z <= z1:
        return np.zeros(u.shape, bool)
    rr = r * (1 - (z - z0) / max(z1 - z0, 1e-6)) if cone else r
    return (u - uc) ** 2 + (v - vc) ** 2 <= rr * rr


## Soft edges: each BAND px of height casts its own layer, blurred by SOFT0 + SOFT * height
## (a 100 px tower's top: about 4 px of penumbra, its foot: crisp).
BAND = 8
SOFT0, SOFT = 0.4, 0.035
STEP = 1 / 32  # cells: one screen pixel across


def carved(parts, alpha: np.ndarray, pivot, zcap=None) -> np.ndarray:
    """Soft shadow (0..1) of the proxy's points that the picture actually shows something at:
    the proxy bounds the building in depth, the sprite's outline trims it (gaps between legs,
    a tree's crown over a bare trunk, roof overhangs). The edge is the sharper the nearer the
    ground: the shadow of each height band is blurred by SOFT0 + SOFT * its height."""
    h, w = alpha.shape
    pts = [p for part in parts for sol in solids(part, zcap) for p in sol]
    if not pts:
        return np.zeros((h, w))
    us = np.arange(min(p[0] for p in pts), max(p[0] for p in pts) + STEP, STEP)
    vs = np.arange(min(p[1] for p in pts), max(p[1] for p in pts) + STEP, STEP)
    u, v = np.meshgrid(us, vs, indexing="ij")
    ztop = max(p[2] for p in pts)
    bands: dict[int, np.ndarray] = {}
    for z in np.arange(0, ztop + 1, 1.0):
        m = np.zeros(u.shape, bool)
        for part in parts:
            m |= inside(part, u, v, z)
        if not m.any():
            continue
        uu, vv = u[m], v[m]
        sx = np.round(pivot[0] + (uu - vv) * 32).astype(int)
        sy = np.round(pivot[1] + (uu + vv) * 16 - z).astype(int)
        ok = (sx >= 0) & (sx < w) & (sy >= 0) & (sy < h)
        seen = np.zeros(uu.shape, bool)
        seen[ok] = alpha[sy[ok], sx[ok]]
        if not seen.any():
            continue
        gx = np.round(pivot[0] + (uu[seen] - vv[seen]) * 32 + SHADOW_DX * z).astype(int)
        gy = np.round(pivot[1] + (uu[seen] + vv[seen]) * 16 + SHADOW_DY * z).astype(int)
        ok = (gx >= 0) & (gx < w) & (gy >= 0) & (gy < h)
        band = bands.setdefault(int(z // BAND), np.zeros((h, w), bool))
        band[gy[ok], gx[ok]] = True
    out = np.zeros((h, w))
    for k, band in bands.items():
        # close pinholes between the splatted points
        near = band | np.roll(band, 1, 0) | np.roll(band, -1, 0) | np.roll(band, 1, 1) | np.roll(band, -1, 1)
        closed = near & np.roll(near, 1, 0) & np.roll(near, -1, 0) & np.roll(near, 1, 1) & np.roll(near, -1, 1)
        im = Image.fromarray(((band | closed) * 255).astype(np.uint8), "L")
        r = SOFT0 + SOFT * (k + 0.5) * BAND
        out = np.maximum(out, np.array(im.filter(ImageFilter.GaussianBlur(r))) / 255.0)
    return out


def reach(parts, pivot) -> tuple[float, float, float, float]:
    """Screen box (x0, y0, x1, y1) of the proxy and its shadow, to size the canvas."""
    pts = []
    for part in parts:
        for s in solids(part):
            pts += [screen(p, pivot) for p in s] + [ground(p, pivot) for p in s]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def swap_uv(parts: list[dict]) -> list[dict]:
    """The mirror view (screen flipped left-right) has u and v swapped."""
    flip = {"gable_u": "gable_v", "gable_v": "gable_u"}
    out = []
    for part in parts:
        q = dict(part)
        if "box" in q or "roof" in q:
            key = "box" if "box" in q else "roof"
            u0, v0, u1, v1, a, b = q[key]
            q[key] = [v0, u0, v1, u1, a, b]
            if key == "roof":
                q["kind"] = flip.get(q.get("kind", "gable_u"), q.get("kind"))
        else:
            key = next(k for k in ("cyl", "cone", "post") if k in q)
            vals = list(q[key])
            vals[0], vals[1] = vals[1], vals[0]
            q[key] = vals
        out.append(q)
    return out


# --- sprite outputs --------------------------------------------------------------------------

def shadow_la(parts, color: Image.Image, pivot, zcap=None) -> Image.Image:
    sh = shadow_mask(parts, color.size, pivot, zcap, np.array(color)[..., 3] > 0)
    la = np.zeros(sh.shape + (2,), np.uint8)
    la[..., 1] = np.round(sh * SHADE).astype(np.uint8)
    return Image.fromarray(la, "LA")


def darken_ground(parts, color: Image.Image, pivot, zcap=None) -> Image.Image:
    """The building's own painted ground (pixels the proxy does not cover) darkened where its
    shadow falls, since the shadow layer is drawn under the sprite and cannot show there."""
    a = np.array(color)
    sh = shadow_mask(parts, color.size, pivot, zcap, a[..., 3] > 0)
    # low parts (a pad, a yard's edge) are ground the shadow may fall on
    body = silhouette([q for q in parts if top(q) > LOW], color.size, pivot, zcap)
    m = (sh > 0) & ~body & (a[..., 3] > 0)
    k = 1.0 - (1.0 - GROUND_DARKEN) * sh[m]
    a[m, :3] = (a[m, :3] * k[:, None]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


LOW = 10
## The sun's ray through the solids: per pixel of height it moves (SUN_DU, SUN_DV) cells along
## the ground (the screen offset SHADOW_DX, SHADOW_DY turned into u, v).
SUN_DU = (SHADOW_DX / 32 + SHADOW_DY / 16) / 2
SUN_DV = (SHADOW_DY / 16 - SHADOW_DX / 32) / 2
CAST = 3  # px: an occluder must be this much higher on the sun's ray to count


def cast_on_self(parts, color: Image.Image, pivot, zcap=None) -> Image.Image:
    """Shadows the solids throw on one another, drawn on the sprite: a keep on its castle's
    roofs and yard, a tall hall on its annex, a belfry on its church roof. A solid never shades
    itself (its dark side is painted already). Each sprite pixel is taken as the front-most
    proxy point the picture shows there; it is in shadow when another solid reaches higher on
    the sun's ray through that point."""
    a = np.array(color)
    alpha = a[..., 3] > 0
    h, w = alpha.shape
    solid_parts = [q for q in parts if top(q) > 0]
    if len(solid_parts) < 2:
        return color
    pts = [p for part in solid_parts for sol in solids(part, zcap) for p in sol]
    us = np.arange(min(p[0] for p in pts), max(p[0] for p in pts) + STEP, STEP)
    vs = np.arange(min(p[1] for p in pts), max(p[1] for p in pts) + STEP, STEP)
    u, v = np.meshgrid(us, vs, indexing="ij")
    ztop = max(p[2] for p in pts)
    # a roof belongs to the box under it (same footprint): one solid
    group, g = [], -1
    for j, part in enumerate(solid_parts):
        prev = solid_parts[j - 1] if j else None
        if not ("roof" in part and prev and "box" in prev and prev["box"][:4] == part["roof"][:4]):
            g += 1
        group.append(g)
    n = g + 1
    if n < 2:
        return color
    # per solid: the highest point on each sun ray, keyed by where the ray meets the ground
    # (screen pixel of that ground point)
    reach = np.full((n, h, w), -1.0)
    # per sprite pixel: the front-most proxy point there (its depth u + v, height, part, ray)
    front = np.full((h, w), -1e9)
    fz = np.zeros((h, w))
    fpart = np.full((h, w), -1)
    fgx = np.zeros((h, w), int)
    fgy = np.zeros((h, w), int)
    for z in np.arange(0, ztop + 1, 1.0):
        for i, part in enumerate(solid_parts):
            m = inside(part, u, v, z)
            if zcap is not None and z > zcap:
                m[:] = False
            if not m.any():
                continue
            uu, vv = u[m], v[m]
            sx = np.round(pivot[0] + (uu - vv) * 32).astype(int)
            sy = np.round(pivot[1] + (uu + vv) * 16 - z).astype(int)
            gx = np.round(pivot[0] + (uu - vv) * 32 + SHADOW_DX * z).astype(int)
            gy = np.round(pivot[1] + (uu + vv) * 16 + SHADOW_DY * z).astype(int)
            ok = (sx >= 0) & (sx < w) & (sy >= 0) & (sy < h) & (gx >= 0) & (gx < w) & (gy >= 0) & (gy < h)
            sx, sy, gx, gy, d = sx[ok], sy[ok], gx[ok], gy[ok], (uu + vv)[ok]
            seen = alpha[sy, sx]
            sx, sy, gx, gy, d = sx[seen], sy[seen], gx[seen], gy[seen], d[seen]
            np.maximum.at(reach[group[i]], (gy, gx), z)
            # front-most: largest depth; ties go to the later (higher) level
            order = np.argsort(d)
            sx, sy, gx, gy, d = sx[order], sy[order], gx[order], gy[order], d[order]
            better = d >= front[sy, sx]
            sx, sy, gx, gy, d = sx[better], sy[better], gx[better], gy[better], d[better]
            front[sy, sx] = d
            fz[sy, sx] = z
            fpart[sy, sx] = group[i]
            fgx[sy, sx] = gx
            fgy[sy, sx] = gy
    shade = np.zeros((h, w), bool)
    has = fpart >= 0
    for i in range(n):
        others = np.max(np.delete(reach, i, axis=0), axis=0)
        mine = has & (fpart == i)
        shade |= mine & (others[fgy, fgx] > fz + CAST)
    if not shade.any():
        return color
    soft = np.array(Image.fromarray((shade * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.0))) / 255.0
    soft = np.where(alpha, soft, 0)
    k = 1.0 - (1.0 - GROUND_DARKEN) * soft
    a[..., :3] = (a[..., :3] * k[..., None]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def top(part: dict) -> float:
    return max(p[2] for s in solids(part) for p in s)


# --- first guess -----------------------------------------------------------------------------

def house(p: dict) -> list[dict]:
    cu, cv, a, b, hw, hr = p["cu"], p["cv"], p["a"], p["b"], p["H"], p["R"]
    u0, u1, v0, v1 = cu - a, cu + a, cv - b, cv + b
    parts = [{"box": [r3(u0), r3(v0), r3(u1), r3(v1), 0, round(hw)]}]
    if p["kind"] != "flat":
        parts.append({"roof": [r3(u0), r3(v0), r3(u1), r3(v1), round(hw), round(hw + hr)], "kind": p["kind"]})
    return parts


def r3(x: float) -> float:
    return round(x, 2)


## Fitting options per id: `lam` is how much spilling out of the outline costs against
## covering it (open frames, legs and crowns need a low one), `kinds` the roofs to try.
FIT = {
    "gdl_tower": {"lam": 0.6, "kinds": ["pyramid"]},
    "mo_watchtower": {"lam": 0.3, "kinds": ["pyramid"]},
    "pl_tower": {"kinds": ["pyramid"]},
    "to_tower": {"kinds": ["pyramid"]},
    "gdl_shrine": {"lam": 0.8},
    "gdl_bort": {"lam": 0.8, "kinds": ["pyramid"]},
    "gdl_field_camp": {"lam": 1.5},
    "pl_lazaret": {"lam": 1.5},
}


def fit(color: Image.Image, pivot, w: int, h: int, lam: float = 3.0,
        kinds=("gable_u", "gable_v", "pyramid", "flat")) -> list[dict]:
    """Box + roof whose outline best covers the sprite without spilling out of it."""
    alpha = np.array(color)[..., 3] > 0
    size = color.size

    def score(p):
        s = silhouette(house(p), size, pivot)
        return int((s & alpha).sum()) - lam * int((s & ~alpha).sum())

    best, best_s = None, -1 << 60
    for kind in kinds:
        p = {"cu": 0.0, "cv": 0.0, "a": w * 0.35, "b": h * 0.35, "H": 24.0, "R": 20.0 if kind != "flat" else 0,
             "kind": kind}
        cur = score(p)
        steps = {"cu": 0.2, "cv": 0.2, "a": 0.2, "b": 0.2, "H": 8.0, "R": 8.0}
        for _ in range(6):
            improved = True
            while improved:
                improved = False
                for k, st in steps.items():
                    if kind == "flat" and k == "R":
                        continue
                    for sgn in (1, -1):
                        q = dict(p)
                        q[k] = p[k] + sgn * st
                        if q["a"] < 0.1 or q["b"] < 0.1 or q["H"] < 0 or q["R"] < 0:
                            continue
                        s = score(q)
                        if s > cur:
                            p, cur, improved = q, s, True
            steps = {k: v / 2 for k, v in steps.items()}
        if cur > best_s:
            best, best_s = p, cur
    return house(best)


def spires(parts: list[dict], color: Image.Image, pivot, min_rise: int = 18,
           min_width: int = 8) -> list[dict]:
    """Extra solids for what sticks up out of the proxy: a keep in a castle yard, a belfry or
    spire on a roof, a chimney. Each run of screen columns where the sprite rises `min_rise` px
    over the proxy becomes a square tower standing on the ground in the middle of the first
    part's depth, as tall as the sprite there, with a pyramid top if the sprite narrows."""
    alpha = np.array(color)[..., 3] > 0
    h, w = alpha.shape
    body = silhouette(parts, color.size, pivot)
    big = 1 << 20
    rows = np.arange(h)[:, None]
    top_s = np.where(alpha.any(0), np.where(alpha, rows, big).min(0), big)
    top_p = np.where(body.any(0), np.where(body, rows, big).min(0), big)
    rise = np.where((top_s < big) & (top_p < big), top_p - top_s, 0)  # only over the proxy
    up = rise >= min_rise
    pts = [p for sol in solids(parts[0]) for p in sol]
    bu0, bu1 = min(p[0] for p in pts), max(p[0] for p in pts)
    bv0, bv1 = min(p[1] for p in pts), max(p[1] for p in pts)

    def depth(c: float) -> float:
        """Middle of the first part's footprint along the view line u - v = c (u + v there);
        past its side corners, the corner's."""
        c = min(max(c, bu0 - bv1), bu1 - bv0)
        # on u - v = c: u in [max(bu0, bv0 + c), min(bu1, bv1 + c)], u + v = 2u - c
        lo, hi = max(bu0, bv0 + c), min(bu1, bv1 + c)
        return (lo + hi) - c
    out: list[dict] = []
    x = 0
    while x < w:
        if not up[x]:
            x += 1
            continue
        x0 = x
        while x < w and up[x]:
            x += 1
        x1 = x - 1
        if x1 - x0 + 1 < min_width or rise[x0:x1 + 1].max() < 0.8 * (x1 - x0 + 1):
            continue  # too thin (a flag) or wide and low (a roof the box fits badly)
        half = (x1 - x0 + 1) / 128  # a square of half side `half` is that wide on screen
        umv = ((x0 + x1) / 2 - pivot[0]) / 32
        d = depth(umv)
        u, v = (d + umv) / 2, (d - umv) / 2
        y_top = int(top_s[x0:x1 + 1].min())
        z_top = pivot[1] + (u + v) * 16 - y_top  # the apex over the middle
        z_top = max(z_top, 1)
        # where the run is under half its width wide, the top is a roof or spire
        cols = alpha[:, x0:x1 + 1]
        widths = cols.sum(1)
        narrow = np.nonzero(widths >= (x1 - x0 + 1) * 0.7)[0]
        z_eave = z_top
        if len(narrow):
            z_eave = max(1.0, z_top - (int(narrow[0]) - y_top))
        u0, u1, v0, v1 = r3(u - half), r3(u + half), r3(v - half), r3(v + half)
        out.append({"box": [u0, v0, u1, v1, 0, round(z_eave)]})
        if z_top - z_eave >= 4:
            out.append({"roof": [u0, v0, u1, v1, round(z_eave), round(z_top)], "kind": "pyramid"})
    return out


# --- review ----------------------------------------------------------------------------------

def wire(parts, img: Image.Image, pivot, k: int) -> None:
    """Edges of the proxy (every pair of corners on its hull outline) drawn on `img` scaled k."""
    d = ImageDraw.Draw(img)
    for part in parts:
        for s in solids(part):
            hl = hull([screen(p, pivot) for p in s])
            d.polygon([(x * k, y * k) for x, y in hl], outline=(255, 40, 40, 255))
            z0 = min(p[2] for p in s)
            base = hull([screen(p, pivot) for p in s if p[2] == z0])
            if len(base) >= 3:
                d.polygon([(x * k, y * k) for x, y in base], outline=(40, 40, 255, 255))
            sh = hull([ground(p, pivot) for p in s])
            d.polygon([(x * k, y * k) for x, y in sh], outline=(255, 230, 40, 255))


def probe(done: Image.Image, pivot, w: int, h: int, k: int = 2) -> Image.Image:
    """The sprite enlarged k times over a ground grid of its footprint: lines every quarter cell
    (whole cells brighter), u and v marked at the edges, to read where walls meet the ground."""
    im = Image.new("RGBA", (done.width * k, done.height * k), (210, 210, 210, 255))
    im.alpha_composite(done.resize(im.size, Image.NEAREST))
    d = ImageDraw.Draw(im)
    hu, hv = w / 2, h / 2

    def sp(u, v, z=0.0):
        x, y = screen((u, v, z), pivot)
        return x * k, y * k

    hu, hv = hu + 1, hv + 1  # the art often spills past its footprint
    n_u, n_v = int(hu * 8), int(hv * 8)
    for i in range(n_u + 1):
        u = -hu + i / 4
        col = (0, 90, 255, 255) if i % 4 == 0 else (0, 90, 255, 110)
        d.line([sp(u, -hv), sp(u, hv)], fill=col, width=1)
        if i % 2 == 0:
            d.text(sp(u, hv + 0.08), f"u{u:+.1f}", fill=(0, 0, 160, 255))
    for i in range(n_v + 1):
        v = -hv + i / 4
        col = (255, 60, 0, 255) if i % 4 == 0 else (255, 60, 0, 110)
        d.line([sp(-hu, v), sp(hu, v)], fill=col, width=1)
        if i % 2 == 0:
            x, y = sp(hu + 0.05, v)
            d.text((x + 2, y), f"v{v:+.1f}", fill=(160, 30, 0, 255))
    # height ticks every 10 px at the front corner
    fx, fy = sp(w / 2, h / 2)
    for z in range(0, 400, 10):
        y = fy - z * k
        if y < 0:
            break
        d.line([(fx - (6 if z % 50 else 14), y), (fx, y)], fill=(0, 0, 0, 255))
    return im


def _main() -> None:
    from tools.art import pixel_iso as pi

    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    cmd, rest = args[0], args[1:]
    proxies = load()
    picks = Path("art_src/pixel_iso/full/picks.json")
    if picks.exists():
        pi.PICK.update(json.loads(picks.read_text()))
    if cmd == "fit":
        ids = rest or [i for i in pi.BUILD if i not in proxies]
        for uid in ids:
            w, h, *_ = pi.BUILD[uid]
            done, pivot = pi.finished(Path("art_src/pixel_iso/full"), uid, w, h, right=100, top=10, bottom=80)
            parts = fit(done, pivot, w, h, **FIT.get(uid, {}))
            proxies[uid] = parts + spires(parts, done, pivot)
            print(uid, json.dumps(proxies[uid]))
        PROXIES.write_text(dump(proxies))
    elif cmd == "spires":  # add towers to proxies made by hand
        for uid in rest:
            w, h, *_ = pi.BUILD[uid]
            done, pivot = pi.finished(Path("art_src/pixel_iso/full"), uid, w, h, right=100, top=10, bottom=80)
            proxies[uid] = proxies[uid] + spires(proxies[uid], done, pivot)
            print(uid, json.dumps(proxies[uid]))
        PROXIES.write_text(dump(proxies))
    elif cmd == "probe":
        out = Path(rest[0])
        out.mkdir(parents=True, exist_ok=True)
        for uid in rest[1:] or list(pi.BUILD):
            w, h, *_ = pi.BUILD[uid]
            done, pivot = pi.finished(Path("art_src/pixel_iso/full"), uid, w, h, right=10, top=4, bottom=4)
            probe(done, pivot, w, h).save(out / f"{uid}.png")
    elif cmd == "sheet":
        out, ids = Path(rest[0]), rest[1:] or list(pi.BUILD)
        tiles = []
        for uid in ids:
            w, h, *_ = pi.BUILD[uid]
            done, pivot = pi.finished(Path("art_src/pixel_iso/full"), uid, w, h, right=100, top=10, bottom=80)
            parts = proxies.get(uid, [])
            k = int(__import__("os").environ.get("K", "2"))
            im = Image.new("RGBA", done.size, (120, 150, 90, 255))
            shm = Image.new("RGBA", done.size, (0, 0, 0, 0))
            shm.putalpha(shadow_la(parts, done, pivot).getchannel("A").point(lambda a: int(a * 0.7)))
            im.alpha_composite(shm)
            im.alpha_composite(cast_on_self(parts, darken_ground(parts, done, pivot) if uid in GROUND else done, pivot))
            left = im.resize((im.width * k, im.height * k), Image.NEAREST)
            right = Image.new("RGBA", left.size, (200, 200, 200, 255))
            right.alpha_composite(done.resize(left.size, Image.NEAREST))
            wire(parts, right, pivot, k)
            ImageDraw.Draw(right).text((4, 4), uid, fill=(0, 0, 0, 255))
            pair = Image.new("RGBA", (left.width * 2, left.height))
            pair.alpha_composite(left)
            pair.alpha_composite(right, (left.width, 0))
            tiles.append(pair)
        cols = 2
        rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
        W = max(sum(t.width for t in r) for r in rows)
        sheet = Image.new("RGBA", (W, sum(max(t.height for t in r) for r in rows)), (40, 40, 40, 255))
        y = 0
        for r in rows:
            x = 0
            for t in r:
                sheet.alpha_composite(t, (x, y))
                x += t.width
            y += max(t.height for t in r)
        sheet.save(out)


def dump(proxies: dict) -> str:
    """One part per line, so hand edits stay readable."""
    lines = ["{"]
    keys = list(proxies)
    for i, uid in enumerate(keys):
        lines.append(f' "{uid}": [')
        parts = proxies[uid]
        for j, part in enumerate(parts):
            lines.append("  " + json.dumps(part) + ("," if j < len(parts) - 1 else ""))
        lines.append(" ]" + ("," if i < len(keys) - 1 else ""))
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    _main()
