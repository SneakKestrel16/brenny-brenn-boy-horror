# Doc 04: Farm Layout

Owner: Level Designer. Task: PP-05. Status: done (QA passed on re-review, Director checked against doc 01,
2026-10-07).

Where everything on the farm stands, in metres, so that "every errand crosses its ground" (doc 01
"The Creature"). Doc 01 is the source of truth; every rule here cites the doc 01 section it comes
from. **Numbers doc 01 doesn't give are marked `placeholder`** and are tuned in the DD Phase 1 and 2
playtests. Inference is marked as inference, with what would settle it. Walking speed, can
refills and plots per player come from doc 02 section 2 (all `placeholder` there). The placements
the Director settled (the generator's place, the DD Phase 1 sell box, the marker group names) are
D-016. Every distance here was computed from the coordinates in sections 3 to 7, not measured off
the diagram.

## Contents

1. [Conventions](#1-conventions)
2. [Diagram](#2-diagram)
3. [Ground: the clearing, the corn ring and the strips](#3-ground-the-clearing-the-corn-ring-and-the-strips)
4. [Buildings and fixed props](#4-buildings-and-fixed-props)
5. [Fields, moonflower bed and Prize Pumpkin](#5-fields-moonflower-bed-and-prize-pumpkin)
6. [Cart route, farm gate and town stand](#6-cart-route-farm-gate-and-town-stand)
7. [Markers for other roles](#7-markers-for-other-roles)
8. [Distance checks](#8-distance-checks)
9. [The DD Phase 1 layout](#9-the-dd-phase-1-layout)
10. [Doc 01 elements checklist](#10-doc-01-elements-checklist)
11. [Gotchas](#11-gotchas)
12. [Questions raised](#12-questions-raised)
13. [Built scenes (P2-02)](#13-built-scenes-p2-02)
14. [Cover, tree lines and landmarks (P4-27)](#14-cover-tree-lines-and-landmarks-p4-27)
15. [More corn (P5-31, CEO STOP 6)](#15-more-corn-p5-31-ceo-stop-6)
16. [Corn through the farm (P5-51)](#16-corn-through-the-farm-p5-51)

## 1. Conventions

- **1 unit = 1 metre, Y up** (CONTRACTS section 4). Coordinates here are `(x, z)` on the ground
  plane: **x east, z south**, so north is -z, Godot's forward. Ground is flat at y = 0
  (`placeholder`; flat ground keeps the distance checks exact).
- **Origin `(0, 0)` is the barn door's outer threshold.** Building positions are their door
  thresholds (CONTRACTS section 4, D-007), so "30 m from any building's door" is a distance between
  the points in section 4.
- Rectangles are written `x0..x1, z0..z1`.
- Corn is 2.4 m tall and blocks sight both ways (CONTRACTS section 4, doc 01 "Senses > Sight").
- Distances are straight lines unless the table says "walk", which follows open ground around corn
  and fields (section 8.7).

## 2. Diagram

![Top-down farm layout](04_farm_layout.svg)

[04_farm_layout.svg](04_farm_layout.svg): 1 m = 4 px, grid lines every 10 m, scale bar 50 m, north
up. Every shape in it has its coordinates in sections 3 to 7, so it can be checked by hand: an
`(x, z)` point is drawn at `((x + 110) × 4, (z + 75) × 4)` px.

| Mark | Meaning |
|---|---|
| Green | Corn (ring, strips, patches and the section 16 weave) |
| Brown blocks | Buildings; white circle with black outline = a door or fixed prop |
| Tan grid, dashed lower row | Field plots; the dashed row is the upgrade row; the dotted row outside a field is the headcount row (section 5.1) |
| Purple squares | Moonflower bed |
| Red dashed line | Cart route |
| Orange dashed circle | 20 m around the Prize Pumpkin; grey dotted circle = 30 m from the farmhouse door |
| Blue circle | Town stand radius, 10 m (less creature interaction, D-115) |
| Blue dashed outline | DD Phase 1 area |
| Black squares (numbered) | Trap spots |
| Purple triangles (`cNN`) | Creature cover points |
| Dark wings | Crow perches |
| Orange crosses | Scarecrow spots |
| Teal circles | Animal escape spots |
| Small blue dots | Spatial audio test markers |
| Dark green circles | Tree canopies, drawn at their sight-blocker radius (section 14) |

## 3. Ground: the clearing, the corn ring and the strips

Doc 01 "The Creature": the creature "lives in the wild corn ringing the farm. Players can't cut or
farm that corn. Strips of it reach toward the buildings and stand between the barn and both fields."

| Area | Rectangle | Notes |
|---|---|---|
| Clearing (open ground) | x -65..105, z -45..55 (170 × 100 m) | `placeholder` size, set by the distances in section 8 |
| Wild corn ring | x -90..130, z -70..80, minus the clearing | 25 m deep (`placeholder`); deep enough for doc 03's "deep in the corn" (section 7.1) |
| Road lane through the ring | x 105..150, z -9..-1 (8 m wide) | From the farm gate east to the town and out of the map |
| Strip 1 (farmhouse) | x -50..-44, z 40..55 | Reaches north from the south ring toward the farmhouse door; the "first corn strip" of the Prize Pumpkin rule (section 5.3) |
| Strip 2 (barn) | x 12..18, z -45..2 | Reaches south from the north ring past the barn's east wall (4 m away); stands between the barn and both fields |
| Strip 3 (fields) | x 46..52, z -15..55 | Reaches north from the south ring; stands between field A and field B, and with strip 2 between the barn and field B |
| Strip 4 (shed) | x -9..-3, z 38..55 | Reaches north from the south ring toward the shed and fuel drum |

- **Strips are 6 m wide** (`placeholder`), so nowhere in a strip is more than 3 m from open ground.
  Being "deep in the corn" (doc 01 "Day deaths") is therefore only possible in the ring unless
  doc 03 sets "deep" at 3 m or less (inference; settled by doc 03's number).
- **Strips 2 and 3 alternate sides** (north, then south), so the walk from the barn to field B
  weaves round two tips and passes within 3 to 4 m of corn twice.
- A map boundary sits at the ring's outer edge (inference: doc 01 doesn't say what lies beyond the
  ring; an invisible wall inside dense corn is the cheapest; the gray-box task settles it).

## 4. Buildings and fixed props

Footprints are `placeholder` gray-box sizes. Door facing is the direction a player faces walking
out.

| Element | Door or position | Footprint | Facing | Doc 01 source |
|---|---|---|---|---|
| Barn | (0, 0) | x -8..8, z -20..0 | south | "Light is the rule"; "The Harvest Moon" (cart loaded in the lit barn); lobby is "the dark barn at night" ("Recording lines") |
| Farmhouse | (-45, 0) | x -51..-39, z -10..0 | south | "Generator" (lights barn and farmhouse); porch light at the door ("Ghosts > Lantern flicker") |
| Tool shed | (-15, 26) | x -18..-12, z 26..31 | north | "The tool shed"; lock on the door |
| Pegboard | (-15, 30.5), inside on the back wall | | faces the door | "The tool shed > Pegboard" |
| Generator | (-11, -6), 3 m off the barn's west wall | 2 × 1 m | | "Nights > Generator"; "From day 6 ... bangs the barn doors while circling to the generator" ("Light is the rule") |
| Fuel drum | (-10, 27), beside the shed door | 1 m | | "the drum by the shed is free and infinite; the walk is the cost" ("Nights") |
| Well | (49, -20), P5-47 (was (-25, 10)) | 2 m | | "Corruption > Cure", "Senses > Hearing" (well pump) |
| Shipping crate and store | (72, 5) | 2 × 1 m | | "Crops" (field B "by the shipping crate"), "Store" ("Bought by the shipping crate") |
| Town stand | (120, -5) | 3 × 2 m | | "Core Loop" (sell at the town stand), "AI Director > Town stand" |
| Farm gate | (105, -5), in the clearing's east fence | 6 m wide | | "Nights > Length", "Winning and losing" |
| Animal pen | x -30..-18, z -38..-28; gate (-24, -28) | 12 × 10 m, fenced | | "Daytime Threats > Broken fences", "Roles > Rancher" |

- **The generator is not by the shed** (D-016). Doc 01 "Nights" puts only the drum there and says
  "the walk is the cost". The generator sits by the barn it powers, 33 m from the drum, so a refuel
  is a 66 m round trip past strip 4's tip at night.
- **Respawn and lobby:** players spawn at dawn inside the barn (inference: doc 01 says the dead
  "respawn at the next dawn" without a place; the barn is the lobby and the cart's start). Six
  spawns for the 6-player cap (D-038): four in a row at z -8 (x -3, -1, 1, 3, 2 m apart) and two at
  (-2, -11) and (2, -11), 3 m behind the row. Nearest pair is 2.0 m apart (capsules about 0.6 m wide, no
  overlap). All are 8 to 12 m from the door (z 0), inside the dark barn (x -8..8, z -20..0), clear of the
  `RecordingSpot` (0, -15; 4.0 m from the back pair) and the lantern (-5, -17).
- **Lit doorway light:** a lit door's light reaches 6 m (`placeholder`, doc 07 sets it). It matters
  for pumpkin guarding (section 8.5).
- **Church bell:** heard, not visited. Its sound plays from (400, -5), beyond the town end of the
  road (`placeholder`; doc 08 owns the sound, doc 01 "Core Loop > Dusk").

## 5. Fields, moonflower bed and Prize Pumpkin

### 5.1 Fields

Doc 01 "Crops": "16 field plots at the start, up to 24 with upgrades, split into two distant fields
(one by the barn, one by the shipping crate) with corn between them."

| Field | Rectangle | Starting plots | Upgrade plots | Near |
|---|---|---|---|---|
| Field A | x 24..36, z -10..-1 | 8: rows z -10..-4 | 4: row z -4..-1 | Barn door 30.5 m (centre), 24 m (nearest corner) |
| Field B | x 66..78, z -10..-1 | 8: rows z -10..-4 | 4: row z -4..-1 | Shipping crate 10.5 m (centre) |

- **Headcount plots (D-039, P2-14):** above 4 players the field grows by 4 plots per extra player, start and
  ceiling both (doc 01 "Crops"; `player_scaling.json` `field_plots_start_by_players` 16/16/16/20/24 and
  `field_plots_max_by_players` 24/24/24/28/32 at 2 to 6 players, `placeholder`). The bought plots stay the 8 upgrade
  plots at every count (4 pairs), so only the starting plots differ and the layout needs 8 more sites, 32 in all:
  a row of 4 on the same 3 m grid outside each field, north of field A (z -13..-10, x 24..36) and south of field B
  (z -1..2, x 66..78; the cart route runs north of B, so its side stays clear). Each carries `extra = true`,
  `min_players` and `extra_order`: the inner two plots of each row (`extra_order` 2 and 3) open at 5 or more players,
  the outer two (1 and 4) at 6, so 5 players open 4 sites (20 at the start) and 6 players open 8 (24).
  A site below its `min_players` stays closed and cannot be bought. Both rows keep the field centres in this section
  and section 8 (centres use the 12-plot grid), sit 6 m or more from corn (strip 2 is 6 m from A's row; strip 3 is
  14 m and Patch4 6 m from B's, see section 15), 28 m from the barn door at nearest and 40 m or more from the town stand.
- **Plots are 3 × 3 m** (`placeholder`), 4 columns by 3 rows per field, so 8 + 8 = 16 at the start
  and 12 + 12 = 24 at most with 4 or fewer players (doc 01 "Crops"); 32 with the headcount rows at 6. Upgrades fill the south row of each field; the bank's
  seizure of 2 plots ("Foreclosure Notice") takes from that row first (inference; doc 02 settles
  which plots).
- Farthest plot centres in one field with the headcount row: 12.7 m (row to the opposite corner, `placeholder`);
  the spatial audio band for "within one field" (section 8.2) becomes up to 13 m, still inside the tested 10 to 30 m.
- Field centres are 42 m apart in a straight line, 48 m on foot round strip 3 (section 8.7).
- Fields are walkable: plots are bare ground, so walks may cross them.
- **Plots per player:** doc 01 "Crops > Labor" gives a starting estimate of about 6, so 4 players
  tend all 24. Doc 02 section 2.4 derives about 9 to 11 from this layout's walks with its
  `placeholder` holds and speeds. Which knob moves (holds, capacities or a longer layout) is Q-015
  item 4, left to the simulator by the Director; the layout stays until then.

### 5.2 Moonflower bed

Doc 01 "Crops > Moonflower bed": 1 plot per player; "moonflowers pay most but mean dark, far walks"
("Farming Meets Horror").

- x 57..63, z 19..25: 2 × 2 plots of 3 m (4 plots for 4 players; fewer players leave plots unused,
  per doc 01 "Debt formula" step 5, "the moonflower bed ... follow[s] headcount").
- East of strip 3, 5 m from its edge. Barn door 63.9 m in a straight line but 98 m on foot round
  strip 3's tip, the farm's darkest walk; field B 30 m.
- The glow (doc 01 "Crops") is the only light there, so the bed is a landmark at night from the
  route north of strip 3 and from field B.

### 5.3 Prize Pumpkin patch

Doc 01 "The Prize Pumpkin > Placement": "at least 30 m from any building's door, between the
farmhouse and the first corn strip."

- Patch centre **(-47, 33)**, 4 m across (`placeholder`).
- Doors: farmhouse 33.1 m, shed 32.8 m, barn 57.4 m, all ≥ 30 m.
- "First corn strip" is read as the strip nearest the farmhouse, strip 1, whose tip (-47, 40) is
  7 m south of the patch; the farmhouse door is 33 m north. So the patch lies on the line from the
  farmhouse door to strip 1 (inference: doc 01 doesn't number the strips; the Director's check
  confirms the reading).
- Harvest Moon: it is moved to the barn at dusk, a 57 m straight-line trip (doc 01 "The Harvest
  Moon"; how it moves is doc 02's and doc 05's).

## 6. Cart route, farm gate and town stand

### 6.1 Cart route

Doc 01 "The Harvest Moon": the cart is loaded in the barn and pushed to the gate; "At the cap, the
cart counts as out only if it's past the fields" ("Nights > Length").

| Waypoint | (x, z) | Leg length | Least distance to corn on the leg |
|---|---|---|---|
| R0 cart park, east of the barn door | (5, 6) | | 8.1 |
| R1 | (5, 8) | 2.0 | 9.2 |
| R2 south of strip 2's tip | (15, 9) | 10.0 | 6.7 |
| R3 east of field A | (40, 5) | 25.3 | 6.0 |
| R4 north, between field A and strip 3 | (41, -24) | 29.0 | 5.3 |
| R5 north of strip 3's tip | (58, -24) | 17.0 | 9.0 |
| R6 | (66, -14) | 12.8 | 10.3 |
| R7 north of field B | (82, -14) | 16.0 | 14.0 |
| R8 farm gate | (105, -5) | 24.7 | 3.7 |

- **R0 moved off the barn door (P5-18, CEO report 2026-10-09: "the cart shouldnt block the doorway to the
  barn").** R0 was (0, 0), the door itself, so the 3 m cart (about 1.6 m wide, 3 m long, prop_cart.glb)
  parked across the door gap (x -1.5 to 1.5). It now parks at (5, 6) facing +Z towards R1: body x 4.2 to
  5.8, z 4.5 to 7.5, so 2.7 m east of the door gap and 4.5 m south of the wall. The straight walk out of
  the door (x -1.5 to 1.5) and the barn-to-field-A walk of doc 04 s8.7 (barn, (11, 3), (19, 3): 1.4 m
  from the wall at x = 5, 3 m clear of the cart body) both stay open. The cart still starts beside the
  barn (6.7 m from the door). The old length was 147.9 m (docs 02 and 05 still quote it, Q-326).
- **Length 136.9 m.** It weaves round both strip tips, so the creature has cover within 5 to 7 m of
  the cart on the R2 to R5 legs.
- **The gate is a corn pinch.** The gate opens into the 8 m road lane, so on the last metres of
  R7 to R8 the cart passes 3.7 m from the ring's corn, and 4 m from it on both sides at the gate.
  That is the route's closest pass to corn, at the end. The layout keeps it on purpose: the gate run
  is "a guaranteed peak, then release as the cart rolls out" (doc 01 "The Harvest Moon"), and a
  pinch at the gate gives the creature a place to make that peak (inference; the DD Phase 4 Harvest
  Moon playtest settles whether it is too hard).
- **"Past the fields" is x > 78**, field B's east edge (inference: the line beyond which both fields
  are behind the cart; doc 05 makes it a check on the cart's position).
- Cart speed by pusher count is doc 02's or doc 03's, so the push time is not given here.
- **A 3 m dirt path is drawn on the route** (P4-27, CEO Harvest Moon test: players couldn't see where to
  push). `build_farm.py` draws it from the same `ROUTE` list as `CartRoute`, one flat visual strip per
  leg from R0 to R8, then on along the lane to the town stand, so if the route moves the path moves
  with it. It is visual only (no collision) and 2 cm high, so the cart's wheels stay at y = 0.
- The route keeps ≥ 4 m from every field edge (R3 to R4 passes 4 m east of field A).
- Player-placed fences and scarecrows ("Farming Meets Horror > Defense") could block it; the host
  should refuse placements within 3 m of the route (inference; doc 05 settles the rule, Q-014 item
  6). Settled: doc 05 sections 11 and 13 adopt 3 m (reason `blocks_cart_route`).
- **Scene contract (Q-022, Q-026).** The route is a `Path3D` named `CartRoute` in the level scene, with
  curve points R0 to R8 in order, y = 0, coordinates as in the table. DD Phase 1 gray-box scene:
  `res://game/world/farm_phase1.tscn` (one field, shed, barn); DD Phase 2: `res://game/world/farm.tscn`.
  Phase 1 has no cart, so `CartRoute` first exists in `farm.tscn`.
- **Light and corn nodes (Q-026).** A `LightRig` scene sits at each door and window of every building;
  lit doorway radius, ground decal and the doc 03 section 9 trap exclusion are all 6 m (doc 07
  section 3). Layer 5 corn sight-blockers are coarse `StaticBody3D` edge strips under a `CornBlockers`
  node, separate from the visual MultiMesh corn (doc 07 section 10); blocker bounds follow the ring
  and strip edges in section 3.

### 6.2 Farm gate and town stand

- **Farm gate (105, -5)**, in the east fence at the clearing's edge. The road runs east from it
  through the ring in an 8 m lane.
- **Town stand (120, -5)**, 15 m outside the gate beside the road, with corn on both sides of the
  lane. Its **10 m radius** (doc 01 "AI Director > Town stand", D-115: lures, scares and kills less
  likely, never impossible) covers x 110..130 of the lane.
  - It never reaches the gate (5 m clear) or any of the cart route (nearest point 15 m), so the
    gate run is never safe ground.
  - It contains no plot, so "nothing grows there" costs nothing that the layout offers.
  - Corn stands within the circle, so the creature can be near a player there; it acts there less
    often (doc 01, D-115).
- **Selling and the store are in different places** (D-017): the shipping crate is the store only;
  selling is at the town stand and at the dawn cash-in.
- Field B to the stand is 48 m on foot; the barn door 127.5 m (section 8.7).

## 7. Markers for other roles

The gray-box farm places these as named `Marker3D` nodes at y = 0, in the groups D-016 accepted
(they enter CONTRACTS when the gray box starts): `trap_spots`, `creature_cover`, `crow_perches`,
`scarecrow_spots`, `animal_escape_spots`, `spatial_audio_markers`. Counts, and the distance
thresholds that define each kind below, are `placeholder`; doc 03 decides which spots are used
each night.

### 7.1 Trap spots

Doc 01 "Night Traps": traps sit in "rows" with clues; day 6 at 4 players is the most at once, 5
bear, 3 pits and 2 bells (doc 01 "Ramp-up"), so 22 spots (`placeholder`, twice the night's maximum
plus two) let placement vary. Kinds (thresholds `placeholder`): **edge** = open ground within
12 m of corn on a walked line; **row** = 2 to 3 m inside corn; **deep** = 10 m or more inside the
ring, for the trap race's "a trap deep in the corn" (doc 01 "Day deaths"). Bells go on row spots
("strung low across rows"). "Inside" is the distance to the nearest open ground.

| Spot | (x, z) | Kind | Where |
|---|---|---|---|
| trap_01 | (15, 6) | edge | Strip 2's tip, barn to field A walk |
| trap_02 | (21, -4) | edge | Field A's west side, 3 m from strip 2 |
| trap_03 | (16, -14) | row | Strip 2 |
| trap_04 | (14, -24) | row | Strip 2, behind the barn |
| trap_05 | (15, -57) | deep | North ring, 12 m in |
| trap_06 | (40, -6) | edge | Between field A and strip 3 (on the cart route) |
| trap_07 | (48, -10) | row | Strip 3's tip |
| trap_08 | (49, -26) | edge | North of strip 3's tip, field A to B walk |
| trap_09 | (50, 0) | row | Strip 3, between the fields |
| trap_10 | (60, 66) | deep | South ring behind the moonflower bed, 11 m in |
| trap_11 | (64, 15) | edge | Field B to moonflower walk |
| trap_12 | (60, -20) | edge | North-east of strip 3's tip, 9.4 m from it (cart route R5 to R6) |
| trap_13 | (80, -48) | row | North ring edge by field B |
| trap_14 | (90, 58) | row | South ring edge, east |
| trap_15 | (-6, 41) | row | Strip 4's tip |
| trap_16 | (-14, 36) | edge | Behind the shed, fuel walk |
| trap_17 | (-47, 44) | row | Strip 1, beside the pumpkin |
| trap_18 | (-58, 30) | edge | West of the pumpkin |
| trap_19 | (-24, -47) | row | North ring behind the animal pen |
| trap_20 | (-35, 68) | deep | South ring, 13 m in |
| trap_21 | (100, 10) | edge | By the gate |
| trap_22 | (30, -55) | deep | North ring behind field A, 10 m in |

Stolen tools "often beside an armed trap" and creature leavings (dead crows, strange seeds) use
trap spots and crow perches (inference; doc 03 settles where sabotage drops things).

### 7.2 Creature cover points

Doc 01 "Behavior states": it lures "from cover" and stalks "from cover". Each point is 1 to 2 m
inside corn (`placeholder`), facing a work spot, and doubles as a lure source for "generic voice
lines from the corn" in DD Phase 1 (doc 01 "Build Plan").

| Point | (x, z) | Watches |
|---|---|---|
| cover_01 | (13, -6) | Barn door and field A |
| cover_02 | (17, -8) | Field A |
| cover_03 | (47, -4) | Field A, cart route R3 to R4 |
| cover_04 | (51, -6) | Field B |
| cover_05 | (49, -13) | Strip 3's tip, field A to B walk |
| cover_06 | (51, 18) | Moonflower bed |
| cover_07 | (72, -47) | Field B, cart route |
| cover_08 | (80, 57) | Moonflower bed, shipping crate |
| cover_09 | (-6, 40) | Fuel drum, shed |
| cover_10 | (-47, 42) | Prize Pumpkin |
| cover_11 | (-67, 30) | Prize Pumpkin, farmhouse |
| cover_12 | (-24, -47) | Animal pen |
| cover_13 | (107, 8) | Farm gate |
| cover_14 | (-9, -47) | Barn's north side, generator |
| cover_15 | (30, 57) | Open ground south of field A |
| cover_16 | (-42, 57) | Prize Pumpkin, strip 1 |
| cover_17 | (73, -21.5) | Field B, north (Patch1, section 15) |
| cover_18 | (95.5, -17.5) | Field B, gate approach (Patch2) |
| cover_19 | (81, 15.5) | Shipping crate, south (Patch3) |
| cover_20 | (58.5, -4) | Field B, west (Patch4) |
| cover_21 | (100.5, 23) | Field B, south-east (Patch5) |
| cover_22 | (69, 39.5) | Moonflower bed, crate (Patch6) |
| cover_23 | (45, -36) | The well and the cart route's R4 corner (Weave1, section 16) |
| cover_24 | (28, -23) | Field A's north side (Weave2) |
| cover_25 | (-1, -37) | Behind the barn, the pen's east side (Weave3) |
| cover_26 | (11, 34) | Yard south of the audio band, shed and drum (Weave4) |
| cover_27 | (28, 26) | Orchard edge, field A's south side (Weave5) |
| cover_28 | (59, 46) | Moonflower bed from the south (Weave6) |
| cover_29 | (78, 36) | Moonflower bed's south-east side, between Patch6 and Patch3 (Weave7) |
| cover_30 | (89, 25.5) | East of the crate, gate's south wing (Weave8) |
| cover_31 | (-35, 44) | Prize Pumpkin from the east (Weave9) |

### 7.3 Crows, scarecrows, pen and escape spots

- **Crow perches** (doc 01 "Ghosts > The crow", "Jumpscares > Fake-outs"): crow_01 (30, 1) field A
  fence; crow_02 (72, -12) field B fence; crow_03 (13, 2) strip 2's tip; crow_04 (-47, 38) by the
  pumpkin; crow_05 (60, 17) moonflower bed; crow_06 (-24, -27) pen gate; crow_07 (46, 30) strip 3's
  edge; crow_08 (-62, 0) west ring edge; crow_09 (51, -19) on the well (P5-47), 5 m from strip 3's tip,
  so ghosts there see the corn edge directly (section 8.4); the crow gives a second view.
- **Scarecrow spots** (doc 01 "Jumpscares > The scarecrow moved", "Store > More scarecrows"):
  scarecrow_01 (30, -5.5) and scarecrow_02 (72, -5.5) are the field scarecrows at the start (2,
  `placeholder`); scarecrow_03 (20, 20), _04 (-40, 20), _05 (60, -30), _06 (90, 20) and _07 (-8,
  -32) are the moved-scarecrow spots, each turned to face the farmhouse door when used. Bought
  scarecrows are placed by players on open ground and need no marker.
- **Animal pen** (section 4) and **escape spots** where escaped animals end up, each 5 m from the
  ring and 60 m or more from the pen gate (both `placeholder`), so animals are "rounded up far from
  the group" (doc 01 "Daytime Threats"): escape_01 (35, -40) 60.2 m, escape_02 (95, -40) 119.6 m,
  escape_03 (35, 50) 97.8 m, escape_04 (-60, 50) 85.9 m. (The first draft had escape_01 at
  (-60, -40), 37.9 m from the gate; it moved north of field A.)
- **Flags** are player-placed anywhere (doc 01 "Night Traps > Flags") and need no marker.

### 7.4 Spatial audio test markers

Doc 01 "Testing > Spatial audio (Phase 1 gate)": place a voice and a whistle at 10, 30 and 60 m.
Proposed test line, all inside the DD Phase 1 area on open ground: listener `audio_listener`
(-26, 16); sources `audio_10m` (-16, 16), `audio_30m` (4, 16), `audio_60m` (34, 16). The sources
stay put and the listener's heading is randomised per trial, so front-to-back confusion is tested
without needing 60 m of open ground in every direction (inference; the procedure is doc 09's).

## 8. Distance checks

### 8.1 Key distances (straight line, m)

| From | To | m |
|---|---|---|
| Barn door | Farmhouse door | 45.0 |
| Barn door | Generator | 12.5 |
| Barn door | Shed door | 30.0 |
| Farmhouse door | Shed door | 39.7 |
| Generator | Fuel drum | 33.0 |
| Barn door | Well | 52.9 |
| Well | Shed door | 78.8 |
| Well | Farmhouse door | 96.1 |
| Barn door | Field A centre | 30.5 |
| Field A centre | Field B centre | 42.0 |
| Barn door | Field B centre | 72.2 |
| Field B centre | Shipping crate | 10.5 |
| Field B centre | Moonflower bed centre | 30.0 |
| Field A centre | Moonflower bed centre | 40.7 |
| Barn door | Moonflower bed centre | 63.9 |
| Farmhouse door | Prize Pumpkin | 33.1 |
| Shed door | Prize Pumpkin | 32.8 |
| Barn door | Prize Pumpkin | 57.4 |
| Well | Prize Pumpkin | 109.7 |
| Field B centre | Town stand | 48.0 |
| Farm gate | Town stand | 15.0 |
| Escape spots | Pen gate | 60.2 to 119.6 (section 7.3) |
| Barn door | Town stand | 120.1 |
| Prize Pumpkin | Town stand | 171.3 (the farm's longest) |

### 8.2 Spatial audio test (10, 30, 60 m)

Doc 01 "Testing" tests placement at 10, 30 and 60 m. Doc 06 section 8 sets voice attenuation at
max distance 80 m (`placeholder`), so beyond 80 m a voice is silent.

| Band | Pairs on this farm | What it means |
|---|---|---|
| About 10 m (up to 11) | Plots within one field (10.8 m at most in the 12-plot grid, 12.7 m with a headcount row); field B and the crate (10.5) | Tested at 10 m |
| 11 to 30 m | Barn door and generator (12.5); well to both field centres (23.9, 27.2); barn to shed; field B to moonflowers | Tested at 10 and 30 m |
| 30 to 60 m | Barn to field A (30.5), barn to well (52.9), fields to each other (42), barn to farmhouse (45), pumpkin to barn (57) | Tested at 30 and 60 m |
| 60 to 80 m | Barn to moonflowers (63.9), barn to field B (72.2), well to shed (78.8) | Audible but beyond the tested 60 m |
| Over 80 m | Barn to town stand, pumpkin to the far field, anything to the stand from the yard, well to farmhouse (96.1) and to the Prize Pumpkin (109.7) | Silent: a seller or a guard can't be called by voice from across the farm |

- **Most calls fall inside the tested range, two don't.** Field to field (42 m), barn to field A
  (30.5 m) and yard to pumpkin (57.4 m from the barn door) are at most 60 m. **Barn to field B
  (72.2 m) and barn to the moonflower bed (63.9 m) are not:** audible, but beyond the 60 m the test
  checks. The layout keeps them: the far field and the moonflowers are meant to be far (doc 01
  "Crops": "two distant fields"; "Farming Meets Horror": "dark, far walks"), and moving field B
  within 60 m of the barn would put it within 30 m of field A. Whether players can place a voice at
  72 m is untested (inference; settled by adding a 72 m trial to the DD Phase 2 playtest, doc 09's
  call).
- **Over 80 m is deliberate:** the town stand and the far ends are out of voice range, which is the
  cost of splitting up (doc 01 "Farming Meets Horror > Splitting up"). The whistle "carries far"
  (doc 01 "How players fight back"), so its range should be at least 171 m, the farm's longest
  distance, so it is heard everywhere (inference; doc 08 sets it, Q-014 item 4).
- If the DD Phase 1 test fails at 60 m, the 60 to 80 m pairs fail too; moving the moonflower bed
  and field B 10 m west would bring them under 65 m (an option, not a plan).

### 8.3 The 15 m lure rule

Doc 01 "Who hears a lure": day lures reach a player "only with no teammate within about 15 m".

- **Two players in one field are always within 15 m** (plot centres at most 12.7 m apart with the headcount rows, 10.8 m in the 12-plot grid), so
  sharing a field protects both from day lures; splitting the fields (42 m apart) exposes both.
- Work spots under 15 m apart: the shed and its drum (5.1 m), field B and the crate (10.5 m), and
  the **barn door and the generator (12.5 m)**. So a teammate at the barn door shields a refueller
  at the generator from day lures, but not at the drum (28.8 m from the barn door). Every other pair
  of work spots is 20.8 m or more apart (moonflower bed to the crate), so any errand done alone can be lured. (The farm gate and
  the town stand are 15.0 m apart, and lures at the stand are less likely anyway, D-115.)
- A spotter watching a disarm (doc 01 "Night Traps > Spotting") stands within 15 m to block lures,
  and every trap spot has open ground within 15 m to stand on, except the deep spots, which are 10
  to 13 m into the ring (inference: the spotter must enter the corn there).
- Every lure-exposed work spot has corn within 20 m for the lure to come from (section 8.4) except
  the generator (23 m); lures there come from the yard's corn edges at range
  (doc 03's lure distance settles whether that's close enough).

### 8.4 The 20 m ghost radius

Doc 01 "Ghosts > Spectating": within about 20 m ghosts see the creature as a smeared silhouette;
beyond that, only through animals and crows. Nearest corn to each work spot:

| Spot | Corn within (m) | Ghost can see the corn edge? |
|---|---|---|
| Prize Pumpkin | 7.0 | Yes |
| Moonflower bed centre | 8.0 | Yes |
| Fuel drum | 11.0 | Yes |
| Barn door, field A centre | 12.0 | Yes |
| Shed door | 13.4 | Yes |
| Animal pen gate | 17.0 | Yes |
| Farmhouse door | 20.0 | At the limit |
| Field B centre | 12.0 | Yes (P5-31 patches, section 15; was 20.0) |
| Shipping crate | 10.8 | Yes (P5-31, Patch3; was 20.0) |
| Farm gate | 4.0 | Yes (the lane's corn) |
| Generator | 23.0 | No: the pen's animals and crow_06, 25 m away, react for it |
| Well | 5.0 | Yes (P5-47: strip 3's tip; was 32.2 m in the yard); crow_09 also sits on it |

### 8.5 The 20 m pumpkin radius and the 30 m door rule

Doc 01 "The Prize Pumpkin": a guard "outdoors within 20 m for at least 60 seconds"; "Time inside a
lit doorway's light doesn't count"; gnawed "on any night nobody is within 20 m".

- The nearest door is 32.8 m away, so the nearest lit-door light (6 m, `placeholder`) ends 26.8 m
  from the pumpkin, outside the 20 m circle. No guard can count time from a doorway.
- No work spot is within 20 m (the nearest is the shed door at 32.8 m): guarding is a job of its own (doc 01
  "Splitting up").
- Strip 1's tip is 7 m away. Inside the circle: cover_10 (9.0 m), trap_17 (11.0), trap_18 (11.4),
  cover_31 (16.3, P5-51, Weave9), crow_04 (5.0) and the moved-scarecrow spot scarecrow_04 (14.8). Just outside: cover_11 (20.2) and
  cover_16 (24.5), which watch the guard from the ring. So the guard stands in the open with corn
  and a cover point close by.

### 8.6 The 10 m town stand radius

Covered in section 6.2: the circle holds no plot and none of the cart route, and ends 5 m outside
the gate.

### 8.7 Walks and labor

Doc 01 "Crops > Labor": labor is measured in seconds, walking included. Speed is doc 02 section
2.2's walk, **3.0 m/s** (`placeholder` there; Q-016 settles who owns speeds).

**How a walk is measured, so anyone can reproduce it:** the shortest path on open ground that keeps
**1 m** (`placeholder`) from corn and from building footprints. Fields are walkable. The path bends
only at the corners of those obstacles grown by 1 m; the waypoints below are those bends, so each
walk is the sum of the straight legs from start, through the waypoints, to the end. A walk starting
at a door may leave through its own building's 1 m margin.

| Walk | Waypoints between start and end | m | s at 3.0 m/s |
|---|---|---|---|
| Barn door to field A centre | (11, 3), (19, 3) | 33.3 | 11.1 |
| Field A centre to field B centre | (45, -16), (53, -16) | 48.0 | 16.0 |
| Barn door to field B centre | (11, 3), (19, 3), (45, -16), (53, -16) | 81.3 | 27.1 |
| Field B centre to moonflower bed | none | 30.0 | 10.0 |
| Barn door to moonflower bed | (11, 3), (19, 3), (45, -16), (53, -16) | 98.2 | 32.7 |
| Field B centre to town stand | none (through the gate) | 48.0 | 16.0 |
| Town stand to shipping crate | (104, -2) | 49.0 | 16.3 |
| Shipping crate to field A centre | (53, -16), (45, -16) | 54.6 | 18.2 |
| Field A centre to town stand | (45, -16), (53, -16) | 94.2 | 31.4 |
| Barn door to town stand | (11, 3), (19, 3), (45, -16), (53, -16) | 127.5 | 42.5 |
| Fuel drum to generator | none | 33.0 | 11.0 |
| Barn door to Prize Pumpkin | none | 57.4 | 19.1 |
| Farmhouse door to Prize Pumpkin | none | 33.1 | 11.0 |
| Well to Prize Pumpkin | (19, 3), (11, 3) | 111.1 | 37.0 |
| Well to field A centre | none | 23.9 | 8.0 |
| Well to field B centre | none | 27.2 | 9.1 |
| Well to moonflower bed | (53, -16) | 44.3 | 14.8 |
| Well to barn door | (19, 3), (11, 3) | 57.2 | 19.1 |
| Barn door to shed door | none | 30.0 | 10.0 |

- **Watering refills:** cans fill at the well only, 2 plots per fill (doc 02 section 2.2, both
  `placeholder`; the well-only reading is doc 02's inference). So watering field A costs a 48 m
  round trip per 2 plots and field B 54 m (P5-47: was 117 m and 213 m with the well in the yard); the Prize Pumpkin
  is now a 222 m round trip per can. A pump at each field would be a new element and needs a
  doc 01 change.
- **For doc 02 section 2.4**, which used this doc's first-draft walks: `d_well` is now 23.9 m
  (field A), 27.2 m (field B), 44.3 m (moonflower bed) and 111.1 m (Prize Pumpkin) after P5-47 (was 58.5, 106.5, 123.4, 31.8); the trade loop field B → stand → crate → B is
  48.0 + 49.0 + 10.5 = 107.5 m (unchanged); field A → stand → crate → A is
  94.2 + 49.0 + 54.6 = 197.8 m (doc 02 used 209.7 via field B). Both shorten the walks a little,
  so doc 02's P ≈ 9 to 11 rises slightly (Q-015 item 4).

## 9. The DD Phase 1 layout

Doc 01 "Build Plan > Phase 1": "one small field, the shed and the barn", plus turnips (plant,
water, sell), a noisy watering can, one generator run, scripted traps and pits, generic voice lines
from the corn, and the spatial audio test.

The Phase 1 farm is the full farm cut to **x -32..46** (the blue dashed outline), at the same
coordinates, so nothing moves when DD Phase 2 widens it:

- **In:** barn, tool shed with pegboard and fuel drum, generator, well (the can refill, doc 02
  section 2.2), field A (8 plots, `placeholder`; the headcount row is full-farm only; 2 players × about 6 plots, doc 01 "Crops > Labor",
  would use all 12, so the upgrade row can be switched on without moving anything), animal pen
  (empty), strips 2 and 4, the north and south ring.
- **Temporary corn walls** at x -32..-57 (west) and x 46..71 (east, the east one where strip 3's
  west edge will be). Both are removed in DD Phase 2.
- **Phase 1 sell box at (40, 20)** (D-016), a stand-in for the town stand, 44.7 m from the barn
  door and 27.4 m from field A in a straight line. Doc 01's Phase 1 list sells turnips but names no
  town stand, so the stand and its 10 m radius come later.
- **Markers in the area** (every marker with x from -32 to 46): trap_01 to _06, _15, _16, _19 and
  _22 (trap_05 and _22 are the deep spots in the north ring); cover_01, _02, _09, _12, _14, _15;
  crow_01, _03, _06, _07, _09; scarecrow_01, _03, _07; escape_01 and _03; all four spatial audio
  markers. Cover_03 (47, -4) lies 1 m inside the temporary east wall, so it is also usable in Phase 1.
- **Out:** farmhouse, field B, moonflower bed, Prize Pumpkin, shipping crate, town stand, gate,
  cart route, strips 1 and 3.
- In Phase 1 the well stays in the yard (-25, 10), 7 m from the temporary west wall, as in the first draft; only the full farm moves it between the fields (P5-47). Corruption isn't in Phase 1 (doc 01 "Build Plan > Phase 3"), so only
  watering refills are affected.

## 10. Doc 01 elements checklist

| Doc 01 element | Section |
|---|---|
| Wild corn ring; strips toward the buildings and between the barn and both fields | 3 |
| Barn; farmhouse (porch light); tool shed with pegboard and lock | 4 |
| Well; generator; fuel drum by the shed | 4 |
| Two distant fields, one by the barn, one by the shipping crate, corn between | 5.1 |
| Moonflower bed | 5.2 |
| Prize Pumpkin patch (30 m from doors, between the farmhouse and the first strip) | 5.3, 8.5 |
| Shipping crate and store | 4, 6.2 |
| Town stand and its 10 m radius | 6.2, 8.6 |
| Farm gate and cart route ("past the fields") | 6.1 |
| Trap spots (bear, pit, bells; deep in the corn) | 7.1 |
| Creature cover points (lure and stalk from cover) | 7.2 |
| Crows, scarecrows, animal pens, broken fences and escapes | 7.3 |
| Spatial audio test | 7.4, 8.2 |
| DD Phase 1 small layout | 9 |

## 11. Gotchas

- **Measure from door thresholds, not building centres** (D-007). A centre-to-centre check would
  pass the pumpkin at 30 m while its door stood closer.
- **6 m strips can't be "deep".** Anything doc 03 calls deep must be in the ring, unless "deep" is
  3 m or less (section 3).
- **Straight-line distance understates walks.** Barn to moonflowers is 64 m straight but 98 m on
  foot; labor uses the walk, voice and hearing use the straight line.
- **Hand-drawn walks drift.** The first draft's walks were picked by eye and came out 2 to 16 m
  long; QA couldn't reproduce them. Give waypoints and a stated clearance (section 8.7).
- **The road lane is corn on both sides.** A check that treats the ring's inner edge as a single
  line misses the lane's sides: the gate is 3.7 m from corn, not the first draft's 10.3 m.
- **Write "inside the circle" only after computing it.** The first draft put cover_16 inside the
  pumpkin's 20 m circle; it is 24.5 m away.
- **The generator is not by the shed** despite the TASKS wording (section 4, D-016).
- **The 80 m voice cut-off** (doc 06 `placeholder`) makes the town stand silent from the yard; a
  change to it changes section 8.2.
- The diagram is generated from the coordinates in this doc; if a number changes, change the SVG
  with it, and check one point against the formula in section 2.
- **Players and the creature walk through layer 5.** Both use collision mask 1, so corn and tree
  canopies stop sight, not bodies, and the creature has no navmesh or unstuck logic. A solid tree
  or fence on a walk would trap it; anything solid needs the AI Programmer first (section 14).
- **Check a model's origin before offsetting it.** `prop_cart.glb` has its origin at the wheel
  base, but `cart.gd` raised it 0.86 m as if the origin were the bed, so the cart hovered parked and
  while pushed (P4-27).

## 12. Questions raised

Q-014 (Level Designer → Director, Game Designer, Gameplay Programmer, Audio Designer). Answered:
item 1 (marker group names), 3 (the generator's place) and 5 (the Phase 1 sell box) in D-016;
item 2 (walk speed, can refills) by doc 02 section 2. Open: item 4, whistle range (Audio Designer,
doc 08), and item 6, fence placement near the cart route (Gameplay Programmer, doc 05). QA's review
findings are Q-017.

## 13. Built scenes (P2-02)

`game/world/build_farm.py` writes both scenes from this doc's coordinates: `farm_phase1.tscn` (section 9,
unchanged) and `farm.tscn` (the full farm). `farm.tscn` adds the farmhouse, strips 1 and 3, the full ring
(layer 5 boxes, road lane left open), field B, the moonflower bed (4 plots, `field = moonflower`), the
shipping crate (group `store_crate`), 8 headcount plots (`Plot29` to `Plot36`, D-039: 36 `plot_spots` in all, 24 field + 8 headcount + 4 moonflower), the town stand (group `sell_box`) with a `sanctuary` marker (10 m; the group keeps its old name, D-115),
the farm gate, the Prize Pumpkin marker, `CartRoute` (R0 to R8), all 22 trap spots, 31 cover points (16 + 6 in the P5-31 corn, section 15, + 9 in the P5-51 weave, section 16), 9 crow
perches, 7 scarecrow spots, 4 escape spots, 4 audio markers, 6 barn spawns (D-038), the pegboard with
`pegboard_bear_slots` slot markers (5, read from `data/season.json`), and in the barn a `RecordingSpot`
(0, -15) and `BarnLantern` (-5, -17; also in group `lightrig_spots`, radius 6, so `world_look.gd` puts the real `LightRig` there, Q-054 item 4) (placeholder positions, inference: inside the barn, away from the door).
`game/world/check_farm.gd` reruns sections 7.1, 7.3, 8.1 and 8.3 to 8.5 on the built scene:
`"$GODOT" --headless --path . --script res://game/world/check_farm.gd` (all pass; every doc distance
matches within 0.1 m, corn distances within 0.5 m). `game/world/farm_view.tscn` loads the full farm with the
corn visuals for render measures. Results are in `production/handoffs/P2-02.md`.

## 14. Cover, tree lines and landmarks (P4-27)

The CEO session found the farm too open and hard to read: flat ground between the buildings, nothing
to steer by (`production/OPEN_ISSUES.md` items 5 and 6). P4-27 adds trees, fences, dirt paths, signs
and landmarks to `farm.tscn` only; `farm_phase1.tscn` is unchanged. All are built by
`game/world/build_farm.py` (lists `TREES`, `FENCES`, `SIGNS`, `PATHS`, function `landmarks()`).
No marker, building, field, plot or route point moved, so every distance in section 8 and
`tools/sim/layout.json` stands.

**What blocks what (D-100, proposed).** Only the tree canopies collide, and only on layer 5, the corn
sight-blocker layer: they block sight at eye height the way corn does. Players and the creature both
use collision mask 1, so they walk through canopies, trunks and fences as they walk through corn
(read from the masks in `player.gd` and `creature.gd`; a solid obstacle would need creature avoidance
first, Q-196). Each canopy collider starts 1.2 m up, so queries at 1 m (the ghost's "in corn" point
test, the sprint-in-corn step, the hearing ray) never hit a tree: a tree hides you from sight but
not from hearing, and standing under one is not "in corn". Trunks, fences, paths, signs and landmarks have no
collision.

### 14.1 Trees

Pine: trunk 0.25 m radius, cone canopy 1.8 m radius from 1.2 to 6.7 m, collider radius 1.3 m from 1.2
to 4.2 m. Round tree: sphere canopy 2 m radius at 3 m, collider radius 1.8 m from 1.3 to 4.3 m.

| Group | Kind | Positions (x, z) | Purpose |
|---|---|---|---|
| Orchard 1 to 9 | round | x 24, 30, 36 × z 30, 36, 42 | Cover in the empty south-centre yard |
| Windbreak A 1 to 5 | pine | x 22 to 38 step 4, z -32 | Tree line north of field A |
| Windbreak B 1 to 4 | pine | x 24 to 36 step 4, z -36 | Second row behind it |
| North-east 1 to 5 | pine | (80, -30), (84, -35), (88, -29), (91, -36), (85, -40) | Clump north of the route's R7 leg |
| East line 1 to 6 | pine | x 97, z 22 to 47 step 5 | Tree line along the east fence |
| East line B 1, 2 | pine | (93, 30), (93, 40) | Second row |
| West 1 to 5 | pine | (-56, -34), (-51, -29), (-47, -37), (-59, -25), (-53, -41) | North-west corner clump |
| South grove 1 to 3 | round | (-27, 47), (-22, 51), (-19, 44) | Cover south of the shed |

**Placement rules**, checked by `check_farm.gd` (`_cover`, all 39 pass), counting each canopy's
collider edge, not its centre:

- Every work spot keeps at least its section 8.4 corn distance clear of canopies, so no tree gives
  the ghost a closer hiding place than corn already does. The pumpkin uses 20 m, its section 8.5
  radius, which is stricter than its 7 m corn distance.
- ≥ 2 m from every marker in every marker group, and from every plot.
- ≥ 3 m from every cart route leg (the section 6.1 placement rule).
- ≥ 1 m from every section 8.7 walk line, so no walk gets longer.
- Outside the spatial audio band (x -30..38, z 10..22, section 8.2), so the 10, 30 and 60 m test
  stays a clear line of sight.

### 14.2 Fences, paths and signs

- **Fences** (split rail, 1 m, visual only): field A's north and south sides (z -14 and 0, x 23..37,
  gap x 28..32 for the walk), field B's north side (z -11, gap x 70..74), the moonflower bed's west,
  south and east sides (north open), and two wings beside the farm gate (x 104.5, z -20..-8.5 and
  -1.5..10).
- **Paths** (packed dirt, visual only, no collision, 2 cm high; P5-21, CEO: every structure leads to
  another and the stray barn-back path to the pen is gone): the 3 m cart route path (section 6.1) and
  1.6 m side paths, all in `PATHS` in `build_farm.py`. Network, each a straight leg or two:
  barn door (-2.5, 1.3) to the yard junction (-25, 9); junction to farmhouse door (-45, 1); junction to shed door (-15, 25);
  shed door to fuel drum (-10, 26); farmhouse to Prize Pumpkin (-46, 31); generator (-11, -5.5) down to
  the barn-to-junction path; junction north to the pen gate (-24, -27); barn door east (2.5, 1.3) to (10, 1.5), then
  to the cart route at (10, 8.5); crate (73.5, 5) east to (90, 5), then north to the route at (90, -10.8);
  crate (72.5, 5.2) to the moonflower bed (61, 17.8); well (49, -20): a stub (49, -23) to (49, -20) off the cart route (P5-47, `ToWell`). The gate and town stand sit on the route lane. So the network is
  two connected groups, east and west, that meet across the open ground in front of the barn door; every
  building and prop is on one. Each strip reaches 0.8 m (half its width) past its end points, so the barn-door paths start at
  x = +-2.5 and none enters the 1.2 m doorway lane; none touches a field, plot, corn block or wall, and the
  parked cart at (5, 6) stays clear of every side path.
- **Signs** (post with a 2.6 m label that faces the camera and darkens at night): FIELD A (21.5, 0.5),
  FIELD B (63.5, -8), MOONFLOWERS (55, 17), STORE (75, 6.5), TOWN (102, -10), PRIZE PUMPKIN (-42, 28),
  TOOL SHED (-11, 23.5), PEN (-20.5, -25.5), FARMHOUSE (-39, 3), WELL (52.5, -18).

### 14.3 Landmarks

Tall shapes that read over the 2.4 m corn, so a player in the yard or the corn can tell direction.
All visual only.

| Landmark | (x, z) | Height | Reads as |
|---|---|---|---|
| Silo | (6, -53), in the north ring behind the barn | 14 m + dome | North |
| Water tower | (40, 64), in the south ring | 17 m | South |
| Windpump | (45.5, -20), beside the well (P5-47; was (-28, 7)) | 9 m | The well between the fields |
| Gate arch | (105, -5), over the farm gate | 4.9 m, "TOWN" facing west | The way out |
| Hay stack | (38, 12), off the audio test line (z 16) | 1.6 m | Yard clutter by field A |
| Wood pile | (-20, 29), by the shed | 0.9 m | Yard clutter by the shed |

## 15. More corn (P5-31, CEO STOP 6)

The CEO asked for more corn so the creature has cover and routes across the farm, most of all round
"farm 2" (inference: field B, the far field; confirm with the CEO). `build_farm.py` list `PATCHES`
adds six `CornBlockers` (`Patch1` to `Patch6`, layer 5, 2.4 m) to `farm.tscn` only; `farm_phase1.tscn`
is unchanged. Each has a `creature_cover` point (cover_17 to cover_22) inside it, so Lurk wanders to
it and Stalk and lures start from it (the creature walks through corn, no nav mesh to bake).

| Patch | Rectangle | Cover | Kind | Role |
|---|---|---|---|---|
| Patch1 | x 68..78, z -40..-20 | cover_17 (73, -21.5) | island, field B | North of the cart route (6 m off R5 to R7); links the ring to field B's north side |
| Patch2 | x 94..100, z -30..-16 | cover_18 (95.5, -17.5) | island, field B | East of field B beside the gate approach, about 6 m off the R7 to R8 leg |
| Patch3 | x 78..84, z 14..30 | cover_19 (81, 15.5) | island, field B | South of the crate and its path, 9 m off the store path |
| Patch4 | x 57..60, z -8..0 | cover_20 (58.5, -4) | island, field B | Between strip 3 and field B, 6 m from the headcount row (x 66), 4.4 m off the A-to-B walk |
| Patch5 | x 99..102, z 16..30 | cover_21 (100.5, 23) | island, field B | South-east of field B, clear of the east tree line (x 97) |
| Patch6 | x 66..72, z 38..55 | cover_22 (69, 39.5) | strip 5 | Reaches north from the south ring toward the moonflower bed and the crate |

- Rules kept (checked by `check_farm.gd`, all PASS): every marker, tree canopy, path, fence and
  doc 04 s8.7 walk stays clear of the patches; every corn distance in section 8.4 for the pumpkin, drum, barn door,
  shed door, pen gate, generator and farm gate is unchanged; the cart route's closest pass to
  corn is still 3.7 m. Gaps between patches and old corn are 3 m or more (Patch5 to the east ring), so players always have a way round.
- Changed: corn within field B's centre is now 12 m (was 20 m), and within the crate 10.8 m (was 20 m).
  Field B is no longer at the ghost 20 m limit; the ghost sees corn edges there (section 8.4).
  Section 5.1 ("6 m or more from corn") holds for every plot and headcount row (Patch4 ends 6 m from x 66).
- I tried a seventh strip (x -52..-46, z -45..-25, north of the farmhouse) and dropped it: it sits on
  the West tree line (West2, 3, 5).
- Phase 2 scene totals after P5-31: 22 cover points. P5-51 (section 16) adds nine more, 31 in all (`check_farm.gd` counts it).

## 16. Corn through the farm (P5-51)

The CEO said the creature "moves through corn but it's only really around the edges". Sections 3 and 15 put
corn on the ring, four strips and six islands, and the middle of the clearing stayed open ground (the creature
crossed it in plain sight). `build_farm.py` list `WEAVE` adds nine `CornBlockers` (`Weave1` to `Weave9`, layer 5,
2.4 m) to `farm.tscn` only (`farm_phase1.tscn` is unchanged). Each has a `creature_cover` point (cover_23 to
cover_31, section 7.2) inside it, so Lurk wander, Stalk and the night lures start from it. Each block either
touches the ring or an older corn block, or leaves a gap of 3 m or more, so no sliver gaps.

| Block | Rectangle | Cover | Role |
|---|---|---|---|
| Weave1 | x 42..48, z -45..-31 | cover_23 (45, -36) | Reaches south from the north ring to the well and the R4 corner of the cart route |
| Weave2 | x 22..36, z -26..-20 | cover_24 (28, -23) | Hedge on field A's north side, between the barn and the field |
| Weave3 | x -6..4, z -45..-30 | cover_25 (-1, -37) | Behind the barn, the pen's east side; the barn's door is on the south wall (z 0), so no doorway is touched |
| Weave4 | x 8..14, z 30..55 | cover_26 (11, 34) | Reaches north from the south ring into the yard, south of the audio band (section 8) |
| Weave5 | x 20..36, z 24..28 | cover_27 (28, 26) | Orchard edge, field A's south side |
| Weave6 | x 52..66, z 43..49 | cover_28 (59, 46) | Joins strip 3 to Patch6 and covers the moonflower bed's south side |
| Weave7 | x 72..84, z 33..40 | cover_29 (78, 36) | Links Patch6 to Patch3 along the south side of the moonflower bed; 28 m south of the crate (72, 5), so it is cover on the way, not at the crate |
| Weave8 | x 84..94, z 23..28 | cover_30 (89, 25.5) | East of the crate, south wing of the gate approach; reached by a detour, see below |
| Weave9 | x -38..-32, z 40..55 | cover_31 (-35, 44) | Second strip beside the Prize Pumpkin (Strip 1 is the first) |

- Rules kept (checked by `check_farm.gd` `_weave()`, "9 of 9 weave blocks pass"): every plot and headcount row 6 m or more
  away (section 5.1), the cart route 3.7 m or more (section 6), every doc 04 s8.7 walk 1 m or more, every marker, tree
  canopy, path, fence and side path clear, the well (49, -20) and all work spots reachable, no block in the audio band
  (x -30..38, z 10..22), the Prize Pumpkin 30 m or more from any door, and the s8.4 corn distances to the drum, doors,
  pen gate, generator and farm gate unchanged. Day safety is unchanged: the Creature uses cover points only at night
  (day cover is cover_15 under the AI Director's keep-out, inference from reading `creature.gd` and `ai_director.gd`).
- Reaching them: `check_corn_creature.gd` now covers cover_17 to cover_31. In Lurk the Creature reaches each new point from the ring in 11 to 29 s,
  except cover_30 (51 s: it detours east around the crate and store, inference from the position it stopped at; a
  longer test wait settles it). Stalk from each point reaches a stand-off or chases.
- Bot season measure (`tests/creature/test_p5_51.gd`, seed 1 and 2, 3 nights, free bots): the Creature stood in the
  new corn 10 s and 7 s of 900 (0 s before). Bots keep it on one goal most nights (cover_01 240 to 287 s of 900 in
  Lurk), so the seasons barely move it. The direct measure is the wander draw: of 400 draws per region from the middle of the farm,
  `pen` 400, `pumpkin` 100, `field_a` 85, `moonflower` 149 and `yard` 0 / `field_b` 0 pick a new point.
  Inference: free bots do not pull it around enough to show the corn; a playtest settles it.
- Perf (doc 07 s10.2, one windowed instance, vsync off, day, 20 s): barn door 1.01 ms / 195 draws, clearing 0.88 /
  81, corn lane 0.90 / 47, road 1.15 / 387, new spot (28, -12) facing Weave2 0.95 ms / 162 draws, 60k prims. All under the budget; no
  spot over 33 ms. (P5-38's 2.2 ms figures came from four instances at once.)
