# Handoff: CEO sound picks installed (D-149, listen of 2026-10-09)

Audio Designer. Nothing set in TASKS.md. Not committed (the Director commits).

## What was done

- Rebuilt all candidates into `logs/listen/` (git-ignored) with `tools/audio/real_creature.py` (creature) and
  `tools/audio/real_animals_items.py build` (items), then copied the picked option of each sound onto the existing
  `assets/audio/<sound_id>.wav` name. Picks are the two "CEO picks" tables of `real_creature.md` and `real_items.md`.
- Gaunt chase loop rebuilt from option C (`CHASE["gaunt"] = "C"` in `real_creature.py`). Corn part is the remade A
  (one brush per stalk). Cart squeak is the remade B (`squash` 2 dB, `TRIM` -6 dB).
- 78 files installed over existing names (27 creature, 51 item) plus 2 alternates in `assets/audio/alt/`
  (`sfx_animal_panic_02.wav` pig panic C, `sfx_animal_panic_03.wav` cow panic C), not loaded by game code.
- 38 Freesound previews added to `assets/audio/src/dl/` (only those the picks and alts use) with 38 new
  `LICENSE.txt` lines (55 lines in all, 55 mp3s). FilmCow files stay outside the repo.
- Doc 08 sections 13.2 and 13.3 rewritten: one row per installed id with source, author, licence, cut. They state
  the gaunt signature is a stand-in (CEO: "not the best", find a better real source later) and that the CEO wants
  all creature sounds redone later. `production/OPEN_ISSUES.md` is not mine: the Director may add that entry
  (it has none now).
- Tool edits: `CHASE["gaunt"]` changed B to C. The installer also pointed both scripts' `LISTEN` under
  `logs/listen/`; the Director reverted that, since the CEO listens from `Music\ceo_listen` (see N1).

## Name notes (no code changed)

- The creature handoff calls the husk jumpscare `cre_jumpscare_hit_corn_husk`; the asset is
  `cre_jumpscare_hit_husk.wav` and that is what was replaced.
- Item ids carry prefixes: the animals are `sfx_animal_chicken_01..03`, `sfx_animal_panic_01/02/03` (chicken, pig,
  cow), `sfx_animal_pig_01..02`, `sfx_animal_cow_01..02`; radio is `vox_radio_*`, `vox_crackle_loop`.
- Not installed (no existing file to replace): `cre_door_bang_02/03`, `cre_corn_part_03`. `Soundscape` has `n: 1` for
  the door bang and `n: 2` for the corn part, so only variants 01 (and 02) play. Follow-up for Gameplay/Audio:
  add the files and raise `n`.

## Differences from the old files (report, not errors)

- Loop lengths kept exactly: flare hiss 2.001 s, cart squeak 3.001 s, radio static and crackle 4.001 s.
- Creature sig, chase, jumpscare, gnaw, lunge, flare hit, corn part and presence swell are 0.0003 to 0.002 s
  shorter than the old files (for example sig 84000 samples vs 84032, chase 192000 vs 192064). The chase loops
  are seamless at their own length (end-to-start jump 0.0000), so this changes nothing audible; no code reads the length.
- Item one-shots changed length with the real recording (steps shorter, cow panic 2.66 s vs 1.0 s, whistle 0.87 s vs
  1.3 s, flare shot 0.73 s vs 1.2 s). Soundscape caps and `unit`/`max` values are untouched; QA should
  listen for any timing that assumed the old length (flare shot, cow panic).

## Checks

Every installed file was re-read after the copy and compared with the candidate it came from (length in samples,
peak, RMS): 80 of 80 match. Installed files (length s, peak dBFS, RMS dBFS):

```
cre_gaunt_sig_01 1.75 -7.8 -36.1 | _02 1.75 -7.0 -35.7 | _03 1.75 -3.6 -33.3 | _chase 4.00 -4.0 -28.0
cre_scarecrow_sig_01 1.75 -4.8 -25.2 | _02 -4.6 -25.4 | _03 -3.0 -25.8 | _chase 4.00 -3.5 -21.7
cre_boar_sig_01 1.75 -2.8 -20.6 | _02 -4.0 -21.5 | _03 -5.2 -21.3 | _chase 4.00 -2.6 -18.3
cre_husk_sig_01 1.75 -1.6 -20.3 | _02 -1.1 -20.9 | _03 -1.0 -19.3 | _chase 4.00 -1.0 -19.3
cre_jumpscare_hit_gaunt 3.20 -1.0 -9.4 | _scarecrow 3.00 | _boar 3.62 | _husk 3.37 (all -1.0 -9.4)
cre_gnaw 2.50 -1.0 -15.9 | cre_lunge 0.89 -1.6 -13.9 | cre_flare_hit 1.20 -4.7 -16.8
cre_door_bang_01 1.60 -1.1 -13.8 | cre_corn_part_01 1.00 -12.4 -21.4 | _02 1.00 -12.2 -21.5
cre_presence_swell 5.69 -2.3 -16.6
sfx_animal_chicken_01 0.894 -1.7 -16.3 | _02 0.978 -7.5 -18.0 | _03 0.758 -7.0 -16.2
sfx_animal_panic_01 1.072 -2.5 -15.6 | _02 1.189 -1.7 -13.6 | _03 2.656 -3.4 -14.4
alt/sfx_animal_panic_02 1.032 -1.8 -13.6 | alt/sfx_animal_panic_03 2.66 -1.2 -14.4
sfx_animal_pig_01 0.714 -5.3 -18.8 | _02 0.657 -1.3 -17.4
sfx_animal_cow_01 2.038 -6.0 -15.3 | _02 1.661 -4.5 -14.8
sfx_flare_shot 0.733 -1.0 -17.3 | sfx_flare_hiss_loop 2.001 -1.0 -14.3 | sfx_cart_squeak_loop 3.001 -9.1 -16.8
sfx_beartrap_snap 0.851 -3.3 -18.5 | sfx_pit_fall 0.982 -1.5 -14.6 | sfx_lantern_blow_out 0.671 -2.8 -21.6
sfx_whistle 0.87 -1.9 -8.8 | sfx_emote_cloth 0.50 -4.0 -24.5
sfx_step_dirt_01..06 0.282 0.289 0.281 0.303 0.264 0.304 | peaks -1.7 -1.0 -1.0 -7.0 -1.1 -1.1 | rms -19.9 -18.4 -19.8 -18.9 -18.2 -18.8
sfx_step_corn_01..06 0.330 0.434 0.456 0.314 0.334 0.409 | peaks -1.6 -1.7 -2.6 -1.2 -2.1 -1.1 | rms -20.4 -19.5 -19.9 -19.4 -20.2 -19.9
sfx_step_wood_01..06 0.326 0.333 0.328 0.329 0.345 0.350 | peaks -5.5 -5.4 -3.9 -2.0 -4.5 -7.9 | rms -22.9 -23.9 -22.2 -23.0 -23.4 -24.2
sfx_ragdoll_thud_01 0.628 -1.3 -14.8 | _02 0.548 -1.1 -14.4
vox_radio_static_loop 4.001 -7.3 -20.7 | vox_crackle_loop 4.001 -1.4 -31.3
vox_radio_squelch_on 0.341 -11.2 -19.2 | _off 0.199 -7.2 -22.0 | vox_radio_low_battery 0.391 -2.3 -9.8 | vox_radio_dead 0.36 -1.1 -20.4
ui_click 0.031 -3.1 -22.2 | ui_confirm 0.437 -1.1 -11.1 | ui_deny 0.227 -1.0 -7.6 | ui_coins 0.375 -1.5 -25.2
ui_stamp 0.37 -1.3 -15.6 | ui_award_reveal 0.975 -3.1 -20.1 | ui_shop_bell 0.863 -9.8 -26.3
```

- Headless import (`--editor --quit --audio-driver Dummy`): 0 ERROR lines. It created `.import` files for the two alt wavs.
- `uv run tools/qa/smoke.py --scene res://game/world/farm.tscn -- --port=47210`: SMOKE PASS (import, parse_check, run, 0 errors).
- `uv run --no-project python tools/qa/grep_rules.py`: all rules ok; the 2 known `lobby.tscn` light_energy warnings only.
- Loops kept their `.import` loop flags (the `.import` files were not changed by the copy).

## For the CEO to listen to

All 78 installed files are new by ear; most are what the CEO already picked. Worth a second listen in game: the
gaunt signature and chase (stand-in), cart squeak (new peak), flare shot and cow panic (shorter/longer than before).

## Open issues

- Gaunt signature is a stand-in; all creature sounds to be redone (CEO). Needs a better real source later.
- `cre_door_bang_02/03`, `cre_corn_part_03` built but not loaded (see above).
- Source licence flags unchanged: 831713 is foley, 610143 may be processed, 146339 not used.

## QA review

**PASS** (2026-10-09, commit 3122160). One pre-existing loop bug found and filed (Q-249); it is not caused by this
install and does not block it.

1. **Picks.** QA rebuilt every candidate from the committed `tools/audio/real_creature.py` and
   `real_animals_items.py` in a scratch tree (temp copies with `LISTEN` pointed into the scratch tree, the
   pre-commit `assets/audio/*.wav` as the RMS reference, so the build matches what the installer saw). All 80 files
   (27 creature, 51 item, 2 `alt/`) are sample-identical to the CEO's picked option in the "CEO picks" tables of
   `real_creature.md` and `real_items.md` (gaunt C, scarecrow A, boar A, husk B; jumpscares C/C/B/C; gnaw B, lunge A,
   flare hit A, door B, corn A remade, presence A; items as listed, cart B remade). `alt/sfx_animal_panic_02/03` are
   pig panic C and cow panic C. Nothing in `game/`, `tests/` or `tools/` references `assets/audio/alt/`; the two
   `.import` files only import them (default params). They still ship in an export (about 0.35 MB).
2. **Loops.** All eight loops are seamless at full length (end-to-start jump 0.0000 to 0.023, below each file's
   99th-percentile sample step). `.import` files unchanged; loop flags are set in code (`Soundscape._stream`,
   `voice_chain.gd`, `walkie.gd`), as before. But see Q-249: those code paths set `loop_end` from
   `data.size() / 2`, and the wavs import as QOA (`compress/mode=2`, format 3), so every code-set loop wraps
   early. Measured: `cre_gaunt_sig_chase` playback position never passes 0.797 s of 4.0 s (headless, Dummy driver).
   Same with the old files: pre-existing.
3. **Lengths.** No game code reads a stream length or times anything to the flare shot, whistle, cow panic or
   creature one-shots. Panics are gated by `PANIC_GAP_S` 12 s (cow panic 2.66 s fits); jumpscare knockdown is a
   fixed 2.0 s (`scares.gd`), audio lengths unchanged. Doc drift only: doc 08 s9.3 still describes `sfx_whistle` as
   "~1.1 s ... rising chirp"; it is now a 0.87 s real metal whistle, peak 2.93 kHz, 99 percent of energy in
   2.4-3.6 kHz (Audio Designer to update). QA updated its own doc 09 s5 ("about 0.9 s").
4. **Licences.** 55 mp3s, 55 `LICENSE.txt` lines, all CC0. The 38 new mp3s are byte-identical to the downloads in
   `C:/Users/Ockey/fc_dl/`. Each new id's Freesound page shows `publicdomain/zero/1.0` (26 from the saved pages,
   12 creature ids fetched live today). Every Freesound id cited in doc 08 s13.2/13.3 has a licence line (452609,
   461839, 613567, 635052 are older lines). Doc 08 rows cite source id, author and cut; s13.2 has a licence column,
   s13.3 states CC0 for all in its header. FilmCow audio is not in the repo.
5. **Names.** Every `Soundscape.CATALOG` id with its `n` variants (88 files) and every literal
   `res://assets/audio/` path in `game/` exists; chase sigs for all four bodies exist. Nothing code loads is
   missing; `cre_door_bang_02/03` and `cre_corn_part_03` are only unbuilt extras (`n` 1 and 2).
6. **Smoke.** Headless import 0 ERROR lines. `smoke.py --scene res://game/world/farm.tscn -- --port=48610`:
   SMOKE PASS (`logs/qa/smoke_20261009_200223`). `grep_rules.py`: all ok, only the 2 known `lobby.tscn` warnings.
   Multi-instance run skipped (no networked change).

Notes (no action needed to pass):
- N1. The handoff says both scripts' `LISTEN` now point under `logs/listen/`. Not so in the commit: both still
  write to `C:\Users\Ockey\Music\ceo_listen\...` (`real_creature.py:13`, `real_animals_items.py:20`); only
  `CHASE` changed. A rerun writes into the CEO's folder. Audio Designer: fix the scripts or the handoff.
- N2. `logs/listen/` has no `.gdignore`, so each editor import also imports the ~470 candidate wavs (local only,
  git-ignored).
- N3. `sfx_lantern_blow_out` is a person's breath (Reitanna 242867, CC0), no voice; CEO-picked. Fine under the
  no-real-voices rule as read by QA.
