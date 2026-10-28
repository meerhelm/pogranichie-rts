# Картотека построек

Карточка на каждую постройку, у которой есть спрайт: постройка в стадии «готова» на траве, в рамке и шрифтах игры, с данными из каталога (`tools/catalog/catalog.json`): фракция, эпоха, размер, стоимость (еда/дерево/железо/серебро), время стройки, прочность, броня и что даёт. 1280×720 PNG.

- `Pogranichie-buildings-gdl-<версия>.zip` и `.pdf`: ВКЛ и сторожевая вышка Московии.
- `Pogranichie-buildings-pl-<версия>.zip` и `.pdf`: Корона Польская.
- `Pogranichie-buildings-to-<версия>.zip` и `.pdf`: Тевтонский орден.

PDF: те же карточки, по одной на страницу. Версия 0.2.0 собрана уже с тенями от грубых 3D-моделей (`tools/art/proxy_shadow.py`).

Пересобрать (нужен дисплей для второго шага):

```sh
python3 -m tools.art.building_cards /tmp/cards
godot -s tools/art/building_cards.gd -- /tmp/cards   # карточки в /tmp/cards/cards
```

Архивы и PDF по фракциям (gdl = `gdl_*` и `mo_*`, pl, to) из `/tmp/cards/cards`:

```sh
python3 - <<'PY'
import zipfile; from pathlib import Path; from PIL import Image
V = "0.2.0"; src = Path("/tmp/cards/cards")
for g, pre in {"gdl": ("gdl_", "mo_"), "pl": ("pl_",), "to": ("to_",)}.items():
    files = sorted(f for f in src.glob("*.png") if f.name.split("_", 1)[1].startswith(pre))
    name = f"Pogranichie-buildings-{g}"
    with zipfile.ZipFile(f"{name}-{V}.zip", "w") as z:
        for f in files: z.write(f, f"{name}/{f.name}")
    ims = [Image.open(f).convert("RGB") for f in files]
    ims[0].save(f"{name}-{V}.pdf", save_all=True, append_images=ims[1:], resolution=96, quality=92)
PY
```
