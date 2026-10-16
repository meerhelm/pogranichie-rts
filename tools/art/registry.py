"""Every code-built asset by catalog id, with how it is rendered."""

from typing import Callable, NamedTuple

from tools.art import beasts, buildings_gdl, buildings_to, folk, models


class Unit(NamedTuple):
    build: Callable
    frame: tuple[int, int] = (160, 144)
    pivot: tuple[int, int] = (64, 104)


class Building(NamedTuple):
    build: Callable
    cells: tuple[int, int]
    tall: float = 8.0  # metres of height the frame must hold (it is cropped afterwards)
    props: bool = True  # foundation stakes, scaffolds and timber in the build stages


## Mounted units and big beasts need a larger frame than a man on foot.
MOUNTED = {"frame": (224, 256), "pivot": (108, 184)}
BEAST = {"frame": (224, 176), "pivot": (108, 124)}
WAGON = {"frame": (320, 240), "pivot": (156, 150)}

UNITS: dict[str, Unit] = {uid: Unit(fn) for uid, fn in {**models.UNITS, **folk.UNITS}.items()}
for _uid, _fn in beasts.UNITS.items():
    UNITS[_uid] = Unit(_fn, **BEAST) if _uid in beasts.BIG_BEASTS else Unit(_fn)
for _uid, _fn in beasts.MOUNTED_UNITS.items():
    UNITS[_uid] = Unit(_fn, **MOUNTED)
for _uid, _fn in beasts.WAGONS.items():
    UNITS[_uid] = Unit(_fn, **WAGON)

BUILDINGS: dict[str, Building] = {
    "gdl_house": Building(models.gdl_house, (2, 2), 6),
    "gdl_town_center": Building(models.gdl_town_center, (4, 4), 9),
}
for _uid, (_fn, _cells, _tall) in {**buildings_gdl.BUILDINGS, **buildings_to.BUILDINGS}.items():
    # Palisade arms are drawn beside the post piece, which alone carries the site props.
    _props = not (_uid.startswith("gdl_palisade_") or _uid.startswith("to_palisade_"))
    BUILDINGS[_uid] = Building(_fn, _cells, _tall, _props)

TREES = models.TREES
DEPOSITS = models.DEPOSITS
DEPOSIT_VARIANTS = models.DEPOSIT_VARIANTS
