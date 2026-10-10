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
import json
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

    def test_p222_measures_on_synthetic_records(self) -> None:
        def rec(event: str, data: dict, peer: int = 1, phase: str = "night") -> check_logs.Record:
            return check_logs.Record("s", peer, 1.0, 1, phase, peer, event, data)

        recs = [
            rec("lure_played", {"lure_id": "a", "kind": "clip"}), rec("lure_played", {"lure_id": "b", "kind": "sound"}),
            rec("lure_result", {"lure_id": "a", "moved_m": 12, "within_s": 3}), rec("lure_result", {"lure_id": "b", "moved_m": 1, "within_s": 8}),
            rec("trap_changed", {"by": "creature", "kind": "bear", "state": "set"}), rec("trap_changed", {"by": 2, "state": "disarmed"}),
            rec("trap_stolen", {}), rec("hold_completed", {"verb": "disarm_bear", "seconds": 5}),
            rec("medical_bill", {"players": 4, "deaths": 1, "bill": 25, "paid": 0, "to_final": 25}, phase="dawn"),
        ]
        lure = check_logs.lure_measure(recs, [])
        self.assertEqual((lure["by_source"]["recorded"]["worked"], lure["by_source"]["generic"]["played"]), (1, 1))
        ts = check_logs.trap_sweep_measure(recs)
        self.assertEqual((ts["set_by_creature"], ts["stolen"], ts["player_state_changes"], ts["sweep_holds"]), ({"bear": 1}, 1, {"disarmed": 1}, {"disarm_bear": 1}))
        self.assertEqual(check_logs.bill_measure(recs)["bills"][0]["to_final"], 25)
        rtt = check_logs.rtt_measure([rec("net_rtt", {"to": 1, "rtt_ms": 10}, peer=2), rec("net_rtt", {"to": 1, "rtt_ms": 20}, peer=2)])
        self.assertEqual(rtt["s/peer_2->1"]["mean"], 15.0)

    def test_p313_phase3_measures_on_synthetic_records(self) -> None:
        def rec(t: float, event: str, data: dict, day: int = 1, phase: str = "day") -> check_logs.Record:
            return check_logs.Record("s", 1, t, day, phase, 1, event, data)

        recs = [
            rec(0, "tension", {"value": 5, "phase": "relax", "profile": "day"}), rec(10, "tension", {"value": 50, "phase": "build_up", "profile": "day"}),
            # Player 2: big at 100, private at 150 (50 s gap: violation), second big on day 1 (violation).
            rec(100, "scare", {"kind": "jumpscare", "target": 2, "big": True, "private": False, "third": 2}),
            rec(150, "scare", {"kind": "whisper", "target": 2, "big": False, "private": True, "third": 3}),
            rec(400, "scare", {"kind": "shed", "target": 2, "big": True, "private": False, "third": 3}),
            # Player 3: one in third 1 (violation); a forced one 3 s after a dev command (not judged).
            rec(20, "scare", {"kind": "wrong_count", "target": 3, "big": False, "private": True, "third": 1}),
            rec(500, "dev_command", {"peer": 1, "line": "scare jumpscare 3"}),
            rec(503, "scare", {"kind": "jumpscare", "target": 3, "big": True, "private": False, "third": 1}),
            rec(600, "scare", {"kind": "fake_out", "target": -1, "big": False, "private": False, "third": 3}),
            rec(601, "scare_dropped", {"kind": "jumpscare", "target": 2, "why": "budget"}),
            rec(700, "shaken", {"player": 2, "seconds": 60}), rec(701, "taint_changed", {"player": 2, "on": True, "cause": "leavings"}),
            rec(800, "taint_changed", {"player": 2, "on": False, "cause": "wash"}),
            rec(0, "disturbance_placed", {"kind": "trample", "day": 1}), rec(0, "disturbance_placed", {"kind": "dead_crow", "day": 1}),
            rec(900, "disturbance_fixed", {"kind": "trample", "fix": "plant"}),
            rec(1000, "lure_played", {"lure_id": "x", "owner_dead": True, "ghost": True}, phase="night"),
        ]
        te = check_logs.tension_measure(recs)
        self.assertEqual((te["samples"], te["value_max"], te["gap_s_max"]), (2, 50.0, 10.0))
        sc = check_logs.scare_measure(recs)
        self.assertEqual((sc["scares"], sc["forced"], sc["dropped_by_why"]), (6, 1, {"budget": 1}))
        self.assertEqual(len(sc["violations"]), 3, sc["violations"])
        self.assertEqual(sc["per_player"]["s/2"]["min_gap_s"], 50.0)
        self.assertIn("s/public", sc["per_player"])
        tn = check_logs.taint_measure(recs)
        self.assertEqual((tn["tainted_by_cause"], tn["cured_by_cause"], len(tn["taint_after_shaken"])), ({"leavings": 1}, {"wash": 1}, 1))
        sb = check_logs.sabotage_measure(recs)
        self.assertEqual(sb["fixed_by_fix"], {"plant": 1})
        opens = check_logs._sabotage_opens()
        self.assertEqual(opens["trample"], 1)
        self.assertEqual(sb["before_opens_day"], ["s day 1 dead_crow (opens day 3)"])
        lure = check_logs.lure_measure(recs, [])
        self.assertEqual((lure["played_owner_dead"], lure["played_ghost"]), (1, 1))

    def test_q021_lure_window_s_tally(self) -> None:
        recs = [check_logs.Record("s", 1, t, 1, "night", 1, "lure_result", d) for t, d in (
            (1.0, {"moved_m": 12, "within_s": 3, "window_s": 8}), (2.0, {"moved_m": 1, "within_s": 6, "window_s": 6}),
            (3.0, {"moved_m": 1, "within_s": 8}))]
        lure = check_logs.lure_measure(recs, [])
        self.assertEqual(lure["window_s"], {"6": 1, "8": 1, "missing": 1})
        self.assertEqual(len(lure["window_not_doc01"]), 1)
        self.assertIn("window_s=6", lure["window_not_doc01"][0])

    def test_q021_spatial_angle_error_tally(self) -> None:
        recs = [check_logs.Record("s", 2, 1.0, 1, "day", 2, "spatial_audio_trial", {"sound": "voice", "distance_m": 30, "correct": True, "angle_error_deg": a})
                for a in (10.0, 30.0)]
        recs.append(check_logs.Record("s", 2, 2.0, 1, "day", 2, "spatial_audio_trial", {"sound": "voice", "distance_m": 30, "correct": False}))
        sp = check_logs.spatial_measure(recs, [])
        self.assertEqual(sp["angle_error_deg"], {"voice@30m": {"n": 2, "mean": 20.0, "max": 30.0}})
        self.assertEqual(sp["by_sound_distance"]["voice@30m"]["trials"], 3)

    def test_q021_close_call_tally(self) -> None:
        def cc(victim: int, result: str, rtt: float) -> check_logs.Record:
            return check_logs.Record("s", 1, 1.0, 1, "night", 1, "close_call", {"victim": victim, "kind": "lunge", "result": result, "rtt_ms": rtt})

        rep = check_logs.close_call_measure([cc(2, "hit", 40), cc(2, "miss_timeout", 300), cc(3, "miss_disagree", 90)])
        self.assertEqual((rep["calls"], rep["by_result"]), (3, {"hit": 1, "miss_disagree": 1, "miss_timeout": 1}))
        self.assertEqual(rep["by_victim"]["s/2"], {"results": {"hit": 1, "miss_timeout": 1}, "rtt_ms_max": 300})

    def test_p510_dev_toy_session_is_skipped_by_the_measures(self) -> None:
        def line(event: str, data: dict) -> str:
            return json.dumps({"t": 1.0, "day": 1, "phase": "night", "peer": 1, "event": event, "data": data})

        with tempfile.TemporaryDirectory() as tmp:
            for name, extra in (("toy_session", [line("dev_toy", {"toy": "shrink", "seconds": 60, "player": 1})]), ("real_session", [])):
                d = Path(tmp) / name
                d.mkdir()
                (d / "peer_1.jsonl").write_text("\n".join(extra + [line("death", {}), line("lure_result", {"moved_m": 20, "within_s": 5})]) + "\n", encoding="utf-8", newline="\n")
            rep = check_logs.analyze([Path(tmp)])
        self.assertEqual(rep["dev_toy_sessions"], ["toy_session"])
        self.assertEqual(rep["other"]["deaths"], 1)  # the real session's only
        self.assertEqual(rep["lure"]["lure_results"], 1)
        self.assertIn("Skipped 1 session(s)", check_logs.format_report(rep))

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
        self.assertEqual(check_logs.format_report(rep).count("none logged"), 7)  # close calls added (Q-021)

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
            ["godot", "--path", str(godot_qa.REPO_ROOT), "--audio-driver", "Dummy", "--headless", "--quit-after", "300", "-s", "res://x.gd", "--verbose", "--", "--qa-port=1", "--qa-role=client", "--free-mouse", "--profile=p2"],
        )

    def test_windows_tile_in_a_grid(self) -> None:
        cmd = multi.build_command("godot", 4, "", "", False, None, True)
        self.assertEqual(cmd[5:-3], ["--windowed", "--resolution", "640x360", "--position", "640,360"])
        self.assertEqual(cmd[-3:], ["--", "--free-mouse", "--profile=p4"])  # b66ddcc: copies 2+ get their own profile


if __name__ == "__main__":
    unittest.main(verbosity=2)
