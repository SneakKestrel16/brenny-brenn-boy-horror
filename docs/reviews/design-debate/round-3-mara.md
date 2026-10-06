# Round 3: Mara (systems & economy)

## Votes

**ACCEPT as written:** A2, A4–A7, A9, A11, A12, B1–B7, B9–B13, C1–C3, C5–C11.

**ACCEPT, with notes:**
- **A1:** Theo's double-softening point is fair. A perfect start makes 322, and scheduled sabotage brings it to about 295–300. 255 leaves about 15%, and with A2 underneath that's the right sting.
- **A3:** state the scaled finals: **3p 836, 2p 627**.
- **A10:** early payments count against what's owed before any A9 rescale.
- **B8:** two bites at most keeps A3's "Large delivered" target reachable from a Giant.
- **C4:** a host-owned economy with no client-side sell calls is the line I asked for.

**OBJECT:** A8 (below).

### A8 objection

The doc puts the Prize Pumpkin "in its own patch **by the farmhouse**". The farmhouse is lit, and B7 says the creature never enters a lit building. A guard who stands 2 m from the pumpkin and 3 m from the lit door meets "outdoors within 20 m for 60 s" with no real risk: one step and they're safe. The guard requirement then costs only 60 seconds of standing around, and Giant goes back to being free money, which is the problem M8 was meant to fix.

**Replacement wording I'd accept:**
> **Scaling:** the payout scales with player count, the same way payments do.
> **Location:** the Prize Pumpkin patch sits **at least 30 m from any building's door**, in the open between the farmhouse and the first corn strip.
> **Giant:** needs watering every day **and** a guard. Someone must be outdoors within 20 m of the pumpkin for at least 60 s, on at least 2 of nights 1 to 6. Time spent inside the light radius of a lit doorway doesn't count.
> **Fertilizer:** cut.
> **Gnawing:** happens on any night nobody is within 20 m of the pumpkin.

This keeps Priya's social payoff (a friend alone in the dark by the pumpkin) and makes it actually cost something. It doesn't touch B8: the cart is loaded in the barn, and the pumpkin is moved there at dusk on night 7.

## Still missing

**M14. Minor: the medical bill doesn't scale with player count.** (Medical Bill, A5)
- **The numbers:** the bill (25/50, cap 120) is described as "10% of the debt", but it's a flat 4p number.
- **The effect:** at 2p the cap is 120 against a 627 final, about 19%. So a 2-player team is punished twice as hard per death.
- **Fix:** death costs and the nightly cap scale like the payments: 2p 15/30, cap 72; 3p 20/40, cap 96. Apply A9's rescale to them too.

**M15. Major: Phase 4's "done" test has no numbers.** (Build Plan, A1, A3, Open Issue 2)
- **The gap:** "Teams sometimes win and sometimes lose, and the numbers are close" can't be measured. A1 and A3 both lean on "a median simulated team", but nothing defines that team or the pass rates we're aiming for.
- **Fix:** Phase 4 is gated on the season simulator, run at 2p, 3p and 4p with A1–A12 applied.
- **The median team:**
  - plays greedily, with a 33% chore tax;
  - takes the scheduled sabotage plus the A1 trample rule;
  - takes 1 death on each of 3 nights;
  - delivers a Large pumpkin.
- **Targets:**

  | Measure | Target |
  |---|---|
  | Median team clears the first payment | about 85% of runs |
  | Median team clears the final payment | 55–70% of runs |
  | Spread across player counts | at most 10 points |

- **Playtest check:** live playtest logs must land within 15 points of the sim before the numbers are frozen.

Without this, "the simulator verifies it" in A1 and A3 is a promise, not a test.

VERDICT: DISAGREE — open points: A8, M14, M15
