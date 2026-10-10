# CEO review, overnight batch of 2026-10-10

Written by the Director while the CEO was away (about 8 hours). Everything that needs your decision is in
section 1. Section 2 lists every change, with the commit and the command that undoes it. Section 3 holds
test results and what was done about them.

**How to revert anything:** each task is one commit on `main`. Run `git revert <commit>` in the repo, then
push. Where a change is behind a setting or data flag, the flag is named, so you can switch it off
without a revert.

## 1. Decisions for you

| # | Question | Default we went with | Where |
|---|---|---|---|
| D-1 | Day full-body visibility of the creature (Q-345) | Unchanged | QUESTIONS.md Q-345 |
| D-2 | Doc 11 section 7 lore questions | Text in game stays placeholder | docs/11 s7 |
| D-3 | The P5-43 whisper is only a dev trigger. Should it happen in play? | Dev trigger only | P5-43 handoff |
| D-4 | The well is about 10 m off the A-B line. Moving it onto the line cuts corn strip 3 | Well stays | P5-47 handoff |
| D-5 | 15 emotes go beyond doc 01's list of 4 (8 added in P5-60: salute, jig, cross_arms, look_around, bow, flex, yawn, shiver) | Kept | data/emotes.json |
| D-6 | Nuke radius 60 m is a placeholder | 60 m | dev_toys.gd |
| D-7 | Crowkeeper role: approve the new Roles row; numbers are placeholders (Q-352) | Built as specced | P5-52 |
| D-8 | Horror role: you picked "flickering light", but doc 01 says only ghosts flicker lights. Built as dimming only (Q-349) | Dimming, no flicker | P5-53 |
| D-9 | Horror role: four exceptions to doc 01's hallucination rules (Q-350, doc 03 s23.1) | Built, placeholder | P5-53 |
| D-10 | Horror role: the "name whisper" replays the player's own recorded clip, not their actual name (only if their voice setting allows) | Own clip | P5-53 |
| D-11 | "Walking through closed doors": who did you see? Tests show players cannot pass a closed door (2310 tries, 0 passes). Found and being fixed: the creature walked through a closed barn door after banging; open door leaves had no collision; the pegboard could be used through the shed wall; bots (only with --bot-chores) crossed the barn wall | All four fixed in P5-55 (4c229d3) | P5-55 handoff |
| D-12 | If a player shuts the door again right after the creature opens it to leave, the creature still walks through the shut door (it ignores door collision, P5-27). Should a shut door ever hold the creature in or out? | It ignores door collision, as built in P5-27; it bangs and opens the door in normal play | creature.gd `_bang_first`, P5-55 QA round 4 |
| D-13 | Smarter creature makes the game easier for bots (Q-356). It now lurks and walks through corn (open time 806 s to 129 s of a 900 s night), but corn muffles its hearing and keeps it away from where players work. Bot seasons, seeds 1-6, old vs new: deaths 23 to 7, finales lost 4 of 6 to 1 of 6 | New behaviour on. To soften, lower `lurk_open_cost_mult` in data/creature.json (0 = old behaviour); not yet measured | P5-56 handoff, Q-356 |
| D-14 | Different behaviour per creature body (Q-355)? Doc 01 says all bodies "hunt identically", so not built | Identical | Q-355 |
| D-15 | Whistle note: doc 11 says "shed shelf"; it is pinned on the shed back wall (P5-48) | Back wall | data/lore.json, P5-48 handoff |

## 2. Changes made (commit, what, how to revert)

| Task | Commit | What changed | Revert |
|---|---|---|---|
| P5-54 | 662d919 | test_roles: stale test fixed (debounce), no game change | `git revert 662d919` |
| P5-52 | 0c17cb6 | Crowkeeper role: bait perches that flush crows when anything moves near (D-7) | `git revert 0c17cb6` |
| P5-53 | 9aa255b | Horror role: darker world and private scares for that player only (D-8, D-9, D-10) | `git revert 9aa255b` (test_roles count also covers P5-52; fix by hand if reverting only one) |
| P5-50 | 80a94c9 | Warm interior fill light in barn, farmhouse and tool shed; also fixes a P5-53 compile break in test_light_rig | `git revert 80a94c9` (reverting also brings back the test_light_rig break; revert 9aa255b too) |
| P5-55 | 4c229d3 | Doors: creature opens a shut door instead of walking through; open door leaves are solid; nothing usable through walls; bots use the barn doorway | `git revert 4c229d3` |
| P5-51 | eaa2284 | More corn inside the farm (weave blocks and nine new cover points) so the creature can move through it, not only round the edges | `git revert eaa2284` |
| P5-56 | 644a47b | Creature AI: lurks through corn on routes, waits in cover, avoids repeats, searches nearby cover after losing a chase, sets night traps on busy paths; stuck guard and Harvest Moon fix (D-13). Each of the five changes reverts by setting its number in data/creature.json to 0 | `git revert 644a47b` |
| P5-48 | a5dc8ce | Lore in game: road sign and bank notice at the gate, intro line, Courier masthead, ten notes on cards pinned to farm surfaces, archive clippings, win lines (D-15) | `git revert a5dc8ce` |
| P5-60 | 2b53fa1 | Eight more silent emotes and an inner ring on the emote wheel (D-5). Cut one by deleting its row in data/emotes.json | `git revert 2b53fa1` |
| P5-59 | f557099 | Weathered look on farm, buildings, props and creatures from a noise shader; scenes 5-12% darker, night yard 10% darker | `git revert f557099`, then delete .godot/imported/*.glb-* to reimport |
| P5-58 | 3f748d8 | Dev pick of the creature body: --creature-body=<id>, host-only lobby dropdown (DevGate), console creaturebody | `git revert 3f748d8` |
| P5-61 | f88ef4d | Every world sign is a plank board on posts; TOWN board moved onto the gate beam | `git revert f88ef4d` |
| P5-57 | a6f4912 | Bots route round walls, do chores by default, open doors, follow the cart; Director fake-outs skip bots. Each switch is a flag in the bots record of data/ai_director.json | `git revert a6f4912` |
| P5-62 | bcc1e78 | Full test sweep: 110 of 111 checks pass; three stale tests fixed, two issues filed | `git revert bcc1e78` |
| P5-64 | e8138ab | Barn sign board cut to a short summary, one fact per line, bigger font | `git revert e8138ab` |

## 3. Tests run and what we did

- **P5-53 QA (Opus): FAIL, fixed by Director.** grep_rules flagged the word "flicker" in two comment lines of `horror_scares.gd` (reworded); roles.json cited doc 03 s13.2 instead of s23.1 (fixed). After merge: import 0 ERROR, parse_check 211/0, grep_rules 0 violations, test_roles PASS, test_horror PASS.
- **P5-53 QA notes, not fixed:** silhouettes log `scare_applied` on the client with no host `scare` line (doc 05 s29 says `scare` is unused); lamp bulb glow is not dimmed, only light energy.
- **P5-50 interior fill re-QA (Opus): PASS.** Merged. Fixed at merge: the barn lantern got a second fill. Open notes: faint wash through barn walls (+6 to +10 brightness on 0-255); no automated test for the fill.
- **Resource cap.** You set 20% CPU / 20% RAM and max 3 agents. About 54 orphan Godot test processes from earlier runs (started around 05:00) use most of the CPU (about 80%) and 6.3 GB RAM. I am not allowed to kill them. To free the machine, run this in PowerShell (it also stops any test Godot an agent is running at that moment):
  `Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object { $_.CommandLine -match 'audio-driver Dummy' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }`
- **P5-55 doors: four Opus QA rounds, PASS.** Tests on main: import 0 ERROR, parse_check 215/0, door, leaf, bot-door, pick-through-wall and creature tests all PASS.
- **test_light_rig broke after P5-53** (LightRig needed the Game autoload); fixed in 80a94c9.
- **P5-51 corn: two Opus QA rounds, PASS.** Round 1 found the stalk test could never fail; fixed. Tests on main: import 0 ERROR, parse_check 217/0, grep_rules clean, check_farm PASS, check_corn_creature PASS, test_p5_51 PASS. Open (Q-354, AI task later): on bot nights the creature still spends most of the night in the open clearing (806 of 900 s); 8 of 15 stalk test points can't fail.
- **P5-56 creature AI: Opus QA PASS, merged with new behaviour on.** Tests on main: import 0 ERROR, parse_check 218/0, grep_rules clean, test_p5_56, test_p5_39 and door-walk PASS. QA notes, not fixed: the stuck guard only logs and does not free the creature from the pen fence (an old stall, logged up to 234 times in some seasons); a follow-up should route round fences.
- **Caps lifted (CEO, evening):** no agent or CPU/RAM limit. All paused work resumed in parallel: P5-48 lore (QA round 2 fixes), P5-57 bots, P5-58 creature pick, P5-59 textures, P5-60 emotes, P5-61 signs.
- **P5-48 lore: Opus QA round 2 PASS.** QA moved the shed_door card 13 cm off the shed corner. Tests on main: import 0 ERROR, parse_check 222/0, test_lore and test_data PASS, grep_rules 0 violations. Open: road sign posts have no collision (players walk through); the TOWN arch label overlaps the BRENN FARM board from the gate view (P5-61 to fix).
- **P5-60 emotes: Opus QA PASS (round 2, after flex and cross_arms poses were redone).** Tests on main: import 0 ERROR, parse_check 222/0, test_emotes PASS, grep_rules clean. Open: on day 1 the controls card covers yawn and facepalm on the wheel; the outer ring runs off screen at 640x360.
- **P5-59 textures: Opus QA PASS after a fix.** The import swap first also hit plots and traps (plot SCRIPT ERROR, trap glow lost); QA kept those on the old material. Tests on main after reimport: import 0 ERROR, smoke PASS, parse_check 222/0, light rig, creature art, farmer body PASS. Watch: night yard is 10% darker; check night readability in the next playtest.
- **P5-58 creature pick: Opus QA PASS.** QA fixed the body test script (it always exited 1) and made the console switch reach clients at once. On main: all four bodies PASS host + client, import 0 ERROR, parse_check 224/0, grep_rules clean. Open: --creature-body works without DevGate, like --body; body art is static (no rig).
- **P5-61 signs: Opus QA PASS after a fix.** QA moved the TOWN board onto the gate beam so it no longer covers the BRENN FARM sign. On main: import 0 ERROR, parse_check 224/0, check_farm, test_lore, smoke PASS. Open: the FIELD A board faces east-west, so strip 2 corn hides it from the west.
- **P5-57 bots and Director: Opus QA PASS.** 12-seed mean short at final payment 877 to 834, deaths 16 to 14; seed 3 is worse with it on (721 to 894); every 4-player bot season is still lost. No crashes in 12 serial seasons. P5-62 full test sweep is next.
- **P5-64 barn sign: Opus QA PASS after a fix.** QA put back "The creature copies voices" (the core threat, doc 01). Import 0 ERROR, parse_check 225/0, grep_rules clean, smoke PASS. Open: blank lines between sections do not show on the board.
- **P5-62 full sweep: 110 of 111 pass.** Fail: the P5-58 screenshot script frames day corn instead of the creature (filed, test only). Three stale tests fixed. Still owed: a run from a cleared .godot cache, which needs your game closed.
