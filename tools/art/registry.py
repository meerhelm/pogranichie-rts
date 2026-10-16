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

## Animations every unit has, and the extra ones: `work` for peasants (felling, digging,
## building), `attack` in a style of people.ATTACK_STYLES (beasts lunge, riders use the style
## too while the horse stands). The wagon neither works nor fights.
BASE_ANIMS = [("idle", 8, 6), ("walk", 12, 15)]  # name, frames, fps
WORK_ANIM = ("work", 8, 9)
ATTACK_ANIM = ("attack", 8, 12)
WORKERS = {"gdl_peasant", "to_peasant", "gdl_camp_servant"}
ATTACK_STYLE = {
    "gdl_peasant": "swing", "gdl_spearman": "thrust", "gdl_forest_archer": "bow",
    "gdl_znakharka": "cast", "gdl_castle_archer": "bow", "gdl_camp_servant": "swing",
    "to_peasant": "swing", "to_halfbrother": "thrust", "to_knecht": "thrust",
    "to_crossbow": "crossbow", "to_priest": "cast", "to_tithe_collector": "swing",
    "nt_villager": "swing", "hero_rumbaudas": "bow", "hero_keeper": "cast",
    "gdl_light_horse": "throw", "gdl_lit_lance": "thrust", "to_knight_brother": "thrust",
    "to_prussian_rider": "thrust", "hero_gintaut": "thrust", "hero_kuchmeister": "swing",
    **{uid: "lunge" for uid in beasts.UNITS},
}


def anims(uid: str) -> list[tuple[str, int, int]]:
    out = list(BASE_ANIMS)
    if uid in WORKERS:
        out.append(WORK_ANIM)
    if uid in ATTACK_STYLE:
        out.append(ATTACK_ANIM)
    return out


def style(figure, uid: str) -> None:
    """Gives a built model its attack style (a rider's goes to the rider)."""
    target = getattr(figure, "rider", figure)
    if uid in ATTACK_STYLE and hasattr(target, "attack_style"):
        target.attack_style = ATTACK_STYLE[uid]
