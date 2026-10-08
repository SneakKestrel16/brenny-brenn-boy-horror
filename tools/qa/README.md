# QA harness

Owner: QA / Reviewer (CONTRACTS section 2). Python 3.13 through `uv`, standard library only, so
there is nothing to install. Run every command from the repo root in Git Bash. Godot is found
through `--godot`, then `$GODOT`, then the CONTRACTS section 1 path.

| Command | What it does |
|---|---|
| `uv run tools/qa/smoke.py` | Headless import, parse check and timed run. Fails on any `ERROR` / `SCRIPT ERROR` line |
| `uv run tools/qa/multi.py -n 2` | Starts 2 to 6 local instances and collects their console output and section 10 logs into one folder |
| `uv run tools/qa/check_logs.py <folder>` | Reports the doc 01 measures found in section 10 JSONL logs |
| `uv run tools/qa/playtest.py new\|tally\|collect\|report` | Runs a DD phase playtest session (doc 09 s2, s3, s11): session folder, observer tally, log collection, pass/fail report |
| `uv run tools/qa/package_playtest.py` | Exports the game and zips it for a remote playtester |
| `uv run tools/qa/grep_rules.py` | Review greps: flicker (doc 07 s4.4), energy_override, light_energy, rpc outside `game/net/`, voice files in git. Exit 1 on violation |
| `tools/qa/playtest.sh check\|local [2-4]\|host\|join <code>\|logs` | Playtest shortcuts: pre-flight checks, a local 2 to 4 window session with `--phase1`, a real host or join, then the log measures |
| `uv run tests/qa/test_harness.py` | Self-test of the three tools on fixtures. Needs no Godot |
| `uv run tests/qa/test_grep_rules.py` | Self-test of `grep_rules.py` on temp git trees. Needs no Godot |
| `uv run tests/qa/test_playtest.py` | Self-test of `playtest.py` and the packager's zip. Needs no Godot |

Every output goes under `logs/qa/` (gitignored), in one folder per run named by its timestamp.

## Smoke run: `smoke.py`

```bash
uv run tools/qa/smoke.py                       # import, parse check, 120-frame run
uv run tools/qa/smoke.py --frames 600          # longer run
uv run tools/qa/smoke.py --scene res://game/world/farm.tscn   # run another scene
uv run tools/qa/smoke.py --clean-import        # delete .godot/ first (close the editor)
uv run tools/qa/smoke.py -- --some-game-flag   # after --: passed to the game
```

| Step | Command |
|---|---|
| `import` | `"$GODOT" --headless --editor --quit --path .` (CONTRACTS section 1) |
| `parse_check` | `"$GODOT" --headless --path . res://tests/qa/parse_check.tscn` |
| `run` | `"$GODOT" --headless --path . --quit-after <frames> [scene] [-- args]` (CONTRACTS section 1) |

A step fails on any of these:

- a line starting `ERROR:`, `SCRIPT ERROR:`, `USER ERROR:` or `SHADER ERROR:`;
- a crash banner (`CrashHandlerException`);
- a non-zero exit code;
- a timeout (`--timeout`, default 300 s).

The import must pass, or the later steps are skipped. The exit code is 0 for a pass and 1 for a
fail. Each step's full output is saved to `logs/qa/smoke_<timestamp>/<step>.log`.

`--allow REGEX` ignores matching error lines. It is for a known, filed error only; name the
QUESTIONS.md entry in the task handoff.

**Why the parse check is there:** the headless import parses only the scripts it needs (those with a
`class_name`, autoloads and scenes). A broken script that nothing references yet passes the import
silently. `tests/qa/parse_check.gd` loads every `.gd` under `res://` (skipping dot-folders and
folders with a `.gdignore`), so the parse error prints, and the step exits 1.

**A pass after a fail with no edit in between is suspicious.** Rerun with `--clean-import`.

**`--clean-import` seeds `.godot/extension_list.cfg`** with every `addons/*/*.gdextension`
(Q-010). A fresh checkout's first headless import segfaults while it registers TwoVoIP mid-scan
(Q-008, PP-02 handoff); the seeded file registers it at startup instead, as the editor does on
every later run. `--no-seed-extensions` reproduces the crash, e.g. to test a TwoVoIP upgrade.

**`logs/qa/` holds a `.gdignore`,** written by the harness, so Godot never scans QA output. With
hundreds of log files there, the editor's first scan ran long enough to hide that crash, and a
clean import in the dev tree no longer behaved like a fresh checkout (measured in the PP-02 review:
the dev tree passed 4 of 4 unseeded, fresh copies crashed 3 of 3).

## Multi-instance run: `multi.py`

```bash
# Two windowed instances, tiled in a 2x2 grid; the first is the host (peer 1).
uv run tools/qa/multi.py -n 2 --args "-- --host" --args "-- --join=127.0.0.1"

# Four headless instances that each quit after 3600 frames, with one argument for all of them.
uv run tools/qa/multi.py -n 4 --headless --frames 3600 --common "-- --bot"

# Harness self-check: 4 networked fake peers over local ENet, each writing a section 10 log.
uv run tools/qa/multi.py -n 4 --headless \
  --common "-s res://tests/qa/fake_peer.gd -- --qa-port=24567 --qa-peers=4" \
  --args "-- --qa-role=host" --args "-- --qa-role=client" --args "-- --qa-role=client" --args "-- --qa-role=client"
```

| Option | Effect |
|---|---|
| `-n 2..4` | Number of instances |
| `--args "..."` | One instance's Godot command line. Repeat it in instance order: the first is instance 1, which should be the host |
| `--common "..."` | Given to every instance, before its own `--args` |
| `--headless` | No windows. Without it, windows are tiled 640x360 in a 2x2 grid (turn this off with `--no-tile`) |
| `--sound` | Play audio. Without it every instance runs `--audio-driver Dummy`, so test runs stay silent on the developer's headphones |
| (always) | Every instance gets the game arg `--free-mouse`: the windows never capture the mouse |
| `--frames N` | Each instance quits after N frames (`--quit-after`) |
| `--duration S` | Kill the instances still running after S seconds. Being killed this way counts as a normal end |
| `--timeout S` | Hard limit when there is no `--duration` (default 1800 s). Being killed this way is a failure |
| `--stagger S` | Seconds between launches, so the host is listening before clients join (default 1) |
| `--allow REGEX` | Ignore matching error lines |

Each argument string is split the way a shell would split it. Engine flags come first; anything
after `--` reaches the game through `OS.get_cmdline_user_args()`. The engine part and the game part
of `--common` and `--args` are merged, so `--common "-- --a"` plus `--args "--verbose -- --b"` becomes
`--verbose -- --a --b`.

Collected into `logs/qa/multi_<timestamp>/`:

- `instance_<i>.log`: each instance's console output, scanned for errors the same way as the smoke
  run.
- `user_logs/<session_id>/peer_<id>.jsonl`: every CONTRACTS section 10 log that was created or grew
  during the run, copied from the project's real `user://logs`. On the CEO's machine that is
  `C:\Users\Ockey\AppData\Roaming\Godot\app_userdata\Brenny Brenn Boy Horror\logs`. The script asks
  Godot for this path each run (`tests/qa/print_user_dir.gd`), so a later custom user dir is
  picked up too.
- `manifest.json`: the commands, exit codes, error lines and copied files.

All instances on one machine share that `user://` folder, so peers must write different file names
(`peer_<id>.jsonl` does this).

The exit code is 1 if any instance printed an error line, crashed or exited non-zero.

Ending the run by killing instances (`--duration`, `--timeout`) can lose log lines the game had not
flushed yet. Prefer `--frames` or a quit from inside the game.

`tests/qa/fake_peer.gd` is a harness fixture, not game code. It hosts or joins over local ENet and
logs `qa_*` events. It proves that the launcher, the networking between instances and the log
collection work before the game has any of them.

## Log checker: `check_logs.py`

```bash
uv run tools/qa/check_logs.py logs/qa/multi_<timestamp>/user_logs
uv run tools/qa/check_logs.py --user-logs     # everything in this machine's user://logs
uv run tools/qa/check_logs.py <paths> --json  # machine-readable
uv run tools/qa/check_logs.py <paths> --strict  # exit 1 on any malformed record
```

The checker reads `.jsonl` files and folders, recursively. A session is the folder that holds the
`peer_<id>.jsonl` files. Measures come from the host's file only (peer 1, which is authoritative
under CONTRACTS section 10), so the same event logged by several peers is not counted twice. A
session with no `peer_1.jsonl` falls back to all of its files, with a warning.

| Measure | Rule | Source |
|---|---|---|
| Lure success rate | `lure_result` counts as worked when `moved_m > 10` and `within_s <= 8`. The rule is recomputed, not read from the logged `worked`, and disagreements are listed. Also broken down by phase. Gate: at least 30% | Doc 01 "Testing" ("A lure worked"); Build Plan Phase 1 "Done when" |
| Trap race | `trap_race_result` survival, overall and for the doc 01 case (`solo`, not `tainted`, `pried_at_once`). Deaths in that case are listed. Also reports the minimum and mean `seconds_spare` | Doc 01 "Testing" ("Trap race") |
| Spatial audio | `spatial_audio_trial` correct placements by sound and distance, overall and per tester, plus the doc 01 cells not tested yet (voice and whistle at 10, 30 and 60 m). Read from **every** peer's file: the tester's own client writes it (doc 05 s18) | Doc 01 "Testing" ("Spatial audio") |
| Other | `death`, `trap_sprung` and `money_changed` counts; `hold_completed` mean seconds by verb; `inside_at_night` seconds by player | Doc 01 "Testing" ("Logs") |

Every record is checked against the section 10 shape:

- `t` is a number, `day` an int, `peer` an int, `event` a string and `data` an object;
- `phase` is a CONTRACTS section 8 phase ID.

A record that breaks this is listed as malformed. Under `--strict`, any malformed record makes the
exit code 1. A log with none of these events is still a pass: each measure reports "none logged".

**Inference, to be settled by doc 05 (PP-07), which owns the full event list:**

- `within_s` is read as the seconds the target took to move. CONTRACTS section 10's example
  (`"within_s": 8`) could also mean the length of the window. If it is the window, the checker needs
  the actual time instead.
- The `spatial_audio_trial` fields `sound`, `distance_m` and `correct` are provisional. Section 10
  names the event but not its fields.
- `player` in `data` is the player the event is about. When it is absent, the logging peer is used.

## Playtest kit: `playtest.py`, `package_playtest.py`, `playtest/`

Step by step: [playtest/checklist.md](playtest/checklist.md). Hand testers
[playtest/tester_brief.md](playtest/tester_brief.md) (controls and setup only; no coaching).

```bash
uv run tools/qa/package_playtest.py                     # builds/playtest_<build id>.zip for a remote tester
uv run tools/qa/package_playtest.py --release           # clean tree, HEAD on origin/main: publishes GitHub release; installed kits self-update (docs/10_install_and_updates.md)
uv run tools/qa/playtest.py new --session 1 --networks different --fresh B --smoke
uv run tools/qa/playtest.py tally logs/qa/playtest_p1_s1_<ts>              # observer, second terminal
uv run tools/qa/playtest.py auto --testers A,B,C --fresh B                # after play: does sessions, collect, report
uv run tools/qa/playtest.py sessions --multi                               # find the game session id
uv run tools/qa/playtest.py collect logs/qa/playtest_p1_s1_<ts> --session <id> brenny_logs.zip
uv run tools/qa/playtest.py report logs/qa/playtest_p1_s1_<ts> logs/qa/playtest_p1_s2_<ts>
```

| Command | Writes into the session folder |
|---|---|
| `new` | `session.json` (phase, session number, build id, networks, tester labels, fresh testers, smoke result, `valid`) and `notes.md` from `playtest/session_notes.md`. `--networks`: `different`, `same` or `one_machine` |
| `tally` | `observer.jsonl`: one line per `s` scream, `l` laugh, `b` bored, `n` note. `g` sets game `t` = 0 when the host's session starts, so tally times match the logs. Rerunning resumes |
| `collect` | `user_logs/<session_id>/peer_<id>.jsonl`: this machine's `user://logs` written since `new`, plus each zip or folder given. A friend's sessions this machine has no log of are skipped (`--keep-all` keeps them). `--session <id>` takes only that game session, however old (use it when `new` was run after play, or when QA runs share the machine). Prints one line per session kept; `--verbose` lists every file. A duplicate file keeps the longer copy. Then `measures.json` and `measures.txt` from `check_logs.py` |
| `auto` | After play, one step. Picks the newest game session on this machine that another person joined (from `player_joined` in the host file; bots and solo starts don't count), the `audiotest_*` runs within 12 hours of it (here and in the zips), and every `Downloads/brenny_logs*.zip`. Reuses the session folder that already holds that game, else makes the next `playtest_p1_s<N>_*`. Then `collect --session` and `report` over every session folder of the phase. `--session <id>` picks the game by hand; zips can be given as arguments |
| `sessions` | Nothing: lists this machine's game sessions (`session_id`, peer files, size, last write), newest first. `--multi` hides solo runs. Session ids are local time |
| `report` | `report.md` in the last folder: per-session table (build, networks, testers, screams, laughs, bored) and the doc 09 s3 rows as `PASS`, `FAIL`, `NO DATA` or `MANUAL` |

Report rules for DD Phase 1 (doc 09 s2, s3, s5, s6; placeholders there are placeholders here):

- A session counts when `valid` is true, it has a host file, and it has 2 players.
- At least 2 such sessions, a fresh tester in one, and one on `different` networks.
- Lures: at least 30% over at least 20 `lure_result`s, pooled.
- Trap race: every solo, untainted, pried-at-once race survived. The 2.0 s minimum spare is `MANUAL`:
  the log does not say normal or deep trap.
- Spatial audio: each of the 6 cells at least 80% pooled, no tester below 60% in a cell, 2 testers.
- Turnips: `plant`, `water`, `sell` holds logged; the 15% check against `data/labor.json` is `MANUAL`.
- Generator: `generator` events present and no `speed_violation`.
- Feel rows (day safe, night tense, Stalk by sound) and the authority grep are always `MANUAL`.

`package_playtest.py` uses the "Playtest (Windows)" preset (D-029) and refuses a dirty tree, so the
build id names a commit. The zip holds the game and its console wrapper, the TwoVoIP DLL and
licenses, `START HERE.txt`, `TESTER BRIEF.md`, `BUILD.txt`, `Host.bat`, `Join.bat`, `SpatialTest.bat` (runs
`res://game/debug/spatial_audio_test.tscn` solo; logs land in `audiotest_<time>/`) and `send_logs.bat`. There is no menu yet, so a bare double-click on the exe starts a solo session without
`--phase1` content; `Host.bat` runs `-- --host --phase1 --port=45120` and `Join.bat` asks for the host's
Tailscale address and runs `-- --join=<ip>:45120 --phase1` (D-024). Both run the game's own phase
lengths (D-032); the host speeds things up in play with the dev console. `Host.bat` passes `--dev`, so the host can open the dev console with the backquote key (D-031). `send_logs.bat` zips the log
folders and `godot*.log` from the last 12 hours to `brenny_logs.zip` on the Desktop.

**Not yet run on a real session.** Nothing in `game/` writes these events yet (DD Phase 1 builds
them). The first real session also checks the kit: hand-count five lines (doc 09 s4).

## Self-test: `tests/qa/test_harness.py`

```bash
uv run tests/qa/test_harness.py
```

The self-test runs the checker, the error scanner and the multi-instance argument builder on the
fixtures in `tests/qa/fixtures/`. Those fixtures cover:

- the lure boundaries: exactly 10.0 m does not count, exactly 8 s does;
- a client file that must not be counted, and a session without a host file;
- malformed lines;
- a sample of Godot output with ANSI colour codes, CRLF line ends and a crash banner.

A `.gdignore` file keeps Godot out of the fixtures folder.

**Gotcha:** the root `.gitignore` ignores every folder named `logs/`, at any depth. Fixture folders
are therefore named `sessions*/`. A fixture under a folder called `logs/` passes locally but is never
committed.

## Files

| Path | Purpose |
|---|---|
| `tools/qa/godot_qa.py` | Shared code: finds Godot, runs it, scans for errors, asks for `user://` |
| `tools/qa/smoke.py`, `multi.py`, `check_logs.py` | The three commands |
| `tools/qa/playtest.py`, `tools/qa/package_playtest.py`, `tools/qa/playtest/`, `tests/qa/test_playtest.py` | Playtest kit and its self-test |
| `tools/qa/grep_rules.py`, `tests/qa/test_grep_rules.py` | Review greps and their self-test (doc 09 section 9) |
| `tests/qa/parse_check.tscn` + `.gd` | Loads every script so parse errors print; a scene run because autoloads are not registered under `-s` (Q-040) |
| `tests/qa/print_user_dir.gd` | Prints `OS.get_user_data_dir()` |
| `tests/qa/fake_peer.gd` | ENet fake peer for the launcher self-check |
| `tests/qa/test_harness.py`, `tests/qa/fixtures/` | Self-test |
| `tests/qa/perf_probe.tscn` + `.gd` | Windowed frame-time and render-counter probe (doc 09 section 10). Prints one `perf_probe` line; the exit prints a leaked-resource error, so `multi.py` reads FAIL |

Code owners add their own tests under `tests/<area>/` (CONTRACTS section 2).
