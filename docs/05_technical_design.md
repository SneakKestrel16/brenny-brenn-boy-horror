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
10. [Taint, Shaken and the well](#10-taint-shaken-and-the-well)
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
| Taint, Shaken | State, timers, wash | Visuals, speed multiplier from `apply_*` | `apply_taint_changed`, `apply_shaken` |
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
autoload, **`Noise`** (`game/core/noise.gd`), the Noise interface (section 8, Q-019 to the Director
for CONTRACTS). Load order matters because later ones use earlier ones:

| Order | Autoload | File | Owner | Job |
|---|---|---|---|---|
| 1 | `Log` | `game/core/log.gd` | Gameplay | JSONL writer (section 18); reads `Clock` lazily for `day` and `phase` (null until `Clock` loads) |
| 2 | `Data` | `game/core/data.gd` | Gameplay | Loads and validates `data/*.json` (section 4) |
| 3 | `Settings` | `game/core/settings.gd` | Gameplay | Local settings file (section 16) |
| 4 | `Net` | `game/net/net.gd` | Network & Voice | Transport, sends, roster, `Net.to_host` / `Net.to_peers` |
| 5 | `Clock` | `game/core/clock.gd` | Gameplay | Day, phase, time (section 5) |
| 6 | `Game` | `game/core/game.gd` | Gameplay | Session state, player registry, ghost list, scene switching, save/load calls |
| 7 | `Noise` | `game/core/noise.gd` | Gameplay (API), AI Programmer (consumer) | Section 8 |
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
  adds: `--debug-view`, `--bots <n>`, `--phase1` (Phase 1 content), `--seed <n>`.
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
  pumpkin, debt, medical_bill, player_scaling, difficulty, store, ramp_up, traps, taint, roles,
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
  helped pry `helped_mult` in `labor.json`, Tainted pry in `taint.json`, role multipliers in
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
  multiply the maximum: Tainted sprint x0.6 (`taint.json`, doc 02 section 13), Shaken sprint x0.6
  for 60 s, Shaken and bear-trap slow walk x0.6 for 60 s (doc 01 "Night Traps"), carrying a teammate
  slows by the `carry` record (a data value; none is given in doc 01, `placeholder` in `labor.json`).
  Stacking Taint and Shaken is x0.36 on sprint (doc 02 section 13).
- **Sprint stamina.** Sprint runs at most `max_s` (6 s) and refills over `refill_s` (10 s) (doc 02
  section 2.2). The refill is linear; sprint can restart once it is above 0 (inference: doc 02 gives
  no minimum; a Tainted player recovers on the same clock; settled by DD Phase 1 feel). Stamina is
  client state; the host never needs it, and checks speed instead (below).
- **Host speed sanity check** (doc 06 section 6, keeping DD Phase 1 free of rubber-banding): the host
  receives `move` frames, computes the speed between frames and compares it with the maximum for the
  player's current state from the host's own view of that state (Taint, Shaken, trap slow, carrying),
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
   `1 / (product of multipliers)` evaluated every tick, so a mid-hold change (a helper arrives, Taint
   starts) changes the speed from then on, without restarting. Multipliers: `helped_mult` for pry when
   another living player holds `request_pry` on the same trap within 3 m (doc 03 section 7, `helped` 
   x0.6), Tainted x1.5 on pry only, role multipliers (Mechanic x0.6 on `repair_generator`, `refuel`,
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

CONTRACTS section 8: "Noise.emit(position: Vector3, radius_m: float, kind: StringName, source_peer:
int)", host-side. Doc 03 section 3.1 sets what the creature does with it. **Final** (confirmed by the AI
Programmer, Q-019, D-021):

```gdscript
# game/core/noise.gd  (autoload "Noise"; host-side only; a client call is a no-op with a warning)
signal noise_emitted(position: Vector3, radius_m: float, kind: StringName, source_peer: int)

func emit(position: Vector3, radius_m: float, kind: StringName, source_peer: int) -> void
func emit_kind(kind: StringName, position: Vector3, source_peer: int, mult: float = 1.0) -> void
func emit_voice(position: Vector3, volume_byte: int, source_peer: int) -> void
```

- **Name clash (P1-04):** `Noise` is also a native Godot class, so GDScript resolves the identifier `Noise` to the class, not the autoload (`Noise.emit_kind` fails to parse). Reach the autoload with `get_node("/root/Noise")` (cache it in a variable), as `Data.scaled` does for `Game`. A rename (for example `NoiseBus`) needs a CONTRACTS section 8 change (Q-041).
- **`emit`** is the raw call and the one CONTRACTS names. `radius_m` is already final (all
  multipliers applied). `kind` is a `StringName` from doc 03's table. `source_peer` is the ENet peer
  id of whoever caused it, or 0 for the world (a generator running dry). `emit` with `radius_m <= 0`
  (for example `step_crouch`) does not fire the signal; it only bumps the debug counter.
- **`emit_kind`** is what gameplay code calls: it looks up the base radius in `creature.json`
  (`noise_radius` records, doc 03 section 3.1 and section 19) by `kind`, multiplies by `mult` and the
  Taint multiplier (x1.5 on footsteps, doc 03 section 3.1; read from `taint.json` through `Game`),
  then calls `emit`. The quiet watering can is `mult = 0.5` on `tool_water` (doc 03 section 3.1).
  **Who owns the radius table** is `creature.json` (the Game Designer's number, the AI Programmer's
  consumer); `Noise` only reads it.
- **`emit_voice`** is called by `Voice` (`game/voice/`) for each speaker at most every 100 ms using
  the loudest frame since the last report (doc 06 section 8, doc 03 section 3). Radius is
  `60 * (volume_byte / 255)^2` m (doc 03 `voice` row: 159 gives 23 m, 255 gives 60 m, `placeholder`).
  The 60 m cap and the exponent are `creature.json` values, not constants in code. Ghost speakers
  never reach `emit_voice` (D-011): `Voice` does not call it for them, and `Noise` also rejects any
  emit whose `source_peer` is a ghost (`Game.is_ghost`) as a second guard.
- **Nothing is stored.** `Noise` keeps no history. The AI Programmer's `noise_emitted` consumer keeps
  its own 12 s hearing memory (doc 03 section 3.1). The volume byte is never logged (doc 06
  section 8).
- **Kinds** are exactly doc 03 section 3.1's ids: `step_walk, step_crouch, step_sprint,
  step_sprint_corn, tool_till, tool_plant, tool_water, tool_harvest, tool_shovel, tool_pry,
  tool_repair, tool_disarm, well_pump, door, generator_dead, bells, flare, whistle, voice, walkie`.
- **Corn damping (x0.7 between sound and creature), hearing memory, "louder replaces quieter within
  4 s" and picking the loudest radius-weighted source** all belong to the consumer, not to `Noise`
  (doc 03 section 3.1). `Noise` is a plain fan-out; a debug counter per `kind` is kept for the debug
  view.

Who calls it, per source:

| Source | Emitter | Kind | Notes |
|---|---|---|---|
| Footsteps | Host movement handler, once per stride from `move` frames (section 6) | `step_*` | Tainted x1.5; crouch radius 0 |
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

- **Plant, water, harvest** are holds (section 7). Planting needs a seed item; watering needs a full
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
- Prize Pumpkin (doc 02 section 6): a single special plot with its own growth rule from
  `pumpkin.json`; `water_prize_pumpkin` is a hold; the 20 m protection radius is checked by the
  host against live player positions (doc 01 "Prize Pumpkin"; the check is part of the AI
  Director's gnaw rule in doc 03 section 10, not duplicated here).

## 10. Taint, Shaken and the well

- **Taint** (doc 01 "The Taint"; effects table in `taint.json`, doc 02 section 13): host-owned flag
  per player with a cause (`dead_plot`, `trap_pit`, and so on from doc 02). While Tainted: sprint
  x0.6, pry x1.5, footsteps x1.5 on the Noise radius, and the creature tracks the player within 60
  m with a 20 s night trail (doc 03 section 3). `apply_taint_changed(peer, on, cause)` informs
  clients, who show it as dark smudges on the hands and a faint fog on screen (visual detail is doc
  07's).
- **Washing** is the `wash` hold, 10 s at the well (doc 01, doc 02 section 2.1), emits `well_pump`
  (45 m) and clears Taint on completion. The well is the only place; it is a normal `Interactable`.
- **Shaken** (doc 01 "Day deaths"): 60 s of sprint x0.6 after surviving a trap race (doc 03 section
  7); host timer, `apply_shaken(peer, seconds)`. Stacks with Taint (x0.36, doc 02 section 13).
- Taint and Shaken are applied on the host and mirrored for the multiplier; the host's speed check
  (section 6) uses the host's copy.

## 11. Traps from the player side, flags and defenses

Traps are host-owned (doc 03 section 8). The player side is:

- **Getting caught.** The trap handler triggers on the `trap` layer (6) with a host-side proximity
  check on the host's view of the player (the closer-to-victim rule applies to lunges and kills, not
  to traps, which are static; the race fairness is the half-RTT credit in section 7). A sprung trap
  sends `apply_trap_changed` and starts the race: `apply_trap_race(victim, trap, deadline, start
  distance)` to everyone, so the other players can come and help (doc 01 "Night Traps").
- **Prying free.** `request_pry` hold (4 s solo, x1.5 Tainted, x0.6 helped, doc 03 section 7);
  completion frees the player and starts Shaken. Failing the deadline is `death` with cause
  `trap_race`.
- **Disarming.** `request_disarm` (bear trap hold `disarm_bear` 5 s, Tracker x0.6), `request_fill_pit`
  (4 s), `request_cut_tripwire`. Cutting bells is `cut_bells` 1 s. All are holds with the Noise in
  section 8.
- **Flags.** Players mark a found trap with a flag (`request_place_flag`, 1 s, doc 01 "Night Traps >
  Flags"); `apply_flags` broadcasts positions and the flag is a world object, visible to everyone and
  hidden from nothing. The creature ignores flags except where doc 03 says (it can be baited near
  them; the AI Programmer's).
- **Pegboard.** The shed's pegboard holds trap items; `request_hang_trap` (1 s) puts one up on a
  slot, `apply_pegboard_changed` shows it; the host reads the pegboard for the AI Director's trap
  budget.
- **Scarecrows and fences.** `request_place_defense(kind, position, yaw)`; the host validates:
  a placement spot on open ground, no overlap with a plot or a trap spot, **and no closer than 3 m to
  the cart route** polyline (doc 04 section 6.1, waypoints R0 to R8, 147.9 m; this answers Q-014
  item 6; 3 m is doc 04's inference-level suggestion and a `placeholder`). The route is read from the
  level scene's `cart_route` `Path3D` (Level Designer: Q-019 asks). The cart route is kept fixed;
  the refusal reason is `blocks_cart_route`, and a refused placement gives the player a plain-language
  message in-world (a red outline on the ghost preview), not a HUD tag.
- **Player scarecrow count** comes from `store.json`; moved scarecrows (doc 03 sabotage) use doc 04
  section 7.3 spots.

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

Harvest Moon only (doc 01 "The Harvest Moon", doc 02 section 9). Host-owned `Cart` node
(`game/items/cart.tscn`) rolling along the level's `cart_route` path.

- Players load crops into it in the barn and push it: `request_push_cart(on)` as a hold-like
  continuous action (while held and within range the cart advances; speed by pusher count is
  doc 02's or doc 03's; `placeholder` until they say). `apply_cart(loaded, pushers)` (doc 06
  section 7) is sent on change only; the cart's transform rides the normal object update
  (inference: the Network & Voice Programmer owns the cadence, Q-019).
- "Out" is the host check `cart.position.x > 78` (doc 04 section 6.1: "past the fields", an inference
  of doc 04's; settled when the Game Designer fixes doc 02 section 9). At the cap, a cart still short
  of x > 78 counts as not out. Reaching the gate (x > 105) ends the run early and starts the payout.
- Pushers are shown by their bodies; the cart load is visible on the cart. No HUD.
- Knock-off: the creature knocks the cart off the route with the 15 s cooldown from doc 03 section
  12; the host moves it and players re-push.

## 14. Death, ghosts, whistle and emotes

- **Death.** Host-owned. Causes (doc 03 section 7 ids): `trap_race`, `deep_corn`, `night_chase`,
  `night_trap`, `harvest_moon`. The host sends `apply_death(peer, cause, position)`, drops the body
  (a prop, `Items`), spawns a `Ghost` for that peer, and logs `death`. The body can be carried by
  teammates (`request_carry_player`); doc 03 section 15 decides what bodies do to the creature.
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
- **Respawn.** At dawn, ghosts get bodies again (doc 01 "Death"). `apply_respawn(peer, position)`.
  A mid-season joiner spawns as a ghost and gets a body at the next dawn (doc 06 section 5).
- **Whistle** (doc 01 "How players fight back > Whistle"): `request_whistle` (cooldown
  `placeholder`); the host stamps the position and sends `apply_whistle(slot, position)`; the whistle
  is a world sound everyone hears at their own distance. It emits `whistle` (50 m) to the creature,
  so it can pull the creature, which is the rule in doc 01. **It is the only sanctioned way to find
  a teammate by sound** (doc 01's whistle rule), so there is no marker on the minimap (none exists).
  Its audible range is long (doc 04 section 8.2 suggests at least 171 m; the Audio Designer's number,
  Q-014 item 4 / doc 08).
- **Emotes** (doc 01 "Emotes and physical comedy"): `wave`, `point`, `shrug`, `scream` (the scream is
  an emote that is also loud: it plays a voice-like sound and emits a Noise of kind `voice` at volume
  255, i.e. 60 m; inference: doc 01 says the scream gives you away, doc 03 gives no emote row; the
  AI Programmer confirms, Q-019). `request_emote(emote_id)`; the host rate-limits (1 per 1 s,
  `placeholder`) and broadcasts `apply_emote`; clients play the animation on the sender's body.
  Pointing is a visible arm direction only (no marker).

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
- **Season Awards** (doc 01 "Season Awards"): shown after the final dawn or on foreclosure. Computed
  by the host from the season log (the same events) and sent as one `apply_dawn_report`-shaped
  message with a `season` flag. The awards list is doc 03 section 16's.
- No audio of a player's real voice is kept by either screen (doc 01 "Voice settings > Storage").

## 16. Menus and settings

- **Menus** (`game/ui/`): main menu (Host, Join, Settings, Quit), lobby (the dark barn, roles,
  difficulty, group options), pause overlay, host-left card, "waiting for a farmhand" card (doc 06
  section 5), Dawn Report, Season Awards. The Host and Join screens are doc 06 sections 3 and 4;
  `game/ui/` embeds `game/net/`'s screens.
- **Settings** live in `user://settings.cfg` (a `ConfigFile`) on **each client's disk and never in
  the host's save** (doc 01 "Voice settings > Storage"; CONTRACTS section 5). Contents: audio
  volumes, mouse sensitivity, FOV, keybinds, toggle crouch, push-to-talk vs open mic and its
  threshold, denoise, six volume sliders `volume_master`, `volume_music`, `volume_sfx`, `volume_ambience`, `volume_voice`, `volume_ui` (0 to 1, each sets its bus; Q-032, doc 08 section 10), `reduce_scares` (bool, default false; `Soundscape` softens stingers and sudden creature cues, read live; accessibility, inference: no doc 01 number), voice setting (`off` / `lobby_lines` / unchosen), streamer-safe, subtitles for
  none (no voice subtitles, D-019).
- **Difficulty and group options** are chosen in the lobby by the host and saved in the season
  (`Easy`, `Normal`, `Hard`, `Nightmare`, `difficulty.json`; "no live clips" and "streamer-safe" are
  flags; doc 01 "Difficulty and group settings"). They go in the save (section 17); the voice
  setting does not.
- **No HUD markers.** There is no minimap, no objective marker, no player name tag over a head, no
  health bar. Information is diegetic (doc 01 "Diegetic"): the pegboard shows what tools are out, the
  flag shows a trap, a wrinkled leaf shows a thirsty crop, the generator hums lower.
- **Accessibility** (inference, unscoped in doc 01): there are no voice subtitles at all (D-019): a
  missing speaker name on a creature fake would expose it and defeat the "wrong place" tell. A
  colour-blind option for the Taint visual. Settled by the CEO if it matters.

## 17. Save at dawn

Doc 01 "Saving": the host saves at every dawn, the save is portable, and any player from the season
can host it. Never voice.

- **When:** at the end of the dawn pipeline (doc 02 section 9: after farm damage; before the free
  scrap and flare refill, which are part of the next day's start, so a reload does not duplicate
  them). The host writes `user://saves/<season_id>/dawn_<NN>.json` (day number `NN`), keeping the last
  three plus `latest.json` copy (`placeholder`), then sends it to all clients (`apply_dawn_save`
  chunks on channel 3, doc 06 section 5) which store the same under `user://saves/<season_id>/`.
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
- **Loading:** the host picks a season from the local `user://saves/` (the player who hosts need not
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
| `taint_changed` | host | `player`, `on`, `cause` | Taint rules |
| `shaken` | host | `player`, `seconds` | Trap race outcome |
| `trap_changed` | host | `trap_id`, `state` (`set`, `sprung`, `disarmed`, `filled`, `cut`), `by` | Trap use |
| `flag_placed` / `flag_removed` | host | `player`, `position`, `trap_id` (or null) | Flags |
| `payment_made` | host | `amount`, `balance`, `due`, `late` | Debt |
| `dawn_summary` | host | `day`, `coins`, `debt`, `plots_ripe`, `plots_wilted`, `farm_damage`, `deaths` | Simulator `compare` (reads `money_changed` by dawn too) |
| `generator` | host | `state` (`fuelled`, `dead`, `repaired`), `fuel_s` | Generator run |
| `door` | host | `door_id`, `open`, `by` | Light rule |
| `creature_state` | host | `from`, `to`, `reason`, `position`, `target` (peer id or null) | Pacing; mirrors `apply_creature_state` (AI Programmer writes it) |
| `noise_emitted` | host, debug runs only | `kind`, `radius_m`, `position`, `source_peer` | Debug; off by default. Never a voice volume |
| `chase_started` / `chase_ended` | host | `target`, `how` (`lost`, `lit_building`, `kill`, `retreat`) | Pacing |
| `sabotage` | host | `kind`, `position` | Disturbance pool |
| `tension` | host, every 10 s | `value` (0 to 100), `phase` | AI Director |
| `speed_violation` | host | `player`, `speed_mps`, `max_mps`, `clamped` | Doc 06 section 6 |
| `data_mismatch` | host | `peer`, `table` | Section 4 |
| `net_*`, `voice_stats` | each peer | doc 06 section 14 (including `net_join_code_rejected` with `reason` `typo` or `length`) | Network |
| `settings_changed` | each peer | `key` (never a voice file path) | Debugging |
| `save_written` | host | `path_name` (file name only), `day`, `bytes` | Save |
| `audio_state` | `Soundscape` on every peer, through `Log`, on each creature-state change and every 5 s while the state is not `lurk` | `creature_state`, `body`, `bed_db`, `wind_db`, `last_sounds` (last 8 sound IDs) | Clients report Stalk layer drops; F3 is host-only (Q-035, CONTRACTS section 10) |
| `ghost_flicker` | host | `player`, `light_id`, `cooldown_s` | Doc 01 Phase 3 "the dead stay engaged"; QA flicker checks (Q-037) |
| `ghost_action` | host | `player`, `action` (`crow`, `rustle`, `static_voice`), `target` (id or null) | Same (Q-037) |
| `lure_fooled` | host, when a recorded-line lure has `lure_result.worked` | `lure_id`, `target`, `line_id` | Doc 01 Phase 2 voice lure check (Q-037) |
| `perf_sample` | each peer, debug runs only (`--debug-view` or `--bots`) | `avg_ms`, `max_ms`, `draw_calls`, `adapter` (`RenderingServer.get_video_adapter_name()`) | Doc 07 section 10.3 four-instance corn profile (Q-037) |

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
  - **Players:** a circle and name per peer, facing arrow, crouch/still/sprint colour, Taint and
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
    (R0 to R8), the sanctuary circle, the lit-building radii, the light registry (lit/unlit),
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
   host speed check, `Noise.emit_kind` from steps. The Phase 1 gray box from the Level Designer
   (doc 04 section 9).
3. **Hold framework and farming:** `HoldController`, `HoldRegistry`, `Interactable`, `plant`, `water`
   (the noisy can), `harvest`, `sell` at the (40, 20) box, `hold_completed` logged. Turnips only.
4. **Noise** wired to the AI Programmer's `noise_emitted` consumer and the voice reports.
5. **Generator and lights:** one generator, fuel drum, refuel, repair, dimming. No flicker anywhere.
6. **Go-still** (the host's ring) and crouch noise.
7. **Scripted creature support:** the host-side `Creature` shell is the AI Programmer's; this doc
   supplies Taint-free player state (Taint off in Phase 1 per doc 03 "fake it first"), the scripted
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

Left for later phases: Taint and washing (Phase 2 or 3 per doc 01), roles, the store beyond turnips,
the cart, Dawn Report, Season Awards, saves (Phase 2: the first full season), emotes, whistle
polish, carrying teammates, flags and pegboard. Their message names are reserved in doc 06 section
7 so they add no transport work.

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
  `Noise.emit_voice` radius at 159 and 255; the save contains no voice keys. These are written with
  the code, not in PP-07.

## 22. Gotchas

None are measured yet (no code exists); these come from Godot facts or other docs, and are marked
accordingly.

- **Do not call `rpc()` outside `Net`.** The latency and loss simulation can only delay what goes
  through the wrapper (doc 06 section 14). A direct call also bypasses `apply_*` naming.
- **Autoload order is a dependency order.** `Data` before anything that reads it; `Log` first so
  every other autoload can log. Reordering them in the editor breaks startup silently.
- **A client calling `Noise.emit` is a bug.** It is a no-op with a warning, and QA greps for it.
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
- **Windows paths in `user://`:** `user://` is `%APPDATA%\Godot\app_userdata\Brenny Brenn Boy Horror`
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
   `emit_voice` helpers and the `noise_emitted` signal; who applies the Taint and quiet-can
   multipliers (proposed: `Noise.emit_kind`); the kind list spelling; when tool noises fire (at
   completion, or also at hold start); emote scream as a `voice` 255 emission; the debug accessors
   (`debug_sensed`, `debug_state`); serialisable creature and AI Director save state.
2. **Director:** add the `Noise` autoload to CONTRACTS section 4, the `apply_debug_state` development
   message to section 7, and record the Q-002, Q-006 and Q-016 answers; add the doc 05 index row in
   `docs/README.md` (Director's file).
3. **QA:** no change to `check_logs.py` is required; optionally tally `angle_error_deg`, `close_call`
   results, and update the "provisional" comments (Q-002).
4. **Level Designer:** a `cart_route` `Path3D` and `Marker3D` groups in the level scene (doc 04
   section 6.1), the Phase 1 gray box scene name.
5. **Network & Voice:** nothing new for the transport; the cart transform cadence and `Net.rtt_ms()`.
