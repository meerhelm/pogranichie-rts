"""Write Godot text resources (.tres) for Def scripts, byte-for-byte reproducible."""

from __future__ import annotations

import json

SCRIPT_DIR = "res://core/data"


def script_path(kind: str) -> str:
    snake = "".join("_" + c.lower() if c.isupper() else c for c in kind).lstrip("_")
    return f"{SCRIPT_DIR}/{snake}.gd"


def _string(value: str) -> str:
    # JSON string escaping matches Godot's for the characters we use; keep UTF-8 as is.
    return json.dumps(value, ensure_ascii=False)


def _value(kind: str, value) -> str:
    if kind == "int":
        return str(int(value))
    if kind == "bool":
        return "true" if value else "false"
    if kind == "name":
        return "&" + _string(value)
    if kind == "text":
        return _string(value)
    if kind == "names":
        items = ", ".join("&" + _string(v) for v in value)
        return f"Array[StringName]([{items}])"
    if kind == "name_ints":
        items = ", ".join(f"&{_string(k)}: {int(v)}" for k, v in sorted(value.items()))
        return f"Dictionary[StringName, int]({{{items}}})"
    raise ValueError(f"unknown field type {kind!r}")


def render(kind: str, schema: dict[str, str], data: dict) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="{kind}" format=3]',
        "",
        f'[ext_resource type="Script" path="{script_path(kind)}" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
    ]
    for name, field_kind in schema.items():
        lines.append(f"{name} = {_value(field_kind, data[name])}")
    return "\n".join(lines) + "\n"
