# Playtest checklist (DD Phase 2, STOP 3)

Run order for the Phase 2 sessions. Rules and reasons are [doc 09](../../../docs/09_playtest_plan.md)
s2 (session rules), s3 "DD Phase 2" (the rows), s4 (measures) and s8 D and E (voice checks). The CEO
hosts; friends use real microphones. The generic Phase 1 list is [checklist.md](checklist.md).

Two sessions, 2 to 4 players each (3 or 4 recommended: a "fooled" lure needs a teammate who is not the
speaker). One session has at least one tester who has not read doc 01 and was told nothing about the
game (a stream counts as having read it). Not the same fresh tester in both.

## Before

- [ ] Build: the zip from `uv run tools/qa/package_playtest.py` (build id printed, goes in the notes).
      Host runs `Host.bat`, others `Join.bat` plus the host's Tailscale address (D-024). Both bats pass
      `--phase1` and the host `--lobby`; the full farm is the default (P2-20), so no farm flag.
- [ ] Do not pass `--voice-setting=off`: testers use their real mics and choose in the game.
- [ ] Headphones on every tester (model noted, left on left, Windows spatial sound off).
- [ ] Consent asked for any recording. Notes say "tester A/B/C/D", never names.
- [ ] Observer: `uv run tools/qa/playtest.py new --session 1 --networks different --fresh B --smoke`,
      then `playtest.py tally <folder>`; `g` + Enter when the match starts.

## Session 1 only: Phase 1 fixes no human has seen (OPEN_ISSUES "Found at the Phase 1 playtest")

Tick when seen working, or write what you saw.

- [ ] **1. Voice quiet / range short:** a teammate 10, 20 and 30 m away is clearly audible without
      turning the volume up; the lobby mic check gain looks right.
- [ ] **4. Watering can and fuel can:** the can is visible in hand after the pickup, can be used, and the
      fuel drum refuels the generator more than once.
- [ ] **5. Corn is walkable:** a tester walks into the corn rows and moves through them.
- [ ] **6. Traps are visible:** a set trap shows as a clue (metal disc or dirt patch) when within about
      4 m; a sprung trap shows too.
- [ ] **9. Dead players not audible:** after a tester dies, the living do not hear their voice (only the
      ghost static rules).
- [ ] **10. Spectate camera:** a dead tester spectates a teammate who turns; the view does not tear.
- [ ] **11. Every crop row can be planted** (try the row that failed before; look for one that refuses).
- [ ] **12. Repeat actions:** plant, fill fuel and water the same target a second time; each works again.

## Play (observer silent, notes in the tester's words)

Order is free; the aim is that each row below happens at least once per session.

| Doc 09 row | Make it happen | Pass (doc 09 s3) | Ticked |
|---|---|---|---|
| Recorded voice fools someone | Everyone records their lines in the barn first. At night, a tester hears a teammate's line from the field | At least one tester walks toward it or says they were fooled; log has `lure_played` (`clip_id` set, `tell`) joined to `lure_result.worked` | [ ] |
| Trap sweeps worth doing | Two fields with corn between; the creature takes a trap from the pegboard | Testers sweep unprompted after the first sprung trap and say it paid off | [ ] |
| Death, respawn, bill | Kill one tester (creature or `kill` in the dev console, backquote) | Dead tester respawns at dawn; the bill matches 25 first / 50 later for 4 players (20/40 for 3); bank never below 4 coins | [ ] |
| Up to 4 players | One session at 4 players | No desync (same day, same deaths and traps on every screen); play stays smooth | [ ] |
| Voice settings (doc 09 s8 D) | Switch Off and Lobby lines mid-session in the pause menu | Off: no recording light, no clip heard in that player's name; light is steady while recording | [ ] |
| 72 m voice trial | Solo, `SpatialTest.bat`, the 72 m cells | Reported, not gated | [ ] |
| Audio (P2-08, owes the CEO) | Listen for the chase sting, body signature (each creature body sounds different), echo/pitch tells, barn lobby, lantern blow-out, door bang | CEO says levels are right (doc 08 s14 item 9) | [ ] |

Observer also counts screams, laughs and bored silences with a timestamp.

## Debrief (10 min, after play, same questions every session, doc 09 s2)

1. When did you feel safest? Least safe?
2. When did you last doubt a voice? Why? **Add:** was any teammate's line fake? Did you believe it?
   Could you understand the stranger lines (OPEN_ISSUES P2-01 item 3)?
3. What did you do when you heard something in the corn?
4. What were you doing when you were bored? **Add:** did walking the fields for traps pay off?
5. What was the funniest moment?

## After

- [ ] Each remote tester runs `send_logs.bat`; save the zips to Downloads.
- [ ] `uv run tools/qa/playtest.py auto --testers A,B,C --fresh B`, then
      `uv run tools/qa/check_logs.py logs/qa/<session>/user_logs`.
- [ ] Hand-count five `lure_result` lines against the checker (doc 09 s4 check-your-checker).
- [ ] Host-only grep on the client files (doc 09 s7).
- [ ] Problems into `production/OPEN_ISSUES.md`; one fresh tester and two sessions recorded in the report.
