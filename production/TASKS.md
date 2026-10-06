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
| PP-01 | Network & Voice | Doc 06 Networking & Voice | in review | — |
| PP-02 | Network & Voice | Voice spike: Opus over ENet, UPnP and join code | done (CEO test at STOP 1) | — |
| PP-03 | QA | Test harness: headless smoke run, multi-instance launcher, log checker | done | — |
| PP-04 | Game Designer | Doc 02 Systems & Economy, data schemas | todo | STOP 1 |
| PP-05 | Level Designer | Doc 04 Farm Layout | todo | STOP 1 |
| PP-06 | Game Designer | Doc 03 Creature, AI Director & Scares | todo | PP-04 |
| PP-07 | Gameplay | Doc 05 Technical Design | todo | PP-01, PP-04, PP-06 |
| PP-08 | Technical Artist | Doc 07 Art Direction & Asset List | todo | PP-05, PP-06 |
| PP-09 | Audio Designer | Doc 08 Audio Design & Sound List | todo | PP-06, PP-01 |
| PP-10 | QA | Doc 09 Playtest Plan | todo | PP-01 to PP-09 drafts |
| PP-11 | Director | Fill CONTRACTS sections 6 to 9 from docs 02, 03, 05, 06, 08 | todo | PP-04, PP-06, PP-07, PP-09 |
| PP-12 | Director | Pre-production review: Open Issues, settle what DD Phase 1 needs, CEO approval | todo | all above |

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

## Later phases

Written at the end of the previous phase's review. Not started without CEO approval.
