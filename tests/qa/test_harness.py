# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Self-test for tools/qa: log checker on fixtures, Godot error scanner, multi-instance arguments.

    uv run tests/qa/test_harness.py

Needs no Godot. Fixtures live in tests/qa/fixtures/ (a .gdignore keeps Godot out of them).
"""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"
sys.path.insert(0, str(HERE.parents[1] / "tools" / "qa"))

import check_logs  # noqa: E402
import godot_qa  # noqa: E402
import multi  # noqa: E402


def _quiet_main(argv: list[str]) -> int:
    with contextlib.redirect_stdout(io.StringIO()):
        return check_logs.main(argv)


class LogCheckerFixture(unittest.TestCase):
    """tests/qa/fixtures/sessions: one session, host file plus a client file that must be ignored."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.rep = check_logs.analyze([FIXTURES / "sessions"])

    def test_lure_rate_uses_doc01_rule_and_host_file_only(self) -> None:
        lure = self.rep["lure"]
        # 11.2 m in 8 s worked (8 s is "within"); 10.0 m did not ("more than 10 m");
        # 25 m in 8.5 s did not; 12 m in 3 s worked. peer_2's 50 m lure is not the host's record.
        self.assertEqual((lure["worked"], lure["lure_results"]), (2, 4))
        self.assertAlmostEqual(lure["rate"], 0.5)
        self.assertTrue(lure["phase1_gate"])
        self.assertEqual(lure["lure_played"], 1)
        self.assertEqual(lure["by_phase"], {"day": {"worked": 1, "total": 1}, "night": {"worked": 1, "total": 3}})

    def test_logged_worked_flag_disagreeing_with_rule_is_reported(self) -> None:
        mismatches = self.rep["lure"]["worked_mismatches"]
        self.assertEqual(len(mismatches), 1)
        self.assertIn("moved_m=10.0", mismatches[0])

    def test_trap_race(self) -> None:
        tr = self.rep["trap_race"]
        self.assertEqual((tr["survived"], tr["races"]), (2, 3))
        key = tr["solo_untainted_pried_at_once"]
        self.assertEqual((key["survived"], key["races"]), (1, 2))
        self.assertEqual(len(key["deaths"]), 1)
        self.assertEqual(tr["seconds_spare_min"], 2.5)
        self.assertAlmostEqual(tr["seconds_spare_mean"], 3.25)

    def test_spatial_audio_reads_client_files_too(self) -> None:
        # Testers' clients write their own trials (doc 09 s7), so peer_2's whistle@30m counts.
        sp = self.rep["spatial_audio"]
        self.assertEqual(sp["trials"], 4)
        self.assertEqual(
            sp["by_sound_distance"],
            {"voice@10m": {"correct": 1, "trials": 2}, "whistle@30m": {"correct": 1, "trials": 1}, "whistle@60m": {"correct": 1, "trials": 1}},
        )
        self.assertEqual(sorted(sp["untested_doc01_cells"]), ["voice@30m", "voice@60m", "voice@72m", "whistle@10m", "whistle@72m"])
        self.assertEqual(sp["by_tester"]["fixture_session/peer_2"], {"whistle@30m": {"correct": 1, "trials": 1}})
        self.assertEqual(sp["by_tester"]["fixture_session/peer_1"]["voice@10m"], {"correct": 1, "trials": 2})

    def test_other_measures(self) -> None:
        o = self.rep["other"]
        self.assertEqual((o["deaths"], o["traps_sprung"], o["money_changed_events"]), (1, 1, 1))
        self.assertEqual(o["hold_seconds_by_verb"]["plant"], {"n": 2, "mean": 2.0})
        self.assertEqual(o["inside_at_night_seconds_by_player"], {2: 60.0})

    def test_clean_fixture_has_no_problems_and_text_report_renders(self) -> None:
        self.assertEqual(self.rep["problems"], [])
        self.assertEqual(self.rep["warnings"], [])
        text = check_logs.format_report(self.rep)
        self.assertIn("2/4 worked = 50%  [PASS]", text)
        self.assertIn("solo, untainted, pried at once: 1/2 survived", text)
        self.assertEqual(_quiet_main([str(FIXTURES / "sessions"), "--strict"]), 0)


class LogCheckerEdgeCases(unittest.TestCase):
    def test_empty_folder_reports_none_logged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rep = check_logs.analyze([Path(tmp)])
        self.assertEqual(rep["records"], 0)
        self.assertIsNone(rep["lure"]["rate"])
        self.assertEqual(rep["trap_race"]["races"], 0)
        self.assertEqual(rep["spatial_audio"]["trials"], 0)
        self.assertEqual(check_logs.format_report(rep).count("none logged"), 3)

    def test_session_without_host_file_falls_back_with_warning(self) -> None:
        rep = check_logs.analyze([FIXTURES / "sessions_no_host"])
        self.assertEqual(rep["lure"]["lure_results"], 1)
        self.assertTrue(any("no peer_1.jsonl" in w for w in rep["warnings"]))

    def test_malformed_records_are_reported_and_fail_strict(self) -> None:
        rep = check_logs.analyze([FIXTURES / "sessions_malformed"])
        problems = "\n".join(rep["problems"])
        self.assertIn(":2: not JSON", problems)
        self.assertIn(":3: missing or wrong type: t", problems)
        self.assertIn("phase 'midnight'", problems)
        self.assertIn("lure_result needs numeric moved_m and within_s", problems)
        self.assertIn("spatial_audio_trial needs", problems)
        self.assertEqual(_quiet_main([str(FIXTURES / "sessions_malformed")]), 0)
        self.assertEqual(_quiet_main([str(FIXTURES / "sessions_malformed"), "--strict"]), 1)


class ErrorScanner(unittest.TestCase):
    def setUp(self) -> None:
        self.text = (FIXTURES / "godot_output_errors.txt").read_text(encoding="utf-8")

    def test_finds_error_script_error_and_crash_lines(self) -> None:
        found = godot_qa.scan_errors(self.text)
        self.assertEqual(
            found,
            [
                "ERROR: qa push_error probe",  # ANSI colour codes stripped
                'SCRIPT ERROR: Parse Error: Unexpected "Indent" in class body.',
                "CrashHandlerException: Program crashed with signal 11",
                "USER ERROR: allowed by test",
            ],
        )

    def test_allow_list_and_crlf(self) -> None:
        import re

        found = godot_qa.scan_errors(self.text.replace("\n", "\r\n"), [re.compile("allowed by test")])
        self.assertEqual(len(found), 3)

    def test_clean_output_passes(self) -> None:
        self.assertEqual(godot_qa.scan_errors("Godot Engine v4.7.2\nWARNING: fine\nhello\n"), [])


class MultiArgs(unittest.TestCase):
    def test_engine_and_game_args_merge(self) -> None:
        cmd = multi.build_command("godot", 2, "-s res://x.gd -- --qa-port=1", "--verbose -- --qa-role=client", True, 300, True)
        self.assertEqual(
            cmd,
            ["godot", "--path", str(godot_qa.REPO_ROOT), "--audio-driver", "Dummy", "--headless", "--quit-after", "300", "-s", "res://x.gd", "--verbose", "--", "--qa-port=1", "--qa-role=client", "--free-mouse"],
        )

    def test_windows_tile_in_a_grid(self) -> None:
        cmd = multi.build_command("godot", 4, "", "", False, None, True)
        self.assertEqual(cmd[5:-2], ["--windowed", "--resolution", "640x360", "--position", "640,360"])
        self.assertEqual(cmd[-2:], ["--", "--free-mouse"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
