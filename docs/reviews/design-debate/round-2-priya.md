# Round 2 — Priya

## Positions

| ID | Position | Note / amended wording |
|---|---|---|
| M1 | ACCEPT | 240/190/145 for the first payment, with a sim gate. A one-death loss on dawn 3 is the worst thing a friend group can hit. |
| M2 | ACCEPT | Foreclosure Notice. Losing a whole evening 45 minutes in means nobody comes back next week. Strongest point in the round. |
| M3 | ACCEPT | Debt 1,300 = 240 + 1,060, gated by the sim. |
| M4 | ACCEPT | Pumpkins unlock at dawn 4; crops still growing at the final dawn salvage at 50%. |
| M5 | ACCEPT | Dawn runs cash-in, then the medical bill, then the payment. Any unpaid bill rolls into the final payment. Also show it on the Dawn Report so it can be read. |
| M6 | ACCEPT | Use her timing definition. The unpicked-moonflower Taint fits T1, because touching it is a choice. |
| M7 | ACCEPT | Lock caps theft at one trap a night and costs ~40. |
| M8 | AMEND | "Payout scales with player count. Giant needs every watering **and** someone within 20 m of the pumpkin on at least 2 nights. Gnawing happens on any night nobody is within 20 m." Drop the fertilizer: it's another store item and another inventory sync for no social gain. Guard duty, by contrast, puts a friend alone by the farmhouse at night. |
| M9 | ACCEPT | It replaces my "rescale only upward" (see P7). Pro rata by days left is cleaner. |
| M10 | ACCEPT | Early payment, 25% carry-over, and numbers spelled out for the 3-day season. |
| M11 | ACCEPT | Labor measured in seconds. Farmer gets +1 crop every 5th harvest. Trap counts round up. |
| T1 | ACCEPT | Shaken replaces Taint on a jumpscare. Also fixes a social problem: black hands should mean "you messed up", which is the thing friends tease each other about. |
| T2 | ACCEPT | A telegraphed pry race is better co-op: it's a reason to yell for help and a reason to run toward a teammate. |
| T3 | ACCEPT | Knowledge separation must be visible in the debug view (sensed vs. true position) so it can be tested. |
| T4 | AMEND | Add: "The creature hears transmitted in-game voice only: the sender's mic amplitude after voice-activity detection, sent as one byte per voice frame. No audio is stored, so no consent tier applies. Groups on Discord don't get this penalty; accepted trade-off." |
| T5 | ACCEPT | The town stand as a sanctuary also gives players a natural regroup point. |
| T6 | ACCEPT | One hard rule, with the generator as the target. |
| T7 | AMEND | Keep acts 2 and 3. Act 1 becomes "the generator fails at cart load", reusing T6. The cart is a host-owned kinematic body that moves at a speed set by the number of pushers; there's no physics push, which avoids desync. A knockdown reuses the jumpscare knockdown. |
| T8 | ACCEPT | (b) also covers my lobby: the staged lantern **blows out**, it doesn't flicker. |
| T9 | ACCEPT | The insect bed is cheap and syncs nothing: each client can run it locally from the replicated creature state. |
| T10 | AMEND | Drop the HUD marker. But see P13: Godot's stock 3D audio localizes front/back poorly. "If Phase 3 tests show players can't place a whistle, the whistler's lantern or hat flashes briefly (diegetic)." |
| T11 | ACCEPT | Merge it with P6 (see C2). |
| P1 | KEEP | Neither colleague objected. Still a blocker. |
| P2 | KEEP | T8a doesn't fix a public line list. Barn chatter in Phase 2 still stands. |
| P3 | KEEP, AMEND | Add: "A targeted lure in a dead player's voice uses the ghost static chain (T8a)." |
| P4 | KEEP | — |
| P5 | KEEP | — |
| P6 | KEEP, AMEND | See C2. |
| P7 | AMEND | Ghost-on-join, the NPC idler and the portable save all stay. The payment rule is now M9's. |
| P8 | KEEP | Theo's tells make it more pressing: a Discord ghost with full sight of the creature is a cheat channel. |
| P9 | KEEP | — |
| P10 | KEEP | The "lure worked" metric now also feeds T3's tuning. |
| P11 | WITHDRAW | M1 and M11 cover it better. |

## Conflicts

**C1. T4 (mic volume) vs P1 (consent) and Discord groups.** Using amplitude as a live input isn't recording, so it stays outside the consent tiers. Discord groups escape it. Don't fight that; it's the same accepted trade-off the doc already makes for mimicry.

**C2. T11 + P6 + M11: Phase 1 scope creep.** All three of us want to add things to Phase 1. My resolution is that Phase 1 gets:
- turnips (plant/water/sell), with the labor clock from M11;
- the noisy watering can;
- crouch and go-still;
- three ambience layers driven by the creature state;
- scripted traps;
- no Director, and no prices beyond turnips.

Anything else waits. Voice still goes first.

**C3. T1/T2 vs Day Deaths' "2 of 3 conditions" bend.** After T1 and T2, the day-death conditions are (a) alone, Tainted by choice and deep in the corn, or (b) losing the trap race. The Director's rare "2 of 3" kill breaks Theo's "own mistake" rule. *Resolution:* the Director bends only the distances, never the number of conditions. Cut the 2-of-3 clause.

**C4. M9 vs P7.** M9 wins on the money and P7 on the join flow. Combined wording: "A late joiner enters at once as a ghost and gets a body at dawn. The amount still owed rescales pro rata by days left. A departure never lowers payments."

**C5. T7 (cart bites) vs M8 (pumpkin size scoring).** Bites taken during the finale drop one size each, capped at two, so a team that guarded it all week still sees that investment pay off at the festival.

**C6. M2 Foreclosure vs P7 portable save.** A foreclosed season must still save and resume. Foreclosure state goes into the dawn save. No conflict once that's stated.

## New issues

**P12 — major — Engine and Tech / Voice.** The doc never picks open mic or push-to-talk for proximity chat. T4 (screams give you away), the Phase 5 rule "only push-to-talk speech is kept", and P2's barn chatter all depend on that choice.
*Change:* proximity chat defaults to open mic with voice-activity detection, and push-to-talk is an option. The creature hears whatever is transmitted. Live clips (Phase 5) come only from transmitted speech in the Live tier.

**P13 — major — Engine and Tech: spatial audio.** `AudioStreamPlayer3D` has panning and attenuation but no HRTF, so front/back and elevation cues are weak, especially at range. "The voice comes from where the teammate can't be" (the one tell that never goes away), the whistle without a marker (T10) and the Stalk direction all rely on localization.
*Change:* in Phase 1, test localization at 10/30/60 m with headphones. If it fails, evaluate the Steam Audio GDExtension, or add an occlusion/reverb send per source so distance and corn cover are audible.

**P14 — minor — Dawn Report (with P3).** Targeted lures are private by design, so the Report is where the group finds out. That's the payoff, and it should be stated as intent. Replays still respect each speaker's consent tier (P1). A player on "Off" is replayed with the fallback voice.

VERDICT: DISAGREE — open points: P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P12, P13, P14, M8, T4, T7, T10, C2, C3
