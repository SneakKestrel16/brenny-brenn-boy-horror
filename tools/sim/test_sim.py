"""Doc 02 section 18.4: tests that must pass before tuning.

Run: uv run --no-project python -I tools/sim/test_sim.py
"""

import random
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sim  # noqa: E402

DATA = sim.load_data()
LAYOUT = sim.load_json(HERE / "layout.json")
MEDIAN = sim.load_json(HERE / "policies" / "median.json")
PERFECT = sim.load_json(HERE / "policies" / "perfect_start.json")
BASE = {"name": "baseline"}


def model(pol=MEDIAN, scn=BASE):
    return sim.Model(DATA, LAYOUT, pol, scn)


class Tests(unittest.TestCase):
    def test_perfect_start(self):  # doc 02 17.1
        m = model(PERFECT)
        for players, want in ((4, 322), (3, 261), (2, 194)):
            r = sim.simulate(m, players, random.Random(1))
            self.assertEqual(r["bank_pre4"], want, f"{players}p")

    def test_debt_example(self):  # doc 02 7.3: 4p, one drops before dawn 2
        m = model()
        total = m.debt([100], 80)
        self.assertEqual((total, m.first_of(total), total - m.first_of(total)), (1077, 211, 866))

    def test_debt_table(self):  # doc 02 7.1
        m = model()
        for players, want in ((4, (1300, 255, 1045)), (3, (1040, 204, 836)), (2, (780, 153, 627)),
                              (5, (1560, 306, 1254)), (6, (1820, 357, 1463))):
            total = m.debt([], m.pct[players])
            first = m.first_of(total)
            self.assertEqual((total, first, total - first), want, f"{players}p")

    def test_debt_extra_cases(self):  # doc 02 7.3
        m = model()
        total = m.debt([60, 60], 80)  # 2p, a third at dawn 3
        self.assertEqual((total, m.first_of(total), total - m.first_of(total)), (966, 189, 777))
        total = m.debt([100] * 5, 80)  # 4p pays 255 at dawn 4, one leaves before dawn 6
        self.assertEqual((total, total - 255), (1226, 971))

    def test_pumpkin_payouts(self):  # doc 02 6
        m = model()
        want = {"giant": (250, 200, 150, 300, 350), "large": (150, 120, 90, 180, 210),
                "medium": (75, 60, 45, 90, 105), "sad": (20, 16, 12, 24, 28)}
        for size, vals in want.items():
            self.assertEqual(tuple(m.payout(size, p) for p in (4, 3, 2, 5, 6)), vals, size)

    def test_medical(self):  # doc 02 8: first, later, cap
        m = model()
        m.pay = m.pct  # doc 01 scaling; the tuned payment_pct_by_players is checked by the season targets
        want = {4: (25, 50, 120), 3: (20, 40, 96), 2: (15, 30, 72), 5: (30, 60, 144), 6: (35, 70, 168)}
        for p, (first, later, cap) in want.items():
            self.assertEqual(m.medical(p, 1), first)
            self.assertEqual(m.medical(p, 2), first + later)
            self.assertEqual(m.medical(p, 10), cap)

    def test_ramp(self):  # doc 02 11: disturbances, bear / pit / bells
        m = model()
        want = {  # day: {players: (dist, bear, pit, bells)}
            1: {4: (1, 2, 1, 0), 3: (1, 2, 1, 0), 2: (1, 2, 1, 0), 5: (2, 3, 2, 0), 6: (2, 3, 2, 0)},
            3: {4: (2, 3, 2, 0), 3: (2, 3, 2, 0), 2: (2, 2, 2, 0), 5: (3, 4, 3, 0), 6: (3, 5, 3, 0)},
            4: {4: (2, 3, 2, 1), 3: (2, 3, 2, 1), 2: (2, 2, 2, 1), 5: (3, 4, 3, 2), 6: (3, 5, 3, 2)},
            5: {4: (3, 4, 3, 1), 3: (3, 4, 3, 1), 2: (2, 3, 2, 1), 5: (4, 5, 4, 2), 6: (5, 6, 5, 2)},
            6: {4: (3, 5, 3, 2), 3: (3, 4, 3, 2), 2: (2, 3, 2, 2), 5: (4, 6, 4, 3), 6: (5, 7, 5, 3)},
            7: {4: (4, 0, 0, 0), 3: (4, 0, 0, 0), 2: (3, 0, 0, 0), 5: (5, 0, 0, 0), 6: (6, 0, 0, 0)},
        }
        for day, row in want.items():
            for p, counts in row.items():
                self.assertEqual(m.ramp_counts(day, p), counts, f"day {day} {p}p")

    def test_debt_derived_table(self):  # D-079: payment_pct_by_players 59/85/101 -> debt.json derived_by_players
        m = model()
        for players, want in DATA["debt"]["season"]["derived_by_players"].items():
            total = m.debt([], m.pay[int(players)])
            first = m.first_of(total)
            self.assertEqual((total, first, total - first), (want["total"], want["first"], want["final"]), f"{players}p")
        self.assertEqual({p: DATA["debt"]["season"]["derived_by_players"][str(p)]["total"] for p in (2, 3, 4)}, {2: 767, 3: 1105, 4: 1313})

    def test_roles_and_phase4_data(self):  # P4-03: ten roles, the two new disturbances enabled with a fix, animals
        self.assertEqual(len(DATA["roles"]), 10)
        for r in DATA["roles"].values():
            self.assertTrue(r["perks"])
        for sid in ("broken_fence", "pumpkin_gnaw"):
            self.assertTrue(DATA["sabotage"][sid]["enabled"])
            self.assertIn("fix", DATA["sabotage"][sid])
        self.assertEqual(DATA["season"]["animal_species"]["value"], ["chicken", "pig", "cow"])
        self.assertIn("round_up", DATA["labor"])

    def test_short_season_from_data(self):
        m = model(scn={"name": "short_season", "short_season": True})
        self.assertEqual((m.days, m.first_dawn, m.debt_base, m.crops["pumpkin"]["grow_days"]), (3, None, 360, 1))

    def test_fixed_seed_repeats(self):
        m = model()
        a = sim.simulate(m, 3, random.Random("1:3:0"))
        b = sim.simulate(m, 3, random.Random("1:3:0"))
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
