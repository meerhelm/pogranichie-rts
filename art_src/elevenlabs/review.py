"""Writes <out_dir>/review.html: every generated variant with a player and a checkbox.

Usage: python3 art_src/elevenlabs/review.py [--batch trial]
Open the page in a browser, tick the variants worth keeping (or write a note), then press
"Copy picks" and paste the text into the chat. Ticks survive a reload (localStorage).
"""
import argparse, html, json
from pathlib import Path

HERE = Path(__file__).resolve().parent

PAGE = """<!doctype html><meta charset="utf-8"><title>Pogranichie SFX review</title>
<style>
body{font:14px system-ui,sans-serif;margin:16px;background:#1d1a16;color:#eee}
h2{margin:28px 0 6px;color:#e0b46c;font-size:16px}
.s{border-top:1px solid #444;padding:8px 0}
.id{font-weight:600}.w{color:#aaa}.p{color:#8fa; font-size:12px;margin:2px 0 6px}
.v{display:inline-flex;align-items:center;gap:4px;margin:2px 10px 2px 0}
audio{height:28px;width:220px}
input[type=text]{width:320px;background:#2b2722;color:#eee;border:1px solid #555}
#bar{position:sticky;top:0;background:#1d1a16;padding:8px 0;border-bottom:1px solid #555}
button{font-size:14px;padding:4px 12px}
textarea{width:100%;height:120px;background:#2b2722;color:#eee}
</style>
<div id="bar"><button onclick="copyPicks()">Copy picks</button> <span id="cnt"></span>
<textarea id="out" placeholder="picks appear here"></textarea></div>
BODY
<script>
const K='pogranichie-sfx-picks';
let st={};try{st=JSON.parse(localStorage.getItem(K)||'{}')}catch(e){}
document.querySelectorAll('input[data-f]').forEach(c=>{c.checked=!!st[c.dataset.f];
 c.onchange=()=>{st[c.dataset.f]=c.checked;save()}});
document.querySelectorAll('input[data-note]').forEach(t=>{t.value=st['note:'+t.dataset.note]||'';
 t.oninput=()=>{st['note:'+t.dataset.note]=t.value;save()}});
function save(){try{localStorage.setItem(K,JSON.stringify(st))}catch(e){};count()}
function count(){document.getElementById('cnt').textContent=
 document.querySelectorAll('input[data-f]:checked').length+' picked'}
function copyPicks(){const lines=[];
 document.querySelectorAll('.s').forEach(s=>{const id=s.dataset.id;
  const v=[...s.querySelectorAll('input[data-f]:checked')].map(c=>c.dataset.n);
  const n=s.querySelector('input[data-note]').value.trim();
  if(v.length||n)lines.push(id+': '+(v.join(',')||'-')+(n?'  // '+n:''))});
 const t=lines.join('\\n');document.getElementById('out').value=t;
 navigator.clipboard&&navigator.clipboard.writeText(t)}
count();
</script>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default=str(HERE / "sfx.json"))
    ap.add_argument("--batch")
    a = ap.parse_args()
    spec = json.loads(Path(a.spec).read_text())
    root = Path(spec["out_dir"])
    if not root.is_absolute():
        root = HERE.parent.parent / root
    keep = set(spec["batches"][a.batch]) if a.batch else None
    parts, group = [], None
    for s in spec["sounds"]:
        if keep is not None and s["id"] not in keep:
            continue
        files = sorted((root / s["id"]).glob(f"{s['id']}_*.mp3"),
                       key=lambda p: int(p.stem.rsplit("_", 1)[1]))
        if not files:
            continue
        if s["group"] != group:
            group = s["group"]
            parts.append(f"<h2>{group}</h2>")
        vs = "".join(
            f'<label class="v"><input type="checkbox" data-f="{f.name}" data-n="{f.stem.rsplit("_", 1)[1]}">'
            f'{f.stem.rsplit("_", 1)[1]} <audio controls preload="none" src="{s["id"]}/{f.name}"></audio></label>'
            for f in files)
        parts.append(
            f'<div class="s" data-id="{s["id"]}"><span class="id">{s["id"]}</span> '
            f'<span class="w">— {html.escape(s["when"])}</span>'
            f'<div class="p">{html.escape(s["prompt"])}</div>{vs}<br>'
            f'<input type="text" data-note="{s["id"]}" placeholder="note"></div>')
    out = root / "review.html"
    out.write_text(PAGE.replace("BODY", "\n".join(parts)))
    print(out)


if __name__ == "__main__":
    main()
