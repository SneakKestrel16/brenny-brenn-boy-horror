"""Tune one later season's debt base per player count (doc 02 section 21.6).

Run: uv run --no-project python -I tools/sim/tune_campaign.py --season 2 --target 57 [--runs 3000] [--seed 7]
Seasons before --season are taken from data/next_season.json as it stands. Prints the 4p-scale base
(`debt_total_4p_by_players`) whose final clear rate lands nearest --target, and the first clear rate there.
Final clear falls as the base rises, so a bisection works; the answer is rounded to 5 coins.
"""

import argparse
import copy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sim  # noqa: E402


def rates(data, layout, pol, p, season, runs, seed, base):
    d = copy.deepcopy(data)
    rec = d["next_season"][f"season_{season}"]
    rec["debt_total_4p_by_players"] = {str(p): base}
    row = sim.run_campaign(d, layout, pol, [p], runs, seed, season)[p][season - 1]
    return row["final_clear_pct"], row["first_clear_pct"], row["reached_pct"]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--season", type=int, required=True)
    ap.add_argument("--target", type=float, required=True)
    ap.add_argument("--players", default="2,3,4,5,6")
    ap.add_argument("--runs", type=int, default=3000)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args(argv)
    data, layout = sim.load_data(), sim.load_json(HERE / "layout.json")
    pol = sim.load_json(HERE / "policies" / "median.json")
    for p in (int(x) for x in a.players.split(",")):
        lo, hi = 600, 3200
        while hi - lo > 5:
            mid = (lo + hi) // 2 // 5 * 5
            final, first, _ = rates(data, layout, pol, p, a.season, a.runs, a.seed, mid)
            lo, hi = (mid, hi) if final > a.target else (lo, mid)
        final, first, reached = rates(data, layout, pol, p, a.season, a.runs, a.seed, hi)
        print(f"{p}p season {a.season}: base {hi} final {final}% first {first}% (reached {reached}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
