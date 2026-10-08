# P2-13 Level Designer part: 6 spawns, barn lantern

- `game/world/build_farm.py`: `player_spawns` now 6: spawn_1..4 unchanged (x -3, -1, 1, 3 at z -8), spawn_5 (-2, -11), spawn_6 (2, -11). Both scenes regenerated (`farm.tscn`, `farm_phase1.tscn`).
- Spacing: nearest pair 2.0 m (capsules do not overlap); 8 to 12 m inside the barn (x -8..8, z -20..0); 4.0 m from `RecordingSpot` (0, -15).
- Q-054 item 4: `BarnLantern` is also in group `lightrig_spots` (meta `radius_m` 6), so `world_look.gd` `_place_rigs` adds the real `LightRig` as its child; `recording_screen._find_lantern` finds it via `barn_lantern`. Marked answered in QUESTIONS.md. Not seen in a render run (needs windowed run). Side effect: `lightrig_spots` is 4 in `farm.tscn` (3 doors + lantern); the lantern rig follows the same lit/unlit logic as door rigs.
- `check_farm.gd` counts updated (spawns 6, lightrig_spots 4); doc 04 s4 and s13 updated. s8 distances unchanged (no building or marker moved); `check_farm.gd` PASS.
- Checks: headless import 0 ERROR; `grep_rules.py` green; `smoke.py` run stage fails with "Couldn't create an ENet host" (both tries; about 8 other Godot instances from parallel agents are running, inference: port held; rerun when they exit). Import and parse stages pass.
- Players script must handle >4 spawns (group size now 6).
