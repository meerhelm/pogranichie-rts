# Картотека построек, юнитов и героев

Карточки для просмотра, 1280×720 PNG, в рамке и шрифтах игры, с данными из каталога (`tools/catalog/catalog.json`):

- **Постройки:** каждая постройка со спрайтом в стадии «готова» на траве; фракция, эпоха, размер, стоимость (еда/дерево/железо/серебро), время стройки, прочность, броня и что даёт.
- **Юниты:** каждый юнит каталога, у которого есть спрайт (или подмена из `SpriteDB.ALIASES`), три раза на траве (стоит, идёт, бьёт; лодка на воде), в цвете своей фракции; фракция, эпоха, где обучается, стоимость, обучение, население, здоровье, урон, перезарядка, дальность, броня, скорость, дух и особое.
- **Герои:** каждый герой кампаний (таблица «Герои кампаний» и беглец Острожский из ВКЛ 6), так же на траве; фракция по `data/units/hero_*.tres`, шаблон, сторона, миссии, здоровье, урон, броня и скорость как в игре, аура и общее умение шаблона, своё умение.

По фракциям:

- `Pogranichie-cards-gdl-<версия>.zip` и `.pdf`: ВКЛ и Московия (сторожевая вышка и юниты Москвы со спрайтами).
- `Pogranichie-cards-pl-<версия>.zip` и `.pdf`: Корона Польская.
- `Pogranichie-cards-to-<версия>.zip` и `.pdf`: Тевтонский орден.

В архиве три папки, `buildings/`, `units/` и `heroes/`; в PDF те же карточки по одной на страницу в том же порядке. Версия 0.2.0: постройки с тенями от грубых 3D-моделей (`tools/art/proxy_shadow.py`), 54 юнита, 51 герой.

Пересобрать (нужен дисплей для второго шага; в контейнере без дисплея годится `xvfb-run -a -s "-screen 0 1280x720x24" godot ...`):

```sh
python3 -m tools.art.building_cards /tmp/cards
godot -s tools/art/building_cards.gd -- /tmp/cards    # постройки в /tmp/cards/cards
python3 -m tools.art.unit_cards /tmp/ucards
godot -s tools/art/building_cards.gd -- /tmp/ucards   # юниты и герои в /tmp/ucards/cards
```

Архивы и PDF по фракциям (gdl = `gdl_*` и `mo_*`, pl, to; герои по фракции из своего `.tres`):

```sh
python3 - <<'PY'
import re, zipfile; from pathlib import Path; from PIL import Image
V = "0.2.0"; b = Path("/tmp/cards/cards"); u = Path("/tmp/ucards/cards")
def fac(f):
    sid = f.stem.split("_", 1)[1]
    return re.search(r'^faction = &"(\w+)"', Path(f"data/units/{sid}.tres").read_text(), re.M)[1] + "_"
for g, pre in {"gdl": ("gdl_", "mo_"), "pl": ("pl_",), "to": ("to_",)}.items():
    own = lambda f: f.name.split("_", 1)[1].startswith(pre)
    bf = sorted(f for f in b.glob("*.png") if own(f))
    uf = sorted(f for f in u.glob("*.png") if own(f))
    hf = sorted(f for f in u.glob("*_hero_*.png") if fac(f) in pre)
    name = f"Pogranichie-cards-{g}"
    with zipfile.ZipFile(f"{name}-{V}.zip", "w") as z:
        for d, fs in (("buildings", bf), ("units", uf), ("heroes", hf)):
            for f in fs: z.write(f, f"{name}/{d}/{f.name}")
    ims = [Image.open(f).convert("RGB") for f in bf + uf + hf]
    ims[0].save(f"{name}-{V}.pdf", save_all=True, append_images=ims[1:], resolution=96, quality=92)
PY
```
