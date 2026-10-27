# Картотека построек

Карточка на каждую постройку, у которой есть спрайт: постройка в стадии «готова» на траве, в рамке и шрифтах игры, с данными из каталога (`tools/catalog/catalog.json`): фракция, эпоха, размер, стоимость (еда/дерево/железо/серебро), время стройки, прочность, броня и что даёт. 1280×720 PNG.

- `Pogranichie-buildings-gdl-<версия>.zip`: ВКЛ и пять построек Московии (вышка и общие с ВКЛ).
- `Pogranichie-buildings-pl-<версия>.zip`: Корона Польская.
- `Pogranichie-buildings-to-<версия>.zip`: Тевтонский орден.

Пересобрать (нужен дисплей для второго шага):

```sh
python3 -m tools.art.building_cards /tmp/cards
godot -s tools/art/building_cards.gd -- /tmp/cards   # карточки в /tmp/cards/cards
```
