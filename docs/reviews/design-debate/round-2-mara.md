# Round 2: Mara (systems & economy)

Theo and Priya convinced me on most points. I'm only pushing back where a fix changes the money or the incentives.

## Positions

| ID | Position | Reason / amended wording |
|---|---|---|
| M1 | KEEP | P11 adds a labor reason to the same conclusion. 22 coins of margin can't survive scheduled sabotage. |
| M2 | KEEP | |
| M3 | KEEP | See C1 for how it interacts with T7. |
| M4 | KEEP | |
| M5 | KEEP | |
| M6 | KEEP | My fix ("an unpicked moonflower at dawn is a Taint source") fits T1, because skipping the harvest is a player choice. |
| M7 | KEEP | |
| M8 | AMEND my own | "Giant also needs 2 bought fertilizers (30 each), **or** a player standing *outside and unlit* within 15 m of the pumpkin for 60 s on 2 nights." Watching from the lit farmhouse window must not count, or T6's rule makes guarding free. |
| M9 | AMEND, merged with P7 | See C2. |
| M10 | KEEP | |
| M11 | AMEND, concede part | P11 made me redo the labor sum. At 2p, 8 of 12 tendable plots already builds in a 33% chore tax, and 4p plants 16 of 24, also 33%. I withdraw "2p could reach 226". What remains: define labor in seconds, change the Farmer bonus, round trap counts up. |
| T1 | ACCEPT | Good for the economy too. A Taint caused by the Director made the day-death odds random, and I can't price randomness. |
| T2 | ACCEPT | |
| T3 | ACCEPT | Knowledge separation is the anti-cheat rule for the Director. |
| T4 | ACCEPT | Crouch-walk is a noise-versus-speed trade, which fits the economy. Its slowdown counts against the 33% chore tax. |
| T5 | AMEND | "First third calm (sabotage evidence only), middle low presence, last third builds to dusk. At most 1 big scare per player per day. Within 10 m of the town stand there are no lures, scares or kills, but **the day clock keeps running and nothing grows there**." Otherwise the sanctuary turns into day-long camping. |
| T6 | ACCEPT | Add M12. |
| T7 | AMEND | "Each stall lets the creature take one bite (one size down), **at most 2 bites per escort**." With uncapped bites the payout is a coin flip, and M3 makes that money load-bearing (C1). |
| T8 | ACCEPT | |
| T9 | ACCEPT | |
| T10 | ACCEPT | A whistle without the marker can't be spammed for free information, which closes Open Issue 3. |
| T11 | ACCEPT | |
| P1 | ACCEPT | Not my lane, but the argument is right. The fallback voices make a hard gate unnecessary. |
| P2 | ACCEPT | |
| P3 | ACCEPT | |
| P4 | ACCEPT | Add: the coin balance, sales and payments are host-only, with **no client-side sell calls**. |
| P5 | ACCEPT | |
| P6 | AMEND | "Phase 1 includes turnips, a noisy watering can and one generator run, **and logs every plant, water and harvest hold time**." That gives me the seconds-based labor model M11 needs before Phase 4. |
| P7 | AMEND | Joining as a ghost and portable saves: accept. "Payments only rescale upward": reject. A friend whose internet dies shouldn't doom the others. See C2. |
| P8 | ACCEPT | |
| P9 | ACCEPT | It suits the economy: the ramp table already doles out a new verb each day. |
| P10 | ACCEPT | |
| P11 | AMEND | The chore tax is already in the plot counts (16 of 24, and 8 of 12). The real hole is **sabotage losses**, not labor. Run the sim with the Ramp-Up disturbances applied, plus 1 trampled plot per night (2 on unattended nights). |

## Conflicts

**C1. T7's bites vs M3's heavier final payment.**
- **The clash:** M3 makes the median team need a Large pumpkin. Under T7 the creature can bite it during the escort. Stack those and the season is decided by finale dice.
- **Fix:**
  - Cap bites at 2 (T7 amended).
  - The sim's target team arrives with a Giant, takes 1 bite and delivers a Large, so a median team has one bite of slack.
  - The final payment is checked against "Large delivered".
  - M8's fertilizer and guarding become the way to buy slack. That puts decisions back into the season.

**C2. Joining and leaving: M9 (pro-rata) vs P7 (upward only).**
- **The clash:** "upward only" stops someone quitting to cut the payment, but it punishes real disconnects. A 4p season that loses 2 players keeps the 4p payment with half the labor, half the moonflower bed and an NPC idler.
- **Fix:**
  - Any change in headcount takes effect at the **next dawn**.
  - From then, the amount still owed rescales pro rata over the days left.
  - The moonflower bed shrinks or grows with it.
  - Quitting just before a payment saves nothing, because that payment is already locked.
- **Why it's fair:** the 60%/80% scaling is meant to track labor, and a missing player is missing labor. A quitter gives up as much farming as they save.

**C3. T5's calm third and T1 vs the sabotage in the economy.**
- **The clash:** both remove daytime losses that the original economy implicitly assumed.
- **Fix:** keep sabotage evidence and trampling, since they're economic rather than scary. Calibrate M1's headroom on sabotage, not on scares. No change to my numbers.

**C4. T6's generator attacks vs the night economy.**
- **The clash:** if the generator becomes the target, repairing and refueling it becomes a cost the economy hasn't priced.
- **Fix:** see M12.

**C5. P1's Off tier vs the Dawn Report.**
- **The clash:** none on the economy side.
- **Note:** awards like "Best Impression" use the fallback voice for players on Off.

## New issues

**M12. Minor: generator fuel and repair aren't priced.** (Nights, T6)
The fuel drum looks infinite and free, and after T6 the creature damages the generator.
**Fix:**
- The drum is free and infinite, so the risk is the walk to it, not coins.
- Repairing creature damage needs 1 scrap. One scrap is salvaged free each dawn; extra scrap costs 15 at the store.
- A generator left dead at dawn costs 1 trampled plot more.
This prices the cost in labor and risk rather than coins, so it doesn't stack with the medical bill.

**M13. Minor: day deaths now cost almost nothing to avoid.** (Day Deaths, T1, T2)
After T1 and T2, the only day kills are a Taint you chose, or failing a telegraphed trap race. That's good. But the medical bill (25/50) is now the only cost of a day death, and early in the season it's often zero because of the M5 floor.
**Fix:** M5's deferral rule covers it, so no new numbers. Just confirm that day deaths go through the same bill.

VERDICT: DISAGREE — open points: M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, M13, T5, T7, P6, P7, P11
