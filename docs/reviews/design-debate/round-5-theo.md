# Round 5: Theo

## A9: ACCEPT the formula and P18, OBJECT to one number

The formula is right. I re-ran the 4p drop case: 185.7 + 6 × 148.6 = 1,077, and 255/1,300 of that is 211. P18's pause is fine. A lone farmer against the creature is a different game, and v1 shouldn't pretend otherwise.

**One inconsistency.** A9's own split rule (255/1,300 of the total debt) gives a 2p season **153 + 627**. That matches A3's 627, but A9's table says **155 + 625**, and A1 says 155. The same mismatch exists at 3p: 1,040 splits into **204 + 836**, while A1 says 205. Right now three items disagree about the payments, so the code, the simulator and the scaling table will each disagree too.

**Replacement (one rule everywhere):**
> **A1:** first payment 4p 255, **3p 204, 2p 153** (exactly 255/1,300 of each total).
> **A9 worked checks, 2p row:** "1,300 × 0.6 = 780 (**153 + 627**)."

A3 (836 / 627) then stands unchanged. This is arithmetic only. It doesn't change any stakes.

VERDICT: DISAGREE — open points: A9 (2p row), A1 (3p/2p amounts)
