# Пограничье (Pogranichie)

Изометрическая историческая RTS в духе Age of Empires II: Великое княжество Литовское и Корона Польская против Тевтонского ордена и Московского княжества, 1409–1514. Сейчас идёт прототип (схватка ВКЛ против Ордена и миссия «ВКЛ 1. Жемайтский огонь»).

## Как открыть

1. Установить [Git LFS](https://git-lfs.com/) (`git lfs install`): через него пойдут арт и звук.
2. Клонировать репозиторий.
3. Открыть папку в Godot **4.7.2** (стандартная сборка, не .NET).

## Стек

| Что | Версия |
| --- | --- |
| Движок | Godot 4.7.2, GDScript со строгими типами (нетипизированный код считается ошибкой) |
| Тесты | GUT 9.7.1, запуск без окна |
| ИИ | LimboAI 1.8.1 (GDExtension) |
| Диалоги | Dialogic 2.0-alpha-20 |
| Линтер | gdtoolkit 4.5.0 (`gdlint`, `gdformat`) |

Версии аддонов и откуда они взяты: [addons/VERSIONS.md](addons/VERSIONS.md).

## Структура

```
addons/            # gut, limboai, dialogic — версии закреплены
core/              # симуляция без сцен и отрисовки
  data/            # классы UnitDef, BuildingDef, TechDef, SpellDef, FactionDef и CatalogDB
  sim/             # тики 20 Гц, фиксированная точка, ГПСЧ, сущности, команды, хеш, повторы
  combat/ economy/ nav/ vision/ magic/
data/              # .tres из каталога, генерирует tools/catalog/export.py, руками не правим
game/              # сцены: карта, юниты, постройки, камера, ввод
ui/                # HUD, миникарта, меню
ai/                # деревья LimboAI
missions/gdl_01/   # карта, триггеры, диалоги
maps/              # map_proto_samogitia
i18n/              # en, be, pl, uk, lt .po
tools/catalog/     # catalog.json (выгрузка каталога) и экспортёр в data/
tools/ci/          # скрипты CI
tools/sim/         # запуск симуляции без окна: повторы, проверка детерминизма, бенчмарк
tests/unit/ tests/integration/ tests/replays/ tests/perf/
tests/support/     # помощники тестов (генератор случайных команд)
```

## Тесты и проверки локально

```sh
GODOT=/путь/к/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --import                          # импорт проекта
$GODOT --headless -s addons/gut/gut_cmdln.gd        # все тесты (настройки в .gutconfig.json)
pip install gdtoolkit==4.5.0
gdlint . && gdformat --check game tests             # линтер и форматирование
python3 -m unittest discover -s tools/catalog/tests -t .   # тесты экспортёра каталога
python3 -m tools.catalog.export --check             # data/ совпадает с catalog.json
$GODOT --headless -s tools/sim/sim_cli.gd -- play tests/replays/*.json        # повторы дают те же хеши
$GODOT --headless -s tools/sim/sim_cli.gd -- determinism --runs 10 --ticks 1000
$GODOT --headless -s tools/sim/sim_cli.gd -- bench --units 200 --ticks 600
```

Тесты кладутся в `tests/unit/` или `tests/integration/`, файл `test_*.gd`, класс `extends GutTest`.

## Симуляция (с M2)

Мир живёт в `Simulation` (`core/sim/`) и меняется только в `step()` и только командами (`SimCommand`): игрок, ИИ и скрипт миссии отдают одни и те же команды. Правила ядра:

- 20 тиков в секунду; `SimClock` двигает симуляцию из игрового цикла, отрисовка только читает состояние.
- Только целые числа: 1 клетка = 1024 единицы (`Fixed`), деление вниз, `Fixed.isqrt` вместо `sqrt`.
- Случайность только из `sim.rng` (`SimRng`, xorshift32 с сидом), не из `randi()`/`randf()`.
- Сущности хранятся массивами по id в `EntityStore`; id растут и не переиспользуются, обход всегда по возрастанию id.
- `StringName` не сортировать напрямую: их порядок зависит от запуска. Сортировать как `String`.
- `state_hash()` — SHA-256 всего состояния. Повтор (`Replay`) хранит сид, версии правил и данных, команды и хеши каждые 10 тиков; при проигрывании называет первый тик расхождения.

Повторы в `tests/replays/` записаны один раз и проигрываются в тестах на каждой ОС. Если правило симуляции или цифры каталога меняются намеренно, повтор перезаписывают отдельным коммитом с объяснением, почему итог изменился (см. [tests/replays/README.md](tests/replays/README.md)).

## CI

Сейчас CI запускается только вручную (Actions → CI → Run workflow), чтобы не тратить минуты GitHub; проверки гоняем локально. Что делает прогон:

- линтер и проверка форматирования gdtoolkit;
- тесты экспортёра каталога и проверка, что `data/` совпадает с `tools/catalog/catalog.json`;
- импорт проекта, тесты GUT и запуск главной сцены на Ubuntu и Windows; любая строка `ERROR` в выводе Godot валит шаг;
- экспорт сборок Windows и Linux; они лежат в артефактах прогона (`pogranichie-windows-…`, `pogranichie-linux-…`).

Версия Godot и контрольные суммы закреплены в `.github/workflows/ci.yml`; поднимаем отдельным PR.

## Правила

- В `main` напрямую не пишем, всё через PR с зелёным CI.
- Симуляция отдельно от отрисовки, без float, фиксированный шаг 20 тиков/с (см. «Симуляция»).
- Цифры баланса только из каталога, не в коде: правка идёт в документ каталога, потом выгрузка и экспорт (см. [tools/catalog/README.md](tools/catalog/README.md)).
