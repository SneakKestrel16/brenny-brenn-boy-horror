# Task Board

Only the Director creates or reassigns tasks. One task in progress per agent.

**Statuses:** `todo` → `in progress` → `in review` (QA) → `done` (QA passed, Director checked,
committed as `<Role> <ID>: <summary>`). `blocked` names what it waits for.

**Every doc task** is also checked by the Director against doc 01 for consistency before it is done.
**Every code task** must work with 2+ instances over ENet (single-player only = not done), and run
headless without new errors.

**IDs:** `PP-` pre-production, `P1-` to `P4-` design doc phases 1 to 4, `PL-` polish.

---

## Studio phase 1: Pre-production

Order (kickoff): 06 and the voice spike first, then 02 and 04 together, then 03, 05, 07, 08, 09.
**STOP after the spike** for the CEO to test it with a friend on another network.

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| PP-01 | Network & Voice | Doc 06 Networking & Voice | done | — |
| PP-02 | Network & Voice | Voice spike: Opus over ENet, UPnP and join code | done (STOP 1 passed 2026-10-06) | — |
| PP-03 | QA | Test harness: headless smoke run, multi-instance launcher, log checker | done | — |
| PP-04 | Game Designer | Doc 02 Systems & Economy, data schemas | done | STOP 1 (passed) |
| PP-05 | Level Designer | Doc 04 Farm Layout | done | STOP 1 (passed) |
| PP-06 | Game Designer | Doc 03 Creature, AI Director & Scares | done | PP-04 |
| PP-07 | Gameplay | Doc 05 Technical Design | done | PP-01, PP-04, PP-06 |
| PP-08 | Technical Artist | Doc 07 Art Direction & Asset List | done | PP-05, PP-06 |
| PP-09 | Audio Designer | Doc 08 Audio Design & Sound List | done | PP-06, PP-01 |
| PP-10 | QA | Doc 09 Playtest Plan | done | PP-01 to PP-09 drafts |
| PP-11 | Director | Fill CONTRACTS sections 6 to 9 from docs 02, 03, 05, 06, 08 | done | PP-04, PP-06, PP-07, PP-09 |
| PP-12 | Director | Pre-production review: Open Issues, settle what DD Phase 1 needs, CEO approval | done (CEO approved 2026-10-07) | all above |

### PP-01 Doc 06 Networking & Voice
Owner: Network & Voice. Output: `docs/06_networking_and_voice.md`.
Acceptance:
- Covers every item in doc 01 "Engine and Tech" (Networking, Voice), "Voice Mimicry" (as it touches
  transport, playback and storage), "Voice settings", "Recording lines", "Joining and leaving" and
  "Saving > Host leaves".
- Defines: ENet channels; the full RPC/message list with direction and who validates; join code
  format (encodes address and port, short, typo-resistant) and the manual IP and VPN fallbacks;
  what the host screen shows when UPnP succeeds or fails; host-left flow; voice frame format
  (Opus settings, frame size, the one-byte volume sent to the host for the creature's hearing);
  host relay; VAD and push-to-talk; the shared voice chain (echo, pitch, missing-crackle tells,
  ghost static) that fakes also use; walkie-talkie routing; how lure clips are pre-shared at session
  start; where lobby lines are stored and how "Off" deletes them; the recording light.
- Bandwidth estimate for 4 players talking at once.
- Phase 5 items (live clips) described only as a later extension, not designed in detail.
- Gotchas section. QA review passes; Director consistency check passes.

### PP-02 Voice spike
Owner: Network & Voice. Output: `spikes/voice/` (throwaway), handoff note.
Acceptance:
- Host button: opens a port with Godot's `UPNP`, shows clearly whether UPnP worked, shows the
  public address, the port to forward by hand if it didn't, and a join code.
- Join screen: enter a join code or a raw IP (VPN IPs work the same way).
- Mic captured with `AudioEffectCapture`, Opus-encoded, sent over ENet, relayed by the host,
  played from an `AudioStreamPlayer3D` on each remote player's capsule. Simple WASD capsules in an
  empty field, so position is audible.
- Voice input can be fed from a WAV file (`--voice-wav <path>`) for testing.
- Open mic with VAD by default; push-to-talk toggle.
- Logs (section 10 format): UPnP result, connect time, round-trip time, voice packet loss.
- Works with 2 local instances (QA confirms), then the CEO tests two machines on different home
  networks at STOP 1.
- Third-party code only as approved in Q-001, with its license recorded in `addons/<name>/LICENSE`
  and in the handoff.

### PP-03 Test harness
Owner: QA. Output: `tools/qa/`, `tests/`.
Acceptance:
- One command runs the headless import and a timed headless run, and fails on any `ERROR` or
  `SCRIPT ERROR` line.
- One command starts N (2 to 4) local instances with per-instance arguments and collects their logs
  into one folder.
- A log checker that reads the section 10 JSONL and reports the doc 01 measures it finds (lure
  success rate, trap race results, spatial audio trials), even if none exist yet.
- Documented in `tools/qa/README.md`.

### PP-04 Doc 02 Systems & Economy
Owner: Game Designer. Output: `docs/02_systems_and_economy.md`, proposed schemas in its appendix.
Acceptance:
- Turns doc 01 numbers into data tables: crops, prices, growth, payments, medical bill, player-count
  scaling (80% / 60%, rounded up), Foreclosure, the joining/leaving debt formula (reproduces doc 01's
  worked example: 1,077 total, 211 first payment), store prices (sim-set items marked), ramp-up,
  trap types, Taint causes and effects, Shaken, Prize Pumpkin sizes and payouts, roles, labor
  (hold seconds per verb, plots per player derivation).
- Every number cites its doc 01 section or is marked `sim` or `placeholder`.
- Proposed JSON schemas for CONTRACTS section 6.
- Simulator design (inputs, the median team, outputs vs doc 01 targets). Building it is a later task.

### PP-05 Doc 04 Farm Layout
Owner: Level Designer. Output: `docs/04_farm_layout.md` with a top-down diagram.
Acceptance:
- Full two-field farm with every element doc 01 names: wild corn ring and strips reaching toward
  buildings and between the barn and both fields; barn; farmhouse; tool shed with pegboard; well;
  generator and fuel drum by the shed; two distant fields (one by the barn, one by the shipping
  crate); moonflower bed; Prize Pumpkin patch at least 30 m from every building door, between the
  farmhouse and the first corn strip; shipping crate and store; town stand with its 10 m sanctuary;
  farm gate and cart route; trap spots, creature cover points, crows, scarecrows, animal pens.
- Distances in metres, checked against the 10/30/60 m spatial audio test, 15 m lure rule, 20 m
  ghost and pumpkin radii, and labor seconds from PP-04.
- The small DD Phase 1 layout (one field, shed, barn) as a subset of the full farm.

### PP-06 Doc 03 Creature, AI Director & Scares
Owner: Game Designer (AI Programmer consulted through QUESTIONS.md).
Output: `docs/03_creature_ai_director_and_scares.md`.
Acceptance:
- Senses with numbers (hearing radii per noise kind, sight range, Taint tracking), behavior states
  and transitions with their audio tells, losing a chase, light rules, day deaths and the trap race
  (tuned so a solo, untainted player who pries at once survives with a few seconds spare), sabotage
  and the disturbance budget, the AI Director (tension meter, phase profiles, day arc, scare rules,
  private events, sanctuary, region-only nudges), jumpscares, hallucinations, fake-outs, Harvest
  Moon acts, bodies, the voice-line list and Dawn Report templates.
- "Fake it first" DD Phase 1 version (scripted trap spots and timers) described separately.
- Every number cites doc 01 or is marked `placeholder`.

### PP-07 Doc 05 Technical Design
Owner: Gameplay. Output: `docs/05_technical_design.md`.
Acceptance: architecture, scene and autoload layout, data loading from `data/`, save at dawn
(what's saved, never voice), log events (full list, section 10 format), the Noise interface agreed
with the AI Programmer, debug top-down view (sensed vs true positions), interaction-hold framework,
how every system follows the CONTRACTS section 5 authority split.

### PP-08 Doc 07 Art Direction & Asset List
Owner: Technical Artist. Output: `docs/07_art_direction_and_asset_list.md`.
Acceptance: art direction (low-poly, scale, palette); lighting plan for day, dusk, night and dark
buildings; the flicker rule (only ghosts flicker lights, enforced how); full asset list with names
per CONTRACTS section 3, dimensions and priority per DD phase; corn rendering budget for 4 players;
Dawn Report card style.

### PP-09 Doc 08 Audio Design & Sound List
Owner: Audio Designer. Output: `docs/08_audio_design_and_sound_list.md`.
Acceptance: buses and mix rules; ambience layers and how Stalk drops them; each body's signature;
every creature state tell; full sound list with IDs, every placeholder marked as such and how it is
generated; voice tells with the Network & Voice Programmer; no downloaded audio without a listed
source and license for CEO approval.

### PP-10 Doc 09 Playtest Plan
Owner: QA. Output: `docs/09_playtest_plan.md`.
Acceptance: for each DD phase, its "done when" test from doc 01, the log measures that prove it,
session rules (2 sessions, one tester who hasn't read doc 01), the spatial audio test procedure
(10, 30, 60 m, voice and whistle), the trap race check, and the review checklist QA applies to every
task, including voice settings and recording rules.

---

## Studio phase 2: DD Phase 1 (prototype)

Source: doc 01 "Build Plan > Phase 1", doc 05 section 20 (build order), doc 03 section 18 (fake it
first), doc 04 section 9 (small layout), doc 09 section 3 (the gate). Voice between two machines
already passed (STOP 1). **Done when** (doc 01): the day feels safe, the night tense, at least 30% of
lures make the target walk toward them, and the spatial audio test (10/30/60 m) is run. Checked in 2
sessions, one tester who hasn't read doc 01, plus log measures (doc 09). **STOP 2** after P1-14 for
the CEO playtest.

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| P1-01 | Game Designer | Data files for Phase 1: `labor`, `crops` (turnip), `creature`, `voice_lines`, timers; Director approves schemas in CONTRACTS 6 | done | — |
| P1-02 | Gameplay | Core: `Log`, `Data`, `Settings`, `Clock`, `Game`, boot to main; 2 instances join over ENet | done | P1-01 |
| P1-03 | Level Designer | Gray-box Phase 1 farm (`farm_phase1.tscn`, x -32..46) with all markers | done | — |
| P1-15 | Network & Voice | Move the ENet host/join, roster, handshake and `apply_clock` rpc from `Game`/`Clock` into `game/net/Net` (doc 06); raw-IP join (Tailscale, D-024); `grep_rules` `rpc_outside_net` clean | done | P1-02 |
| P1-04 | Gameplay | Player controller, crouch, sprint, remote proxies, host speed check, `NoiseBus.emit_kind` | done | P1-02, P1-03, P1-15 |
| P1-05 | Gameplay | Hold framework + turnips: plant, water (noisy can), harvest, sell at (40, 20), `hold_completed` | done | P1-04 |
| P1-06 | Network & Voice | Move the spike voice into `game/`: proximity voice, VAD/PTT, `VoiceEmitter`, voice reports to `Noise` | done (Q-042 push_to_talk setting owed by Gameplay) | P1-04 |
| P1-07 | Gameplay | Generator, fuel drum, lights, go-still ring, crouch noise | done | P1-05 |
| P1-08 | AI Programmer | Scripted creature: Lurk/Stalk/Chase/Retreat timers, wander and chase by sound, scripted traps and pits, stranger lines from the corn, lure logging | done | P1-04, P1-06 |
| P1-09 | Gameplay | Trap race, death, ghost spectate, `apply_creature_state` hooks | done | P1-08 |
| P1-10 | Audio Designer | Three ambience layers from creature state, trap and step sounds, whistle, stranger-line synthesis | done | P1-08 |
| P1-11 | Technical Artist | Day, dusk, night lighting, dark buildings, fog, corn render budget | done (corn budget unmeasured, check in P1-14) | P1-03 |
| P1-12 | Gameplay | Spatial audio test scene with `spatial_audio_trial` logging; debug view | done | P1-06, P1-03 |
| P1-13 | AI Programmer | Bot that walks and does chores | done | P1-05 |
| P1-14 | QA | Review each P1 task; 2-instance run; `check_logs.py` on a full session; run the doc 09 gate | done (human gate measures run at STOP 2) | all above |
| P1-16 | Gameplay | STOP 2 readiness (Q-046): fix the stamina flicker at 0 so no `speed_violation` on a human sprint; minimal prompt layer (hold prompt for the aimed target, stamina bar, clock and phase, coins, a one-screen controls hint on first spawn, death and ghost banner); emit `inside_at_night`; Shaken logged on client | done (human gate measures run at STOP 2) | P1-14 |
| P1-18 | Level Designer | Corn walkable: local player no longer blocks on layer 5 (playtest issue 5) | done | P1-16 |
| P1-19 | Gameplay | Playtest fixes: visible watering and fuel cans, hold race, spectate smoothing, ghost voice muted, 12 plots open (issues 4, 9-12) | done | P1-16 |
| P1-20 | AI Programmer | Playtest fixes: trap clues on every peer, lures in the scripted lurk, scripted stalk keeps 18 m and no kill in the first 2 s of a chase (issues 6-8) | done | P1-16 |
| P1-21 | Audio Designer | Playtest fixes: no day music in docs, voice range 10 m / 120 m, +6 dB default gain (issues 1, 2) | done | P1-16 |
| P1-22 | Director | Auto-updater (`update.ps1`, `Update.bat`, `--release`) and install page `docs/10_install_and_updates.md` (issue 3) | done | P1-16 |
| P1-17 | QA | Playtest kit: session tool, observer tally, log collection, report, Windows packager with host/join launchers, tester brief | done | P1-14 |

Each owner turns their row into acceptance from the cited doc sections when starting; every task
still needs QA pass plus Director check.

---

## DD Phase 2: Barn recording, theft, death costs, two fields

Approved by the CEO 2026-10-08. Source: doc 01 "Build Plan > Phase 2", doc 06 sections 11 and 12
(barn chatter, lures, clip pre-sharing), doc 03 sections 10 and 12 (sabotage, voice mimicry), doc 02
section 8 (medical bill), doc 04 (full layout). **Done when** (doc 01): a friend's recorded voice
fools someone, and trap sweeps feel worth doing. Checked in 2 sessions, one tester who hasn't read doc
01, plus log measures (doc 09). The Phase 1 lure walk-toward measure (30%) is deferred to Phase 3 (CEO, 2026-10-08). The 10/30/60 m spatial
test is closed (CEO, D-033). **STOP 3** after P2-09: closed by the CEO without human sessions (D-057).

P2-01 review (D-034): sabotage from the disturbance budget moves to DD Phase 3, because doc 01 lists
only pegboard theft for Phase 2 and the AI Director spends the budget (doc 03 s10). Three rows are
added for what the Phase 2 rows need and nothing builds yet: a menu and lobby (P2-10), the player side
of trap sweeps (P2-11), and Phase 2 data (P2-12).

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| P2-01 | Director | Between-phase review: read Phase 1 logs and notes, add new problems to OPEN_ISSUES, settle what Phase 2 needs, turn rows below into acceptance | done | — |
| P2-12 | Game Designer | Phase 2 data: medical bill, night trap counts, pegboard lock, recording takes; Q-048 (1) numbers | done | P2-01 |
| P2-02 | Level Designer | Full farm: second field, corn between the two fields, 4-player spawns, pegboard and recording-spot markers (doc 04) | done | P2-01 |
| P2-10 | Gameplay | Host/join menu, barn lobby before the match, pause menu with voice setting and push-to-talk (doc 05 s16, Q-042, Q-047) | done | P2-01 |
| P2-03 | Network & Voice | Staged barn recording: lobby lines, chatter and voice settings, clip capture and pre-share to all peers (doc 06 s11-12) | done | P2-10 |
| P2-04 | AI Programmer | Replay recorded clips as lures, voice mimicry choice, tells and success logging (doc 03 s12) | done | P2-03 |
| P2-11 | Gameplay | Trap sweeps, player side: disarm, fill pit with a shovel, flags, hang traps on the pegboard (doc 05 s11) | done | P2-02, P2-12 |
| P2-05 | AI Programmer | Night traps on the full farm from doc 02 s11 counts; pegboard theft and lock (doc 03 s9) | done (spacing rules coded, no map spot near enough to test) | P2-02, P2-11, P2-12 |
| P2-06 | Gameplay | Dawn respawn and medical bills, day deaths billed at next dawn (doc 02 s8) | done | P2-12 |
| P2-07 | Gameplay | Up to 4 players, 5 and 6 scaled (D-038): roster, spawn, player cap from data, bots fill to 4 (doc 05, `player_scaling.json`) | done | P2-02 |
| P2-13 | Game Designer, Level Designer | 5 and 6 players (D-038): scaling data to 6, 6 barn spawns | done (spawn scene committed with P2-14) | P2-12, P2-02 |
| P2-14 | Level Designer, Gameplay | Field plots scale above 4 players (D-039): 32 plot sites, locked by headcount | done | P2-13 |
| P2-08 | Audio Designer | Clip playback tells, chase sting (Q-048), barn ambience for the recording spot | done (CEO listen owed) | P2-03 |
| P2-15 | Gameplay | Comfort and convenience settings (D-047): camera shake, centre dot, per-player voice volume and mute, toggle holds, toggle sprint, invert Y, menu text size | done | P2-07 |
| P2-16 | Gameplay, Network & Voice | Lobby-only joins, reconnect by `player_uid` (D-048): refuse new players after match start and non-season players on a loaded save; reconnecting roster player returns as a ghost with slot and role kept; rejoin prompt from `user://last_session.cfg`, join code in lobby and pause menu and on the Join screen, rejoin mockery line from a per-player shuffle bag, no repeats until all 50 are seen (D-049, D-050) | done (rejoin box, toast and pause-menu code checked windowed by the CEO 2026-10-08; match-end clear waits for season end) | P2-07 |
| P2-17 | Network & Voice | P2-16 follow-ups: a client with no clips sends digest `""`, which `clips.gd` reads as recording and holds the lobby start; align doc 06 refusal table with code (`full`, `match_in_progress`, `not_in_season`, `no_identity`); `net.gd` join timer logs "no session_state" as ERROR when the host quits after a leave; "farm is full" menu message | done | P2-16 |
| P2-18 | Network & Voice | Join hardening: refuse a joiner whose game version differs from the host's (`version_mismatch`, doc 06; today the host only logs `net_join_version`); stop host sends to a refused peer before it disconnects (18 `Unable to send packet on channel 2` from `players.gd:71` via `net.gd` `send_bytes`, QUESTIONS P2-17 note); menu message for each | done (voice relay through the send filter not run live) | P2-17 |
| P2-19 | Gameplay | Q-056: instant `take_trap` verb and HUD label for a loose trap (today it borrows the 5 s `disarm_bear` hold) | done (`hands_full` by code read) | P2-05 |
| P2-09 | QA | Review each P2 task; 4-instance run; `check_logs.py` on a full session; doc 09 Phase 2 gate | done (CEO closed STOP 3 2026-10-08, D-057; human sessions not run) | all above |
| P2-20 | Gameplay | P2-09 findings A, B, D: a bare exe launch plays the Phase 1 farm (make the full farm the default); `ERROR: 1 resources still in use at exit` on every multi run (find it with `--verbose`, free it); `--autochore`/`--autosweep` SCRIPT ERRORs in the lobby (`hold_controller.gd` null `targets`) | done | P2-09 |
| P2-21 | Network & Voice | P2-09 finding C: log `net_rtt` per peer (doc 06 s13, doc 09 "Up to 4 players") | done | P2-09 |
| P2-22 | QA | P2-09 findings E, F: doc 09 names `medical_bill`/`dawn_summary`, not `money_changed`; `check_logs.py` splits recorded vs generic lures, tallies trap sweeps, reports bills; fix `test_two_good_sessions_pass_every_automatic_row` 72 m fixture; repackage the playtest build clean | done (tooling; tests pass) | P2-20, P2-21 |
| P2-23 | Network & Voice | Q-057: `tests/net/test_voice.gd` fails and hangs; `voice_emitter.gd:45` cannot resolve `Settings` in `-s` mode | done (test loads the emitter after a frame) | — |
| P2-24 | Gameplay | CEO local play 2026-10-08: well gives no refill prompt (`station.gd:8` typed-array SCRIPT ERROR, 471 lines); locked plots give no message; dev command to grow crops; physical fuel can and watering can on the map; make Phase 1 night data the default so a launch without `--phase1` doesn't idle the creature | done | — |
| P2-25 | Level Designer | CEO local play 2026-10-08: two barns on the full farm (doc 04 has one) | done | — |
| P2-26 | AI Programmer | CEO local play 2026-10-08: creature parks in front of the barn; traps still not visible | done | P2-24 |
| P2-27 | Gameplay | D-054: watering and fuel cans as physical pickups (pick up, carry, drop, shared); replace the per-player can count; update bots, QA scripts and creature tool theft | done | P2-24 |
| P2-28 | AI Programmer | CEO play 2026-10-08 (`logs/qa/ceo_play5`): creature set no trap all night; sets wait for lurk (doc 03 s9) and a lone player kept it in lure/stalk/chase. Decide a fallback (e.g. set on retreat or after a wait) so planned traps land | done (D-056: 30 s wait, then any state) | — |

Every code task: works with 2+ instances over ENet, runs headless with no new errors, logs what doc 09
s3 "DD Phase 2" reads, and leaves a handoff note. Placeholders cite doc 01 or say `placeholder`.

### P2-12 Phase 2 data
Owner: Game Designer. Output: `data/*.json` with schemas, doc 02 or 03 updated where a number moves.
Acceptance:
- `medical_bill.json` from doc 02 s8 (first, later, cap per headcount; 4-coin floor; overflow to the
  final payment). `Data` loads it (`medical_bill` is already in `Data.TABLES`).
- Night trap counts per day and headcount from doc 02 s11 (bear / pit / bells). Bells are not built in
  Phase 2; say how days 4 to 6 read without them (Director proposal: bells count as nothing).
- Pegboard lock price (doc 02 s10: 40) and theft cap (one trap a night with the lock).
- Recording take weights (loudness, pitch spread; doc 06 s11 `placeholder`s) and the seven fixed
  lines in `voice_lines.json` with their staging cue (lantern out, door bang).
- Answer Q-048 (1): confirm or set `CHASE_TELL_S`, `SCRIPTED_STANDOFF_M`, `TRAP_LURE_M`, and move the
  ones that stay into `creature.json`.

### P2-02 Full farm
Owner: Level Designer. Output: `game/world/farm.tscn` (full doc 04 layout), `build_farm.py` updated.
Acceptance:
- Both fields, the corn between them, the corn ring and strips, barn, shed, farmhouse, well, generator
  as doc 04 s3 to s5. The Phase 1 scene stays loadable for `--phase1`.
- Markers: 22 `trap_spots` with `edge`/`row`/`deep` kinds (doc 04 s7.1), cover points, 4 player
  spawns inside the barn (doc 04 s4 "Respawn and lobby"), pegboard at (-15, 30.5) with
  `pegboard_bear_slots` slots, a recording spot and lantern marker in the barn.
- Doc 04 s8 distance checks rerun on the built scene (15 m lure rule, 72 m far field).
- Corn walkable for players (P1-18) on the new corn. Doc 07 s10 corn budget measured with 4
  instances (Q-046 (2): say total or in view).

### P2-10 Menu, lobby, pause menu
Owner: Gameplay. Output: `game/ui/`, `game/core/` changes.
Acceptance:
- Main menu: Host, Join (code or raw IP, D-024), Settings, Quit. A bare exe needs no `.bat` (Q-047 (3)).
- Lobby: after joining, players stand in the dark barn (doc 04 s4). The host starts the match; start
  waits for clip pre-share (doc 06 s12 step 5, hook for P2-03).
- Pause and settings menus: voice setting `off` / `lobby_lines` (doc 06 s11 "Voice settings", sends
  `request_voice_setting`), `push_to_talk` in `Settings.DEFAULTS` with a toggle (Q-042 (2)), the six
  volume sliders (doc 05 s16). Menu lines follow doc 06 s11 copy rules.
- Settings menu (from main and pause menu, D-035) with four tabs, all saved through `Settings` and
  applied at boot. Keybinds: rebind every InputMap action, reset to defaults, conflict warning. Audio:
  the six sliders, voice setting, push-to-talk, mic device and gain if Voice exposes them. Graphics:
  quality preset, shadows, render scale, VSync, FPS cap; no knob that breaks doc 07 s10 or the light
  rules. Display: window mode, resolution, monitor, FOV, brightness. A screenshot of each tab.
- Recording entry: "Record lines" for unchosen and Lobby-lines players, "Re-record" and "Skip" later
  (doc 06 s11). The recording screen itself is P2-03's.
- `build_id` logged from the export version (Q-047 (1)).

### P2-03 Staged barn recording and pre-share
Owner: Network & Voice. Output: `game/voice/`, doc 06 updated.
Acceptance:
- Doc 06 s11 "Recording" in full: 7 fixed lines plus one per teammate name, 2 to 3 takes, best take
  kept by P2-12's weights, others deleted; 20 to 40 s barn chatter for Lobby-lines players.
- Staging: the barn lantern blows out (never flickers) before "help me", a door bang before "over
  here". The recording light is steady on the recorder's screen and on their character
  (`apply_recording_light`).
- No Off player's voice plays on a capturing machine (D-011); the screen names who is muted.
- `.vclip` format and storage as doc 06 s11; peers keep clips in memory only. Off deletes the files
  and frees every peer's copy; a playing lure of that player stops.
- Pre-share as doc 06 s12 (manifest, 16 KB chunks on channel 3, host caps, late joiner, 30 s timeout).
  Review: play back and delete each clip before the match.
- Tested with `--voice-wav` loopback on 2 instances; QA hears one real recorded line.

### P2-04 Recorded lures
Owner: AI Programmer. Output: `game/creature/`.
Acceptance:
- Doc 03 s12.1 choice: clip, sound or stranger lure; never voices an Off or unchosen player; weights
  dead 3 : alive 1 : own 0.1; exact clips only (splicing is day 4, read the clock day).
- Day lures go to the target only and keep the 15 m rule; night lures are world sounds.
- One tell or none (about a third none), source at a place the teammate could not be (doc 03 s12.2).
- `lure_played` names `line_id`, owner and `tell`; `lure_result` as Phase 1. `check_logs.py` reports
  recorded against generic lure rates (doc 09 s3, read not gated).

### P2-11 Trap sweeps, player side
Owner: Gameplay. Output: `game/traps_player/`, `game/interaction/`.
Acceptance:
- Holds from `labor.json`: `disarm_bear` 5 s, `fill_pit` 4 s (needs a shovel from the shed),
  `place_flag` 1 s, `hang_trap` 1 s (doc 05 s11). Each makes its Noise (doc 05 s8).
- A disarmed bear trap is a carried item; hung on the pegboard it shows on a slot
  (`apply_pegboard_changed`). Flags are world objects for everyone (`apply_flags`).
- `trap_changed` logs `disarmed` and `filled`; doc 09 s3 "trap sweeps" reads them.
- Clues as P1-20 (4 m, facing). QA looks at one of each in a window.

### P2-05 Night traps and pegboard theft
Owner: AI Programmer. Output: `game/creature/`.
Acceptance:
- Replaces Phase 1 scripted traps on the full farm: counts from P2-12 by day and headcount, spots near
  the region players work, deep spots for bear traps, rules in doc 03 s9 (sanctuary, lit door 6 m,
  one per 8 m circle).
- Pegboard (D-053): the board plus off-board traps are the creature's only bear-trap supply; off-board
  first, then the board; sets beyond supply are skipped. The lock caps all theft at one a night
  before day 5. A trap in a dark building is stolen; one in a building lit all night turns up unarmed
  in the corn at dawn. Log events as CONTRACTS s10 (D-053).
- `--phase1` keeps the scripted traps.
- The Creature exposes `clear_trap(id)`; `trap_race.gd` stops reaching into `_traps` (P2-11 handoff).

### P2-06 Dawn respawn and medical bills
Owner: Gameplay. Output: `game/ghost/`, `game/core/`.
Acceptance:
- Dawn in doc 02 s9 order for steps 1 and 3 (cash-in, medical bill); later steps stubbed.
- Bill from P2-12 for the headcount at the billing dawn; day deaths count toward the next dawn; bank
  floor 4 coins, the rest added to the final payment. `money_changed` with `reason` `medical_bill`.
- The dead respawn at a barn spawn at dawn. The dead lose what they carried.
- `dawn_summary` logged (doc 05 s18).

### P2-07 Up to 4 players
Owner: Gameplay. Output: `game/player/`, `game/net/` as needed.
Acceptance:
- 4 instances join, spawn at P2-02's barn spawns, and play a day and a night with no desync (doc 09 s7).
- Headcount scaling through `player_scaling.json` (doc 02 s4) for bills and trap counts.
- `--bots=N` fills empty slots up to 4.
- `net_bandwidth` logged; compared with doc 06 s13's 4-talker estimate.

### P2-13 5 and 6 players (D-038)
Owner: Game Designer (data), Level Designer (spawns). Output: `data/*.json`, doc 02, `game/world/farm.tscn`.
Acceptance:
- `player_scaling.json` covers 2 to 6 (`max_players` 6; 120% at 5, 140% at 6, `placeholder`); schema
  updated. Every table that reads headcount (medical bill caps, night trap counts, ramp-up, roles,
  plots per player) gives a value at 5 and 6, cited or `placeholder`. Doc 02 s4 updated.
- Six barn spawns in `farm.tscn` (doc 04 s4 updated); doc 04 s8 checks still pass.

### P2-14 Field plots by headcount (D-039)
Owner: Level Designer (sites), then Gameplay (unlock). Output: `game/world/farm.tscn`, doc 04, `game/farming/`.
Acceptance:
- 32 field plot sites across both fields (doc 04 s8 walk and space checks rerun); each extra site
  names the headcount that opens it. Moonflower bed unchanged.
- Gameplay opens `field_plots_start_by_players` plots at match start and lets the store sell up to
  `field_plots_max_by_players` (`player_scaling.json`), not `season.json`. 2 instances and 6 instances
  over ENet agree on which plots are open.

### P2-08 Audio for Phase 2
Owner: Audio Designer. Output: `game/audio/`, `assets/audio/`, doc 08.
Acceptance:
- Chase sting and creature signature on every peer when the state turns `chase` (Q-048 (2)). Try the
  kill-warning heartbeat after the sting exists (OPEN_ISSUES playtest 8 note). No day music (memory
  rule, CEO).
- Clip tells through the shared chain (doc 06 s9): echo, pitch up/down, no crackle.
- Barn lobby ambience, lantern blow-out and door bang for P2-03's staging.

### P2-09 Phase 2 review and gate
Owner: QA. Acceptance: each P2 task reviewed against its block; 4-instance run; `check_logs.py` on a
full session; doc 09 s3 "DD Phase 2" rows run in 2 sessions with one fresh tester. The first session
also rechecks the Phase 1 playtest fixes no human has seen (OPEN_ISSUES "Found at the Phase 1
playtest" 1, 4, 5, 6, 9 to 12).

---

## DD Phase 3: Ghosts, the AI Director, Taint and the Dawn Report

Approved by the CEO 2026-10-08 (D-058). Source: doc 01 "Build Plan > Phase 3": dead
players' voices favored; the AI Director, day arc and jumpscares; Taint and Shaken; ghosts with flicker
and crow; whistle, flags and the Dawn Report. **Done when** (doc 01): the dead stay engaged, the living
argue over a static voice, and someone laughs at the Dawn Report. Checked in 2 sessions, one tester who
hasn't read doc 01, plus log measures (doc 09). **STOP 4** after P3-13: closed by the CEO without human
sessions (D-068); bodies (Open Issue 4) move to Phase 4.

Carried in: sabotage and the disturbance budget (D-034); the Phase 1 lure walk-toward measure, 30%
(deferred, CEO 2026-10-08); both Phase 2 measures, unproven (D-057); the P2-08 CEO listen. Flags are
built (P2-11); Phase 3 only reports them (Dawn Report).

P3-01 review (D-059): doc 01 lists Phase 3 by feature, but docs 03, 05 and 06 also specify pieces
that belong to Phase 4, so these wait: the `harvest_moon` profile and acts (doc 03 s14), `pumpkin_gnaw`
(no Prize Pumpkin yet), `broken_fence` (no animals or pen yet), spliced clips (doc 03 s12.1, "from day
4"; exact clips only) and walkie-talkies (store items). Ghost rustle stays in: doc 01 "Ghosts" and doc
03 s13 list it with flicker and crow.

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| P3-01 | Director | Between-phase review: OPEN_ISSUES, settle what Phase 3 needs, write acceptance for the rows below | done (D-059) | — |
| P3-02 | Game Designer | Phase 3 data (doc 03 s19): Director profiles and tension meter, day arc, scare rules, disturbance budget, Taint and Shaken numbers, Dawn Report templates (doc 03 s8, s10, s11, s13, s17) | done (D-060) | P3-01 |
| P3-03 | AI Programmer | Dead players' voices favored in lure choice (doc 03 s12.1; weights from `ai_director.json` `lures`) | done | P3-02 |
| P3-04 | AI Programmer | AI Director: tension meter, profiles, day arc, region nudges, private events, debug (doc 03 s11); it budgets lures in place of `DAY_LURE_GAP_S` | done | P3-02 |
| P3-05 | AI Programmer, Audio Designer | Jumpscares, fake-outs, hallucinations (doc 03 s13), spent by the Director | done | P3-04 |
| P3-06 | AI Programmer | Sabotage from the disturbance budget (doc 03 s10, D-034) | done | P3-04 |
| P3-07 | Gameplay, AI Programmer | Taint and Shaken: player side and the well (doc 05 s10), creature tracking (doc 03 s3.3, s8); Taint is off since Phase 1 | done | P3-02 |
| P3-08 | Technical Artist, Audio Designer | Taint stain and Taint heartbeat; scare and Director sounds (doc 07, doc 08) | done | P3-05, P3-07 |
| P3-09 | Gameplay, Technical Artist | Ghosts: lantern flicker, crow possession and corn rustle (doc 01 "Ghosts", doc 05 s14, doc 03 s13, doc 07) | done | P3-01 |
| P3-10 | Network & Voice, Audio Designer | Ghost voice: the ghost static chain on dead players' voice to the living and on dead-voice lures (doc 06 s9, D-011); today ghost voice is muted (OPEN_ISSUES playtest 9) | done (CEO listen of the static pending) | P3-09 |
| P3-11 | Gameplay | Whistle and emotes (doc 05 s14); recheck whistle placement by ear (OPEN_ISSUES P2-01 review 1) | done (by-ear test pending a tester, OPEN_ISSUES) | P3-01 |
| P3-12 | Gameplay, Technical Artist | Dawn Report screen: headlines, obituaries, hero actions, flags placed (doc 05 s15, doc 03 s17, doc 07 card style) | done | P3-02 |
| P3-13 | QA | Review each P3 task; 4-instance run; `check_logs.py` on a full session; doc 09 Phase 3 gate plus the carried measures | done (STOP 4 pending: dead stay engaged, static-voice argument, Dawn Report laugh, bodies blocked by Q-074, by-ear whistle, Phase 1 lure over 20 human results, Phase 2 fooled and sweeps, CEO static listen) | all above |

Every code task: works with 2+ instances over ENet, runs headless with no new errors, logs what doc 09
s3 "DD Phase 3" reads, and leaves a handoff note. Placeholders cite doc 01 or say `placeholder`.
Hunting reads `sensed`, presentation reads `true` (doc 03 s20); the review checks it on every AI row.

### P3-02 Phase 3 data
Owner: Game Designer. Output: `data/ai_director.json`, `sabotage.json`, `dawn_report_templates.json`
with schemas (doc 03 s19), Taint and Shaken numbers (doc 02 s13), approved in CONTRACTS s6.
Acceptance:
- `ai_director.json`: tension meter inputs, range, thresholds and phase timers (doc 03 s11.1);
  `day` and `night` profiles (s11.2); day arc thirds as fractions of `day_s`, not 180 s fixed
  (s11.3); scare rules and rarity (s11.4, s13); nudge cooldown (s11.6). No `harvest_moon` values.
- `sabotage.json`: the pool rows built in Phase 3 (`trample`, `stolen_tool`, `dead_crow`,
  `strange_seeds`, `scarecrow_moved`, `generator_kill`), each with a `fix`; `Data` test fails a
  record with no `fix` (doc 03 s10.1).
- Taint causes, effects and cure, and Shaken length, in one table (doc 05 s10 names `taint.json`;
  pick it or `creature.json`, and fix the other doc).
- `dawn_report_templates.json`: doc 03 s17.1 to s17.3 and s17.5 (season awards wait for Phase 4).
- Hallucination opens on day 5 (doc 03 s13): say how a 2-day test session reaches it.

### P3-03 Dead voices favored
Owner: AI Programmer. Output: `game/creature/`.
Acceptance:
- Lure owner weights 3 : 1 : 0.1 dead : alive : own (doc 03 s12.1) from data; a dead owner's night
  lure plays as a world sound with `apply_lure.ghost` true.
- `lure_played` logs `owner_dead`; a headless run with one dead bot shows dead owners chosen more
  than their share. Off and unchosen players are never voiced (unchanged).

### P3-04 AI Director
Owner: AI Programmer. Output: `game/ai_director/`, debug view (doc 03 s11.7).
Acceptance:
- Host-only tension meter and phases from `ai_director.json`; logs `tension` every 10 s with
  meter, phase and profile (doc 09).
- Regions as `Area3D` nodes (Level Designer adds them to `farm.tscn` if missing); a nudge sets the
  wander region only, one hop, cooldown from data (s11.6).
- Day arc: the first third places disturbances only, no presence or scare; the creature stays 25 m
  from the field the group works in (s11.3).
- Scare budget: at most 1 big scare per player per day, none within 120 s on one player, private
  events count; unscared players weighted 3 : 1 (s11.4). A daily roll varies distances but never
  adds a death condition.
- Lure budget replaces `DAY_LURE_GAP_S`. Sanctuary: no lure, scare or kill within 10 m.
- Debug view draws true creature, each `sensed` marker, region, meter and phase.

### P3-05 Scares
Owner: AI Programmer (logic), Audio Designer (build-up and stingers). Output: `game/creature/`,
`game/ai_director/`, `game/audio/`.
Acceptance:
- Jumpscare (Shaken 60 s, never Taint), the whisper, the shed, wrong count, your own voice,
  hallucination (day 5 on, x2 for Tainted), crow fake-out, scarecrow moved; rules and placement as
  doc 03 s13. Disarm lunge and "the trap" too if the trap race code allows it; else say so.
- Private scares go to one peer only (`apply_scare` with target slot, doc 06 s7); public ones to all.
- Each scare logs `scare` with `kind`, `target`, `big`, `private`; the build-up (insects cut,
  silence) plays first. No jumpscare in a trap race, sanctuary or lit building.
- A `day N` dev console command (or flag) reaches day 5 for testing.

### P3-06 Sabotage
Owner: AI Programmer. Output: `game/creature/` or `game/ai_director/`, with Gameplay for the fixes.
Acceptance:
- The Director spends the day's disturbance count (doc 02 s11) from `sabotage.json`; days 1-2
  only `trample` or `stolen_tool`; pool opens by day (doc 03 s10).
- Placed by region, never at a player; each leaves its clue and has its fix (replant, bury 4 s,
  pull 3 s, refuel); a stolen tool lands by an armed trap 60% and Taints on pickup.
- Trample at dawn per doc 03 s10 (1, 2 if nobody outside 30 s, +1 dead generator, unattended cap +3).
- Logs `disturbance_placed` and `disturbance_fixed`; `dawn_summary.farm_damage` filled.

### P3-07 Taint and Shaken
Owner: Gameplay (player side, well), AI Programmer (creature side). Output: `game/player/`,
`game/interaction/`, `game/creature/`.
Acceptance:
- Host-owned Taint flag with a cause; `apply_taint_changed`; sprint x0.6, pry x1.5, steps x1.5
  (`NoiseBus` already reads `tainted`); `wash` hold 10 s at the well clears it and emits `well_pump`.
- Causes built this phase: creature leavings, stolen tool, item left in the field at dusk, dead crow,
  strange seeds (doc 03 s8). A moonflower cause waits if moonflowers are not built; say so.
- Shaken 60 s after a jumpscare or a survived trap race; stacks with Taint (x0.36). Never Taints.
- Creature tracks a Tainted player within 60 m and follows a 20 s night trail (doc 03 s3.3).
- Logs `taint_changed` (peer, on, cause) and `shaken` (peer, seconds).

### P3-08 Taint and scare look and sound
Owner: Technical Artist, Audio Designer. Output: `game/render/`, `game/audio/`, `assets/audio/`.
Acceptance:
- Taint shows as hand smudges and a faint screen fog for the Tainted player, black stains underfoot
  (doc 05 s10, doc 07); the wet heartbeat plays only for the Tainted player (doc 08).
- Scare build-up cues and stingers for P3-05 kinds (doc 08). No day music (CEO).
- Every new sound gets a CEO listen before it ships (D-0xx as P2-08); list them in the handoff.

### P3-09 Ghost powers
Owner: Gameplay (requests, host rules), Technical Artist (flicker look). Output: `game/ghost/`,
`game/render/`.
Acceptance:
- `request_flicker(light_id)` from ghosts only, host cooldown (placeholder); every peer sees the
  flicker. A blown-out lantern never flickers (doc 03 s20).
- `request_possess_crow(crow_id)` at `crow_perches`: once a night, 20 s, caw action, sight of the
  creature (doc 05 s14, doc 03 s13).
- Corn rustle from a ghost: a sound only, no creature Noise.
- Ghosts see the creature as a smeared silhouette within 20 m and never see traps.
- Logs `ghost_action` with `kind` (`flicker`, `crow`, `rustle`, `caw`) and `peer`; QA adds it to
  doc 09 s13 and `check_logs.py`.

### P3-10 Ghost voice
Owner: Network & Voice (routing), Audio Designer (static chain). Output: `game/voice/`,
`game/audio/voice_chain.gd`.
Acceptance:
- The living hear a dead player's real voice from the ghost's position through the ghost static
  chain (doc 06 s9, doc 05 s14); ghosts hear each other clean. Replaces today's mute (playtest 9).
- Ghost frames never feed the creature (D-011, unchanged).
- Dead-voice lures use the same static chain, so static alone cannot tell real from fake; only the
  flicker settles it (doc 01 "The dead-voice twist").
- CEO listen of the static before P3-13.

### P3-11 Whistle and emotes
Owner: Gameplay. Output: `game/player/`, `game/audio/`.
Acceptance:
- `request_whistle` with cooldown; `apply_whistle` world sound at its long range (doc 08); emits
  `whistle` (50 m) to the creature. No minimap marker (doc 05 s14).
- Emotes `wave`, `point`, `shrug`, `scream` (scream emits `voice` at 255); host rate limit 1 per s.
- Logs `whistle` and `emote`. One tester places the whistle by ear at 30 and 72 m (OPEN_ISSUES
  P2-01 review 1); result goes to OPEN_ISSUES.

### P3-12 Dawn Report
Owner: Gameplay (screen, host build), Technical Artist (card style). Output: `game/ui/`.
Acceptance:
- Host builds the report at dawn from the night's events and sends `apply_dawn_report` (lure
  references, no audio); sections Best Impression, Most Wanted, Cause of Death, Hero of the Night,
  lure replay, flags placed (doc 05 s15, doc 03 s17).
- Replays play local clips with their tell and ghost flag; Off players show text plus sound;
  streamer-safe mode never replays voice.
- Shown after the dawn order's money steps, skippable; applies nothing. Logs `dawn_report_shown`.

### P3-13 Phase 3 review
Owner: QA. Acceptance: review each P3 row against the above; 4-instance run with bots and one dead
bot; `check_logs.py` reports tension, scares per player (gap and count rule), Taint and Shaken,
ghost actions; doc 09 Phase 3 gate. Carried: Phase 1 lure 30%, Phase 2 recorded-voice and trap sweep
measures (D-057), OPEN_ISSUES Open Issue 4 (bodies).

---

## Later phases

Written at the end of the previous phase's review. Not started without CEO approval.

Carried notes for those rows:
- When the creature model is built (3D Artist), the Audio Designer redoes the scare and the thud in
  `cre_jumpscare_hit` to fit its body and voice. The running steps stay (CEO, P3-08 listen 5).

---

## DD Phase 4: Full season, economy and the simulator

Started by the CEO 2026-10-08 (D-069). Source: doc 01 "Build Plan > Phase 4": first the simulator hits
its targets; then the full 7-day season, crops, economy and Prize Pumpkin; upgrades, roles and
payments; foreclosure, saving, joining and leaving; the short season and the Harvest Moon. **Done
when** (doc 01): teams sometimes win and sometimes lose, and the logs land within 15 points of the sim
(doc 02 s18.5). Checked in human sessions plus log measures (doc 09). **STOP 5** after P4-18.

Carried in: everything D-068 lists as unproven (run `tools/qa/playtest/checklist_p3.md` in the first
human sessions); the items D-059 held back (`harvest_moon` profile and acts, `pumpkin_gnaw`,
`broken_fence`, walkie-talkies; spliced clips stay Phase 5 per doc 01); Open Issue 4 bodies (D-068).

P4-01 review (D-070): the eight draft rows became seventeen, so each row is one system a reviewer can
check. Animals, the pen and `broken_fence` are in, gray-box (D-071): doc 01 "Daytime Threats" names
broken fences, the Rancher perk needs animals, and the pen, gate and escape spots are already built
(doc 04 s7.3). All ten doc 01 roles are built: the CEO overruled D-072 (D-077), so P4-03 sets placeholder perks for
the six. Models are new work: `assets/` holds only audio, so P4-16 builds the Phase 4 models in Blender
5.2 (doc 07 s12), gray-box first, no downloads. Waiting past Phase 4 (doc 01): Imposter mode, Dev toys and Quirks ("after DD Phase 4"); live and spliced clips, next season
and cosmetics (Phase 5). Open questions are answered or routed in D-073 to D-076 and QUESTIONS.md.
Feature rows wait for P4-02 because doc 01 puts the simulator first; P4-13, P4-16 and P4-17 change
no economy number and can start now.

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| P4-01 | Director | Between-phase review: OPEN_ISSUES, open questions, settle Phase 4 scope, write acceptance for the rows below | done (D-070) | — |
| P4-02 | Game Designer | Season simulator (doc 02 s18): `tools/sim/sim.py`, median policy, variance, scenarios, s18.4 tests, then tune `sim` and `placeholder` values until the s18.3 targets pass | done (QA PASS; D-078, D-079) | — |
| P4-03 | Game Designer | Phase 4 data: pumpkin, debt, difficulty, roles, store effects, crops, `harvest_moon`, Phase 4 sabotage, animals, season awards, Dawn Report gaps | done (QA PASS; follow-ups D-082) | P4-02 |
| P4-04 | Gameplay | Full 7-day season: every crop, town stand selling, dawn steps 1, 2, 5 and 7, season end, doc 05 s18 events; carried fixes | done (QA PASS; trample order Q-086) | P4-02, P4-03 |
| P4-05 | Gameplay, Technical Artist | Prize Pumpkin: patch, growth, sizes, carrying, judging (doc 02 s6) | done (QA PASS; lift rule D-084) | P4-04 |
| P4-06 | Gameplay, AI Programmer | Store and upgrades: every `store.json` item works (doc 02 s10) | done (QA PASS; scrap D-085) | P4-04 |
| P4-07 | Gameplay | Debt, payment dawns, early payment, Foreclosure (doc 02 s7) | done (QA PASS; D-086) | P4-05 |
| P4-08 | Gameplay, AI Programmer, Level Designer | Animals and `broken_fence`: pen animals, escape, round-up (D-071) | done (QA PASS after QA fixes) | P4-03 |
| P4-09 | Gameplay | Roles: all ten doc 01 roles, lobby pick, locked per season (D-077) | done (QA PASS after QA fixes) | P4-04, P4-08 |
| P4-10 | Gameplay, Network & Voice | Saving at dawn, loading, host left, joining and leaving mid-season with headcount scaling | done (QA PASS 2026-10-09; Q-145 refusal flake, Q-122 AI Director state unsaved) | P4-07 |
| P4-11 | AI Programmer, Gameplay | Phase 4 sabotage and difficulty: `pumpkin_gnaw`, full-wipe doubling, difficulty settings | done (QA PASS; `stolen_tool` beyond cans deferred to Q-113) | P4-05, P4-06 |
| P4-12 | AI Programmer, Gameplay, Technical Artist | Short season and the Harvest Moon: festival cart, acts, `harvest_moon` profile (doc 03 s14) | done (QA PASS after QA fixes: cart comment, season awards test; Q-125..Q-129 open, Q-155) | P4-05, P4-07 |
| P4-13 | AI Programmer | Creature body per season: host seeded pick, logged, `--body=<id>` dev flag (doc 01 "Bodies", Q-074, D-068) | done (save and load waits for P4-10, Q-076) | P4-01 |
| P4-14 | Network & Voice | Walkie-talkies as store items (doc 06 s10, doc 02 s10) | done (QA PASS after QA fixes; range Q-116) | P4-06 |
| P4-15 | Gameplay, Technical Artist | Season Awards and season end screens (doc 03 s17.4, doc 05 s15) | done (QA PASS after QA fixes; Q-130 win rule wired, cart_out via Q-131) | P4-07 |
| P4-16 | 3D Artist, Technical Artist | Phase 4 models in Blender 5.2: four bodies, pumpkins, patch, cart, town stand, animals, store items (doc 07 s12) | done (QA PASS; nits for a later pass in handoff) | P4-01 |
| P4-17 | Audio Designer | Phase 4 sounds: cart, gnaw, flare, radio, animals, signature variants, UI (doc 08 s11) | done (CEO listen pending, doc 08 s14 item 11; per-body cre_jumpscare_hit done, D-081) | P4-01 |
| P4-19 | 3D Artist | Final art for the four creature bodies, glimpse parts and smear hulls (D-087) | done (QA PASS after QA fix: husk heart visible) | P4-16 |
| P4-20 | Technical Artist | Final night look: phase lighting, fog, darkness, post stack, creature materials (D-087) | done (QA PASS after QA fixes: HUD below post layers, Harvest Moon disc; Q-150 open) | P4-16; creature materials after P4-19 |
| P4-21 | AI Programmer | Bot seasons stand in for a median team (Q-157): bots go inside at night, save for the payment, plant the Prize Pumpkin; speed fix under `--time-scale` | done (QA FAIL line 2 fixed by Director: moonflower reserve; 2p still forecloses, labour-bound Q-162; sentinel Q-164 for CEO) | P4-18 fixes |
| P4-22 | Gameplay | CEO session: store menu lists every item on interact; seed shop with a seed choice that planting uses; hotbar showing held items and how to use them | done (QA PASS; seeds bought into a team stock, D-093) | P4-06 |
| P4-23 | Gameplay | CEO session: menu lobby before the match (roles, settings, ready), no spawning in the barn to pick | done (QA PASS; D-092; Q-176 for CEO) | P4-09 |
| P4-24 | Gameplay | CEO session: minimap in the top right showing the player, buildings, fields, store, well, cart | done (QA PASS; Q-180 for CEO) | — |
| P4-25 | AI Programmer | CEO session: creature stuck in the barn; at dawn place it back in the corn; fix the cause | done (QA PASS) | — |
| P4-26 | Audio Designer | CEO session: new footstep sounds; crickets chirp less often | done (QA follow-ups merged; CEO approved the evened cricket bed 2026-10-09) | — |
| P4-27 | Level Designer | CEO session: farm less open (cover, tree lines, landmarks); festival cart rests on the ground in the barn | done (QA PASS) | — |
| P4-28 | Game Designer | CEO session: simulate a bigger watering can (3 and 4 plots per fill) against the s18.3 targets and the bot-season gap | done (no change: capacity stays 2, CEO 2026-10-09; 3 or 4 breaks s18.3 at 2p and 3p) | — |
| P4-29 | AI Programmer, Gameplay | CEO: a sprung bear trap stays where it sprang; players pick it up and hang it back on the pegboard | done (QA PASS; follow-up sent) | — |
| P4-30 | Game Designer, Gameplay | CEO: sell bonus by player count so 2p makes its payments; sim targets still pass | done (QA PASS; bonus 0 everywhere, Q-210 for CEO) | P4-28 |
| P4-31 | AI Programmer | CEO: players in the town stand sanctuary do not count as outside at night (D-089); bots drop the sentinel job; re-run bot seasons | superseded by D-115, not merged (bots lost 12 of 12 seasons) | P4-21 |
| P4-34 | AI Programmer, Game Designer | CEO: the town stand lowers creature interaction instead of being a sanctuary (D-115); re-run bot seasons and the sim | done (QA PASS with follow-ups; D-115, D-116) | P4-21 |
| P4-35 | Gameplay | CEO: menu lobby as a character line-up scene (D-140); doc 01 menu-lobby wording (Q-176) | done (QA PASS with follow-ups) | P4-23 |
| P4-32 | Gameplay | CEO: the Harvest Moon push bar shows the distance left to the gate, not a stuck 0%; pushers lock to the cart while holding interact | done (QA PASS; follow-ups sent) | — |
| P4-33 | Gameplay | CEO: flag limit per player; remove your own placed flag; flags as small icons on the minimap | done (QA PASS; CEO flag rules D-142) | P4-24 |
| P4-36 | 3D Artist | CEO: a different hat per role (D-144); ten `hat_<role_id>.glb` for the lobby line-up, later the in-game farmer | done (QA PASS with follow-ups) | — |
| P4-37 | Network & Voice | CEO: drop the barn recording; auto-record live clips from in-game speech as the default voice setting (D-146) | done | — |
| P4-38 | Gameplay, Game Designer | CEO: buyable flare shells in the store (D-147); Dawn Report says the flare gun was reloaded | done (QA PASS with follow-ups) | — |
| P4-39 | Gameplay | P4-38 QA follow-up: after a save resumes, `step_free_scrap` (`save.gd:343`) logs `flare_reloaded`, so the next Dawn Report shows a stale reload line. Skip the log on resume or drop report events from before `save_loaded` | done (QA PASS) | P4-38 |
| P4-40 | 3D Artist, Technical Artist | CEO: upgrade models with Blender plus free CC0 libraries, edited to fit doc 07 (D-151); keep file names | done | — |
| P4-18 | QA | Review each P4 task; 4-instance run; headless with no new errors. Human playtest and sim `compare` economy targets waived by the CEO (D-148), moved to a later economy pass | done (CEO closed STOP 5 by starting Phase 5, D-152) | all above |

Every code task: works with 2+ instances over ENet, runs headless with no new errors, logs what doc 09
s3 "DD Phase 4" reads, and leaves a handoff note. Placeholders cite doc 01, doc 02 `sim` or say
`placeholder`. Numbers live in the data files the simulator reads, not in code.

### P4-03 Phase 4 data
Owner: Game Designer. Output: `data/pumpkin.json`, `debt.json`, `difficulty.json`, `roles.json`
(doc 02 A.5, A.6, A.9, A.14), new rows in `crops.json`, `store.json`, `sabotage.json`,
`ai_director.json` and `dawn_report_templates.json`, approved in CONTRACTS s6. Reuse what P4-02
already wrote; the simulator and the game read the same files (doc 02 s18).
Acceptance:
- `crops.json`: pumpkin and moonflower records (doc 02 s5); moonflower seed from day 3, pumpkin seed
  from dawn 4 (doc 02 s10).
- `pumpkin.json`: growth, size thresholds, short-season growth, judging (doc 02 s6, s16).
- `debt.json`: debt by headcount, payment dawns, early payment, pumpkin unlock, Foreclosure seizures
  (doc 02 s7, s4), at the values P4-02 tuned to the s18.3 targets.
- `difficulty.json`: `easy`, `normal`, `nightmare` and the short season (doc 02 s16).
- `roles.json`: all ten doc 01 "Roles": the four doc 02 s15 roles and their numbers, plus placeholder
  perk numbers for the other six, each marked `placeholder` (doc 01: "Placeholder perks are set before
  roles are built"; D-077).
- `store.json`: `effect` numbers for every row (doc 02 s10), including the flare gun's 30 s Retreat
  (doc 01 "Store"). Numbers doc 03 owns are cited there, not copied.
- `sabotage.json`: `pumpkin_gnaw` and `broken_fence` enabled with the doc 03 s10 costs and day gates;
  each keeps a `fix`.
- Animals: chicken, pig, cow (Q-032); head count, round-up hold, and the cost of an animal still out
  at dusk. Doc 01 is silent on that cost: mark it `placeholder` and run it in the sim.
- `ai_director.json`: the `harvest_moon` profile (doc 03 s11.2, s14).
- `dawn_report_templates.json`: season award templates (doc 03 s17.4) and the copy Q-066 item 2
  lists as missing.
- Q-070 items 2 and 4: write the dawn trample placement rule into doc 03 s10.
- Cart speed by number of pushers (doc 05 s13); the doc 03 s14 cap of 900 s stays reachable.

### P4-04 Full 7-day season
Owner: Gameplay. Output: farm, season and dawn code (doc 05 s9, s15); handoff note.
Acceptance:
- A season runs 7 days and ends after the final dawn (doc 02 s3). The short season is P4-12.
- Every crop in `crops.json` plants, grows and harvests (doc 05 s9); no crop name in code.
- Crops sell at the town stand `sell_box` (D-017, doc 07 s11.8) and at the dawn cash-in.
- Dawn runs doc 02 s9 in order. This row builds steps 1, 2, 5 and 7; step 3 is built, step 4 is P4-07
  and step 6 is P4-10, and they slot in without reordering. A test checks the order.
- Doc 05 s18 events for selling, dawn steps and season end; `audio_*` events per CONTRACTS s10
  (Q-073).
- Carried fixes: `TrapArt` for the pegboard and the sprung trap (Q-058); client debug filter (Q-048
  item 4); remove the `voice_spike` main-scene override (Q-047 item 2).
- `DawnReport._close()` logs `dawn_report_closed`; the soundscape listens for it instead of reading
  the private `_open` (D-081).

### P4-05 Prize Pumpkin
Owner: Gameplay; Technical Artist for size steps and the gnawed look. Output: pumpkin code; handoff
note.
Acceptance:
- Pumpkin plots use the `pumpkin_patch` group (doc 04); seed from dawn 4 (doc 02 s10).
- Growth and size thresholds come from `pumpkin.json` (doc 02 s6). Size shows in the world (doc 07
  s11.5, s12), gray-box until P4-16 lands.
- Carrying and judging follow doc 02 s6; the result is logged.
- Pumpkin state saves and loads (P4-10).
- Each `pumpkin_gnaw` logs the time players spend guarding or repairing it, so P4-10 logs can set the
  sim's gnaw guard charge (D-083).

### P4-06 Store and upgrades
Owner: Gameplay; AI Programmer for the creature-side effects. Output: store code, creature hooks;
handoff note.
Acceptance:
- The shipping crate (`store_crate`) sells every `store.json` row at its price and gate (doc 02 s10,
  D-017). No crop is sold at the crate.
- Seeds, scrap (one free each dawn, not stacking), `quiet_watering_can`, `brighter_lantern`,
  `scarecrow`, `plot_pair` and `flare_gun` each do what doc 02 s10 and doc 03 say. Walkie rows are
  stocked; P4-14 builds the radio.
- `flare_gun`: one shot, refilled at dawn step 7, puts the creature in Retreat for 30 s (doc 01
  "Store").
- `plot_pair` adds plots within the doc 02 s4 ceilings.
- Upgrades are tracked as seizable for P4-07 (doc 02 s10).
- Every purchase is logged with item, price and buyer.

### P4-07 Debt and Foreclosure
Owner: Gameplay. Output: debt code; handoff note.
Acceptance:
- Debt is set by headcount from `debt.json` (doc 02 s7, s4).
- Payment due runs at dawn step 4; early payment works (doc 02 s7).
- The pumpkin unlock rule follows doc 02 s7.
- A missed payment forecloses and seizes per doc 02 s7 (plots in pairs, upgrades); the season is lost
  per doc 02 s7.
- Logs `payment_made` and the Foreclosure events (doc 09 s3 "DD Phase 4").

### P4-08 Animals and broken fence
Owner: Gameplay; AI Programmer for `broken_fence`; Level Designer for the fence. Output: animal code,
sabotage hook, pen edit in `game/world/`; handoff note.
Acceptance:
- Gray-box chicken, pig and cow live in the pen (doc 04 s7.3, Q-032); count from P4-03.
- `broken_fence` (doc 03 s10, cost 3, from day 2) breaks a fence section; animals escape toward
  `animal_escape_spots` (at least 60 m from the gate, doc 04 s7.3).
- Round-up is a hold verb that walks an animal back; the Rancher is faster (×0.6, doc 02 s15).
- The fence is fixed with the sabotage `fix` rule (doc 03 s10.1).
- Animals react before the creature arrives (doc 01 "Daytime Threats") with a P4-17 sound.
- An animal still out at dusk costs what P4-03 set.
- The Level Designer adds a breakable fence section if the pen has none.

### P4-09 Roles
Owner: Gameplay. Output: role code, lobby cards (doc 05 s16); handoff note.
Acceptance:
- All ten doc 01 roles with `roles.json` numbers (D-077).
- Picked on lobby cards, optional, locked for the season (doc 01 "Roles").
- A reconnecting player keeps their role.

### P4-10 Saving, joining and leaving
Owner: Gameplay; Network & Voice for host left and joins. Output: save code (doc 05 s17), net
changes; handoff note.
Acceptance:
- Saves at dawn step 6 only (doc 01 "Saving", doc 05 s17); the menu loads a saved season.
- Host left: the season resumes from the last dawn save (doc 06 s5).
- Mid-season joins and leaves recompute headcount scaling and debt (doc 02 s4). The doc 09 s3 case
  passes: 4 players, one drops before dawn 2, total 1,135, first payment 223 (D-079).
- One player left: the game follows doc 06 s5.
- Refused peers no longer get position sends (QUESTIONS, "QA to Director: refused peer gets position
  sends").
- Debt payments and medical bills read `payment_pct_by_players` from `data/player_scaling.json`;
  traps and disturbances keep `pct_by_players` (D-079).
- Logs `save_written`, `net_peer_left`, `net_host_left`, `session_end`.

### P4-11 Phase 4 sabotage and difficulty
Owner: AI Programmer; Gameplay for settings. Output: AI Director changes, lobby settings; handoff
note.
Acceptance:
- `pumpkin_gnaw` (doc 03 s10: from day 3, within 20 m) damages the pumpkin; P4-05 shows it.
- After a full wipe, farm damage doubles and 2 extra traps appear (doc 02 s14).
- `stolen_tool` covers every tool with the doc 03 s10 fix (Q-070 item 6).
- Difficulty multipliers apply after headcount scaling (doc 02 s16); Nightmare has no voice tells
  (doc 03).
- Lobby difficulty and the streamer-safe group option (doc 01 "Difficulty and group settings").
- The ghost flag applies to day and targeted lures too (D-075, Q-068).
- `scares.gd` plays `cre_jumpscare_hit_<body>` (body id without `body_`), falling back to
  `cre_jumpscare_hit` when `Soundscape.creature_body` is empty or the file is missing
  (`ResourceLoader.exists`; `play_2d` fails silently) (D-081).
- D-085: every creature-damage fix (sabotage.json fix verbs, generator repair) spends 1 scrap via
  `Store.take_scrap()`, refused `no_scrap` when none is left; `pumpkin_gnaw` calls `PrizePumpkin.gnaw()` at
  dawn (D-084); the Sabotage dawn trample moves into `Death.step_farm_damage` (Q-086).

### P4-12 Short season and the Harvest Moon
Owner: AI Programmer; Gameplay for the cart; Technical Artist for the sky and the cart lantern.
Output: Harvest Moon acts, cart code, render changes; handoff note.
Acceptance:
- Short season: 3 days, faster pumpkin (doc 02 s16).
- The festival cart follows `CartRoute` R0..R8 (doc 04 s6.1, doc 05 s13); pushers set speed (P4-03).
- Harvest Moon acts per doc 03 s14: cap 900 s, out at x>78, gate at x>105, knock-off 15 s, at most
  2 bites.
- The cart lantern flickers through `LightRig` (doc 07).
- Festival payout at the final dawn (doc 02 s9 step 2).
- Harvest Moon sky (doc 07).
- D-084: `PrizePumpkin.lift_prize` works only at Harvest Moon dusk; carrying blocks other holds. Judging
  moves from `Death.step_final_sale` to the cart finish; escort bites call `PrizePumpkin.bite()`.

### P4-13 Creature body per season
Owner: AI Programmer. Output: body pick in creature code; handoff note.
Acceptance:
- The host picks one body per season from a seed (doc 01 "Bodies", doc 03 s2); clients agree.
- The pick is logged once per season; `--body=<id>` forces it.
- The pick survives save and load once P4-10 lands.
- Until P4-16, bodies differ by sound signature only (doc 08 s6).

### P4-14 Walkie-talkies
Owner: Network & Voice. Output: radio code in `game/voice/`; handoff note.
Acceptance:
- Bought walkies transmit per doc 06 s10; a battery lasts 180 s (`store.json`, placeholder).
- Radio sound per doc 08 s7.2 with the P4-17 sounds.
- Confirm Q-065: the peer-id RPCs hold with walkies.

### P4-15 Season Awards and season end
Owner: Gameplay; Technical Artist for the card style. Output: awards screen (doc 05 s15); handoff
note.
Acceptance:
- Awards come from the P4-03 templates (doc 03 s17.4); every player gets at least one.
- Shown after the final dawn or a Foreclosure loss (doc 01 "Season Awards").
- Win and loss screens lead back to the menu.

### P4-16 Phase 4 models
Owner: 3D Artist; Technical Artist for materials and light review. Output: `assets/models/`,
`assets/blender/`; handoff note.
Acceptance:
- Built in Blender 5.2, gray-box acceptable, low-poly, real scale (doc 07). No downloaded models.
- Four creature bodies and the smear hull (doc 03 s2, s15); pumpkin sizes and gnawed; patch; cart
  with lantern and slot; town stand; chicken, pig, cow; store items (doc 07 s12).
- Starts with the Q-027 asset list review.
- The Technical Artist closes Q-036 and Q-054 item 5 (`LightRig` review).

### P4-17 Phase 4 sounds
Owner: Audio Designer. Output: `assets/audio/`, `game/audio/`; handoff note.
Acceptance:
- Doc 08 s11 Phase 4 rows: `sfx_cart_squeak_loop`, `cre_gnaw`, `sfx_flare_shot`, `sfx_flare_hiss_loop`,
  `cre_flare_hit`, `vox_radio_*`, animal sounds, body signature variants `_01`..`_03` (doc 08 s6),
  store and awards UI.
- Dawn Report low-pass on Ambience and SFX only (D-074, Q-072).
- Redo `cre_jumpscare_hit` once the P4-16 bodies exist.
- CEO listening per D-066 and doc 08 s14. Never reuse the Phase 1 day music.

### P4-18 Phase 4 review
Owner: QA. Output: `tools/qa/playtest/checklist_p4.md`, review notes; handoff note.
Acceptance:
- Reviews each P4 task against its block.
- 4-instance run over ENet; headless with no new errors.
- Sim `compare` on full-season logs within 15 points (doc 02 s18.5); at least 6 logged seasons with
  both wins and losses (doc 09 s3).
- The doc 09 Phase 4 gate and the D-068 carried `checklist_p3` items.
- Q-021 and Q-039 nits.

### P4-21 Bot seasons as a median team
Owner: AI Programmer. Output: `game/bots/`; handoff note. Source: Q-157, OPEN_ISSUES "Found at the
P4-18 review" items 1 and 4, OPEN_ISSUES "Found at the P4-12 review" item 1. The CEO asked for it at
STOP 5 (2026-10-09) so QA can test the economy in hours instead of evenings.
Acceptance:
- At dusk bots stop chores and go inside a lit building (doc 03 light rules); they come out at dawn.
  Night deaths drop from 5 to 15 per season to the sim median or below.
- Bots keep coins for the next payment (doc 02 s7) before spending on seeds; no foreclosure from
  spending every coin on seeds.
- Bots plant and tend the Prize Pumpkin, so the final judging has a pumpkin.
- Bots stay inside the speed check under `--time-scale` (OPEN_ISSUES P4-18 item 4): a time-scale 8 bot
  season logs 0 bot `speed_violation`.
- Headless bot seasons (2p, 3p and 4p, at least 2 seeds, `--headcount=` set) include at least one win
  and one loss; the `tools/sim/sim.py compare` result goes in the handoff, pass or fail.
- Bots still use only the player paths (move frames, hold requests); no host-side shortcuts.
- Full test suite and smoke pass headless with no new errors.

### P4-22 to P4-28 CEO session fixes
Source: OPEN_ISSUES "Found in the CEO's 2-instance session". Each row is done when a headless run and the
full test suite show no new errors, a windowed screenshot (or listen file for P4-26) shows the change,
and an Opus QA review passes.
- **P4-22:** interacting with the store opens a menu with every `store.json` item, its price and a buy
  button; seeds are sold there per crop (doc 02 crops), and planting uses the chosen seed; a hotbar shows
  held items and a one-line use hint. Host-authoritative as now.
- **P4-23:** a lobby screen before the match: role pick (D-077), settings, ready; the host starts the
  season and players spawn on the farm. The barn lobby goes.
- **P4-24:** a top-right minimap: player arrow, other living players, buildings, fields, store, well,
  cart. Never shows the creature.
- **P4-25:** at dawn the host places the creature back in the corn if it is outside it; find and fix
  why it stuck in the barn.
- **P4-26:** new footstep set per surface; cricket chirp interval longer (doc 08).
- **P4-27:** break up open ground with cover, tree lines and landmarks (doc 04); keep sightlines, bot
  routes and `tools/sim/layout.json` distances valid; festival cart sits on the barn floor.
- **P4-28:** sim the watering can at 3 and 4 plots per fill; report median win rate and payment margins;
  change `data/` only if the s18.3 targets still pass.

### P4-29 and P4-30 CEO requests (2026-10-09)
- **P4-29:** a sprung bear trap no longer disappears. It stays where it sprang, visibly sprung, after the
  victim is freed. A player picks it up (existing trap pickup hold) and hangs it back on the pegboard
  (doc 02 s3 "Hang a trap on the pegboard", 1 s), which fills the outline (doc 01 "Pegboard"). The trap
  race and the night theft rule (doc 02 s21: traps off the pegboard at nightfall are the creature's)
  stay as they are. Synced on every peer; logged.
- **P4-30:** a sell bonus scaled by player count (largest at 2p, none at the headcount where the sim
  already meets its targets), data-driven in `data/`, applied at every sale on the host and shown in the
  sale log. Sim (`tools/sim/sim.py`) models it; all s18.3 checks pass; 2p median pays the first payment.
  Decision recorded. Same done-when line as P4-22 to P4-28.

### P4-31 Sanctuary no longer counts as attending (D-089)
- `_track_night` skips living players inside the town stand sanctuary (creature `_in_sanctuary`), so a
  player parked there all night leaves the farm unattended. Unit test for both cases.
- Bots drop the sentinel job (`bot.gd`); at 2p the freed bot works instead. Re-run the 2p to 4p bot
  seasons and report payments, trample counts and night deaths against P4-21. Logged; same done-when
  line as P4-22 to P4-28.

### P4-32 Harvest Moon push progress
- While a player holds `push_cart`, the hold bar shows route progress (`cart.offset` of `cart.length`) and
  the metres left to the gate, on every peer, instead of a hold that sits at 0%. Same done-when line as
  P4-22 to P4-28.
- While holding interact on `push_cart`, the player is locked to a push slot behind the cart, faces the
  route and moves with it; release, knock-off, death or a creature stall frees them. Host-authoritative,
  mouse look free, bots still push (CEO 2026-10-09).
- `push_cart` is offered only at the cart's handle; push slots sit along the handle (CEO 2026-10-09).
- Added to running tasks from the same CEO report: dirt path along the cart route and cart grounded
  while pushed (P4-27); the creature attacks when nobody pushes, so start-stop pushing no longer stops
  attacks (P4-25).

### P4-33 Flag limit, removal and minimap icons (CEO 2026-10-09)
- Each player may have a limited number of flags placed at once (data-driven in `data/`, placeholder).
- A player can remove a flag they placed (an interact on their own flag); the slot frees.
- Placed flags show as small icons on the P4-24 minimap for every living player.
- Doc 01 "Flags" rules stay: from day 5 the creature can move one flag a night, and the minimap shows
  where the flag is now. Host-authoritative, synced, logged. Same done-when line as P4-22 to P4-28.
- D-141: remove the teammate dots from the minimap; only the local arrow, layout and flags show.

### P4-38 Buyable flare shells (D-147, CEO 2026-10-09)
- New store item `flare_shell` in `data/store.json` (+ schema): needs `flare_gun` bought; each buy loads one shot
  up to `flare_capacity()`; cannot buy when the gun is full. Placeholder price, marked `placeholder`; the Game
  Designer checks it with the season sim (doc 02 s10) and records it in doc 02.
- Host-authoritative through the existing store buy path, synced, saved with `flare_shots`, logged.
- The Dawn Report shows a line when the dawn reload loaded the gun.
- Docs 01 Store and 02 s10 updated. Same done-when line as P4-22 to P4-28.

### P4-37 Live clips replace the barn recording (D-146, CEO 2026-10-09)
- Remove the recording screen and its menu-lobby staging (`lantern_out` and the rest) and the "Lobby lines"
  setting. Voice settings become Off and Live clips; Live clips is the default, including for existing
  settings files that hold Lobby lines.
- On a Live-clips player's own machine, cut clips of at most 3 s from transmitted speech (VAD talk spurts) in a
  match, keep them for the session only, share them by the existing manifest (doc 06 s11), delete them at
  session end and when the player switches to Off.
- The creature lures and the Dawn Report replay these clips through the existing `apply_lure` path. Streamer-safe
  never replays them. The replay checks the owner's current setting at play time.
- The pause menu lists this session's clips: play and delete each.
- Steady recording light (own screen tally and on the character) while clips are kept; never flickering.
- Docs 01, 06 (s16 into the main text, D-013 reading replaced), 08 and 09 updated. Same done-when line as P4-22
  to P4-28; test with 2 instances that a lure replays a clip cut from the other player's speech.

### P4-35 Menu lobby line-up scene (D-140, CEO 2026-10-09)
- Replace the flat lobby menu with a 3D scene behind the UI: a dark barn or night farm, lantern-lit, with
  every connected player's farmer (existing farmer model, hat by role) standing side by side, the local
  player in the centre spotlight.
- Above each farmer: name, chosen role, READY or NOT READY. Role pick, ready, settings and leave sit in
  side panels; the host's start button bottom right. Joining and leaving players appear and vanish.
- Horror tone: dark palette, warm lantern light; take layout only from the reference, not its colours.
- The recording screen's `lantern_out` step blows out a lantern in this scene (Q-176).
- Doc 01 "Picking a role" and recording "Staging" say "menu lobby"; docs 04, 06, 07 barn-lobby lines
  (OPEN_ISSUES "Found at the P4-23 review" 2) updated or routed by Q. Same done-when line as P4-22 to P4-28.

### P4-34 Town stand lowers risk, no sanctuary (D-115)
- Remove every absolute sanctuary rule (creature kill, chase retreat, AI Director `allow`, scares, trap
  spots). Instead, within the stand radius, multiply the chance or weight of lures, scares, stalk
  target picks, knock-offs and kills by data-driven placeholders in `data/`. A creature that does commit
  there can kill.
- A player at the stand counts as outside (as before D-089). Bots keep the stand job.
- Re-run the P4-21 bot seasons (2p to 4p, seeds 1 and 2, normal and short) and compare against P4-21 and
  P4-31: payments, trample, night deaths, deaths at the stand. Model the stand in the sim if needed;
  s18.3 targets pass. Docs 01 and 03 updated. Same done-when line as P4-22 to P4-28.

### P4-19 Creature bodies, final art
Owner: 3D Artist. Output: `assets/models/creature_*.glb`, `assets/blender/`, `tools/blender/`;
handoff note.
Acceptance:
- Final art for `creature_gaunt`, `creature_scarecrow` (+ `_head`), `creature_boar` (+ `_chain`),
  `creature_corn_husk` (+ `_heart`) per doc 07 s1, s2, s8 and s11.7: silhouette first, low-poly,
  flat-shaded, hand-painted feel, no photo textures. Each body reads as itself in silhouette at 25 m.
- Real scale within doc 07 s11.7 tolerance; front -Z, origin at base; under 5,000 triangles each.
- Same file names, part names and pivots as P4-16, so creature code needs no change.
- Smear hulls rebuilt from the new bodies (doc 03 s2, s15).
- Emissive only on ember eyes and the husk heart (`mat_emissive_ember`); no `Light3D` (doc 07 s8).
- Built in Blender 5.2, headless and rebuildable from a script; nothing downloaded (D-077).
- Every other model stays gray-box (D-087).

### P4-20 Night look, final pass
Owner: Technical Artist. Output: `game/render/`, `assets/materials/`, `assets/textures/`; handoff
note.
Acceptance:
- Phase looks per doc 07 s3 (day, dusk, night, dawn, `harvest_moon`), continuous, a pure function of
  clock phase and progress so every peer matches.
- Darkness per doc 07 s5: ambient floor 0.25, no auto exposure, silhouette rule, brightness slider
  range kept.
- Fog and post stack per doc 07 s6 in order: filmic tone map, per-phase colour grade, vignette, static
  grain, Taint overlay; bloom fixed (threshold 1.2, intensity 0.25).
- Creature materials and textures for the P4-19 bodies; `mat_ghost_rim` on the ghost view (doc 07 s7,
  s8).
- The flicker rule holds (doc 07 s4.3, s13): nothing pulses, nothing animates brightness above 0.5 Hz.
- Low quality setting still turns off grain, fog layer and local-light shadows (doc 07 s6).
- Headless run with no new errors; day, dusk, night and Harvest Moon screenshots for the CEO
  (doc 07 s5) from `--look-shot`.

---

## DD Phase 5: Spliced clips, next season, cosmetics

Started by the CEO 2026-10-09 (D-152), which closes STOP 5. Source: doc 01 "Build Plan > Phase 5": spliced
clips from live speech; next season; cosmetics. Live clips came forward in D-146 and are done (P4-37).
Done when the CEO says it is done (Q-250). **STOP 6** after P5-08.

Carried in: the P4-18 gate items the CEO waived (D-148: human sessions, sim `compare` within 15 points),
the P4-17 CEO listen, Q-150 (capsule creature), Q-122 (AI Director state unsaved).

| ID | Owner | Task | Status | Depends on |
|---|---|---|---|---|
| P5-01 | Director | Scope review: settle what P5-04 to P5-07 depend on; done-when proposal (Q-250) | done (D-152) | — |
| P5-02 | Game Designer | Doc 02 next season and cosmetics, doc 03 season traits; `data/` JSON; sim runs season 2 and 3 | done (QA PASS, D-158) | P5-01 |
| P5-03 | Network & Voice, AI Programmer | Spliced lures from live clips, day 4 on (doc 03 s12.1 splice row, doc 06 "A lure") | done (QA PASS, D-156) | P5-01 |
| P5-04 | Gameplay, AI Programmer | Next season: carry-over, savings, debt growth, one new creature trait, saved and loaded | done (QA PASS, D-171) | P5-02 |
| P5-05 | Gameplay | Cosmetics: store items once the debt is paid, equip, synced, saved | in progress | P5-02 |
| P5-06 | 3D Artist, Technical Artist | Cosmetic hats and overalls models and tint slots (doc 07 s8) | done (QA PASS, D-164) | P5-02 |
| P5-07 | Audio Designer | Phase 5 sounds: season-start sting, cosmetic purchase, splice join check (doc 08) | in progress | P5-02, P5-03 |
| P5-09 | Gameplay, AI Programmer | Quirks group option: ten quirks, one random per player per season (doc 01 "Quirks", D-052) | done (QA PASS, D-167) | P5-02 |
| P5-10 | Gameplay, Network & Voice | Dev toys behind the machine-hash gate (doc 01 "Dev toys", D-044, D-045) | done (QA PASS, D-157; hash Q-261) | P5-01 |
| P5-11 | Gameplay | Imposter mode and its hidden dev setting (doc 01 "Imposter mode", D-043, D-044) | done (QA PASS, D-174) | P5-02, P5-10 gate |
| P5-12 | 3D Artist, Technical Artist | Overall upgrade of every model; farmer rig, animations and tint slots (D-154) | done (QA PASS, D-159) | P5-01 |
| P5-13 | Gameplay | Wire the upgraded models in: creature glb for the capsule (Q-150), farmer rig, unused models | done (QA PASS, D-165) | P5-12, P5-03 |
| P5-14 | 3D Artist | Missing models: buildings (barn, shed, farmhouse, well, fences, gates, doors) (Q-266) | done (QA PASS, D-170) | P5-12 |
| P5-15 | 3D Artist | Missing models: traps (all kinds), pegboard, tools (hoe, shovel, fuel can, whistle) (Q-266) | done (QA PASS, D-169) | P5-12 |
| P5-16 | 3D Artist | Missing models: crop growth stages, corn (Q-266) | done (QA PASS, D-166) | P5-12 |
| P5-17 | 3D Artist | Missing models: crow, hands, road items, ragdoll, ghost shell (Q-266) | done (QA PASS, D-168) | P5-12 |
| P5-18 | Level Designer | Cart parks clear of the barn doorway (CEO, 2026-10-09: "the cart shouldnt block the doorway to the barn") | done (QA PASS, D-172) | |
| P5-19 | Network & Voice | `VoiceSplice.word_break` finds real silent frames (Q-291, confirmed at the P5-07 review) | in progress | |
| P5-20 | Gameplay | Players type their own name in the lobby before start (CEO 2026-10-09: "not everyone shows up as farmer") | done (QA PASS, D-173) | |
| P5-21 | Level Designer | Paths connect every structure to another; remove the stray path behind the barn to the animal pen (CEO 2026-10-09) | done (QA PASS, D-175) | P5-18 |
| P5-22 | Gameplay | Wire the P5-14 to P5-17 models: buildings, traps, pegboard, tools, crops, corn, crows, hands, road items, ragdoll, ghost shell | todo | P5-13 |
| P5-23 | Gameplay | Wire the primitives left by P5-13 (Q-283): death corpse, Taint look, hats, Taint sleeves, `interact` animation, cart lantern glass | todo | P5-13 |
| P5-24 | Gameplay | Next season through the lobby: roles re-picked, quirk reroll, `Imposter.pick`, season-start save (P5-04 follow-up) | todo | P5-04, P5-11 |
| P5-25 | Gameplay | Imposter `pegboard_mark` and interaction holds for the kit (Q-303) | todo | P5-11 |
| P5-08 | QA | Review each P5 task; 4-instance run; headless with no new errors | todo | P5-02 to P5-07, P5-09 to P5-25 |

### P5-02 Phase 5 design and data
Owner: Game Designer. Output: doc 02, doc 03, `data/`, `tools/sim/`; handoff note.
Acceptance:
- Doc 02 "Next season": carry-over (upgrades, plots, spare coins at 25% as savings, doc 01), debt growth
  per season as numbers, what resets (crops, Taint, deaths, roles re-picked or kept), how many seasons.
- Doc 02 store rows for cosmetic hats and overalls: prices, sold only once the season's debt is paid
  (doc 01 "Store"), kept across seasons, no gameplay effect.
- Doc 03 "Season traits": a list of creature traits, one gained per season (doc 01 examples: better tool
  mimicry, more pits), each with numbers a coder can build; picked by host seed and logged.
- `data/` JSON for the above; schema tests pass.
- `tools/sim/sim.py` runs seasons 2 and 3 with carry-over and traits; targets for later seasons set and
  met, results in the handoff.
- Doc 09 Phase 5 gate rows drafted in the handoff for QA.

### P5-03 Spliced lures from live clips
Owner: Network & Voice Programmer (playback, wire), AI Programmer (splice choice). Output: `game/voice/`,
`game/creature/`, tests; handoff note.
Acceptance:
- From day 4, voice lures may be spliced (doc 01 "Ramp-up" table): two recorded lines of one owner, cut
  at the word break (the clip's own silence gap, else mid-clip); at most 2 segments (doc 03 s12.1).
- `apply_lure` carries the segment list (doc 06 "A lure"); exact clips keep working unchanged.
- Days 1 to 3 stay exact. `lure_played` logs `exact: false` and the segment list for splices.
- The Dawn Report replays a splice the same way it played.
- Off players and voice settings rules unchanged (doc 01 "Voice settings").
- 2-instance ENet test: a day-4 spliced lure plays on the target only; headless, no new errors.

### P5-04 Next season
Owner: Gameplay Programmer (flow, save), AI Programmer (trait). Output: `game/`, tests; handoff note.
Acceptance:
- After a won season end (doc 05 s15), the host can start the next season; a lost season cannot carry.
- Carry-over per P5-02 doc 02: upgrades, plots, savings at 25% of spare coins; debt grows per the table.
- The creature gains the season's trait (P5-02 doc 03), logged; a new body is picked per season (P4-13).
- Season number shown in the HUD and Dawn Report; saved at dawn and loaded (P4-10 save).
- Joining and leaving mid-season still scale by headcount.
- 2-instance ENet season 2 start with `--time-scale`; full suite and smoke headless, no new errors.

### P5-05 Cosmetics
Owner: Gameplay Programmer. Output: `game/`, tests; handoff note.
Acceptance:
- Hats and overalls sold at the shipping crate only after the debt is paid (P5-02 doc 02).
- Equip in the lobby or pause menu; every peer sees it; the role hat (D-144) rules per doc 07 s8.
- Owned cosmetics persist in the save across seasons; no gameplay effect.
- 2-instance ENet test; headless, no new errors.

### P5-06 Cosmetic models
Owner: 3D Artist, Technical Artist. Output: `assets/models/`, `tools/blender/`; handoff note.
Acceptance:
- Every P5-02 cosmetic as a low-poly .glb per doc 07 s8 and s11 rules (D-151 sources); fits the farmer
  head and body; overalls as tint or mesh per doc 07.
- Screenshots on the farmer in day and night light.

### P5-07 Phase 5 sounds
Owner: Audio Designer. Output: `assets/audio/`, `game/audio/`, doc 08; handoff note.
Acceptance:
- Doc 08 rows and files for Phase 5 cues (CC0 or FilmCow per D-149); listen list for the CEO.
- Splice joins checked by ear in a recorded day-4 lure; report the glitch (doc 06 inference) as heard.

### P5-08 Phase 5 review
Owner: QA. Output: `tools/qa/playtest/checklist_p5.md`, doc 09 Phase 5 gate; handoff note.
Acceptance:
- Reviews each P5 task against its block.
- 4-instance run over ENet across a season end into season 2; headless with no new errors.
- No measured gate: Phase 5 is done when the CEO says so (Q-250). QA lists what to try at STOP 6.

### P5-09 Quirks
Owner: Gameplay Programmer (player effects), AI Programmer (lure weighting, hallucinations). Output: `game/`,
tests; handoff note. Numbers: P5-02 doc 02 and `data/` (doc 01 numbers are placeholders).
Acceptance:
- Lobby group option, off by default; with it on, each player gets one random quirk per season from the ten
  in doc 01 "Quirks", host seeded and logged; real disorder names (D-052).
- Each player sees only their own quirk; others learn it by watching. Kept on reconnect and in the save.
- Every quirk effect works as doc 01 lists; none lets anyone see the creature clearly, harm it, or fake an
  honest signal. Paranoia's fake footstep plays on that player only.
- Photosensitivity rules hold (doc 01 "Photosensitivity safety").
- 2-instance ENet test with Quirks on; headless, no new errors.

### P5-10 Dev toys
Owner: Gameplay Programmer (toys, gate), Network & Voice Programmer (squeaky voices). Output: `game/`, tests;
handoff note.
Acceptance:
- The D-044 gate: works only when the host machine's `OS.get_unique_id()` hash matches one baked into the
  game; only the hash goes in the repo, never the raw ID; `--dev` or a debug build elsewhere does not unlock
  it. No menu shows the toys. The CEO supplies the hash (a FOR CEO question with a one-line command).
- The seven toys in doc 01 "Dev toys"; the host runs them and every peer sees the result.
- Toys never touch the save, coins, debt or deaths; a session that used one logs `dev_toy` and
  `check_logs.py` measures skip it.
- Photosensitivity rules hold: disco lights sweep and never flicker; the nuke is a slow warm glow; safe mode
  shows no disco lights and no nuke glow.
- 2-instance ENet test with a test hash; headless, no new errors.

### P5-11 Imposter mode
Owner: Gameplay Programmer. Output: `game/`, tests; handoff note. Kit: P5-02 doc 02.
Acceptance:
- Lobby toggle, off by default; with it on, a placeholder 50% chance of one imposter, picked secretly by the
  host at match start after roles are locked; the imposter keeps their role and perks.
- Only the imposter's own client learns it; no other peer's state, logs sent to it, or UI can expose it.
- The imposter wins on foreclosure; everyone else wins as normal. Their kit (false signals, open gates and
  doors) per P5-02; they never kill.
- The Dawn Report reveals the imposter, or that there was none, at season end.
- Rejoining keeps imposter status (doc 01 "Rejoining").
- The hidden dev setting (D-044) forces an imposter and picks who, behind the P5-10 gate.
- 2-instance and 4-instance ENet tests; headless, no new errors.

### P5-12 Overall model upgrade
Owner: 3D Artist (models), Technical Artist (rig, animations, tint slots, materials). Output: `assets/models/`,
`assets/blender/`, `tools/blender/`, `game/render/`; handoff note. Source: CEO 2026-10-09 (D-154), D-151, doc 07.
Acceptance:
- Every model in `assets/models/` reviewed against doc 07 s11 and s12 and upgraded: better silhouettes and
  detail within each poly budget, real scale, palette and materials per doc 07; D-151 sources (Blender plus
  CC0 libraries, edited to fit). File names and node names unchanged so game code keeps loading them.
- The P4-16 and P4-40 handoff nits closed or listed with a reason.
- Farmer: rig, the doc 07 s11.7 animations and 4 tint slots.
- Before and after screenshots in day and night light for each model, for the CEO.
- Import headless with no new errors; smoke passes.

### P5-13 Wire in the upgraded models
Owner: Gameplay Programmer (AI Programmer reviews creature changes). Output: `game/`; handoff note.
Acceptance:
- `creature.gd` shows the P4-19 body glb in place of the capsule; the capsule collider stays (Q-150).
- Players use the rigged farmer with its animations and tint slots, synced to every peer; `LineUp._farmer`
  uses it too.
- Built models not yet referenced (`bldg_town_stand`, `crop_plot`, `pumpkin_patch`, `pumpkin_prize_*`) are
  placed or used where doc 04 and doc 07 put them.
- `cart.gd` hangs the lantern at `LanternSocket` (Q-247 N1).
- 2-instance ENet test; full suite and smoke headless, no new errors.

### P5-14 to P5-17 Missing models
Owner: 3D Artist. Output: `assets/models/`, `assets/blender/`, `tools/blender/`; handoff note. Source: Q-266,
D-154, D-159, doc 07 s11 and s12.
Acceptance (each row, for its group):
- Every listed doc 07 s11 item as a low-poly, real-scale .glb within its tri budget, palette and materials per
  doc 07 (D-151 sources). Node names that game code will need are listed in the handoff.
- Gameplay still uses primitives; wiring is a later Gameplay task, so no game code changes here.
- Before and after screenshots in day and night light (the primitive is the "before").
- Import headless with no new errors; smoke passes.

### P5-22 Wire the P5-14 to P5-17 models
Owner: Gameplay Programmer (Level Designer for `farm.tscn` collision). Output: game code, handoff note.
Acceptance:
- Every model built by P5-14 to P5-17 replaces its gray-box or primitive stand-in; gray-box collision stays unless the
  Level Designer moves it. Follow the wiring notes in OPEN_ISSUES (P5-14 to P5-17 reviews).
- No new light flicker; `trap_glint` shown by angle or distance, never a blink; ragdoll `lie` never autoplays with
  physical bones on.
- Two-instance run shows the same models on both peers; smoke and existing tests pass.

### P5-23 Wire the P5-13 leftover primitives
Owner: Gameplay Programmer. Output: game code, handoff note.
Acceptance:
- Q-283 items use the farmer rig or models: death corpse (`game/ghost/death.gd`), Taint look (`tool_hands`), hats on
  the `hat` bone, `mat_farmer_sleeves` for Taint, the `interact` animation on interact, cart lantern glass.
- The big-head dev toy stays a sphere. Two-instance run and smoke pass.

### P5-24 Next season through the lobby
Owner: Gameplay Programmer. Output: game code, doc 05, handoff note.
Acceptance:
- Starting the next season returns everyone to the lobby: roles re-picked, quirks rerolled, `Imposter.pick` run when
  imposter mode is on, and the season-start save written (P5-04 OPEN_ISSUES).
- Two-instance run through a season end into season 2 shows the same state on both peers.

### P5-25 Imposter pegboard mark and kit holds
Owner: Gameplay Programmer. Output: game code, doc 05, handoff note.
Acceptance:
- `pegboard_mark`: the imposter can mark a false trap on the pegboard. Clients see the lie on a separate display array
  (the host's `filled` stays true); touching the slot resets it. Nothing on a client reveals who marked it.
- Kit actions (`whistle_throw`, `gate_prop`, `false_flag`, `pegboard_mark`) use interaction holds with a hold bar like
  other actions. Keys: placeholders until the CEO picks (Q-303).
- `test_imposter_sync` 4 instances still passes; no client log holds the imposter's uid.
