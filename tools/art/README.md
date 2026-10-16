# tools/art — code-built art

Low-poly models built by Python scripts in Blender and rendered into isometric sprites by the
pipeline of the visual assets doc («Технические спецификации»): orthographic camera at X 60°,
Z 45°, sun from the upper left at 45°, AgX, transparent film, 45.25 px per metre (a 2 m cell is
128×64 at render size; the game draws cells 64×32 and sprites at half size).

```sh
pip install bpy==5.2.2 pillow          # Blender as a Python module, no Blender install needed
python3 -m tools.art.render gdl_peasant gdl_spearman gdl_house gdl_town_center nt_pine nt_birch
python3 -m tools.art.render gdl_peasant --preview --out /tmp/prev   # one frame per direction
python3 -m tools.art.preview art/sprites /tmp/units.png             # units as the game tints them
python3 -m tools.art.mockup art/sprites /tmp/scene.png              # game-scale mock scene
```

In-game screenshot (needs a display; on a server use Xvfb):

```sh
xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 \
  -s tools/art/screenshot.gd -- /tmp/shot.png 6 2.0   # seconds, camera zoom
```

## Files

- `rig.py` — camera, light, scale, shadow catcher; `heading_for_facing` turns a model to the
  game's 8 facings (`UnitView.facing`: 0 east, clockwise, 2 south).
- `shapes.py` — materials and primitives; the `TEAM` material marks player-colour zones.
- `people.py` — a 1.75 m figure of joint empties with idle (8 frames) and walk (12 frames).
- `models.py` — the assets, keyed by catalog id; descriptions follow the visual assets doc.
- `render.py` — renders three passes and packs them into `art/sprites`:
  - `color` — the sprite with alpha;
  - `team` — only the TEAM surfaces, lit and white; the game multiplies it by the player colour;
  - `shadow` — the ground shadow alone, drawn first at 70 % so it never covers neighbours.
  Units: `units/<id>/{color,team,shadow}.png` + `sheet.json` (frame, pivot, rows per animation;
  row offset = facing). Buildings and trees: `<kind>/<id>_<pass>.png` + `<id>.json`
  (pivot = centre of the footprint). Trees have no team pass.

The game reads them through `game/world/SpriteDB`; ids without art keep their placeholders.
Rendered PNGs are plain git (see `.gitattributes`), not LFS: they are small and regenerable.
Normal maps and building stages (foundation, damage, rubble) are not rendered yet.
