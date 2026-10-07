# Contracts

Formats more than one role depends on. **Changing anything here needs Director approval and a
DECISIONS.md entry before any dependent work starts.** Sections marked *Draft* are placeholders that
a named task fills in; until then, nobody builds against them.

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
| `export_presets.cfg` | Network & Voice Programmer | Voice spike preset only, until DD Phase 1 (D-014) |
| `default_bus_layout.tres` | Audio Designer | |
| `game/core/` | Gameplay Programmer | Autoloads: `Game`, `Log`, `Data`, `Settings`, `Clock`, `Noise` (D-018) |
| `game/player/`, `game/interaction/`, `game/farming/`, `game/items/`, `game/traps_player/`, `game/ghost/`, `game/ui/`, `game/debug/` | Gameplay Programmer | |
| `game/net/`, `game/voice/` | Network & Voice Programmer | Includes the voice chain the creature's fakes use |
| `game/creature/`, `game/ai_director/`, `game/bots/` | AI Programmer | |
| `game/world/` | Level Designer | Farm scenes, markers, gray-box geometry |
| `game/audio/` | Audio Designer | Ambience, placeholder generators, mix logic |
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
- Sounds: `<bus>_<name>[_<variant>]`, for example `sfx_well_pump_01`, `amb_insect_bed`.

## 4. Scale and space

- 1 unit = 1 metre. Y up. Godot forward is -Z; models face -Z.
- Model origin: centered at the base (feet, ground contact). Buildings: origin at the main door's
  outer threshold, so "30 m from any building's door" is a distance between origins.
- Farmer height 1.8 m; eye height 1.65 m. Corn height 2.4 m (taller than eye height, so it blocks
  sight both ways).
- Physics layers (owner: Gameplay Programmer, set in `project.godot`):
  1 `world`, 2 `player`, 3 `creature`, 4 `interactable`, 5 `corn` (sight and sound occluder),
  6 `trap`, 7 `item`, 8 `trigger`.

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

## 6. Game data (*Draft*, filled by PP-04 and PP-06)

JSON under `data/`, read by the game (`Data` autoload) and by `tools/sim/`. One file per table.
Every record has an `id`. Numbers are copied from doc 01; a value doc 01 doesn't give is marked
`"source": "sim"` or `"source": "placeholder"`.

Planned files: `crops.json`, `traps.json`, `ramp_up.json`, `player_scaling.json`, `medical_bill.json`,
`debt.json`, `store.json`, `pumpkin.json`, `taint.json`, `sabotage.json`, `ai_director.json`,
`voice_lines.json`, `dawn_report_templates.json`, `roles.json`. Schemas: *to be written by PP-04/PP-06
and approved here.*

## 7. Network messages (D-010)

Full list and frame formats: [doc 06 section 7](../docs/06_networking_and_voice.md#7-message-list).

- ENet channels: 0 reliable gameplay, 1 unreliable ordered movement, 2 unreliable voice, 3 reliable
  bulk (lobby-line clips, dawn save copy).
- Naming: client-to-host requests `request_<verb>` (`@rpc("any_peer", "call_remote", "reliable")`,
  host validates); host-to-all results `apply_<event>`. RPCs live on the `Net` autoload.
- Movement and voice frames use `SceneMultiplayer.send_bytes()` with a one-byte type prefix.
- `SceneMultiplayer.server_relay = false`: clients talk only to the host and learn the roster from
  `apply_roster`.
- Creature state is replicated as one of `lurk`, `lure`, `stalk`, `chase`, `retreat`.

## 8. Shared runtime interfaces (*Draft*)

- **Noise (D-018):** autoload `Noise` (`game/core/noise.gd`), host-side only. Final API in
  [doc 05 section 8](../docs/05_technical_design.md#8-the-noise-interface):
  `emit(position: Vector3, radius_m: float, kind: StringName, source_peer: int)` (raw, radius final),
  `emit_kind(kind, position, source_peer, mult = 1.0)` (looks up the radius in `creature.json`,
  applies Taint and quiet-can multipliers) and `emit_voice(position, volume_byte, source_peer)`
  (converts the one-byte voice volume to a radius). Signal `noise_emitted` is what the creature
  connects to. The AI Programmer's confirmation is Q-019.
- **Day phase IDs:** `day`, `dusk`, `night`, `dawn`, `harvest_moon`.
- **Log events:** section 10.

## 9. Audio buses (*Draft*, filled by PP-09)

`Master` with children `Music`, `SFX`, `Ambience`, `Creature`, `Voice`, `UI`. Voice includes real
teammates, ghosts and the creature's fakes, which run through the same chain (doc 01).

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

## 11. Voice and recordings

- No real person's voice recording is ever committed. Test voices are synthetic or CEO-approved
  and kept outside the repo (`user://voice/`); `.gitignore` catches stray copies.
- Voice settings behave exactly as doc 01 "Voice settings" states. QA checks this to the letter.
- Phase 5 features (live clips, spliced clips from live speech) are not built.
