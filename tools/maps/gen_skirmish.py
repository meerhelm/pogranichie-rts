"""The skirmish maps drawn after battlefields of 1410–1514 (2026-10-19).

    python3 -m tools.maps.gen_skirmish            # writes maps/map_sk_*/terrain.txt and maps/skirmish.json
    python3 -m tools.maps.gen_skirmish --check    # fails if the files differ from what it would write

Each map takes the shape of a real field: its rivers, lakes, bogs, woods, hills and roads as the
sources describe them (see SOURCES in each map and docs/04-catalog/08-locations.md). A skirmish
must be fair for both sides (netplay will use these maps too), so every map is point-symmetric
about its centre (tools/maps/skirmish_canvas.py): the field one army held is drawn on both sides,
and both sides start with the same kit of wood, bog ore, silver, salt and places of power. Where
history left one river or one lake, the map has it once in the middle or twice, mirrored; the
notes in each map's header say what is the battle's and what was added for play.

maps/skirmish.json lists the prototype's «Жемайтское порубежье» first (its terrain stays as drawn by
hand) and then these maps, with the English title and history note the menu shows (translated in
i18n/*.po) and the town-centre cells of both sides (SkirmishMaps, SkirmishSetup).
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

from tools.maps.skirmish_canvas import TC, Canvas

ROOT = Path(__file__).resolve().parents[2]
SIZE = 120

# Town-centre top-left cells: a start in the north-west corner or on the west edge; the other
# side's is its mirror image.
NW = (10, 10)
W = (8, 58)


def other(base: tuple[int, int]) -> tuple[int, int]:
    return SIZE - TC - base[0], SIZE - TC - base[1]


# --- what every side gets -------------------------------------------------------------------


def kit(c: Canvas, start: tuple[int, int], place: str, woods: bool = True) -> None:
    """A side's start: open ground, wood close by, three bog-ore deposits, two silver mines,
    a salt spring and a place of power of its own (and the same for the mirrored side)."""
    x, y = start
    if start == NW:
        if woods:
            c.blob(3, 28, 6, "f", keep="~")
            c.blob(28, 3, 6, "f", keep="~")
        c.base(x, y)
        c.ore(25, 9, "y", side=1)
        c.silver(12, 26)
        c.salt(24, 22)
        c.place(place, 19, 16)
    else:
        if woods:
            c.blob(4, 42, 6.5, "f", keep="~")
            c.blob(4, 77, 6.5, "f", keep="~")
        c.base(x, y)
        c.ore(17, 47, "x", side=-1)
        c.silver(18, 73)
        c.salt(25, 66)
        c.place(place, 22, 53)


def scatter_woods(c: Canvas, rng: random.Random, n: int, r: tuple[int, int], area,
                  ch: str = "f", keep: str = "~#=") -> None:
    """n patches of wood of radius r[0]..r[1] at random points of `area` (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = area
    for _ in range(n):
        c.blob(rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(*r), ch, keep=keep)


# --- the maps -------------------------------------------------------------------------------
# Each returns the canvas. Coordinates are for the first side; the canvas mirrors every stroke.


def grunwald() -> Canvas:
    """Open upland among woods, lakes and bogs; the valley of the Wielki Strumień between the
    armies; lake Łubień with bog to its north on the flank; villages Grunwald, Stębark,
    Łodwigowo."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1410)
    # A ring of woods round the open field.
    for _ in range(26):
        t = rng.uniform(0, 1)
        edge = rng.choice(("n", "w"))
        x, y = (t * SIZE, rng.uniform(0, 9)) if edge == "n" else (rng.uniform(0, 9), t * SIZE)
        c.blob(x, y, rng.uniform(4, 8), "f")
    # Lake Łubień with the bogs north of it, on each side's flank.
    c.blob(40, 12, 7, "b", sx=1.5)
    c.blob(42, 11, 4.5, "~", sx=1.6)
    c.blob(37, 14, 2, "B")
    # The valley of the Wielki Strumień across the field, with wet hollows.
    stream = [(108, 10), (88, 28), (72, 46), (59.5, 59.5)]
    c.line(stream, "b", 5)
    c.line(stream, "=", 2)
    for x, y in ((92, 22), (79, 40)):
        c.blob(x, y, 2.5, "B")
    # Villages with their fields.
    c.blob(44, 30, 4, ",")
    c.blob(64, 22, 3.5, ",")
    c.blob(30, 44, 3.5, ",")
    # Roads: from the start to Grunwald, on to the centre; Grunwald–Stębark.
    c.line([(16, 16), (30, 30), (44, 30), (59, 59)], "#", keep="~B")
    c.line([(44, 30), (64, 22), (100, 30)], "#", keep="~B")
    kit(c, NW, "pp_spring")
    # Contested: the hill with the oak in the middle, kurgans by the valley, silver and salt.
    c.blob(59.5, 59.5, 4, "h")
    c.place("pp_oak_grove", 59, 59)
    c.place("pp_kurgan", 48, 70)
    c.silver(70, 50)
    c.salt(52, 40)
    return c


def koronowo() -> Canvas:
    """A hill fought round from its steeper side, the lake by the kurgan at Łąsko, the village
    Łączko where the Order re-formed; woods of the Tuchola forest on the edges (inferred)."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1010)
    scatter_woods(c, rng, 14, (5, 9), (0, 0, 119, 14))
    scatter_woods(c, rng, 6, (4, 7), (20, 20, 50, 40))
    # The long hill in the middle, its steep side a scarp of old wood.
    c.blob(59.5, 59.5, 13, "h", sx=1.0, sy=1.8)
    c.line([(50, 48), (50, 60)], "F", 2)
    # Lakes by the kurgan.
    c.blob(38, 30, 7, "s", sx=1.4)
    c.blob(38, 30, 5, "~", sx=1.4)
    c.place("pp_kurgan", 46, 39)
    # Villages and fields (Łączko).
    c.blob(30, 80, 5, ",")
    c.blob(42, 96, 4, ",")
    c.line([(0, 52), (20, 60), (40, 60), (59, 59)], "#", keep="~")
    c.line([(40, 60), (30, 80), (42, 96), (50, 119)], "#", keep="~")
    kit(c, W, "pp_wayside")
    c.place("pp_hillfort", 59, 59)
    c.silver(62, 46)
    c.salt(48, 76)
    return c


def dabki() -> Canvas:
    """The flood plain of the Orla (Wyrza) with its bogs and meadows between the armies; the
    plateau's edge some 40 m above it on each side; wood and a ravine to the north."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1431)
    # The plateau's edge.
    c.line([(96, 0), (0, 96)], "h", 4)
    # The flood plain: wet meadows, bogs, alder woods.
    for _ in range(18):
        t = rng.uniform(0.05, 0.5)
        x, y = 119 * (1 - t), 119 * t
        off = rng.uniform(-14, 14)
        c.blob(x + off * 0.7, y + off * 0.7, rng.uniform(2.5, 5), rng.choice("bbf"))
    # The Orla in the middle of it, crossed at fords and one causeway.
    c.river([(119, 0), (90, 30), (70, 48), (59.5, 59.5)], water=2, bank="b", bank_w=2)
    c.crossing(97, 22, "=", "x", 4)
    c.crossing(80, 39, "=", "x", 4)
    c.line([(52, 52), (67, 67)], "#", 2, keep="")
    # Woods and ravines on the plateau.
    scatter_woods(c, rng, 10, (4, 7), (0, 30, 30, 70))
    scatter_woods(c, rng, 8, (4, 7), (30, 0, 70, 25))
    c.line([(60, 20), (66, 30)], "F", 2)
    kit(c, NW, "pp_old_tree")
    c.place("pp_bog_island", 59, 59)
    c.silver(42, 56)
    c.salt(56, 42)
    c.place("pp_spring", 36, 84)
    return c


def wilkomierz() -> Canvas:
    """Lake Žirnajai and the marshy Žirnaja stream between the two camps; the Šventoji in the
    corners; the road north to Ukmergė along which Švitrigaila's army was cut in two."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1435)
    # The lake in the middle, long north to south, with reeds; the stream on to the edges.
    c.blob(59.5, 59.5, 9, "b", sx=0.8, sy=2.4)
    c.blob(59.5, 59.5, 7, "~", sx=0.7, sy=2.4)
    c.river([(59.5, 77), (62, 96), (58, 119)], water=2, bank="b", bank_w=2)
    c.crossing(60, 88, "=", "x", 4)
    c.crossing(60, 104, "=", "x", 4)
    # The Šventoji crossing two corners, a ford in each.
    c.river([(80, 119), (98, 104), (119, 98)], water=4)
    c.crossing(97, 102, "=", "y", 6, width=3)
    # Woods, stubble fields.
    scatter_woods(c, rng, 10, (4, 7), (0, 0, 50, 22))
    scatter_woods(c, rng, 6, (4, 6), (25, 30, 48, 50))
    c.blob(30, 92, 5, ",")
    c.blob(40, 30, 4, ",")
    # The road along the west shore north to Ukmergė.
    c.line([(12, 60), (38, 60), (46, 40), (52, 12), (56, 0)], "#", keep="~")
    kit(c, W, "pp_oak_grove")
    c.place("pp_kurgan", 59, 14)
    c.silver(44, 80)
    c.salt(40, 46)
    return c


def chojnice() -> Canvas:
    """The lake by the town with the causeway the Polish knights charged along; the Polish hill
    on its east shore over the roads to Tuchola and Krojanty; bogs on the shores; woods round."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1454)
    scatter_woods(c, rng, 16, (5, 9), (0, 0, 119, 18))
    # The lake with marshy shores and the causeway across it.
    c.blob(59.5, 59.5, 13, "b", sx=0.8, sy=1.6)
    c.blob(59.5, 59.5, 10, "~", sx=0.75, sy=1.6)
    c.blob(52, 44, 3, "B")
    c.line([(44, 59.5), (75, 59.5)], "#", 2)
    # The hill each side holds over the causeway.
    c.blob(32, 58, 7, "h", sy=1.5)
    # Roads round the lake's ends (the Order's march round the west shore).
    c.line([(12, 60), (30, 60), (40, 40), (59, 28), (80, 32), (108, 60)], "#", keep="~")
    c.line([(0, 30), (28, 40)], "#", keep="~")
    scatter_woods(c, rng, 6, (4, 6), (14, 76, 44, 100))
    c.blob(40, 100, 4, ",")
    kit(c, W, "pp_wayside")
    c.place("pp_spring", 59, 22)
    c.silver(26, 98)
    c.salt(46, 30)
    return c


def swiecino() -> Canvas:
    """A clearing in thick beech woods by the muddy lake Rogoźnica, reeds and bog at its shore,
    the hillock the Polish tabor stood on at its north-west shore; ravines and forest tracks."""
    c = Canvas(SIZE, SIZE, fill="f")
    rng = random.Random(1462)
    # Clearings: the field in the middle and the glades of each camp, joined by tracks.
    c.blob(59.5, 59.5, 22, ".", wobble=0.15)
    c.blob(22, 22, 17, ".", wobble=0.15)
    c.blob(60, 18, 9, ".")
    c.blob(18, 60, 9, ".")
    for path in ([(14, 14), (40, 40), (59, 59)], [(18, 60), (40, 66), (59, 59)],
                 [(60, 18), (66, 40), (59, 59)], [(22, 22), (60, 18)], [(22, 22), (18, 60)]):
        c.line(path, ".", 5, keep="~")
        c.line(path, "#", 1, keep="~")
    # Lake Rogoźnica with reeds and bog, the tabor's hillock on its shore.
    c.blob(59.5, 59.5, 8, "b")
    c.blob(59.5, 59.5, 5.5, "~")
    c.blob(50, 50, 3.5, "h")
    c.blob(68, 54, 2.2, "B")
    # Steep ravines in the woods.
    for path in ([(36, 52), (30, 60), (32, 70)], [(84, 30), (92, 36)], [(40, 86), (46, 96)]):
        c.line(path, "F", 2)
    # Lake Żarnowieckie beyond the woods in the corners (mirrored).
    c.blob(104, 12, 9, "s", sx=1.3)
    c.blob(106, 11, 7, "~", sx=1.3)
    kit(c, NW, "pp_footprint_stone", woods=False)
    c.place("pp_kurgan", 72, 44)
    c.silver(40, 72)
    c.salt(46, 34)
    return c


def vedrosha() -> Canvas:
    """Small fields among woods and bogs; the Trosna with its one bridge between the armies,
    the Vedrosha stream before it, the great wood on the flank the ambush came from."""
    c = Canvas(SIZE, SIZE, fill="f")
    rng = random.Random(1500)
    # Fields one or two kilometres across.
    for x, y, r in ((22, 22, 16), (46, 40, 9), (36, 60, 8), (60, 34, 8), (59.5, 59.5, 10),
                    (24, 48, 7), (48, 16, 7)):
        c.blob(x, y, r, ".", wobble=0.2)
    for x, y in ((46, 40), (24, 48)):
        c.blob(x, y, 4, ",")
    scatter_woods(c, rng, 6, (2, 3.5), (20, 20, 70, 70), ch="b", keep="~#")
    # The Trosna between the armies: one bridge in the middle and a ford far up each flank.
    c.river([(119, 0), (90, 28), (59.5, 59.5)], water=3, bank="b", bank_w=2)
    c.line([(54, 54), (65, 65)], "#", 2)
    c.crossing(97, 21, "=", "x", 5)
    # The Vedrosha before it on each side, fordable.
    c.river([(84, 0), (64, 22), (40, 46), (12, 68), (0, 76)], water=2, bank="s", bank_w=1)
    for x, y in ((64, 22), (41, 45), (16, 64)):
        c.crossing(x, y, "=", "x", 3, width=3)
    # Tracks through the woods.
    c.line([(16, 16), (46, 40), (59, 59)], "#", keep="~")
    c.line([(46, 40), (36, 60), (24, 48)], "#", keep="~")
    kit(c, NW, "pp_spring", woods=False)
    c.place("pp_old_tree", 70, 44)
    c.silver(30, 68)
    c.salt(56, 30)
    return c


def smolina() -> Canvas:
    """Lake Smolino by the road the Livonian army fell back along, the Russian regiments coming
    up it in a column. Only the lake and the road are the sources'; the woods and bogs of the
    Pskov land round them are drawn for play."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1502)
    scatter_woods(c, rng, 16, (4, 8), (0, 0, 119, 30))
    scatter_woods(c, rng, 6, (2.5, 4), (20, 30, 50, 60), ch="b", keep="~#")
    # The lake off the road in the middle, a smaller one beyond.
    c.blob(66, 50, 9, "s", sx=1.4, sy=0.9)
    c.blob(66, 50, 7, "~", sx=1.4, sy=0.9)
    c.blob(30, 34, 3.5, "~")
    # The road from Pskov to Livonia through the field, along the lake.
    c.line([(0, 62), (20, 60), (48, 64), (59.5, 59.5)], "#", 2, keep="~")
    c.line([(48, 64), (40, 90), (36, 119)], "#", keep="~")
    c.blob(30, 80, 4, ",")
    kit(c, W, "pp_wayside")
    c.place("pp_oak_grove", 59, 59)
    c.silver(44, 40)
    c.salt(46, 78)
    return c


def kletsk() -> Canvas:
    """The Lan with boggy banks between the armies, the Tsapra closing the Tatar camp behind;
    two crossings (a bridge and a causeway, built under the guns); the edge of Polesie bogs."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1506)
    # The Lan north to south through the middle, wide bogs on its banks.
    lan = [(62, 0), (56, 30), (63, 52), (59.5, 59.5)]
    c.line(lan, "b", 13)
    c.line(lan, "B", 7)
    c.line(lan, "~", 3)
    # Two crossings: a bridge and a causeway.
    c.line([(46, 40), (74, 44)], "#", 2)
    c.line([(44, 78), (70, 76)], "#", 2)
    # A third way for play (Valentin: several ways between the bases): a causeway in the middle.
    c.line([(46, 59.5), (73, 59.5)], "#", 2)
    # The Tsapra behind each side's back, fordable.
    c.river([(30, 0), (24, 20), (28, 34)], water=2, bank="b", bank_w=2)
    c.crossing(25, 16, "=", "x", 4)
    # Polesie: bog patches and woods.
    scatter_woods(c, rng, 10, (3, 5), (0, 70, 40, 119), ch="b", keep="~#")
    scatter_woods(c, rng, 10, (4, 7), (0, 84, 40, 119))
    scatter_woods(c, rng, 6, (4, 6), (30, 0, 50, 20))
    c.line([(12, 60), (30, 60), (46, 40)], "#", keep="~")
    c.line([(30, 60), (44, 78)], "#", keep="~")
    kit(c, W, "pp_spring")
    c.place("pp_bog_island", 48, 30)
    c.silver(36, 26)
    c.salt(38, 88)
    return c


def lopushne() -> Canvas:
    """A corridor some two kilometres wide between two woods, falling towards a ravine and a
    stream under the wood on one side; the valley of the Żyrak across it with a mill pond."""
    c = Canvas(SIZE, SIZE, fill="f")
    rng = random.Random(1512)
    # The corridor west to east through the woods, and each side's glade.
    c.rect(0, 38, 119, 81, ".")
    for _ in range(14):
        c.blob(rng.uniform(0, 119), rng.choice((38, 81)) + rng.uniform(-3, 3), rng.uniform(3, 6),
               "f")
    # The ravine and stream under the wood on its edge.
    c.line([(0, 84), (40, 82), (80, 86), (119, 84)], "F", 2)
    c.river([(0, 88), (50, 86), (119, 90)], water=1, bank="b", bank_w=1)
    # The Żyrak valley across the corridor, the mill pond and a dam to cross on.
    c.river([(59.5, 0), (58, 30), (59.5, 59.5)], water=2, bank="b", bank_w=2)
    c.blob(59.5, 50, 4, "~", sy=1.5)
    c.line([(52, 44), (67, 44)], "#", 2)
    c.crossing(58, 30, "=", "x", 4)
    # The hill the Tatar vanguard held, the village and its fields.
    c.blob(42, 52, 5, "h")
    c.blob(30, 70, 5, ",")
    c.line([(12, 60), (40, 60), (52, 44)], "#", keep="~")
    kit(c, W, "pp_old_tree", woods=False)
    c.place("pp_wayside", 32, 46)
    c.place("pp_oak_grove", 59, 70)
    c.silver(44, 74)
    c.salt(46, 40)
    return c


def orsha() -> Canvas:
    """The Dnieper behind each army, crossed by a ford and a bridge of boats; the boggy
    Krapivna with steep banks closing one flank; ravines and a spruce wood on the other."""
    c = Canvas(SIZE, SIZE)
    rng = random.Random(1514)
    # The Dnieper along each side's back edge, with its ford and boat bridge.
    c.river([(0, 112), (30, 104), (60, 110), (90, 104), (119, 108)], water=5, bank="s", bank_w=2)
    c.crossing(26, 100, "=", "y", 8, width=3)
    c.line([(70, 99), (70, 119)], "#", 2, keep="")
    # The Krapivna: a boggy stream with steep banks from the middle to the river.
    krap = [(59.5, 59.5), (62, 76), (58, 92), (60, 106)]
    c.line(krap, "b", 6)
    c.line(krap, "~", 2)
    c.line([(54, 66), (54, 88)], "F", 1)
    c.crossing(60, 82, "=", "x", 5)
    c.crossing(59, 58, "=", "x", 5, width=4)
    # Ravines and the spruce wood on the other flank.
    scatter_woods(c, rng, 10, (4, 7), (66, 0, 110, 24))
    c.line([(74, 30), (84, 22)], "F", 2)
    c.line([(90, 34), (100, 28)], "F", 2)
    c.blob(30, 44, 4, ",")
    c.line([(12, 60), (40, 58), (59, 59)], "#", keep="~")
    c.line([(40, 58), (40, 100), (26, 100)], "#", keep="~")
    kit(c, W, "pp_oak_grove")
    c.place("pp_old_tree", 82, 40)
    c.silver(44, 80)
    c.salt(46, 40)
    return c


# --- the list -------------------------------------------------------------------------------

PROTOTYPE = {
    "id": "map_proto_samogitia",
    "title": "Samogitian borderland",
    "year": 0,
    "note": "The prototype map: the forests and bogs of the Grand Duchy against the river and "
    + "roads of the Order, a grove in the middle.",
    "bases": [[5, 5], [108, 96]],
}

# id, draw, start, year, title, note (English keys), sources (header of terrain.txt).
MAPS = [
    ("map_sk_grunwald", grunwald, NW, 1410, "Grunwald",
     "15 July 1410. Poland and Lithuania crushed the Teutonic Order on open upland among woods, "
     + "lakes and bogs between Grunwald, Stębark and Łodwigowo; the Grand Master fell.",
     ["en.wikipedia.org/wiki/Battle_of_Grunwald",
      "Gałązka, Marks, Przegląd Geologiczny 55(1), 2007",
      "Stream valley, lake Łubień with bogs to its north, three villages: sources. Mirrored lake "
      + "and kit, oak hill in the middle: for play."]),
    ("map_sk_koronowo", koronowo, W, 1410, "Koronowo",
     "10 October 1410. Three months after Grunwald the Polish army beat the Order's mercenaries "
     + "at Koronowo in three bouts with a truce between them; their commander was taken.",
     ["en.wikipedia.org/wiki/Battle_of_Koronowo; S. Jóźwiak, Zapiski Historyczne 2010",
      "Hill taken from its steeper side, lake by the kurgan at Łąsko, village Łączko: sources "
      + "(the exact place is disputed). Tuchola woods on the edges: inferred."]),
    ("map_sk_dabki", dabki, NW, 1431, "Dąbki",
     "13 September 1431. Peasants of the Krajna and a few knights charged from the edge of the "
     + "plateau on a Livonian force plundering the Noteć meadows; the Order's horse drowned in "
     + "the bogs and the Marshal of Livonia was taken.",
     ["zamki.name (after M. Biskup); fotopolska.eu; en.wikipedia.org/wiki/Gmina_Wyrzysk",
      "Plateau edge ~40 m over the flood plain of the Orla, bogs at the Order's back, wood and "
      + "ravine to the north: sources. The plateau mirrored on both sides: for play."]),
    ("map_sk_wilkomierz", wilkomierz, W, 1435, "Wiłkomierz",
     "1 September 1435. By lake Žirnajai near Ukmergė Sigismund Kęstutaitis caught "
     + "Švitrigaila's army and the Livonian knights on the march, cut it in two and routed it; "
     + "the Livonian Master fell.",
     ["en.wikipedia.org/wiki/Battle_of_Pabaiskas; vle.lt Pabaisko mūšis",
      "Lake Žirnajai and the marshy Žirnaja between the camps, the road north, the Šventoji "
      + "near: sources. Where the Šventoji runs is inferred."]),
    ("map_sk_chojnice", chojnice, W, 1454, "Chojnice",
     "18 September 1454. The Polish levy of Casimir IV charged across the causeway by the lake "
     + "at Chojnice; the Order's wagon fort held, a sally from the town struck their rear and "
     + "they fled into the lake and bogs.",
     ["pl.wikipedia.org/wiki/Bitwa_pod_Chojnicami",
      "Lake with a causeway, Polish hill on its east shore, roads to Tuchola and Krojanty, bogs: "
      + "sources. The walled town is left out; the hill mirrored on the west shore."]),
    ("map_sk_swiecino", swiecino, NW, 1462, "Świecino",
     "17 September 1462. Piotr Dunin's small army behind its wagons by a muddy lake in the "
     + "Kashubian beech woods beat the Order: a feigned retreat drew the knights onto hidden "
     + "crossbowmen.",
     ["en.wikipedia.org/wiki/Battle_of_Świecino; rp.pl 2015; pomorskie.travel",
      "Clearing in beech woods, lake Rogoźnica with reeds and bog, hillock at its NW shore, "
      + "ravines, forest tracks: sources. The lake in the middle and the mirror: for play."]),
    ("map_sk_vedrosha", vedrosha, NW, 1500, "Vedrosha",
     "14 July 1500. Hetman Ostrogski drove the Muscovite vanguard over the Trosna and crossed "
     + "by the bridge; an ambush from the wood struck his rear and broke the bridge.",
     ["en.wikipedia.org/wiki/Battle_of_Vedrosha; ru.wikipedia (mirror dic.academic.ru); "
      + "Prokhorov, Shorin, «Край Смоленский», 2000",
      "Small fields among woods and bogs, two rivers, one bridge, ambush wood: sources (the "
      + "place itself is disputed). The far fords on the Trosna: for play."]),
    ("map_sk_smolina", smolina, W, 1502, "Lake Smolino",
     "13 September 1502. Falling back from Pskov, Master Plettenberg gave battle by lake "
     + "Smolino; his foot with guns and the heavy horse of the Landmarshal held off a far larger "
     + "Muscovite army.",
     ["de.wikipedia.org/wiki/Schlacht_am_Smolinasee; NDB, ADB (Plettenberg)",
      "Only the lake and the road the Livonians fell back along are the sources'; woods, bogs "
      + "and the second lake are drawn for play."]),
    ("map_sk_kletsk", kletsk, W, 1506, "Kletsk",
     "5 August 1506. Michael Glinski's Lithuanian army found the Crimean camp on the boggy Lan "
     + "near Kletsk, built two crossings under its guns, struck from two sides and freed "
     + "thousands of captives.",
     ["en.wikipedia.org/wiki/Battle_of_Kletsk; vklby",
      "The Lan with boggy banks, the Tsapra behind the Tatar camp, two crossings, Polesie bogs: "
      + "sources. The Tsapra on both sides: mirror. The causeway in the middle: for play."]),
    ("map_sk_lopushne", lopushne, W, 1512, "Łopuszno",
     "28 April 1512. After a night march the Crown hetman Kamieniecki and Prince Konstanty "
     + "Ostrogski caught the Crimean horde with its captives in a forest corridor by Łopuszno near "
     + "Wiśniowiec; the freed captives struck the Tatars from behind.",
     ["L. Herbst, «Najazd tatarski 1512 r.», Przegląd Historyczny 1948",
      "Corridor ~2 km wide between woods, ravine, stream and wood on its east edge, the Żyrak "
      + "valley with a mill pond across it, the hill of the Tatar vanguard: Herbst's "
      + "reconstruction. The mirror: for play."]),
    ("map_sk_orsha", orsha, W, 1514, "Orsha",
     "8 September 1514. Hetman Ostrogski bridged the Dnieper by Orsha in secret and gave battle "
     + "on the Krapivna field; a feigned retreat, the fire of his foot and his horse broke the "
     + "Muscovites, many died in the boggy Krapivna.",
     ["en.wikipedia.org/wiki/Battle_of_Orsha; ru.wikipedia (mirror dic.academic.ru); vklby",
      "Dnieper behind, ford and boat bridges, boggy Krapivna with steep banks on one flank, "
      + "ravines and spruce wood on the other: sources. The Dnieper behind both sides: mirror."]),
]


# Valentin 2026-10-19: several ways from one base to the other. Ways count as separate when
# they keep 4 cells apart outside the starts (Canvas.routes).
ROUTES = 3


def check(c: Canvas, start: tuple[int, int]) -> list[str]:
    """What is wrong with a map: not symmetric, a start not open, the sides not joined on foot,
    the kit out of reach, too little wood near a start."""
    errs = []
    if not c.symmetric():
        errs.append("not point-symmetric")
    for sx, sy in (start, other(start)):
        for y in range(sy, sy + TC):
            for x in range(sx, sx + TC):
                if c.get(x, y) not in ".,":
                    errs.append(f"town centre cell {x},{y} is {c.get(x, y)!r}")
        for k in range(5):
            if not c.walkable(sx + k, sy + 5):
                errs.append(f"peasant cell {sx + k},{sy + 5} is {c.get(sx + k, sy + 5)!r}")
    a = c.reach(start[0], start[1] + 5)
    bx, by = other(start)
    if (bx, by + 5) not in a:
        errs.append("the two starts are not joined on foot")
    ways = len(c.routes((start[0], start[1] + 5), (bx, by + 5)))
    if ways < ROUTES:
        errs.append(f"only {ways} separate ways between the starts, want {ROUTES}")
    for y in range(c.h):
        for x in range(c.w):
            if c.get(x, y) in "o$%":
                if not any((x + dx, y + dy) in a for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    errs.append(f"object {c.get(x, y)!r} at {x},{y} out of reach")
    for kind, x, y in c.places:
        if (x, y) not in a:
            errs.append(f"place {kind} at {x},{y} out of reach")
    wood = c.count_near("f", start[0] + 2, start[1] + 2, 22)
    if wood < 120:
        errs.append(f"only {wood} wood cells near the start")
    return errs


def render(map_id: str, title: str, year: int, c: Canvas, start, sources: list[str]) -> str:
    bx, by = other(start)
    lines = [
        f"; {map_id} «{title}, {year}» (skirmish), {c.w}x{c.h}.",
        "; Written by tools/maps/gen_skirmish.py; edit there and re-run, not here.",
        "; Point-symmetric about the centre: both sides get the same ground and resources.",
        f"; Town centres: {start[0]},{start[1]} and {bx},{by}. Legend: core/nav/map_text.gd.",
    ]
    lines += [f"; {s}" for s in sources]
    lines += c.rows()
    lines += [f"@place {kind} {x} {y}" for kind, x, y in c.places]
    return "\n".join(lines) + "\n"


def build() -> tuple[dict[Path, str], list[str]]:
    files: dict[Path, str] = {}
    errors: list[str] = []
    entries = [PROTOTYPE]
    for map_id, draw, start, year, title, note, sources in MAPS:
        c = draw()
        print(f"{map_id}: {len(c.routes((start[0], start[1] + 5), (other(start)[0], other(start)[1] + 5)))} ways")
        errors += [f"{map_id}: {e}" for e in check(c, start)]
        files[ROOT / "maps" / map_id / "terrain.txt"] = render(map_id, title, year, c, start, sources)
        entries.append({
            "id": map_id, "title": title, "year": year, "note": note,
            "bases": [list(start), list(other(start))],
        })
    text = json.dumps({"maps": entries}, ensure_ascii=False, indent="\t") + "\n"
    files[ROOT / "maps" / "skirmish.json"] = text
    return files, errors


def main(argv: list[str]) -> int:
    files, errors = build()
    for e in errors:
        print("ERROR", e)
    if "--check" in argv:
        stale = [p for p, t in files.items() if not p.exists() or p.read_text(encoding="utf-8") != t]
        for p in stale:
            print("stale", p.relative_to(ROOT))
        return 1 if errors or stale else 0
    for p, t in files.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(t, encoding="utf-8")
    print(f"wrote {len(files)} files")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
