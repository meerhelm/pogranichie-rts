"""Unit and hero cards: every catalog unit that has a sprite and every campaign hero, on a patch of grass with its data, for review.

Step 1 (this script) draws the unit three times (standing, walking, striking; walking only
for units without a strike) with shadow and team mask in the faction colour, on grass tiles at
twice the map scale, and writes `cards.json` beside the pictures with the catalog's name,
faction, age, building, cost, training time, population, HP, damage, reload, range, armour,
speed, morale and abilities. Step 2 is the same `building_cards.gd` as for buildings (it lays
out a card by its `kind`); step 3 zips them (see docs/dev/cards/README.md).

    python3 -m tools.art.unit_cards /tmp/ucards
    godot -s tools/art/building_cards.gd -- /tmp/ucards
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image

from tools.art import building_cards
from tools.art.building_cards import CATALOG, TEAM, ground, tint

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / "art" / "sprites" / "units"
## Units drawn with another's art, as game/world/sprite_db.gd ALIASES.
ALIASES = {"pl_field_gun": "gdl_field_gun", "pl_camp_servant": "gdl_camp_servant", "pl_bombard": "to_bombard",
           "mo_tatar": "nt_steppe_archer", "pl_merc_horse": "to_merc_horse"}
## Pose: animation, facing (0 east, clockwise, 2 south), frame.
POSES = (("idle", 3, 0), ("walk", 2, 2), ("attack", 1, 3))
def building_names(c: dict) -> dict[str, str]:
    names: dict[str, str] = {}
    for b in c["common_buildings"]:
        for fac in ("gdl", "pl", "to", "mo"):
            if b.get(f"name_{fac}"):
                names[f"{fac}:{b['id']}"] = b[f"name_{fac}"]
    for b in c["buildings"]:
        bid = b["id"].rstrip("*")
        names[f"{b['faction']}:{bid}"] = b["name"].rstrip("*")
        names[f"{b['faction']}:{bid.split('_', 1)[1] if bid.startswith(b['faction'] + '_') else bid}"] = b["name"].rstrip("*")
    return names


def where(u: dict, names: dict[str, str]) -> str:
    out = []
    for part in u["building"].split(","):
        p = part.strip()
        out.append(names.get(f"{u['faction']}:{p}", p))
    return ", ".join(out)


def frame(sid: str, kind: str, anim: str, facing: int, index: int) -> tuple[Image.Image, tuple[int, int]]:
    """One frame with shadow, colour and team mask, at twice the map scale; and its pivot."""
    d = UNITS / sid
    meta = json.loads((d / "sheet.json").read_text())
    a = meta["anims"].get(anim) or meta["anims"]["idle"]
    fw, fh = meta["frame"]
    row = a["row"] + facing
    i = index % a["frames"]
    box = (i * fw, row * fh, (i + 1) * fw, (row + 1) * fh)
    color = Image.open(d / "color.png").convert("RGBA").crop(box)
    out = Image.new("RGBA", color.size)
    sh = Image.new("RGBA", color.size, (0, 0, 0, 0))
    sh.putalpha(Image.open(d / "shadow.png").convert("LA").crop(box).getchannel("A").point(lambda v: int(v * 0.7)))
    out.alpha_composite(sh)
    out.alpha_composite(color)
    team = d / "team.png"
    if team.exists() and kind in TEAM:
        out.alpha_composite(tint(Image.open(team).crop(box), TEAM[kind]))
    k = float(meta.get("scale", 1.0)) * 2
    pv = tuple(meta["pivot"])
    if k != 1.0:
        out = out.resize((round(out.width * k), round(out.height * k)), Image.NEAREST if k > 1 else Image.LANCZOS)
        pv = (round(pv[0] * k), round(pv[1] * k))
    return out, pv


def card_image(uid: str, fac: str = "") -> Image.Image:
    sid = ALIASES.get(uid, uid)
    fac = fac or uid.split("_")[0]
    meta = json.loads((UNITS / sid / "sheet.json").read_text())
    poses = [p for p in POSES if p[0] in meta["anims"]]
    figs = [frame(sid, fac, *p) for p in poses]
    boxes = [im.getbbox() for im, _ in figs]
    gap = max(b[2] - b[0] for b in boxes) + 24  # screen pixels between figures
    cells = max(2, -(-(gap * len(figs) + 40) // 128))
    water = uid.endswith("_boat")
    building_cards.TILES = ROOT / "art" / "tiles" / ("t_water.png" if water else "t_grass.png")
    grass, _ = ground(cells, cells, margin=0)
    building_cards.TILES = ROOT / "art" / "tiles" / "t_grass.png"
    grass = grass.resize((grass.width * 2, grass.height * 2), Image.NEAREST)
    pad = 300
    canvas = Image.new("RGBA", (grass.width + 2 * pad, grass.height + 2 * pad))
    canvas.alpha_composite(grass, (pad, pad))
    mx, my = pad + grass.width // 2, pad + grass.height // 2
    for n, (im, pv) in enumerate(figs):
        x = mx + round((n - (len(figs) - 1) / 2) * gap)
        y = my + 16 + (12 if n % 2 else 0)
        b = boxes[n]
        canvas.alpha_composite(im, (x - (b[0] + b[2]) // 2, y - pv[1]))
    bb = canvas.getbbox()
    canvas = canvas.crop(bb)
    return canvas


## Hero templates, as the catalog's «Герои: шаблоны» names them in prose.
TEMPLATES = {"mounted": "конный", "light": "лёгкий", "sovereign": "государь", "lady": "пани", "civilian": "небоевой"}
## Heroes the game has beyond the catalog's table: the same person in another mission.
EXTRA_HEROES = {"hero_ostrogski_fugitive": ("hero_ostrogski", "light", "Константин Острожский, беглец", "ВКЛ 6", "Игрок")}


def tres(uid: str) -> dict[str, str]:
    """Plain `key = value` lines of data/units/<id>.tres (the numbers the game plays with)."""
    out = {}
    for line in (ROOT / "data" / "units" / f"{uid}.tres").read_text().splitlines():
        m = re.match(r"(\w+) = (.+)$", line)
        if m:
            out[m[1]] = m[2].strip('&"')
    return out


def num(v: str, milli: bool = False) -> str:
    n = int(v)
    if milli:
        return f"{n / 1000:g}".replace(".", ",")
    return str(n)


def hero_cards(c: dict, out: Path) -> list[dict]:
    """Heroes: the template's numbers as the game has them (data/units), the catalog's words."""
    tpl = {t["id"].removeprefix("hero_type_"): t for t in c["hero_templates"]}
    rows = [(h["id"], h) for h in c["heroes"]]
    by_id = dict(rows)
    for hid, (base, t, name, missions, side) in EXTRA_HEROES.items():
        rows.append((hid, dict(by_id[base], id=hid, name=name, missions=missions, template=t, side=side)))
    cards = []
    for hid, h in rows:
        if not (UNITS / hid / "sheet.json").exists() or not (ROOT / "data" / "units" / f"{hid}.tres").exists():
            print("no sprite or data for", hid)
            continue
        d = tres(hid)
        fac = d["faction"]
        t = h["template"].split(";")[0].strip()
        card_image(hid, fac).save(out / "img" / f"{hid}.png")
        dmg = "—" if int(d["damage"]) == 0 else f"{d['damage']} Б"
        cards.append({"kind": "hero", "id": hid, "img": str((out / "img" / f"{hid}.png").resolve()),
                      "name": h["name"], "faction": c["factions"][fac]["name"], "template": TEMPLATES[t],
                      "side": h["side"], "missions": h["missions"], "hp": num(d["hp"]), "damage": dmg,
                      "armor": f"{d['armor_melee']}/{d['armor_pierce']}", "speed": num(d["speed_milli"], True),
                      "aura": tpl[t]["aura"] if "aura_morale" in d["params"] else "—", "common": tpl[t]["ability"], "effect": h["ability"]})
    return cards


def main(dest: str) -> None:
    out = Path(dest)
    (out / "img").mkdir(parents=True, exist_ok=True)
    c = json.loads(CATALOG.read_text())
    names = building_names(c)
    cards = []
    for u in c["units"]:
        uid = u["id"]
        if not (UNITS / ALIASES.get(uid, uid) / "sheet.json").exists():
            print("no sprite for", uid)
            continue
        card_image(uid).save(out / "img" / f"{uid}.png")
        cost = re.findall(r"\d+", u["cost"]) if re.fullmatch(r"\d+/\d+/\d+/\d+", u["cost"].strip()) else []
        cards.append({"kind": "unit", "id": uid, "img": str((out / "img" / f"{uid}.png").resolve()),
                      "name": u["name"].rstrip("*"), "faction": c["factions"][u["faction"]]["name"],
                      "age": u["age"], "building": where(u, names) if u["building"] != "—" else "",
                      "cost": [int(x) for x in cost], "cost_note": "" if cost else u["cost"],
                      "train_time": u["train_time"], "pop": u["pop"], "hp": u["hp"], "damage": u["damage"],
                      "reload": u["reload"], "range": u["range"], "armor": u["armor"], "speed": u["speed"],
                      "morale": u["morale"], "effect": u["special"]})
    cards += hero_cards(c, out)
    (out / "cards.json").write_text(json.dumps(cards, ensure_ascii=False, indent=1))
    print(len(cards), "cards")


if __name__ == "__main__":
    main(sys.argv[1])
