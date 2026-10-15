"""Collect the game's translatable strings into i18n/messages.pot and the five .po files.

    python3 -m tools.i18n.extract           # update i18n/messages.pot and i18n/<locale>.po
    python3 -m tools.i18n.extract --check   # fail on hard-coded UI text or stale .po files

Keys are of two kinds. Interface text is written in English in the code and wrapped in tr()
(or UiText.t() outside the scene tree); the English text is the key. Game names (units,
buildings, techs, ages, factions) are their catalog ids, so the catalog and the translations
cannot drift apart; their English names live in i18n/en.po like any other translation.

The check fails when
- a string literal in game/ or ui/ looks like text for the player but is not passed to tr()
  (a capitalised word or words with spaces; developer messages in print/push_warning/assert and
  lines marked `# notr` are skipped);
- a .tscn sets text or tooltip_text to something that is not a key;
- a .po file is missing keys of messages.pot or keeps keys that are gone (run the extractor);
- en.po leaves a key untranslated, or a translation's %d / %s placeholders differ from its key.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
I18N = ROOT / "i18n"
LOCALES = ("en", "be", "pl", "uk", "lt")
SCAN_DIRS = ("game", "ui")
INDEX = ROOT / "data" / "catalog_index.tres"
# Catalog lists whose ids are shown to the player.
INDEX_LISTS = (
    "prototype_units", "prototype_buildings", "prototype_techs", "prototype_spells", "factions",
    "ages", "power_places",
)

STRING = re.compile(r'(?P<prefix>[&^$]?)"(?P<body>(?:[^"\\]|\\.)*)"')
TR_CALL = re.compile(r"(?<![\w.])(?:tr|atr|tr_n|UiText\.t|t)\(\s*$")
DEV_CALL = re.compile(r"\b(?:print|printerr|print_debug|push_warning|push_error|assert)\(")
LETTERS = re.compile(r"[^\W\d_]{2,}")
TSCN_TEXT = re.compile(r'^(?:text|tooltip_text|placeholder_text|title) = "(?P<body>(?:[^"\\]|\\.)*)"')
PLACEHOLDER = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[dsfxXc%]")


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    # key -> source references ("ui/hud.gd:12")
    keys: dict[str, list[str]] = field(default_factory=dict)

    def key(self, text: str, ref: str) -> None:
        self.keys.setdefault(text, []).append(ref)


def looks_like_text(body: str) -> bool:
    """A literal a player would read: words with spaces, or a capitalised word."""
    if not LETTERS.search(body):
        return False
    if body.startswith(("res://", "user://", "uid://")):
        return False
    if " " in body.strip():
        return True
    return bool(re.fullmatch(r"[A-ZА-ЯЁІЎЄЇҐ][\w'’-]*[.!?]?", body))


def _code_part(line: str) -> str:
    """The line without its comment (a # outside string literals)."""
    out = []
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def scan_gd(path: Path, rep: Report) -> None:
    rel = path.relative_to(ROOT).as_posix()
    prev = ""
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        code = _code_part(line)
        before_line = prev
        prev = code
        notr = "# notr" in line[len(code):]
        dev = DEV_CALL.search(code) is not None
        for m in STRING.finditer(code):
            body = m.group("body")
            if m.group("prefix"):
                continue
            ref = f"{rel}:{n}"
            before = code[: m.start()]
            if TR_CALL.search(before) or (not before.strip() and TR_CALL.search(before_line)):
                # The file without the line, so that moving code does not change the .pot.
                rep.key(body, rel)
            elif not notr and not dev and looks_like_text(body):
                rep.errors.append(f"{ref}: text not passed to tr(): \"{body}\"")


def scan_tscn(path: Path, rep: Report) -> None:
    rel = path.relative_to(ROOT).as_posix()
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        m = TSCN_TEXT.match(line)
        if m and LETTERS.search(m.group("body")):
            # Controls translate their own text; it must be a key the .po files know.
            rep.key(m.group("body"), rel)


def catalog_keys(rep: Report) -> None:
    text = INDEX.read_text(encoding="utf-8")
    for name in INDEX_LISTS:
        m = re.search(rf"^{name} = Array\[StringName\]\(\[(.*)\]\)$", text, re.M)
        if m is None:
            rep.errors.append(f"{INDEX.relative_to(ROOT)}: no {name}")
            continue
        for key in re.findall(r'&"([^"]+)"', m.group(1)):
            rep.key(key, f"catalog:{name}")


def collect(root: Path = ROOT) -> Report:
    rep = Report()
    for d in SCAN_DIRS:
        for path in sorted((root / d).rglob("*.gd")):
            scan_gd(path, rep)
        for path in sorted((root / d).rglob("*.tscn")):
            scan_tscn(path, rep)
    catalog_keys(rep)
    return rep


# --- .po files ---------------------------------------------------------------------------


def _unquote_lines(lines: list[str]) -> str:
    return "".join(re.fullmatch(r'\s*"(.*)"\s*', ln).group(1) for ln in lines)


def read_po(path: Path) -> dict[str, str]:
    """msgid -> msgstr (both still escaped as in the file); the header is left out."""
    if not path.exists():
        return {}
    entries: dict[str, str] = {}
    msgid: list[str] | None = None
    msgstr: list[str] | None = None
    current: list[str] | None = None

    def flush() -> None:
        if msgid is not None and msgstr is not None:
            key = _unquote_lines(msgid)
            if key:
                entries[key] = _unquote_lines(msgstr)

    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("msgid "):
            flush()
            msgid, msgstr = [line[6:]], None
            current = msgid
        elif line.startswith("msgstr "):
            msgstr = [line[7:]]
            current = msgstr
        elif line.startswith('"') and current is not None:
            current.append(line)
        elif not line.strip():
            current = None
    flush()
    return entries


def _header(locale: str | None) -> str:
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: Pogranichie\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
    ]
    if locale:
        lines.append(f'"Language: {locale}\\n"')
    return "\n".join(lines) + "\n"


def render_pot(rep: Report) -> str:
    out = [
        "# Translatable strings of Pogranichie. Generated by `python3 -m tools.i18n.extract`;",
        "# do not edit by hand.",
        _header(None),
    ]
    for key in sorted(rep.keys):
        refs = sorted(set(rep.keys[key]))
        out.append("\n".join(f"#: {r}" for r in refs) + f'\nmsgid "{key}"\nmsgstr ""\n')
    return "\n".join(out)


def is_catalog_id(key: str) -> bool:
    return re.fullmatch(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*", key) is not None


def render_po(locale: str, rep: Report, old: dict[str, str]) -> str:
    out = [
        f"# Pogranichie, {locale}. Keys come from `python3 -m tools.i18n.extract`, which keeps",
        "# the translations here; an empty msgstr falls back to English.",
        _header(locale),
    ]
    for key in sorted(rep.keys):
        value = old.get(key, "")
        if locale == "en" and not value and not is_catalog_id(key):
            # English interface text is its own key.
            value = key
        out.append(f'msgid "{key}"\nmsgstr "{value}"\n')
    return "\n".join(out)


def check_po(locale: str, rep: Report, entries: dict[str, str]) -> list[str]:
    errors = []
    name = f"i18n/{locale}.po"
    missing = sorted(set(rep.keys) - set(entries))
    stale = sorted(set(entries) - set(rep.keys))
    if missing:
        errors.append(f"{name}: missing {len(missing)} key(s), e.g. {missing[0]!r}")
    if stale:
        errors.append(f"{name}: {len(stale)} key(s) no longer used, e.g. {stale[0]!r}")
    for key, value in entries.items():
        if locale == "en" and not value:
            errors.append(f"{name}: no English for {key!r}")
        if value and not is_catalog_id(key) and sorted(PLACEHOLDER.findall(key)) != sorted(
            PLACEHOLDER.findall(value)
        ):
            errors.append(f"{name}: placeholders of {key!r} differ in {value!r}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--check", action="store_true", help="check instead of writing")
    args = parser.parse_args(argv)
    rep = collect()
    errors = list(rep.errors)
    if args.check:
        pot = I18N / "messages.pot"
        if not pot.exists() or pot.read_text(encoding="utf-8") != render_pot(rep):
            errors.append("i18n/messages.pot is out of date")
        for locale in LOCALES:
            errors += check_po(locale, rep, read_po(I18N / f"{locale}.po"))
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        if errors:
            print("Wrap the text in tr() or run `python3 -m tools.i18n.extract`.", file=sys.stderr)
            return 1
        print(f"Translations are complete: {len(rep.keys)} keys in {len(LOCALES)} languages.")
        return 0
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    I18N.mkdir(exist_ok=True)
    (I18N / "messages.pot").write_text(render_pot(rep), encoding="utf-8")
    for locale in LOCALES:
        path = I18N / f"{locale}.po"
        path.write_text(render_po(locale, rep, read_po(path)), encoding="utf-8")
    print(f"Wrote {len(rep.keys)} keys to i18n/ ({len(errors)} problem(s)).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
