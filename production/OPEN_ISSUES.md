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
