# Consensus Change List (v3, for round 5)

Compiled by the Director from rounds 1 and 2. Each item merges the original issue with the amendments the designers made. **Status** marks where it stands after round 2:

- **Agreed**: all three accepted it, or nobody objected to the amended wording.
- **Director proposal**: the designers disagreed, and this is the Director's proposed compromise.
- **New**: raised in round 2 and not yet reviewed by the other two.

In round 3 every designer votes on every item.

**v2 changes (after round 3):**
- **Objections adopted as written:** Mara's on A8, Theo's on B2, Priya's on A9 and C2.
- **Notes folded in:** A3, A10, C8, C11.
- **New items added:** M14 → A13, M15 → A14, T14 → B14, T15 → B15, P15 → C12, P16 → C13, P17 → C14.
- **Status now:** every item is *Agreed*, except the new items, which are marked *New (round 3)*.

**v3 changes (after round 4):**
- **Round 3 items accepted:** every round-3 item and every reworded item was accepted by all three designers.
- **A9 rewritten:** it now uses Mara's corrected formula (the v2 formula undercounted the final payment) and adds Priya's P18 (below two players).
- **A9 is the only item still open.**

---

## A. Economy

**A1. First payment** (M1, P11) · *Agreed*
- **Amounts:** the first payment is 4p **255**, 3p 205, 2p 155.
- **Check:** a median simulated team, with scheduled sabotage and 1 trampled plot a night (2 on unattended nights), clears it with about 15% margin.
- **Why this number:** Mara's 240 sits on top of the A2 safety net, which softens the game twice (Theo). Theo's 270 leaves about 10% margin, which a single sabotage roll can wipe out. 255 splits the difference.

**A2. Foreclosure Notice** (M2) · *Agreed*
- A missed first payment doesn't end the season.
- **Penalty:** the shortfall × 1.5 moves onto the final payment, and the bank seizes one upgrade or 2 plots (its choice).
- **Losing:** only a missed final payment, or a wipe on the Harvest Moon, loses the season.
- **Saving:** foreclosure state is stored in the dawn save (P-C6).

**A3. Back-loaded debt** (M3) · *Agreed*
- The 4p debt is **1,300** = 255 + 1,045 (adjusted for A1).
- **Scaled finals:** 3p 836, 2p 627.
- The final payment is tuned so a median team needs to deliver a **Large** Prize Pumpkin.
- The season simulator verifies this.

**A4. Pumpkins** (M4) · *Agreed*
- Pumpkins unlock at dawn 4.
- Crops still in the ground at the final dawn sell at 50%.

**A5. Dawn order and medical bill** (M5, M13) · *Agreed*
- **Order at dawn:** cash-in → medical bill → payment. The Dawn Report shows this order.
- **Unpaid bill:** any part of the bill the bank can't cover is added to the final payment.
- **Day deaths** go through the same bill.

**A6. Moonflowers** (M6, T-M6) · *Agreed*
- **Timing:** planted by day, harvestable that night, wilted at dawn.
- **Wording:** correct the doc's claim that they're no longer most of the income.
- **Unpicked flowers:** a moonflower left unpicked at dawn becomes a **Taint object** in its plot. Touching it Taints you (washable), and the plot can't be replanted until someone clears it.

**A7. Store prices and shed lock** (M7) · *Agreed*
- Add a price table, and include purchases in the simulator.
- **Lock:** about 40 coins.
- **Lock still leaks:** a locked shed still loses 1 trap a night ("pried a board loose"). From day 5 the creature can break the lock fully.

**A8. Prize Pumpkin trade-off** (M8) · *Agreed, with Mara's round-3 wording*
- **Scaling:** the payout scales with player count, the same way payments do.
- **Location:** the Prize Pumpkin patch sits **at least 30 m from any building's door**, in the open between the farmhouse and the first corn strip. At dusk on night 7 the pumpkin is moved to the barn for loading.
- **Giant:** needs watering every day **and** a guard. Someone must be outdoors within 20 m of the pumpkin for at least 60 s, on at least 2 of nights 1 to 6. Time inside the light radius of a lit doorway doesn't count. Carrying a lantern is allowed; it's a risk the guard chooses.
- **Fertilizer is cut.**
- **Gnawing:** happens on any night nobody is within 20 m of the pumpkin.

**A9. Joining and leaving mid-season** (M9, P7, P18) · *Agreed, with Mara's round-4 formula and Priya's P18*
- **Joining:** a late joiner enters at once as a ghost and gets a body at the next dawn.
- **Formula:**
  - Each of the 7 days carries an equal share of the base debt (1,300 ÷ 7).
  - A day's share is scaled by the headcount at that day's dawn (100/80/60%), and is fixed once that dawn begins.
  - **Total debt** is the sum of all 7 days' shares. Past days use their recorded headcount; future days use the current one.
  - **Still owed** is the total debt, minus all payments made (including early ones), plus any A2 foreclosure penalty and A5 deferred bills. Those additions never rescale.
  - **Split:** if the first payment is still ahead, it takes 255/1,300 of the total debt (rounded), and the final payment takes the rest.
  - **Moonflower bed:** follows the headcount.
- **Worked checks:**

  | Case | Calculation | Owed |
  |---|---|---|
  | 4p, no change, after the first payment | 1,300 − 255 | 1,045 |
  | 2p, full season | 1,300 × 0.6 | 780 (155 + 625) |
  | 4p, one player drops before dawn 2 | 185.7 + 6 × 148.6 | 1,077; first payment 211 |

- **Players who drop** count as absent from the next dawn. Their idle NPC farmhand doesn't count toward headcount.
- **No exploit:** a payment due at a dawn is locked when that dawn begins, so quitting saves nothing.
- **Below two players:** if the headcount at a dawn would be 1, the game saves at that dawn and the season pauses ("Waiting for a farmhand"). It resumes when a second player joins, through the C12 path. Solo play isn't supported in v1.
- **Saves are portable:** any player who was in the season can host it.

**A10. Progression** (M10) · *Agreed*
- Early payment is allowed. Early payments count against what's owed before any A9 rescale.
- Spare coins carry over at 25% as "savings".
- The 3-day season gets its own numbers.

**A11. Labor model** (M11) · *Agreed*
- **Labor:** defined in seconds (hold times plus walking), with plots per player derived from that.
- **Farmer bonus:** +1 crop on every 5th harvest.
- **Rounding:** scaled trap counts round up.

**A12. Generator costs** (M12) · *Agreed*
- **Fuel:** the drum is free and infinite; the cost is the walk to it.
- **Repairs:** repairing creature damage takes 1 scrap. One scrap is salvaged free each dawn; extra scrap costs 15.
- **Dead at dawn:** a generator left dead at dawn costs 1 extra trampled plot.

**A13. Medical bill scales with players** (M14) · *New (round 3)*
- **Death costs and nightly cap:**

  | Players | First death | Each later death | Nightly cap |
  |---|---|---|---|
  | 2 | 15 | 30 | 72 |
  | 3 | 20 | 40 | 96 |
  | 4 | 25 | 50 | 120 |

- **Rescaling:** A9's rescale applies to these too.

**A14. Phase 4 gated on simulator targets** (M15) · *New (round 3)*
- **The sim:** runs at 2p, 3p and 4p with A1 to A13 applied.
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

## B. Creature, AI Director and fear

**B1. Taint only from choices** (T1) · *Agreed*
- **Jumpscares:** cause a knockdown, dropped items and **Shaken** (shorter sprint for 60 s). They don't Taint.
- **Taint** comes only from things a player chooses to do: touching creature leavings, picking up a stolen tool, leaving items out at dusk, touching an unpicked moonflower.
- **Cure:** every Taint can be washed off at the well.

**B2. Day trap kill is a race** (T2) · *Agreed, with Theo's round-3 wording*
- When a trap springs by day, the creature's sound signature starts approaching from a set distance.
- **Tuning:** the race is tuned so that a solo, untainted player who starts prying at once survives, with a few seconds to spare.
- **What can lose it:** hesitating, being Tainted (shorter sprint means a slower pry), or the trap being deep in the corn.
- **Outcome:** pry free in time and you live, Shaken; fail and you die.
- **Help:** a teammate shortens the pry.
- **AI Director:** its distance bending (B3) applies to the start distance, within that tuning.

**B3. Day deaths: cut the "2 of 3" clause** (Priya C3) · *Agreed*
- **Day death conditions:**
  - (a) alone, Tainted by choice, and deep in the corn; or
  - (b) losing the trap race.
- **AI Director:** bends only the distances, never the number of conditions.

**B4. Knowledge separation and Director profiles** (T3) · *Agreed*
- **Hunting** (movement, pursuit, trap placement) uses only the creature's senses and Taint.
- **Presentation** (lure targeting, scare timing, hallucinations) may use true positions.
- **Phases:** the AI Director runs build-up / peak / fade / relax, with separate day, night and finale profiles, and presence events per player as a tunable.
- **Debug view:** shows sensed and true positions side by side.

**B5. Hide verbs and live mic** (T4) · *Agreed*
- **Losing a chase** takes breaking sight **and** going quiet.
- **New verbs:** crouch-walk and go-still. The host validates stillness.
- **Mic:** the creature hears transmitted in-game voice as amplitude only, one byte per voice frame. No audio is stored, so no consent tier applies.
- **Discord groups** escape this. That's an accepted trade-off (see B13).

**B6. Day arc and sanctuary** (T5) · *Agreed*
- **Day arc:**
  - first third calm (sabotage evidence only);
  - middle third low presence;
  - last third builds to dusk.
- **Scare cap:** at most 1 big scare per player per day.
- **Town stand:** within 10 m of it there are no lures, scares or kills, but the day clock runs and nothing grows there.

**B7. Light is the rule** (T6) · *Agreed*
- The creature never enters a lit building.
- **Hoarded traps:** one vanishes only if the generator went dark that night; otherwise it reappears in the corn at dawn.
- **Barn doors:** testing them means banging while the creature circles to the generator and damages it (costs: see A12).

**B8. Harvest Moon finale** (T7) · *Agreed*
- **Act 1:** the generator fails during cart loading.
- **Act 2:** the push. The cart is a host-owned kinematic body; its speed is set by how many players push. It carries a lantern. Pushers get knocked off with the jumpscare knockdown.
- **Bites:** each stall lets the creature take a bite (one size down), at most 2 per escort.
- **Act 3:** the gate run, with a guaranteed peak and then release.
- **Ghosts** can flicker the cart lantern.

**B9. Dead-voice twist specs** (T8) · *Agreed*
- **(a)** Mimics of a dead player use the ghost static chain, including targeted lures.
- **(b)** Nothing else in the game flickers a light. The generator dims; the lobby lantern blows out.
- **(c)** Night lures in a dead player's voice are world sounds, so the whole team can check for the flicker.

**B10. Readable states** (T9) · *Agreed*
- **Stalk tell:** a constant insect/frog bed cuts out on Stalk. Each client runs it locally from the replicated creature state.
- **Crows:** no longer used as the Stalk or Retreat tell.
- **Husk:** its rustle must sound distinct from ordinary corn rustle.

**B11. Whistle** (T10) · *Agreed*
- The HUD marker is dropped; the whistle is a 3D sound only.
- **Fallback:** if Phase 3 tests show players can't place a whistle, the whistler's lantern or hat flashes briefly.

**B12. Private scare budget** (T13) · *Agreed*
- Targeted lures, hallucinations and the wrong count all count against the per-player daily cap and the 2-minute spacing.

**B13. Discord, said plainly** (T12) · *Agreed*
- The doc admits Discord removes the cost of talking.
- **No compensation:** the AI Director doesn't cheat to make up for it.
- **Lobby note:** "The creature can't hear Discord, and you can't hear where your friends are."

**B14. Dark buildings aren't safe** (T14) · *New (round 3)*
- A building whose lights are out is not safe.
- **Getting in:** the creature can enter only through a door, and it bangs the door first (the B7 tell).
- **Getting it out:** restoring power drives it out.

**B15. Nightmare difficulty** (T15) · *New (round 3)*
- **Day deaths:** on Nightmare they're more likely only through wider distance bends (B3).
- **Whistle:** stays honest.
- **Voice tells:** removed, but the positional tell (C11) always remains.

## C. Voice, multiplayer and production

**C1. Voice consent tiers replace the gate** (P1) · *Agreed, with Theo's amendment*
- **No hard gate.** Each player picks their own tier:
  - **Off**
  - **Lobby lines** (default once recorded)
  - **Live clips** (opt-in, Phase 5)
- **Scope:** a player's tier governs every replay of their voice: the creature, the Dawn Report, and streamer mode.
- **Storage:** lobby lines stay on the owner's disk and in peer memory, never in the host save.
- **Streams:** the doc no longer promises anything about streams.
- **Off players:** the creature never imitates them with a generic voice. It mimics their footsteps and tools instead. In the Dawn Report, their lures appear as text plus the sound, with no voice. (This resolves P14 vs Theo's P1 amendment.)
- **Generic voices** are used only for "stranger" calls.

**C2. Barn chatter** (P2) · *Agreed, with Priya's round-3 wording*
- **Capture:** 20 to 40 s of free barn chatter is added to the Lobby-lines tier.
- **Who is captured:** only players on the Lobby-lines tier who take part in the staged recording, which can be skipped.
- **How:** capture happens on the sender's machine. A visible "recording" lantern or tally light shows while capture is live.
- **Review:** each clip can be reviewed and deleted before the match starts.
- **Timing:** lands in Phase 2.
- **Line list:** never tell players the line list is the whole pool.
- **When lures fire:** when a call-and-response check would be costly.

**C3. Targeted lures** (P3) · *Agreed*
- **Day lures** are heard only by the target, and only when no teammate is within about 15 m (a presentation-side check).
- **Night and chase lures** are world sounds.
- **Dawn Report:** replays targeted lures to everyone, as an intended reveal.

**C4. Networking authority** (P4) · *Agreed*
- **Clients own:** their own movement and camera.
- **The host owns:** the creature, AI Director, traps, pegboard, economy (no client-side sell calls), Taint, deaths, and validation of interactions.
- **Borderline lag calls** go to the victim.
- **Lures** are host RPCs that play clips already distributed to every peer.

**C5. Commit to Steam** (P5) · *Agreed*
- GodotSteam, SteamMultiplayerPeer and Steam voice.
- ENet on LAN for development only.

**C6. Phase 1 scope** (P6, T11, M11) · *Agreed*
- **Phase 1 adds:**
  - turnips (plant, water, sell) with hold-time logging;
  - the noisy watering can;
  - one generator run;
  - crouch and go-still;
  - three ambience layers driven by the creature state;
  - scripted traps.
- **Phase 1 leaves out:** the AI Director, and any prices beyond turnips.
- **Order:** voice still comes first.
- **Gates:** at least 2 sessions, at least one tester who hasn't read the doc, and a log metric.

**C7. Ghost vision** (P8) · *Agreed (Theo's amendment)*
- **Within about 20 m,** ghosts see the creature only as a smeared silhouette.
- **Beyond that,** they see it only through animals and crows reacting.

**C8. Onboarding** (P9) · *Agreed*
- Days 1 to 3 are the tutorial.
- Each verb gets one diegetic introduction.
- **No introduction may tell players the day is safe.** They learn it and doubt it.

**C9. Testing** (P10) · *Agreed*
- **Debug tools:** a "mic from WAV" input and simulated latency and packet loss.
- **"A lure worked"** means the target moved more than 10 m toward the source within 8 s. That one definition is used everywhere.

**C10. Open mic by default** (P12) · *Agreed*
- Proximity chat defaults to open mic with voice activity detection (VAD); push-to-talk is an option.
- The creature hears whatever is transmitted.
- **Live clips** (Phase 5) come only from transmitted speech in the Live tier.

**C11. Spatial audio check** (P13) · *Agreed*
- This is a **Phase 1 gate**, not an optional check: B11 and the positional voice tell depend on it.
- **Phase 1 test:** check headphone localization at 10, 30 and 60 m.
- **If it fails:** evaluate the Steam Audio GDExtension, or add a per-source occlusion/reverb send.

**C12. Host disconnects** (P15) · *New (round 3)*
- If the host leaves, the session ends for everyone with a "host left" card.
- **Resuming:** the season resumes from the last dawn save, and any player from that season can host it (A9).
- **No host migration in v1.** Lost progress is at most one day and night.

**C13. Two voice backends** (P16) · *New (round 3)*
- **One interface, two backends:**
  - Steam voice (shipping);
  - an Opus-over-ENet dev backend, which can be fed from C9's mic-from-WAV input.
- **Two-machine Phase 1 test:** uses Steam's free test AppID (480) until we have our own.

**C14. The doc's own bookkeeping** (P17) · *New (round 3)*
- **Rewrite to match the change list:**
  - the review summary ("ten changes");
  - Resolved and Open Issues: the consent entry; Open Issue 3, closed by B11; Open Issue 4, changed by A2 and A8;
  - the hard-gate wording in Build Notes;
  - Next Steps.
- **Next Steps step 2** becomes "Steam voice between two machines (C5, C13)".
