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
