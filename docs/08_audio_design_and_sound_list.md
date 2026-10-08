# Doc 08: Audio Design & Sound List

Owner: Audio Designer. Task PP-09. Source of truth is [doc 01](01_design_doc.md); doc 01 "Jumpscares"
says to budget more for audio than for the creature's model. Numbers here are starting values.
Where doc 01 gives none the row says `placeholder`; where this doc reads doc 01 in a way it doesn't
state, the row says `inference` and names what settles it. Distances are metres between the points
named, as in doc 04. "AI Director" always means the in-game pacing system.

**I cannot hear.** Everything here is built from text, measured numbers and spectrograms
(D-015). Whether a sound is scary or right is the CEO's call by ear, at the listening list in
section 14.

## Contents

1. [Principles](#1-principles)
2. [Buses and mixing rules](#2-buses-and-mixing-rules)
3. [Spatial rules](#3-spatial-rules)
4. [Ambience layers](#4-ambience-layers)
5. [Creature state tells](#5-creature-state-tells)
6. [Body signatures](#6-body-signatures)
7. [Voice tells and the voice mix](#7-voice-tells-and-the-voice-mix)
8. [Player states: Taint, still, Shaken](#8-player-states-taint-still-shaken)
9. [Dusk bell, generator, whistle](#9-dusk-bell-generator-whistle)
10. [Runtime API (`Soundscape`)](#10-runtime-api-soundscape)
11. [Sound list](#11-sound-list)
12. [How sounds are generated and checked](#12-how-sounds-are-generated-and-checked)
13. [Sources and licenses](#13-sources-and-licenses)
14. [Listening list for the CEO](#14-listening-list-for-the-ceo)
15. [Gotchas](#15-gotchas)
16. [Questions raised](#16-questions-raised)

---

## 1. Principles

1. **Audio is the creature's body.** Doc 01 pillar "Glimpsed, never seen": players hear it far more
   than they see it. Every state has a sound change, not a visual one (doc 01 "Behavior states").
2. **Absence is a signal.** Stalk is a layer dropping away (doc 01 "Ambience"). So **nothing else in
   the game may drop the insect and frog bed or the wind**: not dusk, the generator, a pause, a
   building, a loading hitch or a lost packet (section 4.4). This is the audio twin of the lantern
   rule (doc 01 "Ghosts": nothing else flickers a light).
3. **Honest signals cost something.** The whistle, walkie and ghost flicker are unfakeable; the
   creature's fakes use the very same assets and chain as the real thing (doc 01 "The creature's
   fakes"). No sound is "cleaner" because the creature plays it. A fake footstep is the real
   footstep asset.
4. **Protect the contrast** (doc 01 pillar "Cozy day, terrifying night"). Day is warm and busy
   (birds, livestock, wind, insects); night is sparse, so each hit lands. Never loud by default.
5. **What the creature hears, you can hear.** Audible range of a player-made sound is at least 1.5x
   its `NoiseBus` radius (section 3.2), so a careful player can predict danger. `placeholder`.
6. **Everything is a placeholder.** Every sound in section 11 is generated in code by this studio
   (D-015). Each is replaceable one for one: same ID, same duration class, same bus, same loop
   rule. The `Placeholder` column is "yes" for all rows. Nothing is sampled or downloaded.
7. **Mono in 3D, stereo for beds and UI only** (Audio Designer brief and D-015; CONTRACTS s3 does not say it, flagged to the Director in Q-035).

## 2. Buses and mixing rules

### 2.1 Layout

CONTRACTS section 9: `Master` with children `Music`, `SFX`, `Ambience`, `Creature`, `Voice`, `UI`.
Mix rate 48 kHz (doc 06 section 8; D-015). All dB values are `placeholder`, to be set by ear.

| Bus | Holds | Volume (dB) | Effects in `default_bus_layout.tres` |
|---|---|---|---|
| `Master` | everything | 0 | `AudioEffectLimiter` ceiling -1 dB, so a stacked sting + voice + chase can't clip |
| `Music` | chase sting only; no day music, never (CEO, Phase 1 playtest) | -6 | none |
| `SFX` | footsteps, tools, doors, generator, well, bell, whistle, traps, cart, crows, livestock, flare | -4 | none |
| `Ambience` | the state-driven beds only: wind, insect, frog, corn rustle loop, bulb hum (section 4) | -8 | `AudioEffectLowPassFilter` named `Indoor`, disabled; enabled in buildings (section 4.5) |
| `Creature` | body signatures, lunge, jumpscare hit, door bangs, gnaw, trap setting, presence swell | -2 | none |
| `Voice` | real teammates, ghosts, fakes, walkies, stranger lines, crackle and static layers | 0 | none on the parent; children below |
| `UI` | menus, Dawn Report paper, coin, recording ticks | -6 | none |

- **Animals and crows sit on `SFX`, not `Ambience`.** Stalk ducks the `Ambience` layers by layer
  tag (section 4.3), never by bus, and crows and livestock must keep playing through a Stalk
  (doc 01: "Stalk is a layer dropping away, not animals going missing"). Birdsong one-shots too
  (they are `SFX`). So the bed is the only thing that vanishes.
- **`Creature` has no player slider** and no ducking: it is gameplay information (inference; settle
  by the CEO's call on accessibility). A Settings option `reduce_scares` lowers `Creature` stings
  and `Music` stings by 8 dB (`placeholder`, owner Gameplay's `Settings`).
- Player sliders (Settings, Gameplay): Master, Music, SFX, Ambience, Voice, UI. Sliders write
  `AudioServer.set_bus_volume_db` on those buses, nothing else.

### 2.2 Voice chain buses (answer to Q-007)

Agreed with the Network & Voice Programmer's preference (Q-007): **`game/voice/` creates the chain at
runtime**, because its effects and settings live with the code that owns the chain (doc 06 section 9).
That means `Mic` and the children of `Voice`: `VoiceBase`, `VoiceEcho`, `VoicePitchUp`,
`VoicePitchDown`, `VoiceGhost`, `VoiceGhostEcho`, `VoiceGhostPitchUp`, `VoiceGhostPitchDown`,
`VoiceRadio`. **The mix levels of those buses are mine** and are the table in section 7.2, which
`game/voice/` reads from `game/audio/mix_levels.gd` (constants, one file) instead of hard-coding.
The layout file holds only the seven buses above. If the CEO prefers the chain buses in the file, the
move is mechanical.

### 2.3 Mixing rules

1. **No sidechain ducking in DD Phase 1** (inference). Ducking beds when someone talks would also
   mask the Stalk drop, the one thing the beds are there to show. Revisit if voices feel buried (a
   DD Phase 2 playtest note).
2. **Priority when sounds stack** (from loudest intent down): chase sting, jumpscare hit, creature
   signature in Chase, voice, player tools, footsteps, beds. Mechanism: not ducking but level
   targets (section 2.4); the limiter catches the rest.
3. **Voice is the loudest continuous thing at 6 m or less** and fades by distance like any 3D
   sound (section 3). Fakes and real voices use the same levels (doc 01).
4. **Quiet is the baseline.** At night, with nothing happening, the loudest thing is the wind at
   about -34 dBFS RMS after the Master (target, `placeholder`). Scares are 20+ dB above that.
5. **Pause menu and Dawn Report** low-pass `Master` at 1.2 kHz and drop `SFX` by 10 dB with a
   0.3 s fade; `Ambience` is not touched, so the bed and wind keep playing at their current
   gains under the low-pass (section 4.4 rule 2). The Dawn Report has no music.
6. **Simultaneous voice limit** is the game's: 4 real speakers plus at most 2 fakes at once
   (inference: doc 03 allows one lure at a time, ghosts add up to 3). Each is its own player node
   (doc 06 section 8).
7. **Polyphony.** Max 32 live 3D emitters (`placeholder`, to be profiled in DD Phase 1). Beyond that
   the farthest and quietest is stopped. Footstep and tool one-shots are never queued, only dropped.

### 2.4 Level targets (RMS at the listener, dBFS before the Master limiter)

All `placeholder`. Every WAV is peak-normalised to -1 dBFS (D-015), so the per-sound trim lives in
`volume_db` on the player node, set from the sound's row in the catalog (section 10.3).

| Class | Target at 5 m | Notes |
|---|---|---|
| Wind, night | -34 | steady, wide |
| Insect bed, night | -30 | the layer that carries the tell, so audible but not busy |
| Insect bed, day | -32 | |
| Footsteps (own, walk) | -26 | |
| Tools | -18 to -14 | loud tools sound loud (doc 01 "Noise") |
| Voice, normal speech | -20 | |
| Generator hum | -24 at 5 m | heard across the yard |
| Creature signature, Chase | -12 | "loud" (doc 01) |
| Chase sting | -8 peak-ish | the loudest event in the game |
| Taint heartbeat | -42 | "faint" (doc 01), local only |

## 3. Spatial rules

Stock `AudioStreamPlayer3D`; doc 06 section 8 sets voice attenuation (inverse distance, unit size
10 m, max 120 m) and keeps `VoiceEmitter` swappable. Sound emitters follow the same discipline: **one
scene, `game/audio/sound_emitter.tscn`, is the only node that places a non-voice sound in 3D**, so
the DD Phase 1 spatial-audio gate (doc 01 "Testing") can swap the spatialiser (Steam Audio, or
raycast occlusion and reverb, doc 06 section 8) in one place.

### 3.1 Settings for every emitter

| Property | Value | Why |
|---|---|---|
| `attenuation_model` | inverse distance | as voice |
| `doppler_tracking` | **off** | a running creature would pitch-bend, a tell nobody designed; and the wrong-pitch voice tell must stay a tell |
| `panning_strength` | 1.0 | |
| `max_polyphony` | 1 for loops; 4 for footsteps and tools | |
| `bus` | by the sound's ID prefix (section 11): `sfx`, `step` and tool names to `SFX`; `amb` to `Ambience`; `cre` to `Creature`; `vox` to `Voice`; `mus` to `Music`; `ui` to `UI` | `cre`, `vox`, `mus`, `ui`, `amb` are not in CONTRACTS s3 yet; flagged for the Director's PP-11 update (Q-035) |
| Occlusion | a ray to the listener hitting layer 5 (corn): low-pass 3 kHz and -6 dB; hitting a wall: low-pass 1.5 kHz and -10 dB | mirrors the Noise corn damping (doc 03 s3.1: x0.7 radius); `placeholder`; the doc 06 contingency |

### 3.2 Range classes

`unit_size` = distance at which the sound is at full level; `max_distance` = silent beyond. Hearing
radii are doc 03 section 3.1 (all `placeholder` there). Audible range is about 1.5 to 2x.

| Class | Sounds | Noise radius | `unit_size` | `max_distance` |
|---|---|---|---|---|
| Footsteps | `sfx_step_*` | 12 (walk), 30 sprint, 40 sprint in corn, 0 crouch | 3 | 40 walk, 70 sprint; crouch 4 |
| Light tools | till, plant, water, harvest | 15 | 4 | 40 (quiet can: 20) |
| Heavy tools | shovel, pry, repair | 25 | 5 | 60 |
| Disarm | `sfx_disarm_click` | 8 | 2 | 16 |
| Well pump | `sfx_well_pump_*` | 45 | 6 | 90 |
| Door | `sfx_door_*` | 20 | 4 | 45 |
| Generator running | `sfx_generator_loop` | none (it is the farm's hum) | 8 | 90 |
| Generator dying | `sfx_generator_die` | 80 | 10 | 160 |
| Tripwire bells | `sfx_tripwire_bells` | 60 | 6 | 110 |
| Flare | `sfx_flare_shot` | 70 | 8 | 140 |
| Whistle | `sfx_whistle` | 50 | 20 | **220** (section 9.3) |
| Creature signature | `cre_*_sig_*` | n/a (it is the creature) | 5 | 90 |
| Church bell | `amb_church_bell_x3` | n/a | 80 | 700 (section 9.1) |

- Footsteps of the local player are non-positional (`AudioStreamPlayer`) and quieter in the mix; other
  players' steps use the emitter. Crouch-walk is silent to the creature (doc 01 "Hiding verbs") and
  made nearly silent to players (-12 dB, max 4 m) so audio and Noise agree. Sprint is +6 dB.
- **Tainted footsteps** (+50% heard, doc 01 "The Taint"): `max_distance` and `unit_size` x1.5, plus the
  wet overlay `sfx_step_taint_wet_*` at -10 dB under the normal step.

## 4. Ambience layers

Ambience runs locally on each client from the replicated creature state and the day phase (doc 01
"Ambience"; doc 03 section 4). The host's state message is `apply_creature_state(state, body)` on
change plus `creature` at 15 Hz (doc 06 section 7); `Soundscape` (section 10) is the only listener.

### 4.1 Layers

A layer is a group of looped or scheduled sounds sharing one gain stage (`AudioStreamPlayer` volume,
not a bus). `Tag` is what the Stalk rule affects.

| Layer | Tag | Content | Day | Dusk | Night |
|---|---|---|---|---|---|
| Wind | `wind` | `amb_wind_loop` (stereo) | -26 dB | -24 | -20 |
| Bed, insects | `bed` | `amb_insect_bed_night` (stereo loop) | off (no day insect bed) | in over 45 s | -28 (CEO: halved after the 2026-10-08 playtest) |
| Corn rustle | `corn` | `amb_corn_rustle_loop` (stereo), level by distance to the nearest corn edge, plus one-shots `sfx_corn_rustle_*` | within 6 m of corn: -28 | same | within 6 m: -30 |
| Birds | none (SFX one-shots) | `sfx_bird_*`, one call every 6 to 14 s, random place within 40 m | on | fade out over 45 s | off |
| Livestock | none (SFX one-shots) | `sfx_animal_*` from the pen, every 12 to 30 s, plus when the Rancher rounds up | on | quiet over 45 s ("animals go quiet", doc 01 "Dusk") | off (rare shuffle only) |
| Crows | none | `sfx_crow_*` at `crow_perches` (doc 04 s7.3); sparse | on | off | rare |
| Bulb hum | `light` | `amb_bulb_hum_loop` mono at each lit building's light, 3 m max | when powered | | when powered |
| Dawn | none | `sfx_rooster` once at dawn | | | dawn only |

- Day and dusk levels are `placeholder` and tuned by ear; the **ratios** between layers do not
  change by state except as section 4.3 says.
- **Dusk** (doc 01 "Core Loop"): lasts about 1 minute. Birds and livestock go quiet, the night bed
  crossfades in, and the church bell rings three times (section 9.1). **The bed never reaches
  silence at dusk**; it changes colour (cicada buzz to crickets and frogs). Players must never read
  dusk as a Stalk.
- **Late joiners and reconnects** (doc 06 section 5): `Soundscape` reads the current phase and
  creature state when the roster arrives and starts at those gains with no fade.

### 4.2 Natural variation, so the bed breathes but never drops

- Wind gains wander +/-3 dB over 6 to 20 s (low-frequency noise), never below -6 dB from the layer
  base.
- The bed has a slow +/-2 dB swell and a random "chirp group" pause: individual voices of the bed
  stop and start, but the total layer stays above -4 dB from its base (inference: the bed must always
  be at its audible floor so that a drop to zero is unmistakable).
- **A Stalk drop is a drop of 24 dB or more within 1 s** (section 4.3); natural variation is a
  handful of dB over seconds. The numbers are `placeholder`; the playtest question is "can a tester
  who hasn't read doc 01 notice the drop".

### 4.3 State table: what each creature state does to the layers

Fade times are `placeholder`. `base` is the layer's level for the current phase.

| State | `bed` (insects, frogs) | `wind` | `corn` | Other | Why |
|---|---|---|---|---|---|
| `lurk` | base | base | base | birds, livestock, crows as scheduled | "normal ambience" (doc 01 states table) |
| `lure` | base | base | base | the fake sound or voice plays from the corn (section 7) | doc 01: just the lure |
| `stalk` | **to -60 dB in 0.8 s** (insects first, frogs 0.3 s later) | **base - 18 dB over 2.0 s** | base - 6 dB | **Everything else unchanged** (birds, livestock, crows keep playing; doc 01 "Crows aren't a state tell") | doc 01: "the insect and frog bed cuts out and the wind drops" |
| `chase` | stays off | stays down | off | the **chase sting** (`mus_sting_chase`) fires once on entry, and the body's signature plays loud (section 5.3) | doc 01: "music sting plus the body's signature, loud" |
| `retreat` | **returns over 4 s** (insects first, frogs 2 s later) | **returns over 6 s** | base | the signature stops within 1 s | doc 01: "the insects and frogs come back" |
| `lurk` after a chase is lost | returns over 8 s (inference: doc 01 names retreat only; a lost chase also returns to Lurk) | over 10 s | base | | the layers must not stay off in a state that has no tell |

- **Stalk to Chase** keeps the bed off with no extra cue, then the sting lands on a silent
  background, which is the intended contrast (doc 01 "Making them land": "build up first with
  silence, the insects cutting out").
- **Day trap race** (doc 01 "Day deaths"): the signature approaches from the start distance. I treat
  it as a Chase for ambience: bed off at the spring, signature loop approaching, **no sting**
  (inference: doc 01 gives the race only the signature; a sting would also tell every client).
  Settles by: the CEO's ear on the race, and doc 09's trap-race check.
- **Day jumpscare** (doc 01 "Jumpscares", `stalk` to `retreat` in doc 03 s4.2): the stalk drop
  happens, the `cre_jumpscare_hit` plays (section 5.4), then Retreat brings the layers back.
- **Scope of the drop.** The replicated state has no target in it, so every client hears the drop
  (global). The creature's position is known (the 15 Hz message); a "near only" depth (full drop
  within 60 m, -9 dB beyond) is a switch `stalk_scope` in `Soundscape`, default `global`
  (inference; a DD Phase 1 playtest settles whether global drops tell too much or too little).
- **Failsafe.** If a Stalk lasts longer than `stalk_max_s` (25 s, doc 03 s4.1) plus 5 s without a new
  state message, the layers fade back to base, so a lost reliable message can never leave the farm
  silent (a silence that would itself be a false "Stalk").

### 4.4 Rules that keep the tell honest (QA greps for these)

1. Only `Soundscape.set_creature_state()` may change the gains of layers tagged `bed` or `wind`
   downward by more than 6 dB. This rule is about layer gains. The `Ambience` bus changes for a
   building (rule 3, section 4.5) are the one named bus-level exemption: they follow where the
   listener stands, never creature state, and a Stalk drop is still heard on top of them. The phase crossfade (dusk, dawn) is the one exception and is a
   crossfade between two beds, never through silence.
2. Generator death, a pause (including the pause low-pass, section 2.3 rule 5), a menu, a slow frame, a disconnect or a host-left card never touch
   `bed` or `wind`.
3. Entering a building applies the `Indoor` low-pass and -6 dB to `Ambience` (section 4.5), not a
   mute, so the bed is still there to be heard dropping, quietly.
4. Crows, livestock and birds are never scheduled by creature state (they follow the clock and
   their own timers only). A fake-out crow burst (doc 01 "Jumpscares") plays `sfx_crow_burst` with no
   change to the layers.

### 4.5 Indoors

Lit building (generator on): `Indoor` low-pass at 2.5 kHz on `Ambience`, `Ambience` -6 dB, bulb hum
audible, `amb_room_barn` quiet room tone (a lit room is a calm one). Dark building: `Indoor` at
1.2 kHz, `Ambience` -10 dB (the bus-level exemption of section 4.4 rule 1; layer gains untouched), no hum, `amb_room_dark` (a low breath of air and creaks) so a dark
room sounds hollow. Entering and leaving cross 0.5 s. `placeholder`. A building is "lit" from
`LightRig` state (doc 07), read by `Soundscape`.

## 5. Creature state tells

### 5.1 Summary

| State | Player hears | Rule |
|---|---|---|
| `lurk` | the full bed; faint movement through corn (`cre_corn_part_*`, 12 m audible) and rare trap setting (`cre_trap_set_*`, 25 m) | nothing about the body's signature (inference, section 5.3) |
| `lure` | the fake (voice, footsteps or tool) from the corn, through the same chain | wrong place is the tell (doc 01) |
| `stalk` | the bed and wind dropping, then near silence; very rare faint signature at 20 m (below) | |
| `chase` | sting, loud signature, steps through corn at speed | |
| `retreat` | the bed returns | |

### 5.2 Stalk detail

After the drop, the farm is wind-low and bed-off. In that quiet the creature gives a **faint, rare
signature** (`cre_<body>_sig_*` at -30 dB, once every 6 to 10 s, only within 20 m of any
player, `placeholder`; inference: doc 01 says players should hear it, and silence with a tell that
can be placed rewards listening). If the CEO wants the stalk wholly silent, set `stalk_sig_period_s`
to 0. Settles by: DD Phase 1 spatial audio test (the Stalk direction depends on it, doc 01 Open
Issue 3).

### 5.3 Chase

1. On entry the host sends `apply_creature_state(chase)`; each client plays `mus_sting_chase` once
   (`Music`, non-positional, ~3 s) and starts `cre_<body>_sig_chase` (loop, positional on the
   creature, `Creature` bus), at its fast cadence.
2. The signature's cadence follows speed: Chase plays the loop at `pitch_scale` 1.0; a
   slowed or stopped creature (after a flare hit) drops to the Retreat fade.
3. Chase signature is loud (target -12 dB at 5 m); the sting is 20 dB above the night floor. Both are
   `placeholder` to set by ear.
4. **Close calls** (lunge, doorway reach) cut to black or knockdown (doc 01 "What players see"):
   `cre_lunge` plays at the cut, then `cre_jumpscare_hit` for knockdown, then Retreat.
5. **Chase lost or lit building:** the signature stops within 1 s; the bed returns (section 4.3).

### 5.4 One-shots in the Creature bus

| Moment | Sound | Notes |
|---|---|---|
| Disarm lunge (doc 01 "Jumpscares") | `cre_corn_part_*` x2 (stalks parting) 0.4 s before `cre_lunge` | the parting is the warning |
| Day jumpscare | `cre_jumpscare_hit` | plays on `Creature`, ragdoll thud `sfx_ragdoll_thud_*` on SFX |
| The trap (looking up) | silence + `cre_presence_swell` low | a "watching" tell, not a hit |
| The shed | `sfx_door_slam` behind, no creature sound | |
| Hallucination, stare, wrong count | `cre_presence_swell` (local, private) | no knockdown (doc 01); played only for the target |
| Door banging (doc 01 "Light is the rule") | `cre_door_bang_*` x3, repeated | always before it enters; from day 6, barn bangs while circling |
| Gnawing the pumpkin / biting on the cart | `cre_gnaw` | |
| Setting traps at night | `cre_trap_set_*` | rare, quiet |
| Flare hit | `cre_flare_hit` | then Retreat |

## 6. Body signatures

All four bodies hunt identically; they differ in look and sound only (doc 01 "Bodies"; doc 03 s2).
The signature is what plays in Chase and in the trap race (doc 03 s2, s7). Because the bodies must
be recognisably different by ear and no signature may read as another sound in the game:

| Body | Signature | Shape (placeholder recipe) | Must differ from |
|---|---|---|---|
| `gaunt` | **clicks**: dry tongue and joint clicks | bursts of 1 to 4 ms band-passed noise at 1.8 to 3.4 kHz, irregular rhythm 6 to 14 per s in Chase, 1 to 3 per s in Lurk; each click gets a short hollow knock at ~220 Hz | footsteps (no low thump), insects (irregular, not periodic, never continuous) |
| `scarecrow` | **coat flaps**: heavy cloth snapping | low-passed noise burst (cloth snap) with a 90 to 140 Hz body, at running stride rate (~2.4 per s in Chase), each flap a bit different in length | wind (too sudden), corn rustle (one event, not a texture) |
| `boar` | **chain drags**: iron collar chain on ground, hoof thuds | metallic ring partials 700 Hz to 4 kHz bursting into a scraping noise band 1 to 5 kHz, with a 60 to 90 Hz thud per stride; a slow 1.2 per s drag in Lurk | tripwire bells (bells are tonal and long, chain is scrape and clatter), generator |
| `husk` | **dry rattle**, distinct from normal corn rustle (doc 01) | narrow band-passed noise at ~4 to 7 kHz amplitude-modulated by 14 to 22 Hz pulses with a hollow 800 Hz resonance underneath ("seed pods in a gourd"), pulse rate rises with speed | `amb_corn_rustle_loop` / `sfx_corn_rustle_*`: corn rustle is broadband 500 Hz to 4 kHz, smooth, **unpulsed**, gust-shaped; the husk rattle is periodic and bright with a dry crack |

- **The husk and corn rustle test.** Spectrogram check (section 12.3): rustle has no energy peak
  between 14 and 22 Hz in its envelope; the rattle must. QA/CEO listen to them back-to-back.
- Each signature has 3 short variants (`_01` to `_03`, 1.5 to 2 s) for Lurk, the trap race and the
  rare Stalk ticks, and one Chase loop `_chase` (4 s, exact period, 1 body cycle).
- **Body quirks** (doc 01 Open Issue 4) are not built: the signature is the only body-specific
  sound, as doc 03 s2.
- The body is chosen per season by the host; the other three signatures are never loaded.

## 7. Voice tells and the voice mix

Co-owned with the Network & Voice Programmer. They own the chain code, tells and transport (doc 06
sections 8 to 10); I own the levels, the generated layers and the placeholder voice lines.

### 7.1 Tell inventory (doc 01 "Tells"; doc 06 section 9)

| Tell | What the listener hears | Chain | Who picks |
|---|---|---|---|
| none (about 1/3 of fakes; always at Nightmare) | indistinguishable from a real voice | `VoiceBase` | host, per lure (`apply_lure.tell`) |
| `echo` | a faint repeat | `VoiceEcho` | host |
| `pitch_up`, `pitch_down` | a slightly wrong pitch | `VoicePitchUp`, `VoicePitchDown` | host |
| `no_crackle` | the voice lacks the faint crackle every real proximity voice has | `VoiceBase` without the crackle layer | host |
| ghost static | heavy static, band-limited | `VoiceGhost*` | by voice owner dead (real ghosts and dead-voice fakes) |
| wrong place | it comes from where the teammate can't be | positional | host; always |

**Rules that keep it fair** (doc 01):
- At most one random tell per fake; a real voice never carries a tell. So `VoiceEcho` and the pitch
  buses are fed by fakes only, and the real voice path never touches them (doc 06 section 9).
- The ghost static chain is the same for a real ghost and a fake of the dead, so the tiebreaker is
  the lantern flicker, not the audio (doc 01 "The dead-voice twist").
- The chain must not make fakes cleaner, so lobby lines are stored and replayed as Opus-encoded
  clips (doc 06 section 9), and the crackle layer applies to them equally.

### 7.2 Voice bus levels and layer specs (all `placeholder`)

Numbers marked `doc 06` are Network & Voice's placeholders, kept as they wrote them.

| Item | Value | Notes |
|---|---|---|
| `Voice` bus | 0 dB | |
| `VoiceBase` | 0 dB, no effects | a real and "none" fake voice end up here |
| Proximity crackle layer (`vox_crackle_loop`) | -34 dB relative to the voice envelope (RMS), mono, a second `AudioStreamPlayer3D` on the same emitter | "faint": must not hurt the cozy day (Q-005 answer; D-011). The CEO listens for audibility **in silence between words** |
| Echo | delay 180 ms, level -18 dB, no feedback (`doc 06`) | |
| Pitch | x1.06 / x0.94 (`doc 06`) | pitch shift adds artefacts; they are the tell. The real path never uses it |
| Ghost static | band-pass 400 Hz to 3 kHz (`doc 06`), distortion drive 0.4, static (`vox_ghost_static_loop`) at -14 dB below the voice, gated by the voice envelope | heavy enough to disguise the speaker a little (doc 01 "Static voices") |
| Walkie (`VoiceRadio`) | band-pass 500 Hz to 2.8 kHz, crackle (`vox_radio_static_loop`) -20 dB, not attenuated by distance | |
| Walkie near creature | the same static raised from -inf at 30 m to -6 dB at 5 m, linear in dB (30 m is `doc 06`) | |
| Radio squelch | `vox_radio_squelch_on` (talk start), `vox_radio_squelch_off` (talk end) | holder only (D-011) |
| Low battery | `vox_radio_low_battery` beep, every 20 s once | |
| Dead battery | `vox_radio_dead` click | |

### 7.3 Voice-tell safeguards

- **Tell audibility is a design variable.** Echo -18 dB and the +/-6% pitch are the starting values.
  If a tester can't hear any tell after a session, raise them; if everyone hears every one, lower them
  (the target in doc 01: tells are a giveaway you can catch, with a third having none).
- **Hearing is not subtitled** (D-019): no voice name appears, so audio is the only tell besides the
  wrong place.
- **Off players** are never voiced by a stand-in (doc 01 "Habits"); their fakes are footstep and tool
  assets (section 7.5).
- **Spatial placement** goes through `VoiceEmitter` for voices and `sound_emitter.tscn` for everything
  else; neither knows about tells.

### 7.4 Generic ("stranger") lines (placeholder, synthetic only)

Doc 03 s16: `stranger_over_here`, `stranger_help`, `stranger_anyone`, `stranger_come`,
`stranger_lost`, `stranger_hello` (texts `placeholder`). Sound IDs are `vox_` + line id. They are used
for unattributed stranger calls and DD Phase 1 (doc 01 "Habits"; doc 03 s20).

- **Generation:** formant synthesis in SuperCollider (`Formlet` / `BPF` bank on a pulse source, vowel
  and consonant stages, a gentle pitch glide), 1 to 1.6 s, mono, high-passed and slightly reverbed.
  It will sound like a synthetic, not-quite-speech voice: that is the intended **placeholder
  quality**, and its intelligibility is poor (I cannot measure it). Not a real person, not a recording.
- **Option for the CEO** (section 16, Q-031): replace with offline text-to-speech output. Neither
  Windows' built-in voices nor any downloaded TTS enters the repo without the CEO's approval of
  source and license (D-005 spirit; agent brief).

### 7.5 Sound lures (no voice)

Doc 03 s16 sound IDs map to existing assets. A fake plays the same asset the real action does, in
the same bus and range class; a fake is only wrong by place.

| Lure `sound_id` | Plays | Cadence |
|---|---|---|
| `step_walk_fake` | `sfx_step_dirt_*` or `_corn_*` by the surface at the lure position | every 0.5 s, 6 to 10 steps |
| `step_run_fake` | the same at sprint gain | every 0.32 s |
| `hoe_fake` | `sfx_hoe_till_*` | 2 to 3 strikes, 1.2 s apart |
| `watering_can_fake` | `sfx_water_noisy` | one pour |
| `shovel_fake` | `sfx_shovel_dig_*` | 2 strikes |
| `door_fake` | `sfx_door_open_*` | one |

Pattern generation (cadence, picking variants) is in `game/audio/lure_sounds.gd`.

## 8. Player states: Taint, still, Shaken

| State | Sound | Rule |
|---|---|---|
| **Taint** (doc 01 "The Taint": "a faint wet heartbeat in your audio") | `sfx_taint_heartbeat` (exists, 70 bpm), non-positional, local only, `SFX`; -42 dB; `pitch_scale` follows Taint intensity (1.0 to 1.3; the 4-beat loop is an exact period) | everyone sees black hands; **only the tainted player hears the heartbeat** (it is "in your audio") |
| **Still** (doc 01 "Go still": "while your heartbeat rises") | `sfx_still_heartbeat_loop`, a dry close thump (timbre distinct from the wet Taint beat); `pitch_scale` 1.0 rising to 1.7 and volume -34 to -22 dB over the still time | local only. If Tainted and still, both play and the Taint beat ducks 8 dB |
| **Shaken** (doc 01 "Shaken": never Taints; doc 07 gives it no visual) | `sfx_shaken_ring`: a thin ~4 kHz ring decaying over 4 s, `Master` low-pass 6 kHz for the first 10 s of the 60 s | local only (inference: doc 01 gives it no cue; doc 07 leaves it to audio) |
| **Prying** (doc 01 "trap race") | `sfx_pry_strain` for the hold; rising pitch near completion | gives the player feedback for the race |
| **Carrying a teammate** | slow heavy footsteps (`sfx_step_dirt` at -3 dB, pitch 0.85) + `sfx_cloth_carry` | "slowly and noisily" (doc 01) |

## 9. Dusk bell, generator, whistle

### 9.1 Church bell (doc 01 "Core Loop > Dusk")

`amb_church_bell_x3`: three strikes about 7 s apart (total ~24 s with the tail), mono, `placeholder`
generation: additive inharmonic partials (ratios 0.5, 1, 1.19, 1.56, 2, 2.74, 3, 4.07) with
individual decays (4 to 11 s), a strike transient (a short filtered noise click), and the hum tone at
~210 Hz. The marker is at (400, -5), beyond the town end of the road (doc 04 s4: "doc 08 owns the
sound"), 400 m from the farm. Godot's attenuation curve can't hold a 400 m sound audible without a
huge `unit_size`, so I set `unit_size` 80 and `max_distance` 700 and, if it is still too quiet at the
barn, fall back to a non-positional stereo bell with a 4 kHz low-pass (`placeholder`; the bell
doesn't need to be placed). It plays at the start of dusk, as the "one introduction" of dusk (doc 01
"Onboarding"). **It rings in every phase transition to dusk, including from inside buildings, and is
not a creature tell.** It is not a `NoiseBus` kind: the creature does not hear it.

### 9.2 Generator (doc 01 "Nights"; doc 07 s4.1)

- **Run:** `sfx_generator_loop`, a low engine hum with a 2-stroke thump, loop 2 s exact. Pitch follows
  `fuel_fraction`: `pitch_scale` 1.0 at full fuel falling smoothly to 0.82 at 0%, slew-limited, with
  no random jitter. **It never sputters, stutters or pulses as it runs low** ("dims steadily, never
  flickers": the audio twin; also so that nothing audio-side mimics the ghost flicker).
- **Start / refuel:** `sfx_generator_start` (pull-cord, two failed catches, runs). `sfx_refuel_glug`
  for the pour (hold ~4 s, doc 02), `sfx_fuel_can_slosh` carrying a can.
- **Dies:** `sfx_generator_die` (spin-down, a final heavy clank, then silence). It "carries across
  the farm" (doc 01): max distance 160 m. The lights fade over 0.6 s (doc 07 s4.2), the sound matches.
  It is the same pitch curve with no sputter, so it's not mistaken for a ghost flicker.
- **Dead generator** emits `generator_dead` Noise at 80 m for the creature (doc 03 s3.1): audio and
  Noise agree.

### 9.3 Whistle (doc 01 "Whistle"; Q-014 item 4)

- **Range:** audible to at least 171 m, the farm's longest distance (doc 04 s8.2), so `max_distance`
  is **220 m** and `unit_size` 20 m (`placeholder`). Q-014 item 4 answered. The creature hears it at
  50 m (doc 03 s3.1, `whistle`): the whistle is audible far beyond what the creature hears, which is
  the "carries far" reading (inference).
- **Sound:** `sfx_whistle`, ~1.1 s: a bright tone around 2.6 to 3.4 kHz with a fast rising chirp
  onset (80 ms) and breathy noise, vibrato 6 Hz. A broadband attack and a rising chirp make a sound
  easier to place than a pure tone (inference from how sound localisation uses onsets; the DD
  Phase 1 spatial test at 10, 30 and 60 m settles it). Wind doesn't mask it: it sits above the wind
  band.
- **No HUD marker.** Placement is by 3D audio only (doc 01); the fallback (lantern or hat flash) is
  Gameplay's/Art's if testing fails.
- **Emitter** is `sound_emitter.tscn`, swappable like `VoiceEmitter` (doc 06 section 8).
- **Unfakeable:** the creature has no path to `sfx_whistle`; `Soundscape` refuses it from a lure
  (host-validated `apply_lure.sound_id` list excludes it).

## 10. Runtime API (`Soundscape`)

Owner: Audio Designer, `game/audio/`. A new autoload `Soundscape` (`game/audio/soundscape.gd`); the
entry in `project.godot` is Gameplay's (CONTRACTS section 2), requested in Q-032. It runs on every
peer; **it never talks to the network** and only listens.

### 10.1 Inputs

| Call | From | Meaning |
|---|---|---|
| `set_creature_state(state: StringName, body: StringName)` | `Net` on `apply_creature_state` | layers (section 4.3), sting, signature |
| `set_phase(phase: StringName)` | `Clock` signal | `day`, `dusk`, `night`, `dawn`, `harvest_moon`; crossfades; bell at dusk |
| `set_creature_position(p: Vector3, speed: float)` | `Net` on `creature` | places the signature, scales its cadence |
| `play_3d(sound_id: StringName, position: Vector3, opts := {})` | any system | one-shot via `sound_emitter` with the sound's catalog entry |
| `play_2d(sound_id: StringName, opts := {})` | UI, local | non-positional |
| `set_local_state(tainted: bool, still: bool, shaken: bool, fuel_fraction: float)` | `Player`, `Generator` | heartbeat, ring, hum pitch |
| `set_building(lit: bool, inside: bool)` | `LightRig`, player | `Indoor` filter |

### 10.2 Events from other systems

Footstep, tool, door, trap and whistle sounds are played **locally on each client when the host's
`apply_*` result arrives**, never before the host validates (CONTRACTS section 5). The player's own
immediate feedback (a tool swing sound) may play on request and is cancelled by a refusal
(`apply_refused`, D-018) (inference).

### 10.3 Catalog

**P1-10 status (as built):** the emitter is a script, `game/audio/sound_emitter.gd` (`SoundEmitter`,
`AudioStreamPlayer3D`, doppler off, inverse distance), not a scene. The catalog is a `CATALOG` const in
`game/audio/soundscape.gd`, not JSON (a JSON file and `check_catalog.py` come when the list grows past
Phase 1). Built: four ambience loops, the dusk/night crossfade, stalk/chase/retreat/lurk fades, footsteps
(derived from replicated player positions), trap sounds (on `trap_changed` sprung), stranger lines (on
`lure`), `sfx_whistle` file. Not built: chase sting, bell, signatures, generator hum, heartbeat wiring,
`set_local_state`, `set_building`. All P1-10 sounds are `placeholder`, unheard by the author.

`game/audio/sound_catalog.json` is one record per sound ID: bus, `positional`, range class (section
3.2), `volume_db` trim, variants, loop flag and the Noise `kind` it pairs with (documentation only;
`NoiseBus` is the host's). The section 11 list is its source and the first task is to generate the file
from it (kept in sync by `tools/audio/check_catalog.py`, DD Phase 1 task). Variants use
`AudioStreamRandomizer` (random pitch +/-5%, volume +/-2 dB, no immediate repeat).

### 10.4 Debug

`F3` debug view (doc 05 s19) is host-only by default, but clients are the ones who hear the drop.
So `Soundscape` also writes a log event `audio_state` (through `Log`, CONTRACTS s10) on every
creature-state change it applies and every 5 s while the state is not `lurk` (the baseline, doc 03 s4; there is no `roam` state, D-020): peer id, creature
state and body last received, the gain in dB of each `bed`/`wind` layer, and the last 8 sound IDs
played. A tester reports "the bed didn't drop" by quoting the client's `peer_<id>.jsonl`. The event
needs a line in doc 05's event list (Q-035). The F3 overlay shows the same numbers on the host.

## 11. Sound list

**Key.** `P` = DD Phase when needed (1 to 4, doc 01 "Build Plan"). `Bus`: Mu Music, S SFX, A
Ambience, C Creature, V Voice, U UI. `Dim`: 3D = mono placed in 3D; M = mono local; St = stereo
non-positional. `Len` = target length in seconds; `loop` = exact number of periods, tails die before
the end. **Every row is a placeholder, generated by `assets/audio/src/<id>.scd` (D-015).** Variants
`_01..NN` are separate sources with different seeds and pitches. Counts are `placeholder`.

Recipe abbreviations: `noise` = `WhiteNoise`/`PinkNoise`/`BrownNoise`, `BPF`/`LPF`/`HPF` filters,
`Env.perc` percussive envelope, `SinOsc`/`Saw` oscillators, `Klank` resonators, `FreeVerb` reverb,
`Dust` random impulses.

### 11.1 Ambience beds and animals

| ID | Bus | Dim | Len | Loop | P | Generated by |
|---|---|---|---|---|---|---|
| `amb_wind_loop` | A | St | 24 | yes | 1 | pink noise through two slowly swept BPFs (200 to 900 Hz, LFO 0.07 and 0.11 Hz), gusts by low-passed noise on amplitude; two uncorrelated channels |
| `amb_insect_bed_night` | A | St | 20 | yes | 1 | 20 cricket voices: `SinOsc` 4.2 to 5.4 kHz chirp trains (3 chirps, 0.25 s) with random phase; steady floor of high noise at -50 dB |
| `amb_corn_rustle_loop` | A | St | 18 | yes | 1 | brown + pink noise, BPF 500 to 4 kHz swept by random LFOs, grainy `Dust` leaves ticks; **no pulsing envelope** (section 6) |
| `sfx_corn_rustle_01..04` | S | 3D | 1 to 2 | no | 1 | the same recipe as a gust: swell + tail |
| `sfx_bird_01..04` | S | 3D | 0.4 to 1.2 | no | 1 | two-tone glides `SinOsc` 2.8 to 5 kHz with fast vibrato, tweet patterns |
| `sfx_bird_call_distant_01..02` | S | 3D | 1.5 | no | 1 | a lower, slower warble through `FreeVerb` + LPF (distance) |
| `sfx_crow_caw_01..03` | S | 3D | 0.5 to 0.9 | no | 3 | `Saw` 400 to 700 Hz with a falling glide, formant `BPF` 900 and 1800 Hz, noise |
| `sfx_crow_burst` | S | 3D | 1.2 | no | 3 | wing flaps (`LPF` noise bursts at 8 per s) + one caw (fake-out, doc 01 "Jumpscares") |
| `sfx_crow_flap` | S | 3D | 0.8 | no | 3 | takeoff, ghost possession, perch change |
| `sfx_animal_chicken_01..03` | S | 3D | 0.4 to 1 | no | 1 | cluck: pitched `Saw` 600 to 900 Hz with fast LFO + BPF 1.5 kHz |
| `sfx_animal_cow_01..02` | S | 3D | 2 | no | 1 | low moo: `Saw` 110 to 160 Hz with formant glide, noise breath |
| `sfx_animal_sheep_01..02` | S | 3D | 1.2 | no | 1 | bleat: pulse 300 Hz with fast vibrato 10 Hz and formant sweep |
| `sfx_animal_panic_01..03` | S | 3D | 1 | no | 3 | faster, higher variants of the above (broken fence, escape) |
| `sfx_rooster` | S | 3D | 2.5 | no | 1 | crowing glide, `Saw` 500 to 900 Hz + formants |
| `amb_bulb_hum_loop` | A | 3D | 2 | yes | 1 | 100 Hz (mains) + harmonics, tiny 1 kHz whine, steady; no flicker or stutter (section 9.2) |
| `amb_room_barn` | A | St | 12 | yes | 1 | very quiet low pink noise, subtle low-pass wood-creaks (`Dust` + `Klank`) |
| `amb_room_dark` | A | St | 12 | yes | 1 | low breath of air (brown noise, slow swells), sparse creaks |

Species are `inference`: doc 01 names no pen animals (Q-032 asks the Game Designer); the set above
is generic farm stock and changes without touching the list shape.

### 11.2 Movement and tools

| ID | Bus | Dim | Len | P | Generated by |
|---|---|---|---|---|---|
| `sfx_step_dirt_01..04` | S | 3D | 0.25 | 1 | LPF noise thump 100 to 400 Hz + grit (HPF `Dust`), per-variant pitch |
| `sfx_step_corn_01..04` | S | 3D | 0.35 | 1 | dirt thump + a brushing noise burst (BPF 1 to 3 kHz) from stalks |
| `sfx_step_wood_01..04` | S | 3D | 0.25 | 1 | knock `Klank` 150 to 320 Hz + creak sweep |
| `sfx_step_taint_wet_01..02` | S | M | 0.3 | 3 | LPF squelch (noise + falling sine 300 to 120 Hz) |
| `sfx_hoe_till_01..03` | S | 3D | 0.5 | 1 | dull thud + soil spray (noise decay) |
| `sfx_plant_seed_01..02` | S | 3D | 0.4 | 1 | small pat + rustle |
| `sfx_water_noisy` | S | 3D | 3.5 | 1 | water pour: BPF noise 1 to 5 kHz with bubbling `Dust`, rattling can chain; loud |
| `sfx_water_quiet` | S | 3D | 5.5 | 4 | the same softer, LPF 3 kHz, trickle |
| `sfx_harvest_pull_01..02` | S | 3D | 0.6 | 1 | root tearing: noise crackle + soil thud |
| `sfx_shovel_dig_01..02` | S | 3D | 0.7 | 1 | metal scrape (BPF 2 kHz noise) + dirt thud |
| `sfx_pry_strain` | S | 3D | 4.5 | 1 | rising metal creak: `Klank` resonators with rising pitch, groans |
| `sfx_disarm_click` | S | 3D | 0.4 | 1 | quiet metal ticks (`Klank` 2.6 kHz) |
| `sfx_repair_clank` | S | 3D | 0.6 | 4 | 2 hammer strikes: `Klank` 800/1500/2300 Hz |
| `sfx_well_pump_01..02` | S | 3D | 1.1 | 1 | one stroke: handle squeak (sine glide + BPF), water gush (noise), thump; stroke repeats ~10 s while washing |
| `sfx_wash_splash` | S | 3D | 1.2 | 3 | splash + run-off, plays at the end of the cure |
| `sfx_door_open_01..02`, `sfx_door_close_01..02` | S | 3D | 0.8 | 1 | creak sweep (sine + BPF), latch click, thud |
| `sfx_door_slam` | S | 3D | 0.9 | 3 | heavy bang with rattle (the shed scare) |
| `sfx_lantern_ignite` / `sfx_lantern_blow_out` | S | 3D | 0.6 | 2 | match flare hiss / breath and glass tick (the barn staging, doc 01 "Recording lines") |
| `sfx_flag_plant` | S | 3D | 0.5 | 3 | soft thud + cloth flap |
| `sfx_cloth_carry`, `sfx_emote_cloth` | S | 3D | 0.7 | 3 | cloth rustle |
| `sfx_ragdoll_thud_01..03` | S | 3D | 0.5 | 3 | body fall: low sine drop + noise + rattle of dropped items |
| `sfx_items_drop` | S | 3D | 0.6 | 2 | scatter of tools/produce: several pitched ticks |
| `sfx_fuel_can_slosh` | S | 3D | 1 | 1 | liquid slosh + can clunk |
| `sfx_refuel_glug` | S | 3D | 4 | 1 | glug rhythm: bubbles 3 per s, rising pitch as it fills |
| `sfx_fence_break_01..02` | S | 3D | 1.2 | 2 | wood snap + splinters |
| `sfx_cart_squeak_loop` | S | 3D | 3 | 4 | wheel squeak: 650 Hz sine with chirp + chassis rattle; loops, rate follows pusher speed (doc 01) |
| `sfx_pegboard_board_loose` | S | 3D | 0.8 | 2 | wood groan + pop ("pried a board loose") |
| `sfx_lock_break` | S | 3D | 0.6 | 3 | metal snap |
| `ui_coins` | U | M | 0.5 | 1 | `Klank` coin ticks 3 to 5 kHz cascade |
| `sfx_flare_shot` | S | 3D | 1.2 | 4 | bang (noise decay) + whoosh |
| `sfx_flare_hiss_loop` | S | 3D | 2 | 4 | hiss: HPF noise, steady |


### 11.3 Traps and farm hazards

| ID | Bus | Dim | Len | P | Generated by |
|---|---|---|---|---|---|
| `sfx_beartrap_snap` | S | 3D | 0.7 | 1 | metal jaw slam (`Klank` + noise burst), bone-less crack |
| `sfx_beartrap_open` | S | 3D | 1 | 1 | spring release grind |
| `sfx_pit_fall` | S | 3D | 0.9 | 1 | stalk crunch + soil slide + thud |
| `sfx_tripwire_bells` | S | 3D | 2.8 | 4 | 5 rusty small bells: `Klank` detuned 1.1 to 3.4 kHz, random strikes, clangy tails (not church-like) |
| `sfx_tripwire_cut` | S | 3D | 0.3 | 4 | snip + string twang |

### 11.4 Creature

| ID | Bus | Dim | Len | Loop | P | Generated by |
|---|---|---|---|---|---|---|
| `cre_gaunt_sig_01..03` | C | 3D | 1.5 to 2 | no | 1 | section 6 gaunt: dry clicks, irregular |
| `cre_gaunt_sig_chase` | C | 3D | 4 | yes | 1 | fast clicks 6 to 14 per s |
| `cre_scarecrow_sig_01..03` | C | 3D | 1.5 to 2 | no | 1 | cloth flaps |
| `cre_scarecrow_sig_chase` | C | 3D | 4 | yes | 1 | 2.4 flaps per s, the stride rate |
| `cre_boar_sig_01..03` | C | 3D | 1.5 to 2 | no | 1 | chain drag + hoof |
| `cre_boar_sig_chase` | C | 3D | 4 | yes | 1 | chain clatter + thud per stride |
| `cre_husk_sig_01..03` | C | 3D | 1.5 to 2 | no | 1 | dry pulsed rattle |
| `cre_husk_sig_chase` | C | 3D | 4 | yes | 1 | pulses 14 to 22 per s |
| `mus_sting_chase` | Mu | St | 3.2 | no | 1 | stacked saws detuned a semitone and tritone (cluster), reversed-swell riser, sub-hit at 0.15 s, short `FreeVerb`; stops dead after 2 s with a tail |
| `cre_jumpscare_hit` | C | M | 1.6 | no | 3 | noise burst + 50 Hz boom + falling screech glide 3 kHz to 400 Hz |
| `cre_lunge` | C | M | 0.9 | no | 1 | fast whoosh (noise filter sweep up) + low thump |
| `cre_corn_part_01..03` | C | 3D | 1 | no | 1 | heavy stalks breaking: loud noise swell + wooden cracks |
| `cre_presence_swell` | C | M | 6 | no | 3 | very low (40 to 70 Hz) swell and a thin high partial; the private "something's there" |
| `cre_door_bang_01..03` | C | 3D | 0.9 | no | 1 | heavy thump with wood rattle |
| `cre_gnaw` | C | 3D | 2.5 | no | 3 | wet crunch bursts |
| `cre_trap_set_01..02` | C | 3D | 1.2 | no | 1 | scrape of dirt + metal click-clack |
| `cre_flare_hit` | C | 3D | 1.2 | no | 4 | a falling shriek + stomp |

### 11.5 Player states and UI

| ID | Bus | Dim | Len | Loop | P | Generated by |
|---|---|---|---|---|---|---|
| `sfx_taint_heartbeat` | S | M | 3.43 | yes | 1 | **exists** (`assets/audio/src/sfx_taint_heartbeat.scd`): wet low double thump, 70 bpm x 4 beats |
| `sfx_still_heartbeat_loop` | S | M | 3 | yes | 1 | dry close "tum-tum" at 60 bpm x 3, a tighter attack than Taint's |
| `sfx_shaken_ring` | S | M | 4 | no | 3 | 4 kHz sine with slow decay + faint 8 kHz overtone |
| `ui_click`, `ui_confirm`, `ui_deny` | U | M | 0.1 to 0.35 | no | 1 | short wood tick, up-chirp, down-chirp (sine) |
| `ui_paper_slide`, `ui_paper_rustle` | U | St | 0.8 | no | 3 | filtered noise swell / crinkle (`Dust` + BPF) (Dawn Report) |
| `ui_stamp` | U | M | 0.4 | no | 3 | stamp thump + paper |
| `ui_rec_start`, `ui_rec_stop` | U | M | 0.25 | no | 2 | soft two-tone tally ticks (the recording light's audio, doc 01 "Recording light") |

There is no Phase 1 score: doc 01 mentions only the chase sting (inference, see Q-032).

### 11.6 Voice layers and placeholder lines

| ID | Bus | Dim | Len | Loop | P | Generated by |
|---|---|---|---|---|---|---|
| `vox_stranger_over_here`, `_help`, `_anyone`, `_come`, `_lost`, `_hello` | V | 3D | 0.8 to 1.6 | no | 1 | formant synthesis (section 7.4); **synthetic, never a person** |
| `vox_crackle_loop` | V | 3D | 4 | yes | 2 | `Dust` clicks at 6 to 20 per s through BPF 1.5 to 4 kHz, lightly crushed |
| `vox_ghost_static_loop` | V | 3D | 4 | yes | 3 | white noise through BPF 400 Hz to 3 kHz, bit-crush, amplitude flutter |
| `vox_radio_static_loop` | V | M | 4 | yes | 4 | narrow-band noise + hiss + the crackle at louder density |
| `vox_radio_squelch_on` / `_off` | V | M | 0.2 | no | 4 | noise burst + chirp / reversed |
| `vox_radio_low_battery`, `vox_radio_dead` | V | M | 0.6 / 0.2 | no | 4 | 2 beeps / click |
| `vox_emote_scream` | V | 3D | 1.5 | no | 3 | formant-synth scream (a rising `Saw` 600 to 1100 Hz with strong formants), a placeholder for the "scream" emote (doc 05 s16); it emits a Noise of 60 m (doc 05) |

### 11.7 Counts

About 150 files and about 90 for Phase 1 are inference, not counts: the tables hold about 90 sound IDs (counted by ID prefix, ignoring settings tables) and variants multiply that. `tools/audio/check_catalog.py` (DD Phase 1) will print the real numbers and replace this line. The DD Phase 1 set (P = 1) is about 90 files (beds, steps, tools used in turnips,
the well, the generator, the bell, the whistle, traps, pits, signatures x 4, sting, strangers).
Bodies: only the chosen one is loaded per season.

## 12. How sounds are generated and checked

### 12.1 Pipeline (D-015)

1. Write `assets/audio/src/<sound_id>.scd` (format: top of `tools/audio/render_nrt.scd`; worked
   example `sfx_taint_heartbeat.scd`).
2. `uv run tools/audio/render.py <ids> --spectrogram` writes `assets/audio/<id>.wav` (48 kHz,
   16-bit, peak -1 dBFS), fails on silence, clipping or SC errors.
3. Commit the source and WAV together. Don't commit a re-render of an unchanged source (noise
   sources aren't bit-identical, `tools/audio/README.md`).
4. Variants: one `.scd` per variant with a seed `RandSeed` and a pitch offset, or a generator script
   `tools/audio/gen_variants.py` that writes the `.scd` files from a template (kept simple).
5. The loop WAV files get `loop_mode = forward` in their `.import` files (Godot import setting; the
   `.import` file is committed).

### 12.2 Loops

- A loop is an exact number of periods long; tails die before the end. Beds made of noise:
  stationary noise at constant level loops without an audible seam; scheduled voices (chirps,
  cricket trains) never cross the end. Where a bed has slow level changes, the changes complete a
  whole number of cycles in the file length (LFO periods divide the duration).
- Check: first and last 20 ms RMS within 1 dB, no click (spectrogram column at the loop point has no
  vertical line).

### 12.3 Checks without hearing

Measured, then listened to by the CEO:

| Check | How |
|---|---|
| Length, peak, RMS | `render.py` report |
| Band | spectrogram: energy where the recipe says (clicks 1.8 to 3.4 kHz, wind below 1.5 kHz, bell hum at 210 Hz) |
| Tails | spectrogram: the last 100 ms is dark |
| Husk vs corn rustle | the husk's envelope has a 14 to 22 Hz periodicity; corn rustle has none (compute envelope FFT in `tools/audio/`, DD Phase 1 task) |
| Loops | start and end RMS within 1 dB |
| Voice crackle faintness | -34 dB below voice RMS is a computed ratio in the mix test |

### 12.4 Source order

DD Phase 1 first, in this order: beds and wind (the three ambience layers), four signatures + sting,
steps, tools in the turnip loop + well + generator, traps and pits, whistle + bell, stranger lines.
Then each phase's rows by `P`. When the CEO provides real sound, it goes in `assets/audio/` under the
same IDs (CEO-approved files only).

## 13. Sources and licenses

All sounds are generated by code in this repo, with SuperCollider 3.14.1 (GPL-3.0 tool, output not
affected) and SoX 14.4.2 (tool only); both are CEO-approved in D-015. No downloaded audio or voice
pack is used. Listed here for approval before use (none are being used):

| Candidate | Source | License | Status |
|---|---|---|---|
| Real voice lines for strangers | CEO or a consented person | n/a | not used; synthetic only |
| TTS for stranger lines | OS built-in or offline TTS | to be checked | **not used; FOR CEO (Q-031)** |
| Music | none | n/a | no day music or score, ever (CEO, Phase 1 playtest); only the chase sting |

## 14. Listening list for the CEO

Everything is generated; I cannot hear any of it, so each new sound is for you to listen to. The doc
alone adds none; the first render batch (DD Phase 1 task) will ask you to listen, in this order,
because these carry the game:

1. The Stalk drop (bed and wind cut) and Retreat return: **is it noticeable without being told?**
2. The four signatures back to back, then the husk against corn rustle.
3. The chase sting after a silent Stalk.
4. The proximity crackle: faint enough for the cozy day, present enough to miss when absent?
5. Echo and pitch tells; ghost static intelligibility.
6. The whistle at 10, 30, 60 m and the church bell at the barn.
7. The generator spin-down and low-fuel pitch drop (no sputter).
8. The stranger lines: are they scary, or silly? Decide Q-031.

## 15. Gotchas

- **Don't duck the Ambience bus for Stalk**; duck layers. Crows and livestock are on `SFX` so the
  drop doesn't take them down. A bus-level duck would make every animal vanish and violate doc 01.
- **A lost state message leaves the farm silent**; the failsafe timer in section 4.3 is required.
- **Doppler off.** It would pitch-bend a fast creature and the wrong-pitch tell.
- **`AudioEffectPitchShift` is a tell by itself** (artefacts): never put a real voice through it.
- **Late join with a Stalk in progress** must start at the dropped state with no fade.
- **WAV loop flags** are an import setting; a loop WAV without `loop_mode` plays once and the bed
  falls silent: indistinguishable from a Stalk. Test every loop in the smoke run (QA).
- **Looping noise sources aren't bit-identical** across renders (README), so don't diff WAVs.
- **No stereo in 3D.** A stereo file placed in `AudioStreamPlayer3D` is downmixed; keep placed
  sounds mono.
- **The generator hum must never pulse** or it will read as a flicker.
- **Local player's own footsteps** are non-positional; the host's Noise comes from `move` frames
  (doc 05 s6), not from any played sound, so muting audio never hides you from the creature.
- **Spatial gate.** If the DD Phase 1 test fails at 60 m, the whistle and voice emitters change
  together (one scene each); don't branch inside call sites.

## 16. Questions raised

Appended to `production/QUESTIONS.md`.

- **Q-031 (FOR CEO):** generic stranger lines: formant-synthesis placeholders (low intelligibility), or
  approve offline TTS (name and license)? (Day music: answered, no; CEO called it atrocious at the Phase 1 playtest.)
- **Q-032:** autoload `Soundscape` in `project.godot` (Gameplay); pen animal species (Game
  Designer); Stalk scope (global vs near) as a playtest switch (Director note).
