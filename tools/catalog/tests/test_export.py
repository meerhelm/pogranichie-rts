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
        row(cat, "creatures", "mo_zyuzya")["hp"] = "500"
        self.assertIn("creature mo_zyuzya: HP 500 differs from the unit table (450)", errors_for(cat))

    def test_prototype_rules_must_be_understood(self):
        cat = copy.deepcopy(CATALOG)
        row(cat, "units", "gdl_lit_lance")["special"] = "Конница тяжёлая. Поёт песни"
        self.assertIn(
            "prototype unit gdl_lit_lance: «Особое» clause not understood: «Поёт песни»", errors_for(cat)
        )

    def test_prototype_stays_within_two_ages(self):
        proto = json.loads((HERE / "prototype.json").read_text(encoding="utf-8"))
        proto["units"].append("gdl_szlachta_lance")
        self.assertIn(
            "prototype gdl_szlachta_lance: age 3 is above the prototype's ages", errors_for(CATALOG, proto)
        )


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
