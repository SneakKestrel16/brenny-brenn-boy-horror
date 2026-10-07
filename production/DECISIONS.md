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
