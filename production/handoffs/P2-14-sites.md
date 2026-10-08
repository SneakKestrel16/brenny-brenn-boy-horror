# P2-14 sites (Level Designer)

D-039: 32 field plot sites now authored in `game/world/farm.tscn` (via `game/world/build_farm.py`). `farm_phase1.tscn`
unchanged apart from earlier spawn markers (field A only, no headcount rows); loads for `--phase1`.

## Metadata format Gameplay reads
All plots are `Marker3D` in group `plot_spots` (moonflower bed too, unchanged). Existing 24 field plots (Plot01..24)
keep names, positions, `field` ("a"/"b") and `upgrade` metadata. New: Plot29..Plot32 (field a, north row z -11.5,
x 25.5/28.5/31.5/34.5) and Plot33..Plot36 (field b, south row z 0.5, x 67.5/70.5/73.5/76.5). Each carries:

| key | type | meaning |
|---|---|---|
| `extra` | bool | true = headcount site. Absent on Plot01..28. Read with `get_meta("extra", false)`. |
| `min_players` | int | 5 or 6: site exists only when headcount >= this. Absent on non-extra plots. |
| `extra_order` | int 1..4 | position in the row, left to right. Inner two (2, 3) have `min_players` 5; outer two (1, 4) have 6. |
| `upgrade` | bool | always false on extras (they are never bought). |

## How the counts fall out (player_scaling.json)
- Bought plots are always the 8 `upgrade = true` plots (4 pairs), so start + bought = ceiling holds: 16+8, 20+8, 24+8.
- Start plots open = non-upgrade field plots (16) + extras with `min_players <= headcount` (0 / 4 / 8 at 4 or fewer / 5 / 6).
- Extras below their headcount stay closed and are not sellable. Sum of authored sites: 16 + 8 + 8 = 32 (+4 moonflower).
- Pair the extras by `extra_order` if the store must open a specific order (not needed: all extras open at match start).

## For Gameplay (not done here)
`game/farming/farm.gd` `_ready` locks only `upgrade` plots; until it also locks `extra` plots with `min_players > headcount`, every
extra plot is open at every headcount (2p sees 32 open). Plots `locked`: also check `Game.full_farm`; phase 1 has no extras.

## Checks
- `check_farm.gd`: PASS (36 `plot_spots`, field centres still computed on the 12-plot grid via `extra`, all doc 04 s8 distances unchanged).
- Headcount rows: 12.7 m max between plot centres in one field (was 10.8, still under 15 m lure rule), 6 m from corn (A), 14 m (B),
  28 m nearest to the barn door, > 40 m from the town stand sanctuary, clear of the cart route (z -14 vs row edge -13 for A is not near it; B's row is on the opposite side).
- Doc 04 s5.1, s8.2, s13 and the SVG updated.
