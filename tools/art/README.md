# tools/art — code-built art

Low-poly models built by Python scripts in Blender and rendered into isometric sprites by the
pipeline of the visual assets doc («Технические спецификации»): orthographic camera at X 60°,
Z 45°, sun from the upper left at 60° (the doc says 45°; raised so shadows stay short and whole), AgX, transparent film, 45.25 px per metre (a 2 m cell is
128×64 at render size; the game draws cells 64×32 and sprites at half size).

```sh
pip install bpy==5.2.2 pillow          # Blender as a Python module, no Blender install needed
python3 -m tools.art.render gdl_peasant gdl_spearman gdl_house gdl_town_center nt_pine nt_birch
python3 -m tools.art.render gdl_peasant --preview --out /tmp/prev   # a few frames per direction
python3 -m tools.art.render gdl_peasant --add   # only the animations its sheet lacks
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
- `people.py` — a 1.75 m figure of joint empties with idle (8 frames), walk (12 frames), work
  (8 frames: a two-handed chop, for peasants and camp servants) and attack (8 frames, played
  once per blow) in one of `ATTACK_STYLES`: swing, thrust, throw, bow, crossbow, cast. Which
  units get work and which attack style is in `registry.py` (`WORKERS`, `ATTACK_STYLE`); beasts
  lunge (`beasts.py`), riders strike while the horse stands, the wagon only walks.
- `models.py` — the first assets (peasant, spearman, house, town centre, trees, deposits).
- `folk.py` — the other people on foot; `beasts.py` — a four-legged rig for animals and horses,
  riders sitting on them, the wagon.
- `kit.py` — building materials (log, thatch, shingle, brick, roof tile, plaster and timber
  framing) and parts (roofs, stepped gables, windows, sheds, fences, barrels);
  `buildings_gdl.py` and `buildings_to.py` — the Duchy's and the Order's buildings.
- `registry.py` — every asset by catalog id with its frame (units) or footprint (buildings).
- `render.py` — renders three passes and packs them into `art/sprites`:
  - `color` — the sprite with alpha;
  - `team` — only the TEAM surfaces, lit and white; the game multiplies it by the player colour;
  - `shadow` — the ground shadow alone, drawn first at 70 % so it never covers neighbours.
  Units: `units/<id>/{color,team,shadow}.png` + `sheet.json` (frame, pivot, rows per animation;
  row offset = facing). Buildings: `buildings/<id>_<stage>_<pass>.png`, trees: `trees/<id>_<pass>.png`; each with `<id>.json`
  (pivot = centre of the footprint). Trees have no team pass.

The game reads them through `game/world/SpriteDB`; ids without art keep their placeholders.
`UnitView` plays walk while moving, else attack once after each blow (`last_attack`), else work
at a job, else idle, turned to the target or the work. `--add` renders only the animations a
sheet lacks and copies the old rows back, so a new animation does not re-render the rest.
Building frames are rendered large and cropped to what all stages cover. Unit frames: 160×144
on foot, 224×256 mounted (an upright lance), 224×176 big beasts, 320×240 the wagon; `bar_y`
in `sheet.json` is where the HP bar goes.

Line pieces: a palisade cell is its post cluster (`<id>`) plus arms toward the neighbours
(`<id>_e`, `_w`, `_n`, `_s`, model axes +X, -X, +Y, -Y), which BuildingLayer picks per cell.
Turned views end in `_v`: a zaseka placed along y, a gate in a line running along y.

```sh
python3 -m tools.art.render all          # every asset of the registry (about an hour on 4 cores)
python3 -c "from tools.art.preview import buildings_sheet; buildings_sheet('art/sprites', ['to_castle'], '/tmp/b.png')"
```
Rendered PNGs are plain git (see `.gitattributes`), not LFS: they are small and regenerable.
Buildings come in the 7 stages of `stages.py` (`<id>_<stage>_<pass>.png`): found, build_33,
build_66, done, damaged_1, damaged_2, rubble. Normal maps are not rendered yet.

## Interface

- `ui_skin.py` — procedural nine-patch textures in `ui/skin` (oak panels with a bronze rim,
  wooden buttons, parchment for tooltips, a sunk well); `ui/theme.tres` uses them.
- `menu_scene.py` — the main menu background `ui/art/menu_background.jpg`: the same models
  in the evening sun through a perspective camera (render to PNG, then save as JPEG).
- Icons of the top bar are hand-written SVGs in `ui/icons` (Godot imports SVG directly).

## Ground and resources

- `tiles.py` — a seamless top-down texture per terrain (periodic FFT noise), cut into a 4×4
  atlas of isometric tiles in `art/tiles/<terrain>.png`; cell (x, y) uses tile (x % 4, y % 4).
  Tiles are 96×48: the 64×32 diamond plus a ragged fading rim that blends terrains.
- `render.py o_bog_ore o_silver_mine carcass` — map resources in variants
  (`art/sprites/deposits/<id>_<v>_{color,shadow}.png`), picked per cell by `SpriteDB.deposit_at`.
