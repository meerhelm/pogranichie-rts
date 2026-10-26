"""Retro Diffusion v2 batch client for the isometric trials.

Usage: python3 rd_client.py jobs.json [--cap 0.60] [--dry]
Key from ~/.config/retrodiffusion/token (never printed), sent as X-RD-Token.
Prices every job with check_cost first and refuses to run if the sum exceeds --cap.
"""
import argparse, base64, json, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path

BASE = "https://api.retrodiffusion.ai/v2"


def key() -> str:
    return (Path.home() / ".config/retrodiffusion/token").read_text().strip()


def req(method, path, body=None, headers=None):
    h = {"X-RD-Token": key(), "Content-Type": "application/json"}
    h.update(headers or {})
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=180) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"_http_error": e.code, "body": e.read().decode(errors="replace")[:2000]}
    except urllib.error.URLError as e:
        return {"_http_error": "network", "body": str(e)}


def img_b64(path, bg=(255, 255, 255)):
    """PNG as base64 RGB, transparency flattened onto bg (API wants RGB without alpha)."""
    import io
    try:
        from PIL import Image
    except ImportError:
        return base64.b64encode(Path(path).read_bytes()).decode()
    im = Image.open(path).convert("RGBA")
    flat = Image.new("RGBA", im.size, bg + (255,))
    flat.alpha_composite(im)
    buf = io.BytesIO(); flat.convert("RGB").save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def build(job, palette_b64):
    body = {"prompt": job["prompt"], "prompt_style": job["style"],
            "width": job["size"][0], "height": job["size"][1],
            "num_images": job.get("num_images", 1), "seed": job.get("seed"),
            "remove_bg": job.get("remove_bg", True)}
    if palette_b64:
        body["input_palette"] = palette_b64
    if job.get("input_image"):
        body["input_image"] = img_b64(job["input_image"])
    if job.get("reference_images"):
        body["reference_images"] = [img_b64(r) for r in job["reference_images"]]
    body.update(job.get("extra", {}))
    return body


def load_manifest(out):
    p = out / "manifest.json"
    return json.loads(p.read_text()) if p.exists() else {"entries": [], "spent": 0.0}


def save_manifest(out, m):
    (out / "manifest.json").write_text(json.dumps(m, indent=2, ensure_ascii=False))


def available_styles():
    s = req("GET", "/styles/selector")
    return {x["prompt_style"] for x in s.get("styles", [])}


def nearest_style(style, styles):
    if style in styles:
        return style, None
    fallbacks = [s for s in ("rd_plus__isometric_asset", "rd_pro__isometric", "rd_plus__isometric",
                             "rd_pro__isometric_asset") if s in styles]
    tier = style.split("__")[0]
    same = [s for s in fallbacks if s.startswith(tier)]
    pick = (same or fallbacks or [None])[0]
    return pick, f"style {style} not offered by API, used {pick}"


def run_job(job, body, out, m, price):
    entry = {"name": job["name"], "prompt": job["prompt"], "style": body["prompt_style"],
             "requested_style": job["style"], "size": job["size"], "num_images": body["num_images"],
             "seed": body["seed"], "remove_bg": body["remove_bg"],
             "inputs": {"input_palette": job.get("_palette"), "input_image": job.get("input_image"),
                        "reference_images": job.get("reference_images")},
             "extra": job.get("extra"), "estimated_cost": price}
    notes = [n for n in (job.get("note"), job.get("_note")) if n]
    if notes:
        entry["note"] = "; ".join(notes)
    acc = req("POST", "/inferences", body, {"Idempotency-Key": str(uuid.uuid4())})
    if "_http_error" in acc or "task_id" not in acc:
        entry.update(status="error", error=acc)
        m["entries"].append(entry); save_manifest(out, m)
        return False
    tid = acc["task_id"]
    misses = 0
    while True:
        t = req("GET", f"/inferences/tasks/{tid}")
        if "_http_error" in t:
            misses += 1
            if misses > 20:
                entry.update(status="error", error=t, task_id=tid)
                m["entries"].append(entry); save_manifest(out, m)
                return False
        elif t.get("status") not in ("pending", "running", "queued"):
            break
        time.sleep(3)
    if t["status"] != "succeeded":
        entry.update(status="failed", error=t.get("error"), task_id=tid)
        m["entries"].append(entry); save_manifest(out, m)
        return False
    res = t["result"]
    files = []
    imgs = res.get("base64_images") or []
    for i, b in enumerate(imgs):
        f = out / f"{job['name']}_{i + 1}.png"
        f.write_bytes(base64.b64decode(b)); files.append(f.name)
    if not imgs:
        for i, u in enumerate(res.get("output_urls") or []):
            f = out / f"{job['name']}_{i + 1}.png"
            urllib.request.urlretrieve(u, f); files.append(f.name)
    cost = float(res.get("balance_cost", price))
    m["spent"] = round(m["spent"] + cost, 4)
    m["remaining_balance"] = res.get("remaining_balance")
    entry.update(status="succeeded", files=files, cost=cost, task_id=tid,
                 remaining_balance=res.get("remaining_balance"))
    m["entries"].append(entry); save_manifest(out, m)
    print(f"ok {job['name']}: {files} cost {cost} balance {res.get('remaining_balance')}")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("jobs")
    ap.add_argument("--cap", type=float, default=0.60)
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    spec = json.loads(Path(a.jobs).read_text())
    out = Path(spec["out_dir"]); out.mkdir(parents=True, exist_ok=True)
    palette = spec.get("palette")
    palette_b64 = base64.b64encode(Path(palette).read_bytes()).decode() if palette else None

    styles = available_styles()
    prepared, total = [], 0.0
    for job in spec["jobs"]:
        style, note = nearest_style(job["style"], styles)
        if style is None:
            sys.exit(f"no isometric style available for {job['name']}")
        job = dict(job, style=job["style"], _palette=palette, _note=note)
        body = build(job, palette_b64)
        body["prompt_style"] = style
        c = req("POST", "/inferences", {**body, "check_cost": True})
        if "_http_error" in c:
            sys.exit(f"check_cost failed for {job['name']}: {c}")
        price = float(c.get("balance_cost", 0))
        total += price
        prepared.append((job, body, price))
        print(f"price {job['name']} [{style}]: {price}" + (f" ({note})" if note else ""))
    print(f"total {total:.4f} cap {a.cap}")
    if total > a.cap + 1e-9:
        sys.exit("REFUSED: total exceeds cap")
    if a.dry:
        return

    m = load_manifest(out)
    for job, body, price in prepared:
        if not run_job(job, body, out, m, price):
            print(f"retry {job['name']}: {m['entries'][-1].get('error')}")
            if not run_job(job, body, out, m, price):
                sys.exit(f"STOP: {job['name']} failed twice: {m['entries'][-1].get('error')}")
    print(f"spent {m['spent']} remaining {m.get('remaining_balance')}")


if __name__ == "__main__":
    main()
