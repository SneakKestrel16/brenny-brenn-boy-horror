# Playtest checklist (DD Phase 5, STOP 6)

What to try at STOP 6. Phase 5 has no measured gate: it is done when the CEO says so (Q-250). Rows and
log measures: [doc 09](../../../docs/09_playtest_plan.md) s3 "DD Phase 5". Carried, still unproven:
[checklist_p4.md](checklist_p4.md) (D-148 waived the human-session and sim-compare rows for STOP 5;
they stay open here).

## Sessions

| # | Players | Host flags (beyond Host.bat's) | Covers |
|---|---|---|---|
| 1 | 2 to 4 | `--short-season` | Win a short season, then next season through the lobby: carry-over, trait, cosmetics |
| 2 | 3 or more | lobby: Quirks on | Quirks: each player guesses the others' quirks at the end |
| 3 | 3 or more | imposter dev setting (gated host only, D-044) | Imposter mode, the reveal |
| any | any | `--log-farm` | Doors, held tools, window glow, road lamps, perched crows |

Build, mics, headphones, consent and observer steps: [checklist_p4.md](checklist_p4.md) "Before".

## What to try

| Try | Looks right when | Ticked |
|---|---|---|
| Win season 1, press next season on the Season Awards | Everyone is back in the lobby, picks roles again, lobby says "Season 2"; season 2 starts with the upgrades and plots kept and savings = 25% of the spare coins (cap 60); `ui_season_start_sting` plays once | [ ] |
| Season 2's first dawn | The Dawn Report prints the new creature trait line once and plays `ui_trait_gained`; a reload from the season-start save prints it once, a dawn-save reload does not | [ ] |
| Store before and after the debt is paid | Hats and overalls refused before, sold after (`ui_cosmetic_buy`); every peer sees them; kept after save/load and in season 2; no speed or light change | [ ] |
| Talk a lot on days 1 to 3 | Day 4 on, some lures splice live words; joins sound like the speaker (CEO's ear) | [ ] |
| Quirks on | Each player gets one; only they are told; nothing flashes | [ ] |
| Imposter on | Nobody's screen or sound gives the imposter away before the reveal; the reveal plays `ui_imposter_reveal`; the imposter never kills | [ ] |
| Close the barn door at night with a teammate inside; a teammate joins late | The door stops farmhands, not the Creature; the late joiner sees it closed; all doors open at day start | [ ] |
| Dev toys (gated host only, Q-261) | Each toy looks and sounds right; safe mode holds (OPEN_ISSUES "Found at the P5-10 review") | [ ] |
| Look around the farm at night | Window glow with the generator on, road lamps lit, crows perched, hoe in hand while planting, whistle on whistling; nothing flickers except ghost lights | [ ] |

## After

`uv run tools/qa/playtest.py auto`, then `uv run tools/qa/check_logs.py logs/qa/<session>/user_logs`.
CEO verdict goes in DECISIONS; problems in `production/OPEN_ISSUES.md`.
