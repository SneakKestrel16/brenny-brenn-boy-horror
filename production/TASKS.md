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
hasn't read doc 01, plus log measures (doc 09). **STOP 4** after P3-13.

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
| P3-06 | AI Programmer | Sabotage from the disturbance budget (doc 03 s10, D-034) | todo | P3-04 |
| P3-07 | Gameplay, AI Programmer | Taint and Shaken: player side and the well (doc 05 s10), creature tracking (doc 03 s3.3, s8); Taint is off since Phase 1 | todo | P3-02 |
| P3-08 | Technical Artist, Audio Designer | Taint stain and Taint heartbeat; scare and Director sounds (doc 07, doc 08) | todo | P3-05, P3-07 |
| P3-09 | Gameplay, Technical Artist | Ghosts: lantern flicker, crow possession and corn rustle (doc 01 "Ghosts", doc 05 s14, doc 03 s13, doc 07) | todo | P3-01 |
| P3-10 | Network & Voice, Audio Designer | Ghost voice: the ghost static chain on dead players' voice to the living and on dead-voice lures (doc 06 s9, D-011); today ghost voice is muted (OPEN_ISSUES playtest 9) | todo | P3-09 |
| P3-11 | Gameplay | Whistle and emotes (doc 05 s14); recheck whistle placement by ear (OPEN_ISSUES P2-01 review 1) | done (by-ear test pending a tester, OPEN_ISSUES) | P3-01 |
| P3-12 | Gameplay, Technical Artist | Dawn Report screen: headlines, obituaries, hero actions, flags placed (doc 05 s15, doc 03 s17, doc 07 card style) | todo | P3-02 |
| P3-13 | QA | Review each P3 task; 4-instance run; `check_logs.py` on a full session; doc 09 Phase 3 gate plus the carried measures | todo | all above |

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
