# Farming Horror Game: Design Doc 01

A multiplayer game where friends grow and farm crops while being hunted. The combo works because farming naturally creates the tension horror needs: crops tie you to specific spots, the work is noisy and repetitive, and you can't finish it all with everyone huddled together.

**The pitch:** a farm under siege. Traps, crops and the day/night economy are the hook; voice mimicry supports it rather than leading it, since other games already sell AI voice copying.

**Format:** 2 to 4 player online co-op. The monster is AI-controlled, so every player is on the same side against it. The creature and the money targets scale with the number of players.

**Status:** Starting from scratch. Nothing is built yet. This doc is the first design pass, reviewed and revised.

---

## How to Read This Doc

This is the original concept with a design review folded in. Anything marked **[NEW]** is an addition from the review, and anything marked **[CHANGED]** replaces something in the original concept. Everything unmarked is the original design, kept as is.

---

## Design Review: Summary

### What's already working

- **The day/night contrast is the right hook.** Cozy farming makes players care; the night threatens what they built. That's the same engine that makes Don't Starve, Lethal Company and Phasmophobia sessions memorable.
- **The creature sets traps that become tomorrow's chores.** This is the best idea in the doc. It turns the night into the next day's level design and links the two halves of the loop.
- **The pegboard.** One glance tells you how many traps are out. Clear, physical, diegetic information is exactly what horror games need.
- **The lantern flicker.** A single signal the monster can't fake gives the dead a real job and gives the living a reason to argue. Arguing is fun.
- **Day deaths come only from player mistakes.** Fair, and it keeps the day from being a slog.
- **The Director.** Pacing is what separates scary from exhausting.

### The ten changes that matter most

1. **Fix the economy before anything else** (first payment is unreachable, moonflowers carry everything, scaling runs backwards). See Season and Numbers.
2. **Merge marks, scent and wounds into one "Tainted" state** with one clear visual cue. See The Taint.
3. **The lantern flicker works on any light**, not just carried lanterns. See Death and Respawning.
4. **Make day deaths fuzzy**: the Director can bend the rule. See Day Deaths.
5. **Replace the festival quota with the Prize Pumpkin**, one giant pumpkin the team grows all season and carts out on the last night. See The Prize Pumpkin.
6. **The Harvest Moon ends when the cart is out**, not on a timer. See Nights.
7. **Add the Dawn Report**, a replay of the creature's best lures and the funniest deaths. This is the single biggest "fun with friends" addition. See Making It Fun With Friends.
8. **Settle the fourth role:** Tracker is the role, the flare gun becomes a shed item anyone can carry. See Roles.
9. **Cut scope for the first build:** live voice clips move to a later phase and lobby lines are recorded with in-game acting prompts. See Build Plan.
10. **Plan voice chat from day one**, since Godot has no built-in voice and the whole design depends on it. See Engine and Tech.

---

## The Core Loop

**Day (safe-ish, about 8 to 10 minutes):** Players glance at the shed pegboard, sweep for and disarm traps left overnight, plant, water, harvest, fix what the creature broke, and sell at the town stand. This is the cozy part, and it's where you build up resources and stakes.

**Dusk (warning phase, about 1 minute):** The light fades, animals go quiet, and players rush to finish chores, get valuable crops harvested, and top up the generator. **[NEW]** The church bell in town rings three times across the fields, so everyone knows dusk has started wherever they are.

**Night (the hunt, about 5 minutes):** The creature comes out of the corn, hunts, and sets traps for the next day. Moonflowers can only be harvested at night and are worth far more, and the generator needs refueling partway through. Nobody can sit safely in the barn all night (see Nights).

**Dawn:** Survivors cash in. Anyone who died loses what they were carrying, the medical bill is paid, and the farm takes damage where the creature roamed, more if nobody was outside to stop it. After a full wipe the creature had the farm to itself: farm damage is doubled and it sets extra traps for the morning. **[NEW]** Dawn also plays the Dawn Report (see Making It Fun With Friends).

The contrast between peaceful daytime farming and terrifying nights is the hook. The cozy part makes players care, and the horror part threatens what they built.

---

## The Creature: Something in the Corn

You never see it clearly. It lives in the wild corn that rings the farm, a field players can't cut down or farm, so it always has somewhere to hide. Ragged strips of corn reach in toward the buildings, and rows of it stand between the barn and the two fields, so every errand is a walk through its hunting ground. It hunts with two tools: players' own voices and the traps it sets at night.

**What it looks like changes each run.** The host's game picks one of four bodies at random, so nobody knows what they are looking for:

- a gaunt, hunched thing in dark hide;
- a scarecrow in a ragged coat with a stitched sack head and ember eyes;
- a chained boar brute with tusks and an iron collar;
- a walking corn husk, all stalks and peeled leaves round a glowing heart, that all but vanishes in the corn.

The look is only skin: they all hunt the same way.

**[NEW] Each body gets one sound signature.** The look is hidden, so the sound is how players learn which one they have this season: the gaunt thing clicks, the scarecrow's coat flaps, the boar's chain drags, the husk rustles dry. Players will start saying "it's the chain one this time," which is exactly the kind of shared vocabulary friend groups love. Behavior stays identical.

**What players see of it:** by day only parts and motion: a head above the corn, an arm, stalks parting. A clear full view comes only at night during a chase, in the dark, and never for more than a second. Lunges cut to black or a knockdown before it is in full view, and the stare and hallucinations are distant silhouettes.

### How It Hunts

- **Hearing:** Its main sense. Tools, footsteps, doors and talking all make noise, and louder sounds carry further.
- **Sight:** Short range only. It spots players carrying light or standing in open ground, but tall corn blocks its view just as it blocks yours.
- **[CHANGED] Taint:** It can track Tainted players from much further away (see The Taint). This replaces the separate scent, mark and wound-trail rules.

### Behavior States

- **Lurk:** Moves through the corn, sets traps at night, and gathers voice clips.
- **Lure:** Plays a mimicked voice or sound from cover, usually near an armed trap or a player who is alone.
- **Stalk:** Follows one player from cover, getting closer. Animals nearby go quiet.
- **Chase (night, or a day kill):** Breaks cover and runs a player down. It loses them if they reach a lit building or break its line of sight for a few seconds.
- **Retreat:** After a jumpscare, a kill, or a hit from a flare, it pulls back into the corn for a while.
- **By day:** It Lurks, Lures, Stalks and jumpscares, and kills only in the rare cases below (see Day Deaths).

**[NEW] Readable states.** Every state needs an audio tell players can learn, or the AI will feel random:

| State | What players notice |
|---|---|
| Lurk | Normal ambience, birds, animals |
| Lure | A voice or tool sound from the corn |
| Stalk | Animals go silent, the wind drops, crows lift off the field |
| Chase | A hard music sting and the body's sound signature, loud |
| Retreat | Crows settle, animals start making noise again |

Learning to "hear the farm go quiet" is the skill that makes veterans feel smart.

### Day Deaths

Deaths by day are rare, and always the player's own mistake. The creature can kill by day only when one of these is true:

- A player is **alone, Tainted and deep in the corn**: no teammate within earshot, Tainted, and well inside the rows rather than at the edge.
- A player is **stuck in a bear trap with nobody nearby**: no teammate close enough to help pry them free.

**[CHANGED] The Director can bend this rule.** How deep "deep in the corn" is and how far "earshot" reaches shift a little each day, so the rule can't be measured. Very rarely, after a long quiet stretch, the Director may allow a kill when only two of the three conditions hold. A checklist this exact would be posted online within a week of launch, and the day would go from "never called safe" to provably safe. The fear lives in what players aren't sure of.

Almost nobody will die by day, but everyone will know it can happen, and that is enough. A day death counts like a night one: out until dawn and on the medical bill.

### [NEW] The Taint

The original concept had three systems doing the same job: marks, scent from dropped items, and the wound trail. Players can't tell them apart; they just feel "it found me." They are now one state, **Tainted**, with several causes and one cure.

**Causes:**
- Touching something the creature left behind (a dead crow, a strange seed, a stolen tool).
- Being jumpscared.
- Leaving a dropped item in the field at dusk (the item stays Tainted until picked up).

**Effects (until dawn or until cured):**
- Sprint runs out 40% sooner.
- Footsteps are heard 50% further.
- At night the creature can follow your trail.
- Hallucinations happen to you more often (late season).

**The cue:** Black, oily stains spread up your character's hands and sleeves, visible to everyone, plus a faint wet heartbeat in your own audio. Friends can see who is Tainted and will absolutely give them grief for it.

**The cure:** Wash at the well (about 10 seconds of noisy pumping, which can draw the creature). Being jumpscared can't be washed off; it wears off at dawn.

Being Tainted twice changes nothing, so one bad day doesn't pile up.

### The Director

A simple tension meter decides how aggressive the creature is from moment to moment, in the spirit of Left 4 Dead's AI Director. After a scare or a chase the meter drops and the creature backs off; after a long quiet stretch it rises and the creature pushes in. This keeps scares spaced out and makes the quiet stretches part of the design rather than downtime.

**[NEW] Director rules of thumb:**
- Never two big scares on the same player within 2 minutes.
- Spread attention: a player who hasn't been scared all day is more likely to be targeted next.
- Never scare during the first 60 seconds of a day; let players settle back into cozy mode first so the contrast lands.

---

## Signature Mechanic: Voice Mimicry

The creature can copy players' voices. Proximity voice chat becomes both the team's best tool and its biggest weakness, because nobody can fully trust what they hear.

### How It Works

- **It listens:** The creature uses each player's lobby voice lines and, in a later phase, short clips of what they say over proximity chat. The more someone talks, the more material it has.
- **It copies sounds too:** It can fake a teammate's footsteps, a watering can, or a hoe, so quiet players still give it something to use.
- **By day:** It calls a player's name from the corn or the treeline in a teammate's voice, luring people away from the group and toward armed traps.
- **At night:** It replays phrases like "come here" or "I found something" to pull players into the dark, then hunts them.
- **It favors the dead:** Once a player dies, the creature is more likely to use that player's voice. Hearing a dead friend call from the corn is one of the game's strongest scares.
- **Rarely your own voice:** The chance of the creature using a player's own voice on that same player is kept low, since they would know it isn't them talking.
- **It gets better:** Early in the season it only plays back exact clips. From day 4 it mixes clips together, so the lines sound more natural and harder to spot.

### How Players Fight Back

- **Tells:** Each mimicked voice has at most one small giveaway, picked at random (a faint echo, a slightly wrong pitch, a missing radio crackle), and about a third have none. The one clue that never goes away is the voice coming from somewhere the teammate can't be.
- **Passwords:** Teams can agree on a code word, but the creature can pick that up too if someone says it near it.
- **Staying quiet:** Talking less gives it less to copy, but it also makes teamwork harder.
- **Walkie-talkies:** A craftable radio that the creature can't fake, but it runs on limited batteries and fills with static when the creature is near, so "was that you?" doesn't always get through.
- **The lantern flicker:** A dead teammate's one signal the creature can never fake (see Death and Respawning).
- **[NEW] The whistle:** Every player can whistle (one button, short cooldown). A whistle carries far and shows a small marker for one second at the whistler's real position to teammates who hear it. The creature can't fake a whistle, but it hears it too. This gives players one honest "where are you?" answer that costs them something, instead of leaving position impossible to check.

### Keeping Players on In-Game Voice

Groups of friends often talk on Discord or a party chat instead. The design gives in-game voice real jobs so it's worth using, and makes sure the creature still has voices if a group doesn't.

- **Lobby voice lines:** Before a match, each player can record a short fixed list of lines (see Recording Lines That Sound Scared below). The creature always has clips to use. This is opt-in, and players can hear their recordings back.
- **Proximity chat carries position:** In-game voice is 3D, so it's the only way to hear where a teammate is and how far away.
- **Radios run on in-game chat:** Long-range talk only works through walkie-talkies, so coordinating across the farm needs the in-game system.
- **The dead are only heard in-game:** Dead players' static voices exist only in proximity chat.
- **Fallback voices:** Players with no recordings get generic pre-recorded voices, so the mechanic never fully switches off.
- **Say it up front:** The main menu and lobby recommend in-game voice chat as the intended way to play.
- **Accepted trade-off:** A group on Discord will see through the voices more easily. That weakens mimicry but doesn't break the game, since traps, scares and the night still work.

### [NEW] Recording Lines That Sound Scared

Lines read from a menu come out calm and flat, which makes fakes easy to spot. Fix it with staging, not prompts:

- **Record in the game, not the menu.** The lobby is the dark barn at night. Each line is triggered by a small staged moment: a lantern gutters out before "help me," something bangs on the barn door before "over here." People react, and the reaction is what you record.
- **Record each line 2 to 3 times** and let the game keep the take with the most energy (loudness and pitch variation are a good enough proxy).
- **The line list:** "over here," "help me," "come look at this," "I found something," "where are you?", "wait for me," "it's fine, come on," and each teammate's name.
- **Keep the menu option** for players who want to re-record or skip.

### Build Notes

- **Lobby lines first:** Record lobby voice lines and replay them from the creature's position. This is the first version of mimicry.
- **Live clips later:** Only push-to-talk speech is kept, at most 3 seconds a clip. Each player can see and delete their kept clips from the pause menu. There is no word filter, since that would need speech-to-text.
- **Fallback:** Players with mics off, or who opt out, get pre-recorded generic lines instead.
- **Consent:** Tell players up front that the game records their voice for this, keep the clips only for that match, and include an opt-out setting. Any player can block their voice from replay, entirely or to players they choose. Fixed lobby lines can't carry slurs or private remarks; live clips can, which is still open (see Open Issues).

---

## Night Traps

While players work or hide through the night, the creature sets traps around the farm. Any trap still armed in the morning becomes a daytime chore, and a weapon for the voices.

### Trap Types

- **Bear traps:** The creature steals them from the farm's tool shed and hides them in the corn.
- **Getting free:** A trapped player is pinned by the leg until they pry the jaws open themselves, which takes a few seconds. A teammate can help, but nobody is ever stuck waiting.
- **The slow:** After getting free, the player moves slower for a while (starting point: 40% slower for 60 seconds). By day that costs farming time; at night it makes them easy prey.
- **Small pits:** Shallow holes dug between the rows and covered with stalks and husks. A player who steps in stumbles and drops what they were carrying, and that's it.
- **[NEW] Tripwire bells (from day 4):** A string of rusty bells strung low between corn rows. Stepping through makes a loud jangle that tells the creature exactly where you are. No damage; pure information for the monster. Cheap to disarm (cut it), but easy to miss. It adds a third kind of trap without adding a new punishment system.

### The Tool Shed

- **Pegboard:** Bear traps hang on a pegboard with painted outlines, so one glance through the shed door shows how many are missing. Every empty outline is a trap hidden somewhere on the farm.
- **Locking it:** Buying a lock or boarding up the shed keeps traps in, but costs money and time, and from day 5 the creature can break in anyway.
- **Returning traps:** Disarmed bear traps can be carried back to the shed, which takes time but stops the creature from reusing them. Any bear trap not hanging on the pegboard at nightfall is the creature's to take, wherever it is, so hoarding traps only hands them over. A trap kept inside a lit building is simply gone by morning, with no sign of how.

### Finding and Disarming

- **Clues:** Fresh dirt near pits, bent stalks, or a glint of metal show where traps might be, but only to players who look closely.
- **Disarming:** Bear traps need a tool and a few seconds of kneeling still in the corn. Pits are filled in with a shovel.
- **Spotting:** Disarming is safer with a teammate watching, which pulls two players off farming.
- **[NEW] Flagging:** Players can plant a small red flag (unlimited, free) on a spot or row. Flags are a shared, honest map of "I checked here" or "trap here" that doesn't need voice, so a team that uses them talks less and feeds the creature less. The creature can move a flag once per night from day 5, so flags are reliable but not perfect.

### The Lure Combo

During the day, the creature uses a teammate's voice to call players toward rows where traps are still armed. A player who checked that row in the morning knows it's safe; a player who didn't gets caught. This rewards teams that split up their trap sweeps and talk about which rows are clear, which in turn gives the creature more voice clips to use.

### Rules

- **Rarely lethal by day:** A trap sprung during the day holds, slows, Taints, or costs you items. It only kills if the player is stuck in it with nobody nearby (see Day Deaths).
- **Deadly at night:** Traps that are still armed when night falls become far more dangerous, since a trapped player is easy prey.
- **Ramp up:** A few traps on night one, more and better-hidden ones as the season goes on (see Season and Numbers).

---

## Nights

Hiding in the barn all night is never fully safe and never free. Nights are short so fear doesn't turn into boredom, and there is always a reason for someone to go out.

- **The generator:** The barn and farmhouse lights run on a generator, and the creature won't enter a lit building. Fuel runs low partway through the night, and the fuel drum is outside by the shed. Someone has to go. When the generator dies, the sound carries across the whole farm and the creature comes to look.
- **The unattended farm:** The longer nobody is outside, the more freely the creature roams, and the more crops and fences are wrecked by dawn.
- **Moonflowers:** The most valuable crop only opens at night and can only be harvested in the dark. They glow faintly, so whoever picks them is easy to see.
- **It tests the doors:** From day 6, if every player stays inside, the creature starts working at the barn doors, so staying put stops being safe.
- **[CHANGED] The Harvest Moon has no timer.** Night 7 ends when the Prize Pumpkin's cart rolls out the farm gate, or when everyone is dead. A hard cap of 15 minutes keeps it from dragging; if the cap is reached, dawn comes and the cart counts as out only if it's past the fields. Nights 1 to 6 stay at about 5 minutes.

---

## Jumpscares

The creature almost never kills during the day (see Day Deaths), but it can still terrify. The game never tells players the day is safe; they learn it, and doubt it. A daytime jumpscare knocks the player down, makes them drop what they're carrying, and leaves them Tainted until dawn (see The Taint), then the creature vanishes back into the corn.

### Scare Moments

- **The disarm lunge:** While a player kneels to disarm a bear trap, the stalks part and the creature lunges at them, then pulls back into the rows.
- **The trap:** A player prying themselves out of a bear trap looks up to see the creature standing in the rows, watching, before it disappears.
- **The shed:** A player opens the shed to check the pegboard and the creature is inside, or the door slams shut behind them.
- **The whisper:** A teammate's voice speaks right behind a player, even though that teammate is across the field.
- **Your own voice:** On rare occasions, a player hears their own voice whispering their name from the corn. It won't fool them, but because it almost never happens, it's deeply unsettling when it does.
- **Fake-outs:** The corn rustles and something bursts out, but it's only a crow. These keep players from relaxing between real scares.
- **Hallucinations (from day 5):** A player sometimes sees the creature standing in the field or at the edge of the corn for a moment, and then it's gone. Nobody else sees it. No knockdown and no dropped items. Tainted players see them more often.
- **[NEW] The wrong count:** Rarely, a player looking across the field sees one more farmer than there should be, wearing a teammate's hat, standing still at the edge of the corn. When they look back, it's gone. Cheap to build (a static model and a timer) and the kind of moment people tell their friends about.
- **[NEW] The scarecrow moved:** A farm scarecrow is in a slightly different spot each morning, facing the farmhouse. Never explained, never dangerous. Pure dread for almost zero cost.

### Making Them Land

- **Keep them rare:** Too many jumpscares and players get used to them. Long quiet stretches make each one hit harder.
- **Build up first:** Silence, animals going quiet, or a voice calling from nearby before the scare works better than a scare out of nowhere.
- **Make them cost something:** Dropping items and the Taint until dawn mean a scare matters for the game, not just for the moment.
- **Let the Director time them:** The tension meter decides when a scare is due and randomizes where, so players can't learn the pattern.
- **[NEW] Sound does most of the work:** Budget more time for audio than for the creature's model. Players mostly hear it; they rarely see it.

---

## Death and Respawning

Death should matter without leaving anyone bored for long.

### Out Until Dawn

- **Respawn at dawn:** A player killed at night stays dead for the rest of that night and comes back at dawn with the survivors.
- **Medical bill:** Each death costs the team money at dawn, so protecting each other directly protects the farm. To stop a death spiral, the first death each night is cheaper, the bill has a cap per night, and it never takes the bank below the price of a turnip seed pack (numbers in Season and Numbers).

### Dead Players Stay Involved

- **Ghost spectating:** Dead players can follow their teammates and see the creature, but not traps: a ghost who saw every trap could read out the whole morning sweep.
- **[CHANGED] The lantern flicker works on any light:** A dead player can make any light near a living teammate flicker: a carried lantern, a barn bulb, a porch light, the moonflower glow. The original version needed a carried lantern, so the one unfakeable signal vanished exactly when players went dark to hide. Short cooldown so it stays meaningful.
- **Rustling the corn:** Dead players can also rustle stalks to point at something, but the creature can fake that.
- **Static voices:** Living players can still hear dead teammates in proximity chat, but only through heavy static.
- **[NEW] The crow:** A ghost can possess one crow per night for 20 seconds and fly it. Crows are everywhere on the farm and the creature ignores them, so it's a way to scout and point. The living see a crow acting strangely; the creature can also send fake crows (they're already used for fake-outs), so a weird crow is a hint, not proof. This gives ghosts something active and fun to do, which is the hardest part of spectating design.

### The Dead-Voice Twist

Once a player dies, the creature is more likely to mimic their voice. Combined with the static, this means a dead teammate's real warning and the creature's fake one can sound alike. The flicker is the tiebreaker: a static voice backed by a flickering light is a real teammate, and a voice with no flicker might be the creature. The dead player is trying to help, the creature is trying to lure, and the living have to decide who to trust.

---

## Daytime Threats

The monster rarely kills during the day, but it can still do harm. Traps, voice lures and jumpscares already fill most of the day, so other daytime harm is kept to a small pool. The creature gets a daily disturbance budget, a fixed number of these it can spend each day, rising over the season.

### Sabotage Pool

- **Trampled crops:** A few plants are destroyed where it roamed overnight, more if nobody was outside at night.
- **Stolen tools:** A watering can or hoe goes missing and turns up somewhere creepy, like the edge of the treeline, often next to an armed trap. Picking it back up Taints you.
- **Broken fences and gates:** Animals escape, so someone has to round them up far from the group. Animals matter because they go quiet when the creature is near.

### Setting Up the Night

- **Taint sources:** Dead crows and strange seeds left in the fields (see The Taint).
- **Clues:** Footprints, claw marks, or a moved scarecrow hint at where it will hunt tonight, but only if someone notices.

### Keeping It Fair

- Daytime harm should be annoying or costly, and only fatal through the player's own mistakes, so the day still feels like a break.
- Every disturbance has a fix, like repairing, rounding up, or washing, so it feels like a task and not just bad luck.
- Day 1 might have one broken fence; by day 6 the whole pool is in play.

The core trade-off: the more players investigate and fix during the day, the safer the night is, but that time comes out of farming.

---

## Crops

Prices are in coins per plot. All values are starting numbers to tune from playtest logs.

**[CHANGED] "Grows in" is defined:** "Grows in N days" means the crop is ready on the Nth dawn after planting. A turnip planted on day 1 is ready on the morning of day 2.

| Crop | Grows in | Seed cost | Sells for | Profit | Notes |
|---|---|---|---|---|---|
| Turnips | 1 day | 4 | 10 | 6 | Short and safe. Low value, steady money. |
| Pumpkins | 2 days | 10 | 28 | 18 | Low and sprawling. Unlocks on day 2. **[CHANGED]** sell price up from 25. |
| Moonflowers | 1 night | 25 | 60 | 35 | Night harvest only, and they glow. Unlocks on day 3. **[CHANGED]** sell price down from 70. |

- **Plots and labor:** The farm starts with 16 field plots, and upgrades add up to 24. Planting, watering and harvesting are each a hold of a few seconds, so one player tends about 6 plots a day and nobody can work the whole farm alone. Plots are the bottleneck. The plots are split into two fields far apart, one in front of the barn and one by the shipping crate, with corn rows between them.
- **[CHANGED] The moonflower bed scales:** 1 moonflower plot per player (2 to 4 plots). In the original, a 2-player team got the same 4-plot bed as 4 players while owing much less, so moonflowers alone could pay off more than the whole 2-player debt.
- **Corn is not a crop:** It can't be planted, cut or sold. The wild corn ring is always there, and ragged strips of it reach in toward the buildings and both fields, so every errand starts with a walk through it.

### [NEW] The Prize Pumpkin

Replaces the festival quota of 8 plots of pumpkins.

- **One giant pumpkin**, planted on day 1 in its own patch by the farmhouse. It grows bigger every day it is watered and visibly shrinks or rots on days it isn't.
- **The creature wants it.** Damage to the Prize Pumpkin is on its sabotage list from day 3, and on unattended nights it gnaws at it.
- **On the Harvest Moon** the team loads it onto the festival cart and pushes the cart to the farm gate. The cart is slow and squeaks, and two players pushing it go faster than one.
- **Its size is the score.** A bigger pumpkin pays more at the festival (see Season and Numbers), so it adds money on top of the win.
- **Why it's better:** One object the whole team cares about for seven days gives the season a face. Friends will name it. They will be furious when the creature takes a bite out of it. And the final night becomes a clear, readable objective (escort the cart) instead of a numbers check.

---

## Season and Numbers

A season is 7 days. Night 7 is the Harvest Moon, the final night. All numbers here are starting values to tune from playtest logs.

### Winning and Losing

- **The debt:** The farm owes the bank 1,200 coins (4 players). The team starts with 60 coins.
- **[CHANGED] First payment:** 300 coins due at dawn after night 3 (down from 400; see Economy Check).
- **Final payment:** The remaining 900 coins, due at dawn after the Harvest Moon. The Prize Pumpkin's festival money counts toward it.
- **The festival cart:** On the Harvest Moon the team loads the Prize Pumpkin onto the festival cart and gets it out the farm gate before dawn, under attack all night.
- **Win:** Make both payments and get the cart out the gate, with at least one player alive when it leaves.
- **Lose:** Miss a payment and the bank takes the farm, ending the season. If everyone dies during the Harvest Moon before the cart is out, the season is also lost. A full wipe on any earlier night isn't a loss, it just costs medical bills and farm damage.
- **[CHANGED] Player count:** With 2 or 3 players, payments, trap counts and the disturbance budget scale down (starting point: 60% for 2 players, 80% for 3). The moonflower bed scales with players (see Crops).

### Prize Pumpkin Payout

| Days watered (of 7) | Size | Festival pays |
|---|---|---|
| 7 | Giant | 250 |
| 5 to 6 | Large | 150 |
| 3 to 4 | Medium | 75 |
| 0 to 2 | Sad | 20 (and the festival laughs at you) |

Each night the creature gnawed it unattended drops it one size.

### Medical Bill

- 50 coins per death, but the first death each night costs 25.
- No more than 120 coins per night in total (10% of the debt).
- The bill never takes the bank below 4 coins, the price of a turnip seed pack.

### Economy Check **[NEW]**

A quick hand check of the first payment under the new numbers, assuming no deaths, turnips on every tendable field plot, and moonflowers from night 3.

**4 players (16 field plots, 4 moonflower plots):**

| | Coins |
|---|---|
| Day 1: start 60, plant 15 turnips (60) | 0 |
| Day 2: sell 15 turnips (+150), plant 16 (−64) | 86 |
| Day 3: sell 16 (+160), plant 16 turnips (−64) and 4 moonflowers (−100) | 82 |
| Night 3: sell 4 moonflowers (+240) | **322 vs 300 owed** |

**2 players (8 field plots, 2 moonflower plots, first payment 180):**

| | Coins |
|---|---|
| Day 1: plant 8 turnips (−32) | 28 |
| Day 2: sell 8 (+80), plant 8 (−32) | 76 |
| Day 3: sell 8 (+80), plant 8 turnips (−32) and 2 moonflowers (−50) | 74 |
| Night 3: sell 2 moonflowers (+120) | **194 vs 180 owed** |

Both are now reachable with a perfect start, but only just: one or two deaths before dawn 3 means a team has to plant smarter or take more night risk. That's the right pressure for a first payment. Moonflowers are still the best crop per plot, which is intended (it pushes people outside at night), but they're no longer most of the season's income. Rebuild a spreadsheet simulator before Phase 4 to check the whole season, not just the first payment.

### Ramp-Up (4 Players)

| Day | Daytime disturbances | Traps set that night | Voice | New this day |
|---|---|---|---|---|
| 1 | 1 | 2 bear traps, 1 pit | Exact clips | Turnips; Prize Pumpkin planted |
| 2 | 1 | 2 bear traps, 2 pits | Exact clips | Pumpkins |
| 3 | 2 | 3 bear traps, 2 pits | Exact clips | Moonflowers; Taint sources start; Prize Pumpkin can be damaged; first payment at dawn |
| 4 | 2 | 3 bear traps, 2 pits, 1 bell line | Spliced clips | Mimicry gets more convincing; tripwire bells |
| 5 | 3 | 4 bear traps, 3 pits, 1 bell line | Spliced clips | It can break the shed lock; hallucinations; it can move a flag |
| 6 | 3 | 5 bear traps, 3 pits, 2 bell lines | Spliced clips | It tests the barn doors |
| 7 | 4 | Harvest Moon: hunts all night | Spliced clips | Push the cart; final payment at dawn |

### Length and Saving

- **Dawn saves:** The host's game saves at every dawn, so a season can be played over several evenings.
- **Short season:** A 3-day option for a single sitting, with the debt scaled down and the Prize Pumpkin growing faster.
- **[NEW] Drop-in:** A friend who joins late can join at the next dawn as a new farmhand. Payments rescale at that dawn. Friend groups rarely all start at the same time.

### The Next Season

Upgrades and plots carry into the next season. The debt grows, and each new season the creature gains one new trait, for example copying tools better or setting more pits, so the farm players built is worth defending again.

### Upgrades

Over the season, players unlock new seeds, upgrade tools, and expand the farm (up to 24 plots). Bought at a store by the shipping crate. Examples:

- Quiet watering can (slower, but the creature can't hear it as far)
- Shed lock
- Walkie-talkies and batteries
- Brighter lanterns
- More scarecrows
- New plots
- **[NEW] Flare gun:** one shot, refilled each dawn. Scares the creature off for 30 seconds. Anyone can carry it (see Roles).
- **[NEW] Cosmetic hats and overalls,** bought with leftover coins after the final payment. Pure fun, and it gives the late season something to spend money on once the debt is safe.

Walkie-talkies carry only real teammates' voices, since the creature copies voices only from the corn.

---

## Mechanics That Tie Farming and Horror Together

- **Noise:** Tractors, watering cans, the well pump and the barn door all make sound. Fast tools are loud; quiet tools are slow.
- **Light:** Lanterns help you work at night but make you visible from far away.
- **Crop risk vs. reward:** Moonflowers pay the most but have to be picked in the dark, and the far field means a long walk through the corn.
- **Fences and scarecrows as defense:** You build up your farm's protection over time, like a light tower-defense layer.
- **Splitting up:** One player waters the far field, one checks the traps, one sells at the stand. The farm is too big for a group to stay together.

---

## Roles (Optional, Good for 4 Players)

**[CHANGED] Decided: the four roles are Farmer, Rancher, Mechanic and Tracker.** The Hunter's flare gun becomes a shed item anyone can carry, with one shot per day. This keeps the team's only way to drive the creature off without forcing someone to pick a role just to have it, and the Tracker gives the trap sweep, the most distinctive chore, a specialist.

- **Farmer:** grows faster, harvests more
- **Rancher:** handles animals, which act as early warning when the creature is near
- **Mechanic:** fixes the tractor, generator, and lights, and refuels the generator faster
- **Tracker:** spots trap clues like fresh dirt and glinting metal more easily, and disarms bear traps faster

With fewer than 4 players, roles are optional and each player can pick any one. A team doesn't need every role to win.

---

## [NEW] Making It Fun With Friends

Scary is half the job. The other half is the stories the group tells each other afterward. These additions are cheap and do most of the work there.

### The Dawn Report

At every dawn, before the money screen, a short newspaper-style card shows the night:

- **"Best Impression"**: the lure that worked best, replayed in the creature's voice: *"The creature said 'come look at this' as Sam. Alex walked 40 meters into the corn."*
- **"Most Wanted"**: who the creature chased the most.
- **"Cause of Death"**: written like a small-town obituary. *"Jordan, 2nd night. Survived by 11 turnips."*
- **"Hero of the Night"**: whoever refueled the generator or freed a teammate.

Players can skip it, and it only replays clips from players who allowed replay. This is where the "remember when..." moments come from, and it's what makes people want to play another night.

### Season Awards

At the end of a season, a short awards screen: most traps disarmed, most times fooled by a voice, most coins earned, longest time spent hiding in the barn ("Barn Goblin"). Every player gets at least one award.

### Emotes and Physical Comedy

- A small set of emotes (wave, point, shrug, scream).
- Ragdoll knockdowns on jumpscares. Watching a friend get launched into a pumpkin patch is funny, and funny right after scary is the best rhythm for friend groups.
- Players can pick up and carry a downed or slowed teammate a short way (slowly, noisily).

### Difficulty and Group Settings

- **Difficulty:** Easy (fewer traps, gentler bills), Normal, and Nightmare (shorter nights' generator fuel, day deaths more likely, no voice tells).
- **"No live clips" toggle** in the lobby for groups who'd rather the creature only used recorded lines.
- **Streamer-safe mode:** never replays live clips, only lobby lines.

---

## Build Plan: Four Phases

Starting from scratch: nothing below is built yet. Only move on once the current phase is fun to play. Each phase has a test for "fun."

A review sits between each phase and the next:

1. Read the phase's playtest logs and notes.
2. Add every new problem they show to Open Issues.
3. Settle the open issues the next phase depends on, and any others that are now answerable. Move each settled one to Resolved Issues and update the sections it touches.
4. Start the next phase only when nothing it depends on is still open.

- **Phase 1 (prototype):** One small field, the shed and the barn, one day and one night, 2 players online, the creature wandering and chasing by sound, bear traps and small pits in scripted spots, the generator, and the creature playing generic pre-recorded voice lines. Proximity voice chat working. Done when: the day feels safe, the night feels tense, and a generic voice from the corn makes a playtester walk toward it at least once.
- **Phase 2:** Lobby voice-line recording (staged in the barn), the creature replaying those lines, the creature stealing bear traps from the shed and the pegboard, death with respawn at dawn and the medical bill, the two-field farm layout with corn rows between, and up to 4 players. Done when: hearing a friend's recorded voice from the corn fools someone, and trap sweeps feel worth doing.
- **Phase 3:** The creature favoring dead players' voices, the Director and jumpscares, the Taint, ghosts with the lantern flicker and the crow, the whistle, flags and the Dawn Report. Done when: dead players stay engaged, the living argue over whether to trust a static voice, and someone laughs at the Dawn Report.
- **Phase 4:** The full 7-day season with crops, the economy, the Prize Pumpkin, upgrades, roles, payments, saving and the Harvest Moon. Done when: teams sometimes win and sometimes lose, and the logs show the numbers are close.
- **Phase 5 (later):** Live voice clips from proximity chat, spliced clips, the next season, cosmetics.
- **Fake it first:** Scripted trap spots and simple timers can stand in for smart AI until the core loop is proven.

**Why live clips moved to Phase 5:** they're the hardest technical piece (capturing, trimming and splicing speech), they carry the open consent problem, and staged lobby recordings may be scary enough on their own. Prove the game is fun without them first.

---

## Engine and Tech: Godot

The game is built in Godot 4.

- **Cost:** Free and open source under the MIT license, with no royalties ever.
- **Testing multiplayer:** Debug > Customize Run Instances runs several copies of the game at once from the editor, which covers most solo multiplayer testing.
- **[NEW] Voice chat must be built.** Godot has no built-in voice chat, and the whole design rests on it. Two routes:
  - **Steam (recommended for a friends game):** the GodotSteam plugin gives voice capture, compression and lobbies/invites through Steam. Friends join through the Steam overlay, which removes most networking pain (NAT, port forwarding).
  - **Custom:** capture the mic with an `AudioEffectCapture` on a bus, compress (Opus via a GDExtension), send over Godot's multiplayer, and play back through an `AudioStreamGenerator` on each player. More work, no Steam dependency.
- **Spatial audio:** each player's voice plays from an `AudioStreamPlayer3D` on their character, which is what makes position a real tell.
- **The creature's voice:** recorded clips play from an `AudioStreamPlayer3D` on the creature, run through the same voice chain as real players so fakes don't stand out by sounding cleaner.
- **Networking model:** host-authoritative. The host runs the creature AI and the Director; clients send inputs and voice.

---

## Testing Solo

Most testing can be done alone, with group playtests at the end of each phase.

- **Multiple copies on one computer:** Use Customize Run Instances to run two to four copies of the game at once and check that multiplayer stays in sync.
- **Bot teammates:** Simple stand-in players that walk to fields, do chores, play voice clips and can be killed. They give the creature targets and voices, so mimicry, lures and deaths can be tested without other people.
- **Recorded voices:** Your own recordings, plus a few voice lines from friends who agree to it, so the creature has more than one voice to copy.
- **Logging:** The game records each day and night: who died where, which traps were sprung, which voice lures worked, how long chores took, how much money was made, and how long players stayed inside at night. The Dawn Report can be built from the same logs.
- **Debug view:** A top-down view showing the creature, its current behavior state, the Director's tension meter, traps and players, to check the AI is behaving fairly.
- **Group playtests:** Solo testing can't show whether the scares and voice confusion work on real people, so play with friends at the end of each phase and log those sessions too. **[NEW]** Record the session (with everyone's OK) and watch it back: the moments people scream or laugh are the design working; the moments they go quiet and bored are what to fix.

---

## Resolved Issues

Settled in this design review:

- **"Grows in" was undefined:** it means ready on the Nth dawn after planting. See Crops.
- **The first payment was out of reach:** lowered to 300, and a perfect start now just makes it. See Economy Check.
- **Moonflowers carried the economy:** sell price lowered, pumpkins raised, and the Prize Pumpkin adds a day-farming payout. See Crops.
- **Player-count scaling ran backwards:** the moonflower bed now scales with players, and payments scale to 60% and 80%. See Crops and Season and Numbers.
- **The lantern flicker needed a carried light:** it now works on any light. See Death and Respawning.
- **Three tracking systems did one job:** merged into the Taint. See The Taint.
- **Day-death rules were an exact checklist:** the Director bends them. See Day Deaths.
- **The night was too short for the finale:** the Harvest Moon ends when the cart is out. See Nights.
- **The festival quota was a corn leftover:** replaced by the Prize Pumpkin. See The Prize Pumpkin.
- **The fourth role:** Tracker; the flare gun becomes a shared item. See Roles.
- **Lobby lines came out calm:** recorded through staged moments in the barn. See Recording Lines That Sound Scared.
- **Players couldn't place a quiet teammate:** the whistle gives an honest, costly answer. See How Players Fight Back.
- **Ghosts had little to do without trap sight:** the crow. See Dead Players Stay Involved.

Settled in the original concept (kept): Discord groups weaken mimicry but don't break the game; the day is a small sabotage pool with a daily budget; corn is permanent cover, not a crop; nights always give a reason to go out; the medical bill has a cheap first death, a cap and a floor; trapped players can free themselves; bear traps off the pegboard at nightfall are the creature's; voice tells are random and sometimes absent; mimicry supports the pitch rather than leading it; the creature is only ever glimpsed; dawn saves and a short season.

---

## Open Issues

Problems that still need solving, most important first.

### 1. Scope is large for a first build

Voice chat, voice recording and playback, a trap-setting AI that lures players, the Director, jumpscares, a farming economy and online multiplayer add up to a lot, starting from nothing. The phased Build Plan and moving live clips to Phase 5 help. Biggest risk: voice chat. Build it in Phase 1, not later.

### 2. Live clips can carry anything

Once live clips arrive (Phase 5), a friend's offhand private remark or a slur could be replayed by the creature, or shown in the Dawn Report. Push-to-talk only, 3-second clips, reviewable and deletable, and the "no live clips" toggle help, but it isn't solved. Needs settling before Phase 5.

### 3. The numbers are untested

Every price, payment and trap count is a first guess, and the Economy Check only covers the first payment. Rebuild a season simulator spreadsheet before Phase 4 and tune from the logs once Phase 4 is playable.

### 4. Can the whistle be abused?

A whistle with a position marker could make voice tells pointless if teams whistle constantly. The cooldown and the fact that the creature hears it should balance it. Check in Phase 3's playtest; if players whistle every few seconds, lengthen the cooldown or drop the marker.

### 5. Is the Prize Pumpkin too punishing to forget?

A team that forgets to water it early may feel the season is lost. The "Sad" payout keeps it from being a loss on its own. Check in Phase 4.

### 6. Do sound signatures make the four bodies feel different enough?

All four bodies hunt the same way. If players stop caring which one they got, consider one small behavior quirk each (the husk is quieter in corn, the boar is louder but faster). Check after Phase 3.

---

## Next Steps

1. Set up the Godot project in this repo.
2. Get proximity voice chat working between two machines (Steam or custom; see Engine and Tech). This is the riskiest piece, so do it first.
3. Build Phase 1 and playtest it with one friend.
