"""PixelLab v2 client for the ground tiles (https://api.pixellab.ai/v2).

Usage: python3 art_src/pixellab/pl_client.py jobs.json [--resume]
Key from ~/.config/pixellab/token (never printed), sent as a Bearer token. A job is a
/create-tiles-pro request (ground tiles) or, with "endpoint": "/generate-with-style-v2", a set
of 16 icon variants. `style_from` names our current atlases (art/tiles/<id>.png) whose first
diamond goes in as a style image; `style_images` names whole pictures (the pixel order icons).
The results land in <out_dir>/<name>/tile_<i>.png (or icon_<i>.png) and
the manifest records the generations spent. PixelLab bills in generations of the account's
plan, not in dollars.
"""
import argparse, base64, io, json, sys, time, urllib.request, urllib.error
from pathlib import Path

BASE = "https://api.pixellab.ai/v2"
UA = {"User-Agent": "Mozilla/5.0"}  # the file storage refuses Python's default agent


def key() -> str:
    return (Path.home() / ".config/pixellab/token").read_text().strip()


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": "Bearer " + key(), "Content-Type": "application/json"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(r, timeout=300) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503) and attempt < 4:
                time.sleep(10 * (attempt + 1))
                continue
            return {"_http_error": e.code, "body": e.read().decode(errors="replace")[:2000]}
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if attempt < 4:
                time.sleep(10)
                continue
            return {"_http_error": "network", "body": str(e)}


def style_image(atlas: str) -> dict:
    """The first 64x32 diamond of one of our terrain atlases (96x48 tiles, 16/8 px rim)."""
    from PIL import Image
    im = Image.open(atlas).convert("RGBA").crop((16, 8, 80, 40))
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return {"base64": base64.b64encode(buf.getvalue()).decode(), "width": 64, "height": 32}


def whole_image(path: str) -> dict:
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return {"image": {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"},
            "width": im.width, "height": im.height}


def wait(job_id):
    while True:
        j = call("GET", f"/background-jobs/{job_id}")
        if j.get("status") not in ("processing", "pending", "queued", "running"):
            return j
        time.sleep(5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("jobs")
    ap.add_argument("--resume", action="store_true")
    a = ap.parse_args()
    spec = json.loads(Path(a.jobs).read_text())
    out = Path(spec["out_dir"])
    out.mkdir(parents=True, exist_ok=True)
    mpath = out / "manifest.json"
    m = json.loads(mpath.read_text()) if mpath.exists() else {"entries": [], "generations": 0}
    done = {e["name"] for e in m["entries"] if e.get("status") == "completed"} if a.resume else set()
    for job in spec["jobs"]:
        if job["name"] in done:
            continue
        body = dict(spec.get("defaults", {}), **job["request"])
        endpoint = job.get("endpoint", spec.get("endpoint", "/create-tiles-pro"))
        if job.get("style_from"):
            body["style_images"] = [style_image(p) for p in job["style_from"]]
        if spec.get("style_images") or job.get("style_images"):
            body["style_images"] = [whole_image(p) for p in job.get("style_images", spec.get("style_images"))]
        r = call("POST", endpoint, body)
        if "background_job_id" not in r:
            print("FAILED", job["name"], r)
            m["entries"].append({"name": job["name"], "status": "error", "error": r})
            continue
        j = wait(r["background_job_id"])
        entry = {"name": job["name"], "status": j.get("status"), "tile_id": r.get("tile_id"),
                 "request": {k: v for k, v in body.items() if k != "style_images"},
                 "style_from": job.get("style_from"), "usage": j.get("usage")}
        if j.get("status") == "completed":
            d = out / job["name"]
            d.mkdir(exist_ok=True)
            if r.get("tile_id"):
                t = call("GET", "/tiles-pro/" + r["tile_id"])
                for k, u in t.get("storage_urls", {}).items():
                    (d / f"{k}.png").write_bytes(urllib.request.urlopen(urllib.request.Request(u, headers=UA)).read())
                entry["files"] = len(t.get("storage_urls", {}))
            else:
                imgs = (j.get("last_response") or {}).get("images") or []
                for i, im in enumerate(imgs):
                    (d / f"icon_{i}.png").write_bytes(base64.b64decode(im["base64"]))
                entry["files"] = len(imgs)
            m["generations"] += (j.get("usage") or {}).get("generations", 0)
        m["entries"].append(entry)
        mpath.write_text(json.dumps(m, indent=1, ensure_ascii=False))
        print(job["name"], entry["status"], entry.get("usage"), entry.get("files"), flush=True)
    print("generations spent here:", m["generations"])


if __name__ == "__main__":
    main()
