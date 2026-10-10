# 05 Technical Design

Owner: Gameplay Programmer. Task: PP-07. Status: draft, for QA review and the Director's
consistency check. Source of truth: [doc 01](01_design_doc.md). Builds on
[doc 02](02_systems_and_economy.md) (numbers and schemas), [doc 03](03_creature_ai_director_and_scares.md)
(creature, Noise kinds), [doc 04](04_farm_layout.md) (places) and
[doc 06](06_networking_and_voice.md) (messages). The Noise interface (section 8) needs the AI
Programmer's agreement (Q-019).

How the game is built on the player's side and what everyone plugs into: autoloads, scenes, data
loading, the interaction-hold framework, the Noise interface, saves, logs and the debug view. Doc 01
and `production/CONTRACTS.md` win any conflict. Numbers are tagged like docs 02 and 03: a doc 01
section, `doc02`/`doc03`/`doc04`/`doc06` for a number those docs own, or `placeholder`. **Inference
is marked as inference, with what would settle it.** No numbers in this doc are new design: where
one is new it is a technical limit and tagged `placeholder`.

## Contents

1. [Scope and conventions](#1-scope-and-conventions)
2. [Architecture and the authority split](#2-architecture-and-the-authority-split)
3. [Autoloads, scenes and project settings](#3-autoloads-scenes-and-project-settings)
4. [Data loading](#4-data-loading)
5. [Clock and phases](#5-clock-and-phases)
6. [Player controller, crouch and go-still](#6-player-controller-crouch-and-go-still)
7. [The interaction-hold framework](#7-the-interaction-hold-framework)
8. [The Noise interface](#8-the-noise-interface)
9. [Farming, tools and carrying](#9-farming-tools-and-carrying)
10. [Corruption, Shaken and the well](#10-corruption-shaken-and-the-well)
11. [Traps from the player side, flags and defenses](#11-traps-from-the-player-side-flags-and-defenses)
12. [Generator and lights](#12-generator-and-lights)
13. [The festival cart](#13-the-festival-cart)
14. [Death, ghosts, whistle and emotes](#14-death-ghosts-whistle-and-emotes)
15. [Dawn Report and Season Awards screens](#15-dawn-report-and-season-awards-screens)
16. [Menus and settings](#16-menus-and-settings)
17. [Save at dawn](#17-save-at-dawn)
18. [Log events](#18-log-events)
19. [The debug top-down view](#19-the-debug-top-down-view)
20. [DD Phase 1 build order](#20-dd-phase-1-build-order)
21. [Testing](#21-testing)
22. [Gotchas](#22-gotchas)
23. [Answers to open questions](#23-answers-to-open-questions)
24. [Questions raised](#24-questions-raised)
25. [Dev gate and dev toys (P5-10)](#25-dev-gate-and-dev-toys-p5-10)
26. [Next season and creature traits (P5-04)](#26-next-season-and-creature-traits-p5-04)

---

## 1. Scope and conventions

Covers the player-side systems and the shared architecture listed in `production/TASKS.md` PP-07.
Not covered, and owned elsewhere: transport, voice and join codes (doc 06); what the creature does
with a noise and the AI Director's decisions (doc 03, built by the AI Programmer in
`game/creature/`, `game/ai_director/`); layout (doc 04, `game/world/`); sound list and buses
(doc 08); art and the light shader (doc 07). Phase 5 features (live clips, spliced clips from live
speech, next season, cosmetics) are out of scope.

Conventions (CONTRACTS sections 2 to 5): GDScript, statically typed, Godot 4.7.2, Jolt. Files are
`snake_case`, `class_name` is `PascalCase`, signals are past tense, IDs are snake_case strings.
1 unit is 1 m. A host is peer 1. Every gameplay `rpc` goes through the `Net` wrapper (doc 06
section 14); code in this doc never calls `rpc()` directly.

## 2. Architecture and the authority split

**One rule:** a client owns its own movement and camera; the host (peer 1) owns everything else
that affects gameplay and validates every interaction (doc 01 "Networking > Authority", CONTRACTS
section 5). Every verb is `request_*` (client to host) then `apply_*` (host to clients), listed in
doc 06 section 7. A feature that only works single-player is not done: the host's own player takes
the same path as a client with the network hop removed (`Net.to_host` calls the host handler
directly), so there is one code path.

Each system has a **host half** (state, validation, effects) and a **client half** (input, local
prediction of presentation, cosmetics). Host halves live in a node that checks
`multiplayer.is_server()` once at `_ready()` and never runs on a client; client halves never write
shared state.

| System | Host owns (validates, decides, broadcasts) | Client owns | Messages (doc 06 section 7) |
|---|---|---|---|
| Movement, camera | Speed and teleport sanity check, stillness check | Position, yaw, pitch, crouch and sprint flags | `move`, `moves`, `apply_teleport` |
| Crouch, go-still | Stillness from received transforms (doc 03: under 0.2 m in 1 s) | Crouch flag, "go still" input freezes the body locally | `move` |
| Holds (farming, repair, buy, sell, disarm, pry) | Range, state, timer, multipliers, result | Input, local progress animation | `request_<verb>`, `request_hold_cancel`, `apply_<result>` |
| Farming, plots | Crop growth, water, harvest | Visuals | `apply_plot_changed` |
| Economy | Coins, sell, buy, payments, debt | Nothing | `apply_money_changed`, `apply_payment` |
| Tools, carrying | Item ownership, carried teammate | Held-item visuals | `apply_item_given`, `apply_item_moved`, `apply_carry` |
| Noise | Every emission (section 8) | None; clients never emit | none (host-internal) |
| Corruption, Shaken | State, timers, wash | Visuals, speed multiplier from `apply_*` | `apply_taint_changed`, `apply_shaken` |
| Traps, pegboard, flags, defenses | State, springing, race, placement checks | Placement preview, input | `apply_trap_changed`, `apply_trap_race`, `apply_pegboard_changed`, `apply_flags`, `apply_defense_changed` |
| Generator, lights, doors | Fuel, repair, light state, door state | Light rendering | `apply_generator`, `apply_lights`, `apply_door` |
| Cart, Prize Pumpkin | Position, push, "out" check | Push input | `apply_cart` |
| Death, respawn, ghosts | Cause, ghost state, who is a ghost | Spectator camera | `apply_death`, `apply_respawn` |
| Ghost flicker, crow | Validates caller is a ghost, picks result | Input | `request_flicker`, `apply_flicker`, `request_possess_crow`, `apply_crow_possessed` |
| Whistle, emotes | Cooldown, position stamp | Input, animation, sound | `request_whistle`, `apply_whistle`, `request_emote`, `apply_emote` |
| Clock | Day, phase, time | Interpolation between `apply_clock` ticks | `apply_clock` |
| Creature, AI Director, lures | All of it (AI Programmer) | Ambience from state, lure playback | `creature`, `apply_creature_state`, `apply_lure`, `apply_scare` |
| Voice | Relay, volume byte read, radio flag check | Capture, playback, settings | doc 06 sections 8 to 12 |
| Voice settings, lobby lines | Applies without question | The files, the setting | `request_voice_setting` |
| Settings | Nothing | All of it, on this machine's disk | none |
| Save | Writes it, copies it | Keeps the copy | `apply_dawn_save` |
| Logs | Authoritative gameplay events (peer 1 file) | Own net and local events | none |

Two refinements the table implies:

- **Presentation is client-side and may be predicted; state never is.** A client may start its
  tool animation and local progress ring at once, but the plot, the coins, the trap and the light
  change only when the host's `apply_*` arrives. Rejection (`apply_refused(verb, reason)`) rolls the
  presentation back.
- **Everything host-only is invisible to clients.** The creature's true position is replicated for
  rendering (doc 06 `creature` at 15 Hz) but anything the AI keeps secret (tension meter, sensed
  positions, region graph choices) is never sent. The debug view (section 19) reads it on the host
  only.

## 3. Autoloads, scenes and project settings

### Autoloads

CONTRACTS section 4 names `Game`, `Log`, `Data`, `Settings`, `Clock` in `game/core/`, plus `Net`
(`game/net/net.gd`) and `Voice` (`game/voice/voice.gd`) owned by Network & Voice. This doc adds one
autoload, **`NoiseBus`** (`game/core/noise_bus.gd`), the Noise interface (section 8, Q-019 to the Director
for CONTRACTS). Load order matters because later ones use earlier ones:

| Order | Autoload | File | Owner | Job |
|---|---|---|---|---|
| 1 | `Log` | `game/core/log.gd` | Gameplay | JSONL writer (section 18); reads `Clock` lazily for `day` and `phase` (null until `Clock` loads) |
| 2 | `Data` | `game/core/data.gd` | Gameplay | Loads and validates `data/*.json` (section 4) |
| 3 | `Settings` | `game/core/settings.gd` | Gameplay | Local settings file (section 16) |
| 4 | `Net` | `game/net/net.gd` | Network & Voice | Transport, sends, roster, `Net.to_host` / `Net.to_peers` |
| 5 | `Clock` | `game/core/clock.gd` | Gameplay | Day, phase, time (section 5) |
| 6 | `Game` | `game/core/game.gd` | Gameplay | Session state, player registry, ghost list, scene switching, save/load calls |
| 7 | `NoiseBus` | `game/core/noise_bus.gd` | Gameplay (API), AI Programmer (consumer) | Section 8 |
| 8 | `Voice` | `game/voice/voice.gd` | Network & Voice | Capture, relay, playback |
| 9 | `Soundscape` | `game/audio/soundscape.gd` | Audio Designer (D-020) | Beds, creature-state layers, 3D/2D sound API (doc 08 section 10). Every peer, no network. Reads `Settings` volumes and `reduce_scares`. Gameplay calls `set_creature_state` (from the `apply_creature_state` handler), `set_phase` (from `Clock`), `set_local_state` (Player, Generator) (Q-032) |

`Game` exposes the small shared facts other code needs: `Game.is_host() -> bool`,
`Game.local_peer() -> int`, `Game.players: Dictionary` (peer id to `PlayerState`),
`Game.is_ghost(peer: int) -> bool`, `Game.session_id: String`, `Game.difficulty: StringName`,
`Game.player_count() -> int` (living and ghost, not farmhands that do not count). Nothing else is
global.

### Scene layout

```
res://game/core/boot.tscn          Boot (exists): reads command line, opens the main menu or --host/--join
res://game/core/main.tscn          Main: the running session
  World        instance of the level scene (Level Designer: game/world/)
  Players      one Player node per peer, named by peer id
  Creature     instance of game/creature/creature.tscn (host simulates; clients render)
  Items        dropped items, carried teammates' bodies
  Cart         game/items/cart.tscn (Harvest Moon only)
  Ui           menus, Dawn Report, Season Awards, pause (game/ui/)
  DebugView    game/debug/debug_view.tscn, hidden unless enabled (section 19)
res://game/player/player.tscn      CharacterBody3D on layer 2; local variant has the camera and input
res://game/player/ghost.tscn       Ghost body: spectator camera, no collision with layers 1 to 3
```

- `Boot` is a `Node3D` today (`game/core/boot.tscn`, D-014). Its script parses the user arguments
  from doc 06 section 14 (`--host`, `--join`, `--voice-wav`, `--net-sim-*`) plus the ones this doc
  adds: `--debug-view`, `--bots <n>`, `--phase1` (Phase 1 content), `--seed <n>`. The full farm is the default (P2-20): `Main` and the lobby load `game/world/farm.tscn` through `Game.world_path()`. `--phase1-farm` loads `farm_phase1.tscn` instead; every peer must agree (the handshake does not check). `--full-farm` is still accepted and does nothing. It does not turn Phase 1 data on: add `--phase1` for the creature and traps. With no arguments and a window, `Boot` shows the main menu (section 16); any argument takes the legacy path.
- `Main` is built from code plus the scenes above, not one giant scene, so the level scene can be
  swapped for the Phase 1 gray box and later the full farm without touching any player code.
- A `Player` is the same scene on every machine. `is_multiplayer_authority()` (set to the owning
  peer) switches it between local controller and remote proxy. Remote proxies interpolate the
  `moves` frames; they never run input.
- Physics layers are CONTRACTS section 3: 1 `world`, 2 `player`, 3 `creature`, 4 `interactable`,
  5 `corn`, 6 `trap`, 7 `item`, 8 `trigger`. The interaction ray hits layer 4 (and 6 for traps, 7
  for items).
- Marker groups from doc 04 and D-016 (`trap_spots`, `creature_cover`, `crow_perches`,
  `scarecrow_spots`, `animal_escape_spots`, `spatial_audio_markers`, all `Marker3D`) are read by
  name through `get_tree().get_nodes_in_group()`; the Level Designer owns the nodes.

### `project.godot` entries this doc needs

- `audio/driver/enable_input = true` (Q-006; doc 06 section 8). Without it no microphone frames
  arrive.
- Input actions (the Input Map is mine; keys are `placeholder`, and rebinding is in section 16):
  `move_forward/back/left/right` (WASD), `sprint` (Shift), `crouch` (C), `go_still` (hold X),
  `interact` (E, hold), `use_tool` (left mouse), `alt_use` (right mouse), `drop` (G),
  `lantern` (F), `whistle` (Q), `emote_wheel` (hold Z), `voice_push_to_talk` (V),
  `voice_radio` (B), `toggle_debug_view` (F3), `pause` (Esc), `spectate_next/prev` (E/Q while a
  ghost).
- Autoloads, in the order above (`Soundscape` last; Q-032).
- `physics/3d/default_gravity`, the layer names (1 to 8) from CONTRACTS section 3.
- `run/main_scene` stays `res://game/core/boot.tscn`. The `run/main_scene.voice_spike` line (D-014)
  is dropped when DD Phase 1 adds a game export preset.
- Display and the 4.7 / Forward Plus / Jolt lines stay as they are.

## 4. Data loading

Game numbers live in `data/*.json` and the season simulator reads the same files (D-002, doc 02
section 17). `Data` is the only loader.

- **Files** (CONTRACTS section 6, doc 02 appendix, doc 03 section 19): `season, labor, crops,
  pumpkin, debt, medical_bill, player_scaling, difficulty, store, ramp_up, traps, `taint`, roles,
  creature, sabotage, ai_director, voice_lines, dawn_report_templates`. The files do not exist yet; the Game Designer creates them from the doc 02 and 03
  appendices when DD Phase 1 starts. Until a file exists the code that needs it fails loudly in
  `Data` (below), never silently with a default.
- **Envelope** (doc 02 A.1): `{"table", "schema_version": 1, "records": [{ "id", "source",
  "cite", ... }]}`; `season.json` constants are `{id, value, unit, source}`.
- **API**, all typed and read-only after load:
  - `Data.record(table: StringName, id: StringName) -> Dictionary`
  - `Data.records(table: StringName) -> Array[Dictionary]`
  - `Data.value(table: StringName, id: StringName, field: StringName = &"value") -> Variant`
  - `Data.hold_s(verb: StringName) -> float` and `Data.speed(move: StringName) -> float`
    (thin wrappers on `labor`, below).
  - `Data.scaled(value: int, kind: StringName) -> int`, doc 02 section 4's `ceil(v * pct / 100)`
    in **integer math** (`(v * pct + 99) / 100`), never floats, with debt as the one round-to-nearest
    exception (D-017).
- **Validation at load**, failing with `push_error` and a refusal to start the session:
  1. Envelope present, `table` matches the file name, `schema_version == 1`.
  2. **Duplicate ids rejected.** JSON Schema cannot do this (doc 02 A.1), so `Data` does.
  3. Every id the code asks for exists (the required ids from `labor` A.3 are checked at load, not at
     first use).
  4. `source` is `doc01`, `sim` or `placeholder`.
  The data schemas (`data/*.schema.json`) are doc 02's; `Data` does not implement a general JSON
  Schema validator, only the four checks above (the simulator runs the full schemas in Python).
- **Single source for the simulator (answers Q-016).** Movement speeds, capacities and hold seconds
  are read from `labor.json` (`move` records `walk`, `crouch`, `sprint` with `speed_mps`, `max_s`,
  `refill_s`; `capacity` records `can`, `carry`; `hold` records per verb). Player code owns the
  **behavior** (stamina draw and refill, multipliers); `labor.json` owns the **numbers**, so tuning
  in one place reaches the game and the simulator. The placeholders are doc 02 section 2.2's walk
  3.0, crouch 1.2, sprint 5.0 m/s for 6 s refilling over 10 s.
- **Multipliers** (doc 02 section 2.3) are applied by code that reads them from their own tables:
  helped pry `helped_mult` in `labor.json`, Corrupted pry in `taint.json`, role multipliers in
  `roles.json`. They multiply.
- **Hot reload:** not supported; `Data` loads once at startup. A debug command (`--data-dir <path>`)
  points at another folder for the simulator and QA to run alternate numbers (`placeholder`).
- **Which side reads what:** only the host needs most tables for decisions; clients load all of them
  anyway (they are small, and `labor.json` predicts local progress bars). A client never trusts its
  own copy for an outcome; if a client's file differs from the host's, the host's result wins and
  the mismatch is logged (`data_mismatch`, section 18). The host sends a hash of all loaded data in
  `session_state` (inference: this catches two machines running different builds' numbers; settled by
  whether `build_id` in `request_join` already guarantees it, which it should).

## 5. Clock and phases

The host owns the clock (doc 01 "Day and night"). `Clock` holds `day: int`, `phase: StringName`
(`day`, `dusk`, `night`, `dawn`, `harvest_moon`; CONTRACTS section 8) and `t_phase: float`.

- Lengths come from `season.json`: day 540 s, dusk 60 s, night 300 s, Harvest Moon cap 900 s, all
  `placeholder` (doc 02 section 3). The Harvest Moon is the final night (doc 01 "The Harvest Moon").
- The host advances `t_phase` in `_physics_process` and sends `apply_clock(day, phase, t)` on every
  phase change and every 5 s (doc 06 section 7). Clients keep their own `t_phase` advancing by delta
  and correct toward the host value; they never decide a phase change.
- Signals: `Clock.phase_changed(phase)`, `Clock.day_changed(day)`. Systems react to these: lights
  and ambience on the client, the dawn pipeline (section 17) and the generator (section 12) on the
  host.
- Pause: a pause menu does not stop the host's clock in multiplayer (doc 01 has no pause). The pause
  menu is an overlay only.
- A fixed `t` stamp for logs is the session clock (CONTRACTS section 10: seconds since session
  start), independent of `Clock`.

## 6. Player controller, crouch and go-still

Clients own movement and camera (doc 01 "Authority"). The controller is a `CharacterBody3D`
(capsule 1.8 m tall, eye 1.65 m; CONTRACTS section 3) driven by the local input.

- **Movement.** Walk, crouch-walk and sprint speeds come from `Data.speed()` (section 4). Modifiers
  multiply the maximum: Corrupted sprint x0.6 (`taint.json`, doc 02 section 13), Shaken sprint x0.6
  for 60 s, Shaken and bear-trap slow walk x0.6 for 60 s (doc 01 "Night Traps"), carrying a teammate
  slows by the `carry` record (a data value; none is given in doc 01, `placeholder` in `labor.json`).
  Stacking Corruption and Shaken is x0.36 on sprint (doc 02 section 13).
- **Sprint stamina.** Sprint runs at most `max_s` (6 s) and refills over `refill_s` (10 s) (doc 02
  section 2.2). The refill is linear; sprint can restart once it is above 0 (inference: doc 02 gives
  no minimum; a Corrupted player recovers on the same clock; settled by DD Phase 1 feel). Stamina is
  client state; the host never needs it, and checks speed instead (below).
- **Host speed sanity check** (doc 06 section 6, keeping DD Phase 1 free of rubber-banding): the host
  receives `move` frames, computes the speed between frames and compares it with the maximum for the
  player's current state from the host's own view of that state (Corruption, Shaken, trap slow, carrying),
  plus 20%. A violation is logged (`speed_violation`) and the relayed position is clamped; a jump
  over 3 times the maximum sends `apply_teleport`. These are doc 06's `placeholder` limits.
- **Crouch.** Held (toggle is a setting). It is the crouch-walk speed and the `crouch` flag in
  `move`. Footsteps on a crouch-walk have radius 0 (doc 03 `step_crouch` 0), so crouch-walking is
  silent. A crouched, still player is seen only within 6 m (doc 03 section 3).
- **Go still.** Holding `go_still` freezes the body locally (input ignored, no movement). The client
  sends no "still" flag. The host derives "still" from the transforms it received: under 0.2 m moved
  over 1 s (doc 03 section 3, `placeholder`), so a hacked client cannot claim stillness it did not
  have. The host keeps a 1 s ring of positions per player for this. The result feeds doc 03's sight
  rule; the controller exposes `Game.players[peer].is_still` read from that ring.
- **Camera and look.** First person, mouse look, yaw and pitch sent in `move`. Field of view and
  sensitivity are settings (section 16). No HUD markers: nothing points at a teammate or objective
  (doc 01 "Diegetic"). The bell on a trap, the flag on a pole, the pegboard in the shed are the
  information.
- **Footstep Noise.** Each step event (a distance-based footstep timer, not an animation event) calls
  plays the local sound and bob only (no message is sent); the host emits the Noise from the
  `move` stream (section 8): the host decides `step_walk`, `step_crouch`, `step_sprint` or
  `step_sprint_corn` from the frame's crouch and sprint flags and the position (is it inside a corn
  region), once per `step_stride_m` metres moved (`placeholder` 1.6 m, doc 03 gives only radii, not
  stride). So clients cannot suppress footsteps.
- **Body size and ghosts.** A dead player's `Player` is replaced by a body prop (doc 03 section 15)
  and a `Ghost` (section 14).

## 7. The interaction-hold framework

Every chore in doc 01 is a hold of a set number of seconds (doc 02 section 2.1). One framework,
`game/interaction/`, runs all of them.

### Verbs

A **verb** is an id from `labor.json` (`plant`, `water`, `water_quiet`, `harvest`, `fill_can`, `wash`,
`water_prize_pumpkin`, `sell`, `buy`, `disarm_bear`, `pry`, `fill_pit`, `cut_bells`, `hang_trap`,
`place_flag`, `fill_fuel`, `refuel`, `repair_generator`, `repair_fence`, `clear_plot`,
`place_scarecrow`). Hold seconds, with their doc 01 or `placeholder` tags, are doc 02 section 2.1's
table and live in `data/labor.json`; this doc repeats none of them.

### Classes

- `Interactable` (on layer 4, 6 or 7 nodes): `verbs_for(player) -> Array[StringName]` (what this
  object offers this player now), `can_start(verb, player) -> StringName` (an empty StringName for
  OK, else the refusal reason), `range_m`, and `complete(verb, player)` (host only, applies the
  effect).
- `HoldController` (on the local player): looks at what the interact ray hits, shows the prompt
  (diegetic: a held-tool pose and a progress ring, no floating label), and runs the hold.
- `HoldRegistry` (host): one `ActiveHold` per player at most.

### Flow

1. **Start (client).** The player holds `interact` (or `use_tool` for tool verbs) on an interactable.
   The client picks the verb and sends the matching doc 06 message, `request_<verb>(target_id, ...)`
   (for example `request_plant`, `request_pry`; the table in doc 06 section 7 lists each). It starts
   a local progress ring using `Data.hold_s(verb)` and the multipliers it can see.
2. **Validate (host).** The host checks, in this order: the sender is alive and has a body (not a
   ghost); no other active hold for the sender; the target exists; the sender is within `range_m`
   (placeholder 2.0 m, from the sender's last received position); `can_start` is OK (right tool, plot
   state, enough coins and so on); the sender is not mid-carry for verbs that need free hands. A
   failure sends `apply_refused(verb, reason)` to the sender only and logs `hold_refused`.
3. **Run (host).** The host creates an `ActiveHold { player, verb, target, progress, rate,
   started_at }` and each physics tick adds `delta * rate / hold_s`. `rate` is
   `1 / (product of multipliers)` evaluated every tick, so a mid-hold change (a helper arrives, Corruption
   starts) changes the speed from then on, without restarting. Multipliers: `helped_mult` for pry when
   another living player holds `request_pry` on the same trap within 3 m (doc 03 section 7, `helped` 
   x0.6), Corrupted x1.5 on pry only, role multipliers (Mechanic x0.6 on `repair_generator`, `refuel`,
   `repair_fence`; Tracker x0.6 on `disarm_bear`), all from their own tables (doc 02 section 2.3).
4. **Cancel.** The hold ends without effect if: the client sends `request_hold_cancel`, the player
   leaves `range_m` plus 0.5 m (`placeholder`), the target becomes invalid, the verb's `labor.json`
   entry sets `blocked_when_shaken` and the player becomes Shaken (none set until doc 02 says so,
   inference), or the player dies. The host replies `apply_hold_cancelled` and logs
   `hold_cancelled`. Releasing the key is a cancel; there is no partial progress kept unless the
   verb says so (doc 02 gives none, so none).
5. **Complete (host).** At progress 1 the host calls `complete`, which changes the state and
   broadcasts the verb's `apply_*` result to everyone (`apply_plot_changed`, `apply_money_changed`
   and so on), emits its Noise (section 8) and logs `hold_completed`.
6. **Prediction.** On `apply_*` the client's ring finishes at once; if `apply_refused` or
   `apply_hold_cancelled` arrives first it drops the ring. A client whose ring ends before the
   host's `apply_*` waits (host time is the truth); the ring is cosmetic.

### Rules the framework fixes

- **Instant verbs** (hold of 1 s or less, such as `cut_bells`, `hang_trap`, `place_flag`) use the
  same path; there is no second code path for them.
- **The trap race is the one timing-critical hold.** `pried_at_once` is "the pry hold started within
  0.5 s of the spring" and the host credits the victim with half the RTT when it compares the finish
  with the race deadline (doc 03 section 7, doc 06 section 6 item 4). The framework stamps
  `started_at` with the host's receive time minus half the sender's RTT, for `pry` only (inference
  of "credit": doc 03 states the credit, not where it is applied; settled by the Network & Voice
  Programmer's RTT API, `Net.rtt_ms(peer)`).
- **Noise per verb** is in the table in section 8; the framework only calls it.
- **Looking away** does not cancel a hold; leaving range does.
- **One hold per player.** Placing a flag while watering is impossible by construction.
- **No HUD.** The progress ring is a world-space ring on the target or the held tool, shown only to
  the player holding it (and visible to others as the tool animation). It never marks objects.

## 8. The Noise interface

CONTRACTS section 8: "NoiseBus.emit(position: Vector3, radius_m: float, kind: StringName, source_peer:
int)", host-side. Doc 03 section 3.1 sets what the creature does with it. **Final** (confirmed by the AI
Programmer, Q-019, D-021):

```gdscript
# game/core/noise_bus.gd  (autoload "NoiseBus"; host-side only; a client call is a no-op with a warning)
signal noise_emitted(position: Vector3, radius_m: float, kind: StringName, source_peer: int)

func emit(position: Vector3, radius_m: float, kind: StringName, source_peer: int) -> void
func emit_kind(kind: StringName, position: Vector3, source_peer: int, mult: float = 1.0) -> void
func emit_voice(position: Vector3, volume_byte: int, source_peer: int) -> void
```

- **Name (D-025):** the autoload is `NoiseBus`, not `Noise`: `Noise` is a native Godot class and the identifier would resolve to it, not the autoload (Q-041).
- **`emit`** is the raw call and the one CONTRACTS names. `radius_m` is already final (all
  multipliers applied). `kind` is a `StringName` from doc 03's table. `source_peer` is the ENet peer
  id of whoever caused it, or 0 for the world (a generator running dry). `emit` with `radius_m <= 0`
  (for example `step_crouch`) does not fire the signal; it only bumps the debug counter.
- **`emit_kind`** is what gameplay code calls: it looks up the base radius in `creature.json`
  (`noise_radius` records, doc 03 section 3.1 and section 19) by `kind`, multiplies by `mult` and the
  Corruption multiplier (x1.5 on footsteps, doc 03 section 3.1; read from `taint.json` through `Game`),
  then calls `emit`. The quiet watering can is `mult = 0.5` on `tool_water` (doc 03 section 3.1).
  **Who owns the radius table** is `creature.json` (the Game Designer's number, the AI Programmer's
  consumer); `NoiseBus` only reads it.
- **`emit_voice`** is called by `Voice` (`game/voice/`) for each speaker at most every 100 ms using
  the loudest frame since the last report (doc 06 section 8, doc 03 section 3). Radius is
  `60 * (volume_byte / 255)^2` m (doc 03 `voice` row: 159 gives 23 m, 255 gives 60 m, `placeholder`).
  The 60 m cap and the exponent are `creature.json` values, not constants in code. Ghost speakers
  never reach `emit_voice` (D-011): `Voice` does not call it for them, and `NoiseBus` also rejects any
  emit whose `source_peer` is a ghost (`Game.is_ghost`) as a second guard.
- **Nothing is stored.** `NoiseBus` keeps no history. The AI Programmer's `noise_emitted` consumer keeps
  its own 12 s hearing memory (doc 03 section 3.1). The volume byte is never logged (doc 06
  section 8).
- **Kinds** are exactly doc 03 section 3.1's ids: `step_walk, step_crouch, step_sprint,
  step_sprint_corn, tool_till, tool_plant, tool_water, tool_harvest, tool_shovel, tool_pry,
  tool_repair, tool_disarm, well_pump, door, generator_dead, bells, flare, whistle, voice, walkie`.
- **Corn damping (x0.7 between sound and creature), hearing memory, "louder replaces quieter within
  4 s" and picking the loudest radius-weighted source** all belong to the consumer, not to `NoiseBus`
  (doc 03 section 3.1). `NoiseBus` is a plain fan-out; a debug counter per `kind` is kept for the debug
  view.

Who calls it, per source:

| Source | Emitter | Kind | Notes |
|---|---|---|---|
| Footsteps | Host movement handler, once per stride from `move` frames (section 6) | `step_*` | Corrupted x1.5; crouch radius 0 |
| Tool holds | `Interactable.complete` of the verb | `tool_till/plant/water/harvest` 15 m, `tool_shovel/pry/repair` 25 m, `tool_disarm` 8 m | Quiet can x0.5; all emit at completion; `tool_shovel`, `tool_pry` and `tool_repair` also emit once at hold start (AI Programmer, Q-019) |
| Well | Wash and fill-can at the well | `well_pump` 45 m | |
| Doors | Door handler | `door` 20 m | |
| Generator | Generator when dead and when fuel runs out | `generator_dead` 80 m | World source, `source_peer` 0 |
| Bells | Trap handler | `bells` 60 m | Cutting bells silences it for 1 s (doc 03) |
| Flare | Flare handler | `flare` 70 m | |
| Whistle | Whistle handler (section 14) | `whistle` 50 m | |
| Voice, walkie | `Voice` | `voice`, `walkie` | Section above |

Every emission of a high-value kind is logged by the sender (section 18, `noise_emitted` only in
debug runs; off by default to keep logs small).

## 9. Farming, tools and carrying

Host-owned plots (`game/farming/`): each plot is a node with `crop_id`, `watered_days`, `age_days`,
`state` (`empty`, `growing`, `ripe`, `wilted`, `dead`) and `watered_today`. The host advances them at
dawn (section 17) from `crops.json` (doc 02 section 5).

- **Crops (P4-04).** Every number comes from `crops.json` through `game/farming/crops.gd`; no crop name is in
  code. A crop is found by what it does: `harvest_phase` `night` is the bed crop (the plots whose marker
  `field` meta equals that crop id), `day` crops go in field plots. A plot holds `crop` and `state`; verb
  `plant:<crop>` carries the client's picked seed (`cycle_seed`, key T, client-local `Farm.seed_pick`, cycling
  only among day crops the team owns seeds of; `Farm.planting_seed()` falls back to the first owned; plain
  `plant` is the first day crop). The host refuses `wrong_crop`, `locked_crop` (`unlock_day`, and
  `first_payment_made` until `Debt.first_made`, set at the first-payment dawn, is true; P4-07) and
  `no_seeds`, and uses one of the team's seeds at planting (`Store.use_seed`; no coins, D-093). A day crop grows one day per watered day (`grow_days`); a
  bed crop ripens when night falls if watered. At dawn a night crop left unpicked is `dead` (and Corrupts when
  `dead_plot_taints`), an unripe one `wilted`; `clear_plot` removes either. `plot_changed` has no crop
  argument, so the crop rides in the state string (`ripe:pumpkin`, Q-085).
- **Plant, water, harvest** are holds (section 7). Planting needs a seed in the team's stock (D-093); watering needs a full
  can (capacity from `labor.json` `can`, 2 plots per fill, `placeholder`); harvest puts crops in the
  carry bag (capacity `carry` 4, `placeholder`). A plot's visible state is the information (no HUD).
- **Carrying** is the player's item slots (`game/items/`): hands (a tool, a lantern, a seed packet,
  a crate), and the bag (up to `carry` crops). The host owns the item graph; `request_pick_up`,
  `request_drop`, `request_carry_player` are validated like holds (range, free hands).
- **Selling** is at the sell point only (the stand-in sell box at (40, 20) in DD Phase 1, D-016) and
  at the dawn cash-in; `request_sell` is a 2 s hold (doc 02). The client never changes coins.
- **Tool noises** are in section 8. The noisy watering can is the DD Phase 1 default
  (doc 01 "Build Plan > Phase 1"); the quiet can is bought (doc 02 section 10).
- **Dropped tools**: a tool left outside at night can be "stolen" by the creature as a disturbance
  (doc 03 sabotage, `stolen_tool`); the item node carries `owner_id` and `location_zone` so the
  AI Programmer's sabotage can find it.
- **Shed pegboard**: tools hang on a pegboard in the shed, and `request_hang_trap` is the trap
  version (section 11). Missing tools show as empty pegs: that is the diegetic information.
- **Physical cans (D-054, P2-27)**: the watering can and the fuel can are world objects
  (`game/items/cans.gd`, a child of the farm). Host table `id -> {kind, home, pos, holder, charge}`;
  ids `can_<n>` are interactables with verbs `take_can` (0.5 s) and `drop_can` (0.3 s, key G). One can
  at a time (`placeholder`). Counts are `placeholder` constants: 2 water cans at the well, 1 fuel can at
  the drum (doc 02 settles no count; the Game Designer should move them into data). A water can starts
  full; the fuel can starts empty. The host mirrors the held can into the carrier's `pstate`
  (`held_can`, `held_kind`, `can`, `fuel_can`), so `water`/`fill_can` need a held water can (`no_can`)
  and `fill_fuel` a held fuel can (`no_fuel_can`, `has_fuel_can`). Refusals: `can_taken`, `hands_full`,
  `not_holding`. Every change sends the whole table by rpc `apply_cans(data)` (host to all, or one late
  joiner); a dropped can lands where its carrier stood and shows there on every peer. Death and leaving
  drop the can. At nightfall `creature_move_cans()` (host, called from `creature.gd`) sends a can lying
  more than 4 m from home back home (`placeholder` for the creature moving it). Log events:
  `can_taken`, `can_dropped`, `can_stolen` (host), `can_seen` (clients, what they see). Bots fetch the
  right can first (`bot.gd` `_fetch`); `--autochore` takes a can, waters, refills and drops it.
  Art need (doc 07): `prop_watering_can.glb`, `prop_fuel_can.glb`; placeholder boxes until then.
- **Dev/launch**: Phase 1 data is the default (`--no-phase1` opts out); dev command `grow
  [ripe|growing|empty]` sets planted plots to a stage (host only).
- Prize Pumpkin (doc 02 section 6): a single special plot with its own growth rule from
  `pumpkin.json`; `water_prize_pumpkin` is a hold; the 20 m protection radius is checked by the
  host against live player positions (doc 01 "Prize Pumpkin"; the check is part of the AI
  Director's gnaw rule in doc 03 section 10, not duplicated here).

### The store (P4-06, doc 02 section 10)

- `game/items/store.gd` (`Store`, child of `Farm` on every peer, group `store`). Every `store.json` row is
  bought at the `store_crate` (within 3.5 m, placeholder) at its `price`, from its `unlock_day`. Seeds are not
  `store.json` rows: the store menu buys them at crops.json `seed` into the team stock `team["seed_<crop>"]`
  (`buy_seeds`, `seed_why_not`, `seed_count`; saved and replicated with `team`), and planting uses one (D-093,
  superseding D-090). Foreclosure never seizes seeds. No crop is sold.
- Wire: client `request_store(op, arg)` (`buy`, `flare`, `scarecrow`, `seeds` with arg `<crop>:<n>`, n 1 to 10) ->
  host validates -> `apply_store(state)`
  carries the whole small state (team counts, per-player ownership, scrap, placed scarecrows, flare shots, opened
  plots) to everyone; a late joiner gets it on `farm_state`. Refusals use `apply_refused` (hud.gd `REFUSED_TEXT`).
- Keys (placeholders, `project.godot`): `cycle_item` R, `buy_item` K, `fire_flare` H, `place_scarecrow` N. The HUD
  prompt shows only within reach of the crate. Dev console: `buy <item>` (anywhere, host).
- Store menu (P4-22, `game/ui/store_menu.gd`, built by hud.gd): `interact` at the crate with nothing aimed opens it.
  One row per `store.json` item (price, Buy sends the same `request_store`) and one per crops.json seed with
  `Buy 1` and `Buy 5` (op `seeds`) and the team's count. Rows grey from `why_not(peer, id, false)` and
  `seed_why_not(peer, crop, n, false)`, which are client-safe; the host checks again on Buy.
  Aiming at an empty plot with no seed of its crop, the prompt says "Buy seeds at the store".
- Hotbar (P4-22, hud.gd `_slots`): bottom-centre slots for what the local player holds or the team owns, each with
  a one-line use hint. A CEO-requested exception to "No HUD markers" (D-091): it points at nothing. The seed
  slot shows only while the team owns seeds, with counts and the crop T has picked (D-093).
- Items: `scrap` adds `repairs` to `scrap_bought` (`take_scrap()` spends the free scrap first; nothing calls it yet,
  Q-100). `quiet_watering_can` (per player) offers verb `water_quiet` (5 s, noise x0.5, labor.json).
  `brighter_lantern` is tracked (`lantern_mult(peer)`); no player lantern exists yet. `shed_lock` sets
  `creature.shed_lock`. `scarecrow` (max 3) is placed at the player's feet, 3 m apart, and the creature's
  lurk/lure/stalk moves will not step closer than `creature_avoid_m` (`creature.gd` `_scarecrow_in_way`).
  `flare_gun`: one shot; `fire_flare` makes `noise_flare` and, if the creature is within that radius (inference),
  calls `creature.flare_hit(30)`: Retreat for 30 s. `Death.step_free_scrap` (dawn step 7) calls `refill_flare()`.
  `plot_pair` unlocks 2 locked plots, refused past `farm.plot_ceiling()` (doc 02 section 4).
  `walkie_talkie`/`walkie_battery` are stocked; P4-14 builds the radio.
- `seizable()` lists the bought upgrades; `seize(id)` takes one away (P4-07 calls both).

## 10. Corruption, Shaken and the well

- **Corruption** (doc 01 "The Corruption"; effects table in `taint.json`, doc 02 section 13): host-owned flag
  per player with a cause (`dead_plot`, `trap_pit`, and so on from doc 02). While Corrupted: sprint
  x0.6, pry x1.5, footsteps x1.5 on the Noise radius, and the creature tracks the player within 60
  m with a 20 s night trail (doc 03 section 3). `apply_taint_changed(peer, on, cause)` informs
  clients, who show it as dark smudges on the hands and a faint fog on screen (visual detail is doc
  07's).
- **Washing** is the `wash` hold, 10 s at the well (doc 01, doc 02 section 2.1), emits `well_pump`
  (45 m) and clears Corruption on completion. The well is the only place; it is a normal `Interactable`.
- **Shaken** (doc 01 "Day deaths"): 60 s of sprint x0.6 after surviving a trap race (doc 03 section
  7); host timer, `apply_shaken(peer, seconds)`. Stacks with Corruption (x0.36, doc 02 section 13).
- Corruption and Shaken are applied on the host and mirrored for the multiplier; the host's speed check
  (section 6) uses the host's copy.

**As built (P3-07).** `game/player/taint.gd` (node `Taint`, group `taint`) owns the flag: host
`set_taint(peer, on, cause)` writes `Game.players[peer].tainted` and `taint_cause`, logs
`taint_changed`, and sends `apply_taint_changed`; a second Corruption while Corrupted changes nothing and
logs nothing (doc 01). Corruption ends with `wash` (cause `well`), at dawn (cause `dawn`), or on death
(cause `death`; inference: a ghost is never Corrupted, doc 01 names only washing and dawn). Causes
built: touching a source on the ground within 0.8 m (`leavings`, `dead_crow`, `strange_seeds`;
`add_source` / `remove_source`, `apply_taint_source`, placeholder marks; 0.8 m is a placeholder),
picking up a stolen can (`stolen_tool`) and picking up a can left more than 4 m from its home at
dusk (`field_item_at_dusk`; inference: "in the field" uses the creature's can rule,
`items/cans.gd`). A can Corrupts its next taker once, then is clean (`can_tainted` logs the mark).
Moonflowers wait for their task. Leavings are removed at dawn (inference; doc 01 is silent).
Every peer shows the Corrupted player's body black (placeholder for the hands art) and the local
HUD prints "Corrupted: wash at the well" (tester text until the hands model and heartbeat, Q-060).
The wash hold is offered at the well only while the local player is Corrupted (refusal
`not_tainted`). Pry: `hold_registry.gd` multiplies by `taint.json` `pry_mult`; `trap_race.gd`
counts the race's pry time the same way. Sprint: `player.sprint_max()` is `labor.json`
`sprint.max_s` times `taint.json` `sprint_mult` (Corruption) times `shaken.sprint_mult` (Shaken), so
the two stack to x0.36; the HUD bar uses it as its maximum.

Shaken (P3-07) is only the sprint cut: `trap_race.gd` `shake(peer)` runs `taint.json`
`shaken.duration_s`, restarts on a new cause, sets `Game.players[peer].shaken`, and sends
`apply_shaken(seconds)` to the Shaken player, who keeps `player.shaken_s`. The bear trap's walk
x0.6 for 60 s (doc 02) is a separate slow, `slow(peer)` and `apply_slowed(seconds)`; a freed
player gets both. Dev console: `taint [peer] [off]`, `taint_source [kind]`, `shaken [peer]`.

## 11. Traps from the player side, flags and defenses

Traps are host-owned (doc 03 section 8). The player side is:

- **Getting caught.** The trap handler triggers on the `trap` layer (6) with a host-side proximity
  check on the host's view of the player (the closer-to-victim rule applies to lunges and kills, not
  to traps, which are static; the race fairness is the half-RTT credit in section 7). A sprung trap
  sends `apply_trap_changed` and starts the race: `apply_trap_race(victim, trap, deadline, start
  distance)` to everyone, so the other players can come and help (doc 01 "Night Traps").
- **Prying free.** `request_pry` hold (4 s solo, x1.5 Corrupted, x0.6 helped, doc 03 section 7);
  completion frees the player and starts Shaken. Failing the deadline is `death` with cause
  `trap_race`.
- **Disarming and filling (built, P2-11).** All are `request_hold` verbs (section 7), not separate
  requests. `disarm_bear` (5 s) works on a *set* bear trap; the trap leaves the ground, `trap_changed`
  `disarmed` goes out and the player holds a disarmed trap (`apply_hands`, one trap, no stacking: a
  second disarm is refused `hands_full`). `fill_pit` (4 s) works on a set or sprung pit and needs the
  shovel (refused `need_shovel`); it ends in `trap_changed` `filled`. `Interactable.INSTANT_S` (also `take_trap`, 1 s, P2-19: picks up a loose trap, refused `hands_full`) holds the
  verbs with no `labor.json` entry. Both clear the Creature's table entry (`TrapRace.clear_trap`) so it
  can set that kind again. Noises: `disarm_bear` emits `tool_disarm` (8 m) at completion; `fill_pit`
  emits `tool_shovel` (25 m) at start and completion (the section 8 table). `place_flag` and `hang_trap`
  emit nothing: neither has a kind in doc 03 section 3.1 (placeholder, *inference*; the AI Programmer
  can add `noise_flag` / `noise_hang`). Not built: the Tracker x0.6, the kneeling-still check, Corruption,
  `request_cut_tripwire` / `cut_bells`.
- **The shovel.** Taken and hung back at the pegboard (`take_shovel` / `return_shovel`, 0.3 s, both
  placeholders in `INSTANT_S`). It is a flag on the player (`Game.players[peer].shovel`), not an item
  yet; `apply_hands(peer, shovel, trap)` shows it (a brown stick in the hand) to everyone. Death drops
  both. No shovel marker exists in `farm.tscn`: the pegboard is the rack.
- **Flags (built, P2-11).** Right mouse (`alt_use`) held 1 s on the ground the ray hits (3 m) is a
  `place_flag` hold; the target id is the wire name `flag:<x>,<z>` (one decimal, `FlagSpot`), built by
  the client for its ring and by the host per request (the registry frees it). Refused `flag_here`
  within 1 m of another flag. `TrapSweep` (`game/traps_player/trap_sweep.gd`, host) keeps the list,
  one `{pos, by}` per flag (`by` is the placing peer), and sends it whole as `apply_flags(flags)`;
  every peer draws a pole and red cloth (placeholder art). Disarming or filling a trap clears flags
  within 2 m. A late joiner gets the list on `farm_state`.
  **Limit and removal (P4-33, D-120).** A player has at most `labor.json` `place_flag.max_per_player`
  flags out (3, placeholder); one more is refused `flag_limit`. Every drawn flag carries a `FlagSpot`
  with a thin pick body from 0.7 m to 1.8 m (above a set trap's 0.6 m box), so any player aims at it
  and holds `interact` for `remove_flag` (0.5 s, `INSTANT_S`, placeholder; D-142); the host refuses
  `no_flag` if none is there, and the owner's slot frees. `HoldController.pick` sees through a flag:
  another target within `FLAG_SEE_THROUGH_M` (1 m, placeholder) behind it wins, so a flag on a trap
  never hides its disarm, fill or pickup. A flag cleared by a disarm or fill frees its slot too. When a
  player leaves or drops (`Game.player_left`) the host removes all their flags (`flags_dropped`).
  Dev console: `flag [peer]` plants a flag at that player's feet through the same hold. The minimap
  draws every flag as a small red pennant from `TrapSweep.flags`. Not built: the creature moving flags (doc 01 "Flags", day 5); when built it
  moves `pos` and keeps `by`.
- **Pegboard (built, P2-11).** `TrapSweep` also keeps `filled`, one bool per `pegboard_slots` marker
  (sorted by name), and `apply_pegboard_changed(filled)` sends it. The board is one target (`pegboard`,
  on the `pegboard_spots` marker): with a trap in hand it offers `hang_trap` (1 s, first empty slot;
  refused `pegboard_full` with none), otherwise the shovel. A filled slot is a dark block on the
  board, an empty one a pale slab. The start state is all full (doc 02 section 12, placeholder);
  `-- --pegboard-empty` starts empty for tests. API for the AI Director and P2-05 (theft):
  `TrapSweep.filled` and `TrapSweep.take_trap() -> bool` (host). **Open:** with a full start board a
  disarmed trap has no free hook until a trap is stolen or the start is lowered.
- **Clues (P1-20, unchanged).** The Creature draws a set trap's clue disc on every peer, seen within
  4 m and facing it. `TrapRace` gives every set or sprung spot a `TrapTarget` (`sync_set()` on the host
  because the Creature tells only the *other* peers about `set` and `moved`).
- **Log events.** `trap_changed` (`set`, `sprung`, `disarmed`, `filled`) with `by` and `kind`;
  `flag_placed`, `flag_removed`, `flags_dropped`, `pegboard_changed`; every peer logs `apply_flags` and `apply_pegboard_changed` when it
  receives them. Doc 09 section 3 reads `trap_changed`.
- **Scarecrows and fences.** `request_place_defense(kind, position, yaw)`; the host validates:
  a placement spot on open ground, no overlap with a plot or a trap spot, **and no closer than 3 m to
  the cart route** polyline (doc 04 section 6.1, waypoints R0 to R8, 147.9 m; this answers Q-014
  item 6; 3 m is doc 04's inference-level suggestion and a `placeholder`). The route is read from the
  level scene's `cart_route` `Path3D` (Level Designer: Q-019 asks). The cart route is kept fixed;
  the refusal reason is `blocks_cart_route`, and a refused placement gives the player a plain-language
  message in-world (a red outline on the ghost preview), not a HUD tag.
- **Player scarecrow count** comes from `store.json`; moved scarecrows (doc 03 sabotage) use doc 04
  section 7.3 spots.

### Door state and world dressing (P5-27, D-182, Q-307)

- **Doors** (`game/interaction/doors.gd`, `Doors`, a node in `main.gd` after Farm). One door per `doors` group
  marker: `door_barn`, `door_farmhouse`, `door_toolshed`. Each is an `Interactable` (range 3 m) with the verb
  `open_door` or `close_door`, whichever applies; both are instant holds (0.3 s, `Interactable.INSTANT_S`),
  so they go through the same `request_hold` path as every chore. The host validates (`already_open`,
  `already_closed`, range as for any hold), flips the state in `Doors.host_set`, sends
  `apply_door(door_id, open, by)` to everyone, emits a `door` noise at the door (`creature.json`
  `noise_door`, by the player) and logs `door` `{door_id, open, by}`. A client never flips a door itself.
- **State**: `Doors.open[id]` on every peer, host authoritative. Every door starts open. The host resets any
  closed door to open on each new day (inference: the Phase 1 farm had no doors; a playtest settles it). It is
  not in the dawn save yet (the save lists doors but the Save node stores no door state).
- **Late joiners**: the `farm_state` pull makes the host send one `apply_door(id, open, 0)` per door to that
  peer only. `by` 0 means "snap": the leaves jump to the state without the 0.25 s swing.
- **Collision follows the door**: a closed door enables a `DoorBlock` StaticBody3D (layer 1, 3 x 4 x 0.3 m, in
  the gap, named without `Wall` because `creature.gd` measures buildings by `Wall*` names). The Creature has a
  collision exception for the blocks: it bangs, then comes in (doc 03 section 6). Bots move by position, so
  `bot.gd` handles doors itself (P5-55): a barn crossing is routed through the doorway (`(0,0,-1.5)` and `(0,0,2)`,
  never the wall) and `_door_stops` makes the bot open a closed barn door (`host_set`, noise by the bot) before it steps
  through. Players are physical and stopped by the block (`tests/qa/qa_p5_55_door_walk.gd`, host and client).
  The creature opens the door it banged on, once, when the bang ends and it goes in (`creature.gd` `_move`,
  `host_set(door, true, 0)`, no noise; doc 01 "enter through a door, always banging on it first"); it opens a shut door
  when it walks out too, and leaving clears `_banged` so the next entry bangs again. An open leaf is solid
  too: `LeafBody` (layer 1, 1.49 x 2.6 x 0.22 m, child of each leaf, enabled only while the door is open, creature
  exempt); the 3 m gap between the leaves stays clear (`tests/qa/qa_p5_55_leaf.gd`).
- **No holds through walls** (P5-55): `HoldController.pick` drops a pick-body hit when a layer-1 ray from the eye to the hit,
  stopping 0.05 m short, hits something first. The host does the same in `HoldRegistry._validate` (eye +1.6 m to target +1 m,
  0.5 m short, ignoring a door target's own DoorBlock and leaves) and refuses with `out_of_sight` (`hold_registry.gd` `line_clear`; `tests/gameplay/test_p5_55_pick_los.gd`).
- **Models**: `DoorArt/LeafL` and `LeafR` (`prop_door_*`, pivots at the jambs) turn -90 and +90 degrees when open.
- **`apply_tool(peer, tool_id)`**: the host tells everyone which chore tool a peer holds (`&"hoe"` while a
  `plant` or `clear_plot` hold is in the HoldRegistry, `&""` otherwise); `HeldTools` (`game/player/held_tools.gd`)
  shows `tool_hoe` on that player's `_held` node. `tool_whistle` is shown for 1 s when `apply_whistle` names the
  peer. Visual only.
- **`WorldProps`** (`game/core/world_props.gd`, every peer, nothing synced): `prop_window_glow` on each `WindowGlow_n`
  at dusk, night and harvest moon while the generator has power; a `LightRig` (own power, doc 07 light rules,
  driven by `lights.gd`) on each `prop_road_lamp` at night; perched `animal_crow` (`idle`) at each `crow_perches`
  marker. None of these animate a light.

## 12. Generator and lights

- **Generator** (doc 01 "Nights > Generator"; doc 02 section 14): host-owned node `Generator` with
  `fuel_s` (tank 210 s, burning only at dusk and night, `placeholder`), `repaired` flag and
  `power_on`. `request_refuel` (4 s) and `request_repair_generator` (6 s, 1 scrap, Mechanic x0.6)
  are holds. A dead generator emits `generator_dead` (80 m) and turns off the lit buildings, which
  is when the creature can enter them (doc 01 "Light is the rule").
- **Dimming:** below 25% fuel the lights dim, and they never flicker (doc 02 section 14). Dimming is
  a smooth intensity curve driven by `apply_generator(fuel_fraction)`, not an animation.
- **Lights.** `Light` nodes (`game/world/` places them, `game/core/lights.gd` is the shared
  controller) are host-owned: on or off with `apply_lights`, and dimming from `apply_generator`.
  They never flicker on their own. Each light is a `LightRig` (`game/render/light_rig.gd`, doc 07
  section 4) with slew-limited `set_on`, `set_dim`, `blow_out`. `lights.gd` is the **only** caller of
  those setters, and nothing else in `game/` writes `light_energy` (QA greps `light_energy`).
  `LightRig.energy_override` is guarded and written only by `light_flicker.gd`.
- **Only ghosts flicker lights (doc 01 "Ghosts > Lantern flicker").** Enforced in one place:
  `LightFlicker.flicker(light_id, caller_peer)` in `game/ghost/light_flicker.gd` is the **only**
  function in the codebase that animates a light's energy as a flicker. The host's
  `request_flicker` handler checks `Game.is_ghost(caller_peer)` first and rejects otherwise. The
  generator, lantern, trap, creature and AI Director never call it; a grep for `flicker` in `game/`
  outside `game/ghost/` is a review finding (QA's checklist, doc 09), except the `request_flicker` and
  `apply_flicker` handler glue in `Net`. The lantern "blows out"
  (instant off with a puff) and never flickers (doc 06 section 11, doc 01 "Ghosts"). A dying
  generator dims. Neither is the flicker.
- **Lanterns** are carried lights (`request_lantern(on)`); the creature sees lit lanterns at 40 m at
  night (doc 03 section 3). A lantern is a light entry in the same registry so the host knows every
  lit position.
- **Doors** (`request_door`): host-owned open or closed, emit `door` (20 m), and the creature
  reaches through open doors (doc 03 section 5).

## 13. The festival cart

Harvest Moon only (doc 01 "The Harvest Moon", doc 02 section 9, doc 03 section 14). As built in
P4-12: `game/items/cart.gd`, an interactable that `farm.gd` builds under `World` when the level has a
`World/CartRoute` `Path3D` (none on the Phase 1 farm). Group `cart`; SeasonAwards reads `cart_out`.

- Acts (`cart_act` log): 1 loading when the final dusk turns into `harvest_moon`; 2 push once the
  Prize Pumpkin is loaded (`load_cart`, an instant verb while holding it) or, with no pumpkin planted,
  on the first push; the generator fails at act 2. 3 gate run is the route's last `gate_run_m`
  (`profile_harvest_moon`); then done.
- Pushing is the `push_cart` hold that never completes. Each tick the host counts the living players
  holding it; the count sets the speed (`profile_harvest_moon`, doc 02 section 9).
- Push at the handle (P4-32). `cart.gd` adds a `Handle` marker at the model's push bar (back of the cart,
  1.45 m behind its centre, 1.05 m up; `tools/blender/build_phase4.py` `cart()`). `push_cart` is offered
  only to a player standing within 1.5 m (flat) of it; `load_cart` is unchanged. The host does not
  gate the request on the handle, so bots asking from their usual spot still push.
- Lock while pushing (P4-32). `cart.push_slot(peer)` gives each pusher a slot 0.4 m behind the handle,
  pushers side by side 0.7 m apart in `pushers` order. It is `Vector3.INF` (no lock) unless the peer is
  in `pushers`, the act is push or gate run and the cart is not stalled, so release, a knock-off, death
  and the end of the run all free the player. The host pins each pusher's received frame to their slot
  in `players.submit` (no speed check for that frame); the client walks its own body to the same slot
  each frame from the synced cart, faces the route when the lock starts and then turns with the
  cart's heading as the route bends; mouse look stays free on top of that. Clients still own their movement; the host's copy wins as for traps.
- The push hold's bar is the route, not a timer (P4-32): `cart.hold_progress(&"push_cart")` returns
  `[offset / length, "N m to the gate"]` from the synced cart, so every peer shows the same value.
  `HoldController.hold_state()` returns `[verb, progress, note]`, using a target's `hold_progress` when
  it has one; the HUD prompt reads e.g. "Push Cart... 3%  143 m to the gate".
- QA: `-- --autopush` (client or host) walks to the handle on the Harvest Moon, pushes 12 s and logs
  `autopush_step` (slot distance, hold state) each second, then lets go and logs that the lock is gone.
- The creature knocks a pusher off (`knock`): the hold is cancelled, the cart stalls `knock_stall_s`,
  and the next knock waits `knock_cooldown_s` (act 2 only). Each stall allows one `bite` of the
  pumpkin; the pumpkin caps bites at `max_escort_bites`.
- Out: the route's end is the gate. Reaching it with a living player sets `cart_out` (Q-130), judges
  the pumpkin and ends the Harvest Moon early. At the cap (dawn) `settle()` counts the cart out only
  when `x > 78` (doc 03 section 14, doc 04 section 6.1). All players dead ends it not out.
- The payout is paid once at the final dawn (`PrizePumpkin.pay`, reason `pumpkin_payout`); the final
  sale also calls `settle()` so a cart still rolling at the cap is decided first.
- `Net.apply_cart(offset, act, loaded, pushers, stall, cart_out, knocked)` is sent on change and
  every 1 s while moving (placeholder cadence, Q-128). Every peer moves the body along the curve.
- The cart squeaks: a `cart_squeak` Noise every 1 s while moving, 25 m (placeholder, Q-127).
- Pushers are shown by their bodies; the pumpkin sits visibly on the cart, bitten after a bite. No HUD.

## 14. Death, ghosts, whistle and emotes

- **Death.** Host-owned. Causes (doc 03 section 7 ids): `trap_race`, `deep_corn`, `night_chase`,
  `night_trap`, `harvest_moon`. The host sends `apply_death(peer, cause, position)`, drops the body
  (a prop, `Items`), spawns a `Ghost` for that peer, and logs `death`. The body can be carried by
  teammates (`request_carry_player`); doc 03 section 15 decides what bodies do to the creature.
- **Dawn, respawn and the medical bill (P2-06, `game/ghost/death.gd` `dawn()`).** Host only, on
  `phase_changed(dawn)`, doc 02 section 9 order: (1) cash-in: each living player's bag sells at its crops' prices (P4-04)
  price (`money_changed` reason `dawn_cash_in`); the dead lose bag and fuel can (`carried_lost`); (3) bill:
  `_bill_deaths` (every death since the last dawn, day deaths included) gives `min(first + later * (n-1), cap)`
  from `medical_bill.json`, each scaled by `Data.scaled` to the headcount at that dawn (doc 02 section 8). The
  bank pays down to `season.bank_floor` (4); the rest goes to `Farm.final_extra` (the final payment adds it
  when payments are built). `money_changed` reason `medical_bill`, `player` null.
  Then every ghost respawns at its own barn spawn slot (`player_spawns[index in Game.players]`), then
  `dawn_summary` (`debt` is 0 until P4-07).
- **Dawn steps, full season (P4-04).** `Death.DAWN_STEPS` is the doc 02 section 9 order and `dawn()` logs
  `dawn_step` then calls `step_<name>(farm, final)` for each: `cash_in` (each living bag sells at its crops'
  prices, `Crops.bag_value`), `final_sale` (final day only: crops in the ground sell at `end_season_sale_pct`,
  nearest coin, wilting crops excluded; the festival payout is P4-09's), `medical_bill` (scaled by
  `payment_pct_by_players`, D-079), `payment` (stub, P4-07), `farm_damage` (night-crop `dawn_wilt()`, then
  the Sabotage dawn trample), `save` (stub, P4-10), `free_scrap` (non-stacking). A later task fills a stub
  in place; `tests/gameplay/test_season.gd` checks the order. `Clock` ends the season after the final
  dawn (`season_ended`, `season_over`, the clock stops); clients learn it from the final Dawn Report because
  `apply_clock` has no season flag (Q-085).
- **Ghosts** (doc 01 "Ghosts"): a spectator camera that flies, passes through everything but cannot
  interact with the world, see `Ghost` in section 3. The ghost's position is its own camera
  position (client-owned like all movement). Ghosts see the world as it is (including a dim glow on
  the creature when within 20 m, doc 01 "Ghosts > Vision": the glow is doc 07's visual; the rule is
  host data), and may cycle spectate targets (`spectate_next/prev`).
- **Ghost voice position (answers Q-006 item 4).** A ghost's `VoiceEmitter` is attached to the
  ghost's **spectating camera position**, i.e. the `Ghost` node's transform (the ghost body), not
  to the player they are watching. `Ghost` exposes `voice_anchor() -> Node3D` and `Voice` attaches
  the emitter there (doc 06 section 8: "Ghost voices play from the ghost's spectating position as the
  Ghost system reports it"). The living hear it through the ghost static chain (D-011) from that
  position; ghosts hear each other clean.
- **Lantern flicker** (ghost power): `request_flicker(light_id)`, host rejects non-ghosts and
  cooldown-limits (per-ghost cooldown, `placeholder`; doc 01 gives none, only that it is "short");
  `apply_flicker(light_id)`; handled by `LightFlicker` (section 12).
- **Crow possession**: `request_possess_crow(crow_id)` at a `crow_perches` marker; host picks the
  crow, `apply_crow_possessed`. A possessed crow can "caw" (a ghost action, no creature Noise) and
  gives the ghost sight of the creature (doc 03 section 11.6, doc 04 section 8.4). The creature may
  attack a possessed crow (a `dead_crow` disturbance), host rules in doc 03.
- **As built (P3-09).** `game/ghost/ghost_powers.gd` (node `Death/GhostPowers`) holds every rule; the
  look is `game/ghost/light_flicker.gd`. Requests: `request_flicker(light_id)`,
  `request_possess_crow(crow_id)`, `request_crow_caw()`, `request_rustle()`; results:
  `apply_flicker(light_id)`, `apply_crow_possessed(peer, crow_id)` (to every peer, `""` to
  release), plus the P5-66 flight pair below, `apply_ghost_sound(kind, position)`. A `light_id` is the `lightrig_spots` marker path
  relative to Main (e.g. `World/Buildings/Barn/LightRigDoor`), the same on every peer; a `crow_id` is
  the `crow_perches` marker name. Host rules: ghosts only; per-ghost cooldowns flicker 8 s, rustle
  8 s, caw 3 s (`placeholder`, doc 01 says only "short"); the ghost must be within 20 m of the light
  or perch (`placeholder`); the light must be lit (a blown-out or dark lantern never flickers, doc 03
  section 20) and within 15 m of a living player (`placeholder` for doc 01's "near a living
  teammate"); one crow per ghost per `Clock.day` (inference: "once a night" read as once per day
  number), 20 s (doc 01 "Ghosts"), one ghost per perch; a rustle only inside the corn (layer 5) and
  only a sound (`sfx_step_corn`), never a creature Noise; a caw plays `sfx_crow_caw` at the perch,
  no Noise. Keys (no new actions): `use_tool` uses the nearest lit light, or caws while in a crow;
  `alt_use` rustles; `lantern` takes the nearest crow. In a crow the local player's view rides the
  flying crow (P5-66, next bullet). Ghost vision (local only): every `trap_spots` marker is hidden (all trap looks hang under
  them), and the creature mesh shows only within 20 m of the ghost's camera (30 m from a crow,
  inference so the crow adds sight), at transparency 0.6 as a placeholder "smeared silhouette".
  Not built: the creature attacking a possessed crow, the
  photosensitive flicker variant. Dev console: `ghost light|crow|rustle|caw [peer] [id]`.
- **Crow flight (P5-66, CEO playtest 2026-10-10).** A possessed crow flies; doc 01 "Ghosts" says
  "possess one crow per night for 20 seconds and fly it around" but gives no flight numbers, so they are
  `placeholder`s in `ghost_powers.gd`. The ghost's client sends `request_crow_steer(dir)` (unreliable
  ordered on channel 1, 20 Hz; the host ignores any sender but that crow's ghost; a world direction from move keys and the camera, so forward, turn, climb and dive
  follow where the ghost looks). The host (the only mover) clamps `dir` to length 1, flies the crow at
  7 m/s with altitude 1 to 8 m (under the 10 m boundary walls), and a ray on layer 1 (buildings, roofs,
  boundary walls) stops it short of anything solid. No steer for 0.4 s and it hovers. The host sends
  `apply_crow_pos(peer, position, yaw)` (unreliable ordered, channel 1, 20 Hz) to every peer; each peer draws one
  `animal_crow` (clip `fly`), smoothed, and hides the perch crow. The ghost's camera rides the crow;
  the caw sounds at the crow's position. When the 20 s end (or the ghost respawns) the host sends
  `apply_crow_possessed(peer, "")`; every peer flies the crow back to its perch at 8 m/s on its own
  (nothing is synced for the trip), lands it and shows the perch crow again. The 20 s and one-a-night
  limits, the ghost-only check, the 20 m reach and "ghosts cannot harm" are unchanged: the crow
  emits no Noise and touches nothing. A client joining mid-flight does not see that crow until the
  next possession (inference: 20 s, not worth a state sync). QA: `-- --crow-shot=<dir>` (each peer saves
  one picture of a flying crow); `check_ghost.gd` checks steer validation, climb, ceiling and wall;
  `tests/qa/qa_p5_66_crow_client.gd` flies a real client's crow with key events.
- **Respawn.** At dawn, ghosts get bodies again (doc 01 "Death"). `apply_respawn(peer, position)`.
  A roster player who reconnects mid-session spawns as a ghost and gets a body at the next dawn
  (doc 06 section 5). No one new joins after the match starts (D-048).
- **Whistle** (doc 01 "How players fight back > Whistle"): `request_whistle` (cooldown
  `placeholder`); the host stamps the position and sends `apply_whistle(slot, position)`; the whistle
  is a world sound everyone hears at their own distance. It emits `whistle` (50 m) to the creature,
  so it can pull the creature, which is the rule in doc 01. **It is the only sanctioned way to find
  a teammate by sound** (doc 01's whistle rule), so the whistle puts no marker on the minimap (P4-24).
  Its audible range is long (doc 04 section 8.2 suggests at least 171 m; the Audio Designer's number,
  Q-014 item 4 / doc 08).
- **Emotes** (doc 01 "Emotes and physical comedy"): `wave`, `point`, `shrug`, `scream` (the scream is
  an emote that is also loud: it plays a voice-like sound and emits a Noise of kind `voice` at volume
  255, i.e. 60 m; inference: doc 01 says the scream gives you away, doc 03 gives no emote row; the
  AI Programmer confirms, Q-019). `request_emote(emote_id)`; the host rate-limits (1 per 1 s,
  `placeholder`) and broadcasts `apply_emote`; clients play the animation on the sender's body.
  Pointing is a visible arm direction only (no marker).
- **More emotes (P5-45).** The list lives in `data/emotes.json` (schema `data/emotes.schema.json`, table
  `emotes`, in wheel order, each with `loud` and `cite`): the four above plus `thumbs_up`, `beckon`, `shh`,
  `cower`, `cheer`, `facepalm`, `clap`. Doc 01 lists only the first four; the extra seven rest on the CEO's
  STOP 6 and are marked `placeholder` in the data (no doc 01 edit made). Only `scream` is `loud` (Noise `voice`
  255); the others are silent and cost nothing in the Noise model. The seven are procedural poses in
  `game/player/emote_poses.gd`, built from the body's `Skeleton3D` by bone name (rest rotation times a delta
  Euler per key) and added to the AnimationPlayer's library by `FarmerBody._init`, so they play on any farmer
  mesh with the 12 bones and need no clip in the glb. `Player.play_emote` plays any one-shot the body has.
  Networking is unchanged: `request_emote` to the host, `emote()` validates against `emotes()` (from data),
  `apply_emote` to all. The wheel (`emote_wheel.gd`) lays the words on an ellipse, clockwise from the top, and
  picks by angle. QA: `-- --autoemotes` requests every emote 4 s apart after 12 s; `-- --emote-shots=<dir>`
  on the watching peer saves `<emote>_a.png` / `_b.png` from a camera in front of the sender.
  Test: `tests/gameplay/test_emotes.gd`.
- **Eight more emotes (P5-60, CEO 2026-10-10).** `salute`, `jig`, `cross_arms`, `look_around`, `bow`, `flex`, `yawn`,
  `shiver`: silent, `placeholder` rows in `data/emotes.json` (schema max raised to 24), procedural poses in
  `emote_poses.gd` (helpers `_hold`, `_alt`). Deleting a data row removes the emote everywhere (wheel, host
  validation); its pose stays unused. The wheel has two rings: the first 11 on the outer ellipse, the rest on an inner
  one; aim travel under 130 px picks the inner ring. Ghosts still cannot emote (`ghost` refusal, unchanged).
- **Whistle and emotes as built (P3-11, `game/player/whistle_emotes.gd`, node `WhistleEmotes`).** `whistle`
  (Q) sends `request_whistle`; hold `emote_wheel` (Z) opens the word wheel (`game/ui/emote_wheel.gd`; P3-11 had four
  words: up `wave`, right `point`, down `shrug`, left `scream`; P5-45 adds seven, see below; release fires, under 25 px of mouse travel
  picks nothing) and sends `request_emote(emote_id)`. Both keys are ignored while the dev console is open
  and for a ghost (a ghost's Q is `spectate_prev`). The host checks, in order: the sender has a body
  (`no_player`), is alive (`ghost`), and the whistle cooldown of **5 s** (`cooldown`; `placeholder`,
  doc 01 "Whistle" says only "short cooldown") or the emote gap of 1 s (`rate_limit`); an unknown emote
  id is `unknown_emote`. A refusal logs `hold_refused` (`verb` `whistle` or `emote`, `target` "") and
  sends `apply_refused` to the sender. Accepted: the host stamps the position from its own
  `Game.players` state, emits the Noise (`whistle` 50 m; `scream` as `voice` at byte 255, 60 m), logs
  `whistle` or `emote` (section 18) and sends `apply_whistle(peer, position)` /
  `apply_emote(peer, emote_id, position)` to everyone. The RPCs carry the **peer id**, not a voice slot,
  because slots are not built (Q-065). Every peer plays `sfx_whistle` (doc 08 section 3.2: `unit_size`
  20 m, `max_distance` 220 m) or `vox_emote_scream` (no file yet, silent) at that position and the emote
  on the sender's body (`Player.play_emote`: a placeholder box arm that waves or points along the
  sender's pitch, a shrug bob, a scream swell; the owner sees nothing in first person). No marker of any
  kind. QA: `-- --autowhistle` makes a peer send two whistles and two emotes every 3 s through the real
  request path; dev console `whistle [peer]` and `emote <kind> [peer]` go through the same host checks.
  The by-ear placement test at 30 m and 72 m is pending a tester (OPEN_ISSUES).
- **Crowkeeper bait perches (P5-52, `game/player/crow_perches.gd`, node `CrowPerches`, after `WhistleEmotes` in `main.gd`).** Key P (`place_perch`) sends `request_store(&"perch")`; the host's `toggle(peer)` places a perch where the Crowkeeper stands or takes up their own within `pickup_m`. Refusals (`apply_refused` `perch`): `ghost`, `not_crowkeeper`, `perches_full`, `not_at_edge` (no `plot_spots` or `creature_cover` node within `edge_m`), `too_close`. Every 0.25 s the host `step()` flushes any off-cooldown perch with a mover within `flush_radius_m` that moved at least `move_eps_m` since the last tick (a living player but not the owner, a loose animal, the creature); a Scares `fake_out` within the radius flushes it too. A flush emits `NoiseBus.emit_kind(&"crow_flush", pos, 0)` and sends `apply_scare(&"perch_flush")`, which every peer draws as `Scares._crow_burst` plus `sfx_crow_burst`, the perch crow hidden 60 s. State syncs as `apply_scare(&"perches", ..., "x:z:owner;...")`, re-sent on `farm_state`. No marker, and the burst is the same for a teammate and the creature. Numbers in `roles.json` `crowkeeper` (placeholder). Perches live in host memory, not in the save. QA: `-- --autoperch` (host, with `--role=crowkeeper`) places a perch at 6 s and flushes it at 10 s; the client logs `perches_seen` and `perch_flush_seen`. Test: `tests/gameplay/test_crow_perches.gd`.

## 15. Dawn Report and Season Awards screens

Screens are client-side presentation of host data (`game/ui/`), shown at dawn and season end.

- **Dawn Report** (doc 01 "Dawn Report"): sections in order: Best Impression, Most Wanted, Cause of
  Death, Hero of the Night. The host builds the report at dawn from the night's events (the same
  records written to its log, section 18) using the templates in `dawn_report_templates.json` (doc 03
  section 16) and sends `apply_dawn_report(report)` with lure references, not audio (doc 06 section
  12).
- **Replay** plays the creature's fakes locally: each peer already holds every Lobby-lines clip, so
  it plays the lure's segments on a `VoiceEmitter` with the lure's `tell` and ghost flag. The player
  who owns a clip is replayed only if that player's **current** voice setting is `lobby_lines`; an
  Off player appears as text plus the sound the creature faked for them (footsteps or tools). Streamer-safe
  mode never replays voice clips (doc 01 "Difficulty and group settings"). This is the one place the
  Dawn Report touches voice, and it uses `Voice`'s API, not its own player.
- **Order of the dawn** (doc 02 section 9): cash-in, final-dawn 50% sale + festival payout, medical
  bill, payment, farm damage, save, free scrap and flare refill. The report screen shows the cash and
  payment results as they were applied; it is a view and applies nothing.
- **As built (P3-12):** `game/ui/dawn_report.gd` (node `DawnReport`, added by `main.gd`) and the pure
  builder `game/ui/dawn_report_logic.gd` (unit checks: `tests/ui/test_dawn_report_logic.gd`).
  - **Host build:** `Log.logged` (a signal emitted after each record is written) feeds the host the day's
    report events, so the report reads the same records as the log. It adds places the creature never
    logs: `lure_played.owner_place` (the voiced teammate's AI Director region at that moment),
    `chase_started.place`, `death.place_name` and `death.distance` (to the nearest `player_spawns`
    marker, standing in for "the barn lights"; inference, doc 04 names no light point). It builds the
    report one frame after `dawn_summary`, which `Death.dawn()` logs once cash-in, medical bill and respawn
    are done, so the card follows the money steps. Events are kept from one dawn to the next (the day's
    targeted lures count: they are day lures). `Net.apply_dawn_report(report)` carries text and lure
    references only.
  - **Report:** `day` (the day that ended), `streamer_safe`, `ledger` (rows `[label, coins, red]`:
    cash-in, medical bill paid, the unpaid rest added to the final payment, farm damage, balance;
    payment is not built) and `sections` in order: Best Impression (the lure with the largest
    `lure_result.moved_m`), Most Wanted (most `chase_started`; ties, and a chase-free day, go to the
    owner voiced in most lures; Q-066), Cause of Death (one obituary per death, `reconnect` skipped; a
    full wipe heads it; none gives `no_deaths`), Hero of the Night (score: trap disarmed or pit filled 3,
    a pry that freed a teammate 3, a refuel 2, outside the most while someone hid 1; placeholder weights,
    the biggest deed names the action), Heard in the Corn (up to 3 more targeted lures, placeholder cap)
    and Flags Placed (per-player flags still out: `flag_placed` less `flag_removed` by `owner`). A section with nothing to say is left out,
    except Cause of Death and Flags Placed. Copy without a template (freed, refueled, flags) is in the
    builder until the Game Designer adds it (Q-066).
  - **Screen (every peer):** placeholder newspaper card (doc 07 section 9 colours, 0.5 degree tilt,
    masthead, dotted ledger, red ink, fold line; no vignette). A section fades in every 3 s; a click or
    Enter reveals the rest at once (skipping their replays); the next click closes. It closes itself at
    dusk. While open it frees the mouse and sets `Game.console_open`. It applies nothing and logs
    `dawn_report_shown` on each peer.
  - **Replays** (on a section's reveal, 2.5 s apart, placeholder): a clip plays through
    `VoiceChain.play_clip` with its tell at the listener's `voice_peer_volume`; a muted owner is skipped
    whole (D-047). A clip whose owner is not `lobby_lines` now, or any clip in streamer-safe mode, shows
    the `off_player` line and plays a neutral cue (`sfx_step_dirt`, placeholder). A sound lure shows the
    `off_player` line and replays the faked sound (`creature.gd` `SOUND_LURES`); a stranger plays its
    `Soundscape.STRANGER_LINES` line. The ghost flag is carried but changes nothing until P3-10's ghost
    chain exists. Streamer-safe is the host's `--streamer-safe` debug flag until the lobby's group option
    exists; it blocks every voice replay (this section's wording; doc 01 says "live clips", Q-066).
- **Season Awards** (doc 01 "Season Awards"): shown after the final dawn or on foreclosure. Computed
  by the host from the season log (the same events) and sent as one `apply_dawn_report`-shaped
  message with a `season` flag. The awards list is doc 03 section 16's.
- No audio of a player's real voice is kept by either screen (doc 01 "Voice settings > Storage").

### Lore in game (P5-48, doc 11)

All lore text lives in `data/lore.json` (table `lore`, schema `lore.schema.json`, every record `source: "placeholder"`),
registered in `Data.TABLES`. Records: `masthead`, `intro`, `road_sign`, `notes` (10 verb notes), `archive` (21 clippings),
`win` (3 lines). Text only: no captions, no voice, no rule (doc 11 s1). Every peer reads the same file; nothing is synced.

- `game/ui/lore.gd` (`Lore`, statics): `text(id)`, `clipping(season, day, tenants)`, `archive_index()`, `win_lines()`,
  `tenant_names()`. The clipping for a dawn is `posmod((season-1)*7 + (day-1), 21)`, so season 1 day 1 is clipping 1,
  season 2 day 1 is clipping 8, and it repeats after 21. `{tenants}` (the last clipping) becomes the team's names.
- `game/world/lore_props.gd` (`LoreProps`, added in `main.gd` and `farm_view.gd`): no floating words (CEO 2026-10-10). Every
  note is a thin paper box (`MeshInstance3D`, sized from the wrapped text) with a non-billboard `Label3D` lying on its
  face. A note record is `anchor` (node path under the farm scene), `offset` (x/z metres from the anchor, y height above
  ground), `facing` (yaw degrees, 0 faces +z, 180 faces -z, 90 faces +x, -90 faces -x) and `mount`: `wall` (card pinned flat
  on a wall) or `post` (card on a wooden stake from the ground), plus an optional `width` (card wrap width in metres, default 1.5). A moved prop moves its note (the well, P5-47); a missing
  anchor logs a warning and skips. The road sign is two boards (the BRENN FARM title over the bank notice) on two posts at
  the lane centre (`road_sign.at` in `lore.json`, with `notice_y`, `title_y`, `post_top`, `post_half`), above the corn, facing the gate. Notes have a 7 m visibility range. It does nothing when the farm has no
  `World/Buildings/Barn` (Phase 1 farm).
- UI: `intro_card.gd` puts `Lore.text(&"intro")` above the situation; `dawn_report.gd` uses the masthead and appends a
  "FROM THE ARCHIVE" block as the last pending section; `season_awards.gd` draws `Lore.win_lines()` on the campaign win.
- Test: `tests/gameplay/test_lore.tscn` (a scene, because `Lore` reads the `Data` autoload).

## 16. Menus and settings

- **Menus** (`game/ui/`): main menu (Host, Join, Settings, Quit), menu lobby (a menu screen over a
  3D line-up: roles, difficulty, group options, ready; P4-23, P4-35), pause overlay, host-left card, "waiting for a farmhand" card (doc 06
  section 5), Dawn Report, Season Awards. The Host and Join screens are doc 06 sections 3 and 4;
  `game/ui/` embeds `game/net/`'s screens.
- **Settings** live in `user://settings.cfg` (a `ConfigFile`, autoload `Settings`) on **each client's
  disk and never in the host's save** (doc 01 "Voice settings > Storage"; CONTRACTS section 5).
  `Settings.DEFAULTS` is the key list; `Settings.set_value` + `Settings.save()` write it and emit
  `changed(key)`. `SettingsApply` (`game/core/settings_apply.gd`, a node on the root made by `Settings`)
  pushes every key to the engine at boot and on each change. Display and graphics keys apply only
  once the player has set them (`Settings.is_set`), so launch flags and the QA window tiling still work.
  Keys: `mouse_sensitivity` (radians per pixel, default 0.0025; the Comfort tab slider shows it as a
  multiple of the default, 0.1x to 3.0x in 0.05 steps, applies live because `Player.look` reads it on
  every mouse motion, and saves on change; P5-46), `fov` (read live by the local Player), `toggle_crouch`, `reduce_scares`
  (default false; `Soundscape` softens stingers and sudden creature cues, read live; accessibility,
  inference: no doc 01 number), `push_to_talk` (Voice reads it live), `voice_gain_db`, `player_name`,
  the six volume sliders `vol_master`, `vol_music`, `vol_sfx`, `vol_ambience`, `vol_voice`, `vol_ui`
  (0 to 1, each sets its bus, muted at 0; Q-032, doc 08 section 10), `voice_setting` (`unchosen` /
  `off` / `lobby_lines`) and `lines_recorded` (P2-03 sets it), `keybinds`, `mic_device`,
  `quality_preset`, `render_scale`, `shadow_quality`, `vsync`, `fps_cap`, `window_mode`, `resolution`,
  `monitor`, `brightness`, `photosensitive_safe` (default false; asked on first launch; doc 01
  "Photosensitivity safety", D-046; read live by `LightFlicker`, the lunge cut and the dev toys).
  D-047 (doc 01 "Comfort and convenience settings"): `camera_shake` (0 to 1, default 1; 0 also
  keeps the knockdown camera level), `centre_dot` (default false), `voice_peer_volume` (player id to
  0 to 1, 0 is mute; applies to that player's live voice and the creature's replays of their clips
  alike), `toggle_holds`, `toggle_sprint`, `invert_y` (default false), `ui_text_scale` (0.8 to 1.5,
  default 1).
  Streamer-safe and denoise are not built. There are no voice
  subtitles (D-019).
- **Settings screen** (`game/ui/settings_menu.gd`, shared by the main menu and the pause menu), five tabs:
  - **Keybinds:** every non-`ui_*` InputMap action. Click an action, press the new key or mouse button;
    Esc cancels. A key already used by another action shows a warning and is still bound (the ghost
    spectate keys deliberately share E and Q with interact and whistle, so those pairs never warn).
    Stored as `keybinds`: action -> `[{"t": "k", "c": physical_keycode}]` or `{"t": "m", "b": button}`;
    only changed actions are stored, "Reset all" empties it.
  - **Audio:** the six volume sliders, push-to-talk, the mic device (`AudioServer.input_device`, shown
    when more than one exists), and the voice setting with doc 06 section 11 copy and the Discord line.
    No mic gain control: Voice exposes none (inference: remote-voice gain `voice_gain_db` is a tuning
    value, not a player option; add a slider if Network & Voice exposes a capture gain).
  - **Graphics:** quality preset (`low`, `medium`, `high`, `custom`: each sets `render_scale` and
    `shadow_quality`, placeholders; touching either switches to `custom`), shadow quality (directional
    and positional shadow atlas 1024, 2048, 4096; doc 07 section 10 makes shadows the first cut), render
    scale 0.5 to 1.0 (`scaling_3d_scale`), VSync, FPS cap (`Engine.max_fps`). **No fog or corn density
    knob:** the corn budget (doc 07 section 10) and the fog values (doc 07 section 3) are fixed so every
    player sees the same night, and light rules (D-019, doc 07 section 4) stay untouched.
  - **Display:** window mode (windowed, borderless, fullscreen), resolution (windowed), monitor, FOV,
    brightness. Brightness is the night ambient floor, 0.2 to 0.4, default 0.25 (doc 07 section 5,
    "Gamma and brightness slider"): `SettingsApply` raises the active `Environment` ambient to the floor
    after `WorldLook` sets the phase value (never lowers it), and touches no light. There is no gamma
    control and no screen pass. At 0.2 the slider equals the default because doc 07 s3 holds the night
    ambient at 0.25 or more (inference; the CEO or Technical Artist can rule otherwise).
  - **Comfort** (D-047): camera shake and head bob slider (`camera_shake`; `Player._head_bob` scales the bob, and `Player.knockdown_camera(seconds)` rolls the camera but stays level at 0; no knockdown exists yet, the creature work calls it on the local player), centre dot (`HUD`, 4 px), toggle holds (`HoldController`: press starts, release arms, next press cancels; hold times unchanged), toggle sprint, invert mouse Y, menu text size (`SettingsApply` sets `default_font_size` (16 x scale) on a Theme assigned to the root Window, because `ThemeDB.fallback_font_size` changes nothing; the HUD sets its own sizes). No panic key, scare volume cap, colour-blind option or captions.
  - **Per-player voice volume** is not in this screen: the pause menu roster (`PauseMenu._roster_volumes`) has a slider and Mute box per other human, stored in `voice_peer_volume` under the player profile uid (else the peer id). `Player._peer_gain_db` applies it to the live voice emitter; `Creature._hear_lure` reads `Settings.peer_volume(owner)` to skip a muted player's replay entirely (no crackle either, so mute never exposes a fake) and to scale the replay volume.
- **Flow.** Launching with no arguments in a window opens the main menu (`game/ui/main_menu.tscn`):
  Host (port), Join (a join code, a raw IP or `IP:port`; D-049 brings back doc 06 s4 join codes for rejoining), Settings, Quit. Host and
  Join turn Phase 1 data on and reload it (a bare exe has no `--phase1`; remove when the full farm lands).
  Both land in the **menu lobby** (`game/ui/lobby.tscn`, P4-23; line-up scene P4-35, D-140): a menu screen
  over a local 3D line-up, no farm and no player bodies (nobody spawns until the match starts). The line-up
  is the `Players` node (`lobby.gd` `LineUp`): a placeholder barn set at night (three `LightRig` lanterns,
  the centre one in group `barn_lantern` for the recording staging; a moon and a spot on the centre authored
  in `lobby.tscn`), and one placeholder farmer per player with a role hat (`assets/models/hat_<role>.glb` when present, D-144; else the `LineUp.HATS` placeholders) and three
  `Label3D` tags: name, role, and HOST / READY / NOT READY. The local farmer stands in the centre; the others
  alternate right and left, a step back; the camera fits six (doc 01 "Format" cap) between the side panels, and odd slots lift their tags so neighbours stagger. `LineUp.sync()` runs on every refresh and frees a leaver's farmer.
  Left: the role cards (P4-09; a taken role greyed out, all locked when a loaded season keeps its roles,
  which clients learn from `apply_roles`' `locked` key, D-143). Right: a roster with each player's voice
  setting, the join code, doc 01's Discord line, the group settings (difficulty and streamer-safe; host
  edits, `Game.set_group_settings`, everyone sees them). Above the roster a name field (P5-20): Enter or
  focus-out saves `player_name` to Settings and sends `request_name(name)`; the host cleans it
  (`Net._clean_name`: no line breaks or `[ ]`, 24 characters, blank -> "Farmer"), keeps it unique ("Farmer 2"),
  updates `Net.profiles`, resends `apply_roster`, and both ends emit `Net.names_changed`. Lobby only. Bottom right: one big button. A client's button toggles Ready
  (`request_lobby_ready(on)`; the host logs `lobby_ready {player, on}` and broadcasts
  `apply_lobby_ready(peers)` into `Game.lobby_ready`; a joiner sends `false` to get everyone's marks). The
  host's button, "Start the season", is enabled when `Game.all_ready()` (every other human ready; bots
  count as ready); Enter presses it. `Game.lobby_ready` is cleared at match start and on leave. Voice hangs
  each player's emitter on their farmer, so lobby voice is placed in the line-up (the AudioListener3D rides
  the camera). `Game.start_match()` waits for `Game.match_ready()` (P2-03 clip pre-share hook, doc 06 section 12
  step 5), clears each player's movement state (the host drops frames with a stale `seq`), starts the
  `Clock`, sends `apply_match_start` and everyone changes to `main.tscn`. A client that joins during
  the lobby gets `p_lobby = true` in `apply_session_state`. The pause menu (`PauseMenu`, `CanvasLayer`
  120, Esc) does not pause the session: Resume, Settings, Leave to menu,
  Quit. While open it sets `Game.console_open` so Player and HoldController ignore game keys. It also
  shows the host-left card (`multiplayer.server_disconnected`) with a way back to the menu.
- **Joining, rejoining and join codes (P2-16, D-048 to D-050).** `Game.match_roster` (uid -> true, filled by
  `start_match` from `Net.profiles`) is who may be in a running match; `Game.match_started()` is true when it
  is non-empty, so a host started straight into the farm (debug, QA) stays open. While a match runs, a new
  peer sits in `Net._pending` until `request_join` brings its uid (10 s, else `no_identity`); a uid not on the
  roster is refused `match_in_progress`, and a loaded save's lobby refuses uids not in `Game.season_uids`
  (`not_in_season`; empty = new game, the save task fills it). A roster player back in a running match is
  admitted with `players[id].rejoin = true`; `Death` sees it on `player_joined` and calls
  `die(id, &"reconnect")` (ghost at once, no debt billed; the dawn respawn returns the farmer). A same-uid peer
  still on the host (a crash not yet timed out) is replaced by the new connection. The refused client reads
  `Net.refusal` on the main menu. `Rejoin` (`game/core/rejoin.gd`) keeps `last_session.cfg` (written at match
  start, cleared by Leave or a `match_in_progress` refusal; match end has no hook yet) and the
  `rejoin_bag.cfg` shuffle bag for `data/rejoin_lines.json` (all lines before a repeat, a new round never
  opens on the last line shown); the rejoiner sees one line in `RejoinToast` (event `rejoin_line`). The main
  menu offers "Rejoin your last match?" from `last_session.cfg`. `JoinCode` (`game/net/join_code.gd`)
  encodes and decodes doc 06 s4 codes; the Join field takes a code or an IP (`IP:port`); the lobby roster and
  the pause menu show `Net.join_code()` (host: best local IPv4, Tailscale first). Not built: the "Waiting
  for a farmhand" dawn pause for a lone survivor (no dawn save exists), roles and slots (kept by uid).
- **Voice setting on the wire.** `Game.set_voice_setting` saves locally and sends `request_voice_setting`
  (`unchosen` is sent as `off`); the host accepts `off` and `lobby_lines`, refuses `live_clips`, logs
  `voice_setting`, and broadcasts `apply_voice_setting(peer, setting)` (the peer id, not a slot: slots are
  not built). A joiner sends its setting after `apply_session_state` and the host tells it everyone's.
  "Record lines" is offered to unchosen players and to Lobby-lines players with no lines recorded,
  "Re-record" once `lines_recorded`, and never to a player who chose Off. The button emits
  `Game.recording_requested`; the recording screen is P2-03's.
- **Build id.** `Game.build_id()` returns `res://build_id.txt` if present (the packager writes it for
  the export only, from `git describe --always --dirty`; the export preset includes it), else
  `application/config/version` (`dev`). `session_start` logs it as `build_id` and the data hash as
  `data_hash` (Q-047).
- **Debug arguments:** `--menu` (menu even headless), `--lobby` (host through the lobby),
  `--lobby-start=<n>` (host starts the match when n players are in, ready or not), `--lobby-ready` (a
  client presses Ready after 1 s; the host presses Start once a teammate is in and all are ready),
  `--role=<id>` (picks a role 1 s into the lobby), `--menu-open=settings`,
  `--settings-tab=<0..3>`, `--pause-open`, `--ui-shot=<png>` (saves the window after 90 frames and quits).
- **Difficulty and group options** are chosen in the lobby by the host and saved in the season
  (`Easy`, `Normal`, `Hard`, `Nightmare`, `difficulty.json`; "no live clips" and "streamer-safe" are
  flags; doc 01 "Difficulty and group settings"). They go in the save (section 17); the voice
  setting does not.
- **No HUD markers.** There is no objective marker, no player name tag over a head, no
  health bar. The one exception is the CEO-requested minimap (P4-24, D-094, `game/ui/minimap.gd`,
  a child of the HUD): a north-up farm map in the top right, read from the level's nodes when the HUD
  is built (`Ground/Floor`, `Buildings/*`, `Regions/field_*` and `corn_*`, groups `plot_spots`,
  `well`, `store_crate`, `sell_box`, `cart`), with the local player's arrow and every placed flag as a small red pennant (P4-33). It never reads the `creature` group,
  and nothing on it marks a teammate (D-141), a trap, a noise or a whistle. Information is diegetic (doc 01 "Diegetic"): the pegboard shows what tools are out, the
  flag shows a trap, a wrinkled leaf shows a thirsty crop, the generator hums lower. Exception (D-091): the
  P4-22 hotbar lists what the local player holds, with a use hint; it points at nothing.
- **Accessibility** (inference, unscoped in doc 01): there are no voice subtitles at all (D-019): a
  missing speaker name on a creature fake would expose it and defeat the "wrong place" tell. A
  colour-blind option for the Corruption visual. Settled by the CEO if it matters.

## 17. Save at dawn

Doc 01 "Saving": the host saves at every dawn, the save is portable, and any player from the season
can host it. Never voice.

- **When:** at the end of the dawn pipeline (doc 02 section 9: after farm damage; before the free
  scrap and flare refill, which are part of the next day's start, so a reload does not duplicate
  them). The host writes `<user dir>/saves/<season_id>/dawn_<NN>.json` (day number `NN`), keeping the last
  three plus `latest.json` copy (`placeholder`), then sends it to all clients (`apply_dawn_save`
  chunks on channel 3, doc 06 section 5) which store the same under `<user dir>/saves/<season_id>/`.
- **Format:** JSON, `{"schema_version": 1, "game_build": ..., "season_id": ..., "saved_at": ..., "state": {...}}`.
  JSON (not a `Resource`) so a `Resource` can never drag a clip or script into the file (doc 06
  section 11 forbids voice in the save), and so QA and the simulator can read it. Written to a temp
  file then renamed (an atomic replace), so a crash mid-save keeps the old save.
- **What is saved:**
  - Season: `season_id`, day number, season length (default 3 days short season, doc 01), difficulty,
    group options (`no_live_clips`, `streamer_safe`), roles assigned to `player_uid` (not peer id).
  - Bank: coins, debt, payments made and due, headcount history per day (for the joining and leaving
    debt formula, doc 02 section 7), foreclosure state (doc 01 "Foreclosure").
  - Farm: every plot (`crop_id`, `age_days`, `watered_days`, `state`), the Prize Pumpkin (size
    counters), upgrades bought, scarecrows and fences placed (position, yaw, health), store items
    owned and their stock, the pegboard contents, trap spots with traps set or disarmed, flags,
    generator fuel and repaired state, doors, animals' pen state.
  - Players: per `player_uid`: coins carried are 0 at dawn (inference: the cash-in empties the bag),
    inventory, tools, whether they are a farmhand that does not count, absences.
  - Creature: body id and the season's traits (doc 03 section 2), the AI Director's cross-day state
    (day arc, ramp-up row, trap pool), sabotage disturbance budget carried over. Exact fields belong to
    the AI Programmer; this doc requires them to be serialisable plain data (Q-019).
- **What is never saved:** voice lines, clips, chatter, the voice setting, voice settings of any
  kind, settings, logs, the recording state, network ids (peer ids and slots), the Noise memory and
  anything audio. A dawn save is checked by QA's checklist for any `voice`, `clip`, `lobby` key
  (doc 09).
- **As built (P4-10, `game/core/save.gd`):** the folder is `Net.user_dir() + "saves/<season_id>/"`
  (per profile, so two instances on one machine do not share saves). Saves are written only when the
  match started from a lobby or `--save` is passed. The dawn pipeline (`Death.step_save`) calls
  `Save.write`. Nodes that own cross-day state join group `saveable` with `save_key`, `save_state()` and
  `load_state(d)`: their data goes under `state.extras[save_key]`. `Game` properties named in
  `Save.GAME_FLAGS` (`streamer_safe`, `no_live_clips`) are saved if they exist. The generator is found by
  group `generator_logic` (group `generator` is the world mesh). Per-player data is keyed by `player_uid`
  (store ownership, walkie battery, awards tally). Not saved, by inference: bags and inventory (the
  dawn cash-in empties bags), the animal pen (animals return at dawn), the Corruption id. The final dawn's
  save is marked `over` and is not loadable. `--load=<season_id|path>` hosts a save from the command line.
  The Load Season list in the main menu shows saves of this profile; a uid not in the save is refused
  with "You were not in that season.". Roles lock once a season has uids (`Game.season_uids`).
- **Host left:** a client gets `net_host_left` (`quit` from `apply_host_leaving`, else `timeout`) and the
  pause menu shows the card. Everyone who was in the season has the latest dawn save.
- **Waiting card:** at a dawn with a 2+ player roster but fewer than 2 humans, `WaitingCard` stops
  the `Clock` and shows "Waiting for a farmhand" until another human joins. The debt re-scales on
  every join and leave (`Debt._headcount_changed`).
- **Loading:** the host picks a season from the local `saves/` folder (the player who hosts need not
  be the original host: the save came to them at every dawn). On loading it creates the session with
  a new `session_id` and keeps the old `season_id`. The "host left" card (doc 06 section 5) leads back
  to the menu, from which Load Season is one click. **Players who were in the save but are absent**
  are farmhands that do not count (doc 01 "Joining and leaving"); a player rejoining takes theirs by
  `player_uid`.
- **Cheating:** a client could edit its copy to host a different state. Co-op among friends; doc 01
  asks for no cheat resistance (inference, same as doc 06 section 6).
- **Versioning:** a save from another `schema_version` is refused with a message; no migration in
  DD Phase 1 (`placeholder`).

## 18. Log events

CONTRACTS section 10 format, one JSON object per line:
`{"t", "day", "phase", "peer", "event", "data": {}}` in `user://logs/<session_id>/peer_<id>.jsonl`.
`t` is seconds since session start. The **host's file is authoritative** for gameplay events:
host-only events are written only by the host. A client writes only events about itself (its
network and voice events; doc 06 section 14 lists them).

- `session_id` is `YYYYMMDD_HHMMSS_<4 hex digits>`, made by the host and sent to clients in
  `session_state`. Only `[A-Za-z0-9_]` is accepted (Q-013 item 2), so it is a safe folder name.
- `Log.event(name: StringName, data: Dictionary = {})` writes one line; the writer flushes each
  line (a crash loses nothing), buffers on a thread-free queue, and never throws. Players are named by
  **ENet peer id**, never by voice slot (D-012). Positions are `[x, y, z]` rounded to 0.1 m. Names and
  raw voice volume are never logged. The audio is never logged (doc 01).
- `peer` in the record is the peer that wrote the line. When an event is about a player and the host
  writes it, the player id goes in `data.player`; QA's checker already uses `data.player` for
  `trap_race_result` and `inside_at_night` and falls back to `peer`.

### Events the doc 01 measures need (the minimum in CONTRACTS section 10)

| Event | Written by | `data` fields | Doc 01 measure |
|---|---|---|---|
| `hold_completed` | host | `player`, `verb`, `seconds` (actual hold length), `target` (id), `helped` (bool), `mult` (the product of multipliers) | "hold and chore times" |
| `hold_cancelled` | host | `player`, `verb`, `seconds`, `reason` | chore times |
| `hold_refused` | host | `player`, `verb`, `reason` | bug finding |
| `chore_summary` | host, at each dawn | `player`, `seconds_holding`, `seconds_walking`, `seconds_idle`, `by_verb` ({verb: seconds}) | "chore times" (an addition to cover per-day totals; inference that doc 01's "hold and chore times" means both single holds and per-day totals) |
| `lure_played` | host | `lure_id`, `owner` (peer id or null), `line_id` (or null), `sound_id` (or null), `target` (peer id or null), `position`, `tell`, `ghost` (D-012) | lure success |
| `lure_result` | host | `lure_id`, `target`, `moved_m`, `within_s`, `window_s`, `worked` | lure success (see below) |
| `trap_sprung` | host | `trap_id`, `kind`, `player`, `position`, `deep` (bool) | "sprung traps" |
| `trap_race_result` | host | `player`, `trap_id`, `solo`, `tainted`, `pried_at_once`, `survived`, `seconds_spare`, `start_distance_m`, `pry_s`, `credit_ms` | trap race |
| `death` | host | `player`, `cause` (`trap_race`, `deep_corn`, `night_chase`, `night_trap`, `harvest_moon`), `position`, `phase`, `body_id` | "deaths" |
| `money_changed` | host | `reason`, `delta`, `balance`, `player` (or null), `item` | "money" and the simulator `compare` |
| `inside_at_night` | host, once per player per night | `player`, `seconds` | "time spent inside at night" |
| `spatial_audio_trial` | the tester's client (the machine under test) | see below | spatial audio test |

**`lure_result` (answers Q-002 item 1).** `within_s` is the **actual seconds taken**, not the window.
The host watches the target for the window (`window_s`, 8, doc 01 "Testing"). It measures `moved_m`
as the largest reduction of the target's distance to the lure `position` since the lure started. It
writes the event at the moment `moved_m` first exceeds 10 m (then `within_s` is the time of that
moment, and `worked` is true), or at the end of the window (then `within_s` is `window_s` and `worked`
is false). So `worked` = `moved_m > 10` and `within_s <= 8` exactly as the checker computes it, and
`within_s` is always a number. `moved_m` is the value at that moment, after that it stops counting.
Doc 01 "Testing": "A lure worked: the target moved more than 10 m toward the source within 8 seconds."
CONTRACTS section 10's example shows `within_s: 8` with `worked: true`, which this reading allows (a
target who reached 10 m exactly at 8 s). Fix needed in CONTRACTS section 10's example? None; it
remains valid.

**`spatial_audio_trial` (answers Q-002 item 2).** Fields: `sound` (`voice` or `whistle`),
`distance_m` (10, 30 or 60 for the doc 01 test), `correct` (bool, the tester picked the right
marker), `angle_error_deg` (number, the angle between the true direction and the tester's guess,
0 to 180), `marker` (the `spatial_audio_markers` id), `guessed_marker` (id), `listener` (peer id).
`correct`, `sound` and `distance_m` are the names `tools/qa/check_logs.py` already uses, so **no
change to the checker is needed**; `angle_error_deg` is extra and can be tallied later.
Written by the machine that runs the test (a client), so it is the one case where a client writes a
gameplay measure; the checker must read it from that client's file or the host's. See section 24 for
the QA changes.

### The rest of the event list

| Event | Written by | `data` fields | Why |
|---|---|---|---|
| `session_start` / `session_end` | host | `session_id`, `build_id`, `players` (peer ids), `season_id`, `difficulty`, `phase1` (bool), `bots` (count) | Context |
| `day_start` / `phase_changed` | host | `day`, `phase` | Time axis |
| `close_call` | host | `call_id`, `victim`, `kind` (`lunge`, `kill`, `doorway`), `result` (`hit`, `miss_disagree`, `miss_lit`, `miss_timeout`), `rtt_ms`, `answer_ms` | OPEN_ISSUES 1: a laggy player must be killable. `miss_timeout` vs `miss_disagree` per player RTT is the number that settles it |
| `taint_changed` | host, and the Corrupted client | `player`, `on`, `cause` (a `taint.json` cause, or `well`, `dawn`, `death`, `dev`) | Corruption rules |
| `shaken` | host, and the Shaken client | `player`, `seconds` | Trap race outcome |
| `taint_source` | host | `id`, `kind` (`leavings`, `dead_crow`, `strange_seeds`), `on`, `pos` [x, z] | Corruption sources placed and removed (P3-07) |
| `can_tainted` | host | `can`, `cause` (`stolen_tool`, `field_item_at_dusk`) | A can that Corrupts its next taker (P3-07) |
| `trap_changed` | host | `trap_id`, `state` (`set`, `sprung`, `disarmed`, `filled`, `cut`, `loose`, `picked_up`), `by` | Trap use |
| `trap_plan` | host | `day`, `players`, `plan` (kinds), `supply` (stolen bear traps in hand after nightfall theft), `armed` | Night trap count and bear supply (D-053) |
| `trap_stolen` | host | `trap` (`held:<peer>` or `board:<slot>`), `from` (`board`, `outdoor`, `dark_building`), `lock`, `day`, `supply`, `player` (hands only) | Pegboard theft (D-053) |
| `trap_theft_capped` | host | `cap`, `day` | Shed lock (D-053) |
| `trap_skipped` | host | `kind`, `reason` (`no_supply`, `no_spot`) | Bear supply ran out (D-053) |
| `trap_moved` | host | `trap`, `from_building`, `to_spot`, `player` | Lit-building trap to the corn at dawn (D-053) |
| `flag_placed` / `flag_removed` | host | `player`, `position`, `trap_id` (or null), `flags` (all out), `mine` (the owner's); `flag_removed` adds `owner` | Flags; `flag_removed` is any player pulling one up (`player` pulled it, `owner` placed it; P4-33, D-142) |
| `flags_dropped` | host | `player`, `count` | A leaver's flags go with them (D-142) |
| `payment_made` | host | `amount`, `balance`, `due`, `late` | Debt |
| `dawn_summary` | host | `day`, `coins`, `debt`, `plots_ripe`, `plots_wilted`, `farm_damage`, `deaths` (+ `medical_bill`, `final_extra`; P2-06) | Simulator `compare` (reads `money_changed` by dawn too) |
| `generator` | host | `state` (`fuelled`, `dead`, `repaired`), `fuel_s` | Generator run |
| `door` | host | `door_id`, `open`, `by` | Light rule |
| `creature_state` | host | `from`, `to`, `reason`, `position`, `target` (peer id or null) | Pacing; mirrors `apply_creature_state` (AI Programmer writes it) |
| `noise_emitted` | host, debug runs only | `kind`, `radius_m`, `position`, `source_peer` | Debug; off by default. Never a voice volume |
| `chase_started` / `chase_ended` | host | `target`, `how` (`lost`, `lit_building`, `kill`, `retreat`) | Pacing |
| `sabotage` | host | `kind`, `position` | Disturbance pool |
| `tension` | host, every 10 s | `value` (0 to 100), `phase`, `profile` (P3-04) | AI Director |
| `daily_roll` | host, at start and each dawn (for the next day) | `day`, `deep_m`, `earshot_m`, `trap_race_m`, `deep_trap_race_m` | AI Director (doc 03 section 11.8) |
| `nudge` | host | `from`, `to`, `toward` (region names) | AI Director region-only nudge (doc 03 section 11.8) |
| `scare` | host, when a scare lands (after its build-up) | `kind`, `target` (-1 public), `big`, `private`, `day`, `third`, `position`, `extra` (clip source or null), `hold` (disarmed trap or null) | Scares (doc 03 section 13.1, P3-05) |
| `scare_dropped` | host, when a scare's build-up ends and its rules no longer hold | `kind`, `target`, `why` (a `fits` reason or `director`) | Scares (doc 03 section 13.1) |
| `scare_applied` | client, when it plays a scare sent to it | `kind` | Scares sync check |
| `dawn_report_shown` | each peer, when the Dawn Report card opens | `day`, `sections` (ids in order), `replays` (count), `streamer_safe` | Dawn Report (section 15, P3-12) |
| `speed_violation` | host | `player`, `speed_mps`, `max_mps`, `clamped` | Doc 06 section 6 |
| `data_mismatch` | host | `peer`, `table` | Section 4 |
| `net_*`, `voice_stats` | each peer | doc 06 section 14 (including `net_join_code_rejected` with `reason` `typo` or `length`) | Network |
| `settings_changed` | each peer | `key` (never a voice file path) | Debugging |
| `save_written` | host | `path_name` (file name only), `day`, `bytes` | Save |
| `save_received` | client | `path_name`, `day`, `bytes` | Save (P4-10) |
| `save_refused` | any | `reason` (`not_json`, `schema`, `shape`) | Save (P4-10) |
| `save_loaded` | host | `season_id`, `day`, `coins`, `debt_paid`, `players` | Save (P4-10) |
| `creature_body` | host and each peer | `body`, `forced` (`save` when a loaded save sets it), `seed` | Save, Creature |
| `net_peer_left` | host | `peer`, `how` | Joining and leaving (P4-10) |
| `net_host_left` | client | `how` (`quit`, `timeout`) | Host left (P4-10) |
| `session_end` | each peer | `how` | Joining and leaving (P4-10) |
| `waiting_for_farmhand` / `farmhand_returned` | host | `day` | Waiting card (P4-10) |
| `debt_rescaled` | host | `players`, `owed`, `pct` | Joining and leaving (P4-10) |
| `audio_state` | `Soundscape` on every peer, through `Log`, on each creature-state change and every 5 s while the state is not `lurk` | `creature_state`, `body`, `bed_db`, `wind_db`, `last_sounds` (last 8 sound IDs) | Clients report Stalk layer drops; F3 is host-only (Q-035, CONTRACTS section 10) |
| `audio_play` | `Soundscape`, on the peer that hears it, each one-shot except footsteps | `id` (sound ID) | CONTRACTS section 10 (Q-073, D-076); QA sound checks |
| `audio_hush` | `Soundscape`, on the hearing peer | `seconds` | Same |
| `audio_taint_heartbeat` | `Soundscape`, on the hearing peer, when the heartbeat starts or stops | `on` | Same |
| `audio_chase_cue` | `Soundscape`, on every peer, when the creature state turns `chase` | `body` | Same |
| `sell` | host, a sell-box hold completes | `player`, `items`, `coins` (per-crop price from `crops.json`) | Selling (P4-04) |
| `harvest` | host | `player`, `plot`, `crop` | Crop checks (P4-04) |
| `seed_picked` | client, on `cycle_seed` | `crop` | Seed choice is client-local; it rides in the `plant:<crop>` verb (P4-04) |
| `dawn_step` | host, before each step of `Death.dawn()` | `step` (`cash_in`, `final_sale`, `medical_bill`, `payment`, `farm_damage`, `save`, `free_scrap`), `day` | Doc 02 section 9 order test (P4-04) |
| `end_of_season_sale` | host, final dawn step 2 | `plots`, `coins` | Dawn Report ledger row (P4-04) |
| `free_scrap` | host, dawn step 7 | `scrap` | Doc 02 section 9 step 7 (P4-04) |
| `store_buy` | host | `item`, `price`, `buyer`, `day`, `coins`, `flare` (shots after the buy); seeds: `item` `seed_<crop>`, `count`, `price` the total | Doc 02 section 10 (P4-06, D-093) |
| `store_refused` | host | `item`, `buyer`, `reason` | P4-06 |
| `store_picked` | local peer | `item`, `price` | P4-06 |
| `store_menu` | local peer, on opening the crate's menu | `open` | P4-22 |
| `store_seized` | host | `item` | Foreclosure (P4-07) |
| `scrap_used` | host | `left` | P4-06 |
| `flare_fired` | host | `player`, `hit`, `left` | P4-06 |
| `flare_reloaded` | host, dawn step 7 when the reload added shots | `before`, `shots` | Dawn Report "Flare Gun" line (D-147, P4-38) |
| `scarecrow_placed` | host | `player`, `position`, `avoid_m` | P4-06 |
| `season_ended` | each peer (host from the clock, clients from the final Dawn Report) | `day` | Season Awards entry point (P4-04) |
| `pumpkin_planted`, `pumpkin_watered`, `pumpkin_lifted`, `pumpkin_set_down` | host, Prize Pumpkin verbs | `player`, `day` / `watered_days`, `size` / `pos` | P4-05 |
| `pumpkin_night` | host, dawn | `day`, `guard_max_s`, `guard_total_s`, `guarded`, `guarded_nights` | Guard rule, doc 02 s6 (P4-05) |
| `pumpkin_gnaw`, `pumpkin_bite` | host, P4-11 / P4-12 call `gnaw()` / `bite()` | `day`, `size`, `drops`, `guard_max_s`, `guard_total_s`, `repair_s` (0, no fix) | D-083 guard-charge data (P4-05) |
| `pumpkin_judged` | host, when the loaded cart goes out (P4-12); at `step_final_sale` only on the Phase 1 farm (no cart) | `size`, `watered_days`, `guarded_nights`, `drops`, `bites`, `payout`, `players` | Doc 02 s6 (P4-05) |
| `cart_act` | host | `act` (1 loading, 2 push, 3 gate run) | Doc 03 s14 acts (P4-12) |
| `cart_loaded` | host | `player`, `size` | P4-12 |
| `cart_knock` | host | `player`, `x`, `stall_s` | Knock-off cooldown and stall (P4-12) |
| `cart_finished` | host | `reason` (`gate`, `cap`, `all_dead`), `x`, `offset_m`, `loaded`, `cart_out`, `bites` | P4-12 |
| `cart_out` | host, with `cart_finished` when out | `alive`, `loaded` | Win condition (Q-130); P4-15 |
| `cart_seen` | client, on `apply_cart` when the act changes | `act`, `offset_m`, `pushers`, `cart_out` | Replication check (P4-12) |
| `pumpkin_seen` | client, on `apply_prize` | `size`, `watered_days`, `drops`, `judged` | Replication check (P4-05) |
| `dawn_report_closed` | each peer, `DawnReport._close()` | `day` | `Soundscape` ends the report bed on it (D-081 item 2) |
| `ghost_action` | host | `kind` (`flicker`, `crow`, `rustle`, `caw`), `peer`, plus `light_id` (flicker), `crow_id` (crow, caw) or `position` `[x, z]` (rustle). As built in P3-09; replaces the proposed `ghost_flicker` row and the `player`/`action`/`target` fields. P3-10 adds `kind` `static_voice` (a ghost starts a talk spurt; `peer` only) | Doc 01 Phase 3 "the dead stay engaged"; QA flicker checks (Q-037); `check_logs.py` tallies it by kind |
| `ghost_action_refused` | host | `kind`, `peer`, `reason` (`not_ghost`, `cooldown`, `no_light`, `unlit`, `too_far`, `no_living_near`, `not_in_corn`, `used_tonight`, `no_perch`, `taken`, `no_crow`) | QA: non-ghosts and blown-out lanterns refused (P3-09) |
| `ghost_action_seen` | client, when it applies a ghost result | `what` (`ghost_light`, `ghost_sound`, `crow_possessed`), `args`, `played` | Every peer sees the flicker (P3-09) |
| `ghost_vision` | client, `--ghost-auto` QA runs only | `traps_shown`, `creature_seen`, `creature_m` | Ghosts never see traps; creature within 20 m (P3-09) |
| `lure_fooled` | host, when a recorded-line lure has `lure_result.worked` | `lure_id`, `target`, `line_id` | Doc 01 Phase 2 voice lure check (Q-037) |
| `perf_sample` | each peer, debug runs only (`--debug-view` or `--bots`) | `avg_ms`, `max_ms`, `draw_calls`, `adapter` (`RenderingServer.get_video_adapter_name()`) | Doc 07 section 10.3 four-instance corn profile (Q-037) |
| `whistle` | host, on an accepted whistle | `player`, `position` (`[x, z]`), `cooldown_s` | Doc 01 "Whistle"; P3-11 cooldown check |
| `emote` | host, on an accepted emote | `player`, `emote` (any id in `data/emotes.json`), `position` (`[x, z]`) | Doc 01 "Emotes"; P3-11 rate-limit check. Refusals of both are `hold_refused` with `verb` `whistle` or `emote` and `reason` `cooldown`, `rate_limit`, `unknown_emote`, `ghost` or `no_player` |
| `dev_toy` | host, when a dev toy starts (P5-10) | `toy` (`shrink`, `disco`, `nuke`, `low_gravity`, `big_heads`, `confetti`, `chicken`), `seconds` (0 = until dawn), `player`, `target` (nuke only, peer id or 0), plus `nuke_hit {peer, dist_m, throw_m}` per player hit (host) and `nuke_land {peer, from, to, moved_m}` (each peer, for its own player) | Doc 01 "Dev toys": a session that used a toy is not a play session. `check_logs.py` drops the session from every measure and lists it (`dev_toy_sessions`). Section 25 |
| `imposter_picked` | host only, at match start (and each next season) | `season`, `roster_id` (profile uid), `forced` | Doc 02 s22.1. Only the host's own log has it; no client ever logs or receives it. Section 26 |
| `group_settings_imposter` | host, when the lobby toggle changes | `enabled` | Doc 01 "Imposter mode" (default off, D-158). Public setting. Section 26 |
| `imposter_action` | host only, when a kit action succeeds | `kind` (`whistle_throw`, `gate_prop`), `position` | Doc 02 s22.1. Host log only. Section 26 |

The event names and fields in the first table are final; the second table is a proposal
(`placeholder`) and adding an event never needs the Director (CONTRACTS section 10 asks only that
the minimum events exist), but renaming a minimum one does.

Event frequency stays low: nothing in the per-frame path logs. The largest file is the `tension` and
`noise_emitted` lines in debug runs.

## 19. The debug top-down view

Doc 01 "Testing": "a debug top-down view (creature, state, sensed vs true positions, tension meter,
traps, players)". Code in `game/debug/`. It is a development tool; it is excluded from export
presets for release (inference: settled by the Director when a release preset exists).

- **Toggle:** `toggle_debug_view` (F3) or `--debug-view`; **host machine only** by default, because
  it shows secrets. A client gets it only with `--debug-view` plus the host's `--debug-share`
  (`placeholder`), which sends the host's `apply_debug_state` snapshot on a debug channel message
  (not in doc 06's list: an addition to the D-010 list for development only, Q-019 to the Director).
  The release build ships without the share message handler.
- **Camera:** an orthographic `Camera3D` looking down at the level, pan with the mouse, zoom with the
  wheel, drawn on a `SubViewport` in a `CanvasLayer` that sits above the game view (shown as a window
  overlay in the corner or a full-screen toggle). It draws with `ImmediateMesh`/`Label3D` primitives
  in debug layer 20 so the game camera never sees them.
- **Draws:**
  - **Players:** a circle and name per peer, facing arrow, crouch/still/sprint colour, Corruption and
    Shaken rings, inside-lit-building marker. Ghosts as dim circles.
  - **Creature, true position:** a red filled circle at the creature's real position, with its state
    (`lurk`, `lure`, `stalk`, `chase`, `retreat`), body id, timers, and its current target peer.
  - **Creature, sensed positions:** the AI's belief of where each player is (what the creature
    "thinks"): a hollow circle per player at the position the creature last sensed, with age in
    seconds and a line to the true position, so the gap between sensed and true is visible. The
    AI Programmer exposes `Creature.debug_sensed() -> Array[Dictionary]` (`{peer, position, age_s,
    source_kind}`) and `Creature.debug_state() -> Dictionary` (`state`, `body`, `timers`,
    `target`, `noise_memory` (list of `{position, radius, kind, age_s}`), plus true `position`,
    `region`, `wander_region`). `source_kind` is `heard`, `seen`, `taint` or `trail`. Accessors return
    copies; the view finds the nodes by group `creature` and `ai_director` (host only). Without these
    the debug view can show only true positions (AI Programmer, Q-019, D-021).
  - **Noise:** each `noise_emitted` as an expanding ring at the position, radius to scale, coloured
    by `kind`, fading in 2 s.
  - **Hearing and sight radii** of the creature on demand (hold H).
  - **Tension meter** (AI Director, 0 to 100) as a bar and a rolling graph, plus the current phase
    profile and the next scare timer. `AiDirector.debug_state()` returns `tension`, `phase` (`build_up`, `peak`, `fade`, `relax`),
    `profile`, `phase_time_s`, `next_scare_s`, `nudge_region`, `nudge_cooldown_s`, `budget_left`
    (disturbance points) and `scares` (`{peer: {big_today, last_big_s}}`).
  - **Traps:** every trap spot from `trap_spots`, its trap kind, set/sprung state, and flags. Spots
    never used are grey.
  - **World:** the region graph (doc 03 section 11.6) as coloured polygons, the cart route polyline
    (R0 to R8), the town stand circle, the lit-building radii, the light registry (lit/unlit),
    the generator fuel, plots with water state.
  - **Lures:** active lures as a line from the creature to the lure position with `lure_id` and the
    seconds left in the 8 s window, and the target's moved metres so far.
- **Data source:** the host reads the live nodes directly; no extra messages. The view is a pure
  reader: it never changes state (a debug "teleport creature" command lives behind `--cheats`).
- **Bots** (doc 01 "Testing > Bots"): a bot is a `Player` driven by a script instead of input,
  connected through the same `request_*` path (so it can be killed and a trap race can happen to it).
  Implemented by the AI Programmer in `game/bots/` against the `HoldController` API of section 7;
  the debug view shows a bot as a player with a tag.

## 20. DD Phase 1 build order

Doc 01 "Build Plan > Phase 1": first voice between two machines; then one small field, shed, barn;
one day and one night, 2 players, proximity chat; turnips plant/water/sell with hold times logged;
noisy watering can; one generator run; crouch and go-still; three ambience layers from scripted
creature state (Lurk, Stalk, Chase); creature wandering and chasing by sound; scripted traps and
pits, generic voice lines from the corn; the spatial audio test; no AI Director. "Done when day feels
safe, night tense, at least 30% of lures make the target walk toward them." The subset of this doc
that DD Phase 1 builds, in order (each step is playable on its own with 2 instances):

1. **Core:** `Log`, `Data` (with `labor` and `crops` at least; the Game Designer supplies the
   files), `Settings`, `Clock`, `Game`, `project.godot` entries, `boot.tscn` to `main.tscn`. Smoke
   test: two instances join each other's session over ENet from the command line (the `Net` side is
   Network & Voice's).
2. **Player controller:** movement, camera, crouch, sprint, the `move`/`moves` stream, remote proxies,
   host speed check, `NoiseBus.emit_kind` from steps. The Phase 1 gray box from the Level Designer
   (doc 04 section 9).
3. **Hold framework and farming:** `HoldController`, `HoldRegistry`, `Interactable`, `plant`, `water`
   (the noisy can), `harvest`, `sell` at the (40, 20) box, `hold_completed` logged. Turnips only.
4. **Noise** wired to the AI Programmer's `noise_emitted` consumer and the voice reports.
5. **Generator and lights:** one generator, fuel drum, refuel, repair, dimming. No flicker anywhere.
6. **Go-still** (the host's ring) and crouch noise.
7. **Scripted creature support:** the host-side `Creature` shell is the AI Programmer's; this doc
   supplies Corruption-free player state (Corruption off in Phase 1 per doc 03 "fake it first"), the scripted
   trap spots 01 to 06, 15, 16, 19, 22 as the sprung traps with `trap_sprung` and the trap race
   (`request_pry`, `trap_race_result`), death, ghosts (spectate only), and `apply_creature_state`
   ambience hooks (the Audio Designer plays the three layers from the state).
8. **Spatial audio test scene:** a test scene using `spatial_audio_markers` (doc 04 section 8):
   10, 30, 60 m markers for a voice and a whistle, a headphone prompt, the tester picks the marker
   they hear, and `spatial_audio_trial` is logged. The sound source is the Network & Voice
   `VoiceEmitter` (voice) and the Audio Designer's whistle through the same emitter.
9. **Debug view** (section 19), with only true positions until the creature exposes `debug_sensed`.
10. **Bots and the log check**: a bot that walks and does chores (the AI Programmer), and a
    `check_logs.py` run on the 2-player session.

Left for later phases: Corruption and washing (Phase 2 or 3 per doc 01), roles, the store beyond turnips,
the cart, Dawn Report, Season Awards, saves (Phase 2: the first full season), emotes, whistle
polish, carrying teammates, flags and pegboard. Their message names are reserved in doc 06 section
7 so they add no transport work.

### 20.1 Cosmetics (P5-05, doc 02 section 21.5, doc 07 section 8)

- **Autoload `Cosmetics`** (`game/items/cosmetics.gd`). Rows are `data/cosmetics.json` records of kind `hat` or
  `overalls`. Ownership is kept by player uid (`Save.uid_of`), so it survives a rejoin, a new peer id and the
  next season (the autoload outlives a `Main`). No gameplay code reads it.
- **Flow:** client `Net.request_cosmetic(op, id, slot)` (`buy`, `wear`, `sync`; `wear` with an empty id takes the slot
  off) -> host validates (`why_not_buy`: `no_item`, `not_sold`, `ghost`, `owned`, `too_far`, `no_coins`) ->
  `farm.add_coins(-price, &"cosmetic", peer)` -> `Net.apply_cosmetics(table)` to all. The table is
  `{owned: {peer: [ids]}, worn: {peer: {slot: id}}}`; refusals go back as `apply_refused(&"cosmetic", why)`.
  Host logs `cosmetic_bought`, `cosmetic_worn`, `cosmetic_refused`.
- **Sold when** the mirrored `Debt` node says `not lost and paid > 0 and owed == 0`, and the buyer is within crate
  range (`store._too_far`) until `Clock.season_over`, when the Season's End card sells (the crate is out of reach then).
- **Save:** group `saveable`, extras key `cosmetics` (`{owned: {uid: [ids]}, worn: {uid: {slot: id}}}`); `Game.load_season`
  calls `load_state`. Unknown ids are dropped.
- **Looks:** `Cosmetics.make_hat(id)` loads `res://assets/models/char_hat_<id>.glb` (origin at the band bottom) else a
  primitive from `HAT_LOOK`; `tint(id)` reads the glb extra `tint` else `TINT_LOOK` (placeholders, the extras format is
  inference until P5-06 lands); `attach_overlay(skel, id)` re-parents `char_overalls_<name>.glb` meshes into a farmer
  Skeleton3D (the plaid, striped and patched patterns exist only as these skinned meshes; their `tint` is alpha 0).
- **UI:** `CosmeticsPanel` (`game/ui/cosmetics_panel.gd`) in the pause menu (lobby and match, wear only), the store menu
  and the Season's End card (buy and wear). `CosmeticDress` is `game/player/cosmetic_dress.gd`: a child of every
  non-local Player that calls `FarmerBody.wear_hat` (a `BoneAttachment3D` on the `hat` bone) and `FarmerBody.set_overalls(colour, id)`
  (frees the old overlay meshes, attaches the new; alpha 0 keeps the player colour, D-159); the lobby line-up swaps the role hat for the worn hat.
- **Test:** `tests/net/test_cosmetics.gd` (2 instances, ports 53750-53759).

## 21. Testing

- **2+ instances over ENet**, every feature: `uv run tools/qa/multi.py -n 2` (PP-03). The host's own
  player and a client take the same code path (section 2). A feature tested with one instance only
  is not done.
- **Headless:** the import must print no new `ERROR`/`SCRIPT ERROR`; `tools/qa/smoke.py` runs it.
- **Logs:** `uv run tools/qa/check_logs.py <folder>` reports the lure rate, the trap races, the
  spatial audio trials. Section 18 is built so that report is filled, not "none logged".
- **Simulated latency and loss:** `--net-sim-latency-ms`, `--net-sim-loss` (doc 06 section 14) with
  the close-call events (section 18) give the OPEN_ISSUES 1 data.
- **Unit-level checks** (`tests/gameplay/`, GDScript run by `--script`): `Data` rejects duplicate ids;
  `Data.scaled` reproduces doc 02 section 4's rounding; the hold rate maths with a helper; the
  stillness ring (0.19 m vs 0.21 m moved in 1 s); the `place_defense` cart-route clearance;
  `NoiseBus.emit_voice` radius at 159 and 255; the save contains no voice keys. These are written with
  the code, not in PP-07.

## 22. Gotchas

None are measured yet (no code exists); these come from Godot facts or other docs, and are marked
accordingly.

- **Do not call `rpc()` outside `Net`.** The latency and loss simulation can only delay what goes
  through the wrapper (doc 06 section 14). A direct call also bypasses `apply_*` naming.
- **Autoload order is a dependency order.** `Data` before anything that reads it; `Log` first so
  every other autoload can log. Reordering them in the editor breaks startup silently.
- **A client calling `NoiseBus.emit` is a bug.** It is a no-op with a warning, and QA greps for it.
- **Stillness must come from transforms, not from a client flag.** A client flag lets a hacked client
  hide; also a flag is wrong on packet loss. (Reasoning, not measured.)
- **Never branch on peer id for the host.** Use `Game.is_host()` or `multiplayer.is_server()`; a
  singleplayer-shaped branch is what makes features "work only on the host".
- **`Dictionary` ordering and JSON:** Godot's `JSON.stringify` writes keys in insertion order unless
  `sort_keys` is set; save files use `sort_keys = true` so diffs and the Python reader agree.
- **Integer ids as JSON keys:** JSON object keys are strings, so `peer ids` as keys come back as
  strings; the save and the report convert on load.
- **Float rounding in `ceil(v * pct / 100)`:** `ceil(0.8 * 15)` can give 13 in floats (12.000000000000002
  rounds up). Use integer math (section 4).
- **`Timer` nodes drift with frame time in headless runs;** the hold and Clock timers use accumulated
  `delta`, not `Timer`, so `--quit-after` runs and the simulation agree.
- **TwoVoIP first headless import crash** (doc 06 section 15): new scenes must not be the cause of
  the import crash QA sees; run the import twice before suspecting your change.
- **Windows paths in `user://`:** `user://` is (custom user dir name kept after the P5-37 rename) `%APPDATA%\Godot\app_userdata\Brenny Brenn Boy Horror`
  (QA's print_user_dir, PP-03); logs of 4 instances on one PC share it, so the file is
  `peer_<id>.jsonl` under one session folder (distinct peer ids, no clash). Two sessions in the same
  second would clash on `session_id`: hence the 4 hex digits.

## 23. Answers to open questions

| Item | Answer |
|---|---|
| **Q-002 (QA)** 1 | `lure_result.within_s` is the actual seconds taken; `window_s` (8) is added. Section 18 |
| **Q-002 (QA)** 2 | `spatial_audio_trial`: `sound`, `distance_m`, `correct`, plus `angle_error_deg`, `marker`, `guessed_marker`, `listener`. Section 18. Checker needs no change |
| **Q-016 (Game Designer)** | Movement speeds, `max_s`, `refill_s`, capacities read from `labor.json`; the player code owns the behavior. Sections 4 and 6 |
| **Q-014 item 6 (Level Designer)** | The host refuses `request_place_defense` closer than 3 m to the cart-route polyline; reason `blocks_cart_route`. Section 11 |
| **Q-006 (Network & Voice)** | `audio/driver/enable_input = true`; autoloads `Net` and `Voice` listed (section 3); `voice_push_to_talk` = V, `voice_radio` = B (section 3); a ghost's voice plays from the `Ghost` node's transform via `voice_anchor()` (section 14) |
| **Q-013 items (QA)** | `session_id` restricted to `[A-Za-z0-9_]` (section 18); `net_join_code_rejected` is in the event list (doc 06 section 14, section 18 here) |
| **Doc 06 "Noise interface signature and the save contents are doc 05's"** | Section 8 and section 17 |
| **Doc 02 "interaction-hold framework, saves, log events are doc 05's"** | Sections 7, 17 and 18 |
| **Doc 03 "debug view is doc 05 / AI Programmer"** | Section 19; the AI Programmer exposes `debug_sensed()` and `debug_state()` |

## 24. Questions raised

Raised in `production/QUESTIONS.md` (Q-019 onward):

1. **AI Programmer, Noise interface** (Q-019): confirm section 8's signature, `emit_kind` /
   `emit_voice` helpers and the `noise_emitted` signal; who applies the Corruption and quiet-can
   multipliers (proposed: `NoiseBus.emit_kind`); the kind list spelling; when tool noises fire (at
   completion, or also at hold start); emote scream as a `voice` 255 emission; the debug accessors
   (`debug_sensed`, `debug_state`); serialisable creature and AI Director save state.
2. **Director:** add the `NoiseBus` autoload to CONTRACTS section 4, the `apply_debug_state` development
   message to section 7, and record the Q-002, Q-006 and Q-016 answers; add the doc 05 index row in
   `docs/README.md` (Director's file).
3. **QA:** no change to `check_logs.py` is required; optionally tally `angle_error_deg`, `close_call`
   results, and update the "provisional" comments (Q-002).
4. **Level Designer:** a `cart_route` `Path3D` and `Marker3D` groups in the level scene (doc 04
   section 6.1), the Phase 1 gray box scene name.
5. **Network & Voice:** nothing new for the transport; the cart transform cadence and `Net.rtt_ms()`.

## Up to 6 players (P2-07, D-038)

- **Cap.** `Game.max_players()` reads `player_scaling.json` `max_players` (6). `Game.BASE_PLAYERS` (4) is the
  size the game is built around. `Net.host` opens `max_players` connections (one more than the clients allowed).
- **"Farm is full" (doc 06 s2).** When a peer connects and `Game.humans() >= max_players()` (bots do not count: a joining human drops a bot, below),
  the host logs `join_refused` (`peer`, `reason` `full`, `players`), sends `apply_join_refused(&"full")` to that
  peer only, and drops it 0.5 s later (an immediate drop beat the RPC). While it waits, `Net.to_peers` and
  `send_bytes` skip it (`_refused`) and its disconnect is not a `player_left`. The joiner prints the refusal,
  clears its peer, and goes to the main menu (headless: quits).
- **Spawn.** `Players._free_slot`: the lowest-use `player_spawns` index, so two players share a spot only when
  more players than spawns exist. Six barn spawns (doc 04 s13): x -3, -1, 1, 3 at z -8 and (-2, -11), (2, -11).
  Logged as `player_spawn_at` (`peer`, `slot`, `pos`).
- **Headcount scaling** has one reader: `Data.scaled(v, kind, players = 0)` reads `pct_by_players` for
  `Game.player_count()` (roster size incl. bots and ghosts; a count with no entry reads 100%). Bills use it
  (`death.gd`); the trap setter and disturbance budget call the same function (doc 02 s11).
- **`--bots=N`** adds `min(N, BASE_PLAYERS - roster size)` bots when `Main` loads (`bots.gd`): never past 4. A human joining while the roster (bots included) is past 4 makes `bots.gd` drop the newest bot (erase from `Game.players`, free its node, resend the roster, `player_left` with `bot:true, reason:"human_joined"`), so bots never push a match past the base count and never block a human.
  Bots joined later by real players are not counted. On `--full-farm` a bot spawns, streams and stands
  (`bot_route.gd` is Phase 1 only; `bot.gd` skips `_run`).
- **`net_bandwidth`** (`Net._process`, every 10 s, every peer): ENet host counters plus 28 B of UDP/IPv4
  header per datagram (PP-02 method). Headless, no microphone (no voice sent): 4 players host up 79 to 85
  kbps, down 32 to 36; client up 11.5, down 26 to 28. 6 players host up 163 to 178, down 49 to 58; client up
  11.5, down 36. Doc 06 s13's 4-talker figures (327 to 342 up) include voice; not exercised.
- **Lobby autostart** (`--lobby-start=n`) retries until `match_ready()`; before, a first refusal ended it.

## Field plots by headcount (P2-14, D-039)

- Under `--full-farm`, `farm.gd` locks every `upgrade` plot (bought later) and every `extra` plot (Level Designer metadata `extra`, `min_players` 5 or 6). `_set_headcount(n)` opens extras whose `min_players <= n`. The host calls it at `Farm._ready` with `Game.player_count()` (roster at match start; in the lobby flow the match scene loads after the host starts, so that is the lobby headcount). Clients get the number through `apply_headcount` in the `farm_state` reply, so every peer opens the same plots.
- A player joining after the match starts does not change the open plots (the headcount is fixed at match start; inference: the CEO's D-039 text says "start", it does not say plots appear mid-season). Settle by asking the Game Designer if mid-season joins should grow the field.
- Open plots at 2/3/4/5/6 players: 16 + 0/0/0/4/8 extras, matching `field_plots_start_by_players` (16/16/16/20/24).
- `Farm.plot_ceiling()` reads `field_plots_max_by_players` from `player_scaling.json` (24/24/24/28/32), not `season.json`. No store sells plots yet; whoever builds it reads this.
- Log: `plots_open {headcount, extras_open, ceiling}` on every peer. Debug: `--headcount=<n>` (host) overrides the count for no-lobby runs, where joiners arrive after the farm loads.

## 25. Dev gate and dev toys (P5-10)

Doc 01 "Hidden dev setting" and "Dev toys" (D-044, D-045, D-046). Code: `game/core/dev_gate.gd`, `game/debug/dev_toys.gd`, `game/debug/disco_rig.tscn`, `game/voice/squeaky.gd`.

**The gate (`DevGate`, reused by P5-11).** `DevGate.unlocked()` is true only when `OS.get_unique_id().sha256_text()` is in `DevGate.HASHES`. `--dev` and a debug build do not open it. Only hashes are stored, never a raw id. `HASHES` is empty until the CEO answers Q-261; the CEO prints their hash with `"$GODOT" --headless --path . -s res://game/core/print_machine_hash.gd | tail -1` and the Director pastes it in. The host's machine decides: every check runs on the host (peer 1).

- Test path: in a debug build only, `--dev-gate-test-hash=<hash>` (a user argument) adds one hash, and only if it equals this machine's own hash, so the real compare still runs. Tests pass the hash the print script gives for their own machine. Inference: someone who has the repo can print their own hash and use this argument, so the gate guards against accidents and stray `--dev` runs, not against a determined reader. A secret kept outside the repo would settle it.
- A closed gate makes `toy` answer like any unknown command (`? unknown command 'toy' (help)`), and `help` does not list it.

**Running a toy.** The dev console (backquote, host only) or `--dev-exec="toy disco"`: `toy shrink|disco|nuke [target]|low_gravity|big_heads|confetti|chicken`. `DevToys.run` (host) checks the gate, logs `dev_toy {toy, seconds, player, target}` (section 18), and sends `apply_dev_toy(toy, seconds, position)` through `Net.to_peers`, plus a local `Net.apply_received.emit` for the host. The RPC sits in `net.gd` like every other (doc 06 s14). Each peer then runs the toy on its own screen and Player nodes. `squeak` is the same message with a one-shot name (the rubber chicken). A peer that joins while a toy runs does not see it (inference: toys are short; settle by replaying the active list in the join snapshot).

**What never happens.** A toy calls nothing in `Farm`, `Save`, `Death`, `Debt` or the generator, so the save, coins, debt and deaths stay untouched. No light energy is assigned in `game/debug/` (doc 07 s4.4 rule 3; `tools/qa/grep_rules.py` passes): the disco beams are in `disco_rig.tscn` with a static energy, and the nuke's glow is a screen tint plus emissive cloud meshes. Nothing flashes: the disco turns the rig at 0.5 rad/s and drifts the hue at 0.4 rad/s; the nuke glow ramps over 5 s to alpha 0.30 (at most 0.09 per second) and falls over 6 s, warm orange, never white or red. Safe mode (`photosensitive_safe`, now in `Settings.DEFAULTS`, default false) hides the beams and the glow on that peer.

| Toy | Length | Effect |
|---|---|---|
| `shrink` | 60 s (doc 01) | Every player's `body_scale` 0.25 (height, camera eye, collider keep their ratio). `Squeaky` adds one `AudioEffectPitchShift` (1.7) to the `Voice` bus, which all voice buses feed, so live, dead and creature-replayed voices squeak. A bus effect, not `pitch_scale`, because a faster emitter drains its Opus buffer and underflows. |
| `disco` | 45 s (inference) | Mirror ball drops in over the host's player, generated music loop on the `Music` bus, four slow colour beams, every player dances (`Player.dance`), the creature gets a steady colour overlay (fully visible) and its parts bob and spin. |
| `nuke` | 14 s (inference) | `toy nuke [player name or peer id]` (dev menu: "nuke" and "nuke player"). The host picks the blast centre: the target's position, else the middle of `World/CornBlockers`, and sends it as `pos`, so no RPC change and every peer agrees. A flat-shaded low-poly mushroom cloud (`nuke_cloud.gdshader`: stem, rolling cap, puffs, base ring, warm-to-dark layers, world-space vertex billow, no light node) rises and spreads over 14 s, cools to smoke, then dissolves with a dither fade. A warm slow screen glow and a rumble. 1.2 s in, every player within `NUKE_RADIUS` (60 m, inference) ragdolls (`Player.ragdoll`, 4 s) and is thrown outward for real: the local player on each peer gets an upward kick (8 m/s) and a flat velocity so the range is `6 m * strength` (`Player.ragdoll`, `game/player/player.gd`), lands where the throw takes them (walls stop it), and has input locked for 4 s; other peers see it through the normal position sync, and the host lets the speed check pass for that peer until the throw is over (`free_until` in `Game.players`, `players.gd`). The range scales by `NUKE_THROW * (1 - d / NUKE_RADIUS)` (2.5 at the centre, 0 at the edge; inference, settle by playtest), so a near player flies farther than a far one. The creature parts are thrown by the same falloff. The host logs `nuke_hit {peer, dist_m, throw_m}` per player. No damage, no death, nothing destroyed. |
| `low_gravity` | 60 s (doc 01) | The local player's gravity scale is 0.2 (placeholder). There is no jump in the base game, so while this runs Space jumps (`JUMP_V` 5 m/s); inference, the toy would otherwise only slow falls. |
| `big_heads` | 60 s (inference) | Every player's `head_scale` 3 (the head bone, see "Big heads (P5-42)"), and a `ToyHead` sphere on the creature. |
| `confetti` | until dawn | A ripe-to-empty `plot_changed` (a harvest) pops confetti and a kazoo on every peer. |
| `chicken` | until dawn | The host's tools squeak: each `hold_done` on the host broadcasts `squeak`, every peer plays a rubber-chicken squeak. |

Durations other than doc 01's 60 s, the 0.2 gravity, the 1.7 pitch and the sound designs are placeholders for a listen and play test. Sounds are generated at run time (no files, no recordings). Tests: `tests/gameplay/test_dev_gate.gd` (gate closed by default, open with the test hash, `Squeaky` adds and removes one effect) and `tests/net/test_dev_toys_sync.gd` (2 instances: a host `toy shrink` reaches a client; see its header for the command). `tests/qa/test_harness.py` covers the `check_logs.py` skip.

## 26. Next season and creature traits (P5-04)

Source: doc 01 "Next season", [doc 02](02_systems_and_economy.md) section 21, [doc 03](03_creature_ai_director_and_scares.md) section 22. Numbers are in `data/next_season.json` and `data/creature_traits.json`; `Data.TABLES` also registers `cosmetics`, `quirks` and `imposter` for the parallel Phase 5 tasks.

- **Flow.** A won season ends as in section 15 (`SeasonAwards._host_end` sets `Game.season_lost`). On the card the host gets "Start season N+1" (only if `Game.can_start_next_season()`: host, `Clock.season_over`, not lost, `season_no < campaign.seasons_max`), clients see a waiting line. `Game.start_next_season()` (host): `Campaign.build_carry` reads the live nodes, `season_no += 1`, a new `season_id` (`<session_id>_sN`, so the won season's final save is untouched), the trait draw and `Data.apply_traits`, then `apply_next_season(season, traits, reload)` to every peer and every peer loads the lobby; see **Through the lobby (P5-24)** below for the rest (P5-04 reloaded Main and started the clock here; P5-24 replaced that).
- **Carry.** `Campaign` (`game/core/campaign.gd`, static helpers) keeps upgrades (store records with `upgrade: true`, except `plot_pair`), the bought plots, and savings at 25% of the spare coins, rounded down, capped at 60 (doc 02 s21.2). `Save.apply_pending` calls `Campaign.apply_carry` in the new Main when `Game.carry` is set: store state, plots (never past `Farm.plot_ceiling()` of the new headcount), the flare gun refill, the savings coins (reason `savings`), then the `season_started` log event. Everything else resets with the Main reload (crops, traps, `taint`, generator, walkie batteries, scrap).
- **Debt.** Season 2 and 3 read `next_season.json` `season_N` (`Campaign.debt_base`), by headcount. `Debt.total_for` and `Debt.first_of` use it when `Game.season_no > 1`; season 1 and the short season are unchanged. A join or leave still re-scales owed by headcount (`Debt._headcount_changed`).
- **Traits.** `Campaign.draw_trait(seed, season, gained)` is uniform among the traits not yet gained, seeded by `hash("seed:season")`; the seed is `Game.seed_value`, or `hash(session_id)` when 0 (as `Creature._pick_body`). A trait is gained from `campaign.first_trait_season` on. `Data.apply_traits(ids)` applies each trait's `overrides` to the live records and remembers an undo list (`clear_overrides`): fields picked by `id`, `days` (ramp-up day range) or `where_kind`; `field` may be a dotted path; ops `set`, `add`, `mul`; a null base stays null. Overrides run on the host only; clients keep the trait id list for the Dawn Report. Apply them before the Main reload: the creature and AI Director cache some values in `_ready`. A new body is picked each season by P4-13.
- **RPC.** `apply_next_season(season: int, traits: Array, reload: bool)` (host to clients, reliable). A joiner gets it with `reload` false from `Net._admit`.
- **Display.** The HUD top line starts "Season N". The Dawn Report card says "Season N  Day D" and prints the new trait's `report_line` once, on the first report of the season (`report.trait_line`).
- **Save.** The dawn save adds `season_no` and `traits`; `Game.load_season` restores both and re-applies the overrides.
- **Log events.** `trait_gained` {season, trait, seed} once per season start; `season_started` {season, savings, spare, coins, plots, plots_carried, upgrades, headcount, traits}.
- **Through the lobby (P5-24).** This replaces the direct reload in **Flow**: `start_next_season` no longer starts the clock or reloads Main into the farm. It builds the carry, bumps the season, draws the trait, clears `Game.roles` and `Game.season_uids` (a loaded season's role lock ends) and calls `Imposter.clear_pick()` (host only: uid, name, `picked`). Then `apply_next_season(..., reload=true)` runs on every peer: it sets `in_lobby`, clears `lobby_ready` and `match_roster`, drops `Imposter.me` and `Quirks.mine`, sets `Game.season_sting` and loads the lobby. `Quirks.reroll(season)` clears the quirks; the draw happens at `start_match`. `can_start_next_season` also needs `not in_lobby`. The lobby then runs as for season 1: roles picked again, group settings, Ready, `start_match` (`Roles.sync` draws the quirks with the new `season_n`, `Imposter.pick` rolls again, `Clock.start()` at day 1). Main applies the carry as before and then writes the **season-start save**: `Save.build` plus `season_start: true`, as `dawn_01.json` in the `<session_id>_sN` folder, sent to clients. Loading it resumes at the start of day 1 (`Game._start_clock`), not at a dawn. The save has no imposter field (`Imposter.uid` is host-only; the uid shows in `uids` like every player's). A client never learns the new `season_id` (host-only), so it finds the copy by folder name. Cues: `ui_season_start_sting` on every peer when Main loads after the lobby (`Game.season_sting`); `ui_trait_gained` with the Dawn Report's `trait_line`, which never names the trait (doc 03 s22.1).
- **Test (P5-24).** `tests/net/test_p5_24_lobby.gd` (2 instances, command in its header): season end, lobby, season 2, same state on both peers.
- **Tests.** `tests/gameplay/test_next_season.gd` (overrides, draw, savings, plots clamp, season debt) and the 2-instance `tests/net/test_p5_04_e2e.gd` (header has the command). Open points: Q-271 to Q-275.

## 27. Imposter mode (P5-11)

Doc 01 "Imposter mode", "Rejoining"; doc 02 s22; `data/imposter.json`; D-155, D-158, D-161. Code: `game/core/imposter.gd` (static class `Imposter`, like `Roles`), `game/core/imposter_input.gd` (kit keys), small hooks in `game.gd`, `net.gd`, `lobby.gd`, `dawn_report.gd`, `season_awards.gd`, `dev_console.gd`.

**State.** `Imposter.enabled` (the lobby toggle, every peer, default off) and `Imposter.me` (only the imposter's own client). `uid`, `picked_name`, `forced` exist on the host only.

**Pick.** `Game.start_match` calls `Imposter.pick()` after `Roles.sync()`. It rolls only when the toggle is on and at least `min_players` (4) humans are in; the box is disabled in the lobby below 4 and the pick ignores the toggle there. `chance_pct` 50 decides, then one human at random. The secret goes with `Net.to_peers(&"apply_imposter_secret", [], [peer])` to that peer alone. Nobody else is sent a "no". Each next season goes back through the lobby, so `start_match` calls `Imposter.pick()` again (`rerolled_each_season`, P5-24).

**What never leaves the host.** The uid is not in the dawn save (that file is copied to every client), not in any broadcast, not in a client log. Inference: a loaded season therefore re-rolls (Q-301).

**Rejoin.** `Net._admit` calls `Imposter.sync_to(id)`: the toggle always, the secret only when the profile uid matches. Test: `tests/net/test_imposter_sync.gd` (rejoin run, port 53763).

**Win.** `Imposter.won()` is `Debt.lost` (final payment missed) and nothing else: a first-payment Foreclosure Notice and a Harvest Moon wipe are not an imposter win (D-155). The reveal line goes into the final Dawn Report (`report.imposter_line`) and the Season Awards card, only when the toggle was on or a dev pick forced one.

**Kit.** `request_imposter_act(kind, at)` is an `any_peer` RPC; `Imposter.act` drops it silently unless the sender is the imposter, alive, within the per-night/day caps and cooldown of `imposter.json`. Built: `whistle_throw` (noise `whistle` at a point up to 25 m away, sound broadcast as peer 0) and `gate_prop` (the section nearest the pen gate stands open, like a fence break). `false_flag` needs no new code: the imposter plants a normal flag with its own three slots and lies by where it puts it. Not built: `door_prop` (Q-303).

**Kit holds (P5-25).** Every kit action is a hold like any other chore: the imposter keeps the key down until a bar fills (`ImposterInput`, bar bottom centre, that client only). Placeholder keys `[` whistle, `]` gate, `\` pegboard mark (Q-303: the CEO picks). Seconds: `gate_prop` 2 and `pegboard_mark` 3 from `imposter.json hold_s`; `whistle_throw` has none there, so `Imposter.WHISTLE_HOLD_S` 1.0 stands in (Q-340). The client sends `request_imposter_hold(kind)` when it starts and `request_imposter_act` when the bar fills; the host stores the start (`Imposter.begin`) and drops an act that has no begin, comes before 90% of the hold time, or is over 30 s old. A begin consumes on act; a release early sends nothing. `false_flag` is the normal flag hold (`place_flag`), unchanged. Not through `HoldRegistry`: the registry needs a target in range and a kit piece such as the whistle has none.

**pegboard_mark (P5-25).** The host's `TrapSweep.filled` stays the truth (hang, take, creature theft all read it). `TrapSweep.pegboard_mark` is a separate bool-per-slot array on every peer: true draws that outline as the opposite of `filled` (`_paint` only; no rule reads it). `Imposter.act` calls `TrapSweep.mark_slot(at, here, 3.0)`: the unmarked slot nearest `at`, with the imposter within the board's 3 m. The host broadcasts `apply_pegboard_marks(marks)`: the array only, no peer id, so a client log and the packet hold nothing about who (a late joiner gets it with `farm_state`). Resets: any completed pegboard hold (`PegTarget.complete`, shovel or hang) clears all marks; a slot whose `filled` changes (hung, taken by the creature) clears its own. Inference: "touching the slot" is built as touching the board, because the pegboard is one interactable (Q-341). Caps: 1 per day phase and 1 per night (`imposter.json`). Test: `tests/net/test_imposter_sync.gd` (host rules, clients see exactly one mark), `tests/gameplay/test_imposter.gd` (hold seconds).

The end reveal also plays `ui_imposter_reveal` (P5-07 cue) on every peer when the line shows (`dawn_report.gd`, `season_awards.gd`).

**Dev setting.** Console `imposter <peer id|name|me|none|off>` (host only, answers "unknown command" and is not in `help` unless `DevGate.unlocked()`): forces the pick, even below 4 players. In a running match it picks at once and tells only that peer the secret (the public toggle is re-broadcast first, which clears the old imposter's `me`). Test: the host script uses `Imposter.dev_force` with `--dev-gate-test-hash=`.

### Dev console message and dev menu (P5-36)

`msg <peer|name> <text>` (host only, logged `dev_command` and `dev_message`) sends the text to one peer: `Net.to_peers(&"apply_dev_message", [text], [peer])`, an authority-to-client reliable RPC, so no other peer receives it. The target's `DevConsole` shows it as an outlined label for 8 s at the bottom of the screen (the host shows its own locally). The peer argument resolves like every console peer argument (id, nth player, name prefix). A console message is a dev tool, not a gameplay surface.

The console panel has a left column, the dev menu: a player picker (filled from `Game.players` each time the console opens), buttons for the common commands (`MENU` in `dev_console.gd`; `{p}` is the picked peer), and a message box with Send. A button runs the same command line through `DevConsole.run`, so the host-only rule, logging and replies are identical to typing; a client's buttons answer "host only". The typed console is unchanged. Test: `tests/net/test_p5_36_msg.gd` (3 peers: the named one shows the message, the other does not).

### Dev console whisper (P5-43)

`whisper [peer|name]` (host only like every console command; default: yourself) plays the creature's whisper scare (doc 03 section 13 "The whisper") on that one player. It runs `scare whisper <peer>`, so it goes through `Scares.fire(..., forced)` and `Scares._send` with the scare's `private` flag: the build-up and the whisper go only to the target (`Net.to_peers(&"apply_scare", args, [peer])`; the host emits locally only when it is the target), and the host logs `scare` (`private` true, `target`). The target's client logs `scare_applied`; no other peer does. The whisper needs a teammate's clip at least `COULD_NOT_BE_M` away (`Scares._voice`); when there is none the director drops the whisper (`fits` returns `no_teammate_clip`), and the console, which forces it, sends the whisper with no clip: the target gets the hush and the log line, silence where the voice would be, and the reply says so. The dev menu's `whisper` button runs `whisper {p}` for the picked player. Test: 3 headless peers, host `whisper 2; whisper 1; whisper 3`, a client `whisper 1` answers "host only"; each client logged one `scare_applied`.

### Big heads (P5-42)

The `big_heads` toy scales the farmer's own `head` bone (`FarmerBody.set_head_scale`, via `HeadScaler`, a `SkeletonModifier3D` that sets the bone's pose scale after the animation each frame), so the skinned head texture and the `hat` bone below it (cosmetic hats) grow together. It replaced a separate white sphere that floated over the real head and hid the hat. The creature's `ToyHead` sphere is unchanged.

## 29. Horror role scares (P5-53)

`HorrorScares` (`game/player/horror_scares.gd`, `class_name`, added by `main.gd` before `sweep`) runs on every peer but is
active only when `Roles.of(Game.local_peer()) == &"horror"` and the player is not a ghost (or the dev console `horror <kind>`
forced it for 20 s on that machine). It never sends an RPC and never touches host state.

- Darker world: static `HorrorScares.ambient_mult` / `fog_mult` / `lamp_mult` (1.0 when inactive), read by `WorldLook._apply`
  (ambient energy, fog density) and `LightRig` (lamp energy). Nothing flickers a light; only ghosts do.
- Local scares: `silhouette` reuses `Scares._present(&"hallucination", ...)`, whispers use `Soundscape` or the `lure` event
  through `Net.apply_received` (same path and voice-setting rules as the creature's copied voices), `steps` follows the
  player until `turned`, `shadow` is a local mesh, `grab` jolts the camera.
- Sixth sense: the host's `Scares._sixth_sense` (dusk and night) sends a private `chill` through `apply_scare` to the Horror
  peer when the real creature is within `chill_range_m` (`DirectorLogic.chill_due`); `_present` calls the `horror_scares` group.
  Fake chills come from the role's own loop. The client cannot tell them apart.
- Logging: `horror_scare {kind, result, local}` and `horror_chill {target, real}`; `scare` is not used, so `check_logs` is unchanged.
- Data: `roles.json` `horror` (placeholders, doc 03 s23). Tests: `tests/gameplay/test_horror.gd`, `tests/net/test_p5_53_horror.gd`.
