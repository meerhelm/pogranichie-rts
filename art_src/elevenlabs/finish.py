"""Turns the picked raw variants into game files: audio/sfx/<id>_<k>.ogg (k = 1, 2, ... in pick order).

Usage: python3 art_src/elevenlabs/finish.py [--ids a,b]   # needs ffmpeg and numpy
Then import in Godot (--headless --import) and commit audio/sfx (Git LFS: from the Mac).

Per file: decode at 48 kHz; mono except ambience and loops (stereo); one-shots lose the silence
before and after the sound (a few ms kept) and get a short fade-out; loops stay as generated (the
API makes them seamless). The level is set by group, RMS over the audible part, and lowered when
the peak would pass -1 dBFS (levels in LEVEL).
"""
import argparse, json, subprocess, tempfile, wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SR = 48000
## Target RMS of the audible part, dBFS, by group.
LEVEL = {"ALERT": -16.0, "UI": -22.0, "ACK": -20.0, "WORLD": -18.0, "MAGIC": -18.0, "AMB": -24.0}
PEAK = 10 ** (-1.0 / 20)


def decode(path: Path, channels: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", str(channels), "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


def trim(x: np.ndarray) -> np.ndarray:
    win = SR // 200  # 5 ms frames
    n = len(x) // win
    if n < 2:
        return x
    env = np.sqrt(np.mean(x[: n * win].reshape(n, win, -1) ** 2, axis=(1, 2)))
    top = env.max()
    on = np.nonzero(env > top * 10 ** (-50 / 20))[0]
    if len(on) == 0:
        return x
    start = max(0, on[0] - 2) * win
    end = min(len(x), (on[-1] + 3) * win)
    return x[start:end]


def fade_out(x: np.ndarray) -> np.ndarray:
    n = min(len(x) // 5, int(SR * 0.04))
    if n > 1:
        x[-n:] *= np.linspace(1, 0, n, dtype=np.float32)[:, None]
    return x


def level(x: np.ndarray, target_db: float) -> np.ndarray:
    win = SR // 100
    n = len(x) // win
    if n == 0:
        return x
    env = np.sqrt(np.mean(x[: n * win].reshape(n, win, -1) ** 2, axis=(1, 2)))
    loud = env[env > env.max() * 0.1]
    rms = float(np.sqrt(np.mean(loud ** 2))) if len(loud) else float(env.max())
    gain = 10 ** (target_db / 20) / max(rms, 1e-6)
    peak = float(np.abs(x).max()) * gain
    if peak > PEAK:
        gain *= PEAK / peak
    return x * gain


def write_ogg(x: np.ndarray, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(x.shape[1])
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5",
                        str(dst)], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids")
    a = ap.parse_args()
    spec = json.loads((HERE / "sfx.json").read_text())
    picks = json.loads((HERE / "picks.json").read_text())["picks"]
    raw = REPO / spec["out_dir"]
    out = REPO / "audio/sfx"
    only = set(a.ids.split(",")) if a.ids else None
    done = 0
    for s in spec["sounds"]:
        sid = s["id"]
        if only and sid not in only or sid not in picks:
            continue
        loop = bool(s.get("loop"))
        stereo = loop or s["group"] == "AMB"
        for k, n in enumerate(picks[sid], 1):
            src = raw / sid / f"{sid}_{n}.mp3"
            x = decode(src, 2 if stereo else 1)
            if not loop:
                x = fade_out(trim(x))
            x = level(x, LEVEL[s["group"]])
            write_ogg(x, out / f"{sid}_{k}.ogg")
            done += 1
    print(f"{done} files in {out}")


if __name__ == "__main__":
    main()
