"""Code-built human figures (1.75 m, feet on zero, front +Y, right hand +X) and their
idle / walk animation. A figure is a tree of joint empties; `pose()` rotates them."""

import math

from tools.art import shapes as S

HIP_Z = 0.92


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
        for k, v in rot.items():
            self.joints[k].rotation_euler = v
        self.hips.location.z = hips_z
        self.chest.rotation_euler = (chest_x + self.stoop, 0.0, 0.0)
        self.head.rotation_euler = (0.0, 0.0, head_z)
