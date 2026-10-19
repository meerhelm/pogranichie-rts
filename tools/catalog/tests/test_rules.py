"""«Особое» column: classes, class bonuses and rule clauses."""

import unittest

from tools.catalog.rules import parse_special


class ClassesTest(unittest.TestCase):
    def test_classes_and_cavalry_group(self):
        sp = parse_special("Конница тяжёлая. Таран ×2 после разгона 4 клетки")
        self.assertEqual(sp.classes, ["heavy_cavalry", "cavalry"])
        self.assertEqual(sp.params, {"charge_permille": 2000, "charge_distance": 4})
        self.assertEqual(sp.unparsed, [])

    def test_two_classes_and_bonuses(self):
        sp = parse_special("Пехота, копейщик. +6 к коннице, +4 к существам")
        self.assertEqual(sp.classes, ["infantry", "spearman"])
        self.assertEqual(sp.bonuses, {"cavalry": 6, "creature": 4})

    def test_bonus_against_spearmen(self):
        sp = parse_special("Стрелок. +8 к тяжёлой коннице, +5 к копейщикам; доступен в Уделе")
        self.assertEqual(sp.bonuses, {"heavy_cavalry": 8, "spearman": 5})

    def test_bonus_against_buildings(self):
        sp = parse_special("Осадное, огнестрел. Урон по площади радиусом 1; +20 по постройкам")
        self.assertEqual(sp.classes, ["siege", "firearm"])
        self.assertEqual(sp.bonuses, {"building": 20})
        self.assertEqual(sp.params, {"splash_radius": 1})

    def test_class_only(self):
        sp = parse_special("Крестьянин")
        self.assertEqual(sp.classes, ["peasant"])
        self.assertEqual((sp.tags, sp.params, sp.unparsed), ([], {}, []))


class ClauseTest(unittest.TestCase):
    def test_light_horse(self):
        sp = parse_special(
            "Конница лёгкая. Сулица: бросок 6 С на 3 клетки раз в 12 с; «Литовский отход»; обзор 8"
        )
        self.assertEqual(sp.tags, ["javelin", "lithuanian_retreat"])
        self.assertEqual(
            sp.params,
            {"javelin_damage": 6, "javelin_range": 3, "javelin_cooldown_ticks": 240, "sight": 8},
        )

    def test_comma_list_of_rules(self):
        sp = parse_special("Осадное. Камнемёт, развёртывание 10 с, урон по площади радиусом 1")
        self.assertEqual(sp.params, {"deploy_ticks": 200, "splash_radius": 1})
        self.assertEqual(sp.unparsed, [])

    def test_same_as(self):
        self.assertEqual(parse_special("Как у ВКЛ", "to_field_gun").same_as, "gdl_field_gun")
        sp = parse_special("Конный стрелок. Та же модель, что у ВКЛ; не больше 12", "mo_tatar")
        self.assertEqual((sp.same_as, sp.params), ("gdl_tatar", {"limit": 12}))

    def test_watch_with_dogs(self):
        sp = parse_special("Конница лёгкая. Обзор 10; с собаками видит скрытых в радиусе 4")
        self.assertEqual((sp.tags, sp.params, sp.unparsed), (["dogs"], {"sight": 10, "dogs_radius": 4}, []))

    def test_siege_of_slutsk(self):
        sp = parse_special("Пехота. Тушит пожары, носит воду; в осаде берёт оружие и бьёт на 5 Б")
        self.assertEqual((sp.tags, sp.params, sp.unparsed), (["douses"], {"militia_damage": 5}, []))
        sp = parse_special(
            "Огнестрел. Стреляет только с крюка на стене или в укреплении (установка 5 с); попадание −10 духа цели"
        )
        self.assertIn("wall_mounted", sp.tags)
        self.assertEqual(sp.params["mount_ticks"], 100)
        self.assertEqual(sp.unparsed, [])
        sp = parse_special("Осадное, огнестрел. +30 по воротам и деревянным постройкам, по каменным стенам вдвое слабее")
        self.assertEqual(sp.params, {"wood_bonus": 30, "stone_permille": 500})
        self.assertEqual(sp.unparsed, [])

    def test_orsha_crown_troops(self):
        sp = parse_special(
            "Конница лёгкая. Копьё и сабля, таран ×1,5 после 4 клеток; "
            "это лёгкая сербская конница около 1500 года, не крылатая гусария"
        )
        self.assertEqual(sp.unparsed, [])
        self.assertIn("charge", sp.tags)
        sp = parse_special("Пехота, копейщик. +8 к коннице; роет ров у табора; жалованье 1 С в минуту")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.bonuses, {"cavalry": 8})

    def test_crown_skirmish_troops(self):
        sp = parse_special(
            "Пехота. Рядом с копьём +10 духа; в сомкнутом строю соседи теряют вдвое меньше духа"
        )
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.tags, ["lance_escort", "steadies_neighbours"])
        self.assertEqual(sp.params, {"escort_morale": 10})
        sp = parse_special("Пехота. Ставит павезу за 3 с: стрелки за ним +3 к С-броне")
        self.assertEqual(sp.params, {"pavise_ticks": 60, "pavise_armor": 3})
        sp = parse_special(
            "Осадное, огнестрел. Стреляет только из батареи (развёртывание 20 с), "
            "5 железа пороха за выстрел"
        )
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.tags, ["battery_only"])
        self.assertEqual(sp.params, {"deploy_ticks": 400, "shot_iron": 5})

    def test_malbork_shipmen(self):
        sp = parse_special("Пехота. Ночью виден только с 4 клеток; заклёпывает бомбарду за 8 с")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.tags, ["spiker"])
        self.assertEqual(sp.params, {"night_reveal_cells": 4, "spike_ticks": 160})

    def test_baltic_orphans(self):
        sp = parse_special("Пехота. Сулица 6 С на 3 клетки; у возов +4 к коннице")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.tags, ["javelin"])
        self.assertEqual(
            sp.params,
            {"javelin_damage": 6, "javelin_range": 3, "javelin_cooldown_ticks": 240, "wagon_cavalry_bonus": 4},
        )
        sp = parse_special("Осадное. Стрелки на возу; табор собирается за 3 с, внутри +4/+4")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(
            sp.params, {"tabor_wagons": 4, "tabor_ticks": 60, "tabor_armor_melee": 4, "tabor_armor_pierce": 4}
        )
        sp = parse_special("Стрелок. Как pl_crossbow, городской скин")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.same_as, "pl_crossbow")

    def test_chojnice_hirelings(self):
        sp = parse_special("Конница тяжёлая. Жалованье 2 С в минуту; за разграбленный воз +50 С")
        self.assertEqual(sp.unparsed, [])
        self.assertEqual(sp.params, {"upkeep_silver_per_min": 2, "plunder_wagon_silver": 50})

    def test_unknown_clause_is_reported_not_dropped(self):
        sp = parse_special("Пехота. Поёт песни; +6 к коннице")
        self.assertEqual(sp.unparsed, ["Поёт песни"])
        self.assertEqual(sp.bonuses, {"cavalry": 6})

    def test_partly_known_comma_list_stays_unparsed(self):
        sp = parse_special("Осадное. Камнемёт, летает")
        self.assertEqual(sp.unparsed, ["Камнемёт, летает"])


if __name__ == "__main__":
    unittest.main()
