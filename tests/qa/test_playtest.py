# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Self-test for tools/qa/playtest.py and package_playtest.py on temp folders. Needs no Godot.

    uv run tests/qa/test_playtest.py
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools" / "qa"))

import package_playtest  # noqa: E402
import playtest  # noqa: E402


def _rec(t: float, event: str, data: dict, peer: int = 1, phase: str = "day") -> str:
    return json.dumps({"t": t, "day": 1, "phase": phase, "peer": peer, "event": event, "data": data})


def _quiet(fn, *args):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*args)


def _new(root: Path, session: int, networks: str = "different", fresh: str = "B") -> Path:
    argv = ["new", "--session", str(session), "--networks", networks, "--fresh", fresh, "--build-id", "abc1234", "--out-root", str(root)]
    _quiet(playtest.main, argv)
    (folder,) = [p for p in root.iterdir() if p.name.startswith(f"playtest_p1_s{session}_")]
    return folder


def _good_session(sid: str) -> dict[str, list[str]]:
    """Host and client files for one session that meets every automatic Phase 1 row."""
    host = [_rec(0, "session_start", {"session_id": sid, "build_id": "abc1234", "players": [1, 2]})]
    for i in range(10):  # 10 lures, 4 worked
        host.append(_rec(100 + i, "lure_result", {"lure_id": i, "target": 2, "moved_m": 12.0 if i < 4 else 3.0, "within_s": 5}, phase="night"))
    for i in range(3):
        host.append(_rec(200 + i, "trap_race_result", {"player": 2, "solo": True, "tainted": False, "pried_at_once": True, "survived": True, "seconds_spare": 3.1}))
    for verb in ("plant", "water", "sell"):
        host.append(_rec(300, "hold_completed", {"verb": verb, "seconds": 2.0}))
    host.append(_rec(310, "generator", {"state": "fuelled"}))
    peer_files = {"peer_1.jsonl": host, "peer_2.jsonl": []}
    for peer in (1, 2):  # each tester's client writes its own trials, all correct
        lines = peer_files[f"peer_{peer}.jsonl"]
        for sound in ("voice", "whistle"):
            for d in (10, 30, 60):
                for _ in range(3):
                    lines.append(_rec(400, "spatial_audio_trial", {"sound": sound, "distance_m": d, "correct": True}, peer=peer))
    return peer_files


def _write_logs(root: Path, sid: str, files: dict[str, list[str]]) -> None:
    (root / sid).mkdir(parents=True, exist_ok=True)
    for name, lines in files.items():
        (root / sid / name).write_text("".join(x + "\n" for x in lines), encoding="utf-8")


class New(unittest.TestCase):
    def test_writes_session_json_and_filled_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = _new(Path(tmp), 1)
            meta = json.loads((folder / "session.json").read_text())
            notes = (folder / "notes.md").read_text()
        self.assertEqual((meta["phase"], meta["session"], meta["networks"]), (1, 1, "different"))
        self.assertEqual((meta["testers"], meta["fresh_testers"], meta["build_id"]), (["A", "B"], ["B"], "abc1234"))
        self.assertEqual(meta["smoke"], "not run")
        self.assertNotIn("{{", notes)
        self.assertIn("| Build id | abc1234 |", notes)

    def test_fresh_tester_must_be_a_tester(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(SystemExit):
            _new(Path(tmp), 1, fresh="C")


class Tally(unittest.TestCase):
    def test_times_count_from_go_and_undo_and_resume(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = _new(Path(tmp), 1)
            ticks = iter([990.0, 1000.0, 1012.5, 1020.0, 1030.0])
            args = playtest.argparse.Namespace(folder=folder)
            stdin = io.StringIO("s A\ng\nl B\nb\nu\nn tester B froze at the gate\nq\nl\n")
            _quiet(playtest.cmd_tally, args, stdin, lambda: next(ticks))
            recs = [json.loads(x) for x in (folder / "observer.jsonl").read_text().splitlines()]
            self.assertEqual([r["kind"] for r in recs], ["scream", "go", "laugh", "note"])
            self.assertIsNone(recs[0]["t"])  # before go
            self.assertEqual((recs[2]["t"], recs[2]["who"]), (12.5, "B"))
            self.assertEqual(recs[3]["text"], "tester B froze at the gate")
            # A second tally keeps the first go as t = 0.
            _quiet(playtest.cmd_tally, args, io.StringIO("l\n"), lambda: 1100.0)
            last = json.loads((folder / "observer.jsonl").read_text().splitlines()[-1])
            self.assertEqual(last["t"], 100.0)


class Collect(unittest.TestCase):
    def test_local_since_new_plus_zip_and_folder_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            folder = _new(tmp / "qa", 1)
            user = tmp / "user_logs"
            good = _good_session("20261008_190000_ab12")
            _write_logs(user, "20261008_190000_ab12", {"peer_1.jsonl": good["peer_1.jsonl"]})
            _write_logs(user, "20260101_000000_0000", {"peer_1.jsonl": [_rec(0, "death", {})]})
            old = time.time() - 86400
            os.utime(user / "20260101_000000_0000" / "peer_1.jsonl", (old, old))
            friend = tmp / "brenny_logs.zip"
            with zipfile.ZipFile(friend, "w") as z:
                z.writestr("20261008_190000_ab12/peer_2.jsonl", "".join(x + "\n" for x in good["peer_2.jsonl"]))
                z.writestr("20250505_000000_ffff/peer_2.jsonl", _rec(0, "death", {}, peer=2) + "\n")  # friend's old session
                z.writestr("../../evil/peer_3.jsonl", "x")
                z.writestr("notes.txt", "x")
            copy = tmp / "copy" / "20261008_190000_ab12"
            copy.mkdir(parents=True)
            (copy / "peer_1.jsonl").write_text("short\n")  # shorter than the local host file: kept local
            log = playtest.collect(folder, [friend, tmp / "copy"], user)
            got = sorted(p.relative_to(folder / "user_logs").as_posix() for p in (folder / "user_logs").rglob("*.jsonl"))
            self.assertEqual(got, ["20261008_190000_ab12/peer_1.jsonl", "20261008_190000_ab12/peer_2.jsonl"])
            self.assertTrue(any("skipped 20250505_000000_ffff" in x for x in log))
            self.assertTrue(any(x.startswith("kept 20261008_190000_ab12/peer_1.jsonl") for x in log))
            self.assertFalse((tmp / "evil").exists())
            rep = json.loads((folder / "measures.json").read_text())
            self.assertEqual(rep["spatial_audio"]["trials"], 36)
            self.assertTrue((folder / "measures.txt").read_text().startswith("Files: 2"))

    def test_session_filter_takes_old_local_logs_and_only_that_session(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            folder = _new(tmp / "qa", 1)
            user = tmp / "user_logs"
            _write_logs(user, "s_real", {"peer_1.jsonl": [_rec(0, "death", {})]})
            _write_logs(user, "s_qa_run", {"peer_1.jsonl": [_rec(0, "death", {})]})
            old = time.time() - 86400  # played before `new`: kept because it is named
            os.utime(user / "s_real" / "peer_1.jsonl", (old, old))
            friend = tmp / "f.zip"
            with zipfile.ZipFile(friend, "w") as z:
                z.writestr("s_real/peer_7.jsonl", _rec(0, "voice_stats", {}, peer=7) + "\n")
                z.writestr("s_friend_solo/peer_1.jsonl", _rec(0, "death", {}) + "\n")
            log = playtest.collect(folder, [friend], user, sessions=["s_real"])
            got = sorted(p.relative_to(folder / "user_logs").as_posix() for p in (folder / "user_logs").rglob("*.jsonl"))
            self.assertEqual(got, ["s_real/peer_1.jsonl", "s_real/peer_7.jsonl"])
            self.assertTrue(any("s_friend_solo" in x and "not a --session" in x for x in log))

    def test_sessions_lists_newest_multi_peer_first(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            user = Path(tmp)
            _write_logs(user, "solo", {"peer_1.jsonl": ["{}"]})
            _write_logs(user, "pair", {"peer_1.jsonl": ["{}"], "peer_2.jsonl": ["{}"]})
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                playtest.main(["sessions", "--multi", "--user-logs-dir", str(user)])
        self.assertIn("pair", out.getvalue())
        self.assertNotIn("solo", out.getvalue())

    def test_safe_member_rejects_escapes(self) -> None:
        self.assertEqual(playtest._safe_member("logs/s1/peer_2.jsonl"), ("s1", "peer_2.jsonl"))
        self.assertEqual(playtest._safe_member("s1\\peer_2.jsonl"), ("s1", "peer_2.jsonl"))
        for bad in ("../peer_2.jsonl", "/abs/s1/peer_2.jsonl", "s1/../peer_2.jsonl", "peer_2.jsonl", "s1/other.jsonl"):
            self.assertIsNone(playtest._safe_member(bad), bad)


class Report(unittest.TestCase):
    def _sessions(self, tmp: Path, second: dict[str, list[str]] | None = None, networks2: str = "same") -> list[Path]:
        folders = []
        for n, (networks, files) in enumerate([("different", _good_session("s1")), (networks2, second or _good_session("s2"))], 1):
            folder = _new(tmp, n, networks=networks, fresh="B" if n == 1 else "")
            _write_logs(folder / "user_logs", f"s{n}", files)
            folders.append(folder)
        return folders

    def _rows(self, folders: list[Path]) -> dict[str, tuple[str, str]]:
        text = playtest.report(folders)
        rows = {}
        for line in text.splitlines():
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) == 3 and cells[1] in ("PASS", "FAIL", "MANUAL", "NO DATA"):
                rows[cells[0]] = (cells[1], cells[2])
        return rows

    def test_two_good_sessions_pass_every_automatic_row(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._rows(self._sessions(Path(tmp)))
        auto = {k: v for k, v in rows.items() if v[0] != "MANUAL"}
        self.assertTrue(all(v[0] == "PASS" for v in auto.values()), auto)
        self.assertIn("8/20 = 40%", rows["Lures: at least 30% walk toward"][1])
        self.assertEqual(rows["First: voice on different home networks"][0], "MANUAL")

    def test_failures_are_named(self) -> None:
        bad = _good_session("s2")
        bad["peer_1.jsonl"] = [x for x in bad["peer_1.jsonl"] if '"lure_result"' not in x]  # 10 lures, too few
        bad["peer_1.jsonl"].append(_rec(500, "trap_race_result", {"player": 2, "solo": True, "tainted": False, "pried_at_once": True, "survived": False, "seconds_spare": 0}))
        bad["peer_2.jsonl"] = [x.replace('"correct": true', '"correct": false') if '"whistle", "distance_m": 60' in x else x for x in bad["peer_2.jsonl"]]
        bad["peer_1.jsonl"].append(_rec(600, "speed_violation", {"player": 2}))
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._rows(self._sessions(Path(tmp), bad))
        self.assertEqual(rows["Lures: at least 30% walk toward"][0], "FAIL")
        self.assertIn("4/10", rows["Lures: at least 30% walk toward"][1])
        self.assertEqual(rows["Trap race: solo, untainted, pried at once survives"][0], "FAIL")
        self.assertEqual(rows["Spatial audio: no tester below 60% in a cell"][0], "FAIL")
        self.assertIn("s2/peer_2 whistle@60m 0/3", rows["Spatial audio: no tester below 60% in a cell"][1])
        self.assertEqual(rows["Spatial audio: every cell >= 80% pooled"][0], "FAIL")
        self.assertEqual(rows["Generator run, no speed_violation"][0], "FAIL")

    def test_session_without_host_file_or_second_player_does_not_count(self) -> None:
        only_client = {"peer_2.jsonl": _good_session("s2")["peer_2.jsonl"]}
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._rows(self._sessions(Path(tmp), only_client))
        self.assertEqual(rows["Session 2 counts"][0], "FAIL")
        self.assertIn("no host file", rows["Session 2 counts"][1])
        self.assertEqual(rows["At least 2 valid sessions"], ("FAIL", "1 valid"))

    def test_no_logs_reports_no_data(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folders = [_new(Path(tmp), 1), _new(Path(tmp), 2)]
            rows = self._rows(folders)
        self.assertEqual(rows["Lures: at least 30% walk toward"][0], "NO DATA")
        self.assertEqual(rows["Spatial audio: 6 cells"][0], "NO DATA")


class Package(unittest.TestCase):
    def test_zip_layout_and_bat_safety(self) -> None:
        self.assertNotIn("%", package_playtest.SEND_LOGS)  # cmd.exe would expand it
        with tempfile.TemporaryDirectory() as tmp:
            export_dir = Path(tmp) / "export"
            export_dir.mkdir()
            (export_dir / package_playtest.EXE).write_bytes(b"MZ")
            (export_dir / "libtwovoip.windows.template_release.x86_64.dll").write_bytes(b"MZ")
            (export_dir / "Brenny Brenn Boy Horror.console.exe").write_bytes(b"MZ")
            old = package_playtest.EXPORT_DIR
            package_playtest.EXPORT_DIR = export_dir
            try:
                names = package_playtest.write_zip(Path(tmp) / "out.zip", "abc1234")
            finally:
                package_playtest.EXPORT_DIR = old
            with zipfile.ZipFile(Path(tmp) / "out.zip") as z:
                start = z.read("brenny_playtest/START HERE.txt").decode()
        top = "brenny_playtest/"
        for want in (package_playtest.EXE, "Brenny Brenn Boy Horror.console.exe", "Host.bat", "Join.bat", "send_logs.bat", "START HERE.txt", "TESTER BRIEF.md", "BUILD.txt", "licenses/LICENSE"):
            self.assertIn(top + want, names)
        self.assertIn("abc1234", start)
        host = package_playtest.HOST_BAT.format(exe=package_playtest.EXE, port=package_playtest.PORT)
        join = package_playtest.JOIN_BAT.format(exe=package_playtest.EXE, port=package_playtest.PORT)
        self.assertIn('-- --host --phase1 --dev --port=45120\n', host)
        self.assertIn('-- --join=%HOSTIP%:45120 --phase1\n', join)
        self.assertNotIn("--dev", join)  # the dev console is the host's only (D-031)
        for bat in (host, join):  # the game's own phase lengths (D-032)
            self.assertNotIn("--day-s", bat)
        self.assertIn("\r\n", start)


if __name__ == "__main__":
    unittest.main()
