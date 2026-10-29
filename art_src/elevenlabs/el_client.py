"""ElevenLabs sound effects client (POST https://api.elevenlabs.io/v1/sound-generation).

Usage:
  python3 art_src/elevenlabs/el_client.py --batch trial --dry       # free: count generations
  python3 art_src/elevenlabs/el_client.py --batch trial --cap 120   # run, at most 120 generations
  python3 art_src/elevenlabs/el_client.py --ids ui_click,bow_shot   # only these sounds
  python3 art_src/elevenlabs/el_client.py --all --cap 700

The list is art_src/elevenlabs/sfx.json: each sound has an id, a prompt, a group whose tail is
appended to the prompt, a length in seconds, a loop flag and a number of variants. One variant is
one generation. The key comes from ~/.config/elevenlabs/token (never printed, never in the repo).
Results land in <out_dir>/<id>/<id>_<n>.mp3; variants already on disk are skipped, so a rerun only
fills the gaps. Then python3 art_src/elevenlabs/review.py writes the listening page.
"""
import argparse, json, sys, time, urllib.error, urllib.request
from pathlib import Path

URL = "https://api.elevenlabs.io/v1/sound-generation"
HERE = Path(__file__).resolve().parent


def key() -> str:
    return (Path.home() / ".config/elevenlabs/token").read_text().strip()


def prompt_of(spec: dict, s: dict) -> str:
    tail = spec["tails"].get(s["group"], "")
    return (s["prompt"].rstrip(".") + ". " + tail).strip()


def generate(spec: dict, s: dict) -> bytes:
    body = {
        "text": prompt_of(spec, s),
        "duration_seconds": max(0.5, min(30.0, float(s["seconds"]))),
        "prompt_influence": s.get("prompt_influence", spec["prompt_influence"]),
        "loop": bool(s.get("loop", False)),
        "model_id": s.get("model_id", spec["model_id"]),
    }
    r = urllib.request.Request(URL + "?output_format=" + spec["output_format"],
                               data=json.dumps(body).encode(), method="POST",
                               headers={"xi-api-key": key(), "Content-Type": "application/json"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(r, timeout=180) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")[:500]
            if e.code in (429, 500, 502, 503) and attempt < 4:
                time.sleep(10 * (attempt + 1))
                continue
            raise RuntimeError(f"HTTP {e.code}: {text}")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if attempt < 4:
                time.sleep(10)
                continue
            raise RuntimeError(f"network: {e}")
    raise RuntimeError("unreachable")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default=str(HERE / "sfx.json"))
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--batch")
    g.add_argument("--ids")
    g.add_argument("--all", action="store_true")
    ap.add_argument("--cap", type=int, default=0, help="stop after this many generations (0 = no cap)")
    ap.add_argument("--variants", type=int, default=0, help="override the number of variants")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    spec = json.loads(Path(a.spec).read_text())
    by_id = {s["id"]: s for s in spec["sounds"]}
    if a.all:
        ids = list(by_id)
    elif a.batch:
        ids = spec["batches"][a.batch]
    else:
        ids = [i.strip() for i in a.ids.split(",") if i.strip()]
    missing = [i for i in ids if i not in by_id]
    if missing:
        print("unknown ids:", ", ".join(missing))
        return 1

    root = Path(spec["out_dir"])
    if not root.is_absolute():
        root = HERE.parent.parent / root
    todo = []
    for i in ids:
        s = by_id[i]
        n = a.variants or s["variants"]
        for v in range(1, n + 1):
            f = root / i / f"{i}_{v}.mp3"
            if not f.exists():
                todo.append((s, f))
    secs = sum(float(s["seconds"]) for s, _ in todo)
    print(f"{len(ids)} sounds, {len(todo)} generations to make, {secs / 60:.1f} min of audio")
    if a.dry:
        for s, f in todo[:400]:
            print(f"  {f.name:32s} {s['seconds']:>5}s {'loop ' if s.get('loop') else ''}{prompt_of(spec, s)}")
        return 0

    made = failed = 0
    log = root / "log.jsonl"
    root.mkdir(parents=True, exist_ok=True)
    for s, f in todo:
        if a.cap and made >= a.cap:
            print(f"cap {a.cap} reached")
            break
        f.parent.mkdir(parents=True, exist_ok=True)
        try:
            audio = generate(spec, s)
        except RuntimeError as e:
            failed += 1
            print(f"FAIL {f.name}: {e}")
            if "401" in str(e) or "quota" in str(e).lower():
                break
            continue
        f.write_bytes(audio)
        made += 1
        with log.open("a") as lf:
            lf.write(json.dumps({"file": f.name, "prompt": prompt_of(spec, s), "seconds": s["seconds"],
                                 "loop": bool(s.get("loop")), "model": spec["model_id"],
                                 "time": time.strftime("%Y-%m-%d %H:%M:%S")}, ensure_ascii=False) + "\n")
        print(f"ok {made}/{len(todo)} {f.name} ({len(audio) // 1024} KB)")
    print(f"done: {made} made, {failed} failed")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
