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
