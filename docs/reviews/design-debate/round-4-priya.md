# Round 4 — Priya

## Votes

| Item | Vote | Note |
|---|---|---|
| A3 | ACCEPT | 836 and 627 are exactly 80% and 60% of 1,045. Consistent with A9. |
| A8 | ACCEPT | Mara's 30 m rule makes guard duty a real choice. The social scene survives. |
| A9 | ACCEPT | It's my formula. See P18 for its one gap. |
| A10 | ACCEPT | |
| A13 | ACCEPT | Same scale as the payments, so the 2-player game is no longer punished twice. |
| A14 | ACCEPT | It turns "the sim verifies it" into a pass/fail gate. That's the testability I wanted. |
| B2 | ACCEPT | "A solo untainted player who pries at once survives" is a measurable tuning target. Put it in C9's logs. |
| B14 | ACCEPT | Readable both ways. It also makes B8's Act 1 a real beat. |
| B15 | ACCEPT | |
| C2 | ACCEPT | |
| C8 | ACCEPT | |
| C11 | ACCEPT | It's right as a gate. |
| C12 | ACCEPT | |
| C13 | ACCEPT | |
| C14 | ACCEPT | It also has to cover A8's move of the pumpkin patch away from "by the farmhouse". "Rewrite to match the change list" already includes that. |

## Remaining objection

**P18 — minor — A9 has no 1-player value.** The scale is 100/80/60% for 4/3/2 players, and the game is for 2 to 4. The most common group is a pair, so the most common drop leaves one player alone. A9's formula then needs a share that doesn't exist, and the host is left running a 2-player creature and debt solo. Without a rule, the code will pick one by accident.

Replacement, appended to A9:
> **Below two players:** if the headcount at a dawn would be 1, the game saves at that dawn and the season pauses there ("Waiting for a farmhand"). It resumes when a second player joins. A solo continuation isn't supported in v1, and the day 1–7 numbers are never tuned for one player.

This adds no scope: it reuses the C12 save-and-resume path. It doesn't concede the edge case, and it doesn't open a new solo mode.

VERDICT: DISAGREE — open points: P18
