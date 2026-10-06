# Round 5 — Priya

## A9 vote: ACCEPT the formula, with a numbers errata

Mara's formula is correct. I re-ran her checks:
- **4p:** 1,300 − 255 = 1,045.
- **3p dropping before dawn 2:** 185.7 + 6 × 148.6 = 1,077; first payment 255/1,300 × 1,077 = 211.

Her catch on my v2 wording was right.

The formula is now the source of truth, but it disagrees with the fixed numbers elsewhere by 2 coins:

| | 2p first | 2p final | 3p first | 3p final |
|---|---|---|---|---|
| Formula (split 255/1,300) | 153 | 627 | 204 | 836 |
| A1 / A3 as written | 155 | 627 | 205 | 836 |
| A9 check row | 155 | **625** | — | — |

Three places disagree, so a programmer can't tell which number wins.

**Errata to apply:**
- **A1:** 3p **204**, 2p **153**.
- **A9 check row:** "780 (153 + 627)".
- **A9, add one line:** "A1 and A3's per-player-count amounts are outputs of this formula. If they ever differ, the formula wins."

No other objections. With this errata applied, the list is complete.

VERDICT: DISAGREE — open points: A9 (numbers errata only: A1 3p 204 / 2p 153, check row 153 + 627)
