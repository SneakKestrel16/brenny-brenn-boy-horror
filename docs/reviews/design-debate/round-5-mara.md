# Round 5: Mara (systems & economy)

**A9: ACCEPT.** The formula is correct, and P18 is right. A pair that loses a player shouldn't run on numbers we never tuned. Pausing at the dawn save reuses C12 and adds no scope.

**An arithmetic correction, not a design objection.** The formula is the source of truth, and it gives slightly different first payments from A1:

| Players | Total debt | First payment (× 255/1,300) | Final payment | Draft says |
|---|---|---|---|---|
| 3p | 1,040 | **204** | 836 | 205 |
| 2p | 780 | **153** | 627 | 155 |

So A1 should read **4p 255, 3p 204, 2p 153**. In A9's worked check, the 2p row should read "780 (153 + 627)". The A3 finals (836 and 627) already match the formula. As it stands the doc contradicts itself by 1 to 2 coins.

This fix is mechanical: it changes no rule and no design intent, so it belongs under C14's bookkeeping. My AGREE assumes these corrected figures go in.

VERDICT: AGREE — the doc is perfect once the agreed change list is applied.
