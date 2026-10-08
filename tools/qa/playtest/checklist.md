# Playtest checklist (DD Phase 1)

Run order for one session. Rules and reasons are [doc 09](../../../docs/09_playtest_plan.md)
sections 2, 5, 6 and 11; this list does not change them. A phase needs at least **2 sessions**, at
least one tester who has not read doc 01, and at least one session on **two home networks**.

## The day before

- [ ] The build passes: `uv run tools/qa/smoke.py --clean-import` (doc 09 s2 "Build").
- [ ] For a remote tester: `uv run tools/qa/package_playtest.py` and send them the zip from
      `builds/`. Note the build id it prints.
- [ ] Send each tester [tester_brief.md](tester_brief.md). Ask what they already know about the game
      (doc 09 s12: a stream counts as having read doc 01).
- [ ] Pick labels: tester A is the host, tester B joins. Never write real names.

## Start of session

- [ ] Ask each tester for consent to screen or voice recording. Record only on a yes.
- [ ] Headphones: model noted, left on left, Windows spatial sound off, volume set once.
- [ ] Make the session folder:

      uv run tools/qa/playtest.py new --session 1 --networks different --fresh B --smoke

  `--networks`: `different` (two homes, over Tailscale, D-024), `same` (one home network) or
  `one_machine`. Only `different` closes the "First" item.
- [ ] Observer opens the tally in a second terminal and leaves it running:

      uv run tools/qa/playtest.py tally logs/qa/playtest_p1_s1_<timestamp>

## Play (observer silent)

- [ ] Host runs `Host.bat` (or `-- --host --phase1` from the editor build); tester B runs `Join.bat`
      with the host's Tailscale address (D-024). Both must run the same zip or checkout.
- [ ] Observer types `g` + Enter the moment the host's session starts (lines tally `t` up with the
      logs' `t`).
- [ ] `s` scream, `l` laugh, `b` bored silence, `n <text>` anything else. Add `A` or `B` for who.
- [ ] Day: turnips planted, watered and sold; one generator run; one crouch-and-still hide.
- [ ] Trap race: at least 3 springs where the tester pries at once (doc 09 s6). A 2 s hesitation
      too, if there is time.
- [ ] Night: both testers out at least once. Note whether either names Stalk by sound.
- [ ] Spatial audio test scene (`SpatialTest.bat` in the zip): 36 trials per tester, rest after 18 (doc 09 s5). Ask the tester to
      name the left side first with a 10 m sound.
- [ ] If a tester asks to stop, stop. A crash or desync: note it, `n crash`, restart, keep the logs.

## Debrief (10 min, after play, tester's own words)

Same five questions every session (doc 09 s2). They are printed in `notes.md`.

## After

- [ ] Remote tester runs `send_logs.bat` and sends `brenny_logs.zip`.
- [ ] Save each friend's `brenny_logs.zip` to Downloads (`brenny_logs (1).zip` and so on is fine), then
      collect and report in one step:

      uv run tools/qa/playtest.py auto --testers A,B,C --fresh B

  It finds the game session and the spatial audio tests by itself. Run it again after more zips arrive.
- [ ] Hand-count five `lure_result` lines against the checker's number the first time
      (doc 09 s4 "check your checker").
- [ ] Doc 09 s7 host-only grep on the client files in `user_logs/<session_id>/`.
- [ ] Fill `notes.md`. If the session must not count, set `"valid": false` in `session.json`.
- [ ] `auto` reports every session of the phase so far; `report.md` is in this game's session folder.
- [ ] Each new problem to `production/OPEN_ISSUES.md`, each bug to `production/QUESTIONS.md`, the
      phase verdict per doc 09 s3 row into the phase review handoff (doc 09 s11).
- [ ] Delete any recordings once the notes are written. Nothing from the session folder goes into git
      (`logs/` is gitignored).
