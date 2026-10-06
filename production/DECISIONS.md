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
