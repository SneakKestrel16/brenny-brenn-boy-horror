# Round 1: Mara (systems & economy)

I checked every number in Season and Numbers by hand and with a greedy season sim (start 60; turnips, pumpkins and moonflowers bought in profit order; moonflowers sold at the same dawn).

## Strong features

- **Traps as tomorrow's chores (Night Traps, Tool Shed).** The night creates the next day's work, so the two halves of the loop feed each other. The pegboard makes that state readable at a glance.
- **Plots, not seeds, are the bottleneck (Crops).** With 16 plots and about 6 per player, splitting up comes out of the economy instead of a rule.
- **One Taint state, and stacking does nothing (The Taint).** Merging three systems into one, and making a second Taint free, stops one bad day from snowballing. Good restraint.
- **Prize Pumpkin as the season's face.** Escorting one object the team cared about all week beats a quota check.

## Issues

**M1. Blocker: the first payment still needs a perfect start, and the design rules a perfect start out.** (Economy Check, Ramp-Up)
At 4 players the margin is 322 − 300 = **22 coins**. The check assumes no losses, but the doc guarantees some:
- day 1 has a disturbance;
- the creature tramples crops every night, more if nobody went out;
- pits make players drop what they carry.
Each trampled turnip costs 10 coins of sales. Three trampled turnips, or **one death on night 3 (25 coins), gives 297 < 300 and the farm is lost.** The doc says "one or two deaths means plant smarter", but before dawn 3 there's nothing smarter to plant (see M4). So the bug Change #1 claims to fix is still there.
**Fix:** set the first payment so a perfect start has about 30% headroom: 4p **240**, 3p 190, 2p 145. Add a rule that a median simulated team, with the scheduled sabotage applied, clears it.

**M2. Major: a missed first payment ends the season about 45 minutes in.** (Winning and Losing)
Too harsh for a friends' co-op.
**Fix:** a missed first payment becomes a **Foreclosure Notice**. The shortfall × 1.5 is added to the final payment and the bank seizes one upgrade or 2 plots. Only the final payment, or a wipe on the Harvest Moon, loses the season.

**M3. Major: the difficulty curve runs backwards.** (Season and Numbers)
The money is tightest at dawn 3 and slack at the finale. A 4p team planting **turnips only** has **966 coins by day 7, before the Prize Pumpkin and before the day-7 crop**, against 900 owed. With the pumpkin (250) the total is about 1,376, roughly 50% over. The Prize Pumpkin barely matters to the win.
**Fix:** move the weight to the end. Debt 1,300 = 240 + **1,060**. A median team then needs at least a Large pumpkin. Check it with the sim.

**M4. Major: pumpkins are a newbie trap and partly a dead crop.** (Crops, Ramp-Up)
Pumpkins unlock on day 2 and grow in 2 days, so a day-2 pumpkin is ready on dawn 4, after the first payment. My sim: a 4p team that plants pumpkins on day 2 has **0 coins at payment** against 300 owed. Pumpkins planted on day 6 are ready on day 8, after the season. Only two cycles are useful, and the first loses the game.
**Fix:** unlock pumpkins at **dawn 4** (a reward for the first payment). Add a salvage rule: crops still in the ground at the final dawn sell at 50%, so late planting isn't wasted.

**M5. Major: the medical bill has an exploit and an undefined order.** (Dawn, Medical Bill)
- **The floor:** the bill never takes the bank below 4. A team that spends everything on seeds every day, which is already optimal early, sits near 0 every night, so **deaths on nights 1 and 2 are free**.
- **The order:** Dawn doesn't say whether cash-in, the bill or the payment comes first. On dawn 3 that order decides win or lose.
**Fix:** dawn order is cash-in → medical bill → payment. Any part of the bill the bank can't cover is added to the final payment. That keeps the anti-death-spiral intent without free deaths.

**M6. Major: moonflowers still dominate, and the doc says they don't.** (Crops, Economy Check)
Profit is 35 per plot per night against 6 for turnips, **5.8× per plot**. At 4p, nights 3 to 7 give 5 × 140 = **700 profit**. All 16 field plots of turnips make about 566 over the season. The claim that they're "no longer most of the season's income" is false. Also, "1 night" isn't covered by the "Grows in" definition (ready on the Nth dawn), yet the check harvests a day-3 planting the same night.
**Fix:** keep them strong, since that's the reason to go out at night, but correct the claim. Define the timing as "planted by day, harvestable that night, wilts at dawn". Add a risk the team can see: an unpicked moonflower at dawn is a Taint source.

**M7. Major: the store has no prices, and the shed lock can switch off the bear traps.** (Tool Shed, Upgrades)
- **The lock:** bear traps come only from the shed, and the creature can't break a lock until day 5. Buying the lock on day 1 removes bear traps for nights 1 to 4. With no price listed, this may be the dominant opening.
- **Plots:** extra plots (to 24) are useless at 4p, because 4 × 6 = 24 needs every player farming full-time with zero sweeping.
**Fix:** add a price table and put purchases into the sim. Even locked, the creature takes one trap a night ("pried a board loose"); the lock only caps theft. Price the lock at about 40, so buying it on day 1 means planting 10 fewer turnips.

**M8. Major: the Prize Pumpkin is free money with no decision.** (The Prize Pumpkin, Payout)
Giant costs one watering hold a day. Its payout isn't scaled by player count, so 250 is 28% of the 4p final payment but **46% of the 2p one (540)**. The real problem isn't punishment (Open Issue #4), it's that there's no trade-off.
**Fix:**
- Scale the payout with player count like the payments.
- Make Giant cost something: Large needs only water; Giant also needs 2 bought fertilizers (30 each), or someone within sight of the pumpkin on 2 nights.
- Gnawing can happen on any night nobody is within 20 m of it, not only when nobody is outside.

**M9. Minor: drop-in rescaling can be gamed.** (Length and Saving)
Start as 2, pay 180, then add 2 friends: that saves 120 against the 4p 300. Players leaving isn't covered at all.
**Fix:** a rescale only changes the amount still owed, pro rata by days left. A departure never lowers payments.

**M10. Minor: there's no progression spine past the final dawn.** (The Next Season, Upgrades, Short season)
- **Spare coins:** whether they carry over is unspecified, and a surplus could trivialize the next debt.
- **Cosmetics:** they're bought "after the final payment", but the season ends there, and paying early isn't allowed.
- **Short season:** the 3-day season's debt is unspecified, and the payout table is still "of 7".
**Fix:**
- Allow early payment.
- Spare coins carry over at 25% as "savings".
- Spell out the numbers for the 3-day season.

**M11. Minor: the labor model is uncalibrated.** (Crops, Roles)
- **Plots per player:** "6 plots a day" isn't tied to hold times or the length of a day. The 2p check plants 8 plots when 12 could be tended (a 2p team could reach 226, not 194).
- **Farmer:** "grows faster" breaks the dawn-based growth model.
- **Rounding:** the 60% trap counts round to nothing defined (2 bear traps × 0.6 = 1.2).
**Fix:**
- Express labor in seconds (plant, water and harvest holds plus walking) and derive plots per player from that.
- Farmer gets +1 crop on every 5th harvest instead.
- Round trap counts up.

VERDICT: DISAGREE — open points: M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11
