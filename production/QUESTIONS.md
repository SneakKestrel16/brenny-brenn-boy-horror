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

### Q-002 · 2026-10-05 · QA → Gameplay Programmer (doc 05, PP-07) · open
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

### Q-006 · 2026-10-05 · Network & Voice → Gameplay Programmer · open
**`project.godot` and ghost entries doc 06 needs** (you own `project.godot` and `game/ghost/`):
1. `audio/driver/enable_input = true` (mic capture).
2. Autoloads `Net` (`game/net/net.gd`) and `Voice` (`game/voice/voice.gd`).
3. Input actions `voice_push_to_talk` and `voice_radio` (defaults to be agreed; suggestion: V and
   B).
4. Where a ghost's voice plays from: the ghost's spectating camera position, or something else? Doc
   06 section 8 attaches the ghost's `VoiceEmitter` to whatever node the Ghost system names.
Not blocking PP-02 (the spike sets its own project settings in `spikes/voice/`).

### Q-007 · 2026-10-05 · Network & Voice → Audio Designer · open
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
