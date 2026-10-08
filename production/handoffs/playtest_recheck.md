# Playtest recheck: OPEN_ISSUES "Found at the Phase 1 playtest" items 1-12, against current main

> Note (Director): this recheck ran on a snapshot older than the audio and AI commits (d9b654c, d00549b). Its "still broken" verdicts for issues 1 and 6 are stale; both fixes are on main and unverified by ear or eye.
Owner: QA  Date: 2026-10-07  Worktree: C:\Users\Ockey\Documents\bbbh-main (no git run)

Method: read code; ran 2 headless instances (`multi.py -n 2 --headless --frames 40000 -- --phase1
--creature-test`, client `--autowalk`, run `logs/qa/multi_20261007_234955`). Fresh import, 0 error lines,
except `ERROR: 1 resources still in use at exit` on the client (benign exit leak) and smoke `run` step
`Couldn't create an ENet host` x2 (probably port clash with a running game; not investigated).
The creature-test clock is compressed, so chase and death timings below are not real-time.

1. **Voice quiet / range short: STILL BROKEN.** `game/voice/voice_emitter.gd:16-17` still unit_size 6 m, max 80 m;
   `game/voice/voice.gd:30-31` NORMAL_DB still the -20 dBFS placeholder; no mic-check gain target exists.
   Human must judge loudness once raised.
2. **Day music: NOT REMOVED (likely misnamed).** No music file or Music-bus player exists. The only day audio is
   the synthetic insect bed `assets/audio/amb_insect_bed_day.wav` (+ `assets/audio/src/amb_insect_bed_day.scd`),
   still looped by `game/audio/soundscape.gd:29`. Human must confirm this bed is the "music"; if so delete the
   layer, wav, .import and .scd.
3. **No updater: STILL MISSING (as expected).** No updater/release-feed code in `game/` or `tools/`; no install
   page (README.md has none). `tools/qa/package_playtest.py` makes a zip only.
4. **No watering/fuel can: FIXED in code.** `game/player/player.gd:82-115` shows a blue watering can (pale when
   empty) or red fuel can in hand, replicated via `carry`; `game/core/generator.gd:30-57` `fill_fuel` then
   `refuel` on the generator. Headless run: `fill_can` holds completed. Human: check can visible and refuel works.
5. **Corn solid wall: FIXED in code.** Corn blockers are layer 16 (`game/world/farm_phase1.tscn:202`); local player
   mask is 1 only (`game/player/player.gd:47`, 196). Human: walk into corn.
6. **Traps not visible: STILL BROKEN.** `game/creature/creature.gd` `_set_trap` only logs `trap_changed set`; it
   sends nothing to peers. `game/traps_player/trap_race.gd:153-155` renders a disc only on `sprung`, so a trap
   is first seen when someone is already on it. Needs an armed-trap visual (and a Design ruling: should
   players see armed traps?).
7. **No lures: FIXED.** Headless 2-peer run: `lure_played` 6, `lure_result` 6 (1 worked, 17%, n=6,
   below the 30% gate, sample too thin; check_logs prints it). Path `creature.gd:248` -> `_play_lure` -> `Net.to_peers
   apply_lure` -> `soundscape.gd:121` plays the line. Preconditions: creature in lurk, hears a lone player
   (no other living player within 15 m), a crow perch 12-40 m away, 20 s cooldown. Likely cause of 0 in the
   playtest: stale build, or players always grouped. Human: lone player at night, listen for the voice.
8. **Random death: STILL OPEN (design/telegraph).** Night is scripted: stalk 60 s into night, chase 15 s
   later; then heard-step stalk, chase on seen/sprint/within close range (`creature.gd:262-280`). The only
   telegraph is the ambience bed and wind dropping in stalk/chase (`soundscape.gd:130-135`); no creature
   footsteps, sound or on-screen cue exists in the assets or code. A long near-then-kill stalk is consistent
   with this. Not verifiable headless; a human must say whether the bed drop is audible, and Design decides on a cue.
9. **Dead players audible: STILL BROKEN.** `game/voice/voice.gd:230-240` relays ghost audio to everyone with
   FLAG_GHOST; `game/voice/voice_emitter.gd` ignores the flag, so a ghost is heard at normal proximity. No ghost
   static or mute exists (doc 06). The "ghost mute" fix named in the brief is not in this worktree.
10. **Spectate tear: FIXED in code.** `game/player/player.gd:218-224` smooths the watched player's yaw and the
    camera position (exp lerp). Human: spectate a player turning.
11. **One row unplantable: FIXED in code.** `game/farming/farm.gd:22` `p.locked = false` for all 12 plots.
    Headless: 12 plant holds completed. Human: plant every row.
12. **Same action cannot repeat: FIXED in code (likely).** `game/interaction/hold_controller.gd:19,120-135` a refused
    hold waits for release (kills retry spam); a done hold immediately re-offers the target's next verb. Headless:
    plant x12 and water x12 completed on the same plots. Human: fill_fuel twice, plant then plant again.
