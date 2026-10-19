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
  lunge (`beasts.py`), riders strike while the horse stands, wagons only walk, the bombard
  fires (flash, smoke, recoil).
- `models.py` — the first assets (peasant, spearman, house, town centre, trees, deposits).
- `folk.py` — the other people on foot; `beasts.py` — a four-legged rig for animals and horses,
  riders sitting on them, the wagon.
- `folk_1410.py` — the units of the Grunwald mission (ВКЛ 2): Samogitian, Polish and Tatar
  troops, the guest knight, the Order's wagon and bombard, and the heroes; the `sovereign`
  hero template (a rider with a standard-bearer on foot) is `Sovereign` there. Also the
  Baptism (ВКЛ 3): the Order's spy, the pagans and their priest, and the council's envoys
  (`Envoys`: two clerics as one unit); civilians only idle and walk.
- `folk_1435.py` — the heroes of Wiłkomierz (ВКЛ 4): the Gintovt brothers (placeholder family
  arms: a white zigzag on green; Jurij's lance carries the woven belt under the pennon),
  Mikhail Sigismundovich with the Pogoń, Jakub of Kobylany (arms unverified: plain white and
  red), the Livonian brother Nesselrode and the Master Kerskorf (`Sovereign`, with a bearer).
- `folk_1500.py` — Vedrosha (ВКЛ 5): the noble lancer (plate, sallet, two-tailed pennon,
  chanfron), the field gun (`FieldGun`: bronze barrel on a wheeled carriage, two gunners; a
  horse pulls it trail first on the march, it fires like the bombard), the first Muscovite
  units (syn boyarsky with bow and saadak, boyar in a bakhterets with a round shield, the monk
  with the icon on a pole: `cast` lifts it over his head, so he has a taller frame) on an
  eastern saddle with short stirrups (`EasternMounted`), and the heroes Andrei Gintovt (the
  khorugv with the Gintovt arms, the woven belt), Ostrogski (bulawa; arms unverified, none
  drawn) and Shchenya (`EasternSovereign`: his bearer carries the rider and serpent of coa_mo).
- `folk_1507.py` — the Wolf Trail (ВКЛ 6): Ostrogski in flight (`hero_ostrogski_fugitive`: no
  armour, a plain dark riding coat, a fur cap, a drawn sabre), the Muscovite border watchman
  (`mo_storozha`: a faded tegilyai, a fur-banded cap, bow and saadak) and the invented centurion
  Nezhdan (`hero_nezhdan`: a dark red tegilyai, a gilt-rimmed spheroconical helmet); the
  watchtower `mo_watchtower` (four leaning posts, a roofed platform, the signal barrel) and
  the map props `prop_chapel` (a log chapel with an onion dome and an eight-pointed cross) and
  `prop_campfire` (stones, logs, still flames, an emissive glow on the ground).
- `folk_1508.py` — the siege of Slutsk (ВКЛ 7): the townsman with bucket and axe, the hook
  gun, princess Anastasia, prince Yuri, Glinski's envoy, the Muscovite light gun (`FieldGun`
  with a Muscovite crew), the log wall `gdl_wall` and the props `prop_well`, `prop_barrels`,
  `prop_ladders`.
- `folk_1514.py` — Orsha (ВКЛ 8): the Crown's mercenary pikeman `pl_drab` (kettle hat, quilted
  coat, pike, a spade on the back; a wider, taller frame for the levelled pike), the handgunner
  (`Gunner`: a muzzle flash and a puff of smoke in the attack), the light Serbian-style hussar
  (tall cloth cap, tarcza, lance; no wings, no armour), the heroes Świerczowski (blackened half
  armour, beret), Sampoliński (armet, the court banner with the White Eagle), Chelyadnin (green
  ferjaz, white horse), Bulgakov-Golitsa (kolontar, yalovets on the shishak) and the chronicler
  Maciej (civilian: idle and walk); the props `prop_boats`, `prop_logs` and the old oak
  `prop_oak`, which renders in a bigger frame (`registry.PROP_FRAMES`). `pl_field_gun` and
  `mo_tatar` have no model of their own: `SpriteDB.ALIASES` draws them as `gdl_field_gun` and
  `nt_steppe_archer`.
- `folk_crown.py` and `buildings_pl.py` — the Crown of Poland as a skirmish faction. Units:
  the kmet (sermięga, an axe; works like the Duchy's peasant), the bowman (hood with a pelerine,
  longbow), the light horse (mail, kapalin, a small shield with the White Eagle), the foot
  servant (sulica, a small round shield), the pavise man (`PaviseMan`: a falchion, the pavise on
  his back; his `work`, played while the pavise is set up, plants it in front of him and shows
  him crouched behind it), the priest (cassock, surplice, stole, a cross on a staff raised in
  `cast`, so the tall frame) and the wagon under a white canvas with red hoops. Buildings:
  whitewashed timber under thatch and shingle for the village (the manor «Двор» with its porch
  and brick lamus, the cottage «Хата», the wayside cross `pl_shrine` and the chapel it becomes,
  `pl_shrine_chapel`, a separate art id), brick Gothic with white stone for the church
  «Костёл» (green copper spire) and the castle «Замок» (round towers, a round keep, a palace in
  an open court), the salt works with steam and a horse capstan, the gabion battery; the
  Crown's flag (`crown_flag`) is the White Eagle on red with a team pennon. `pl_camp_servant`,
  `pl_bombard` and `pl_field_camp` have no model: `SpriteDB.ALIASES` draws them as
  `gdl_camp_servant`, `to_bombard` and `gdl_field_camp`.
- `folk_crown_1410.py` — the heroes of the Crown's Grunwald (Корона 1): Jaśko of Łęczyca in
  borrowed old mail with a plain small shield on a plain horse, Zyndram of Maszkowice (stocky,
  a plain red surcoat, a mace; arms unverified, none drawn), Marcin of Wrocimowice with the
  great banner of the Kingdom (the crowned White Eagle on red), Oleśnicki in a dark cleric's
  gown on a light horse with a broken lance stump, the king Jagiełło (`Sovereign`: a crown on
  an open bascinet, a red mantle; beside him a guard with a spear, not a bearer: his banner is
  hidden in the story), the stranger in red (civilian: a red kaftan and cap, no weapons) and
  the Grand Commander Lichtenstein (a knight brother like hero_wallenrode).
- `folk_crown_malbork.py` — the siege of Malbork (Корона 2): Heinrich von Plauen (`Sovereign`:
  a lean, tired face, the white mantle with the black cross and no rank insignia, a plain
  shield, a lance; beside him a grey half-brother with the Order's banner), the envoys of the
  Prussian towns (`Envoys` of three burghers in dark gowns, one holding a sealed letter; no
  town arms drawn), the Gdańsk shipman `nt_gdansk_shipwright` (dark wool, leather apron,
  knitted cap, axe and hammer; works and strikes with a swing); the Order's brick town wall
  `to_wall` (crenellated both sides, a frieze in the team colour; joined like gdl_wall from
  the pier and the arms `_e/_w/_n/_s`), the Crown's field infirmary `pl_lazaret` (2×2 as in the
  catalog: tents with red trim, stretchers, cauldron, drying linen) and the map props
  `prop_church` (St John's of the burned town: brick Gothic, the west half of the roof burned
  to black rafters, soot over the windows; a big frame in `registry.PROP_FRAMES`) and
  `prop_ruins` (blackened brick walls of burned houses, charred beams, rubble).
- `folk_crown_baltic.py` — the march to the Baltic (Корона 3): Mikołaj of Michałów (white
  plate under a plain red surcoat, an open bascinet, a raised sword, a red caparison; arms not
  drawn), Jan Čapek (dark brigandine, open sallet, the lance with the orphans' banner: a red
  chalice on black, a white shield with the chalice), the Hussite footman `nt_hussite_flail`
  (padded jack, kettle hat, a red chalice on the chest, sulice on the back; `FlailMan`: the
  swingle hangs at rest and flies out in the blow; the tall frame), the Gdańsk militiaman (red
  jack, white sleeves, spear, the town's two white crosses on red without the crown) and
  crossbowman (pl_crossbow in a white tunic with red sleeves and the town's badge), the war
  wagon `nt_hussite_wagon` (high plank sides with loopholes, the chalice, chains; a handgunner
  inside fires over the boards) and the houfnice on a cart `nt_hussite_gun` (turned round to
  fire, the horses stay hitched; flash, smoke, recoil).
- `kit.py` — building materials (log, thatch, shingle, brick, roof tile, plaster and timber
  framing) and parts (roofs, stepped gables, windows, sheds, fences, barrels);
  `buildings_gdl.py` and `buildings_to.py` — the Duchy's and the Order's buildings.
- `registry.py` — every asset by catalog id with its frame (units) or footprint (buildings).
- `render.py` — renders three passes and packs them into `art/sprites`:
  - `color` — the sprite with alpha;
  - `team` — only the TEAM surfaces, lit and white; the game multiplies it by the player colour;
  - `shadow` — the ground shadow alone, drawn first at 70 % so it never covers neighbours.
  Units: `units/<id>/{color,team,shadow}.png` + `sheet.json` (frame, pivot, rows per animation;
  row offset = facing). Buildings: `buildings/<id>_<stage>_<pass>.png`, trees: `trees/<id>_<pass>.png`,
  map props: `props/<id>_<pass>.png`; each with `<id>.json` (`size`, `pivot` = centre of the
  footprint, `scale`, `cells`). Trees and props have no team pass.

The game reads them through `game/world/SpriteDB`; ids without art keep their placeholders.
`UnitView` plays walk while moving, else attack once after each blow (`last_attack`), else work
at a job, else idle, turned to the target or the work. `--add` renders only the animations a
sheet lacks and copies the old rows back, so a new animation does not re-render the rest.
Building frames are rendered large and cropped to what all stages cover. Unit frames: 160×144
on foot (160×216 the monk with his raised icon, the Crown's priest with his cross and the Hussite
with his flail, 288×216 the drab with his pike, 224×144 the handgunner), 224×256 mounted (an upright lance), 224×176
big beasts, 320×240 the wagons, the bombard and the guns; `bar_y` in `sheet.json` is where the HP bar goes.

Line pieces: a palisade cell is its post cluster (`<id>`) plus arms toward the neighbours
(`<id>_e`, `_w`, `_n`, `_s`, model axes +X, -X, +Y, -Y), which BuildingLayer picks per cell.
Turned views end in `_v`: a zaseka placed along y, a gate in a line running along y.

```sh
python3 -m tools.art.render all          # every asset of the registry (about an hour on 4 cores)
python3 -m tools.art.render prop_chapel prop_campfire   # map props (registry.PROPS), like trees
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
- `render.py o_bog_ore o_silver_mine o_salt_spring carcass` — map resources in variants (the salt
  spring, a brine pool in a salt crust with a log curb, is where the Crown builds its salt works)
  (`art/sprites/deposits/<id>_<v>_{color,shadow}.png`), picked per cell by `SpriteDB.deposit_at`.

## HUD icons

The bottom panel's buttons show 128×128 icons from `ui/icons` (list: docs/07-ui-icons.md):

```sh
python3 -m tools.art.icons          # buildings: the done sprite on a plate, team-tinted
python3 -m tools.art.portraits      # units: close-up portraits rendered in Blender (bpy)
python3 -m tools.art.ui_icons       # orders, techs, ages, spells: SVG
xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 \
  -s tools/art/screenshot.gd -- /tmp/panel.png 3 1.0 panel:peasants:gdl_bort
```

`panel:WHAT[:HOVER]` selects peasants, army or a building (base id) and shows the tooltip of
the button HOVER; `SHOT_LOCALE=be` takes the shot in another language. The game finds icons by
catalog id through `ui/icon_db.gd`; buttons are `ui/icon_button.gd`, tooltips `ui/tips.gd`.
