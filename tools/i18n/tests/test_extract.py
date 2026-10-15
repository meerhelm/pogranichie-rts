"""The translation check: text outside tr() is caught, keys and .po files stay in step."""

import tempfile
import unittest
from pathlib import Path

from tools.i18n import extract


class ScanTest(unittest.TestCase):
    def scan(self, code: str) -> extract.Report:
        rep = extract.Report()
        with tempfile.TemporaryDirectory(dir=extract.ROOT) as d:
            path = Path(d) / "x.gd"
            path.write_text(code, encoding="utf-8")
            extract.scan_gd(path, rep)
        return rep

    def test_text_in_tr_is_a_key(self):
        rep = self.scan('label.text = tr("Population %d/%d") % [a, b]\nx = UiText.t("Food")\n')
        self.assertEqual(sorted(rep.keys), ["Food", "Population %d/%d"])
        self.assertEqual(rep.errors, [])

    def test_text_on_the_line_after_tr_is_a_key(self):
        rep = self.scan('x = tr(\n\t"A long line of text"\n)\n')
        self.assertEqual(list(rep.keys), ["A long line of text"])

    def test_hard_coded_text_is_an_error(self):
        rep = self.scan('button.text = "Start game"\nlabel.text = "Resume"\n')
        self.assertEqual(len(rep.errors), 2)
        self.assertIn("Start game", rep.errors[0])

    def test_identifiers_paths_formats_and_dev_messages_pass(self):
        code = "\n".join(
            [
                'cfg.get_value("general", "edge_scroll")',
                'load("res://ui/main_menu.tscn")',
                'v.name = "Unit%d" % id',
                'label.text = "%s %d" % [a, b]',
                'push_warning("cannot save the file")',
                'x = &"gdl_peasant"',
                'var n := "English"  # notr',
                '# label.text = "In a comment"',
            ]
        )
        rep = self.scan(code)
        self.assertEqual(rep.errors, [])


class PoTest(unittest.TestCase):
    def test_check_finds_missing_stale_and_placeholders(self):
        rep = extract.Report()
        rep.key("HP %d/%d", "a")
        rep.key("gdl_peasant", "b")
        errors = extract.check_po("en", rep, {"HP %d/%d": "HP %d", "old": "x"})
        text = "\n".join(errors)
        self.assertIn("missing 1", text)
        self.assertIn("no longer used", text)
        self.assertIn("placeholders", text)
        self.assertEqual(extract.check_po("be", rep, {"HP %d/%d": "", "gdl_peasant": ""}), [])

    def test_po_round_trip_keeps_translations(self):
        rep = extract.Report()
        rep.key("Quit", "a")
        rep.key("gdl_peasant", "b")
        text = extract.render_po("pl", rep, {"Quit": "Wyjdź"})
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pl.po"
            path.write_text(text, encoding="utf-8")
            self.assertEqual(extract.read_po(path), {"Quit": "Wyjdź", "gdl_peasant": ""})
        en = extract.render_po("en", rep, {})
        self.assertIn('msgid "Quit"\nmsgstr "Quit"', en, "English text is its own translation")
        self.assertIn('msgid "gdl_peasant"\nmsgstr ""', en, "names are written by hand")

    def test_the_project_passes(self):
        rep = extract.collect()
        self.assertEqual(rep.errors, [])
        for locale in extract.LOCALES:
            entries = extract.read_po(extract.I18N / f"{locale}.po")
            self.assertEqual(extract.check_po(locale, rep, entries), [], locale)


if __name__ == "__main__":
    unittest.main()
