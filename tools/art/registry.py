"""Every code-built asset by catalog id, with how it is rendered."""

from typing import Callable, NamedTuple

from tools.art import (beasts, buildings_gdl, buildings_pl, buildings_to, folk, folk_1410, folk_1435, folk_1500,
                       folk_1507, folk_1508, folk_1514, folk_crown, folk_crown_1410, models)


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
## A man on foot who raises a pole over his head (mo_inok lifts the icon).
TALL = {"frame": (160, 216), "pivot": (64, 176)}
TALL_UNITS = {"mo_inok", "pl_priest"}
## Long weapons levelled forward reach past the usual frame (pl_drab's pike, the handgunner's smoke).
PIKE = {"frame": (288, 216), "pivot": (144, 176)}
WIDE = {"frame": (224, 144), "pivot": (112, 104)}
FRAMES = {"pl_drab": PIKE, "pl_handgunner": WIDE}

UNITS: dict[str, Unit] = {uid: Unit(fn, **TALL) if uid in TALL_UNITS else Unit(fn) for uid, fn in {
    **models.UNITS, **folk.UNITS, **folk_1410.UNITS, **folk_1500.UNITS, **folk_1507.UNITS,
    **folk_1508.UNITS, **folk_1514.UNITS, **folk_crown.UNITS, **folk_crown_1410.UNITS}.items()}
for _uid, _frame in FRAMES.items():
    UNITS[_uid] = Unit(UNITS[_uid].build, **_frame)
for _uid, _fn in beasts.UNITS.items():
    UNITS[_uid] = Unit(_fn, **BEAST) if _uid in beasts.BIG_BEASTS else Unit(_fn)
for _uid, _fn in {**beasts.MOUNTED_UNITS, **folk_1410.MOUNTED_UNITS, **folk_1435.MOUNTED_UNITS,
                  **folk_1500.MOUNTED_UNITS, **folk_1507.MOUNTED_UNITS,
                  **folk_1508.MOUNTED_UNITS, **folk_1514.MOUNTED_UNITS, **folk_crown.MOUNTED_UNITS,
                  **folk_crown_1410.MOUNTED_UNITS}.items():
    UNITS[_uid] = Unit(_fn, **MOUNTED)
for _uid, _fn in {**beasts.WAGONS, **folk_1410.WAGONS, **folk_1500.WAGONS, **folk_1508.WAGONS,
                  **folk_crown.WAGONS}.items():
    UNITS[_uid] = Unit(_fn, **WAGON)

BUILDINGS: dict[str, Building] = {
    "gdl_house": Building(models.gdl_house, (2, 2), 6),
    "gdl_town_center": Building(models.gdl_town_center, (4, 4), 9),
}
for _uid, (_fn, _cells, _tall) in {**buildings_gdl.BUILDINGS, **buildings_to.BUILDINGS,
                                   **buildings_pl.BUILDINGS, **folk_1507.BUILDINGS, **folk_1508.BUILDINGS}.items():
    # Palisade arms are drawn beside the post piece, which alone carries the site props.
    _props = not _uid.startswith(("gdl_palisade_", "to_palisade_", "pl_palisade_", "gdl_wall_"))
    BUILDINGS[_uid] = Building(_fn, _cells, _tall, _props)

TREES = models.TREES
## Static map props drawn like trees (one view, color and shadow, no team pass): props/<id>_*.
PROPS = {**folk_1507.PROPS, **folk_1508.PROPS, **folk_1514.PROPS}
## Props too big for the usual frame (the old oak): id -> (width, height, pivot) to render at.
PROP_FRAMES = folk_1514.PROP_FRAMES
DEPOSITS = models.DEPOSITS
DEPOSIT_VARIANTS = models.DEPOSIT_VARIANTS

## Animations every unit has, and the extra ones: `work` for peasants (felling, digging,
## building), `attack` in a style of people.ATTACK_STYLES (beasts lunge, riders use the style
## too while the horse stands). Wagons neither work nor fight; the bombard and the field gun
## fire (flash, smoke, recoil: folk_1410.Bombard, folk_1500.FieldGun). Civilians (to_spy,
## hero_council_envoys, hero_maciej, hero_stranger) only idle and walk.
BASE_ANIMS = [("idle", 8, 6), ("walk", 12, 15)]  # name, frames, fps
WORK_ANIM = ("work", 8, 9)
ATTACK_ANIM = ("attack", 8, 12)
WORKERS = {"gdl_peasant", "to_peasant", "gdl_camp_servant", "gdl_burgher", "pl_kmet", "pl_pavise"}
ATTACK_STYLE = {
    "gdl_peasant": "swing", "gdl_spearman": "thrust", "gdl_forest_archer": "bow",
    "gdl_znakharka": "cast", "gdl_castle_archer": "bow", "gdl_camp_servant": "swing",
    "to_peasant": "swing", "to_halfbrother": "thrust", "to_knecht": "thrust",
    "to_crossbow": "crossbow", "to_priest": "cast", "to_tithe_collector": "swing",
    "nt_villager": "swing", "hero_rumbaudas": "bow", "hero_keeper": "cast",
    "gdl_light_horse": "throw", "gdl_lit_lance": "thrust", "to_knight_brother": "thrust",
    "to_prussian_rider": "thrust", "hero_gintaut": "thrust", "hero_kuchmeister": "swing",
    "gdl_samogitian": "thrust", "pl_spearman": "thrust", "pl_crossbow": "crossbow",
    "nt_steppe_archer": "bow", "pl_kopia": "thrust", "to_guest_knight": "thrust",
    "hero_vytautas": "swing", "hero_lengvenis": "thrust", "hero_wallenrode": "thrust",
    "hero_jungingen": "swing", "to_bombard": "fire", "nt_pagan": "swing", "nt_pagan_priest": "cast",
    "hero_mikolaj": "swing", "hero_jurij_gintovt": "thrust", "hero_mikhail_sigismundovich": "swing",
    "hero_jakub_kobylany": "thrust", "hero_nesselrode": "thrust", "hero_kerskorf": "swing",
    "gdl_szlachta_lance": "thrust", "gdl_field_gun": "fire", "mo_syn_boyarsky": "bow", "mo_boyar": "thrust",
    "mo_inok": "cast", "hero_andrei": "thrust", "hero_ostrogski": "swing", "hero_shchenya": "swing",
    "hero_ostrogski_fugitive": "swing", "mo_storozha": "bow", "hero_nezhdan": "bow",
    "gdl_burgher": "swing", "gdl_hakownica": "crossbow", "hero_yuri_olelkovich": "swing", "mo_cannon": "fire",
    "pl_drab": "thrust", "pl_handgunner": "crossbow", "pl_hussar": "thrust", "hero_swierczowski": "swing",
    "hero_sampolinski": "thrust", "hero_chelyadnin": "swing", "hero_bulgakov": "thrust",
    "pl_kmet": "swing", "pl_bowman": "bow", "pl_light_horse": "thrust", "pl_foot_servant": "thrust",
    "pl_pavise": "swing", "pl_priest": "cast",
    "hero_jasko": "thrust", "hero_zyndram": "swing", "hero_marcin": "thrust", "hero_olesnicki": "swing",
    "hero_jagiello": "swing", "hero_order_k1": "thrust",
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
