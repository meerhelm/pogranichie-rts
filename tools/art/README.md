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

## Pixel art (Retro Diffusion)

Buildings, trees, decals and the first units are now pixel art generated with Retro Diffusion
and drawn 1:1 (`"scale": 1.0`, nearest filter). Raw output and job files live in
`art_src/pixel_iso/full`; the key is `~/.config/retrodiffusion/token`, never in the repo.

```sh
python3 art_src/pixel_iso/rd_client.py jobs.json --dry            # free: price every job
python3 art_src/pixel_iso/rd_client.py jobs.json --cap 2 --resume  # run, skip what succeeded
python3 -m tools.art.pixel_iso --src art_src/pixel_iso/full --out art/sprites [--only id ...]
python3 -m tools.art.pixel_units [id ...]   # unit sheets + panel icons from the animation GIFs
godot --headless -s tools/art/make_frames.gd -- gdl_peasant   # then SpriteFrames
```

- Buildings: `rd_pro__isometric` with the reference huts as `reference_images`, a building
  palette, `remove_bg`; prompts say «no people». `picks.json` names the chosen raw per id.
- Units: one view (`rd_pro__isometric`, 64×64) → `rd_advanced_animation__rotate` (8 views in a
  GIF) → idle / walking / attack (`rd_advanced_animation__*`, 8 frames each) for facings 0, 1,
  2, 6, 7; 3, 4, 5 are mirrors. The team colour is a belt band at the waist.
- Riders (`pixel_units.RIDERS`) are generated at 96×96 (the price does not depend on the size)
  and get a 128×120 frame; their panel portrait is the rider from the helmet to the saddle.
  `WHITE_CLAD` units keep the near-white inside the figure (white cloaks, tabards, shields).
- The turn GIF starts at the base view's own facing and steps 45° per frame (E, SE, S, … for
  most); check the sheet by eye and map frames to facings 0, 1, 2, 6, 7. Read its frames with
  `seek`, not `list(ImageSequence.Iterator(...))`, which hands back one image eight times.
- A unit costs about $2.40: base 0.36 (two images) + turn 0.10 + 15 animations × 0.14.

### Ground from PixelLab and the ground shader

The ground of most terrains comes from PixelLab (https://api.pixellab.ai/v2, key in
`~/.config/pixellab/token`, never in the repo; the account bills in generations of its plan):
`/create-tiles-pro` isometric 64x32 tiles in the style of our old atlas, four numbered kinds of
ground with four tiles of each (`art_src/pixellab/jobs_tiles.json`, raw tiles in
`art_src/pixellab/tiles/<id>/`; road and hill came out worse and are kept aside in
`tiles_unused/`, those two use the old textures).

```sh
python3 art_src/pixellab/pl_client.py art_src/pixellab/jobs_tiles.json --resume   # needs Pillow
python3 -m tools.art.pixel_tiles --src art_src/pixel_iso/ground --palette art_src/pixel_iso/palette.png
godot --headless -s tools/art/make_tileset.gd
```

- `pixel_tiles` turns each tile back to a 32x32 top-down cell (`unproject_cell`, cutting off the
  darker rim PixelLab paints round every diamond), fills the 8x8-cell period with tiles of each
  kind and lays the kinds out in noise patches; PixelLab colours are kept (the 30-colour palette
  turned dark water brown). It writes the old atlases (`art/tiles/<id>.png`, now with a 32 px
  rim) and the top-down textures `art/tiles/<id>_top.png`.
- In the game the ground is drawn by one shader over the map (`game/world/ground_splat.gdshader`,
  set up by `MapView`): per screen pixel the cell point under it, each ground's share as the
  bilinear blend of the four nearest cell centres, the highest ground (`MapView.LAYERING`) whose
  share reaches shows, frayed by noise and dither. Borders run smoothly through the cells, a lone
  cell is a rounded patch, a road over water gets an earth causeway and shores sparse reeds. The
  tiles stay in the TileMapLayer as data (map editor, tests) but are not drawn.

Tech, spell and order icons and unit portraits are PixelLab too (`/generate-with-style-v2` with
our pixel order icons as the style, 16 variants each, `art_src/pixellab/jobs_*.json`);
`python3 -m tools.art.pl_icons` writes the picked ones (`art_src/pixellab/icons/picks.json`).

### Building shadows from rough 3D proxies (`proxy_shadow.py`)

A generated picture is flat, so its shadow is computed from an invisible stand-in: a few
solids per building in `art_src/pixel_iso/proxies.json` (box, roof `gable_u` / `gable_v` /
`pyramid` / `flat`, cylinder, cone, post), in cells from the centre of the footprint (`u` screen
down-right, `v` down-left) and screen pixels of height `z`. The sun is the Blender rig's (upper
left of the screen, 60° up): a point `z` px high throws its shadow (0.3 z, 0.3 z) px down-right,
the same for buildings, trees and units.

- The proxy only gives depth: it is carved by the picture (a proxy point counts only where the
  sprite is opaque at its screen spot), so the gaps between a tower's legs, a bare trunk under a
  crown or an open shed come out by themselves.
- Soft: every 8 px of height casts its own layer, blurred by 0.4 + 0.035 × height px, so the
  shadow is crisp at the foot and soft at a tower's top (`BAND`, `SOFT0`, `SOFT`).
- Heights: `fit` adds a tower for every run of screen columns where the sprite rises 18 px or
  more over the first box (a keep, a belfry, a spire, a chimney; `spires`), standing in the
  middle of the box's depth there. Solids shade one another on the sprite itself
  (`cast_on_self`): the keep darkens the castle roofs to its lower right, a hall its annex; a box
  and the roof on it are one solid and never shade themselves (their dark side is painted).
- The shadow stays a separate layer (`*_shadow.png`); building stages get it too (the scaffold
  stages from the proxy cut at a third and two thirds of its height). For ids in `GROUND` (a
  painted yard or pad) the sprite's own ground pixels inside the shadow are darkened as the game
  darkens the map.
- Raws lit from the right are turned in `pixel_iso.LIGHT_FIX` (square footprints mirrored, the
  felled tree turned half round). Trees and units keep the flat-card shadow (`shadow_of`).

```sh
python3 -m tools.art.proxy_shadow fit [id ...]         # first guess: box + roof fitted to the outline, + towers
python3 -m tools.art.proxy_shadow spires id …          # add towers to a hand-made proxy
python3 -m tools.art.proxy_shadow sheet /tmp/s.png id …  # review: shadow on grass | proxy wireframe (K=1: 1x)
python3 -m tools.art.proxy_shadow probe /tmp/probe id …  # sprite x2 over a quarter-cell ground grid
python3 -m tools.art.pixel_iso --only id …             # write the sprites with the new shadows
```

`fit` writes only ids missing from `proxies.json` unless named; options per id (`lam` = how
much spilling past the outline costs, lower for frames and crowns; `kinds` = roofs to try) are
in `proxy_shadow.FIT`. A tower `fit` puts on a ridge finial or a target post (a dark stripe on
a roof in the sheet) is deleted from `proxies.json` by hand. Hand-made proxies (farms, ranges,
the Order's town centre) are read off `probe`: a ground point of the sprite at (x, y) is
u − v = (x − pivot x) / 32, u + v = (y + z − pivot y) / 16. On the sheet the red outline is the
proxy, blue its base, yellow its uncarved shadow.

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
- `folk_crown_chojnice.py` — Chojnice (Корона 4): the levy nobleman `pl_pospolite` (an old red
  brigandine, an old open bascinet, a plain painted shield, a lance; a plainer horse), the
  Order's hired foot `to_soldner` (open sallet, blue-grey brigandine, particoloured hose, a long
  spear held like a pike, the pike frame) and `to_handgunner` (grey quilted coat, kettle hat,
  `Gunner`'s shot, no chalice; the handgunner's frame), the mercenary horseman `to_merc_horse`
  (half armour, sallet with bevor, ochre tunic, two-tailed pennon), and the heroes Stach (a
  bright new breastplate and pauldrons, open sallet, beardless, his grandfather's plain small
  shield), Casimir IV (`Sovereign`: young, a crown on an open bascinet, crimson mantle with
  ermine; his bearer carries the crowned White Eagle on red), the Great Polish lords
  `hero_k4_lords` (bright full plate, crimson tabard, gold chain, a mace), Heinrich Reuss von
  Plauen (a knight brother in a sallet, a full clean-shaven face, a sword) and the mercenary
  captains `hero_k4_order` (gilt-edged plate, blue tabard, a team plume, a war hammer); no family
  arms are drawn.
- `folk_crown_silver.py` — Silver for Malbork (Корона 5): pani Barbara (`lady`, idle and walk:
  a dark blue wool gown to the ground with fur at the hem and collar, a townswoman's
  white linen headdress with a roll, veil and wimple, the counting book, keys and a purse at a
  team girdle), Červenka (`mounted`, bareheaded as the card says: a breastplate and pauldrons
  over a wine-red velvet doublet, a gold chain, a war hammer, a dark bay without a caparison; no arms), the
  Gdańsk councillor `hero_k5_civil` (civilian: a long dark gown edged with fur, a chain of
  office, a tall tapering hat in a fur brim, a sealed letter), the river boat `pl_river_boat`
  (`RiverBoat`: a long plank punt of which only the part above the waterline is built, two
  rowers with a pair of oars each, a steersman with a sweep, a crossbowman behind pavises in
  the bow, chests of silver, a team pennon; idle rocks, walk is the oar stroke with a bow wave
  and wake, attack is the crossbow shot; its own frame, `registry.BOAT`), the landing
  `pl_dock` (3×3: a plank pier on piles over a small basin cut into the river side (+X) and
  running out past the footprint, a store shed, a jib crane with a chest on the rope, a moored
  punt, goods, the Crown's flag) and the prop `prop_piles` (the broken piles of the old Nogat
  bridge on transparent ground for the water tiles; a bigger frame). `pl_merc_horse` has no
  model: `SpriteDB.ALIASES` draws it as `to_merc_horse`.
- `folk_crown_swiecino.py` — Świecino (Корона 6): Piotr Dunin (`mounted`: plain steel half
  armour, a red tabard and a small shield with his arms Łabędź, a white swan on red; an open
  sallet with the bevor, a greying beard, a steel mace, a bay without a caparison), Paweł
  Jasieński leading the heavy horse (full bright plate, a closed sallet with a white plume, a
  dark green tabard, a lance with a two-tailed team pennon, a grey with a chanfron under a
  green caparison), the Order's mercenary captains Fritz Raweneck (dark russeted half armour,
  a black tabard edged in ochre, a grizzled beard, a sword, a dun) and Kaspar Nostitz (the
  same type: steel half armour, a tabard quartered dark red and white, a full clean-shaven
  face, a war hammer, a black horse), and the Pomeranian peasant `nt_pomeranian` (homespun
  coat, hood with a cape, leg wraps, a sickle at the rope belt, a three-tined pitchfork held
  like a spear, attack `thrust`). Only Dunin's arms are drawn.
- `kit.py` — building materials (log, thatch, shingle, brick, roof tile, plaster and timber
  framing) and parts (roofs, stepped gables, windows, sheds, fences, barrels);
  `buildings_gdl.py` and `buildings_to.py` — the Duchy's and the Order's buildings.
- `registry.py` — every asset by catalog id with its frame (units) or footprint (buildings).
- `render.py` — renders three passes and packs them into `art/sprites`:
  - `color` — the sprite with alpha;
  - `team` — only the TEAM surfaces, lit and white; the game multiplies it by the player colour;
  - `shadow` — the ground shadow alone, drawn first at 70 % so it never covers neighbours.
  Units: `units/<id>/{color,team,shadow}.png` + `sheet.json` (frame, pivot, rows per animation;
  row offset = facing) + `pick.json` (the rectangle around the figure in each frame, so a click anywhere
  on it picks the unit; `render.py` writes it, `python3 -m tools.art.pick art/sprites [id ...]`
  rewrites it from the sheets). Buildings: `buildings/<id>_<stage>_<pass>.png`, trees: `trees/<id>_<pass>.png`,
  map props: `props/<id>_<pass>.png`; each with `<id>.json` (`size`, `pivot` = centre of the
  footprint, `scale`, `cells`). Trees and props have no team pass.

The game reads them through `game/world/SpriteDB`; ids without art keep their placeholders.
`UnitView` plays walk while moving, else attack once after each blow (`last_attack`), else work
at a job, else idle, turned to the target or the work. `--add` renders only the animations a
sheet lacks and copies the old rows back, so a new animation does not re-render the rest.
Building frames are rendered large and cropped to what all stages cover. Unit frames: 160×144
on foot (160×216 the monk with his raised icon, the Crown's priest with his cross and the Hussite
with his flail, 288×216 the drab and the Söldner with their pikes, 224×144 the handgunners), 224×256 mounted (an upright lance), 224×176
big beasts, 320×240 the wagons, the bombard and the guns, 384×288 the river boat; `bar_y` in `sheet.json` is where the HP bar goes.

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
- `make_tileset.gd` — after new terrain art, writes the ground TileSet `art/tiles/ground.tres`
  (one atlas source per terrain, terrain set 0) used by the game and the map editor
  (`tools/maps/map_editor.tscn`): `godot --headless -s tools/art/make_tileset.gd`.
- `make_frames.gd` — after rendering units, writes `art/sprites/units/<id>/frames.tres`, the
  SpriteFrames the unit scene plays: `godot --headless -s tools/art/make_frames.gd [-- <id> ...]`.
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
