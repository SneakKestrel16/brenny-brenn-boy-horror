# Playtest checklist (DD Phase 3, STOP 4)

Run order for the Phase 3 sessions. Rules and reasons are [doc 09](../../../docs/09_playtest_plan.md)
s2 (session rules), s3 "DD Phase 3" (the rows) and s4 (measures). Doc 01 "Build Plan", Phase 3:
"Done when: the dead stay engaged, the living argue over a static voice, and someone laughs at the
Dawn Report." The Phase 2 list is [checklist_p2.md](checklist_p2.md); its rows still owed (recorded
voice fools someone, trap sweeps) are carried here.

Two sessions, 3 or 4 players each (a static-voice argument needs one dead and two living). One session
has at least one tester who has not read doc 01 and was told nothing about the game. Not the same fresh
tester in both (doc 09 s2).

## Before

- [ ] Build: the zip from `uv run tools/qa/package_playtest.py` (build id printed, goes in the notes).
      Host runs `Host.bat`, others `Join.bat` plus the host's Tailscale address (D-024).
- [ ] Real mics; do not pass `--voice-setting=off`. Everyone records lobby lines in the barn.
- [ ] Headphones on every tester (model noted, Windows spatial sound off).
- [ ] Consent asked for any recording. Notes say "tester A/B/C/D", never names.
- [ ] Observer: `uv run tools/qa/playtest.py new --session 1 --networks different --fresh B --smoke`;
      `g` + Enter when the match starts.
- [ ] Creature body for this session written in the notes. Session 1 and 2 use different bodies
      (Open Issue 4). Today the build always uses `body_gaunt` (OPEN_ISSUES "Found at the P3-13 review"
      item 1): skip the body row until that is fixed.

## Play (observer silent, notes in the tester's words)

| Doc 09 row | Make it happen | Pass (doc 09 s3) | Ticked |
|---|---|---|---|
| The dead stay engaged | Let one tester die on night 1 (creature, or `kill` in the dev console) | Stays connected to the dawn; uses flicker, crow, rustle or talks in static; says there was something to do | [ ] |
| The living argue over a static voice | The dead tester talks; a lure in the dead tester's voice plays at night | At least one spoken argument "was that really them?"; at least one tester used the lantern flicker to settle it | [ ] |
| Someone laughs at the Dawn Report | Read the report at every dawn | Observer logs a laugh (timestamp) | [ ] |
| AI Director, day arc, jumpscares | Work the fields by day; stay out at night | No scare in the first third of a day (only sabotage clues); testers name a scare by day | [ ] |
| Taint and Shaken | Touch leavings or a stolen tool (Taint), wash at the well (cure); get jumpscared (Shaken) | Taint stain and heartbeat seen and heard; washing cures; Shaken slows the sprint and does not Taint | [ ] |
| Whistle and flags | Whistle from 30 m and from 72 m; place a flag | Listener points to the whistler (OPEN_ISSUES "Found in P3-11" item 1); flags show in the Dawn Report | [ ] |
| Four bodies (Open Issue 4) | One body per session | Tester names the body by sound alone, or says they could not | [ ] |
| Carried: recorded voice fools someone (DD Phase 2) | A teammate's line plays from the field at night | Walks toward it or says fooled; log `worked` on a `clip` lure | [ ] |
| Carried: trap sweeps (DD Phase 2) | Two fields with corn between | Testers sweep unprompted after the first sprung trap | [ ] |

Observer also counts screams, laughs and bored silences with a timestamp.

## Debrief (10 min, after play, doc 09 s2)

1. When did you feel safest? Least safe?
2. When did you last doubt a voice? Why? **Add:** did a dead teammate's voice ever fool you? How did
   you decide?
3. What did you do when you heard something in the corn?
4. What were you doing when you were bored? **Add (dead testers):** what did you do as a ghost?
5. What was the funniest moment? **Add:** what in the Dawn Report made you laugh?
6. **Add:** what did the creature sound like? Was it the same creature as last time?

## After

- [ ] Each remote tester runs `send_logs.bat`; save the zips to Downloads.
- [ ] `uv run tools/qa/playtest.py auto --testers A,B,C --fresh B`, then
      `uv run tools/qa/check_logs.py logs/qa/<session>/user_logs`.
- [ ] Scare rules PASS, no "Taint right after Shaken" flag, no "BEFORE OPENS_DAY" line.
- [ ] Phase 1 lure rate over at least 20 results across both sessions (doc 09 s3 DD Phase 1).
- [ ] Hand-count five lines of each Phase 3 measure against the checker (doc 09 s4 check-your-checker).
- [ ] Problems into `production/OPEN_ISSUES.md`.
