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
| P1-17 | QA | Playtest kit: session tool, observer tally, log collection, report, Windows packager with host/join launchers, tester brief | in review (Director) | P1-14 |

Each owner turns their row into acceptance from the cited doc sections when starting; every task
still needs QA pass plus Director check.

---

## Later phases

Written at the end of the previous phase's review. Not started without CEO approval.
