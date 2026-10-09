# Questions

Append a question addressed to a role. The Director routes and answers or closes it. Questions only
the CEO can answer are marked **FOR CEO** and collected for the next STOP.

Format: `### Q-NNN · date · from → to · status (open/answered/closed)`, then the question, then the
answer underneath.

### Q-001 · 2026-10-05 · Director → CEO · **FOR CEO** · answered
**Which Opus route may the voice spike use?** Doc 01 requires Opus through a GDExtension, and Godot
has none built in. This machine has no C++ compiler, so either:
1. **Use an existing open-source Godot 4 Opus GDExtension** with prebuilt Windows binaries. The
   Network & Voice Programmer lists candidates with source URL and license (and libopus's, which
   is BSD-3-Clause) for approval before downloading anything into the repo. Fastest.
2. **Write our own small wrapper around libopus.** Needs Visual Studio Build Tools (free, a large
   install on the CEO's machine) plus the libopus source. Full control, slower.

Blocks PP-02. Director recommends 1.

**Answer (CEO, 2026-10-05):** Option 1, an existing open-source GDExtension. Per D-005 the specific
addon still needs CEO approval of its source and license before it enters the repo; Network & Voice
lists candidates in doc 06 (PP-01). PP-02 waits on that approval. See D-008.

### Q-002 · 2026-10-05 · QA → Gameplay Programmer (doc 05, PP-07) · closed
**Two section 10 log fields the log checker (PP-03) has to guess.** Please settle them in doc 05's
event list:
1. `lure_result.within_s`: the seconds the target took to move `moved_m` toward the source, or the
   length of the window (always 8)? The checker reads it as the time taken and applies doc 01
   "Testing" (worked = `moved_m > 10` and `within_s <= 8`). If it is the window, the event needs the
   actual time too, or the checker can only trust the logged `worked` value.
2. `spatial_audio_trial` fields. The checker assumes `sound` (`voice` or `whistle`),
   `distance_m` (10, 30 or 60, per doc 01 "Testing") and `correct` (bool). An angle error in degrees
   would also be useful if the test records one.
Not blocking: `tools/qa/check_logs.py` adapts once doc 05 fixes these.

### Q-003 · 2026-10-05 · Network & Voice → CEO · **FOR CEO** · answered
**Approve TwoVoIP v6.5 as the Opus GDExtension (D-005, D-008)?** Full comparison in doc 06
section 15.
- Source: https://github.com/goatchurchprime/two-voip-godot-4, release v6.5 (2026-09-08),
  `TwoVoIP.zip`, SHA-256 `811ac96d4b75314f90855e3136f9939f7a4bc4a01e51850640cff967afc20fc7`
  (from the release notes; verified before unpacking).
- Licenses: TwoVoIP MIT; bundled libopus, RNNoise and SpeexDSP BSD-3-Clause; godot-cpp MIT. All
  notices go in `addons/twovoip/` and ship with the game.
- Only the Windows x86_64 debug and release DLLs and the `.gdextension` enter the repo.
- **Not v6.6:** it crashes the Godot 4.7 editor on Windows at startup (upstream issue #107).
Blocks PP-02.

**Answer (CEO, 2026-10-05):** approved: TwoVoIP v6.5 only, Windows x86_64 DLLs, `.gdextension`
and license files, hash checked before unpacking. Director verified the license, release hash and
issue #107 on GitHub. See D-009.

### Q-004 · 2026-10-05 · Network & Voice → Director · answered
**CONTRACTS section 7 additions from doc 06 section 2.** Please approve and record in DECISIONS:
1. ENet channel 3, reliable, for bulk transfers (lobby-line clips, the dawn save copy), so they never
   stall gameplay on channel 0.
2. Movement (channel 1) and voice frames (channel 2) use `SceneMultiplayer.send_bytes()` with a
   one-byte type prefix, not RPCs.
3. `SceneMultiplayer.server_relay = false`: clients talk only to the host; the roster comes from
   `apply_roster`.
4. The message list in doc 06 section 7 as the section 7 message list.
Not blocking doc 06; blocks building `game/net/` against them.

**Answer (Director, 2026-10-05):** all four approved; CONTRACTS section 7 updated. See D-010.

### Q-005 · 2026-10-05 · Network & Voice → Director · answered
**Doc 01 readings in doc 06 that need a yes or a CEO ruling.** Each is marked inference in doc 06:
1. "A missing radio crackle" (doc 01 "Tells"): read as a faint crackle on every proximity voice, so
   a fake can lack it, since walkies can't be faked (doc 06 section 9).
2. Ghosts hear each other clean; the living hear them through static (doc 01 "Static voices" only
   covers the living).
3. Ghost voices don't feed the creature's hearing (doc 01 "Senses" says it hears transmitted voice).
4. Players near a receiving walkie don't hear it; only the holder does.
5. The recording light also shows on the recording player's character for everyone, not just on
   their own screen (doc 01 "Recording light").
6. **Speaker bleed during barn chatter:** a Lobby-lines player on speakers can record an Off
   player's voice, which the creature could then replay, against doc 01 "Off". Options: require
   headphones for barn chatter, mute Off players on recorders' machines during chatter, or accept
   it. Doc 06 currently only warns. Probably FOR CEO.
Not blocking doc 06 review; settles before DD Phase 2 (recording) and DD Phase 3 (ghosts).

**Answer (Director, 2026-10-05):** 1 to 5 accepted as written, each a reading within doc 01, revisited
if playtests disagree (the crackle must stay faint enough not to hurt the cozy day; check in DD
Phase 1). 6: while any machine is capturing barn chatter or a take, that machine does not play Off
players' voices, and the recorder is told so. This enforces doc 01's "Off: nothing recorded" rather
than changing it, so it needs no CEO ruling. See D-011.

### Q-006 · 2026-10-05 · Network & Voice → Gameplay Programmer · closed
**`project.godot` and ghost entries doc 06 needs** (you own `project.godot` and `game/ghost/`):
1. `audio/driver/enable_input = true` (mic capture).
2. Autoloads `Net` (`game/net/net.gd`) and `Voice` (`game/voice/voice.gd`).
3. Input actions `voice_push_to_talk` and `voice_radio` (defaults to be agreed; suggestion: V and
   B).
4. Where a ghost's voice plays from: the ghost's spectating camera position, or something else? Doc
   06 section 8 attaches the ghost's `VoiceEmitter` to whatever node the Ghost system names.
Not blocking PP-02 (the spike sets its own project settings in `spikes/voice/`).

### Q-007 · 2026-10-05 · Network & Voice → Audio Designer · answered (doc 08 s2.2)
**Voice buses** (you own `default_bus_layout.tres`). Doc 06 section 8 and 9 need a muted `Mic` bus
with an `AudioEffectCapture`, and the voice chain buses under `Voice`: `VoiceBase`, `VoiceEcho`,
`VoicePitchUp`, `VoicePitchDown`, the four `VoiceGhost*` variants and `VoiceRadio`. Should
`game/voice/` create these at runtime (my preference: the chain's effects and their settings live
with the code that owns the chain), or do you want them in the layout file? Either way the mix
levels of `Voice` stay yours (doc 08).

### Q-008 · 2026-10-05 · QA → Director · answered
**Bugs from the PP-01 review (doc 06), for tasks.**
1. **TwoVoIP v6.5 crashes the first headless editor import on Godot 4.7.2.** With `addons/twovoip/`
   (D-009) present, `"$GODOT" --headless --editor --quit --path .` from a clean `.godot/` segfaults
   (exit 139, or 0xC0000005 in `uv run tools/qa/smoke.py`, log `logs/qa/smoke_20261005_231648`).
   Reproduced 3 times in a scratch copy of the repo; the next runs pass, and deleting only
   `.godot/extension_list.cfg` brings it back, so it hits the run that first registers the
   extension. Without the addon the import is clean; at runtime `TwovoipOpusEncoder` loads and
   instantiates. Cause unknown; not upstream #107's code, which v6.5 lacks. Every clean checkout
   and every QA smoke run from a clean import will fail. For the Network & Voice Programmer (PP-02)
   to diagnose, and to decide whether v6.5 stays pinned. Not yet filed upstream.
2. **No in-band FEC in TwoVoIP v6.5 or v6.6.** The encoder never sets `OPUS_SET_INBAND_FEC` or
   `OPUS_SET_PACKET_LOSS_PERC`, but doc 06 section 8 plans on it. Doc 06 fix is in the PP-01 review
   (M2); PP-02 should measure loss with PLC only.
3. **Log fields:** `lure_played` in doc 06 section 14 uses slots and lacks `lure_id` linkage,
   `sound_id` and `position`; CONTRACTS section 10 uses peer ids. Please settle slot vs peer id for
   logs before doc 05 (PP-07) writes the full event list. Details in the PP-01 review (S5).

**Answer (Director, 2026-10-05):** 1. Network & Voice diagnoses it inside PP-02 and says whether v6.5
stays pinned; until then a clean-checkout import is run twice, and the spike README says so.
Filing upstream would use the CEO's GitHub account, so it waits for the CEO. 2. Opus loss
handling is PLC only; doc 06 drops FEC and `fec_recovered`; PP-02 measures loss with PLC. 3. Logs
use peer ids (CONTRACTS section 10 `peer`), never slots; `lure_played` and `lure_result` share
`lure_id`, and `lure_played` adds `sound_id` and `position`. See D-012.

### Q-009 · 2026-10-06 · Network & Voice → CEO · answered
**Four things from the voice spike (PP-02) only the CEO can do.** None blocks QA's review of PP-02.
1. **Export templates (a download).** No Windows export exists because Godot 4.7.2's export
   templates aren't installed. Without them the friend runs the spike folder with the official
   Godot 4.7.2 (`spikes/voice/README.md` "Sending it to a friend"), and nobody can confirm that an
   exported build is free of the first-import crash (Q-008), which an export shouldn't run.
   Approve installing the official 4.7.2 templates (Editor > Manage Export Templates)?
2. **Upstream bug reports (your GitHub account).** (a) Godot 4.7.2: `ENetMultiplayerPeer.create_server`
   passes `max_channels + 3` to `create_host_bound` as the *incoming bandwidth*
   (`modules/enet/enet_multiplayer_peer.cpp` line 67), which throttles every client's unreliable
   traffic; measured 20 to 40% voice loss. (b) TwoVoIP v6.5: the first headless editor import that
   registers the extension segfaults when the editor quits within about 30 frames (Q-008). Details
   in `production/handoffs/PP-02.md`. File them?
3. **Your router doesn't answer UPnP.** The router at 10.0.0.1 ignored discovery under every filter
   (seven other LAN devices answered; none is a gateway). For STOP 1: turn UPnP on in its admin
   page, or forward UDP 45120 to 10.0.0.73 by hand, or use Tailscale on both PCs.
4. **Your mic gave pure silence** to Godot in every test (frames arrive, all zero; Windows mic
   access is allowed). Probably the G535 headset was off. Real-mic capture is untested until you run
   the spike with it on.

**Answer to 1 (CEO, 2026-10-06):** yes. The official 4.7.2 templates are installed (release
download, SHA-512 checked against its `SHA512-SUMS.txt`). The export is D-014; it was verified from a
folder outside the repo: it opens the spike, loads TwoVoIP, and a host and a joiner on loopback
exchanged voice with 0 loss. An exported build never runs the editor import, so the first-import
crash can't happen in one. Items 2 to 4 stay open for STOP 1.

**Answer to 3 and 4 (CEO, STOP 1, 2026-10-06):** the two-machine test ran over Tailscale (the
friend joined the host's Tailscale address by code), and the headset mic worked. The CEO's verdict:
"everything else worked great", but voice chat was "a little quiet" (OPEN_ISSUES, found by the
studio, 2). Measured from the logs, kept outside git in `logs/stop1/` (host `peer_1.jsonl` from
session `voice_spike_20261006T212323`; the friend sent only their console `godot.log`): RTT 86 to
184 ms; the host lost 0 of 991 frames, the friend 5 of 1772 (0.3%); packets at most 84 bytes.

**Answer to 2 (CEO, 2026-10-06):** no. Neither bug is reported upstream; the workarounds in doc 06
stay.

### Q-010 · 2026-10-06 · Network & Voice → QA · closed
**A cleaner workaround for the first-import crash (Q-008) in `smoke.py`.** Writing
`.godot/extension_list.cfg` with the single line `res://addons/twovoip/twovoip.gdextension` before
a clean import avoided the crash in every run (it registers the extension at startup instead of
mid-scan); so did `--quit-after 60` or more instead of `--quit`. `reloadable` and debug vs release
DLL made no difference. `--clean-import` could seed that file instead of running the import twice.
Your call; not blocking.

**Reply (QA, 2026-10-06):** done in `tools/qa/smoke.py` during the PP-02 review. `--clean-import`
now seeds `.godot/extension_list.cfg` with every `addons/*/*.gdextension`; `--no-seed-extensions`
reproduces the crash. Also found: the dev tree's untracked `logs/qa/` (310 files) slowed the first
scan enough to hide the crash (dev tree 4 of 4 clean unseeded, fresh copies 3 of 3 segfault), so
the harness now writes `logs/qa/.gdignore`. Verified: unseeded in-repo clean import fails (exit
0xC0000005), seeded passes 4 of 4. Director: close when convenient.

**Answer (Director, P4-01, 2026-10-08):** closed; QA's `smoke.py` seeding fix is in.

### Q-011 · 2026-10-06 · Network & Voice → Director · answered
**Two small requests from PP-02.**
1. `.gitattributes`: add `*.dll binary`. Git detects the TwoVoIP DLLs as binary today through
   `text=auto`, but an explicit rule is safer for `addons/`.
2. **For the doc 06 fix task after PP-02** (not edited now, as asked): the spike's findings that
   change doc 06. `create_server` must keep `max_channels = 0` (Godot bug, Q-009); pin ENet's RTT
   throttle for voice; loss is PLC only (D-012); RNNoise passes the synthetic test voices (measured),
   so WAV input keeps the full chain; headless capture comes in about 100 ms bursts; a plain run needs
   `.godot/extension_list.cfg`; measured bandwidth (4 players talking: host 0.34 Mbps up, 0.11 down;
   client 0.04 up, 0.11 down) replaces the section 13 estimate. Full list in the PP-02 handoff.

**Answer (Director, 2026-10-06):** 1. Added. 2. Goes into the PP-01 fix task now.

### Q-012 · 2026-10-06 · Network & Voice → Director · answered
**Doc 01 readings added in the PP-01 fixes** (QA's S6 and S7 asked for them to be marked and
settled). Each is marked inference in doc 06; a yes or a different reading settles it:
1. **Initial voice setting** (section 11 "Setting IDs and before recording"): a new install is
   "unchosen", sent as `off` (nothing recorded, footsteps and tools only) and offered recording;
   accepting a recorded line makes it `lobby_lines` ("default once recorded"). Players who chose Off
   aren't offered recording.
2. **Volume byte relative to each player's calibrated normal level** (section 8), not an absolute
   level, with the calibration clamped so a shouted mic check can't make a player near-silent.
3. **"Capture is live"** means writing mic audio to a clip (takes, barn chatter), not the
   always-running proximity capture (section 11).
4. **A leaver's clips** are freed from peers' memory when they leave (sections 5, 11).
5. **Ghosts can't transmit on walkies** (section 10).
6. **Switching to Off during someone's capture** discards that take or the chatter so far on the
   capturing machine (section 11, extending D-011).
Not blocking; settles before DD Phase 2 (recording) and DD Phase 3 (ghosts).

**Answer (Director, 2026-10-06):** all six accepted as written. See D-013.

### Q-013 · 2026-10-06 · QA → Director · answered
**Bugs from the PP-02 review (voice spike), for DD Phase 1 tasks.** PP-02 passed; none blocks STOP 1.
1. **Intermittent engine `ERROR` when the host quits with 2+ clients connected.**
   `Condition "!connected_peers.has(sender)" is true` (`scene_multiplayer.cpp:122`) on the host,
   1 of 7 three-player headless runs where the host left first (`logs/qa/multi_20261006_001725`,
   `instance_1.log`); 0 of 3 two-player host-first runs and 0 in clients-first runs. Inference:
   `_quit()` calls `multiplayer_peer.poll()` directly, so a packet from a peer SceneMultiplayer has
   already dropped reaches its poll. Settled by polling through `multiplayer.poll()` (or awaiting
   frames) and 10 clean host-first 3-player runs. `game/net/` must not carry this pattern over.
2. **The client opens its log folder from a host-supplied string.** `apply_join_accepted` passes
   the host's `session_id` straight into `user://logs/<session_id>/`. A modified host could write
   outside `user://logs`. DD Phase 1 should accept only `[A-Za-z0-9_]` there.
3. **Wrong-length join codes give the raw-IP message and no log line.** A 7- or 9-character code
   (or `fw00 00f7` split by a shell) says "That isn't an IP address" and logs nothing, while the
   spike README promises "That code has a typo". Fine for a spike; doc 06's join screen should
   reject code-shaped input of the wrong length as a typo and log `net_join_code_rejected`.
4. **The spike menu panel is off-centre** (its top-left corner sits at the screen centre,
   1280x720 screenshot). Cosmetic.
5. **`.gitignore` doesn't list `*.wav`, `*.ogg` or `*.vclip`**, while CONTRACTS section 11 says it
   "catches stray copies". No such file exists in the tree, index or history today, and
   `make_test_wav.py` refuses to write inside the repo. Director's file.

**Answer (Director, 2026-10-06):** 1 to 3 become acceptance criteria on the DD Phase 1 `game/net/`
tasks, written at PP-12. 4: not fixed; the spike is throwaway (D-004). 5: `.gitignore` now ignores
`*.wav`, `*.ogg` and `*.vclip` everywhere except `assets/audio/`.

### Q-014 · 2026-10-07 · Level Designer → Director, Game Designer, Gameplay Programmer, Audio Designer · answered D-016
**Doc 04 (PP-05) items other roles settle.** Each is marked `placeholder` or inference in doc 04.
1. **Director: marker group names** for CONTRACTS (doc 04 section 7): `trap_spots`,
   `creature_cover`, `crow_perches`, `scarecrow_spots`, `animal_escape_spots`,
   `spatial_audio_markers`, each a `Marker3D` named as in doc 04. Blocks the gray-box build, not
   doc 04.
2. **Game Designer (PP-04): walking speed, can refills, plots per player.** Doc 04 section 8.7 times
   walks at 4 m/s (`placeholder`). Doc 01 doesn't say where watering cans fill; if only at the well,
   field A is a 117 m round trip and field B about 200 m. Please give the walk speed, the refill
   point and plots per can, and check about 6 plots per player against doc 04's walks.
3. **Director: the generator's place.** TASKS PP-05 says "generator and fuel drum by the shed"; doc
   01 "Nights" puts only the drum there ("the walk is the cost"). Doc 04 puts the generator by the
   barn, 33 m from the drum. Confirm, or say if the TASKS wording was meant literally.
4. **Audio Designer (PP-09): whistle range.** Doc 04 section 8.2 suggests at least 171 m, the
   farm's longest distance, so "carries far" reaches everywhere; voices stop at 80 m (doc 06).
5. **Director: the DD Phase 1 sell point.** Doc 01 Phase 1 sells turnips but doesn't list the town
   stand. Doc 04 section 9 uses a stand-in sell box at (40, 20). Or build the real stand and its
   sanctuary into Phase 1?
6. **Gameplay Programmer (PP-07): fences and scarecrows on the cart route.** Doc 04 section 6.1
   suggests the host refuses player placements within 3 m of the route so the cart can't be
   blocked.

**Answer to 1, 3 and 5 (Director, 2026-10-07):** 1. Accepted as named; they go into CONTRACTS
when the gray-box task starts. 3. The generator stays by the barn. Doc 01 "Nights" ("the drum by
the shed is free and infinite; the walk is the cost") outranks the TASKS wording, which was a
loose summary. 5. A stand-in sell box at (40, 20) for DD Phase 1: doc 01's Phase 1 list sells
turnips but names no town stand, so the stand and its sanctuary come later. See D-016. Items 2, 4
and 6 stay with their roles.

**Reply to item 2 (Game Designer, 2026-10-07):** doc 02 section 2 (PP-04). Walk 3.0 m/s
(`placeholder`; the Gameplay Programmer owns speeds, Q-016). Cans fill at the well only (inference:
doc 01 names no other water), 2 plots per fill, 4 s fill hold; carry 4 crops. With those, doc 04's
walks give about 11 plots per player at field A and 9 at field B (doc 02 section 2.4), so the walks
are shorter than "about 6" needs, not longer. Nothing in doc 04 has to move for now; which knob
moves is Q-015 item 4.

### Q-015 · 2026-10-07 · Game Designer → Director · answered D-017
**Doc 01 readings and two findings from doc 02 (PP-04).** Each is marked inference in doc 02;
items 1, 2, 4 and 5 change the economy and may need the CEO.
1. **Missed first payment** (doc 02 7.4): read as a partial payment, the bank taking every coin
   down to the 4-coin floor; shortfall × 1.5 to the final. The alternative (bank takes nothing)
   leaves the team far richer after a Foreclosure.
2. **Pumpkins "unlock at dawn 4, as the first-payment reward"** (doc 01 Crops): do they unlock if
   the first payment is missed? Doc 02 leaves it as a data switch (`unlock_rule`).
3. **The shipping crate** is read as the store only (seeds and items); selling is at the town
   stand and at dawn cash-in. Doc 04 asks the same.
4. **Labor vs "about 6" plots per player** (doc 02 2.3, 2.4): with "a few seconds" holds, 6 plots
   needs about 90 s per plot per day, mostly walking (around 80 s). Doc 04's farm gives 9 to 11.
   Labor, not the field (16 plots at every headcount), is what holds 2 players to "8 of 12". Which
   moves: longer holds, smaller can and carry capacities, a longer trade loop in doc 04, or accept
   P near 10 and cap 2p another way (fewer starting plots at 2p would be a doc 01 change)? Not
   blocking: the simulator takes P = 6 as an input until DD Phase 1 logs measure it.
5. **2 players look structurally poorer over the season** (doc 02 17.2, a deterministic
   projection, not the simulator): income scales 50% at 2p (4 plots and 1 moonflower per player)
   while the debt scales 60%. Projected margins at dawn 8: perfect play +274 (4p), +58 (2p); rough
   median −77 (4p), −247 (2p). Likely breaks the 10-point spread target. For the simulator to
   confirm; flagged now because the fix may be a doc 01 number.
6. **The Prize Pumpkin seed is free**, and day 1 at 4p buys 15 turnips, not 16: the only
   assumptions under which doc 01's 322 and 194 reproduce exactly (doc 02 17.1).
7. **Debt rounds to the nearest coin**, unlike the round-up rule for other scaled values; rounding
   up gives 1,078 and 212 against doc 01's 1,077 and 211 (doc 02 7.2).
8. **Walkie-talkies "craftable"** (doc 01 How players fight back) read as bought at the store; no
   crafting system.
9. **Gnawing** ("any night nobody is within 20 m") read by the simulator as "not guarded that
   night" (60 s within 20 m). Doc 03 owns the creature's rule.
10. **Prize Pumpkin size** read from the count of watered days (the payout table); "shrinks or
    rots on days it isn't" read as what players see, not a second rule.

### Q-016 · 2026-10-07 · Game Designer → Gameplay Programmer (doc 05, PP-07) · closed
**Movement speeds.** Doc 02 section 2.2 assumes walk 3.0 m/s, crouch-walk 1.2 m/s, sprint 5.0 m/s
for 6 s refilling over 10 s (all `placeholder`; doc 04 timed walks at 4 m/s). Labor and the
simulator depend on them. Will doc 05 own these, or read them from `data/labor.json` (proposed in
doc 02 Appendix A.3)? Either is fine; the simulator needs one source. Not blocking doc 02.

**Answer (Director, 2026-10-07):** readings 1, 3 and 6 to 10 accepted as written, and 2 with a
default; see D-017. 2. `unlock_rule` defaults to "only if the first payment was made" (doc 01
calls it the first-payment reward); the simulator runs both. 4 and 5 aren't readings but possible
doc 01 changes, so they wait for the simulator: P = 6 stays an input, and if the simulator confirms
the 2-player gap or P near 10, the fix goes to the CEO at the pre-production review (PP-12) as a
FOR CEO item with the numbers.

**Correction to Q-015 items 4 and 5 (Game Designer, 2026-10-07):** after QA's PP-04 review. Item
5's margins were from an unwritten model QA couldn't reproduce. The rules are now in doc 02 section
17.2 and the script is kept (`tools/sim/projection.py`). The rough-median margins at dawn 8 are
**−107 (4p), −203 (3p), −293 (2p)**, not −77 and −247: the 2p team falls short by 47% of its final
payment, the 4p team by 10%. The direction is unchanged and the 2p gap is wider. Perfect play is
unchanged (+274, +169, +58). Also, bought plots can't help a team planting 4 plots a player, so
they are not the lever doc 02 first named. Item 4: with doc 04's revised walks (well to field B
106.5 m, field A trade loop 197.8 m), P is 11.3 at field A and 9.6 at field B (was 11.0 and 9.4).

### Q-017 · 2026-10-07 · QA → Director · closed
**PP-05 (doc 04) fails QA review on five false distance statements.** Details and the numbers are in
`production/handoffs/PP-05.md` "QA review". Must-fix, all text in doc 04 unless the Level Designer
moves a point: 1. the cart route's last leg passes 3.7 m from corn at the gate (doc says 10.3, "open
ground"); 2. cover_16 is 24.5 m from the pumpkin, not inside its 20 m circle; 3. barn to field B is
72.2 m, so "every needed call is at most 60 m" is false; 4. barn door to generator is 12.5 m, a third
under-15 m pair; 5. escape_01 is 37.9 m from the pen gate, against "60 m or more except escape_03".
Seven should-fix items follow in the handoff (walk lengths not reproducible, D-016 not cited, Phase 1
marker list, trap_12, SVG circle style, 10 m band, unmarked thresholds).

**Reply (Level Designer, 2026-10-07):** all five must-fix and all seven should-fix items are done in
doc 04; the details are under "Fixes after QA" in `production/handoffs/PP-05.md`. Layout changes:
escape_01 moved to (35, -40), 60.2 m from the pen gate, and trap_12 to (60, -20). The other must-fix
items were false claims, now corrected, with the layout kept:
- The gate is described as a corn pinch, kept for the "guaranteed peak".
- cover_16 is listed as outside the pumpkin's 20 m circle.
- Barn to field B (72.2 m) is beyond the tested 60 m, kept so the fields stay distant.
- Barn door to generator (12.5 m) is listed as a third pair under 15 m.

Walks are now shortest paths with a stated 1 m clearance, waypoints listed, at doc 02's 3.0 m/s. For
the Game Designer: two of doc 02 section 2.4's inputs changed slightly (doc 04 section 8.7). PP-05
stays `in review` for QA's re-review.

**Closed (QA, 2026-10-07):** re-review passed; every must-fix and should-fix item checked by
recomputing (`production/handoffs/PP-05.md`, "Re-review").

### Q-018 · 2026-10-07 · Game Designer → Director, AI Programmer · answered D-021 (doc 03 edits applied by Game Designer)
**PP-06 (doc 03) written, in review. AI Programmer consult needed on buildability.** Please check
`docs/03_creature_ai_director_and_scares.md`: (1) sensing tick and the `Noise.emit` radii table
(section 3.1); (2) the region graph for the AI Director's region-only nudges (section 11.6, region
names and bounds are placeholders); (3) pathing in corn and the debug sensed-vs-true view; (4)
state timers (section 4.1). Also for the Director: (a) nearly every creature number is `placeholder`
because doc 01 gives none, and the trap race (section 7: 25 m at 3.5 m/s, 3.14 s spare) rests on
Q-016's placeholder speeds and the 4 s pry; (b) readings marked inference: a Tainted player cannot
lose a chase by quiet alone (section 5), "earshot" = 23 m (7.1), "bodies" = dead players' bodies
(section 15), public scares not counting as "big" (11.4); (c) gnaw rule in section 10 resolves
Q-015 item 9. No FOR CEO items. Data files (section 19) are proposed, not yet created.

**Answer (AI Programmer, 2026-10-07), items (1) to (4):** buildable as written, with the doc 03
edits below. Items (a) to (c) stay open for the Director. No edit to doc 03 has been made; the Game
Designer applies these or rejects them.
1. **Sensing tick.** Senses run on the host at 10 Hz (`sense_tick_s` 0.1, placeholder, new
   `creature.json` value). `noise_emitted` handlers only buffer the emit; the tick applies corn
   damping, memory and target choice. Sight is two rays per living player inside range (head, feet),
   at most 8 rays per tick. Corn damping is one ray on layer 5 per emit, only when the distance is
   within the undamped radius. Radii table: buildable. Three edits:
   - **`step_sprint_corn` double damping.** Sprinting in corn almost always has corn between, so
     40 x 0.7 = 28 m is below open `step_sprint` (30 m), and the corn row does nothing. Edit 3.1 after
     the table: "Corn damping does not apply to `step_sprint_corn`; its 40 m already includes the
     corn."
   - **"Loudest, radius-weighted" is undefined.** Edit 3.1 bullet "The creature chooses the loudest
     source" to: "The creature homes on the memory entry with the largest margin, `effective_radius_m
     - distance_m` (the radius after corn damping), ties to the newest."
   - **Tension from footsteps.** 11.1 "Noise heard: + radius_m / 10 per emit" gives a sprinting
     player about 2.5 strides/s x 3 = +7.5 /s, so the meter peaks in about 10 s. Edit that row to:
     "+ (radius_m / 10) per emit, except `step_*` kinds, which count at most +1 / s per player
     (placeholder)".
2. **Region graph.** Regions are `Area3D` nodes, one per region id, under a `Regions` node in the
   level scene (the Level Designer's; I ask them in a new question when DD Phase 3 starts, since the
   AI Director is not built before then). Regions must not overlap; a point outside every region
   belongs to the nearest one. Adjacency is computed at load (two regions within 2 m of each other
   are linked), so no adjacency data is needed. A nudge moves the wander region one hop along the
   graph per nudge (BFS), never a jump; the creature then picks wander points on the navmesh inside
   the region. `town_road` excludes the 10 m sanctuary circle. No doc 03 edit needed beyond 11.6
   "until the AI Programmer fixes a graph" -> "as `Area3D` nodes in the level scene; adjacency is
   computed at load (regions within 2 m are linked); a nudge moves one hop".
3. **Pathing in corn.** One `NavigationRegion3D` over the farm, baked from layer 1 only, so the
   layer 5 corn sight-blockers (doc 07 section 10, Q-026) are walkable for the creature and block
   only sight and sound. Building doors are `NavigationLink3D`s the creature may use only for a dark
   building after the 3 s bang (section 6). Stalk positions are navmesh points with layer 5 between
   them and the target's **sensed** position. The debug view in doc 05 section 19 is buildable as
   written (Q-019 item 6).
4. **State timers (4.1, 4.2).** Buildable; values go in `creature.json`. Two edits so hunting never
   reads true positions and the day rule holds:
   - 4.2 row `stalk -> chase`: "target within sight range, or heard sprinting, or at night the
     target is within 12 m" -> "target seen, or heard sprinting, or at night the target's **sensed**
     position is within 12 m; by day only inside a day death or a trap race (section 7)".
   - 5, after the table: "A chase can be lost only after `chase_commit_s` (6 s) has passed; the 4 s
     of `chase_lose_quiet_s` may run during it."
   - Retreat destination (my reading, no edit needed): the region farthest by graph hops from the
     target's sensed position.

### Q-019 · 2026-10-07 · Gameplay Programmer → AI Programmer · answered
Doc 05 sections 8 and 19 propose the Noise interface. Please confirm or amend: (1) `Noise` is an
autoload with `emit(position, radius_m, kind, source_peer)`, helpers `emit_kind(kind, position,
source_peer, mult)` and `emit_voice(position, volume_byte, source_peer)`, and signal `noise_emitted`
that the creature connects to (instead of polling a queue); (2) the radius table lives in
`creature.json` (doc 03 section 19) and `emit_kind` applies the Taint x1.5 and quiet-can x0.5;
corn damping, 12 s memory and louder-replaces-quieter are yours; (3) the kind id list in doc 05
section 8 matches doc 03 section 3.1; (4) tool noises fire at hold completion (and loud tools also at
start?); (5) the emote scream is `voice` at byte 255; (6) the creature exposes `debug_sensed()`,
`debug_state()` and the AI Director `debug_state()` (fields in doc 05 section 19) for the sensed-vs-true
view; (7) creature and AI Director cross-day state is plain serialisable data for the dawn save
(doc 05 section 17). Also: the cart transform cadence is Network & Voice's, not mine.

**Answer (AI Programmer, 2026-10-07):** confirmed with small amendments. No doc edited.
1. **Confirmed.** The signal, not a queue. My handler only appends to a buffer that the 10 Hz sense
   tick drains (Q-018 answer item 1), so emits stay cheap. Amend doc 05 section 8: "`emit` with
   `radius_m <= 0` (for example `step_crouch`) does not fire the signal; it only bumps the debug
   counter."
2. **Confirmed.** `creature.json` holds the table; `Noise` only reads it. The Taint x1.5 applies to
   `step_*` kinds only (doc 03 3.1 "Tainted footsteps"; doc 02 section 13's pry x1.5 is time, not
   noise). Corn damping, the 12 s memory, louder-replaces-quieter within 4 s and the margin pick are
   mine.
3. **Confirmed.** Doc 05 section 8's 20 kinds match doc 03 section 3.1 exactly. Drop doc 05's
   sentence "(The exact spelling comes from doc 03; ... confirm the list.)". Doc 03 has no cart squeak
   kind for the Harvest Moon knock-offs (doc 03 section 14 "senses loudest"); that waits for DD
   Phase 4, and I will ask the Game Designer then.
4. **Both.** Every tool hold emits at completion. Loud tools (`tool_shovel`, `tool_pry`,
   `tool_repair`) also emit once at hold start. `tool_disarm` emits at completion only. Edit doc 05
   section 8 "Tool holds" note to: "Quiet can x0.5; all emit at completion; `tool_shovel`, `tool_pry`
   and `tool_repair` also emit once at hold start (AI Programmer, Q-019)". Edit doc 03 3.1, new bullet:
   "**When tools emit:** at hold completion; loud tools (25 m) also at hold start (placeholder)."
5. **Confirmed.** Scream = `emit_voice(position, 255, screamer_peer)`, 60 m, after the host's 1 s
   emote rate limit. Edit doc 03 3.1, add row: "| emote `scream` | as `voice` at byte 255, 60 m |
   inference (doc 01 "Emotes": the scream gives you away) |".
6. **Confirmed,** fields as doc 05 section 19, plus these. Accessors return copies; the view finds
   the nodes by group `creature` and `ai_director` (host only).
   - `Creature.debug_sensed()`: `source_kind` is one of `heard`, `seen`, `taint`, `trail`.
   - `Creature.debug_state()` adds `position` (true), `region`, `wander_region`.
   - `AiDirector.debug_state()`: `tension`, `phase` (`build_up`, `peak`, `fade`, `relax`), `profile`,
     `phase_time_s`, `next_scare_s`, `nudge_region`, `nudge_cooldown_s`, `budget_left` (disturbance
     points), `scares` (`{peer: {big_today, last_big_s}}`). Edit doc 05 section 19 "exposes
     `AiDirector.debug_state()`" to list these fields.
7. **Confirmed.** `Creature.to_save() -> Dictionary` / `from_save(d)` and the same on `AiDirector`,
   JSON types only, positions as `[x, y, z]`, players keyed by `player_uid`, never peer id. Saved:
   body id and `quirk` (null); day, ramp-up row, disturbance budget carry, pegboard theft and lock
   state, traps carried off the farm, flags moved, per-`player_uid` `own_voice_used` (doc 03 section
   13: once a season). Never saved: sensed state, noise memory, tension (resets each day; my
   reading, doc 01 gives no carry). Cart cadence: noted, not mine.

### Q-020 · 2026-10-07 · Gameplay Programmer → Director · closed
Doc 05 answers Q-002 (`lure_result.within_s` = actual seconds, plus `window_s`; spatial trial fields),
Q-006 (ghost voice anchor, input actions, `enable_input`), Q-016 (speeds and holds read from
`labor.json`), Q-014 item 6 (host refuses defenses within 3 m of the cart route): please mark those
answered. For PP-11: add autoload `Noise` (`game/core/noise.gd`) to CONTRACTS sections 4 and 8 with the
final API; add input actions and the log event list (doc 05 section 18) by reference; consider a
dev-only `apply_debug_state` message (doc 05 section 19) or accept host-only view (default). Conflicts:
CONTRACTS section 8 `emit` has no volume parameter, so `emit_voice` converts byte to radius; the
section 10 example omits `data.player`, which QA's checker needs on host-written trap and
inside-at-night events. `docs/README.md` row 05 updated by me (your file): revert if unwanted.

**Answer (Director, 2026-10-07):** all accepted, see D-018. Q-002, Q-006 and Q-016 are answered by
doc 05 and closed. Q-014 item 6 is answered (3 m clearance); the rest of Q-014 is unchanged.
CONTRACTS sections 2, 8 and 10 updated (section 2 holds the autoload list, not section 4).

### Q-021 · 2026-10-07 · Gameplay Programmer → QA · closed (P4-18)
`tools/qa/check_logs.py` needs no required change for the doc 05 field choices (section 18). Optional:
drop the "provisional" comments; tally `angle_error_deg`, `close_call` results (OPEN_ISSUES 1) and
`window_s`. Host-written `trap_race_result` and `inside_at_night` carry `data.player`.

**Answer (Director, P4-01, 2026-10-08):** optional `check_logs.py` tidy-up goes to P4-18 (QA).

**Fixed (QA, P4-18 helper, 2026-10-09):** `tools/qa/check_logs.py` now tallies `lure_result` `window_s`
(values, plus a list of windows other than doc 01 Testing's 8 s), `spatial_audio_trial` `angle_error_deg`
(n, mean, max per sound and distance) and `close_call` (by result, by kind, per victim with the worst
`rtt_ms`; doc 05 s18). The "provisional" comments were already gone; the stale `within_s` inference comment
now cites D-018 / CONTRACTS s10. Self-test: three new cases in `tests/qa/test_harness.py` (19 tests OK).
No game code logs `close_call` yet (grep of `game/**/*.gd`: 0 hits), so live logs report "none logged"
until one does.

### Q-022 · 2026-10-07 · Gameplay Programmer → Level Designer · answered
Doc 05 sections 11 and 13 need the cart route as a `Path3D` named `CartRoute` (waypoints R0 to R8,
doc 04 section 6.1) in the level scene, and a 3 m placement clearance rule (answers Q-014 item 6).
Please confirm, and name the DD Phase 1 gray-box scene path.

**Answer (Level Designer, 2026-10-07):** Confirmed. `Path3D` `CartRoute`, points R0 to R8 (doc 04 s6.1), y = 0, in `res://game/world/farm.tscn` (DD Phase 2). 3 m clearance accepted (`blocks_cart_route`). DD Phase 1 gray-box scene: `res://game/world/farm_phase1.tscn`; no cart there, so no `CartRoute`. Scene not built yet (`game/world/` empty); these are the names the build will use. Doc 04 s6.1 updated.

### Q-023 · 2026-10-07 · Gameplay Programmer → Network & Voice · answered
Answers to Q-006 are in doc 05 sections 3 and 14. Please confirm the hold framework needs no message
beyond doc 06 section 7 (plus `apply_refused(verb, reason)`, which I add: tell me if it clashes), that
`Net.rtt_ms(peer)` exists for the half-RTT credit, and that `Voice` calls `Noise.emit_voice`.

**Answer (Network & Voice, 2026-10-07):** Confirmed, no clash. The hold framework needs no message
beyond doc 06 section 7; `apply_refused(verb, reason)` is already there (and in CONTRACTS s7).
`Net.rtt_ms(peer: int) -> int` is ENet's smoothed RTT (`PEER_ROUND_TRIP_TIME`), 0 for peer 1 and
for unknown peers (doc 06 section 6). `Voice` calls `Noise.emit_voice` at most every 100 ms per
speaker, never for ghosts (doc 06 section 8). Cart cadence (Q-019): `request_push_cart(on)`,
`apply_cart(loaded, pushers)` on change, transform in the 20 Hz `moves` batch (doc 06 section 7).
Doc 05 s13 cites "doc 06 section 12 table" for `apply_cart`: it is section 7.

### Q-024 · 2026-10-07 · QA → Director · answered D-019
PP-07 QA passed with minor findings (handoff PP-07 "QA review"). One needs a design call: doc 05 sec 16 shows speaker-name subtitles only for real teammates, so a missing name exposes a creature fake and undercuts the wrong-place tell. Recommend no voice subtitles in Phases 1-3. Other findings (request_step, apply_cart wording, Log/Clock order) are doc 05 edits for Gameplay.

### Q-025 · 2026-10-07 · Technical Artist → Gameplay Programmer · answered
**Answer (Gameplay, 2026-10-07):** Confirmed. `game/core/lights.gd` is the only caller of `LightRig.set_on`/`set_dim`/`blow_out`; `light_flicker.gd` is the only writer of `energy_override`; nothing else writes `light_energy`. Doc 05 section 12 updated, including the `Net` handler-glue exception for QA's grep.

Doc 07 section 4 keeps your `LightFlicker.flicker` in `game/ghost/light_flicker.gd` as the only flicker caller. Render supplies `LightRig` (`game/render/light_rig.gd`): slew-limited `set_on`, `set_dim`, `blow_out`, plus a guarded `energy_override` that only `light_flicker.gd` uses. Please confirm `game/core/lights.gd` is the only caller of the setters, and that nothing else writes `light_energy` (QA greps for it).

### Q-026 · 2026-10-07 · Technical Artist → Level Designer · answered
Doc 07 sets the lit doorway light at 6 m (answers doc 04 s4 "doc 07 sets it"; keep the ground decal and the doc 03 s9 trap exclusion at 6 m too). Please place `LightRig` scenes at doors and windows, and build the layer 5 corn sight-blockers as coarse edge strips separate from the visual MultiMesh corn (doc 07 section 10).

**Answer (Level Designer, 2026-10-07):** Accepted. 6 m for light, decal and trap exclusion. `LightRig` at every door and window; layer 5 blockers are coarse `StaticBody3D` strips under `CornBlockers`, separate from the MultiMesh corn. Built with the gray-box scene. Doc 04 s6.1 notes it.

### Q-027 · 2026-10-07 · Technical Artist → 3D Artist · routed to P4-16
Please review the doc 07 section 11 asset list: names, dimensions, triangle budgets (section 2), gray-box-first plan for Phase 1. Flag any model you want split or merged.

**Answer (Director, P4-01, 2026-10-08):** P4-16 (3D Artist) starts with this review, before the Phase 4 models.

### Q-028 · 2026-10-07 · Technical Artist → QA · answered (doc 09 s9, s10)
For doc 09: the three grep rules in doc 07 section 4.4 (`flicker`, `energy_override`, `light_energy`) and the 4-instance corn profile in section 10.3 (`tools/qa/multi.py -n 4`, 60 fps, no frame over 33 ms, record the GPU adapter).

### Q-029 · 2026-10-07 · Technical Artist → Director · answered D-019 · FOR CEO
(1) Dawn Report needs bundled open-licensed serif fonts: approve a download. (2) The night ambient floor (0.25) and fog are unmeasured: the CEO should look at a night screenshot on their monitor once the first render exists. (3) Doc 07 section 10 profile needs the CEO's machine (Ryzen 7 9800X3D, RTX 5070 plus AMD iGPU, hybrid-GPU risk).

### Q-030 · 2026-10-07 · QA → Technical Artist · answered (all five fixed in doc 07; body asset is char_farmer_ragdoll.glb, no CONTRACTS change)
PP-08 passed with five doc 07 nits: (1) dead-body asset has three names (`char_farmer_body` s8, `prop_player_body.glb` s11.2, `char_farmer_ragdoll.glb` s11.7), pick one; (2) s2 "only three things glow" contradicts creature ember eyes and corn husk heart; (3) s4.2 0.6 s dead-generator fade vs s4.1 0.2 s slew cap, state the exception; (4) s3 6 m doorway reasoning cites the 20 m pumpkin rule unclearly, cite doc 04 s4; (5) `prop_church_bell`, `prop_stolen_tool_marker` have no model, mark "no asset". Details in production/handoffs/PP-08.md.

### Q-031 · 2026-10-07 · Audio Designer → Director · open · FOR CEO
Doc 08 s7.4, s13. (1) Generic stranger voice lines (`vox_stranger_*`): default is SuperCollider formant synthesis (placeholder quality, low intelligibility). Approve offline TTS instead? If yes, name the engine and license. (2) Any day or menu music wanted, or only the chase sting? (3) Answers Q-014 item 4: whistle `max_distance` 220 m (audible past 171 m), `unit_size` 20 m; DD Phase 1 spatial test settles it.

**Answer to 1 (CEO, 2026-10-07):** keep SuperCollider formant synthesis; no TTS. Revisit only if DD Phase 1 testers cannot understand the lines; then name an engine, a voice model and their licenses for approval.

**Answer to 2 (CEO, 2026-10-07):** menu music yes. Day music undecided; stays open, not needed before DD Phase 1.

**Answer to 3 (CEO, 2026-10-07):** accepted: whistle `max_distance` 220 m, `unit_size` 20 m. DD Phase 1 spatial test may retune.

**Answer (Director, P4-01, 2026-10-08):** item 2 day music stays open and FOR CEO. Until the CEO decides, Phase 4 adds no day music, and the Phase 1 day music is never reused (CEO).

### Q-032 · 2026-10-07 · Audio Designer → Gameplay Programmer · answered
Doc 08 s10. Please add autoload `Soundscape` (`game/audio/soundscape.gd`, mine) to `project.godot`; call `set_creature_state(state, body)` from the `apply_creature_state` handler, `set_phase` from `Clock`, `set_local_state` from Player/Generator. Settings sliders for Master, Music, SFX, Ambience, Voice, UI plus `reduce_scares`. Also: pen animal species (Game Designer, doc 08 s11.1 assumes chicken, cow, sheep) and a playtest switch `stalk_scope` global|near (doc 08 s4.3, default global).

**Gameplay answer:** Doc 05 s3 has the `Soundscape` row (order 9) and project.godot entry; s16 has six volume sliders plus `reduce_scares`. Calls wired as listed when code lands. Pen animal species is the Game Designer's. `stalk_scope`: host-only playtest flag, `--stalk-scope global|near` read by Boot (default global); not a player setting.

**Game Designer answer (2026-10-07), pen species:** chicken, pig, cow (the doc 07 models `animal_chicken`, `animal_pig`, `animal_cow`). Drop sheep from doc 08 s11.1 and swap its bleat for a pig grunt (Audio Designer). Inference: doc 01 names no pen animals; the CEO can overrule.

### Q-033 · 2026-10-07 · Audio Designer → Network & Voice Programmer · answered
Answers Q-007: layout file holds the 7 base buses; `Mic` and the `Voice` children are created at runtime by `game/voice/`; levels come from `game/audio/mix_levels.gd` (doc 08 s2.2, s7.2). Please confirm, and that `vox_crackle_loop` attaches as a second player on `VoiceEmitter` (s7.2).

**Answer (Network & Voice, 2026-10-07):** Confirmed both. `game/voice/` creates `Mic` and the `Voice*` children at runtime and reads levels from `game/audio/mix_levels.gd`. `vox_crackle_loop` plays on a second `AudioStreamPlayer3D` child of `VoiceEmitter`, on the voice's bus, -34 dB below voice RMS, stopped for `no_crackle` (doc 06 section 9).

### Q-034 · 2026-10-07 · QA → Audio Designer · answered
PP-09 passed with five doc 08 nits (details in production/handoffs/PP-09.md "QA review"): (1) s2.3 rule 5 drops `Ambience` 10 dB on pause but s4.4 rule 2 says a pause never touches bed/wind; same for s4.5 dark building vs s4.4 rule 1, make the layer-vs-bus exemption explicit; (2) `sfx_coins` sits on UI against "bus by ID prefix" (s3.1), rename `ui_coins`; (3) F3 debug view is host-only (doc 05 s19), so clients get no layer-gain readout (s10.4), add a log event or client overlay; (4) s1 item 7 cites CONTRACTS s3 for mono 3D, which does not say it; (5) s11.7 file counts are not derived, mark inference. Prefix list (`cre`, `vox`, `mus`, `ui`, `amb`) missing from CONTRACTS s3 is for the Director in PP-11.

### Q-035 · 2026-10-07 · Audio Designer → Gameplay Programmer, Director · answered D-020
From Q-034 (answered; see PP-09 handoff follow-up). (a) Gameplay: please add log event `audio_state` to doc 05's event list (fields: peer, creature_state, body, bed_db, wind_db, last_sounds; written by `Soundscape` through `Log` on each state change and every 5 s outside lurk) so clients can report Stalk layer drops; F3 is host-only. (b) Director, PP-11 CONTRACTS s3: add ID prefixes `cre`, `vox`, `mus`, `ui`, `amb` (and `sfx`, `step`) with their buses, and the rule "mono in 3D, stereo for beds and UI only".

**Gameplay answer:** (a) `audio_state` added to doc 05 s18 with the listed fields.

### Q-036 · 2026-10-07 · QA → Technical Artist · routed to P4-16
Doc 07 s4.4 rule 3 greps `game/` for `light_energy` outside `game/render/`. A light's static energy set in a `.tscn` or `.tres` also matches. `tools/qa/grep_rules.py` fails a `.gd` hit and only warns on a scene hit (inference, doc 09 section 9). Should scene-authored energies count as violations (then every light is made by `LightRig`), or are they allowed? Also: rule 1 counts comments, so "flicker" in any comment outside `game/ghost/` fails; keep comments to "steady" or "dim". Answer closes Q-028's open point.

**Answer (Director, P4-01, 2026-10-08):** the Technical Artist answers this in P4-16 with the `LightRig` review.

### Q-037 · 2026-10-07 · QA → Gameplay Programmer · answered D-020 (Gameplay: all four events plus `perf_sample` added to doc 05 s18)
Doc 09 measures need events doc 05 s18 does not list: `ghost_flicker` and ghost crow/rustle/static-voice actions (DD Phase 3 "the dead stay engaged"), a "fooled" signal for recorded-line lures (DD Phase 2), and a debug-only `perf_sample` (avg/max frame ms, draw calls, `RenderingServer.get_video_adapter_name()`) for the doc 07 s10.3 four-instance corn profile. Add them to doc 05 s18, or say the observer's notes cover them.

### Q-038 · 2026-10-07 · QA → Game Designer · answered
Doc 09 DD Phase 4 needs the `tools/sim/` `compare` command doc 05 s18 names. Which metric is "within 15 points" (first/final payment clear rates, or per-dawn coin and debt trajectory), and how many seasons does the comparison need? Doc 09 proposes at least 6 full seasons (placeholder).

**Answer (Game Designer, 2026-10-07):** doc 02 s18.5. Gating metric: per dawn 2 to 8, live median coins as a percentage of the next payment due vs the sim median for the same player count, within 15 points. Clear rates are reported, not gating (6 seasons gives a band far wider than 15 points). Seasons: at least 6 live (2 per player count, placeholder, doc 09 accepted); sim 1,000+ per count. `compare` is built in DD Phase 4 prep once real logs exist (inference; first logs settle it).

Note on Q-028: answered by doc 09 (PP-10): three flicker greps in section 9 and `tools/qa/grep_rules.py`; four-instance corn profile in section 10. Director to close.

### Q-039 · 2026-10-07 · QA reviewer → QA · closed (P4-18)
PP-10 passed with three nits (production/handoffs/PP-10.md "QA review"): (1) `grep_rules.py` `rpc_outside_net` misses bare `rpc_id(` calls and `@rpc` outside `game/net/`; (2) the voice-file extension rule is QA's, not CONTRACTS s11's, so mark it inference, and decide a `spikes/` exception for WAV test input; (3) doc 09 s9 hand grep 1 is looser than the script, say the script rules.

**Answer (Director, P4-01, 2026-10-08):** the three nits go to P4-18 (QA).

**Fixed (QA, P4-18 helper, 2026-10-09):** (1) `grep_rules.py` `rpc_outside_net` now matches bare
`rpc(` / `rpc_id(` calls and `^\s*@rpc` outside `game/net/` (`send_rpc_id(` and `rpc_config(` do not
match); 0 violations on main 45963f1. (2) The voice extension list is marked QA inference (CONTRACTS s11
names no extensions), and `spikes/` gets no exception (test voice input lives outside the repo). (3) Doc 09
s9 says the script is the rule and why hand grep 1 is looser. `tests/qa/test_grep_rules.py`: 7 tests OK
with new bare-call, `@rpc`, non-call-name and `spikes/` cases.

### Q-040 · 2026-10-07 · Gameplay → QA · closed
`tools/qa/smoke.py` step `parse_check` runs `tests/qa/parse_check.gd` as a `-s` SceneTree script. In that mode the autoload names (`Game`, `Data`, `Log`, `Clock`, `Settings`, from P1-02) are not registered, so every script that uses one fails with "Identifier not found" and smoke reports FAIL though the game is fine (import and run steps pass). Checked: the same script run as a scene (`Node` with `_ready`, `get_tree().quit(...)`, run as `godot --headless --path . res://tests/qa/<scene>.tscn`) loads all scripts with `failed=0`. Please switch `parse_check` to a scene run. P1-02 is in review with this one failing smoke step.
**Answer (QA, 2026-10-07):** fixed. `parse_check` is now a scene run (`tests/qa/parse_check.tscn`, script extends `Node`, quits from `_ready`); `smoke.py` and `tools/qa/README.md` updated. Smoke on P1-02: PASS, 0 errors. Director to close.

**Answer (Director, P4-01, 2026-10-08):** closed; `parse_check` runs as a scene.

### Q-041 · 2026-10-07 · Gameplay → Director, AI Programmer · answered
The autoload `Noise` (CONTRACTS section 8, doc 05 section 8) shares its name with Godot's native `Noise` class (FastNoiseLite's base). In GDScript the identifier resolves to the class: `Noise.noise_emitted` and `Noise.emit_kind()` fail to parse ("Cannot find member ... in base Noise"), and smoke fails. P1-04 works around it with `get_node("/root/Noise")` (cached in a variable). The AI Programmer's consumer needs the same. Choose: keep the name and use the `get_node` form everywhere, or rename the autoload (for example `NoiseBus`; `project.godot`, CONTRACTS section 8, docs 03/05 and the `emit_*` call sites change). I recommend the rename, before P1-06 and P1-08 add more call sites.

**Answer (Director, 2026-10-07):** renamed to `NoiseBus` (D-025). Done in P1-04: file, autoload, call sites, docs 03/05/06/08, CONTRACTS section 8.

### Q-042 · 2026-10-07 · Network & Voice → Director, Gameplay Programmer · answered (D-073)
1. **Director: voice type bytes collide with movement.** Doc 06 section 8 gave voice frames type
   `0x01` (client to host) and `0x02` (relay), but `game/player/move_frame.gd` (P1-04) already sends
   `MOVE = 1` and `MOVES = 2` through the same `Net.bytes_received` signal, so the host would read
   voice as movement. P1-06 moved voice to `0x10` and `0x11` and updated doc 06. CONTRACTS says shared
   formats change only with a DECISIONS entry: please record one (proposal: `send_bytes` type bytes
   `0x01`-`0x0F` movement, `0x10`-`0x1F` voice).
2. **Gameplay: push-to-talk setting.** Doc 01 "Voice" makes push-to-talk a per-player setting. Please
   add `push_to_talk` (default `false`) to `Settings.DEFAULTS` and a menu toggle. `Voice` already reads
   the key when it exists; until then `--ptt` starts in push-to-talk.
3. **Gameplay: `project.godot` autoload.** P1-06 added `Voice="*res://game/voice/voice.gd"` after
   `NoiseBus` (CONTRACTS section 8 load order, asked in Q-006). Please confirm, since you own the file.

**Answer (Gameplay, P2-10):** (2) done: `push_to_talk` was already in `Settings.DEFAULTS`; the Audio tab of the settings screen (main menu and pause menu) has the toggle, and `Voice` reads it live via `Settings.changed`. (3) confirmed: `Voice` is in `project.godot` after `NoiseBus`. (1) is the Director's.

**Answer (Director, P4-01, 2026-10-08):** item 1: D-073 records the ranges, `0x01`-`0x0F` movement and `0x10`-`0x1F` voice. Items 2 and 3 were answered by Gameplay. Closed.

### Q-043 · 2026-10-07 · AI Programmer → Gameplay · answered
P1-13 (bots, doc 05 s19) touched two Gameplay files; please confirm or redo them your way. (1) `game/core/main.gd`: adds the `Bots` node after `Players`. (2) `game/interaction/hold_registry.gd` `_reply`: `else:` became `elif peer > 1:`, because bots use negative peer ids and have no connection (they poll `holds` instead). Three asks: (a) a public `Players.submit(peer, frame)` so `game/bots/bot.gd` stops calling the private `_ingest`; (b) `players.gd` line 134 sends `apply_teleport` to any `peer != 1`, so a bot speed violation errors "unknown peer ID -1"; guard it `peer > 1` (bots now resync to the host's kept position, so it no longer fires in runs); (c) existing bug, not mine (inference from reading, not seen in a log): `player_left` makes the registry cancel a hold and `_reply` to the disconnected peer. (d) Debug view (P1-12): tag bots, they are `peer < 0` and `Game.players[peer].bot == true` (doc 05 s19).
**Answer (Gameplay, P1-09):** (a) done: `Players.submit(peer, f)` is public, `bot.gd` calls it. (b) done: `apply_teleport` guarded `peer > 1`. (c) done: `HoldRegistry.cancel(peer, reason, notify)`; the `player_left` path passes `notify=false`. (d) done: debug view tags bots (`bot`, `peer < 0`). Your `main.gd` Bots block and the `_reply` `elif peer > 1` are kept.

### Q-044 · 2026-10-07 · AI Programmer → Gameplay · answered
P1-08 added one block to `game/core/main.gd`: a `Creature` node (`game/creature/creature.gd`) after `Bots`, before the debug view. Please confirm or move it. P1-09 needs the trap state on clients: the Creature keeps traps host-only and logs `trap_changed`/`trap_sprung`; say if you want an `apply_trap_changed` RPC from me or will add it in net.gd yourself.
**Answer (Gameplay, P1-09):** Creature block in `main.gd` confirmed (kept before `Death`, `TrapRace`). I added `apply_trap_changed` (and `apply_trap_race`, `apply_shaken`, `apply_death`, `apply_respawn`) in net.gd. Please review three small edits I made in `creature.gd`: signals `caught(peer)` (before both 'reached' retreats) and `trap_sprung(trap_id, kind, peer, position, deep)` (in `_check_traps`), plus public `force_state(s, reason, target)` used by the trap race (chase while pinned, retreat or lurk after). Your `trap_changed` / `trap_sprung` logs are unchanged. Open for you: after a kill the creature goes to retreat (night) or lurk (day) from `force_state`; refine if doc 03 wants otherwise.

### Q-045 · 2026-10-07 · Audio Designer → Gameplay · closed
P1-10 added one line to `project.godot` (your file): `Soundscape="*res://game/audio/soundscape.gd"` after `Voice`. Please confirm. Hooks: `Soundscape` already plays `sfx_beartrap_snap`/`sfx_pit_fall` from `Net.apply_received` `trap_changed` (state `sprung`), so no extra call is needed. `sfx_whistle` exists but nothing in gameplay plays it yet: when the whistle mechanic lands, call `Soundscape.play_3d(&"sfx_whistle", pos)` on each peer when the host's result arrives. The 3D whistle range class (unit 20 m, max 220 m) is in doc 08 s9.3.

**Answer (Director, P4-01, 2026-10-08):** closed. `Soundscape` stays in `project.godot` after `Voice` (CONTRACTS s8 load order); the whistle sound landed with P3-11.

### Q-046 · 2026-10-07 · QA → Director (for Gameplay) · closed
P1-14 findings, each wants a task. (1) `speed_violation` on `autowalk`: probable stamina flicker at 0 in `player.gd` (OPEN_ISSUES P1-14 entry). A human who holds Shift past 6 s likely logs violations, and doc 09 s3 says no `speed_violation` on a normal client. Gameplay: refill threshold or hysteresis, then rerun `--autowalk` and expect 0. (2) Corn budget wording (Technical Artist / Director): doc 07 s10.2 "corn stalk instances 25,000 or fewer"; `look_stats` reports `stalks=55704` for the whole field (53 cells). Say if the budget means total or in view (instances within the 30 m MultiMesh range). Frame time, draws and triangles are far inside budget either way (handoff P1-14). (3) No HUD or menu exists (`game/ui/` absent): a first-time tester sees no prompt text beyond the placeholder ring; doc 01 "Onboarding" (one intro per verb) is not met. Out of P1 scope per TASKS, but a tester who has not read doc 01 will be lost; Director decides whether STOP 2 needs a minimal prompt layer. (4) Doc 09 s3 needs 20 lure results over 2 sessions; creature in `--creature-test` produced 4 lures in 1500 s of 2-instance runs (lone-player condition). Two humans in a real session may produce few; Game Designer/AI Programmer: say whether a lone-player rule leaves 30% measurable in 5 minutes of night.

**Answer (Director, P2-02):** (2) in view. Doc 07 s10.2's row reads "Corn stalk instances drawn", so the
budget counts stalks inside the camera frustum and the 30 m MultiMesh range. P2-02 measured 926 to 4,820
drawn on the full farm (100,164 total) with 4 instances, inside the 25,000 budget.

**Answer (Director, P4-01, 2026-10-08):** closed. Item 1: resolved in P1-16 (OPEN_ISSUES). Item 3: the main menu (P2-10) and `game/ui/hud.gd` exist. Item 4: answered in Q-048 item 1 (`trap_lure_m`).

### Q-047 · 2026-10-08 · QA → Gameplay Programmer · closed (item 2 to P4-04)
P1-17 (D-029). (1) `session_start.build_id` is `str(Data.hash_value)`, a data hash, not a build. `package_playtest.py`
names a build `git describe --always --dirty` and writes it to `BUILD.txt`. Proposal: the export step writes it to
`application/config/version` and `Game` logs that as `build_id` (keep the data hash as its own field). (2) Doc 05 s3:
`run/main_scene.voice_spike` is to go once a game preset exists; "Playtest (Windows)" now exists. (3) Without a menu,
a bare exe double-click hosts solo without `--phase1`; the zip works around it with `Host.bat`/`Join.bat`. A host/join
menu (or `--phase1` as the default in an export) removes the need.

**Answer (Gameplay, P2-10):** (1) done your way: `Game.build_id()` reads `res://build_id.txt`, else `application/config/version` (now `dev`); `session_start` logs `build_id` plus `data_hash`. `package_playtest.py` writes `build_id.txt` from `git describe` for the export only and deletes it after (try/finally; the file is in `.gitignore`); the "Playtest (Windows)" preset `include_filter` now has `build_id.txt`. I edited `tools/qa/package_playtest.py` and `export_presets.cfg` for that: please review. Not run: a full export (needs a clean tree). (2) left as is: `run/main_scene.voice_spike` is a feature-tag override of the Phase 1 spike; say if you want it removed. (3) done: a bare launch with a window opens the main menu (Host / Join / Settings / Quit); Host and Join turn Phase 1 data on. `Host.bat`/`Join.bat` still work and can stay.

**Answer (Director, P4-01, 2026-10-08):** items 1 and 3 done. Item 2: remove the `run/main_scene.voice_spike` override in P4-04.

### Q-048 · 2026-10-08 · AI Programmer → Game Designer, Audio Designer, Network & Voice, Gameplay · closed (item 4 to P4-04)
P1-20 (OPEN_ISSUES playtest 6, 7, 8; handoff `production/handoffs/P1-20.md`).
1. **Game Designer: three placeholders in `game/creature/creature.gd`.** (a) `CHASE_TELL_S = 2.0`: no
   kill in a chase's first 2 s, so the chase tell (doc 03 s4) always comes before a lunge. The playtest
   kill came 1.18 s after `chase_started`. (b) `SCRIPTED_STANDOFF_M = 18.0`: the scripted stalk follows
   the true position, so it now holds back past `sight_night_m` (15 m) and backs off when the player
   walks closer (doc 03 s2 "never in clear view at night except mid-chase"); at 10 m it stood in view
   for 15 s. (c) `TRAP_LURE_M = 15.0`: reading of doc 01 "Lure: near armed traps or lone players" as
   "a source within 15 m of an armed trap may lure a player who is not alone". Lures also fire in the
   scripted lurk now. Please confirm or set numbers; this also answers Q-046 (4) from my side.
2. **Audio Designer: no chase sting or signature sound exists.** Doc 01 / doc 03 s4 give the chase "music
   sting plus signature"; `Soundscape` has no cue for `apply_creature_state` `chase`, and stalk and chase
   share the -80 dB bed, so entering a chase is silent. This is half of the playtest "killed without
   warning". Please add both on every peer when the replicated state turns `chase`.
3. **Network & Voice: `net.gd` comment is stale.** `apply_trap_changed` says "Set traps are never sent";
   the Creature now sends `set` (and `moved` when a trap moves), so every peer can draw the close-range
   clue (doc 03 s9, 4 m). Please update the comment.
4. **Gameplay: client `TrapRace.traps` now holds `set` and `moved` entries.** `_on_apply` stores every
   state; nothing breaks, but the debug view on a client may colour a set trap as if open. Filter on
   `state` if that matters.


**Answer to Q-048 (1), Game Designer, P2-12, 2026-10-08.** Confirmed as placeholders, now in `data/creature.json`
(and `creature.gd` reads them from `_num`; the three consts are gone): `chase_tell_s` 2, `scripted_standoff_m` 18,
`trap_lure_m` 15. A Phase 2 playtest settles them. Items 2 to 4 are for the other roles.

**Answer to Q-048 (2), Audio Designer, P2-08, 2026-10-08.** Done: `Soundscape` plays `mus_sting_chase` and the body's `cre_<body>_sig_chase` on every peer when the state turns `chase` (doc 08 s10.5).

**Answer to Q-048 (3), Network & Voice, P2-03, 2026-10-08.** Done: the `apply_trap_changed` comment in `net.gd` now lists `set` and `moved` and says why they are sent.

**Answer (Director, P4-01, 2026-10-08):** items 1 to 3 done. Item 4: the client debug filter goes to P4-04.

### Q-053 · 2026-10-08 · Level Designer → Gameplay Programmer · answered (P2-11)
P2-02 (handoff `production/handoffs/P2-02.md`). `res://game/world/farm.tscn` (full farm) is built; `Main.FARM` still loads `farm_phase1.tscn`. (1) Please add a flag (or make full farm the default and `--phase1` the Phase 1 scene) so `Main` loads `farm.tscn`. (2) New groups in `farm.tscn` for your code: `store_crate` (shipping crate = store only, D-017), `sell_box` now sits on the town stand (120, -5), `sanctuary` (Marker3D, meta `radius_m` 10), `farm_gate`, `pumpkin_patch`, `moonflower_bed`, `pegboard_slots` (5 children of the pegboard, count from `season.json`), `recording_spots`, `barn_lantern` (both in the barn). Plots: 28 `plot_spots`, meta `field` = `a`, `b` or `moonflower`; `upgrade` true on the south row of each field (8), so 16 field plots start open plus 4 moonflower. `CartRoute` is a `Path3D` with R0..R8. (3) `farm.gd` and `bot_route.gd` assume Phase 1 (field A only; hand-made bot route); check both before the switch. Director: add the new groups to CONTRACTS s4.

**Answer (Gameplay Programmer, P2-11).** (1) New launch flag `--full-farm`: `Game.world_path()` returns `res://game/world/farm.tscn` with it and `farm_phase1.tscn` otherwise; `Main` and the lobby both call it (`Game.LOBBY_WORLD` is gone). `--phase1` still loads the Phase 1 scene and all other flags work. Every peer must pass `--full-farm` (the handshake does not check it yet). `--full-farm` does not turn Phase 1 data on, so use `--phase1 --full-farm` for the creature. The main menu still forces Phase 1 data and the Phase 1 world; making the full farm the default waits for P2-05/P2-06. (2) The new groups are read where used (`pegboard_spots`, `pegboard_slots`, `trap_spots`, `plot_spots`); the others are unused so far. `farm.gd` now locks the `upgrade` plots only under `--full-farm` (Phase 1 keeps all open). Adding the groups to CONTRACTS s4 is the Director's. (3) `farm.gd` loads the 28 plots and field-A-only logic is unchanged: the moonflower plots accept turnips (unchecked). `game/bots/bot_route.gd` is a hand-made Phase 1 route and is not usable on the full farm: bots there are unsupported and unverified.

### Q-054 · 2026-10-08 · Network & Voice → Gameplay, Level Designer, Render, Audio Designer, AI Programmer, QA, Director · items 1-4, 6, 7 answered; 5 to P4-16; 8 FOR CEO
P2-03 (handoff `production/handoffs/P2-03.md`).
1. **Gameplay: one-line edit in your `game/core/game.gd`.** `match_ready()` now returns `Voice.clips.ready_to_start()` (the P2-10 hook). Please keep it when you next edit the file.
2. **Gameplay: the Off confirm.** Doc 01 "Voice settings > Off" deletes the lines; the settings menu should ask "This deletes your recorded lines" before setting `off` when `Settings.get_value("lines_recorded")` is true. `Voice.clips` deletes on `Settings.changed`, so the prompt is the only missing part.
3. **Gameplay: lobby names.** The lobby roster shows "Player N"; `Net.profiles` carries the profile name ("Farmer" by default), which the recording screen uses ("you won't hear: Farmer"). Please pick one source. The lobby could also mark who is recording (`Net.apply_recording_light` / `Voice` keeps the state).
   **Answered (Gameplay, P2-06):** items 1 to 3 done. Item 1: `match_ready()` kept. Item 2: `settings_menu.gd` asks "This deletes your recorded lines" (confirm or cancel) before Off when `lines_recorded`. Item 3: lobby uses `Net.profiles` names and adds ", recording" from `Voice._lit` (no public accessor; Network & Voice may add one).
4. **Level Designer: the real barn lantern.** The recording screen blows out the `LightRig` in group `barn_lantern` (or under that marker). `farm.tscn` has only the marker, so the screen adds a staging rig there while it is open. Please put the barn's real lantern `LightRig` in the group.
   **Answered (Level Designer, P2-13):** `BarnLantern` is now also in `lightrig_spots` (radius 6), so `world_look.gd` `_place_rigs` adds the real `LightRig` as its child; `_find_lantern` finds it through the `barn_lantern` group. Needs a windowed or render run to see it (not done here).
5. **Render: `game/render/light_rig.gd` edit (Director-authorised).** Added `stage_blown(out)` and `_staged_out` (held out whatever `apply_lights` sets; lit again through the slew) and factored `_puff()`. Please review.
6. **Audio Designer: missing sounds.** `sfx_lantern_blow_out` and `cre_door_bang_01` are not in `assets/audio/` (the relight is silent); the recording screen plays a short noise burst instead.
   **Answered (Audio Designer, P2-08):** `sfx_lantern_blow_out.wav` and `cre_door_bang_01.wav` exist in `assets/audio/`; the screen's `load()` of those paths now finds them, no code change. The relight is silent by design.
7. **AI Programmer / P2-04: lures.** Play a clip with `Voice.clips.play_packets(owner, clip_id, emitter)` (or `packets()`), check the owner's current setting at play time, and stop on `Voice.clips.clip_freed(owner, clip_id)`: Off frees every clip of that owner on every peer.
8. **QA / FOR CEO: listening to a kept take.** `--clip-wav-out` writes nothing under `--audio-driver Dummy` (the silent-test rule). A listening check of "help me" needs one run with a real audio driver; it plays only into a muted bus, so nothing reaches the headphones (inference: the bus is muted; unverified with a real driver after that change). Director/CEO decide whether that run is allowed.

**Answer (Director, P4-01, 2026-10-08):** item 5: the Technical Artist reviews `stage_blown` in P4-16. Item 7 was used in P2-04. Item 8 stays FOR CEO: a real-audio listening run of a kept take. It needs a real audio driver, which the silent-test rule bars without CEO approval.

## QA to Director: refused peer gets position sends (found in P2-17 review)
Host logs ~18 `ERROR: Unable to send packet on channel 2, max channels: 0` (`net.gd:170 send_bytes` from `players.gd:71`) in the 0.5 s after `join_refused` (match_in_progress, running match). Skip peers in `Net._refused` in the send loop. Owner: Gameplay (`players.gd`) or Network & Voice (`send_bytes`). Verify: host with `--lobby --lobby-start=1`, then a refused `--join`; expect 0 host ERROR.

**Answer (Director, P4-01, 2026-10-08):** routed to P4-10 (Gameplay or Network & Voice). Verify as written above.

### Q-055 · 2026-10-08 · AI Programmer → Director, Game Designer · answered (D-053)
P2-05 (handoff `production/handoffs/P2-05.md`, doc 03 s9.1).
1. **Director / Game Designer: pegboard pool.** Doc 01 "Night Traps" ("every empty outline is a trap somewhere on the farm", "pried a board loose") and doc 02 s12 (board holds 5, inferred from the day 6 count) read as a finite pool the creature steals from the board. P2-05's acceptance says only "any bear trap not on the pegboard at nightfall is the creature's", so I built that: only off-board traps are taken, the creature's own supply is unlimited, the board starts full and is never emptied. Result: P2-11's `pegboard_full` refusal stays the normal case in play (`--pegboard-empty` is the only way to hang a disarmed trap). Decide: board start state, and whether the creature takes from the board.
2. **Game Designer: lit building.** Doc 03 s9 table row "Trap kept in a building" says a trap in a building lit all night turns up in the corn at dawn; the P2-05 acceptance says it stays. I followed the acceptance (it stays). Which one?
3. **Director: new log events** for CONTRACTS s10 / doc 05 s18: `trap_plan`, `trap_stolen`, `trap_theft_capped`, `trap_skipped`, and new `trap_changed set` fields `region`, `work_m`, `stolen`. Difficulty scaling and full-wipe extras (doc 03 s9) are not applied yet: no difficulty table in the plan path.

### Q-056 · 2026-10-08 · AI Programmer → Gameplay, Game Designer, Network & Voice · closed
P2-05 rework (D-053 (3), handoff `production/handoffs/P2-05.md`).
1. **Gameplay / Game Designer: pick-up verb.** A trap kept in a lit building turns up at dawn as a loose, unarmed pickup (`game/creature/trap_pickup.gd`). No pick-up verb exists, so it borrows `disarm_bear` (5 s labor) and refuses `hands_full`. Proposal: an instant `take_trap` verb (Gameplay's `Interactable.INSTANT_S`, about 1 s like hanging, doc 02 s2.1) plus its HUD label; I then swap the one verb in `trap_pickup.gd`.
2. **Network & Voice (FYI):** `apply_trap_changed` carries two new `state` values, `loose` and `picked_up` (args unchanged: id, kind, state, position). Late joiners get loose traps from trap_race's `farm_state` resend, which stores the state as-is.

**Answer (Gameplay, P2-19, 2026-10-08), Q-056 item 1:** done. `take_trap` is an instant verb (`Interactable.INSTANT_S`, 1.0 s placeholder, about 1 s like hanging, doc 02 s2.1), HUD label "Pick up the trap". `trap_pickup.gd` offers only `take_trap`, still refuses `hands_full`. `trap_changed` `picked_up` and wire state unchanged. Item 2 noted. Handoff `production/handoffs/P2-19.md`.

**Answer (Director, P4-01, 2026-10-08):** closed; item 1 built in P2-19, item 2 noted.

### Q-057 · 2026-10-08 · QA → Director · answered (P2-23)
P2-22 review. `tests/net/test_voice.gd` (`-s` run) does not run: `game/voice/voice_emitter.gd:45` has `Settings`, which does not resolve in script mode ("Identifier not found: Settings"), so the preload fails and the process then hangs without quitting (a Godot process stays up until killed). Not caused by P2-20 or P2-21 (neither touches voice or the test). Owner: Network & Voice. Fix idea: run it as a scene like `tests/ui/test_settings_binds.tscn`, or load `Settings` through the tree. Also: `tests/ui/test_settings_binds.gd` is a scene test (`.tscn`), not an `-s` script; it passes as a scene.
**Answer (P2-23, 2026-10-08):** the test preloaded `voice_emitter.gd`, which compiles before autoloads exist under `-s`; the compile error skipped `quit()`, so Godot idled. The test now `load()`s the emitter after a frame, as it already did for `voice.gd`. It prints `test_voice: PASS` and exits 0.

### Q-058 · 2026-10-08 · AI Programmer → Gameplay · routed to P4-04
D-055 follow-up. `game/creature/trap_art.gd` (`class_name TrapArt`) builds the placeholder trap meshes: `TrapArt.bear()`, `TrapArt.pit()`, `TrapArt.of(kind)`, each a `Node3D` with its origin on the ground. Set traps (`creature.gd` `_show_clue`) and loose traps (`_show_loose`) use it now. Ask: use it for the pegboard hung trap (`trap_sweep.gd` `_make_slot`, now a 0.6 m box) and the sprung trap (`trap_race.gd` "Sprung" cylinder), so a trap looks the same everywhere. For the pegboard, rotate the bear 90 degrees on x so it hangs flat on the board.

**Answer (Director, P4-01, 2026-10-08):** yes: use `TrapArt` for the pegboard slot and the sprung trap in P4-04.

### Q-059 · 2026-10-08 · AI Programmer → Audio Designer, Director · answered (P3-08)
P3-05 (handoff `production/handoffs/P3-05.md`, doc 03 s13.1). A scare's build-up calls `Soundscape.hush(seconds)`: the insect bed off and the wind 12 dB down, then the layers return unless the creature is stalking or chasing. Doc 08 s4.4 rule 1 lets only creature state lower layers. Ask: amend doc 08 s4.4 to allow `hush` as a second layer-lowering path (P3-08), or say which path the build-up should use instead.

**Answer (Audio Designer, P3-08):** amended. Doc 08 s4.4 rule 1 now names `Soundscape.hush(seconds)` as the second path that may lower `bed` and `wind`: it is the creature's own pre-scare silence, on the target's peer only. `hush` logs `audio_hush {seconds}`. Director: object if the rule change needs a DECISIONS entry.

### Q-064 · 2026-10-08 · Gameplay Programmer → Audio Designer · answered (P3-08)
P3-11 (handoff `production/handoffs/P3-11.md`). The scream emote plays `vox_emote_scream` (doc 08 s11.6 row: formant-synth scream, rising `Saw` 600 to 1100 Hz, 1.5 s, 3D, Voice bus). The file does not exist, so the scream is silent to players today (its 60 m `voice` Noise to the creature works). Ask: render `assets/audio/vox_emote_scream.wav` from a `src/vox_emote_scream.scd`. I added the `Soundscape` CATALOG row with `unit` 6 m, `max` 110 m, -4 dB (inference: doc 08 gives no range for it; 110 m copies the 60 m-Noise tripwire bells row in s3.2). Change the row if you want other numbers.

**Answer (Audio Designer, P3-08):** rendered `assets/audio/vox_emote_scream.wav` from `src/vox_emote_scream.scd` (1.5 s, formant synth, no recorded voice). Your CATALOG row is kept. Tested: `emote scream 2` logs `audio_play {vox_emote_scream}` on both peers. Also added `sfx_emote_cloth` for wave, point and shrug.

### Q-065 · 2026-10-08 · Gameplay Programmer → Network & Voice · answered (P4-14)
P3-11 (handoff `production/handoffs/P3-11.md`). I added four RPCs to `game/net/net.gd` (your path), in a section marked P3-11, following the request/apply pattern already there: `request_whistle()`, `request_emote(emote_id: StringName)`, `apply_whistle(peer, position)`, `apply_emote(peer, emote_id, position)`. Doc 05 s14 and doc 06 s7 name a voice slot as the first argument of the applies; I send the ENet peer id because slots are not built (logs use peer ids too, D-012). Ask: confirm the RPCs, or move them; when slots exist, say whether the applies should switch to slots.

**Answer (Director, P4-01, 2026-10-08):** accepted as built (D-076): peer ids until slots exist. Network & Voice confirms or moves them in P4-14.

**Answer (Network & Voice, P4-14, 2026-10-09):** confirmed, they stay in `net.gd` with peer ids. P4-14's `apply_walkie(peer, has_walkie, battery)` uses peer ids too, and doc 06 s7 now says so. No voice slot reaches an apply: the only slot is the relay frame's byte (the speaker's index in `Game.players`), which never leaves `voice.gd`. If slots ever replace peer ids in applies, it is one Director-approved change for all of them, not per RPC.

### Q-066 · 2026-10-08 · Gameplay → Director, Game Designer · answered (D-074)
P3-12 Dawn Report (handoff `production/handoffs/P3-12.md`, doc 05 s15 "As built (P3-12)").
1. **Most Wanted:** doc 01 "Dawn Report" says "who was chased most"; the `most_wanted` template prints `{fake_count}` calls. Built: most `chase_started`, ties and a chase-free day go to the owner voiced in most lures. Confirm, or pick one measure.
2. **Missing copy:** no templates for the Hero actions "freed a teammate" and "refueled", the Flags Placed lines, the empty-flags line, or the ledger labels. Placeholders live in `game/ui/dawn_report_logic.gd` (`HERO_FREED`, `HERO_REFUELED`, `FLAGS_LINE`, `NO_FLAGS`). Also `most_wanted` reads "1 calls" for one call: needs a singular.
3. **Streamer-safe:** doc 01 says the mode "never replays live clips"; doc 05 s15 and the P3-12 criteria say it never replays voice. Built the stricter rule (no voice replay at all). Confirm.
4. **Skip:** each peer closes its own card; there is no host "skip for all". Say if doc 01 wants one.

**Answer (Director, P4-01, 2026-10-08):** D-074: (1) Most Wanted as built, most `chase_started`, ties to lures. (2) the missing copy and the singular go to P4-03. (3) the stricter rule stands: no voice replay. (4) skip stays per peer.

### Q-060 · 2026-10-08 · Gameplay → Audio Designer · answered (P3-08)
P3-07 (handoff `production/handoffs/P3-07.md`). Doc 01 "The Taint" cues a Tainted player with a wet heartbeat. Ask: in `game/audio/soundscape.gd`, play `sfx_taint_heartbeat` (doc 08 level, about -42 dB, local only) while the local player is Tainted. The flag is `Game.players[Game.local_peer()].tainted`; it changes in `Net.apply_taint_changed(peer, on, cause)` (host and the Tainted client), so a poll or that RPC both work. Doc 08 s10.1 plans `Soundscape.set_local_state(tainted, still, shaken, fuel_fraction)` called by `Player`; it does not exist yet. Build it and I add the call from `player.gd`, or poll the flag. Until then the HUD prints tester text "Tainted: wash at the well".

**Answer (Audio Designer, P3-08):** polled. `Soundscape._taint_heartbeat()` reads `Game.players[Game.local_peer()].tainted` each frame and loops `sfx_taint_heartbeat` (-42 dB, `SFX`, non-positional) while Tainted and alive. No `player.gd` call is needed; `set_local_state` stays unbuilt. Two-instance test: the beat started only on the Tainted peer (`audio_taint_heartbeat`). The HUD text is yours to keep or drop.

### Q-061 · 2026-10-08 · Gameplay → AI Programmer · answered (P3-06: item 1 built in `bot.gd` `next_job`; item 2 used as written)
P3-07 (handoff `production/handoffs/P3-07.md`).
1. **Bots never wash.** A Tainted bot keeps its Taint until dawn. Ask: in `game/bots/bot.gd` `next_job`, return `[&"wash", "well"]` when `Game.players[peer].tainted` (tested as a one-line temporary edit on the Phase 1 farm: the 10 s hold completed and logged `taint_changed` cause `well`).
2. **P3-06 sabotage:** place dead crows and strange seeds with `get_tree().get_first_node_in_group(&"taint").add_source(&"dead_crow" or &"strange_seeds", pos)` and clear them with `remove_source(id)` (host; it logs `taint_source` and mirrors to clients). A stolen tool that is a can: `farm.cans.taint_can(id, &"stolen_tool")`; `creature_move_cans` already does this.

### Q-068 · 2026-10-08 · Network & Voice → AI Programmer, Gameplay · answered (D-075, D-076)
P3-10 (handoff `production/handoffs/P3-10.md`, doc 06 s9 "As built (P3-10)"). I made two one-line edits outside my paths, because the ghost voice could not land without them.
1. **AI Programmer:** `game/creature/creature.gd` `_hear_lure` now picks the bus with `bus_for(tell, Voice.hears_static(owner))`, so a dead owner's clip lure plays through the ghost static, the same as their real voice. The listener decides this, not the `ghost` flag in `apply_lure`. That flag is set only for night lures (`not day`, doc 03 s12), but doc 01 "The dead-voice twist" says "including in targeted lures". Ask: keep the edit, and drop `not day` from the logged `ghost` flag (or say why day lures differ).
2. **Gameplay:** `game/player/player.gd` no longer sets a ghost's `VoiceEmitter` to -80 dB for living listeners (playtest issue 9's stopgap). It applies only the per-player volume. `Voice` now puts the emitter on the ghost static bus. Ask: confirm.

**Answer (Director, P4-01, 2026-10-08):** (1) keep the edit; drop `not day` from the `ghost` flag (D-075, P4-11). (2) confirmed (D-076).

### Q-072 · 2026-10-08 · Audio Designer → Director, Game Designer · answered (D-074)
P3-08 (handoff `production/handoffs/P3-08-sound.md`). Doc 08 s2.3 rule 5 low-passes `Master` at 1.2 kHz and drops `SFX` 10 dB while the Dawn Report is open. The P3-12 report replays lures (voice clips and sound lures) while open, so a `Master` low-pass would muffle the replays. Not built. Proposal: no low-pass for the Dawn Report (keep it for the pause menu), or low-pass `Ambience` and `SFX` only. Pick one; until then the card only plays `ui_paper_slide`.

**Answer (Director, P4-01, 2026-10-08):** low-pass `Ambience` and `SFX` only while the Dawn Report is open; the pause menu keeps the `Master` low-pass (D-074, P4-17).

### Q-073 · 2026-10-08 · Audio Designer → Director, QA · answered (D-076)
P3-08. `Soundscape` now logs `audio_play {id}` (each one-shot but footsteps), `audio_hush {seconds}` and `audio_taint_heartbeat {on}`, on the peer that hears them. Ask: list them in CONTRACTS s10 and doc 05 s18 with `audio_state` (the Phase 2 `audio_chase_cue` is also unlisted). `check_logs.py` already counts them.

**Answer (Director, P4-01, 2026-10-08):** the four events are in CONTRACTS s10 (D-076); Gameplay adds them to doc 05 s18 in P4-04.

### Q-069 · 2026-10-08 · AI Programmer → Network & Voice, Gameplay · answered (D-076)
P3-06 Sabotage (handoff `production/handoffs/P3-06.md`). I made small edits outside my paths so sabotage could land. Ask: confirm each, or move it.
1. **Network & Voice:** `game/net/net.gd` has one new apply RPC after `apply_taint_source`: `apply_disturbance(id: int, kind: StringName, position: Vector3, yaw: float, on: bool)`. The host sends it to show or clear a disturbance mark (footprints, claw marks, feathers) and to move a scarecrow (negative `id`). Late joiners get the live set on `farm_state`.
2. **Gameplay:** `game/interaction/interactable.gd` has a new static `fix_hold_s(verb)` that reads `sabotage.json` `fix_hold_s` (`bury` 4 s, `pull_seeds` 3 s), and `hold_seconds` falls back to it. `game/interaction/hold_registry.gd` `_validate` accepts a verb with `fix_hold_s > 0` before the `labor.json` check (else `Data.record` logs an error for `bury`). Fix targets are `FixTarget` nodes in `farm.targets["dist_<id>"]`; `bury` needs a held shovel (refusal `no_shovel`).
3. **Gameplay:** `game/ghost/death.gd` `dawn_summary.farm_damage` reads the `Sabotage` node's `farm_damage`: coins of crops lost to the dawn trample (each plot at `crops.turnip.sell`). Inference: doc 03 section 10 gives no unit; coins match the dawn report ledger (D-065). Say if the ledger wants a plot count.
4. **Gameplay:** bots started with `--bot-chores` now also run on the full farm (straight-line walk, no `bot_route.gd`), so the multi-day sabotage check has teammates that fix things. A run without the flag is unchanged.

**Answer (Director, P4-01, 2026-10-08):** items 1 to 4 accepted as built (D-076). Item 3: the ledger counts coins (D-065), so coins stay.

### Q-070 · 2026-10-08 · AI Programmer → Game Designer · routed (P4-03, P4-11)
P3-06 Sabotage. Doc 03 section 10 leaves these open; each is built as an inference. Ask: confirm, or change doc 03.
1. **When:** budgeted disturbances land at even times through the first third of the day (doc 03 section 11.3: "evidence of sabotage only"). Doc 03 gives no time.
2. **Where at dawn:** the dawn trample hits the crops nearest the creature at dawn. A plot with no crop is never trampled, so on a bare farm the dawn trample does nothing (`trample` log: `want` 2, `trampled` 0).
3. **Generator kill:** drains the tank to 0 during the day; the tank refills on the next day (`generator.gd`), logged as fix `new_day`. Like every disturbance, it never lands within 12 m of a living player.
4. **Found in QA:** the budgeted `trample` can land mid-day (doc 03 s10.1 says a plot is trampled at dawn), and the dawn trample hits the plot nearest the creature, so the same plot most dawns. Confirm or ask for a spread.
5. **Scarecrow moved:** "never the one closest to a player" is read as one spot, the one nearest any living player.
6. **Not built:** the full-wipe doubling of the next day's budget, the wash and buy-back fixes for a stolen tool that is not a can, and `broken_fence` / `pumpkin_gnaw` (Phase 4, D-059).

**Answer (Director, P4-01, 2026-10-08):** items 1, 3 and 5 accepted as built. Items 2 and 4: the Game Designer writes the dawn trample placement rule (spread, bare farm) into doc 03 s10 in P4-03. Item 6 is P4-11.

### Q-074 · 2026-10-08 · QA → AI Programmer · answered D-068
P3-13 (OPEN_ISSUES "Found at the P3-13 review" item 1). Doc 01 "Bodies": the host's game picks one of four bodies per season. `game/creature/creature.gd` fixes `const BODY := &"body_gaunt"`, so doc 01 Open Issue 4 (do the four bodies feel different) cannot be played at STOP 4. Ask: add the season pick (host, seeded, logged in `session_start` or a `creature_body` event), plus a `--body=<id>` dev flag so the two STOP 4 sessions can use different bodies. Is this Phase 3 scope, or should the Director move Open Issue 4 to Phase 4?

**Answer (CEO, D-068):** not Phase 3. Open Issue 4 and the season body pick move to DD Phase 4 (P4-08).

**Answer (Director, P4-01, 2026-10-08):** the body pick row is now P4-13 (D-070).

### Q-075 · 2026-10-08 · Director → CEO · answered D-077 · FOR CEO
P4-01 (D-070). Three Phase 4 scope calls; the rows proceed as written unless overruled.
1. **Animals (D-071):** chicken, pig and cow in the pen, `broken_fence`, round-up, gray-box. Keep, or cut and drop the Rancher's perk to nothing?
2. **Roles (D-072):** only the four doc 02 s15 roles. The six doc 01 placeholder roles wait until their perks are set. Add them to Phase 4?
3. **Models (P4-16):** gray-box models built in Blender 5.2, no downloaded models. Approve, or name a source and license for downloads?
Also still open for the CEO: Q-031 item 2 (day music) and Q-054 item 8 (a real-audio listening run).

**Answer (CEO, D-077):** 1 keep animals; 2 build all ten roles; 3 Blender gray-box approved; Q-054 item 8: no, the CEO listens. Q-031 item 2 stays open.

### Q-076 · 2026-10-08 · AI Programmer → Gameplay Programmer · open
P4-13. The body pick logs a new event `creature_body` on every peer, once per season: host `{body, seed, forced}`, client `{body}` on the first `apply_creature_state`. Please add it to the doc 05 section 10 event table (owner: Gameplay Programmer). P4-10: save `Creature.body` with the season and pass it back on load as the forced id (`Creature._pick_body`, the `--body=<id>` path; AI Programmer wires it once P4-10 names the save field), so the pick survives a reload (P4-13 acceptance item 3).

### Q-077 · 2026-10-08 · Game Designer -> Director · answered D-079

P4-02 retune under D-078. All sim targets pass with doc 01's 16 plots, 2 deaths, buying on and the original hazards (nobody outside 20, generator dead 10, kill unfixed 50), but only if payments and medical bills scale a little off doc 01 Ramp-up's 80% / 60%: `payment_pct_by_players` 2p 59, 3p 85, 4p 101 (new `player_scaling.json` key, source `sim`; traps, disturbances and payouts keep 80/60/100). Reason: at doc 01's scaling 3p clears the final 85% and 2p 55%, and the final clear moves about 6 points per 1% of debt, so no other placeholder closes the gap (hazards hit 2p hardest; plot buying only helps 3p/4p). The 4p 101 and 2p 59 are rounding-scale nudges; the real move is 3p 80 to 85, which turns doc 02 7.1 3p debt 1,040 to 1,105 (first payment 217). The game reads only `pct_by_players` today, so live and sim differ until you decide. Options: (a) accept `payment_pct_by_players` and have Gameplay read it for debt and bills (doc 01 Ramp-up wording changes), (b) keep 80/60 and accept a 20 to 30 point 2p/3p spread, (c) another lever you name. Settle with: first live full-season logs (P4-10).

**Answer (CEO, D-079, revised):** `payment_pct_by_players` 59/85/101, the spread rule wins (60/85/100 gave a final spread of 16). Medium drop 37/44/48 accepted, revisit with P4-10 logs.

### Q-078 · 2026-10-08 · Game Designer -> Director · answered D-078
(Was Q-075 in this worktree; renumbered, main's Q-075 is the Director's.) P4-02: Medium pumpkin at 2p cost 26.7 points not 30, 2 deaths and 13/14 start plots. Answered by D-078: 2 deaths, 16 plots at every headcount, buying on, a drop of about 25 at 2p accepted. After the retune the drop is 36.7/44.3/48.3, so the 30 check passes.

### Q-079 · 2026-10-08 · Game Designer -> Gameplay Programmer · answered D-079
P4-03 data. Debt, the first payment and the medical bill must read `player_scaling.json` `payment_pct_by_players` (59/85/101, D-079), not `pct_by_players`. `debt.json` `derived_by_players` holds the expected table (2p 767/150/617, 3p 1105/217/888, 4p 1313/258/1055); use it as a test (P4-07).

**Answer (QA, P4-03 review):** already covered by D-079 "How to apply" (Gameplay makes debt and medical bills read `payment_pct_by_players`, P4-10 acceptance). The `derived_by_players` test table stays useful for P4-07/P4-10.

### Q-080 · 2026-10-08 · Game Designer -> Gameplay Programmer · answered
P4-03 animals. No `animals` table is in `Data.TABLES`, so species (chicken, pig, cow), `animals_per_species` 2, `animals_per_fence_break` 2, `animal_out_at_dusk_coins` 10, `animal_escape_m` 60 and `round_up_rounding` are records in `season.json`; the `round_up` hold (4 s) is in `labor.json`. Say if P4-08 wants a separate table. Out-at-dusk cost is billed at dawn after the medical bill with the 4-coin floor (doc 02 s10.1).

**Answer (Gameplay, P4-08):** no separate table. `animals.gd` reads the `season.json` records; `Data.TABLES` unchanged. Billing is in `Death.dawn()` via `Animals.bill_dusk(farm)`.

### Q-081 · 2026-10-08 · Game Designer -> Technical Artist · open
Cart speed by pushers is set: 1.0/1.6/2.0/2.4 m/s for 1 to 4 pushers (`ai_director.json` `profile_harvest_moon`, placeholder, doc 02 s9). Doc 05 s13 still says "placeholder until doc 02/03 says"; please update it. At 1 pusher the 147.9 m route takes about 148 s, so the 900 s cap stays reachable.

### Q-082 · 2026-10-08 · Game Designer -> Gameplay Programmer · open
Q-070 items 2 and 4. Doc 03 s10.1 now has the dawn trample placement rule: weighted pick by closeness (weight 1/(1+d/20)), a previously trampled plot at half weight, and bare plots churned (no coins lost) when crops are fewer than the count. The build differs (nearest crops, bare plot never trampled). Placeholder; change Sabotage if you agree, or say what is unbuildable.

### Q-083 · 2026-10-08 · Game Designer -> Director · open
FYI, no doc 01 change. Short-season `debt_total_4p` retuned 557 to 360 (`sim`, doc 01 Saving says the sim sets it). 3p/4p clear about 66%, 2p about 99%; report only, no target. Six roles (carpenter, medic, night_owl, radio_operator, warden, medium) carry placeholder perk numbers (D-077); scarecrow, lantern and flare effect numbers are placeholders in `store.json` and doc 03 may overrule.

### Q-084 · 2026-10-08 · QA -> Director · open
P4-03 review findings (non-blocking; QA PASS). Probes: 4,000 runs, seed 1, one change each from the delivered data; first/final clear 2p, 3p, 4p.
1. **`pumpkin_gnaw` is free in the sim.** It has no fix, so `sim.py` charges no chore, and the median policy's Large pumpkin ignores gnaw. Enabled, it only dilutes the disturbance pool: gnaw off alone gives final 59.6/55.8/61.1 against 62.9/58.9/62.3 delivered, so gnaw adds about 3 points. Both new disturbances off gives 66.3/60.0/63.8: the net cost of P4-03 is 1 to 3 points, not the 8 to 11 the handoff reports before its placeholder moves. Ask: should the sim charge guarding time for gnaw (doc 03 s10.1 gnaw rule, "no living player within 20 m for the last 60 s")? Suggest Game Designer, P4-10.
2. **`animal_out_dusk_pct` 5 (policy, placeholder) is the most sensitive new knob.** 0 gives 64.0/60.5/65.0; 25 gives 59.1/51.1/52.3 (3p and 4p fail 55); 50 gives 55.1/42.3/40.1. 3p final sits about 2 points above the 55 floor (56.8 at seed 3). `animals_per_fence_break` 3 instead of 2 costs 1.0 to 1.6 points; `round_up` hold 0 gains under 1 point. P4-10 logs should measure how often animals are still out at dusk.
3. **Perk multipliers with no base value:** `roles.json` warden `flare_refill_mult` 0.5 (the flare refills "each_dawn", no timer to multiply) and rancher `animal_alert_range_mult` 1.5 (no animal alert range exists). Game Designer to define the base or reword before P4-09.
4. **Two copies of one number:** `difficulty.json` `short_season.pumpkin_grow_days` and `pumpkin.json` `short_season.grow_days` (both 1); the sim reads only the pumpkin one. Game Designer: keep one.
5. **Live game:** `sabotage.gd` now sees `broken_fence` and `pumpkin_gnaw` in its pool. `_place` returns false for them, so it falls through to another kind and the `sabotage_plan` log lists them. Harmless (2-instance bot run clean); P4-11 builds them.
6. **Short season 2p 99.3% vs 3p/4p about 67%** (report only). Inference: 2p plants 14 plots (7 per player) against 16 at 3p/4p, while its debt is 59% against 85/101%. A 2p-specific short-season debt or a target would settle it.

### Q-095 · 2026-10-08 · Game Designer -> Director · answered D-083
D-082 item 1 breaks the full-season gate, so I stopped it and left it off (`charge_gnaw_guard` false in `tools/sim/policies/median.json`). Charging `pumpkin.json` `rules.guard_s` 60 s plus a 57.4 m round trip per `pumpkin_gnaw` drawn gives final clear 2p/3p/4p 54.8/52.2/62.1 (seed 1), 55.6/51.5/61.6 (seed 2), 55.4/51.3/61.5 (seed 3); the 55 floor fails at 3p (and 2p seed 1) and the spread is 9.9/10.1/10.2. First clear moves at most 0.3 (seed 1 2p 87.1 to 87.4). Options: (a) keep it off and treat gnaw as free (QA's Q-084 item 1 view); (b) turn it on and retune a P4-03 placeholder one knob at a time (for example `animal_out_dusk_pct` 5 to 0, which Q-084 item 2 measured at about +1 to +4); (c) charge less time. I did not pick one because (b) and (c) move placeholders the D-082 text did not name. Also: item 5 (short season) was tuned with item 1 off; re-check it if you pick (b) or (c).

**Answer (Director, D-083):** keep the charge off; P4-05 logs guarding and repair time per gnaw, and the charge is set from P4-10 live logs. QA notes the model charges night guarding to the day labour budget and only on draw nights; revisit both when setting it.

### Q-085 · 2026-10-08 · Gameplay Programmer -> Network & Voice · answered (P4-14)
P4-04. Three wire gaps, all worked around without editing `net.gd`: (1) `apply_plot_changed` has no crop argument, so the crop rides in the state string (`ripe:pumpkin`, `Plot.wire_state` / `apply_state` parse it). (2) `apply_clock` has no season-over flag; a client learns the season ended from the final Dawn Report (`Clock.end_season()` on show). (3) The picked seed rides in the hold verb (`plant:<crop>`), so no seed RPC. Please confirm or give real arguments (a `crop` arg on `apply_plot_changed`, a `season_over` arg on `apply_clock`); I will switch when they exist.

**Answer (Network & Voice, P4-14, 2026-10-09):** confirmed as built; no new arguments. (1) `ripe:pumpkin` in the state string is one reliable string per plot change, cheaper than a second arg, and late joiners get it from the same parser. (2) Season-over from the final Dawn Report is right: the season ends at that dawn, and the report reaches every peer reliably on channel 0 (P4-12 can add a flag later if the awards screen needs it before the report). (3) `plant:<crop>` keeps the hold verb host-validated like every other hold. Adding args would change your `farm.gd` callers during parallel P4 work for no gain.

### Q-086 · 2026-10-08 · Gameplay Programmer -> AI Programmer · answered P4-11
P4-04 (also answers Q-082 for my side). (1) `Death.step_farm_damage` (doc 02 s9 step 5) calls `Sabotage.dawn_trample()` if it exists. Please make `_dawn_trample` public as `dawn_trample()` and drop its own `Clock.phase_changed` dawn connection (sabotage.gd line 74-79); today the trample runs before cash-in, out of doc 02 s9 order. (2) Q-082's placement rule (weighted pick by closeness, half weight for plots trampled last dawn) lives in `sabotage.gd`, not my path, so I did not build it. (3) `farm_damage` (line 325) uses the turnip price per plot; use `Plot.sell_value()` (crop in the ground) instead, so a trampled pumpkin or moonflower costs its own price.

**Answer (AI Programmer, P4-11):** all three done. (1) `dawn_trample()` is public, and the dawn `phase_changed` hook is gone, so only Death step 5 runs it. (2) Doc 03 s10.1 placement is `SabotageLogic.trample_pick`: weight `1/(1+d/20)` from the creature's dawn position, half weight for a plot whose same crop was trampled at an earlier dawn, and bare plots churned with no coins lost. The `trample` log gains `churned` and `full_wipe`. (3) `farm_damage` sums `Plot.sell_value()` of the crops lost.

### Q-087 · 2026-10-08 · Gameplay Programmer -> Audio Designer · open
P4-04 / D-081 item 2. `DawnReport._close()` now logs `dawn_report_closed {day}` on every peer. `Soundscape` should listen to `Log.logged` for that name instead of reading `DawnReport._open`. Doc 05 s18 lists the event and the four `audio_*` events.

### Q-088 · 2026-10-08 · Gameplay Programmer -> Director · open (item 1 settled by P4-07: `Crops.first_paid` reads `Debt.first_made`)
P4-04 gaps for later rows, no doc 01 change. (1) `Crops.first_paid` (pumpkin `first_payment_made` unlock) is `day > first_payment_dawn` until P4-07 records the real payment. (2) The Season Awards screen is not built; `Clock.season_ended` and the final Dawn Report ("THE SEASON IS OVER") are its hook. (3) The final night runs as a normal night until the Harvest Moon (cart, P4-09 per the table). (4) Pumpkin seeds cost `seed` 10 each; the free Prize Pumpkin seed (D-017) is not modelled (P4-05).

### Q-090 · 2026-10-08 · Gameplay -> Game Designer · open
P4-08 placeholders in code with no data home: animal alert range base `ALERT_M` 35 m (creature distance for the panic sound; rancher `animal_alert_range_mult` 1.5 multiplies it, Q-084 item 3), animal walk 0.9 m/s and run 3.2 m/s, panic gap 12 s, idle-call gap 25 to 50 s. Say the base alert range and I move all of them to `season.json`. Until then they are consts in `game/farming/animals.gd`.

### Q-091 · 2026-10-08 · Gameplay -> AI Programmer, Level Designer · answered P4-11 (AI side)
FYI P4-08 edits in your paths, kept minimal. AI: `game/ai_director/sabotage.gd` (`_place(&"broken_fence")`, `fixed()`, `_mark`, `fix_jobs`); `tests/creature/test_director_logic.gd` day 2/3 pool asserts updated (P4-03 enabled broken_fence). Level: `game/world/build_farm.py` pen north/west/east walls split into 6 sections in group `fence_sections`; `farm.tscn` and `farm_phase1.tscn` regenerated. Veto or restyle as you like; the group name and `Animals.fence_points()` are the contract.

**Answer (AI Programmer, P4-11):** accepted as built for my paths. P4-11 adds that `repair_fence` (like every creature-damage fix, D-085) spends 1 scrap.

### Q-092 · 2026-10-08 · Gameplay -> Network & Voice · open
FYI P4-08 added RPC `apply_animals(kind, data)` (authority, reliable, 5 Hz snapshot plus events) to `game/net/net.gd`. Check the channel and rate fit your budget.

### Q-093 · 2026-10-08 · Gameplay -> Gameplay (P4-04, P4-09, P4-10) · open
P4-04: `Death.dawn()` calls `animals.bill_dusk(farm)` after the medical bill (3 lines); merge with the season dawn work. P4-09: set `Game.players[peer].role` to `&"rancher"` and the round_up hold shortens (ceil 4 x 0.6 = 3 s) with no more code. P4-10: log `animals_out_at_dusk` {day,out,total,breaks_today,fence_still_broken,players} measures Q-084 item 2; `animal_dusk_bill` has the cost.

### Q-089 · 2026-10-09 · QA (P4-08 review) -> AI Programmer · answered P4-11
Pre-existing, not P4-08: with `--no-phase1`, `game/creature/creature.gd:876` `_in_sanctuary` repeatedly errors on key `'sanctuary_m'` because `_num` is never filled without the phase1 table. Also for P4-10 (doc 06 s5): `Animals.bill_dusk` clamps headcount to 2 while `Death.bill_for` does not, so solo play pays 59% animal fee but 100% medical bill.

**Answer (AI Programmer, P4-11):** the first part is fixed. `creature.gd` now fills `_num["sanctuary_m"]` before the Phase 1 table check, so `--no-phase1` runs no longer error. The `bill_dusk` clamp is a Gameplay path, so P4-10 handles it.

### Q-096 · 2026-10-09 · QA -> Director · answered D-084
P4-05 review. (1) `lift_prize` works on any day, so players can move the Prize Pumpkin anywhere, for example next to the barn door. Doc 01 "The Prize Pumpkin" places it at least 30 m from any door and only moves it to the barn at Harvest Moon dusk; doc 02 s6 has no carrying rule. Relocation also makes the missing lit-doorway exclusion (guard time inside a doorway's light still counts) matter, since 30 m placement plus a 20 m radius kept doorways out of range. Options: allow lift only on the final day (P4-12's loading), or keep free carrying and build the doorway exclusion. (2) Carrying the pumpkin does not block taking a can, shovel or trap (`held_prize` is checked nowhere else); pick a hands rule with (1). (3) `gnaw()` drops the size at once; doc 03 s10 says "in the morning". P4-11 should call it at dawn. (4) HUD has no text for refusals `carried`, `judged`, `not_holding` on the pumpkin. None blocks P4-05.

**Answer (Director, D-084):** doc 01 wins. The pumpkin stays on its patch until the Harvest Moon dusk move to the barn; P4-12 gates `lift_prize` to that dusk and makes carrying block other holds. The doorway-light exclusion is not needed while it cannot be moved.

### Q-100 · 2026-10-09 · Gameplay Programmer -> Director · answered D-085
P4-06: `scrap` is bought and counted (`Store.take_scrap()` spends the free scrap first), but no repair consumes it, and nobody has scrap on day 1 (only dawn step 7 grants one). Gating generator or trap repair on scrap would break day-1 bots and tests, so I did not. Which repairs cost scrap (doc 01 Nights / doc 02 s10), and does day 1 start with one free scrap? Settles: the call sites of `take_scrap()`.

**Answer (Director, D-085):** doc 01 settles it: every fix of creature damage (the sabotage.json fix verbs, generator repair included) costs 1 scrap; no free scrap on day 1, since no damage exists before the first night and dawn step 7 grants one. P4-11 wires `take_scrap()` into those fixes.

### Q-101 · 2026-10-09 · Gameplay Programmer -> AI Programmer · answered P4-11
P4-06 made additive edits in `game/creature/creature.gd`: `flare_hit(seconds)` (forces Retreat, reason `flare`, restarts the timer on a second hit), `_flare_retreat_s` (Retreat exit uses the longer of it and `retreat_s`), and `_scarecrow_in_way(dir)` (lurk/lure/stalk will not step closer than `creature_avoid_m` to a node in group `bought_scarecrow`; chase and retreat ignore it). Please review. The flare hit radius reuses `noise_flare` 70 m, an inference; confirm or give a different range.

**Answer (AI Programmer, P4-11):** the three edits are accepted. The 70 m is kept for now, but the inference is weak. Doc 03 s3.1 has `flare` 70 m as a placeholder *hearing* range, and no doc gives a hit range. Q-114 asks the Game Designer for a `flare_gun` hit range; switch to it when it lands.

### Q-102 · 2026-10-09 · Gameplay Programmer -> Network & Voice · answered (P4-14)
P4-06 added two rpcs to `game/net/net.gd`: `request_store(op, arg)` (any_peer, reliable) and `apply_store(state)` (authority, reliable). Please review. The 2-instance bot run passes; the join path sends `apply_store` once on `farm_state`.

**Answer (Network & Voice, P4-14, 2026-10-09):** confirmed. Typed `StringName` args stop junk types at the RPC layer, the host validates every buy through `Store.why_not` (unknown id is `no_item`, `tests/gameplay/test_store.gd`), refusals go back to the sender only, and an unknown op is ignored. `apply_store` sends the whole state, which is small (a few counts and lists), so resending it on each change is fine on channel 0. P4-14 builds on it: walkie ownership reads `Store.owns`, spare batteries come out of `Store.team`, and a 2-instance run bought a client walkie through it.

### Q-103 · 2026-10-09 · Gameplay Programmer -> Level Designer · open
Bought scarecrows (store.json `scarecrow`, max 3) are placed at the player's feet, 3 m apart, anywhere. Sabotage already uses `scarecrow_03..07` marker spots. Should bought scarecrows snap to a marker list (new group), or stay free-placed? Settles: whether `place_scarecrow` needs spot markers.

### Q-108 · 2026-10-09 · Gameplay -> Game Designer · open
P4-07 early payment has no data home. Code const `Debt.EARLY_STEP` = 50 coins per `pay_early` hold at the sell box, and `pay_early` hold time 2 s sits in `Interactable.INSTANT_S` (no `labor.json` entry; I do not own it). Doc 01 says only "allowed at any dawn"; I allow it any time, to first then final (`early_order`, placeholder). Give the step size and hold seconds a record and I move them. Also: pumpkins unlock only at the first-payment dawn even if early payments already cover the first payment.

### Q-109 · 2026-10-09 · Gameplay -> Director · open
P4-07 gaps outside its row. (1) A missed final payment logs `season_lost` and sets `Debt.lost`; the clock still ends the season at its normal next step, and the win (cart out the gate) is P4-12. (2) The Dawn Report ledger has no payment or foreclosure row yet (`dawn_report_logic.gd` is not mine); `money_changed` with reason `payment` and `payment_made`/`foreclosure` events carry the data for P4-15. (3) The "imposter wins if the farm forecloses" role rule (P4-09) can read `Debt.foreclosed` on group `debt`. (4) Short season: debt from `difficulty.json` `short_season` (360, 2p 410) is the base, and the headcount pct (`payment_pct_by_players`) still scales it, as `tools/sim/sim.py` `debt()` does (QA checked); no first payment.

### Q-110 · 2026-10-09 · QA -> Director · answered D-086
P4-07 review (QA PASS after fixes). (1) QA fixed `Store.seize` (P4-06): a per-player upgrade owned by two players now leaves one owner (the highest peer id loses it, placeholder); before, both kept it. Ruling: one Foreclosure seizure takes one item. (2) QA fixed `Debt.pct_for` to clamp the headcount to 2..max like traps and sabotage; a no-lobby `--host` run recorded dawn 1 at 1 player (pct 100), so 2-instance logs showed 843 total instead of 767. Debt still ignores the farm's `--headcount=` QA override. (3) `apply_debt` was added to `game/net/net.gd` without a review question to Network & Voice (P4-06 filed Q-102 for its rpcs). (4) A seized bought plot pair is relocked with its crop left on it (`Store.seize`); seized starting plots are cleared. Pick one rule. (5) Early payment works any time at the sell box; doc 01 and doc 02 s7.4 say "at any dawn" (Q-108 asks the Game Designer for the numbers; the timing is a doc reading for you).

**Answer (Director, D-086):** (1) and (2) accepted. (3) Network & Voice reviews `apply_debt` with Q-102 in P4-14. (4) Seized plots are cleared, bought or starting. (5) Early payment at the sell box any time stands; doc 02 s7.4 gets the wording on the Game Designer's next pass.

### Q-112 · 2026-10-09 · AI Programmer -> Director · answered
P4-11 / D-085 scope. Scrap is charged only on fixes of creature damage: `repair_generator`, `bury` (dead crow), `pull_seeds` (strange seeds) and `repair_fence`. Plant (trample), take_can (stolen tool), wash and refuel are not charged. They undo damage with their own cost (a seed, a Taint, a can of fuel from the free drum). D-085 says "the sabotage.json fix verbs". Read literally, that also charges re-planting a trampled plot. Confirm the narrower list, or name the verbs to add. A refusal logs `hold_refused` `no_scrap`. Bots buy one scrap (15 coins) when the team has none. Settles: the `take_scrap()` call sites in `sabotage.gd` and `generator.gd`.

**Answer (Director, 2026-10-09, recorded by QA):** the narrower list stands. Re-planting a trampled plot does not cost scrap. Only the fix verbs `bury`, `pull_seeds`, `repair_fence` and `repair_generator` spend 1 scrap. The P4-11 build matches; QA ran the `no_scrap` refusal and the spend on `repair_generator` and `pull_seeds` (`tests/creature/test_p4_11_e2e.gd`).

### Q-113 · 2026-10-09 · AI Programmer -> Game Designer, Gameplay Programmer · open
P4-11 / Q-070 item 6. `stolen_tool` still steals only cans (water and fuel). Doc 03 s10 says "wash, buy back (the tool is lost until found)". The other tools give no theft that matters. The shovel is unlimited at the pegboard. Bear traps are already taken by `pegboard_theft` (D-053). The flare gun is a store item that refills at dawn. A buy-back needs a store.json record for each tool (Gameplay path, doc 02 s10 price) and a per-tool count that theft can lower. Ask: (1) which tools a steal may take besides cans, (2) the buy-back price. Today the can fix is pick-up (Taint) plus wash. Settles: the `stolen_tool` branch of `Sabotage._place`.

### Q-114 · 2026-10-09 · AI Programmer -> Game Designer · open
P4-11 inferences, each a placeholder in code. (1) Full wipe "damage doubles" (doc 02 s14) is read as doubled dawn-trample plots, `season.json` `full_wipe_damage_mult` 2. It is not doubled coins per plot. The extra traps (`full_wipe_extra_traps` 2) alternate bear and pit, from doc 03 s9's "1 bear + 1 pit". (2) The trample distance is measured from the creature's position at dawn, which stands for "where the creature roamed" (doc 01 "Dawn"). (3) Flare hit range: `creature.flare_hit` uses `noise_flare` 70 m (a hearing range, doc 03 s3.1). Give a `flare_gun` hit range (store.json), or confirm 70 m. (4) Nightmare drops voice tells (`tell` none) but keeps the state ambience. Confirm or change doc 03.

### Q-130 · 2026-10-09 · Gameplay -> Director · answered by Director from doc 01 l.443/445
P4-15 reads Q-109 the direct way (inference): the season is won if the final payment was made (`Debt.lost` false when `Clock.season_ended` fires), lost if missed; the Season Awards show at either end. A mid-season Foreclosure (missed first payment) is a penalty, not a loss, so it shows no awards. P4-12's cart finish adds no gate here; if doc 01 wants "cart out the gate" as the win, say so and P4-12 sets a flag the card reads (`SeasonAwards._host_end`, `lost` arg). The Dawn Report payment row (Q-109 item 2) is not added, since P4-11 edits `dawn_report.gd`; the data (`money_changed` reason `payment`, `payment_made`) is in the log. Card headlines ("THE DEBT IS PAID", "THE BANK TOOK THE FARM") are placeholders for the Game Designer.

**Answer (Director, from doc 01 l.443/445 "Winning and losing", recorded by QA in the P4-15 review):** win = the final payment made AND the cart out the gate with at least one player alive. Lose = the final payment missed, OR everyone dead on the Harvest Moon before the cart is out. A Foreclosure alone is not a loss. P4-12 provides a host flag `cart_out: bool` plus a `cart_out` signal and log event; the end card reads it. QA wired it in `SeasonAwards._host_end`: `lost = Debt.lost or <Harvest Moon wipe> or (cart provider present and not cart_out)`; the provider is looked up as the first node in group `cart` with a `cart_out` property (placeholder name, Q-131). With no provider yet, a paid debt with no Harvest Moon wipe counts as the cart out (marked placeholder in code).

### Q-116 · 2026-10-09 · Network & Voice -> Director, Game Designer · open
P4-14. `roles.json` `radio_operator` `walkie_range_mult` (1.5) has nothing to multiply: doc 06 s10 gives walkies unlimited range, while doc 01 "Roles" says the Radio Operator's walkie "reaches further". Built: `battery_transmit_mult` (270 s) only; range ignored. Options: give walkies a range (then a placeholder number, and out-of-range frames dropped by the host), or drop the perk and keep unlimited range. Settles: whether `Walkie.transmit` checks distance. Also an inference to confirm: spare `walkie_battery` purchases are a team pool, and the first flat walkie takes one (doc 02 s10 lists them as a team item).

**Answer (QA, P4-14 review, 2026-10-09):** battery part only: team pool stands. `store.json` `walkie_battery` is `per_player: false`, so bought batteries land in `Store.team`, and doc 02 s10 names no owner. Range (`walkie_range_mult`) stays open for the Director.

### Q-131 · 2026-10-09 · QA -> Director, AI Programmer (P4-12), Network & Voice · open
P4-15 review. (1) P4-12: `SeasonAwards` (`game/ui/season_awards.gd` `_cart()`) finds the cart flag as `get_tree().get_first_node_in_group(&"cart")` with a `cart_out` property. Put the cart root in group `cart` with `var cart_out: bool` (host), or tell Gameplay the real path so `_cart()` changes; until then the win falls back to "debt paid and no Harvest Moon wipe". The Harvest Moon wipe check reads the `death` log event's `phase` == `harvest_moon`, so the P4-12 clock phase name must stay `harvest_moon`. (2) Network & Voice: P4-15 added `Net.apply_season_awards(result)` (host to all, reliable, text only) to `game/net/net.gd` without a question to you, as with `apply_debt` (Q-110 item 3). Please review it. (3) The season tally (`SeasonAwards._tally`, `_hm_wipe`) is memory only; P4-10 must save it at dawn or a loaded season's awards count only the nights since the load.

**Note (QA, P4-10 review):** item 3 closed: the season tally and `_hm_wipe` save at dawn (Q-123).

**Note (QA, P4-12 review):** item 1 closed: `game/items/cart.gd` joins group `cart` with `var cart_out`; the `_cart()` placeholder comments are removed and the win needs `cart_out` when a cart exists.

### Q-120 · 2026-10-09 · Gameplay -> Network & Voice · open
P4-10: saves live under `Net.user_dir() + "saves/<season_id>/"` (per profile), not `user://saves/`. Doc 06 s5 line ~268 still says `user://saves/<season_id>/`; please reword. I also added to `game/net/net.gd`: signal `host_left(how)`, rpcs `apply_host_leaving`, `request_leaving`, `apply_dawn_save` (channel 3), and `_log_host_left` no longer calls `Game.is_host()` (it errored on a timeout after the peer was gone). Please review. Inference to settle: a refused or pending peer gets no position sends (P2-18 `Net.send_bytes` skips `_refused`/`_pending`); I did not add a separate test.

**Note (QA, P4-10 review):** the refused-peer inference holds by code (`Net.send_bytes` skips `_refused`/`_pending`, `to_peers` sends a refused peer only `apply_join_refused`) and by runs: four 2- and 3-instance runs with a `not_in_season` refusal logged 0 error lines (P2-17 saw "Unable to send packet" when it failed). The doc 06 reword and the RPC review stay open for Network & Voice.

### Q-121 · 2026-10-09 · Gameplay -> Network & Voice · answered by QA
P4-14 Walkie (main 9ff9f3d, not in my worktree) erases `battery[peer]` in `_on_player_left`. The save keeps batteries by uid (`Save._remap_walkie`), but a farmhand who is absent at the dawn save loses their charge. Keep a `battery_by_uid` entry on leave instead of erasing? My walkie code is untested against the real `walkie.gd`: please run `tests/` for it after merge.

**Answer (QA, P4-10 review, 2026-10-09):** done. `walkie.gd` `_on_player_left` no longer erases `battery[peer]`; `Save` keys it by uid through `Save.uid_of` (which falls back to `Save.peer_uid` once `Net.profiles` has dropped the leaver) and `_remap` gives a rejoiner their battery and store ownership back, from the same match or from a loaded save. `tests/gameplay/test_save.gd` checks it against the real `walkie.gd`.

### Q-122 · 2026-10-09 · Gameplay -> AI Programmer · open
P4-10 saves the creature body (P4-13) and forces it on load (`creature_body` `forced:"save"`). The AI Director's cross-day state (day arc, ramp row, trap pool), the sabotage budget carried over and the lure memory are not saved: they need to join group `saveable` with `save_key`, `save_state() -> Dictionary` (JSON-safe) and `load_state(d)`. Until then a loaded season restarts those from the day's defaults.

### Q-123 · 2026-10-09 · Gameplay -> Director · answered by QA
P4-15 SeasonAwards (main 10c609a) is not in my worktree, so I could not edit it. Needed in `game/ui/season_awards.gd` (host only; `_tally` is {category: {peer: n}}, `_hm_wipe` is a bool): in `_ready` under `if Game.is_host():` add `add_to_group(&"saveable")`; add `var save_key := "season_awards"`, `func save_state() -> Dictionary: return {"tally": Save.tally_state(_tally), "hm_wipe": _hm_wipe}`, `func load_state(d: Dictionary) -> void: _hm_wipe = bool(d.get("hm_wipe", false)); Save.tally_load(_tally, d.get("tally", {}))`. `tests/gameplay/test_save.gd` proves the round trip with a stub carrying this exact code (`saveable_awards_stub.gd`). After merge, swap the stub for the real node. Closes Q-131 item 3.

**Answer (QA, P4-10 review, 2026-10-09):** wired. `game/ui/season_awards.gd` now has `save_key`, host `add_to_group(&"saveable")`, `save_state()` and `load_state(d)` as above; the stub is deleted and `test_save` uses the real node. Q-131 item 3 is closed.

### Q-124 · 2026-10-09 · Gameplay -> Game Designer · open
P4-10 D-079 caveats. Measured: `Debt.total_for([101], 85, 3)` = 1135 and first payment 223 (matches doc 09 s3); a solo bill now reads the 2-player percentage (59%, Q-089). Not measured: `death_night_weight` 3, the 4-player plot-price cliff, `animals_out_at_dusk` rate, the pumpkin guard times (D-083) and Medium drop 37/44/48 need full-season bot runs (`--bots` with a long clock) and none were run in this task. `pumpkin_gnaw` logs the guard time, so a 3-day season with 2+ instances gives it. What would settle them: three full short-season runs per player count with `tools/sim`.

### Q-145 · 2026-10-09 · QA -> Network & Voice · open
P4-10 review, first live `not_in_season` refusal (a loaded save's lobby, D-048). The host always refuses the stranger correctly, but in 1 of 4 runs the joiner never got `apply_join_refused`: it logged `net_server_disconnected` then `net_host_left {"how":"timeout"}`, so it would show the host-left card instead of "That farm's season belongs to other players." The failing run had 3 instances with two clients' clip transfers on channel 3 in flight (`--load=<id> --lobby-start=2`, qa_b host, qa_a and qa_c joining; logs were in a temp folder). Inference: `Net._refuse` calls `ENetMultiplayerPeer.disconnect_peer(id)` 0.5 s after the RPC, and ENet's immediate disconnect drops reliable packets still queued. What would settle it: switch to `get_peer(id).peer_disconnect_later()` (it waits for the queue), or close only once the joiner acknowledges, then run the 3-instance case about 10 times.

### Q-146 · 2026-10-09 · QA -> Director · answered
`production/handoffs/img/P4-19/*.png` has no `.gdignore`, so every headless import writes six `*.png.import` files into `production/handoffs/img/P4-19/` and they show as new files. I deleted them in the P4-10 worktree. Fix: add an empty `production/handoffs/img/.gdignore` (the Director owns `production/`), or a `.gitignore` rule.

**Answer (Director, 2026-10-09):** moot. Those images came from a rival P4-19 build in another session that was not merged; main has no `production/handoffs/img/`. Any future handoff image folder gets an empty `.gdignore`.

### Q-150 · 2026-10-09 · QA -> Director, Gameplay Programmer · open
P4-20 review. (1) Director, with a CEO night screenshot: doc 07 s5 says a player "cannot see a creature at 25 m", but its silhouette rule calls a creature against the sky line the intended scare. In the open yard at night (camera at -20,1.65,30, looking at 25 m), the P4-19 gaunt and boar read as dark shapes against the horizon fog band, with no detail and no ember pixels. In the corn they are not visible. This is not new: night fog, ambient and sun values are unchanged by P4-20 (mean luminance 33.4 before, 33.6 after). Settle: is the sky-line silhouette at 25 m in the open yard intended, or must night fog get denser? Low quality has no ground fog (doc 07 s6), so a low-quality peer sees slightly further (mean 35.3). (2) Gameplay: `creature.gd` still spawns a capsule. When the P4-19 glb is wired, call `CreatureLook.apply(root)` and `CreatureLook.ghost_view(root, on)` (`game/render/creature_look.gd`). The lantern owner calls `CreatureLook.lantern_glass(root, lit)`. A held lantern's shadow must be off when `WorldLook.low_quality()` is true.

**Director note (2026-10-09):** a second session reviewed its rival P4-20 build (41c5ab1, not merged) and listed six must-fixes before STOP 5. Checked against main: (1) P4-20 is landed as 9403a5e, the reviewed build. (2) The capsule is still in game: the Gameplay wiring above stands. (3) No snap into the Harvest Moon look on main: `world_look.gd` eases in over `HARVEST_EASE_S`. (4) The 25 m night shot was taken by QA; the ruling above is still open. (5) Gaunt depth 1.06 m, boar length 2.38 m and husk depth 1.07 m accepted by P4-19 QA; doc 07 s11.7 updated to the built sizes. (6) No shimmer: `ghost_rim.gdshader` on main has no TIME input.

### Q-125 · 2026-10-09 · AI Programmer -> Gameplay Programmer, Network & Voice · open
P4-12 short season: `difficulty.json` `short_season` (3 days, doc 02 s16) is chosen only by the dev flag `--short-season` (sets `Game.difficulty`; `Data.value(&"season", &"season_days")` reads the override). No lobby pick and no replication of the choice to clients yet; clients only follow the host's clock. Who adds the lobby option and sends the difficulty to joiners (P4-11 difficulty settings or P4-10 save/join)?

**Note (QA, P4-12 review):** replication closed by P4-11 (`apply_session_state`, `apply_group_settings`; a 2-instance run logs `group_settings short_season` on the client). The lobby pick stays open: see Q-155.

### Q-126 · 2026-10-09 · AI Programmer -> Game Designer · open
P4-12 Prize Pumpkin timing (D-084). Built: `lift_prize` opens at the final dusk and through the Harvest Moon; the pumpkin is judged when the loaded cart goes out the gate (with its escort bites), and the payout is paid once at the final dawn (`pumpkin_payout`, dawn step 2). A cart not out, or out unloaded, pays nothing. Inference from doc 01 "The Harvest Moon" and doc 02 s9; please confirm in doc 02 s6/s9.

**Note (QA, P4-12 review):** consistent with D-084 and P4-12 acceptance step 2. A cart not out is a season loss anyway (Q-130), so its zero payout changes no outcome. Stays open for the doc 02 wording.

### Q-127 · 2026-10-09 · AI Programmer -> Game Designer · open
P4-12 cart squeak has no data row. Code const `Cart.SQUEAK_M` = 25 m, one `cart_squeak` Noise per 1 s while moving (placeholders). The creature hears it (`heard_cart_squeak`) and goes to the cart. Please add `noise_cart_squeak` to `creature.json` (doc 03 s3 noise table).

**Note (QA, P4-12 review):** doc 03 has no squeak radius; stays open for the Game Designer.

### Q-128 · 2026-10-09 · AI Programmer -> Network & Voice · open
P4-12 added `Net.apply_cart(offset, act, loaded, pushers, stall, cart_out, knocked)` (authority, reliable), sent on every change and every 1 s while the cart moves (`Cart.SYNC_EVERY_S`, placeholder). Every peer moves the body along the curve from `offset`. Please review the cadence and channel; a 2-instance run shows the client's `cart_seen` per act.

**Note (QA, P4-12 review):** 2-instance run (port 49470): the client logged `cart_seen` for acts 1, 2 and done with offset 69.3, equal to the host. Cadence review stays open for Network & Voice.

### Q-129 · 2026-10-09 · AI Programmer -> Game Designer · open
P4-12 Harvest Moon rules built by inference, please settle in doc 03 s14: (1) knock-offs only in act 2; act 3 (last `gate_run_m` 30 m) is a chase, and the AI Director allows chase only in act 3. (2) After a knock-off the creature bites the stalled cart once, then backs off a straight 30 m (placeholder; the farthest cover would leave act 3 with no creature near). (3) In acts 2 and 3 the AI Director nudge jumps to the players' region every tick with no hop or cooldown. (4) The cap counts out only at x > 78; the gate (route end) ends the Harvest Moon early. (5) `Cart.BED_Y` 0.9 m is read off `prop_cart.glb` by eye (Technical Artist).

**Note (QA, P4-12 review):** items 1 and 4 match doc 03 s14 and doc 01 "Length". Items 2, 3 and 5 stay open. The route ends at x = 105 exactly, while acceptance and doc 03 s14 say the gate is at x > 105: see Q-155.

### Q-155 · 2026-10-09 · QA -> Director, Gameplay Programmer · open
P4-12 review. (1) The short season is the difficulty id `short_season` (`--short-season`, `--difficulty=short_season`). The lobby F7 list (easy, normal, nightmare) cannot pick it, and it cannot combine with Easy or Nightmare. Doc 01 lists the short season under "Saving", not "Difficulty" (inference: it is a separate group option). Decide: separate lobby toggle, or a fourth difficulty entry. (2) `World/CartRoute` ends at x = 105 exactly; P4-12 acceptance and doc 03 s14 say "gate at x > 105". The cart counts out at the route end, so behaviour is right; confirm the wording or move the route end past 105.

### Q-156 · 2026-10-09 · QA -> Game Designer · answered (doc 02 s18.5; compare moved to `tools/sim/compare.py`)
P4-18. `tools/qa/sim_compare.py` is QA's stand-in for the `compare` command doc 05 s18 names. It reads
host logs (jsonl or console), and per dawn 2 to 8 compares the live median bank as % of the next
scheduled payment with the sim median at the same player count and difficulty (doc 02 s18.5, 15
points). *Inference:* the denominator is the scheduled payment with no penalty or deferred bill (the sim
logs no per-run `owed`); dawn 8 uses the bank before the final payment. Live `due` matched the sim
denominators at 2p, 3p and 4p (150/617, 217/888, 258/1055). Please confirm the denominator in doc 02
s18.5, or build `tools/sim/sim.py compare` and QA will switch to it.

### Q-157 · 2026-10-09 · QA -> AI Programmer · answered (CEO 2026-10-09: yes, task P4-21)
P4-18. Bots never go inside at night and die nearly every night (OPEN_ISSUES "Found at the P4-18
review" item 1); they also never plant the Prize Pumpkin (OPEN_ISSUES "Found at the P4-12 review" item
1). So headless seasons cannot reach a win and cannot be compared with the sim. Not a Phase 4 gate item
(humans run the seasons), but a bot that hides at night and saves for the payment would let QA test the
economy in hours instead of evenings. Decide if it is worth a task.

### Q-158 · 2026-10-09 · QA -> Gameplay Programmer · open
P4-18. With `--bots=N`, `plots_open` logs `headcount 1`: `Farm._set_headcount` runs before the bots
join and is not called again, so `plot_ceiling()` uses the 2p row at 3p and 4p. Debt does rescale
(`debt_rescaled`). Humans who join in the lobby are counted at match start, so this is bot-only
(inference: the lobby start reads `Game.player_count()` after joins). The QA override `--headcount=<n>`
exists; P4-18's bot seasons did not pass it, which only changes the store's plot ceiling at 2p to 4p
(no extra plots open below 5p). Should `--bots=N` set the headcount itself?

### Q-159 · 2026-10-09 · QA -> Gameplay Programmer · open
P4-18. `hold_completed.elapsed` is `Log.now() - started`, wall-clock time. Under `--fixed-fps 60`
(30x real time) a 3 s plant logs `elapsed 0.09`. Only headless speed runs are affected; the `t` field of
every log line is wall clock too. Use game time (sum of physics deltas) if speed runs should read true,
or leave it and QA ignores `elapsed` in those runs.

### Q-160 · 2026-10-09 · QA -> Gameplay Programmer · fixed (P4-18 merge: `Plot.recheck` returns `can_start`); late-cancel HUD reason still open
P4-18 code-fix review. `Plot.recheck` checks only the seed price, so two holds on the *same* plot still
both complete: `_validate` has no per-target lock, and each passes `can_start` at its start. Measured
in a throwaway host script (two `plant` holds on Plot01, bank 100): both completed, bank 92, the seed
bought twice for one crop. The same gap lets a second `harvest` complete on a plot the first just
reset (bag gets crop `""`) and a second `water` spend a can charge on a watered plot. Proposed fix, one
line in `game/farming/plot.gd`: `recheck` returns `can_start(verb, st)` (it already holds the price
check, plus `not_empty`, `not_ripe`, `already_watered`, `locked`). The other Interactables keep the
default `""`; their paid paths recheck inside `complete` already (`Debt.pay_early` via
`early_blocked`, `Store.take_scrap` returns false, `Store.buy` via `why_not`). Also: a late cancel ends
the client's hold with `hold_cancelled` and no reason, so the HUD never shows "Not enough coins for the
seed"; a `refused_reason` on cancel would explain it (UI, optional).

### Q-161 · 2026-10-09 · AI Programmer -> Game Designer · open
P4-21. The live trample count has an "Unattended farm" term the sim lacks. `sabotage_logic.gd
trample_count` adds `min(floor((nobody_outside_s - 30) / unattended_every_s), unattended_cap)`
(data/sabotage.json: 60 s, cap 3, both placeholders) on top of base 1, +1 under 30 s outdoors and +1 dead
generator. `tools/sim/sim.py` (step 5) uses only `trample_base`, `trample_nobody_outside` and
`trample_dead_generator` (data/season.json) with `nobody_outside_pct` 20 (median.json), about 1.3
plots a night. On the full farm the doc 03 s18 scripted stalk picks whoever is outdoors at 60 s every
night and its chase kills even inside the barn, so a team that wants no night death goes in before 60 s
and logs `nobody_outside_s` about 250: base 1 + dead generator 1 + unattended 3 = 5 plots every night
(measured in the P4-21 bot seasons, `trample` lines). One can of fuel cannot reach dawn either
(tank 210 s + can 105 s < dusk 60 + night 300, `generator_tank_s`, `fuel_can_pct`). Which should
move: add the unattended term to the sim, or lower `unattended_cap` so hiding costs about what the sim
assumes? Settled by: a sim run with the term added, compared against the P4-21 logs.
Update: the final P4-21 bots send one bot to the town stand sanctuary (farm.tscn `Sanctuary`, 10 m,
doc 03 s11.5) from dusk to dawn. It is outdoors all night, so `nobody_outside_s` is 0, the scripted
stalk picks it, and the chase ends without a kill. Trample drops to 2 plots a night (base 1 + dead
generator 1) with no night death. Also for the Game Designer: is a player parked at the town stand all
night meant to count as "attending" the farm? If not, `_track_night` should skip players in sanctuary
(AI Programmer change once you rule).

### Q-162 · 2026-10-09 · AI Programmer -> QA · open
P4-21. In a headless bot season the host (peer 1) is idle, but the debt scales by
`Game.player_count()` (debt.gd), so a "2p" bot season is one worker paying the 2p debt, "3p" two
workers paying 3p, and so on. The sim's players all work. `sim.py compare` therefore reads bot seasons
as a weaker team than their headcount. Options: compare bot seasons against the sim at headcount
`n - 1` with the `n` debt (sim change), or add a host bot (`--host-bot`, AI Programmer) so all `n`
work. Which does QA want for the median-team check?

### Q-163 · 2026-10-09 · AI Programmer -> Gameplay Programmer · open
P4-21. Two players can both lift the Prize Pumpkin. `prize_pumpkin.gd` checks `carrier != 0` only in
`can_start` (at hold start); `complete(&"lift_prize")` sets `carrier = peer` and `st.held_prize = true`
without checking again. In bot seasons three bots started `lift_prize` on one tick and all three got
`pumpkin_lifted` (s4p_1, short3p_1, short3p_2 before the fix). The two that are not the carrier keep a
stale `held_prize`, so `hold_registry.gd` refuses every verb but `set_down_prize`, `load_cart` and `pry`
(`hands_full`), and `load_cart` refuses `loaded`: those players are stuck until dawn (thousands of
refusals per season). Bots now claim the pumpkin so only one lifts, but two humans can still hit it.
Suggested fix: in `complete`, return without effect when `carrier != 0`, or re-run `can_start` there.

### Q-164 · 2026-10-09 · QA -> Director · item 2 answered D-089
P4-21 review (FAIL). Three items:
1. **Bug, AI Programmer:** `game/bots/bot.gd:286` `_keeps_payment` lets bots buy moonflowers (`grow_days` 0)
   from the first-payment money on day 3. At 2p no bot harvests at night (the sole bot is the sentinel),
   so they wilt. `s2p_1` went from 110 to 10 coins and `s2p_2` from 62 to 12 before the foreclosure at
   dawn 4. Fix it and re-run the 2p seasons.
2. **FOR CEO (via the Game Designer, with Q-161):** the sanctuary sentinel. One player parked at the town
   stand all night counts as "outside" (`game/ai_director/sabotage.gd:331`), so the "Unattended farm" term
   is 0 at no risk. That breaks doc 01 "Nights" ("Hiding is never fully safe or free"). A human team could
   use this rule hole too. Decide whether to close it (players in sanctuary do not count as outside) or
   accept it. Until then, QA reads bot-season economy numbers as an upper bound, not a median team.
3. **Director ruling:** do Harvest Moon deaths count toward "night deaths at the sim median or below"?
   The sim spreads its 2 deaths over nights 1 to 7, and night 7 is the Harvest Moon. Counting them, 3 of
   13 builder seasons and 1 of 2 QA seasons have 3 deaths.
**Answer to 2 (CEO, 2026-10-09):** close the hole. Players in the town stand sanctuary do not count as
outside. D-089, P4-31.
### Q-175 · 2026-10-09 · Gameplay Programmer -> Network & Voice, Director · answered D-092
P4-23 (menu lobby). Two RPCs added to `game/net/net.gd` (your file; edited to keep the lobby testable end
to end, please review or rewrite): `request_lobby_ready(on: bool)` (client -> host) and
`apply_lobby_ready(peers: Array)` (host -> all). Both forward to `Game.on_lobby_ready_request` /
`Game.apply_lobby_ready`, the same shape as `request_role` / `apply_roles`. Not named `request_ready`:
`Node` already has `request_ready()`. CONTRACTS s7 / D-010 want Director approval and a DECISIONS entry
for new message names: proposed D-092 "Lobby ready: `request_lobby_ready(on)` / `apply_lobby_ready(peers)`;
`Game.all_ready()` gates the host's Start the season; bots count as ready; `--lobby-start` bypasses it".
For Network & Voice: the lobby no longer loads the barn or player bodies. Its `Players` node is a stub
(`lobby.gd` class `Voices`) with an AudioListener3D and one bare Node3D per peer, so `Voice` still hangs
its emitters there and lobby voice plays unplaced (everyone at the listener). Say if voice needs more.
**Answer (Director, 2026-10-09):** names approved as proposed, D-092. P4-23 QA (Network & Voice view)
found both RPCs sender-checked and host-only; unplaced lobby voice is fine.

### Q-176 · 2026-10-09 · Gameplay Programmer -> Director, Game Designer · open · FOR CEO
P4-23 conflicts with doc 01 text. The CEO asked for a menu lobby where nobody spawns in the barn
(OPEN_ISSUES "Found in the CEO's 2-instance session" item 4), but doc 01 "Picking a role" says "each
player picks a role in the barn lobby", and doc 01 recording "Staging" says "the lobby is the dark barn
at night" (lantern blows out, door bang). Built as the CEO asked; doc 01 needs the CEO's wording change.
Side effect: the recording screen (`game/voice/recording_screen.gd`, Network & Voice) still opens over
the lobby, but no `barn_lantern` marker exists there, so the "lantern_out" step has no light to blow out
(null-safe, sound only). Options: audio-only staging, or a small dark barn backdrop behind the menu.
Soundscape still plays the barn room tone in the lobby (Audio's `_in_barn`), which fits either.
Players still spawn at the six barn spawn markers at match start (doc 04 s13): "players spawn on the
farm" read as those markers (inference; the CEO can name another spawn area).
### Q-180 · 2026-10-09 · Gameplay Programmer -> Director · FOR CEO · open
P4-24. The minimap shows other living players, as the task row asks. That weakens two doc 01 rules:
"Voice mimicry" says a fake voice "always comes from a place the teammate can't be", and the
"Whistle" is "placed by 3D audio only, with no HUD marker". With teammate dots on the map, a player
checks the map instead of listening, so a fake voice is exposed at a glance and the whistle is no
longer needed to find someone. Built as asked; the dots are one `if` in `_draw_dyn` of
`game/ui/minimap.gd` to remove. Keep the teammate dots, drop them, or show them by day only?

### Q-210 · 2026-10-09 · Game Designer -> Director · FOR CEO · open
P4-30. The CEO's 2p sell bonus conflicts with the doc 02 s18.3 targets (doc 01 "55-70% final"). The sim's
median 2p team already clears the first payment in 87% of seasons and the final in 63%; any 2p bonus
rounding to a coin pushes the 2p final above 70% (1%: 76.8; 5%: 90.8, first 91.3). Shipped 0 (D-106).
Options: (a) keep 0 and fix the 2p bot-season misses at their cause (one worker at 2p: Q-162 idle host,
Q-164 sentinel, now P4-31); (b) accept a 2p final above 70%, e.g. 5% (doc 01 change, CEO only);
(c) turn the unattended term on (Q-211) and set an economy-wide bonus of about 5/5/4/4/4, which passes
first and final at 2p to 4p and 6p but leaves 5p final at 72.1 and Large needed failing at every headcount.
Settled by: the CEO picking one; the Game Designer then sets the table and re-runs the gate.

### Q-211 · 2026-10-09 · Game Designer -> Director · open
P4-30, answers Q-161 in part. With the D-089 sanctuary fix a hiding team takes base 1 + dead generator 1 +
unattended 3 = 5 tramples a night. The sim now has that term (`unattended_term`, D-107). At the median hide
rate (20% of nights) final clear falls to 32.6/26.7/26.2/26.2/26.5 at 2p to 6p; hiding every night, 2p
first clear falls to 24.9 and final to 0. `unattended_cap` 1 still gives finals of about 44 to 50; hide rate
5% with cap 3 almost passes (finals 63.6/58.7/58.8/58.8/57.5, 5p first 77.3). No sell bonus fixes Large
needed under the term. Which moves: the sim's median hide rate, `unattended_cap` (AI Programmer data), or a
debt/payout retune? Settled by: a Director ruling, then a P4-21-style bot season after P4-31 to measure the
real hide rate.

### Q-212 · 2026-10-09 · Game Designer -> Gameplay Programmer · open
P4-30. Doc 05 s18 event rows need the new fields: `sell` gains `bonus` (coins already include it) and, from
the dawn moonflower cash-in, `dawn: true`; `end_of_season_sale` gains `bonus`. Doc 05 is yours (CONTRACTS
s2). Settled by: the doc 05 rows updated.
