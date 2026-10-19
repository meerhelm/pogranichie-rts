"""Parse the «Особое» column of unit tables into classes, bonuses, tags and parameters.

The column starts with the unit's classes ("Пехота, копейщик.") and continues with rule
clauses separated by "; " or ". ". Each clause is matched against RULES below; a match
adds tags (StringName flags) and integer parameters. Clauses that match nothing are
returned as `unparsed`: the exporter fails on them for prototype units and lists them for
the rest, so a new rule in the catalog never slips into the game silently.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass, field

from . import cells

CLASSES = {
    "пехота": "infantry",
    "копейщик": "spearman",
    "стрелок": "archer",
    "огнестрел": "firearm",
    "конница лёгкая": "light_cavalry",
    "конница тяжёлая": "heavy_cavalry",
    "конница тяжёлая (средняя)": "heavy_cavalry",
    "конный стрелок": "horse_archer",
    "осадное": "siege",
    "духовный": "spiritual",
    "существо": "creature",
    "герой вместо существа": "hero",
    "крестьянин": "peasant",
    "лодка": "boat",
}
# Every kind of cavalry also counts as "cavalry" for bonuses like "+6 к коннице".
CAVALRY = {"light_cavalry", "heavy_cavalry", "horse_archer"}

BONUS_TARGETS = {
    "коннице": "cavalry",
    "тяжёлой коннице": "heavy_cavalry",
    "копейщикам": "spearman",
    "существам": "creature",
    "постройкам": "building",
}

ABILITIES = {
    "Литовский отход": "lithuanian_retreat",
    "Экзорцизм": "sp_exorcism",
    "Реликвия в строю": "sp_relic",
    "Пророчество": "sp_prophecy",
}

# "Как у ВКЛ" and similar: the unit copies another unit's rules.
SAME_AS_FACTION = {"ВКЛ": "gdl", "Короны": "pl"}


@dataclass
class Special:
    classes: list[str] = field(default_factory=list)
    bonuses: dict[str, int] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    params: dict[str, int] = field(default_factory=dict)
    same_as: str = ""
    unparsed: list[str] = field(default_factory=list)

    def tag(self, *names: str) -> None:
        for name in names:
            if name not in self.tags:
                self.tags.append(name)


Rule = tuple[str, Callable[[Special, re.Match, str], None]]


def _params(**names: int) -> Callable[[Special, re.Match, str], None]:
    """Store numbered regex groups as integer params: _params(sight=1)."""

    def apply(sp: Special, m: re.Match, _uid: str) -> None:
        for name, group in names.items():
            if m.group(group) is not None:
                sp.params[name] = cells.integer(m.group(group))

    return apply


def _tags(*names: str) -> Callable[[Special, re.Match, str], None]:
    return lambda sp, _m, _uid: sp.tag(*names)


def _bonuses(sp: Special, m: re.Match, _uid: str) -> None:
    for amount, target in re.findall(r"\+(\d+) (?:к|по) ([^,]+)", m.group(0)):
        sp.bonuses[BONUS_TARGETS[target.strip()]] = int(amount)


def _charge(sp: Special, m: re.Match, _uid: str) -> None:
    sp.params["charge_permille"] = cells.permille(m.group(1))
    if m.group(2):
        sp.params["charge_distance"] = int(m.group(2))
    sp.tag("charge")


def _abilities(sp: Special, m: re.Match, _uid: str) -> None:
    for name in re.findall(r"«([^»]+)»", m.group(0)):
        sp.tag(ABILITIES[name])


def _same_as(sp: Special, m: re.Match, uid: str) -> None:
    faction = SAME_AS_FACTION[m.group("faction")]
    base = m.group("unit") or uid.split("_", 1)[1]
    sp.same_as = f"{faction}_{base}"


_TARGETS = "|".join(re.escape(t) for t in BONUS_TARGETS)
_ABILITY = "«(?:" + "|".join(re.escape(a) for a in ABILITIES) + ")»"

RULES: list[Rule] = [
    (rf"\+\d+ (?:к|по) (?:{_TARGETS})(?:, \+\d+ (?:к|по) (?:{_TARGETS}))*", _bonuses),
    (r"таран ×(\d+(?:,\d+)?)(?: после (?:разгона )?(\d+) клет(?:ки|ок))?", _charge),
    (rf"{_ABILITY}(?:, {_ABILITY})*", _abilities),
    (r"не больше (\d+)", _params(limit=1)),
    (r"один на игрока", lambda sp, _m, _u: sp.params.__setitem__("limit", 1)),
    (r"не больше (\d+) на каждый комтурский замок", _params(limit_per_castle=1)),
    (r"(\d+) на каждую слободу", _params(limit_per_sloboda=1)),
    (r"обзор (\d+)", _params(sight=1)),
    (
        r"с собаками видит скрытых в радиусе (\d+)",
        lambda sp, m, _u: (sp.tag("dogs"), sp.params.update(dogs_radius=int(m.group(1)))),
    ),
    (
        r"жалованье (\d+) С в минуту(?:, без него уходит через (\d+) с)?",
        _params(upkeep_silver_per_min=1, desert_after_s=2),
    ),
    (r"лечит (\d+) HP/с(?: в радиусе (\d+))?", _params(heal_hp_per_s=1, heal_radius=2)),
    (r"заклинания ВКЛ", _tags("casts_faction_spells")),
    (r"ставит (?:алку|скит|крест и каплицу)", _tags("builds_shrine")),
    (r"лес и болото без штрафа", _tags("forest_walker")),
    (r"в лесу \+(\d+)/\+(\d+) брони", _params(forest_armor_melee=1, forest_armor_pierce=2)),
    (r"в лесу невидим(?:, пока не выстрелит)?", _tags("forest_stealth")),
    (
        r"как жемайт: лес без штрафа, в лесу \+(\d+)/\+(\d+)",
        lambda sp, m, _u: (
            sp.tag("forest_walker"),
            sp.params.update(forest_armor_melee=int(m.group(1)), forest_armor_pierce=int(m.group(2))),
        ),
    ),
    (r"из леса \+(\d+) к дальности", _params(forest_range_bonus=1)),
    (
        r"сулица: бросок (\d+) С на (\d+) клетки раз в (\d+) с",
        lambda sp, m, _u: (
            sp.tag("javelin"),
            sp.params.update(
                javelin_damage=int(m.group(1)),
                javelin_range=int(m.group(2)),
                javelin_cooldown_ticks=cells.ticks(m.group(3)),
            ),
        ),
    ),
    (
        r"на стене \+(\d+) к дальности и \+(\d+)/\+(\d+) брони",
        _params(wall_range_bonus=1, wall_armor_melee=2, wall_armor_pierce=3),
    ),
    (r"стреляет на ходу", _tags("fires_while_moving")),
    (r"собирает, строит, чинит, валит засеки", _tags("gather", "build", "repair", "fell_zaseka")),
    (r"строит лагерь и наплавной мост, чинит", _tags("build_field_camp", "build_bridge", "repair")),
    (r"ресурсы не собирает", _tags("no_gather")),
    (r"везёт (\d+)(?: любого ресурса)?", _params(carry=1)),
    (r"ставит походный (?:лагерь|стан)", _tags("build_field_camp")),
    (r"урон по площади радиусом (\d+)", _params(splash_radius=1)),
    (r"развёртывание (\d+) с", lambda sp, m, _u: sp.params.update(deploy_ticks=cells.ticks(m.group(1)))),
    (r"не уходит в погоню", _tags("no_pursuit")),
    (r"сам уходит в погоню", _tags("auto_pursuit")),
    (r"(?:попадание|залп) −(\d+) духа цели", _params(hit_morale_damage=1)),
    (r"залп −(\d+) духа в радиусе (\d+)", _params(volley_morale_damage=1, volley_morale_radius=2)),
    (
        r"может спешиться: \+(\d+)/\+(\d+) брони, скорость пехоты",
        lambda sp, m, _u: (
            sp.tag("can_dismount"),
            sp.params.update(dismount_armor_melee=int(m.group(1)), dismount_armor_pierce=int(m.group(2))),
        ),
    ),
    (r"в гарнизоне даёт башне \+(\d+) стрелу", _params(garrison_tower_arrows=1)),
    (r"освящение в радиусе (\d+)", _params(consecration_radius=1)),
    (r"забирает еду у деревень", _tags("tithe_collector")),
    (r"не дерётся|не атакует|не сражается", _tags("non_combat")),
    (r"наполняет шкалу Свидетельства", _tags("witness_meter")),
    (
        r"как (?P<unit>ручничник) (?P<faction>Короны)",
        lambda sp, _m, _u: setattr(sp, "same_as", "pl_handgunner"),
    ),
    (r"(?:как у|та же модель, что у) (?P<faction>ВКЛ)(?P<unit>)", _same_as),
    # Flavour with no rule behind it: the catalog explains, the game shows it on the card.
    (r"бежит при (\d+) духа", _params(flee_morale=1)),
    (
        r"через (\d+) минут уезжает",
        lambda sp, m, _u: sp.params.update(lifetime_ticks=cells.ticks(m.group(1)) * 60),
    ),
    (r"приходит со стаей из (\d+) волков", _params(pack_wolves=1)),
    (r"поёт «Богородицу»", _tags("sp_bogurodzica")),
    (r"несёт икону", _tags("sp_icon")),
    (r"в дождь не стреляет", _tags("rain_silenced")),
    (r"отходит без потери духа", _tags("lithuanian_retreat")),
    (r"при отходе теряет вдвое меньше духа", _tags("steady_retreat")),
    (r"стреляет на ходу, вблизи сабля (\d+) Б", lambda sp, m, _u: (
        sp.tag("fires_while_moving"), sp.params.update(close_melee_damage=int(m.group(1))))),
    # ВКЛ 7 (Слуцк): burghers who douse fires and take up arms in a siege, the hook gun on the
    # wall, the Muscovite cannon against gates and wood.
    (r"тушит пожары, носит воду", _tags("douses")),
    (r"в осаде берёт оружие и бьёт на (\d+) Б", _params(militia_damage=1)),
    (
        r"стреляет только с крюка на стене или в укреплении \(установка (\d+) с\)",
        lambda sp, m, _u: (sp.tag("wall_mounted"), sp.params.update(mount_ticks=cells.ticks(m.group(1)))),
    ),
    (
        r"\+(\d+) по воротам и деревянным постройкам, по каменным стенам вдвое слабее",
        lambda sp, m, _u: sp.params.update(wood_bonus=int(m.group(1)), stone_permille=500),
    ),
    # ВКЛ 8 (Орша): the drabs' ditch belongs to the Crown's wagon fort, not in the game yet; the
    # hussar's lance and sabre charge like any other; the note on what a hussar was in 1514.
    (r"роет ров у табора", _tags()),
    (r"копьё и сабля, таран ×(\d+(?:,\d+)?) после (\d+) клет(?:ки|ок)", _charge),
    (r"это лёгкая сербская конница около 1500 года, не крылатая гусария", _tags()),
    (r"в Державе заменяет литовское копьё", _tags()),
    (r"грабит обозы", _tags("plunders_wagons")),
    (
        r"−(\d+) урона после (\d+) с сечи",
        lambda sp, m, _u: sp.params.update(
            melee_fatigue_damage=int(m.group(1)), melee_fatigue_ticks=cells.ticks(m.group(2))
        ),
    ),
    (r"в жару теряет дух \(кампания\)", _tags("heat_morale")),
    (r"стреляет и без батареи", _tags()),
    (r"в дождь перезарядка вдвое дольше", _tags("rain_slow_reload")),
    (r"из (\d+) возов собирается (?:табор|вагенбург.*)", _params(tabor_wagons=1)),
    # The Crown (skirmish faction): the foot servant by his knight's lance and in close order,
    # the pavise set up in front of the shooters, the bombard firing only from its battery.
    (r"рядом с копьём \+(\d+) духа", lambda sp, m, _u: (
        sp.tag("lance_escort"), sp.params.update(escort_morale=int(m.group(1))))),
    (r"в сомкнутом строю соседи теряют вдвое меньше духа", _tags("steadies_neighbours")),
    (
        r"ставит павезу за (\d+(?:,\d+)?) с: стрелки за ним \+(\d+) к С-броне",
        lambda sp, m, _u: (
            sp.tag("pavise"),
            sp.params.update(pavise_ticks=cells.ticks(m.group(1)), pavise_armor=int(m.group(2))),
        ),
    ),
    (
        r"стреляет только из батареи \(развёртывание (\d+) с\), (\d+) железа пороха за выстрел",
        lambda sp, m, _u: (
            sp.tag("battery_only"),
            sp.params.update(deploy_ticks=cells.ticks(m.group(1)), shot_iron=int(m.group(2))),
        ),
    ),
    # Корона 2: the Gdańsk shipmen of the night sorties.
    (r"ночью виден только с (\d+) клеток", _params(night_reveal_cells=1)),
    (
        r"заклёпывает бомбарду за (\d+) с",
        lambda sp, m, _u: (sp.tag("spiker"), sp.params.update(spike_ticks=cells.ticks(m.group(1)))),
    ),
    # Корона 3: the Hussite «orphans» of Jan Čapek and the Gdańsk crossbowmen. The javelin
    # has no cooldown in the catalog: it is thrown as often as the GDL light horse's (12 s); the
    # war wagons make a ring of four, like the Crown's.
    (
        r"сулица (\d+) С на (\d+) клетки",
        lambda sp, m, _u: (
            sp.tag("javelin"),
            sp.params.update(
                javelin_damage=int(m.group(1)),
                javelin_range=int(m.group(2)),
                javelin_cooldown_ticks=cells.ticks("12"),
            ),
        ),
    ),
    (r"у возов \+(\d+) к коннице", _params(wagon_cavalry_bonus=1)),
    (r"стрелки на возу", _tags()),
    (r"стреляет с воза без развёртывания", _tags()),
    (
        r"табор собирается за (\d+) с, внутри \+(\d+)/\+(\d+)",
        lambda sp, m, _u: sp.params.update(
            tabor_wagons=4,
            tabor_ticks=cells.ticks(m.group(1)),
            tabor_armor_melee=int(m.group(2)),
            tabor_armor_pierce=int(m.group(3)),
        ),
    ),
    (r"как pl_crossbow, городской скин", lambda sp, _m, _u: setattr(sp, "same_as", "pl_crossbow")),
    # Campaign-only notes (К5 calls the servant a worker; plague and rumours are mission rules).
    (r"в кампании сбивает мор и слухи", _tags()),
    (r"в К5 называется работником", _tags()),
    # Animals and villagers.
    (r"даёт сдачи, идёт на охотника", _tags("charges_hunter")),
    (r"бьёт в ответ", _tags("retaliates")),
    (r"убегает", _tags("flees")),
    (r"нападает на одиночек рядом с берлогом", _tags("territorial")),
    (r"ночью нападает на крестьян", _tags("night_raider")),
    (r"платит налог или фураж", _tags("pays_tribute")),
    (r"бежит от солдат", _tags("flees_soldiers")),
    (r"серый плащ", _tags()),
    (r"умеет «Болотный туман»", _tags()),
    (r"сторона переговоров", _tags()),
    (r"разведка", _tags()),
    (r"та же модель в стае волколака", _tags()),
    (r"у Ордена доступен уже в Уделе", _tags()),
    (r"камнемёт", _tags()),
    (r"подробности во вкладке «Магия»", _tags()),
]
_COMPILED = [(re.compile(p), f) for p, f in RULES]


def _lower_first(text: str) -> str:
    return text[:1].lower() + text[1:]


def _split_clauses(text: str) -> list[str]:
    parts = re.split(r"; |\. ", text.strip().rstrip("."))
    return [p.strip() for p in parts if p.strip()]


def parse_special(text: str, uid: str = "") -> Special:
    """Parse one «Особое» cell. uid is the unit id, used by «Как у ВКЛ»."""
    sp = Special()
    clauses = _split_clauses(text)
    if clauses:
        head = clauses[0]
        tokens = [t.strip() for t in head.split(", ")]
        n = 0
        while n < len(tokens) and tokens[n].lower() in CLASSES:
            cls = CLASSES[tokens[n].lower()]
            if cls not in sp.classes:
                sp.classes.append(cls)
            n += 1
        if n:
            rest = ", ".join(tokens[n:])
            clauses = ([rest] if rest else []) + clauses[1:]
    if "hero" in sp.classes:
        sp.tag("replaces_creature")
    if any(c in CAVALRY for c in sp.classes):
        sp.classes.append("cavalry")
    for clause in clauses:
        normalized = _lower_first(clause)
        for regex, apply in _COMPILED:
            m = regex.fullmatch(normalized) or regex.fullmatch(clause)
            if m:
                apply(sp, m, uid)
                break
        else:
            # "Камнемёт, развёртывание 10 с, урон по площади радиусом 1": a comma list of
            # rules is accepted when every part is a known rule on its own.
            parts = [_lower_first(p) for p in clause.split(", ")]
            found = [_match(p) for p in parts] if len(parts) > 1 else [None]
            if all(found):
                for regex_match, apply in found:
                    apply(sp, regex_match, uid)
            else:
                sp.unparsed.append(clause)
    return sp


def _match(clause: str):
    for regex, apply in _COMPILED:
        m = regex.fullmatch(clause)
        if m:
            return m, apply
    return None
