"""Deterministic season projection behind doc 02 section 17 (a sanity check, not the simulator).

Run: uv run --no-project python -I tools/sim/projection.py
Numbers are copied from doc 01 here because data/ doesn't exist yet; the simulator reads data/.
Rules are listed in doc 02 section 17.2.
"""

PCT = {6: 140, 5: 120, 4: 100, 3: 80, 2: 60}  # 5 and 6: D-038 placeholder
FIELD = {2: 8, 3: 12, 4: 16, 5: 20, 6: 24}  # plots tended; 5p, 6p: D-039 placeholder (4 per player)
GROW = {"turnip": 1, "pumpkin": 2}
SEED = {"turnip": 4, "pumpkin": 10, "moonflower": 25}
SELL = {"turnip": 10, "pumpkin": 28, "moonflower": 60}


def scaled(value: int, players: int) -> int:
    return (value * PCT[players] + 99) // 100


def run(players: int, median: bool, pumpkins: bool = True) -> dict:
    """Days 1..7, each followed by its dawn (2..8). `pumpkins=False` keeps them locked (D-017)."""
    coins = 60
    field = FIELD[players]
    moon = players
    plots: list[tuple[str, int]] = []
    deaths = {2, 4, 6} if median else set()
    deferred = 0
    pumpkins_open = False
    ledger = {}
    for day in range(1, 8):
        # harvest and sell ripe field crops at the town stand
        coins += sum(SELL[c] for c, r in plots if r <= day)
        plots = [(c, r) for c, r in plots if r > day]
        # moonflowers first, from day 3
        if day >= 3:
            coins -= moon * SEED["moonflower"]
        # field: pumpkins days 4-5 if unlocked, else turnips; a plot that can't afford its
        # pumpkin gets a turnip
        for _ in range(field - len(plots)):
            crop = "pumpkin" if pumpkins_open and day in (4, 5) else "turnip"
            if coins < SEED[crop]:
                crop = "turnip"
            if coins < SEED[crop]:
                break
            coins -= SEED[crop]
            plots.append((crop, day + GROW[crop]))
        # dawn day+1
        dawn = day + 1
        picked = moon if day >= 3 else 0
        if day in deaths and picked:
            picked -= 1
        coins += picked * SELL["moonflower"]
        if dawn == 8:
            coins += sum(SELL[c] // 2 for c, _ in plots) + scaled(150, players)
        if day in deaths:
            bill = scaled(25, players)
            pay = min(bill, max(0, coins - 4))
            coins -= pay
            deferred += bill - pay
        if median and plots:
            plots.sort(key=lambda p: SEED[p[0]])
            plots.pop()
        if dawn == 4:
            due = scaled(255, players)
            if coins >= due:
                coins -= due
                pumpkins_open = pumpkins
            else:
                deferred += (3 * (due - max(0, coins - 4)) + 1) // 2  # Foreclosure: x1.5, up
                coins = min(coins, 4)
                pumpkins_open = False
        ledger[dawn] = coins
    final = scaled(1045, players) + deferred
    return {"ledger": ledger, "coins": coins, "owed": final, "margin": coins - final}


if __name__ == "__main__":
    for players in (6, 5, 4, 3, 2):
        for median in (False, True):
            r = run(players, median)
            name = "rough median" if median else "perfect"
            print(players, name, r)
        locked = run(players, True, pumpkins=False)
        print(players, "rough median, pumpkins never unlocked", locked)
