# Farmer's Delight: Design Doc 01

**Game name:** Farmer's Delight. Its `project.godot` `config/name` sets the window title and the main menu title. `config/custom_user_dir_name` keeps the old `Brenny Brenn Boy Horror` folder under `app_userdata`, so saves and logs stay where they were.

Friends grow crops on a farm while something in the corn hunts them. Farming creates the tension horror needs: crops tie you to spots, the work is noisy, and you can't finish it all huddled together.

**Pitch:** a farm under siege. Traps, crops and the day/night economy are the hook. Voice mimicry supports it rather than leading it.

**Format:** 2 to 6 player online co-op against an AI creature, built and balanced around 4. The creature, the debt and the costs scale with player count.

**Status:** Nothing is built yet. All numbers are starting values, tuned with the season simulator and playtest logs.

### Pillars

- **Cozy day, terrifying night.** Protect the contrast.
- **The night writes tomorrow's chores.** The creature's traps are the next day's work.
- **Honest signals cost something.** Pegboard, flags, whistle, flicker and radios tell the truth at a price.
- **Deaths come from player choices.** The creature frightens all day but only kills when someone took a risk.
- **Glimpsed, never seen.** Players hear it far more than they see it.
- **Stories for friends.** The Dawn Report, ragdolls and trust arguments make the "remember when" moments.

---

## Core Loop

**Day (about 8 to 10 minutes):**
- check the pegboard, sweep and disarm traps;
- plant, water, harvest, repair, sell at the town stand;
- follows the day arc (see AI Director).

**Dusk (about 1 minute):**
- light fades and animals go quiet;
- the church bell rings three times;
- players rush to harvest and top up the generator.

**Night (about 5 minutes):**
- the creature hunts and sets traps;
- moonflowers are harvested;
- the generator needs refueling.

**Dawn, in this order (shown on the Dawn Report):**
1. **Cash-in:** survivors sell what they carry; the dead lose what they carried.
2. **Medical bill.**
3. **Any payment due.**
4. **Farm damage:** where the creature roamed, more if nobody was outside. After a full wipe, damage doubles and extra traps appear.

---

## The Creature

It lives in the wild corn ringing the farm. Players can't cut or farm that corn. Strips of it reach toward the buildings and stand between the barn and both fields, so every errand crosses its ground.

### Bodies

The host's game picks one of four bodies per season. They all hunt identically; only the look and sound differ.

| Body | Look | Sound signature |
|---|---|---|
| Gaunt thing | hunched, dark hide | clicks |
| Scarecrow | ragged coat, stitched sack head, ember eyes | coat flaps |
| Boar brute | tusks, iron collar, chain | chain drags |
| Corn husk | stalks and peeled leaves round a glowing heart | dry rattle, distinct from normal corn rustle |

### What players see

- **By day:** parts and motion only, such as a head above the corn or stalks parting.
- **At night:** a clear view only mid-chase, in the dark, for under a second.
- **Lunges:** cut to black or a knockdown before a full view.
- **Stares and hallucinations:** distant silhouettes.
- **Ghosts:** follow the same rule.

### Senses

The creature acts only on what it senses. It never knows positions any other way.

- **Hearing (main sense):** louder sounds carry further. It hears:
  - tools, footsteps, doors and the well pump;
  - sprinting through corn;
  - **transmitted in-game voice volume.** A scream gives you away. Only the volume is sent, one byte per voice frame, and nothing is stored.
- **Sight:** short range. It spots light and open ground; corn blocks its view as it blocks yours.
- **Corruption:** it tracks Corrupted players from much further away.

**Hiding verbs:**
- **Crouch-walk:** silent and slow.
- **Go still:** no movement while your heartbeat rises. The host checks stillness.

### Behavior states

| State | What it does | What players hear |
|---|---|---|
| Lurk | moves through corn, sets night traps, gathers clips | normal ambience: insect and frog bed, birds, animals |
| Lure | plays a voice or sound from cover, near armed traps or lone players | a voice or tool sound from the corn |
| Stalk | follows one player from cover | the insect and frog bed cuts out and the wind drops |
| Chase | night, or a day kill: runs a player down | music sting plus the body's signature, loud |
| Retreat | after a jumpscare, kill or flare hit | the insects and frogs come back |

- **Losing a chase:** break line of sight **and** go quiet (crouch or still) for a few seconds, or reach a lit building.
- **By day:** it Lurks, Lures, Stalks and jumpscares, and kills only as in Day Deaths.
- **Ambience:** runs locally on each client from the replicated state.
- **Crows aren't a state tell.** Stalk is a layer dropping away, not animals going missing, because escaped animals would cause false tells.

### Light is the rule

- **Lit buildings:** the creature never enters one.
- **Dark buildings aren't safe:** the creature can enter through a door, always banging on it first. Restoring power drives it out.
- **From day 6:** if everyone stays inside, it bangs the barn doors while circling to the generator and damaging it.

### Day deaths

By day the creature kills in only two cases:

1. **Alone, Corrupted and deep in the corn.** No teammate within earshot, Corrupted (always self-inflicted), and well inside the rows.
2. **Losing the trap race.** When a bear trap springs by day, the creature's signature starts approaching from a set distance.
   - **Pry free in time:** you live, Shaken.
   - **Fail:** you die.
   - **A teammate** shortens the pry.
   - **Tuning:** a solo, uncorrupted player who pries at once survives with a few seconds to spare.
   - **What loses it:** hesitating, being Corrupted (slower pry), or a trap deep in the corn.

**Bending:**
- The AI Director varies "deep", "earshot" and the race start distance a little each day, so the rule can't be measured exactly.
- It never adds conditions.
- A day death counts like a night one: out until dawn, and on the medical bill.

### The Corruption

One state with several causes and one cure. Corruption always comes from a player's choice, so black hands mean "you messed up."

**Causes:**
- touching creature leavings (dead crow, strange seed);
- picking up a stolen tool;
- leaving an item in the field at dusk (the item stays Corrupted until picked up);
- touching an unpicked moonflower.

**Effects, until washed or dawn:**
- sprint runs out 40% sooner, and prying is slower;
- footsteps are heard 50% further;
- the creature can follow your trail at night;
- more hallucinations (late season).

**Cue:** black, oily stains up the hands and sleeves, visible to all, plus a faint wet heartbeat in your audio.

**Cure:** about 10 seconds of noisy pumping at the well. That can draw the creature. All Corruption is washable. Being Corrupted twice changes nothing.

**Shaken** is separate. Jumpscares and surviving a trap race cause it. It shortens sprint for 60 seconds, never Corrupts, and wears off on its own.

### The AI Director

A tension meter in the spirit of Left 4 Dead. It cycles **build-up → peak → fade → relax**: it backs off after scares and pushes in after quiet stretches. Day, night and Harvest Moon each have their own profile. Presence events per player per phase are tunable.

- **Hunting** (movement, pursuit, trap placement) uses only the creature's senses and Corruption. The AI Director may nudge the creature toward a *region*, never a position.
- **Presentation** (lure targeting, scare timing, hallucinations) may use true positions.
- **The debug view** shows sensed and true positions side by side.

**Day arc:**

| Third | Activity |
|---|---|
| First | Calm: only evidence of last night's sabotage, so cozy mode lands |
| Middle | Low presence |
| Last | Builds toward dusk |

**Rules:**
- At most one big scare per player per day.
- Never two on the same player within 2 minutes.
- Players who haven't been scared are more likely targets.
- **Private events count toward both limits:** targeted lures, hallucinations and the wrong count.

**Town stand:** within 10 m of the town stand lures, scares and kills are less likely, never impossible (D-115). A player there still guards the farm, but is not safe. The clock still runs and nothing grows there.

---

## Voice Mimicry

The creature copies voices, so proximity chat is both the team's best tool and its biggest weakness.

### How it works

**Material:**
- live clips: short clips cut from each player's in-game speech (D-146);
- faked footsteps, watering cans and hoes, so quiet players still give it something.

**Who hears a lure:**
- **Day lures are targeted:** only the target hears them, and only with no teammate within about 15 m. They call a name in a teammate's voice, pulling the player toward armed traps.
- **Night and chase lures are world sounds:** "come here," "I found something," to pull players into the dark.
- **The Dawn Report** replays targeted lures to everyone.

**Habits:**
- **It favors the dead.** A dead friend calling from the corn is one of the strongest scares.
- **It rarely uses your own voice on you.**
- **Off players** (see Voice Settings) are never voiced by a stand-in, since a mismatched voice is a free tell. It fakes their footsteps and tools instead. Generic voices are used only for unattributed "stranger" calls.
- **Exact clips through day 3; spliced clips from day 4.**
- **Never tell players the line list is the whole pool.**

### How players fight back

- **Tells:**
  - each fake has at most one random giveaway: a faint echo, a wrong pitch, or a missing radio crackle;
  - about a third have none;
  - it always comes from a place the teammate can't be.
- **Passwords:** work, until the creature overhears them.
- **Silence:** gives it less to copy and hear, but makes teamwork harder.
- **Walkie-talkies:** craftable and unfakeable, carrying only real teammates. Limited batteries; static when the creature is near.
- **Lantern flicker:** see Death and Respawning.
- **Whistle:** one button, short cooldown, carries far.
  - Placed by 3D audio only, with no HUD marker.
  - Unfakeable, but the creature hears it too.
  - **Fallback:** if testing shows players can't place it, the whistler's lantern or hat flashes briefly.

### Staying on in-game voice

- **Why it's worth using:** in-game voice is 3D, so it's the only way to hear where friends are. Radios need it. Ghost voices exist only in it. Live clips come only from it, so a Discord team gives the creature only footsteps, tools and the stranger.
- **Lobby note:** the menu and lobby recommend in-game voice, with the line "The creature can't hear Discord, and you can't hear where your friends are."
- **Accepted trade-off:** Discord groups see through fakes more easily and coordinate silently at no cost. Traps, scares and the night still work. The AI Director never cheats to compensate.

### Voice settings

There's no forced consent screen. Each player picks a setting on their own machine and can change it any time.

| Setting | Effect |
|---|---|
| **Off** | Nothing recorded; the creature fakes only this player's footsteps and tools |
| **Live clips** (default, D-146) | Short clips of transmitted proximity speech are kept and can be replayed by the creature and in the Dawn Report |

- **Coverage:** the setting governs every replay: the creature, the Dawn Report (Off players appear as text plus sound) and streamer-safe mode.
- **Storage:** live clips stay in the owner's and peers' memory only, never on disk or in the host save. Off deletes them.
- **Recording light:** a "recording" lantern or tally light shows steadily while clips are being kept (D-146).
- **Review:** each clip can be reviewed and deleted from the pause menu.

### Live clips

The staged barn recording is dropped: the game cuts clips automatically from in-game speech (D-146).

- **Source:** transmitted speech from Live-clips players only, cut on the speaker's own machine during a match.
- **Length:** at most 3 seconds a clip.
- **Lifetime:** kept for that session, then deleted.
- **Review:** viewable and deletable from the pause menu.
- **No word filter.**

Group options: a "no live clips" lobby toggle, and streamer-safe mode (never replays live clips).

---

## Night Traps

Traps still armed in the morning become daytime chores, and weapons for the lures.

| Trap | Effect | Clearing |
|---|---|---|
| Bear trap | Pins your leg until you pry it open (a few seconds; a teammate can help). By day, starts the trap race. Afterwards you're 40% slower for 60 s. | Disarm with a tool, kneeling still for a few seconds |
| Pit | Shallow, hidden under stalks. You stumble and drop what you carry. | Fill with a shovel |
| Tripwire bells (from day 4) | Rusty bells strung low across rows. Stepping through loudly tells the creature where you are. | Cut it: cheap, but easy to miss |

- **Clues:** fresh dirt, bent stalks and glinting metal, visible only to players who look closely.
- **Spotting:** disarming is safer with a teammate watching, which pulls two players off farming.
- **Flags:**
  - Free, but each player has only a few out at once: a shared, honest "checked" or "trap here" map that needs no voice.
  - Any player can pull up any flag, freeing its slot for the player who placed it. A player who leaves takes their flags with them.
  - Placed flags show as small icons on the minimap, where each flag is now.
  - From day 5 the creature can move one flag a night.
- **Lure combo:** day lures pull players toward unchecked rows. Teams that split sweeps and share which rows are clear stay safe, but talking feeds the creature clips.
- **Lethality:** rarely lethal by day (only by losing the race); deadly at night, when a trapped player is easy prey.
- **Ramp-up:** trap counts rise over the season (see Ramp-Up); scaled counts round up.

### The tool shed

- **Pegboard:** bear traps hang on painted outlines. Every empty outline is a trap somewhere on the farm.
- **Lock (40 coins):** caps theft at one trap a night ("pried a board loose"). From day 5 the creature breaks it entirely.
- **Returning traps:** carrying disarmed traps back stops reuse.
  - Any trap not on the pegboard at nightfall is the creature's to take.
  - A trap kept in a building vanishes only if that building went dark; otherwise it turns up in the corn at dawn.

---

## Nights

Hiding is never fully safe or free, and there's always a reason to go out.

- **Generator:**
  - **Fuel:** it powers barn and farmhouse lights. Fuel runs low mid-night, and the drum by the shed is free and infinite; the walk is the cost.
  - **When it dies:** the sound carries across the farm and the creature comes to look.
  - **Running low:** it dims steadily and never flickers.
  - **Repairs:** fixing creature damage takes 1 scrap (one free each dawn, extra 15 coins).
  - **Left dead at dawn:** one extra trampled plot.
- **Unattended farm:** the longer nobody is outside, the more the creature wrecks.
- **Moonflowers:** the best crop, harvestable only in the dark, and they glow.
- **Length:** nights 1 to 6 are about 5 minutes. The Harvest Moon has no timer: it ends when the cart leaves the gate or everyone is dead.
  - **Hard cap:** 15 minutes. At the cap, the cart counts as out only if it's past the fields.

### The Harvest Moon

A three-act AI Director profile:

1. **Loading:** the Prize Pumpkin was moved to the barn at dusk. The team loads the festival cart in the lit barn. Then the generator fails and the barn goes dark and unsafe.
2. **The push:**
   - The cart carries a lantern, squeaks, and moves at a speed set by the number of pushers (no physics).
   - The creature knocks pushers off. Each stall lets it bite the pumpkin down one size, at most 2 bites per escort.
   - Ghosts can flicker the cart lantern.
3. **The gate run:** a guaranteed peak, then release as the cart rolls out.

---

## Jumpscares

The game never says the day is safe; players learn it, and doubt it. A day jumpscare causes:
- a ragdoll knockdown;
- dropped items;
- **Shaken** for 60 seconds.

Then the creature vanishes. Jumpscares never Corrupt.

**Scare moments:**
- **Disarm lunge:** stalks part and it lunges at a player kneeling at a trap.
- **The trap:** a player prying free looks up and sees it watching from the rows.
- **The shed:** it's inside, or the door slams behind you.
- **The whisper:** a teammate's voice right behind you while they're across the field.
- **Your own voice:** very rarely, your own voice whispers your name from the corn.
- **Fake-outs:** something bursts out of the corn, but it's only a crow.
- **Hallucinations (from day 5):** a private glimpse of it in the field. No knockdown. Corrupted players see them more.
- **The wrong count:** rarely, one farmer too many stands at the corn edge in a teammate's hat, then is gone.
- **The scarecrow moved:** a farm scarecrow is in a new spot each morning, facing the farmhouse. Never explained, never dangerous.

**Making them land:**
- Keep them rare, so quiet stretches make each hit harder.
- Build up first with silence, the insects cutting out, or a nearby voice.
- Make them cost something: dropped items and Shaken.
- Let the AI Director time them and randomize where, within its rules.
- Budget more for audio than for the creature's model.

---

## Death and Respawning

**Out until dawn:** the dead respawn at the next dawn.

**Medical bill** (day deaths count too):

| Players | First death a night | Each later death | Nightly cap |
|---|---|---|---|
| 4 | 25 | 50 | 120 |
| 3 | 20 | 40 | 96 |
| 2 | 15 | 30 | 72 |

- **Floor:** the bill never takes the bank below 4 coins (a turnip seed pack).
- **Deferred:** whatever it can't cover is added to the final payment, so death is never free.

### Ghosts

- **Spectating:** ghosts follow teammates.
  - Within about 20 m they see the creature only as a smeared silhouette; beyond that, only through animals and crows reacting.
  - They never see traps.
- **Lantern flicker:** a ghost can flicker any light near a living teammate: carried lantern, bulb, porch light, moonflower glow or cart lantern. It has a short cooldown.
  - **Nothing else in the game ever flickers a light,** whether the generator, ambience, weather or the lobby. It's the one unfakeable signal.
- **Rustling corn:** points at things, but the creature can fake it.
- **Static voices:** the living hear ghosts in proximity chat through heavy static.
- **The crow:** a ghost can possess one crow per night for 20 seconds, to scout and point. The creature ignores crows but also sends fake ones, so an odd crow is a hint, not proof.

### The dead-voice twist

- **More likely:** the creature uses the dead's voices more often.
- **Same static:** it runs them through the same static as real ghosts, including in targeted lures.
- **Heard by all:** night lures in a dead player's voice are world sounds.
- **The tiebreaker:** a static voice with a flicker is a real teammate; without one, it may be the creature.

---

## Daytime Threats

The creature has a daily disturbance budget, rising over the season. Day 1 might bring one broken fence; by day 6 the whole pool is in play.

**Sabotage pool:**
- **Trampled crops:** one plot a night, two if nobody was outside, plus one if the generator was left dead.
- **Stolen tools:** a tool turns up somewhere creepy, often beside an armed trap. Picking it up Corrupts you.
- **Broken fences:** animals escape and must be rounded up far from the group.

**Setting up the night:**
- **Corruption sources:** dead crows and strange seeds.
- **Clues:** footprints, claw marks and moved scarecrows hint where it will hunt.

**Fairness:**
- Daytime harm costs time or money and is only fatal through the player's own risks.
- Every disturbance has a fix (repair, round up, wash).

**The trade-off:** time spent fixing makes the night safer but comes out of farming.

---

## Crops

"Grows in N days" means ready on the Nth dawn after planting.

| Crop | Grows in | Seed | Sells | Profit | Notes |
|---|---|---|---|---|---|
| Turnips | 1 day | 4 | 10 | 6 | Safe, steady money |
| Pumpkins | 2 days | 10 | 28 | 18 | Unlock at dawn 4, as the first-payment reward |
| Moonflowers | same night | 25 | 60 | 35 | Unlock day 3. Planted by day, harvested that night, wilted by dawn. They glow. |

- **Plots:** 16 field plots at the start, up to 24 with upgrades at 4 players; above 4 players the field grows by 4 plots per extra player (20 at 5 players, 24 at 6; up to 28 and 32 with upgrades), split into two distant fields (one by the barn, one by the shipping crate) with corn between them.
- **Labor:** planting, watering and harvesting are each a hold of a few seconds, plus walking. Labor is measured in seconds, and plots per player are derived from that (starting estimate about 6).
- **Moonflower bed:** 1 plot per player.
  - The best crop per plot and a big share of income, by design, to push people outside at night.
  - An unpicked moonflower at dawn becomes a Corruption object; its plot can't be replanted until someone clears it.
- **End of season:** crops still in the ground at the final dawn sell at 50%.
- **Corn** can't be planted, cut or sold.

### The Prize Pumpkin

One giant pumpkin gives the season a face; friends will name it.

- **Placement:** planted day 1, at least 30 m from any building's door, between the farmhouse and the first corn strip.
- **Watering:** it grows every day it's watered and shrinks or rots on days it isn't.
- **Guarding:** Giant also needs a guard, outdoors within 20 m for at least 60 seconds, on at least 2 of nights 1 to 6.
  - Time inside a lit doorway's light doesn't count.
  - Lanterns are allowed, at the guard's risk.
- **Gnawing:** from day 3 it's on the sabotage list. The creature gnaws it on any night nobody is within 20 m, dropping it one size.
- **Finale:** escorted on the festival cart (see The Harvest Moon). Its size sets its festival payout.

---

## Season and Numbers

7 days. Night 7 is the Harvest Moon. The team starts with 60 coins.

### Debt and payments

| Players | Total debt | First payment (dawn after night 3) | Final payment (dawn after Harvest Moon) |
|---|---|---|---|
| 4 | 1,313 | 258 | 1,055 |
| 3 | 1,105 | 217 | 888 |
| 2 | 767 | 150 | 617 |

- **Early payment:** allowed at any dawn.
- **Final payment:** the festival payout counts toward it. Foreclosure penalties and deferred medical bills are added to it.
- **Tuning target:** a median team needs a Large pumpkin to make the final payment.

**Winning and losing:**
- **Win:** make the final payment, and get the cart out the gate with at least one player alive.
- **Foreclosure Notice:** a missed first payment isn't a loss. The shortfall × 1.5 is added to the final payment, and the bank seizes one upgrade or 2 plots (its choice).
- **Lose:** miss the final payment, or everyone dies on the Harvest Moon before the cart is out. Wipes on earlier nights only cost bills and damage.

### Prize Pumpkin payout

| Size | Requirement | 4p | 3p | 2p |
|---|---|---|---|---|
| Giant | Watered all 7 days and guarded 2 nights | 250 | 200 | 150 |
| Large | Watered 5 to 7 days | 150 | 120 | 90 |
| Medium | Watered 3 to 4 days | 75 | 60 | 45 |
| Sad | Watered 0 to 2 days | 20 | 16 | 12 |

The size drops one per gnawed night and one per escort bite (at most 2 bites). The festival laughs at a Sad pumpkin.

### Economy check

- **Perfect start** (no deaths, turnips on every tendable plot, moonflowers from day 3): 322 coins at 4p and 194 at 2p, about 25% over the first payment. Sabotage and a death or two eat most of that.
- **Chore time:** planting 16 of 24 tendable plots (8 of 12 at 2p) leaves about a third of everyone's time for chores.

### Season simulator

Phase 4 is gated on the simulator. It runs 2p, 3p and 4p with every rule here, including purchases.

**The median team:**
- plays greedily, keeping a third of its time for chores;
- takes scheduled sabotage plus the trample rule;
- has one death on each of 2 nights;
- buys plots when the store offers them;
- delivers a Large pumpkin.

| Target | Value |
|---|---|
| Median team clears the first payment | about 85% of runs |
| Median team clears the final payment | 55–70% of runs |
| Spread across player counts | at most 10 points |

**Playtest check:** live logs must land within 15 points of the sim before the numbers are frozen.

### Ramp-up (4 players)

Trap counts and the disturbance budget scale to 80% at 3 players and 60% at 2, rounded up. Payments and medical bills scale to 85% at 3 players, 59% at 2 and 101% at 4 (season simulator, D-079; retuned from live logs). Above 4 everything scales up the same way, 120% at 5 and 140% at 6 (placeholder until the season simulator sets them).

| Day | Disturbances | Traps that night | Voice | New |
|---|---|---|---|---|
| 1 | 1 | 2 bear, 1 pit | Exact | Turnips; Prize Pumpkin planted |
| 2 | 1 | 2 bear, 2 pits | Exact | |
| 3 | 2 | 3 bear, 2 pits | Exact | Moonflowers; Corruption sources; pumpkin can be damaged; first payment at dawn |
| 4 | 2 | 3 bear, 2 pits, 1 bell | Spliced | Pumpkins; tripwire bells |
| 5 | 3 | 4 bear, 3 pits, 1 bell | Spliced | Lock-breaking; hallucinations; flag-moving |
| 6 | 3 | 5 bear, 3 pits, 2 bells | Spliced | Attacks the light if everyone stays in |
| 7 | 4 | Hunts all night | Spliced | Cart push; final payment at dawn |

### Joining and leaving

- **Joining:** new players join only in the lobby, before the host starts the match.
- **No mid-session joins:** once the match starts, the host refuses anyone who is not on the match roster.
- **Rejoining:** a roster player who drops (crash or disconnect) can reconnect to the same session. They come back as a ghost at once and get their own farmer back at the next dawn, keeping their role (and imposter status in Imposter mode).
  - **Rejoin prompt:** after a crash or disconnect, the next launch opens with "Rejoin your last match?" and connects in one click. A clean "Leave" or the end of the match clears it.
  - **Join code fallback:** the lobby and pause menu show the host's join code. If the prompt fails, a teammate reads the code out and the dropped player enters it on the Join screen (an IP still works too).
  - **Welcome back:** the rejoining player sees a line mocking them for crashing. Each player sees all 50 once, in random order, before any repeats, and a new round never opens with the line they saw last. Lines come from 50 in `data/rejoin_lines.json`, such as "Haha, you crashed.", "Most people die to the creature. You died to Windows." or "Crashing doesn't reset the debt. Nice try."
- **Loading a save:** a saved season opens a lobby only to the players from that season.
- **Leaving:** a player who drops counts as absent from the next dawn. Their character stays as an idle farmhand that doesn't count.

**Debt formula:**
1. Each of the 7 days carries 1/7 of 1,300, scaled by that dawn's headcount (payments: 101/85/59%, D-079) and fixed once the dawn begins.
2. **Total debt** is the sum of all 7 shares. Past days use recorded headcount; future days use the current headcount.
3. **Still owed** is the total debt, minus payments made, plus foreclosure penalties and deferred bills. Those additions never rescale.
4. **Split:** if the first payment is still ahead, it takes 255/1,300 of the total debt (rounded); the final takes the rest.
5. **Everything else scales too:** the moonflower bed, bills, traps and disturbances follow headcount.

**Example:** 4p with one drop before dawn 2 gives 187.6 + 6 × 157.9 = 1,135 total, so a first payment of 223.

**Rules:**
- Payments lock when their dawn begins, so quitting saves nothing.
- **One player left:** the game saves and pauses at that dawn ("Waiting for a farmhand") until a teammate from the roster reconnects. There's no solo play.

### Saving

- **Dawn saves:** every dawn, including foreclosure state.
- **Portable:** any player from the season can host the save.
- **Host leaves:** the session ends with a "host left" card and resumes from the last dawn save. There's no host migration.
- **Short season:** 3 days, with a faster-growing Prize Pumpkin. Its numbers are set with the simulator.

### Next season

- **A campaign is 3 seasons.** Winning season 3 pays the farm off (D-155).
- **Carry over:** upgrades and plots, plus spare coins at 25% as savings, capped at 60 coins (D-162).
- **The debt grows.**
- **The creature gains one new trait,** such as better tool mimicry or more pits.
- **A new season resets** crops, the Prize Pumpkin, Corruption, deaths, the medical bill, traps, pegboard stock,
  fuel, flags, the day count and payments. Roles can be picked again and a new body is picked.
- **A lost season** (final payment missed) ends the campaign and carries nothing. A missed first payment is
  not a loss. Numbers: doc 02 section 21.

### Store

Bought by the shipping crate. "sim" means the price is set with the simulator before Phase 4.

| Item | Price | Notes |
|---|---|---|
| Shed lock | 40 | Caps theft at one a night; broken from day 5 |
| Scrap | 15 | Generator repair; one free each dawn |
| Quiet watering can | sim | Slower, heard less far |
| Walkie-talkies, batteries | sim | |
| Brighter lanterns | sim | |
| More scarecrows | sim | |
| New plots (to 24; to 28 at 5 players, 32 at 6) | sim | |
| Flare gun | sim | One shot, refilled each dawn; scares the creature off for 30 s; anyone can carry it |
| Flare shell | placeholder | Needs the flare gun; loads one shot, up to the gun's capacity; not sold while the gun is full (D-147) |
| Cosmetic hats, overalls | sim | Phase 5, bought once the debt is paid |

---

## Farming Meets Horror

- **Noise:** fast tools are loud and quiet tools are slow; your voice counts too.
- **Light:** lanterns help work but make you visible.
- **Risk vs reward:** moonflowers pay most but mean dark, far walks.
- **Defense:** fences and scarecrows build up like light tower defense.
- **Splitting up:** watering, sweeping, selling and guarding can't all happen together.

## Roles (optional, best at 4 players)

| Role | Perk |
|---|---|
| Farmer | +1 crop every 5th harvest |
| Rancher | Handles animals, the early warning system |
| Mechanic | Repairs and refuels faster |
| Tracker | Spots trap clues more easily and disarms faster |
| Carpenter (placeholder) | Builds fences and scarecrows faster or cheaper, then repairs them; machines stay the Mechanic's |
| Medic (placeholder) | Frees a teammate from a bear trap faster; cuts the medical bill for deaths they were near |
| Night Owl (placeholder) | Quieter at night (steps, tools, crouch) and picks moonflowers faster |
| Radio Operator (placeholder) | Walkie-talkie reaches further and its batteries last longer; their voice carries too, so lures favor them |
| Warden (placeholder) | More flare shots and a faster refill. A hit only drives the creature into Retreat, never harms it; the shot is the loudest noise on the farm and gives the Warden's position away |
| Medium (placeholder) | Hears dead teammates' ghost voices through less static. Never tells a real ghost voice from the creature's fake; the flicker stays the only tiebreaker |

There are more roles than players, so each player picks one they want and no team has every role. Roles
never let anyone harm the creature or see it clearly ("Glimpsed, never seen"). No role sides with the
creature in the normal game: honest signals must stay honest, so the only liar on the farm is the
creature. The one exception is the opt-in Imposter mode below.

### Imposter mode (opt-in, placeholder, after DD Phase 4)

A lobby toggle, off by default, for groups who want betrayal on top of the creature. It needs at least
4 players (D-161).
- **The toggle means "maybe", not "yes".** With it on, each season has a placeholder 50% chance of
  one imposter and 50% of none. Nobody knows which, so the toggle alone proves nothing.
- **The imposter keeps a real role.** Everyone picks roles in the lobby first; the host's game then
  secretly picks the imposter at match start. The imposter's role and perks work as normal, so the
  role list gives nothing away.
- **The imposter wins only if the final payment is missed** (D-155). The first-payment Foreclosure
  Notice and a Harvest Moon wipe are not imposter wins. Everyone else wins as normal.
- **The imposter lies, never kills.** They can raise false signals (flags, whistle, pegboard marks)
  and leave gates or doors open. Deaths still come from the creature. Exact kit is set by the Game
  Designer.
- The Dawn Report reveals the imposter, or that there was none, at the end of the season.
- **Hidden dev setting (CEO's PC only):** forces an imposter this season and picks who it is. It
  never shows in any menu. It works only when the host machine's `OS.get_unique_id()` hash matches
  one baked into the game, so `--dev` or a debug build on another PC does not unlock it. Peers see
  nothing different.

### Dev toys (CEO's PC only, placeholder, after DD Phase 4)

Hidden joke commands, behind the same machine-hash gate as the imposter dev setting. No menu shows
them. The host runs them and every peer sees the result.
- **Shrink:** every player shrinks to a quarter size for 60 seconds, with squeaky voices.
- **Disco:** a mirror ball drops over the farm, music plays, and players and the creature dance until
  it ends. The creature is fully visible while it dances.
- **Nuke:** a slow warm glow (never a white flash), a mushroom cloud over the corn, and every player and the creature ragdoll
  outward. Nobody dies and nothing is destroyed.
- **Low gravity:** jumps float for 60 seconds.
- **Big heads:** everyone's head, the creature's included, grows to three times size.
- **Confetti harvest:** every harvest pops confetti and a kazoo for the rest of the day.
- **Rubber chicken:** every tool in the host's hands squeaks like a rubber chicken.

Rules: toys never touch the save, coins, debt or deaths. A session that used one is marked `dev_toy`
in the logs, so playtest measures skip it. Disco lights sweep colors and never flicker on and off,
so the ghost flicker stays the one flicker in the game.

This mode bends two pillars on purpose: "Honest signals cost something" (the imposter's signals lie)
and the creature as the only liar. The normal game stays as written.
 Placeholder perks are
set before roles are built.

**Picking a role:** each player picks a role in the menu lobby before the match starts.
- A role card per role shows its perk; a taken role is greyed out, so no two players share one.
- "No role" is always open. Players can change picks until the host starts the match.
- Roles are locked for the season once the match starts.
- A player who reconnects keeps the role they had.
- Bots take no role (placeholder).

The flare gun is a store item, not a role; anyone can carry one, and the Warden is simply better with it. Below 4 players, roles are optional, and no role is required to win.

---

## Fun With Friends

### Dawn Report

A skippable newspaper card each dawn. It lists cash-in, bill and payment in order, then:
- **Best Impression:** the best lure, replayed in the creature's voice (text for Off players). Targeted lures are revealed here.
- **Most Wanted:** who was chased most.
- **Cause of Death:** small-town obituaries.
- **Hero of the Night:** whoever refueled, guarded the pumpkin, or freed a teammate.

Replays follow each player's voice setting.

### Season Awards

Every player gets at least one award, such as:
- most traps disarmed;
- most times fooled by a voice;
- most coins earned;
- "Barn Goblin" for the most time hiding.

### Emotes and physical comedy

- **Emotes:** wave, point, shrug, scream.
- **Ragdoll knockdowns:** funny right after scary.
- **Carrying:** players can carry a downed or slowed teammate a short way, slowly and noisily.

### Onboarding

- **Days 1 to 3 are the tutorial,** and the ramp-up table is the curriculum.
- **One introduction per verb:** each new verb gets one in-world introduction, like a shed-door note or the dusk bell.
- **Never say the day is safe.**

### Difficulty and group settings

| Setting | Changes |
|---|---|
| Easy | Fewer traps, gentler bills |
| Normal | |
| Nightmare | Less fuel. Day deaths more likely only through wider distance bends. No voice tells, but the whistle stays honest and the wrong-place tell always remains. |

Group options: the "no live clips" toggle, streamer-safe mode and Quirks.

### Quirks (opt-in group option, placeholder, after DD Phase 4)

With Quirks on, every player starts the season with one random quirk: a mental disorder, played
for laughs, that is half handicap, half joke. Quirks use real disorder names (D-052). Each player
sees their own quirk; others learn it by watching. The season-end Dawn Report reveals every quirk (D-161).
- **Anxiety disorder:** Shaken lasts twice as long, but sprint refills faster.
- **Nyctophobia:** their lantern lights half as far.
- **ADHD:** their voice carries 50% further, so lures favour them.
- **Paranoia:** now and then they alone hear a footstep behind them that isn't there.
- **Schizophrenia:** private hallucinations start on day 1 instead of day 5.
- **Dyspraxia:** a jumpscare drops everything they carry, not just the held item.
- **Hoarding disorder:** one extra carry slot, but they walk 10% slower.
- **Narcolepsy:** they are the last to get a body at dawn, a few seconds after everyone else.
- **Grandiose delusions:** bear traps take a little longer to snap on them.
- **OCD:** walking under the scarecrow's gaze makes them Shaken.

Quirks never let anyone see the creature clearly, harm it, or fake an honest signal. Numbers are
placeholders for the Game Designer.

### Photosensitivity safety

A player in the CEO's group is prone to seizures, so these rules hold in every mode, dev toys included.
They follow WCAG 2.3.1 (no more than 3 flashes per second) and the Harding broadcast test rules.
- **Never more than 3 flashes in any second,** anywhere on screen.
- **No full-screen white or red flash.** No saturated red flashing at all.
- **No strobe, lightning, or fast-moving high-contrast stripes or checks.**
- **The ghost flicker is slowed to stay safe:** 2 dips per second, dimming to 30% rather than off, in
  cold blue. Doc 07 section 4.3 holds the numbers.
- **First launch shows a photosensitivity warning** and offers safe mode before the main menu.

**Safe mode** (setting `photosensitive_safe`, per player, off by default, stored on each player's own
PC like the other settings). It changes only that player's screen:
- the ghost flicker becomes one slow cold-blue dim and return over 1 second, with no steps; cold blue
  still marks it as a ghost, so it stays an honest signal;
- the cut to black on a lunge fades over 0.5 seconds instead of cutting;
- the whistle fallback flash becomes a steady 1-second glow;
- dev toys show no disco lights and no nuke glow.

### Comfort and convenience settings

Per player, stored on each player's own PC (D-047):
- **Camera shake and head bob:** one slider from 100% to off. At off, the knockdown camera stays level
  instead of tumbling with the ragdoll.
- **Centre dot:** an optional small dot in the middle of the screen. It is not a marker and points at
  nothing.
- **Per-player voice volume and mute:** set from the pause menu roster. Muting a player also mutes
  the creature's replays of that player's voice for you, so it never exposes a fake.
- **Toggle holds:** press once to start a hold action (disarm, pry, pour) and again to stop. Hold
  times do not change.
- **Toggle sprint** and **invert mouse Y.**
- **Menu text size.**

---

## Build Plan

Only move on when the current phase is fun. Each "done when" is checked in at least 2 sessions, with at least one tester who hasn't read this doc, plus a measure from the logs.

**Between phases:**
1. Read the logs and notes.
2. Add new problems to Open Issues.
3. Settle what the next phase depends on, and update the affected sections.
4. Start only when nothing it depends on is open.

**Phase 1 (prototype):**
- **First:** voice between two machines on different home networks, joining through UPnP and a join code.
- **Then:**
  - one small field, the shed and the barn;
  - one day and one night, 2 players, proximity chat;
  - turnips (plant, water, sell) with hold times logged;
  - a noisy watering can, one generator run;
  - crouch and go-still;
  - three ambience layers from a scripted creature state (Lurk, Stalk, Chase);
  - the creature wandering and chasing by sound;
  - scripted traps and pits, generic voice lines from the corn;
  - the spatial audio test.
- **Not yet:** the AI Director.
- **Done when:** the day feels safe, the night tense, and at least 30% of lures make the target walk toward them.

**Phase 2:**
- voice settings and recorded voices replayed by the creature (live clips since D-146; the staged barn recording was built here and dropped);
- pegboard theft;
- death, dawn respawn and medical bills;
- two fields with corn between them;
- up to 4 players, with 5 and 6 supported and scaled.
- **Done when:** a friend's recorded voice fools someone, and trap sweeps feel worth doing.

**Phase 3:**
- dead players' voices favored;
- the AI Director, day arc and jumpscares;
- Corruption and Shaken;
- ghosts with flicker and crow;
- whistle, flags and the Dawn Report.
- **Done when:** the dead stay engaged, the living argue over a static voice, and someone laughs at the Dawn Report.

**Phase 4:**
- **First:** the simulator hits its targets.
- **Then:**
  - the full 7-day season, crops, economy and Prize Pumpkin;
  - upgrades, roles and payments;
  - foreclosure, saving, joining and leaving;
  - the short season and the Harvest Moon.
- **Done when:** teams sometimes win and sometimes lose, and the logs land within 15 points of the sim.

**Phase 5 (later):**
- spliced clips from live speech;
- next season;
- cosmetics.
- **Done when:** the CEO says it is done.

Live clips moved forward from Phase 5 and replaced the barn recording (D-146).

**Fake it first:** scripted traps and timers stand in for smart AI until the loop is proven.

---

## Engine and Tech: Godot 4

Free and open source (MIT), with no royalties.

**Distribution:** exported desktop builds shared directly with friends. No Steam or store page.

### Networking

- **Transport:** Godot's built-in ENet (`ENetMultiplayerPeer`), with no third-party services or servers.
- **Hosting:** the host's game opens its port automatically with Godot's built-in `UPNP` and reads its public address.
- **Joining:** the host shares a short join code that encodes their address and port. A friend enters the code, or types an IP directly.
- **When UPnP fails:**
  - the host forwards one port by hand (the game shows which one);
  - or the group uses a free VPN such as Tailscale or ZeroTier and joins by VPN IP.
  - The host screen shows clearly whether UPnP worked.
- **Authority:**
  - **Clients own** their movement and camera.
  - **The host owns** the creature, AI Director, traps, pegboard, economy (no client-side selling), Corruption, deaths and the cart, and validates every interaction.
- **Close calls:** lag-dependent lunges, kills and doorway reaches go to the victim. Lag never kills.

### Voice

- **Codec and transport:** mic audio is captured with `AudioEffectCapture`, compressed with Opus (via a GDExtension, since Godot has no built-in Opus) and sent over ENet. The host relays each speaker to the others.
- **Test input:** the voice input can be fed from WAV files for testing.
- **Mic mode:** open mic with voice activity detection is the default; push-to-talk is an option and doubles as stealth.
- **Positional voice:** each player's voice plays from an `AudioStreamPlayer3D` on their character.
- **The creature's fakes:** played from the creature through the same voice chain, so they don't sound cleaner. Fakes of the dead use the ghost static chain.
- **Lures:** clips are sent to every peer at session start, so a lure is a host message ("play clip X at P for player Y"), not streamed audio.
- **Weak localization:** Godot's stock 3D audio is weak front-to-back. If the Phase 1 test fails, evaluate the Steam Audio GDExtension (Valve's free spatial-audio library, which doesn't need Steam), or add per-source occlusion and reverb.

---

## Testing

- **Local multiplayer:** Debug > Customize Run Instances runs 2 to 4 copies over local ENet.
- **Fake input:** a mic-from-WAV input per copy, plus simulated latency and packet loss.
- **Bot teammates:** walk, do chores, play clips and can be killed.
- **Voices:** your own recordings, plus consenting friends.
- **Logs:** deaths, sprung traps, lure results, hold and chore times, money, and time spent inside at night. The Dawn Report uses the same logs.
- **"A lure worked":** the target moved more than 10 m toward the source within 8 seconds. Used for logs, the Dawn Report, the AI Director and the Phase 1 gate.
- **Trap race:** log whether a solo, uncorrupted player who pries at once survives.
- **Spatial audio (Phase 1 gate):** with headphones, players must be able to place a voice and a whistle at 10, 30 and 60 m.
- **Debug view:** a top-down map of the creature, its state, sensed versus true positions, the tension meter, traps and players.
- **Group playtests:** at the end of each phase, logged and (with consent) recorded. Screams and laughs are the design working; bored silence is what to fix.

---

## Open Issues

1. **Scope is large.** Voice, mimicry, trap AI, the AI Director, economy and netcode, all from scratch. Voice and connecting over the internet are the biggest risks, so they come first. If UPnP fails for too many friends, reconsider a relay (for example Epic Online Services, or our own server).
2. **Numbers are untested.** Most store prices are still open. The simulator gates Phase 4.
3. **Can players place sounds by ear?** The whistle, the wrong-place tell and Stalk direction depend on it. Tested in Phase 1; fixes are better spatial audio or the whistle flash.
4. **Do the four bodies feel different enough?** If not, give each one small quirk (the husk quieter in corn, the boar louder but faster). Check after Phase 3.

## Next Steps

1. Set up the Godot project in this repo.
2. Get Opus voice over ENet working between two machines on different home networks, connected through UPnP and a join code.
3. Build Phase 1 and playtest it.
