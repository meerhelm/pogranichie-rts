import sys, rd
P = "/Users/valentinsobolev/Development/meerhelm/pogranichie-rts/.rd-trial/gdl01/palette_buildings.png"
T = ", game command button icon, single centred symbol, bold dark outline, warm colours, light from top-left, medieval 15th century, crisp pixel art, no text, no letters, on a plain white background"
I = {
 "stop": "a raised open human palm facing the viewer, pale beige skin colour, a brown leather cuff at the wrist, hand showing stop",
 "aggressive": "two crossed steel swords with brown leather grips",
 "defensive": "a round wooden shield with an iron boss in the centre and iron rim",
 "stand_ground": "a wooden pole with a small red flag stuck into a small mound of earth",
 "line": "two horizontal rows of five round bronze dots, and a small arrow pointing up above them",
 "column": "a vertical column of round bronze dots, two wide and five deep, with a small arrow pointing up above it",
 "wedge": "ten round bronze dots arranged in a triangular wedge with the point upward",
}
for i, n in enumerate(sys.argv[1:] or I):
    rd.generate(n, dict(prompt_style="rd_plus__ui_element", width=64, height=64, num_images=1, seed=9500 + i, remove_bg=True, prompt=I[n] + T),
                {"input_palette": P})
