"""Build game definitions from catalog.json.

catalog.json is a raw copy of the catalog document. This module parses its cells
(cells.py, rules.py), expands common buildings into one per faction, resolves names and
ids, and returns plain dicts keyed by the fields of the Godot Def classes (SCHEMAS).
Problems are collected in Report instead of stopping at the first one.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from . import cells, rules
from .cells import CellError

FACTIONS = ("gdl", "pl", "to", "mo")
FACTION_BY_NAME = {"ВКЛ": "gdl", "Корона": "pl", "Орден": "to", "Москва": "mo"}
AGE_GENITIVE = {"Удела": 1, "Хоругви": 2}
AGE_IDS = {1: "age_udel", 2: "age_khorugv", 3: "age_derzhava"}
RESOURCES = ("food", "wood", "iron", "silver")

# Combat and morale numbers (M4), in data/rules/combat.tres; values come from manual.json.
COMBAT_RULE_KEYS = (
    "flank_permille", "rear_permille", "firearm_pierce_armor_permille", "siege_vs_unit_permille",
    "forest_miss_permille", "hill_range_bonus", "charge_distance_default", "morale_per_tenth_hp",
    "neighbour_death_morale", "neighbour_radius_milli", "flank_hit_morale", "rear_hit_morale",
    "firearm_hit_morale", "cannon_volley_morale", "cannon_volley_radius", "hero_aura_morale",
    "hero_aura_radius", "formation_morale", "formation_neighbours", "formation_radius_milli",
    "waver_morale", "waver_damage_permille", "flee_ticks", "morale_recovery_per_second",
    "out_of_combat_ticks", "sight_default", "melee_reach_milli", "pursuit_cells",
    "defensive_leash_cells", "projectile_speed_milli", "stealth_reveal_ticks",
    "dismount_speed_milli", "retreat_cells", "retreat_fearless_ticks", "retreat_speed_permille",
    "retreat_disorder_ticks", "retreat_disorder_armor", "turn_window_ticks", "turn_damage_bonus",
    "turn_charge_permille", "retreat_cooldown_ticks", "arena_budget", "arena_iron_permille",
    "arena_silver_permille",
)

# Economy and construction numbers (M5), in data/rules/economy.tres; values from manual.json.
ECONOMY_RULE_KEYS = (
    "carry", "pop_cap", "gather_farm_milli", "gather_hunt_milli", "gather_bort_milli",
    "gather_wood_milli", "gather_iron_milli", "gather_silver_milli", "tree_wood", "bog_ore_iron",
    "silver_mine_silver", "bort_workers", "farm_workers", "zaseka_cells",
    "brick_wood_discount_permille", "brick_wall_silver_discount_permille", "start_food",
    "start_wood", "start_iron", "start_silver", "work_reach_milli", "resource_search_cells",
    "builder_extra_permille", "repair_cost_permille", "repair_time_permille", "queue_max",
    "cancel_refund_permille", "near_forest_cells",
)
# Fog of war numbers (M6), in data/rules/vision.tres; values from manual.json.
VISION_RULE_KEYS = (
    "cover_reveal_cells", "hill_sight_bonus", "foundation_sight",
)
# Places of power and spells (M7), in data/rules/magic.tres; values from manual.json.
MAGIC_RULE_KEYS = (
    "capture_ticks", "capture_radius", "power_cap", "consecration_permille",
    "alka_recharge_permille", "alka_recharge_radius", "cast_range", "relic_morale_floor",
    "relic_enemy_morale", "exorcism_creature_damage",
)
# What a spell does in the game (manual.json → spell_effects, appended to SpellDef.tags): how it
# is aimed and which effect the simulation runs. A prototype spell must have both or be passive.
SPELL_TARGETS = ("target_point", "target_self", "passive")
SPELL_EFFECTS = ("mist", "dispel", "relic", "consecration")
# Keys of tech effects (manual.json → tech_effects). Gathering and farm keys are per-mille
# increases; "<class or unit id>.<stat>" keys change unit stats (see TECH_STATS).
TECH_EFFECT_KEYS = (
    "gather_farm", "gather_hunt", "gather_bort", "gather_wood", "gather_iron", "gather_silver",
    "farm_food", "zaseka_speed", "zaseka_hp", "wall_sight",
)
TECH_STATS = (
    "damage_melee", "damage_pierce", "armor_melee", "armor_pierce", "range", "hp_permille",
    "heal", "radius",
)

# Field types: int, bool, name (StringName), names (Array[StringName]),
# name_ints (Dictionary[StringName, int]), text (String).
COST_FIELDS = {f"cost_{r}": "int" for r in RESOURCES}
SCHEMAS: dict[str, dict[str, str]] = {
    "UnitDef": {
        "id": "name",
        "faction": "name",
        "age": "int",
        "campaign_only": "bool",
        "trained_at": "names",
        "spawned_by": "name",
        **COST_FIELDS,
        "cost_power": "int",
        "cost_debt": "int",
        "train_ticks": "int",
        "pop": "int",
        "hp": "int",
        "damage": "int",
        "damage_type": "name",
        "shots": "int",
        "reload_ticks": "int",
        "attack_range": "int",
        "min_range": "int",
        "armor_melee": "int",
        "armor_pierce": "int",
        "speed_milli": "int",
        "morale": "int",
        "never_flees": "bool",
        "classes": "names",
        "bonuses": "name_ints",
        "tags": "names",
        "params": "name_ints",
        "same_as": "name",
        "food_yield": "int",
        "lifetime_ticks": "int",
    },
    "BuildingDef": {
        "id": "name",
        "faction": "name",
        "base_id": "name",
        "age": "int",
        "campaign_only": "bool",
        **COST_FIELDS,
        "cost_per_tile": "bool",
        "cost_source": "name",
        "build_ticks": "int",
        "hp": "int",
        "armor_melee": "int",
        "armor_pierce": "int",
        "pop_provided": "int",
        "garrison": "int",
        "accepts": "names",
        "damage": "int",
        "damage_type": "name",
        "attack_range": "int",
        "power_rate_milli": "int",
        "trains": "names",
        "tags": "names",
        "params": "name_ints",
    },
    "TechDef": {
        "id": "name",
        "faction": "name",
        "building": "name",
        "age": "int",
        **COST_FIELDS,
        "research_ticks": "int",
        "faith": "bool",
        "effects": "name_ints",
    },
    "SpellDef": {
        "id": "name",
        "faction": "name",
        "casters": "names",
        "age": "int",
        "power_cost": "int",
        "debt_cost": "int",
        "cooldown_ticks": "int",
        "radius": "int",
        "duration_ticks": "int",
        "tags": "names",
        "params": "name_ints",
    },
    "FactionDef": {
        "id": "name",
        "unit_ids": "names",
        "building_ids": "names",
        "tech_ids": "names",
        "spell_ids": "names",
        "tech_cost_permille": "name_ints",
    },
    "AgeDef": {
        "id": "name",
        "index": "int",
        **COST_FIELDS,
        "research_ticks": "int",
        "params": "name_ints",
    },
    "PowerPlaceDef": {
        "id": "name",
        "power_permille": "int",
    },
    "TerrainDef": {
        "id": "name",
        "passable": "bool",
        "boats_only": "bool",
        "infantry_permille": "int",
        "cavalry_permille": "int",
        "uphill_permille": "int",
        "siege_blocked": "bool",
    },
    # One resource, data/rules/combat.tres: the combat and morale numbers the catalog gives in
    # prose (manual.json → combat_rules).
    "CombatRulesDef": {"id": "name", **{k: "int" for k in COMBAT_RULE_KEYS}},
    # data/rules/economy.tres: gathering, construction and production (manual.json →
    # economy_rules).
    "EconomyRulesDef": {"id": "name", **{k: "int" for k in ECONOMY_RULE_KEYS}},
    # data/rules/vision.tres: fog of war (manual.json → vision_rules).
    "VisionRulesDef": {"id": "name", **{k: "int" for k in VISION_RULE_KEYS}},
    # data/rules/magic.tres: places of power and spells (manual.json → magic_rules).
    "MagicRulesDef": {"id": "name", **{k: "int" for k in MAGIC_RULE_KEYS}},
    "CatalogIndex": {
        "exported_on": "text",
        "units": "names",
        "buildings": "names",
        "techs": "names",
        "spells": "names",
        "factions": "names",
        "ages": "names",
        "power_places": "names",
        "terrains": "names",
        "prototype_factions": "names",
        "prototype_units": "names",
        "prototype_buildings": "names",
        "prototype_techs": "names",
        "prototype_spells": "names",
    },
}
KIND_DIRS = {
    "UnitDef": "units",
    "BuildingDef": "buildings",
    "TechDef": "techs",
    "SpellDef": "spells",
    "FactionDef": "factions",
    "AgeDef": "ages",
    "PowerPlaceDef": "power_places",
    "TerrainDef": "terrain",
    "CombatRulesDef": "rules",
    "EconomyRulesDef": "rules",
    "VisionRulesDef": "rules",
    "MagicRulesDef": "rules",
}


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    pending: list[str] = field(default_factory=list)

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")


def _defaults(kind: str) -> dict:
    zero = {"int": 0, "bool": False, "name": "", "names": [], "name_ints": {}, "text": ""}
    return {
        k: (zero[t].copy() if isinstance(zero[t], (list, dict)) else zero[t])
        for k, t in SCHEMAS[kind].items()
    }


def _set_cost(d: dict, cost: cells.Cost) -> None:
    for r in RESOURCES:
        d[f"cost_{r}"] = getattr(cost, r)


def _required(row: dict, keys: tuple[str, ...], where: str, rep: Report) -> bool:
    ok = True
    for k in keys:
        if row.get(k, "").strip() == "":
            rep.error(where, f"required cell «{k}» is empty")
            ok = False
    return ok


def _strip_name(name: str) -> str:
    """'Подсека*' -> 'Подсека', 'Шницхаус (арбалетная мастерская)' -> 'Шницхаус'."""
    return re.sub(r"\s*\(.*\)$", "", name.rstrip("*")).strip()


class Builder:
    def __init__(self, catalog: dict, manual: dict, prototype: dict) -> None:
        self.cat = catalog
        self.manual = manual
        self.proto = prototype
        self.rep = Report()
        self.units: dict[str, dict] = {}
        self.buildings: dict[str, dict] = {}
        self.techs: dict[str, dict] = {}
        self.spells: dict[str, dict] = {}
        self.ages: dict[str, dict] = {}
        self.power_places: dict[str, dict] = {}
        self.terrains: dict[str, dict] = {}
        self.rules: dict[str, dict] = {}
        self.economy: dict[str, dict] = {}
        self.vision: dict[str, dict] = {}
        self.magic: dict[str, dict] = {}
        self.factions: dict[str, dict] = {}
        # (faction or "", lower-case building name) -> building id
        self.building_names: dict[tuple[str, str], str] = {}
        self.common_ids: set[str] = set()
        self.unit_names: dict[tuple[str, str], str] = {}
        self.unit_specials: dict[str, rules.Special] = {}

    # --- buildings -------------------------------------------------------------------

    def _building_row(self, d: dict, row: dict, where: str) -> None:
        try:
            age, exceptions = cells.age_with_exceptions(row["age"])
            faction_age = {FACTION_BY_NAME[k]: v for k, v in exceptions.items()}
            d["age"] = faction_age.get(d["faction"], age)
            d["campaign_only"] = d["age"] == 0
            cost = cells.cost(row["cost"])
            # "как конюшня": a faction variant keeps the cost of the building it replaces.
            if not cost.same_as:
                _set_cost(d, cost)
                d["cost_per_tile"] = cost.per_tile
                d["cost_source"] = cost.source
            d["build_ticks"] = cells.ticks(row["build_time"])
            d["hp"] = cells.integer(row["hp"])
            d["armor_melee"], d["armor_pierce"] = cells.armor(row["armor"])
        except CellError as err:
            self.rep.error(where, str(err))
        self._building_effect(d, row["effect"])

    def _building_effect(self, d: dict, text: str) -> None:
        m = re.search(r"\+(\d+) нас\.", text)
        if m:
            d["pop_provided"] = int(m.group(1))
        m = re.search(r"гарнизон (\d+)", text)
        if m:
            d["garrison"] = int(m.group(1))
        m = re.search(r"(\d+) (Б|С|О|Ос), дальн\. (\d+)", text)
        if m:
            d["damage"] = int(m.group(1))
            d["damage_type"] = cells.DAMAGE_TYPES[m.group(2)]
            d["attack_range"] = int(m.group(3))
        accepts = []
        if re.search(r"[Пп]риём всех ресурсов|[Пп]риём из обоза", text):
            accepts = list(RESOURCES)
        else:
            for word, res in (("еды", "food"), ("дерева", "wood"), ("железа", "iron"), ("серебра", "silver")):
                if re.search(rf"[Пп]риём [^,;.]*{word}", text):
                    accepts.append(res)
        d["accepts"] = accepts
        m = re.search(r"(\d+) еды, потом пересев", text)
        if m:
            d["params"]["food_capacity"] = int(m.group(1))
        m = re.search(r"[Кк]онница −(\d+)% цены", text)
        if m:
            d["params"]["cavalry_discount_permille"] = int(m.group(1)) * 10

    def build_buildings(self) -> None:
        for row in self.cat["common_buildings"]:
            base = row["id"]
            self.common_ids.add(base)
            for fac in FACTIONS:
                bid = f"{fac}_{base}"
                where = f"building {bid}"
                d = _defaults("BuildingDef")
                d.update(id=bid, faction=fac, base_id=base)
                _required(row, ("id", f"name_{fac}", "age", "cost", "hp"), where, self.rep)
                self._building_row(d, row, where)
                self.buildings[bid] = d
                self.building_names[(fac, _strip_name(row[f"name_{fac}"]).lower())] = bid
                self.building_names[("", _strip_name(row[f"name_{fac}"]).lower())] = base
        for row in self.cat["buildings"]:
            fac = row["faction"]
            if row["id"].endswith("*"):
                self._apply_faction_variant(row)
                continue
            bid = row["id"]
            where = f"building {bid}"
            if not _required(
                row, ("id", "name", "age", "cost", "build_time", "hp", "armor"), where, self.rep
            ):
                continue
            if bid in self.buildings:
                self.rep.error(where, "duplicate id")
            d = _defaults("BuildingDef")
            d.update(id=bid, faction=fac)
            self._building_row(d, row, where)
            self.buildings[bid] = d
            self.building_names[(fac, _strip_name(row["name"]).lower())] = bid
        for bid, over in self.manual["building_overrides"].items():
            if bid.startswith("_"):
                continue
            d = self.buildings[bid]
            if "cost" in over:
                cost = cells.cost(over["cost"])
                _set_cost(d, cost)
                d["cost_per_tile"] = cost.per_tile
            if "hp" in over:
                d["hp"] = cells.integer(over["hp"])
            d["params"].update(over.get("params", {}))
            d["tags"] += over.get("tags", [])
        self._shrine_rates()
        self._building_layout()

    def _building_layout(self) -> None:
        """Footprints and construction tags (M5) from manual.json → building_layout.

        The catalog gives no sizes; every building needs one, keyed by its own id or common id.
        """
        layout = self.manual.get("building_layout", {})
        sizes = layout.get("sizes", {})
        for bid, d in self.buildings.items():
            size = sizes.get(bid) or sizes.get(d["base_id"])
            if size is None:
                self.rep.error(f"building {bid}", "no size in manual.json → building_layout")
                continue
            d["params"]["size_w"], d["params"]["size_h"] = size
            sight = layout.get("sight", {})
            default = sight.get("_default", 0)
            d["params"]["sight"] = sight.get(bid, sight.get(d["base_id"], default))
            for tag, ids in layout.get("tags", {}).items():
                if bid in ids or d["base_id"] in ids:
                    d["tags"].append(tag)

    def _apply_faction_variant(self, row: dict) -> None:
        """'stable*' in a faction tab replaces that faction's copy of a common building."""
        base = row["id"].rstrip("*")
        fac = row["faction"]
        bid = f"{fac}_{base}"
        where = f"building {bid} (faction variant)"
        if bid not in self.buildings:
            self.rep.error(where, f"no common building {base!r}")
            return
        d = self.buildings[bid]
        self._building_row(d, row, where)
        d["tags"].append("faction_variant")
        self.building_names[(fac, _strip_name(row["name"]).lower())] = bid

    def _shrine_rates(self) -> None:
        for row in self.cat["shrines"]:
            fac = FACTION_BY_NAME.get(row["faction"])
            where = f"shrine of {row['faction']}"
            if fac is None:
                self.rep.error(where, "unknown faction")
                continue
            d = self.buildings[f"{fac}_shrine"]
            try:
                rates = [cells.milli(x) for x in row["power_rate"].split(" → ")]
            except CellError as err:
                self.rep.error(where, str(err))
                continue
            d["power_rate_milli"] = rates[0]
            if len(rates) > 1:
                d["params"]["upgrade_power_rate_milli"] = rates[1]

    def resolve_building(self, fac: str, ref: str) -> str | None:
        """'stable' -> 'gdl_stable'; 'tatar_sloboda' -> 'gdl_tatar_sloboda'; 'pl_tavern' as is."""
        for candidate in (f"{fac}_{ref}", ref):
            if candidate in self.buildings:
                return candidate
        return None

    def resolve_building_name(self, fac: str, name: str) -> str | None:
        alias = self.manual["tech_place_aliases"].get(name)
        if alias:
            return alias if fac == "" or alias.startswith(f"{fac}_") else self.resolve_building(fac, alias)
        return self.building_names.get((fac, name.lower()))

    # --- units -----------------------------------------------------------------------

    SPAWNED_BY = {"«Рейза»": "raid", "способность Двора": "town_center_ability"}

    def build_units(self) -> None:
        rows = [(r, "faction") for r in self.cat["units"]]
        rows += [(r, "neutral") for r in self.cat["neutral_units"]]
        rows += [(r, "animal") for r in self.cat["animals"]]
        for row, kind in rows:
            uid = row["id"]
            where = f"unit {uid}"
            if uid in self.units:
                self.rep.error(where, "duplicate id")
            d = _defaults("UnitDef")
            d.update(id=uid, faction=row["faction"])
            required = ("id", "name", "hp", "armor", "speed")
            if kind == "faction":
                required += ("age", "pop", "special")
            _required(row, required, where, self.rep)
            try:
                self._unit_cells(d, row, kind, where)
            except CellError as err:
                self.rep.error(where, str(err))
            self._unit_special(d, row, kind)
            self.units[uid] = d
            if row.get("name"):
                self.unit_names[(row["faction"], row["name"].lower())] = uid
        self._creatures()
        self._resolve_same_as()

    def _unit_cells(self, d: dict, row: dict, kind: str, where: str) -> None:
        d["hp"] = cells.integer(row["hp"])
        d["armor_melee"], d["armor_pierce"] = cells.armor(row["armor"])
        d["speed_milli"] = cells.milli(row["speed"])
        dmg = cells.damage(row["damage"])
        if dmg:
            d["damage"], d["damage_type"], d["shots"] = dmg.amount, dmg.type, dmg.shots
        if kind == "animal":
            d["food_yield"] = cells.integer(row["food"])
            d["never_flees"] = True
            d["reload_ticks"] = cells.ticks("2,0") if dmg else 0
            return
        d["reload_ticks"] = cells.seconds_or_none(row["reload"]) or 0
        if not cells.is_empty(row["range"]):
            d["attack_range"], d["min_range"] = cells.attack_range(row["range"])
        m = cells.morale(row["morale"])
        d["never_flees"] = m is None
        d["morale"] = m or 0
        if kind == "neutral":
            return
        d["age"] = cells.age(row["age"])
        d["campaign_only"] = d["age"] == 0
        d["pop"] = cells.integer(row["pop"])
        cost = cells.cost(row["cost"]) if not cells.is_empty(row["cost"]) else cells.Cost()
        _set_cost(d, cost)
        d["cost_power"], d["cost_debt"] = cost.power, cost.debt
        d["train_ticks"] = cells.seconds_or_none(row["train_time"]) or 0
        building = row["building"].strip()
        if building in self.SPAWNED_BY:
            d["spawned_by"] = self.SPAWNED_BY[building]
        elif not cells.is_empty(building):
            for ref in building.split(", "):
                bid = self.resolve_building(d["faction"], ref)
                if bid is None:
                    self.rep.error(where, f"trained at unknown building {ref!r}")
                else:
                    d["trained_at"].append(bid)
                    self.buildings[bid]["trains"].append(d["id"])
        elif not d["campaign_only"]:
            self.rep.error(where, "no building to train it, and it is not campaign-only")

    def _unit_special(self, d: dict, row: dict, kind: str) -> None:
        sp = rules.parse_special(row["special"], d["id"])
        self.unit_specials[d["id"]] = sp
        d["classes"] = sp.classes or list(self.manual["unit_classes"].get(d["id"], []))
        if kind == "animal" and not d["classes"]:
            d["classes"] = ["animal"]
        d["bonuses"], d["tags"], d["params"], d["same_as"] = sp.bonuses, sp.tags, sp.params, sp.same_as
        for clause in sp.unparsed:
            self.rep.pending.append(f"unit {d['id']}: «{clause}»")

    def _resolve_same_as(self) -> None:
        for uid, d in self.units.items():
            ref = d["same_as"]
            if not ref:
                if not d["classes"]:
                    self.rep.error(f"unit {uid}", "no class in «Особое» and no manual class")
                continue
            if ref not in self.units:
                self.rep.error(f"unit {uid}", f"«как у» refers to unknown unit {ref!r}")
                continue
            base = self.units[ref]
            # «Как у ВКЛ» copies what this row does not say itself.
            if not d["classes"]:
                d["classes"] = list(base["classes"])
            for k in ("bonuses", "params"):
                d[k] = {**base[k], **d[k]}
            d["tags"] = base["tags"] + [t for t in d["tags"] if t not in base["tags"]]

    def _creatures(self) -> None:
        for row in self.cat["creatures"]:
            uid = row["id"]
            where = f"creature {uid}"
            d = self.units.get(uid)
            if d is None:
                self.rep.error(where, "not in any unit table")
                continue
            try:
                if cells.integer(row["hp"]) != d["hp"]:
                    self.rep.error(where, f"HP {row['hp']} differs from the unit table ({d['hp']})")
            except CellError as err:
                self.rep.error(where, str(err))
            life = row["lifetime"].strip()
            if re.fullmatch(r"\d+", life):
                d["lifetime_ticks"] = cells.ticks(life)

    # --- techs, spells, ages, power places -------------------------------------------

    def build_techs(self) -> None:
        for row in self.cat["common_techs"]:
            self._tech(row, "", "")
        for row in self.cat["techs"]:
            self._tech(row, row["faction"], row["faction"])
        for row in self.cat["faith_techs"]:
            fac = FACTION_BY_NAME.get(row["faction"])
            if fac is None:
                self.rep.error(f"tech {row['id']}", f"unknown faction {row['faction']!r}")
                continue
            place = self.manual["faith_tech_building"][fac]
            self._tech({**row, "building": "", "research_time": ""}, fac, fac, f"{fac}_{place}")

    def _tech(self, row: dict, fac: str, scope: str, building: str = "") -> None:
        tid = row["id"]
        where = f"tech {tid}"
        if tid in self.techs:
            self.rep.error(where, "duplicate id")
        d = _defaults("TechDef")
        d.update(id=tid, faction=fac, faith=bool(building))
        _required(row, ("id", "name", "age", "cost"), where, self.rep)
        try:
            d["age"] = cells.age(row["age"])
            _set_cost(d, cells.cost(row["cost"]))
            d["research_ticks"] = cells.seconds_or_none(row["research_time"]) or 0
        except CellError as err:
            self.rep.error(where, str(err))
        if not building:
            building = self.resolve_building_name(scope, _strip_name(row["building"])) or ""
            if not building:
                self.rep.error(where, f"researched at unknown building {row['building']!r}")
        d["building"] = building
        self.techs[tid] = d

    def _tech_effects(self) -> None:
        """Effects of techs (M5) from manual.json → tech_effects: the catalog gives them in prose."""
        block = self.manual.get("tech_effects", {})
        deferred = block.get("_deferred", {})
        for tid, effects in block.items():
            if tid.startswith("_"):
                continue
            if tid not in self.techs:
                self.rep.error("tech effects", f"unknown tech {tid!r}")
                continue
            for key, value in effects.items():
                target, _, stat = key.rpartition(".")
                ok = key in TECH_EFFECT_KEYS if not target else stat in TECH_STATS
                if not ok:
                    self.rep.error(f"tech {tid}", f"unknown effect {key!r}")
                elif not isinstance(value, int) or isinstance(value, bool):
                    self.rep.error(f"tech {tid}", f"effect {key} must be an integer")
            self.techs[tid]["effects"] = dict(effects)
        for tid in deferred:
            if tid not in self.techs:
                self.rep.error("tech effects", f"_deferred lists unknown tech {tid!r}")

    def build_spells(self) -> None:
        for row in self.cat["spells"]:
            sid = row["id"]
            where = f"spell {sid}"
            d = _defaults("SpellDef")
            fac = FACTION_BY_NAME.get(row["faction"], "")
            d.update(id=sid, faction=fac)
            _required(row, ("id", "name", "faction", "casters", "age", "radius", "duration"), where, self.rep)
            if not fac:
                self.rep.error(where, f"unknown faction {row['faction']!r}")
            try:
                self._spell_cells(d, row)
            except CellError as err:
                self.rep.error(where, str(err))
            for token in re.split(r", | или ", row["casters"]):
                ref = self._resolve_caster(fac, token.strip())
                if ref is None:
                    self.rep.error(where, f"unknown caster {token!r}")
                elif ref.startswith("@"):
                    d["tags"].append(ref[1:])
                else:
                    d["casters"].append(ref)
            self.spells[sid] = d

    def _spell_effects(self) -> None:
        """How spells are aimed and what they do (M7), from manual.json → spell_effects."""
        block = self.manual.get("spell_effects", {})
        for sid, tags in block.items():
            if sid.startswith("_"):
                continue
            if sid not in self.spells:
                self.rep.error("spell effects", f"unknown spell {sid!r}")
                continue
            for tag in tags:
                if tag not in SPELL_TARGETS and tag not in SPELL_EFFECTS:
                    self.rep.error(f"spell {sid}", f"unknown spell effect {tag!r}")
                elif tag not in self.spells[sid]["tags"]:
                    self.spells[sid]["tags"].append(tag)
        for sid in self.proto["spells"]:
            tags = self.spells.get(sid, {}).get("tags", [])
            aimed = any(t in tags for t in SPELL_TARGETS)
            if sid in self.spells and not (aimed and any(t in tags for t in SPELL_EFFECTS)):
                self.rep.error(f"prototype spell {sid}", "no target and effect in spell_effects")

    def _resolve_caster(self, fac: str, token: str) -> str | None:
        alias = self.manual["caster_aliases"].get(token)
        if alias:
            return alias
        if token.lower() == "герой у места силы":
            return "@hero_at_power_place"
        uid = self.unit_names.get((fac, token.lower()))
        if uid:
            return uid
        return self.building_names.get((fac, token.lower()))

    def _spell_cells(self, d: dict, row: dict) -> None:
        d["age"] = cells.age(row["age"])
        power = row["power"].strip()
        if cells.is_empty(power):
            d["tags"].append("passive")
        else:
            m = re.fullmatch(r"(\d+)(?:, \+(\d+) долга)?", power)
            if not m:
                raise CellError(f"unknown spell cost: {power!r}")
            d["power_cost"], d["debt_cost"] = int(m.group(1)), int(m.group(2) or 0)
        cooldown = row["cooldown"].strip()
        m = re.fullmatch(r"1 раз за миссию \(в схватке (\d+)\)", cooldown)
        if m:
            d["tags"].append("once_per_mission")
            d["cooldown_ticks"] = cells.ticks(m.group(1))
        elif not cells.is_empty(cooldown):
            d["cooldown_ticks"] = cells.ticks(cooldown)
        radius = row["radius"].strip()
        if m := re.fullmatch(r"тропа до (\d+) клеток", radius):
            d["params"]["path_length"] = int(m.group(1))
        elif radius == "1 отряд":
            d["tags"].append("single_target")
        elif m := re.fullmatch(r"(\d+) в любой точке", radius):
            d["radius"] = int(m.group(1))
            d["tags"].append("global_target")
        else:
            d["radius"] = cells.integer(radius)
        duration = row["duration"].strip()
        if duration == "сразу":
            d["tags"].append("instant")
        elif duration == "постоянно":
            d["tags"].append("permanent")
        else:
            d["duration_ticks"] = cells.ticks(duration)

    def build_ages(self) -> None:
        for row in self.cat["ages"]:
            where = f"age {row['name']}"
            try:
                index = cells.age(row["name"])
            except CellError as err:
                self.rep.error(where, str(err))
                continue
            d = _defaults("AgeDef")
            d.update(id=AGE_IDS[index], index=index)
            if row["cost"] != "старт":
                try:
                    _set_cost(d, cells.cost(row["cost"]))
                    d["research_ticks"] = cells.ticks(row["research_time"])
                except CellError as err:
                    self.rep.error(where, str(err))
            cond = row["condition"]
            if m := re.search(r"(\d+) постройки (\S+)", cond):
                d["params"]["required_buildings"] = int(m.group(1))
                d["params"]["required_buildings_age"] = AGE_GENITIVE[m.group(2)]
            if cond.startswith("Замок или"):
                d["params"]["castle_instead"] = 1
            self.ages[d["id"]] = d

    def build_power_places(self) -> None:
        for row in self.cat["power_places"]:
            d = _defaults("PowerPlaceDef")
            d["id"] = row["id"]
            try:
                d["power_permille"] = cells.permille(row["power"])
            except CellError as err:
                self.rep.error(f"power place {row['id']}", str(err))
            self.power_places[d["id"]] = d

    def build_terrain(self) -> None:
        """«Тайлы и рельеф»: movement multipliers for the nav grid (M3).

        Only the movement part of «Особое» is read here («Осадное не проходит»); the rest
        (wood, ore, fire, range) belongs to later systems.
        """
        for row in self.cat.get("terrain", []):
            where = f"terrain {row['id']}"
            d = _defaults("TerrainDef")
            d["id"] = row["id"]
            text = row["passability"].strip()
            try:
                if text == "непроходима":
                    pass
                elif text == "только лодки":
                    d["boats_only"] = True
                elif m := re.fullmatch(r"пехота (×[\d,]+), конница (×[\d,]+)", text):
                    d["passable"] = True
                    d["infantry_permille"] = cells.permille(m.group(1))
                    d["cavalry_permille"] = cells.permille(m.group(2))
                    d["uphill_permille"] = 1000
                elif m := re.fullmatch(r"(×[\d,]+)( вверх)?", text):
                    d["passable"] = True
                    mult = cells.permille(m.group(1))
                    climb = bool(m.group(2))
                    d["infantry_permille"] = d["cavalry_permille"] = 1000 if climb else mult
                    d["uphill_permille"] = mult if climb else 1000
                else:
                    self.rep.error(where, f"passability «{text}» not understood")
                    continue
            except CellError as err:
                self.rep.error(where, str(err))
                continue
            d["siege_blocked"] = "Осадное не проходит" in row["special"]
            self.terrains[d["id"]] = d

    def build_rules(self) -> None:
        """Combat and morale rules (M4): one CombatRulesDef with id "combat".

        The catalog states them in prose only, so they live in manual.json → combat_rules; each
        value is an integer in the units its key names (_ticks, _permille, _milli; cells or
        points otherwise). The keys must be exactly COMBAT_RULE_KEYS.
        """
        self.rules["combat"] = self._rule_block("combat", "CombatRulesDef", COMBAT_RULE_KEYS)
        self.economy["economy"] = self._rule_block("economy", "EconomyRulesDef", ECONOMY_RULE_KEYS)
        self.vision["vision"] = self._rule_block("vision", "VisionRulesDef", VISION_RULE_KEYS)
        self.magic["magic"] = self._rule_block("magic", "MagicRulesDef", MAGIC_RULE_KEYS)

    def _rule_block(self, name: str, kind: str, keys: tuple[str, ...]) -> dict:
        block = self.manual.get(f"{name}_rules", {})
        values = block.get("values", {})
        d = _defaults(kind)
        d["id"] = name
        for key in keys:
            if key not in values:
                self.rep.error(f"{name} rules", f"missing {key}")
        for key, value in values.items():
            if key not in keys:
                self.rep.error(f"{name} rules", f"unknown key {key!r}")
            elif not isinstance(value, int) or isinstance(value, bool):
                self.rep.error(f"{name} rules", f"{key} must be an integer, got {value!r}")
            else:
                d[key] = value
        for key in block.get("_temporary", []):
            if key not in keys:
                self.rep.error(f"{name} rules", f"_temporary lists unknown key {key!r}")
        return d

    # --- factions and checks ---------------------------------------------------------

    def build_factions(self) -> None:
        excluded = self.manual["excluded_techs"]
        for fac in FACTIONS:
            d = _defaults("FactionDef")
            d["id"] = fac
            d["unit_ids"] = sorted(u for u, x in self.units.items() if x["faction"] == fac)
            d["building_ids"] = sorted(b for b, x in self.buildings.items() if x["faction"] == fac)
            d["tech_ids"] = sorted(
                t
                for t, x in self.techs.items()
                if x["faction"] in ("", fac) and t not in excluded.get(fac, [])
            )
            d["spell_ids"] = sorted(s for s, x in self.spells.items() if x["faction"] == fac)
            d["tech_cost_permille"] = dict(self.manual["tech_cost_permille"].get(fac, {}))
            self.factions[fac] = d

    def check_references(self) -> None:
        """Every id a Def points to must exist; heroes are checked against the hero table."""
        heroes = {h["id"] for h in self.cat.get("heroes", [])}
        for tid, t in self.techs.items():
            known = self.common_ids if t["faction"] == "" else self.buildings
            if t["building"] and t["building"] not in known:
                self.rep.error(f"tech {tid}", f"researched at unknown building {t['building']!r}")
        for sid, sp in self.spells.items():
            for ref in sp["casters"]:
                if ref not in self.units and ref not in self.buildings and ref not in heroes:
                    self.rep.error(f"spell {sid}", f"caster {ref!r} is not a unit, building or hero")
        for bid, b in self.buildings.items():
            for uid in b["trains"]:
                if uid not in self.units:
                    self.rep.error(f"building {bid}", f"trains unknown unit {uid!r}")

    def check_prototype(self) -> None:
        """Prototype content must be complete: no pending rules, nothing above max age."""
        kinds = (("units", self.units), ("buildings", self.buildings), ("spells", self.spells))
        for key, table in kinds:
            for eid in self.proto[key]:
                if eid not in table:
                    self.rep.error(f"prototype {key}", f"unknown id {eid!r}")
                    continue
                if table[eid].get("age", 0) > self.proto["max_age"]:
                    self.rep.error(
                        f"prototype {eid}", f"age {table[eid]['age']} is above the prototype's ages"
                    )
        block = self.manual.get("tech_effects", {})
        for tid in self.prototype_techs():
            if tid not in block and tid not in block.get("_deferred", {}):
                self.rep.error(f"prototype tech {tid}", "no effects and not deferred in manual.json")
        for uid in self.proto["units"]:
            sp = self.unit_specials.get(uid)
            if sp and sp.unparsed:
                for clause in sp.unparsed:
                    self.rep.error(f"prototype unit {uid}", f"«Особое» clause not understood: «{clause}»")

    def prototype_techs(self) -> list[str]:
        facs = set(self.proto["factions"])
        out = []
        for tid, t in sorted(self.techs.items()):
            if t["age"] > self.proto["max_age"]:
                continue
            if any(tid in self.factions[f]["tech_ids"] for f in facs if t["faction"] in ("", f)):
                out.append(tid)
        return out

    def index(self) -> dict:
        d = _defaults("CatalogIndex")
        d.update(
            exported_on=self.cat["source"]["exported_on"],
            units=sorted(self.units),
            buildings=sorted(self.buildings),
            techs=sorted(self.techs),
            spells=sorted(self.spells),
            factions=list(FACTIONS),
            ages=sorted(self.ages),
            power_places=sorted(self.power_places),
            terrains=sorted(self.terrains),
            prototype_factions=list(self.proto["factions"]),
            prototype_units=sorted(self.proto["units"]),
            prototype_buildings=sorted(self.proto["buildings"]),
            prototype_techs=self.prototype_techs(),
            prototype_spells=sorted(self.proto["spells"]),
        )
        return d

    def build(self) -> dict[str, dict[str, dict]]:
        self.build_buildings()
        self.build_units()
        self.build_techs()
        self._tech_effects()
        self.build_spells()
        self._spell_effects()
        self.build_ages()
        self.build_power_places()
        self.build_terrain()
        self.build_rules()
        self.build_factions()
        self.check_references()
        self.check_prototype()
        for b in self.buildings.values():
            b["trains"] = sorted(b["trains"])
        return {
            "UnitDef": self.units,
            "BuildingDef": self.buildings,
            "TechDef": self.techs,
            "SpellDef": self.spells,
            "FactionDef": self.factions,
            "AgeDef": self.ages,
            "PowerPlaceDef": self.power_places,
            "TerrainDef": self.terrains,
            "CombatRulesDef": self.rules,
            "EconomyRulesDef": self.economy,
            "VisionRulesDef": self.vision,
            "MagicRulesDef": self.magic,
        }
