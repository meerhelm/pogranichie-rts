"""Exporter: reproducible output, --check, validator errors."""

import copy
import json
import re
import tempfile
import unittest
from pathlib import Path

from tools.catalog import export
from tools.catalog.model import SCHEMAS
from tools.catalog.tres import script_path

HERE = Path(export.__file__).resolve().parent
ROOT = HERE.parents[1]
CATALOG = json.loads((HERE / "catalog.json").read_text(encoding="utf-8"))


def errors_for(catalog, prototype=None):
    _defs, _index, rep = export.build(catalog, prototype=prototype)
    return rep.errors


def row(catalog, section, rid):
    return next(r for r in catalog[section] if r["id"] == rid)


class ReproducibleTest(unittest.TestCase):
    def test_catalog_exports_without_errors(self):
        self.assertEqual(errors_for(CATALOG), [])

    def test_two_exports_write_identical_files(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            for root in (a, b):
                defs, index, rep = export.build(copy.deepcopy(CATALOG))
                export.write(export.render_files(defs, index, rep), Path(root))
            files_a = sorted(p.relative_to(a) for p in Path(a).rglob("*") if p.is_file())
            files_b = sorted(p.relative_to(b) for p in Path(b).rglob("*") if p.is_file())
            self.assertEqual(files_a, files_b)
            self.assertGreater(len(files_a), 250)
            for rel in files_a:
                self.assertEqual((Path(a) / rel).read_bytes(), (Path(b) / rel).read_bytes(), str(rel))

    def test_committed_data_matches_catalog(self):
        defs, index, rep = export.build(CATALOG)
        self.assertEqual(export.check(export.render_files(defs, index, rep), ROOT), [])

    def test_check_finds_edited_and_stale_files(self):
        defs, index, rep = export.build(CATALOG)
        files = export.render_files(defs, index, rep)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            export.write(files, root)
            self.assertEqual(export.check(files, root), [])
            unit = root / "data/units/gdl_peasant.tres"
            unit.write_text(unit.read_text(encoding="utf-8").replace("hp = 25", "hp = 26"), encoding="utf-8")
            (root / "data/units/gdl_ghost.tres").write_text("", encoding="utf-8")
            problems = export.check(files, root)
            self.assertIn("differs from catalog: data/units/gdl_peasant.tres", problems)
            self.assertIn("stale file: data/units/gdl_ghost.tres", problems)


class ValidatorTest(unittest.TestCase):
    def test_unknown_training_building(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "units", "gdl_spearman")["building"] = "pikemen_hall"
        self.assertIn("unit gdl_spearman: trained at unknown building 'pikemen_hall'", errors_for(cat))

    def test_unknown_tech_building(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "techs", "t_gdl_steppe")["building"] = "Ипподром"
        self.assertIn("tech t_gdl_steppe: researched at unknown building 'Ипподром'", errors_for(cat))

    def test_empty_required_cell(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "units", "to_knecht")["hp"] = ""
        row(cat, "common_buildings", "house")["cost"] = ""
        errs = errors_for(cat)
        self.assertIn("unit to_knecht: required cell «hp» is empty", errs)
        self.assertIn("building gdl_house: required cell «cost» is empty", errs)

    def test_bad_cell(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "units", "to_crossbow")["damage"] = "9 стрел"
        self.assertIn("unit to_crossbow: unknown damage format: '9 стрел'", errors_for(cat))

    def test_unknown_caster(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "spells", "sp_bog_mist")["casters"] = "Ведьма"
        self.assertIn("spell sp_bog_mist: unknown caster 'Ведьма'", errors_for(cat))

    def test_creature_hp_must_agree_between_tabs(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "creatures", "mo_moroz")["hp"] = "500"
        self.assertIn("creature mo_moroz: HP 500 differs from the unit table (450)", errors_for(cat))

    def test_prototype_rules_must_be_understood(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "units", "gdl_lit_lance")["special"] = "Конница тяжёлая. Поёт песни"
        self.assertIn(
            "prototype unit gdl_lit_lance: «Особое» clause not understood: «Поёт песни»", errors_for(cat)
        )

    def test_prototype_stays_within_two_ages(self):
        proto = json.loads((HERE / "prototype.json").read_text(encoding="utf-8"))
        proto["units"].append("gdl_merc_infantry")
        self.assertIn(
            "prototype gdl_merc_infantry: age 3 is above the prototype's ages", errors_for(CATALOG, proto)
        )

    def test_mission_only_units_may_be_of_a_later_age(self):
        proto = json.loads((HERE / "prototype.json").read_text(encoding="utf-8"))
        self.assertIn("gdl_szlachta_lance", proto["mission_only"])
        self.assertEqual([], [e for e in errors_for(CATALOG, proto) if "above" in e])


class SchemaTest(unittest.TestCase):
    GD_TYPES = {
        "int": "int",
        "bool": "bool",
        "name": "StringName",
        "names": "Array[StringName]",
        "name_ints": "Dictionary[StringName, int]",
        "text": "String",
    }

    def test_gdscript_defs_match_exporter_schema(self):
        for kind, schema in SCHEMAS.items():
            path = ROOT / script_path(kind).removeprefix("res://")
            text = path.read_text(encoding="utf-8")
            self.assertIn(f"class_name {kind}\n", text)
            exported = re.findall(r"^@export var (\w+): (.+)$", text, re.MULTILINE)
            expected = [(name, self.GD_TYPES[t]) for name, t in schema.items()]
            self.assertEqual(exported, expected, kind)


if __name__ == "__main__":
    unittest.main()


class TerrainTest(unittest.TestCase):
    def terrain(self, catalog=None):
        defs, _index, rep = export.build(catalog or copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        return defs["TerrainDef"]

    def test_movement_multipliers(self):
        t = self.terrain()
        self.assertEqual((t["t_forest"]["infantry_permille"], t["t_forest"]["cavalry_permille"]), (700, 500))
        self.assertEqual(t["t_bog"]["infantry_permille"], 500)
        self.assertEqual(t["t_ford"]["cavalry_permille"], 400)
        self.assertTrue(t["t_ford"]["siege_blocked"])
        self.assertEqual(t["t_road"]["infantry_permille"], 1200)
        self.assertEqual((t["t_hill"]["infantry_permille"], t["t_hill"]["uphill_permille"]), (1000, 900))
        self.assertEqual(t["t_grass"]["uphill_permille"], 1000)

    def test_impassable_tiles(self):
        t = self.terrain()
        for tid in ("t_old_forest", "t_quagmire", "t_water"):
            self.assertFalse(t[tid]["passable"], tid)
            self.assertEqual(t[tid]["infantry_permille"], 0, tid)
        self.assertTrue(t["t_water"]["boats_only"])

    def test_unknown_passability_is_an_error(self):
        catalog = copy.deepcopy(CATALOG)
        row(catalog, "terrain", "t_sand")["passability"] = "медленно"
        self.assertIn("passability «медленно» not understood", " ".join(errors_for(catalog)))


class CombatRulesTest(unittest.TestCase):
    MANUAL = json.loads((HERE / "manual.json").read_text(encoding="utf-8"))

    def rules_errors(self, edit):
        manual = copy.deepcopy(self.MANUAL)
        edit(manual["combat_rules"])
        _defs, _index, rep = export.build(copy.deepcopy(CATALOG), manual=manual)
        return " ".join(rep.errors)

    def test_rules_from_the_catalog_prose(self):
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        r = defs["CombatRulesDef"]["combat"]
        self.assertEqual((r["flank_permille"], r["rear_permille"]), (1250, 1500))
        self.assertEqual((r["waver_morale"], r["waver_damage_permille"]), (25, 800))
        self.assertEqual(r["flee_ticks"], 400, "20 seconds")
        self.assertEqual(r["retreat_cooldown_ticks"], 900, "45 seconds")

    def test_missing_unknown_and_non_integer_values_are_errors(self):
        self.assertIn("missing flank_permille", self.rules_errors(lambda b: b["values"].pop("flank_permille")))
        self.assertIn("unknown key 'flanc'", self.rules_errors(lambda b: b["values"].update(flanc=1)))
        self.assertIn("must be an integer", self.rules_errors(lambda b: b["values"].update(rear_permille=1.5)))
        self.assertIn("_temporary lists unknown key", self.rules_errors(lambda b: b["_temporary"].append("x")))


class EconomyExportTest(unittest.TestCase):
    """M5: economy rules, building footprints and tags, tech effects."""

    MANUAL = json.loads((HERE / "manual.json").read_text(encoding="utf-8"))

    def build_with(self, edit):
        manual = copy.deepcopy(self.MANUAL)
        edit(manual)
        return export.build(copy.deepcopy(CATALOG), manual=manual)

    def test_economy_rules_match_the_catalog_prose(self):
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        r = defs["EconomyRulesDef"]["economy"]
        self.assertEqual((r["carry"], r["pop_cap"]), (10, 200))
        self.assertEqual(r["gather_wood_milli"], 390, "0,39 wood a second")
        self.assertEqual(r["gather_bort_milli"], 250)
        self.assertEqual((r["tree_wood"], r["bog_ore_iron"], r["silver_mine_silver"]), (100, 800, 800))

    def test_buildings_get_sizes_tags_and_the_stable_discount(self):
        defs, _index, _rep = export.build(copy.deepcopy(CATALOG))
        b = defs["BuildingDef"]
        self.assertEqual((b["gdl_town_center"]["params"]["size_w"], b["gdl_town_center"]["params"]["size_h"]), (4, 4))
        self.assertEqual((b["gdl_zaseka"]["params"]["size_w"], b["gdl_zaseka"]["params"]["size_h"]), (3, 1))
        self.assertIn("in_forest", b["gdl_zaseka"]["tags"])
        self.assertIn("walkable", b["gdl_farm"]["tags"])
        self.assertIn("brickworks", b["to_brickworks"]["tags"])
        self.assertEqual(b["to_stable"]["params"]["cavalry_discount_permille"], 150)

    def test_a_building_without_a_size_is_an_error(self):
        _defs, _index, rep = self.build_with(lambda m: m["building_layout"]["sizes"].pop("house"))
        self.assertTrue(any("no size" in e for e in rep.errors))

    def test_tech_effects_are_checked(self):
        defs, _index, _rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(defs["TechDef"]["t_saw"]["effects"], {"gather_wood": 200})
        bad = self.build_with(lambda m: m["tech_effects"].update(t_saw={"gather_woood": 1}))[2]
        self.assertTrue(any("unknown effect 'gather_woood'" in e for e in bad.errors))
        bad = self.build_with(lambda m: m["tech_effects"].update(t_saw={"infantry.speedd": 1}))[2]
        self.assertTrue(any("unknown effect" in e for e in bad.errors))
        bad = self.build_with(lambda m: m["tech_effects"].update(t_nope={"gather_wood": 1}))[2]
        self.assertTrue(any("unknown tech 't_nope'" in e for e in bad.errors))


class VisionExportTest(unittest.TestCase):
    """M6: fog of war rules, building sight, t_watch."""

    def test_vision_rules_and_building_sight(self):
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        r = defs["VisionRulesDef"]["vision"]
        self.assertEqual(r["hill_sight_bonus"], 2, "t_hill «+2 обзора»")
        self.assertEqual(r["cover_reveal_cells"], 2)
        b = defs["BuildingDef"]
        self.assertEqual(b["gdl_town_center"]["params"]["sight"], 8)
        self.assertEqual(b["mo_watchtower"]["params"]["sight"], 12, "«Обзор 12»")
        self.assertEqual(b["gdl_barracks"]["params"]["sight"], 4, "the default")
        self.assertIn("watch", b["to_tower"]["tags"])
        self.assertIn("watch", b["gdl_palisade"]["tags"])
        self.assertEqual(defs["TechDef"]["t_watch"]["effects"], {"wall_sight": 2})


class SkirmishExportTest(unittest.TestCase):
    """M8: how a skirmish is won."""

    def test_skirmish_rules(self):
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        r = defs["SkirmishRulesDef"]["skirmish"]
        self.assertEqual(r["hold_all_places_ticks"], 5 * 60 * 20, "«в течение 5 минут»")


class MagicExportTest(unittest.TestCase):
    """M7: magic rules, how prototype spells are aimed, healer and reliquary techs."""

    MANUAL = EconomyExportTest.MANUAL

    def build_with(self, edit):
        manual = copy.deepcopy(self.MANUAL)
        edit(manual)
        return export.build(copy.deepcopy(CATALOG), manual=manual)

    def test_magic_rules_and_spell_tags(self):
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        r = defs["MagicRulesDef"]["magic"]
        self.assertEqual(r["capture_ticks"], 300, "15 seconds")
        self.assertEqual(r["power_cap"], 500)
        self.assertEqual(r["consecration_permille"], 500, "«вдвое меньше»")
        s = defs["SpellDef"]
        self.assertIn("mist", s["sp_bog_mist"]["tags"])
        self.assertIn("target_point", s["sp_exorcism"]["tags"])
        self.assertIn("target_self", s["sp_relic"]["tags"])
        self.assertIn("passive", s["sp_consecration"]["tags"])
        self.assertIn("spell_recharge", defs["BuildingDef"]["gdl_shrine"]["tags"])
        self.assertEqual(defs["TechDef"]["t_gdl_herbs"]["effects"], {"gdl_znakharka.heal": 1})
        self.assertEqual(defs["TechDef"]["t_to_reliquary"]["effects"]["sp_exorcism.radius"], 2)

    def test_wolf_trail_dogs_and_the_fugitive_hetman(self):
        """ВКЛ 6: «Волчья тропа» by a hero at a place of power, dogs that find the hidden, and
        Ostrogski as a lone fugitive of the light template (250 HP, no aura)."""
        defs, _index, rep = export.build(copy.deepcopy(CATALOG))
        self.assertEqual(rep.errors, [])
        s = defs["SpellDef"]["sp_wolf_path"]
        for tag in ("hero_at_power_place", "target_self", "wolf_path"):
            self.assertIn(tag, s["tags"])
        u = defs["UnitDef"]
        self.assertEqual(u["mo_storozha"]["params"], {"sight": 10, "dogs_radius": 4})
        self.assertEqual(u["hero_nezhdan"]["params"]["dogs_radius"], 6)
        f = u["hero_ostrogski_fugitive"]
        self.assertEqual((f["hp"], f["speed_milli"], f["faction"]), (250, 1600, "gdl"))
        self.assertIn("forest_stealth", f["tags"])
        self.assertFalse(any(k.startswith("aura_") for k in f["params"]))
        self.assertEqual(u["hero_ostrogski"]["hp"], 400, "the hetman of ВКЛ 5 and 8 stays as he was")

    def test_prototype_spell_without_effect_and_unknown_effect_are_errors(self):
        rep = self.build_with(lambda m: m["spell_effects"].pop("sp_relic"))[2]
        self.assertTrue(any("sp_relic" in e and "no target" in e for e in rep.errors))
        rep = self.build_with(lambda m: m["spell_effects"].update(sp_relic=["target_self", "fog"]))[2]
        self.assertTrue(any("unknown spell effect 'fog'" in e for e in rep.errors))
