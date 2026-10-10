# 07 Art Direction & Asset List

Owner: Technical Artist  Task: PP-08  Status: In review

This is the 3D Artist's work list and the lighting, material, shader and post-processing spec for the
Technical Artist (me). Doc 01 is the source of truth. Every number carries a source tag: `doc 01
"<heading>"`, `doc 02 s<n>` and so on, `placeholder` (a starting value to tune, easy to change),
`inference` (my reading, with what would settle it) or `unmeasured` (a budget that needs a profile
run; no render code exists yet, so nothing in section 10 has been measured).

## Contents

1. Art direction
2. Scale, palette and low-poly rules
3. Lighting plan
4. Light registry, dimming and the flicker rule
5. Darkness that is scary but playable
6. Fog and post-processing
7. Materials and shaders
8. Characters, Taint, ragdoll and ghost look
9. Dawn Report card style
10. Corn rendering and the 4-player budget
11. Asset list
12. Phase priority summary
13. Gotchas
14. Questions raised
15. Model sources (P4-40, D-151)

## 1. Art direction

- **One idea: cozy by day, wrong by night** (doc 01 pillar "cozy day, terrifying night"). The same
  places, same props and same models, lit differently. Night is not a second art set; it is the day
  set with the lights taken away. Saves assets, and makes the contrast the whole look.
- **Low-poly, flat-shaded, hand-painted feel** (inference from the solo, small-team scope and the
  Godot Forward Plus renderer in CONTRACTS; settled by the CEO's reaction to the first gray-box
  render). Large clean shapes, few materials, no photo textures. Props read at a glance from 30 m.
- **Show the creature last.** By day only parts and motion (head above corn, stalks parting); at night
  a clear view only mid-chase for under 1 s; lunges cut to black; stares and hallucinations are
  distant silhouettes (doc 01 "The creature"). So creature models are built for silhouette first and
  detail second; nothing about them is optimised for a close inspection.
- **No HUD markers.** Everything the player needs is in the world: pegboard outlines, flags, a
  wrinkled leaf on a thirsty crop, the generator hum (doc 01 "Interface"). Art makes those readable.
- **Lit means safe, and it must look it** (doc 01 "Light is the rule"). A lit window or porch is the
  warmest, most saturated thing at night. A dark building is the darkest shape on the horizon.

## 2. Scale, palette and low-poly rules

**Scale** (CONTRACTS section 3): 1 unit = 1 m, Y up, models face -Z, origin at the base (feet);
buildings have the origin at the main door's outer threshold (D-007). Farmer 1.8 m, eye 1.65 m; corn
2.4 m (doc 01 "Corn").

**Palette.** Hex values are `placeholder` and live in `assets/materials/palette.tres`, one swatch
resource, so a re-grade is one file.

| Role | Day | Night (same object under moonlight) |
|---|---|---|
| Sky | warm pale blue `#9CC6E0` | deep blue-black `#070B16` |
| Corn | gold-green `#B9A545` | blue-grey `#2A3140` |
| Soil | brown `#6B4A2F` | near black `#14100E` |
| Wood and buildings | red barn `#9A3B2B`, weathered grey boards `#8A8277` | cold grey `#1F2530` |
| Lit light (lantern, porch, window) | warm amber `#FFB45A` | the same, and it must be the brightest thing in frame |
| Moonflower glow | pale cyan `#7FE6D8` | same |
| Ghost / spirit | cold white-blue `#BFD8FF` | same |
| Taint | oil black `#0A0710` with a purple sheen `#3A1F4A` | same |
| Creature eyes and ember | orange-red `#FF5A1F` | same |

Rule: no object is pure black or pure white. Rule: only these things ever glow at night: warm light
sources, moonflowers, and Taint-free spirit tones, plus two fixed exceptions that are part of the
creature's tell: the creature's ember eyes and the corn husk heart. Nothing else glows. If something
else glows, players will misread it.

**Low-poly budgets** (all `placeholder`, tune after the first full-farm render):

| Class | Triangles per model | Texture |
|---|---|---|
| Hand tool, small prop, seed packet | up to 300 | shares the 256 px prop atlas |
| Crop stage, animal, trap | up to 800 | shares the prop atlas |
| Large prop (cart, generator, well, pen fence segment) | up to 2,000 | one 512 px texture or vertex colour |
| Farmer character (with sleeves and hands) | up to 4,000 | one 512 px texture |
| Creature body (each of 4) | up to 5,000 | one 512 px texture |
| Building (exterior and interior together) | up to 12,000 | one 1024 px atlas |
| Corn stalk (single mesh, section 10) | 40 high LOD, 12 mid, a 2-quad card far | shared |

Use vertex colour wherever a flat colour will do. Trim-sheet or atlas textures only; no unique 2K maps.
Every mesh gets a simple collision shape or none (the 3D Artist does not make physics shapes; the
level layer does, CONTRACTS section 3).

## 3. Lighting plan

Environment, sun and fog per clock phase. Phase ids and lengths come from doc 02 s3 (day 540 s, dusk
60 s, night 300 s, Harvest Moon no timer, 900 s cap). Phase environments are Godot `Environment`
resources in `game/render/environments/`, blended by one script keyed to the Clock phase and the
phase's progress (a function of time, not of random numbers, so every peer looks the same).

| Phase | Sun | Ambient | Fog | Mood |
|---|---|---|---|---|
| `day` | warm directional, 55 degree elevation at noon, soft shadows, energy 1.2 | sky light, warm, 0.8 | thin haze, colour `#D8E2E8`, density 0.0008 | Cozy. Long shadows only late in the day. |
| `dusk` (60 s) | sun drops to 5 degrees, colour shifts amber to red, energy 1.2 to 0.1 | falls from 0.8 to 0.25 | thickens to density 0.004, tint purple-orange | Lights come on in the buildings as the sun leaves. |
| `night` | no sun; one cool moon directional at 35 degrees, energy 0.12, colour `#8FA8D8`, shadows on | 0.25 floor, blue | ground fog, density 0.012, colour `#0D1220` | Dark, readable shapes (section 5). |
| `dawn` | rises amber from the horizon over the Dawn Report load | rises to day values | burns off | Relief. Matches the Dawn Report card. |
| `harvest_moon` | as `night` but moon energy 0.2, full orange-white moon low and large, no timer | 0.3 | as `night` but slightly lighter | Same dark, but the sky says "the last night" (doc 01 "Harvest Moon"). |

Each value is `placeholder`; the timings are doc 02 s3. The sun colour curve is a `Gradient` resource,
so tuning needs no code. Day-to-dusk to night is continuous inside one `Environment` (no pop), and
the sun's elevation at the time the lights switch on is the one number that matters: lit buildings
and the warm light reach full strength before the ambient falls below 0.5.

**Shadows.** One cascaded directional light (sun or moon), 2 cascades, 60 m max distance
(`placeholder`). All local lights (lantern, porch, bulbs) cast no shadows except the held lantern,
which casts one low-res shadow so corn stalks throw moving shadows. Shadow-casting lights are limited
to 4 on screen (`unmeasured`, section 10).

**Lit and dark buildings.** Doc 01 "Light is the rule": the creature never enters a lit building and
may enter a dark one.

- **Lit building.** A warm interior light, a porch light on the door, and window glow cards (emissive
  quads, not lights). Doorway light is an `OmniLight3D` of **radius 6 m** at the door (doc 04 s4
  leaves this to doc 07: I keep the 6 m, which doc 03 s9 already uses for "no traps near a lit
  doorway"). It is not larger, because a bigger pool would blur with the 20 m pumpkin circle
  (doc 04 s4) and the player must be able to tell where safety ends. A painted ground decal (warm light pool) matches
  the 6 m edge so the player can see it from outside.
- **Dark building (generator dead).** All building lights off (via `apply_lights`, doc 05 s12). The
  windows go black, the door is the darkest rectangle in the wall. Interior is lit only by moonlight
  through windows (a single weak spot cone, energy 0.1). A banging door (doc 01 "Nights") has a
  slightly rattling mesh and no light effect.
- **Barn lobby.** The lobby is the dark barn at night (doc 01 "Lobby"): three warm bulbs on a hanging
  fixture, two window slabs of moonlight, and a long contrasting door. Lit and cozy even though it is
  "dark".

**Carried and placed lights** (all `placeholder`):

| Light | Colour | Range | Energy | Notes |
|---|---|---|---|---|
| Lantern | `#FFB45A` | 9 m | 1.6 | Held; creature sees it at 40 m (doc 03 s3.2). Casts a shadow. |
| Brighter lantern (store item, doc 02 s10) | `#FFC47A` | 13 m | 2.4 | Same model, larger glass. |
| Porch light and doorway | `#FFB45A` | 6 m | 1.2 | Doc 04 s4 left 6 m to doc 07; kept. |
| Interior bulb | `#FFD8A0` | 8 m | 1.0 | One per room. |
| Cart lantern | `#FFB45A` | 7 m | 1.2 | Mounted on the cart, swings with it. |
| Moonflower glow | `#7FE6D8` | 3 m | 0.5 | Steady, section 7. |
| Recording light (doc 06) | `#FFB45A` | 2 m | 0.6 | Lantern-style tally light; stays steady, never flickers. |
| Ghost glow on the creature | `#BFD8FF` | n/a | rim only | A rim shader, section 8; no `Light3D`. |

## 4. Light registry, dimming and the flicker rule

### 4.1 One controller, no direct light writes

Every gameplay light is a `LightRig` node (`game/render/light_rig.gd`, a script on a `Node3D` that
owns one or more `Light3D` and emissive meshes). `game/core/lights.gd` (doc 05 s12) is the only thing
that calls its setters. Nothing else touches `Light3D.light_energy`.

- `LightRig.set_on(on: bool)`: on or off. Ramps over 0.2 s (a smooth step, never instant), except
  `blow_out()`. The dead-generator fade (4.2) is the one slower exception: 0.6 s, which is below the
  slew cap, so it never breaks the 0.2 s rule.
- `LightRig.set_dim(fraction: float)`: smooth multiplier from 0 to 1. The generator curve below.
- `LightRig.blow_out()`: instant off with a smoke puff (doc 01 "Ghosts"; doc 06 s11). The only
  instant-off, and it is a one-way event (the player must relight).
- `LightRig.energy_override(value, token)`: used only by the ghost flicker (4.3).

The setters slew-limit change speed, so a bug elsewhere cannot make a light strobe: the maximum
change rate is `full energy per 0.2 s` outside the override path.

### 4.2 Generator dimming (not a flicker)

Doc 02 s14 (placeholder): below 25% fuel the lights dim. Doc 05 s12 drives it with
`apply_generator(fuel_fraction)`.

- Dim factor `d = smoothstep(0.0, 0.25, fuel_fraction)` mapped to `0.35 + 0.65 * d`, so the lights
  never fall below 35% until the generator is dead (`placeholder`, tune so the last 30 s are visibly
  worse but not dark).
- Colour drifts slightly warmer (amber to deep orange) as it dims, so low fuel reads as "tired", not
  "off".
- Dimming is monotonic and slow: no oscillation, no noise term, no random jitter. A dead generator
  (`power_on == false`) goes through `set_on(false)` over 0.6 s, a clear fade rather than a click.
- The generator hum (audio, doc 08) drops pitch with the same `fuel_fraction`; the art side only owns
  the light and the gauge on the generator body (a plain swinging dial, no HUD).

### 4.3 The ghost flicker (the one unfakeable signal)

Doc 01 "Ghosts > Lantern flicker": only a ghost can flicker a light, so a flicker is proof. The rule is
therefore absolute.

- **The effect.** On `apply_flicker(light_id)` (doc 05 s12), `LightFlicker.flicker(light_id,
  caller_peer)` in `game/ghost/light_flicker.gd` runs a fixed pattern on that light's `LightRig`
  through `energy_override`:
  four square steps, dim, on, dim, on, 0.25 s each, 1.0 s total (2 dips per second, D-046: never
  above 3 flashes per second), each dip to 30% energy rather than off, with the light colour shifted
  to cold white-blue `#BFD8FF` for the duration, then back to the previous colour and energy over
  0.1 s (`placeholder`, tune by feel within D-046). With `photosensitive_safe` on (doc 01
  "Photosensitivity safety"), that player sees one smooth cold-blue dim to 50% and back over 1.0 s
  instead. Square steps and the cold colour are what separate it from
  dimming (smooth, warm, slow) and from a blow-out (single instant off, warm puff, stays off).
  Lanterns, bulbs, porch lights, moonflower glow and cart lanterns can all be flickered; the pattern
  is the same for all. A ghost has a short per-ghost cooldown (doc 01 "Ghosts"; value in doc 02).
- **Who may call it.** Only `game/ghost/light_flicker.gd`. It lives in `game/ghost/` per doc 05 s12
  (Gameplay owns that file); the render side only supplies `energy_override`.
- **Nothing else may look like it.**
  - No light has an animation, noise or tween on energy faster than 0.5 Hz or with a swing above 15%.
    Candle and fire movement are done in the mesh and particles, never in the light.
  - Moonflower glow is a steady emission and a steady 3 m light, no pulse.
  - The recording light and a staged lantern blow-out stay steady (doc 06).
  - Post-processing never pulses brightness (no flash, no strobe, no lightning). The only full-screen
    brightness changes are the ones the clock phase and the cut-to-black on a lunge (section 8).
  - The Taint overlay and screen smudge change slowly and are not light.
- **As built (P3-09).** `LightFlicker.play(rig) -> bool` (a static call on the `LightRig`; the host
  resolves `light_id` to the rig in `ghost_powers.gd`) runs the pattern above: 30% of the rig's own
  level, 0.25 s steps, `#BFD8FF`, colour back over 0.1 s, then the override is cleared so dimming and
  outages carry on. It refuses (returns false) when the rig is at or below 5% (off, out or blown out),
  and runs one pattern at a time per rig. The photosensitive variant is not built: no
  `photosensitive_safe` setting exists yet. Placeholder look; the Technical Artist may replace it
  inside the same function.

### 4.4 How QA enforces it

Three checks (copied to doc 09 by QA):

1. A grep of `game/` for `flicker` (case-insensitive) must match only `game/ghost/` and the message
   names in the net layer (`request_flicker`, `apply_flicker`).
2. A grep of `game/` for `energy_override` must match only `game/render/light_rig.gd` and
   `game/ghost/light_flicker.gd`.
3. A grep of `game/` for `light_energy` must match only `game/render/`. Everything else goes through
   `LightRig`.

The host's `request_flicker` handler checks `Game.is_ghost(caller_peer)` first (doc 05 s12), so a
non-ghost client cannot trigger it even by hand-crafting a message.

## 5. Darkness that is scary but playable

The goal: the player can walk, see a wall or a corn edge, and tell a lit door from a dark one; they
cannot see a creature at 25 m. Both are required (doc 01 "Nights", "Light is the rule").

- **Floor, not zero.** The night ambient is never below 0.25 (section 3) and the moon is a real
  shadowed directional light, so terrain edges, building outlines and the corn wall read as shapes.
  A pure-black night is a bug. `unmeasured`: set 0.25 so that on a calibrated monitor you can see the
  road lane against corn; settle by showing the CEO a night screenshot on their monitor (section 10).
- **Contrast lives in the lights.** Lit sources are the brightest thing by a wide margin (section
  3). A player in the open at night uses the lantern light pool as their visible radius. Without a
  lantern, 6 to 8 m of ground silhouette is visible by moonlight; beyond that, shapes only.
- **No auto-exposure.** Fixed exposure per phase (a pop in brightness reads as a flicker, section
  4.3). The `Environment` has auto exposure off.
- **Gamma and brightness slider.** A settings brightness slider moves the ambient floor between 0.2
  and 0.4 (doc 05 s15 screens). It does not touch lights, so it cannot hide a flicker or a
  lit/dark difference. This is the accessibility valve; the default is the 0.25 floor.
- **Silhouette rule.** The corn wall, building outlines and sky horizon must differ by at least a
  visible step at night (sky slightly lighter than corn). A distant creature stands against the sky
  line only where the corn is shorter than it; that is the intended scare window.
- **Vignette** (section 6) keeps the screen edge darker than the centre, so the centre is playable
  and the edge is where fear lives.

## 6. Fog and post-processing

- **Fog.** `Environment` volumetric fog is off (cost, `unmeasured`); use depth fog plus a ground-height
  fog layer, densities in section 3. Fog colour matches the horizon colour, so distance fades into
  the sky and not into grey. Fog is a **mood and clue** tool: at night it hides the far end of the
  road; it never hides a trap clue (doc 01 clues are close-range).
- **Post stack (in order).** All set by the `Environment` plus one fullscreen `ShaderMaterial` pass in
  `game/render/post/`:
  1. Tone map (filmic). Fixed exposure.
  2. Colour grade: a lookup texture per phase (`day` warm and saturated, `night` desaturated blue),
     blended with the phase environment.
  3. Vignette: strength 0.15 by day, 0.4 at night (`placeholder`), radius widening with stamina so
     tired players lose edge vision a little.
  4. Film grain: very light by day (0.02), stronger at night (0.06). Static noise, not animated
     brightness.
  5. Taint overlay (section 8).
- **No bloom flares or lens flares on lights.** Bloom is subtle (threshold 1.2, intensity 0.25) so the
  lit sources feel warm; a pulsing bloom would imitate a flicker, so bloom intensity never changes at
  runtime.
- **Quality switch.** A "low" setting turns off the grain, fog layer and shadows on local lights
  (doc 05 s15), so the game stays playable on a weak machine without losing the signal lights.

## 7. Materials and shaders

All in `assets/materials/` (`.tres`) and `game/render/shaders/` (`.gdshader`). Few, shared materials;
a new material needs a reason.

| Material | Shader | Notes |
|---|---|---|
| `mat_flat_lit` | standard, vertex colour, roughness 1, no specular | 90% of the world |
| `mat_prop_atlas` | standard, 256 px atlas | tools, small props |
| `mat_building_atlas` | standard, 1024 px atlas | buildings |
| `mat_corn_stalk` | custom, instanced, wind sway in the vertex shader, per-instance colour jitter | section 10 |
| `mat_soil_wet` / `mat_soil_dry` | standard, darker and glossier when watered | plot state is readable without HUD (doc 01 "Farming") |
| `mat_crop_wilted` | standard, droops via vertex offset, desaturated | "wrinkled leaf" for a thirsty crop, a mesh shape, not a glow |
| `mat_emissive_warm` | unshaded emissive | window glow cards, lantern glass |
| `mat_moonflower` | emissive `#7FE6D8`, steady, 3 m `OmniLight3D` | glow is constant, no pulse (section 4.3) |
| `mat_taint_surface` | oil-black sheen, slow noise scroll (not brightness) | Taint objects, unpicked moonflower once rotted (doc 01) |
| `mat_glass_lantern` | emissive amber, a flame mesh with its own vertex wobble | flame moves, the light does not |
| `mat_ghost_rim` | rim light shader, `#BFD8FF` | glow on the creature seen by ghosts (doc 05 s14) |
| `mat_paper` | paper texture, no lighting | Dawn Report card |

Rule: no material animates emission or light energy faster than 0.5 Hz. Wind, sway and scrolling use
vertex offsets or UV scroll, which are position or texture changes, not brightness changes.

## 8. Characters, Taint, ragdoll and ghost look

- **Farmer.** Same body for every player, tinted overalls per player colour (6 colours, D-159). Visible
  sleeves and hands in first person (the Taint stain needs them). Third-person body for other
  players, standing at 1.8 m. Cosmetics (hats, overalls) are DD Phase 5 and out of scope.
  **Exception (D-144):** one fixed hat per role is in now, as a role marker rather than a cosmetic
  (`hat_<role_id>.glb`, s11.7). Picked hats and other cosmetics stay Phase 5.
- **Taint stain on hands and sleeves** (doc 01 "Taint"): black oily stains climbing from fingers
  toward the elbow as a `taint_level` shader parameter on the hand and sleeve material, in steps tied
  to the Taint stages in doc 02. Visible to all (doc 01), so the third-person body uses the same
  material. For the local player, doc 05 s10 adds a faint dark smudge and fog at the screen edge.
  A **colour-blind-safe cue** is the shape: stains are dark and glossy against matte cloth, with a
  hard edge pattern, readable in greyscale (inference; settled by testing a greyscale screenshot).
  *As built (P3-08):* `game/render/taint_look.gd`. Until `tool_hands.glb` exists, two capsule
  forearms with `taint_hands.gdshader` hang under each player's camera and show only while Tainted.
  `taint_level` is fixed at 1, because doc 01 says a second Taint changes nothing, so the "stages"
  above are unsettled (Game Designer). The local player also gets `taint_screen.gdshader`, a
  CanvasLayer at layer 5 that fades in over 3 s (`placeholder`). Ground sources use
  `taint_ground.gdshader`: an oil puddle for leavings and a seed scatter for strange seeds. The dead
  crow is still a dark box. None of these is a light or emissive.
- **Shaken.** Doc 01 gives Shaken no visual. I add none; the camera and audio handle it (inference;
  settled by the Game Designer if a cue is wanted).
- **Ragdoll knockdown.** After a jumpscare or trap (doc 01 "Traps"), the farmer swaps from the
  animated rig to a ragdoll (Jolt physical bones, CONTRACTS) for about 1.5 s (`placeholder`), the
  camera drops to ground level and the vision tilts. Lunges cut to black, then fade up on the
  ragdoll (doc 01 "The creature"): the cut hides the creature's close-up. The dead player's body
  stays in the world as a ragdoll prop (`char_farmer_ragdoll.glb`), same mesh, no animation.
- **Ghost look.** A dead player becomes a ghost (doc 01 "Ghosts"): translucent cold-blue body, no
  shadow, fades to nothing in light. Ghosts see the creature as a smeared silhouette within about
  20 m (doc 01; doc 05 s14): the creature gets `mat_ghost_rim` and a motion-smear on its outline, only
  on the ghost's own screen. Living players never see this.
- **Creature bodies** (doc 01 "The creature"): Gaunt (hunched, dark hide), Scarecrow (ragged coat,
  stitched sack head, ember eyes `#FF5A1F`), Boar brute (tusks, iron collar, chain), Corn husk
  (stalks and peeled leaves around a glowing heart). The corn husk's "glowing heart" is the one
  creature glow and is hidden inside the husk shape; it must not read as a light source (low energy,
  no `Light3D`).
- **Disturbance clues** (doc 01 "Clues"): footprints, claw marks, feathers, teeth marks, moved
  scarecrows. All are decals or small meshes, visible only close; they use `mat_flat_lit` and never
  glow.

## 9. Dawn Report card style

A skippable newspaper card (doc 01 "Dawn Report"). Client UI in `game/ui/` (doc 05 s14); templates and
copy come from doc 03 s17. Art spec:

- **Paper.** A cream sheet `#E8DCC0` with a subtle fibre texture, slightly rotated 0.5 degrees, a
  fold line across the middle, a dark vignette from the card to the screen edge. `mat_paper`.
- **Masthead.** "THE HARROW COUNTY GAZETTE" in a bold slab serif at the top (name is a
  `placeholder` for the Game Designer's town name), a thin rule under it, the date as "Day N" and
  the weather.
- **Sections in order** (doc 01 "Dawn Report"): cash-in, bill, payment, farm damage; then Best
  Impression, Most Wanted, Cause of Death, Hero of the Night. Money lines use a ledger look: a dotted
  leader between label and amount, right-aligned numbers, red ink for the bill.
- **Headlines** use the doc 03 s17 templates, for example "BEST IMPRESSION: ...", "MOST WANTED: ...",
  "No obituaries this morning. The town is suspicious.", "THE FARM WENT QUIET. Four chairs, no
  farmers." Obituary text sits in a narrow column with a thin border, small-town style.
- **Photos.** A halftone dot treatment of a flat silhouette per player (the farmer in their colour),
  not a screenshot. Off players (no voice, doc 03 s17) are shown as text plus a speaker icon and a
  sound cue (doc 08), no waveform.
- **Season Awards card** uses the same paper, with the wide masthead "SEASON'S END".
- **Motion.** The card slides up, settles with a small paper rustle, and each section fades in on
  click or 3 s. Skippable at any time by the host and by any client's local skip (doc 01).
- **Type.** One serif display face, one body serif, both open-licensed and bundled; no system fonts.
  Final typeface is a CEO call if a download is needed (see section 14, FOR CEO).

## 10. Corn rendering and the 4-player budget

Corn is the main cost and the main design device: it blocks sight and sound (doc 01 "Corn"; layer 5
in CONTRACTS section 3), 2.4 m high, 25 m deep around the clearing (doc 04) plus 6 m strips (strips 1
to 4). Corn area (inference from doc 04 coordinates): ring about 25 m wide around a roughly 170 by 100
m clearing, about 9,000 m2, plus strips of about 90, 47, 70, 17 m of 6 m width, about 1,300 m2.

### 10.1 Design

- **Visuals and gameplay are separate.** The sight-blocking is a collision layer (layer 5), built by
  the level layer as coarse boxes or thick wall strips that follow the corn edges. Visual stalks are
  only drawing. The corn can be low-cost cards without changing what blocks sight, which is why this
  is possible at all.
- **Rendering.** Corn is drawn with `MultiMeshInstance3D`, one MultiMesh per 16 by 16 m cell, so
  frustum culling works at cell level. Stalks per m2: 6 (placeholder, thin enough to look like a
  field). That is about 62,000 stalks over the farm; not all drawn at once.
- **Three levels of detail.** Within 12 m: 40-triangle stalk with a leaf quad. 12 to 35 m: 12-triangle
  stalk. Beyond 35 m: a flat two-quad card per cluster (impostor) with the same wall silhouette.
  Beyond about 60 m the corn wall is drawn as a textured band mesh. The cutoffs are `placeholder`.
- **Wind.** Sway is a vertex shader (`mat_corn_stalk`), no CPU cost, no per-frame uploads.
- **Parting stalks.** When the creature or a player moves through corn, stalks within 1.5 m of the
  mover bend away via a shader uniform array of up to 8 mover positions per frame (players and the
  creature). It is a cheap displacement in the vertex shader, and the "stalks parting" scare (doc 01
  "The creature") uses the same uniform. No per-instance CPU updates.
- **Shadows.** Corn casts no shadows from the sun or moon in the high LOD beyond 20 m. Only the held
  lantern shadow touches near stalks. Shadows on corn are the first thing to cut.
- **Per-peer cost.** Four players on one machine render four windows (QA multi, 4 instances), so the
  per-instance cost is what matters. Each instance renders only its own camera.

### 10.2 Budget (all `unmeasured`, `placeholder`)

| Item | Budget per instance |
|---|---|
| Frame time at 1280x720 | 16.6 ms (60 fps) with 4 instances running on the CEO's machine |
| Draw calls | 1,500 or fewer |
| Triangles on screen | 1,500,000 or fewer |
| Corn stalk instances drawn | 25,000 or fewer |
| Shadow-casting lights | 4 or fewer |
| Texture memory | 256 MB or less per instance |

The CEO's machine (this one, read from Windows for this doc): AMD Ryzen 7 9800X3D (8 cores), NVIDIA
GeForce RTX 5070 plus an AMD integrated GPU, 31 GB RAM. Godot may pick the AMD integrated GPU by
default on a hybrid system, which would make every number worse; the profiling run records which
adapter each instance used (see gotchas).

### 10.3 Profiling procedure (to be run, not reasoned)

Required before the budget is marked measured. Needs a scene with the corn in it (DD Phase 1 corn
walls at x -32..-57 and 46..71, doc 04 s9) so cannot be run yet.

1. `uv run tools/qa/multi.py -n 4` with the debug view on, each instance placed at a different spot
   (inside the clearing facing the corn wall, in the corn lane, at the barn door, on the road).
2. In each instance, record 60 s of frame time (the debug view shows ms) and the Godot Monitors for
   draw calls, triangles and video memory.
3. Pass: average 60 fps or better on every instance at the same time; no frame above 33 ms.
4. If it fails, cut in this order: corn shadows, local light shadows, grain, fog layer, high LOD
   range 12 to 8 m, stalks per m2 6 to 4, MultiMesh cell size. Record each change and the effect in
   the PP-08 follow-up handoff.
5. Record which GPU each instance used (`RenderingServer.get_video_adapter_name()`).

## 11. Asset list

Names follow CONTRACTS section 3: `<category>_<name>[_<part>][_<variant>].glb`, snake_case, nodes in
PascalCase, models in `assets/models/`, origin at the base. Dimensions are in metres (width x depth
x height, or radius) and come from doc 04 footprints where they exist; otherwise they are
`placeholder`. Phase is the DD phase that first needs it (P1 to P4; P5 is out of scope). Triangles
follow section 2.

### 11.1 Buildings (`bldg`, origin at the main door's outer threshold)

| Name | Dimensions | Phase | Source |
|---|---|---|---|
| `bldg_barn.glb` | 16 x 20 x 9 (x -8..8, z -20..0); as built (P5-14): 17.2 x 21.5 x 9.04 with eaves and trim, 3,156 tris | P1 | doc 04 s3 |
| `bldg_shed.glb` | 6 x 5 x 3.2, pegboard inside back wall; as built (P5-14): 6.8 x 6.1 x 3.44, 1,080 tris, `Pegboard` empty at the back wall, the board is a separate model | P1 | doc 04 s3 |
| `bldg_farmhouse.glb` | 12 x 10 x 7; as built (P5-14): 13.7 x 13.0 x 7.0 with porch and chimney, 2,332 tris | P2 | doc 04 s3 |
| `bldg_generator_house.glb` (optional; a lean-to over the generator) | 3 x 2 x 2.4 | P1 | inference |
| `bldg_town_stand.glb` | 3 x 2 x 2.8 | P4 | doc 04 s3 |
| `bldg_church.glb` (silhouette only, distant, with a bell tower) | 10 x 20 x 14 | P3 | doc 01 "Church bell" |

### 11.2 World props (`prop`)

| Name | Dimensions | Phase | Notes |
|---|---|---|---|
| `prop_generator.glb` | 2 x 1 x 1.2 | P1 | doc 04 s3; dial gauge, hum visual |
| `prop_fuel_drum.glb` | 1 diameter x 1.1 | P1 | doc 04 s3 |
| `prop_well.glb` | 2 diameter x 2.2; as built (P5-14): 2.41 x 2.08 x 2.23, 628 tris | P1 | doc 04 s3 |
| `prop_pegboard.glb` | 1.6 x 0.1 x 1.2 | P1 | painted outlines for each tool (doc 01) |
| `prop_sell_box.glb` | 1.2 x 0.8 x 1 | P1 | DD Phase 1 (40,20), doc 04 s9 |
| `prop_shipping_crate.glb` | 2 x 1 x 1.2 (as built, P5-12: 2.02 x 1.11 x 1.04, 552 tris) | P2 | doc 04 s3 |
| `prop_fence_segment.glb` | 3 x 0.1 x 1.2 | P1 | pen fence 12 x 10 m |
| `prop_fence_gate.glb` | 2 x 0.1 x 1.2; as built (P5-14): 2.02 x 0.14 x 1.29, `Leaf` pivots at the hinge | P1 | pen gate |
| `prop_farm_gate.glb` | 6 x 0.3 x 2.2; as built (P5-14): 6.4 x 0.4 x 2.28, `LeafL` and `LeafR` pivot at the posts; spans X, so the gray-box line along Z needs yaw 90 | P2 | doc 04 s3 |
| `prop_road_sign.glb` | 0.4 x 0.1 x 2 | P2 | |
| `prop_lantern_hook.glb` | 0.2 x 0.2 x 0.4 | P1 | for hanging lanterns |
| `prop_porch_light.glb` | 0.2 x 0.2 x 0.3 | P1 | has `LightRig` |
| `prop_window_glow.glb` | 1 x 0.05 x 1 | P1 | emissive quad (not a light) |
| `prop_door_barn.glb`, `prop_door_shed.glb`, `prop_door_farmhouse.glb` | 3.0 wide double leaf (P5-14, Q-306: matches the 3 m gray-box gap), 3.3 (barn), 2.5 (shed), 2.6 (farmhouse) tall; nodes `LeafL`, `LeafR`, pivots at the jambs (x -1.5, +1.5), swing about Y | P1 to P2 | hinged, host-owned open state |
| `prop_flag.glb` | 0.5 x 0.05 x 1.2 | P3 | placeable marker (doc 01) |
| `prop_scarecrow_field.glb` | 0.8 x 0.8 x 2 | P1 | start scarecrow (doc 04 s7: 2 at start) |
| `prop_scarecrow_player.glb` | 0.8 x 0.8 x 2 | P2 | store item |
| `prop_church_bell` | no asset | none | doc 01: heard, not seen; audio only, no model |
| `prop_dead_crow.glb` | 0.3 x 0.15 x 0.1 | P3 | doc 01 |
| `prop_strange_seeds.glb` | 0.15 x 0.1 x 0.02 | P3 | doc 01 |
| `prop_stolen_tool_marker` | no asset | none | tool drop; uses the tool model |
| `char_farmer_ragdoll.glb` | 1.8 long ragdoll | P2 | dead body; listed in s11.7, same file, not a second asset |

### 11.3 Tools and items (`tool`)

| Name | Dimensions | Phase |
|---|---|---|
| `tool_watering_can.glb` (plus `_quiet` variant) | 0.4 x 0.2 x 0.3 | P1 |
| `tool_hoe.glb` | 0.15 x 0.05 x 1.4 | P1 |
| `tool_shovel.glb` | 0.2 x 0.05 x 1.3 | P1 |
| `tool_seed_packet.glb` (variants `_turnip`, `_pumpkin`, `_moonflower`) | 0.1 x 0.01 x 0.15 | P1 (turnip), P2, P3 |
| `tool_scrap.glb` | 0.15 x 0.1 x 0.05 | P1 |
| `tool_fuel_can.glb` | 0.3 x 0.15 x 0.35 | P1 |
| `tool_lantern.glb` (plus `_bright` variant) | 0.25 x 0.25 x 0.34 (as built, P4-40; Director decision, QA fix); `_bright` is 0.30 x 0.30 x 0.38 as built. The glass is its own surface in `mat_emissive_warm`; to show an unlit lantern, override that surface by material name (P5-12) | P1, P4 |
| `tool_walkie_talkie.glb` | 0.08 x 0.04 x 0.2 | P3 |
| `tool_flare_gun.glb` | 0.25 x 0.05 x 0.18 | P3 |
| `tool_shed_lock.glb` | 0.1 x 0.05 x 0.15 | P3 |
| `tool_whistle.glb` | 0.08 x 0.03 x 0.03 | P3 |
| `tool_hands.glb` (first-person arms with sleeves; Taint material slot) | 0.5 x 0.15 x 0.15 | P1 |

### 11.4 Traps (`trap`)

| Name | Dimensions | Phase |
|---|---|---|
| `trap_bear_open.glb` | 0.6 x 0.6 x 0.15 | P1 |
| `trap_bear_closed.glb` | 0.5 x 0.4 x 0.2 | P1 |
| `trap_bear_item.glb` (disarmed, carried) | 0.5 x 0.4 x 0.2 | P1 |
| `trap_pit_cover.glb` (stalks and dirt over the pit) | 1.5 x 1.5 x 0.1 | P1 |
| `trap_pit_open.glb` | 1.5 x 1.5 x 1.5 deep | P1 |
| `trap_tripwire.glb` (post and bells) | 0.1 x 3 x 0.8 | P2 |
| `trap_fresh_dirt_decal.glb` | 1 x 1 x 0.02 | P1 |
| `trap_bent_stalks.glb` | 1.5 x 1 x 2.4 | P1 |
| `trap_glint.glb` | metal glint card | P1 |

### 11.5 Crops (`crop`, `pumpkin`) and plots

| Name | Dimensions | Phase |
|---|---|---|
| `crop_plot.glb` (3 x 3 m tilled square, dry and wet via material) | 3 x 3 x 0.15 | P1 |
| `crop_turnip_stage0.glb` to `_stage3.glb` (seedling to harvest) | up to 0.4 high | P1 |
| `crop_turnip_wilted.glb`, `crop_turnip_rotten.glb` | 0.4 high | P1 |
| `crop_pumpkin_stage0.glb` to `_stage3.glb`, `_wilted`, `_rotten` | up to 0.8 | P2 |
| `crop_moonflower_stage0.glb` to `_stage2.glb`, `_wilted` | up to 0.6 | P2 |
| `crop_moonflower_taint.glb` (unpicked at dawn becomes a Taint object) | 0.6 | P3 |
| `pumpkin_prize_giant.glb` | 3 diameter x 2.4 | P4 |
| `pumpkin_prize_large.glb` | 2 diameter x 1.6 | P4 |
| `pumpkin_prize_medium.glb` | 1.2 diameter x 1 | P4 |
| `pumpkin_prize_sad.glb` | 0.7 diameter x 0.5 | P4 |
| `pumpkin_prize_gnawed.glb` (teeth marks variant) | as size | P4 |
| `pumpkin_patch.glb` (4 m patch with vines) | 4 diameter | P4 |

Doc 04 s5: plots are 3 x 3 m; field A has 8 start plots and 4 upgrade plots; field B the same; the
moonflower bed has 4 plots (2 by 2); the Prize Pumpkin patch is 4 m across centred (-47, 33).

### 11.6 Corn (`corn`)

| Name | Dimensions | Phase |
|---|---|---|
| `corn_stalk_lod0.glb` | 0.15 x 0.15 x 2.4, 40 tris | P1 |
| `corn_stalk_lod1.glb` | same, 12 tris | P1 |
| `corn_card_lod2.glb` (2-quad cluster) | 1 x 0.2 x 2.4 | P1 |
| `corn_wall_band.glb` (far band, tiles along edges) | 4 x 0.5 x 2.4 | P1 |
| `corn_stalk_cut.glb` (flattened, "trampled" decal) | 1 x 1 x 0.05 | P2 |

### 11.7 Characters and creatures (`char`, `creature`, `animal`)

| Name | Dimensions | Phase |
|---|---|---|
| `char_farmer.glb` (rig: idle, walk, run, crouch, interact, emotes wave, point, shrug, scream; 4 tint slots) | 0.5 x 0.3 x 1.8; as built (P5-12) 0.61 x 0.38 x 1.8 (arm width, boot length), 2,152 tris of 4,000; Skeleton3D of 12 bones (`hips`, `spine`, `head`, `hat`, `arm_l/r`, `forearm_l/r`, `thigh_l/r`, `shin_l/r`), 9 animations named as listed, tint slot = material `mat_farmer_overalls`, Taint slot = `mat_farmer_sleeves` | P1 |
| `char_farmer_ragdoll.glb` (physical bones) | 1.8 | P2 |
| `char_ghost.glb` (translucent shell of the farmer) | 0.5 x 0.3 x 1.8 | P3 |
| `hat_<role_id>.glb`, one per role in `data/roles.json` (D-144): farmer straw hat, rancher cowboy hat, mechanic backwards cap with goggles, tracker hunting cap with ear flaps, carpenter hard hat, medic pillbox with red cross, night owl beanie with owl tufts and headlamp, radio operator cap with headphones and antenna, warden campaign hat, medium bent witch hat. Origin at the centre of the band's bottom edge, sits at 1.74 m on the head; up to 300 tris (small prop); vertex colour, nothing emissive | 0.24 to 0.72 wide, up to 0.5 tall (radio antenna) | P4 |
| `creature_gaunt.glb` | 0.9 x 1.06 x 2.1 (hunched; depth as built in P4-19, head and hump forward) | P1 (placeholder) |
| `creature_scarecrow.glb`, `creature_scarecrow_head.glb` | 1 x 0.6 x 2.2; as built 1.14 x 0.83 x 2.23 with level arms along the crossbar (P5-12; hat brim and coat set the depth) | P2 |
| `creature_boar.glb` (with `_chain` part) | 1.2 x 2.38 x 1.4 (length as built in P4-19) | P3 |
| `creature_corn_husk.glb`, `creature_corn_husk_heart.glb` | 1 x 1.07 x 2.4 (depth as built in P4-19) | P3 |
| `creature_smear.glb` (ghost-view silhouette, a hull of the active body) | as body | P3 |
| `animal_chicken.glb` | 0.3 x 0.4 x 0.4 | P1 |
| `animal_pig.glb` | 0.6 x 1.2 x 0.8 | P2 |
| `animal_cow.glb` | 0.8 x 2 x 1.5 | P2 |
| `animal_crow.glb` (perched, flying) | 0.3 x 0.3 x 0.2 | P1 |

Doc 04 s7 lists 9 crow markers, 7 scarecrow markers and a 12 x 10 m pen; the exact animal set comes
from doc 02 (inference; settled by the Game Designer if the pen holds other species).

### 11.8 Vehicles and town

| Name | Dimensions | Phase |
|---|---|---|
| `prop_cart.glb` (with lantern part `prop_cart_lantern.glb`, squeaks) | 1.62 x 3 x 1.8 (1.62 wide as built, P4-40; Director decision, QA fix; P5-12: 1.60 x 2.99 x 1.74, 1,384 tris, wheels are the separate nodes `WheelL` and `WheelR`, pivot at the hub, spin about X) | P4 |
| `prop_cart_pumpkin_slot.glb` (bite damage variant) | n/a | P4 |
| `bldg_town_stand.glb` | see above | P4 |
| `prop_road_lamp.glb` | 0.3 x 0.3 x 3.5 | P3 |

### 11.9 Textures, materials, shaders, UI and effects (Technical Artist)

| Path | What | Phase |
|---|---|---|
| `assets/textures/atlas_prop_256.png` | prop atlas | P1 |
| `assets/textures/atlas_building_1024.png` | building atlas | P1 |
| `assets/textures/farmer_512.png` | farmer | P1 |
| `assets/textures/creature_<name>_512.png` | four creature textures | P1 to P3 |
| `assets/textures/grade_<phase>.png` | colour grade lookups | P1 |
| `assets/textures/paper_cream.png`, `halftone.png`, `fibre.png` | Dawn Report | P3 |
| `assets/materials/palette.tres` | swatch resource (section 2) | P1 |
| `assets/materials/mat_*.tres` | all of section 7 | P1 to P3 |
| `game/render/environments/env_<phase>.tres` | five phase environments | P1 |
| `game/render/light_rig.gd` | light controller (section 4.1) | P1 |
| `game/render/post/post.gdshader` and `.tscn` | post stack | P1 |
| `game/render/shaders/corn_stalk.gdshader` | wind and parting | P1 |
| `game/render/shaders/taint.gdshader`, `ghost_rim.gdshader`, `paper.gdshader` | | P1 to P3 |
| `game/render/corn_field.gd` | builds MultiMesh cells from edge paths | P1 |
| `game/ghost/light_flicker.gd` | **not mine** (Gameplay, doc 05 s12); I only supply `energy_override` | P3 |

## 12. Phase priority summary

- **P1 (the first playable, doc 01 Phase 1; area x -32..46, doc 04 s9):** barn, shed with pegboard
  and drum, generator, well, field A with 8 plots, turnip stages, pen with chickens, strips 2 and 4,
  temporary corn walls, sell box, farmer, creature placeholder silhouette, bear trap and pit, the
  lantern, crows, the day-night environments, light rig, post, corn. Gray-box meshes from doc 04 are
  acceptable until real ones land.
- **P2:** farmhouse, field B, pumpkins, moonflower bed and glow, crate, pig and cow, scarecrow body,
  doors, ragdoll, tripwire, farm gate, wilting and rotting variants.
- **P3:** Taint, ghosts, flags, whistle, walkie-talkie, flare, church silhouette, Dawn Report card,
  boar and corn husk creatures, Harvest Moon sky.
- **P4:** Prize Pumpkin sizes, patch, cart, store items, town stand, bright lantern.
- **P5:** cosmetics, live clips, next season. Out of scope.

## 13. Gotchas

- **A pulsing anything looks like a flicker.** Auto exposure, bloom pulse, emissive wobble, candle
  noise in a light, lightning. All forbidden (section 4.3). Flicker is the one signal the whole
  game trusts.
- **Dimming must not step.** A generator at 25% fuel that dims in fuel-sized steps will look jerky.
  The curve is continuous in fuel_fraction and the rig slew-limits it.
- **Hybrid GPUs.** The CEO's machine has an NVIDIA RTX 5070 and an AMD integrated GPU. If an instance
  starts on the integrated one, every number is wrong; record the adapter in the profile.
- **Four instances share one GPU.** A single-instance frame time says nothing. Profile with
  `tools/qa/multi.py -n 4`.
- **Corn sight-blocking is a collision layer, not a mesh.** Do not rely on stalks to hide the
  creature; if LOD hides stalks the creature must still be hidden by layer 5 and the corn wall.
- **Fog and viewing distance can hide a trap clue.** Clues are close-range by design (doc 01);
  keep fog density under 0.02 within 10 m.
- **The 6 m lit doorway is one number in three places.** Light node radius, ground decal, and the
  trap exclusion in doc 03 s9. Change all three together.
- **Origin at the base.** A prop modelled around its centre sinks into the ground or floats
  (CONTRACTS section 3).

## 14. Questions raised

Appended to `production/QUESTIONS.md` (Q-025 onwards):

- Q-025 to Gameplay Programmer: confirm `LightRig` setters and `energy_override` split, and that
  `game/core/lights.gd` is the only caller of the setters; `light_flicker.gd` stays yours.
- Q-026 to Level Designer: light node placement, 6 m doorway light, ground decals, and corn
  collision (layer 5) strips for the corn field.
- Q-027 to 3D Artist: review this list, triangle budgets and the gray-box-first plan.
- Q-028 to QA: add the three grep rules from section 4.4 and the corn profile (section 10.3) to doc 09.
- Q-029 FOR CEO: bundled serif fonts for the Dawn Report need an open-licensed download; and the
  night ambient floor needs a look on the CEO's monitor.

## 15. Model sources (P4-40, D-151)

CEO direction: build models better in Blender, or start from a free CC0 library model and edit it to fit this
doc. Only CC0 is used. Anything else needs CEO approval first and is not in the repo. Downloads stay outside the
repo (`C:\Users\Ockey\fc_dl\models\`), are read only with Blender's own glTF importer, and no script inside a
download is run. Build script: `tools/blender/build_p4_40.py` (run line in its docstring); sources in
`assets/blender/<name>.blend`. Before/after renders: `logs/renders/p4_40/` (gitignored).

### 15.1 Library models used (edited)

| Model | Source | Asset | Licence | Changes |
|---|---|---|---|---|
| `animal_cow.glb` | https://poly.pizza/m/5XSc2Fka3F | "Cow" (Quaternius) | CC0 1.0 (Poly Pizza page) | Rig and stray sphere removed, turned to face -Z in Godot, scaled to 2.3 m long (1.3 m tall), feet on y=0, colours baked into vertex colour layer `Col` (white `#E8E4DA`, black `#2C2624`, nose `#D8A0A0`), one `mat_flat_lit`, flat shading, 796 tris (budget 800). |
| `animal_pig.glb` | https://poly.pizza/m/TNvG3QUFlp | "Pig" (Quaternius) | CC0 1.0 (Poly Pizza page) | Same steps as the cow; recoloured pink (`#D9A3A0`, `#C48A8A`), 1.4 m long, 562 tris. |

### 15.2 Built in Blender, no outside source

`animal_chicken` (hen: breast, neck, comb, wattle, wings, fanned tail, toed legs; 716 tris), `char_farmer`
(P5-12: skinned; parts Torso, Head, ArmL, ArmR, LegL, LegR kept as skinned meshes whose joints are now the bones, no hat, head centre z 1.62;
belt, bib pocket, buttons, straps, hair fringe, ears, cuffs, boot soles and laces; 2,152 tris; 12-bone rig, 9
animations, tint and Taint material slots; `tools/blender/build_p5_12.py`), P5-12 also rebuilt in Blender
`tool_watering_can` and `_quiet` (ribbed body, rose, cloth wrap), `tool_walkie_talkie`, `tool_walkie_battery`,
`tool_flare_gun` (now 0.18 high, grip on the ground), `tool_shed_lock` (round shackle), `tool_scrap`,
`tool_seed_packet_*` (crimped top, one drawn crop each), `prop_shipping_crate`, `prop_scarecrow_player`,
`prop_cart_pumpkin_slot` and `_bitten` (staves, rope-free), `creature_scarecrow` and its smear (level arms),
`prop_cart` (wheels split, round 16-sided rims), all with sizes and node names unchanged; P5-14 (`tools/blender/build_p5_14.py`) built `bldg_barn`, `bldg_shed`, `bldg_farmhouse` (exterior and interior in one model, empties `Door`, `WindowGlow_n`, `PorchLightMount`), `prop_well`, `prop_fence_segment`, `prop_fence_gate`, `prop_farm_gate` and the three door models; `pumpkin_prize_*` (eight files: 12 ribs, dimpled top, curved stem; sizes
unchanged), `pumpkin_patch` (mound, edge stones, vines, leaves, flowers; 1,840 tris), `crop_plot` (tilled ridges,
overlapping boards, corner posts), `prop_cart` (rimmed iron tyres, 8 spokes, plank sides with gaps, slatted deck,
yoke; layout, wheel centres and the `LanternSocket` and `PumpkinSlot` Empties unchanged), `prop_cart_lantern`,
`tool_lantern`, `tool_lantern_bright` (bail handle, vent chimney), `bldg_town_stand` (plank counter and back wall,
scalloped striped awning, hanging sign, jars, turnip crate, lamp; origin and 3.0 m width unchanged).

### 15.3 Looked at and rejected (all CC0, Quaternius via Poly Pizza)

| Poly Pizza id | Asset | Why not |
|---|---|---|
| `26zM1outCr` | cow (brown bull) | atlas texture; doc 07 s7 allows no textures |
| `u35l6uP5vj` | pig | atlas texture |
| `ineV9pU5VL`, `Z3RCoCYss4` | chicken | blob shape; voxel with atlas texture |
| `l7bDe7ak6j` | cart | awning blocks the carried pumpkin; 514 unwelded islands |
| `DGIM5HGISb`, `hts7l0NZxW`, `fmHUuX9AS3`, `4ZAhRv2tLG` | market stands and stalls | not matching the stand layout and awning; the built stand fits doc 07 s11.8 |
| `bvLvqnU1jX` | pumpkin | exact width and height formulas needed; built instead |

The Quaternius Farm Animal pack on Google Drive was out of quota and not downloaded. No CC-BY or other
non-CC0 asset was used, so nothing here needs CEO approval.

### 15.4 Still gray-box

Unchanged since P4-16 (P5-12 reviewed them and left them): the gaunt, boar and corn husk creatures (passed P4-19,
seen only in glimpses, about 1,000 of 5,000 tris each), the hats (only the import script was fixed), `tool_lantern*`,
`pumpkin_*`. Not built yet: the rest of s11 (pegboard, traps, crops,
corn, crow, hoe, shovel, fuel can, whistle, hands, road items, ragdoll, ghost shell); listed in Q-266 (P5-14 built the buildings group).
