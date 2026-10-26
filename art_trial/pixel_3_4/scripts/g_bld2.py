import os, sys
import rd
P = "/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01/palette_buildings.png"
T = (", single building game asset, front view facing south, 3/4 top-down view from slightly above, walls parallel to image edges, "
     "front wall facing the viewer straight on, not isometric, no diagonal corner, no rotation, light from top-left, crisp pixel art, "
     "no text, no ground, no grass, on a plain white background")
GDL = "Grand Duchy of Lithuania 1409, Samogitian, "
B = {
 "gdl_gate": ("rd_plus__topdown_asset", 64, 64, GDL + "gate in a palisade of sharpened brown log stakes: two thick square log gate posts joined by a log beam on top, closed double door of vertical brown planks between them, short pieces of brown stake palisade on the left and right, symmetrical, brown wood only"),
 "gdl_tower": ("rd_plus__topdown_asset", 64, 96, GDL + "tall narrow square watchtower of horizontal brown round logs on four log legs, an open lookout platform with a railing on top, a steep pyramid roof of brown wooden shingles, symmetrical, brown wood only"),
 "gdl_zaseka": ("rd_plus__topdown_asset", 96, 96, "abatis barrier: a low horizontal row of felled spruce trees lying side by side on the ground with sharpened bare branches pointing towards the viewer, brown trunks, dry brown and dark green branches, wide and low, symmetrical"),
 "gdl_lumber_yard": ("rd_plus__topdown_asset", 64, 80, GDL + "small lumber yard: an open shed of round logs on four posts with a straw roof, front side open towards the viewer, neat stack of logs under it, a chopping block with an axe in front"),
}
only = sys.argv[1:]
SUF = os.environ.get("SUFFIX", "")
for i, n in enumerate(only):
    st, w, h, p = B[n]
    rd.generate(n + SUF, dict(prompt_style=st, width=w, height=h, num_images=1, seed=9400 + i + len(SUF), remove_bg=True, prompt=p + T),
                {"input_palette": P})
