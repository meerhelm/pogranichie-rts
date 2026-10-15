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
```

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
