"""Job files for a batch of pixel units (Retro Diffusion), stage by stage.

    python3 art_src/pixel_iso/unit_jobs.py batch.json base   # one view each (2 images)
    python3 art_src/pixel_iso/unit_jobs.py batch.json rot    # 8-way turn of the picked view
    python3 art_src/pixel_iso/unit_jobs.py batch.json anim   # idle / walk / attack, facings 0 1 2 6 7

Each stage writes art_src/pixel_iso/full/jobs/<batch>_<stage>.json for rd_client.py. batch.json:
{"name": "b4", "units": {"<id>": {"desc": "...", "rider": true, "attack": "...", "pick": 1,
"anims": ["idle", "walk", "attack"]}}}. The anim stage cuts the turn GIF into facings: the turn
starts at no fixed facing, so the frame most like the picked view is facing 1 (down right, as
the view was asked for; "base_facing": 3 when the generator drew it facing down left instead) and
each next frame is 45 degrees clockwise.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / ".rd-trial/iso/units"
JOBS = ROOT / "art_src/pixel_iso/full/jobs"
GEN = (0, 1, 2, 6, 7)
FOOT = "standing in a neutral pose, isometric view facing down right, game unit sprite, no ground, isolated on a plain white background"
RIDE = "standing still, isometric view facing down right, game unit sprite, no ground, isolated on a plain white background"
IDLE = "subtle breathing and weight shifting, seamless loop, standing in place, same size every frame"
WALK = "seamless looping walk cycle in place, same size every frame"
HORSE_WALK = "the horse walks at a steady pace, seamless looping walk cycle in place, same size every frame"


def on_white(im: Image.Image) -> np.ndarray:
    w = Image.new("RGBA", im.size, (255, 255, 255, 255))
    w.alpha_composite(im.convert("RGBA"))
    return np.array(w.convert("RGB"), dtype=float)


def main() -> None:
    spec = json.loads(Path(sys.argv[1]).read_text())
    stage = sys.argv[2]
    name = spec["name"]
    jobs = []
    seed = {"base": 9000, "rot": 9300, "anim": 9600}[stage] + 1000 * int(name.strip("b") or 0)
    for uid, u in spec["units"].items():
        size = [96, 96] if u.get("rider") else [64, 64]
        if stage == "base":
            who = "single mounted rider alone" if u.get("rider") else "single small full body figure alone"
            seed += 1
            jobs.append({"name": uid + "_base", "style": "rd_pro__isometric", "size": size, "num_images": 2,
                         "seed": seed, "remove_bg": True,
                         "prompt": f"{who}, {u['desc']}, {RIDE if u.get('rider') else FOOT}"})
        elif stage == "rot":
            seed += 1
            jobs.append({"name": uid + "_rot", "style": "rd_advanced_animation__rotate", "size": size, "seed": seed,
                         "remove_bg": False, "input_image": str(UNITS / f"{uid}_base_{u.get('pick', 1)}.png"),
                         "prompt": u["desc"][:300]})
        else:
            base = on_white(Image.open(UNITS / f"{uid}_base_{u.get('pick', 1)}.png"))
            gif = Image.open(UNITS / f"{uid}_rot_1.png")
            frames = []
            for i in range(gif.n_frames):
                gif.seek(i)
                frames.append(gif.convert("RGBA"))
            f1 = int(np.argmin([np.abs(on_white(f) - base).mean() for f in frames]))
            for g in GEN:
                f = frames[(f1 + g - u.get("base_facing", 1)) % len(frames)]
                Image.fromarray(on_white(f).astype(np.uint8)).save(UNITS / "dirs" / f"{uid}_g{g}.png")
                for anim in u.get("anims", ["idle", "walk", "attack"]):
                    style = {"idle": "rd_advanced_animation__idle", "walk": "rd_advanced_animation__walking",
                             "attack": "rd_advanced_animation__attack"}[anim]
                    prompt = {"idle": IDLE, "walk": HORSE_WALK if u.get("rider") else WALK,
                              "attack": u.get("attack", "attacks with the weapon, in place")}[anim]
                    seed += 1
                    jobs.append({"name": f"{uid}_{anim}_g{g}", "style": style, "size": size, "seed": seed,
                                 "remove_bg": False, "input_image": str(UNITS / "dirs" / f"{uid}_g{g}.png"),
                                 "prompt": prompt})
            print(uid, "turn frame of facing 1:", f1)
    out_dir = UNITS / (f"anim_{name}" if stage == "anim" else "")
    path = JOBS / f"jobs_units_{name}_{stage}.json"
    path.write_text(json.dumps({"out_dir": str(out_dir).rstrip("/"), "jobs": jobs}, indent=1, ensure_ascii=False))
    print(path, len(jobs), "jobs")


if __name__ == "__main__":
    main()
