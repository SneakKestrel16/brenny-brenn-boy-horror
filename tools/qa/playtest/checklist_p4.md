# Playtest checklist (DD Phase 4, STOP 5)

Run order for the Phase 4 sessions. Rules and reasons are [doc 09](../../../docs/09_playtest_plan.md)
s2 (session rules), s3 "DD Phase 4" (the gate rows) and s4 (measures). Doc 01 "Build Plan", Phase 4:
the simulator hits its targets, teams sometimes win and sometimes lose, and the logs land within 15
points of the sim. D-068 carries every Phase 3 row and every older measure still unproven
([checklist_p3.md](checklist_p3.md)); they are folded in below so one set of sessions covers both.

Why humans: P4-18 ran 14 bot seasons (6 full before and 6 after the bot fixes, 2 short). All 14 were
lost, and `tools/sim/sim.py compare` failed 15 of 21 dawns. Bots die nearly every night and spend every
coin on seed (production/handoffs/P4-18.md). A bot team is not a median team, so only human seasons can
pass the win/loss and the 15-point rows. The P4-18 gate verdict is FAIL pending the bot/economy fixes
and a season re-run; run these sessions on a build that has those fixes.

## Sessions

| # | Players | Length | Host flags (beyond Host.bat's) | Covers |
|---|---|---|---|---|
| 1 to 6 | 2, 3 and 4 (at least two seasons each) | full season (8 days) | `--body=<id>`, a different body each session | win/loss, sim compare, carried rows |
| 7 | 4, one leaves before dawn 2 | full season or until dawn 4 | none | saving, joining, leaving (debt 1,135, first payment 223) |
| 8 | 5 or 6 | full season | none | D-088 retune (5p/6p), sim compare at 5p/6p |
| 9 | any | short season | `--short-season` | Harvest Moon, Prize Pumpkin, the cart |

Sessions 1 to 6 can double as 7 to 9 when they meet those rows. A full season is about 3 to 4 hours
at doc 01 phase lengths, so expect several evenings; a team may stop at a dawn and resume (session 7
row) and that season still counts. One session per player count has a tester who has not read doc 01
(doc 09 s2); not the same fresh tester twice.

Host.bat takes no extra arguments. For a flag, open a terminal in the build folder and run
`"Brenny Brenn Boy Horror.exe" -- --host --lobby --phase1 --dev --port=45120 <flags>` (Host.bat's own
line plus the flags). The short season has no lobby pick (OPEN_ISSUES "Found at the P4-12 review" item 2).

## Before

- [ ] Build: the zip from `uv run tools/qa/package_playtest.py` (build id printed, goes in the notes).
      Others run `Join.bat` plus the host's Tailscale address (D-024).
- [ ] Real mics; do not pass `--voice-setting=off`. Everyone records lobby lines in the barn.
- [ ] Headphones on every tester (model noted, Windows spatial sound off).
- [ ] Consent asked for any recording. Notes say "tester A/B/C/D", never names.
- [ ] Observer: `uv run tools/qa/playtest.py new --session <n> --networks different --fresh B --smoke`;
      `g` + Enter when the match starts.
- [ ] Notes: player count, difficulty, body (`--body=` value or "seeded"), build id.

## Phase 4 gate (doc 09 s3 "DD Phase 4")

| Doc 09 row | Make it happen | Pass | Ticked |
|---|---|---|---|
| The simulator hits its targets | `uv run tools/sim/sim.py --players 2,3,4,5,6` (Game Designer) | First clear about 85%, final 55 to 70%, spread at most 10 points (doc 01 "Season simulator"). P4-18 measured 2p 87.5/62.1, 3p 85.2/58.8, 4p 84.8/62.2 (2,000 runs, seed 1) | [x] (P4-02, P4-03, D-088) |
| Teams sometimes win and sometimes lose | Play sessions 1 to 6 to the final dawn; plan to save for the final payment | At least one `season_awards_shown` with `lost:false` and one with `lost:true` | [ ] |
| Logs land within 15 points of the sim | After the seasons: `uv run --no-project python -I tools/sim/sim.py compare logs/qa/<session>/user_logs ...` (all host files at once) | Every dawn 2 to 8 `ok` for each player count with a season; first and final clear rates are printed, not gated | [ ] |
| Saving, joining and leaving | Session 7: 4 players start; one quits before dawn 2. Later: the host quits at a dawn, another farmhand loads the season (main menu "Load Season") and the rest rejoin | `debt_rescaled` to 1,135 total with first payment 223 (doc 01 "Joining and leaving"); `net_peer_left`, `net_host_left`, `save_written`; resumed play starts at the last dawn save with the same coins, plots, debt and body | [ ] |
| 5p and 6p retune (D-088) | Session 8 | Season ends with a payment result; `sim.py compare` reports the 5p/6p rows; tester notes on whether the field felt big enough | [ ] |
| Harvest Moon and the cart (P4-12) | Session 9: plant the Prize Pumpkin early, lift it on the Harvest Moon, load and push the cart out the gate | `cart_out loaded:true`; `pumpkin_payout` paid; the final payment uses it. Bots never did this (OPEN_ISSUES "Found at the P4-12 review" item 1) | [ ] |

## Carried rows (D-068: checklist_p3 and older, still unproven)

| Row | Make it happen | Pass | Ticked |
|---|---|---|---|
| The dead stay engaged (DD Phase 3) | Let one tester die on night 1 | Stays connected to the dawn; uses flicker, crow, rustle or static talk; says there was something to do | [ ] |
| The living argue over a static voice (DD Phase 3) | The dead tester talks; a lure in their voice plays at night | One spoken "was that really them?"; one tester used the lantern flicker to settle it | [ ] |
| Someone laughs at the Dawn Report (DD Phase 3) | Read the report at every dawn | Observer logs a laugh (timestamp) | [ ] |
| AI Director, day arc, jumpscares | Work the fields by day; stay out at night | No scare in the first third of a day; testers name a scare by day | [ ] |
| Taint and Shaken | Touch leavings or a stolen tool; wash at the well; get jumpscared | Stain and heartbeat seen and heard; washing cures; Shaken slows the sprint and does not Taint | [ ] |
| Whistle at 30 m and 72 m | OPEN_ISSUES "Found in P3-11" item 1 procedure, 6 trials per distance | At least 4/6 at 30 m and 3/6 at 72 m; `check_logs.py` prints the mean angle error per cell | [ ] |
| Four bodies by sound (doc 01 Open Issue 4) | One body per session via `--body=boar`, `gaunt`, `husk`, `scarecrow` | Tester names the body by sound alone, or says they could not | [ ] |
| Recorded voice fools someone (DD Phase 2) | A teammate's line plays from the field at night | Walks toward it or says fooled; log `worked` on a `clip` lure | [ ] |
| Trap sweeps (DD Phase 2) | Two fields with corn between | Testers sweep unprompted after the first sprung trap | [ ] |
| Phase 1 lure rate | Across all sessions | At least 20 `lure_result`; rate at least 30% (doc 09 s3 DD Phase 1) | [ ] |
| CEO static listen and P4-17 listen list | The CEO, alone, headphones: the six items in production/handoffs/P4-17.md "CEO listen list" | CEO writes pass or redo per item in QUESTIONS.md | [ ] |
| 4-talker bandwidth | Four testers talk at once for 30 s at night | No voice drop-outs reported; host upload in Task Manager noted | [ ] |

Observer also counts screams, laughs and bored silences with a timestamp.

## Debrief (10 min, after play, doc 09 s2)

1. When did you feel safest? Least safe?
2. When did you last doubt a voice? Why? Did a dead teammate's voice ever fool you?
3. What did you do when you heard something in the corn?
4. What were you doing when you were bored? (Dead testers: what did you do as a ghost?)
5. What was the funniest moment? What in the Dawn Report made you laugh?
6. What did the creature sound like? Was it the same creature as last time?
7. **Add:** when did you know you would make (or miss) the payment? Did the debt feel fair for your
   team size?

## After

- [ ] Each remote tester runs `send_logs.bat`; save the zips to Downloads.
- [ ] `uv run tools/qa/playtest.py auto --testers A,B,C --fresh B`, then
      `uv run tools/qa/check_logs.py logs/qa/<session>/user_logs`.
- [ ] `uv run --no-project python -I tools/sim/sim.py compare <every session's user_logs>`; paste the
      table in the session notes.
- [ ] Scare rules PASS, no "Taint right after Shaken" flag, no "BEFORE OPENS_DAY" line.
- [ ] Hand-count five lines of each Phase 4 measure against the checker (doc 09 s4 check-your-checker).
- [ ] Problems into `production/OPEN_ISSUES.md`.
