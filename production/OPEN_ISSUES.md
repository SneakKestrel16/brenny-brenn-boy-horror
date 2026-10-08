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
