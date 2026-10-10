# real_creature handoff: creature sounds from real recordings, three options each (D-149)

Audio Designer. Source: CEO direction D-149 ("make them sound as close as they can to what the monster is based
on, pull from public libraries and give me 3 options for each one"). No TASKS.md row exists for this; nothing
is installed. The CEO picks by ear, then a follow-up copies the picks to `assets/audio/` and commits the picked
Freesound mp3s to `assets/audio/src/dl/` with their `LICENSE.txt` lines.

## What was done

- `tools/audio/real_creature.py` (new) builds every candidate from FilmCow Recorded SFX (D-149) and Freesound
  CC0 HQ previews (D-066). It reuses the D-066 helpers of `process_downloads.py` (exec of the part before its
  build table; that file is unchanged) and adds an event finder, a seamless loop folder and a periodic shaker.
  Seeded: a rerun gives the same files.
  `uv run --no-project --with numpy --with soundfile python -I tools/audio/real_creature.py [name_prefix ...]`
  It reads decoded 48 kHz mono wavs outside the repo: Freesound in `C:/Users/Ockey/fc_dl/fs_creature_wav/`,
  the earlier D-066 mp3s in `C:/Users/Ockey/fc_dl/repo_dl_wav/` (both from `decode_downloads.py`), FilmCow
  in `C:/Users/Ockey/fc_dl/recorded/FilmCow Recorded SFX/`.
- 82 candidates in `logs/listen/real_creature/` (git-ignored), named `<sound_id>_<A|B|C>[_0n].wav`:
  sig sets `cre_<body>_sig_<opt>_01..03`, chase loops `cre_<body>_sig_chase_<opt>`, `cre_jumpscare_hit_<body>_<opt>`,
  `cre_door_bang_<opt>_01..03`, `cre_corn_part_<opt>_01..03`, `cre_gnaw_<opt>`, `cre_lunge_<opt>`,
  `cre_flare_hit_<opt>`, `cre_presence_swell_<opt>`.
- All 48 kHz, 16-bit, mono, peak at most -1 dBFS, first and last sample 0, RMS matched per file to the file it
  would replace (gaunt sig -36.1/-35.7/-33.3, chase -28.0; scarecrow -25.2/-25.4/-25.8, chase -21.7; boar
  -20.6/-21.5/-21.3, chase -18.3; husk -20.3/-20.9/-19.3, chase -19.3; jumpscare -9.4; door -13.8; corn part
  -10.2; gnaw -15.9; lunge -13.9; flare -16.8; presence -16.6). Lengths match the current files (sig 1.75 s,
  chase 4.000 s, jumpscare gaunt 3.20 / scarecrow 3.00 / boar 3.62 / husk 3.37 s, door 1.6, corn part 1.0,
  gnaw 2.5, lunge 0.89, flare 1.2, presence 5.69 s).
- Chase loops: events placed on a 4.0 s circle (what runs past the end wraps onto the start), rotated to start
  at the quietest 10 ms, 1 ms edge fades; measured end-to-start jump 0.0000. Built only for the option ranked
  first per body (gaunt B, scarecrow A, boar A, husk B); `CHASE` in the script switches it.
- Doc 08 section 13.2 lists the sources as "candidates, not yet picked".

## Doc 08 s6 rules, as built and measured

- Gaunt: no low thump (high-pass 150 Hz on the mix, 250 Hz per grain for A and C; 60-90 Hz band -29 to -77 dB re
  total). Irregular: lurk gaps 0.3-0.65 s with 30 percent double clicks (about 2.4/s); chase gaps 0.06-0.14 s
  (about 10/s).
- Scarecrow: single snaps (each flap cut to its first 0.35 s), 2-3 per variant, gaps 0.45-0.9 s; chase 10 per
  4 s (2.5/s) with plus or minus 20 ms jitter, like the current loop. Sources played at 0.75-0.85x to lower the
  coat body; high-pass 80 Hz removes the flag-handling rumble (20-60 Hz was -8 dB re total before).
- Boar: chain scrape/clatter, no bells; hoof thud per drag/stride; 2 drags per 1.75 s variant (1.2/s);
  chase 10 strides per 4 s with grunts on 3 of them. 60-90 Hz band: A -9 to -14, B -7, C -8 dB re total
  (current file -7). A's hoof layers a 250 Hz low-passed slice of a FilmCow bass body fall under the dirt
  landing for that band.
- Husk: no source pulses at 14-22 Hz by itself (measured envelope peaks: gourd 8.1 Hz, seed pods 7.2,
  beads 7.7, shekere 7.0, rattlesnake 53 Hz buzz with weak periodicity). So each husk texture is levelled
  (`flat()`, divide by its 40 ms RMS envelope) and shaken by `pulsed()` (2 ms attack, 22 ms decay per period):
  A at 18.7 Hz, 70 percent deep (the 0.35x rattlesnake buzzes near 18.7 Hz itself), B at 17 Hz, C at 19 Hz.
  Measured envelope peak of the >2 kHz band: A 18.9 Hz, B 17.1-17.7 Hz, C 18.9 Hz, chase B 17.0 Hz; share of
  14-22 Hz in 3-80 Hz 0.33-0.62. Corn stand-in: 3.4 Hz, share 0.12.

## Options

Freesound ids are `https://freesound.org/s/<id>/`; every page and remix chain was checked CC0
(publicdomain/zero/1.0, no remix group). Rank is mine from source fit and the measurements; I can't hear them.

| Sound | Opt | Sources | Processing | Description | Rank |
|---|---|---|---|---|---|
| gaunt sig | A | 500797 Finger bones crack (khenshom); 390962 Cracking joints (lucantunes) | loudest 6 + 8 cracks, 0.15 s each, 0.8x, hp 250 | real knuckle and joint cracks, darker | 2 |
| gaunt sig | B | FilmCow `marionette movement sounds`; 146339 tongue_click (MoltenMustafa) | 16 loudest wood clacks hp 300 + 11 tongue clicks 0.85x hp 400, 0.12 s each, 60/40 mix | dry tongue + jointed-limb clacks: both halves of the signature | 1 |
| gaunt sig | C | 621977 Multiple Bones Cracking (rydra_wong); 831713 Click Beetle (BugginOut.wav) | 5 snaps 0.2 s + 7 clicks 0.1 s, hp 250-300 | brittle snaps and hard clicks, brightest | 3 |
| scarecrow sig | A | FilmCow `flag 1`, `flag 3`-`flag 7` | first 0.35 s of each snap, 0.8x, hp 60, lp 14 kHz | heavy cloth snaps, cleanest recording | 1 |
| scarecrow sig | B | 701647 Fabric Flapping (IENBA); 386796 flag_flap_3 (RichieMcMullen) | 7 bursts, 0.85x, same cut | cape whips, lighter cloth | 2 |
| scarecrow sig | C | 244982 wing/flag flap (ani_music); FilmCow `umbrella opening 1-6`, `fiber bundle moved 1-2` | flap or umbrella snap 0.8x + straw crackle 50 ms ahead at 0.3 | coat snap with straw rustle under it | 3 |
| boar sig | A | FilmCow `chain 3`, `land in dirt 1-4`, `body fall with lots of bass 1, 2, 4, 5`; 158746 pig grunting close (felix.blume) | chain drags 0.7 s; hoof = dirt landing 0.6x lp 600 + bass slice lp 250; grunts 0.85x hp 50 | chain drag, thud, close pig grunt | 1 |
| boar sig | B | 191513 chain drag floor (Hitrison); 352698 angry pig (Jofae); FilmCow `footstep dirt 2, 7, 12, 17` | chain lp 8 kHz; steps 0.55x lp 600; squeals as recorded hp 50 | harsher chain, angry squealing pig | 2 |
| boar sig | C | FilmCow `metal dragged on floor 1, 5, 9`, `body fall with lots of bass 1, 3-5`; 235959 chain (mffm); 612995 wild boars yelling (felix.blume) | drags 0.6 s; bass thud lp 900; wild boar calls 0.9x, cut to 0.8 s | real wild boars, field recording, more distant | 3 |
| husk sig | A | 855914 timber rattlesnake (TheKingOfGeeks360) | 0.35x (buzz to ~18.7 Hz), hp 300, lp 6.5 kHz, levelled, pulsed 18.7 Hz at 70 percent | slowed rattlesnake, darker (1.5-3 kHz) | 2 |
| husk sig | B | 434881 small gourd shakers (TA-AT); 610143 dried seedpods (Michel1980) | shaker 1.5-5.8 s hp 400 + pods 7.0-9.25 s at 0.5, levelled, pulsed 17 Hz | dried gourd and pods: dried plant matter, bright | 1 |
| husk sig | C | FilmCow `glass full of beads 3, 9, 17`; 127385 seedpods popping (vigorish) | beads hp 400 levelled, pulsed 19 Hz; 2 pod cracks per variant at 0.6 | hard bead rattle with pod cracks | 3 |
| jumpscare gaunt | A / B / C | A 634005 fox screams (Soundburst) + 500797; B 485952 cat hiss (aunrea, 0.85x) + 4 marionette clacks; C 832436 fox night (felix.blume, 0.8x) + 621977 | scare at 0.3 s, thud at 0.92 s, steps from 1.36 s | fox scream + crack / hiss + clacks / low fox bark + snap | A, C, B |
| jumpscare scarecrow | A / B / C | A FilmCow `flag 3` 0.7x + `umbrella opening 2` + `woosh 5`; B 701647 0.75x + 386796 + FilmCow `swoosh 2`; C 244982 0.7x + FilmCow `flag 6` + `fiber bundle moved 1` | same | coat burst at the face | A, B, C |
| jumpscare boar | A / B / C | A 612995 wild boar yell + FilmCow `chain 10`; B 352698 pig squeal + 191513 chain; C 425241 wild boar squeak (Garuda1982) + 764944 wild boar growl (Mastersoundboy2005) + FilmCow `chain basket falling 3` | same | boar scream + chain crash | A, B, C |
| jumpscare husk | A / B / C | A 855914 rattlesnake + 755839 green corn leaves (Sami_Zadoud); B 434881 + 454368 corn stalks in wind (kyles); C FilmCow `harpoon rattle` + 613567 corn field (zazz.sound.design) x4 + 127385 | same | rattle burst + corn crash | A, B, C |
| gnaw | A / B / C | A 260880 dog gnawing bone (YOH); B 854169 large dog chewing bone (FOSSarts); C 861818 dog eating chicken wing (qubodup) | loudest 2.5 s, hp 60; C at 0.88x | real dog teeth on bone | B, A, C |
| lunge | A / B / C | A 613567 corn 8.0-8.5 s x4 + FilmCow bass body fall 2; B FilmCow `crashing through debris 3` + `woosh 5` + bass body fall 4; C 755839 + FilmCow `swoosh 4` + `land in dirt 3` 0.7x | rush, thud at 0.45 s | corn rush and landing | A, C, B |
| flare hit | A / B / C | A 634005 fox scream + FilmCow `land in dirt 3` 0.7x; B 832436 fox 0.9x + bass body fall 1; C 485952 cat hiss + 634005 + bass body fall 5 | shriek, recoil thud at 0.72 s | animal shriek and stagger | A, C, B |
| door bang 01-03 | A / B / C | A FilmCow `door knock 1-3` 0.75x + bass body fall 2-4; B 411694 door kick (deoking) + 452609 heavy door kick (kyles) at 1.0/0.9/0.8x; C 623701 rattling door (mediatheksuche) + FilmCow `closet door close 1, 4`, `screen door close 2` | 1.6 s each | knocked / kicked / rattled door | B, C, A |
| corn part 01-03 | A / B / C | A 755839 three loudest shakes; B 613567 at 8, 20, 30 s; C FilmCow `bushes 3, 8, 15` + `branch moved 2, 5, 7` at 0.35 | 1.0 s each | green corn leaves / corn walk / bush push with stem snap | A, C, B |
| presence swell | A / B / C | A 461839 sleeping dog (installed CEO pick, rebuilt the same way); B 439216 pig breathing close (matschulat) 0.8x; C 170567 donkey breathing (felix.blume) 0.7x | loudest window, hp 40, lp 1.8 kHz, loud breaths ducked | slow big-animal breath | A, C, B |

## CEO listen list

All in `C:\Users\Ockey\Music\ceo_listen\creature\` (each sig/door/corn file plays its 3 variants with 0.6 s gaps;
chase files play the loop 3 times to hear the seam):

1. `gaunt_sig_A/B/C.wav`, `gaunt_sig_chase_B_x3.wav`
2. `scarecrow_sig_A/B/C.wav`, `scarecrow_sig_chase_A_x3.wav`
3. `boar_sig_A/B/C.wav`, `boar_sig_chase_A_x3.wav`
4. `husk_sig_A/B/C.wav`, `husk_sig_chase_B_x3.wav`, `husk_vs_corn_rustle_A/B/C.wav` (husk variant, then corn, three times)
5. `jumpscare_<gaunt|scarecrow|boar|husk>_A/B/C.wav`
6. `gnaw_`, `lunge_`, `flare_hit_`, `door_bang_`, `corn_part_`, `presence_swell_` `A/B/C.wav`

## Open issues

- **Corn stand-in**: no `sfx_corn_rustle` or corn-rustle loop exists in `assets/audio/`, so the husk comparison
  uses 613567 at 20.0-21.75 s, RMS -20.3. Replace it when the real corn rustle exists.
- **Flags for the CEO**: 146339 is a human mouth (tongue clicks, no voice; gaunt B); 831713 is foley of a
  flicked clipboard, not a real beetle (gaunt C); 610143 was recorded through a Morphagene and may be processed
  (husk B underlayer); 764944 is a looped clip (boar jumpscare C); 612995 is a 246 s field recording with
  low rumble (high-passed).
- Husk pulsing is imposed in code on every option; the raw rattles do not meet the 14-22 Hz rule. If the CEO
  prefers the raw rattle, the rule in doc 08 s6 needs a change (Director, FOR CEO).
- After the pick: copy the chosen `logs/listen/real_creature/` files to `assets/audio/<sound_id>.wav`
  (dropping the option letter), commit the picked Freesound mp3s to `assets/audio/src/dl/` with LICENSE lines,
  move the picked rows of doc 08 s13.2 into the s13 table, build chase loops for any non-first-ranked pick
  (`CHASE` in the script), and add `cre_door_bang_02/03` and `cre_corn_part_03` to the Soundscape lists if
  they are not loaded yet (check `game/audio/`).
- The FilmCow library is outside the repo; its license note lives with D-149. Downloads in `fs_creature_wav`
  that no option uses are not referenced and need not be committed.
- Scratch measurement tools (`fs.py`, `ana.py`, `pulse.py`, `bands.py`) and spectrogram PNGs are in
  `logs/scratch_rc/` (git-ignored).

## CEO picks (2026-10-09 listen)

Install all picks in one batch after the listen. Use the steps under "Installing picks" above.

| Sound | Pick | CEO note |
|---|---|---|
| gaunt signature (`cre_gaunt_sig_*`) | C | "just go with c for now and make a note that its not the best": placeholder pick, find a better real source later |
| scarecrow signature (`cre_scarecrow_sig_*`) | A | FilmCow flag snaps at 0.8x |
| boar signature (`cre_boar_sig_*`) | A | FilmCow chain + dirt/bass hoof + Freesound 158746 pig |
| husk signature (`cre_husk_sig_*`) | B | Freesound 434881 gourd + 610143 seed pods at 17 Hz |
| gaunt jumpscare (`cre_jumpscare_hit_gaunt`) | C | |
| scarecrow jumpscare (`cre_jumpscare_hit_scarecrow`) | C | |
| boar jumpscare (`cre_jumpscare_hit_boar`) | B | |
| husk jumpscare (`cre_jumpscare_hit_corn_husk`) | C | |
| gnaw (`cre_gnaw`) | B | |
| lunge (`cre_lunge`) | A | |
| flare hit (`cre_flare_hit`) | A | |
| door bang (`cre_door_bang_*`) | B | |
| corn part (`cre_corn_part_*`) | A, remade | CEO: "reduce the max sound and make it softer, its way too loud", then "the sound should match each corn he goes through". Rebuilt as one 755839 brush per stalk, 0.05-0.10 s apart, RMS -20 dB soft-limited to peak about -12 dBFS, no silent gaps. CEO: "just go with it". |
