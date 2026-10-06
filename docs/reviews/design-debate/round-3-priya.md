# Round 3 — Priya

## Votes

**A1 — ACCEPT.** 255 with a check against the sim is defensible. With A2 as the net, the exact number matters less than the sim gate, and that is in the wording.

**A2–A7 — ACCEPT.**

**A8 — ACCEPT.** "Outdoors, 60 s, 2 nights" is checked on the host and logged, so it can be tested. Guard duty also puts one friend alone by the farmhouse at night, which makes good stories.

**A9 — OBJECT (wording only, not the direction).** I concede both directions; Mara is right about disconnects. Two parts are underspecified. First, "rescales pro rata over the days left" has no formula, so two programmers will build two different ones. Second, an idle NPC farmhand has no stated headcount status. Replacement:
> "Each season day carries an equal share of the debt. A day's share is scaled by the headcount at that day's dawn (100/80/60%). The amount still owed is the sum of the remaining days' shares, minus payments made. A player who drops counts as absent from the next dawn; their NPC farmhand doesn't count toward headcount. A payment due at a dawn is locked when that dawn begins."

Without this, the scaling table, the simulator and the drop-in code can each settle on a different number.

**A10–A12 — ACCEPT.** In A12, scrap is one more store item, but it's priced in labor and risk. Fine.

**B1, B2 — ACCEPT.**

**B3 — ACCEPT.** This is my own point from round 2 (my conflict C3), and B1 and B2 make it the only consistent rule.

**B4 — ACCEPT.** Splitting hunting from presentation is the right line, and the debug view makes it testable.

**B5–B11 — ACCEPT.** B8's kinematic cart and 2-bite cap network cleanly.

**B12 — ACCEPT.** It stops one friend from eating three private scares while the rest hear nothing. That matters for fairness at the group level.

**B13 — ACCEPT.** Honest, with no hidden compensation.

**C1 — ACCEPT.** Theo is right that a generic voice standing in for a known friend is a free tell.

**C2 — OBJECT.** It doesn't say who gets captured. Barn chatter is off-guard speech, and the barn is the lobby everyone stands in, including players on Off. Replacement:
> "Barn chatter is captured only from players on the Lobby-lines tier who are taking part in the staged recording, which can be skipped. A visible 'recording' lantern/tally light shows while capture is live. Capture happens on the sender's machine. Each clip can be reviewed and deleted before the match starts."

As drafted, a player on Off could have chatter captured just by standing in the lobby. That would break C1.

**C3–C5 — ACCEPT.** C5 needs P16 below.

**C6 — ACCEPT.**

**C7–C11 — ACCEPT.**

## Still missing

**P15 — major — the host disconnects mid-session** (Engine and Tech, Length and Saving). A9 covers a client dropping. The host dropping isn't covered, and on a host-authoritative design the host is the creature, the Director and the economy.
*Add:* "If the host leaves, the session ends for everyone with a 'host left' card, and the season resumes from the last dawn save. Any player from that season can host it (A9). No host migration in v1; the lost progress is at most one day/night."
Saying this plainly saves weeks of scope creep into host migration.

**P16 — major — dev testing can't exercise Steam voice** (Testing Solo, C5). Run Instances starts one Steam user, and Steam voice doesn't run over the ENet dev transport. So C5 plus "most testing can be done alone" means voice can never be tested solo.
*Add:* "Voice sits behind one interface with two backends: Steam voice (shipping) and an Opus-over-ENet dev backend that can be fed from C9's mic-from-WAV input. Use Steam's free test AppID (480) for the two-machine Phase 1 test until we have our own AppID."

**P17 — minor — the doc's own bookkeeping** (Design Review summary, Resolved and Open Issues, Next Steps). Applying this list leaves stale text behind:
- "ten changes that matter most";
- the consent entry under Resolved Issues;
- Open Issue 3 (the whistle marker), which B11 closes;
- the hard-gate wording in Build Notes;
- Open Issue 4, which A8 and A2 change.

*Add:* "Rewrite the summary, Resolved and Open Issues, and Next Steps to match the change list. Next Steps step 2 becomes 'Steam voice between two machines (C5, P16)'."
A doc that contradicts itself isn't perfect, however good each change is.

VERDICT: DISAGREE — open points: A9, C2, P15, P16, P17
