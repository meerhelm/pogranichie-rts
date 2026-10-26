import sys
import rd
P = "/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01/palette_buildings.png"
T = (", single building game asset, front view facing south, 3/4 top-down view from slightly above, walls parallel to image edges, "
     "front wall facing the viewer straight on, not isometric, no diagonal corner, no rotation, light from top-left, crisp pixel art, no text, no ground, no grass, on a plain white background")
TI = (", small game asset, 3/4 top-down view (not isometric), light from top-left, crisp pixel art, no text, no ground, on a plain white background")
GDL = "Grand Duchy of Lithuania 1409, Samogitian, round logs, "
TO = "Teutonic Order 1409, "
# id, style, w, h, prompt
B = [
 ("gdl_town_center", "rd_pro__topdown", 128, 160, GDL + "chieftain's yard: a big log house with a high steep straw roof inside a square palisade of sharpened stakes, an open wooden gate at the front, a tall wooden watchtower in the corner with a small red pennant"),
 ("to_castle", "rd_pro__topdown", 128, 160, TO + "small wooden-and-earth castle: square rampart with a timber palisade, a red brick gate tower with a red tile roof and a white flag with a black cross"),
 ("gdl_house", "rd_plus__topdown_asset", 64, 80, GDL + "small peasant log hut with a steep straw thatched roof, no chimney, small door"),
 ("gdl_granary", "rd_plus__topdown_asset", 64, 80, GDL + "small log granary raised on wooden stilts with a ladder, straw roof, grain sacks by the door"),
 ("gdl_lumber_yard", "rd_pro__topdown", 96, 96, GDL + "small lumber yard, the whole scene visible and centred: one open shed on four posts with a straw roof in the middle, stacks of logs beside it and a chopping block with an axe, compact"),
 ("gdl_mine", "rd_plus__topdown_asset", 64, 80, GDL + "bog iron works: small clay bloomery furnace under a straw lean-to, baskets and heaps of rusty bog ore, charcoal pile"),
 ("gdl_shrine", "rd_plus__topdown_asset", 64, 96, "pagan Samogitian sacred place (alka): a large old oak tree standing in a ring of grey field stones with a small fire burning in the middle of the ring, no idols"),
 ("gdl_farm", "rd_plus__topdown_asset", 96, 96, "slash-and-burn field clearing seen from above: square patch of green young rye among tree stumps and black burnt earth, flat, no buildings"),
 ("gdl_barracks", "rd_plus__topdown_asset", 96, 112, GDL + "long log hall with a straw roof, racks of spears and round shields by the wall, a small red pennant"),
 ("gdl_range", "rd_plus__topdown_asset", 96, 96, GDL + "archery range: small open straw-roofed shed, a trampled yard with three straw targets, bows on a rack"),
 ("gdl_stable", "rd_plus__topdown_asset", 96, 112, GDL + "long log stable with a straw roof, a small fenced paddock and a haystack"),
 ("to_house", "rd_plus__topdown_asset", 64, 80, TO + "colonist's house: half-timbered white plaster walls with dark beams, high straw thatched roof"),
 ("to_shrine", "rd_plus__topdown_asset", 64, 96, TO + "small red brick gothic chapel with a small bell turret, red tile roof, a cross on top"),
 ("rubble_wood", "rd_plus__topdown_asset", 64, 64, "pile of burnt black and brown log beams, charred timber debris and ashes, ruins of a wooden house"),
 ("rubble_brick", "rd_plus__topdown_asset", 64, 64, "low flat heap of broken red bricks and charred beams lying on the ground, collapsed ruins, no standing walls, no roof"),
 ("gdl_bort", "rd_plus__topdown_item", 32, 64, "tall pine tree with a wooden beehive hollow carved in the trunk, reddish bark"),
 ("gdl_palisade", "rd_plus__topdown_item", 96, 48, "straight horizontal row of sharpened vertical brown weathered wooden log stakes, a palisade wall segment, front view, brown wood only"),
 ("gdl_palisade_v", "rd_plus__topdown_item", 32, 96, "palisade wall of sharpened brown wooden log stakes running away from the viewer, seen from above, narrow vertical strip, brown wood only"),
 ("gdl_gate", "rd_plus__topdown_asset", 64, 64, GDL + "wooden double gate between two thick gate posts of a log palisade, a small roofed lookout platform above the gate, brown wood"),
 ("gdl_gate_v", "rd_plus__topdown_item", 32, 64, GDL + "wooden palisade gate seen from the side, running away from the viewer, narrow"),
 ("gdl_tower", "rd_plus__topdown_item", 32, 80, GDL + "tall square log watchtower with an overhanging fighting gallery and a pyramid shingle roof"),
 ("gdl_zaseka", "rd_plus__topdown_item", 96, 48, "abatis barrier: felled trees lying crosswise with branches pointing out, horizontal"),
 ("gdl_zaseka_v", "rd_plus__topdown_item", 32, 96, "abatis barrier: felled trees lying crosswise with branches, running away from the viewer, narrow vertical strip"),
 ("to_gate", "rd_plus__topdown_item", 48, 48, TO + "wooden gate with a timber gatehouse platform above, a small white flag with a black cross, front view"),
 ("to_gate_v", "rd_plus__topdown_item", 32, 64, TO + "wooden gate seen from the side, running away from the viewer, narrow, small white flag with black cross"),
]
SUFFIX = __import__("os").environ.get("SUFFIX", "")
only = set(sys.argv[1:])
for i, (n, st, w, h, p) in enumerate(B):
    if only and n not in only:
        continue
    rd.generate(n + SUFFIX, dict(prompt_style=st, width=w, height=h, num_images=1, seed=9300 + i, remove_bg=True,
                        prompt=p + (TI if "item" in st else T)), {"input_palette": P})
