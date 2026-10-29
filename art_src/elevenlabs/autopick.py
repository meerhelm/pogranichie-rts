"""Picks the best generated variants without listening: defect checks + CLAP text match + typicality.

Usage:
  python3 art_src/elevenlabs/autopick.py --batch rest            # writes raw/autopick_rest.json
  python3 art_src/elevenlabs/autopick.py --batch trial --compare art_src/elevenlabs/picks.json
  python3 art_src/elevenlabs/review.py --batch rest --picks art_src/elevenlabs/raw/autopick_rest.json

Needs ffmpeg (decoding) and, for CLAP, `pip install torch transformers numpy` (model
laion/clap-htsat-unfused, ~600 MB, downloaded once). Without CLAP (--no-clap) only the defect
checks and loudness typicality are used.

Per variant:
- defects: near-silence, clipping, long silence at the start, length far from the requested one,
  for loops a jump between the end and the start;
- clap: cosine between the audio and the sound's own prompt (without the group tail);
- typical: cosine to the mean audio embedding of the other variants of the same sound
  (an odd generation lands far from its siblings).
score = clap + 0.5 * typical - penalties. One pick for alerts, UI, acknowledgements, magic and
ambience loops; up to three for world sounds (combat, work, buildings), only those close to the best.
"""
import argparse, json, subprocess
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SR = 48000
MULTI = {"WORLD": 3}


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def db(x: float) -> float:
    return 20 * np.log10(max(x, 1e-9))


def defects(x: np.ndarray, s: dict) -> tuple[float, list[str]]:
    pen, why = 0.0, []
    if len(x) == 0:
        return 99.0, ["empty"]
    rms = float(np.sqrt(np.mean(x ** 2)))
    if db(rms) < -45:
        pen += 5; why.append(f"silent {db(rms):.0f} dB")
    clip = float(np.mean(np.abs(x) > 0.995))
    if clip > 0.001:
        pen += min(2.0, clip * 200); why.append(f"clipping {clip * 100:.1f}%")
    win = SR // 100
    frames = np.sqrt(np.mean(x[: len(x) // win * win].reshape(-1, win) ** 2, axis=1))
    loud = frames > max(rms * 0.1, 1e-4)
    if not s.get("loop") and loud.any():
        lead = int(np.argmax(loud)) / 100
        if lead > 0.15:
            pen += min(2.0, lead * 2); why.append(f"starts late {lead:.2f}s")
    want = float(s["seconds"])
    have = len(x) / SR
    if abs(have - want) > max(0.3, want * 0.25):
        pen += 1.0; why.append(f"length {have:.1f}s of {want}s")
    if s.get("loop") and len(frames) > 4:
        a, b = frames[:3].mean(), frames[-3:].mean()
        seam = abs(db(a) - db(b))
        jump = abs(float(x[0]) - float(x[-1]))
        if seam > 6 or jump > 0.2:
            pen += 1.5; why.append(f"loop seam {seam:.0f} dB")
    return pen, why


class Clap:
    def __init__(self):
        import torch
        from transformers import ClapModel, ClapProcessor
        self.torch = torch
        self.model = ClapModel.from_pretrained("laion/clap-htsat-unfused").eval()
        self.proc = ClapProcessor.from_pretrained("laion/clap-htsat-unfused")

    def audio(self, xs):
        with self.torch.no_grad():
            inp = self.proc(audios=[x[: SR * 10] for x in xs], sampling_rate=SR, return_tensors="pt")
            e = self.model.get_audio_features(**inp)
        return self.torch.nn.functional.normalize(e, dim=-1).numpy()

    def text(self, t):
        with self.torch.no_grad():
            inp = self.proc(text=[t], return_tensors="pt", padding=True)
            e = self.model.get_text_features(**inp)
        return self.torch.nn.functional.normalize(e, dim=-1).numpy()[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default=str(HERE / "sfx.json"))
    ap.add_argument("--batch", required=True)
    ap.add_argument("--no-clap", action="store_true")
    ap.add_argument("--compare", help="a picks.json made by ear, to report agreement")
    a = ap.parse_args()
    spec = json.loads(Path(a.spec).read_text())
    root = Path(spec["out_dir"])
    if not root.is_absolute():
        root = HERE.parent.parent / root
    clap = None if a.no_clap else Clap()
    by_id = {s["id"]: s for s in spec["sounds"]}
    out = {}
    for sid in spec["batches"][a.batch]:
        s = by_id[sid]
        files = sorted((root / sid).glob(f"{sid}_*.mp3"), key=lambda p: int(p.stem.rsplit("_", 1)[1]))
        if not files:
            continue
        xs = [decode(f) for f in files]
        rows = []
        if clap:
            emb = clap.audio(xs)
            t = clap.text(s["prompt"])
            sims = emb @ t
            mean = emb.mean(axis=0)
        for i, (f, x) in enumerate(zip(files, xs)):
            pen, why = defects(x, s)
            if clap:
                others = (mean * len(xs) - emb[i]) / max(1, len(xs) - 1)
                typ = float(emb[i] @ others / (np.linalg.norm(others) + 1e-9)) if len(xs) > 1 else 1.0
                score = float(sims[i]) + 0.5 * typ - pen
                info = {"clap": round(float(sims[i]), 3), "typical": round(typ, 3)}
            else:
                score, info = -pen, {}
            rows.append({"n": int(f.stem.rsplit("_", 1)[1]), "score": round(score, 3),
                         "defects": why, **info})
        rows.sort(key=lambda r: -r["score"])
        k = MULTI.get(s["group"], 1) if not s.get("loop") else 1
        best = rows[0]["score"]
        chosen = [r["n"] for r in rows[:k] if not r["defects"] and r["score"] >= best - 0.08] or [rows[0]["n"]]
        out[sid] = {"picks": chosen, "ranked": rows}
        print(f"{sid:28s} -> {chosen}  " + "  ".join(f"{r['n']}:{r['score']}" for r in rows))
    dst = root / f"autopick_{a.batch}.json"
    dst.write_text(json.dumps(out, ensure_ascii=False, indent=1))
    print(dst)
    if a.compare:
        ear = {k: v for k, v in json.loads(Path(a.compare).read_text())["picks"].items() if k in out}
        hit = [sid for sid in ear if sid in out and set(ear[sid]) & set(out[sid]["picks"])]
        top2 = [sid for sid in ear if sid in out and ear[sid][0] in [r["n"] for r in out[sid]["ranked"][:2]]]
        print(f"agreement with ear: {len(hit)}/{len(ear)} same pick, {len(top2)}/{len(ear)} in top 2")


if __name__ == "__main__":
    main()
