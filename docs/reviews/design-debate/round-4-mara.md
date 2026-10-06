# Round 4: Mara (systems & economy)

## Votes

**ACCEPT:** A3, A8, A10, A13, A14, B2, B14, B15, C2, C8, C11, C12, C13, C14.
- **A8:** "carrying a lantern is allowed" is fine. Light is a risk the guard chooses, and the 30 m rule is what stops guarding from being free.
- **B2:** "a solo, untainted player who starts prying at once survives" keeps the day predictable enough to farm in.

**OBJECT:** A9, the formula. I agree with the direction, and Priya was right to ask for a formula. But the formula as written is arithmetically wrong.

## A9 objection

The draft says: "the amount still owed is the sum of the **remaining** days' shares, minus payments made." That subtracts payments from shares that were never charged.

**Check it, 4p, no headcount change, at dawn 4 after the 255 first payment:**
- The remaining days 4–7 carry 4/7 × 1,300 = 743.
- The formula gives 743 − 255 = **488** owed.
- The real figure is 1,300 − 255 = **1,045**.

So the formula cancels more than half the final payment, with nobody joining or leaving.

**Two more gaps:**
- It doesn't say how a rescale splits between the first payment and the final payment.
- It's silent on what A2 and A5 add to the final payment. If those amounts rescaled, a team could drop a player to shed its own penalty.

**Replacement wording I'd accept:**
> **Formula:**
> - Each of the 7 days carries an equal share of the base debt (1,300 ÷ 7).
> - A day's share is scaled by the headcount at that day's dawn (100/80/60%), and is fixed once that dawn begins.
> - **Total debt** is the sum of all 7 days' shares. Past days use their recorded headcount; future days use the current one.
> - **Still owed** is the total debt, minus all payments made (including early ones), plus any A2 foreclosure penalty and A5 deferred bills. Those additions never rescale.
> - **Split:** if the first payment is still ahead, it takes 255/1,300 of the total debt (rounded), and the final payment takes the rest.
> - **Moonflower bed:** follows the headcount.

**Checks:**

| Case | Calculation | Owed |
|---|---|---|
| 4p, no change, after the first payment | 1,300 − 255 | 1,045 ✓ |
| 2p, full season | 1,300 × 0.6 | 780 (155 + 625), matches A1/A3 within rounding ✓ |
| 4p, one player drops before dawn 2 | 185.7 + 6 × 148.6 | 1,077; first payment 211 |

The rest of A9 stands as written: joining as a ghost, the NPC farmhand not counting, payments locked when a dawn begins, and portable saves.

VERDICT: DISAGREE — open points: A9
