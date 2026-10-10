# 03 Creature, AI Director & Scares

Owner: Game Designer. Task: PP-06. Status: in review. Source of truth: [doc 01](01_design_doc.md).
Builds on [doc 02](02_systems_and_economy.md) (numbers), [doc 04](04_farm_layout.md) (places) and
[doc 06](06_networking_and_voice.md) (messages). Buildability review by the AI Programmer is open
(Q-018).

## Contents

1. Scope and conventions
2. Bodies
3. Senses
4. Behavior states
5. Losing a chase
6. Light rules
7. Day deaths and the trap race
8. Corruption and Shaken, creature side
9. Night traps (9.1 As built, P2-05)
10. Sabotage and the disturbance budget
11. The AI Director
12. Voice mimicry
13. Jumpscares, fake-outs, hallucinations and other scares (13.1 As built, P3-05)
14. Harvest Moon acts
15. Bodies of the dead and ghost hand-off
16. Voice-line list
17. Dawn Report templates
18. DD Phase 1: fake it first
19. Data files this doc adds
20. Gotchas
21. Questions raised
22. Season traits (DD Phase 5)

## 1. Scope and conventions

- **Source tags,** as doc 02: `doc 01 "<heading>"` is a number or rule doc 01 gives; `placeholder`
  is a number doc 01 does not give, needing a playtest; `sim` is a number the season simulator
  tunes; `inference` is my reading of doc 01, with what would settle it.
- **Nothing here is invented silently.** Doc 01 gives almost no creature distances or speeds, so
  most numbers in sections 3, 4 and 7 are `placeholder`. They sit in data (section 19), not code.
- **Host only.** The creature, the AI Director, traps, Corruption, deaths and every roll in this doc run
  on the host (peer 1) (CONTRACTS section 5). Clients get states and one-shot messages (doc 06
  section 7). Close calls resolve in the victim's favour; lag never kills (doc 01 "Close calls").
- **Dependency on Q-016.** Walk 3.0, crouch 1.2 and sprint 5.0 m/s are doc 02 `placeholder`s
  (doc 02 section 2.2). The trap race (section 7) is derived from them and from the pry time
  (doc 02 section 2.1, 4 s `placeholder`); if either changes, rerun section 7's formula.
- **Distances** are metres between the points named, as in doc 04. Place names are doc 04's.
- **AI Director** always means the in-game pacing system.

## 2. Bodies

Doc 01 "The Creature > Bodies": the host picks one body per season. All four hunt identically.

| Body id | Signature sound (the tell in Chase and in the trap race) | Source |
|---|---|---|
| `gaunt` | clicks | doc 01 "Bodies" |
| `scarecrow` | coat flaps | doc 01 "Bodies" |
| `boar` | chain drags | doc 01 "Bodies" |
| `husk` | dry rattle | doc 01 "Bodies" |

- Bodies change look and signature sound only. Same speeds, senses and rules (doc 01 "Bodies").
- **Quirks are not built.** Doc 01 open issue 4 floats "husk quieter in corn, boar louder but
  faster". Hold until the CEO decides; the data schema leaves a `quirk` field empty (section 19).
- **Night view.** The body is never in clear view at night except mid-chase for under 1 s. Lunges
  cut to black or knock down. Stares and hallucinations are distant silhouettes (doc 01 "What
  players see").

## 3. Senses

Doc 01 "Senses": hearing is the main sense; sight is short range; Corruption is tracked from much
further. Hunting uses only these (doc 01 "AI Director > Hunting and presentation").

### 3.1 Noise kinds and hearing radii

Every sound reaches the creature as `NoiseBus.emit(position, radius_m, kind, source_peer)`
(CONTRACTS section 8). The creature hears an emit if it is within `radius_m` of the position. Corn
(layer 5) between sound and creature shortens the radius by 30% (`placeholder`, `corn_damp_mult`
0.7; doc 01 says only that corn blocks sight). Doc 01 gives no radii, so all are `placeholder`
except the rows marked.

| Noise kind | Radius | Source |
|---|---|---|
| `step_walk` | 12 m | placeholder (doc 01 "Senses": footsteps are heard) |
| `step_crouch` | 0 m (silent) | doc 01 "Hiding verbs": crouch-walking is silent |
| `step_sprint` | 30 m | placeholder |
| `step_sprint_corn` | 40 m | placeholder (doc 01 "Senses": sprint in corn is heard) |
| Corrupted footsteps | radius x1.5 | doc 01 "The Corruption" ("heard 50% further"); doc 02 section 13 |
| `tool_till`, `tool_plant`, `tool_water`, `tool_harvest` | 15 m | placeholder |
| `tool_water` with quiet watering can | x0.5, so 7.5 m | placeholder (doc 02 section 10 names the can; this doc sets the radius) |
| `tool_shovel`, `tool_pry`, `tool_repair` | 25 m | placeholder |
| `tool_disarm` (kneeling still) | 8 m | placeholder (doc 01 "Night Traps": disarm kneeling still) |
| `well_pump` | 45 m | placeholder (doc 01 "Senses": named as a heard sound; the cure is "noisy", doc 01 "The Corruption") |
| `door` | 20 m | placeholder |
| `generator_dead` | 80 m | placeholder (doc 01 "Nights": dead generator, "sound carries") |
| `bells` (tripwire bells rung) | 60 m | placeholder (doc 01 "Night Traps": loud) |
| `flare` | 70 m | placeholder |
| `whistle` | 50 m | placeholder (section 13) |
| `voice` | `60 x (byte/255)^2` m | placeholder shape; the byte is doc 01 "Senses" and doc 06 section 8. Normal speech (159) gives 23 m; a scream (255) gives 60 m |
| `walkie` | as `voice` | placeholder: the radio is a voice at the speaker's position |
| emote `scream` | as `voice` at byte 255, 60 m | inference (doc 01 "Emotes": the scream gives you away) |

Corn damping does not apply to `step_sprint_corn`; its 40 m already includes the corn (Q-018, D-021).

- **Nothing stored.** The creature never keeps or replays a heard voice for hunting; it uses the
  byte and the position only (doc 01 "Senses").
- **Ghost voices do not feed the creature** (doc 06 section 8).
- **The host reports a speaker at most every 100 ms** using the loudest frame (doc 06 section 8).
- **Sound memory.** Each heard emit sets `last_heard_position` and `heard_age_s` = 0. Memory lasts
  12 s (`placeholder`, `hearing_memory_s`); then the creature stops homing and wanders in its
  region. Louder emit replaces a quieter one if it arrives within 4 s (`placeholder`).
- **When tools emit:** at hold completion; loud tools (25 m) also at hold start (placeholder).
- The creature homes on the memory entry with the largest margin, `effective_radius_m - distance_m`
  (the radius after corn damping), ties to the newest.
- **The 10/30/60 m reference.** Doc 04 sec 8 tests players hearing each other at 10, 30 and 60 m;
  the creature's radii above sit beside those but are separate.

### 3.2 Sight

| Value | Number | Source |
|---|---|---|
| Sight range in open ground by day | 25 m | placeholder (doc 01 "Senses": short range) |
| Sight range in open ground by night | 15 m | placeholder (night is darker; inference) |
| A lit lantern, lit doorway or flashlight-style light is spotted at | 40 m | placeholder (doc 01 "Senses": "spots light") |
| Eye height | 1.65 m | CONTRACTS section 4 |
| Corn | blocks sight both ways (layer 5, 2.4 m) | doc 01 "Senses"; CONTRACTS section 4 |
| Crouched and still player | seen only within 6 m | placeholder (doc 01 "Hiding verbs") |

- Sight is a ray from the creature's head to the player's head and feet, blocked by layer 5 and
  layer 1. Open ground means no corn on that ray.
- **Stillness** is the host's own check on received transforms: under 0.2 m moved over 1 s
  (`placeholder`, doc 01 "Hiding verbs: go still").

### 3.3 Corruption tracking

Doc 01 "The Corruption": the creature tracks a Corrupted player "from much further".

| Value | Number | Source |
|---|---|---|
| Corruption tracking radius | 60 m | placeholder |
| Tracking works | day and night, through corn | doc 01 "The Corruption" (inference: "tracked", not "seen") |
| Night trail | a Corrupted player's path is followable by the creature for 20 s of age | doc 01 "The Corruption" (follow trail at night); 20 s placeholder |
| Cue to the player | black stains underfoot and a wet heartbeat | doc 01 "The Corruption" |
| Ground effect: dead crows and strange seeds | stay Corruption sources; touching Corrupts | doc 01 "Daytime Threats" |

- Tracking gives a **position** to the creature's senses. It is a sense, so it is legal for
  hunting (section 11.6).
- Corruption costs and cure are doc 02 section 13: sprint x0.6, footsteps x1.5, pry x1.5, cure 10 s at
  the well (noisy).

**As built (P3-07).** `creature.gd` `_track_taint()` runs from `_sense` at night only; day tracking
waits for a creature that hunts by day. Within `taint_tracking_radius_m` (60 m) a Corrupted living
player's true position is the fix. Further out, the creature follows the night trail once it comes
within 3 m of one of its points, homing on the point 3 steps newer; the trail keeps one point per
second for `taint_trail_s` (20 s). Trail step 1 s, pickup 3 m and lead 3 are placeholders in
`creature.gd`; the rule is `creature_logic.gd` `taint_fix` (unit test
`tests/creature/test_creature_logic.gd`). A fix enters the hearing memory every 0.1 s as kind
`taint` with margin 0, so any real noise wins the pick and a Corrupted chase never goes quiet
(section 5). Washing or death drops the trail at once. Tracking and leavings are off on the
Phase 1 farm unless `phase1.json` `taint_enabled` is set. The debug state shows `taint_trails`.

### 3.4 Sensed against true

The creature has a `sensed` state (what it heard, saw or tracked) and the world has the `true`
state. Hunting reads `sensed` only. The debug view draws both (doc 01 "Hunting and presentation",
doc 05) so a designer can see where the creature is wrong.

## 4. Behavior states

States are `lurk`, `lure`, `stalk`, `chase`, `retreat` (doc 01 "Senses"; CONTRACTS section 7).
The host sends `creature` (position and state) at 15 Hz and `apply_creature_state(state, body)` on
change (doc 06 section 7). Ambience runs locally from the state (doc 01 "Ambience").

| State | What it does | Audio tell | Doc 01 |
|---|---|---|---|
| `lurk` | wanders its region at walk speed, listens, sets and moves traps at night | normal insect and frog bed | "Senses > States" |
| `lure` | plays a fake sound or voice and waits near the source's far side | the fake itself; local to the target in day | "Voice mimicry" |
| `stalk` | closes on a sensed target slowly, just out of sight | insect and frog bed cuts out; wind drops | "Senses > States" |
| `chase` | runs at a target it has found | music sting on entry plus the body's signature sound | "Senses > States" |
| `retreat` | leaves after a jumpscare, kill or flare hit | insects return | "Senses > States" |

### 4.1 Speeds and timers

Doc 01 gives none. All `placeholder`, in `creature.json` (section 19). They depend on doc 02's
placeholder player speeds (Q-016).

| Value | Number | Reason |
|---|---|---|
| `lurk_speed_mps` | 2.0 | slower than a walking farmer (3.0, doc 02 section 2.2) |
| `stalk_speed_mps` | 2.5 | still slower than walking, so a player can leave |
| `trap_race_speed_mps` | 3.5 | section 7 |
| `chase_speed_mps` | 5.5 | just above sprint (5.0), so a sprint buys time but a 6 s sprint cannot escape alone; breaking line of sight does |
| `chase_speed_tainted_mps` | 5.5 | unchanged: Corruption hurts the player, not the creature |
| `lure_wait_s` | 8 | doc 01 "Voice mimicry": a lure works if the target moves over 10 m toward within 8 s |
| `stalk_max_s` | 25 | then it commits or gives up |
| `chase_commit_s` | 6 | minimum chase before it can lose interest |
| `retreat_s` | 30 | before it can lurk near the same player |
| `retreat_after_flare_s` | 30 | doc 01 "Store": flare scares off 30 s; doc 02 section 10 |
| `reach_m` | 1.5 | arm length for a lunge |

### 4.2 Transitions

| From | To | Condition |
|---|---|---|
| `lurk` | `lure` | the AI Director grants a lure (section 12), or the creature hears a lone player and picks a lure (night) |
| `lurk` | `stalk` | a target sensed (heard, seen or Corrupted) and the AI Director's phase allows presence |
| `lure` | `stalk` | lure worked (target moved 10 m toward within 8 s) |
| `lure` | `lurk` | lure failed |
| `stalk` | `chase` | target seen, or heard sprinting, or at night the target's **sensed** position is within 12 m; by day only inside a day death or a trap race (section 7) |
| `stalk` | `lurk` | `stalk_max_s` passes with no commit, or the target joins a group (day) |
| `stalk` | `retreat` | a jumpscare is played (day only, section 13) |
| `chase` | `retreat` | kill, jumpscare, flare hit |
| `chase` | `lurk` | chase lost (section 5) |
| any | `retreat` | flare hit, or the player enters a lit building during chase |

- **By day** only `lurk`, `lure`, `stalk` and the jumpscare apply, plus the day deaths (section 7);
  a day `chase` happens only inside a day death or a trap race (doc 01 "By day").
- **At night** all states apply. A `stalk` ends in `chase` more often when the target is alone
  (section 11).
- **Drawn to noise (P5-33, CEO STOP 6).** In `lurk` during a night build-up, a noise it hears that
  does not start a stalk (the AI Director's budget is spent) still sends it walking to the heard
  position, with no target. In `fade` and `relax` it keeps to its region.
- **Seen in lurk (P5-39, as built).** The `lurk` to `stalk` row's "seen" applies on its own:
  with nothing heard, a living player in sight within the last 0.5 s and not sheltered (not in a lit
  building or lit doorway, section 6) starts a stalk when the AI Director allows one (reason `seen`).
  Sight never starts a lure, and a seen player the AI Director holds back is not walked up to.
  Before this, lurk reacted to sound only, so a silent player in plain view was never stalked.
- **Wander points (P5-39, as built).** A lurk wander point is a cover point or trap spot at
  least `wander_min_hop_m` (creature.json, placeholder 8 m) from the creature. When the AI Director's
  wander region holds no such point (`town_road` holds none), it picks among points within 25 m of
  the region instead of parking on the region's centre. Inference: 8 m is about one marker spacing;
  playtests settle it.
- **Stalk hiding spots (P5-39, as built).** A night `stalk` no longer walks the straight line at the
  sensed position and stands 10 m off in the open. Every `stalk_repick_s` (placeholder 6 s) it picks a
  spot on a ring round the target's **sensed** position: `stalk_hold_far_m` (placeholder 18 m, past
  `sight_night_m`) at the start, shrinking to `stalk_hold_near_m` (placeholder 9 m) as `stalk_max_s`
  runs out. Of the ring points on its own side, it takes the nearest that a wall or the corn hides from
  a standing player's eye there; with none hidden, the point 45 degrees to one side (picked per stalk),
  so it circles in. The scripted stalk (section 18) keeps its fixed standoff.
- **Giving up a stalk (P5-39, as built).** When `stalk_max_s` passes it drops its goal (it used to
  walk on to where the target was) and does not stalk that player again for `stalk_rest_s`
  (placeholder 30 s); it re-stalked the same player the next frame, standing off them stalk after
  stalk. Lures still apply in the rest.
- **Retreat (P5-39, as built).** A retreat runs to a random cover point at least `retreat_min_m`
  (placeholder 30 m) off and farther from the target's last sensed position than from the creature;
  with none, the farthest cover point (the old rule, which sent every retreat the same way).
- **Crows** never change a state tell (doc 01 "Ambience"): crows are a scare, not a state.

## 5. Losing a chase

Doc 01 "Senses > Losing a chase": **break line of sight AND go quiet** for a few seconds, **or
reach a lit building**.

| Rule | Number | Source |
|---|---|---|
| Line of sight broken | no unblocked ray to the player's head for the whole time | doc 01 "Senses" |
| Go quiet | crouch-walking or stillness, so `step_crouch` or no emit | doc 01 "Hiding verbs" |
| Time both must hold | 4 s ("a few seconds") | placeholder (`chase_lose_quiet_s`) |
| Reaching a lit building | the player inside the lit doorway radius (6 m, doc 04 sec 8) | doc 01 "Nights"; 6 m is doc 04's placeholder |
| Breaking line of sight while sprinting | does not lose it: the creature goes to the last heard position (sprint is loud) | inference from doc 01 "Senses" |
| Flare hit | creature goes to `retreat` for 30 s | doc 01 "Store"; doc 02 section 10 |

- A chase can be lost only after `chase_commit_s` (6 s) has passed; the 4 s of `chase_lose_quiet_s`
  may run during it.
- When a chase is lost the creature goes to the last sensed position, searches for `memory` seconds
  (section 3.1) and returns to `lurk`.
- **Any Corrupted player cannot lose a chase by quiet alone:** Corruption tracking keeps giving the
  creature a position (section 3.3). They must reach a lit building or wash off the Corruption. This is a
  consequence of doc 01 "The Corruption" and "Senses" (inference; settle it in a Phase 1 playtest).

## 6. Light rules

Doc 01 "Nights".

| Rule | Detail | Source |
|---|---|---|
| Lit buildings | the creature never enters one | doc 01 "Nights" |
| Dark buildings | enterable through the door; it **always bangs first** | doc 01 "Nights" |
| Restoring power | drives it out of a dark building it entered | doc 01 "Nights" |
| Bang time | 3 s of banging, audible at 30 m, before it enters | placeholder (`door_bang_s`, `door_bang_radius_m`) |
| Barn attack from day 6 | if everyone is inside, it bangs the barn doors while circling to damage the generator | doc 01 "Ramp-up" (day 6) |
| Generator damage rate | each pass takes 15% of the tank (`placeholder`); the generator is outside, 12.5 m from the barn door (doc 04 sec 8.3) | doc 02 section 14 for fuel |
| Dead generator | sound carries 80 m; the creature comes to look | doc 01 "Nights"; radius placeholder (section 3.1) |
| Dimming | steady dim, never flickers; only ghosts flicker lights | doc 01 "Nights", "Ghosts" |

- **Lit** means the building's light is on and the generator has fuel above the dim threshold
  (doc 02 section 14). A dimming light still counts as lit until the generator is empty.
- The "everyone inside" test is: every living player inside a building for the last 20 s
  (`placeholder`, `everyone_inside_s`).
- The AI Director's phase profiles are not allowed to override these rules.
- **Bang first (P5-39, as built).** At night, when its goal is inside a dark building it is outside
  of, it walks to the step 2 m outside the door, logs `creature_door_bang`, and stands there for
  `door_bang_s` (creature.json, 3 s) while every peer hears `cre_door_bang` at the door once a second
  (placeholder rate). Then it may go in and out until it leaves the building. A chase cannot catch
  during the bang. `door_bang_radius_m` is not a separate number: the bang's reach is the sound's
  own falloff in the Soundscape catalog (`cre_door_bang`, max 90 m). Before P5-39 the bang was never
  built, and it walked into the dark barn and killed the sheltering players without a sound.

## 7. Day deaths and the trap race

Doc 01 "Day Deaths": a day death is out until dawn plus the medical bill (doc 02 section 8).
There are exactly two ways to die by day; the AI Director varies the thresholds a little each day
but never adds a condition.

### 7.1 Death 1: alone and Corrupted in the deep corn

All four must hold (doc 01 "Day Deaths (1)"):

1. The player is **Corrupted**.
2. The player is **alone**: no teammate within earshot.
3. The player is **deep in corn**.
4. The creature is in `stalk` on that player and reaches `reach_m` (the close-call check, doc 06
   section 7, resolved in the victim's favour).

| Term | Number | Source |
|---|---|---|
| Deep in corn | 10 m or more inside the ring edge | doc 04 sec 2 (strips are 6 m wide, so no point is more than 3 m from open ground, and "deep" is a ring location only); the 10 m is doc 04's |
| Earshot | the creature's `voice` radius for a normal speech byte, 23 m (section 3.1) | inference: "earshot" is a teammate hearing a shout; settle it by a playtest |
| AI Director variation | deep 8 to 12 m, earshot 18 to 28 m, chosen once at dawn | placeholder bends (section 11.4) |

A player hunted by day while fitting only some conditions is stalked and may be jumpscared
(section 13), never killed.

### 7.2 Death 2: the trap race

Doc 01 "Day Deaths (2)": a bear trap springs by day; the creature's signature sound approaches
from a set distance; prying free leaves you alive and Shaken; failing kills; a teammate shortens
the pry. Tuned so **a solo, uncorrupted player who pries at once survives with a few seconds to
spare** (doc 01 "Day Deaths (2)").

**Formula.** `spare_s = start_distance_m / approach_speed_mps - pry_s`. The player survives when
`spare_s >= 0`.

| Input | Number | Source |
|---|---|---|
| `pry_s`, solo uncorrupted | 4 s | doc 02 section 2.1 (placeholder) |
| `pry_s`, Corrupted | 4 x 1.5 = 6 s | doc 02 section 13 (placeholder) |
| `pry_s`, with a teammate | 4 x 0.6 = 2.4 s (3.6 s Corrupted) | doc 02 section 2.1 (`labor.json` `pry.helped_mult`) |
| `approach_speed_mps` | 3.5 | placeholder (section 4.1) |
| `start_distance_m`, normal | 32 | placeholder, derived below (25 before P5-33) |
| `start_distance_m`, deep trap | 25 | placeholder, derived below (18 before P5-33) |

**Derivation.** The first target spare was 3 s ("a few seconds", doc 01): 3.5 x (4 + 3) = 24.5,
rounded up to 25 m. In the CEO's STOP 6 playtest (P5-33, `logs/playtest_20261009/`) every race
killed at 7.7 s, before a teammate could arrive or the victim could read the warning ("kills so
quickly and randomly"). The target is now 5 s of spare for a solo uncorrupted player who pries at
once, so a teammate a few metres away can still run over and help: 3.5 x (4 + 5) = 31.5, rounded
up to **32 m**, giving `spare_s` = 32 / 3.5 - 4 = **5.14 s**. A deep trap keeps its 7 m lead over
the normal one: **25 m**, giving 25 / 3.5 - 4 = **3.14 s**. Both are placeholders
(`ai_director.json` `trap_race`).

Worked table (normal start 32 m, deep 25 m; speed 3.5):

| Case | Pry | Normal spare | Deep spare | Outcome | Doc 01 loss reason |
|---|---|---|---|---|---|
| Solo, uncorrupted, pries at once | 4 s | +5.14 | +3.14 | survive | the target |
| Solo, uncorrupted, hesitates 2 s | 4 s + 2 s | +3.14 | +1.14 | survive | "hesitation" |
| Solo, uncorrupted, hesitates 4 s | 4 s + 4 s | +1.14 | -0.86 | lives normal, dies deep | "hesitation", "deep trap" |
| Solo, Corrupted, pries at once | 6 s | +3.14 | +1.14 | survive | "Corruption" (slower pry) |
| Solo, Corrupted, hesitates 2 s | 6 s + 2 s | +1.14 | -0.86 | lives normal, dies deep | "Corruption", "hesitation", "deep trap" |
| With a teammate, uncorrupted | 2.4 s | +6.74 | +4.74 | survive | "a teammate shortens the pry" |
| With a teammate, Corrupted | 3.6 s | +5.54 | +3.54 | survive | |

- **Hesitation** is the time from spring to starting the pry hold (the host measures it).
- **AI Director bend.** The AI Director may vary `start_distance_m` between 29 and 35 m at normal
  and between 22 and 28 m at deep (placeholder, `trap_race_bend_m` +/- 3), picked at dawn. At 29 m
  a solo uncorrupted player has 4.29 s spare; at 35 m, 6.0 s. It never adds conditions and never
  moves a solo uncorrupted immediate prier at a normal trap below 2 s of spare (the floor;
  placeholder `trap_race_min_spare_s`). The floor does not apply to deep traps: they are meant to
  be tighter (25 m gives 3.14 s; the 22 m bend gives 2.29 s).
- **Nightmare** widens the bend range to +/- 5 m but keeps the floor at 1 s; no voice tells; the
  whistle stays honest; the "wrong-place" tell remains (doc 01 "Difficulty and group settings").
- **Who is "alone".** The race has no alone condition: a teammate within `help_range_m` (3 m,
  `placeholder`, doc 02 section 2.1 for the helped pry) who starts a prying hold shortens it; a
  teammate farther away may still run to help. The race simply continues while they run.
- **Credit for lag.** The host gives the victim half the RTT against the deadline (doc 06 section
  7, `apply_trap_race`).
- **Outcome.** Survive = freed, Shaken for 60 s (doc 02 section 13), walk x0.6 for 60 s
  (doc 01 "Night Traps"), the creature goes to `retreat`. Fail = at the deadline the creature reaches
  the player; a day death (section 15).
- **Signature approach.** From spring the body's signature sound plays from the approach
  direction, coming at `approach_speed_mps`, so a player can judge the time left. The creature is
  heard before it is seen (doc 01 "What players see").
- **Log.** `trap_race_result` with `solo`, `tainted`, `pried_at_once` (hold started within 0.5 s of
  the spring, placeholder), `survived`, `seconds_spare` (the margin, negative on death) (CONTRACTS
  section 10).

**As built (P5-33, CEO STOP 6).** The playtest log showed why the trap felt random. Three of the
four races were sprung at night, although doc 01 "Night Traps" starts the race only "by day". A
teammate's finished pry was ignored, so the victim died anyway. The clock killed while the creature
was 66 to 72 m away or in `lurk`. The victim had to aim at the trap to pry it. Now:

- **Only a day spring starts a race** (`traps.json` `bear_trap.starts_race_by_day`). A night pin
  has no clock: the victim pries free (4 s), or the creature's own catch kills (cause `night_trap`).
  `trap_pinned` logs `race` and `deadline_s`.
- **Any living player's finished pry frees the victim**; a teammate's pry counts as helped
  (`solo: false`).
- **The body walks in.** On a day spring the creature's body is placed `start_distance_m` from the
  victim and walks at `start_distance_m / deadline`, speeding up to its chase speed when the way
  round buildings is longer, so it arrives on the deadline. The kill happens with the creature at
  the victim, never from out of sight.
- **A pinned player pries with the interact key** without aiming at the trap.
- **HUD.** The victim sees "CAUGHT IN A TRAP. It is coming: N s" with the seconds left (day) or
  "It can hear you" (night). Every teammate sees "A FRIEND IS CAUGHT IN A TRAP, N m away".

## 8. Corruption and Shaken, creature side

Effects on the player are doc 02 section 13. What the creature does:

| Cause of Corruption | Where it comes from | Source |
|---|---|---|
| Creature leavings | black stains on the ground left by `lurk` and `stalk` passes, one per 20 m walked (placeholder) | doc 01 "The Corruption" |
| A stolen tool | picking it up | doc 01 "Daytime Threats" |
| An item left in the field at dusk | the item turns Corrupted until picked up | doc 01 "The Corruption" |
| An unpicked moonflower | at dusk | doc 01 "The Corruption" |
| Dead crows and strange seeds | disturbance sources from day 3 | doc 01 "Daytime Threats", "Ramp-up" |

- **Hallucinations are more frequent for a Corrupted player** (doc 01 "The Corruption"), and more
  frequent late in the season (section 13). Rate multiplier x2 while Corrupted (placeholder).
- **Corruption never comes from a jumpscare** (doc 01 "Jumpscares").
- **Shaken** comes from jumpscares and surviving a trap race (doc 01 "The Corruption"), never Corrupts.
- **Corruption leaves a night trail** (section 3.3).

**As built (P3-07).** Leavings: while `lurk` or `stalk` walks at night, every `leavings_every_m`
(20 m) calls `Taint.add_source(&"leavings", pos)` (`game/player/taint.gd`); touching one within
0.8 m Corrupts (placeholder). Leavings are removed at dawn (inference; doc 01 is silent). A can the
creature moves (`creature_move_cans`) Corrupts its next taker (`stolen_tool`); a can left more than
4 m from home at dusk does the same (`field_item_at_dusk`, inference: the creature's can rule).
Dead crows and strange seeds have the source kinds and a dev command (`taint_source`) but no
sabotage spawns them yet (Q-061). Moonflowers are not built. The x2 hallucination rate is not
part of P3-07.

## 9. Night traps

Doc 01 "Night Traps". The creature sets traps while in `lurk` at night, counts from doc 02 section
11 (scaled by headcount, difficulty). A set that has waited 30 s (placeholder) for `lurk` lands in
any state, so a lone player who keeps the creature busy still meets planned traps (P2-28, CEO
2026-10-08; `trap_changed` carries `late: true`).

| Item | Rule | Source |
|---|---|---|
| Count per night | doc 02 section 11, bear / pit / bells, set on the 22 trap spots (doc 04 sec 7.1) | doc 01 "Ramp-up" |
| Spot choice | from the spot list near the **region** where the creature's senses say players work (fields, yard, paths), never at a player's tracked position; deep spots (`trap_05`, `_10`, `_20`, `_22`, doc 04 sec 7.1) are reserved for bear traps | doc 01 "Hunting and presentation"; doc 04 |
| Kinds of spot | `edge`, `row`, `deep` | doc 04 sec 7.1 |
| Bear trap | pins until pried (any living player's pry frees); by day starts the race (section 7); at night there is no clock and only the creature's catch kills (P5-33); then walk x0.6 for 60 s | doc 01 "Night Traps" |
| Pit | stumble, drop the carried item; fill with a shovel | doc 01 "Night Traps" |
| Tripwire bells | from day 4; loud (60 m); tell the creature where the player is; cut with 1 s | doc 01 "Night Traps"; doc 02 section 12 |
| Clues | fresh dirt, bent stalks, glinting metal; seen only by a player looking closely (within 4 m and facing, placeholder); trackers 1.5x that (doc 02 section 15, placeholder) | doc 01 "Night Traps" |
| Flags | free for the players; from day 5 the creature moves one flag a night | doc 01 "Night Traps", "Ramp-up" |
| Pegboard | bear traps hang on outlines; the farm's traps (board plus any off the board) are the creature's only bear supply, taken at nightfall as the plan needs, off-board traps first, then the board; the lock caps all theft at one trap a night; the creature breaks the lock from day 5 | doc 01 "Night Traps", "The tool shed"; D-053; lock price 40, doc 02 section 10 |
| Trap kept in a building | vanishes only if the building went dark; if lit all night it is not stolen, and at dawn it turns up unarmed in the corn at a random `trap_spot`, as a pickup | doc 01 "Night Traps"; D-053 (unarmed is inference) |
| Day-time traps | traps stay armed by day; day traps are the source of trap races | doc 01 "Day Deaths" |

- **A trap is never placed within 6 m of a lit doorway** (placeholder). No `trap_spot` lies within
  10 m of the town stand (doc 04), so no trap lands there; the stand has no trap rule of its own
  (D-115).
- **At most one trap in any 8 m circle** (placeholder), so the player can disarm one at a time.
- **Full wipe.** Traps +2 and farm damage x2 (doc 02 section 14); the extra traps are 1 bear and 1
  pit (placeholder, `full_wipe_extra_mix`).
- **Returned traps.** A trap taken from the pegboard is carried out of the farm and placed next
  night on the ordinary list; no special rule.
- **Unarmed debris.** When disarmed, a bear trap becomes an item the player can hang on the
  pegboard in 1 s (doc 02 section 2.1).

### 9.1 As built (P2-05)

`game/creature/creature.gd`, host only, on the full farm (`--full-farm`). The Phase 1 world
(`--phase1` without `--full-farm`) keeps the scripted spots and timers of section 18.

- **Count.** At nightfall `trap_plan` reads `ramp_up` `bear_4p` / `pit_4p` for the day (1 to 7),
  scales it with `Data.scaled` by headcount (2 to `max_players`), and tops up: kinds already armed
  are subtracted. Bells wait (`traps.json` `enabled: false`). Difficulty and the full-wipe extras are
  not applied yet.
- **Timing.** The night's sets are spread at random over 10% to 75% of the night (placeholder) and
  happen only while the creature is in `lurk`; a set missed in another state waits for the next
  `lurk`.
- **Region.** The host keeps up to 64 positions of player noises the creature heard (day and night,
  within hearing radius; never true positions). A set picks one at random and uses free spots within
  25 m of it (`region: heard`), else the nearest free spot (`nearest`); nothing heard yet gives a
  random spot (`none`). `trap_changed set` logs `region` and `work_m`.
- **Spot rules.** Not used by another trap; deep spots bear only; not within 6 m of a lit doorway
  (generator powered); not within 8 m of
  another trap; not within 4 m of a living player (placeholder, so nobody watches it appear). No
  spot: `trap_skipped` `reason: no_spot`.
- **Supply (D-053).** Every bear set uses a stolen trap (`trap_changed` `stolen: true`); pits need
  none. At nightfall the creature steals what the plan's bears need beyond its stash: first traps
  in living players' hands outdoors (`from: outdoor`) or in a dark building (`dark_building`), then
  the pegboard, lowest slot first (`board`). A trap taken at nightfall is set that same night. A
  bear set with an empty stash logs `trap_skipped` `reason: no_supply`; no free spot logs
  `reason: no_spot`. `trap_plan` logs `supply` (the stash after nightfall theft) and `armed`.
  Unused stolen traps stay in the stash for later nights.
- **Dark building.** Through the night (checked every second) a trap held in a building while the
  generator is not powered (`fuel_s > 0` and not damaged) is stolen, whatever the plan needs.
- **Lock.** With the shed lock and before day 5 (`store.json` `shed_lock` `broken_from_day`), all
  theft, hands and board together, stops at `theft_cap_per_night` (1); the first refused theft logs
  `trap_theft_capped` (`cap`, `day`) once a night. Logs: `trap_stolen` (`trap`: `held:<peer>` or
  `board:<slot>`, `from`, `lock`, `day`, `supply`, and `player` for hands).
- **Lit building.** A trap held at nightfall in a building with the generator powered is not
  stolen. If the player still holds it in a building at dawn, and the building never went dark, it
  leaves their hands and turns up unarmed at a random free `trap_spot`
  (`trap_moved`: `trap`, `from_building`, `to_spot`, `player`; `trap_changed` state `loose` to every
  peer). The pickup (`game/creature/trap_pickup.gd`) uses the `disarm_bear` hold until a pick-up verb
  exists (Q-056); it refuses `hands_full` and logs `trap_changed` `picked_up`.
- **Clearing.** `clear_trap(id)` drops a trap from the creature's list; the trap race and the host's
  own `disarmed` / `filled` handling call it, so the spot can be reused.
- **QA flags.** `--give-trap` puts a bear trap in every living player's hands at nightfall;
  `--shed-lock` sets the lock (the store does not sell it yet); `--take-loose` (host) moves the host
  player to a loose trap and picks it up; `--log-creature` also logs `trap_changed_applied` on
  clients. `--pegboard-empty` now means no bear supply, so bears are skipped.

## 10. Sabotage and the disturbance budget

Doc 01 "Daytime Threats": the creature leaves **disturbances** by day against a rising budget.
Every disturbance has a fix; none is fatal on its own. Count per day is doc 02 section 11
(disturbances 4p / 3p / 2p; the scaled table is the single source).

### 10.1 The pool

| Disturbance id | Effect | Fix | Clue left | Cost points | Source |
|---|---|---|---|---|---|
| `trample` | a plot is trampled at dawn: crops lost, replant | replant | footprints | 2 | doc 01 "Daytime Threats" (1 per night; 2 if nobody outside; +1 dead generator, doc 02 section 14) |
| `stolen_tool` | a tool vanishes and reappears creepy, often beside an armed trap; picking it up Corrupts | wash, buy back (the tool is lost until found) | claw marks | 2 | doc 01 "Daytime Threats" |
| `broken_fence` | animals escape the pen | round up, far from the group | claw marks | 3 | doc 01 "Daytime Threats" |
| `dead_crow` | Corruption source on the ground | bury with a shovel (4 s, placeholder) or wash | feathers | 1 | doc 01 "Corruption sources" |
| `strange_seeds` | Corruption source in a plot | pull them (3 s, placeholder) | footprints | 1 | doc 01 "Corruption sources" |
| `scarecrow_moved` | a scarecrow stands elsewhere facing the farmhouse; never dangerous | none needed | none | 0 (free, daily, section 13) | doc 01 "Scare moments" |
| `pumpkin_gnaw` | the Prize Pumpkin drops one size | none this season (a lost size stays) | teeth marks | 3 | doc 01 "Daytime Threats" |
| `generator_kill` | the generator is left dead | refuel, 6 s (doc 02 section 14) | none | 4 | doc 01 "Nights" |

- **Budget.** The AI Director spends the day's disturbance count (doc 02 section 11). Day 1-2 the
  budget is 1 and can only be `trample` or `stolen_tool` ("evidence of sabotage only", doc 01
  "Day arc"). The cost points above are `placeholder`s and `sim` tunes them against the clearing
  rates (doc 01 "Targets").
- **The pool opens by day,** matching doc 02 section 11: Corruption sources from day 3; pumpkin gnaw
  from day 3; generator kill from day 4; fences from day 2 (placeholder: doc 01 lists fences
  without a day).
- **Placing.** Each disturbance is placed by the AI Director in a region, not at a player's
  position (section 11.6), and is a thing the players can find by looking: fresh clues
  (footprints, claw marks, moved scarecrows) (doc 01 "Daytime Threats").
- **Stolen tools** are placed next to an armed `trap_spot` 60% of the time (doc 01 "often";
  placeholder).
- **Trample (rule restated).** One plot at dawn per night; two if no living player spent 30 s outside
  that night; +1 if the generator is dead at dawn (doc 02 section 14, doc 01 "Daytime Threats").
- **Dawn trample placement (P4-03; resolves Q-070 items 2 and 4; `placeholder`).** The count is the
  rule above. Which plots:
  1. Candidates are plots holding a living crop, plus (rule 4) bare plots only when too few crops exist.
  2. Pick without replacement, weighted by closeness to the creature's dawn position: weight
     `1 / (1 + d / 20)` where `d` is metres from the plot (20 m, so a plot at 20 m weighs half one
     under the creature). Nearest is likeliest, never certain.
  3. A plot trampled at an earlier dawn this season has its weight halved while it is still the
     same crop, so the same plot is not hit most dawns.
  4. Bare farm: if fewer living crops exist than the count, the shortfall is trampled bare plots
     (the plot is churned, nothing is lost: no coins, no replant seed spent) so the dawn report still
     shows the damage. Farm damage in coins counts crops lost only (doc 02 section 14).
  5. Never more than the count; a plot is hit once per dawn. The budgeted `trample` disturbance (cost
     2) uses the same placement but fires by day; the dawn trample fires at dawn only.
  The current build (nearest crops, bare plot never trampled, same plot most dawns) differs on
  rules 2 to 4. Gameplay change is flagged in QUESTIONS.md (Q-082).
- **Animals (P4-03, doc 02 section 10.1).** `broken_fence` lets 2 animals escape (from 6: chicken,
  pig, cow, 2 each), fixed by `repair_fence`; `pumpkin_gnaw` has no fix. Both are `enabled` in
  `sabotage.json` from P4-03 (`broken_fence` opens day 2, `pumpkin_gnaw` day 3).
- **Unattended farm.** Doc 01 "The longer nobody is outside, the more wrecked the farm". The
  trample count is raised by 1 for every 60 s of the night with
  nobody outside after the first 30 s, capped at +3 (placeholder; doc 02 section 14 gives only the
  30 s "nobody outside" rule and 2 plots). Settle in the simulator.
- **Gnaw rule** (resolves Q-015 item 9, D-017). From day 3, on a night where no living player is
  within 20 m of the Prize Pumpkin at any time (doc 01 "Daytime Threats", and the circle contents
  in doc 04 sec 8.5), the pumpkin drops one size in the morning. The creature gnaws only when the
  AI Director spends gnaw points. One gnaw per night. A dead player does not count as guarding.
  The simulator should treat the rule as: "gnawed on any night with no living player within 20 m of
  the pumpkin for the last 60 s of the dusk-night window" (placeholder, 60 s).
- **Every disturbance has a fix** is checked by a data test: each record has a `fix` field
  (section 19).

## 11. The AI Director

The AI Director is the pacing system (doc 01 "AI Director"). It runs only on the host. It decides
**when and where** the creature gets presence, which scares and lures play, and which players they
land on. **It is limited:** hunting uses only the creature's senses and Corruption; the AI Director may
nudge hunting to a **region**, never a position; presentation (lure targeting, scare timing,
hallucinations) may use true positions (doc 01 "Hunting and presentation").

### 11.1 Tension meter

Left 4 Dead style (doc 01 "AI Director"): build-up, peak, fade, relax.

| Meter input | Per event | Source |
|---|---|---|
| Players outside, per second at night | +0.4 / s each, capped at +1.2 / s | placeholder |
| Player sprinting | +1.0 / s | placeholder |
| Noise heard by the creature | + (radius_m / 10) per emit, except `step_*` kinds, which count at most +1 / s per player | placeholder |
| A lure worked | +10 | placeholder |
| Jumpscare played | -30 and a 45 s `relax` | placeholder |
| Trap sprung | +15 | placeholder |
| Meter decay in `relax` | -3 / s | placeholder |
| Meter range | 0 to 100 | placeholder |
| Phase thresholds | build-up below 70, peak at 70, fade after a peak ends, relax at 0 | doc 01 "AI Director" for the four phases; numbers placeholder |

- **Peak** lasts at most 20 s (placeholder) then `fade`; **fade** lasts until the meter is 30, then
  `relax` for a minimum 40 s (placeholder, doc 01 "release" after peaks).
- **Caps (P5-33, CEO STOP 6).** `fade` lasts at most `fade_max_s` 20 s and `relax` at most
  `relax_max_s` 40 s, then the night returns to build-up (placeholders). In the STOP 6 playtest a
  group talking outdoors kept feeding the meter, so it never fell to 30 or 0: fade and relax held
  63 to 79% of the night, and the creature, which may not stalk or chase there, went after the
  group only 1 to 2 times a night. With the caps: 49 to 55% and 4 to 5 times
  (`tests/creature/test_p5_33_night.gd`, seeds 1 to 3).
- The meter is one number per session, plus a per-player **scare debt** (section 11.3).

### 11.2 Profiles

Three profiles (doc 01 "AI Director"): `day`, `night`, `harvest_moon`. Each sets the allowed
presence events per player in each phase (tunable, in `ai_director.json`).

| Profile | Build-up | Peak | Fade | Relax | Source |
|---|---|---|---|---|---|
| `day` | `lurk` presence 1 event / player, no chase | one jumpscare or trap race allowed | none | none | doc 01 "By day" |
| `night` | 2 events / player, lures, traps, stalks | stalk to chase, 1 chase / player | retreat, ambience returns | calm, insect bed | doc 01 "AI Director" |
| `harvest_moon` | scripted by act (section 14) | guaranteed peak in the gate run, then release | n/a | n/a | doc 01 "Harvest Moon" |

Event counts per player in the table are `placeholder`s, as doc 01 says only "tunable".

**`harvest_moon` fields (P4-03, `ai_director.json` `profile_harvest_moon`, `placeholder` except where
doc 01 is cited):** `uses_tension` false (doc 01); `knock_cooldown_s` 15; `knock_stall_s` 5;
`gate_run_m` 30; `gate_run_guaranteed_peak` true (doc 01); `hallucinations`, `lures` and
`ordinary_traps` false; cart speed `cart_speed_1p_mps` 1.0, `_2p_` 1.6, `_3p_` 2.0, `_4p_` 2.4
(doc 02 section 9).

### 11.3 Day arc

Doc 01 "AI Director > Day arc": thirds of the day clock (540 s, doc 02 section 3 -> 180 s each).

| Third | Window | Allowed | Source |
|---|---|---|---|
| 1 calm | 0 to 180 s | evidence of sabotage only: disturbances placed, no presence | doc 01 "Day arc" |
| 2 low presence | 180 to 360 s | stalks, lures (targeted), fake-outs; no jumpscare | doc 01 "Day arc" |
| 3 builds to dusk | 360 to 540 s | rising presence; jumpscares, wrong count, whisper; day-death conditions can trigger | doc 01 "Day arc" |

The calm window is for farming, so it also keeps the creature out of 25 m of the field the group
works in (placeholder).

### 11.4 Scare rules

Doc 01 "AI Director > Scare rules".

| Rule | Number | Source |
|---|---|---|
| Max big scares per player per day | 1 | doc 01 |
| Min gap between two big scares on the same player | 2 min (120 s) | doc 01 |
| A player not yet scared today | is more likely picked | doc 01; weight 3 : 1 vs scared (placeholder) |
| Private events (targeted lures, hallucinations, wrong count) | count toward both limits | doc 01 |
| Public events (fake-outs, crow bursts, scarecrow moved) | do not count | inference: doc 01 limits "big scares" |
| Big scare list | jumpscare, the whisper, the shed, the trap (not a race), wrong count, hallucination, your-own-voice | doc 01 "Scare moments" |

**Daily variation.** At dawn the AI Director rolls the day's "deep" (8 to 12 m), "earshot" (18 to 28
m) and trap race distance (section 7), and the day's scare targets. It never adds a death
condition (doc 01 "Day Deaths").

### 11.5 Private events, town stand

| Rule | Detail | Source |
|---|---|---|
| Private events | go to one player only (`apply_scare` with a target slot, doc 06 section 7) | doc 01 "Voice mimicry" |
| Town stand | within 10 m of the town stand: lures, scares, stalk picks, Harvest Moon knock-offs and kills on a player there are less likely, never impossible. Each goes ahead on a won roll at its `ai_director.json` `town_stand` multiplier (placeholders: lure 0.25, scare 0.25, stalk 0.5, knock-off 0.25, kill 0.4; one roll per kind and player per night, D-116). A player there still counts as outside for the "Unattended farm" term | doc 01 "Town stand"; D-115; doc 04 sec 8 |
| Targeted day lure | only the target hears; no teammate within 15 m of the **source** (the lure's origin) | doc 01 "Voice mimicry" |
| Dawn Report | replays targeted lures | doc 01 "Dawn Report" |

### 11.6 Region-only nudges

The farm is cut into **regions** (data, doc 04 markers): `yard` (barn, farmhouse, generator, well,
shed), `field_a`, `field_b`, `corn_ring_north`, `corn_ring_south`, `corn_ring_west`, `corn_ring_east`,
`pen`, `moonflower`, `pumpkin`, `town_road`. Region bounds come from doc 04's clearing and ring and
are `placeholder`. Regions are `Area3D` nodes in the level scene; adjacency is computed at load
(regions within 2 m are linked); a nudge moves one hop (Q-018, D-021).

- A nudge sets the creature's **wander region**, never a goal point or a target. The creature
  then hunts inside the region with senses.
- The AI Director may move the creature's region toward where the most players are (their true
  region is allowed for presentation, not hunting). This is allowed only as a region: doc 01
  "Hunting and presentation".
- Nudge cooldown 20 s (placeholder).
- **Stand nights (D-116).** At nightfall the AI Director rolls `town_stand.reach_night_chance`
  (placeholder 0.5). On a stand night, while a living player is within the town stand radius, the nudge
  jumps straight to that player's region (`town_road`) instead of one hop: the stand is about 100 m from
  the farm, and hops would outlast the scripted stalk (section 18). The section 11.5 stand rolls still
  gate the stalk pick and the kill, so the guard is reached on some nights and dies on fewer
  (target about 1 night in 10, placeholder: 0.5 x `stalk_mult` 0.5 x `kill_mult` 0.4 at most). The roll
  hold `reroll_s` is one night (300 s), so a guard who stays is not re-rolled until the stalk wins.

### 11.7 Debug

The debug view draws the true creature, players, each player's `sensed` marker and the region, the
meter and the phase (doc 01 "Hunting and presentation"; owner doc 05 / AI Programmer).

### 11.8 As built (P3-04)

`game/ai_director/ai_director.gd` (node `AiDirector`, group `ai_director`, added by `main.gd` before the
Creature) runs on the host only; the pure rules are in `director_logic.gd` and checked by
`tests/creature/test_director_logic.gd`. All numbers come from `ai_director.json`.

- **Meter.** Inputs as section 11.1: players outdoors at night, sprinting, the Creature's new `heard`
  signal (noise that passed its hearing check), `lure_result.worked`, trap sprung, and `jumpscare(peer)`
  for P3-05. It logs `tension` (`value`, `phase`, `profile`) every 10 s.
- **Fade decays.** Inference: the meter decays in `fade` at the `relax` rate, else a quiet fade never
  reaches `fade_to`. Doc 01 does not say; a playtest of a peak settles it.
- **Gating.** The Creature asks `allow(kind, peer)` and then `spend`s it. Night `lure` and `stalk` are
  build-up events (2 per player per build-up, `profile_night`); a stalk is also allowed at peak.
  A `chase` is allowed only at peak (1 per player per peak). Inference: the table's "stalk to chase" at
  peak is read as "chases only at peak"; outside peak the creature holds the stalk. The scripted first
  night (section 18) is not gated.
- **Day arc.** Third 1: no day lure, and the day cover keeps `calm_field_keepout_m` (25 m) from the
  field region holding the most players. Day lures start in third 2, every `lures.day_gap_s`.
- **Scare budget.** A day lure is a private event: the target is picked among outdoor living players
  that pass `scare_ok` (1 per player per day, 120 s apart), weighted unscared 3 : 1. Counts reset on
  `Clock.day_changed`.
- **Town stand (P4-34, D-115).** For a player within the stand radius (farm.tscn `Sanctuary` marker
  `radius_m`, else `town_stand.radius_m`) `allow` adds a `stand_ok(kind, peer)` roll for `lure`,
  `day_lure`, `stalk`, `scare` and `kill`, after the profile has allowed the event; a chase is not rolled
  (the kill at its end is). The creature asks `stand_ok` itself for the scripted night's stalk pick and
  lure and for a Harvest Moon knock-off. A roll is won at `town_stand.<kind>_mult`; one roll per kind and
  player holds `reroll_s` (300 s, one night, D-116), so asking every frame cannot wear it down. Rolls use
  their own seeded stream (`seed + 7`; scares use `seed + 5`) and log `town_stand_roll` (`kind`, `player`, `won`). A chase that reaches its target
  on a lost kill roll ends as `retreat` / `town_stand` and the player lives; on a won roll the player dies
  as anywhere else. `tests/creature/test_p4_34.gd` checks both. `roll_stand_night()` sets `stand_night`
  at nightfall and logs `town_stand_night` (`day`, `reach`); `_nudge` reads it (section 11.6, D-116).
- **Daily roll.** At start and at each dawn (for the next day) it rolls `deep_m`, `earshot_m`,
  `trap_race_m` and `deep_trap_race_m` and logs `daily_roll`. A normal trap race keeps a floor of
  (pry hold + `min_spare_s`) at the approach speed, 21 m; a deep trap has none. `trap_race.gd` reads the
  roll. `deep_m` and `earshot_m` are only rolled and logged: nothing reads them until the day deaths.
- **Regions and nudges.** `build_farm.py` places the eleven regions as `Area3D` boxes (group `regions`,
  placeholder bounds tiling the clearing). Boxes within `link_m` (2 m) are linked. Every 20 s in a night
  build-up the wander region moves one hop toward the region with the most living players; `nudge`
  logs `from`, `to`, `toward`. The Creature's lurk wanders among cover and trap spots inside the region.
- **Not built.** Nightmare numbers and the `harvest_moon` profile (P3-06 and later); trap setting is not
  gated (the night's counts come from `ramp_up.json`); scares themselves are P3-05.
- **Debug view.** Region boxes (the wander region filled), and a line with tension, phase, profile,
  third and region over the tension graph.

## 12. Voice mimicry

Doc 01 "Voice mimicry". Playback is doc 06's `apply_lure`; **choosing** is here.

### 12.1 Choosing a lure

| Step | Rule | Source |
|---|---|---|
| Kind | clip lure (a recorded line), sound lure (`sound_id`: faked footsteps, tools, watering cans, hoes) or generic voice ("stranger") | doc 06 section 7 `apply_lure`; doc 01 "Material", "Habits" |
| Who is voiced | a player whose setting is `lobby_lines` with a line; **never** an Off or unchosen player: they get footsteps and tools only; generic voices only for unattributed "stranger" calls | doc 01 "Habits"; doc 06 section 11 |
| Whose voice | favors the dead (a dead player's lines, more often); rarely uses the target's own voice on them | doc 01 "Voice mimicry"; weight 3 : 1 : 0.1 dead : alive : own, placeholder |
| Day | targeted: only the target hears; no teammate within 15 m of the source (the "15 m rule", doc 04 sec 8.3) | doc 01 "Voice mimicry" |
| Night and chase | world sounds (everyone hears) | doc 01 "Voice mimicry" |
| Dead-voice twist | night lures in a dead player's voice are world sounds, with the ghost's static; static plus flicker = real | doc 01 "Ghosts" |
| Dead voices | used more often than live voices | doc 01 "Voice mimicry" |
| Exactness | exact clips through day 3; spliced clips from day 4 | doc 01 "Ramp-up" |
| Splice | joins two live clips of one owner, cut at the word break (the clip's own silence gap, or the middle of the clip if none); a lure reuses at most 2 segments: the head of the chosen clip up to its break, then the tail of another clip of the same owner from its break | doc 01 "Ramp-up" (splicing), "Build Plan > Phase 5" (spliced clips from live speech, P5-03); the cut rule is a placeholder (section 12.4); the `splice_master` trait (section 22) lifts the cap to 3 |
| Position | the source is the point the creature wants the target to go **to**: in a trap spot (day) or toward a cover point (night) | doc 01 "Voice mimicry" (inference) |
| The 15 m rule | day lures need a source position 15 m or more from every teammate of the target. Pairs in one field are always within 15 m (doc 04 sec 8.3), so field lures come from the corn edge on the far side; the yard's generator and well are 23 m and 32 m from corn, so yard lures come from yard corn edges | doc 04 sec 8.3 |

### 12.2 Tells

- Each fake gets at most **one** random giveaway: `echo` (180 ms, -18 dB), `pitch_up` or
  `pitch_down` (+/-6%), `no_crackle` (a walkie voice without radio crackle) (doc 01 "Voice mimicry",
  doc 06 section 8).
- About a **third** have none (doc 01); **Nightmare** always none (doc 01 "Nightmare").
- Always from a place **the teammate could not be** at that time: the host picks the source
  position outside any reachable area for that teammate (for example the corn on the far side of a
  fence, a cover point 25 m or more from the teammate) (doc 01 "Voice mimicry").
- **Passwords** work only until overheard (doc 01 "Voice mimicry"): the host marks a password as
  burned if a living player says it within the creature's voice radius.

### 12.3 Success and logs

- **A lure worked** if the target moved more than 10 m toward the source within 8 s (doc 01
  "Voice mimicry"). `lure_played` logs the id and fields in CONTRACTS section 10 / doc 06 section 14.
  `lure_result` logs `moved_m`, `within_s`, `worked`.
- **DD Phase 1 gate:** at least 30% of lures make the target walk toward them (doc 01 "Build Plan").
- **Never tell players the line list is the whole pool** (doc 01 "Habits").
- **Staging:** the lantern blows out (never flickers) before "help me"; a bang on the door before
  "over here" (doc 01 "Recording"). The same staged moments are used in play for those two lines as
  the AI Director's build-up (placeholder reading).

### 12.4 As built (P2-04)

`game/creature/creature.gd`, host only, until the AI Director (DD Phase 3) takes over the timing.

- **Whose voice.** One weighted pick among the stranger (weight 1, placeholder) and every player in
  the session: dead 3, alive 1, the target's own 0.1 (12.1). Since P3-03 the weights are
  `ai_director.json` `lures` and the rule is `creature_logic.gd` `voice_weight`; `lure_played` logs
  `owner_dead`. A dead owner's night lure sends `ghost` true (the ghost static chain is P3-10). A player voices a **clip** only with
  `lobby_lines` and a fitting clip the host holds: the phase's lines from section 16 (day:
  `come_look_at_this`, `i_found_something`, `its_fine_come_on`, `wait_for_me`; night: `over_here`,
  `help_me`, `where_are_you`, `wait_for_me`, `its_fine_come_on`; placeholder reading of the "Day or
  night use" column) or the target's `name:<uid>` (not in the target's own voice). Barn chatter is
  never used. Anyone else (Off, unchosen, a bot) gets a **sound lure** in their place:
  `step_walk_fake`, `step_run_fake` or `door_fake` (`hoe_fake`, `watering_can_fake` and
  `shovel_fake` wait for sounds).
- **Source.** Day: a trap spot; night: a crow corn edge or a cover point; 12 to 40 m from the
  target, nearest first. Night with company: within `trap_lure_m` of an armed trap (Phase 1 rule).
  Day: 15 m from every living teammate of the target. A living voiced teammate other than the
  target: 25 m from the source (12.2). No place for the chosen voice: the stranger from any place.
- **Day.** From the start of the day's second third (11.3), one attempt every 90 s (placeholder) at
  a random living outdoor player; sent to the target only; the creature stays in cover (no state
  change). The town stand and the scare budget (11.4, 11.5) wait for the AI Director.
- **Night.** As Phase 1 (section 4.2 lurk to lure), sent to everyone (target slot -1), the host
  included (`apply_lure` is `call_remote`, so the host plays its share locally).
- **Tells.** Voice lures (clip, stranger): a third none, else one of `echo`, `pitch_up`,
  `pitch_down`, `no_crackle`. Sound lures: none (inference: tells are voice giveaways).
- **Exactness.** Days 1 to 3 play exact clips. From the first day whose `ramp_up.json` `voice` is
  `spliced` (day 4, doc 01 "Ramp-up"), every clip lure whose owner has 2 or more clips on the host
  is spliced (P5-03): the chosen clip's head up to its word break, then the tail of another of the
  same owner's clips (picked at random) from its word break. Only that owner's clips are used, so a
  splice obeys the same voice setting as an exact clip (doc 01 "Voice settings"); an owner with one
  clip gets the exact clip. The extra random draw happens only on the splice path, so days 1 to 3
  keep their seed stream.
- **Word break** (`VoiceSplice.word_break`, placeholder): the middle of the longest run of 2 or more
  frames whose Opus packet is no bigger than half the clip's median packet, ignoring the first and
  last 5 frames (the talk-start pre-roll and the voice activity hang); no such run, the middle of
  the clip. Packet size stands in for loudness, an inference: variable-bitrate Opus spends few
  bytes on silence, and TwoVoIP has no standalone decoder to measure the samples. A listening test
  of spliced lures would settle the thresholds.
- **Wire.** `apply_lure.source` stays a String: `"stranger"`, `"sound:<sound_id>"`,
  `"clip:<owner_peer>:<clip_id>"` for an exact clip, or `"clip:<owner_peer>:<spec>"` for a splice,
  where `<spec>` is `<clip_id>@<first_frame>+<frame_count>` segments joined by commas (at most 2;
  for example `clip:1:live_1@0+75,live_0@30+31`). Doc 06 section 12 describes a dictionary with a
  segment list; the string carries the same list (raised in P2-04's and P5-03's handoffs). A
  hearer refuses a malformed spec or a segment past its clip's end (`lure_skipped`, `missing`). Each hearer checks the owner's setting at play time and plays the clip from its store
  at the source on the tell's bus (`VoiceChain`), positional like a voice (`VoiceEmitter` unit size
  and range); a clip freed on Off stops at once (`lure_stopped`); a missing one logs `lure_skipped`.
- **Logs.** `lure_played`: `lure_id`, `kind` (`clip`, `sound`, `stranger`), `owner`, `line_id`,
  `clip_id`, `sound_id`, `target`, `heard_by` (the target, or -1 for everyone), `position`, `tell`,
  `ghost`, `day`, `exact` (false for a splice), `segments` (`[[clip_id, first_frame, frame_count]]`:
  one whole-clip segment for an exact clip lure, two for a splice, null for other kinds). The Dawn
  Report replays a splice from these logged segments, so it plays the same cut. `lure_result` as Phase 1. `lure_fooled` when a clip lure worked.
  `check_logs.py` reports recorded (clip) against generic (stranger and sound) rates, read not gated
  (doc 09 section 3).
- **QA flag.** `-- --creature-walk` walks the local player round the yard and turns it toward half
  the lures it hears, with the real clock (so day lures happen).

## 13. Jumpscares, fake-outs, hallucinations and other scares

Doc 01 "Scare moments" and "Jumpscares". Make them land: **rare**, **built up** (silence, insects
cut, a nearby voice), **cost something**, AI Director **times and randomizes**, budget **audio over
model** (doc 01 "Make them land").

| Scare | What happens | Cost to the player | Build-up | Public or private | Count as big | Source |
|---|---|---|---|---|---|---|
| Jumpscare | a day lunge: ragdoll, dropped items, then the creature vanishes | Shaken 60 s; never Corrupts | insects cut, wind drops | private to the target + the screen of those in view | yes | doc 01 "Jumpscares" |
| Disarm lunge | when a player kneels to disarm a trap, a lunge cuts to black | Shaken 60 s if on a day trap | silence | private | yes | doc 01 "Scare moments" |
| The trap | a prying player looks up and sees it watching | none besides the pry | the signature sound approaches | private | yes | doc 01 "Scare moments" |
| The shed | the player is inside the shed, the door slams | locked 5 s (placeholder) | a bang outside | private | yes | doc 01 "Scare moments" |
| The whisper | a teammate's voice right behind the player while the teammate is across the field | none | silence | private | yes | doc 01 "Scare moments" |
| Your own voice | very rare, once a season at most per player | none | silence | private | yes | doc 01 "Scare moments" |
| Fake-out | a crow bursts from the corn | none | rustle | public | no | doc 01 "Scare moments" |
| Hallucination | from day 5; a distant silhouette | no knockdown, no cost; Corrupted players see more (x2) | insects cut | private | yes | doc 01 "Ramp-up" (day 5), "The Corruption" |
| Wrong count | rare; an extra farmer in a teammate's hat at the corn edge | none | silence | private | yes | doc 01 "Scare moments" |
| Scarecrow moved | a new spot each morning, facing the farmhouse; never dangerous | none | none | public | no | doc 01 "Scare moments" |
| Whistle | an honest warning whistle (Nightmare keeps it honest) | none | none | world | no | doc 01 "Nightmare" |

- **Rarity.** At most one wrong count and one own-voice scare per team per day (placeholder). The
  AI Director rolls the rest from its profile (section 11).
- **Jumpscares never occur during a trap race,** where the creature's reach is the kill (section 7).
- **Jumpscares do not occur** in a lit building, or within 20 s of another big scare on the same
  player (the 2-min rule, section 11.4). At the town stand they are less likely (section 11.5).
- **Hallucination placement** uses true positions (presentation, section 11); the silhouette stands
  15 to 30 m away, in a place the player can see (placeholder). It disappears when looked at for
  1.5 s or when the player moves 5 m toward it.
- **Scarecrow moved:** to one of `scarecrow_03` to `_07` (doc 04); never the one closest to a
  player; faces the farmhouse; never within 4 m of a trap spot (placeholder).
- **Fake-outs** use `crow_01` to `_09` perches (doc 04) and are not a state tell (section 4).
- **Ghosts** (doc 01 "Ghosts"): see the creature as a smeared silhouette within 20 m (doc 04 sec 8.4),
  else only by animals and crows; never see traps; flicker lanterns (only ghosts flicker); rustle
  corn (the creature can fake rustling); static voices; one crow possession a night for 20 s; the
  creature ignores crows but sends fake ones.

### 13.1 As built (P3-05)

`game/ai_director/scares.gd` (node `Scares`, added by `main.gd` after the Creature) runs on every peer.
The host picks and applies scares; every peer plays the build-up and the scare it is sent. Numbers come
from the `scare_*` records in `ai_director.json`; `director_logic.scare_weight_of` (unit-tested) opens a
record by `opens_day` and `from_third` and applies `tainted_mult`.

- **Timing.** Every second the host tries the living human players in a seeded random order (bots
  are skipped: nobody sits behind them to be scared). A player gets a scare only when the AI Director
  allows a big scare (`allow(&"scare", peer)`: third 2 or 3, phase peak, the per-peak count, 1 per day,
  120 s apart, a won town stand roll at the stand) and a roll of `SCARE_CHANCE_PER_S` (0.05, placeholder: a 20 s peak
  scares a player about 2 times in 3) hits, so a peak does not always bring one ("rare", "randomizes").
  A player already in a build-up is skipped. The kind is a weighted pick among the open records that fit
  where the player is. Inference: scares wait for a day peak, so they stay rare. The
  P3-04 run reached a meter of only 44 in the day, so a day peak may never happen; a playtest (Game
  Designer) settles whether the day needs its own peak or scares should also fire in build-up.
- **Where each fits.** Jumpscare: outdoors (no building at all, lit or dark: inference, doc says lit),
  no trap race on, the Creature not chasing. Shed: inside `ToolShed`; the door slam plays at its door.
  Whisper: a living teammate on Lobby lines at least 25 m away (`COULD_NOT_BE_M`) with a fitting clip;
  the clip plays 1.2 m behind the target through the lure clip player. Own voice: the target's own clip,
  `own_voice_per_player_per_season` (data reads per player per season, the table above says per team per
  day; data wins). Wrong count (`wrong_count_per_team_per_day`) and hallucination: outdoors, with a crow
  perch or creature cover point 15 to 30 m away within 60 degrees of the player's facing (inference for
  "a place the player can see"; walls and corn are not checked).
- **Build-up.** Two sends. The host first sends `apply_scare(&"buildup", ...)` with the kind in
  `extra`; the target's machine (every machine for a public scare) plays the build-up. `Soundscape.hush`: the insect bed off and the wind 12 dB down for the build-up (3 s,
  placeholder), then the layers return unless the creature is stalking or chasing. Doc 08 section 4.4
  rule 1 only lets creature state lower layers; hush is a second path, to be added to doc 08 in P3-08.
  The shed's build-up is `cre_door_bang` outside; the fake-out's is a corn rustle and no layer change.
- **Check again.** After the build-up the host checks the target is still alive and, unless the dev
  console forced it, that the kind still fits and the AI Director still allows it. If not, it logs
  `scare_dropped` (`kind`, `target`, `why`), sends nothing and spends no budget: the hush lifts on its
  own. Otherwise it spends the budget, sends the scare (played at once), applies the cost and logs `scare`.
- **Cost.** a jumpscare (and a disarm lunge) calls
  `TrapRace.shake` (Shaken 60 s, never Corruption) and the AI Director's `jumpscare(peer)` (meter -30, a 45 s
  relax). A jumpscare drops the held can. The shovel and a held trap are not dropped (not built).
  The shed's "locked 5 s" is a 5 s freeze through `player.shake(5, 0)` (placeholder until a door lock
  exists); a Shaken it interrupts carries on for its remaining time afterwards.
- **Disarm lunge.** When a player starts the `disarm_bear` hold and the AI Director allows a big
  scare, the hold is cancelled and the lunge plays: two corn parts, the lunge sound, 1.5 s of black.
- **Fake-out.** Each second a roll of `FAKE_OUT_CHANCE_PER_S` (1/240, placeholder: about one every 4
  minutes) bursts a crow from the perch nearest a living outdoor player, while its record is open.
  Inference: doc 01 does not say when fake-outs fire; at random, so they tell the players nothing.
  Public, not big, day or night.
- **Presentation.** A placeholder capsule: the creature tall and black, a farmer brown (no hats yet, so
  no teammate's hat on the wrong count). It goes after `vanish_look_s` looked at (camera within about
  14 degrees), after `vanish_approach_m` walked toward it, or after 20 s. The jumpscare shows a creature
  capsule for 0.4 s with the knockdown camera.
- **Network.** `Net.apply_scare(scare_id, target_slot, position, extra)`: a private scare goes to the
  target only (nothing to send for a bot), a public one to all. Every scare logs `scare` with `kind`,
  `target`, `big`, `private`, `day`, `third`, `position`; a client logs `scare_applied`.
- **Not built.** The trap (a pry only happens in a trap race, which the doc rules out, so nothing
  triggers it); scarecrow moved (weight 0, P3-06 sabotage). The stingers in doc 08 section 5.4 are in the
  Soundscape catalog but have no files until P3-08, so the scares are silent apart from the hush.
- **Dev console.** `day <n>` sets the day; `tension <n>` sets the meter; `scare <kind> [peer]` plays
  one now, past the AI Director and the where-it-fits rules, and names the rule it forced past. It
  refuses a kind that is not built and a dead target.
- **Not yet (doc 03 section 13).** The jumpscare on the screens of others in view, the creature
  vanishing, and its state change after a jumpscare (drop the stalk, then Retreat, as doc 08 expects).
- **Crows (P5-33, CEO STOP 6: "show crows more often", no louder).** Besides the still crow on each
  of the nine `crow_perches` (P5-27), the host sends two kinds of silent flock by day and dusk, timed
  by `ai_director.json` `crows` on their own seeded stream (`seed + 6`), so the scare rolls are
  unchanged. A **flyover** (every 40 to 90 s) is a line of 3 to 6 crows crossing 140 m over the fields
  at 18 to 25 m up and 9 m/s. A **landing** (every 60 to 120 s) brings 3 to 6 crows down on a
  `plot_spots` field marker; they sit for 20 to 40 s, or fly off when a living player comes within
  8 m. All numbers are placeholders. They are not scares: no budget, no build-up, no sound, never a
  state tell (section 4.2), and they log `crows` (`kind` flyover or land, `count`, `position`). They
  go out as public `apply_scare` sends (`crow_flyover`, `crow_land`), and every peer draws the same
  flock from the message. A fake-out burst now empties its perch: the still crow there is hidden
  for `perch_empty_s` (60 s), so the burst is the crow that was sitting there (the P5-27 finding).
  A day measure (`tests/creature/test_p5_33_crows.gd`, seed 1) gives 8 flyovers and 5 landings in
  600 s of day and dusk, against none before.

### 13.2 As built (P3-09): ghost powers

`game/ghost/ghost_powers.gd` (Gameplay) holds the rules; doc 05 section 14 lists the messages. What
touches the creature side:

- **Corn rustle.** A sound only (`sfx_step_corn` at the ghost's spot, inside the corn): the host emits
  no `Noise`, so the creature never hears it. Players cannot tell it from the creature's own rustling
  (doc 01 "Ghosts").
- **Crow.** One per ghost per day number (inference for "a night"), 20 s (doc 01), at a `crow_perches`
  marker; the perch is the crow (no crow model yet). A caw is a sound (`sfx_crow_caw`, no file until
  P3-08) and no `Noise`. The creature does not react: it "ignores crows" (doc 01). Not built: the
  creature attacking a possessed crow (`dead_crow`, doc 05 section 14) and fake possessed crows.
- **Ghost sight.** Local only: the creature mesh is shown to a ghost within 20 m of its camera (doc 01,
  doc 04 section 8.4), 30 m from a crow (inference: the crow must add sight), at 0.6 transparency as a
  placeholder smear. All `trap_spots` markers are hidden from a ghost. Not hidden: a trap hung on the
  pegboard and a trap a living player carries.
- **Lantern.** A ghost may use a lit light within 15 m of a living player (`placeholder`); a blown-out
  lantern is below 5% and never answers (section 20).

## 14. Harvest Moon acts

Doc 01 "Harvest Moon". No timer; a hard cap of 15 min (900 s, doc 02 section 3) after which the
cart counts out only if it is past the fields (x > 78, doc 04 sec 6).

| Act | Rules | Source |
|---|---|---|
| 1 Loading | the Prize Pumpkin is brought to the barn at dusk; load the cart in the lit barn; then the generator fails, the barn goes dark and unsafe | doc 01 "Harvest Moon" |
| 2 Push | the cart has a lantern; it squeaks; its speed depends on pushers; the creature knocks pushers off; each stall lets it bite the pumpkin one size, at most 2 bites per escort; ghosts can flicker the cart lantern | doc 01 "Harvest Moon" |
| 3 Gate run | a guaranteed peak, then release | doc 01 "Harvest Moon" |

- **Profile.** The `harvest_moon` profile ignores tension thresholds; the AI Director follows the
  acts (section 11.2).
- **Knock-offs.** The creature attacks the pusher it senses loudest (section 3.1). One knock-off
  per 15 s at most (placeholder, `harvest_knock_cooldown_s`). A pusher within 10 m of the town stand
  is knocked off only on a won `town_stand.knock_off_mult` roll, and killed only on a won
  `kill_mult` roll (section 11.5, D-115); the stand is never a safe zone for the cart.
- **Nobody pushing.** While the cart is in act 2 or 3 and nobody pushes it, the creature goes for
  the living player it senses nearest the cart (sensed positions only, section 3) and chases them
  as at night: a catch kills. The knock-off cooldown and the stall bites are unchanged, and the
  lit-building rule and the town stand rolls still hold (sections 6 and 11.5). In act 2 an unpushed cart lets
  the AI Director allow that chase. Source: the CEO's Harvest Moon test, where players stopped
  and started pushing and the creature stood off (P4-25).
- **The gate run** is the final 30 m of the route (R7 to the gate, doc 04 sec 6.1, 3.7 m from corn
  at the pinch), where the creature gives a chase `chase_speed_mps` against a cart speed of
  1.0 to 2.4 m/s by pushers (doc 02 section 9, `profile_harvest_moon`). The peak ends when the cart reaches the gate (x > 105) or the cap
  passes.
- **Hallucinations, lures and ordinary traps** are off during acts 2 and 3 (placeholder, to keep
  the beat clean).

## 15. Bodies of the dead and ghost hand-off

"Bodies" here covers the dead player's body (the creature's bodies are in section 2).

- **Death** (day or night) is host-decided and resolved in the victim's favour (doc 01 "Close
  calls"). The victim becomes a **ghost** until dawn (doc 01 "Ghosts"); the medical bill applies
  (doc 02 section 8).
- **The body.** A death leaves a ragdoll at the place (the victim's last position) until dawn. At
  dawn it is removed (doc 01 shows no rule; placeholder; settle by playtest). A body is
  **not** a Corruption source (inference: doc 01 lists the sources and does not include it).
- **Finding a body** is not a scare. It lets the others see where the death was and reads in the
  Dawn Report (section 17).
- **Cause of death** stored for the Dawn Report: `trap_race`, `deep_corn`, `night_chase`,
  `night_trap`, `harvest_moon` (placeholder ids).
- **Ghost hand-off.** The ghost sees the creature as a smeared silhouette within 20 m (section 13);
  its voice carries static; dead voices are used more by the creature (section 12).
- **Death at the town stand** is less likely, never impossible (section 11.5, D-115).

## 16. Voice-line list

`voice_lines.json`. The seven fixed lines (doc 01 "Recording > Lines") plus a name per teammate
(doc 06 section 11). **Never tell players the list is the whole pool** (doc 01 "Habits").

| Id | Text | Staged moment | Day or night use | Source |
|---|---|---|---|---|
| `over_here` | "over here" | a bang on the door first | lures toward a cover point | doc 01 "Recording" |
| `help_me` | "help me" | the lantern blows out first | the strongest lure; at night | doc 01 "Recording" |
| `come_look_at_this` | "come look at this" | none | day lures to a trap spot | doc 01 "Recording" |
| `i_found_something` | "I found something" | none | day lures to a trap spot | doc 01 "Recording" |
| `where_are_you` | "where are you?" | none | calls to make a lone player answer | doc 01 "Recording" |
| `wait_for_me` | "wait for me" | none | pulls a leaver back | doc 01 "Recording" |
| `its_fine_come_on` | "it's fine, come on" | none | calms a player into walking | doc 01 "Recording" |
| `name:<player_uid>` | the teammate's name | none | a call by name | doc 06 section 11 |

**Staging cue and take scoring (P2-12):** each fixed line has `staging_cue` in `voice_lines.json`: `door_bang`
(`over_here`), `lantern_out` (`help_me`, blows out, never flickers), else `none`. The record `take_scoring` holds the
doc 06 s11 weights (`placeholder`): score = 1.0 x mean dB of voiced frames + 3.0 x standard deviation of the pitch
in semitones, 2 to 3 takes per line. Starting point: the two terms span about 20 and 15 points on a normal voice.
A recorded session settles it.

**Chase and lure constants (P2-12, Q-048 (1)):** `creature.json` `chase_tell_s` 2 (no lunge in a chase's first
2 s), `scripted_standoff_m` 18 (scripted stalk holds past `sight_night_m` 15), `trap_lure_m` 15 (a source within
15 m of an armed trap may lure a player who is not alone). All `placeholder`; a playtest settles them.

**Generic ("stranger") voice lines** (unattributed, for Off players' teams and DD Phase 1, no real
voice; synthetic only). Doc 01 "Habits" and doc 06 section 7 allow generic voices as "stranger"
calls:

| Id | Text |
|---|---|
| `stranger_over_here` | "over here" |
| `stranger_help` | "somebody, please" |
| `stranger_anyone` | "is anyone out there?" |
| `stranger_come` | "come quick" |
| `stranger_lost` | "I'm lost" |
| `stranger_hello` | "hello?" |

(Texts are `placeholder`; the audio is synthetic and generated outside the repo's voice rules.)

**Sound lures** (no voice, `sound_id`): `step_walk_fake`, `step_run_fake`, `hoe_fake`,
`watering_can_fake`, `shovel_fake`, `door_fake` (doc 06 section 7; Off players get these).

## 17. Dawn Report templates

`dawn_report_templates.json`. Doc 01 "Dawn Report". Order: cash-in, bill, payment, farm damage
(doc 02 section 9), then the newspaper card (skippable). Voice replays follow each owner's setting;
Off players appear as text plus sound (doc 06 section 11).

### 17.1 Headlines

| Section | Template (`{...}` is filled) | Source |
|---|---|---|
| Best Impression | "BEST IMPRESSION: the creature as {owner_name} said '{line_text}' and {target_name} walked {moved_m} m toward it." | doc 01 "Dawn Report" |
| Most Wanted | "MOST WANTED: {owner_name}, last seen {place_name}, wanted for questions about {fake_count} calls." | doc 01 "Dawn Report" |
| Cause of Death | one obituary per death (below) | doc 01 "Dawn Report" |
| Hero of the Night | "HERO OF THE NIGHT: {name} {hero_action}." | doc 01 "Dawn Report" |
| No deaths | "No obituaries this morning. The town is suspicious." | placeholder |
| Full wipe | "THE FARM WENT QUIET. Four chairs, no farmers." | placeholder |
| Lure replay | "{target_name} heard {owner_name} say '{line_text}'. {owner_name} was {owner_place}." | doc 01 "Dawn Report" (replays targeted lures) |

### 17.2 Obituaries (small-town style)

| Cause | Template | Source |
|---|---|---|
| `trap_race` | "{name} was pried loose from this life at {place_name}, a few seconds short. Survived by {n} unharvested plots." | doc 01 "Dawn Report" |
| `deep_corn` | "{name} took a walk in the corn alone and was missed, eventually, by {teammate}." | placeholder |
| `night_chase` | "{name} ran toward the barn lights. The barn lights were {distance} m away." | placeholder |
| `night_trap` | "{name} stepped on a thing that was not there yesterday." | placeholder |
| `harvest_moon` | "{name} gave the cart one more push." | placeholder |

### 17.3 Hero actions

`{hero_action}`: "disarmed {n} traps", "pumped the well for {teammate}", "carried the generator through",
"pushed the cart {m} m alone", "stayed outside while we hid" (one is picked by score; placeholder).
P4-03 moves the last two hard-coded lines out of `dawn_report_logic.gd` (Q-066 item 2, D-074):
`hero_freed` "pried {teammate} out of a trap" and `hero_refueled` "kept the generator fed".

The report also needs `most_wanted_one` ("... wanted for questions about 1 call.", used when
`fake_count` is 1), the Flags Placed card lines `flags_line` / `flags_line_one` / `flags_none`
("{name} planted {n} flags." / "... 1 flag." / "Nobody marked a trap."), and the dawn ledger labels
`ledger_cash_in`, `ledger_medical_bill`, `ledger_added_to_final`, `ledger_farm_damage`,
`ledger_balance`. All are `placeholder` except doc 01's headlines; sections `flags`, `ledger` and
`season_award` are new in the schema.

### 17.4 Season awards

Doc 01 "Season awards": most traps disarmed, most fooled by voice, most coins, "Barn Goblin" (the
player with the most `inside_at_night` seconds). Templates (`section` `season_award`):

| Id | Template |
|---|---|
| `award_traps_disarmed` | "{name}: Trap Whisperer. Disarmed {n} traps this season." |
| `award_fooled_by_voice` | "{name}: Easy Mark. Fooled by a voice {n} times." |
| `award_most_coins` | "{name}: Cash Crop. Earned {n} coins." |
| `award_barn_goblin` | "{name}: Barn Goblin. {n} seconds hiding indoors at night." |
| `award_participation` | "{name}: Still Here." (placeholder: every player gets at least one award) |

The four doc 01 awards have `source` doc01 for the category; the titles and wording are placeholder.

### 17.5 Off players

An Off player's lines are never voiced. In the report they appear as text only plus a
sound-only effect: "{name} said something" plus a neutral sound cue (doc 06 section 11).

## 18. DD Phase 1: fake it first

Doc 01 "Build Plan > DD Phase 1": scripted creature states, the creature wandering and chasing by
sound, scripted traps and pits, generic voice lines from the corn, **no AI Director**.

| Piece | Phase 1 rule | Source |
|---|---|---|
| Area | doc 04 Phase 1 area (x -32 to 46) | doc 04 sec 9 |
| Scripted trap spots | `trap_01` to `_06`, `_15`, `_16`, `_19`, `_22` (the bear trap or pit per list below) | doc 04 |
| Timers | the night is 300 s (doc 02 section 3); at 40 s, 100 s, 160 s, 220 s a trap is set (4 traps), one bear and one pit in two spots each night | placeholder |
| Scripted creature | `lurk` for 60 s, `stalk` 20 s at the first outdoor player, `chase` after 15 s of `stalk`, `retreat` after 10 s; the creature wanders by sound after | placeholder |
| Chase by sound | the creature homes on the loudest emit (section 3.1) and loses it by section 5 | doc 01 "Build Plan" |
| Ambience | scripted `lurk`, `stalk`, `chase` ambience cues | doc 01 "Build Plan" |
| Voice lines | generic "stranger" lines (section 16) from `crow_01`, `_03`, `_06`, `_07`, `_09` corn edges | doc 01 "Build Plan" |
| Lure gate | at least 30% of lures make the target walk toward them | doc 01 "Build Plan" |
| Corruption | off (no Corruption in Phase 1) | placeholder |
| AI Director | none | doc 01 "Build Plan" |
| Trap race | on the trap race formula (section 7) with fixed distance 25 m | section 7 |
| Day traps | scripted at `trap_03` for the day race test | placeholder |

## 19. Data files this doc adds

Envelope as doc 02 Appendix A.1: `{"table", "schema_version", "records": [{id, source, cite, ...}]}`.
**Proposed; schemas become final when the Director approves them in CONTRACTS section 6.**
Field suffixes are `_s`, `_m`, `_mps`, `_pct`, `_mult`.

| File | Contains |
|---|---|
| `creature.json` | bodies (`id`, `signature_sound`, `quirk`), speeds and timers (section 4.1), hearing radii (3.1), sight (3.2), Corruption tracking (3.3) |
| `sabotage.json` | disturbance pool (10.1): `id`, `cost_points`, `opens_day`, `fix`, `clue`, `fix_hold_s` |
| `ai_director.json` | tension meter (11.1), profiles (11.2), day arc (11.3), scare rules (11.4), trap race (`start_distance_m`, `deep_start_distance_m`, `bend_m`, `min_spare_s`) |
| `voice_lines.json` | the lines, stranger lines and sound lures (16) |
| `dawn_report_templates.json` | templates (17) |
| `creature_traits.json` | season traits (22): `id`, `report_line`, `overrides` |

The simulator reads `sabotage.json` for scheduled sabotage and `ai_director.json` for the trap-race
distances (doc 02 hold question).

## 20. Gotchas

- Speeds are `placeholder` and tied together; change `pry_s` or any speed and the race spare
  (section 7) moves. Re-derive before tuning.
- "Deep" is a ring location only (doc 04 sec 2); a player standing in a field is never "deep".
- The AI Director's variation moves thresholds, never adds a condition.
- Hunting reads `sensed`; presentation reads `true`. Mixing them is the likeliest bug.
- A Corrupted player cannot lose a chase by quiet alone.
- The crow burst is public and does not count as a big scare; a hallucination is private and does.
- The lantern blows out, never flickers; only ghosts flicker.

## 21. Questions raised

See Q-018 in `production/QUESTIONS.md`: AI Programmer buildability review (sensing tick, region
graph, corn pathing, Noise API); placeholder speeds depend on Q-016; the Corrupted-quiet reading
(section 5); "bodies" read as the dead player's body (section 15); the splice cut rule.

## 22. Season traits (DD Phase 5)

Doc 01 "Next season": the creature gains one trait per season (better tool mimicry, more pits). The
trait list is `data/creature_traits.json`; the season count and the carry-over are
[doc 02 section 21](02_systems_and_economy.md#21-next-season-and-cosmetics). Every number here is
`placeholder` except the two doc 01 names (tool mimicry, more pits); a playtest of season 2 and 3
tunes them, and the sim (doc 02 21.6) checks that the team can still win.

### 22.1 The rule

- **When.** At the start of season 2 and season 3 (never season 1). A lost season does not carry
  (doc 02 21.1), so a new campaign starts again with no traits.
- **Pick.** The host draws uniformly among the traits not yet gained, seeded by the save seed and the
  season number (`Random(hash(seed, season))`), so the pick is repeatable. Clients never pick.
- **Log.** `trait_gained` with `season`, `trait` and `seed` (doc 05 log events; the QA gate checks it).
- **Stacking.** Traits stack and are kept until the campaign ends. No two traits `set` the same
  field; where two would `add` to one field the sum applies.
- **Dawn Report.** The first Dawn Report of the season prints the trait's `report_line` once, under
  the season header, in the style of a disturbance clue. It hints at the effect and never names it.
- **Wire.** The host applies overrides when it loads the season's data. Clients get the trait list in
  the season-start message (doc 06) only so the Dawn Report can print it; no client rule depends on it.

### 22.2 The traits

Ten traits, seven more than a 3-season campaign draws, so teams see different pairs.
`overrides` is an array the data loader applies on top of the base record. Fields: `table`, `id`
(the record) or `days` (a `ramp_up` day range, both ends included), `field`, `op` (`set`, `add`,
`mul`), `value`, and `base` (the value it replaces, for the reader). `where_kind` selects every
`creature` record whose `kind` is that value (here `noise`). `new: true` marks a field that does not
exist yet; the AI Programmer adds it (Q-255).

| Trait | Effect | Base to new | Source |
|---|---|---|---|
| `tool_mimicry` | Sound lures carry no tell more often; day lures come more often | `sound_no_tell_pct` new field, 80 (voice lures keep their third); `day_gap_s` 90 to 70 | doc 01 "Next season" (name); numbers placeholder |
| `more_pits` | One more pit on days 2 to 6 | `pit_4p` +1 on `ramp_up` `day_2` to `day_6` (headcount scaling applies as for the ramp-up). Pits need no stolen supply (9.1) | doc 01 "Next season" (name); number placeholder |
| `keen_ears` | Every creature noise radius x1.25. The voice formula (3.1) is unchanged; the radius it multiplies grows | `radius_m` x1.25 on every `noise` record | placeholder |
| `fast_legs` | Chase speed +0.5 m/s | 5.5 to 6.0 (Corrupted chase speed +0.5 too). Player sprint stays 5.0, so a sprinter loses ground at 1.0 m/s. The trap race (7) speed is unchanged (Director decision, P5-02 QA); the sim does not model the chase change | placeholder |
| `long_eyes` | Sees farther | `sight_day_m` +5, `sight_night_m` +5. The 40 m lit-lantern spot (3.2) is unchanged | placeholder |
| `lock_breaker` | The shed lock breaks sooner | `shed_lock` `broken_from_day` 5 to 3 | placeholder |
| `thick_hide` | A flare scares it off for less time | `retreat_after_flare_s` 30 to 20 | placeholder |
| `extra_hands` | One more disturbance a day on days 4 to 6 | `disturbances_4p` +1 on `day_4` to `day_6` | placeholder |
| `taint_nose` | Tracks Corruption from farther and for longer | tracking radius 60 to 80 m; trail 20 to 30 s | placeholder |
| `splice_master` | Splices three segments, not two | `splice_max_segments` new field, 2 to 3 (needs P5-03's segment list) | placeholder; 12.1 |

### 22.3 What a trait never does

- No trait lets the creature hear a quiet, crouching player outside its radii, or see through the
  light rules (6). Radii grow; the rules do not change.
- No trait adds a scare, a body or a way to die. Deaths still follow the trap race (7).
- Traits change nothing the AI Director budgets: the scare budget (11.4) and the one-big-scare-a-day
  rule (13) are untouched, so a trait cannot stack frights on a player.
- Honest signals stay honest: no trait fakes the flicker, the radio or the lantern dim.

### 22.4 Checks

- `tools/sim/test_sim.py` loads the trait table and requires every trait to have overrides and a
  report line (doc 02 21.6). Whether each override target exists is for the data loader (P5-04).
- Campaign sim: only `more_pits` and `extra_hands` (ramp-up counts) move its numbers; the other
  eight change chase, detection, lures or items, which the sim does not model (inference; a bot
  season would settle it). Doc 02 21.6 reports the per-trait final clear.

## 23. Horror role scares (DD Phase 5, P5-53) - PLACEHOLDER

Game Designer to confirm. Every number is a placeholder in `data/roles.json` (`horror.perks`). Source: CEO picks of
2026-10-10 (P5-53); doc 01 "Roles" has no Horror row yet (Q-350). Everything below is local to the Horror player's peer
(`game/player/horror_scares.gd`): no other peer sees, hears or logs it, and nothing in it can hurt the player.

| Scare | What the Horror player gets | Placeholder |
|---|---|---|
| Darker world | Ambient light, lamps and fog density scaled; no flicker | ambient x0.55, lamps x0.6, fog x2.0 |
| More hallucinations | The AI Director's hallucination weight doubles for that player | x2.0, from day 5 |
| Silhouette | A hallucination put in view by the role, not the AI Director | every 50-110 s, 18-40 m |
| Whisper | A teammate's real clip, or a stranger line, from a spot nearby | every 60-140 s, 10-22 m |
| Own-voice whisper | The player's own recorded clip from the corn (the "name" scare) | every 150-300 s, 6-12 m |
| Steps behind | Footsteps behind that close in while moving, and stop when the player turns more than 35 degrees | every 70-160 s, 14 s, 3.5 m to 2.0 m |
| Edge shadow | A black shape 50-75 degrees off the view axis; gone when it comes within 20 degrees of the centre | every 80-170 s, 5-11 m |
| Fake grab | A camera jolt and a stinger, then nothing: nothing is held, dropped, locked or slowed | every 200-420 s, 2 a day, 0.35 s |
| Sixth sense | A slow dark-blue vignette and a swell when the real creature is within 30 m (host-sent, `Scares._sixth_sense`), and also on 40% of hallucinations, 30% of whispers and a random fake about every 50 s, so it is never proof | cooldown 25 s |

### 23.1 Exceptions to doc 01's hallucination rules (placeholder, FOR CEO in Q-350)

1. The role's scares are extra to the AI Director's budget and do not count against its once-per-season-per-player and
   spacing limits. They only reach the Horror player, who chose them.
2. The own-voice whisper replays the Horror player's own clips more than doc 01 allows a clip to be replayed in a season.
   It still honours doc 06 s11: only when that player's voice setting replays it (`Game.replays_voice`), never with Off or
   streamer-safe, and it uses the same `lure` path as the creature's copied voices. It is the player's own clip, not the
   real name (the game cannot make the name in their voice; inference, Q-353).
3. The fake grab is a jolt, not a grab: no catch, no pin, no Corruption, no loss of items.
4. The edge shadow is a near-field shape that vanishes on sight; doc 01's hallucinations are distant silhouettes.

Settings: `reduce_scares` doubles every interval and drops the edge shadow and the fake grab. `camera_shake` 0 removes the
jolt (the sound stays). No white flash anywhere (doc 07 s4.3). `photosensitive_safe` needs no extra handling: the world
only dims, and the vignette ramps in 0.8 s.
