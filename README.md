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
  sim/ combat/ economy/ nav/ vision/ magic/
data/              # сгенерированные .tres, руками не правим
game/              # сцены: карта, юниты, постройки, камера, ввод
ui/                # HUD, миникарта, меню
ai/                # деревья LimboAI
missions/gdl_01/   # карта, триггеры, диалоги
maps/              # map_proto_samogitia
i18n/              # en, be, pl, uk, lt .po
tools/             # экспортёр каталога, скрипты CI
tests/unit/ tests/integration/ tests/replays/ tests/perf/
```

## Тесты и проверки локально

```sh
GODOT=/путь/к/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --import                          # импорт проекта
$GODOT --headless -s addons/gut/gut_cmdln.gd        # все тесты (настройки в .gutconfig.json)
pip install gdtoolkit==4.5.0
gdlint . && gdformat --check game tests             # линтер и форматирование
```

Тесты кладутся в `tests/unit/` или `tests/integration/`, файл `test_*.gd`, класс `extends GutTest`.

## CI

Сейчас CI запускается только вручную (Actions → CI → Run workflow), чтобы не тратить минуты GitHub; проверки гоняем локально. Что делает прогон:

- линтер и проверка форматирования gdtoolkit;
- импорт проекта, тесты GUT и запуск главной сцены на Ubuntu и Windows; любая строка `ERROR` в выводе Godot валит шаг;
- экспорт сборок Windows и Linux; они лежат в артефактах прогона (`pogranichie-windows-…`, `pogranichie-linux-…`).

Версия Godot и контрольные суммы закреплены в `.github/workflows/ci.yml`; поднимаем отдельным PR.

## Правила

- В `main` напрямую не пишем, всё через PR с зелёным CI.
- Симуляция отдельно от отрисовки, без float, фиксированный шаг 20 тиков/с (с M2).
- Цифры баланса только из каталога, не в коде.
