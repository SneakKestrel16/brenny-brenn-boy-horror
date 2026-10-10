# Open Issues

Mirrors doc 01's Open Issues format: numbered, one problem each, with what would settle it. Read at
every between-phase review. Doc 01's own list is the starting point; these are found in playtests and
reviews and are proposed to the CEO for doc 01 when they change it.

## From doc 01 (tracked here, owned by doc 01)

1. Scope is large; voice and connecting over the internet come first. If UPnP fails for too many
   friends, reconsider a relay.
2. Numbers are untested; the simulator gates DD Phase 4.
3. Can players place sounds by ear? Tested in DD Phase 1.
4. Do the four bodies feel different enough? Check after DD Phase 3.

## Found by the studio

1. **A laggy player is hard to kill.** Doc 01 "Close calls: lag never kills", built in doc 06
   section 6 as "no answer within 300 ms plus RTT is a miss", means a player with high latency or
   loss survives lunges others wouldn't, and nobody dies during a timeout. Inference; settled by DD
   Phase 1 logs counting close calls missed for timeout versus disagreement, per player RTT.
2. **Voice chat is a little quiet** (CEO, STOP 1, 2026-10-06). Peaks of the decoded voice, each a
   10 s window's loudest 20 ms chunk before 3D attenuation (`voice_stats.decoded_peak`): the friend
   heard the host at 0.12 to 0.21 (about -16 dBFS typical), the host heard the friend at 0.12 to
   0.75 (median 0.27). The spike has no mic check, so it sends the mic at unity gain, and doc 06
   rules out automatic gain ("No automatic gain control"). Settled by the lobby mic check's manual
   gain (doc 06): it should raise a normal voice to a target level, a number for a playtest to set.
   Inference: the 6 m inverse-distance falloff (`UNIT_SIZE`) adds to it at range; a peak measured
   after the `AudioStreamPlayer3D` would separate the two.
   **Settled for now (CEO, 2026-10-06).** No change to the spike; the numbers above are a starting
   point for the mic check's gain target, and a later playtest reopens it if chat is still quiet.

- P1-08 QA: `speed_violation` logs fire for autowalk players headless (4.3 m/s vs max 3.0), with or without `--creature-test`. Gameplay owns the check; settle by reading frame dt or autowalk speed. Not blocking P1-08.
- P1-14 QA: `speed_violation` stamina flip: **RESOLVED** (P1-16, QA pass 2026-10-07). `exhausted` hysteresis plus interval sprint flag; 0 violations in 2-instance `--autowalk --autosprint` 5400 frames. The original entry text is in `production/handoffs/P1-14.md` section 2.
- P1-16 QA: `ERROR: N resources still in use at exit` after long multi-instance runs (2 headless instances, 5400 frames; `--verbose` shows `ObjectDB instances were leaked` on shorter runs too). Bisect: `--voice-off` removes `AudioStreamMicrophone` and `AudioStreamPlaybackMicrophone` (owner `game/voice/voice.gd`, Voice autoload; 12 leaked objects down to 10). The rest is 4 `AudioStreamWAV` plus 4 `AudioStreamPlaybackWAV` (matches the 4 `LAYERS` in `game/audio/soundscape.gd`: `_cache` holds the looped duplicates and the players are never freed at exit; Soundscape autoload, owner Audio Designer; inference, settle by freeing players and clearing `_cache` in `_exit_tree`) and 2 unnamed objects. Exit-only, but it makes `multi.py` report MULTI FAIL on long runs. Not caused by P1-16. **PARTLY FIXED** (Audio Designer P1-10): Soundscape `_exit_tree` frees the players and clears `_cache`; 2-instance `--phase1 --creature-test --voice-off` 3600 frames now leaves 1 resource (was 10). Remaining: the microphone pair (`game/voice/voice.gd`, Network & Voice, run without `--voice-off`) and the last leaked object, unnamed, not Soundscape. **Microphone part FIXED** (Network & Voice P1-06): root cause is the AudioServer, which releases a stopped playback only on its next mix step, and at quit none comes; `stop()` plus nulled refs in `_exit_tree` still leaked (measured). `Voice._exit_tree` now stops and frees the player, removes the `Mic` capture effect, and waits (5 ms polls, cap 200 ms) until a weakref to the playback clears. 2-instance `--phase1 --bot` 3600 frames `--verbose`, both mic and `--voice-wav` loopback: 0 leaked instances (was 12 per instance before either fix), MULTI PASS; voice 754 and 761 frames received, 0 lost. If Soundscape leaks return under `--voice-off`, the same stop-then-wait applies there.

## Found at the Phase 1 playtest (CEO and friends, 2026-10-07, build 7d470fc)

Reported by the CEO after one session with friends. Each is a report, not a diagnosis; the cause column
is inference until a log or a run settles it. Host log: `logs/qa/stop1_host/` (gitignored).

1. **Voice chat quiet; range too short.** Reopens Found-by-the-studio 2. Raise the voice range a bit
   and the lobby mic-check gain target.
2. **Day music is unacceptable.** CEO: "atrocious", never to be used again in any project. Remove it
   from the game and do not regenerate it; replacement needs a CEO listen first.
3. **No auto-updater.** Friends must not redownload each build. Needs a GitHub release feed plus an
   in-game or launcher updater, and an install page on GitHub with step-by-step instructions.
4. **No watering can or fuel can.** The fuel drum could be interacted with but nothing followed. The
   log shows `fill_fuel` completing 3 times and then `has_fuel_can` refusing every retry (285), so the
   can was granted in state but never shown or usable. Hold-retry spam fixed in P1-17; the missing
   can model/pickup and the refuel step are open.
5. **Corn is a solid wall.** Players cannot walk in, so nobody can be lured into it.
6. **No traps visible.** `trap_changed` logged 4 times; none rendered. **FIXED** (AI Programmer
   P1-20): cause was by design, a set trap stayed host-only and only sprung traps were drawn. The
   Creature now sends `set`/`moved` to every peer and draws a clue seen within 4 m (doc 03 s9): metal
   disc for a bear trap, dirt patch for a pit. Placeholder art; not yet looked at in a window.
7. **No lures.** `lure_played` is 0 in the logs; the scripted corn lines never fired. **FIXED** (P1-20):
   lures fired only in the unscripted lurk and only for a lone player (no one within 15 m); the night
   ran scripted for most of the session with three players together (inference from the log). Lures
   now also fire in the scripted lurk, and a source within 15 m of an armed trap may lure a player with
   company (doc 01 "Lure"). Not tied to the corn. 2-instance `--creature-test --bots=2` at 10x:
   `check_logs.py` reports 3 lures (bots ignore them, so 0% is expected there).
8. **Random death.** The creature stayed near for a long time, then killed without warning. One
   `death` in the logs; the 5 chases need reading against it. **FIXED in part** (P1-20): the death was
   the scripted chase. The creature stood 10 m from the host for 15 s (in view, sight 15 m), chased
   from 8 m and killed 1.18 s later with no sound; this breaks doc 03 s2 and the s4 chase tell. The
   scripted stalk now holds 18 m and backs off, no kill comes in a chase's first 2 s, and
   `chase_started` logs `reason` and `start_m`, `chase_ended` logs `chase_s`. The other 4 chases were
   fine. Open: no chase sting or signature sound exists (Q-048, Audio Designer).
   CEO note (2026-10-08): when the creature goes for the kill we might add a heartbeat sound effect as
   the warning. Not decided; try it after the chase sting exists.
9. **Dead players still audible.** Ghost voice must not reach the living except through the ghost
   static rules in doc 06.
10. **Spectate camera tears** whenever the spectated player turns.
11. **One crop row cannot be planted.**
12. **After a plant or fill completes, the same action cannot be done again** (`hold_completed`
    plant 9, fill_fuel 3 in the logs; the per-target state after completion is a suspect).

## Found at the P2-01 review (Director, 2026-10-08)

Issues 1, 4, 5, 6 and 9 to 12 above are fixed in code but not yet seen by a human; the first Phase 2
session rechecks them (P2-09, D-034).

1. **Whistle is harder to place than voice at 30 and 72 m.** Spatial test, one tester (D-033): whistle
   30 m 4/6, 72 m 3/6; voice 6/6 at both. The CEO closed the test, so this is not a gate. Inference: the
   20 m unit size leaves little level difference between 30 and 60 m. Settled by a second tester's
   run, or by ear once the whistle mechanic exists (DD Phase 3).
2. **The spatial test's voice source is a synthetic buzz, not `VoiceEmitter`** (P1-12, P1-14). The real
   emitter path was never tested by ear. Settled by hearing a recorded line as a lure (P2-04, P2-09).
3. **Stranger lines' intelligibility is unheard.** Q-031 (1) keeps formant synthesis until testers
   cannot understand it; no tester has been asked. Settled by Phase 2 debrief question 2.
4. **Lure counts may stay thin.** Q-046 (4): 4 lures in 1500 s of headless night. The Phase 2 gate
   needs only one fooled tester; the 30% rate is deferred to Phase 3 (CEO, 2026-10-08). Settled by
   `check_logs.py` lure counts in the first Phase 2 session.

## Found at the P3-01 review (Director, 2026-10-08)

1. **No human has seen the Phase 2 fixes.** STOP 3 closed without sessions (D-057). The P2-01 review
   items above and the P2-24 to P2-28 fixes stay unconfirmed. Settled by the first Phase 3 human
   session (P3-13).
2. **Ghost voice is muted to the living**, against doc 06's ghost static design (playtest issue 9's
   stopgap). Settled by P3-10.
3. **Doc 09 "DD Phase 3" reads ghost action events that are not defined.** P3-09 defines `ghost_action`
   (`flicker`, `crow`, `rustle`, `caw`); QA adds it to doc 09 s13 and `check_logs.py`.
4. **No dev way to reach day 5**, where hallucinations open (doc 03 s13). The dev console has no day
   command. Settled by P3-05.
5. **Taint data has two homes.** Settled in P3-02: player effects and causes in `taint.json` (doc 02 A.13),
   creature-side tracking in `creature.json` (doc 03 s19). Different values, one home each; no doc change needed.

## Found in P3-11 (Gameplay, 2026-10-08)

1. **The in-game whistle has not been placed by ear (pending a tester).** P3-11 built the whistle; no
   human has heard it in play. P2-01 issue 1 (whistle 30 m 4/6, 72 m 3/6 in the standalone test) stays
   open until this runs. Needs two people on two machines with headphones (one machine plays both
   peers' audio, so it cannot test placement). Steps:
   1. Host (the whistler) runs the game with `-- --dev --debug-view`; the listener joins. Stay in daylight
      (the creature sleeps), or use the dev console `phase day`.
   2. Both walk into the open field. On the host's F3 view, the whistler moves to stand 30 m from the
      listener (F3 shows both dots and each facing line) at a bearing the listener does not know. Vary
      the bearing each trial; never say it aloud.
   3. The listener faces a fixed landmark (the barn), then looks away from the screen or closes their
      eyes. The whistler presses Q once (the cooldown is 5 s).
   4. The listener turns with the mouse to face where the whistle came from, without looking, then says
      "here". The whistler reads the listener's facing line on F3: correct when it points within 45
      degrees of the whistler's dot (inference: the 45 degree bar is not in any doc; doc 09 section 5
      scores by marker pick).
   5. Six trials at 30 m, then six at 72 m. Record correct out of 6 per distance in this entry and in
      P2-01 issue 1; compare with 4/6 and 3/6. If either is below 4/6, raise it with the Audio Designer
      (the 20 m `unit_size`, doc 08 section 9.3) and the Director (doc 08's fallback is a lantern or hat
      flash, never a HUD marker).

## Found at the P3-13 review (QA, 2026-10-08)

1. **The creature body is fixed at `body_gaunt`.** Doc 01 "Bodies": "The host's game picks one of four bodies
   per season." `game/creature/creature.gd` has `const BODY := &"body_gaunt"` (Phase 1 placeholder) and
   nothing picks another. Doc 01 Open Issue 4 ("Do the four bodies feel different enough? ... Check after
   Phase 3") cannot be tested until a session can choose the body. Asked the AI Programmer in Q-074.
   Blocks the doc 09 s3 "Four bodies" row. **Moved to DD Phase 4 (D-068, P4-08).**
2. **Headless runs show few scare kinds.** Two 840 s runs logged 3 natural scares: 2 `own_voice` (big,
   private, day 2 third 3) and 1 `fake_out` (public, at dawn, third 0). No natural `jumpscare`.
   Other kinds are covered by dev commands and the P3-05 review, not by a natural run. Inference: bots stay near the farm, so the AI Director rarely picks a
   corn-edge jumpscare. Settled by the STOP 4 sessions: count scare kinds in `check_logs.py`.
3. **The dawn trample does nothing on a bare farm.** Run 1 (joiners replaced both chore bots, no crops) logged `trample`
   with `trampled` 0. Run 2 (one chore bot kept, crops planted) trampled 1 to 3 plots each dawn. Known as
   Q-070 item 2; listed so STOP 4 plants crops before night 1.

## Found at the P4-12 review (QA, 2026-10-09)

1. **Bot runs push an empty festival cart.** Bots never plant the Prize Pumpkin, so headless Harvest Moon
   runs never judge it or pay `pumpkin_payout`; the first push starts act 2. Bots also keep buying seeds
   (`money_changed seed`) after the season ends. Human sessions must plant the pumpkin to test D-084.
2. **The short season has no lobby pick.** Only `--short-season` or `--difficulty=short_season` choose it
   (Q-155). STOP sessions that test the Harvest Moon must launch the host with the flag.

## Found at the P4-18 review (QA, 2026-10-09)

1. **Bot seasons cannot stand in for a median team.** 14 headless bot seasons (12 full at 2p, 3p and
   4p, seeds 1 and 2; 2 short) were all lost: every full season missed the first payment (foreclosure)
   and the final one. Bots die nearly every night (5 to 15 deaths per season), pay 56 to 451 coins in
   medical bills, and plant with every coin, so the bank is 0 to 5 coins at most dawns. `sim_compare.py` (now `sim.py compare`)
   failed 15 of 21 dawns in both batches (worst gaps at dawn 3, 5 to 7 and 8). The Phase 4 win/loss and
   15-point rows need human seasons (`tools/qa/playtest/checklist_p4.md`). Asked about bot night
   behaviour in Q-157.
2. **Fixed in P4-18: bots spun on a trampled plot with no coins.** `sab.fix_jobs()` ranks a trample
   re-plant above harvest; a broke bot at 2p retried `plant` on Plot16 4,003 times and never harvested.
   `bot.gd` now skips a fix-job plant that `can_start` refuses, and its empty-plot pick filters the same
   way. 2p sales went from 0 to 390 and 480 coins per season.
3. **Fixed in P4-18: two plant holds could spend the same last coins.** `can_start` checked the seed
   price at hold start only; three bots starting together drove the bank to -4. `HoldRegistry._complete`
   now calls the target's `recheck` (new on `Interactable`, `Plot` checks the seed price) and cancels
   with that reason. `tests/gameplay/test_seed_race.gd` fails without the fix.
4. **Bots trip `speed_violation` under `--time-scale`.** Inference from code, not yet run: `bot.gd`
   moves `walk * delta` every physics step, but `_seq` advances by `floori(_send_t * SEND_HZ)`, so the
   host (`players.gd:177`) can see 0.4 m in 0.1 s (4.0 > 3.6 m/s). Likely fix: move only on send steps,
   by `walk * ticks / SEND_HZ`. A time-scale 8 bot season with 0 violations after the fix would settle
   it. Use `--fixed-fps 60` for bot seasons meanwhile.

## Found in the CEO's 2-instance session (CEO, 2026-10-09)

Source: the CEO's own play test at STOP 5 (host and one client on one PC). Routed to P4-22 to P4-28.

1. **The store shows no full list.** Interacting with the store should open a menu listing every item.
   P4-22.
2. **No seed choice.** There is no seed shop; planting spends coins on a fixed seed, so a player cannot
   choose a crop. P4-22.
3. **No hotbar.** After buying an item, nothing shows what is held or how to use it. P4-22.
4. **No lobby screen.** Players start in the barn and pick there; the CEO wants a menu lobby for roles
   and other settings before the match starts. P4-23.
5. **The farm feels too open and hard to read.** No minimap; the CEO asks for one in the top right
   (P4-24) and for a less open layout (P4-27).
6. **The festival cart hovers in the barn.** P4-27.
7. **The creature stuck itself in the barn** and was still there at the start of the next day. The CEO
   asks that at dawn the creature is put back in the corn. P4-25.
8. **Footsteps sound bad; crickets chirp too often.** P4-26.
9. **Scarecrows stand in open fields.** By design: doc 01 "Jumpscares > The scarecrow moved" and doc 04
   s7.3 scarecrow spots. Nothing tells the player that. Not routed; the CEO decides.
10. **Would a bigger watering can fix the money gap?** Watering can capacity is 2 plots per fill
    (doc 02 s3, placeholder). P4-28 runs the simulator on it.
11. **The creature killed a player inside the lit barn** after the player whistled. Doc 01 "Nights" and
    doc 03 s211/s247 say the creature never enters a lit building. Bug; added to P4-25.
12. **Harvest Moon: no visible cart path.** The cart should follow a dirt path to the gate. Added to P4-27.
13. **Harvest Moon: push progress stays at 0%.** The push hold never completes, so its bar never moves; it
    should show the distance left to push. P4-32.
14. **Harvest Moon: start-stop pushing stops all attacks.** The creature only attacks active pushers, so
    players stop and restart and it just stands there. Added to P4-25.
15. **The cart hovers while pushed** on the Harvest Moon, as well as in the barn. Added to P4-27.

## Found at the P4-21 review (QA, 2026-10-09)

1. **Bot nights are dark nights.** The generator dies in every night of every bot season
   (`generator_dead` 7 of 7). Bots never refuel after 50 s into the night, so they wait in a dark barn. A
   Tainted bot does not wash at night: one QA season (`qts8_3p`) lost a bot to a `night_chase` inside the
   barn. Human seasons would show whether a median team refuels.
2. **The Prize Pumpkin is judged "sad" in every bot season** (`guarded_nights` 0). The sim's median
   policy assumes `pumpkin_size` "large". This is part of the `sim.py compare` final-dawn gap.
3. **No normal-length bot season has won** (13 builder seasons, 2 QA seasons). Final payments come up 358
   to 949 short at 3p and 4p. Q-162 (idle host) and Q-164 (sentinel) decide how far bot seasons can stand
   in for the median team.

## Found at the P4-23 review (QA, 2026-10-09)

Source: `production/handoffs/P4-23.md` "QA review" (PASS). None blocks.

1. **A loaded season's locked roles show only on the host.** `game/ui/lobby.gd:143` reads
   `Game.season_uids`, which is never synced; clients can click a locked card and get no reason. Gameplay.
2. **Docs 04, 06 and 07 still describe the barn lobby** (doc 04 lines 98 and 113-114; doc 06 lines 232,
   800, 839, 862-866; doc 07 line 125), as well as doc 01 (Q-176). Waits on the CEO's Q-176 answer.
3. **Leftover "barn lobby" wording** in `game/core/game.gd:130`, `game/net/net.gd:380` and `in_barn` at
   `game/net/net.gd:489`. Gameplay, Network & Voice.
4. **`Voices` keeps a leaver's Node3D** (`game/ui/lobby.gd:38-44`), so a silent emitter stays. Gameplay.
5. **Doc 05 s16 lists a `Hard` difficulty**; `data/difficulty.json` has easy, normal, nightmare and
   short_season. Gameplay.
6. **Intermittent exit crash 0xC0000005** when the host quits in the lobby with a ready client (1 of 4
   runs; also in `production/handoffs/P4-06.md:38`). Not attributed to P4-23.


## Found at the P4-24 review (QA, 2026-10-09)

Source: `production/handoffs/P4-24.md` "QA review" (PASS). None blocks.

1. **The ghost "YOU ARE DEAD" text runs off-screen and under the minimap** (`game/ui/hud.gd:125`). Gameplay.
2. **`docs/05_technical_design.md` line 906 is not wrapped.** Gameplay.
3. **Teammate dots on the minimap** may undercut doc 01's voice-mimicry and whistle tells (Q-180, for the CEO).

## Found at the P4-30 review (QA, 2026-10-09)

Source: the Opus QA review of P4-30 (PASS). None blocks. Game Designer unless noted.

1. **The sim rounds the sell bonus once per day** (`tools/sim/sim.py:224, 227, 278`); the game rounds up per
   sale (`game/farming/station.gd:49`). Fix before the bonus table goes above 0; Q-210 sizes are low until then.
2. **`tests/gameplay/test_season.gd:134-140` checks headcount 1**, which has no table key, so the "shipped 0"
   check passes by default. Loop over keys 2 to 6. Gameplay.
3. **Doc 02 line 225 says a 2p bonus "above about 0.5%"** breaks 70%; with ceil any nonzero bonus does (D-106).
4. **With `unattended_term` on, 6p first clear stays 84.3** while 4p and 5p fall. Recheck with a per-night
   trample trace before Q-211 is ruled on (inference).

## Found at the P4-33 review (QA, 2026-10-09)

Source: `production/handoffs/P4-33.md` "QA review" (PASS). Items 1 to 3 sent back to the Gameplay Programmer.

1. **A flag's pick body may cover the trap it marks** (`game/traps_player/trap_sweep.gd:177` against
   `game/traps_player/trap_race.gd:282`), hiding disarm, fill and P4-29's loose-trap pickup (inference).
2. **A leaver's flags can never be pulled up** (owner keyed by peer id); they clear only by a disarm or fill.
3. **Dawn report flag count** (`game/ui/dawn_report_logic.gd:54`) is inflated by placing and pulling up.
4. **`apply_flags(positions)` in `game/net/net.gd`** still names a list that now holds `{pos, by}`. Network & Voice.

## Found at the P4-32 review (QA, 2026-10-09)

1. **Pusher facing is set once at lock start** (`game/player/player.gd:177`); after the route turns about 8 m in, the pusher faces off the cart. Gameplay.
2. **The controls hint covers the push prompt** for the first 20 s. Gameplay.
3. **Only the client checks that a push starts at the handle.** Harmless: the host moves the pusher to the push spot.

## Found at the P4-29 review (QA, 2026-10-09)

1. **Victim dies or leaves mid-race:** the trap stays `sprung` forever and never goes `loose` (old behaviour). `game/traps_player/trap_target.gd:16-27` offers no action, so nobody can pick it up and the creature cannot steal it; in Phase 1 it also stops further bear sets. Follow-up sent to the AI Programmer: set it `loose` on `death` or `player_left`, as `on_pry_done` does.
2. **Doc 03 s9.1** (lines ~428-437) does not list the ground theft step (`from: "ground"`). Game Designer.
3. **`game/net/net.gd:657` comment** does not list `loose`, `picked_up` or `stolen`. Network & Voice.
4. **TrapRace keeps `picked_up` and `stolen` entries** and resends them to late joiners. Harmless.
5. **P4-29 handoff calls `take_trap` instant**; logs show a 1.0 s hold.

## Found at the P4-27 review (QA, 2026-10-09)

1. **Wrong section cited:** `game/world/check_farm.gd:236` and `game/world/build_farm.py:130`, `:395` cite "doc 04 s13"; cover is s14. Level Designer.
2. **Doc 03 s3.2 (line 127)** still says only corn blocks sight; tree canopies now block it too (layer 16). AI Programmer, once Q-196 is answered.
3. **No solid trees:** players and the creature walk through trunks and fences (D-100), until the creature can steer round obstacles. Expect a playtest note.
4. **Not checked:** that `build_farm.py` regenerates `farm.tscn` exactly (QA sandbox blocked the overwrite).
5. **`test_debt_sync` race:** a client that joins after dawn misses the early 50 payment and fails the test. Harness problem, not P4-27. QA.
6. **Merge note:** the P4-32 cart `Handle` now sits at `HANDLE_UP` (1.05 m) above the ground-level glb instead of 0.86 m higher; `test_cart` PASS after the merge.

## Found at the P4-32 follow-up review (QA, 2026-10-09)

1. **`yaw_off` in `game/interaction/hold_controller.gd:342` is always 0** because `--autopush` never moves the mouse; it proves facing tracks the cart, not that mouse look survives a turn. Add a fixed yaw offset in `--autopush` to prove it. Gameplay.
2. **The cart turns about 86 degrees in about 0.3 s at a route corner** (`game/items/cart.gd:364`), and the pusher camera now turns with it. Playtest note.

## Found at the P4-25 review (QA, 2026-10-09)

1. **Corner pin:** a creature inside the wall pad at a barn corner (e.g. (8.43, -20.43)) never moves; `_way_to` (`game/creature/creature.gd:1261-1275`) aims through the wall. Only a spawn, teleport or push puts it there; dawn frees it. Fix: skip `_crosses` when inside `r.grow(WALL_PAD_M)` but not `r`, or step out first. AI Programmer.
2. **Harvest Moon act 2 opens with a chase** before anyone pushes (`_begin_push`). Game Designer to confirm under Q-185.
3. **Doc 03 edited by the AI Programmer** (Game Designer owns it). Director asked for it; Game Designer to review under Q-185.
4. **`creature_dawn_reset` log event** is not in the CONTRACTS log table or doc 05 s18.
5. **`_door_step`** takes the outward direction from building centre to door; right only while doors are centred on their walls.
6. **Door bang before entering a dark building** (doc 03 s6) not built; Q-186.

## Found at the P4-22 seed stock review (QA, 2026-10-09)

1. **`tests/net/test_store_client.gd:4-8`** documents `--duration 90`; the client is killed before planting. Use 200. QA.
2. **Broke team log noise:** every bot `next_job` logs `store_refused seed_turnip no_coins` (`game/items/store.gd:194`, `game/bots/bot.gd`); 287 lines in one run. AI Programmer.
3. **Cross-owner edits:** `game/bots/bot.gd` (AI Programmer) and `docs/02` line 483 (Game Designer) edited by Gameplay; owners to sign off.
4. **`request_store` doc comment** in `game/net/net.gd` omits the `seeds` op. Network & Voice.
5. **Merge note:** bot planting now needs `_keeps_payment(p) and _plantable(p, st)` (P4-18 payment guard kept with P4-22 seed buying); the P4-22 hint offset was dropped for P4-32 left-edge hint.

## Found at the P4-29 follow-up review (QA, 2026-10-09)

1. **`tests/creature/test_p4_29_e2e.gd:142-161`** does not cover a lost race, a client mirror or a late joiner (manual multi.py runs did). QA.
2. **`production/CONTRACTS.md:265`** does not list the `loose`/`picked_up` states or the new `cause` field. Director, with a DECISIONS entry.
3. **`tools/qa/check_logs.py:291-297`** counts loose events from a death or leave as the victim acting; count only `cause: "pried"`. QA.
4. **A client victim quitting mid-race** not tested live (`--force-spring` springs only host traps).

## Found at the P4-33 follow-up review (QA, 2026-10-09)

1. **Dawn Report flag count** is "planted minus pulled up"; flags cleared by disarm, fill or a leaver still count. Accepted as deliberate. Gameplay, if the CEO asks.
2. **A dropped flag seen by a third client** not verified; needs 3 instances. QA.
3. **`game/net/net.gd` `apply_flags(positions)`** name no longer matches what it carries. Gameplay.
4. **Q-230** still open.

## Found at the P4-35 re-review (QA, 2026-10-09)

1. **4:3 screens** (1024x768) fit only 3 farmers: the camera keeps its height while the side panels stay a fixed pixel width (`game/ui/lobby.gd:220-223`). 1280x720 and 1920x1080 fit all six. Closed: 16:9 only (D-145).
2. **The far-right raised tag** sits on the right lantern; its glow washes out the end of the name. Still readable. Gameplay.
3. **A real `hat_<role>.glb`** loading in `LineUp._hat` (`game/ui/lobby.gd:138`) untested until P4-36 lands. QA.

## Found at the P4-36 review (QA, 2026-10-09)

1. **Night owl tufts read as cat ears** (two upright 4-sided cones, `tools/blender/build_phase4.py:768-769`). Fallback: the handoff's pompom, or flatter outward-tilted tufts. Closed: the CEO keeps the tufts (D-145).
2. **The 14-energy lobby spot** (`game/ui/lobby.tscn:16`) washes the local player's hat near-white (navy beanie, straw hat). Technical Artist.
3. Fixed at merge: lobby farmers faced away, hiding every hat's front (Q-242); `LineUp._farmer` now turns them 180 degrees. Director checked by screenshot.

## Found at the P4-34 D-116 re-review (QA, 2026-10-09)

Source: `production/handoffs/P4-34.md` "QA re-review, D-116" (PASS with follow-ups). None blocks.

1. **Stand death rate unconfirmed against D-116's "about 1 in 10"**: 2 stand deaths in 32 nights on 16 fresh seeds; pooled with P4-34's independent seeds about 2 in 56. Seasons that share a `--seed` share the stand stream, so they are not independent samples. Game Designer: tune `town_stand.reach_night_chance` / `kill_mult` on 50 or more distinct seeds.
2. **On a stand night the nudge leaves the farm players** whenever anyone is at the stand (`game/ai_director/ai_director.gd:327`), not only when the guard is the only one outside (Q-225 option b). Bots at the farm never die at night, so the effect needs a 2-instance session. Game Designer / AI Programmer.
3. **Exit segfault after `season_ended`** in headless bot seasons, about 1 in 35 runs (`logs/p434/seasons3/short3p_2`, `logs/qa_d116/s13.log`, rc 139). Data is complete. Possibly related to the lobby exit crash above (inference; a crash trace would settle it).

## Found at the D-149 creature sound listen (CEO, 2026-10-09)

Source: `production/handoffs/real_creature.md` "CEO picks".

1. **The gaunt signature is a stand-in.** The CEO picked option C (a flicked clipboard as joint clicks) "for now" and noted "its not the best". Audio Designer: find a better real joint, knuckle or beetle-click recording later. Settled when the CEO picks a replacement by ear.
2. **All D-149 sound picks are stand-ins.** The CEO, 2026-10-09: "make a note to redo all these sounds at a later date as im not compltely satisfied with them but they will work for now". Every pick from the D-149 listen (creature, animal, item, radio, UI) ships for now. Audio Designer: redo them all in a later sound pass, starting from better real recordings. Settled when the CEO re-listens and approves each sound.

## Found at the P5-03 review (QA, 2026-10-09)

- **Splice word break unproven on real speech.** Both e2e runs cut mid-clip; the packet-size silence path
  (`VoiceSplice.word_break`) is covered only by `tests/net/test_splice.gd`. Logging per-clip packet sizes
  in a real-voice day-4 lure settles it (P5-07 listens to splice joins). Owner: Network & Voice.
- **No test for exact days 1 to 3.** Nothing asserts a day-1 to day-3 lure logs `exact:true` with an
  unchanged seed stream. Owner: QA (P5-08).
- **Splice log nits.** `lure_stopped` and `lure_skipped` put the whole spec in `clip_id`; doc 03 s12.4
  "Wire" and "Logs" bullets need rewrapping. Owner: Network & Voice.

## Found at the P5-10 review (QA, 2026-10-09)

- **Dev toys unseen and unheard.** No toy has been looked at or listened to, and safe mode was checked by
  reading only. Needs a windowed playtest on the CEO's PC once Q-261's hash is in. Owner: QA (P5-08).
- **Late joiners miss a running toy.** A peer joining mid-toy does not get it. Owner: Gameplay.
- **Low-gravity jump bypasses the InputMap** (`KEY_SPACE` read directly); settle with Q-262. Owner: Gameplay.
- **`test_harness.py` `MultiArgs` fails on main** (2 tests): `multi.py` now appends `--profile=p<n>` and
  `--`, which the tests do not expect. Owner: QA.

## Found at the P5-06 review (QA, 2026-10-09)

- **Role hats show the farmer's fringe.** `hat_farmer` and `hat_warden` (crown radius 0.13 m) let the hair
  fringe poke through; the cosmetic hats use 0.185 m. Owner: 3D Artist.
- **Doc 07 lacks cosmetics.** s11.7 has no rows for the 11 cosmetics, and s8 still says cosmetics are out of
  scope. Owner: Technical Artist (doc 07).
- **Overalls pattern gap at the knee.** Plaid and striped lines part slightly at the bent knee mid-stride.
  Owner: 3D Artist.

## Found at the P5-16 review (QA, 2026-10-09)

- **Wiring notes for the crop and corn models.** Wilted models use `mat_flat_lit` with baked droop, not doc 07 s7
  `mat_crop_wilted`; the moonflower's 3 m OmniLight (s7) is not in the glb and must come from the light registry
  (s4.1). Owner: Gameplay Programmer (wiring task).
- **Shots write `.png.import` under `logs/`.** `logs/` has no `.gdignore`; the files are gitignored. Owner:
  Technical Artist.

## Found at the P5-09 review (QA, 2026-10-09)

- **Grandiose may be too strong.** A walking player escapes every bear trap without reacting (D-167). Settle by
  playtest; tune `quirks.json` `grandiose` grace if the trap race never happens. Owner: Game Designer.
- **Nyctophobia has no visible effect yet.** No carried lantern exists; `Store.lantern_mult` is host-only. The
  lantern drawer must use `Quirks.local(&"light_radius_mult")`. Owner: Gameplay Programmer.
- **Scarecrow facing.** Store the placer's yaw with each scarecrow and have `QuirkWatch` read it (Q-276). Owner:
  Gameplay Programmer (model wiring task).
- **Host-only `--quirks` without `--lobby` draws no quirk** (only lobby start and joins call `Roles.sync`). Test
  harness only. Owner: Gameplay Programmer.
- **Dyspraxia drops are lost** like on death; the Game Designer should confirm. Names are not saved, so a loaded
  season's reveal shows "A farmhand" for anyone not seen since. Owner: Game Designer, Gameplay Programmer.
- **P5-04 must call `Quirks.reroll(season)`** on a new season and set `Quirks.season_n` on load. Owner: Director at
  the P5-04 merge.

## Found at the P5-17 review (QA, 2026-10-09)

- **Doc 07 sync for P5-17.** s11 sizes to as-built (crow 0.18 x 0.21 x 0.44, dead crow 0.28 x 0.10 x 0.38, hands
  0.50 x 0.19 x 0.53, sign 0.42 x 2.04 x 0.14, ghost 1.83 m); s7 lacks `mat_ghost_shell` (BLEND, alpha 0.42, no
  emission); s8 still says the dead crow is a box and the ragdoll has no animation (it has pose-only `lie`);
  s15.2 and s15.4 should move the seven models to "Built in Blender". Owner: Technical Artist (doc 07).
- **Wiring notes.** `tool_hands` arms run along -Z (`TaintLook` ARM_LEN climbs +Y); do not autoplay the ragdoll's
  AnimationPlayer with physical bones on; the ghost's double-sided blend shows inner faces (set cull back if it
  reads badly). Owner: Gameplay Programmer (model wiring task).
- **`before/tool_hands_*` shot camera sits below the ground plane** (cosmetic, shots only). Owner: 3D Artist.

## Found at the P5-15 review (QA, 2026-10-09)

- **Doc 07 s11 trap and tool sizes.** Bear open 0.58 x 0.62 x 0.21 m, pit 1.56 x 1.5 m deep, tripwire span 3.06 m,
  hoe 1.39 m, shovel 1.33 m differ from the placeholder rows. Owner: Technical Artist (doc 07).
- **Wiring the trap models.** `trap_glint` is static: show it by angle or distance, never a blink. Hang the bear item
  at scale 1.0; offset the pegboard so hook y meets the `Pegboard` marker; regenerate `Slot1..5` from `Hook1..5`.
  The rust pan #8A5A3A must not read as creature ember at night. Owner: Gameplay (model wiring task).
- **Pegboard outlines are circles** while a hung bear is closed (cosmetic). Owner: 3D Artist.

## Found at the P5-14 review (QA, 2026-10-09)

- **Barn door look.** A sliding-door rail sits above hinged leaves; pick one. Owner: 3D Artist.
- **Overhangs without collision.** Farmhouse chimney (x 6..7.2), porch posts (to z +2.3) and the barn hoist beam
  (to z +1.0) are outside the gray-box collision. Owner: Level Designer, with the model wiring task.

## Found at the P5-04 review (QA, 2026-10-09)

- **Roles are not re-pickable between seasons.** Route the next season through the lobby (`in_lobby = true`,
  carry applied at match start); that also gives the quirk re-roll and P5-11's `Imposter.pick` per season a home.
  Owner: Gameplay (follow-up task).
- **No save until season 2's first dawn.** A crash before it loses the carry. Owner: Gameplay.
- **Trait seed after a load is not reproducible.** Owner: Gameplay / AI Programmer.
- **`splice_master` trait** stays out of the pool until the splice handles more than two segments (Q-272).
  Owner: Game Designer (data), AI Programmer.
- **P5-04 e2e client check is weak** (passes on reload plus one trait). Owner: QA.
- **Docs 05 section 26** is P5-04's; P5-11 also claims a section 26 and must renumber at its merge. Owner: Director.

## Found at the P5-18 review (QA, 2026-10-09)

- **Route length in docs 02 and 05** still 147.9 m; now 136.9 m, about 137 s for one pusher (Q-326). Owner: Game
  Designer (doc 02), Technical Director (doc 05).
- **Doc 01 "Harvest Moon" act 1 and doc 03 s14** say "load the cart in the lit barn"; sync to "beside the lit barn
  door" (D-172). Owner: Game Designer.

## Found at the P5-13 review (QA, 2026-10-09)

- **Town stand collision (Q-281).** `bldg_town_stand.glb` sits at (0, -0.5, -0.96) over the unchanged 3 x 1 x 2 box in
  `farm.tscn`; check footprint and facing against doc 04 in a windowed session. Owner: Level Designer.
