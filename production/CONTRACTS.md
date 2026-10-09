# Contracts

Formats more than one role depends on. **Changing anything here needs Director approval and a
DECISIONS.md entry before any dependent work starts.** All sections are final as of PP-11 (D-020).

Source of truth for rules and numbers: [docs/01_design_doc.md](../docs/01_design_doc.md). Doc 01's
"AI Director" is the in-game pacing system; the studio role is "the Director". Always write the full
name "AI Director" for the game system.

---

## 1. Environment

| Tool | Version | Path on the CEO's machine |
|---|---|---|
| Godot | 4.7.2 stable (standard, GDScript) | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` |
| Blender | 5.2.2 LTS | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Python | 3.13 via `uv` | `uv run` from `tools/` |
| SuperCollider | 3.14.1 (winget `SuperCollider.SuperCollider`) | `C:\Program Files\SuperCollider-3.14.1\sclang.exe` (found by `tools/audio/render.py`; D-015) |
| SoX | 14.4.2 (winget `ChrisBagwell.SoX`, portable, not on PATH) | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\ChrisBagwell.SoX_Microsoft.Winget.Source_8wekyb3d8bbwe\sox-14.4.2\sox.exe` (found by `render.py`; D-015) |
| C++ toolchain | **none installed** | Needed only to build a GDExtension; see Q-001 |

- Git Bash for shell work, native Windows paths, no WSL.
- `$GODOT` in any doc or agent definition means the Godot path above. Headless checks: `"$GODOT" --headless --editor --quit --path .` (import, must print no
  `ERROR`/`SCRIPT ERROR`), then `"$GODOT" --headless --path . --quit-after 120`.

## 2. Folder layout and ownership

An agent edits only what its role owns. A change needed in someone else's path becomes a question
in QUESTIONS.md or a task from the Director.

| Path | Owner | Notes |
|---|---|---|
| `docs/01_design_doc.md` | CEO | Director proposes edits; never edited without CEO approval |
| `docs/README.md` | Director | Index of docs |
| `docs/02_systems_and_economy.md`, `docs/03_creature_ai_director_and_scares.md` | Game Designer | |
| `docs/04_farm_layout.md` | Level Designer | |
| `docs/05_technical_design.md` | Gameplay Programmer | |
| `docs/06_networking_and_voice.md` | Network & Voice Programmer | |
| `docs/07_art_direction_and_asset_list.md` | Technical Artist | |
| `docs/08_audio_design_and_sound_list.md` | Audio Designer | |
| `docs/09_playtest_plan.md` | QA / Reviewer | |
| `production/TASKS.md`, `CONTRACTS.md`, `DECISIONS.md`, `README.md` | Director | Others propose changes via QUESTIONS.md |
| `production/QUESTIONS.md` | Everyone appends; Director answers and closes | |
| `production/OPEN_ISSUES.md` | QA and Director append; Director edits | |
| `production/handoffs/<task-id>.md` | The task's owner | QA appends its review verdict |
| `project.godot` | Gameplay Programmer | Autoloads, input map, layers. Others request entries |
| `export_presets.cfg` | Network & Voice Programmer | Voice spike preset (D-014); the "Playtest (Windows)" preset is QA's (D-029) |
| `default_bus_layout.tres` | Audio Designer | |
| `game/core/` | Gameplay Programmer | Autoloads: `Game`, `Log`, `Data`, `Settings`, `Clock`, `NoiseBus` (D-018) |
| `game/player/`, `game/interaction/`, `game/farming/`, `game/items/`, `game/traps_player/`, `game/ghost/`, `game/ui/`, `game/debug/` | Gameplay Programmer | |
| `game/net/`, `game/voice/` | Network & Voice Programmer | Includes the voice chain the creature's fakes use |
| `game/creature/`, `game/ai_director/`, `game/bots/` | AI Programmer | |
| `game/world/` | Level Designer | Farm scenes, markers, gray-box geometry |
| `game/audio/` | Audio Designer | Ambience, placeholder generators, mix logic, `Soundscape` autoload (D-020) |
| `game/render/` | Technical Artist | Shaders, materials, environments, post, light rigs |
| `assets/models/`, `assets/blender/` | 3D Artist | `.glb` exports and `.blend` sources |
| `assets/textures/`, `assets/materials/` | Technical Artist | |
| `assets/audio/` | Audio Designer | Only placeholders we generate, or CEO-approved files |
| `data/` | Game Designer | JSON game data (section 6) |
| `tools/sim/` | Game Designer | Season simulator |
| `tools/blender/` | 3D Artist | Export scripts |
| `tools/audio/` | Audio Designer | Render pipeline for generated sounds (D-015). Sources in `assets/audio/src/` |
| `tools/qa/`, `tests/` | QA / Reviewer | Test runner and checks. Code owners add tests under `tests/<their area>/` |
| `spikes/voice/` | Network & Voice Programmer | Throwaway; not imported by `game/` |
| `addons/` | Director assigns per addon | Third-party code only after CEO license approval |
| `README.md`, `.gitignore`, `.gitattributes` | Director | |

## 3. Naming

- Files and folders: `snake_case`. Scenes `.tscn`, scripts `.gd` with the same base name as their
  scene's root.
- GDScript: typed (`var speed: float`), `class_name` in `PascalCase`, functions and variables
  `snake_case`, constants `UPPER_SNAKE`, private members `_leading_underscore`.
- Nodes in scenes: `PascalCase` (`Player`, `VoiceEmitter`, `Generator`).
- Signals: past tense, `snake_case` (`trap_sprung`, `crop_harvested`).
- IDs in data and logs (crops, traps, events, sounds, voice lines): `snake_case` strings, never
  display text. Display text lives in data or UI only.
- Assets: `<category>_<name>[_<part>][_<variant>].glb`, for example `crop_turnip_stage2.glb`,
  `creature_scarecrow_head.glb`, `prop_pegboard.glb`, `trap_bear_open.glb`.
  Categories: `creature`, `char`, `crop`, `pumpkin`, `corn`, `bldg`, `prop`, `tool`, `trap`, `animal`.
- Sounds: `<prefix>_<name>[_<variant>]`, for example `sfx_well_pump_01`, `amb_insect_bed`. The prefix
  picks the bus (Q-035, doc 08 section 3.1):

  | Prefix | Bus | Prefix | Bus |
  |---|---|---|---|
  | `sfx`, `step` (tool sounds too) | `SFX` | `vox` | `Voice` |
  | `amb` | `Ambience` | `mus` | `Music` |
  | `cre` | `Creature` | `ui` | `UI` |

- **Mono in 3D, stereo for beds and UI only.** A sound placed in 3D is mono, so the engine pans it;
  stereo files are for `amb` beds and `ui` only (doc 08 section 1, Q-034).

## 4. Scale and space

- 1 unit = 1 metre. Y up. Godot forward is -Z; models face -Z.
- Model origin: centered at the base (feet, ground contact). Buildings: origin at the main door's
  outer threshold, so "30 m from any building's door" is a distance between origins.
- Farmer height 1.8 m; eye height 1.65 m. Corn height 2.4 m (taller than eye height, so it blocks
  sight both ways).
- Physics layers (owner: Gameplay Programmer, set in `project.godot`):
  1 `world`, 2 `player`, 3 `creature`, 4 `interactable`, 5 `corn` (sight and sound occluder),
  6 `trap`, 7 `item`, 8 `trigger`.
- Level scene groups (D-016, D-023): `trap_spots`, `creature_cover`, `crow_perches`, `scarecrow_spots`,
  `animal_escape_spots`, `spatial_audio_markers`; plus `player_spawns`, `plot_spots`, `sell_box`,
  `generator`, `fuel_drum`, `well`, `pegboard_spots`, `pen_gates`, `doors`, `lightrig_spots`; DD Phase 2 adds `store_crate`,
  `sanctuary`, `farm_gate`, `pumpkin_patch`, `moonflower_bed`, `pegboard_slots`, `recording_spots`,
  `barn_lantern` (P2-02), `trap_sweep` (P2-11). DD Phase 1
  scene: `res://game/world/farm_phase1.tscn`; DD Phase 2: `farm.tscn`. Corn blockers sit on layer 5 and
  block players; the creature ignores layer 5 for movement.

## 5. Host and client authority

Per doc 01 "Engine and Tech > Networking". **The host is peer 1.** Any feature that only works
single-player is not done.

| Thing | Owned by | How |
|---|---|---|
| Own character movement and camera | Each client | Client simulates, replicates transform to everyone (unreliable channel). Host sanity-checks speed |
| Crouch, go-still state | Client reports | **Host checks stillness** from received transforms (doc 01) |
| Interactions (plant, water, harvest, disarm, pry, wash, refuel, sell, pick up) | Host | Client sends `request_*`; host validates range, timing, state; host broadcasts result |
| Creature, all its states, senses, traps it sets | Host | Clients receive state and transform; ambience runs locally from the replicated state |
| AI Director, tension meter, scare and lure scheduling | Host | Never runs on clients |
| Traps, pegboard, flags | Host | |
| Economy: money, prices, selling, bills, payments, debt | Host | No client-side selling |
| Taint, Shaken, deaths, respawns | Host | |
| Generator fuel, lights, doors | Host | |
| Crops and plots | Host | |
| Festival cart and Prize Pumpkin | Host | |
| Day clock and phase | Host | Broadcast; clients interpolate |
| Voice capture and encode | Each client | Host relays each speaker to the others |
| Voice settings and lobby line files | Each client, on its own disk | Never in the host save (doc 01 "Voice settings") |
| Lure playback | Host decides; clients play | "Play clip X at P for player Y"; clips pre-shared at session start |
| Close calls (lunges, kills, doorway reaches) | Host, **resolved in the victim's favour** | Lag never kills |
| Save at dawn | Host | |

## 6. Game data

JSON under `data/`, read by the game (`Data` autoload, [doc 05 section 4](../docs/05_technical_design.md#4-data-loading))
and by `tools/sim/`. One file per table. **Schemas are final as written in
[doc 02 Appendix A](../docs/02_systems_and_economy.md#appendix-a-proposed-json-schemas-contracts-section-6)
(A.1 shared rules, A.2 to A.14 per file) and [doc 03 section 19](../docs/03_creature_ai_director_and_scares.md#19-data-files-this-doc-adds);
this section does not copy them.** The files do not exist yet; the Game Designer creates them with
`data/*.schema.json` when DD Phase 1 starts (D-020).

- **Files (18, plus `phase1`):** `season`, `labor`, `crops`, `pumpkin`, `debt`, `medical_bill`, `player_scaling`,
  `difficulty`, `store`, `ramp_up`, `traps`, `taint`, `roles` (doc 02); `creature`, `sabotage`,
  `ai_director`, `voice_lines`, `dawn_report_templates` (doc 03). `phase1.json` (scripted DD Phase 1 timers,
  doc 03 section 18) is loaded by `Data` only with `--phase1` (D-023). `creature` and `voice_lines`
  schemas are as written in `data/*.schema.json` (D-023), as are `ai_director`, `sabotage`, `taint` and
  `dawn_report_templates` (P3-02, D-060).
- **Envelope:** `{"table": "<file name>", "schema_version": 1, "records": [{"id", "source", "cite", ...}]}`.
  `season.json` records are `{id, value, unit, source}`.
- **Ids:** `snake_case`, unique per file (the `Data` loader and the simulator reject duplicates; JSON
  Schema cannot).
- **`source`:** `doc01`, `sim` or `placeholder`; `sources` overrides it per field.
- **Suffixes:** `_s`, `_m`, `_mps`, `_pct` (integer percent), `_mult`; `_4p` is a 4-player value scaled
  by `player_scaling.json`, rounded up (debt rounds to nearest, D-017). Coins are integers.
- **One home per value:** a multiplier or rule lives in one file only (doc 02 section 19).
- **Load checks** (in `Data`, doc 05 section 4): envelope, duplicate ids, required ids present,
  `source` valid. A missing file fails loudly. The simulator runs the full schemas.
- Movement speeds, capacities and hold seconds come from `labor.json` for both game and simulator
  (D-018).

## 7. Network messages (D-010)

Full list, arguments and frame formats: [doc 06 section 7](../docs/06_networking_and_voice.md#7-message-list).
A message not on that list needs Director approval and a DECISIONS entry.

- ENet channels: 0 reliable gameplay, 1 unreliable ordered movement, 2 unreliable voice, 3 reliable
  bulk (lobby-line clips, dawn save copy).
- Naming: client-to-host requests `request_<verb>` (`@rpc("any_peer", "call_remote", "reliable")`,
  host validates); host-to-all results `apply_<event>` (`@rpc("authority", ...)`). RPCs live on the
  `Net` autoload.
- Movement and voice frames use `SceneMultiplayer.send_bytes()` with a one-byte type prefix.
- `SceneMultiplayer.server_relay = false`: clients talk only to the host and learn the roster from
  `apply_roster`. Messages name players by slot; logs name them by peer id (D-012).
- Creature state is replicated as one of `lurk`, `lure`, `stalk`, `chase`, `retreat` (doc 03
  section 4). `lurk` is the baseline; there is no `roam` state (D-020).
- **`apply_refused(verb, reason)`** (host to the sender only): the host's answer to a refused
  `request_*`. The client rolls back its prediction; the host logs `hold_refused` (doc 05 section 7).
  Doc 06 section 7 lists it.
- **`apply_debug_state`** (dev only, host to a client that started with `--debug-view` and the host
  with `--debug-share`): snapshot for the client debug view (doc 05 section 19). Not in release
  builds; the handler is not compiled into them.
- Doc 01's verb list is the source for gameplay requests; their arguments and checks are in docs 02,
  03 and 05, with no new message families.

## 8. Shared runtime interfaces

- **Autoloads**, in load order (doc 05 section 3): `Log`, `Data`, `Settings`, `Net`, `Clock`, `Game`,
  `NoiseBus`, `Voice`, `Soundscape`.
- **Noise (D-018):** autoload `NoiseBus` (`game/core/noise_bus.gd`), host-side only. Final API in
  [doc 05 section 8](../docs/05_technical_design.md#8-the-noise-interface):
  `emit(position: Vector3, radius_m: float, kind: StringName, source_peer: int)` (raw, radius final),
  `emit_kind(kind, position, source_peer, mult = 1.0)` (looks up the radius in `creature.json`,
  applies Taint and quiet-can multipliers) and `emit_voice(position, volume_byte, source_peer)`
  (converts the one-byte voice volume to a radius). Signal `noise_emitted` is what the creature
  connects to. The AI Programmer's confirmation is Q-019.
- **Soundscape (D-020):** autoload `Soundscape` (`game/audio/soundscape.gd`, Audio Designer), runs on
  every peer, never talks to the network. API in
  [doc 08 section 10](../docs/08_audio_design_and_sound_list.md#10-runtime-api-soundscape):
  `set_creature_state(state, body)` from the `apply_creature_state` handler, `set_creature_position`,
  `set_phase` from `Clock`, `play_3d`, `play_2d`, `set_local_state`, `set_building`. Footstep, tool,
  door and trap sounds play when the host's `apply_*` arrives. `project.godot` entry is Gameplay's.
- **Debug accessors:** creature and AI Director expose `debug_sensed()` and `debug_state()` (doc 05
  section 19).
- **Input actions:** listed in doc 05 (sections 3 and 6); not copied here.
- **Day phase IDs:** `day`, `dusk`, `night`, `dawn`, `harvest_moon`.
- **Log events:** section 10.

## 9. Audio buses

Full rules, levels and layers: [doc 08 sections 2 and 3](../docs/08_audio_design_and_sound_list.md#2-buses-and-mixing-rules).

- **Layout file** (`default_bus_layout.tres`, Audio Designer): `Master` (limiter) with children
  `Music`, `SFX`, `Ambience`, `Creature`, `Voice`, `UI`. Mix rate 48 kHz (D-015).
- **Runtime buses** (D-020, answers Q-007): `game/voice/` creates `Mic` and the `Voice` children
  `VoiceBase`, `VoiceEcho`, `VoicePitchUp`, `VoicePitchDown`, `VoiceGhost`, `VoiceGhostEcho`,
  `VoiceGhostPitchUp`, `VoiceGhostPitchDown`, `VoiceRadio`. Their levels come from
  `game/audio/mix_levels.gd`. Real teammates, ghosts and the creature's fakes run through the same
  chain (doc 01).
- **Which bus:** by sound ID prefix (section 3). Crows and livestock are `SFX`, not `Ambience`; the
  Stalk drop is per-layer gain on `Ambience` beds, never a bus mute.
- **Sliders:** Master, Music, SFX, Ambience, Voice, UI; `Creature` has none. `reduce_scares` lowers
  `Creature` and `Music` stings (doc 08 section 2.1).
- Non-voice 3D sound is placed only by `game/audio/sound_emitter.tscn`; voice by `VoiceEmitter`.

## 10. Logs

JSON Lines, one file per peer per session: `user://logs/<session_id>/peer_<id>.jsonl`. The host's
file is authoritative for gameplay events.

```json
{"t": 312.4, "day": 1, "phase": "night", "peer": 1, "event": "lure_result", "data": {"target": 2, "moved_m": 11.2, "within_s": 8, "worked": true}}
```

`t` is seconds since session start. Events needed for the doc 01 measures (minimum):
`hold_completed` (verb, seconds), `lure_played`, `lure_result` (worked = moved more than 10 m toward
the source within 8 s), `trap_sprung`, `trap_race_result` (solo, tainted, pried_at_once, survived,
seconds_spare), `death`, `money_changed`, `inside_at_night` (seconds), `spatial_audio_trial`.
Full list and field names: [doc 05 section 18](../docs/05_technical_design.md). Host-written
`trap_race_result` and `inside_at_night` carry `data.player` (D-018). `lure_result.within_s` is
actual seconds; `window_s` is the allowed window (D-018).

Added by D-020 (Q-035, Q-037); Gameplay adds them to doc 05 section 18 with the rest:

| Event | Written by | `data` |
|---|---|---|
| `audio_state` | `Soundscape` on every peer, through `Log`, on each creature-state change and every 5 s while the state is not `lurk` | `creature_state`, `body`, `bed_db`, `wind_db`, `last_sounds` (last 8 sound IDs) |
| `ghost_flicker` | host | `player`, `light_id`, `cooldown_s` |
| `ghost_action` | host | `player`, `action` (`crow`, `rustle`, `static_voice`), `target` (id or null) |
| `lure_fooled` | host, when a recorded-line lure has `lure_result.worked` | `lure_id`, `target`, `line_id` |
| `perf_sample` | each peer, debug runs only | `avg_ms`, `max_ms`, `draw_calls`, `adapter` |

Added by D-053 (P2-05); the AI Programmer adds them to doc 05 section 18:

| Event | Written by | `data` |
|---|---|---|
| `trap_plan` | host, at nightfall | `day`, `players`, `plan` (kinds), `supply` (bear traps available) |
| `trap_stolen` | host | `trap`, `from` (`board`, `outdoor`, `dark_building`), `lock` |
| `trap_theft_capped` | host, when the lock stops a theft | `cap` |
| `trap_skipped` | host, when a planned set is dropped | `kind`, `reason` (for example `no_supply`, `no_spot`) |
| `trap_moved` | host, at dawn | `trap`, `from_building`, `to_spot` |
| `trap_changed` (new fields) | host | `region` (`heard`, `nearest`, `random`), `work_m`, `stolen` |

Added by P2-21 (P2-09 finding C; doc 06 s14 already lists it):

| Event | Written by | `data` |
|---|---|---|
| `net_rtt` | every peer, every 10 s with `net_bandwidth`, one per ENet peer (a client logs only the host) | `to` (peer id), `rtt_ms` (ENet round-trip time), `enet_loss` (ENet's reliable-packet loss, 0 to 1) |

Added by D-076 (Q-073; built in P2-08 and P3-08); Gameplay adds them to doc 05 section 18 in P4-04:

| Event | Written by | `data` |
|---|---|---|
| `audio_play` | `Soundscape` on the peer that hears it, each one-shot except footsteps | `id` (sound ID) |
| `audio_hush` | `Soundscape` on the hearing peer | `seconds` |
| `audio_taint_heartbeat` | `Soundscape` on the hearing peer, when the heartbeat starts or stops | `on` |
| `audio_chase_cue` | `Soundscape` on every peer, when the creature state turns `chase` | `body` |

## 11. Voice and recordings

- No real person's voice recording is ever committed. Test voices are synthetic or CEO-approved
  and kept outside the repo (`user://voice/`); `.gitignore` catches stray copies.
  One exception (D-067): the CC0 scream in `vox_emote_scream` (Freesound 850699), a published
  performance, not a player's voice.
- Voice settings behave exactly as doc 01 "Voice settings" states. QA checks this to the letter.
- Phase 5 features (live clips, spliced clips from live speech) are not built.
