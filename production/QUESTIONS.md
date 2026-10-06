# Questions

Append a question addressed to a role. The Director routes and answers or closes it. Questions only
the CEO can answer are marked **FOR CEO** and collected for the next STOP.

Format: `### Q-NNN · date · from → to · status (open/answered/closed)`, then the question, then the
answer underneath.

### Q-001 · 2026-10-05 · Director → CEO · **FOR CEO** · answered
**Which Opus route may the voice spike use?** Doc 01 requires Opus through a GDExtension, and Godot
has none built in. This machine has no C++ compiler, so either:
1. **Use an existing open-source Godot 4 Opus GDExtension** with prebuilt Windows binaries. The
   Network & Voice Programmer lists candidates with source URL and license (and libopus's, which
   is BSD-3-Clause) for approval before downloading anything into the repo. Fastest.
2. **Write our own small wrapper around libopus.** Needs Visual Studio Build Tools (free, a large
   install on the CEO's machine) plus the libopus source. Full control, slower.

Blocks PP-02. Director recommends 1.

**Answer (CEO, 2026-10-05):** Option 1, an existing open-source GDExtension. Per D-005 the specific
addon still needs CEO approval of its source and license before it enters the repo; Network & Voice
lists candidates in doc 06 (PP-01). PP-02 waits on that approval. See D-008.

### Q-002 · 2026-10-05 · QA → Gameplay Programmer (doc 05, PP-07) · open
**Two section 10 log fields the log checker (PP-03) has to guess.** Please settle them in doc 05's
event list:
1. `lure_result.within_s`: the seconds the target took to move `moved_m` toward the source, or the
   length of the window (always 8)? The checker reads it as the time taken and applies doc 01
   "Testing" (worked = `moved_m > 10` and `within_s <= 8`). If it is the window, the event needs the
   actual time too, or the checker can only trust the logged `worked` value.
2. `spatial_audio_trial` fields. The checker assumes `sound` (`voice` or `whistle`),
   `distance_m` (10, 30 or 60, per doc 01 "Testing") and `correct` (bool). An angle error in degrees
   would also be useful if the test records one.
Not blocking: `tools/qa/check_logs.py` adapts once doc 05 fixes these.
