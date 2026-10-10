# Handoff: real-recording options for animals, items, radio and UI (D-149)

Role: Audio Designer. Status: options built, **nothing installed**, nothing committed. The CEO picks one
option (A, B or C) per sound by ear; the picks are then installed into `assets/audio/` by a follow-up task.

## What was done

CEO direction D-149: animals "bad, base them off real life animals"; all sounds "base all of the sounds on the
real life counterpart". Every animal, item, radio and UI sound in scope got three options cut from real
recordings: the FilmCow Recorded SFX library (approved in D-149) and Freesound CC0 1.0 sounds (D-066; each
page was checked for CC0 and for remix chains). No voices, no music, no other license. `vox_stranger_*` and
the music were skipped, as asked. The day music was not touched.

- Script: `tools/audio/real_animals_items.py` (`recipes()` holds every cut; `build [names]` writes the
  candidates and listen files; `spec` draws spectrograms). Run it with
  `uv run --no-project --with numpy python -I tools/audio/real_animals_items.py build`.
  It reads the FilmCow folder `C:\Users\Ockey\fc_dl\recorded\FilmCow Recorded SFX\` and the decoded
  Freesound previews in `C:\Users\Ockey\fc_dl\fs_items\wav\` (outside the repo; the saved pages are in
  `fs_items\pages\`).
- Candidates: `logs/listen/real_items/<sound_id>_<A|B|C>.wav` (mono, 48 kHz, 16-bit). Multi-variant
  sounds (chicken 01..03, steps 01..06, and so on) have one file per variant.
- Listen files: `C:\Users\Ockey\Music\ceo_listen\items\<name>_ABC.wav`: A, B, C back to back with 0.8 s
  gaps; the variants of one option follow each other; loops play twice so the seam is audible.

## Processing (all options)

Cut (times below, in seconds), high-pass and low-pass where listed (smooth 4th-order FFT roll-off, from
`process_downloads.py`), trim leading audio below -45 dB, remove DC, 4 ms fade-in and a short fade-out,
soft-limit (tanh) to the RMS of the file it would replace, peak at most -1 dBFS. One-shots start and end at
sample 0. Loops: a 0.25 s equal-power crossfade of the tail into the head, cut to the exact current
length (flare hiss 2 s, cart squeak 3 s, radio static 4 s, crackle 4 s). "Grains" means the strongest
footfall onsets found in a walking recording (the `grains()` method of `process_downloads.py`).

## Listening order for the CEO

`C:\Users\Ockey\Music\ceo_listen\items\`, in this order:
animal_chicken, animal_chicken_panic, animal_pig, animal_pig_panic, animal_cow, animal_cow_panic,
flare_shot, flare_hiss_loop, cart_squeak_loop, beartrap_snap, pit_fall, lantern_blow_out, whistle,
step_dirt, step_corn, step_wood, emote_cloth, ragdoll_thud, radio_static_loop, crackle_loop,
radio_squelch_on, radio_squelch_off, radio_low_battery, radio_dead, ui_click, ui_confirm, ui_deny,
ui_coins, ui_stamp, ui_award_reveal, ui_shop_bell (31 files, `_ABC.wav` suffix).

## Sources

FS = Freesound, `https://freesound.org/s/<id>/`, license CC0 1.0 for every one. FC = FilmCow Recorded SFX
(file name as in the library).

| Sound | Opt | Source | Processing | Description |
|---|---|---|---|---|
| chicken 01..03 | A | FS 456803 "Chicken clucking", Breviceps | 0.05-0.95, 0.75-1.75, 4.55-5.35; hp 150 | hen clucks (16 kHz source, a little dull) |
| chicken 01..03 | B | FS 316921 "Chicken Alarm Call full...", Rudmer_Rotteveel | 0.4-0.9, 2.2-3.0, 4.15-5.1; hp 150 | sharper, more alert clucks |
| chicken 01..03 | C | FS 494613 "ChickenAlarmCall.wav", roboroo | 1.75-2.45, 4.2-5.2, 7.2-8.15; hp 150 | barnyard hen, rounder |
| chicken panic | A | FS 316920 "Chicken Single Alarm Call", Rudmer_Rotteveel | whole | one loud alarm squawk run |
| chicken panic | B | FS 494613, roboroo | 0.3-1.6 | alarm cackle |
| chicken panic | C | FS 232495 "Polish hen cackling.wav", tom_woysky | 4.15-5.0 | short frantic cackle |
| pig 01..02 | A | FS 158746 "A pig grunting...", felix.blume | 3.0-3.85, 10.25-11.1; hp 60 | low sleepy grunts |
| pig 01..02 | B | FS 652361 "Pig grunts.wav", nomerodin1 | 1.0-1.9, 9.1-9.9; hp 60 | snuffling grunts |
| pig 01..02 | C | FS 442906 "Pig Oink", qubodup (remix of CC0 352698) + FS 352698 "Angry Pig Oinking", Jofae | whole; 1.5-2.2; hp 60 | oinks, more pronounced |
| pig panic | A | FS 344972 "Pig in slop squealing", mrmunk | 3.1-4.3 | squeal |
| pig panic | B | FS 260640 "Pig Squealing.mp3", TheAcidRomance | 0-1.3 | high long squeal |
| pig panic | C | FS 352698, Jofae | 2.3-3.35 | angry squeal-grunt |
| cow 01..02 | A | FS 163727 "Cow mooing in south of France", felix.blume + FS 59245 "z-moo01.wav", Zozzy | 0.25-2.35 lp 3500; whole lp 4000 | distant field moos |
| cow 01..02 | B | FS 401636 "cows_mooing_mono_4824.wav", Mystikuum | 0.05-2.15, 2.15-3.75 | close moos |
| cow 01..02 | C | FS 513565 "Cow moo #8", spurioustransients | 2.9-4.85, 6.9-9.3; hp 90, lp 2500 twice | deep moos; faint birds remain |
| cow panic | A | FS 827111 "Loud Bellow from Hereford Bull", TheKingOfGeeks360 | 0-2.7 | loud bull bellow |
| cow panic | B | FS 194899 "Distressed Mother Cow and Calves.wav", lolamadeus | 133.8-136.3 | distressed bawl |
| cow panic | C | FS 194899, lolamadeus | 126.4-129.4 | second distressed bawl |
| flare_shot | A | FS 163455 "Shotgun Shot", LeMudCrab + FS 404434 "Bottle_Rocket_3.wav", Duesenbert | shot lp 2500; whoosh 5.75-6.3 at 0.05 s, gain 0.6 | muffled bang then a rising whoosh |
| flare_shot | B | FS 151713 "PVC Rocket Cannon.wav", bowlingballout + same whoosh | whoosh at 0.08 s, gain 0.5 | hollow tube pop and whoosh |
| flare_shot | C | FS 404434, Duesenbert | 8.2-9.4 | bottle rocket launch and report |
| flare_hiss_loop | A | FS 348767 "road flare ignite burns.wav", frankelmedico | from 0.6; hp 150; loop 2 s | road flare burning |
| flare_hiss_loop | B | FS 348766 "ROAD FLARE.wav", frankelmedico | from 5.0; hp 150; loop 2 s | road flare, rougher |
| flare_hiss_loop | C | FS 316682 "sparkler_fuse_nm.wav", Alex_hears_things | from 4.0; hp 150; loop 2 s | sparkler fizz, crackly |
| cart_squeak_loop | A | FS 635488 "cart noisy push roll... squeaky rattly wheel", kyles | from 2.5; loop 3 s | cart roll, squeak and rattle |
| cart_squeak_loop | B | FS 577320 "Tricycle wheel squeek.wav", TRP | from 1.95; loop 3 s | regular wheel squeak |
| cart_squeak_loop | C | FS 389687 "Squeaky Wheels.wav", Shamewap | from 0.9; loop 3 s | higher squeaks |
| beartrap_snap | A | FS 644245 "Steel Spring Bear Trap", fractionalist | 0.78-1.75 | real steel trap snap |
| beartrap_snap | B | FS 278203 "Bear Trap", ThePriest909 (sources ra_gun 83374, 83454, CC0) | whole | heavy metal snap with ring |
| beartrap_snap | C | FS 752070 "Trap Springing Shut", qubodup (sources 38747, 426774, 752065, CC0) | 0.4-1.0 | tight spring clack |
| pit_fall | A | FC "crashing through debris 2" + FC "land in dirt 1" | land at 0.45 s | crash through cover, land in dirt |
| pit_fall | B | FC "crashing through debris 1" + "land in leaves 2" + "body fall with lots of bass 3" | layered | crash, leaves, heavy body |
| pit_fall | C | FS 461697 "Body falls into debris", leonelmail + FS 853591 "A body falling... with leaf crush", Wigglesworth | 0.1-1.3; 11.95-12.6 | body into debris and leaves |
| lantern_blow_out | A | FS 242867 "blowing out candle.wav", Reitanna + FC "glass clink 1" | 0.25-0.8; clink at 0.45 s, gain 0.25 | human puff, small glass tick |
| lantern_blow_out | B | FS 204531 "Candle flicker/ blown out x4", peridactyloptrix | 2.8-3.6 | human puff on a flame |
| lantern_blow_out | C | FC "air duster 1" + FC "glass clink 1" | clink gain 0.25 | air puff, no breath |
| whistle | A | FS 255835 "tin whistle.wav", neild101 | 2.85-3.8 | one tin-whistle (penny whistle) note |
| whistle | B | FS 35397 "tin whistle messing.wav", marvman | 5.2-6.5 | tin whistle, short changing phrase |
| whistle | C | FS 568995 "metal whistle.wav", strongbot | 12.75-13.7 | metal pea whistle near 3 kHz (old design) |
| step_dirt 01..06 | A | FC "footstep dirt 1".."6" | trim, fade | dirt steps |
| step_dirt 01..06 | B | FS 452633 "footsteps boots shoes dirt gravel...", kyles | grains | boots on dirt and gravel |
| step_dirt 01..06 | C | FS 682127 "Footsteps Dirt Road 1.wav", HenKonen | grains | dirt road steps |
| step_corn 01..06 | A | FC "footstep grass and leaves 1".."6" | trim, fade | grass and leaf steps |
| step_corn 01..06 | B | FC "footstep leaves 1".."6" | trim, fade | dry leaf steps |
| step_corn 01..06 | C | FS 613567 "Walking Through Corn Field", zazz.sound.design | grains | real corn-field steps |
| step_wood 01..06 | A | FS 543685 "Footsteps_Wood_Walk_Mono.wav", Nox_Sound | grains | wood floor steps |
| step_wood 01..06 | B | FS 523273 "Foley_Footsteps_ShedWoodenFloor.wav", MrFossy | grains | shed floor, hollow |
| step_wood 01..06 | C | FS 521589 "Hiking Boot Footsteps on Wooden Planks", Fission9 | grains | boots on planks; short (0.09-0.15 s) |
| emote_cloth | A | FC "clothes ruffle 1" | trim, fade | clothes ruffle |
| emote_cloth | B | FC "clothing movement 1" | trim, fade | softer cloth movement |
| emote_cloth | C | FC "flag 1" | trim, fade | heavier cloth flap |
| ragdoll_thud 01..02 | A | FC "body fall 1", "body fall 2" | trim, fade | body falls |
| ragdoll_thud 01..02 | B | FC "body fall with lots of bass 1", "2" | trim, fade | heavier, bassier |
| ragdoll_thud 01..02 | C | FS 504626 "BODY FALL - V HVY - DIRT", leonelmail + FS 853591, Wigglesworth | 0.4-1.1; 10.7-11.4 | heavy fall on dirt |
| radio_static_loop | A | FS 154654 "Walkie_Talkie_Static.aif", crcavol | from 4.5; bp 300-3400; loop 4 s | walkie static |
| radio_static_loop | B | FS 760335 "Radio static", LukaCafuka | from 12; bp 300-3400; loop 4 s | walkie line-out hiss |
| radio_static_loop | C | FS 110739 "Radio static", clesquir | from 20; bp 300-3400; loop 4 s | AM/FM static |
| crackle_loop | A | FS 154654, crcavol | from 7.5; only the clicks (1.5-4 kHz transients over 1.8x their 0.1 s level); loop 4 s | sparse walkie crackle |
| crackle_loop | B | FS 316682, Alex_hears_things | from 4.0; same click gate; loop 4 s | dense sparkler-like crackle |
| crackle_loop | C | FS 110739, clesquir | from 30; same click gate; loop 4 s | radio-static crackle, medium |
| radio_squelch_on | A | FS 454259 "tv channel change static blips...", kyles | 0.08-0.34 | CB blip |
| radio_squelch_on | B | FS 701314 "Walkie Talkie button press tone", SEF7 | 0-0.22 | walkie key tone |
| radio_squelch_on | C | FS 612722 "walkie_talkie_beep.wav", 3questionmarks | 0.62-0.99 | walkie beep |
| radio_squelch_off | A | FS 524205 "Radio Sign Off / Squelch", JovianSounds | 0-0.22 | squelch tail |
| radio_squelch_off | B | FS 760245 "Walkie-talkie end of transmission", LukaCafuka | 0-0.33 | end-of-transmission burst |
| radio_squelch_off | C | FS 47646 "End radio transmission", ReadeOnly | whole | toy walkie end tone |
| radio_low_battery | A | FC "beep 3" | two beeps 0.3 s apart | two electronic beeps |
| radio_low_battery | B | FS 701327 "Walkie Talkie power on", SEF7 | 0-0.42 | walkie power tones |
| radio_low_battery | C | FS 701326 "Walkie Talkie famous beep", SEF7 | 0-0.3 | end-of-transmission tones |
| radio_dead | A | FC "tube tv turn off 1" | 0.05-0.5 | tube set dying |
| radio_dead | B | FC "light switch off" + FS 760245, LukaCafuka | burst 0.24-0.3 | switch click with a static burst |
| radio_dead | C | FS 454259, kyles | 8.45-8.7 at 0.7x speed | blip pitched down, dying |
| ui_click | A | FC "mouse click 1" | trim | very short click |
| ui_click | B | FC "switch press 1" | from 0.36 | switch press |
| ui_click | C | FC "knob clicky turn 1" | from 0.18 | knob detent |
| ui_confirm | A | FC "ding 1" | 0.45 s | small ding |
| ui_confirm | B | FC "glass ding 1" | trim | glass ding |
| ui_confirm | C | FC "clicky button 1" | trim | button click, no tone |
| ui_deny | A | FC "door knock 1" | 0.1-0.75 | two knocks |
| ui_deny | B | FC "punch soft thud 1" | played twice | two soft thuds |
| ui_deny | C | FC "table hit 1" | trim | one table hit |
| ui_coins | A | FS 847350 "handful-of-coins-007", ilyaShevelev | whole | short handful |
| ui_coins | B | FS 223343 "1_Coins.ogg", jalastram | whole | coins dropped |
| ui_coins | C | FS 336481 "CoinsSlide_03.wav", Faulkin | 0.1-0.85 | coins sliding |
| ui_stamp | A | FS 470710 "traditional stamp.wav", I.fekry | from 0.4 | rubber stamp |
| ui_stamp | B | FS 448474 "es-stamp.wav", eddies2000 | from 1.0 | stamp, two-part |
| ui_stamp | C | FS 683031 "Thump.mp3", mpuffenbarger | whole | fist thump on drywall |
| ui_award_reveal | A | ui_stamp A + FS 709925 "Service bell louder", Squidems | bell from 1.3 at 0.3 s, gain 0.45 | stamp, then a service-bell tick |
| ui_award_reveal | B | ui_stamp B + FC "glass ding 1" | at 0.3 s, gain 0.45 | stamp, then glass ding |
| ui_award_reveal | C | ui_stamp C + FC "ding 1" | at 0.3 s, gain 0.45 | thump, then small ding |
| ui_shop_bell | A | FS 57743 "shop_door_bell.wav", 3bagbrew | whole, 1.2 s | real door bell; jingles about 4 times, not 2 |
| ui_shop_bell | B | FS 192761 "Ryuuzan_shop_door_bell00.wav", ryuuzan (from a CC0 bell) | whole | double ding |
| ui_shop_bell | C | FS 709925, Squidems | struck at 0 and 0.28 s | service bell, two strikes |

Downloaded but not used: 192035, 349177, 668804, 823065 (chickens); 376467, 421734, 442907, 567529 (pigs);
353682, 546479 (cows); 218318 (referee whistle); 45650, 587173 (fuses); 406648, 826338 (candles); 352870,
459970 (steps); 559470 (wheel). Excluded on purpose: 125392 (AM tuning, may hold broadcast voice or music),
321906 (synthesized beep), 522164 (designed noise), 151903.

## Checks

Every candidate: length, RMS (matched to the current file), peak at most -1 dBFS, first and last sample 0
for one-shots. Spectrograms of every listen file were read (`logs/listen/real_items/spec/`). The crackle loop
was first built with a whole-file gate and came out silent for A and B; it is now gated against the local
0.1 s level (all three at RMS -31.3 dB, dense clicks like the current asset).

## Open issues for the CEO

- Lantern A and B are a person blowing out a candle: breath, no voice. C is an air duster (no person).
- Whistle: "a real tin whistle" read as a penny whistle (A, B). C is a metal pea whistle like the old design.
- Flare shots are 0.5 to 0.7 s; the current file is 1.2 s. The hiss loop carries the burn after it.
- Step wood C grains are short (0.09-0.15 s).
- Cow C has faint birds after filtering.
- Shop bell A jingles about four times; the brief said two strikes (B and C have two).
- The picks change no gameplay, file names or lengths of loops; installing is a copy to `assets/audio/`,
  plus a doc 08 section 13 row per pick (source, author, cut).

## CEO picks (2026-10-09 listen)

| Sound | Pick | Notes |
|---|---|---|
| animal_chicken | A | |
| animal_chicken_panic | A | |
| animal_pig | C | |
| animal_pig_panic | A | CEO: "save option c because i might switch to that later". At install, also keep C (for example `assets/audio/alt/`). |
| animal_cow | A | |
| animal_cow_panic | A | CEO: "keep option c of the cow one as an option to be used later". At install, also keep C (for example `assets/audio/alt/`). |
| flare_shot | C | |
| flare_hiss_loop | C | |
| cart_squeak_loop | B, remade | CEO: "reduce the max sound in the audio because the peak loud sound was too much". Rebuilt with `squash` 2 dB and `TRIM` -6 dB: RMS -16.8, peak -9.1 (was -10.8 / -1.9). CEO: "yes go with b". |
| beartrap_snap | A | |
| pit_fall | A | |
| lantern_blow_out | A | Breath of a person blowing out a candle, no voice. |
| whistle | C | |
| step_dirt | B | |
| step_corn | A | |
| step_wood | A | |
| emote_cloth | C | |
| ragdoll_thud | A | |
