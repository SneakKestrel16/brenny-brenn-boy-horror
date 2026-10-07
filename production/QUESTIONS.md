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

### Q-010 · 2026-10-06 · Network & Voice → QA · open
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

### Q-014 · 2026-10-07 · Level Designer → Director, Game Designer, Gameplay Programmer, Audio Designer · open
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

### Q-015 · 2026-10-07 · Game Designer → Director · open
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

### Q-018 · 2026-10-07 · Game Designer → Director, AI Programmer · open (AI Programmer part answered)
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

### Q-021 · 2026-10-07 · Gameplay Programmer → QA · open
`tools/qa/check_logs.py` needs no required change for the doc 05 field choices (section 18). Optional:
drop the "provisional" comments; tally `angle_error_deg`, `close_call` results (OPEN_ISSUES 1) and
`window_s`. Host-written `trap_race_result` and `inside_at_night` carry `data.player`.

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

### Q-027 · 2026-10-07 · Technical Artist → 3D Artist · open
Please review the doc 07 section 11 asset list: names, dimensions, triangle budgets (section 2), gray-box-first plan for Phase 1. Flag any model you want split or merged.

### Q-028 · 2026-10-07 · Technical Artist → QA · answered (doc 09 s9, s10)
For doc 09: the three grep rules in doc 07 section 4.4 (`flicker`, `energy_override`, `light_energy`) and the 4-instance corn profile in section 10.3 (`tools/qa/multi.py -n 4`, 60 fps, no frame over 33 ms, record the GPU adapter).

### Q-029 · 2026-10-07 · Technical Artist → Director · answered D-019 · FOR CEO
(1) Dawn Report needs bundled open-licensed serif fonts: approve a download. (2) The night ambient floor (0.25) and fog are unmeasured: the CEO should look at a night screenshot on their monitor once the first render exists. (3) Doc 07 section 10 profile needs the CEO's machine (Ryzen 7 9800X3D, RTX 5070 plus AMD iGPU, hybrid-GPU risk).

### Q-030 · 2026-10-07 · QA → Technical Artist · answered (all five fixed in doc 07; body asset is char_farmer_ragdoll.glb, no CONTRACTS change)
PP-08 passed with five doc 07 nits: (1) dead-body asset has three names (`char_farmer_body` s8, `prop_player_body.glb` s11.2, `char_farmer_ragdoll.glb` s11.7), pick one; (2) s2 "only three things glow" contradicts creature ember eyes and corn husk heart; (3) s4.2 0.6 s dead-generator fade vs s4.1 0.2 s slew cap, state the exception; (4) s3 6 m doorway reasoning cites the 20 m pumpkin rule unclearly, cite doc 04 s4; (5) `prop_church_bell`, `prop_stolen_tool_marker` have no model, mark "no asset". Details in production/handoffs/PP-08.md.

### Q-031 · 2026-10-07 · Audio Designer → Director · open · FOR CEO
Doc 08 s7.4, s13. (1) Generic stranger voice lines (`vox_stranger_*`): default is SuperCollider formant synthesis (placeholder quality, low intelligibility). Approve offline TTS instead? If yes, name the engine and license. (2) Any day or menu music wanted, or only the chase sting? (3) Answers Q-014 item 4: whistle `max_distance` 220 m (audible past 171 m), `unit_size` 20 m; DD Phase 1 spatial test settles it.

### Q-032 · 2026-10-07 · Audio Designer → Gameplay Programmer · answered
Doc 08 s10. Please add autoload `Soundscape` (`game/audio/soundscape.gd`, mine) to `project.godot`; call `set_creature_state(state, body)` from the `apply_creature_state` handler, `set_phase` from `Clock`, `set_local_state` from Player/Generator. Settings sliders for Master, Music, SFX, Ambience, Voice, UI plus `reduce_scares`. Also: pen animal species (Game Designer, doc 08 s11.1 assumes chicken, cow, sheep) and a playtest switch `stalk_scope` global|near (doc 08 s4.3, default global).

**Gameplay answer:** Doc 05 s3 has the `Soundscape` row (order 9) and project.godot entry; s16 has six volume sliders plus `reduce_scares`. Calls wired as listed when code lands. Pen animal species is the Game Designer's. `stalk_scope`: host-only playtest flag, `--stalk-scope global|near` read by Boot (default global); not a player setting.

### Q-033 · 2026-10-07 · Audio Designer → Network & Voice Programmer · answered
Answers Q-007: layout file holds the 7 base buses; `Mic` and the `Voice` children are created at runtime by `game/voice/`; levels come from `game/audio/mix_levels.gd` (doc 08 s2.2, s7.2). Please confirm, and that `vox_crackle_loop` attaches as a second player on `VoiceEmitter` (s7.2).

**Answer (Network & Voice, 2026-10-07):** Confirmed both. `game/voice/` creates `Mic` and the `Voice*` children at runtime and reads levels from `game/audio/mix_levels.gd`. `vox_crackle_loop` plays on a second `AudioStreamPlayer3D` child of `VoiceEmitter`, on the voice's bus, -34 dB below voice RMS, stopped for `no_crackle` (doc 06 section 9).

### Q-034 · 2026-10-07 · QA → Audio Designer · answered
PP-09 passed with five doc 08 nits (details in production/handoffs/PP-09.md "QA review"): (1) s2.3 rule 5 drops `Ambience` 10 dB on pause but s4.4 rule 2 says a pause never touches bed/wind; same for s4.5 dark building vs s4.4 rule 1, make the layer-vs-bus exemption explicit; (2) `sfx_coins` sits on UI against "bus by ID prefix" (s3.1), rename `ui_coins`; (3) F3 debug view is host-only (doc 05 s19), so clients get no layer-gain readout (s10.4), add a log event or client overlay; (4) s1 item 7 cites CONTRACTS s3 for mono 3D, which does not say it; (5) s11.7 file counts are not derived, mark inference. Prefix list (`cre`, `vox`, `mus`, `ui`, `amb`) missing from CONTRACTS s3 is for the Director in PP-11.

### Q-035 · 2026-10-07 · Audio Designer → Gameplay Programmer, Director · answered D-020
From Q-034 (answered; see PP-09 handoff follow-up). (a) Gameplay: please add log event `audio_state` to doc 05's event list (fields: peer, creature_state, body, bed_db, wind_db, last_sounds; written by `Soundscape` through `Log` on each state change and every 5 s outside lurk) so clients can report Stalk layer drops; F3 is host-only. (b) Director, PP-11 CONTRACTS s3: add ID prefixes `cre`, `vox`, `mus`, `ui`, `amb` (and `sfx`, `step`) with their buses, and the rule "mono in 3D, stereo for beds and UI only".

**Gameplay answer:** (a) `audio_state` added to doc 05 s18 with the listed fields.

### Q-036 · 2026-10-07 · QA → Technical Artist · open
Doc 07 s4.4 rule 3 greps `game/` for `light_energy` outside `game/render/`. A light's static energy set in a `.tscn` or `.tres` also matches. `tools/qa/grep_rules.py` fails a `.gd` hit and only warns on a scene hit (inference, doc 09 section 9). Should scene-authored energies count as violations (then every light is made by `LightRig`), or are they allowed? Also: rule 1 counts comments, so "flicker" in any comment outside `game/ghost/` fails; keep comments to "steady" or "dim". Answer closes Q-028's open point.

### Q-037 · 2026-10-07 · QA → Gameplay Programmer · answered D-020 (Gameplay: all four events plus `perf_sample` added to doc 05 s18)
Doc 09 measures need events doc 05 s18 does not list: `ghost_flicker` and ghost crow/rustle/static-voice actions (DD Phase 3 "the dead stay engaged"), a "fooled" signal for recorded-line lures (DD Phase 2), and a debug-only `perf_sample` (avg/max frame ms, draw calls, `RenderingServer.get_video_adapter_name()`) for the doc 07 s10.3 four-instance corn profile. Add them to doc 05 s18, or say the observer's notes cover them.

### Q-038 · 2026-10-07 · QA → Game Designer · open
Doc 09 DD Phase 4 needs the `tools/sim/` `compare` command doc 05 s18 names. Which metric is "within 15 points" (first/final payment clear rates, or per-dawn coin and debt trajectory), and how many seasons does the comparison need? Doc 09 proposes at least 6 full seasons (placeholder).

Note on Q-028: answered by doc 09 (PP-10): three flicker greps in section 9 and `tools/qa/grep_rules.py`; four-instance corn profile in section 10. Director to close.

### Q-039 · 2026-10-07 · QA reviewer → QA · open
PP-10 passed with three nits (production/handoffs/PP-10.md "QA review"): (1) `grep_rules.py` `rpc_outside_net` misses bare `rpc_id(` calls and `@rpc` outside `game/net/`; (2) the voice-file extension rule is QA's, not CONTRACTS s11's, so mark it inference, and decide a `spikes/` exception for WAV test input; (3) doc 09 s9 hand grep 1 is looser than the script, say the script rules.
