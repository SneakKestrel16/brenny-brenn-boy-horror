# Questions

Append a question addressed to a role. The Director routes and answers or closes it. Questions only
the CEO can answer are marked **FOR CEO** and collected for the next STOP.

Format: `### Q-NNN · date · from → to · status (open/answered/closed)`, then the question, then the
answer underneath.

### Q-001 · 2026-10-05 · Director → CEO · **FOR CEO** · open
**Which Opus route may the voice spike use?** Doc 01 requires Opus through a GDExtension, and Godot
has none built in. This machine has no C++ compiler, so either:
1. **Use an existing open-source Godot 4 Opus GDExtension** with prebuilt Windows binaries. The
   Network & Voice Programmer lists candidates with source URL and license (and libopus's, which
   is BSD-3-Clause) for approval before downloading anything into the repo. Fastest.
2. **Write our own small wrapper around libopus.** Needs Visual Studio Build Tools (free, a large
   install on the CEO's machine) plus the libopus source. Full control, slower.

Blocks PP-02. Director recommends 1.
