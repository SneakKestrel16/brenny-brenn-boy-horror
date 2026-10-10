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

    def test_roles_and_phase4_data(self):  # P4-03: ten roles, plus Crowkeeper (P5-52) and Horror (P5-53), the two new disturbances enabled with a fix, animals
        self.assertEqual(len(DATA["roles"]), 12)
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
        self.assertEqual(m.debt([], 59, 2), sim.rhu(410 * 59, 100))  # 2p base override (D-082 item 5)
        self.assertEqual(m.debt([], 101, 4), sim.rhu(360 * 101, 100))
        self.assertNotIn("pumpkin_grow_days", DATA["difficulty"]["short_season"])  # D-082 item 4: grow time lives in pumpkin.json only

    def test_sell_bonus_and_unattended(self):  # P4-30, D-106: bonus rounds up per sale; Q-161 term is +3 when on
        m = model()
        m.sell_bonus = {2: 5}
        self.assertEqual((m.sold(40, 2), m.sold(41, 2), m.sold(0, 2), m.sold(40, 4)), (42, 44, 0, 40))
        self.assertEqual((model().unattended, model(dict(MEDIAN, unattended_term=True)).unattended), (0, 3))

    def test_fixed_seed_repeats(self):
        m = model()
        a = sim.simulate(m, 3, random.Random("1:3:0"))
        b = sim.simulate(m, 3, random.Random("1:3:0"))
        self.assertEqual(a, b)


class TestPhase5(unittest.TestCase):
    """DD Phase 5 (doc 02 sections 21, 22): campaign carry-over, season debts, quirks, imposter."""

    def test_season_debts(self):  # 4p entry equals the scalar; debt grows each season at every headcount
        ns = DATA["next_season"]
        for s in ("season_2", "season_3"):
            self.assertEqual(ns[s]["debt_total_4p_by_players"]["4"], ns[s]["debt_total_4p"])
        for p in "23456":
            self.assertLess(ns["season_2"]["debt_total_4p_by_players"][p], ns["season_3"]["debt_total_4p_by_players"][p])

    def test_carry_clamp_and_savings(self):
        m = sim.Model(DATA, LAYOUT, MEDIAN, {"name": "s2", "season": 2})
        a = sim.simulate(m, 2, random.Random(1), {"owned": 99, "savings": 30})
        self.assertEqual(a["owned_start"], m.max_plots[2])
        b = sim.simulate(m, 2, random.Random(1), {"owned": 0, "savings": 0})
        self.assertLessEqual(b["owned_start"], a["owned_start"])
        rule = DATA["next_season"]["carry"]
        self.assertEqual((rule["savings_pct"], rule["savings_cap_coins"], rule["savings_rounding"]), (25, 60, "floor"))

    def test_campaign_runs(self):
        camp = sim.run_campaign(DATA, LAYOUT, MEDIAN, [4], 40, 1, 3)
        self.assertEqual([r["season"] for r in camp[4]], [1, 2, 3])
        self.assertLessEqual(camp[4][2]["reached_pct"], camp[4][1]["reached_pct"])

    def test_trait_pool(self):  # one trait per season, every trait has overrides and a report line
        tr = DATA["creature_traits"]
        self.assertGreaterEqual(len(tr), DATA["next_season"]["campaign"]["seasons_max"] - 1)
        for rec in tr.values():
            self.assertTrue(rec["overrides"] and rec["report_line"])

    def test_quirks(self):  # D-153: ten quirks, never a forbidden effect
        q = DATA["quirks"]
        names = {"anxiety_disorder", "nyctophobia", "adhd", "paranoia", "schizophrenia", "dyspraxia",
                 "hoarding_disorder", "narcolepsy", "grandiose_delusions", "ocd"}
        self.assertEqual(set(q) - {"assign"}, names)
        self.assertEqual(q["nyctophobia"]["effects"]["light_radius_mult"], 0.5)
        self.assertIn("harm_creature", q["assign"]["forbidden"])

    def test_hoarding_cost(self):  # doc 02 22.3: +1 carry, walk x0.9 loses 1-6% of plot capacity
        base = model()
        e = DATA["quirks"]["hoarding_disorder"]["effects"]
        d = dict(DATA)
        d["labor"] = {k: dict(v) for k, v in DATA["labor"].items()}
        d["labor"]["walk"]["speed_mps"] *= e["walk_speed_mult"]
        d["labor"]["carry"]["capacity"] += e["carry_extra_slots"]
        slow = sim.Model(d, LAYOUT, MEDIAN, BASE)
        loss = 100 * (base.P - slow.P) / base.P
        self.assertTrue(1 <= loss <= 6, loss)

    def test_imposter(self):  # D-153: never kills, honest signals stay, no imposter below min_players
        r = DATA["imposter"]["rule"]
        self.assertFalse(r["kills"])
        self.assertIn("walkie", r["still_honest"])
        m = sim.Model(DATA, LAYOUT, MEDIAN, {"name": "imposter", "imposter": True})
        self.assertGreater(m.imp_loss_s, 0)
        self.assertEqual(m.imp_min, r["min_players"])

    def test_cosmetics(self):
        c = DATA["cosmetics"]
        self.assertFalse(c["rule"]["gameplay_effect"])
        self.assertEqual(c["rule"]["sold_when"], "season_debt_paid")
        for k, v in c.items():
            if k != "rule":
                self.assertGreater(v["price"], 0)
                self.assertIn(v["kind"], ("hat", "overalls"))


class TestCompare(unittest.TestCase):
    def test_self_test(self):
        import compare

        compare.self_test()


if __name__ == "__main__":
    unittest.main()
