# Recorded replays

Each `.json` here is a recorded game: seed, rules version (`sim_version`), catalog version
(`data_version`), map size, commands and state hashes every `checkpoint_every` ticks.
`tests/integration/test_determinism.gd` and the CI step "Recorded replays" play every file back
and fail on the first checkpoint whose hash differs, on Linux and Windows alike.

| File | What it is |
| --- | --- |
| `m2_fuzz_1000.json` | 1000 ticks of random spawn/move/stop/remove orders for two players on open grass (seed 1, fuzz seed 2) |
| `m3_samogitia_fuzz_1000.json` | The same kind of orders, with formations, on `map_proto_samogitia` (seed 1, fuzz seed 3) |
| `m5_samogitia_economy_2000.json` | 2000 ticks with the economy: both players join with town centres and peasants, then gather, build, wall, repair, assault, queue, cancel and set rally points among the other orders (seed 1, fuzz seed 4, `--economy 1`) |
| `m7_samogitia_magic_3000.json` | 3000 ticks of the same with magic: units take and retake places of power, shrines are ordered on them and spells cast (seed 1, fuzz seed 5, `--economy 1 --magic 1`) |
| `m9_gdl01_playthrough.json` | `MissionBot` plays the campaign mission «ВКЛ 1. Жемайтский огонь» (normal) from the start to victory, 61 701 ticks (51:25); checkpoints every 200 ticks. The test also requires the mission to end in victory |
| `gdl02_playthrough.json` | `GrunwaldBot` plays «ВКЛ 2. Грюнвальд, 1410» (normal) from the start to victory, 12 351 ticks (10:17); checkpoints every 200 ticks. Also required to end in victory |
| `gdl03_playthrough.json` | `BaptismBot` plays «ВКЛ 3. Крещение, 1413–1417» (normal) from the start to victory, 27 801 ticks (23:10); checkpoints every 200 ticks. Also required to end in victory |
| `gdl04_playthrough.json` | `VilkomirBot` plays «ВКЛ 4. Вилькомир, 1435» (normal) from the start to victory, 18 001 ticks (15:00); checkpoints every 200 ticks. Also required to end in victory |
| `gdl05_playthrough.json` | `VedroshaBot` plays «ВКЛ 5. Ведроша, 1500» (normal) from the start to victory, 19 851 ticks (16:32); checkpoints every 200 ticks. Also required to end in victory |
| `gdl06_playthrough.json` | `WolfTrailBot` plays «ВКЛ 6. Волчья тропа, 1507» (normal) from the start to victory without raising the alarm, 13 711 ticks (11:25); checkpoints every 200 ticks. Also required to end in victory |
| `gdl07_playthrough.json` | `SlutskBot` plays «ВКЛ 7. Слуцк, 1508» (normal) from the start to victory: the walls held, the workshops burned in a sortie through the secret passage, the night assault beaten back, 32 131 ticks (26:46); checkpoints every 200 ticks. Also required to end in victory |
| `gdl08_playthrough.json` | `OrshaBot` plays «ВКЛ 8. Орша, 1514» (normal) from the start to victory: both bridges laid at night without the alarm, the court banners held, the false retreat onto the hidden guns, Chelyadnin taken and the Muscovite camp stormed, 19 931 ticks (16:36); checkpoints every 200 ticks. Also required to end in victory |
| `crown01_playthrough.json` | `CrownGrunwaldBot` plays «Корона 1. Грюнвальд, 1410» (normal) from the start to victory: waits out the heat in the grove, meets the Order's right wing, rides Jaśko to the fallen great banner, calls «The Pact» against the Grand Master's reserve by the king's hill and storms the wagenburg, 18 871 ticks (15:43); checkpoints every 200 ticks. Also required to end in victory |
| `crown02_playthrough.json` | `MalborkBot` plays «Корона 2. Мальборк, 1410» (normal) from the start to victory: four batteries east of the castle out of its towers' reach, the town wall, the guard against the night sorties of the Gdańsk shipmen and the forge for the spiked guns, the lances with the towns' envoys, the lazaret against the plague and the bombards to Sztum, 26 281 ticks (21:54); checkpoints every 200 ticks. Also required to end in victory |
| `crown03_playthrough.json` | `BalticBot` plays «Корона 3. Балтийская вода, 1433» (normal) from the start to victory: the wagons out of the Chojnice trenches, a wagenburg at each of the four camps, the monks of Pelplin led out, the orphans paid twice, the suburb of Tczew fired from the west so the wind carries the fire to the gate, the prisoners brought to Mikołaj, the villages foraged before the orphans, three banners knighted on the shore and the stranger at the boulder, 18 311 ticks (15:15); checkpoints every 200 ticks. Also required to end in victory |

## When a replay fails

- `data_version` differs: the catalog numbers changed (re-export of `data/`).
- Hash mismatch with the same `data_version`: either a rule changed on purpose or the sim is not
  deterministic. Run the same replay twice and on another OS before deciding which.

Re-record only when the change is intended, in its own commit that says why the result changed:

```sh
$GODOT --headless -s tools/sim/sim_cli.gd -- record --seed 1 --fuzz-seed 2 --ticks 1000 \
  --out tests/replays/m2_fuzz_1000.json
$GODOT --headless -s tools/sim/sim_cli.gd -- record --seed 1 --fuzz-seed 3 --ticks 1000 \
  --map map_proto_samogitia --out tests/replays/m3_samogitia_fuzz_1000.json
$GODOT --headless -s tools/sim/sim_cli.gd -- record --seed 1 --fuzz-seed 4 --ticks 2000 \
  --map map_proto_samogitia --economy 1 --out tests/replays/m5_samogitia_economy_2000.json
$GODOT --headless -s tools/sim/sim_cli.gd -- record --seed 1 --fuzz-seed 5 --ticks 3000 \
  --map map_proto_samogitia --economy 1 --magic 1 --out tests/replays/m7_samogitia_magic_3000.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --out tests/replays/m9_gdl01_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_02 \
  --out tests/replays/gdl02_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_03 \
  --out tests/replays/gdl03_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_04 \
  --out tests/replays/gdl04_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_05 \
  --out tests/replays/gdl05_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_06 \
  --out tests/replays/gdl06_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_07 \
  --out tests/replays/gdl07_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_08 \
  --out tests/replays/gdl08_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission crown_01 \
  --out tests/replays/crown01_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission crown_02 \
  --out tests/replays/crown02_playthrough.json
$GODOT --headless -s tools/sim/sim_cli.gd -- mission --mission crown_03 \
  --out tests/replays/crown03_playthrough.json
```

The mission replay is recorded by the bot, so a change to the mission, its map or the rules can
make the bot lose; then the command fails and the bot (`tools/sim/mission_bot.gd`) needs work.

History: both re-recorded for `sim_version` 2 (M3: terrain, A*, flow fields, formations,
separation; replay format 2 adds `map_id`).
Then for `sim_version` 3 (M4: combat and morale; the fuzzer now also attacks, sets stances and
rally points, and data adds `rules/combat.tres`, so `data_version` changed too).
Then for `sim_version` 4 (M5: economy; the commands are unchanged, the hashes now include
players, buildings, resources and per-unit work, units carry tech bonuses, map deposits block
their cells, and `data_version` changed with `rules/economy.tres`, building sizes and tech
effects). `m5_samogitia_economy_2000.json` is new.
Then for `sim_version` 5 (M6: fog of war; units pick fights only with enemies their side sees,
units in the forest are seen only from 2 cells, the hashes include every player's explored
cells, and `data_version` changed with `rules/vision.tres`, building sight and «Караулы»).
Then for `sim_version` 6 (M7: places of power, Сила, spells and healers; the hashes include
places, Сила, cooldowns, effects and each unit's last attack, and `data_version` changed with
`rules/magic.tres`, spell tags and the healer and reliquary techs). `m7_samogitia_magic_3000.json`
is new.
Then for the catalog's balance edits after calibration (same `sim_version` 6, new `data_version`:
spearman and knecht bonuses against cavalry, the crossbow's bonus against spearmen, samogitian
and light horse costs, light horse damage). The economy fuzzer's orders depend on what players
can pay, so its commands changed as well.
Then for `sim_version` 7 (M8: skirmish victory and per-player statistics in the hashes, and
`data_version` changed with `rules/skirmish.tres`).
Then for `sim_version` 8 (M9: fire, heroes' own auras, mission locks and rules in the hashes,
and `data_version` changed with `rules/fire.tres`, the heroes of the campaign and the wooden and
fireproof tags). The fuzzer picks unit types from the prototype catalog, which now has the four
heroes of «ВКЛ 1», so the spawn orders changed too. `m9_gdl01_playthrough.json` is new.
Then for `sim_version` 9 (M10: path searches and flow fields run in slices of at most
`PATH_BUDGET` expanded cells a tick instead of one whole search per tick, so units start walking
on different ticks; the hashes include the open search and the flow fields still being built).
The bot now wins «ВКЛ 1» at 40:18.
Then for `sim_version` 10 (taking own buildings apart: the `DISMANTLE` order, salvage piles only
their owner picks up, and `data_version` changed with the dismantling rules in
`rules/economy.tres`). The fuzzer now also orders peasants to take buildings apart.
Then for `sim_version` 11 (towers and gates shoot).
Then for `sim_version` 12 («ВКЛ 3»: the `CHOOSE` command, spies nobody strikes without an
order, places of power that go out; `data_version` changed with the church, the Samogitian
footman and the mission's new units in the prototype catalog). The fuzzer picks unit types from
the prototype catalog, so its spawn orders changed too. `gdl03_playthrough.json` is new.
Then for `sim_version` 13 («ВКЛ 4»: the marching column, captives, the spared hero's HP floor,
camp supply and raids in the hashes; `data_version` changed with the mission's heroes and the
field camp in the prototype catalog). The fuzzer picks unit types from the prototype catalog, so
its spawn orders changed too. `gdl04_playthrough.json` is new.
Then for `sim_version` 15 («ВКЛ 5»: the bridge, the ford, the men brought back and the
Muscovite waves in the hashes; `data_version` changed with Muscovy and the mission's units in the
prototype catalog and the icon's morale floor). `gdl05_playthrough.json` is new.
Then for `sim_version` 16 («ВКЛ 6»: the watch, the detection meter and alarms, day and night,
the horses, hidden places of power and open trails in the hashes; `data_version` changed with the
mission's units, Muscovite buildings and «Волчья тропа» in the prototype catalog).
`gdl06_playthrough.json` is new.
Then for `sim_version` 17 («ВКЛ 7»: ladders, castle belts, wall bonuses, the townsmen's water,
the princess, starvation, the posad, boats, the secret passage, ladder workshops and fire arrows
in the hashes, and fires that do not spread to the walls; `data_version` changed with the
mission's units, the log wall and the light gun in the prototype catalog). The fuzzer picks unit
types from the prototype catalog, so its spawn orders changed too. `gdl07_playthrough.json` is
new.
Then for `sim_version` 18 («ВКЛ 8»: bridges laid section by section, the night patrol and its
alarm, the held ambush deaf to its player's orders, the false retreat to the rally point, the
chase, the Kropivna and the captive commander in the hashes; `data_version` changed with the
Crown's mercenary foot, field gun and hussars, the service Tatars and the mission's heroes in the
prototype catalog). The fuzzer picks unit types from the prototype catalog, so its spawn orders
changed too. Every mission bot wins at the same tick as before. `gdl08_playthrough.json` is new.
All re-recorded for `sim_version` 20 (the Crown as a skirmish faction: tabor rings, pavises, the
tiring lance, the foot servant, the bombard's battery, the chapel flag of buildings, salt works and
the salt springs on `map_proto_samogitia`, the Crown's spells; `data_version` changed with the
Crown's units, buildings, techs and spells in the prototype catalog). The fuzzer picks unit types
from the prototype catalog, so its spawn orders changed too. Every mission bot wins at the same
tick as before.

Re-recorded for «Корона 1» (no `sim_version` change; `data_version` changed with the seven heroes
of the mission, Jaśko, Zyndram, Marcin, Oleśnicki, Jagiełło, the stranger and Lichtenstein, in
the prototype catalog with their factions). `crown01_playthrough.json` added.

Re-recorded for «Корона 2» (`sim_version` 21: MissionBesiege, the building HP floor, the spiked
bombard, a camp kept from healing, campaign-only buildings a mission allows; `data_version`
changed with the shipman's rules, the Order's brick wall, the lazaret, Plauen and the towns'
envoys in the prototype catalog). `crown02_playthrough.json` added.
