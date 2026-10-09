"""Doc 02 s18.5 compare: live full-season host logs against the season simulator.

Run: uv run --no-project python -I tools/sim/sim.py compare LOG [LOG ...] [--runs 2000] [--seed 1]
     uv run --no-project python -I tools/sim/compare.py --self-test
(origin: QA's tools/qa/sim_compare.py, P4-18, reviewed and adopted by the Game Designer.)

LOG is a host log: `peer_1.jsonl` (CONTRACTS s10) or a console capture holding `[log] <event> {json}` lines.
Stdlib only. Events read: session_start (difficulty), dawn_summary (day, coins), payment_made (final, ok, players,
balance, amount; early payments skipped), season_lost, season_ended, season_awards_shown (lost).

Metric (doc 02 s18.5, Q-038, ruling on Q-156): per dawn d = 2..8, the median live bank as a percentage of the next
scheduled payment, against the simulated median for the same player count; each dawn must be within 15 points.
Inference: "next payment due" is the scheduled payment with no penalty or deferred bill, so live and sim share one
denominator per headcount: the first payment before the first-payment dawn, the final payment (total - first) from it
on. Banks are after the dawn's payment (sim `banks`, live `dawn_summary` coins), except the final dawn, which uses the
bank before the final payment. Also gated (doc 09 s3): at least 6 seasons with at least one win and one loss.
First/final clear rates are reported, not gated.
"""

import argparse
import json
import random
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sim  # noqa: E402

GAP = 15  # doc 01 "Season simulator": within 15 points


def events(path: Path):
    """Yield (name, data) from a jsonl host log or a console capture."""
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "event" in e:
                yield e["event"], e.get("data") or {}
        elif line.startswith("[log] "):
            name, _, rest = line[6:].partition(" ")
            try:
                yield name, json.loads(rest) if rest else {}
            except json.JSONDecodeError:
                continue


def read_season(path: Path) -> dict:
    """Banks by dawn number (dawn = Clock.day + 1), headcount, outcome."""
    s = {"file": path.parent.name if path.suffix == ".jsonl" else path.name, "banks": {}, "players": None, "difficulty": "normal", "first": None, "final": None,
         "lost": False, "awards": None, "ended": False}
    for name, d in events(path):
        if name == "session_start":
            s["difficulty"] = d.get("difficulty", "normal")
        elif name == "dawn_summary":
            s["banks"][int(d["day"]) + 1] = int(d["coins"])
        elif name == "payment_made" and not d.get("early"):
            s["players"] = int(d.get("players") or 0) or s["players"]
            if d.get("final"):
                s["final"] = bool(d.get("ok"))
                s["pre_final"] = int(d["balance"]) + int(d["amount"])
            else:
                s["first"] = bool(d.get("ok"))
        elif name == "season_lost":
            s["lost"] = True
        elif name == "season_ended":
            s["ended"] = True
        elif name == "season_awards_shown":
            s["awards"] = "lost" if d.get("lost") else "won"
    if "pre_final" in s and s["banks"]:
        s["banks"][max(s["banks"])] = s["pre_final"]
    return s


def schedule(M: "sim.Model", hc: int) -> dict:
    """Scheduled payment that a dawn's bank is measured against, by dawn number."""
    total = M.debt([], M.pay[hc], hc)
    first = M.first_of(total) if M.first_dawn else 0
    return {d: (first if M.first_dawn and d < M.first_dawn else total - first) for d in range(2, M.final_dawn + 1)}


def pct(bank: int, due: int) -> float:
    return 100.0 * bank / due if due else 0.0


def sim_side(hc: int, runs: int, seed: int, scn: dict) -> dict:
    data, layout = sim.load_data(), sim.load_json(sim.HERE / "layout.json")
    pol = sim.load_json(sim.HERE / "policies" / "median.json")
    M = sim.Model(data, layout, pol, scn)
    due = schedule(M, hc)
    per = {d: [] for d in due}
    first = final = 0
    for i in range(runs):
        r = sim.simulate(M, hc, random.Random(f"{seed}:{hc}:{i}"))
        for d in due:
            b = r["banks"].get(d)
            if d == M.final_dawn and r.get("margin8") is not None:
                b = r["margin8"] + r["owed8"]
            if b is not None:
                per[d].append(pct(b, due[d]))
        first += bool(r["first_clear"])
        final += bool(r["final_clear"])
    return {"due": due, "median": {d: statistics.median(v) for d, v in per.items() if v},
            "first_pct": round(100 * first / runs, 1) if M.first_dawn else "n/a", "final_pct": round(100 * final / runs, 1)}


def compare(seasons: list, runs: int, seed: int) -> int:
    """Print the table; return 0 when every dawn of every headcount is within GAP points and wins and losses both occur."""
    bad = 0
    by_hc: dict = {}
    for s in seasons:
        by_hc.setdefault((s["players"], s["difficulty"]), []).append(s)
    for (hc, diff), group in sorted(by_hc.items(), key=lambda k: (k[0][0] or 0, k[0][1])):
        if not hc:
            print(f"skip {[s['file'] for s in group]}: no dawn payment logged (season not full)")
            bad += 1
            continue
        scn = {"name": diff, "difficulty": "normal" if diff == "short_season" else diff, "short_season": diff == "short_season"}
        S = sim_side(hc, runs, seed, scn)
        print(f"== {hc}p {diff}: {len(group)} live season(s) vs {runs} sim runs (seed {seed}) ==")
        print(f"   sim first clear {S['first_pct']}{'%' if S['first_pct'] != 'n/a' else ''} final clear {S['final_pct']}%")
        for s in group:
            out = "won" if s["final"] and not s["lost"] else ("lost" if s["final"] is not None else "unfinished")
            print(f"   live {s['file']}: first {s['first']} final {s['final']} awards {s['awards']} -> {out}")
        print("   dawn  due   live%   sim%   gap")
        for d, due in S["due"].items():
            live = [pct(s["banks"][d], due) for s in group if d in s["banks"]]
            if not live or d not in S["median"]:
                print(f"   {d:>4} {due:>5}  (no data)")
                bad += 1
                continue
            lm, sm = statistics.median(live), S["median"][d]
            ok = abs(lm - sm) <= GAP
            bad += not ok
            print(f"   {d:>4} {due:>5} {lm:7.1f} {sm:6.1f} {lm - sm:+6.1f} {'ok' if ok else 'FAIL'}")
    won = sum(1 for s in seasons if s["final"] and not s["lost"])
    lost = sum(1 for s in seasons if s["final"] is False or s["lost"])
    done = sum(1 for s in seasons if s["final"] is not None)  # unfinished seasons do not count toward the 6
    mix = done >= 6 and won >= 1 and lost >= 1
    print(f"seasons {done} finished (need 6), wins {won}, losses {lost}: {'ok' if mix else 'FAIL (doc 09 s3: >= 6 seasons, >= 1 win and >= 1 loss)'}")
    bad += not mix
    print("PASS" if not bad else f"FAIL ({bad} check(s) out of range or missing)")
    return 0 if not bad else 1


def self_test() -> None:
    import tempfile
    lines = ['[log] session_start {"difficulty":"normal"}']
    for day in range(1, 8):
        lines.append('[log] dawn_summary {"day":%d,"coins":%d}' % (day, 100 * day))
    lines += ['[log] payment_made {"amount":223,"balance":77,"due":223,"final":false,"ok":true,"players":4}',
              '[log] payment_made {"amount":900,"balance":5,"due":900,"final":true,"ok":true,"players":4}',
              '{"event":"season_awards_shown","data":{"lost":false}}']
    with tempfile.TemporaryDirectory() as t:
        p = Path(t) / "s.log"
        p.write_bytes("\n".join(lines).encode())
        s = read_season(p)
    assert s["players"] == 4 and s["first"] and s["final"] and s["awards"] == "won", s
    assert s["banks"][2] == 100 and s["banks"][8] == 905, s["banks"]
    M = sim.Model(sim.load_data(), sim.load_json(sim.HERE / "layout.json"), sim.load_json(sim.HERE / "policies" / "median.json"), {"name": "t"})
    due = schedule(M, 4)
    assert due[2] == M.first_of(M.debt([], M.pay[4], 4)) and due[8] == M.debt([], M.pay[4], 4) - due[2], due
    print("self-test ok")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="sim.py compare", description=__doc__.split("\n")[0])
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--runs", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        self_test()
        return 0
    if not a.logs:
        ap.error("give host logs")
    return compare([read_season(Path(p)) for p in a.logs], a.runs, a.seed)


if __name__ == "__main__":
    sys.exit(main())
