"""Code-built human figures (1.75 m, feet on zero, front +Y, right hand +X) and their
animations: idle, walk, work (a two-handed chop at the ground: felling, digging, building)
and attack in the figure's style (`ATTACK_STYLES`). A figure is a tree of joint empties;
`pose()` rotates them."""

import math

from tools.art import shapes as S

HIP_Z = 0.92
## swing: overhead blow with what the right hand holds; thrust: a spear driven forward level;
## throw: a javelin thrown overhand; bow: draw and loose a longbow held in the left hand;
## crossbow: aim, shoot, lower and span again; cast: both arms raised to the sky.
ATTACK_STYLES = ("swing", "thrust", "throw", "bow", "crossbow", "cast")


def ease(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def blow(t: float) -> float:
    """Wind up slowly (0 -> 1), strike fast past the rest (1 -> -0.2), recover (-> 0)."""
    if t < 0.5:
        return ease(t / 0.5)
    if t < 0.7:
        return 1.0 - 1.2 * ease((t - 0.5) / 0.2)
    return -0.2 * (1.0 - ease((t - 0.7) / 0.3))


def lunge(t: float) -> float:
    """Draw back (0 -> -1), drive forward fast (-> 1), come back to rest (-> 0)."""
    if t < 0.4:
        return -ease(t / 0.4)
    if t < 0.6:
        return -1.0 + 2.0 * ease((t - 0.4) / 0.2)
    return 1.0 - ease((t - 0.6) / 0.4)


class Figure:
    def __init__(self, name: str):
        self.root = S.empty(name)
        self.hips = S.empty("hips", (0, 0, HIP_Z), self.root)
        self.chest = S.empty("chest", (0, 0, 0), self.hips)
        self.head = S.empty("head", (0, 0, 0.67), self.chest)
        self.joints = {}
        for side, x in (("l", -1), ("r", 1)):
            thigh = S.empty(f"thigh_{side}", (0.1 * x, 0, 0), self.hips)
            knee = S.empty(f"knee_{side}", (0, 0, -0.45), thigh)
            shoulder = S.empty(f"shoulder_{side}", (0.25 * x, 0, 0.5), self.chest)
            elbow = S.empty(f"elbow_{side}", (0, 0, -0.29), shoulder)
            hand = S.empty(f"hand_{side}", (0, 0, -0.27), elbow)
            self.joints.update(
                {f"thigh_{side}": thigh, f"knee_{side}": knee, f"shoulder_{side}": shoulder,
                 f"elbow_{side}": elbow, f"hand_{side}": hand}
            )
        self.held_r = False  # right arm holds a weapon still
        self.held_l = False  # left arm holds a shield still
        self.stoop = 0.0  # forward lean of the chest in every pose (old people)
        self.attack_style = "swing"
        self._held = None  # (empty in the right hand, its rest rotation), found on first pose
        self._offhand = None  # the same for the left hand (a bow)

    def j(self, name):
        return self.joints[name]

    def body(self, skin, shirt, legs, shoes, sleeve=None, wraps=None):
        """Bare body: torso, head, arms, legs with footwear."""
        sleeve = sleeve or shirt
        torso = S.cyl("torso", 0.17, 0.23, 0.52, (0, 0, -0.02), shirt, self.chest, seg=10)
        torso.scale = (1.0, 0.72, 1.0)
        S.cyl("neck", 0.05, 0.05, 0.12, (0, 0, 0.49), skin, self.chest, seg=8)
        S.ball("skull", 0.125, (0, 0.0, 0.0), skin, self.head, scale=(0.92, 1.0, 1.05))
        S.ball("nose", 0.026, (0, 0.118, -0.01), skin, self.head)
        for side in ("l", "r"):
            S.limb(f"upper_{side}", 0.08, 0.068, 0.3, sleeve, self.j(f"shoulder_{side}"))
            S.limb(f"fore_{side}", 0.068, 0.056, 0.28, sleeve, self.j(f"elbow_{side}"))
            S.ball(f"fist_{side}", 0.058, (0, 0, -0.02), skin, self.j(f"hand_{side}"))
            S.limb(f"thighm_{side}", 0.1, 0.082, 0.46, legs, self.j(f"thigh_{side}"))
            S.limb(f"shin_{side}", 0.078, 0.064, 0.42, wraps or legs, self.j(f"knee_{side}"))
            foot = S.box(
                f"foot_{side}", (0.12, 0.27, 0.09), (0, 0.06, -0.42), shoes, self.j(f"knee_{side}")
            )
            foot.parent = self.j(f"knee_{side}")
        return self

    def hair(self, material, beard=True):
        S.ball("hair", 0.13, (0, -0.015, 0.02), material, self.head, scale=(0.95, 1.0, 0.95))
        if beard:
            S.ball("beard", 0.085, (0, 0.075, -0.085), material, self.head, scale=(1.1, 0.8, 1.0))
        return self

    def skirt(self, name, top_z, bottom_z, r_top, r_bottom, material):
        """Coat or shirt skirt hanging from the waist (z relative to the hips)."""
        sk = S.cyl(name, r_bottom, r_top, top_z - bottom_z, (0, 0, bottom_z), material,
                   self.hips, seg=12)
        sk.scale = (1.0, 0.85, 1.0)
        return sk

    def _weapon(self, side: str):
        """The empty a weapon hangs from in that hand (spear, staff, bow...), with its rest
        rotation; (None, None) when the hand holds nothing turnable."""
        cache = "_held" if side == "r" else "_offhand"
        if getattr(self, cache) is None:
            found = (None, None)
            for child in self.j(f"hand_{side}").children:
                if child.type == "EMPTY":
                    found = (child, tuple(child.rotation_euler))
                    break
            setattr(self, cache, found)
        return getattr(self, cache)

    def pose(self, anim: str, frame: int, frames: int) -> None:
        p = 2.0 * math.pi * frame / frames
        r = math.radians
        rot = {k: [0.0, 0.0, 0.0] for k in self.joints}
        hips_z = HIP_Z
        chest_x = 0.0
        head_z = 0.0
        if anim == "walk":
            s, c = math.sin(p), math.cos(p)
            rot["thigh_l"][0] = r(26) * s
            rot["thigh_r"][0] = -r(26) * s
            rot["knee_l"][0] = -r(8) - r(38) * max(0.0, c)
            rot["knee_r"][0] = -r(8) - r(38) * max(0.0, -c)
            rot["shoulder_l"][0] = -r(22) * s
            rot["shoulder_r"][0] = r(22) * s
            rot["elbow_l"][0] = r(12) + r(10) * max(0.0, -s)
            rot["elbow_r"][0] = r(12) + r(10) * max(0.0, s)
            hips_z = HIP_Z - 0.03 + 0.03 * abs(math.cos(p))
            chest_x = r(4)
        elif anim in ("work", "attack"):
            pass
        else:  # idle: breathing and a slow look around
            chest_x = r(1.5) * math.sin(p)
            head_z = r(6) * math.sin(p)
            rot["elbow_l"][0] = rot["elbow_r"][0] = r(8)
            rot["shoulder_l"][1] = -r(4)
            rot["shoulder_r"][1] = r(4)
        if self.held_r:
            rot["shoulder_r"] = [r(18), r(6), 0.0]
            rot["elbow_r"] = [r(62), 0.0, 0.0]
        if self.held_l:
            rot["shoulder_l"] = [r(30), r(8), 0.0]
            rot["elbow_l"] = [r(75), 0.0, -r(20)]
        held, held_rest = self._weapon("r")
        bow, bow_rest = self._weapon("l")
        if held is not None:
            held.rotation_euler = held_rest
        if bow is not None:
            bow.rotation_euler = bow_rest
        t = frame / frames
        if anim == "work":
            chest_x, hips_z = self._work(rot, t)
        elif anim == "attack":
            chest_x = self._attack(rot, t)
        for k, v in rot.items():
            self.joints[k].rotation_euler = v
        self.hips.location.z = hips_z
        self.chest.rotation_euler = (chest_x + self.stoop, 0.0, 0.0)
        self.head.rotation_euler = (0.0, 0.0, head_z)

    def _level(self, side: str, rot, chest_x: float, angle: float = -90.0, twist: bool = True) -> None:
        """Turns what the hand holds to `angle` degrees off upright (-90: straight forward),
        whatever the arm does."""
        weapon, rest = self._weapon(side)
        if weapon is None:
            return
        arm = chest_x + self.stoop + rot[f"shoulder_{side}"][0] + rot[f"elbow_{side}"][0]
        weapon.rotation_euler = (math.radians(angle) - arm, rest[1], rest[2] if twist else 0.0)

    def _work(self, rot, t: float):
        """Two-handed chop at the ground, bent at the knees."""
        r = math.radians
        w = blow(t)
        for side in ("l", "r"):
            rot[f"shoulder_{side}"] = [r(25) + r(135) * w, r(10) if side == "l" else -r(10), 0.0]
            rot[f"elbow_{side}"] = [r(15) + r(35) * max(w, 0.0), 0.0, 0.0]
            rot[f"thigh_{side}"] = [r(16), 0.0, 0.0]
            rot[f"knee_{side}"] = [-r(26), 0.0, 0.0]
        rot["thigh_l"][0] += r(10)
        chest_x = r(20) - r(16) * w
        return chest_x, HIP_Z - 0.05

    def _attack(self, rot, t: float) -> float:
        r = math.radians
        style = self.attack_style
        chest_x = 0.0
        if style in ("swing", "throw"):
            w = blow(t)
            rot["shoulder_r"] = [r(35) + r(130) * w, -r(8), 0.0]
            rot["elbow_r"] = [r(20) + r(45) * max(w, 0.0), 0.0, 0.0]
            if not self.held_l:
                rot["shoulder_l"] = [r(25) - r(15) * w, r(6), 0.0]
                rot["elbow_l"] = [r(20), 0.0, 0.0]
            chest_x = r(10) - r(14) * w
            rot["thigh_l"][0] = r(14)
            rot["thigh_r"][0] = -r(8)
            if style == "throw":
                self._level("r", rot, chest_x)
        elif style == "thrust":
            e = lunge(t)
            rot["shoulder_r"] = [r(28) + r(42) * e, -r(6), 0.0]
            rot["elbow_r"] = [max(r(5), r(65) - r(50) * e), 0.0, 0.0]
            chest_x = r(6) * e + r(4)
            rot["thigh_l"][0] = r(18) + r(8) * max(e, 0.0)
            rot["thigh_r"][0] = -r(10)
            rot["knee_l"][0] = -r(12)
            self._level("r", rot, chest_x, -84.0)
        elif style == "bow":
            draw = ease(t / 0.5)
            loose = t >= 0.62
            back = ease((t - 0.62) / 0.38) if loose else 0.0
            rot["shoulder_l"] = [r(84) - r(10) * back, r(14), 0.0]
            rot["elbow_l"] = [r(4), 0.0, 0.0]
            rot["shoulder_r"] = [r(84) - (r(14) if loose else 0.0) - r(20) * back, -r(12), 0.0]
            rot["elbow_r"] = [r(10) + r(115) * (draw if not loose else 1.0 - back), 0.0, 0.0]
            chest_x = -r(4)
            rot["thigh_l"][0] = r(12)
            rot["thigh_r"][0] = -r(8)
            self._level("l", rot, chest_x, 0.0)
        elif style == "crossbow":
            # Aim and shoot (kick at 0.3), then lower it, span and raise it again.
            low = math.sin(math.pi * ease((t - 0.45) / 0.55)) if t > 0.45 else 0.0
            kick = r(10) if 0.3 <= t < 0.42 else 0.0
            for side in ("l", "r"):
                rot[f"shoulder_{side}"] = [r(92) - kick - r(60) * low, r(10) if side == "l" else -r(4), 0.0]
                rot[f"elbow_{side}"] = [r(55) - r(10) * low, 0.0, 0.0]
            chest_x = r(14) * low
            self._level("r", rot, chest_x, -90.0 + 60.0 * low, twist=False)
        elif style == "cast":
            k = math.sin(math.pi * t)
            rot["shoulder_r"] = [r(20) + r(140) * k, -r(10), 0.0]
            rot["elbow_r"] = [r(10), 0.0, 0.0]
            if not self.held_l:
                rot["shoulder_l"] = [r(15) + r(140) * k, r(10), 0.0]
                rot["elbow_l"] = [r(10), 0.0, 0.0]
            chest_x = -r(8) * k
        return chest_x
