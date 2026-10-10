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

### D-023 · 2026-10-07 · Director · P1-01 and P1-03 checked
Approved: `phase1.json` as its own file (loaded only with `--phase1`); the proposed `creature` and
`voice_lines` schemas; `none` added to the `unit` enum (strings and booleans). Level scene groups
beyond D-016 added to CONTRACTS section 4. Phase 1 scene is `farm_phase1.tscn` (renamed from
`farm.tscn`, per Q-022; Phase 2 keeps `farm.tscn`). Corn on layer 5 blocks players; the creature
ignores it for movement. Open, inference: doc 03 section 18 stalk 20 s with chase at 15 s; a
playtest settles it. Retreat is 10 s in Phase 1 (`phase1.json`). **Why:** removes the ambiguities
P1-04, P1-05 and P1-08 would otherwise hit.

### D-024 · 2026-10-07 · CEO · Joining over Tailscale
CEO: players join over Tailscale. Joining by raw IP (a Tailscale address works like any VPN IP, doc 06
manual fallback) is the supported path for DD Phase 1. UPnP and join codes stay as built in the spike
but get no new work until the CEO asks. **Why:** removes router and UPnP failures from playtests
(Open Issue 1 in doc 01 stays tracked). **How to apply:** Network & Voice does not prioritise join
codes; QA tests two-machine sessions over Tailscale.

### D-025 · 2026-10-07 · Director · Noise autoload renamed NoiseBus
Autoload `Noise` becomes `NoiseBus` (`game/core/noise_bus.gd`) because `Noise` is a native Godot class and the identifier resolves to the class. API unchanged (`emit`, `emit_kind`, `emit_voice`, signal and log event `noise_emitted`). Answers Q-041. **Why:** removes the `get_node("/root/Noise")` workaround. **How to apply:** call `NoiseBus.emit*`; "Noise" stays the name of the concept and the doc 03 kind table.

### D-026 · 2026-10-07 · Director · Hold RPC shape
Accepted P1-05's single `request_hold(verb, target)` plus `request_hold_cancel` and
`request_farm_state`, with results `apply_refused`, `apply_hold_cancelled`, `apply_hold_done`,
`apply_plot_changed`, `apply_money_changed`, in place of doc 06's per-verb `request_<verb>`. Seeds are
infinite in Phase 1 (no store; inference). **Why:** one validated path for every hold verb, fewer
messages. **How to apply:** doc 06 section 7 and CONTRACTS 7 get the new names when the Network &
Voice Programmer next edits them.

### D-027 · 2026-10-07 · Director · Packet type bytes on channel 1/2
Doc 06's voice type bytes `0x01`/`0x02` collided with movement's MOVE=1 and MOVES=2 (both arrive on
`Net.bytes_received`). Ranges: `0x01`-`0x0F` movement and gameplay, `0x10`-`0x1F` voice. Voice is now
`0x10`/`0x11` (doc 06 updated by P1-06). Gameplay adds a `push_to_talk` setting (default `false`) to
`Settings`. **Why:** the host would read voice as movement. Answers Q-042.

### D-028 · 2026-10-07 · Director · Text HUD allowed in Phase 1
Doc 05 s3 says "No HUD markers". P1-16 adds a plain text layer (aimed-target verb prompt, stamina bar,
clock and phase, coins, controls hint, death banner) and no world markers. **Why:** a tester who has not
read doc 01 cannot play without it (Q-046). Doc 01 "Onboarding" in-world intros stay open; revisit after
STOP 2 whether the text layer stays. Unverified: the aimed-target prompt has not been seen on screen.

### D-029 · 2026-10-08 · Director · Playtest kit and Windows playtest export (P1-17)
CEO asked for the STOP 2 playtest set up. (1) P1-17, owned by QA: `tools/qa/playtest.py` (`new`, `tally`,
`collect`, `report`), `tools/qa/package_playtest.py`, `tools/qa/playtest/` (checklist, tester brief, notes).
(2) `export_presets.cfg` gets "Playtest (Windows)", owned by QA: main scene `boot.tscn`, `data/*.json`
included explicitly (Data reads them with `FileAccess`), `tests/`, `tools/`, `spikes/` excluded, console
wrapper exported in release too. (3) Boot has no menu, so the zip ships `Host.bat` (`-- --host --phase1
--port=45120`) and `Join.bat` (`-- --join=<tailscale ip>:45120 --phase1`, D-024). (4) `check_logs.py` reads
`spatial_audio_trial` from every peer's file: the tester's client writes it (doc 05 section 18). (5) Session
build id is `git describe --always --dirty` until Q-047 settles it. **Why:** the first zip, built before
`main` had the game, showed a gray screen; a bare exe also starts no Phase 1 session, so the launch
arguments must ship with the build.

### D-030 · 2026-10-08 · CEO · Faster playtest pacing
CEO asked for faster time in the playtest. `Clock` takes `--day-s`, `--dusk-s`, `--night-s` (seconds) and logs
`clock_override` at session start; game data is unchanged (doc 02 numbers stay). The playtest zip's `Host.bat`
and `Join.bat` pass day 180, dusk 30, night 300. Night stays full length: Phase 1 traps are set 40 to 220 s
into it and the scripted stalk starts at 60 s. **Why:** shorter days give more nights (lures, chases) per
session hour. Doc 09 s2's session length assumes 540 s days; the notes record the override.

### D-031 · 2026-10-08 · CEO · Dev console until release
CEO asked for a dev command tool kept until the game is finished. `game/debug/dev_console.gd` (`DevConsole`,
added by `Main`): backquote opens it in debug runs or any build started with `--dev`; the playtest `Host.bat`
passes `--dev`, `Join.bat` does not. Commands: `help`, `status`, `skip`, `phase`, `time`, `length`, `coins`,
`fuel`, `gen`, `creature`, `kill`, `respawn`, `debug`, `clear`; `--dev-exec="a; b"` runs commands at session
start for scripted QA. State-changing commands run on the host only (CONTRACTS section 5), through the
systems' own host functions, so clients get the normal `apply_*` messages; no new RPC. Each is logged as
`dev_command`; a playtest session with any `dev_command` must say so in its notes (doc 09 s2 measures can be
skewed). `Game.console_open` makes Player and HoldController ignore game keys while typing. **Remove before
release:** delete the `Main` line and the file, or gate it on `OS.is_debug_build()` only. Gameplay owns
`game/debug/` and reviews the edits to `clock.gd`, `game.gd`, `player.gd`, `hold_controller.gd`, `main.gd`.

### D-032 · 2026-10-08 · CEO · Playtest runs at normal length
Supersedes D-030's launcher pacing. `Host.bat` and `Join.bat` no longer pass `--day-s`/`--dusk-s`/`--night-s`;
sessions run the game's own lengths (day 540, dusk 60, night 300 s). The host skips or shortens phases with
the dev console (D-031: `skip`, `phase`, `length`), which logs each use. The `Clock` overrides stay for
scripted runs. **Why:** CEO prefers normal pacing now that the dev console exists.

### D-033 · 2026-10-08 · CEO · Spatial audio test closed (DD Phase 1 gate)
One tester, 48 trials, four bearings 90 degrees apart (session `audiotest_20261008_015727`, local logs,
not committed): voice 10/30/60/72 m 5/6, 6/6, 5/6, 6/6; whistle 6/6, 4/6, 5/6, 3/6. Every gated cell
is at or above 80% except whistle at 30 m (67%, above the 60% floor); 72 m is reported only. The CEO
closed the test on this run: no second tester, no emitter retune, Steam Audio contingency (doc 06 s15)
not needed. Voice 10 m / 120 m and whistle 20 m / 220 m stay. **Why:** distance and direction are
placeable by ear; the whistle's 30 and 72 m misses are noted in OPEN_ISSUES for a later listen. Doc 09
s5's 80% / 60% thresholds stay as written for any rerun.

### D-034 · 2026-10-08 · Director · DD Phase 2 review (P2-01)
(1) Sabotage from the disturbance budget moves from P2-05 to DD Phase 3: doc 01 "Build Plan > Phase 2"
lists only pegboard theft, and the AI Director that spends the budget (doc 03 s10) is Phase 3. (2) New
rows: P2-10 (Gameplay: menu, barn lobby, pause menu with the voice setting and push-to-talk; the
recording flow and the setting have no screen to live on), P2-11 (Gameplay: disarm, fill pit, flags,
pegboard hang; "trap sweeps feel worth doing" needs them, `trap_race.gd` builds none), P2-12 (Game
Designer: `medical_bill.json`, night trap counts, lock, take weights, Q-048 (1)). (3) P2-05 now
replaces the Phase 1 scripted traps on the full farm with doc 03 s9 trap setting; `--phase1` keeps the
scripted ones. Tripwire bells are not built in Phase 2 (proposal for P2-12: they count as nothing).
(4) Phase 1 playtest fixes no human has checked (OPEN_ISSUES playtest 1, 4, 5, 6, 9 to 12) are
rechecked in the first Phase 2 session (P2-09). Acceptance for every row is in TASKS.md. **Why:**
doc 01 "Between phases" step 3: settle what the next phase depends on before it starts.

### D-035 · 2026-10-08 · CEO · Full settings menu in P2-10
P2-10's settings menu grows to four tabs: Keybinds (rebind every action, reset, conflict warning),
Audio (six volume sliders, voice setting, push-to-talk, mic device and gain), Graphics (quality preset,
shadows, render scale, VSync, FPS cap) and Display (window mode, resolution, monitor, FOV, brightness).
All are saved through `Settings` and applied at boot. Graphics knobs must not break the doc 07 s10 corn
budget or the light rules. **Why:** CEO request; players expect to set these before a session.

### D-036 · 2026-10-08 · Director · P2 QA round 1 (P2-12, P2-02, P2-10)
P2-12 and P2-02 pass QA and are done. P2-10 fails on two findings (QA-P2-10.md 1 and 2) and goes back to
Gameplay: brightness follows doc 07 (ambient floor 0.2 to 0.4, no screen pass, no gamma), and the lobby
light goes through the light rig. Cross-path edits are ratified: the CONTRACTS s4 Phase 2 groups (Director),
P2-10's `tools/qa/package_playtest.py`, `project.godot`, `export_presets.cfg` and `.gitignore` changes
(packager test and a real export run in P2-09), and P2-10's `net.gd` RPCs pending the Network & Voice
owner review inside P2-03. QA's `tests/ui/test_settings_binds.gd` joins the suite. `grep_rules.py` no longer matches `ambient_light_energy` (Environment, not a light). **Why:** doc 07 sets
the brightness rule and the light rules; changing them needs the CEO, and the menu does not need it.

### D-037 · 2026-10-08 · Director · P2-03 and P2-11 in review; test runs stay off the CEO's desk
(1) The pegboard starts full (5 bear traps, doc 02 s12). A disarmed trap is refused with `pegboard_full`
until P2-05 theft frees a slot; `--pegboard-empty` stays a QA start. (2) P2-05 adds `clear_trap(id)` on the
Creature so `trap_race.gd` stops writing the Creature's private `_traps`. (3) CONTRACTS s4 gains the
`trap_sweep` group. (4) P2-11's QA screenshot lamp is removed: clue shots show what a player sees, and
`grep_rules.py` passes. (5) Test runs: `multi.py` launches every instance with `--audio-driver Dummy`
(`--sound` turns audio on) and the game arg `--free-mouse` (`Game.free_mouse`, never captures the mouse).
**Why:** (1) doc 02 is the source and a theft-free pegboard is not testable before P2-05; (5) CEO request,
test windows played audio and took the mouse while the CEO worked.

### D-038 · 2026-10-08 · CEO · 2 to 6 players, built around 4
The game is built and balanced for 4 players; 5 and 6 are supported and scaled. Doc 01 "Format", "Ramp-up"
and "Build Plan > Phase 2" now say so. Scaling above 4 mirrors the steps below it: 120% at 5 and 140% at
6, rounded up (`placeholder` until the season simulator sets them). (1) Game Designer (P2-13): extend
`player_scaling.json` (`max_players` 6), medical bill caps, night trap counts, roles and plots per
player to 5 and 6. (2) Level Designer (P2-13): 6 barn spawns. (3) Gameplay (P2-07): the player cap
comes from `player_scaling.json`; a peer past the cap is refused; `--bots=N` fills up to 4 only (bots
never push a match past the base count). (4) Network & Voice: doc 06 s13 adds a 6-talker bandwidth row.
Doc 07 s10 corn budget stays measured at 4; a 6-instance frame check joins P2-09. **Why:** CEO request.

### D-039 · 2026-10-08 · CEO · Field plots scale above 4 players
Above 4 players the field grows by 4 plots per extra player, start and ceiling both: start 16/16/16/20/24
and bought-plot ceiling 24/24/24/28/32 at 2/3/4/5/6 players (`placeholder`, `player_scaling.json`
`field_plots_start_by_players`, `field_plots_max_by_players`). Below 4 nothing changes. Doc 01 "Crops"
and "Store" updated. Projection (`tools/sim/projection.py`): median shortfall 3.7% at 5p and 2.4% at 6p
against 10% at 4p, so 5p and 6p run slightly easy; the real simulator may raise the 120% / 140%
placeholders. Level Designer authors 32 plot sites (extra ones locked below their headcount); Gameplay
reads the per-count tables, not `season.json`. **Why:** CEO; with a fixed 16-plot field, extra players
had no work and debt outgrew income (P2-13 data handoff).

### D-040 · 2026-10-08 · Director · P2 QA round 2
P2-10 (re-review), P2-03, P2-06, P2-07 and P2-13 pass QA and are done. P2-11 fails (QA-P2-11.md): a client
can crash when `trap_changed` frees a trap target before `apply_hold_done` arrives; back to Gameplay. Also
to Gameplay: a human joining past 4 when bots fill the match drops one bot (D-038 (3)). QA's `multi.py`
takes `-n 2` to 6. P2-13's spawn scene changes ship with P2-14, which edits the same files. Network &
Voice owes a review of P2-07's `net.gd` changes (cap, `apply_join_refused`, `net_bandwidth`) and decides
whether `clips.gd` needs a fast path when nobody recorded. **Why:** QA reviews in `production/handoffs/QA-*.md`.

### D-041 · 2026-10-08 · CEO · More roles than players
Doc 01 "Roles" gains five placeholder roles: Carpenter, Medic, Night Owl, Radio Operator, Warden (9 roles
for up to 6 players). The roster always holds more roles than the player cap, so players choose. Rules:
every role has work every day however well the team plays (no speed-only or mistake-only roles: Hauler,
Cleaner and Lookout were rejected for that, Lookout also for overlapping the Tracker and Rancher); no role
harms the creature or reveals it; the Warden only forces Retreat like a flare hit. Game Designer sets the
perk numbers in doc 02 s15 before roles are built (not a DD Phase 2 task). Players pick roles in the
barn lobby: one player per role, "No role" always open, picks change until the host starts, then lock
for the season; late joiners pick from what is free; bots take none (placeholder). Roles and the lobby
pick are built with DD Phase 4 "upgrades, roles and payments". **Why:** CEO; 5 and 6 player
teams (D-038) need distinct jobs.

### D-042 · 2026-10-08 · CEO, Director · Medium added; no imposter role
Doc 01 "Roles" gains the Medium (placeholder, 10 roles): hears ghost voices through less static, never
learns which voice is the creature's fake, so the flicker stays the only tiebreaker (doc 01 "Ghosts").
An imposter role siding with the creature is rejected: it breaks "Honest signals cost something"
(pegboard, flags, whistle, flicker and radios must tell the truth), moves deaths from player risk to
betrayal ("Deaths come from player choices"), and turns "is that the creature?" into "is that the
imposter?", which weakens voice mimicry. A separate opt-in mode may be considered after DD Phase 4,
not before. **Why:** CEO asked; Director recommendation.

### D-043 · 2026-10-08 · CEO · Opt-in Imposter mode
Reverses D-042's "not before DD Phase 4" only as far as the design: doc 01 "Imposter mode" is added
as an opt-in lobby toggle, off by default, built after DD Phase 4. To keep the toggle and the role
list from exposing the imposter: the toggle means a placeholder 50% chance of one imposter or none;
roles are picked publicly first, then the imposter is chosen secretly at match start and keeps their
role and perks. The imposter wins on foreclosure, lies through signals and open doors, never kills;
the Dawn Report reveals them at season end. The normal game keeps D-042's no-imposter rule.
**Why:** CEO; the mode signalling "there is an imposter" and obvious roles giving them away were the
CEO's concerns.

### D-044 · 2026-10-08 · CEO · Hidden imposter dev setting, CEO's PC only
Imposter mode (D-043) gets a hidden dev setting: guarantee an imposter and choose the player. No menu
shows it. It unlocks only when the host's `OS.get_unique_id()` SHA-256 matches a hash baked into the
game; the existing `--dev` / debug-build gate (`game/debug/dev_console.gd:38`) is not enough, since any
PC can pass `--dev`. Only the hash goes in the repo, never the raw ID. The host assigns the imposter,
so the setting works only when the CEO's PC hosts. Built with Imposter mode, after DD Phase 4.
**Why:** CEO.

### D-045 · 2026-10-08 · CEO · Dev toys on the CEO's PC
Doc 01 "Dev toys" adds hidden joke commands behind the D-044 machine-hash gate: shrink, disco (creature
dances, fully visible), nuke (ragdoll, no deaths), low gravity, big heads, confetti harvest, rubber
chicken. Toys never touch save, coins, debt or deaths; sessions that used one log `dev_toy` so doc 09
measures skip them; disco never flickers lights (the ghost flicker stays unique, doc 01 "Ghosts").
Built after DD Phase 4. **Why:** CEO.

### D-046 · 2026-10-08 · CEO · Photosensitivity safety and safe mode
A player in the CEO's group is prone to seizures. Doc 01 "Photosensitivity safety" sets rules for every
mode: at most 3 flashes per second (WCAG 2.3.1), no full-screen white or red flash, no strobe,
lightning or fast high-contrast patterns. The ghost flicker (doc 07 s4.3) changes from 4 hard
off/on steps at 0.12 s (about 4 per second, unsafe) to dips to 30% at 0.25 s (2 per second). The
nuke toy (D-045) glows instead of flashing. New per-player setting `photosensitive_safe` (doc 05 s16),
offered by a first-launch warning: one smooth cold-blue dim for the flicker, a 0.5 s fade for the
lunge cut, a steady glow for the whistle fallback, no disco lights or nuke glow. Nothing built yet
flashes (`LightRig` is slew-limited to 0.2 s, the ghost flicker is Phase 3); the setting and warning
ship with the ghost flicker. QA adds a doc 09 check when the flicker lands: log light transitions and
fail any light passing 3 per second. **Why:** CEO; player safety outranks the flicker's punch.

### D-047 · 2026-10-08 · CEO · Comfort and convenience settings
Added (doc 01 "Comfort and convenience settings", doc 05 s16 keys, task P2-15): camera shake and
head-bob slider with a level knockdown camera at off, centre dot, per-player voice volume and mute
(also mutes the creature's replays of that player, so a mute never exposes a fake), toggle holds
(same hold times), toggle sprint, invert Y, menu text size. Not added: panic key, scare volume cap,
colour-blind Taint option. On-screen captions or subtitles for sounds are rejected for good (they
would give away where sounds come from; D-019) and are not to be raised again. **Why:** CEO.

### D-048 · 2026-10-08 · CEO · Lobby-only joins, rejoin allowed
New players join only in the lobby. After the match starts the host refuses any `player_uid` not on
the match roster; a loaded save's lobby admits only that season's players. A roster player who drops
can reconnect to the same session: ghost at once, own farmer back at the next dawn, slot and role kept
(imposter status too). One player left now waits for a roster teammate to reconnect. Replaces doc 01's
"late joiners enter as a ghost" and D-041's late-joiner role pick. Field plots stay fixed at match
start (D-039), which this makes final. Docs 01, 02, 05, 06 updated; task P2-16. **Why:** CEO.

### D-049 · 2026-10-08 · CEO · Rejoin prompt, join codes back, crash mockery
A player who crashes or disconnects gets "Rejoin your last match?" on the next launch (client file
`user://last_session.cfg`, cleared on a clean Leave or match end). Fallback: the lobby and pause menu
show the host's join code (doc 06 s4 format, already specified in the voice spike), and the Join
screen accepts a code or an IP. This is the CEO asking for join codes, so D-024's "no new work on join
codes" ends for this use; Tailscale addresses encode like any IPv4. The rejoiner sees one random
mocking line from doc 01 "Joining and leaving" (10 lines, data in `data/rejoin_lines.json`). Part of
P2-16. **Why:** CEO.

### D-050 · 2026-10-08 · CEO · Rejoin lines never repeat early
Each player sees all 50 rejoin lines (D-049) before any repeats: a shuffle bag kept on the player's
own PC (`user://rejoin_bag.cfg`), reshuffled when empty, with the new round never opening on the
line shown last. Docs 01 and 06, task P2-16. **Why:** CEO.

### D-051 · 2026-10-08 · CEO, Director · Quirks group option
CEO asked for an option where every player starts with a mental disorder. Doc 01 "Quirks" adds an
opt-in group option: one random quirk per player per season, ten placeholder quirks. Director's call:
quirks use invented names, not real diagnoses, so the joke lands on the farmhand and not on real
conditions someone in the group may have. The CEO can overrule. Quirks never reveal or harm the
creature or fake an honest signal. Built after DD Phase 4. **Why:** CEO; naming is the Director's.

### D-052 · 2026-10-08 · CEO · Quirks use real disorder names
CEO overruled D-051's naming: quirks use real disorder names because it is funnier (for example,
Nyctophobia, ADHD, Paranoia, Narcolepsy, OCD). The mechanics are unchanged. The option stays opt-in
per group, so a group can leave it off. **Why:** CEO.

### D-053 · 2026-10-08 · Director · Q-055: the pegboard is the creature's only bear-trap supply
P2-05's acceptance (written by the Director) missed doc 01 "The tool shed"; doc 01 wins.
1. **Finite pool.** Every bear trap the creature sets comes from the farm's own traps: the
   pegboard (doc 02 s12 capacity, 5 inferred) plus any off-board trap at nightfall. "Every empty
   outline is a trap somewhere on the farm." Pits are dug and need no supply. At nightfall the
   creature takes what the plan needs, off-board traps first, then from the board. Bear sets beyond
   the supply are skipped (`trap_skipped` reason `no_supply`). Traps taken at nightfall
   can be set that same night.
2. **Lock.** Before day 5 the lock caps all theft, board and off-board together, at one trap a
   night. From day 5 the lock is broken and theft is uncapped.
3. **Lit building.** A trap kept in a building that stayed lit all night is not stolen. At dawn it
   turns up unarmed in the corn at a random `trap_spot`, as a pickup (doc 01, doc 03 s9 table).
   Unarmed is inference from "turns up"; the Game Designer can overrule.
4. **Logs.** `trap_plan`, `trap_stolen` (`from`: `board`, `outdoor`, `dark_building`),
   `trap_theft_capped`, `trap_skipped`, `trap_moved` (lit building to corn), and `trap_changed`
   fields `region`, `work_m`, `stolen` join CONTRACTS s10.
**Why:** doc 01 is CEO-approved; the acceptance contradicted it. The rule is also more readable:
players count empty outlines to know how many bear traps are out there.

### D-054 · 2026-10-08 · CEO · Watering and fuel cans are physical objects
The CEO, after local play: the watering can and the fuel can are physical objects in the world.
Players pick them up, carry them and drop them, and anyone can pick up a dropped can. A can is no
longer a per-player count that every player starts with. Where cans start (the well, the fuel drum),
how many there are by headcount, whether carrying one fills a hand slot, and how creature tool theft
treats them follow doc 01 and doc 05; where those are silent, the Gameplay Programmer picks a
`placeholder` and the Game Designer settles it in data.
**Why:** CEO ask ("yes you can pickup, carry and drop them"). Cans that sit where someone left them
give the farm more to fetch and the creature more to move.

### D-055 · 2026-10-08 · CEO · Set traps get a visible basic mesh
The CEO, after local play ("traps still aren't visible, can you give them a basic texture"): set bear
traps and pits get a plainly visible basic mesh and material, seen from normal walking distance.
Doc 03 s9's clue-only rule (a trap shows only within 4 m) is paused until trap art exists; the clue
logic and `trap_clue_shown` logs stay.
**Why:** CEO ask. Testers couldn't find traps by eye, so trap sweeps (the Phase 2 "done when") had
nothing to sweep.

### D-056 · 2026-10-08 · CEO · A trap set waits for lurk, then lands anyway
A planned night trap set waits up to 30 s (placeholder, `TRAP_WAIT_S` in `creature.gd`) for `lurk`.
After the wait it lands in any state; `trap_changed` logs `late: true`. Doc 03 s9 updated.
**Why:** CEO play 2026-10-08 (`logs/qa/ceo_play5`): a lone player kept the creature in
lure/stalk/chase all night, so no planned trap landed (P2-28). CEO chose a timed wait over setting on
retreat.

### D-057 · 2026-10-08 · CEO · DD Phase 2 closed without the STOP 3 human sessions
P2-09 is done on its automated part (task reviews, 4-instance run, `check_logs.py`). The two human
sessions and the "done when" measures (a recorded voice fools someone; trap sweeps feel worth doing)
were not run. The P2-08 CEO listen is still owed.
**Why:** CEO call (no reason recorded; the CEO's local plays on 2026-10-08, P2-24 to P2-28, are the only human play of Phase 2).
**How to apply:** treat both Phase 2 "done when" measures as unproven. Check them in the first
human sessions of DD Phase 3.

### D-058 · 2026-10-08 · CEO · DD Phase 3 scope approved
The CEO approved rows P3-01 to P3-13 in `production/TASKS.md` as drafted. Phase 3 also carries the
sabotage budget (D-034), the Phase 1 30% lure measure and both Phase 2 measures (D-057).
**Why:** CEO approval; doc 01 "Build Plan > Phase 3" is the source.

### D-059 · 2026-10-08 · Director · Phase 3 scope settled at the P3-01 review
Waiting for Phase 4: the `harvest_moon` profile and acts (doc 03 s14), `pumpkin_gnaw` (no Prize
Pumpkin), `broken_fence` (no animals or pen), spliced lure clips (doc 03 s12.1) and walkie-talkies
(store items). The Phase 3 sabotage pool is `trample`, `stolen_tool`, `dead_crow`, `strange_seeds`,
`scarecrow_moved`, `generator_kill`. P3-09 defines the doc 09 ghost action events and includes corn
rustle; P3-05 adds a dev command to set the day.
**Why:** doc 01 "Build Plan > Phase 3" lists the AI Director, sabotage, scares, Taint, dead voices,
ghosts, whistle, emotes and the Dawn Report; the waiting items depend on Phase 4 content.
**How to apply:** acceptance for P3-02 to P3-13 is in `production/TASKS.md`.

### D-060 · 2026-10-08 · Director · Phase 3 data schemas approved (P3-02)
`ai_director`, `sabotage`, `taint` and `dawn_report_templates` are final as written in
`data/*.schema.json`. `taint` is doc 02 A.13 plus a `causes` list. `ai_director` keeps one record
per scare kind (`scare_*`: `big`, `private`, `opens_day`, `from_third`, `weight`) and takes the trap
race distances and lure weights (doc 03 s7.2, s12.1). The day arc is stored as fractions of
`season.day_s`, not 180 s. `broken_fence` and `pumpkin_gnaw` stay in `sabotage.json` with
`enabled: false` (D-059).
**Why:** doc 03 s19 proposed the files; CONTRACTS s6 makes schemas final on Director approval.
**How to apply:** P3-03 to P3-07 read these files and drop their constants (`WEIGHT_*`,
`DAY_LURE_GAP_S`, `DEEP_M`, `SHAKEN_*`, `TAINT_STEP_MULT`). See `production/handoffs/P3-02.md`.

### D-065 · 2026-10-08 · AI Programmer · Sabotage budget is a count; farm damage is coins (P3-06)
The daily disturbance budget is `ramp_up.json` `disturbances_4p` scaled by `Data.scaled(v, &"disturbances")`,
spent one disturbance at a time. `sabotage.json` `cost_points` are not used. `dawn_summary.farm_damage` is
the coin value of the crops lost to the dawn trample (crop sell price per plot).
**Why:** doc 03 section 10 gives a count per day and no point budget. The dawn report shows money, so coins
fit its ledger (inference; Q-069 item 3, Q-070).
**How to apply:** `game/ai_director/sabotage.gd` and `sabotage_logic.gd`. A point budget, if the Game
Designer wants one, can use `cost_points`, already in the data.

### D-066 · 2026-10-08 · CEO · Downloaded CC0 and Sonniss GDC sounds are allowed
Sound effects may come from Freesound.org recordings licensed CC0 and from the Sonniss GameAudioGDC
bundles (royalty-free, commercial use, no credit). Each downloaded file is listed in doc 08 section 13
with its source URL, author and license before it is committed. Generated sounds (D-015) stay for
everything not replaced. Voices of real people stay out (CONTRACTS section 11; one exception, D-067), and music stays out.
**Why:** CEO listens 1 and 2 of P3-08: the generated jumpscare, lunge, presence, crows, scream and paper
slide did not sound right after a rework; the CEO asked for a library of real sounds.
**How to apply:** Audio Designer. Keep the original download unchanged under `assets/audio/src/dl/` with
the license, process it (tools/audio/process_downloads.py) into `assets/audio/<sound_id>.wav` (48 kHz, 16-bit, peak -1 dBFS), and
note the processing in doc 08 section 13. Any other license needs the CEO first.

### D-067 · 2026-10-08 · CEO · The CC0 scream recording stays
The scream emote (`vox_emote_scream`) keeps the real CC0 recording of a woman's scream (Freesound 850699
by IENBA), an exception to CONTRACTS section 11 ("No real person's voice recording is ever committed").
**Why:** CEO listen 2 rejected the synthetic scream ("doesnt sound like a scream at all"); QA flagged the
recording against section 11 and the CEO chose to keep it ("keep it").
**How to apply:** this file only. Any other recording of a real voice still needs the CEO first. Player
voices stay out of the repo as section 11 says.

### D-068 · 2026-10-08 · CEO · DD Phase 3 closed without the STOP 4 human sessions; bodies move to Phase 4
P3-13 is done on its automated part (task reviews, two 840 s multi-instance runs, `check_logs.py`). The
STOP 4 human sessions were not run, so the Phase 3 "done when" tests (the dead stay engaged, the living
argue over a static voice, someone laughs at the Dawn Report) and every carried measure (Phase 1 lure
30%, both Phase 2 measures, by-ear whistle, the CEO static listen, 4-talker bandwidth) are unproven.
Doc 01 Open Issue 4 (do the four bodies feel different) and the per-season body pick (Q-074) move to DD
Phase 4.
**Why:** CEO call 2026-10-08 ("move creature body to phase 4 and start next phase").
**How to apply:** the first human sessions of DD Phase 4 run `tools/qa/playtest/checklist_p3.md`
alongside the Phase 4 measures. P4-08 builds the body pick.

### D-069 · 2026-10-08 · CEO · DD Phase 4 started
The CEO started DD Phase 4. The Director drafted rows P4-01 to P4-10 in `production/TASKS.md` from doc
01 "Build Plan > Phase 4", the items D-059 held back, and D-068. P4-01 settles scope and writes the
acceptance; the simulator (P4-02) needs no settling (doc 02 s18) and runs beside it.
**Why:** CEO request; doc 01 "Build Plan > Phase 4" is the source. Doc 01: "First: the simulator hits
its targets", so feature rows wait for P4-02.

### D-070 · 2026-10-08 · Director · Phase 4 scope settled at the P4-01 review
The D-069 draft rows P4-03 to P4-10 are replaced by P4-03 to P4-18 in `production/TASKS.md`, each with an
acceptance block: data (P4-03), full season (P4-04), Prize Pumpkin (P4-05), store (P4-06), debt and
Foreclosure (P4-07), animals (P4-08), roles (P4-09), saving and joining (P4-10), Phase 4 sabotage and
difficulty (P4-11), short season and Harvest Moon (P4-12), body pick (P4-13, was P4-08 in D-068),
walkies (P4-14), Season Awards (P4-15), models (P4-16), sounds (P4-17), QA review (P4-18). P4-02 is
unchanged. STOP 5 follows P4-18. Waiting past Phase 4 (doc 01): the six placeholder roles (D-072),
Imposter mode, Dev toys and Quirks ("after DD Phase 4"); live and spliced clips, next season and
cosmetics (Phase 5). Models: `assets/` holds no models, so P4-16 builds gray-box models in Blender 5.2;
no downloaded models without CEO approval.
**Why:** doc 01 "Build Plan > Phase 4" lists more systems than eight rows can review one at a time.
Doc 01 puts the simulator first, so rows that set or read economy numbers depend on P4-02; the body
pick, models and sounds touch no economy number.
**How to apply:** owners work from the P4 acceptance blocks. Feature rows start after P4-02 is done.

### D-071 · 2026-10-08 · Director · Animals and `broken_fence` are in Phase 4, gray-box
Chicken, pig and cow (Q-032) live in the pen. `broken_fence` lets them escape toward
`animal_escape_spots`; players round them up. P4-03 sets the numbers, including the cost of an animal
still out at dusk, which doc 01 does not give (placeholder, run in the sim). P4-08 builds it.
**Why:** doc 01 "Daytime Threats" names broken fences and animals rounded up far from the group; the
Rancher perk (doc 01 "Roles", doc 02 s15) does nothing without animals. The pen, gate and escape spots
already exist (doc 04 s7.3). The CEO may overrule (QUESTIONS, FOR CEO).
**How to apply:** P4-08; the Rancher in P4-09 depends on it.

### D-072 · 2026-10-08 · Director · Only the four doc 02 s15 roles are built in Phase 4
`farmer`, `rancher`, `mechanic`, `tracker`. The six placeholder roles of doc 01 "Roles" wait.
**Why:** doc 01 "Roles": "Placeholder perks are set before roles are built"; no perk numbers exist for
the six. Roles are optional and none is needed to win (doc 02 s15). FOR CEO: overrule to add them.
**How to apply:** `roles.json` (P4-03) and P4-09 carry four roles. **Overruled by D-077: all ten.**

### D-073 · 2026-10-08 · Director · `send_bytes` type byte ranges
`0x01`-`0x0F` are movement frames, `0x10`-`0x1F` are voice frames. New byte types take the next free
number in their range.
**Why:** Q-042 item 1. Voice `0x01`/`0x02` collided with `MOVE = 1` and `MOVES = 2`; P1-06 moved voice
to `0x10`/`0x11`. CONTRACTS changes shared formats only with a DECISIONS entry.
**How to apply:** Network & Voice owns the table in doc 06 s8; walkies (P4-14) use the voice range.

### D-074 · 2026-10-08 · Director · Dawn Report rulings (Q-066, Q-072)
1. Most Wanted is the player with the most `chase_started`; ties and a chase-free day go to the owner
   voiced in most lures, as built in P3-12. Doc 01 "who was chased most" is the primary measure.
2. Streamer-safe never replays any voice in the Dawn Report, as built (stricter than doc 01 "never
   replays live clips").
3. Skip stays per peer. Doc 01 asks for no host "skip for all".
4. The Dawn Report low-passes `Ambience` and `SFX` only, so replays stay clear. The pause menu keeps
   the doc 08 s2.3 `Master` low-pass.
The missing copy (Q-066 item 2) goes to P4-03.
**Why:** the built choices match doc 01's intent; a `Master` low-pass would muffle the replays
(Q-072).
**How to apply:** Audio Designer edits doc 08 s2.3 and builds the low-pass in P4-17; Gameplay updates
doc 05 s15 if wording differs.

### D-075 · 2026-10-08 · Director · Ghost flag on day and targeted lures
The logged `ghost` flag in `apply_lure` is set for a dead owner's lure by day too; drop `not day`.
Network & Voice's `_hear_lure` edit in `creature.gd` stays.
**Why:** doc 01 "The dead-voice twist": "including in targeted lures" (Q-068 item 1).
**How to apply:** AI Programmer in P4-11.

### D-076 · 2026-10-08 · Director · Phase 3 out-of-path edits accepted; audio log events listed
Accepted as built: Q-068 item 2 (`player.gd` ghost emitter), Q-069 items 1 to 4 (`apply_disturbance`,
`fix_hold_s`, `farm_damage` in coins, bots on the full farm), Q-065 (peer-id whistle and emote RPCs;
Network & Voice confirms with walkies in P4-14). CONTRACTS s10 lists `audio_play`, `audio_hush`,
`audio_taint_heartbeat` and `audio_chase_cue` (Q-073).
**Why:** each edit was small, logged in its handoff, and needed for the feature to land. The ledger
counts coins (D-065), so `farm_damage` in coins matches it.
**How to apply:** owners keep the edits when they next touch the files. Gameplay adds the audio events
to doc 05 s18 in P4-04.

### D-077 · 2026-10-08 · CEO · Q-075 answered: animals kept, all ten roles, Blender models, no agent listens
1. Animals, the pen and `broken_fence` stay in Phase 4, gray-box (D-071 confirmed).
2. All ten doc 01 roles are built in Phase 4, overruling D-072. P4-03 sets placeholder perk numbers for
   the six roles doc 01 lists without numbers; P4-09 builds all ten.
3. Phase 4 models are gray-box, built in Blender 5.2, nothing downloaded (P4-16 as written).
4. Q-054 item 8: no agent plays audio out loud. Test runs stay on the Dummy driver; the CEO does every
   listen.
**Why:** CEO answers to Q-075, 2026-10-08.
**How to apply:** P4-03 and P4-09 acceptance updated. Q-031 item 2 (day music) stays open.

### D-078 · 2026-10-08 · CEO · P4-02 simulator retune rules
1. The median team dies on 2 nights a season, not 3 (doc 01 "Season simulator" edited).
2. The field stays 16 plots at every headcount (doc 02 s4). The 2p/3p gap closes through headcount
   scaling of bills or debt, not fewer plots.
3. Plot buying stays in the sim; the median team buys. The Game Designer tunes plot price and payback
   so buying pays.
4. A drop of about 25 points in Medium-pumpkin rate at 2p is accepted.
5. Hazard knobs move one at a time, each move noted in the P4-02 handoff with its effect.
**Why:** CEO answers to the P4-02 QA FAIL, 2026-10-08. The first sim pass cut deaths to 1, cut 2p/3p
plots to 13/14 and turned buying off, which broke doc 01 and doc 02 s4.
**How to apply:** Game Designer retunes P4-02 in its worktree; any other doc 01 number it must move is
raised as a question, not edited.

### D-080 · 2026-10-08 · Director · P4-16 smear files and tool naming
1. The creature smear is four per-body hull files, one per body. The Technical Artist updates the doc 07
   s11.7 row to the four names.
2. Hand tools keep the `tool_*` prefix (CONTRACTS s3, doc 07 s11.3). Gameplay fixes
   `prop_watering_can`/`prop_fuel_can` in doc 05 s453 and the `game/items/cans.gd` comment when next
   touching them.
3. QA fixed double sRGB-to-linear vertex colours in `tools/blender/build_phase4.py` and rebuilt all 43
   models; `default_bus_layout.tres` was dropped from the P4-16 commit.
**Why:** QA review of P4-16; doc 07 s11.7 says "a hull of the active body", which four files match.
**How to apply:** owners above. Nits (cart and flare gun float 0.03 m, flare gun 0.14 m vs 0.18,
lantern glass always emissive, rebuilds not byte-stable, manual `import_script/path`) are listed in
the P4-16 handoff for a later 3D Artist pass.

### D-079 · 2026-10-08 · CEO · Q-077 answered: payment and bill scaling 59/85/101
1. Debt payments and medical bills scale by `payment_pct_by_players` in `data/player_scaling.json`:
   59% at 2p, 85% at 3p, 101% at 4p. Traps and disturbances keep `pct_by_players` 60/80/100. Doc 01
   "Ramp-up" edited.
2. The Medium-pumpkin drop of 35 to 48 points (2p to 4p) is accepted; revisit with P4-10 logs.
3. First clear near 85% assumes deaths bunch late (`death_night_weight` 3). P4-10's per-night death
   log checks it.
**Why:** CEO first chose 60/85/100; that gave a 16-point final-clear spread against doc 01's 10, so
the CEO switched to 59/85/101 (final 66/59/64, spread 6). The values are tuned to 1% steps and get
retuned from live logs.
**How to apply:** Gameplay makes debt and medical bills read `payment_pct_by_players` (added to
P4-10). Game Designer keeps doc 02 s4 and s18.6 in step.

### D-081 · 2026-10-08 · Director · P4-17 follow-ups
1. `cre_jumpscare_hit` is four per-body files, `cre_jumpscare_hit_{gaunt,scarecrow,boar,husk}`, with
   the old file kept as fallback. The AI Programmer wires the pick in `scares.gd` in P4-11.
2. Gameplay adds `Log.event(&"dawn_report_closed")` in `DawnReport._close()` in P4-04, so the
   soundscape stops polling the private `_open`.
3. Step-sound replays on the Dawn Report go through the SFX low-pass; accepted as built.
4. Sounds that reuse recorded material may be built in numpy (`tools/audio/gen_jumpscare.py`), as
   `process_downloads.py` already is; D-015's SuperCollider rule covers pure synthesis.
**Why:** P4-17 reviews. The four bodies differ too much in size for one hit sound; a log event is the
documented cross-system hook (CONTRACTS s10).
**How to apply:** rows P4-04 and P4-11 carry the items.

### D-082 · 2026-10-08 · Director · Q-084 answered: P4-03 follow-ups
1. The sim charges guarding time for `pumpkin_gnaw` per doc 03 s10.1; the Game Designer adds it.
2. The 5% chance an animal is out at dusk stands as a placeholder. P4-10 logs measure the real rate.
3. The Game Designer gives the Warden's `flare_refill_mult` and the Rancher's `animal_alert_range_mult`
   a base value to multiply, or rewrites the perk, before P4-09.
4. Short-season pumpkin grow time lives in `pumpkin.json` only; `difficulty.json` drops its copy.
5. The short season gets the same spread rule as the full season (at most 10 points across headcounts);
   the Game Designer tunes 2p short-season debt to meet it. No clear-rate target is added.
**Why:** QA review of P4-03 (Q-084). Items 1 and 5 keep the sim honest; 3 and 4 remove data the game
cannot use.
**How to apply:** one Game Designer follow-up in parallel with P4-04 and P4-08; rerun the sim gate
after each change. Q-084 item 5 is already in P4-11 scope.

### D-083 · 2026-10-08 · Director · Q-095 answered: gnaw guard charge stays off until measured
The sim's `charge_gnaw_guard` stays false. P4-05 logs the guarding and repair time per
`pumpkin_gnaw`; once P4-10 live logs exist, the Game Designer sets the charge from them and retunes one
P4-03 placeholder at a time if the gate fails.
**Why:** the 60 s guard and 57.4 m round trip are inference, not data, and turning them on fails 3p
(final about 52). Retuning other placeholders to absorb a guessed cost would be fitting to a guess.
**How to apply:** P4-05 acceptance carries the log. Short-season debt is re-checked when the charge
turns on.

### D-084 · 2026-10-09 · Director · Q-096 answered: Prize Pumpkin lifts only at Harvest Moon dusk
The Prize Pumpkin stays on its patch (at least 30 m from any door) until the Harvest Moon dusk move to
the barn, as doc 01 "The Prize Pumpkin" says. P4-12 gates `PrizePumpkin.lift_prize` to that dusk and
makes carrying it block other holds (can, shovel, trap). P4-11 calls `gnaw()` at dawn to match doc 03
s10 "in the morning".
**Why:** free carrying lets a team park the pumpkin in a lit doorway, which doc 01's placement rule
exists to prevent; doc 02 s6 has no carrying rule, so doc 01 settles it. Building a doorway-light
exclusion would be code for a case the design forbids.
**How to apply:** P4-12 acceptance carries the lift gate and the hold block; until then `lift_prize`
works on any day (dev and test use only).

### D-085 · 2026-10-09 · Director · Q-100 answered: scrap pays for every creature-damage fix
Every fix of creature damage costs 1 scrap: the `sabotage.json` fix verbs, generator repair included
(doc 01 "Repairs" line 289 and the store table, line 540). There is no free scrap on day 1; the first
free scrap comes at the first dawn (step 7), before any damage can exist. P4-11 calls
`Store.take_scrap()` from those fixes and refuses the hold with `no_scrap` when none is left.
**Why:** doc 01 states the rule; the P4-06 builder held back only because day-1 bots and tests would
break, which cannot happen if no damage exists on day 1.
**How to apply:** P4-11 acceptance; bots that fix damage must buy scrap when the free one is spent.

### D-086 · 2026-10-09 · Director · Q-110 answered: Foreclosure and early-payment rulings
(1) One Foreclosure seizure takes one item; when two players own a per-player upgrade, one keeps it
(QA's highest-peer-id pick stays a placeholder). (2) `Debt.pct_for` clamps headcount to 2..max like
traps and sabotage. (3) Network & Voice reviews the `apply_debt` RPC alongside Q-102 in P4-14.
(4) Every seized plot is cleared, bought plot pair or starting plot: one rule, and a team cannot keep a
crop on land the bank took. (5) Early payment works any time at the sell box, not only at dawn; the
money is gone either way, and a dawn-only window would need a Dawn Report control for no gain. Doc 01
line 438 and doc 02 s7.4 say "at any dawn"; the Game Designer rewords both on their next pass.
**Why:** QA's P4-07 review left these five calls open; none changes the simulator's totals.
**How to apply:** `Store.seize` clears crops on the relocked plot pair (folded into the P4-07 merge).

### D-087 · 2026-10-09 · CEO · Final art for the scare only before STOP 5
Before the STOP 5 playtest, only the parts that carry the scare get final art: the four creature
bodies (with their glimpse parts and smear hulls) and the night look (lighting, fog, darkness, post
stack, creature materials). Everything else (crops, buildings, props, tools, animals, pumpkins, cart)
stays gray-box until STOP 5 passes. Kickoff step 5's two stops stay: STOP 5 tests the season with the
scare art in, and the full art pass follows it.
**Why:** CEO call 2026-10-09. Testers who have not read the docs react to a real scare, while art on
systems still in play (rows P4-09 to P4-15, untested Phase 3, Open Issue 4) is not built twice.
**How to apply:** rows P4-19 (3D Artist) and P4-20 (Technical Artist). P4-18 depends on both. No
economy number or gameplay rule changes. Night readability (doc 07 s5) still gates: if the art
changes how far a creature or a trap clue is seen, the logs say so and the Director reviews it.

### D-088 · 2026-10-09 · CEO · 5 and 6 players retuned in the simulator
The P4-02 gate ran 2 to 4 players. At 5p and 6p the final payment cleared in about 83% of simulated
seasons (target 55 to 70) and the Prize Pumpkin size barely mattered (QA-check-2026-10-09). Retuned in
`tools/sim/` (doc 02 s18.6): `field_plots_start_by_players` 5p 20 to 18, 6p 24 to 20;
`field_plots_max_by_players` 5p 28 to 26, 6p 32 to 28; `payment_pct_by_players` 6p 140 to 138 (5p stays
120). All s18.3 targets pass at 2 to 6 players on seeds 1 to 3. `sim.py` now defaults to `--players
2,3,4,5,6`. `farm.gd` opens extra plots up to `field_plots_start_by_players` instead of every plot whose
`min_players` is met, so the data, not the level, sets the starting field.
**Why:** CEO call 2026-10-09 ("fix the 5-6 player balance").
**How to apply:** 2 to 4 players are unchanged. A 5p or 6p playtest session checks it (doc 09 s3 DD Phase 4).

### D-089 · 2026-10-09 · CEO · The town stand sanctuary does not count as attending the farm · superseded by D-115
A living player within the town stand sanctuary (farm.tscn `Sanctuary`, doc 03 s11.5) does not count as
"outside" for the night "Unattended farm" term (`game/ai_director/sabotage.gd` `_track_night`). Parking
one player at the stand all night therefore no longer zeroes `nobody_outside_s` (Q-164 item 2, Q-161).
The bots' sentinel job goes with it (P4-31).
**Why:** CEO call 2026-10-09 ("close the hole"); doc 01 "Nights": hiding is never fully safe or free.
**How to apply:** sanctuary still blocks lures, scares and kills; it only stops counting as attending.

### D-092 · 2026-10-09 · Director · Lobby ready messages
New net messages (CONTRACTS s7): `request_lobby_ready(on: bool)` (client to host, sender from `_sender()`)
and `apply_lobby_ready(peers: Array)` (host to all). `Game.all_ready()` gates the host's "Start the
season"; bots count as ready; `--lobby-start` bypasses it for QA. Not named `request_ready`, which `Node`
already has.
**Why:** P4-23 menu lobby (CEO session item 4); Q-175.
**How to apply:** doc 06 s7 lists them beside `request_role` / `apply_roles`.

### D-115 · 2026-10-09 · CEO · The town stand lowers creature interaction instead of being a sanctuary
Replaces D-089 and the absolute sanctuary (doc 01 "Sanctuary", doc 03 s11.5). Within 10 m of the town
stand the creature's lures, scares, stalk picks, knock-offs and kills are less likely (data-driven
multipliers, placeholders) but never impossible. A player there still counts as outside, so the
"Unattended farm" term does not grow while they stand there: standing guard lowers crop damage but does
not guarantee their safety. Bots keep their stand job. P4-31 is not merged; P4-34 builds this.
**Why:** CEO call 2026-10-09: "someone at the stand can still reduce the chances of crops being damaged
but cant completely guarantee their safety".
**How to apply:** no code path may treat the stand as fully safe. P4-34 re-runs the bot seasons and the
sim against the s18.3 targets.

### D-116 · 2026-10-09 · AI Programmer (CEO "yes" to Q-225) · Stand nights give the creature reach to the town stand
On a stand night the AI Director's nudge jumps the creature's wander region to the region of a living
player at the town stand (`town_road`), instead of one hop toward the most players (doc 03 s11.6). At
nightfall the AI Director rolls `ai_director.json town_stand.reach_night_chance` (placeholder 0.5) and
logs `town_stand_night`. It is still a region, never a position, and every D-115 stand roll (lure, scare,
stalk, knock-off, kill) still applies, so a guard is reached on some nights and killed on fewer.
Target (placeholder): a guard at the stand dies on about 1 night in 10 (0.5 stand night x `stalk_mult`
0.5 x reach x `kill_mult` 0.4, at most 0.1); a player outside at the farm when the scripted stalk starts
is picked and chased with no roll, so the guard's risk stays well below it and above 0.
To make the multipliers per-night chances, `town_stand.reroll_s` goes from 30 to 300, one night
(`data/season.json night_s`, doc 01 Nights): with a 30 s hold a guard who stays at the stand is re-rolled
ten times a night, so `stalk_mult` was only a delay (P4-34 QA). `kill_mult` goes from 0.2 to 0.4 to keep
the target. The stand RNG seed moves from `seed + 5` to `seed + 7`, off the scares stream (`scares.gd`
uses `seed + 5`).
**Why:** CEO answer to Q-225, 2026-10-09: "yes", the creature must sometimes go after a player at the
town stand. P4-34 measured 0 stand deaths in 84 bot nights without it: about 100 m of hops outlast the
doc 03 s18 scripted stalk and chase.
**How to apply:** the stand's risk is set by `reach_night_chance` and the D-115 multipliers together.
Tune them against bot seasons (stand deaths per night), not one at a time.
### D-094 · 2026-10-09 · Gameplay Programmer · The minimap is the one HUD map (P4-24)
The CEO asked for a top-right minimap (OPEN_ISSUES "Found in the CEO's 2-instance session" item 5).
`game/ui/minimap.gd` is a north-up map of the whole farm, built once from the level's own nodes, so
layout changes (P4-27) show without code edits. It shows the local player's arrow, living players,
buildings, fields and plots, the corn ring, the well (W), store crate (S), town stand (T) and cart
(C). It never shows the creature, a trap, a noise or a whistle. Doc 05 section "No HUD markers" now
names it as the one exception.
**Why:** CEO request; TASKS P4-24 lists the content.
**How to apply:** new map content goes through `minimap.gd`; anything secret (creature, set traps)
stays off it. Q-180 asks the CEO whether teammate dots stay (doc 01 voice and whistle tells).
### D-106 · 2026-10-09 · Game Designer · Headcount sell bonus, shipped at 0
P4-30 (CEO: "add a sell bonus based on player count to increase money so 2p still makes payments").
`player_scaling.json` `sell_bonus_pct_by_players` (2 to 6, integer %, `sim`) adds `ceil(v * b / 100)` to
every crop sale at the current headcount: sell box, dawn moonflower cash-in, final-dawn end-of-season
sale. Not the Prize Pumpkin payout. The host applies it (`Crops.sell_bonus`) and logs it as `bonus` on
`sell` (the dawn cash-in now logs a `sell` with `dawn: true`) and `end_of_season_sale`. The sim
(`Model.sold`) models it. **The table is 0 at every headcount:** the sim's median team already meets
every doc 02 s18.3 target at 2 to 6 players, the 2p median already pays the first payment, and any 2p
bonus that rounds to a coin pushes the 2p final clear above 70% (1% gives 76.8, 5% gives 90.8; doc 02
s18.6 P4-30 log).
**Why:** the acceptance says no bonus where the sim already meets its targets, and the sim meets them at
every headcount. The 2p misses in bot seasons come from a 2p team with one worker (Q-162, Q-164) and the
unattended trample term (Q-161), not from 2p prices.
**How to apply:** turn the bonus on by data only, after the Director rules on Q-210 and Q-211; re-run
`tools/sim/sim.py` and record the new table in doc 02 s18.6.

### D-107 · 2026-10-09 · Game Designer · Sim models the Q-161 unattended term, off by default
`tools/sim/sim.py` adds `min((night_s - 30) // unattended_every_s, unattended_cap)` (3 with the shipped
`sabotage.json` values) to the trample count on nobody-outside nights when the policy sets
`unattended_term: true`. `median.json` keeps it `false`, so the s18.3 gate is unchanged.
**Why:** with it on, final clear falls to about 26 to 33% at every headcount and Large needed fails
everywhere, with or without a sell bonus (doc 02 s18.6). Turning it on is an economy retune, which the
Director decides (Q-211).
**How to apply:** set `unattended_term` true in a policy to measure the D-089 world.

### D-130 · 2026-10-09 · CEO · No player-count sell bonus for now (Q-210 option a)
The `sell_bonus` table stays 0 at every headcount (D-106 unchanged). The 2p bot-season misses are fixed at
their cause, a single worker at 2p (Q-162, Q-164), not by raising 2p income.
**Why:** any 2p bonus that rounds to a coin pushes the sim's 2p final clear above doc 01's 70% ceiling
(Q-210). The CEO said "go with a for now".
**How to apply:** do not set a nonzero bonus without a new CEO decision. Revisit after the P4-34 bot
seasons; before any nonzero bonus, make the sim round per sale (OPEN_ISSUES "Found at the P4-30 review" 1).

### D-140 · 2026-10-09 · CEO · The menu lobby is a character line-up scene (Q-176)
The lobby shows every connected player's farmer standing side by side in a dark, lantern-lit 3D scene
(barn or night farm), the local player in the centre. Each farmer has its name, role and READY or NOT
READY above its head. Menus sit in side panels; the host's start button sits bottom right. Players still
spawn at the barn spawn markers at match start.
**Why:** the CEO asked for a lobby "similar to" a Fortnite-style concept image they linked
(behance.net project module 35f8a0200404059). The image is third-party art and is not committed.
**How to apply:** P4-35 builds it. Keep the horror tone: dark palette, lantern light, no bright colours
from the reference. Doc 01 "Picking a role" and "Staging" say "menu lobby".

### D-141 · 2026-10-09 · CEO · The minimap shows no other players (Q-180)
The minimap shows only the local player's arrow, the farm layout and placed flags (P4-33). It never
shows teammates or the creature.
**Why:** the CEO said "dont show players on the minimap"; teammate dots would expose fake voices and
replace the whistle (doc 01 "Voice mimicry", "Whistle").
**How to apply:** P4-33 removes the teammate dots from `game/ui/minimap.gd` `_draw_dyn`.
### D-120 · 2026-10-09 · CEO · Flags: a per-player limit, removal, and minimap icons (P4-33)
Replaces doc 01 "Flags" "Free and unlimited". Each player has at most `labor.json`
`place_flag.max_per_player` flags out at once (3, `placeholder`); the host refuses one more with
`flag_limit`. A player pulls up a flag they placed by aiming at it and holding `interact`
(`remove_flag`, 0.5 s placeholder); the host refuses anyone else (`not_your_flag`). Every placed flag
shows as a small icon on the P4-24 minimap. Flags stay free; the day-5 flag move is unchanged.
`labor.schema.json` gains the optional integer `max_per_player` on a hold record.
**Why:** CEO 2026-10-09: "players should have a limit on the amount of flags they can place and add a
method to remove one they already placed, flags should up on the minimap as well as small icons".
**How to apply:** the limit is data only. `TrapSweep.flags` holds `{pos, by}`; code that moves a flag
(the creature, day 5) changes `pos` and keeps `by`. Q-230 asks the Game Designer to own the number and
mirror the schema field in doc 02.
### D-104 · 2026-10-09 · AI Programmer (P4-29) · A pried-free bear trap lies loose at its spot
CEO request P4-29: a sprung bear trap no longer disappears when the victim is pried free. It stays at
its spot, jaws shut, as a loose trap (`trap_changed` `loose`, the dawn-trap `TrapPickup`). A player
takes it (`take_trap`, instant) and hangs it on the pegboard (`hang_trap`, doc 02 s3, 1 s), filling an
outline. A loose trap still lying out at nightfall is the creature's (doc 01 "Any trap not on the
pegboard at nightfall is the creature's"): `_steal_traps` takes loose traps after the ones in hands and
before the pegboard (`trap_stolen` `from: "ground"`).
**Why:** CEO call 2026-10-09. Doc 01 already makes every trap off the pegboard at nightfall the
creature's; the order (hands, ground, board) is an inference that keeps a team that hangs its traps back
ahead of one that leaves them lying. A playtest settles whether the order matters.
**How to apply:** trap race, pry, slow-after and night theft rules are unchanged. Bots pry themselves but
do not fetch traps.
### D-100 · 2026-10-09 · Level Designer, confirmed by Director · Farm cover blocks sight only
P4-27 breaks up the open farm with trees, fences, dirt paths, signs and landmarks (doc 04 s14). Only tree
canopies collide, on layer 5 (corn sight-blockers), from 1.2 m up; everything else is visual only.
Canopies keep each work spot's doc 04 s8.4 corn distance (pumpkin 20 m), 2 m from every marker and plot,
3 m from the cart route and 1 m from every s8.7 walk line, and stay out of the audio test band.
`check_farm.gd` `_cover` enforces this. No marker, building, field or route point moved, so doc 04 s8 and
`tools/sim/layout.json` are unchanged.
**Why:** players and the creature use collision mask 1 and the creature has no navmesh or unstuck logic,
so solid obstacles could pin it (Q-196). Sight cover is what the open ground lacked.
**How to apply:** new world dressing stays visual or layer 5 unless the AI Programmer adds avoidance.
### D-090 · 2026-10-09 · Gameplay Programmer · Seeds are chosen at the store, paid at planting
**Superseded by D-093** (CEO ruling on Q-170: seeds are bought into a stock).
P4-22 sells seeds at the shipping crate's menu (OPEN_ISSUES CEO session item 2). A seed row sets which crop
this player's field plots plant (`farm.seed_pick`, the same pick `cycle_seed` T already made); the seed's
price (doc 02 s10: turnip 4, pumpkin 10 from the first payment, moonflower 25 from day 3, bed only) is still
charged per plot when it is planted. Players hold no seed stock.
**Why:** charging at planting is what `tools/sim/` models (doc 02 s18). Seed packs bought ahead would move
coins earlier in the day and need a retune. Q-170 asks whether real seed stock is wanted.
**How to apply:** menu seed rows never send `request_store`; planting stays host-validated in `plot.gd`.

### D-091 · 2026-10-09 · Gameplay Programmer · The hotbar is an exception to "no HUD markers"
P4-22 adds a bottom-centre hotbar listing what the local player holds or the team owns, each with a
one-line use hint (OPEN_ISSUES CEO session item 3). Doc 05 s16 says "No HUD markers"; doc 01's only
HUD rule is the whistle's "no HUD marker" (doc 01 "How players fight back"). The hotbar points at no
teammate, objective, sound or creature, so it breaks neither.
**Why:** CEO request in the 2-instance session: players could not tell what they held or how to use it.
**How to apply:** the hotbar shows only the local player's things and the team's shared items. It never
shows positions, threats or other players. It hides while the player is a ghost.

### D-093 · 2026-10-09 · Gameplay Programmer · Seeds are bought at the store and held in a team stock
Supersedes D-090. The CEO answered Q-170: "can we add the seeds to the shop menu instead of having an
on screen constant seed purchase menu". The crate's menu sells seeds (`Buy 1`, `Buy 5`) through
`request_store` op `seeds`, arg `<crop>:<n>` (the RPC has one argument; at most 10 per request). The
host checks the crate's reach, ghosts, the unlock and the coins, then adds to `store.team["seed_<crop>"]`.
That dictionary is already saved and sent with `apply_store`. Planting an empty plot uses one seed of
the picked crop and charges nothing (`plot.gd`, refusal `no_seeds`, shown as "Buy seeds at the store").
The hotbar shows a seed slot only while the team owns seeds, with counts; T cycles only among owned day
crops. Prices and unlocks are unchanged (doc 02 s10). Bots buy one seed just before planting.
**Why:** the stock is the team's because coins are one shared purse and anyone plants any plot; a stock per
player would strand seeds when a player dies or leaves. The total spent per plot is the same. Coins leave
at purchase instead of at planting, within the same day for a team that buys as it plants, so the
simulator (daily steps) needs no change; the default `sim.py` run still passes every target.
**How to apply:** planting validates seeds, not coins. Foreclosure never seizes seeds (`seizable()` reads
only `store.json` rows). Seeds stay out of `store.json`; their prices live in `crops.json`.

### D-142 · 2026-10-09 · CEO · Anyone pulls up any flag; a leaver's flags go with them (P4-33)
Amends D-120. Any player may pull up any flag (`remove_flag`), not only the one who placed it; the
owner's slot frees. `not_your_flag` is gone; the host refuses only `no_flag` (nothing there). When a
player leaves or disconnects, the host removes all their flags (`flags_dropped`). A flag never hides the
trap it stands on: `HoldController.pick` sees through a flag to a target within 1 m behind it
(placeholder), and the flag's pick body sits above a set trap's.
**Why:** CEO 2026-10-09: "auto remove flags on leave or disconnect from that player, allow other players
to remove someone else flags, and that should solve the issue with it overlapping the traps". The
P4-33 QA follow-ups found a leaver's flags could never be removed and a flag's pick body could cover a
trap's.
**How to apply:** doc 01 "Flags" says any player can pull up any flag. `flag_removed` logs `player`
(who pulled it) and `owner` (who placed it); the Dawn Report counts flags still out per owner.

### D-143 · 2026-10-09 · Gameplay Programmer · `apply_roles` carries the role lock (P4-35, needs Director approval)
The `apply_roles` table (peer id -> role id) gains one non-peer key, `"locked": bool`: true when the host
loaded a season (`Game.season_uids` not empty), so its roles stay as saved. `Roles.apply` stores it and
`Roles.locked()` returns it on clients (the host reads `season_uids` directly). `Roles.apply` reads only
`int` keys as peers.
**Why:** OPEN_ISSUES "Found at the P4-23 review" item 1: only the host knew a loaded season locks roles, so a
client's role cards stayed clickable and every pick came back refused with no reason shown.
**How to apply:** readers of the table iterate only `int` keys. The lobby greys every card and shows "Roles
are kept from the saved season." when `Roles.locked()` is true.


### D-144 · 2026-10-09 · CEO · One distinct hat per role, built now (Q-241)
The CEO answered Q-241 with "make different hats now". Each of the ten roles in `data/roles.json` gets its
own low-poly hat model, built in Phase 4 instead of waiting for the DD Phase 5 cosmetics (doc 07 s8).
**Why:** the menu lobby line-up (D-140, P4-35) shows each player's role on their farmer, and placeholder
primitives do not tell the roles apart.
**How to apply:** the 3D Artist builds `assets/models/hat_<role_id>.glb` (P4-36), with the origin at the
inside centre of the band so it sits on a head at 1.74 m. The lobby's `LineUp._hat` loads them in place of
the primitives. The hats are role markers, not cosmetics: wider cosmetics (overalls, picked hats) stay
Phase 5. The D-142 and D-143 numbers are taken by the P4-33 and P4-35 branches still in review.
### D-145 · 2026-10-09 · CEO · 16:9 is the only supported screen shape; the night owl hat stays
The game supports 16:9 screens only (1280x720 and up). 4:3 and 16:10 are out of scope, so the menu
lobby's 3-farmer fit at 1024x768 is not a bug. The night owl hat (P4-36) keeps its tufts as built.
**Why:** CEO, 2026-10-09: "keep owl hat, and 16by9 is enough", answering the P4-35 and P4-36 QA findings.
**How to apply:** layout and screenshot checks run at 16:9 resolutions only.
### D-146 · 2026-10-09 · CEO · Auto-record in-game speech (live clips) instead of the barn recording
The staged barn recording (doc 01 "Recording lines that sound scared") is dropped. The creature and the Dawn
Report use short clips cut automatically from each player's transmitted proximity speech, so the doc 01
"Live clips" mode comes forward from DD Phase 5 and becomes the default voice setting.
**Why:** CEO, 2026-10-09, during a playtest: "can we skip the record in the barn and just have it set to auto
record players in game and use that".
**How to apply:** Keep the per-player voice setting on each player's own machine (doc 01 "Voice settings"),
with Live clips as the default and Off still available in the menu, lobby and pause menu. Off keeps nothing
and deletes kept clips. Doc 01 "Live clips" rules apply: transmitted speech only, at most 3 s a clip, kept for
the session and then deleted, reviewable and deletable from the pause menu, streamer-safe never replays them.
While clips are being kept, the recording light shows steadily (doc 01 "Recording light"); this replaces the
D-013 reading that proximity capture is not "capture". The "Lobby lines" setting and the recording screen
go. Doc 06 s16 settles where clips are cut (sender's machine, as barn chatter was) and how the manifest
shares them (doc 06 s11 clip format, unchanged). Task P4-37.
### D-147 · 2026-10-09 · CEO · Flare shells are buyable in the store
Besides the free reload each dawn (doc 01 Store), the team can buy flare shells in the store. Each shell loads one
shot, up to the gun's capacity (`flare_capacity()`, one more with a Warden). Shells need the flare gun bought.
**Why:** CEO, 2026-10-09 playtest: "the flare gun has no way to refill its ammo so you get only 2 shots total", then
"add buyable ammo" (the dawn reload exists but was not reached in a day-1 session and nothing tells players of it).
**How to apply:** a `flare_shell` row in `data/store.json` with a placeholder price (Game Designer confirms with the
sim, doc 02 s10). The Dawn Report says when the flare gun was reloaded. Task P4-38.
### D-148 · 2026-10-09 · CEO · Phase 4 human playtest skipped; economy tuning waits for a fully playable game
The P4-18 gate runs without human playtest seasons (`tools/qa/playtest/checklist_p4.md` is not required) and
without the economy targets: the sim `compare` within 15 points (doc 02 s18.5) and the "teams sometimes win and
sometimes lose" check move to a later economy pass, once the game is fully playable. Prices added before then
(such as `flare_shell`, D-147) stay `placeholder`.
**Why:** CEO, 2026-10-09: "we will skip the phase 4 playtest, the economy can be fixed after its considered fully
playable".
**How to apply:** P4-18 closes on the automated checks only: each P4 task reviewed, a 4-instance run over ENet,
headless with no new errors. Then STOP 5. The economy pass is a later task; nobody tunes prices against the sim
until it is opened.
### D-149 · 2026-10-09 · CEO · Real recordings for every sound; FilmCow SFX library approved (D-005)
Every game sound is redone from real recordings of its real-life counterpart (an animal from that animal, the
boar signature from a boar and a dragged chain), with 3 options per sound for the CEO to choose. Sources: Freesound
CC0 (D-066) and the FilmCow Royalty Free SFX Library (https://filmcow.itch.io/filmcow-sfx, `license.pdf`):
royalty-free, commercial use allowed, no credit required, not for national government, law enforcement or hate-group
projects. Redistributing the library as a library is not allowed; shipping processed sounds inside the game is.
**Why:** CEO, 2026-10-09 CEO listen: lurk signatures "redo make them sound as close as they can to what the monster is
based on, pull from public libraries and give me 3 options", animals "bad base them off real life animals", then
"base all of the sounds on the real life counterpart also pull up the filmcow sound pack and see if you can use any".
**How to apply:** The CEO's request approves FilmCow under D-005. Downloads stay outside the repo
(`C:\Users\Ockey\fc_dl\recorded\`); only the processed wavs and a source list enter the repo. Log every source with
its file name or Freesound id and license in doc 08 section 13. No recording of a person's voice or name enters the
repo without the CEO's approval (D-067 precedent).
### D-150 · 2026-10-09 · CEO · Live clips: no lobby toggle; P4-37 doc 01 wording approved
The doc 01 group option "no live clips" is dropped and not built. Live clips are controlled only by each player's
own setting (Off / Live clips) and by streamer-safe. The CEO approves the P4-37 doc 01 changes: live clips on by
default, and the barn recording removed (D-146).
**Why:** CEO, 2026-10-09: "skip the lobby option to turn off live clips and approve the design doc". This answers
Q-244.
**How to apply:** When P4-37 merges, mark Q-244 answered and remove the "no live clips" group option from doc 01.
### D-151 · 2026-10-09 · CEO · 3D models: Blender plus free model libraries, edited to fit
The 3D Artist builds models in Blender and may also start from free library models, then edits them to fit
doc 07 (scale, poly budget, palette, materials, pivots). Default sources are CC0 only: Poly Haven, Kenney,
Quaternius, ambientCG (textures) and CC0 items on Sketchfab/OpenGameArt. This matches the D-066 CC0 rule for sound,
and keeps author names out of the repo. Anything under CC-BY or another license needs CEO approval under D-005
first.
**Why:** CEO, 2026-10-09: "have the 3d artist use blender to make models and also pull from any free libraries and
make any changes it needs after it pulls them".
**How to apply:** Downloads stay outside the repo (`C:\Users\Ockey\fc_dl\models\`) and are treated as untrusted.
Only edited `.blend` sources and `.glb` exports enter the repo. Log every source (URL, asset name, license) in doc 07
under a sources section. Exports keep the existing file names, so scenes need no rewiring.

### D-152 · 2026-10-09 · CEO · DD Phase 5 started; STOP 5 closed
The CEO started DD Phase 5 ("start phase 5"). This closes STOP 5 without the human sessions, as D-057 did
for STOP 3; the gate items D-148 waived stay carried (human sessions, sim `compare` within 15 points), as do
the P4-17 CEO listen, Q-150 and Q-122. P4-18 is done. The Director wrote rows P5-01 to P5-08 in
`production/TASKS.md` from doc 01 "Build Plan > Phase 5": spliced clips from live speech (P5-03), next season
(P5-02, P5-04), cosmetics (P5-02, P5-05, P5-06), sounds (P5-07), QA review (P5-08). Live clips are already
done (D-146, P4-37). Splicing is ready now: doc 03 s12.1 has the cut rule and doc 06 "A lure" the segment
list. Next season and cosmetics wait for P5-02, since doc 02 leaves both out of scope. Doc 01 gives Phase 5
no "done when"; the Director's proposal is Q-250 for the CEO. STOP 6 follows P5-08.
**Why:** CEO request; doc 01 "Build Plan > Phase 5" is the source.

### D-153 · 2026-10-09 · CEO · Quirks, Dev toys and Imposter mode join Phase 5
Doc 01 places Quirks, Dev toys and Imposter mode "after DD Phase 4" in no phase. The CEO put all three in
DD Phase 5: rows P5-09 (Quirks), P5-10 (Dev toys) and P5-11 (Imposter mode). The Game Designer sets quirk
numbers and the imposter kit inside P5-02. Dev toys need no design numbers, so P5-10 starts now and builds the
D-044 machine-hash gate that P5-11's dev setting reuses.
**Why:** CEO, 2026-10-09, asked whether the mental illness options and dev trolls were in this phase, then said
yes to adding them (Imposter mode included).

### D-154 · 2026-10-09 · CEO · Overall model upgrade in Phase 5
The CEO asked for an overall upgrade of all models in DD Phase 5. P5-12 upgrades every model in
`assets/models/` under D-151 (Blender plus CC0 libraries) and adds the farmer rig, animations and tint slots
(doc 07 s11.7). P5-13 wires them in: the creature glb replaces the capsule (Q-150), the rigged farmer, and the
built models no code uses yet. P5-13 waits for P5-03, which also edits `game/creature/`. File and node names
stay, so code keeps loading the upgraded files.
**Why:** CEO, 2026-10-09: "do an overall upgrade of all models".


### D-155 · 2026-10-09 · CEO · Next season campaign and imposter win (Q-251, Q-252 item 2)
The CEO approved the P5-02 proposals. Q-251: a campaign is 3 seasons; a won season 3 pays the farm off; a lost
season (final payment missed) ends the campaign and carries nothing; a missed first payment is not a loss.
Resets each season: crops, Prize Pumpkin, Taint, deaths, medical bill, traps, pegboard stock, fuel, flags, day
count, payments. Roles are re-pickable and a new body is picked. Q-252 item 2: the imposter wins only when the
final payment is missed; the first-payment Foreclosure Notice is not an imposter win. Doc 01 "Next season" and
"Imposter mode" get this wording when P5-02 merges.
**Why:** CEO, 2026-10-09: "yes to both".

### D-156 · 2026-10-09 · Director · P5-03 splice decisions; cross-owner edits ratified
P5-03 (spliced lures) passed QA and is merged. The Director adopts its three proposals:
1. A splice travels as a spec String in `apply_lure.source` (`clip:<owner>:<id>@<first>+<count>,...`),
   not doc 06's original dictionary; an exact clip keeps the bare `clip:<owner>:<id>`. Continues P2-04's
   String source, and an old client given a splice skips it as `missing` instead of crashing.
2. Opus packet size is the silence proxy for the word break (`VoiceSplice.word_break`); thresholds are
   placeholders, inference. A real-speech listening test settles them (OPEN_ISSUES).
3. From day 4, every clip lure is spliced when its owner has 2 or more clips. Doc 01 says "spliced clips
   from day 4" with no share; reading it as all of them is inference. The CEO can set a share.
P5-03's edits outside Network & Voice paths are ratified, as D-036 did: doc 03 s12.1 and s12.4 (Game
Designer), `game/creature/creature.gd` (AI Programmer, co-owner on the row), `game/ui/dawn_report_logic.gd`
and its test (Gameplay). All are small and needed for the splice to log and replay.
**Why:** QA PASS (handoffs/P5-03.md "QA review"); the proposals were in the P5-03 handoff.

### D-157 · 2026-10-09 · Director · P5-10 dev toys merged; gate rulings
P5-10 passed QA and is merged. Rulings on its handoff and review notes:
1. No secret salt on the machine-hash gate. The debug-only `--dev-gate-test-hash=` path accepts only the
   running machine's own hash and is dead in release exports (`package_playtest.py` uses
   `--export-release`); anyone who could exploit it already holds the repo and could edit `HASHES`.
2. Safe mode hides the disco beams and the nuke screen glow but keeps the mushroom cloud. The cloud is a
   steady, slowly growing emissive mesh, not a flash, and doc 01 lists "glow" and "mushroom cloud"
   separately.
3. The Director narrowed `_creature_parts()` to visual nodes (a `VisualInstance3D` or a plain `Node3D` such
   as a glb root), so P5-13's sensors and emitters on the creature are never moved by a toy.
4. The Q-261 command gains `2>/dev/null`, so Godot's leak warnings do not crowd the hash.
5. Edits outside Gameplay paths are ratified: `tools/qa/check_logs.py` and `tests/qa/test_harness.py`
   (QA accepted them), `game/net/net.gd` and `game/voice/squeaky.gd` (Network & Voice, co-owner on the row).
**Why:** QA PASS (handoffs/P5-10.md "QA review").

### D-158 · 2026-10-09 · Director · P5-02 merged; later-season targets accepted
P5-02 (Phase 5 design and data) passed QA on its second pass and is merged: doc 02 s21 and s22, doc 03 s22,
`data/` next_season, creature_traits, cosmetics, quirks and imposter, and the 3-season sim. Doc 01 "Next season"
and "Imposter mode" now carry D-155. Rulings:
1. Q-253: later-season targets accepted as placeholders (first payment 80 to 90%; final 50 to 65% in season 2
   and 40 to 60% in season 3; at most 10 points of spread). Season 3 at 5p and 6p sits on the 40% floor.
2. Q-252 item 3: Imposter mode and Quirks default to off in the lobby, as doc 01 says.
3. `fast_legs` leaves the trap-race speed unchanged (the Director's call during the QA fix).
4. The doc 03 s12.1 Splice row keeps P5-03's wording and adds the `splice_master` cap of 3.
Still FOR CEO: Q-252 items 1 (imposter minimum 4 players) and 4 (quirks revealed at season end), Q-254 (savings
capped at 60 coins). Q-255 goes to the P5-04, P5-05 and P5-06 owners; `game/core/data.gd` TABLES gains the five
tables there.
**Why:** QA PASS (handoffs/P5-02.md "QA review"); CEO answers in D-155.

### D-159 · 2026-10-09 · CEO, Director · P5-12 merged; six player colours; missing models tasked
P5-12 (overall model upgrade) passed QA and is merged. The farmer has a 12-bone rig, 9 animations, a `hat` bone,
`mat_farmer_overalls` (player tint) and `mat_farmer_sleeves` (Taint). QA corrected the handoff: the farmer part
nodes are now skinned meshes; P5-13 poses bones, not part nodes, and must set LOOP_LINEAR on idle, walk, run and
crouch. Rulings:
1. Q-267: six player colours for up to 6 players: red #C04040, blue #4070C0, yellow #D0B040, green #50A050
   (3D Artist's proposal, CEO approved), purple #8050B0 and orange #D07830 (CEO asked for 2 more; the Director
   picked them). The doc 07 "Farmer" line is updated.
2. Q-266: doc 07 s11 items with no model get rows P5-14 to P5-17, one per group, under the CEO's "overall upgrade
   of all models" (D-154). P5-08 depends on them.
**Why:** QA PASS with fixes (handoffs/P5-12.md "QA review"); CEO, 2026-10-09: "those colors are good but add 2
more for up to 6 players".

### D-161 · 2026-10-09 · CEO, Director · Imposter minimum and quirk reveal
D-160 is a status-only commit subject (batch 1 in progress) with no entry. Rulings:
1. Q-252 item 1: Imposter mode needs at least 4 players. Doc 01 "Imposter mode" and `data/imposter.json` cite it.
2. Q-252 item 4: the season-end Dawn Report reveals every player's quirk. Doc 01 "Quirks" carries it; P5-09
   builds it (told mid-task).
**Why:** CEO, 2026-10-09: "yes to item 1, yes item 4".

### D-162 · 2026-10-09 · CEO · Savings capped at 60 coins
Q-254: next-season savings (25% of spare coins, rounded down) are capped at 60 coins. Doc 01 "Next season" and
`data/next_season.json` cite it. Rounding down stays a placeholder.
**Why:** CEO, 2026-10-09: "yes cap it 60".
