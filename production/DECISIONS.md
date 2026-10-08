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
