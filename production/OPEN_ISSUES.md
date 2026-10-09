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
