# CEO review, overnight batch of 2026-10-10

Written by the Director while the CEO was away (about 8 hours). Everything that needs your decision is in
section 1. Section 2 lists every change, with the commit and the command that undoes it. Section 3 holds
test results and what was done about them.

**How to revert anything:** each task is one commit on `main`. Run `git revert <commit>` in the repo, then
push. Where a change is behind a setting or data flag, the flag is named, so you can switch it off
without a revert.

## 1. Decisions for you

| # | Question | Default we went with | Where |
|---|---|---|---|
| D-1 | Day full-body visibility of the creature (Q-345) | Unchanged | QUESTIONS.md Q-345 |
| D-2 | Doc 11 section 7 lore questions | Text in game stays placeholder | docs/11 s7 |
| D-3 | The P5-43 whisper is only a dev trigger. Should it happen in play? | Dev trigger only | P5-43 handoff |
| D-4 | The well is about 10 m off the A-B line. Moving it onto the line cuts corn strip 3 | Well stays | P5-47 handoff |
| D-5 | 7 emotes go beyond doc 01's list | Kept | data/emotes.json |
| D-6 | Nuke radius 60 m is a placeholder | 60 m | dev_toys.gd |
| D-7 | Crowkeeper role: approve the new Roles row; numbers are placeholders (Q-352) | Built as specced | P5-52 |
| D-8 | Horror role: you picked "flickering light", but doc 01 says only ghosts flicker lights. Built as dimming only (Q-349) | Dimming, no flicker | P5-53 |
| D-9 | Horror role: four exceptions to doc 01's hallucination rules (Q-350, doc 03 s23.1) | Built, placeholder | P5-53 |
| D-10 | Horror role: the "name whisper" replays the player's own recorded clip, not their actual name (only if their voice setting allows) | Own clip | P5-53 |

## 2. Changes made (commit, what, how to revert)

| Task | Commit | What changed | Revert |
|---|---|---|---|
| P5-54 | 662d919 | test_roles: stale test fixed (debounce), no game change | `git revert 662d919` |

## 3. Tests run and what we did

(Filled in as tasks land.)
