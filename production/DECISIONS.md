# Decisions

Every decision that affects another role. Newest last. Format: ID, date, who, decision, why.

### D-001 · 2026-10-05 · Director · Godot 4.7.2, GDScript, Jolt
Game code is statically typed GDScript on Godot 4.7.2 (the installed version). C++ appears only
inside GDExtensions. 3D physics uses Jolt. **Why:** doc 01 picks Godot 4; GDScript needs no
toolchain (none is installed) and keeps every role able to read every script.

### D-002 · 2026-10-05 · Director · Game data in JSON under `data/`
**Why:** the season simulator (Python) and the game must read the same numbers, so tuning in one
place reaches both.

### D-003 · 2026-10-05 · Director · Phase naming
Studio phases follow the kickoff; design doc phases are written "DD Phase N". Task IDs: `PP-`
pre-production, `P1-`..`P4-` for DD Phases 1 to 4, `PL-` polish. **Why:** the kickoff's phase 2 is
DD Phase 1, which invites mix-ups.

### D-004 · 2026-10-05 · Director · Spikes stay separate
The voice spike lives in `spikes/voice/` and nothing in `game/` imports it. DD Phase 1 rebuilds
networking and voice in `game/net/` and `game/voice/` from doc 06. **Why:** spike code is written to
answer a question fast, not to last.

### D-005 · 2026-10-05 · Director · Third-party code needs CEO license approval
Any downloaded code or binary (including an Opus GDExtension or libopus) is listed with source and
license and approved by the CEO before it enters the repo. **Why:** the kickoff reserves downloaded
assets and their licenses to the CEO, and a binary is no different from a model or sound.

### D-006 · 2026-10-05 · Director · Logs are JSON Lines
Format in CONTRACTS section 10. **Why:** QA's checker, the Dawn Report and the simulator comparison
all read the same logs.

### D-007 · 2026-10-05 · Director · Building origins at the main door
Building models and scenes put their origin at the main door's outer threshold. **Why:** doc 01
measures the Prize Pumpkin and several rules from building doors; this makes them one distance check.

### D-008 · 2026-10-05 · CEO · Opus via an existing GDExtension
The voice spike and game use an existing open-source Godot 4 Opus GDExtension with prebuilt Windows
binaries, not our own libopus wrapper (Q-001). The specific addon is chosen from doc 06's candidate
list and approved by the CEO under D-005 before download. **Why:** no C++ toolchain is installed,
and it is the fastest route to the spike, the riskiest piece in doc 01.

### D-009 · 2026-10-05 · CEO · TwoVoIP v6.5 approved as the Opus addon
`addons/twovoip/`: TwoVoIP v6.5 (MIT), bundling libopus, RNNoise and SpeexDSP (BSD-3-Clause) and
godot-cpp (MIT). Windows x86_64 DLLs, `.gdextension` and every license file only; archive SHA-256
`811ac96d4b75314f90855e3136f9939f7a4bc4a01e51850640cff967afc20fc7` checked before unpacking.
Pinned; upgrades only by task. Owner: Network & Voice. **Why:** Q-003; the only maintained
candidate with Windows binaries (doc 06 section 15). v6.6 crashes Godot 4.7 on Windows (upstream #107).

### D-010 · 2026-10-05 · Director · Network transport contract
ENet channel 3 (reliable) carries bulk transfers; movement and voice use `send_bytes` with a type
byte; `server_relay = false`; doc 06 section 7 is the message list. CONTRACTS section 7 updated.
**Why:** Q-004. Bulk clips must not stall gameplay, and the host must sit in every path it
validates.

### D-011 · 2026-10-05 · Director · Doc 01 voice readings
Faint crackle on every proximity voice, so a fake can lack it; ghosts hear each other clean; ghost
voices don't feed the creature's hearing; only the holder hears a receiving walkie; the recording
light shows to everyone; a capturing machine never plays Off players' voices during capture.
**Why:** Q-005. Each follows from doc 01's text; the last makes "Off: nothing recorded" hold for
players on speakers.

### D-012 · 2026-10-05 · Director · Log identity and voice loss handling
Log events name players by ENet peer id, never by voice slot. `lure_played` and `lure_result`
share a `lure_id`; `lure_played` carries `sound_id` and `position`. Voice loss is handled by Opus
PLC only, because TwoVoIP has no in-band FEC. **Why:** Q-008. One identity across logs lets QA's
checker join events, and doc 06 must not plan on a codec feature the addon lacks.

### D-013 · 2026-10-06 · Director · More doc 01 voice readings; message list additions
Accepted as doc 06 states them (Q-012): an unchosen setting is sent as `off` until a line is
recorded; the volume byte is relative to each player's clamped calibration; "capture is live" means
writing mic audio to a clip; a leaver's clips are freed from peers' memory; ghosts can't transmit on
walkies; switching to Off during someone's capture discards it. The lantern, scarecrow and fence
placement, and role verbs added to doc 06 section 7 are part of the D-010 message list. **Why:**
each is the stricter or simpler reading of doc 01, and DD Phase 2 and 3 playtests can revisit them.

### D-014 · 2026-10-06 · Director · Windows export of the voice spike
`export_presets.cfg` is owned by Network & Voice for now (CONTRACTS section 2). Its "Voice spike
(Windows)" preset sets the custom feature `voice_spike`, and `project.godot` gains one line,
`run/main_scene.voice_spike`, so that export opens the spike; other runs still start at
`game/core/boot.tscn`. `spikes/voice/package_for_friend.py` exports and zips it; the friend needs no
Godot. A game preset comes with DD Phase 1, which drops the spike line. **Why:** Q-009 item 1. A
feature override is the one way to give an exported build its own main scene, and it doesn't touch
the game's.

### D-015 · 2026-10-07 · CEO · Generated sounds are rendered from SuperCollider sources
Placeholder sounds are written as SuperCollider sources, `assets/audio/src/<sound_id>.scd`, and
rendered headless by `uv run tools/audio/render.py` to 48 kHz 16-bit WAV at
`assets/audio/<sound_id>.wav`, peak-normalized to -1 dBFS by SoX and checked for silence and
clipping. Sources and rendered WAVs are both committed. `--spectrogram` writes a PNG per sound so a
reviewer who can't listen can still check pitch range, timing and tails. SuperCollider and SoX are
free; both are added to CONTRACTS section 1, and `tools/audio/` to section 2. **Why:** the Audio
Designer must generate placeholders in code (doc 01; no downloaded audio without CEO approval).
SuperCollider renders in non-real-time with no audio device, the way Blender runs headless for
models, so every sound is reproducible from a text file. 48 kHz matches the CEO's WASAPI mix rate
(doc 06 section 8).

### D-016 · 2026-10-07 · Director · Doc 04 placements (Q-014)
The generator stands by the barn, about 33 m from the fuel drum by the shed, so refuelling is a
walk. DD Phase 1 sells turnips at a stand-in sell box at (40, 20); the town stand and its 10 m
sanctuary come in a later phase. Doc 04's marker groups (`trap_spots`, `creature_cover`,
`crow_perches`, `scarecrow_spots`, `animal_escape_spots`, `spatial_audio_markers`, each a
`Marker3D`) are accepted, for CONTRACTS when the gray box starts. **Why:** doc 01 "Nights" puts
only the drum by the shed ("the walk is the cost"), and doc 01's Phase 1 list names no town stand.

### D-017 · 2026-10-07 · Director · Doc 02 readings of doc 01 (Q-015)
A missed first payment is a partial payment: the bank takes every coin down to the 4-coin floor,
and the shortfall × 1.5 goes onto the final. Pumpkins unlock at dawn 4 only if the first payment
was made (`unlock_rule`, a data switch the simulator also runs the other way). The shipping crate is
the store only; selling is at the town stand and the dawn cash-in. The Prize Pumpkin seed is free.
The debt rounds to the nearest coin (other scaled values round up). Walkie-talkies are bought, not
crafted. The simulator reads gnawing as "not guarded that night" until doc 03 sets the rule. The
pumpkin's size comes from its count of watered days. **Why:** each is the reading that reproduces
doc 01's worked numbers (1,077 / 211; 322 / 194) or the stricter, simpler one. Q-015 items 4 and 5
(plots per player, the 2-player gap) wait for the simulator and may go to the CEO at PP-12.

### D-018 · 2026-10-07 · Director · Doc 05 interfaces (Q-020)
Accepted as doc 05 writes them: autoload `Noise` with `emit`, `emit_kind`, `emit_voice` and signal
`noise_emitted`; `data.player` on host-written `trap_race_result` and `inside_at_night`;
`lure_result.within_s` is actual seconds with a new `window_s`; movement speeds and hold times read
from `labor.json` (one source for the game and the simulator); the host refuses defenses within 3 m
of the cart route; input actions and the log event list live in doc 05 and CONTRACTS refers to them;
dev-only `apply_debug_state` message for the client debug view (never in release builds);
`apply_refused(verb, reason)` is accepted pending Network & Voice's reply (Q-023). **Why:** each
removes an ambiguity two roles hit (Q-002, Q-006, Q-014 item 6, Q-016) with the least new surface.

### D-019 · 2026-10-07 · CEO · Voice subtitles and Doc 07 asks (Q-024, Q-029)

No voice subtitles for now (a missing speaker name would expose a creature fake); Gameplay edits doc 05
section 16 to match. Q-029 item 1 approved: Technical Artist may download open-licensed serif fonts for
the Dawn Report, with source and license listed in doc 07. Items 2 and 3 (night screenshot check, corn
profile on the CEO's machine) stay as future asks once a render exists. **Why:** subtitles undercut the
wrong-place tell; fonts are needed for the Dawn Report card.

### D-020 · 2026-10-07 · Director · CONTRACTS sections 6 to 9 filled (PP-11)
CONTRACTS sections 6 to 9 now point at docs 02 (Appendix A), 03 (section 19), 05, 06 and 08 instead of
copying them; no section is Draft. Where docs disagreed: (1) data files are 18, not doc 02's 13:
doc 05 section 4 adds `creature` and doc 03's four, and `season`, `labor`, `difficulty` are doc 02's
additions. (2) Doc 08 section 10.4 says "not `Roam`"; there is no such state, the baseline is `lurk`
(doc 03 section 4), so `audio_state` is written outside `lurk`; Audio Designer fixes doc 08. (3) Doc 05
section 3's autoload table lacks `Soundscape`; accepted as a ninth autoload after `Voice` (Q-032), Gameplay
adds the row and the `project.godot` entry. (4) Doc 06 section 8 leaves the voice-chain buses to Q-007;
doc 08 section 2.2 answered it: `game/voice/` creates `Mic` and the `Voice` children at runtime, the layout
file holds the seven base buses. (5) Sound ID prefixes `sfx`, `step`, `amb`, `cre`, `vox`, `mus`, `ui` and
the rule "mono in 3D, stereo for beds and UI only" go in section 3 (Q-035). (6) Q-037 events accepted:
`audio_state`, `ghost_flicker`, `ghost_action`, `lure_fooled`, debug-only `perf_sample` (section 10).
(7) `apply_refused` and dev-only `apply_debug_state` are in section 7 (D-018). **Why:** each is the
reading with the fewest new parts that lets two roles build against one file.

### D-021 · 2026-10-07 · Director · AI Programmer proposals (Q-018, Q-019)

Accepted as written in the Q-018 and Q-019 answers: Noise API amendments (radius <= 0 emits nothing,
Taint x1.5 on `step_*` only, tool noise on hold complete plus on start for shovel, pry and repair,
scream = `emit_voice` at byte 255); doc 03 edits (corn damping not applied to `step_sprint_corn`;
home on largest `effective_radius_m - distance_m`; footstep tension capped at +1/s per player;
stalk-to-chase uses the sensed position and not by day outside day death or trap race; chase lost
only after `chase_commit_s`; regions are `Area3D` nodes linked within 2 m); navmesh baked from
layer 1 only. **Why:** each removes an ambiguity or exploit (sprint quieter in corn, undefined
homing) that would otherwise surface during DD Phase 3 build.

### D-022 · 2026-10-07 · CEO · PP-12 approved, pre-production closed
CEO approved the pre-production review. Q-031 answered: stranger lines stay SuperCollider formant
synthesis (no TTS, revisit if DD Phase 1 testers cannot understand them); menu music yes, day music
undecided (not needed for DD Phase 1); whistle `max_distance` 220 m and `unit_size` 20 m accepted,
DD Phase 1 spatial test may retune. **Why:** none of these blocks DD Phase 1. Next: Director writes
the `P1-` tasks in `TASKS.md`.

### D-023 · 2026-10-08 · Director · Playtest kit before DD Phase 1 code (P1-01)
CEO asked for the playtest set up. Nothing in `game/` is playable yet, so the kit is built against doc
09 and the section 10 log format, and is checked on synthetic logs only. (1) P1-01, owned by QA, is the
first `P1-` task. (2) `export_presets.cfg` gets a second preset, "Playtest (Windows)", owned by QA:
main scene `boot.tscn`, no custom feature, excludes `tests/`, `tools/` and `spikes/`. The voice spike
preset is unchanged. (3) `check_logs.py` reads `spatial_audio_trial` from every peer's file, not the
host's only: doc 05 section 18 has the tester's client write it, so the host-only rule dropped every
client tester's trials. (4) Build id for a session is `git describe --always --dirty` until Gameplay
says where the game's `build_id` comes from (Q-040). **Why:** the STOP after DD Phase 1 needs every
step of doc 09 section 11 ready; building it now costs no game work and finds log gaps early.

