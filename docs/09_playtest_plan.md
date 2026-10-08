# Doc 09: Playtest Plan

Owner: QA / Reviewer. Source of truth: [doc 01](01_design_doc.md) "Build Plan", "Testing" and
"Voice settings". Numbers below are doc 01's unless marked `placeholder` (a starting value, tuned by
the first run) or *inference* (with what would settle it). Nothing is built yet, so nothing in this
doc has been run; every command is the harness as it stands in `tools/qa/README.md`.

## Contents

1. [How to use this plan](#1-how-to-use-this-plan)
2. [Session rules](#2-session-rules)
3. [The done-when tests, phase by phase](#3-the-done-when-tests-phase-by-phase)
4. [Log measures and what proves them](#4-log-measures-and-what-proves-them)
5. [Spatial audio test procedure (DD Phase 1 gate)](#5-spatial-audio-test-procedure-dd-phase-1-gate)
6. [Trap race check](#6-trap-race-check)
7. [Multi-instance and authority checks](#7-multi-instance-and-authority-checks)
8. [Review checklist for every task](#8-review-checklist-for-every-task)
9. [Automated greps (flicker and others)](#9-automated-greps-flicker-and-others)
10. [Performance profile: 4 instances with corn](#10-performance-profile-4-instances-with-corn)
11. [After a session](#11-after-a-session)
12. [Gotchas](#12-gotchas)
13. [Inference, gaps and questions raised](#13-inference-gaps-and-questions-raised)

## 1. How to use this plan

- Sections 2 to 6 are for a playtest at the end of a DD phase (doc 01 "Build Plan": "Each 'done when'
  is checked in at least 2 sessions, with at least one tester who hasn't read this doc, plus a measure
  from the logs").
- Sections 7 to 9 are for the review of every task (a task is done only when QA passes it).
- Section 10 is a one-off measurement doc 07 requires before its budget counts as measured.
- DD Phase 5 (live clips, spliced clips from live speech, next season, cosmetics) is not tested here.

## 2. Session rules

Per phase, at least **2 sessions** (doc 01 "Build Plan"):

| Rule | Detail |
|---|---|
| Fresh tester | At least one tester per phase who has not read doc 01 and has had no one explain the game. They get the in-game onboarding only (doc 01 "Onboarding": one introduction per verb, never say the day is safe). They cannot be the same person in both sessions if the phase is Phase 2 or 3, where a second look at a surprise is worth less (*inference*) |
| Players | Phase 1: 2 players. Phase 2 and later: 2 to 4. A session with fewer than the phase's player count does not count |
| Networks | DD Phase 1 "First": at least one of the two sessions has the two players on **different home networks**, joined by UPnP and a join code. A LAN-only pass does not close that item |
| Length | Phase 1: one full day (about 8 to 10 min), dusk, one night (about 5 min), then a 10 minute debrief (doc 01 "Core Loop"). Later phases: whatever the phase's scope needs, logged in the session notes |
| Build | A clean export or a fresh checkout whose smoke run passed (section 8). The build id (`session_start.build_id`) goes in the notes so a log can be matched to a build |
| Logging | Every peer writes its CONTRACTS section 10 log. All peers' folders are collected; the host's file is authoritative. A session without a host file is invalid for measures |
| Recording | Voice and screen recording only with each player's consent, asked before the session, and only if they want. Recordings and session notes stay outside the repo (`logs/qa/` is gitignored; a recording of a person's voice is never committed, CONTRACTS section 11) |
| Names | Notes and OPEN_ISSUES use "tester A" and "tester B", never real names. The logs already use peer ids only (doc 05 section 18) |
| Voices | Test voices are synthetic, or the testers' own with consent, kept in `user://voice/` on their machine. For the spatial test and WAV-fed mics, use generated speech or a tone-and-noise stand-in, not a real person's file |
| Observer | One QA observer per session, silent during play. Counts screams and laughs ("screams and laughs are the design working; bored silence is what to fix", doc 01 "Testing") with a timestamp relative to `t` in the logs |
| Stop rule | If a tester asks to stop, stop. A crash or desync mid-session is logged and the session restarted; the partial logs still go through `check_logs.py` |

Debrief questions are asked after play, not during, and use the tester's words in the notes. Ask
the same questions every session so sessions compare:

1. When did you feel safest? Least safe?
2. When did you last doubt a voice? Why?
3. What did you do when you heard something in the corn?
4. What were you doing when you were bored?
5. What was the funniest moment? (the Dawn Report, ragdolls, trust arguments, doc 01 pillar 6)

## 3. The done-when tests, phase by phase

Each row is doc 01 "Build Plan" verbatim in spirit; the third column is the number from the logs that
backs the feeling. A phase passes only when **both** hold in at least 2 sessions. Thresholds marked
`placeholder` are mine, not doc 01's, and the first run may change them (recorded in DECISIONS by the
Director).

### DD Phase 1 (prototype)

| Item | Test | Log measure | Pass |
|---|---|---|---|
| First: voice between two machines on different home networks, through UPnP and a join code | Host presses host; friend types the code; both talk for 5 minutes | `net_upnp_result.result`, `net_connected.via` = `code`, `net_rtt`, `voice_stats` (`loss`, `underflow_ms`) | Connected by code with no manual step; both heard each other. Voice loss and underflow numbers are read, not gated (doc 06 section 8 gives PP-02 baselines: 0 clicks; underflow at most 216 ms per speaker over about 45 s) |
| Day feels safe | Debrief question 1 plus the observer's notes | `inside_at_night` is irrelevant by day; read `creature_state` and `noise_emitted` (debug) to confirm no chase by day | Both testers say the day felt calm. A scare by day in Phase 1 is a finding (doc 01: no AI Director yet) |
| Night feels tense | Debrief questions 1 and 3 | `inside_at_night.seconds` per player, `creature_state` transitions, `chase_started` count | Both testers name a tense moment at night. Seconds inside the whole night near 100% means the night is too frightening or the reason to go out is too weak (*inference*) |
| **At least 30% of lures make the target walk toward them** | Scripted lures from the corn (doc 01 "Phase 1": generic voice lines from the corn) | `lure_played` joined to `lure_result` (`moved_m > 10`, `within_s <= 8`; CONTRACTS section 10) | `check_logs.py` lure rate at least 30% over **at least 20 lure results across the two sessions** (`placeholder`: fewer than 20 is too few to say 30%; the sample size is mine, not doc 01's) |
| Spatial audio test | Section 5 | `spatial_audio_trial` | Section 5 |
| Turnips with hold times | Plant, water, sell | `hold_completed` (`verb`, `seconds`), `chore_summary`, `money_changed` | Every plant, water and sell shows a `hold_completed` line; mean seconds within 15% of `labor.json` unless a multiplier explains it (`placeholder`) |
| Generator run, noisy can, crouch and go-still | One generator run; one still hide | `generator`, `noise_emitted` kinds, host `speed_violation` count | `generator` shows `fuelled` then `dead` or a refuel; no `speed_violation` on a normal client |
| Trap race (scripted traps) | Section 6 | `trap_race_result` | Section 6 |
| Three ambience layers from creature state | Lurk, Stalk, Chase heard; the bed cuts out in Stalk | `creature_state` timestamps against the tester's call-out | The tester names Stalk by sound alone (doc 01 "Behavior states"), or the miss is logged as a finding |
| 2 instances, authority split | Section 7 | Host-only events absent from client files | Section 7 |

### DD Phase 2

| Item | Test | Log measure | Pass |
|---|---|---|---|
| A friend's recorded voice fools someone | Staged recording; the creature replays a recorded line to a teammate (not the speaker) | `lure_played` with `line_id` of a teammate and `tell` (`echo`, `pitch`, `crackle`, or none), joined to `lure_result.worked`; plus the debrief answer "did you believe it?" | At least one tester reports being fooled (they walked toward it or said so), and the log shows `worked` for a recorded-line lure. A lure's `worked` rate for recorded lines against generic ones is read, not gated |
| Trap sweeps feel worth doing | Two fields, corn between, a pegboard theft | `trap_changed` (`disarmed`, `filled`, `cut`) against `trap_sprung` by day; `hold_completed` for `disarm` (seconds); debrief question 4 | Testers sweep without being told to after the first sprung trap, and say it paid off. A team that never sweeps and never springs a trap means the clues are too weak (*inference*) |
| Death, dawn respawn, medical bills | Kill one tester | `death`, `medical_bill` (`players`, `deaths`, `bill`, `paid`, `to_final`), `dawn_summary` (`medical_bill`, `final_extra`); with nothing in the bank the game logs no `money_changed` for a bill (P2-09) | The bill matches doc 01's table for the headcount; the floor of 4 coins holds |
| Up to 4 players | One session at 4 | `net_bandwidth`, `net_rtt`, `voice_stats` per speaker | No desync (section 7); bandwidth in line with doc 06 section 13's estimate |
| Voice settings | Section 8 voice checks, in play | none (checklist) | All pass |
| 72 m voice trial | Add a 72 m trial to the section 5 line (doc 04 section 8.2 asks for it: the far field and the moonflower bed are 64 to 72 m from the barn) | `spatial_audio_trial` at `distance_m` 72 | Reported, not gated |

### DD Phase 3

| Item | Test | Log measure | Pass |
|---|---|---|---|
| The dead stay engaged | A tester dies early and keeps playing as a ghost | ghost actions: flicker, crow, rustle, static voice (events not yet defined, section 13); time a dead tester stays connected and in the session | The dead tester stays to the dawn and reports something to do (debrief question 4) |
| The living argue over a static voice | A dead teammate's voice or a faked dead voice plays in static | `lure_played.ghost` = true; observer counts a spoken argument about whether it was real | At least one argument per session, and at least one tester used the flicker as the tiebreaker (doc 01 "The dead-voice twist") |
| Someone laughs at the Dawn Report | The Dawn Report shown at dawn | none | Observer logs at least one laugh per session |
| The AI Director, day arc, jumpscares | Day arc thirds; at most one big scare per player per day; never two on the same player within 2 minutes (doc 01 "Rules") | `tension` every 10 s, `creature_state`, scare events | No player has two big scares within 2 minutes; first third of the day has no scare except evidence of sabotage |
| Taint and Shaken | Cause each once | `taint_changed`, `shaken` | Cause and cure as doc 01 states; Shaken never Taints |
| Do the four bodies feel different? | Open Issue 4; each session uses a different body | none | Debrief: can the tester name the body by sound alone? Written into OPEN_ISSUES |

### DD Phase 4

| Item | Test | Log measure | Pass |
|---|---|---|---|
| First: the simulator hits its targets | `tools/sim/` run for 2p, 3p, 4p (Game Designer) | the sim's output | Median team clears the first payment in about 85% of runs and the final in 55 to 70%; spread across player counts at most 10 points (doc 01 "Season simulator") |
| Teams sometimes win and sometimes lose | At least 6 full seasons (`placeholder`; fewer can't show both outcomes) | `payment_made`, `session_end` | At least one win and one loss across the seasons |
| Logs land within 15 points of the sim | Compare playtest logs to the sim | `dawn_summary`, `money_changed`, `payment_made`, `death` | First-payment clear rate and final-payment clear rate each within 15 points of the sim (doc 01 "Playtest check"). *Inference:* a handful of seasons is a loose test; per-dawn coin and debt trajectories from `dawn_summary` against the sim's are the tighter comparison, and doc 01 does not say which. Settled by the Game Designer's `compare` command (doc 05 section 18 names it) |
| Saving, joining and leaving | A drop mid-season; a late join; a host left | `net_peer_left`, `net_host_left`, `save_written` | Debt recomputed per doc 01's example (4p, one drop before dawn 2: 1,077 total, first payment 211); resume from the last dawn save |

## 4. Log measures and what proves them

`uv run tools/qa/check_logs.py <folder>` reads the host's file (peer 1) per session and reports the
three doc 01 measures plus tallies.

| Measure | Event | Rule in the checker | Status |
|---|---|---|---|
| Lure success | `lure_result` | worked when `moved_m > 10` and `within_s <= 8`; recomputed, mismatches with the logged `worked` listed; gate 30% | Done (PP-03); fields fixed by doc 05 section 18 |
| Trap race | `trap_race_result` | survival overall and for `solo` and not `tainted` and `pried_at_once`; deaths in that case listed; minimum and mean `seconds_spare` | Done (PP-03) |
| Spatial audio | `spatial_audio_trial` | correct by `sound` and `distance_m`, overall and per tester; read from every peer's file (the tester's client writes it); untested cells listed | Done (PP-03, per-tester and client files P1-17). `angle_error_deg` is logged but not tallied yet |
| Hold times | `hold_completed` | mean seconds by verb | Done |
| Time inside at night | `inside_at_night` | seconds by player | Done |
| Deaths, traps, money | `death`, `trap_sprung`, `money_changed` | counts | Done |
| Ghost powers used (DD Phase 3 "the dead stay engaged") | `ghost_action` (`kind`: `flicker`, `crow`, `rustle`, `caw`; `peer`) | count by `kind` | Done (P3-09). Refusals are `ghost_action_refused` with a `reason` (doc 05 section 18), counted in the event list only |
| Lure success by source (recorded line, generic line, sound) | `lure_played` joined to `lure_result` on `lure_id` | not built | Needed for DD Phase 2 "fooled" (section 13) |
| Sim comparison | `dawn_summary`, `payment_made` | not built | DD Phase 4 (section 13) |
| Close calls missed for timeout vs disagreement, per RTT | `close_call` | not built | OPEN_ISSUES "A laggy player is hard to kill"; DD Phase 1 logs settle it |

Check-your-checker rule: the first time a measure is read from real logs, compare the checker's number
with a hand count of five lines from the same file.

## 5. Spatial audio test procedure (DD Phase 1 gate)

Doc 01 "Testing": "with headphones, players must be able to place a voice and a whistle at 10, 30 and
60 m." Build: doc 05 section 20 step 8, markers from doc 04 section 7.4, emitters from doc 06
section 8 (voice) and doc 08 section 9.3 (whistle).

**Setup.**

- Listener `audio_listener` (-26, 16). Sources `audio_10m`, `audio_30m`, `audio_60m`, `audio_72m` at 10, 30, 60 and 72 m on four bearings 90 degrees apart (CEO 2026-10-08: one line made distance the only cue; the test scene sets them, see `BEARINGS_DEG`). Superseded layout: (-16, 16), (4, 16),
  (34, 16). All on open ground in the DD Phase 1 area. The sources stay put; the listener's heading is
  randomised each trial, so front-to-back confusion is tested without 60 m of open ground in every
  direction (doc 04 section 7.4).
- Wired or good wireless **stereo headphones**, worn correctly (left on left). The tester states the
  model. Windows spatial sound off, game volume set once at a comfortable level and not changed. Room
  quiet.
- The voice source is the `VoiceEmitter` playing a synthetic line (doc 08 section 7.4 stranger line, or
  a generated test voice), so no real person's voice is involved. The whistle is `sfx_whistle` through
  `sound_emitter.tscn`. Both with doc 06 and doc 08 attenuation settings (voice: inverse distance, unit
  6 m, max 80 m; whistle: unit 20 m, max 220 m).
- No HUD marker, no visual cue of which source plays (doc 01 "Whistle": placed by 3D audio only).

**A trial.**

1. The tester stands at `audio_listener` with a random heading and a screen showing the three
   candidate positions (the marker ids) but not which one is active.
2. One sound (voice or whistle) plays from one source, once, about 1.1 s for the whistle and one
   short line for the voice. No repeats.
3. The tester picks the marker they heard. The game logs `spatial_audio_trial` (`sound`,
   `distance_m`, `correct`, `angle_error_deg`, `marker`, `guessed_marker`, `listener`; doc 05 section
   18).

**Sample.** Per tester: 2 sounds x 4 distances (10, 30, 60, 72 m) x 6 trials = **48 trials**, order shuffled, no more
than 2 in a row from the same source. Rest after 24. At least 2 testers (one new to the game).
(`placeholder`: 6 per cell is the smallest count where 5 of 6 is clearly above the 1 in 3 chance rate;
tune after the first run.)

**Pass.** Doc 01 gives no number, only "must be able to place". Proposed (*inference*, settled by the
first run and by the CEO's ear):

- Each of the 6 cells (voice and whistle at 10, 30, 60 m) at least **80% correct** pooled over testers
  (chance is 33%), and
- no tester below 60% in any cell, and
- median `angle_error_deg` of the **wrong** answers reported, not gated, to tell front-to-back mix-ups
  (near 180 degrees) from plain misses.

Note the geometry: the three sources lie on one line from the listener, so a correct pick at 30 or 60
m with a random heading tests direction and distance together, and with a clear front/back flip the
answer is wrong by direction. Distance cues alone are weak at 60 m: the voice at 60 m is about 20 dB
below its level at 6 m, the whistle about 9.5 dB below its level at 20 m (inverse-distance law, my
arithmetic from the unit sizes above).

**If a cell fails.** In doc 01's order (doc 06 section 8): (1) evaluate the Steam Audio GDExtension
(needs CEO approval of source and license, D-005); (2) add per-source occlusion and reverb (doc 08
section 3.1 already specifies an occlusion low-pass); (3) for the whistle, doc 01's fallback is a brief
flash on the whistler's lantern or hat. Record the failing cell and what was changed in OPEN_ISSUES
(doc 01 Open Issue 3), then rerun the failing cells only after the change.

**Logs.** Written by the tester's client. `check_logs.py` lists the cells not yet tested, so a run that
skips one shows it.

**Result (2026-10-08, D-033).** One tester, 48 trials, four-bearing layout. Voice 10/30/60/72 m: 5/6,
6/6, 5/6, 6/6. Whistle: 6/6, 4/6, 5/6, 3/6. Whistle at 30 m (67%) is below 80% but above the 60%
floor. The CEO closed the gate on this run, with no second tester and no retune. The whistle misses
are OPEN_ISSUES "Found at the P2-01 review" 1.

## 6. Trap race check

Doc 01 "Testing": "log whether a solo, untainted player who pries at once survives." Doc 01 "Day
deaths": that player "survives with a few seconds to spare". Doc 03 section 7.2: normal start 25 m,
speed 3.5 m/s, solo untainted pry 4 s, so 3.14 s spare; bend 22 to 28 m with a 2 s floor (all
`placeholder` there).

**Procedure.** A tester springs a bear trap by day and pries at once (hold started within 0.5 s of the
spring, doc 03 section 7.2). Cases to run per session, at least 3 each:

| Case | Expect (doc 03 section 7.2) |
|---|---|
| Solo, untainted, pries at once, normal trap | survives; `seconds_spare` between 2.0 and 4.0 |
| Same, deep trap | survives; spare about 1.14 (0.29 to 2.0 across the bend) |
| Solo, hesitates 2 s | lives normal, dies deep |
| Solo, Tainted | lives normal (1.14 s), dies deep. Needs Taint (Phase 2 or 3), skip in Phase 1 |
| With a teammate | survives with more spare than solo |

**Pass.** `check_logs.py` section "Trap race":

- **Every** solo, untainted, pried-at-once race at a normal trap survived. One death in that subset is a
  failure and goes to the Game Designer as a tuning bug; the checker lists those deaths.
- Minimum `seconds_spare` in that subset at least 2.0 s at a normal trap (doc 03 `trap_race_min_spare_s`,
  `placeholder`).
- The tester can say how long they thought they had (the signature approach is a tell, doc 03).
- A tester who survived by luck of lag: look at `credit_ms`; if survival needed the lag credit, the
  tuning is off, not the player.

**Not a pass on its own.** The numbers are placeholders; a clean log with a bored tester fails the
test too (doc 01: "deaths come from player choices").

## 7. Multi-instance and authority checks

```bash
uv run tools/qa/multi.py -n 2 --args "-- --host" --args "-- --join=127.0.0.1"   # then -n 3 and -n 4
uv run tools/qa/check_logs.py logs/qa/multi_<timestamp>/user_logs
```

(Exact game flags come from doc 06 section 14: `--host`, `--join <code or ip>`.) A feature is tested
with **2 instances at minimum** and, if it touches 3 or 4 players, with that many. The host's own player
and a client take the same code path (doc 05 section 2), so test the feature **from a client**, not
only from the host. A feature that only works single-player is not done (CONTRACTS section 5).

| Check | How | Pass |
|---|---|---|
| Sync | Do the action on a client; watch the host and a second client | All three agree on the result (crop state, trap state, money, creature state) |
| Host validates | Client-side `request_*` refused out of range or out of state (try it with a debug command) | The host writes `hold_refused` and the client sees `apply_refused`; nothing changes |
| No client-side selling or economy | Client sells; read the money | `money_changed` appears in the **host** file only |
| Host-only events | `grep -l '"event": "money_changed"' <session>/peer_[2-9].jsonl` and the same for `lure_played`, `lure_result`, `trap_sprung`, `trap_race_result`, `death`, `creature_state`, `tension` | No output (doc 05 section 18: these are written only by the host). Clients write `net_*`, `voice_stats`, `settings_changed`, `spatial_audio_trial` |
| Creature and AI Director run on the host only | Run with the host headless-quiet and look for creature nodes moving on a client without `apply_creature_state` | The client's creature follows the replicated state; no AI Director node ticks on clients |
| Stillness from transforms | A client stands still with a modified flag | The host's ring uses received transforms (doc 05 section 22); a client flag alone changes nothing |
| Lag never kills | `--net-sim-latency-ms 250 --net-sim-loss 0.1` (doc 06 section 14) and a lunge | `close_call.result` is `miss_*`, never a death from disagreement; OPEN_ISSUES 1 gets the counts |
| Late join, leave, host left | Drop a client; drop the host | Roster updates; "host left" card; resume from the dawn save (doc 01 "Saving") |
| Channels | `net_bandwidth` for 4 players talking | Within doc 06 section 13's estimate |

A pass after a fail with no edit in between is suspicious: rerun from a clean import
(`uv run tools/qa/smoke.py --clean-import`).

## 8. Review checklist for every task

QA reviews a task against its acceptance criteria in TASKS.md and doc 01's pillars. A reviewer never
reviews their own work; the Director reviews QA's. Record the verdict in the task's handoff under
`## QA review` (pass or fail, with reasons). Each bug goes to the Director in QUESTIONS.md; each
playtest problem into `production/OPEN_ISSUES.md`.

**A. Process**

- [ ] The task has a handoff (what was done, files changed, what the next role needs, open issues).
- [ ] Only the role's owned paths changed (CONTRACTS section 2); anything else is a question, not an edit.
- [ ] The task stayed inside its DD phase's scope; nothing from Phase 5 (live clips, spliced live clips,
      next season, cosmetics).
- [ ] No conflict with doc 01. A conflict is flagged to the Director, not resolved in the lower doc.
- [ ] Numbers cite a doc 01 section or are marked `placeholder` or inference with what settles them.
- [ ] Names follow CONTRACTS section 3: `snake_case` files and IDs, typed GDScript, "AI Director" written
      in full for the game system.
- [ ] Commit staged only the task's files.

**B. Run it (code tasks)**

- [ ] `uv run tools/qa/smoke.py` passes: no `ERROR`, `SCRIPT ERROR`, `USER ERROR`, `SHADER ERROR` or
      crash banner, import then parse check then timed run.
- [ ] Clean import: `uv run tools/qa/smoke.py --clean-import` also passes (close the editor first).
- [ ] `uv run tests/qa/test_harness.py`, `uv run tests/qa/test_grep_rules.py` and the role's own tests
      under `tests/<area>/` pass.
- [ ] `uv run tools/qa/grep_rules.py` passes (section 9).
- [ ] 2 instances, then 3 or 4 where the feature needs them (section 7).
- [ ] `check_logs.py` on the run shows the measures the task affects, not "none logged".

**C. Authority split (CONTRACTS section 5)**

- [ ] Clients own only their movement and camera; crouch and still are checked by the host from
      transforms.
- [ ] Interactions are `request_*` to the host, validated, then `apply_*` back. No `rpc()` outside `Net`.
- [ ] Creature, AI Director, traps, pegboard, economy, Taint, deaths, generator, crops, cart, clock run on
      the host only.
- [ ] Close calls are resolved in the victim's favour.
- [ ] The feature works from a client.

**D. Voice settings, to the letter (doc 01 "Voice settings"; doc 06 section 11)**

- [ ] **Off:** nothing recorded (no capture, no clip file created), and the creature fakes only this
      player's footsteps and tools. `lure_played.owner` is never an Off player; no generic voice is used
      in an Off player's name.
- [ ] A new, unchosen player is treated as Off on the wire; Lobby lines becomes the default only once a
      line is recorded (D-013).
- [ ] **Lobby lines:** lobby lines and barn chatter can be replayed by the creature and in the Dawn
      Report.
- [ ] **Live clips** (Phase 5) is not built; the host refuses `live_clips`.
- [ ] No forced consent screen. A player can change the setting at any time (menu, lobby, pause).
- [ ] The setting governs every replay: the creature, the Dawn Report (Off players appear as text plus
      sound) and streamer-safe mode, checked at play time.
- [ ] **Storage:** lobby lines on the owner's disk (`user://voice/`) and in peers' memory only. The
      dawn save contains no voice key or path (grep the save file). Received clips are never written
      to disk.
- [ ] **Off deletes them:** the files under `user://voice/lines/` and `user://voice/chatter/` are gone,
      peers free the clips, and a lure playing one of them stops at once.
- [ ] The recording light is on whenever capture is live, steady, for the whole capture, on the
      recorder's screen and on their character.
- [ ] Each clip can be reviewed and deleted before the match.
- [ ] UI copy never says or implies the line list is the whole pool. The lobby line is verbatim: "The
      creature can't hear Discord, and you can't hear where your friends are."
- [ ] Tells: each fake has at most one giveaway (echo, wrong pitch, missing crackle); about a third have
      none; a tell always comes from a place the teammate can't be. Nightmare has no voice tells.
- [ ] Day lures are targeted (only the target hears them, only with no teammate within about 15 m);
      night and chase lures are world sounds.

**E. Recording lines that sound scared (doc 01)**

- [ ] The lobby is the dark barn at night; each line follows a staged moment. A lantern **blows out,
      never flickers**.
- [ ] Each line is recorded 2 to 3 times; the game keeps the most energetic take (loudness and pitch
      variation) and deletes the rest on accept.
- [ ] The line list is the seven lines ("over here", "help me", "come look at this", "I found
      something", "where are you?", "wait for me", "it's fine, come on") plus each teammate's name.
- [ ] Barn chatter is 20 to 40 seconds, only from Lobby-lines players who join the staged recording,
      skippable, captured on the sender's machine with the recording light on.
- [ ] While a machine captures, it plays no Off player's voice (D-011).
- [ ] The menu offers re-record or skip.

**F. No real voice in the repo (CONTRACTS section 11)**

- [ ] `uv run tools/qa/grep_rules.py` voice-file rule passes (no tracked `.vclip` or `.opus`; no
      `.wav`, `.ogg`, `.mp3`, `.flac` outside `assets/audio/` and `tests/`).
- [ ] Anything under `assets/audio/` is generated (the render pipeline, D-015) or CEO-approved, with the
      source named in doc 08 section 13.
- [ ] Logs and saves contain no audio, no voice volume, no names (doc 05 section 18).

**G. Flicker**

- [ ] Nothing but the ghost system flickers a light. The three greps in section 9 pass. The generator
      dims (smooth, warm, monotonic) and the lantern blows out; neither is a flicker. The recording
      light, moonflower glow and cart lantern are steady (doc 07 section 4.3).
- [ ] Post-processing never pulses brightness.

**H. Logs capture the phase's measures**

- [ ] The events in section 4 for the task's phase are written, by the right peer, with the field names
      of doc 05 section 18.
- [ ] A fresh run's `check_logs.py` report fills lure, trap race and spatial audio, or the task says why
      it cannot yet.

**I. Review hygiene**

- [ ] A pass after a failure with no edit in between is rerun from a clean `.godot/` import.
- [ ] Verdict states what was run and what was only read.
- [ ] Findings that are not blockers are listed as non-blocking and filed.

## 9. Automated greps (flicker and others)

`uv run tools/qa/grep_rules.py` (self-test: `uv run tests/qa/test_grep_rules.py`) runs these. It
exits 1 on a violation and passes with a note while `game/` does not exist.

**The three flicker rules, copied from doc 07 section 4.4** (doc 05 section 12 adds the handler-glue
exception):

| # | Search `game/` for | Allowed only in |
|---|---|---|
| 1 | `flicker` (case-insensitive) | `game/ghost/`, and the message names `request_flicker` and `apply_flicker` in `game/net/` |
| 2 | `energy_override` | `game/render/light_rig.gd` and `game/ghost/light_flicker.gd` |
| 3 | `light_energy` | `game/render/` (everything else goes through `LightRig`) |

Equivalent by hand (Git Bash):

```bash
grep -rniE 'flicker' game/ | grep -v '^game/ghost/' | grep -vE '^game/net/.*(request|apply)_flicker'
grep -rn 'energy_override' game/ | grep -vE '^game/(render/light_rig|ghost/light_flicker)\.gd'
grep -rn 'light_energy' game/ | grep -v '^game/render/'
```

All three must print nothing. Details:

- Rule 1 counts comments. A comment saying "no flicker here" outside `game/ghost/` is a hit, so reword
  it ("steady"). The only exception is the two message names in `game/net/`; a line in `game/net/`
  that has `flicker` besides those names fails.
- Rule 3 fails a `.gd` hit and only **warns** on a `.tscn` or `.tres` hit (a light's static value set
  in a scene). That relaxation is mine (*inference*): doc 07 section 4.4 says "a grep of `game/`" and
  does not say whether scene-authored energies count. Settled by the Technical Artist (section 13).
- The grep proves where code can write a flicker, not that the runtime never strobes. At runtime
  also watch: dimming is monotonic; no light changes faster than full energy per 0.2 s outside the
  override (doc 07 section 4.1); the `LightRig` slew cap exists; the host rejects `request_flicker`
  from a non-ghost (`Game.is_ghost`), tested by sending it from a living client.

**Other rules in the same script:**

| Rule | Check | Source |
|---|---|---|
| `rpc_outside_net` | `.rpc(` and `.rpc_id(` in `.gd` only under `game/net/` | doc 06 section 14, doc 05 section 22 |
| `voice_files` | tracked `.vclip` and `.opus` nowhere; `.wav`, `.ogg`, `.mp3`, `.flac` only in `assets/audio/` and `tests/` | CONTRACTS section 11 |

**Review by hand (no grep exists yet):** doc 08 section 4.4's rules for the ambience tell. Only
`Soundscape.set_creature_state()` lowers the `bed` or `wind` layers by more than 6 dB (the dusk and
dawn crossfade is the exception); generator death, a pause or menu, a slow frame, a disconnect and the
host-left card never touch them; crows, livestock and birds are never scheduled by creature state. Find
with `grep -rn "volume_db\|set_bus_volume\|bed\|wind" game/audio game/core` and read each hit; a script
form is a follow-up once `game/audio/soundscape.gd` exists.

## 10. Performance profile: 4 instances with corn

Required by doc 07 section 10.3 before its budget counts as measured (Q-028). Needs the DD Phase 1
corn walls (doc 04 section 9), so it cannot run yet. Not a headless test: the headless renderer draws
nothing and cannot give a frame time.

**Budget (doc 07 section 10.2, all `placeholder`):** at 1280x720 with 4 instances running on the CEO's
machine, 60 fps; draw calls 1,500 or fewer; triangles on screen 1,500,000 or fewer; corn stalk
instances 25,000 or fewer; shadow-casting lights 4 or fewer; texture memory 256 MB or less per
instance.

**Procedure.**

1. `uv run tools/qa/multi.py -n 4` (add `--no-tile` and give each instance
   `--resolution 1280x720 --position X,Y` through `--args`, so each renders at the budget size; the
   default tiling is 640x360 and does not match). Debug view on. Place the instances at four spots:
   inside the clearing facing the corn wall, in the corn lane, at the barn door, on the road.
2. Let each instance run 60 s. Record the frame time (the debug view shows ms) and the Godot Monitors
   for draw calls, triangles and video memory.
3. **Pass:** every instance averages 60 fps or better **at the same time**, and no frame goes above 33
   ms.
4. Record the GPU each instance used: `RenderingServer.get_video_adapter_name()`. The CEO's machine is
   a Ryzen 7 9800X3D with an RTX 5070 and an AMD integrated GPU; Godot may pick the integrated one,
   which would make every number worse (doc 07 section 10.2). A pass on the wrong adapter is not a pass
   for the machine's best GPU, and a fail on the integrated GPU is not a fail of the budget; report the
   adapter beside every number.
5. If it fails, cut in doc 07's order, one change at a time, noting each effect: corn shadows, local
   light shadows, grain, fog layer, high LOD range 12 to 8 m, stalks per m2 6 to 4, MultiMesh cell
   size. Results go in the PP-08 follow-up handoff (doc 07).
6. Because 4 windows share one GPU, this is a pessimistic bound for what four friends' machines each
   render (*inference*); a one-instance number at the same spot is recorded beside it.

**Open:** no log event carries frame time or the adapter name (section 13), so the first measurement is
read from the screen and typed into the handoff.

**Tool (P1-14):** `tests/qa/perf_probe.tscn` boots the game like Boot does, waits `--probe-warm` s (default 15),
samples `--probe-s` s (default 60) and prints one `perf_probe` line: average fps, worst frame ms, frames over
33 ms, draw calls, primitives, texture and video MB, adapter, size. Windowed only. Example (4 instances):
`uv run tools/qa/multi.py -n 4 --no-tile --common "res://tests/qa/perf_probe.tscn -- --phase1 --port=50742 --autowalk"
--args "--resolution 1280x720 --position 0,0 -- --host" --args "--resolution 1280x720 -- --join=127.0.0.1:50742" ...`.
The engine prints a leaked-resource error at exit when the probe quits, so `multi.py` reports FAIL on it; read the
`perf_probe` lines in `instance_<i>.log`. The probe samples wherever the player is (autowalk circle), not the worst
view.

## 11. After a session

The kit in `tools/qa/playtest/` and `tools/qa/playtest.py` runs these steps (`new`, `tally`,
`collect`, `report`; `tools/qa/README.md`). Its report applies sections 2, 3, 5 and 6; rows only
people can judge print as `MANUAL`.

1. Collect every peer's log folder into one place under `logs/qa/` and run `check_logs.py` on it.
2. Check for the host file; a session without one is invalid (section 2).
3. Write the notes: build id, players (as tester A, B), networks, counts of screams and laughs with the
   log time, the debrief answers, the measure numbers.
4. Add each new problem to `production/OPEN_ISSUES.md`, numbered, one problem each, with what would
   settle it (that file's format).
5. File each bug as a question to the Director in QUESTIONS.md.
6. At the phase end, summarise pass or fail per row of section 3 in the phase's review handoff, for the
   between-phase review (doc 01 "Between phases": read the logs, add problems, settle dependencies).

## 12. Gotchas

- **The tester who "hasn't read doc 01" must be asked.** A friend who watched a stream counts as having
  read it. Ask what they know about the game before the session.
- **Machine on one desk is not two networks.** Two instances on one PC test the code path, not UPnP or
  the join code over the internet; the DD Phase 1 "First" item needs two homes.
- **Hybrid GPU.** A framerate number without the adapter name is meaningless on the CEO's machine
  (doc 07 section 10.2).
- **Headless runs do not measure feel or frame time.** The smoke run proves the code loads and runs.
- **Killing an instance loses unflushed log lines** (`tools/qa/README.md`); end a log-measure run with
  `--frames`, not `--duration`.
- **`logs/` is gitignored at any depth,** so a fixture folder named `logs/` is never committed.
- **A clean log can hide a bad session.** The measures are only half of "done when"; the feeling is the
  other half.
- **Do not coach the lure.** If a tester is told "voices in the corn are fake", the lure rate falls for
  a reason that is not the design. Brief them on controls only.
- **Lure `moved_m` is the largest reduction of distance to the lure** (doc 05 section 18), not the
  distance walked; a tester who circles can score as moved.
- **Headphones left/right swapped** is the commonest spatial test failure; start with a 10 m sound on a
  known side.

## 13. Inference, gaps and questions raised

Filed in `production/QUESTIONS.md` (see the PP-10 handoff for the IDs):

1. **Technical Artist (doc 07):** does a `light_energy` set inside a `.tscn` or `.tres` outside
   `game/render/` break rule 3? The script warns; it does not fail. Settled by the Technical Artist's
   answer.
2. **Gameplay Programmer (doc 05 section 18):** event names for items doc 01's later phases measure
   and the list lacks: `ghost_flicker` (who, which light, cooldown), a ghost crow possession event,
   a frame-time and adapter event (`perf_sample`: average and max ms, draw calls, adapter name; debug
   runs only), and whether a "was fooled" signal exists for DD Phase 2. Without them DD Phase 2 and 3's
   measures are the observer's notes only. **Answered for ghosts (P3-09):** one event,
   `ghost_action` with `kind` (`flicker`, `crow`, `rustle`, `caw`) and `peer`, replaces
   `ghost_flicker`; doc 05 section 18 lists it. The cooldown is not logged (a refusal logs
   `ghost_action_refused` with `reason` `cooldown`).
3. **Game Designer:** is `tools/sim/` getting the `compare` command doc 05 section 18 names, and which
   metric does "within 15 points" mean (clear rates, or the coin trajectory)? How many seasons does the
   comparison need?
4. **QA (mine, next task, not asked of anyone):** extend `check_logs.py` with lure success by source
   (join `lure_played` and `lure_result`), `angle_error_deg` tally, the host-only events in client
   files check, and the sim comparison once the format exists.

Inference in this doc: the 20-lure and 36-trial sample sizes and the 80% and 60% spatial pass
thresholds (doc 01 gives none); the 6 full seasons for Phase 4; the "a second Phase 2 or 3 tester must
be fresh" rule; reading `light_energy` in a scene as a warning. Each is `placeholder`: the first run
shows whether it is too loose or too tight, and the Director records the final number in DECISIONS.
