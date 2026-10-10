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
5. **Pause menu** low-passes `Master` at 1.2 kHz and drops `SFX` by 10 dB with a 0.3 s fade;
   `Ambience` is not touched, so the bed and wind keep playing at their current gains under the
   low-pass (section 4.4 rule 2). **Dawn Report (D-074, Q-072, P4-17):** a 1.2 kHz low-pass on
   `Ambience` and `SFX` only (the `Report` effects in `default_bus_layout.tres`, off until
   `Soundscape.set_report_open(true)`); `Voice`, `Creature` and `UI` stay clear, so the replayed
   clips and the paper card sound normal. No fade or SFX drop (inference: a bare cutoff is the
   smallest build; the CEO listen settles it). The Dawn Report has no music.
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
| Taint heartbeat | -20 (was -32; CEO listens 2 and 3 doubled it twice) | "faint" (doc 01), local only |

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
- **Every step varies** (P4-26, CEO: the old steps sounded synthetic and repetitive): a random one of 6
  variants, never the one just played, at pitch 0.9 to 1.1 and level -2.5 to +1 dB. The surface comes from
  the step position: inside a building footprint is `wood`, inside a corn area is `corn`, else `dirt`.
  The sprint level counts from the midpoint of walk and sprint speed (`data/labor.json`). Sound only:
  the host's Noise is unchanged.
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
| Wind | `wind` | `amb_wind_loop` (stereo), played at pitch 0.5 (CEO listen 3: half the frequency) | -29.1 dB | -26.1 | -23.1 (CEO listen 3: 30 percent quieter, -3.1 dB, from -26 and -20) |
| Bed, insects | `bed` | `amb_insect_bed_night` (stereo loop) | off (no day insect bed) | in over 45 s | -30.8 (CEO: -28, halved after the 2026-10-08 playtest; -2.8 dB in P4-26 to match the re-rendered, evener bed's RMS -16.3 dBFS to the -19.1 the CEO approved) |
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
- **Idea, not decided** (CEO, 2026-10-08): when the creature goes for the kill, a heartbeat sound effect
  might warn the target. It needs a new sound, because `sfx_taint_heartbeat` and
  `sfx_still_heartbeat_loop` already mean Taint and Still. Tracks playtest issue 8 in
  `production/OPEN_ISSUES.md`.

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

1. Only `Soundscape.set_creature_state()` and the scare build-up `Soundscape.hush(seconds)`
   (P3-08, answer to Q-059) may change the gains of layers tagged `bed` or `wind` downward by more
   than 6 dB. `hush` is the creature's own silence before a scare (doc 03 s13.1), on the target's
   peer only, so it is still the creature's tell, not noise from another system. This rule is about layer gains. The `Ambience` bus changes for a
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
| Day jumpscare | `cre_jumpscare_hit` | plays on `Creature`; the body thud and the running steps are inside the file, so no separate `sfx_ragdoll_thud_*` call. Per body (P4-17): `cre_jumpscare_hit_<body>` for gaunt, scarecrow, boar, husk; the old name is the fallback |
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
- The chain must not make fakes cleaner, so live clips are kept and replayed as the Opus packets the
  speaker transmitted (doc 06 sections 9 and 11, D-146), and the crackle layer applies to them equally.

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
| **Taint** (doc 01 "The Taint": "a faint wet heartbeat in your audio") | `sfx_taint_heartbeat` (exists, 70 bpm), non-positional, local only, `SFX`; -20 dB (`TAINT_DB`; was -32, then -26 at listen 2); `pitch_scale` follows Taint intensity (1.0 to 1.3; the 4-beat loop is an exact period). As built (P3-08): Taint is on/off, so the pitch stays 1.0; the beat ducks 8 dB while the chase heartbeat (10.5) plays | everyone sees black hands; **only the tainted player hears the heartbeat** (it is "in your audio") |
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

### 10.5 Phase 2 as built (P2-08)

All `placeholder`, rendered by `assets/audio/src/<id>.scd`, unheard by the author. Measured with `render.py`
(peak -1 dBFS for all; RMS dBFS in brackets): `mus_sting_chase` 3.2 s stereo (-17.7), `cre_gaunt_sig_chase`
(-28.0), `cre_scarecrow_sig_chase` (-21.7), `cre_boar_sig_chase` (-18.3), `cre_husk_sig_chase` (-19.3), each
4.0 s mono loop whose tail is dark before the seam (husk: continuous pulses, envelope peak at 18 Hz,
checked by FFT of the 400 Hz envelope); `sfx_still_heartbeat_loop` 3.0 s (-21.2); `vox_crackle_loop` 4.0 s,
faded at both ends; `amb_barn_lobby_loop` 8.0 s stereo, first/last 20 ms within 1 dB; `sfx_lantern_blow_out`
0.8 s; `cre_door_bang_01` 1.0 s.

- **Chase (Q-048 (2)).** `Soundscape.set_creature_state(chase)` on every peer: `mus_sting_chase` once
  (`Music`, non-positional, -6 dB; not on a late-join snap), `cre_<body>_sig_chase` as a looping
  `SoundEmitter` child of the creature node (`Creature` bus, -6 dB, unit 8 m, max 90 m), both stopped
  when the state leaves `chase` (and by the 45 s failsafe). The bed and wind drop is unchanged (4.3). Log
  event `audio_chase_cue {body}` on entry. Levels are by ear later (CEO).
- **Kill-warning heartbeat (trial, OPEN_ISSUES playtest 8).** While in `chase`, local only: `sfx_still_heartbeat_loop`
  on `SFX`, -34 to -22 dB and pitch 1.0 to 1.5 over 8 s. `CHASE_HEARTBEAT` in `soundscape.gd` switches it off.
  Inference: it warns a player who has not yet seen the creature; a playtest settles whether it helps or spoils.
- **Barn bed.** `amb_barn_lobby_loop` fades in over 2 s (-34 dB) while `Game.in_lobby`, over the wind. No day music, no score (CEO, Phase 1 playtest).
- **Recording staging** is gone with the barn recording (D-146, P4-37). `sfx_lantern_blow_out` and
  `cre_door_bang_01` stay in the `Soundscape` catalog for `play_3d`.
- **Clip tells (`game/audio/voice_chain.gd`, `VoiceChain`).** `bus_for(tell)` creates (idempotently, under
  `Voice`) `VoiceBase`, `VoiceEcho` (`AudioEffectDelay` 180 ms, -18 dB, one tap, no feedback),
  `VoicePitchUp` / `VoicePitchDown` (`AudioEffectPitchShift` 1.06 / 0.94) and returns the bus for `none`,
  `echo`, `pitch_up`, `pitch_down`, `no_crackle`. `attach_crackle(player, tell, bus)` adds `vox_crackle_loop`
  at -40 dB (fixed level, a stand-in for -34 dB under the voice envelope) as a child, 3D if the player is
  3D, and adds nothing for `no_crackle`. `play_clip(owner, clip_id, tell)` wraps `Voice.clips.play`. The
  levels live in the script constants (doc 06 s9 wanted `mix_levels.gd`; this file is it). Real voices never
  call it. Ghost-static buses are not built (Phase 3).
- **Not done:** non-chase signatures (`_01..03`), generator, bell and other Phase 1 gaps in 10.3; hearing the
  tells (they exist as buses with effects, listened to by no one).

### 10.6 Phase 3 as built (P3-08)

All `placeholder`, rendered by `assets/audio/src/<id>.scd`, unheard by the author. Measured with `render.py`
(48 kHz, 16-bit, peak -1 dBFS; length, RMS dBFS; every tail below -90 dBFS in its last 30 ms). Mono unless
marked. Rows tagged **(real)** are Freesound CC0 recordings since D-066 (section 13), processed by
`tools/audio/process_downloads.py`; their `.scd` sources are superseded. The others are still generated.

| File | Length | RMS | What |
|---|---|---|---|
| `sfx_taint_heartbeat` (changed twice) | 3.43 s loop | -19.0 | 70 bpm lub-dub, wet: a resonant low-pass squelch on each thump, low-passed 900 Hz, a stronger knock (CEO listen 1: more body above 100 Hz so small speakers carry it; played at -42, then -32, -26 and now -20 dB) |
| `cre_jumpscare_hit` **(real running; scare and thud PLACEHOLDER)** | 3.15 s | -9.4 | CEO listen 4 pick (option 03): 0.3 s silence, then a kea and bat scream (0.3 to 0.95 s, the loudest part), a soft body fall at 0.92 s, then 13 running steps on grass that fade and close up (lowpass) to 3.1 s (section 13). The running is approved; **superseded by the four `cre_jumpscare_hit_<body>` files (section 10.7); this stays as the fallback**. The thud is part of this file now. Played at -8 dB (unchanged) |
| `cre_lunge` **(real)** | 0.89 s | -13.9 | corn walk + body thud (section 13), liked at listen 3; played at -4 dB |
| `cre_presence_swell` **(real)** | 5.69 s | -16.6 | CEO listen 4 pick (option B): a sleeping dog's slow heavy breathing, played at 0.85x so it reads bigger, high-pass 40 Hz and low-pass 1.8 kHz, loud breaths ducked so the breaths are even (section 13); peak -2.3 dBFS; played at -8 dB |
| `cre_corn_part_01`, `_02` (redone) | 1.00 s | -10.2, -10.2 | CEO listen 1: dense leaf and husk crackle, shoulder push, green-wood snaps (no ringing resonators); played at -12 dB (was -6) |
| `sfx_ragdoll_thud_01`, `_02` (redone) | 0.70 s | -14.8, -14.4 | CEO listen 1: heavier: saturated sub drop, flesh slap, dirt grains, dull rattles instead of bright ticks |
| `sfx_door_slam` **(real)** | 2.00 s | -14.0 | CEO listen 3: a hard thump on the wall, then a heavy wooden door kicked shut with rattle and a sharp slam transient (section 13); 5 dB louder than the generated -19.0 for the startle; played at -2 dB |
| `sfx_crow_caw_01`, `_02`, `_03` **(real)** | 0.51, 0.30, 0.45 s | -16.2 each | CEO listen 3: close, clean American crow and rook caws, gaps gated, no ambience (section 13); played at -5 dB |
| `sfx_crow_burst` **(real)** | 1.21 s | -18.0 | two startled caws and wing beats (section 13), liked at listen 3; played at +0.4 dB (listen 3: x1.4 amplitude, +2.9 dB from -2.5) |
| `vox_emote_scream` **(real)** | 2.46 s | -16.4 | one whole scream with its own natural fall-off (the earlier cut ended it abruptly: "mechanical" at listen 3); kept by D-067; played at -1 dB |
| `sfx_emote_cloth` | 0.70 s | -24.5 | cloth rustle under wave, point and shrug (P3-11) |
| `ui_paper_slide` **(real)** | 0.48 s | -20.8 | CEO listen 4 pick (option C): one sheet scritching across wood, 0.6-10 kHz, no room (section 13); played at -10.4 dB |

- **Taint heartbeat (Q-060).** `Soundscape` polls `Game.players[local].tainted` every frame; no
  `set_local_state` call from `Player` is needed. While Tainted and alive it loops `sfx_taint_heartbeat`
  (non-positional, `SFX`, -20 dB), local only. Log `audio_taint_heartbeat {on}`.
- **Scares (P3-05 wiring in `game/ai_director/scares.gd`, AI Programmer).** Build-up: `hush(seconds)`
  (section 4.4 rule 1), plus `cre_door_bang` for the shed. Jumpscare: `cre_jumpscare_hit` (2D; the body
  thud is inside the file). Disarm lunge: `cre_corn_part` twice, then `cre_lunge`. Shed: `sfx_door_slam`.
  Wrong count and hallucination: `cre_presence_swell`. Fake-out: `sfx_crow_burst` at the perch. The
  build-up has no cue beyond the silence (doc 03 s13.1). "The trap" scare is not built, so it has no sound.
- **Emotes.** `sfx_emote_cloth` on `apply_emote` for every emote but the scream; the scream plays
  `vox_emote_scream` (from `whistle_emotes.gd`).
- **Dawn Report.** `ui_paper_slide` when the card shows (`dawn_report_shown` log line, so the host hears
  it too). The Dawn Report low-pass is built in P4-17 (section 10.7).
- **Logs.** `audio_play {id}` for every `play_3d`/`play_2d` (footsteps excepted), `audio_hush {seconds}`,
  `audio_taint_heartbeat {on}`.
- **Not done:** `ui_paper_rustle`, `sfx_crow_flap`, a third corn part and ragdoll thud, Taint pitch.

### 10.7 Phase 4 as built (P4-17)

All 39 files are new, generated (D-015, no downloads, no music), `placeholder`, unheard by the author, rendered
from `assets/audio/src/<id>.scd`; the sources are written by `tools/audio/gen_p4.py` (section 12.1 item 4).
Mono, 48 kHz, 16-bit, peak -1.0 dBFS. Callers belong to P4-06, P4-08, P4-14, P4-15 and the Creature owner;
the catalog rows carry the trims. `unit`/`max` for the new 3D rows are inference (like the P3 rows).

| File | Length | RMS | What |
|---|---|---|---|
| `cre_gaunt_sig_01..03` | 1.75 s | -36.1, -35.7, -33.3 | sparse dry clicks with a 220 Hz knock, gaps 0.3-0.6, 0.4-0.8, 0.25-0.5 s (section 6); played at 0 dB (quiet files) |
| `cre_scarecrow_sig_01..03` | 1.75 s | -25.2, -25.4, -25.8 | slow heavy coat flaps, 90 to 140 Hz body, gaps 0.45 to 0.9 s; -6 dB |
| `cre_boar_sig_01..03` | 1.75 s | -20.6, -21.5, -21.3 | two chain drags (ring partials, scrape) with a 60 to 90 Hz hoof thud, about 0.75 to 0.9 s apart; -9 dB |
| `cre_husk_sig_01..03` | 1.75 s | -20.3, -20.9, -19.3 | three 0.55 s bursts of the pulsed rattle at 18, 15 and 21 Hz (inside 14 to 22 Hz), 4 to 7 kHz pods over a hollow 800 Hz; the spectrogram shows the 55 ms pulse comb at 18 Hz; -9 dB |
| `sfx_cart_squeak_loop` | 3.0 s loop | -10.8 | festival cart wheel: 600 to 720 Hz squeak, rattle and clunk, four 0.75 s cycles, quiet seam; -14 dB; the game pitches it with the pushers |
| `cre_gnaw` | 2.5 s | -15.9 | four groups of wet crunches (crack, wet, thump); -8 dB |
| `sfx_flare_shot` | 1.2 s | -17.3 | flat bang, 45 to 110 Hz boom, rising whoosh; -4 dB, `unit` 20 and `max` 220 (the loudest noise on the farm) |
| `sfx_flare_hiss_loop` | 2.0 s loop | -14.3 | stationary bright hiss with sparse pops; -12 dB |
| `cre_flare_hit` | 1.2 s | -16.8 | synthetic falling shriek (2.2 kHz to 350 Hz) and a stomp at 0.75 s; not a voice; -6 dB |
| `vox_radio_squelch_on`, `_off`, `_dead` | 0.2 s each | -19.2, -22.0, -20.4 | key-up chirp, key-down chirp with a noise tail, a dying click and tone; -10 dB |
| `vox_radio_low_battery` | 0.6 s | -9.8 | two 1.2 kHz beeps; -18 dB |
| `vox_radio_static_loop` | 4.0 s loop | -20.7 | 300 to 3400 Hz band noise with crackle; -22 dB, level follows proximity (caller) |
| `sfx_animal_chicken_01..03` | 0.7, 0.5, 0.9 s | -16.3, -18.0, -16.2 | cluck groups (Saw through a 1.4 kHz band-pass); -8 dB |
| `sfx_animal_pig_01..02` | 1.0 s | -18.8, -17.4 | two oink grunts through 450 and 1100 Hz formants; -8 dB |
| `sfx_animal_cow_01..02` | 2.0 s | -15.3, -14.8 | low moo with a formant glide; -8 dB |
| `sfx_animal_panic_01..03` | 1.0 s | -15.6, -13.6, -14.4 | chicken squawks, pig squeal, cow bellow (one each, not variants); -6 dB |
| `ui_click` | 0.1 s | -22.2 | wood tick; -8 dB |
| `ui_confirm` | 0.25 s | -11.1 | soft up-chirp; -14 dB |
| `ui_deny` | 0.35 s | -7.6 | two low down-chirps; -16 dB |
| `ui_coins` | 0.5 s | -25.2 | five coin ticks; -4 dB |
| `ui_stamp` | 0.4 s | -15.6 | rubber stamp on paper; -10 dB |
| `ui_award_reveal` | 1.0 s | -20.1 | stamp then one bell tick, no melody; -8 dB |
| `ui_shop_bell` | 0.9 s | -26.3 | town-stand door bell, two strikes; -4 dB |

- **Animals are the weakest guess.** Synthetic chicken, pig and cow voices will not sound like animals. If the CEO
  rejects them at listen 1, D-066 allows CC0 downloads (log each in section 13). The pig replaces the doc's
  sheep (P4-08 spawns chicken, pig, cow).
- **Dawn Report low-pass (D-074, Q-072).** `Report` low-pass effects (1.2 kHz) on `SFX` (slot 0) and `Ambience`
  (slot 1), disabled by default. `Soundscape.set_report_open(on)` toggles them; it turns on at the
  `dawn_report_shown` log line and off when the card's `_open` flag clears (polled in `_process`, because
  `dawn_report.gd` logs no close event; a close event would replace the poll).
- **Jumpscare redo (P4-16 bodies now exist).** `cre_jumpscare_hit_{gaunt,scarecrow,boar,husk}`, 2D, `Creature`
  bus, written by `tools/audio/gen_jumpscare.py` (numpy synthesis; the approved running steps are read from
  the fallback `cre_jumpscare_hit.wav`, 1.27 s on; steps retimed per body). Each: 0.3 s lead
  silence, synthetic scare from 0.3 s, synthetic body thud at 0.92 s, steps from 1.27 s; RMS -9.4, peak -1.0.
  Sizes from `assets/models/creature_*.glb` bounds (W x H x L m): gaunt 0.47 x 2.75 x 0.61, scarecrow 0.82 x
  1.65 x 0.83, boar 1.08 x 1.56 x 2.04, husk 0.93 x 3.21 x 0.97. The old `cre_jumpscare_hit` is kept as the
  fallback. Measured (`tools/audio/measure_jumpscare.py`): lengths gaunt 3.20 s, scarecrow 3.00 s, boar 3.62 s,
  husk 3.37 s (boar and husk steps are slower); scare centroid 3707, 1136, 465, 1885 Hz; thud centroid 247, 572,
  137, 1003 Hz (boar thud 1.1 s long, 38 Hz floor; the others 55 to 95 Hz). **No caller picks the body yet**: `scares.gd` (AI Programmer) plays `cre_jumpscare_hit`; it should
  play `cre_jumpscare_hit_` + body (`creature_body` without `body_`), see `Soundscape.CATALOG`.
- Not done: no caller wired for any new id (owners above).

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
| `amb_insect_bed_night` | A | St | 20 | yes | 1 | 20 cricket voices: `SinOsc` 4.2 to 5.4 kHz chirp trains (3 chirps, 0.25 s); voices take turns, one train every 0.15 to 0.27 s (about 4.7 a second), the next a random voice rested at least 3 s (P4-26, CEO: chirps too often; voices used to repeat every 0.9 to 1.6 s). Turns keep the layer above -4 dB from its base (section 4.2): quietest 1 s window -2.1 dB, longest gap 0.21 s; steady floor of high noise at -50 dB |
| `amb_corn_rustle_loop` | A | St | 18 | yes | 1 | brown + pink noise, BPF 500 to 4 kHz swept by random LFOs, grainy `Dust` leaves ticks; **no pulsing envelope** (section 6) |
| `sfx_corn_rustle_01..04` | S | 3D | 1 to 2 | no | 1 | the same recipe as a gust: swell + tail |
| `sfx_bird_01..04` | S | 3D | 0.4 to 1.2 | no | 1 | two-tone glides `SinOsc` 2.8 to 5 kHz with fast vibrato, tweet patterns |
| `sfx_bird_call_distant_01..02` | S | 3D | 1.5 | no | 1 | a lower, slower warble through `FreeVerb` + LPF (distance) |
| `sfx_crow_caw_01..03` | S | 3D | 0.3 to 0.6 | no | 3 | **real** (section 13): clean American crow and rook caws, gated |
| `sfx_crow_burst` | S | 3D | 1.2 | no | 3 | **real** (section 13): two startled caws and wing beats (fake-out, doc 01 "Jumpscares") |
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
| `sfx_step_dirt_01..06` | S | 3D | 0.35 | 1 | Noise only, no oscillator (P4-26): heel thud (double LPF noise ~320 Hz + brown-noise weight), toe roll 60 to 120 ms later, a scuff and dry soil grains (filtered `Dust`). Each variant seeds its own timing, weight and texture. All steps high-passed at 30 Hz (no infrasound). Generated and rendered by `tools/audio/gen_steps.py --render`, which levels each surface's variants within 2 dB RMS |
| `sfx_step_corn_01..06` | S | 3D | 0.5 | 1 | the dirt step on softer soil + leaf brush (jittered BPF noise 2.6 to 5.2 kHz) and dry-leaf crackle (P4-26) |
| `sfx_step_wood_01..06` | S | 3D | 0.4 | 1 | barn planks: noise-excited damped `Klank` (ring under 0.12 s, heel then toe), low thud, straw grit; a faint creak on even variants (P4-26) |
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
| `sfx_door_slam` | S | 3D | 2.0 | no | 3 | **real** (section 13): wall thump, then a heavy wooden door kicked shut with rattle (the shed scare) |
| `sfx_lantern_ignite` / `sfx_lantern_blow_out` | S | 3D | 0.6 | 2 | match flare hiss / breath and glass tick (was the barn staging, dropped in D-146) |
| `sfx_flag_plant` | S | 3D | 0.5 | 3 | soft thud + cloth flap |
| `sfx_cloth_carry`, `sfx_emote_cloth` | S | 3D | 0.7 | 3 | cloth rustle |
| `sfx_ragdoll_thud_01..03` | S | 3D | 0.5 | 3 | body fall: saturated sub drop + flesh slap + dirt grains + dull rattles |
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
| `cre_jumpscare_hit` | C | M | 3.2 | no | 3 | fallback: **real running steps**; kea/bat scare and body thud are placeholders, superseded by the four below (section 10.7) |
| `cre_jumpscare_hit_{gaunt,scarecrow,boar,husk}` | C | M | 3.0 to 3.6 | no | 4 | per-body jumpscare: synthetic scare and thud (**PLACEHOLDER**), approved steps; section 10.7 |
| `cre_lunge` | C | M | 0.9 | no | 1 | **real** (section 13): corn walk rush, then a body thud |
| `cre_corn_part_01..03` | C | 3D | 1 | no | 1 | heavy stalks: dense leaf crackle + push + green-wood snaps |
| `cre_presence_swell` | C | M | 5.7 | no | 3 | **real** (section 13): two slow heavy dog breaths, 0.85x; the private "something's there" |
| `cre_door_bang_01..03` | C | 3D | 1.6 | no | 1 | `_01` **real** (section 13): hard banging on a rattling door over a heavy thump; `_02`, `_03` not built |
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
| `ui_paper_slide`, `ui_paper_rustle` | U | M | 0.5 | no | 3 | `ui_paper_slide` **real** (section 13): one sheet scritching across wood (Dawn Report); `ui_paper_rustle` not built |
| `ui_stamp` | U | M | 0.4 | no | 3 | stamp thump + paper |
| `ui_rec_start`, `ui_rec_stop` | U | M | 0.25 | no | 2 | soft two-tone tally ticks (the recording light's audio, doc 01 "Recording light"; the live-clips tally is silent since D-146, so unused) |

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
| `vox_emote_scream` | V | 3D | 2.5 | no | 3 | **real** (section 13, D-067): a CC0 scream recording, the "scream" emote (doc 05 s16); it emits a Noise of 60 m (doc 05) |

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
   `tools/audio/gen_variants.py` that writes the `.scd` files from a template (kept simple). Built as
   `tools/audio/gen_p4.py` (P4-17): `uv run tools/audio/gen_p4.py` rewrites the Phase 4 sources.
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

P4-17 (section 10.7) added no downloads: every new file is generated.

Most sounds are generated by code in this repo, with SuperCollider 3.14.1 (GPL-3.0 tool, output not
affected) and SoX 14.4.2 (tool only); both are CEO-approved in D-015. Since D-066 (CEO listen 2 of P3-08)
the sounds below are real recordings from Freesound.org, all licensed Creative Commons 0 (checked on each
sound's page). The unchanged HQ preview mp3 and `LICENSE.txt` are in `assets/audio/src/dl/`
(`freesound_<id>.mp3`); processing is `tools/audio/decode_downloads.py` then `process_downloads.py`
(mono, 48 kHz, 16-bit, trim, fade, soft limit, RMS matched to the file replaced unless noted, peak at most -1 dBFS).
To rebuild: `decode_downloads.py assets/audio/src/dl <scratch>/wav` (it drops the `freesound_` prefix from the
name, so no rename is needed; the mp3 is polyphase-resampled, not linear), then, in `<scratch>` with an empty
`out/`, `process_downloads.py`; copy `out/*.wav` to `assets/audio/`. Each page and any "original recordings" credit
was checked to be CC0 all the way down (CEO listen 3 rule). `vox_emote_scream` is a real person's performance,
kept by D-067 (CONTRACTS section 11 exception).
The `.scd` sources of these ids stay in `assets/audio/src/` but are **superseded** and not rendered.
No voice pack, no music, no other license.

| Sound id | Source (Freesound, CC0) | Author | Processing |
|---|---|---|---|
| `sfx_crow_caw_01` | [182090 U.S. National Park Service - American Crow](https://freesound.org/people/qubodup/sounds/182090/) | qubodup (cleaned US public-domain recording) | one caw, 1.97 to 2.5 s; gated; high-pass 150 Hz; shared RMS -16.2 dB |
| `sfx_crow_caw_02` | [673545 American Crows](https://freesound.org/people/deadrobotmusic/sounds/673545/) | deadrobotmusic | one caw, 5.33 to 5.72 s; gated; same |
| `sfx_crow_caw_03` | [556221 Rook (Corvus frugilegus)](https://freesound.org/people/Walking.With.Microphones/sounds/556221/) | Walking.With.Microphones | one caw, 3.3 to 3.75 s; gated; same |
| `sfx_crow_burst` | [536732 Caw.ogg](https://freesound.org/people/egomassive/sounds/536732/) | egomassive | 0.05 to 1.3 s (two caws, 24 kHz source) |
| `vox_emote_scream` | [850699 Female Scream](https://freesound.org/people/IENBA/sounds/850699/) | IENBA | the whole first scream, 0.2 to 2.66 s (its own fall-off ends it; listen 3 fix), 60 ms fade; no words; kept by D-067 |
| `sfx_door_slam` | [529396 thump_thud_slam_fist_heavy](https://freesound.org/people/bouncyballblue/sounds/529396/) + [452609 door wood old heavy kick open](https://freesound.org/people/kyles/sounds/452609/) + [216872 Doorslam](https://freesound.org/people/CastIronCarousel/sounds/216872/) | bouncyballblue, kyles, CastIronCarousel | thump (0.8), then at 0.14 s the door with rattle (0 to 1.9 s) and the slam transient (0.9); RMS -14.0 dB (+5 dB over the old -19.0, for the startle) |
| `cre_door_bang_01` | [623701 banging on rattling door](https://freesound.org/people/mediatheksuche/sounds/623701/) + 529396 | mediatheksuche, bouncyballblue | 0 to 1.6 s with the thump under the first hit (0.7); RMS -13.8 dB (+3 dB over -16.8) |
| `cre_jumpscare_hit` | [456802 Kea screaming](https://freesound.org/people/Breviceps/sounds/456802/) + [667579 Bat Screech](https://freesound.org/people/Yoyodaman234/sounds/667579/) + [346694 Body fall_02.wav](https://freesound.org/people/deleted_user_2104797/sounds/346694/) + [635052 Panicked Running Footsteps on Grass](https://freesound.org/people/sillygrizzlies/sounds/635052/) | Breviceps, Yoyodaman234, deleted_user_2104797, sillygrizzlies | kea 1.1 to 1.78 s (hp 300) at 0.3 s, kea 3.4 to 3.98 s (0.7x speed) at 0.6 s (0.7), bat 3.45 to 4.25 s (0.8x speed) at 0.35 s (0.7), synthetic leaf burst at 0.3 s, body fall from 0.435 s at 0.92 s (x2.16), 13 steps from the 12 strongest grass onsets (0.14 s each, 0.14 s apart, gain 1 to 0.16, lowpass 7 kHz to 2.2 kHz); RMS -9.4 dB. Built by `jumpscare()` in `tools/audio/process_downloads.py`, which reproduces the WAV byte for byte. **Scare and thud: placeholder, redo with the creature model.** |
| `cre_lunge` | [613567 Walking Through Corn Field](https://freesound.org/people/zazz.sound.design/sounds/613567/) + 673424 | zazz.sound.design, courtneyeck | corn 8.0 to 8.5 s, x4, fade-in 0.25 s, then the thud at 0.45 s |
| `cre_presence_swell` | [461839 2-1 dog breathing- sleeping](https://freesound.org/people/15GPanskaCepelak_Adam/sounds/461839/) | 15GPanskaCepelak_Adam | 3.8 to 9.0 s (two slow breaths); played at 0.85x (linear-interpolated slow-down); high-pass 40 Hz, low-pass 1.8 kHz (smooth 4th-order); loud breaths ducked (120 ms follower, gain = (thr/env)^0.9 above peak -12 dB) so the two breaths peak within 2 dB; 0.15 s fade-in, 0.4 s fade-out. The option-B air swells (synth) are not used. Replaces the pig 233111. |
| `ui_paper_slide` | [451411 foley paper sheet of white paper slide around on wood](https://freesound.org/people/kyles/sounds/451411/) | kyles | one scritch, 2.3 to 2.85 s; high-pass 600 Hz, low-pass 10 kHz; 4 ms fade-in, 80 ms fade-out; no added reverb. Replaces 46631. |

`sfx_taint_heartbeat` stays generated: no clearly better CC0 beat was found. Not used:

| Candidate | Source | License | Status |
|---|---|---|---|
| Real voice lines for strangers | CEO or a consented person | n/a | not used; synthetic only |
| TTS for stranger lines | OS built-in or offline TTS | to be checked | **not used; FOR CEO (Q-031)** |
| Music | none | n/a | no day music or score, ever (CEO, Phase 1 playtest); only the chase sting |

### 13.1 CEO listen 4 (2026-10-08)

CEO listen 4 rejected `cre_jumpscare_hit` ("monster breaking a door"), `cre_presence_swell` (pig breath, too
short) and `ui_paper_slide`. Three options each were built in `builds/sound_options/<sound_id>_A/_B/_C.wav`
(git-ignored; scratch sources). The CEO picked **presence B** (installed, with the loudest breath ducked) and
**paper C** (installed); the jumpscare pick was **option 03** of ten (installed; the wood-smash sources 562189, 553886 and 115917 are removed, 673424 stays for `cre_lunge`). The pig and the old paper original are removed.
`process_downloads.py` now trims leading silence, removes DC, then fades, so every installed WAV starts and ends
at sample 0 (QA LOW; the presence swell began at -2975 and the paper slide at -987 before).

| Sound | Option | Sources (all CC0 pages checked, no remix chain except where noted) | Length / RMS |
|---|---|---|---|
| jumpscare | A | Louisville Zoo tiger roar (lauramellis 263115) + 0.7x copy, corn field (zazz 613567), body fall (courtneyeck 673424), synth leaf burst | 1.60 s / -9.4 |
| jumpscare | B | leaf burst first, then black bear growl (celldroid 763026) + 0.8x copy, body fall | 1.80 s / -9.4 |
| jumpscare | C | lion roars (craigsmith 675443, flagged below) + 0.6x copy, corn field, body fall, synth burst | 1.60 s / -9.4 |
| presence | A | horse breathing (craigsmith 479677, flagged), two breaths, + 0.85x copy | 6.60 s / -16.6 |
| presence | B | sleeping dog (15GPanskaCepelak_Adam 461839) at 0.85x, synth low air swells | 6.57 s / -16.6 |
| presence | C | cow breaths (JarredGibb 233137) at 0.8x + original, synth low air swells | 6.80 s / -16.6 |
| paper | A | PaperSlide (eyesonlegs 464302), last 0.8 s of the pull, 0.8-11 kHz | 0.85 s / -20.8 |
| paper | B | dropping and sliding paper (123jorre456 46625), clean swish, 0.9-11 kHz | 0.53 s / -20.8 |
| paper | C | paper sheet on wood (kyles 451411), scritch, 0.6-10 kHz | 0.54 s / -20.8 |

Flag for the CEO: craigsmith's 675443 and 479677 are CC0 on Freesound, but he states they are digitised copies of
Hollywood optical and magnetic effects from the 1930s to the 1960s (USC Cinema). The CC0 grant is his; whether the
original studio recordings are free of rights is not something the page settles. Options A and B for the jumpscare
and B and C for the presence avoid them. Rejected as human voice or unclear chains: Vaporpup tiger and jaguar
(mouth), 190595 dog snarl (voice, reversed), 170454 growl (voice), 470900 and 844096 breathing (voice), 350414
(derived from a sound outside the checked chain).

### 13.2 Creature sounds from real recordings: CEO picks installed (D-149)

CEO listen of 2026-10-09 picked one option per sound; the picks are installed in `assets/audio/` under the
existing names, lengths within one frame of the old ones (+/- 64 samples, loops 4.000 s) and RMS unchanged
(table in `production/handoffs/install_picks.md`). Built by `tools/audio/real_creature.py`, seeded, so a rerun
gives the same files (`uv run --no-project --with numpy --with soundfile python -I tools/audio/real_creature.py`).
Sources: FilmCow Recorded SFX (D-149, library outside the repo, file names given) and Freesound CC0 (the
unchanged previews and their `LICENSE.txt` lines are in `assets/audio/src/dl/`; pages and remix chains checked).
`https://freesound.org/s/<id>/`. Full processing table: `production/handoffs/real_creature.md`.

**The gaunt signature is a stand-in.** The CEO took option C "for now": it is not the best, and a better real
source is to be found later. The CEO wants all creature sounds redone later (see `production/OPEN_ISSUES.md`),
so every row below can change.

| Sound id | Source id and author | Licence | Cut |
|---|---|---|---|
| `cre_gaunt_sig_01..03` (stand-in) | 621977 rydra_wong "Multiple Bones Cracking"; 831713 BugginOut.wav "Click Beetle" (foley of a flicked clipboard, not a beetle) | CC0 | 5 snaps 0.2 s + 7 clicks 0.1 s, high-pass 250-300 Hz, no low thump, lurk gaps 0.3-0.65 s |
| `cre_gaunt_sig_chase` (stand-in) | same two | CC0 | same grains on a 4.0 s circle, gaps 0.06-0.14 s (about 10/s), seamless loop |
| `cre_scarecrow_sig_01..03`, `_chase` | FilmCow `flag 1`, `flag 3`-`flag 7` | FilmCow (D-149) | first 0.35 s of each snap, 0.8x, high-pass 60 Hz, low-pass 14 kHz, single snaps 0.45-0.9 s apart; chase 10 per 4 s |
| `cre_boar_sig_01..03`, `_chase` | 158746 felix.blume (pig grunt); FilmCow `chain 3`, `land in dirt 1-4`, `body fall with lots of bass 1, 2, 4, 5` | CC0, FilmCow | chain drags 0.7 s; hoof = dirt landing 0.6x low-passed 600 Hz + bass slice low-passed 250 Hz; grunts 0.85x; chase 10 strides per 4 s |
| `cre_husk_sig_01..03`, `_chase` | 434881 TA-AT (gourd shakers); 610143 Michel1980 (dried seedpods; may be processed through a Morphagene) | CC0 | shaker 1.5-5.8 s high-pass 400 Hz + pods 7.0-9.25 s at 0.5, levelled, shaken at 17 Hz (doc 08 s6 14-22 Hz rule, imposed in code) |
| `cre_jumpscare_hit_gaunt` | 832436 felix.blume (fox, 0.8x); 621977 rydra_wong; FilmCow `body fall with lots of bass`; the approved 635052 steps | CC0, FilmCow | scare at 0.3 s, thud at 0.92 s, steps from 1.36 s |
| `cre_jumpscare_hit_scarecrow` | 244982 ani_music (flap, 0.7x); FilmCow `flag 6`, `fiber bundle moved 1`, bass body fall; 635052 steps | CC0, FilmCow | same timing |
| `cre_jumpscare_hit_boar` | 352698 Jofae (angry pig squeal); 191513 Hitrison (chain drag); FilmCow bass body fall; 635052 steps | CC0, FilmCow | same timing |
| `cre_jumpscare_hit_husk` | FilmCow `harpoon rattle`, bass body fall; 613567 zazz.sound.design (corn, x4); 127385 vigorish (seedpods popping); 635052 steps | CC0, FilmCow | same timing |
| `cre_gnaw` | 854169 FOSSarts "large dog chewing bone" | CC0 | loudest 2.5 s, high-pass 60 Hz |
| `cre_lunge` | 613567 zazz.sound.design (corn 8.0-8.5 s, x4); FilmCow bass body fall 2 | CC0, FilmCow | rush, thud at 0.45 s |
| `cre_flare_hit` | 634005 Soundburst (fox scream); FilmCow `land in dirt 3` (0.7x) | CC0, FilmCow | shriek, recoil thud at 0.72 s |
| `cre_door_bang_01` | 411694 deoking (door kick); 452609 kyles (heavy door kick) | CC0 | 1.6 s kick, variant 1 of 3 (`_02`, `_03` built but not installed, see below) |
| `cre_corn_part_01..02` | 755839 Sami_Zadoud "green corn leaves" | CC0 | one brush per stalk, 0.05-0.10 s apart, RMS -20 dB, soft-limited to peak about -12 dBFS (CEO: softer, one sound per stalk) |
| `cre_presence_swell` | 461839 15GPanskaCepelak_Adam (sleeping dog), unchanged since CEO listen 4 | CC0 | see section 13 table |

Not installed: `cre_door_bang_02/03` and `cre_corn_part_03` exist as candidates in `logs/listen/real_creature/`;
`Soundscape` loads one door variant and two corn variants (`n` in `game/audio/soundscape.gd`), so they have no
files to replace. Adding the files and raising `n` is a follow-up. The old `cre_jumpscare_hit` stays as fallback.

### 13.3 Real-recording picks installed: animals, items, radio and UI (D-149)

CEO listen of 2026-10-09 picks, built by `tools/audio/real_animals_items.py` (`build`, sources cached outside
the repo) and installed over the old sound ids; loop files keep their exact length (flare hiss 2.001 s, cart
squeak 3.001 s, radio static and crackle 4.001 s, seamless). Other one-shots changed length with the real
recording (the listen candidates already did); each file is mono 48 kHz 16 bit, peak at most -1 dBFS except where
the CEO asked for a lower peak (cart squeak, peak -9.1). Per-option cuts: `production/handoffs/real_items.md`.
All Freesound sources are CC0 1.0 (previews in `assets/audio/src/dl/`); FilmCow is the D-149 library, not in the repo.

| Sound id | Source id and author | Cut |
|---|---|---|
| `sfx_animal_chicken_01..03` | 456803 Breviceps "Chicken clucking" | 0.05-0.95, 0.75-1.75, 4.55-5.35 s; high-pass 150 Hz |
| `sfx_animal_panic_01` (chicken) | 316920 Rudmer_Rotteveel "Chicken Single Alarm Call" | whole |
| `sfx_animal_pig_01..02` | 442906 qubodup "Pig Oink" (remix of CC0 352698) + 352698 Jofae | whole; 1.5-2.2 s; high-pass 60 Hz |
| `sfx_animal_panic_02` (pig) | 344972 mrmunk "Pig in slop squealing" | 3.1-4.3 s |
| `sfx_animal_cow_01..02` | 163727 felix.blume + 59245 Zozzy | 0.25-2.35 s low-passed 3.5 kHz; whole low-passed 4 kHz |
| `sfx_animal_panic_03` (cow) | 827111 TheKingOfGeeks360 "Loud Bellow from Hereford Bull" | 0-2.7 s |
| `sfx_flare_shot` | 404434 Duesenbert "Bottle_Rocket_3.wav" | 8.2-9.4 s, launch and report |
| `sfx_flare_hiss_loop` | 316682 Alex_hears_things "sparkler_fuse_nm.wav" | from 4.0 s, high-pass 150 Hz, loop 2 s |
| `sfx_cart_squeak_loop` | 577320 TRP "Tricycle wheel squeek.wav" | from 1.95 s, loop 3 s, soft-limited 2 dB and trimmed -6 dB (CEO: peak too loud): RMS -16.8, peak -9.1 |
| `sfx_beartrap_snap` | 644245 fractionalist "Steel Spring Bear Trap" | 0.78-1.75 s |
| `sfx_pit_fall` | FilmCow `crashing through debris 2` + `land in dirt 1` | land at 0.45 s |
| `sfx_lantern_blow_out` | 242867 Reitanna "blowing out candle.wav" + FilmCow `glass clink 1` | 0.25-0.8 s, clink at 0.45 s, gain 0.25; a person's breath, no voice |
| `sfx_whistle` | 568995 strongbot "metal whistle.wav" | 12.75-13.7 s |
| `sfx_step_dirt_01..06` | 452633 kyles | six strongest footfall onsets |
| `sfx_step_corn_01..06` | FilmCow `footstep grass and leaves 1..6` | trim, fade |
| `sfx_step_wood_01..06` | 543685 Nox_Sound "Footsteps_Wood_Walk_Mono.wav" | six strongest footfall onsets |
| `sfx_emote_cloth` | FilmCow `flag 1` | trim, fade |
| `sfx_ragdoll_thud_01..02` | FilmCow `body fall 1`, `body fall 2` | trim, fade |
| `vox_radio_static_loop` | 110739 clesquir "Radio static" | from 20 s, band-pass 300-3400 Hz, loop 4 s |
| `vox_crackle_loop` | 316682 Alex_hears_things | from 4.0 s, clicks only (1.5-4 kHz transients over 1.8x the 0.1 s level), loop 4 s |
| `vox_radio_squelch_on` | 612722 3questionmarks "walkie_talkie_beep.wav" | 0.62-0.99 s |
| `vox_radio_squelch_off` | 524205 JovianSounds "Radio Sign Off / Squelch" | 0-0.22 s |
| `vox_radio_low_battery` | 701327 SEF7 "Walkie Talkie power on" | 0-0.42 s |
| `vox_radio_dead` | FilmCow `tube tv turn off 1` | 0.05-0.5 s |
| `ui_click` | FilmCow `mouse click 1` | trim |
| `ui_confirm` | FilmCow `ding 1` | 0.45 s |
| `ui_deny` | FilmCow `table hit 1` | trim |
| `ui_coins` | 223343 jalastram "1_Coins.ogg" | whole |
| `ui_stamp` | 683031 mpuffenbarger "Thump.mp3" | whole |
| `ui_award_reveal` | 470710 I.fekry "traditional stamp.wav" + 709925 Squidems "Service bell louder" | stamp from 0.4 s; bell from 1.3 s at 0.3 s, gain 0.45 |
| `ui_shop_bell` | 709925 Squidems "Service bell louder" | struck at 0 and 0.28 s |

**Alternates, not loaded by game code** (CEO: may switch later), in `assets/audio/alt/` under the same file names:
`alt/sfx_animal_panic_02.wav` (pig panic option C: 352698 Jofae, angry squeal-grunt, 2.3-3.35 s) and
`alt/sfx_animal_panic_03.wav` (cow panic option C: 194899 lolamadeus "Distressed Mother Cow and Calves.wav",
126.4-129.4 s, high-pass 50 Hz). To switch, copy the alt file over the file of the same name in `assets/audio/`.

No voices (the radio sounds are static, squelch and tones only). Not installed: every option the CEO did not pick.


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
9. Phase 2 (P2-08): the chase sting and the four chase signatures; the rising chase heartbeat (keep it or cut it?); a clip with echo, pitch up/down and no crackle against one with none; the barn bed in the lobby. (The lantern blow-out and door bang in the recording went with D-146.)
10. Phase 3 (P3-08), section 10.6: the wet Taint heartbeat (`taint 2` in the dev console); each scare
    with `scare <kind> 2` for `jumpscare`, `disarm_lunge`, `shed`, `hallucination`, `wrong_count`, and
    `scare fake_out` with a player outdoors; the crow caws (`kill 2`, then `ghost caw 2`); the scream and the
    cloth (`emote scream 2`, `emote wave 2`); the paper slide (`phase dawn`). Is the scream scary or silly? CEO listen 3 redo: jumpscare hit,
    shed slam and bang, presence swell (breathing), the three caws, the scream's ending, the paper slide.
11. Phase 4 (P4-17), section 10.7, all synthetic placeholders. In this order: the four lurk signatures
    `cre_<body>_sig_01..03` (is the husk rattle clearly not corn rustle? back to back with `sfx_corn_rustle_*`);
    the animals (chicken, pig, cow, then the three panic sounds: do they read as animals at all? if not, say so
    and a D-066 download replaces them); `cre_gnaw`; the flare (`sfx_flare_shot`, `sfx_flare_hiss_loop`,
    `cre_flare_hit`); the cart loop `sfx_cart_squeak_loop`; the five walkie sounds (`vox_radio_*`); the UI set
    (`ui_click`, `ui_confirm`, `ui_deny`, `ui_coins`, `ui_stamp`, `ui_award_reveal`, `ui_shop_bell`); and the
    Dawn Report low-pass (`phase dawn`: wind and SFX dull, the card and the replayed clips clear).
    The `cre_jumpscare_hit_<body>` redo (section 10.7 jumpscare bullet), 4 files in this order: gaunt, scarecrow,
    boar, husk (`scare jumpscare 2` once a caller picks the body; until then play the wavs). Does the scare fit
    the body (gaunt thin shriek, scarecrow hoarse and ragged, boar low bellow with chain, husk dry rattle and
    hollow wail)? Is the boar thud clearly the heaviest, the scarecrow and husk the lightest? Are the running
    steps (the approved ones, retimed per body) still right? The old `cre_jumpscare_hit` stays as the fallback.

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
