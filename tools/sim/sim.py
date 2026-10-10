"""Season simulator (doc 02 section 18). Python 3.13, stdlib only.

Run: uv run --no-project python -I tools/sim/sim.py --players 2,3,4,5,6 --runs 10000 --seed 1
Reads data/*.json (the same files the game reads) and copies no number into code. Not spatial:
distances come from tools/sim/layout.json (doc 04). Rules and every placeholder are in doc 02 18.
One step per phase per day: harvest/sell, buy, plant, night, dawn (cash-in, bill, payment, damage).
"""

import argparse
import csv
import json
import math
import random
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def scaled(value: int, pct: int) -> int:
    """Headcount scaling, always rounded up (doc 02 section 4)."""
    return (value * pct + 99) // 100


def rhu(num: int, den: int) -> int:
    """Round half up, integer only (the debt rounds to nearest, doc 02 section 7.2)."""
    return (2 * num + den) // (2 * den)


def load_data(root: Path = ROOT / "data") -> dict:
    data = {}
    for f in sorted(root.glob("*.json")):
        if f.name.endswith(".schema.json"):
            continue
        t = json.loads(f.read_text(encoding="utf-8"))
        if "table" in t:
            data[t["table"]] = {r["id"]: r for r in t["records"]}
    return data


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class Model:
    """Everything the season reads, taken from data/ plus one scenario."""

    def __init__(self, data: dict, layout: dict, pol: dict, scn: dict):
        self.pol, self.layout = pol, layout
        self.S = {k: v["value"] for k, v in data["season"].items()}
        hc = data["player_scaling"]["headcount"]
        scn = dict(scn)
        if scn.get("short_season"):  # doc 02 section 16: the short-season record in difficulty.json plus pumpkin.json short_season
            ss = data["difficulty"]["short_season"]
            scn.setdefault("season_days", ss["season_days"])
            scn.setdefault("no_first_payment", ss["no_first_payment"])
            scn.setdefault("debt_total_4p", ss["debt_total_4p"])
            scn.setdefault("debt_total_4p_by_players", ss.get("debt_total_4p_by_players", {}))
            scn.setdefault("crops_override", {"pumpkin": {"grow_days": data["pumpkin"]["short_season"]["grow_days"]}})
        self.scn = scn
        self.pct = {int(k): v for k, v in hc["pct_by_players"].items()}
        # debt, payments and medical bills may scale differently from traps and payouts (D-078 item 2)
        self.pay = {int(k): v for k, v in hc.get("payment_pct_by_players", hc["pct_by_players"]).items()}
        self.start_plots = {int(k): v for k, v in hc["field_plots_start_by_players"].items()}
        self.max_plots = {int(k): v for k, v in hc["field_plots_max_by_players"].items()}
        self.sell_bonus = {int(k): v for k, v in hc.get("sell_bonus_pct_by_players", {}).items()}  # P4-30, D-106
        self.min_players, self.max_players = hc["min_players"], hc["max_players"]
        self.crops = {k: dict(v) for k, v in data["crops"].items()}
        for k, v in scn.get("crops_override", {}).items():
            self.crops[k].update(v)
        self.diff = data["difficulty"][scn.get("difficulty", "normal")]
        self.days = scn.get("season_days", self.S["season_days"])
        self.final_dawn = self.days + 1
        self.first_dawn = None if scn.get("no_first_payment") else self.S["first_payment_dawn"]
        debt = data["debt"]["season"]
        self.total_4p = debt["total_4p"]
        self.debt_base = scn.get("debt_total_4p", self.total_4p)
        self.first_base = debt["first_payment_4p"]
        # DD Phase 5 (doc 02 section 21): seasons 2 and 3 read their debt from next_season.json, traits from creature_traits.json
        self.season = scn.get("season", 1)
        self.traits = data.get("creature_traits", {})
        self.next = data.get("next_season", {})
        if self.season > 1:
            ns = self.next[f"season_{self.season}"]
            self.total_4p, self.first_base = ns["debt_total_4p"], ns["first_payment_4p"]
            self.debt_base = scn.get("debt_total_4p", self.total_4p)
            scn.setdefault("debt_total_4p_by_players", ns.get("debt_total_4p_by_players", {}))
        # DD Phase 5 (doc 02 section 22.5): one imposter costs the team labor, the imposter's own share plus the cost of each lie it tells
        imp = data.get("imposter", {})
        self.imp_loss_s, self.imp_min = 0.0, 0
        if scn.get("imposter") and imp:
            kit = [r for r in imp.values() if "team_cost_s" in r]
            self.imp_min = imp["rule"]["min_players"]
            self.imp_loss_s = ((100 - imp["sim"]["work_share_pct"]) * self.S["day_s"] / 100
                               + imp["sim"]["lies_per_day"] * sum(r["team_cost_s"] for r in kit) / len(kit))
        self.unlock_rule = scn.get("unlock_rule") or self.crops["pumpkin"]["unlock_rule"]
        self.bill = data["medical_bill"]["bill"]
        self.pumpkin = data["pumpkin"]
        self.size = scn.get("pumpkin_size") or pol["pumpkin_size"]
        self.L = {k: v for k, v in data["labor"].items()}
        self.walk_v = self.L["walk"]["speed_mps"]
        self.can = self.L["can"]["capacity"]
        self.carry = self.L["carry"]["capacity"]
        self.ramp = data["ramp_up"]
        self.bells_on = data["traps"]["tripwire_bells"].get("enabled", True)
        self.traps = data["traps"]
        self.pair_price = data["store"]["plot_pair"]["price"]
        self.pair_plots = data["store"]["plot_pair"]["effect"]["plots"]
        self.pool = [r for r in data["sabotage"].values() if r["enabled"] and r["budget"]]
        self.end_pct = self.S["end_season_sale_pct"]
        # Q-161: a nobody-outside night is a whole night hidden, so the game's "unattended farm" term is full (doc 03 s10).
        # Policy switch: on, every headcount fails s18.3 (doc 02 s18.6 P4-30 log)
        tr = data["sabotage"]["trample"]
        self.unattended = min(int((self.S["night_s"] - tr["nobody_outside_s"]) // tr["unattended_every_s"]), tr["unattended_cap"]) if pol.get("unattended_term") else 0
        # doc 02 section 10.2: a broken fence frees animals; each is herded back with round_up, or costs coins if still out at dusk
        self.animals = self.S["animals_per_fence_break"]
        self.animal_cost = self.S["animal_out_at_dusk_coins"]
        self.allowed = pol["crops"] or [k for k in self.crops if k != "moonflower"]
        self.t_plot = self._t_plot()
        self.P = self.t_plot[1]
        self.per_player = pol["plots_per_player"]
        if self.per_player == "derived":
            self.per_player = math.ceil((100 - self.S["chore_share_pct"]) / 100 * self.P)
        self._vt = {}

    def pct_of(self, hc: int) -> int:
        return self.pct[hc]

    def sold(self, v: int, hc: int) -> int:
        """A sale's coins plus the headcount sell bonus, rounded up (doc 02 section 4, D-106). The game rounds per sale."""
        return v + scaled(v, self.sell_bonus.get(hc, 0))

    def _t_plot(self) -> tuple[float, float]:
        """Doc 02 section 2.3: seconds per plot per day, blended over the fields, and P = day_s / t."""
        L, v = self.L, self.walk_v
        lay = self.layout
        base = L["harvest"]["hold_s"] + L["plant"]["hold_s"] + L["water"]["hold_s"] + lay["d_step_m"] / v
        t = 0.0
        for f in lay["fields"].values():
            trade = sum(f["trade_loop_m"])
            t += f["share"] * (
                base
                + (L["fill_can"]["hold_s"] + 2 * f["d_well_m"] / v) / self.can
                + (trade / v + L["sell"]["hold_s"] + L["buy"]["hold_s"]) / self.carry
            )
        return t, self.S["day_s"] / t

    def ramp_counts(self, day: int, hc: int, traits: tuple = ()) -> tuple[int, int, int, int]:
        """(disturbances, bear, pit, bells) for a day, scaled for the headcount (doc 02 section 11).
        A season trait's ramp_up `add` overrides raise the 4p base before scaling (doc 03 section 22)."""
        r, p = self.ramp[f"day_{day}"], self.pct[hc]
        add = dict.fromkeys(("disturbances_4p", "bear_4p", "pit_4p", "bells_4p"), 0)
        for t in traits:
            for o in self.traits[t]["overrides"]:
                if o["table"] == "ramp_up" and o["days"][0] <= day <= o["days"][1]:
                    add[o["field"]] += o["value"]
        return tuple(scaled((r[k] or 0) + add[k], p) for k in ("disturbances_4p", "bear_4p", "pit_4p", "bells_4p"))

    def medical(self, hc: int, deaths: int) -> int:
        b, p = self.bill, self.pay[hc]
        raw = scaled(b["first_4p"], p) + max(0, deaths - 1) * scaled(b["later_4p"], p)
        return min(raw, scaled(b["cap_4p"], p))

    def payout(self, size: str, hc: int) -> int:
        return scaled(self.pumpkin[size]["payout_4p"], self.pct[hc])

    def debt(self, pcts: list[int], cur: int, hc: int = 0) -> int:
        """Total debt: past days at their recorded pct, the rest at the current headcount. `hc` picks a per-headcount base (short season, D-082 item 5)."""
        s = sum(pcts) + (self.days - len(pcts)) * cur
        base = self.scn.get("debt_total_4p_by_players", {}).get(str(hc), self.debt_base)
        return rhu(base * s, self.days * 100)

    def first_of(self, total: int, hc: int = 0) -> int:
        # season 2 and 3 (doc 02 section 21.4): the denominator is the headcount's own base, so the first payment keeps its 4p-scale share
        den = self.scn.get("debt_total_4p_by_players", {}).get(str(hc), self.total_4p) if self.season > 1 else self.total_4p
        return rhu(self.first_base * total, den)

    def turnip_value(self, d: int) -> int:
        """What a plot bought on day d returns planting turnips only (no pumpkin cash or labor assumed); the buy test uses this."""
        c = self.crops["turnip"]
        if d + c["grow_days"] > self.days:
            return c["sell"] * self.end_pct // 100 - c["seed"]
        return c["sell"] - c["seed"] + self.turnip_value(d + c["grow_days"])

    def values(self, pumpkin_open: bool) -> list:
        """DP over days: best (value, crop) for a plot planted on day d. The end sale pays 50%."""
        key = pumpkin_open
        if key in self._vt:
            return self._vt[key]
        V = [0] * (self.days + 3)
        best = [None] * (self.days + 3)
        for d in range(self.days, 0, -1):
            top = (0, None)
            for c in self.allowed:
                cr = self.crops[c]
                if d < cr["unlock_day"] or (c == "pumpkin" and not pumpkin_open):
                    continue
                ripe = d + cr["grow_days"]
                val = cr["sell"] - cr["seed"] + V[ripe] if ripe <= self.days else cr["sell"] * self.end_pct // 100 - cr["seed"]
                if val > top[0]:
                    top = (val, c)
            V[d], best[d] = top
        self._vt[key] = (V, best)
        return self._vt[key]


def simulate(M: Model, players: int, rng: random.Random, carry: dict | None = None, traits: tuple = ()) -> dict:
    """One season. `carry` ({"owned", "savings"}) and `traits` are the Phase 5 inputs (doc 02 section 21)."""
    S, pol = M.S, M.pol
    jitter = pol["jitter_pct"] / 100
    jit = (lambda: 1 + rng.uniform(-jitter, jitter)) if jitter else (lambda: 1.0)
    hc = players
    coins = S["start_coins"] + (carry["savings"] if carry else 0)
    owned = M.start_plots[hc]
    if carry:  # plots carry, clamped to the headcount ceiling (doc 02 section 21.2)
        owned = min(max(owned, carry["owned"]), M.max_plots[hc])
    owned_start = owned
    ground: list[list] = []
    pcts: list[int] = []
    paid = penalty = deferred = 0
    first_due = None
    first_paid = False
    foreclosed = False
    nights = list(range(1, M.days + 1))
    dead_nights = set()
    for _ in range(min(pol["deaths"], M.days)):
        # death_night_weight 0: any night equally; else night weight = disturbances ** weight (the creature ramps up, doc 01 Ramp-up)
        w = [M.ramp[f"day_{n}"]["disturbances_4p"] ** pol.get("death_night_weight", 0) for n in nights]
        n = rng.choices(nights, weights=w)[0] if sum(w) else rng.choice(nights)
        nights.remove(n)
        dead_nights.add(n)
    moon = M.crops["moonflower"]
    changes = {c["dawn"]: c["delta"] for c in M.scn.get("headcount_changes", [])}
    moon_n, kill_pending, died, animal_debt = 0, False, 0, 0
    banks, r = {}, {"bank_pre4": None, "margin4": None, "margin8": None}
    for d in range(1, M.final_dawn + 1):
        # ---- dawn d (d = 1 is the start) ----
        if d > 1:
            n = d - 1
            if d in changes and M.min_players <= hc + changes[d] <= M.max_players:
                hc += changes[d]
            if d <= M.days:
                pcts.append(M.pay[hc])
            # 1. cash-in: the dead lose what they carried
            cash = moon_n * moon["sell"]
            if n in dead_nights:
                if moon_n:
                    cash -= moon["sell"]
                carried = rng.randint(0, M.carry) * M.crops["turnip"]["sell"]
                cash = max(0, cash - carried)
            coins += M.sold(cash, hc)
            # 2. final dawn: the ground sells at 50%, then the festival payout
            if d == M.final_dawn:
                coins += M.sold(sum(M.crops[c]["sell"] * M.end_pct // 100 for c, _ in ground), hc) + M.payout(M.size, hc)
            # 3. medical bill, never below the floor; the rest goes to the final
            if n in dead_nights:
                died += 1  # first_4p, then later_4p each, up to the cap (doc 02 section 8)
                bill = M.medical(hc, died) - (M.medical(hc, died - 1) if died > 1 else 0)
                bill = (bill * M.diff["bill_pct"] + 99) // 100
                pay = min(bill, max(0, coins - S["bank_floor"]))
                coins -= pay
                deferred += bill - pay
            # 3b. animals still out at dusk cost coins, never below the floor (placeholder, doc 02 section 10.2)
            lost = min(animal_debt, max(0, coins - S["bank_floor"]))
            coins -= lost
            animal_debt = 0
            # 4. payment
            total = M.debt(pcts, M.pay[hc], hc)
            if d == M.first_dawn:
                first_due = M.first_of(total, hc)
                r["bank_pre4"] = coins
                r["margin4"] = coins - first_due
                if coins >= first_due:
                    coins -= first_due
                    paid += first_due
                    first_paid = True
                else:
                    part = max(0, coins - S["bank_floor"])
                    coins -= part
                    paid += part
                    penalty += (S["foreclosure_penalty_pct"] * (first_due - part) + 99) // 100
                    foreclosed = True
                    owned -= S["foreclosure_seized_plots"]
                    ground = ground[: max(0, owned)]
            if d == M.final_dawn:
                owed = total - paid + penalty + deferred
                r["margin8"] = coins - owed
                r["owed8"] = owed
            banks[d] = coins
            # 5. farm damage (trample), not at the final dawn
            if d <= M.days:
                k = S["trample_base"]
                if rng.random() * 100 < pol["nobody_outside_pct"]:
                    k = S["trample_nobody_outside"] + M.unattended
                p_dead = min(100, pol["generator_dead_base_pct"] + pol["generator_dead_tank_factor_pct"] * (100 - M.diff["generator_tank_pct"]) / 100)
                if rng.random() * 100 < p_dead or (kill_pending and rng.random() * 100 < pol["generator_kill_unfixed_pct"]):
                    k += S["trample_dead_generator"]
                if not pol["trample"]:
                    k = 0
                for i in sorted(rng.sample(range(len(ground)), min(k, len(ground))), reverse=True):
                    ground.pop(i)
        if d > M.days:
            break
        # ---- day d ----
        coins += M.sold(sum(M.crops[c]["sell"] for c, ripe in ground if ripe <= d), hc)
        ground = [g for g in ground if g[1] > d]
        pumpkin_open = (d >= M.crops["pumpkin"]["unlock_day"]) and (M.unlock_rule == "day" or first_paid)
        moon_n = 0
        if d >= moon["unlock_day"] and hc:
            moon_n = min(hc, coins // moon["seed"])
            coins -= moon_n * moon["seed"]
        # chores: last night's traps, today's sabotage
        chore_s = 0.0
        kill_pending = False
        if pol["labor"]:
            walks = M.layout["trap_walk_m"]
            if d > 1:
                _, bear, pit, bells = M.ramp_counts(d - 1, hc, traits)
                tp = (M.diff["trap_pct"])
                for verb, cnt, en in (("bear_trap", bear, True), ("pit", pit, True), ("tripwire_bells", bells, M.bells_on)):
                    if en and M.traps[verb].get("enabled", True):
                        cnt = (cnt * tp + 99) // 100
                        hold = M.L[M.traps[verb]["clear_verb"]]["hold_s"]
                        chore_s += sum(hold + 2 * rng.choice(walks) / M.walk_v for _ in range(cnt))
        if pol["sabotage"]:
            nd = M.ramp_counts(d, hc, traits)[0]
            pool = [s for s in M.pool if s["opens_day"] <= d]
            for _ in range(nd):
                s = rng.choice(pool)
                if s["id"] == "generator_kill":
                    kill_pending = True
                hold = s["fix_hold_s"] if s["fix_hold_s"] is not None else M.L.get(s["fix"], {}).get("hold_s", 0)
                if s["fix"] not in ("plant", "none"):
                    chore_s += hold + 2 * rng.choice(M.layout["trap_walk_m"]) / M.walk_v
                if s["id"] == "pumpkin_gnaw" and pol.get("charge_gnaw_guard"):  # doc 03 s10.1: no fix; the pumpkin is guarded for guard_s, one walk out and back
                    chore_s += M.pumpkin["rules"]["guard_s"] + 2 * M.layout["walk_m"]["barn_door_to_prize_pumpkin"] / M.walk_v
                if s["id"] == "broken_fence":
                    chore_s += M.animals * M.L["round_up"]["hold_s"] + 2 * rng.choice(M.layout["trap_walk_m"]) / M.walk_v  # one herding trip, a hold per animal
                    if rng.random() * 100 < pol.get("animal_out_dusk_pct", 0):
                        animal_debt += M.animals * scaled(M.animal_cost, M.pay[hc])
        free = owned - len(ground)
        cap = hc * M.per_player
        if pol["labor"]:
            j = jit()
            fixed = chore_s * j
            if M.imp_loss_s and hc >= M.imp_min:
                fixed += M.imp_loss_s * j
            fixed += moon_n * (M.L["plant"]["hold_s"] + M.L["water"]["hold_s"] + (M.L["fill_can"]["hold_s"] + 2 * M.layout["moonflower_bed"]["d_well_m"] / M.walk_v) / M.can) * j
            fixed += (M.L["water_prize_pumpkin"]["hold_s"] + (M.L["fill_can"]["hold_s"] + 2 * M.layout["prize_pumpkin"]["d_well_m"] / M.walk_v) / M.can) * j
            cap = min(cap, int(max(0.0, hc * S["day_s"] - fixed) / (M.t_plot[0] * j)))
        V, best = M.values(pumpkin_open)
        if pol["buy_plots"] and best[d] and d >= pol["buy_plots_from_day"]:
            # a plot pair when the planting cap outgrows what we own and the pair pays back
            while (owned < cap and owned + M.pair_plots <= M.max_plots[players]
                   and 2 * M.turnip_value(d) > M.pair_price
                   and coins - M.pair_price >= min(free + M.pair_plots, cap) * M.crops["turnip"]["seed"]):
                coins -= M.pair_price
                owned += M.pair_plots
                free += M.pair_plots
        n = max(0, min(free, cap))
        if best[d] and n:
            b = best[d]
            sb, st = M.crops[b]["seed"], M.crops["turnip"]["seed"]
            if "turnip" not in M.allowed:
                st = sb
            if coins < n * st:
                n, k = coins // st, 0
            else:
                k = n if sb <= st else min(n, (coins - n * st) // (sb - st))
            coins -= k * sb + (n - k) * st
            ground += [[b, d + M.crops[b]["grow_days"]]] * k + [["turnip", d + M.crops["turnip"]["grow_days"]]] * (n - k)
    r.update(
        first_clear=first_paid if M.first_dawn else None,
        final_clear=r["margin8"] is not None and r["margin8"] >= 0,
        foreclosed=foreclosed,
        banks=banks,
        deaths=sorted(dead_nights),
        owned_start=owned_start,
        owned_end=owned,
        spare=max(0, r["margin8"]) if r["margin8"] is not None else 0,
    )
    return r


def quart(xs: list) -> list:
    return [round(v, 1) for v in statistics.quantiles(xs, n=4, method="inclusive")]


def run_scenario(data, layout, pol, scn, counts, runs, seed):
    out, rows = {}, []
    for p in counts:
        if scn.get("headcount_changes") and not any(M_ok(data, p, c) for c in scn["headcount_changes"]):
            continue
        M = Model(data, layout, pol, scn)
        res = []
        for i in range(runs):
            r = simulate(M, p, random.Random(f"{seed}:{p}:{i}"))
            res.append(r)
            rows.append([scn["name"], p, i, r["first_clear"], r["final_clear"], r["foreclosed"], r["margin4"], r["margin8"], " ".join(map(str, r["deaths"]))] + [r["banks"].get(d) for d in range(2, 9)])
        pct = lambda f: round(100 * sum(1 for r in res if f(r)) / runs, 1)
        m4 = [r["margin4"] for r in res if r["margin4"] is not None]
        m8 = [r["margin8"] for r in res if r["margin8"] is not None]
        bank = {d: statistics.median(r["banks"][d] for r in res if d in r["banks"]) for d in range(2, M.final_dawn + 1)}
        out[p] = {
            "first_clear_pct": pct(lambda r: r["first_clear"]) if M.first_dawn else None,
            "final_clear_pct": pct(lambda r: r["final_clear"]),
            "win_pct": pct(lambda r: r["final_clear"]),
            "foreclosure_pct": pct(lambda r: r["foreclosed"]),
            "margin_dawn4_quartiles": quart(m4) if m4 else None,
            "margin_dawn8_quartiles": quart(m8),
            "median_bank_by_dawn": bank,
            "plots_per_player": M.per_player,
        }
    return out, rows


def run_campaign(data, layout, pol, counts, runs, seed, seasons):
    """DD Phase 5 (doc 02 section 21.6): chain seasons 1..`seasons`. Only a won season carries; each later season
    gains one random trait (host seed), starts with the carried plots and 25% of the spare coins as savings.
    Rates are of the teams that reached the season. Returns {players: [per-season dict]}."""
    carry_rule = data["next_season"]["carry"]
    models = [Model(data, layout, pol, {"name": f"season_{s}", "season": s}) for s in range(1, seasons + 1)]
    pool = sorted(data["creature_traits"])
    out = {}
    for p in counts:
        rows = [[] for _ in models]
        for i in range(runs):
            carry, picked = None, []
            trng = random.Random(f"{seed}:{p}:{i}:trait")
            for s, M in enumerate(models):
                if s:
                    picked.append(trng.choice([t for t in pool if t not in picked]))
                rng = random.Random(f"{seed}:{p}:{i}" + (f":{s}" if s else ""))
                r = simulate(M, p, rng, carry, tuple(picked))
                rows[s].append((r, tuple(picked)))
                if not r["final_clear"]:
                    break
                carry = {"owned": r["owned_end"], "savings": min(carry_rule["savings_cap_coins"], r["spare"] * carry_rule["savings_pct"] // 100)}
        out[p] = []
        for s, rs in enumerate(rows):
            n = len(rs)
            pct = lambda f: round(100 * sum(1 for r, _ in rs if f(r)) / n, 1)
            wins = [r for r, _ in rs if r["final_clear"]]
            out[p].append({
                "season": s + 1,
                "reached_pct": round(100 * n / runs, 1),
                "first_clear_pct": pct(lambda r: r["first_clear"]),
                "final_clear_pct": pct(lambda r: r["final_clear"]),
                "foreclosure_pct": pct(lambda r: r["foreclosed"]),
                "owned_start_median": statistics.median(r["owned_start"] for r, _ in rs),
                "spare_median": statistics.median(r["spare"] for r in wins) if wins else None,
                "spare_quartiles": quart([r["spare"] for r in wins]) if len(wins) > 1 else None,
                "campaign_win_pct": round(100 * len(wins) / runs, 1),
                "by_trait_final_clear_pct": {t: round(100 * sum(1 for r, tr in rs if t in tr and r["final_clear"]) / c, 1)
                                             for t in pool if (c := sum(1 for _, tr in rs if t in tr))} if s else {},
            })
    return out


def evaluate_campaign(camp: dict, data: dict) -> list:
    """The later-season targets in next_season.json (doc 02 section 21.6). Returns (name, value, ok)."""
    t = []
    for s in sorted(k for k in data["next_season"] if k.startswith("season_")):
        n = int(s.split("_")[1])
        tg = data["next_season"][s]["targets"]
        for key in ("first_clear_pct", "final_clear_pct"):
            lo, hi = tg[key]
            vs = []
            for p, rows in camp.items():
                if len(rows) >= n:
                    v = rows[n - 1][key]
                    vs.append(v)
                    t.append((f"season {n} {key.split('_')[0]} clear {p}p in {lo}-{hi}%", v, lo <= v <= hi))
            if vs:
                t.append((f"season {n} spread {key.split('_')[0]} clear <= {tg['spread_pts']} points", round(max(vs) - min(vs), 1), max(vs) - min(vs) <= tg["spread_pts"]))
    return t


def M_ok(data, p, change):
    hc = data["player_scaling"]["headcount"]
    return hc["min_players"] <= p + change["delta"] <= hc["max_players"]


def evaluate(summary: dict, counts: list) -> list:
    """The s18.3 targets. Returns (name, value, ok)."""
    t = []
    base = summary["scenarios"].get("baseline")
    if not base:
        return t
    for p in counts:
        v = base[p]["first_clear_pct"]
        t.append((f"first clear {p}p in 80-90%", v, 80 <= v <= 90))
    for p in counts:
        v = base[p]["final_clear_pct"]
        t.append((f"final clear {p}p in 55-70%", v, 55 <= v <= 70))
    for key, name in (("first_clear_pct", "first"), ("final_clear_pct", "final")):
        vs = [base[p][key] for p in counts]
        t.append((f"spread {name} clear <= 10 points", round(max(vs) - min(vs), 1), max(vs) - min(vs) <= 10))
    med = summary["scenarios"].get("medium_pumpkin")
    if med:
        for p in counts:
            drop = round(base[p]["final_clear_pct"] - med[p]["final_clear_pct"], 1)
            t.append((f"Large needed {p}p: Medium drops final clear >= 30 points", drop, drop >= 30))
    imp = summary["scenarios"].get("imposter")
    if imp:  # doc 02 section 22.5: with an imposter aboard the team still clears the final in at least 50% of runs (labor cost only)
        for p in counts:
            if p >= 4:
                v = imp[p]["final_clear_pct"]
                t.append((f"imposter aboard: final clear {p}p >= 50%", v, v >= 50))
    return t


def resolve_scenarios(arg: str) -> list:
    d = HERE / "scenarios"
    names = ["baseline", "unlock_day", "medium_pumpkin"] if arg is None else (sorted(p.stem for p in d.glob("*.json")) if arg == "all" else arg.split(","))
    out = []
    for n in names:
        f = Path(n) if n.endswith(".json") else d / f"{n}.json"
        out.append(load_json(f))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--players", default="2,3,4,5,6")
    ap.add_argument("--runs", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--policy", default="median")
    ap.add_argument("--scenario", default=None, help="comma list of names/files, or 'all'")
    ap.add_argument("--out", default=str(HERE / "out"))
    ap.add_argument("--seasons", type=int, default=1, help="2 or 3: run the DD Phase 5 campaign instead of the scenarios (doc 02 section 21.6)")
    a = ap.parse_args(argv)
    counts = [int(x) for x in a.players.split(",")]
    data, layout = load_data(), load_json(HERE / "layout.json")
    pol = load_json(HERE / "policies" / f"{a.policy}.json")
    if a.seasons > 1:
        camp = run_campaign(data, layout, pol, counts, a.runs, a.seed, a.seasons)
        targets = evaluate_campaign(camp, data)
        out = Path(a.out) / str(a.seed)
        out.mkdir(parents=True, exist_ok=True)
        (out / "campaign.json").write_bytes((json.dumps({"seed": a.seed, "runs": a.runs, "policy": a.policy, "campaign": camp,
                                                         "targets": [{"name": n, "value": v, "pass": ok} for n, v, ok in targets]}, indent=2) + "\n").encode())
        for p, rows in camp.items():
            for r in rows:
                print(f"{p}p season {r['season']} reached {r['reached_pct']}% first {r['first_clear_pct']}% final {r['final_clear_pct']}% "
                      f"foreclosure {r['foreclosure_pct']}% plots {r['owned_start_median']} spare {r['spare_quartiles']}")
            print(f"{p}p campaign win {rows[-1]['campaign_win_pct']}%")
        for n, v, ok in targets:
            print(f"{'PASS' if ok else 'FAIL'}  {n}: {v}")
        return 1 if any(not ok for _, _, ok in targets) else 0
    summary = {"seed": a.seed, "runs": a.runs, "policy": a.policy, "scenarios": {}}
    rows = []
    for scn in resolve_scenarios(a.scenario):
        res, r = run_scenario(data, layout, pol, scn, counts, a.runs, a.seed)
        summary["scenarios"][scn["name"]] = res
        rows += r
    targets = evaluate(summary, counts)
    summary["targets"] = [{"name": n, "value": v, "pass": ok} for n, v, ok in targets]
    out = Path(a.out) / str(a.seed)
    out.mkdir(parents=True, exist_ok=True)
    (out / "summary.json").write_bytes((json.dumps(summary, indent=2) + "\n").encode())
    with open(out / "runs.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["scenario", "players", "run", "first_clear", "final_clear", "foreclosed", "margin4", "margin8", "death_nights"] + [f"bank_dawn{d}" for d in range(2, 9)])
        w.writerows(rows)
    for sc, res in summary["scenarios"].items():
        for p, v in res.items():
            print(f"{sc:15s} {p}p first {v['first_clear_pct']}% final {v['final_clear_pct']}% foreclosure {v['foreclosure_pct']}% "
                  f"margin4 {v['margin_dawn4_quartiles']} margin8 {v['margin_dawn8_quartiles']} (plots/player {v['plots_per_player']})")
    for n, v, ok in targets:
        print(f"{'PASS' if ok else 'FAIL'}  {n}: {v}")
    return 1 if any(not ok for _, _, ok in targets) else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "compare":
        sys.path.insert(0, str(HERE))  # -I drops the script folder from the path
        import compare  # doc 02 18.5

        sys.exit(compare.main(sys.argv[2:]))
    sys.exit(main())
