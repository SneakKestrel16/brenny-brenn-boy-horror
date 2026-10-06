# Consensus Change List (draft for round 3)

Compiled by the Director from rounds 1 and 2. Each item merges the original issue with the amendments the designers made. **Status** marks where it stands after round 2:

- **Agreed**: all three accepted it, or nobody objected to the amended wording.
- **Director proposal**: the designers disagreed, and this is the Director's proposed compromise.
- **New**: raised in round 2 and not yet reviewed by the other two.

In round 3 every designer votes on every item.

---

## A. Economy

**A1. First payment** (M1, P11) · *Director proposal*
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

**A8. Prize Pumpkin trade-off** (M8) · *Director proposal*
- **Scaling:** the payout scales with player count, the same way payments do.
- **Giant:** needs watering every day **and** an outdoor guard. Someone must be outdoors (not inside a building) within 20 m of the pumpkin for at least 60 s, on at least 2 nights.
- **Fertilizer is cut.** Priya: it adds store and inventory scope for no social gain. Mara offered it only as an alternative path.
- **Gnawing:** happens on any night nobody is within 20 m of the pumpkin.

**A9. Joining and leaving mid-season** (M9, P7) · *Director proposal*
- **Joining:** a late joiner enters at once as a ghost and gets a body at the next dawn.
- **Headcount changes** take effect at the next dawn. From then, the amount still owed rescales pro rata over the days left, in **either direction**, and the moonflower bed scales with it.
- **No exploit:** a payment due at that dawn is already locked, so quitting saves nothing.
- **Why both directions:** this is Mara's rule. Priya's "a departure never lowers payments" punishes real disconnects; a missing player is missing labor.
- **Players who drop** become an idle NPC farmhand.
- **Saves are portable:** any player who was in the season can host it.

**A10. Progression** (M10) · *Agreed*
- Early payment is allowed.
- Spare coins carry over at 25% as "savings".
- The 3-day season gets its own numbers.

**A11. Labor model** (M11) · *Agreed*
- **Labor:** defined in seconds (hold times plus walking), with plots per player derived from that.
- **Farmer bonus:** +1 crop on every 5th harvest.
- **Rounding:** scaled trap counts round up.

**A12. Generator costs** (M12) · *New*
- **Fuel:** the drum is free and infinite; the cost is the walk to it.
- **Repairs:** repairing creature damage takes 1 scrap. One scrap is salvaged free each dawn; extra scrap costs 15.
- **Dead at dawn:** a generator left dead at dawn costs 1 extra trampled plot.

## B. Creature, AI Director and fear

**B1. Taint only from choices** (T1) · *Agreed*
- **Jumpscares:** cause a knockdown, dropped items and **Shaken** (shorter sprint for 60 s). They don't Taint.
- **Taint** comes only from things a player chooses to do: touching creature leavings, picking up a stolen tool, leaving items out at dusk, touching an unpicked moonflower.
- **Cure:** every Taint can be washed off at the well.

**B2. Day trap kill is a race** (T2) · *Agreed*
- When a trap springs by day, the creature's sound signature starts approaching from a set distance.
- **Outcome:** pry free in time and you live, Shaken; fail and you die.
- **Help:** a teammate shortens the pry.

**B3. Day deaths: cut the "2 of 3" clause** (Priya C3) · *New*
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

**B12. Private scare budget** (T13) · *New*
- Targeted lures, hallucinations and the wrong count all count against the per-player daily cap and the 2-minute spacing.

**B13. Discord, said plainly** (T12) · *New*
- The doc admits Discord removes the cost of talking.
- **No compensation:** the AI Director doesn't cheat to make up for it.
- **Lobby note:** "The creature can't hear Discord, and you can't hear where your friends are."

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

**C2. Barn chatter** (P2) · *Agreed*
- **Capture:** 20 to 40 s of free barn chatter is added to the Lobby-lines tier.
- **Notice:** a visible "recording" notice in the barn, plus per-clip review and delete.
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

**C9. Testing** (P10) · *Agreed*
- **Debug tools:** a "mic from WAV" input and simulated latency and packet loss.
- **"A lure worked"** means the target moved more than 10 m toward the source within 8 s. That one definition is used everywhere.

**C10. Open mic by default** (P12) · *New*
- Proximity chat defaults to open mic with voice activity detection (VAD); push-to-talk is an option.
- The creature hears whatever is transmitted.
- **Live clips** (Phase 5) come only from transmitted speech in the Live tier.

**C11. Spatial audio check** (P13) · *New*
- **Phase 1 test:** check headphone localization at 10, 30 and 60 m.
- **If it fails:** evaluate the Steam Audio GDExtension, or add a per-source occlusion/reverb send.
