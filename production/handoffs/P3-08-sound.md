# P3-08 (sound half): Taint and scare sound
Owner: Audio Designer  Date: 2026-10-08

## Done
- Wet Taint heartbeat: `sfx_taint_heartbeat` re-rendered wetter (a resonant low-pass squelch on each
  thump). `Soundscape` polls `Game.players[local].tainted` and loops it at -42 dB on `SFX`,
  non-positional, only on the Tainted player's machine, never for a ghost (Q-060). It ducks 8 dB under
  the chase heartbeat (doc 08 s8).
- Scare sounds for the P3-05 wiring in `scares.gd` (unchanged): `cre_jumpscare_hit`, `sfx_ragdoll_thud_01..02`,
  `cre_corn_part_01..02`, `cre_lunge`, `sfx_door_slam`, `cre_presence_swell`, `sfx_crow_burst`. Build-up
  stays the `hush` silence (doc 03 s13.1); doc 08 s4.4 rule 1 now allows it (Q-059).
- Catalog gaps: `sfx_crow_caw_01..03` (P3-09 ghost crow), `vox_emote_scream` (Q-064),
  `sfx_emote_cloth` (P3-11 wave, point, shrug), `ui_paper_slide` (P3-12 Dawn Report card).
- `Soundscape` logs `audio_play {id}` per one-shot (footsteps excepted), `audio_hush {seconds}`,
  `audio_taint_heartbeat {on}`. The paper slide triggers from the `dawn_report_shown` log line, so the
  host hears it too (the host does not receive `apply_dawn_report`).
- All synthetic (SuperCollider), no recorded or downloaded audio, no day music.
- Doc 08: s4.4 rule 1, s8 Taint row, new s10.6 "Phase 3 as built (P3-08)" with lengths and RMS, s14 item 10.

## Files changed
`assets/audio/src/` + `assets/audio/` (WAV and `.wav.import`): `sfx_taint_heartbeat` (changed),
`cre_jumpscare_hit`, `cre_lunge`, `cre_presence_swell`, `cre_corn_part_01`, `cre_corn_part_02`,
`sfx_ragdoll_thud_01`, `sfx_ragdoll_thud_02`, `sfx_door_slam`, `sfx_crow_caw_01..03`, `sfx_crow_burst`,
`vox_emote_scream`, `sfx_emote_cloth`, `ui_paper_slide` (new). `game/audio/soundscape.gd`,
`docs/08_audio_design_and_sound_list.md`, `production/QUESTIONS.md` (answers Q-059, Q-060, Q-064; new Q-072, Q-073).

## What the next role needs to know
- **Gameplay:** no `player.gd` call is needed for the heartbeat; the HUD "Tainted" tester line is yours.
- **Technical Artist:** nothing in `game/render/` touched.
- **QA:** dev console triggers are in the CEO listen list below. Expect `audio_*` lines on the peer
  that hears the sound, not the host (scares are private to the target).

## Verified
- `render.py`: every file 48 kHz, 16-bit, peak -1 dBFS, no clipping, tail below -90 dBFS in the last
  30 ms; heartbeat loop seam clean. Spectrograms read for jumpscare, heartbeat, scream.
- Headless import exit 0, no ERROR. `parse_check.tscn`, `test_creature_logic`, `test_director_logic`,
  `test_data`, `test_dawn_report_logic`, `test_voice`, `test_hold_math`: exit 0, no ERROR.
  `grep_rules.py`: 0 violations (voice_files clean).
- Two instances, port 24741 (`multi.py -n 2 --headless`, `--dev-exec` on the host), MULTI PASS, 0 SCRIPT ERROR:
  - `taint 2`: `audio_taint_heartbeat on` in the client log only; `taint 2 off` turned it off there.
    `taint 1`: on in the host log only; dawn cleared it.
  - Client log after each `scare <kind> 2`: jumpscare `audio_hush`, `cre_jumpscare_hit`, `sfx_ragdoll_thud`;
    disarm_lunge `audio_hush`, `cre_corn_part` x2, `cre_lunge`; shed `audio_hush`, `cre_door_bang`,
    `sfx_door_slam`; hallucination and wrong_count `audio_hush`, `cre_presence_swell`. None in the host log.
  - `emote wave 2`: `sfx_emote_cloth` on both peers. `emote scream 2`: `vox_emote_scream` on both.
  - `kill 2; ghost caw 2`: `sfx_crow_caw` on both. `phase dawn`: `ui_paper_slide` on both.
  - `check_logs.py` on the run: exit 0.

## Open issues
- `scare fake_out` not seen live: both spawn points count as indoors and `--autowalk` stayed inside, so
  the dev command refused ("no living player outdoors"). Its wiring (`sfx_crow_burst` in `scares.gd`) is
  unchanged from P3-05.
- Dawn Report low-pass (doc 08 s2.3 rule 5) not built: it would muffle the replays (Q-072).
- New log events need listing in CONTRACTS s10 and doc 05 (Q-073).
- "The trap" scare is not built, so it has no sound. Taint pitch does not follow intensity (Taint is on/off).
- Skipped: `ui_paper_rustle`, `sfx_crow_flap`, `cre_corn_part_03`, `sfx_ragdoll_thud_03`.
- Every level is a placeholder, unheard by the author.

## CEO listen list (corrected 2026-10-08)
Start a host with `--dev`, a second instance joined; open the console with the backquote key on the host. The
target `2` is the nth player (the second machine), not a peer id.
1. `taint 2`: the wet heartbeat on the second machine only (now -32 dB). `taint 2 off` stops it.
2. `scare jumpscare 2`: the silence, then the hit and a body thud (second machine).
3. `scare disarm_lunge 2`: corn parting twice, then the lunge.
4. `scare shed 2`: the target must first walk into the ToolShed, or the command refuses by design.
5. `scare hallucination 2` and `scare wrong_count 2`: the presence swell.
6. `scare fake_out`: needs a player outdoors in the field; the crow burst.
7. `kill 2`, `ghost crow 2`, then `ghost caw 2`: the crow caws (three variants, random). Without the first two
   the command refuses (no crow taken), by design.
8. `emote scream 2`: is the synthetic scream scary or silly? `emote wave 2`: the cloth rustle.
9. `phase dawn`: the paper slide as the Dawn Report shows.

## CEO listen 1 (2026-10-08)
All new files rendered with `render.py` (48 kHz, 16-bit, peak -1 dBFS, tails below -60 dBFS in the last 30 ms).
Files are peak-normalized, so loudness changes were re-matched in `Soundscape` by RMS against the old file
(inference: RMS is a proxy for what the CEO heard; the CEO says if any feels louder or quieter).
1. Taint heartbeat barely audible: `TAINT_DB` -42 to -32 (+10 dB; +8 to +10 asked, chose the top because the beat
   is mostly under 150 Hz and laptop speakers drop it). The file also gets a 900 Hz low-pass (was 600) and a
   stronger knock, so there is body above 100 Hz. Still ducks 8 dB under the chase heartbeat.
2. Jumpscare (`cre_jumpscare_hit`, `sfx_ragdoll_thud`): hit redone as a slam (crack, saturated sub drop, broken
   FM shriek, 55 Hz growl, tail); thuds heavier, no bright metal ticks. Hit level -2 to -8 dB (new RMS -11.4,
   was -17.6); thuds unchanged (RMS within 0.8 dB).
3. Disarm lunge: `cre_corn_part_01/02` now dense leaf crackle plus green-wood snaps, -6 to -12 dB (RMS -10.2,
   was -16.3); `cre_lunge` now a rush with growl and a saturated impact and a gasp, -2 to -4 dB (RMS -13.9, was -15.9).
4. Shed: no change; nothing found wrong. The refusal outside the ToolShed is by design.
5. Presence swell: no tone; two slow breaths of dark noise, drifting sub pressure, murmuring mouth layer.
   -10 to -8 dB (RMS -16.6, was -14.5).
6. Crows: caws (`sfx_crow_caw_01..03`) and the burst rebuilt from jittered glottal pulses with shimmer, roughness,
   throat noise, moving formants and soft saturation; the burst has uneven feathery flaps, a leaf rustle and two
   caws. Burst level -4 to -2.5 dB (RMS -18.0, was -17.3; includes the +0.83 dB, so +1.5 dB net). Caws -6 to -5 dB.
7. Ghost caw: no change; refused because no crow was taken, by design (see list item 7).
8. Scream: jittered pulses, shimmer, uneven rise with a pitch break, moving vowel formants, breath noise, late
   roughness. -4 to -1 dB (RMS -16.4, was -13.3). Still synthetic.
9. `ui_paper_slide`: paper over wood: broadband friction that follows the sheet's speed, one-pole slope, no
   resonant filter (spectrogram shows no tonal lines), faint fibre ticks. -6 to -7.3 dB (-2.5 dB asked, plus 1.2 dB
   because the new file is 1.2 dB quieter by RMS).
Files: the 14 `.scd` sources and WAVs above in `assets/audio/`, `game/audio/soundscape.gd` (catalog `db`,
`TAINT_DB`), doc 08 (s8 Taint row, s10.6 table, s11 rows). No music touched. Headless import: 0 ERROR.
`grep_rules.py`: 0 violations. Not run live (no ears); the CEO listens.

## QA review
Opus `qa-reviewer`, 2026-10-08: PASS, nothing must-fix. A 3-instance run confirmed the Taint heartbeat and the
private scare sounds play only on the target's machine, the heartbeat stops on death and at dawn, the emote cloth
plays for all, and the paper slide plays once per peer. All 16 WAVs are 48 kHz, peak -1 dBFS; no recordings, no
music. Left: `scare fake_out` has not been heard live (needs a player outdoors); doc 08 section 8 says the Taint beat
ducks under the still heartbeat but the code ducks it under the chase heartbeat (inference, designer to confirm);
Q-072 and Q-073 stay open; every level waits on the CEO listen above.
