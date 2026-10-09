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
  - Client log after each `scare <kind> 2`: jumpscare `audio_hush`, `cre_jumpscare_hit`, `sfx_ragdoll_thud` (the thud call is gone since the option 03 install below);
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
1. `taint 2`: the wet heartbeat on the second machine only (now -20 dB). `taint 2 off` stops it.
2. `scare jumpscare 2`: the silence, then the hit and a body thud (second machine).
3. `scare disarm_lunge 2`: corn parting twice, then the lunge.
4. `scare shed 2`: the target walks into the ToolShed first. The dev console forces past `not_in_shed`, but both
   sounds play 3D at the shed door, so from the barn (about 37 m away) they are faint.
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
4. Shed: no change. The CEO likely heard it from the barn: the dev console forces past `not_in_shed` (no refusal)
   and the sounds play 3D at the shed door, about 37 m away (QA review of 7e8c30a).
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

## CEO listen 2 (2026-10-08)
Under D-066, 11 sounds are now real Freesound CC0 recordings (sources, authors and processing in doc 08
section 13; originals in `assets/audio/src/dl/`): the three crow caws, the crow burst, the scream, the shed door
slam and bang, the jumpscare hit, the lunge, the presence swell (real breathing) and the paper slide (dry). Each
was RMS-matched to the file it replaced, so catalog levels hold; the three caws now share one RMS. Levels:
`TAINT_DB` -32 to -26 (doubled), paper slide -7.3 to -10.4 dB (30 percent quieter). The heartbeat file is unchanged.
Processing: `tools/audio/decode_downloads.py` and `tools/audio/process_downloads.py`.

## CEO listen 3 (2026-10-08)
Six sounds changed; the lunge and crow burst are unchanged (decode now resamples polyphase, so their files differ by
a hair; RMS the same). All sources CC0 with the whole chain checked (doc 08 section 13); originals in
`assets/audio/src/dl/`, eight unused originals removed. `process_downloads.py` rebuilds every WAV;
`decode_downloads.py` now reads `freesound_<id>.mp3` straight from `assets/audio/src/dl` (no rename step).
- `cre_jumpscare_hit`: box smash + wood smash + table crash + body thud, no cinematic impact; RMS -11.4 to -9.4 dB (+2). Catalog -8 dB kept.
- `sfx_door_slam`: wall thump, then a kicked heavy door with rattle and a sharp slam; -19.0 to -14.0 (+5). `cre_door_bang_01`: banging on a rattling door over a thump; -16.8 to -13.8 (+3). Catalog dB kept, so both play louder by that much.
- `cre_presence_swell`: pig breathing (CC0 chain), no slow-down, low-passed 1.1 kHz, clicks ducked; 5.87 s to 2.83 s, RMS -16.6. Replaces 350414 (CC-BY chain).
- `sfx_crow_caw_01..03`: clean American crow x2 and a rook, gated; same RMS -16.2.
- `vox_emote_scream`: whole scream to its own fall-off (kept by D-067); 1.95 s to 2.46 s.
- `ui_paper_slide`: real table slide, 1.04 s to 0.58 s, RMS -20.8 and catalog -10.4 kept.
Lead changes in `soundscape.gd` (TAINT_DB -20, crow burst +0.4 dB, wind pitch 0.5 and -3.1 dB) are in doc 08.
Not used: Smash.ogg 536777 (mixes a deleted account's sound whose license cannot be checked).
For the CEO to listen: the six above (`scare jumpscare 2`, `scare shed 2`, `scare hallucination 2`, `ghost caw 2`, `emote scream 2`, `phase dawn`).

## CEO listen 4 (2026-10-08)
Kept as liked: heartbeat, shed slam and bang, crow burst, scream, caws, wind, lunge (their WAVs differ only by the
edge fix below). Rejected: jumpscare ("breaking a door"), presence swell (pig, too short), paper slide ("off").
Per the Director, nothing is installed: three options each are in `builds/sound_options/` (doc 08 section 13.1 lists
sources, lengths, RMS; RMS matches the old targets -9.4, -16.6, -20.8). Built with SoX (trim, EQ, pitch, DC) and
SuperCollider NRT (layers, leaf-burst, thud and air sweeteners) by a scratch script; installing a pick means adding
its recipe to `process_downloads.py`, copying the original mp3s into `assets/audio/src/dl/` with LICENSE.txt lines,
removing the orphan originals (562189, 553886, 115917, 233111, 46631 once unused), rewriting doc 08 rows, and
re-importing. Fixed (QA LOW): `process_downloads.py` trims, removes DC, then fades; first and last sample of all 11 WAVs
are 0 (lengths and RMS unchanged). Listen to: the nine options. Flagged sources: craigsmith 675443 and 479677
(1930s-60s film effects, see doc 08 13.1).

### CEO listen 4 picks (installed)
Presence B (dog 461839) and paper C (kyles 451411) are installed: originals and LICENSE.txt lines in
`assets/audio/src/dl/`, recipes (`dog()`, `even()`, `paper()`) in `process_downloads.py` (pure numpy; the option's SoX
and SuperCollider steps and its synthetic air swells are dropped, so it reproduces both WAVs). `cre_presence_swell` is
5.69 s, RMS -16.6, peak -2.3 (was -1.0 in the option: ducking the loudest breath lowers the peak at equal RMS); its
two breaths peak within 2 dB and nearly all energy is under 200 Hz, so it is a heavy low breath and small speakers
will carry little of it. `ui_paper_slide` is 0.48 s, RMS -20.8, peak -1.0. Orphans removed: 233111, 46631. The
jumpscare is not picked: its sources and the current WAV stay.


### cre_jumpscare_hit options redone (2026-10-08, pending CEO pick, not installed)
Action-based (instant close onset, strike on player, fast vanish; no body thud, `sfx_ragdoll_thud` covers it). Options in `builds/sound_options/cre_jumpscare_hit_A/B/C.wav` (git-ignored), 1.5 s, RMS -9.4, peak -1.0. A: hawk cry 774252 + 0.55x copy, whip 72190, cloth punch 641234, leaves 489940 + scurry 415203. B: bear growl 763026 + tiger 263115 0.7x, dark whoosh 431976, belt snap 596477, corn 613567. C: cow huff 233137 (0.8x), towel whip 263454, cloth punch 641234, scurry 415203. All plus a synth leaf burst; all CC0 (641234 credit optional). Installed WAV unchanged.

### cre_jumpscare_hit options v3 (2026-10-08, pending CEO pick, not installed)
Replaces the A/B/C set. Ten options `builds/sound_options/cre_jumpscare_hit_01..10.wav` (git-ignored), 3.1-3.5 s, RMS -9.4, peak -1.0. Structure: 0.3 s silence head, scare (0.3-0.95 s, loudest), body thud (~0.85 s, so `sfx_ragdoll_thud` must not play separately for the jumpscare at install), rapid light steps fading out (lowpass closes with distance). Each has a different scare, thud and step set; all sources CC0 (page-checked, remix_group false, no human voice, no craigsmith). Build: tmp scripts `opt/jump10.py` (SoX stems + SuperCollider NRT), not in repo; on a pick the recipe must go into `tools/audio/process_downloads.py`.

### cre_jumpscare_hit: option 03 installed (2026-10-08)
`assets/audio/cre_jumpscare_hit.wav` is CEO option 03 (kea/bat scare, soft fall, grass running), 3.15 s, RMS -9.4, peak -1.0, 0.3 s head silence. Running steps are approved; **scare and thud are placeholders, redo with the creature model**. The thud is inside the file: the lead drops the separate `sfx_ragdoll_thud` call at the jumpscare.
- **Rebuilt, not copied.** The approved option was built with SoX + SuperCollider NRT, which is not deterministic (two runs gave different md5). To get a WAV a repo recipe reproduces byte for byte, `jumpscare()` in `tools/audio/process_downloads.py` re-makes it in numpy: same sources, cut points, grain picks, step timing and gains; the leaf burst is seeded numpy noise. The 0.1 s envelope matches option 03 (silence to 0.3 s, scare about -4 dB to 0.95 s, thud, 13 steps fading) but the tail ends 0.2 s earlier (3.15 s vs 3.36 s). **CEO listen again** since it is not the exact file approved.
- `process_downloads.py` keeps the head silence for this sound only.
- Added to `assets/audio/src/dl/` (+ LICENSE.txt, all CC0): 456802, 667579, 346694, 635052. Removed orphans 562189, 553886, 115917. 673424 stays (`cre_lunge`).
- Doc 08 updated (sections 5.4 table, 10.6, 11.4, 13, 13.1).
