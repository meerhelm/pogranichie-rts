"""Minimal Retro Diffusion v2 client. Key from env or ~/.config/retrodiffusion/token; never printed."""
import base64, json, os, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path

BASE = "https://api.retrodiffusion.ai/v2"
OUT = Path(os.environ.get("RD_OUT", "/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/landscape"))
MANIFEST = OUT / "manifest.json"
BUDGET = float(os.environ.get("RD_BUDGET", "2.00"))


def key() -> str:
    for v in ("RD_API_KEY", "RETRODIFFUSION_API_KEY", "RETRO_DIFFUSION_API_KEY", "X_RD_TOKEN"):
        if os.environ.get(v):
            return os.environ[v].strip()
    p = Path.home() / ".config/retrodiffusion/token"
    return p.read_text().strip()


def req(method, path, body=None, headers=None):
    h = {"X-RD-Token": key(), "Content-Type": "application/json"}
    h.update(headers or {})
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"_http_error": e.code, "body": e.read().decode(errors="replace")[:2000]}


def manifest():
    return json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"entries": [], "spent": 0.0}


def save_manifest(m):
    MANIFEST.write_text(json.dumps(m, indent=2, ensure_ascii=False))


def generate(name, payload, input_files=None):
    """payload: request dict. input_files: {field: path} to base64-encode."""
    OUT.mkdir(parents=True, exist_ok=True)
    m = manifest()
    body = dict(payload)
    for field, path in (input_files or {}).items():
        body[field] = base64.b64encode(Path(path).read_bytes()).decode()
    cost = req("POST", "/inferences", {**body, "check_cost": True})
    if "_http_error" in cost:
        print("check_cost error", cost); return None
    price = float(cost.get("balance_cost", 0))
    if m["spent"] + price > BUDGET + 1e-9:
        print(f"STOP: spent {m['spent']:.3f} + {price:.3f} > {BUDGET}"); return None
    acc = req("POST", "/inferences", body, {"Idempotency-Key": str(uuid.uuid4())})
    entry = {"name": name, "prompt": payload.get("prompt"), "extra_prompt": payload.get("extra_prompt"),
             "style": payload["prompt_style"], "size": [payload["width"], payload["height"]],
             "num_images": payload["num_images"], "seed": payload.get("seed"),
             "inputs": {k: str(v) for k, v in (input_files or {}).items()},
             "other_params": {k: v for k, v in payload.items() if k not in
                              ("prompt", "extra_prompt", "prompt_style", "width", "height", "num_images", "seed")},
             "estimated_cost": price}
    if "_http_error" in acc or "task_id" not in acc:
        entry.update(status="error", error=acc); m["entries"].append(entry); save_manifest(m)
        print("submit error", acc); return None
    tid = acc["task_id"]
    while True:
        t = req("GET", f"/inferences/tasks/{tid}")
        if t.get("status") in ("pending", "running") or "_http_error" in t:
            time.sleep(3); continue
        break
    if t["status"] != "succeeded":
        entry.update(status="failed", error=t.get("error"), task_id=tid); m["entries"].append(entry); save_manifest(m)
        print("failed", t.get("error")); return None
    res = t["result"]
    files = []
    imgs = res.get("base64_images") or []
    for i, b in enumerate(imgs):
        f = OUT / (f"{name}.png" if len(imgs) == 1 else f"{name}_{i + 1}.png")
        f.write_bytes(base64.b64decode(b)); files.append(f.name)
    for i, u in enumerate(res.get("output_urls") or []):
        if not imgs:
            f = OUT / f"{name}_{i + 1}.png"
            urllib.request.urlretrieve(u, f); files.append(f.name)
    spent = float(res.get("balance_cost", price))
    m["spent"] = round(m["spent"] + spent, 4)
    entry.update(status="succeeded", files=files, cost=spent, task_id=tid,
                 remaining_balance=res.get("remaining_balance"))
    m["entries"].append(entry); m["remaining_balance"] = res.get("remaining_balance"); save_manifest(m)
    print(f"ok {name}: {files} cost {spent} total {m['spent']} balance {res.get('remaining_balance')}")
    return files


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "credits":
        print(req("GET", "/inferences/credits"))
    elif cmd == "styles":
        s = req("GET", "/styles/selector" + (sys.argv[2] if len(sys.argv) > 2 else ""))
        print(json.dumps(s, indent=1, ensure_ascii=False)[:20000])
