# P3-08 (look half): Taint look
Owner: Technical Artist  Date: 2026-10-08

## Done
- `game/render/taint_look.gd` (`TaintLook`, static): `show_on(player, on)` and `mark(kind)`, called from
  `taint.gd` on every peer.
- Hands and sleeves (doc 01 "Taint", doc 07 section 8): two capsule forearms hang under each player's camera,
  so the owner sees them at the bottom of the screen and other players see them in front of the body. The
  shader (`taint_hands.gdshader`) draws oil black `#0A0710` with a purple fresnel sheen `#3A1F4A`, climbing
  from the fingers toward the elbow with a jagged edge, and denim cloth above. The arms show only while
  Tainted. This replaces the black body capsule.
- Screen (doc 05 section 10): only the Tainted player gets `taint_screen.gdshader`, a CanvasLayer at layer 5,
  under the HUD and the post pass. It adds edge smudges, heaviest at the bottom, and a faint dark fog
  (`fog` 0.10). It only darkens, has no TIME term, and fades in or out over 3 s.
- Ground (`taint_ground.gdshader`, alpha scissor, seen by all): leavings are a 1.1 m oil puddle with drips,
  strange seeds a 0.6 m dark scatter. The dead crow is a dark box.
- Debug aid: `--look-cam=x,y,z,yaw,pitch` without `--look-shot` now holds a fixed camera in a live session, so
  a client can screenshot another player (`world_look.gd`).
- Doc 07 section 8: "As built (P3-08)" note.

## Files changed
`game/render/taint_look.gd`, `game/render/taint_hands.gdshader`, `game/render/taint_ground.gdshader`,
`game/render/taint_screen.gdshader` (new), `game/render/world_look.gd`, `game/player/taint.gd` (Gameplay's
file: `_hands` and `_mark` now call `TaintLook`, minimal hook), `docs/07_art_direction_and_asset_list.md`.

## What the next role needs to know
- **QA:** host `--host --port=24731 "--dev-exec=taint; taint_source leavings"`. Client
  `--join=127.0.0.1:24731 --look-cam=-0.8,1.6,-10.4,138,-12` looks at the host's spawn and the puddle.
- **Gameplay Programmer:** `taint.gd` `_hands` and `_mark` now delegate to `TaintLook`. The body material is
  no longer touched.
- **3D Artist:** `tool_hands.glb` (doc 07 section 11.3) should expose a material slot for
  `taint_hands.gdshader` (`taint_level`, `arm_len`). Then the capsules go and clean hands can show too.
- **UI Programmer / the Director:** with the look in place, the HUD tester line "Tainted: wash at the well"
  (`game/ui/hud.gd`) can go under the no-HUD rule (doc 05 section 3). Not touched here.

## Verified
- Headless import: no ERROR. `test_light_rig`, `test_creature_logic` pass. `grep_rules.py`: flicker,
  energy_override and light_energy have 0 violations.
- Host and client on port 24731, 0 SCRIPT ERROR. Screenshots in `C:\Users\Ockey\.claude\jobs\a4c64d86\tmp\`:
  `p308a_local4.png` shows the Tainted host's own view: oily forearms, edge smudge and fog, and the
  puddle. `p308a_client11.png` shows the client view of the Tainted host: dark forearms in front of the
  body and a clearly black puddle.

## Open issues
- "Black stains underfoot" is read as the Taint sources on the ground. This is an inference: no doc names
  Tainted footprints. The Game Designer settles it.
- `taint_level` is binary. Doc 07 mentions stages, but doc 01 says a second Taint changes nothing.
- The dead crow is a box until its model exists. Tainted cans have no look.
- No greyscale check yet (doc 07 section 8 colour-blind cue).
- The 3 s fade and the 0.10 fog are placeholders. A night pair was not captured.
- Pre-existing: after the host disconnected, the client HUD showed "Tainted", because `local_peer` falls back
  to 1.
- Not committed: the worktree guard refused every git command.

## QA review
