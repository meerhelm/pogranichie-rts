# Recorded replays

Each `.json` here is a recorded game: seed, rules version (`sim_version`), catalog version
(`data_version`), map size, commands and state hashes every `checkpoint_every` ticks.
`tests/integration/test_determinism.gd` and the CI step "Recorded replays" play every file back
and fail on the first checkpoint whose hash differs, on Linux and Windows alike.

| File | What it is |
| --- | --- |
| `m2_fuzz_1000.json` | 1000 ticks of random spawn/move/stop/remove orders for two players (seed 1, fuzz seed 2) |

## When a replay fails

- `data_version` differs: the catalog numbers changed (re-export of `data/`).
- Hash mismatch with the same `data_version`: either a rule changed on purpose or the sim is not
  deterministic. Run the same replay twice and on another OS before deciding which.

Re-record only when the change is intended, in its own commit that says why the result changed:

```sh
$GODOT --headless -s tools/sim/sim_cli.gd -- record --seed 1 --fuzz-seed 2 --ticks 1000 \
  --out tests/replays/m2_fuzz_1000.json
```
