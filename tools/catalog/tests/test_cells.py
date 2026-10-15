"""Every cell format that occurs in the catalog, and a few that must be rejected."""

import unittest

from tools.catalog import cells
from tools.catalog.cells import CellError, Cost, Damage


class CostTest(unittest.TestCase):
    def test_four_resources(self):
        self.assertEqual(cells.cost("50/0/20/0"), Cost(food=50, iron=20))
        self.assertEqual(cells.cost("120/0/90/55"), Cost(food=120, iron=90, silver=55))

    def test_per_tile_and_forest(self):
        self.assertEqual(cells.cost("0/2/0/0 за клетку"), Cost(wood=2, per_tile=True))
        self.assertEqual(cells.cost("0/0/0/0, рубится из леса"), Cost(source="forest"))
        self.assertEqual(cells.cost("ставит обозный воз"), Cost(source="wagon"))

    def test_power_and_debt(self):
        self.assertEqual(cells.cost("вызов за 300 Силы"), Cost(power=300))
        self.assertEqual(cells.cost("300 Силы"), Cost(power=300))
        self.assertEqual(cells.cost("0/0/0/0 и 50 Силы"), Cost(power=50))
        self.assertEqual(cells.cost("вызов без Силы, цена в долге"), Cost(debt=1))
        self.assertEqual(cells.cost("0 Силы, цена в долге"), Cost(debt=1))

    def test_free_and_same_as(self):
        self.assertEqual(cells.cost("бесплатно"), Cost(free=True))
        self.assertEqual(cells.cost("как конюшня"), Cost(same_as="stable"))
        self.assertEqual(cells.cost("как рынок"), Cost(same_as="market"))

    def test_rejects_unknown(self):
        for bad in ("50/0/20", "50/0/20/0 и пиво", "дорого", "50 / 0 / 20 / 0"):
            with self.assertRaises(CellError, msg=bad):
                cells.cost(bad)


class DamageTest(unittest.TestCase):
    def test_types(self):
        self.assertEqual(cells.damage("6 Б"), Damage(6, "melee"))
        self.assertEqual(cells.damage("9 С"), Damage(9, "pierce"))
        self.assertEqual(cells.damage("16 О"), Damage(16, "firearm"))
        self.assertEqual(cells.damage("200 Ос"), Damage(200, "siege"))

    def test_pellets_and_none(self):
        self.assertEqual(cells.damage("8 О ×5"), Damage(8, "firearm", 5))
        self.assertIsNone(cells.damage("—"))

    def test_rejects_unknown(self):
        for bad in ("6", "6 X", "Б 6", "6Б"):
            with self.assertRaises(CellError, msg=bad):
                cells.damage(bad)


class ArmorRangeTest(unittest.TestCase):
    def test_armor(self):
        self.assertEqual(cells.armor("1/2"), (1, 2))
        self.assertEqual(cells.armor("8/12"), (8, 12))
        with self.assertRaises(CellError):
            cells.armor("1-2")
        with self.assertRaises(CellError):
            cells.armor("—")

    def test_range(self):
        self.assertEqual(cells.attack_range("0"), (0, 0))
        self.assertEqual(cells.attack_range("6"), (6, 0))
        self.assertEqual(cells.attack_range("12 (мин. 4)"), (12, 4))
        with self.assertRaises(CellError):
            cells.attack_range("12 (min 4)")


class NumbersTest(unittest.TestCase):
    def test_ticks(self):
        self.assertEqual(cells.ticks("2,0"), 40)
        self.assertEqual(cells.ticks("1,8"), 36)
        self.assertEqual(cells.ticks("4,5"), 90)
        self.assertEqual(cells.ticks("25"), 500)
        with self.assertRaises(CellError):
            cells.ticks("0,01")  # 0.2 ticks: not representable

    def test_speed_and_multipliers_are_exact(self):
        self.assertEqual(cells.milli("0,85"), 850)
        self.assertEqual(cells.milli("1,35"), 1350)
        self.assertEqual(cells.permille("×1,25"), 1250)
        self.assertEqual(cells.permille("2,5"), 2500)

    def test_decimal_comma_or_point_only(self):
        self.assertEqual(cells.decimal("2,0"), cells.decimal("2.0"))
        for bad in ("", "—", "2,0,0", "-1", "1e3"):
            with self.assertRaises(CellError, msg=bad):
                cells.decimal(bad)

    def test_age(self):
        self.assertEqual(cells.age("Удел"), 1)
        self.assertEqual(cells.age("Хоругвь"), 2)
        self.assertEqual(cells.age("Держава"), 3)
        self.assertEqual(cells.age("кампания"), 0)
        self.assertEqual(cells.age_with_exceptions("Удел (Корона: Хоругвь)"), (1, {"Корона": 2}))
        with self.assertRaises(CellError):
            cells.age("Империя")

    def test_morale(self):
        self.assertEqual(cells.morale("55"), 55)
        self.assertIsNone(cells.morale("—"))
        with self.assertRaises(CellError):
            cells.morale("120")


if __name__ == "__main__":
    unittest.main()
