"""Turn tab dumps of the catalog document into tools/catalog/catalog.json.

The catalog lives in a Claude Doc ("Пограничье: каталог локаций, юнитов и построек").
Each tab is dumped to a Markdown file with pipe tables (headings + tables, nothing else
matters). This script copies the tables cell by cell, without interpreting them: parsing
happens in the exporter, so catalog.json stays a faithful copy of the document.

Usage:
    python3 -m tools.catalog.import_docs DUMP_DIR [--date YYYY-MM-DD]

DUMP_DIR holds overview.md, gdl.md, crown.md, order.md, moscow.md, allies.md, magic.md.
A Claude Docs `read` result (JSON with an "xml" field) can be converted with --from-xml.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

CATALOG_PATH = Path(__file__).with_name("catalog.json")
DOC_URL = "https://claude.ai/code/artifact/8a193a2b-0e1e-4e3b-b25f-666c9b168c25"
DOC_TITLE = "Пограничье: каталог локаций, юнитов и построек"

UNIT_COLUMNS = {
    "id": "id",
    "Юнит": "name",
    "Эпоха": "age",
    "Здание": "building",
    "Цена Е/Д/Ж/С": "cost",
    "Найм, с": "train_time",
    "Нас.": "pop",
    "HP": "hp",
    "Урон": "damage",
    "Перез., с": "reload",
    "Дальн.": "range",
    "Броня": "armor",
    "Скор.": "speed",
    "Дух": "morale",
    "Особое": "special",
    "Миссии": "missions",
}
NEUTRAL_UNIT_COLUMNS = {
    "id": "id",
    "Юнит": "name",
    "Чьи": "side",
    "HP": "hp",
    "Урон": "damage",
    "Перез., с": "reload",
    "Дальн.": "range",
    "Броня": "armor",
    "Скор.": "speed",
    "Дух": "morale",
    "Особое": "special",
    "Миссии": "missions",
}
ANIMAL_COLUMNS = {
    "id": "id",
    "Зверь": "name",
    "HP": "hp",
    "Урон": "damage",
    "Броня": "armor",
    "Скор.": "speed",
    "Еда": "food",
    "Поведение": "special",
}
COMMON_BUILDING_COLUMNS = {
    "id": "id",
    "ВКЛ": "name_gdl",
    "Корона": "name_pl",
    "Орден": "name_to",
    "Москва": "name_mo",
    "Эпоха": "age",
    "Цена Е/Д/Ж/С": "cost",
    "Стройка, с": "build_time",
    "HP": "hp",
    "Броня": "armor",
    "Что даёт": "effect",
}
BUILDING_COLUMNS = {
    "id": "id",
    "Постройка": "name",
    "Эпоха": "age",
    "Цена Е/Д/Ж/С": "cost",
    "Стройка, с": "build_time",
    "HP": "hp",
    "Броня": "armor",
    "Что даёт": "effect",
}
TECH_COLUMNS = {
    "id": "id",
    "Технология": "name",
    "Где": "building",
    "Эпоха": "age",
    "Цена Е/Д/Ж/С": "cost",
    "Время, с": "research_time",
    "Эффект": "effect",
}
FAITH_TECH_COLUMNS = {
    "id": "id",
    "Технология": "name",
    "Фракция": "faction",
    "Эпоха": "age",
    "Цена Е/Д/Ж/С": "cost",
    "Эффект": "effect",
}
AGE_COLUMNS = {
    "Эпоха": "name",
    "Цена Е/Д/Ж/С": "cost",
    "Время, с": "research_time",
    "Условие": "condition",
    "Что открывает": "unlocks",
}
POWER_PLACE_COLUMNS = {"id": "id", "Место силы": "name", "Сила": "power", "Особое": "special"}
SHRINE_COLUMNS = {
    "Фракция": "faction",
    "Святилище": "name",
    "Сила в секунду": "power_rate",
    "Дополнительно": "special",
}
SPELL_COLUMNS = {
    "id": "id",
    "Заклинание": "name",
    "Фракция": "faction",
    "Кто читает": "casters",
    "Эпоха": "age",
    "Сила": "power",
    "Перезарядка, с": "cooldown",
    "Радиус": "radius",
    "Длится, с": "duration",
    "Эффект": "effect",
    "Бытовое объяснение": "mundane",
}
CREATURE_COLUMNS = {
    "id": "id",
    "Существо": "name",
    "Фракция": "faction",
    "Цена": "cost",
    "Живёт, с": "lifetime",
    "HP": "hp",
    "Урон": "damage",
    "Броня": "armor",
    "Скор.": "speed",
    "Правила": "special",
    "Бытовое объяснение": "mundane",
}

HERO_COLUMNS = {
    "id": "id",
    "Герой": "name",
    "Сторона": "side",
    "Миссии": "missions",
    "Шаблон": "template",
    "Своё умение": "ability",
}

# (dump file, heading, catalog section, columns, faction)
TABLES = [
    ("overview.md", "Эпохи, население, сбор", "ages", AGE_COLUMNS, None),
    ("overview.md", "Общие постройки", "common_buildings", COMMON_BUILDING_COLUMNS, None),
    ("overview.md", "Общие технологии", "common_techs", TECH_COLUMNS, None),
    ("gdl.md", "Юниты", "units", UNIT_COLUMNS, "gdl"),
    ("gdl.md", "Уникальные постройки", "buildings", BUILDING_COLUMNS, "gdl"),
    ("gdl.md", "Уникальные технологии", "techs", TECH_COLUMNS, "gdl"),
    ("crown.md", "Юниты", "units", UNIT_COLUMNS, "pl"),
    ("crown.md", "Уникальные постройки", "buildings", BUILDING_COLUMNS, "pl"),
    ("crown.md", "Уникальные технологии", "techs", TECH_COLUMNS, "pl"),
    ("order.md", "Юниты", "units", UNIT_COLUMNS, "to"),
    ("order.md", "Уникальные постройки", "buildings", BUILDING_COLUMNS, "to"),
    ("order.md", "Уникальные технологии", "techs", TECH_COLUMNS, "to"),
    ("moscow.md", "Юниты", "units", UNIT_COLUMNS, "mo"),
    ("moscow.md", "Уникальные постройки", "buildings", BUILDING_COLUMNS, "mo"),
    ("moscow.md", "Уникальные технологии", "techs", TECH_COLUMNS, "mo"),
    ("allies.md", "Особые отряды", "neutral_units", NEUTRAL_UNIT_COLUMNS, "nt"),
    ("allies.md", "Звери", "animals", ANIMAL_COLUMNS, "nt"),
    ("allies.md", "Герои кампаний", "heroes", HERO_COLUMNS, None),
    ("magic.md", "Места силы", "power_places", POWER_PLACE_COLUMNS, None),
    ("magic.md", "Святилища", "shrines", SHRINE_COLUMNS, None),
    ("magic.md", "Заклинания", "spells", SPELL_COLUMNS, None),
    ("magic.md", "Существа", "creatures", CREATURE_COLUMNS, None),
    ("magic.md", "Технологии веры", "faith_techs", FAITH_TECH_COLUMNS, None),
]

FACTIONS = {
    "gdl": {"name": "Великое княжество Литовское", "tab": "ВКЛ"},
    "pl": {"name": "Корона Польская", "tab": "Корона Польская"},
    "to": {"name": "Тевтонский орден", "tab": "Тевтонский орден"},
    "mo": {"name": "Московское государство", "tab": "Московское государство"},
}


class ImportError_(Exception):
    pass


def read_tables(text: str) -> dict[str, list[list[str]]]:
    """Return {last heading before the table: rows}, rows as lists of cell strings."""
    tables: dict[str, list[list[str]]] = {}
    heading = ""
    current: list[list[str]] | None = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#"):
            heading = line.lstrip("#").strip()
            current = None
        elif line.startswith("|"):
            if current is None:
                if heading in tables:
                    raise ImportError_(f"two tables under heading {heading!r}")
                current = tables.setdefault(heading, [])
            cells = [c.strip() for c in line.strip("|").split("|")]
            current.append(cells)
        else:
            current = None
    return tables


def table_rows(rows: list[list[str]], columns: dict[str, str], where: str) -> list[dict]:
    header = rows[0]
    if header != list(columns):
        raise ImportError_(f"{where}: columns {header} != expected {list(columns)}")
    out = []
    for cells in rows[1:]:
        if len(cells) != len(header):
            raise ImportError_(f"{where}: row {cells[:1]} has {len(cells)} cells")
        out.append({columns[h]: v for h, v in zip(header, cells)})
    return out


def build_catalog(dump_dir: Path, date: str) -> dict:
    catalog: dict = {
        "format": 1,
        "source": {"title": DOC_TITLE, "url": DOC_URL, "exported_on": date},
        "factions": FACTIONS,
    }
    parsed: dict[str, dict] = {}
    for fname, heading, section, columns, faction in TABLES:
        if fname not in parsed:
            parsed[fname] = read_tables((dump_dir / fname).read_text(encoding="utf-8"))
        tables = parsed[fname]
        if heading not in tables:
            raise ImportError_(f"{fname}: no table under heading {heading!r}")
        rows = table_rows(tables[heading], columns, f"{fname} / {heading}")
        if faction is not None:
            rows = [{"faction": faction, **r} for r in rows]
        catalog.setdefault(section, []).extend(rows)
    return catalog


def xml_dump_to_markdown(read_result: dict) -> str:
    """Convert a Claude Docs `read` result of one tab into the Markdown this script reads."""
    data = read_result.get("data", read_result)
    root = ET.fromstring(data["xml"])
    out: list[str] = []

    def text(el: ET.Element) -> str:
        return "".join(el.itertext()).strip()

    def walk(el: ET.Element) -> None:
        for child in el:
            if child.tag == "paragraph":
                level = child.get("heading")
                if level:
                    out.append("#" * int(level) + " " + text(child))
                elif text(child):
                    out.append(text(child))
            elif child.tag == "table":
                for row in child.findall("row"):
                    cells = [text(c).replace("|", "/") for c in row.findall("cell")]
                    out.append("| " + " | ".join(cells) + " |")
                out.append("")
            else:
                walk(child)

    walk(root)
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump_dir", type=Path)
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    parser.add_argument("--out", type=Path, default=CATALOG_PATH)
    parser.add_argument(
        "--from-xml",
        nargs=2,
        metavar=("READ_JSON", "OUT_MD"),
        help="convert one Claude Docs read result to Markdown and exit",
    )
    args = parser.parse_args(argv)
    if args.from_xml:
        src, dst = args.from_xml
        md = xml_dump_to_markdown(json.loads(Path(src).read_text(encoding="utf-8")))
        Path(dst).write_text(md, encoding="utf-8")
        return 0
    try:
        catalog = build_catalog(args.dump_dir, args.date)
    except ImportError_ as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1
    text = json.dumps(catalog, ensure_ascii=False, indent=1) + "\n"
    args.out.write_text(text, encoding="utf-8")
    counts = {k: len(v) for k, v in catalog.items() if isinstance(v, list)}
    print(f"Wrote {args.out}: {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
