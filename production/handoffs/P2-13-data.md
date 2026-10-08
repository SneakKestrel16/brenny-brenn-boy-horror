# P2-13 (Game Designer part): 5 and 6 players

## Done
- `data/player_scaling.json`: `pct_by_players` 5 = 120, 6 = 140, `max_players` 6; per-key `sources` (2 to 4 `doc01`,
  5 and 6 `placeholder`). Schema updated to match (also copied into doc 02 A.8).
- Every headcount reader goes through `Data.scaled`, so no other data file changed. Values (ceil):
  - Debt 1,560 / 306 / 1,254 (5p), 1,820 / 357 / 1,463 (6p); `pct_d` formula unchanged.
  - Medical bill 30 / 60 / cap 144 (5p), 35 / 70 / cap 168 (6p); cap bites at 3 deaths.
  - Prize Pumpkin 300 / 180 / 90 / 24 (5p), 350 / 210 / 105 / 28 (6p).
  - Disturbances days 1 to 7: 2,2,3,3,4,4,5 (5p); 2,2,3,3,5,5,6 (6p).
  - Traps bear / pit / bells, days 1 to 6: 5p 3/2/0, 3/3/0, 4/3/0, 4/3/2, 5/4/2, 6/4/3; 6p 3/2/0, 3/3/0, 5/3/0, 5/3/2, 6/5/2, 7/5/3 (bells still disabled).
  - Per-player values (moonflower bed, `plots_per_player`, `store.json` `per_player`) grow with headcount; roles have no headcount rule; field stays 16 plots.
- Doc 02 updated: s4 (rule, range 2 to 6, "above 4" paragraph), s6, s7.1/7.2, s8, s11 (5p/6p table), s17.2, A.8.
  Doc 03 untouched (no number moved).
- `tools/sim/projection.py` (the only sim; `sim.py` does not exist yet) takes 5 and 6 and runs both.

## Numbers vs doc 01 targets (projection, not the simulator; 4p untouched)
Rough median margin: 5p -213 (17% of final), 6p -375 (26%), 4p -107 (10%). Perfect: +195 and +116.
5p and 6p are poorer than 4p because the field is 16 plots (income stops growing) while debt scales 120% / 140%.
Settled only by the real simulator (target: first payment ~85%, final 55 to 70%, spread <= 10 points).

## For CEO (not applied)
If the simulator confirms, levers are more field plots at 5 and 6 (doc 01 change) or lower percentages above 4.

## Checks
All 11 data files validate against their schemas (jsonschema 4); `uv run tools/qa/smoke.py` SMOKE PASS.
Gameplay must read `max_players` from `player_scaling.json` (P2-07); `Data.scaled` already handles keys "5" and "6".

## Follow-up: field plots scale with headcount (CEO request after D-038)
Rule (all `placeholder`): field grows 4 plots per extra player above 4. Start 16/16/16/20/24 and bought-plot
ceiling 24/24/24/28/32 at 2/3/4/5/6p. Below 4 nothing changes (ceiling stays 24; the starting 16 is not
scaled down, only planted plots are). `plot_pair` stays 40 for 2 plots; 4 pairs to buy at every count.
Data: `player_scaling.json` `field_plots_start_by_players`, `field_plots_max_by_players` (+ schema, doc 02 A.8);
`season.json` `field_plots_start`/`field_plots_max` stay the doc 01 4p values (P2-07 must read the per-count tables).
Doc 02 updated: s4, s5 (Plots), s10 table, s17.2. Not edited: doc 01, doc 04, game/, TASKS.md.

Projection (rough median margin / perfect margin): 6p -35 / +418 (was -375), 5p -47 / +349 (was -213),
4p -107 / +274 (unchanged), 3p -203 / +169, 2p -293 / +58. 5p/6p now slightly easier than 4p (3.7% and 2.4% of final vs 10%);
the real simulator should trim via the 120%/140% placeholders. Ceiling-only growth (start 16) does nothing for the
median team (plants 4 per player), which is why the start scales too. 2p/3p shortfall is still outside the 10-point spread (pre-existing).
Checks: player_scaling validates; `uv run tools/qa/smoke.py` SMOKE PASS.

### Note for Level Designer (doc 04 space check is yours)
Farm needs up to 24 starting plots and 32 at the ceiling (6p), up from 16/24: +8 plots at both ends. Suggest the
two fields grow in place: 16 plots are always present; the extra 4 (5p) / 8 (6p) starting plots plus the 8 bought ones
should be authored as an "outer ring" of plot sites per field that stays hidden/locked below the headcount threshold.
Bought plots (4 pairs) open the next sites; at 5p/6p the first 4 / 8 of the 16 extra sites are open at start. Total
authored sites: 32. Keep the moonflower bed separate (1 per player, 6 max). Check walking time: the P = 6 plots/player labor
number assumes 3 m spacing.

### Proposed doc 01 wording (Director applies)
- Crops, plots: "16 plots at the start, up to 24 with upgrades at 4 players; above 4 players the field grows by 4 plots per
  extra player (20 at 5 players, 24 at 6; up to 28 and 32 with upgrades)."
- Store, "New plots (to 24)" -> "New plots (to 24; to 28 at 5 players, 32 at 6)."
