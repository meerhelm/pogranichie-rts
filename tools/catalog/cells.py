"""Parsers for catalog table cells.

Every parser takes the cell text exactly as it is in the catalog and returns integers
ready for the simulation: seconds become ticks (20 per second), multipliers become
per-mille, decimals are read with Decimal so nothing goes through float.
A cell that does not fit its format raises CellError.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

TICKS_PER_SECOND = 20

DASHES = ("—", "–", "-", "")

AGES = {"Удел": 1, "Хоругвь": 2, "Держава": 3, "кампания": 0}

DAMAGE_TYPES = {"Б": "melee", "С": "pierce", "О": "firearm", "Ос": "siege"}


class CellError(ValueError):
    pass


def is_empty(text: str) -> bool:
    return text.strip() in DASHES


def decimal(text: str) -> Decimal:
    """'2,0' -> Decimal('2.0'). Accepts a decimal comma or point."""
    clean = text.strip().replace(",", ".")
    if not re.fullmatch(r"\d+(\.\d+)?", clean):
        raise CellError(f"not a number: {text!r}")
    try:
        return Decimal(clean)
    except InvalidOperation as err:
        raise CellError(f"not a number: {text!r}") from err


def integer(text: str) -> int:
    value = decimal(text)
    if value != value.to_integral_value():
        raise CellError(f"not an integer: {text!r}")
    return int(value)


def scaled(text: str, scale: int) -> int:
    """Decimal cell times scale, which must come out whole: '1,35' x 1000 -> 1350."""
    value = decimal(text) * scale
    if value != value.to_integral_value():
        raise CellError(f"{text!r} x {scale} is not whole")
    return int(value)


def ticks(text: str) -> int:
    """Seconds -> simulation ticks: '1,8' -> 36."""
    return scaled(text, TICKS_PER_SECOND)


def permille(text: str) -> int:
    """Multiplier -> per-mille: '2,5' -> 2500, '×1,25' -> 1250."""
    return scaled(text.strip().lstrip("×"), 1000)


def milli(text: str) -> int:
    """Speeds and rates are kept exact in thousandths: '0,85' -> 850."""
    return scaled(text, 1000)


def round_half_up(value: Decimal) -> int:
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))


@dataclass(frozen=True)
class Cost:
    food: int = 0
    wood: int = 0
    iron: int = 0
    silver: int = 0
    power: int = 0
    debt: int = 0
    per_tile: bool = False
    free: bool = False
    # Cost is given by reference: "как конюшня" -> "stable".
    same_as: str = ""
    # Not bought with resources: felled from forest, set up by a wagon, ...
    source: str = ""


COST_RE = re.compile(r"(\d+)/(\d+)/(\d+)/(\d+)")
SAME_AS = {"как конюшня": "stable", "как рынок": "market"}


def cost(text: str) -> Cost:
    """'50/0/20/0', '0/2/0/0 за клетку', 'вызов за 300 Силы', 'бесплатно', ..."""
    t = text.strip()
    if t in SAME_AS:
        return Cost(same_as=SAME_AS[t])
    if t == "бесплатно":
        return Cost(free=True)
    if t == "ставит обозный воз":
        return Cost(source="wagon")
    m = re.fullmatch(r"(?:вызов за )?(\d+) Силы", t)
    if m:
        return Cost(power=int(m.group(1)))
    if t in ("вызов без Силы, цена в долге", "0 Силы, цена в долге"):
        return Cost(debt=1)
    m = re.fullmatch(r"(\d+/\d+/\d+/\d+)(.*)", t)
    if not m:
        raise CellError(f"unknown cost format: {text!r}")
    food, wood, iron, silver = (int(x) for x in COST_RE.fullmatch(m.group(1)).groups())
    tail = m.group(2).strip()
    extra: dict = {}
    if tail == "":
        pass
    elif tail == "за клетку":
        extra["per_tile"] = True
    elif tail == ", рубится из леса":
        extra["source"] = "forest"
    elif re.fullmatch(r"и (\d+) Силы", tail):
        extra["power"] = int(re.fullmatch(r"и (\d+) Силы", tail).group(1))
    else:
        raise CellError(f"unknown cost suffix: {text!r}")
    return Cost(food=food, wood=wood, iron=iron, silver=silver, **extra)


@dataclass(frozen=True)
class Damage:
    amount: int
    type: str
    shots: int = 1


def damage(text: str) -> Damage | None:
    """'6 Б', '200 Ос', '8 О ×5' (five pellets); '—' means the unit does not attack."""
    if is_empty(text):
        return None
    m = re.fullmatch(r"(\d+) (Б|С|О|Ос)(?: ×(\d+))?", text.strip())
    if not m:
        raise CellError(f"unknown damage format: {text!r}")
    return Damage(int(m.group(1)), DAMAGE_TYPES[m.group(2)], int(m.group(3) or 1))


def armor(text: str) -> tuple[int, int]:
    """'1/2' -> (melee, pierce)."""
    m = re.fullmatch(r"(\d+)/(\d+)", text.strip())
    if not m:
        raise CellError(f"unknown armor format: {text!r}")
    return int(m.group(1)), int(m.group(2))


def attack_range(text: str) -> tuple[int, int]:
    """'6' -> (6, 0); '12 (мин. 4)' -> (12, 4); '0' is melee."""
    m = re.fullmatch(r"(\d+)(?: \(мин\. (\d+)\))?", text.strip())
    if not m:
        raise CellError(f"unknown range format: {text!r}")
    return int(m.group(1)), int(m.group(2) or 0)


def age(text: str) -> int:
    """Age index: 1 Удел, 2 Хоругвь, 3 Держава, 0 campaign only."""
    t = text.strip()
    if t not in AGES:
        raise CellError(f"unknown age: {text!r}")
    return AGES[t]


def age_with_exceptions(text: str) -> tuple[int, dict[str, int]]:
    """'Удел (Корона: Хоругвь)' -> (1, {'Корона': 2})."""
    m = re.fullmatch(r"(\S+) \((\S+): (\S+)\)", text.strip())
    if not m:
        return age(text), {}
    return age(m.group(1)), {m.group(2): age(m.group(3))}


def morale(text: str) -> int | None:
    """Starting morale 0..100; '—' means the unit never flees."""
    if is_empty(text):
        return None
    value = integer(text)
    if not 0 <= value <= 100:
        raise CellError(f"morale out of 0..100: {text!r}")
    return value


def seconds_or_none(text: str) -> int | None:
    return None if is_empty(text) else ticks(text)
