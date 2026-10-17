"""Four-legged figures (visual assets doc: «один общий скелет для всех коней»): beasts of the
map, horses under riders, and the wagon. A beast is a tree of joint empties like a person:
body, four legs of two segments, neck and head, tail; `pose()` walks it in a four-beat gait
or lets it stand, breathing, with a slow turn of the head.

- nt_bison: European wisent, high legs and a high hump; nt_bear: a brown bear; nt_elk: an elk
  with palmate antlers; nt_boar: a dark bristly boar with tusks; nt_wolf: a grey wolf.
- gdl_light_horse: mail or quilted coat, a simple helmet, a small shield, three sulitsa
  javelins, a sword, a small horse without a caparison.
- gdl_lit_lance: a bascinet with a visor, brigandine with plate arms, a shield with the
  Pogoń, a lance with a pennon, the horse in a red caparison.
- to_knight_brother: white cloak with the black cross, visored bascinet, plate, a white shield
  with the cross, a white caparison, a long lance; no crests.
- to_prussian_rider: mail, a simple helmet, a spear, a small shield, a small local horse.
- hero_gintaut: a Samogitian noble about 30, fair hair, short beard, mail, open bascinet, a
  fur cloak, mounted. hero_kuchmeister: a knight brother in a white cloak, mounted.
- gdl_wagon: a four-wheeled cart with plank sides under matting, two horses, a driver,
  cargo showing at the back.
"""

import math

from tools.art import folk, people
from tools.art import shapes as S


class Beast:
    def __init__(self, name, *, length, height, rx, rz, upper, lower, leg_r, hide, hoof=None,
                 neck=(0.6, 40.0), neck_r=0.16, head=(0.25, 0.5), head_tilt=30.0, tail=0.5, legs_y=None,
                 front_z=0.0, belly=None):
        """`length` of the body, `height` of its centre, radii `rx` (sideways) and `rz`;
        legs of `upper` + `lower`; neck (length, degrees forward from upright); head (radius,
        length)."""
        self.root = S.empty(name)
        self.body = S.empty("body", (0, 0, height), self.root)
        self.height = height
        self.rx, self.rz, self.half = rx, rz, length / 2
        self.torso = S.ball("torso", 1.0, (0, 0, 0), hide, self.body, scale=(rx, length / 2, rz), seg=16)
        if belly is not None:
            S.ball("chest_mass", 1.0, (0, length * 0.25, front_z * 0.5), belly, self.body,
                   scale=(rx * 1.05, length * 0.3, rz * 1.05), seg=14)
        self.joints = {}
        ly = legs_y if legs_y is not None else length * 0.36
        for end, y in (("f", ly), ("h", -ly)):
            for side, x in (("l", -1), ("r", 1)):
                k = f"{end}{side}"
                # The hips sit so the hooves just reach the ground.
                z = -height + upper + lower + 0.04 + (front_z if end == "f" else 0.0)
                hip = S.empty(f"hip_{k}", (x * rx * 0.55, y, z), self.body)
                S.limb(f"thigh_{k}", leg_r * 1.5, leg_r, upper, hide, hip, seg=8)
                knee = S.empty(f"knee_{k}", (0, 0, -upper), hip)
                S.limb(f"shin_{k}", leg_r, leg_r * 0.8, lower, hide, knee, seg=8)
                if hoof is not None:
                    S.cyl(f"hoof_{k}", leg_r * 0.95, leg_r * 0.85, 0.07, (0, 0.0, -lower - 0.03), hoof, knee, seg=8)
                self.joints[f"hip_{k}"] = hip
                self.joints[f"knee_{k}"] = knee
        self.neck = S.empty("neck", (0, length * 0.42, rz * 0.35 + front_z), self.body)
        self.neck_angle = math.radians(neck[1])
        self.neck.rotation_euler = (-self.neck_angle, 0, 0)
        S.cyl("neck_mesh", neck_r * 1.2, neck_r, neck[0], (0, 0, 0), hide, self.neck, seg=10)
        self.head = S.empty("head", (0, 0, neck[0]), self.neck)
        self.head_tilt = math.radians(head_tilt)
        self.skull = S.ball("skull", 1.0, (0, head[1] * 0.35, 0), hide, self.head,
                            scale=(head[0] * 0.8, head[1] * 0.6, head[0]), seg=12)
        self.tail = S.empty("tail", (0, -length / 2 + 0.05, rz * 0.4), self.body)
        self.tail.rotation_euler = (math.radians(160), 0, 0)
        if tail > 0:
            S.cyl("tail_mesh", 0.05, 0.02, tail, (0, 0, 0), hide, self.tail, seg=6)
        self.base_tail = math.radians(160)

    def j(self, name):
        return self.joints[name]

    def pose(self, anim: str, frame: int, frames: int) -> None:
        p = 2.0 * math.pi * frame / frames
        r = math.radians
        bob = 0.0
        head = 0.0
        turn = 0.0
        tail = 0.0
        phases = {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}
        for k, ph in phases.items():
            hip = self.joints[f"hip_{k}"]
            knee = self.joints[f"knee_{k}"]
            if anim == "attack":
                # A lunge: the forelegs reach, the hind legs push.
                s = math.sin(math.pi * frame / frames)
                hip.rotation_euler = ((-r(22) if k[0] == "f" else r(16)) * s, 0, 0)
                knee.rotation_euler = ((-r(30) if k[0] == "f" else r(10)) * s, 0, 0)
            elif anim == "walk":
                a = p + ph * 2.0 * math.pi
                hip.rotation_euler = (r(24) * math.sin(a), 0, 0)
                bend = max(0.0, math.cos(a))
                knee.rotation_euler = (-r(42) * bend if k[0] == "f" else r(30) * bend - r(6), 0, 0)
            else:
                hip.rotation_euler = (0, 0, 0)
                knee.rotation_euler = (0, 0, 0)
        lean = 0.0
        if anim == "walk":
            bob = 0.025 * math.cos(2 * p)
            head = r(5) * math.sin(2 * p)
            tail = r(8) * math.sin(p)
        elif anim == "attack":
            s = math.sin(math.pi * frame / frames)
            bob = 0.04 * s
            head = r(28) * s
            lean = r(7) * s
            tail = r(20) * s
        else:
            head = r(6) + r(6) * math.sin(p)
            turn = r(10) * math.sin(p)
            tail = r(14) * math.sin(p * 2)
        self.body.location.z = self.height + bob
        self.body.rotation_euler = (-lean, 0, 0)
        self.body.location.y = 0.12 * lean / math.radians(7)
        self.neck.rotation_euler = (-self.neck_angle + head * 0.5, 0, turn)
        self.head.rotation_euler = (self.neck_angle - self.head_tilt + head, 0, 0)
        self.tail.rotation_euler = (self.base_tail, tail, 0)


def _ears(beast, mat, size=0.08, spread=0.09, pointed=True, z=0.15, y=0.05):
    for x in (-spread, spread):
        if pointed:
            S.cyl(f"ear_{x}", size * 0.6, 0.005, size * 1.6, (x, y, z), mat, beast.head, rot=(0.0, x * 2.5, 0), seg=4,
                  smooth=False)
        else:
            S.ball(f"ear_{x}", size, (x, y, z), mat, beast.head, scale=(1, 0.5, 1))


# --- beasts --------------------------------------------------------------------------------

def nt_bison():
    hide = S.mat("bison_hide", "#4a3424", 1.0, noise=0.45)
    shag = S.mat("bison_shag", "#3a2618", 1.0, noise=0.6)
    horn = S.mat("horn", "#2a2420", 0.5)
    b = Beast("nt_bison", length=2.3, height=1.15, rx=0.42, rz=0.48, upper=0.48, lower=0.5, leg_r=0.09,
              hide=hide, hoof=horn, neck=(0.35, 105.0), neck_r=0.3, head=(0.28, 0.55), head_tilt=95.0, tail=0.55,
              front_z=0.12, belly=shag)
    # The high hump over the shoulders and the shaggy front.
    S.ball("hump", 0.55, (0, 0.5, 0.35), shag, b.body, scale=(0.75, 1.0, 0.9))
    S.ball("beard", 0.15, (0, 0.3, -0.25), shag, b.head, scale=(0.8, 1.0, 1.4))
    for x in (-1, 1):
        S.cyl(f"horn_{x}", 0.045, 0.01, 0.22, (x * 0.2, 0.1, 0.18), horn, b.head, rot=(0.5, x * 1.1, 0), seg=6)
    _ears(b, hide, 0.06, 0.24, pointed=False, z=0.08, y=0.0)
    return b


def nt_bear():
    fur = S.mat("bear_fur", "#5a3c24", 1.0, noise=0.5)
    snout = S.mat("bear_snout", "#7a5a3a", 1.0, noise=0.3)
    nose = S.mat("nose", "#151210", 0.4)
    b = Beast("nt_bear", length=1.6, height=0.78, rx=0.4, rz=0.42, upper=0.32, lower=0.36, leg_r=0.1,
              hide=fur, hoof=fur, neck=(0.25, 70.0), neck_r=0.24, head=(0.25, 0.42), head_tilt=75.0, tail=0.0,
              front_z=0.05)
    S.ball("shoulder_hump", 0.3, (0, 0.4, 0.3), fur, b.body, scale=(1.1, 1.0, 0.7))
    S.cyl("snout", 0.11, 0.08, 0.2, (0, 0.3, -0.05), snout, b.head, rot=(-math.pi / 2, 0, 0), seg=8)
    S.ball("nose", 0.045, (0, 0.5, -0.05), nose, b.head)
    _ears(b, fur, 0.07, 0.16, pointed=False, z=0.2, y=0.05)
    return b


def nt_elk():
    hide = S.mat("elk_hide", "#4e3a2a", 0.95, noise=0.35)
    legs = S.mat("elk_legs", "#8a7a64", 0.95, noise=0.3)
    antler = S.mat("antler", "#b9a888", 0.8, noise=0.3)
    hoof = S.mat("hoof", "#2a2420", 0.5)
    b = Beast("nt_elk", length=1.9, height=1.5, rx=0.33, rz=0.4, upper=0.65, lower=0.8, leg_r=0.065,
              hide=hide, hoof=hoof, neck=(0.5, 55.0), neck_r=0.17, head=(0.2, 0.62), head_tilt=70.0, tail=0.12,
              front_z=0.1)
    for k in ("fl", "fr", "hl", "hr"):
        S.limb(f"stocking_{k}", 0.07, 0.055, 0.45, legs, b.j(f"knee_{k}"), seg=8).location.z = -0.8
    S.ball("hump", 0.3, (0, 0.55, 0.3), hide, b.body, scale=(0.8, 1.2, 0.8))
    # The overhanging muzzle, the bell under the throat, palmate antlers.
    S.ball("muzzle", 0.12, (0, 0.55, -0.05), hide, b.head, scale=(0.9, 1.2, 1.0))
    S.cyl("bell", 0.04, 0.02, 0.25, (0, 0.1, -0.4), hide, b.head, seg=6)
    for x in (-1, 1):
        beam = S.empty(f"antler_{x}", (x * 0.1, 0.05, 0.17), b.head)
        beam.rotation_euler = (0.3, x * 1.2, 0)
        S.cyl(f"antler_beam_{x}", 0.03, 0.03, 0.22, (0, 0, 0), antler, beam, seg=6)
        beam.scale = (0.75, 0.75, 0.75)
        palm = S.poly(f"antler_palm_{x}", [(0, 0, 0.2), (0.12, -0.08, 0.55), (0.0, 0.0, 0.7), (-0.18, 0.15, 0.6),
                                            (-0.22, 0.25, 0.3)], [(0, 1, 2, 3, 4)], antler, beam)
        S.solidify(palm, 0.04)
        for t in range(4):
            S.cyl(f"tine_{x}_{t}", 0.02, 0.004, 0.16, (-0.2 + t * 0.1, 0.22 - t * 0.08, 0.35 + t * 0.1), antler, beam,
                  rot=(0.2, -0.5, 0), seg=4)
    _ears(b, hide, 0.07, 0.14, z=0.1, y=-0.05)
    return b


def nt_boar():
    hide = S.mat("boar_hide", "#2e2620", 1.0, noise=0.55)
    bristle = S.mat("boar_bristle", "#1c1714", 1.0, noise=0.6)
    tusk = S.mat("tusk", "#e6dfcf", 0.5)
    snout = S.mat("boar_snout", "#4a3a34", 0.8)
    b = Beast("nt_boar", length=1.3, height=0.6, rx=0.26, rz=0.32, upper=0.24, lower=0.3, leg_r=0.05,
              hide=hide, hoof=snout, neck=(0.15, 80.0), neck_r=0.22, head=(0.2, 0.55), head_tilt=100.0, tail=0.2,
              front_z=0.08)
    S.box("bristle_ridge", (0.08, 1.0, 0.12), (0, 0.15, 0.36), bristle, b.body)
    S.cyl("snout", 0.1, 0.07, 0.25, (0, 0.38, -0.05), hide, b.head, rot=(-math.pi / 2, 0, 0), seg=8)
    S.cyl("snout_disc", 0.075, 0.075, 0.03, (0, 0.62, -0.05), snout, b.head, rot=(-math.pi / 2, 0, 0), seg=8)
    for x in (-1, 1):
        S.cyl(f"tusk_{x}", 0.02, 0.003, 0.12, (x * 0.07, 0.5, -0.1), tusk, b.head, rot=(-0.4, x * 0.4, 0), seg=5)
    _ears(b, hide, 0.06, 0.1, z=0.14, y=0.0)
    return b


def nt_wolf():
    fur = S.mat("wolf_fur", "#7d776b", 1.0, noise=0.45)
    pale = S.mat("wolf_pale", "#b5ad9c", 1.0, noise=0.35)
    nose = S.mat("nose", "#151210", 0.4)
    b = Beast("nt_wolf", length=1.1, height=0.62, rx=0.17, rz=0.21, upper=0.3, lower=0.33, leg_r=0.04,
              hide=fur, hoof=fur, neck=(0.25, 45.0), neck_r=0.1, head=(0.12, 0.32), head_tilt=75.0, tail=0.0,
              front_z=0.04, belly=pale)
    S.cyl("snout", 0.06, 0.03, 0.2, (0, 0.2, -0.03), fur, b.head, rot=(-math.pi / 2, 0, 0), seg=6)
    S.ball("nose", 0.025, (0, 0.4, -0.03), nose, b.head)
    _ears(b, fur, 0.05, 0.06, z=0.1, y=0.0)
    # A bushy tail hanging down.
    S.ball("tail_brush", 0.08, (0, 0, 0.22), fur, b.tail, scale=(1, 1, 2.8))
    b.base_tail = math.radians(150)
    return b


# --- horses and riders ---------------------------------------------------------------------

def horse(name, coat, small=False, mane=None, size=None):
    """A horse; `size` scales it (default 0.92 small, 1.0 otherwise; 1.08 a heavy destrier)."""
    hoof = S.mat("hoof", "#2a2420", 0.5)
    s = size or (0.92 if small else 1.0)
    h = Beast(name, length=1.7 * s, height=1.15 * s, rx=0.27 * s, rz=0.33 * s, upper=0.5 * s, lower=0.56 * s,
              leg_r=0.05, hide=coat, hoof=hoof, neck=(0.7 * s, 38.0), neck_r=0.13, head=(0.13, 0.6 * s),
              head_tilt=105.0, tail=0.6 * s, front_z=0.08)
    mane = mane or S.mat("mane", "#2a1d14", 1.0, noise=0.4)
    S.box("mane", (0.06, 0.1, 0.62 * s), (0, -0.1, 0.35 * s), mane, h.neck)
    S.cyl("muzzle", 0.075, 0.06, 0.25, (0, 0.3, -0.05), coat, h.head, rot=(-math.pi / 2, 0, 0), seg=8)
    _ears(h, coat, 0.05, 0.06, z=0.12, y=0.0)
    for x in (-1, 1):
        S.cyl(f"rein_{x}", 0.008, 0.008, 0.7, (x * 0.09, 0.35, -0.05), S.mat("leather", "#5a3e28", 0.8, noise=0.2),
              h.head, rot=(math.radians(-120), 0, 0), seg=3)
    return h


class Mounted:
    """A rider on a horse: the rider's figure sits on the horse's body and moves with it."""

    def __init__(self, name, horse_beast, rider, saddle_cloth):
        self.root = S.empty(name)
        self.horse = horse_beast
        self.horse.root.parent = self.root
        self.rider = rider
        body = self.horse.body
        rz = horse_beast.rz
        saddle_z = rz + 0.06
        S.box("saddle", (0.36, 0.55, 0.1), (0, -0.05, saddle_z - 0.05), S.mat("leather", "#5a3e28", 0.8, noise=0.2),
              body)
        S.box("saddle_cloth", (0.62, 0.7, 0.04), (0, -0.05, saddle_z - 0.1), saddle_cloth, body)
        rider.root.parent = body
        rider.root.location = (0, -0.08, saddle_z - people.HIP_Z + 0.05)

    def pose(self, anim, frame, frames):
        # The horse stands while its rider strikes.
        self.horse.pose("idle" if anim == "attack" else anim, frame, frames)
        self.rider.pose("attack" if anim == "attack" else "idle", frame, frames)
        r = math.radians
        for side, x in (("l", -1), ("r", 1)):
            self.rider.j(f"thigh_{side}").rotation_euler = (r(72), -x * r(28), 0)
            self.rider.j(f"knee_{side}").rotation_euler = (-r(80), 0, 0)
        if anim == "walk":
            self.rider.chest.rotation_euler.x += r(3) * math.sin(4 * math.pi * frame / frames)


def caparison(h, mat, trim, cross=None):
    """A cloth cover over the horse to the knees, with a trim in the player colour."""
    body = h.body
    rx, ry = h.rx, h.half
    skirt = S.cyl("caparison", 1.0, 1.0, 0.62, (0, 0, -0.62), mat, body, seg=16)
    skirt.scale = (rx + 0.05, ry + 0.06, 1.0)
    band = S.cyl("caparison_trim", 1.0, 1.0, 0.08, (0, 0, -0.66), trim, body, seg=16)
    band.scale = (rx + 0.055, ry + 0.065, 1.0)
    S.ball("caparison_top", 1.0, (0, 0, 0.0), mat, body, scale=(rx + 0.04, ry + 0.05, h.rz + 0.03), seg=16)
    S.cyl("caparison_neck", 0.17, 0.15, 0.55, (0, 0, 0), mat, h.neck, seg=10)
    if cross is not None:
        for x in (-1, 1):
            S.box(f"cap_cross_v_{x}", (0.03, 0.12, 0.5), (x * (rx + 0.07), 0.0, -0.2), cross, body)
            S.box(f"cap_cross_h_{x}", (0.03, 0.45, 0.12), (x * (rx + 0.07), 0.0, -0.1), cross, body)


def _rider(name, body_mat, legs_mat, shoes, m, hair=None, beard=True):
    f = people.Figure(name)
    f.body(m["skin"], body_mat, legs_mat, shoes)
    if hair is not None:
        f.hair(hair, beard=beard)
    return f


def _lance(f, m, length=3.6, pennon=None):
    return folk._spear(f, m, length=length, pennon=pennon)


def gdl_light_horse():
    m = folk._m()
    r = _rider("rider", m["quilt"], m["trousers"], m["leather"], m, m["hair"])
    r.skirt("coat_skirt", 0.06, -0.3, 0.22, 0.3, m["quilt"])
    folk._belt(r, m["team"])
    S.cyl("cap_rim", 0.142, 0.138, 0.045, (0, 0, 0.03), m["iron"], r.head, seg=14)
    S.cyl("cap", 0.138, 0.02, 0.18, (0, 0, 0.07), m["iron"], r.head, seg=14)
    # Three sulitsas held upright, a small Lithuanian shield on the arm, a sword at the hip.
    spear = folk._spear(r, m, length=1.6)
    for i, dx in enumerate((0.05, -0.05)):
        S.cyl(f"sulitsa_{i}", 0.014, 0.013, 1.6, (dx, 0.02 * i, -0.85), m["wood"], spear, seg=6)
    from tools.art.models import _lithuanian_shield
    r.held_l = True
    sh = _lithuanian_shield(r.chest, m)
    sh.scale = (0.8, 0.8, 0.8)
    S.cyl("sword", 0.015, 0.015, 0.8, (-0.22, -0.05, -0.75), m["steel"], r.hips, rot=(-0.3, 0, 0), seg=5)
    h = horse("horse", S.mat("bay", "#6e4428", 0.9, noise=0.25), small=True)
    return Mounted("gdl_light_horse", h, r, m["team"])


def gdl_lit_lance():
    m = folk._m()
    brig = S.mat("brigandine", "#6a2a26", 0.8, noise=0.15)
    r = _rider("rider", brig, m["steel"], m["steel"], m)
    for side in ("l", "r"):
        S.limb(f"plate_arm_{side}", 0.085, 0.07, 0.3, m["steel"], r.j(f"shoulder_{side}"))
    r.skirt("tassets", 0.06, -0.25, 0.23, 0.29, m["steel"])
    folk._bascinet(r, m["steel"], visor=True)
    _lance(r, m, pennon=m["team"])
    sh = folk._heater(r, m["team"], m, cross=False)
    # The Pogoń: a white rider on the shield, drawn as a simple silhouette.
    white = S.mat("pogon_white", "#e8e6df", 0.8)
    S.box("pogon_horse", (0.22, 0.04, 0.1), (0.0, -0.05, 0.38), white, sh)
    S.box("pogon_rider", (0.06, 0.04, 0.14), (0.0, -0.05, 0.48), white, sh)
    S.box("pogon_sword", (0.03, 0.04, 0.14), (-0.06, -0.05, 0.56), white, sh)
    h = horse("horse", S.mat("grey_horse", "#8d867c", 0.9, noise=0.25))
    caparison(h, S.mat("red_caparison", "#8e2a22", 0.9, noise=0.15), m["team"])
    return Mounted("gdl_lit_lance", h, r, m["team"])


def _knight_brother(name, m, visor=True, lance=True):
    r = _rider("rider", m["mail"], m["steel"], m["steel"], m)
    for side in ("l", "r"):
        S.limb(f"plate_arm_{side}", 0.085, 0.07, 0.3, m["steel"], r.j(f"shoulder_{side}"))
    folk._cloak(r, m["order_white"], bottom=-0.75, r_bottom=0.42)
    folk._cross("cloak_cross", r.chest, (-0.12, 0.25, 0.28), 0.18, m["order_black"])
    folk._bascinet(r, m["steel"], visor=visor)
    if lance:
        _lance(r, m, length=3.9, pennon=m["team"])
    else:
        r.held_r = True
        sword = S.empty("sword", (0, 0, 0), r.j("hand_r"))
        sword.rotation_euler = (math.radians(-80), 0, 0)
        S.cyl("sword_blade", 0.022, 0.01, 0.9, (0, 0, 0.05), m["steel"], sword, seg=4, smooth=False)
        S.box("sword_guard", (0.2, 0.03, 0.03), (0, 0, 0.05), m["steel"], sword)
        S.solidify(S.poly("cloak_trim", [(-0.22, 0.2, 0.42), (0.22, 0.2, 0.42), (0.22, 0.2, 0.36),
                                         (-0.22, 0.2, 0.36)], [(0, 1, 2, 3)], m["team"], r.chest), 0.02)
    folk._heater(r, m["order_white"], m)
    h = horse("horse", S.mat("dark_bay", "#4a3020", 0.9, noise=0.25))
    caparison(h, m["order_white"], m["team"], cross=m["order_black"])
    return Mounted(name, h, r, m["team"])


def to_knight_brother():
    return _knight_brother("to_knight_brother", folk._m())


def hero_kuchmeister():
    m = folk._m()
    return _knight_brother("hero_kuchmeister", m, visor=False, lance=False)


def to_prussian_rider():
    m = folk._m()
    r = _rider("rider", m["mail"], m["hose"], m["leather"], m, m["fair_hair"])
    r.skirt("coat_skirt", 0.06, -0.3, 0.22, 0.29, S.mat("prussian_coat", "#6b5a42", 0.95, noise=0.2))
    folk._belt(r, m["leather"])
    S.ball("helmet", 0.14, (0, 0, 0.04), m["iron"], r.head, scale=(1, 1.05, 0.95))
    folk._spear(r, m, length=2.4)
    from tools.art.models import _lithuanian_shield
    r.held_l = True
    _lithuanian_shield(r.chest, m).scale = (0.8, 0.8, 0.8)
    h = horse("horse", S.mat("dun", "#9a8058", 0.9, noise=0.25), small=True)
    return Mounted("to_prussian_rider", h, r, m["team"])


def hero_gintaut():
    m = folk._m()
    r = _rider("rider", m["mail"], m["trousers"], m["leather"], m, m["fair_hair"])
    r.skirt("mail_skirt", 0.06, -0.3, 0.23, 0.3, m["mail"])
    folk._belt(r, m["team"])
    folk._cloak(r, m["fur"], bottom=-0.6, r_bottom=0.4)
    S.cyl("fur_collar", 0.3, 0.2, 0.12, (0, -0.02, 0.42), S.mat("fur_light", "#9a7a54", 1.0, noise=0.5), r.chest, seg=12)
    # An open bascinet over the fair hair and short beard.
    S.ball("bascinet", 0.15, (0, -0.02, 0.05), m["steel"], r.head, scale=(1.0, 1.05, 1.2))
    S.box("face_open", (0.16, 0.05, 0.12), (0, 0.13, -0.02), m["skin"], r.head)
    _lance(r, m, length=2.8, pennon=m["team"])
    from tools.art.models import _lithuanian_shield
    r.held_l = True
    _lithuanian_shield(r.chest, m)
    h = horse("horse", S.mat("black_horse", "#2a221c", 0.85, noise=0.25))
    return Mounted("hero_gintaut", h, r, m["team"])


# --- the wagon ------------------------------------------------------------------------------

def _wagon_driver(d, m):
    d.body(m["skin"], m["svita"], m["trousers"], m["lapti"], wraps=m["wraps"])
    d.hair(m["hair"])
    S.cyl("cap", 0.135, 0.12, 0.09, (0, 0, 0.05), m["felt"], d.head, seg=12)
    folk._belt(d, m["team"])


class Wagon:
    """`cover`: colour of the matting; `dress(driver, m)` clothes the driver; `mark(cart,
    m)` adds signs on the cover (the Order's cross)."""

    def __init__(self, name="gdl_wagon", cover="#b8a273", dress=_wagon_driver, mark=None, coat="#6e4428"):
        m = folk._m()
        plank = S.mat("plank", "#9a7a52", 0.85, noise=0.3)
        mat_cover = S.mat("matting", cover, 1.0, noise=0.5 if name == "gdl_wagon" else 0.15)
        self.root = S.empty(name)
        self.cart = S.empty("cart", (0, -1.0, 0), self.root)
        S.box("bed", (1.2, 2.5, 0.08), (0, 0, 0.75), plank, self.cart)
        for x in (-0.6, 0.6):
            S.box(f"side_{x}", (0.06, 2.5, 0.45), (x, 0, 1.0), plank, self.cart)
        S.box("tail_board", (1.2, 0.06, 0.45), (0, -1.25, 1.0), plank, self.cart)
        # Matting over hoops on the front two thirds; cargo shows at the back.
        cover = S.cyl("cover", 0.62, 0.62, 1.6, (0, -0.3, 1.2), mat_cover, self.cart, rot=(-math.pi / 2, 0, 0), seg=14)
        cover.scale = (1.0, 0.75, 1.0)
        S.box("cover_band", (1.27, 0.12, 0.05), (0, 0.6, 1.2), m["team"], self.cart)
        if mark is not None:
            mark(self.cart, m)
        S.ball("cargo_sack", 0.25, (-0.25, -0.95, 1.05), m["sack"], self.cart, scale=(1, 0.9, 0.8))
        S.cyl("cargo_barrel", 0.22, 0.22, 0.5, (0.25, -1.0, 0.8), S.mat("barrel", "#7c5a36", 0.8, noise=0.3),
              self.cart, seg=10)
        self.wheels = []
        for x in (-0.68, 0.68):
            for y in (-0.85, 0.85):
                w = S.empty(f"wheel_{x}_{y}", (x, y, 0.48), self.cart)
                S.cyl(f"wheel_rim_{x}_{y}", 0.46, 0.46, 0.08, (-0.04, 0, 0), plank, w, rot=(0, math.pi / 2, 0), seg=14)
                for k in range(3):
                    S.box(f"spoke_{x}_{y}_{k}", (0.09, 0.08, 0.86), (0, 0, 0), m["wood"], w, rot=(k * math.pi / 3, 0, 0))
                self.wheels.append(w)
        S.cyl("pole", 0.04, 0.04, 1.9, (0, 1.2, 0.7), m["wood"], self.cart, rot=(-math.pi / 2 + 0.12, 0, 0), seg=6)
        self.horses = []
        for x in (-0.42, 0.42):
            h = horse(f"horse_{x}", S.mat("bay" if coat == "#6e4428" else "wagon_horse", coat, 0.9, noise=0.25),
                      small=True)
            h.root.parent = self.root
            h.root.location = (x, 1.35, 0)
            S.box(f"collar_{x}", (0.3, 0.12, 0.35), (0, 0.6, 0.25), m["leather"], h.body)
            self.horses.append(h)
        # The driver on the front of the bed.
        d = people.Figure("driver")
        dress(d, m)
        d.root.parent = self.cart
        d.root.location = (0, 1.0, 0.85 - 0.3)
        self.driver = d

    def pose(self, anim, frame, frames):
        for i, h in enumerate(self.horses):
            h.pose(anim, (frame + i * frames // 4) % frames, frames)
        self.driver.pose("idle", frame, frames)
        r = math.radians
        for side in ("l", "r"):
            self.driver.j(f"thigh_{side}").rotation_euler = (r(85), 0, 0)
            self.driver.j(f"knee_{side}").rotation_euler = (-r(85), 0, 0)
            self.driver.j(f"shoulder_{side}").rotation_euler = (r(40), 0, 0)
        spin = 2 * math.pi * frame / frames if anim == "walk" else 0.0
        for w in self.wheels:
            w.rotation_euler = (spin, 0, 0)
        self.cart.location.z = 0.012 * math.sin(4 * math.pi * frame / frames) if anim == "walk" else 0.0


def gdl_wagon():
    return Wagon()


UNITS = {
    "nt_bison": nt_bison, "nt_bear": nt_bear, "nt_elk": nt_elk, "nt_boar": nt_boar, "nt_wolf": nt_wolf,
}
MOUNTED_UNITS = {
    "gdl_light_horse": gdl_light_horse, "gdl_lit_lance": gdl_lit_lance, "to_knight_brother": to_knight_brother,
    "to_prussian_rider": to_prussian_rider, "hero_gintaut": hero_gintaut, "hero_kuchmeister": hero_kuchmeister,
}
WAGONS = {"gdl_wagon": gdl_wagon}
BIG_BEASTS = ("nt_bison", "nt_elk")
