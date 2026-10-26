# Пиксельный вид 3/4: пробные ассеты (не принятое решение)

Проба Retro Diffusion для вида 3/4 сверху, клетка 32 px, общая палитра.

- `smolina/`, `landscape/`: первые пробы земли и деревьев.
- `gdl01/`: миссия «ВКЛ 1»: земля, деревья, 22 спрайта построек по 7 стадий (`buildings/`, исходники `buildings_src/`, сырые ответы `buildings_raw/`), лист `sheet_buildings.png`, карта `map_*.png`, иконки `icons/`.
- `scripts/`: генерация (`rd.py`, ключ берётся из `~/.config/retrodiffusion/token`, в репозиторий не попадает) и сборка (`finals.py` → `states.py` → `sheet_b.py`, `assemble_gdl01.py`, `bicons.py`, `oicons.py`). Пути в скриптах абсолютные, под Mac Valentin.

Траты и промпты в `manifest.json` каждой папки.
