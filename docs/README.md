# Документация «Пограничья»

Проектные документы игры, выгруженные в Markdown из Claude Docs 16 октября 2026. Оригиналы живут онлайн (ссылки ниже) и правятся там; эта папка их копия для чтения из репозитория и из Claude Code. После правок оригинала выгрузку нужно повторить.

| Файл | Что внутри | Оригинал |
| --- | --- | --- |
| [01-concept.md](01-concept.md) | Концепт: эпоха 1409–1514, фракции, Сила и магия, стиль, рамки прототипа | [документ](https://claude.ai/code/artifact/8fd2215e-d788-4c53-8017-3b19b2393ca1) |
| [02-campaign-story.md](02-campaign-story.md) | Общий сюжет двух кампаний, 14 миссий, герои | [документ](https://claude.ai/code/artifact/685cea2b-e608-485a-a318-f7b5e89a4d99) |
| [03-missions/](03-missions/) | Подробные миссии: ВКЛ 1–8, Корона 1–6, реестр юнитов, построек и заклинаний по миссиям, источники | [документ](https://claude.ai/code/artifact/c5b5d31d-38a8-4ccf-8fb9-9e6816580df0) |
| [04-catalog/](04-catalog/) | Каталог: правила, юниты и постройки четырёх фракций, союзники и герои, магия, локации, источники | [документ](https://claude.ai/code/artifact/8a193a2b-0e1e-4e3b-b25f-666c9b168c25) |
| [05-implementation-plan.md](05-implementation-plan.md) | Стек и план реализации прототипа по вехам M0–M10, тестирование | [документ](https://claude.ai/code/artifact/6a467fca-fdd4-422c-9b93-73310a4201e4) |
| [06-visual-assets.md](06-visual-assets.md) | Около 600 визуальных ассетов по id каталога и пайплайн AI-концепт → 3D → риг → 2D-рендер | [документ](https://claude.ai/code/artifact/b3f91fd7-d6e1-4ed7-9baa-89cf9ad0bfb3) |

## Что главнее

- Цифры баланса в игре берутся из `tools/catalog/catalog.json` (выгрузка таблиц каталога) и `data/**/*.tres`, а не из `04-catalog/`. Если они расходятся, верен `catalog.json`; как он обновляется, описано в [tools/catalog/README.md](../tools/catalog/README.md).
- Код и `README.md` в корне описывают, что уже сделано; `05-implementation-plan.md` описывает, что задумывалось.
