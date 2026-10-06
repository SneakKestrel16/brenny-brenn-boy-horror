# Farming Horror Game: Design Doc 01

A multiplayer game where friends grow and farm crops while being hunted. Farming creates the tension horror needs:
- crops tie you to specific spots;
- the work is noisy and repetitive;
- you can't finish it all with everyone huddled together.

**The pitch:** a farm under siege. Traps, crops and the day/night economy are the hook. Voice mimicry supports it rather than leading it, since other games already sell AI voice copying.

**Format:** 2 to 4 player online co-op. The monster is AI-controlled, so every player is on the same side against it. The creature, the debt and the costs scale with the number of players.

**Status:** Starting from scratch. Nothing is built yet. All numbers are starting values, to be tuned with the season simulator and playtest logs.

### Design pillars

- **Cozy day, terrifying night.** The day makes players care, and the night threatens what they built. Protect the contrast.
- **The night writes tomorrow's chores.** Traps the creature sets become the next day's work.
- **Honest signals, costly to use.** Pegboard, flags, whistle, flicker and radios each tell the truth, and each costs something.
- **Deaths come from player choices.** The creature is frightening all day, but it only kills when someone took a risk.
- **Glimpsed, never seen.** Players mostly hear the creature. They rarely see it, and never clearly.
- **Stories for friends.** The Dawn Report, ragdolls and arguments over who to trust are the "remember when" moments.

---

## The Core Loop

**Day (safe-ish, about 8 to 10 minutes):**
- Players glance at the shed pegboard and sweep for traps left overnight, disarming what they find.
- They plant, water, harvest, fix what the creature broke, and sell at the town stand.
- This is the cozy part, where resources and stakes build up.
- The day has a fixed arc (see The AI Director).

**Dusk (warning phase, about 1 minute):**
- The light fades and the animals go quiet.
- The church bell in town rings three times across the fields, so everyone knows dusk has started wherever they are.
- Players rush to finish chores, harvest valuable crops and top up the generator.

**Night (the hunt, about 5 minutes):**
- The creature comes out of the corn, hunts, and sets traps for the next day.
- Moonflowers can only be harvested at night and are worth far more.
- The generator needs refueling partway through.
- Nobody can sit safely in the barn all night (see Nights).

**Dawn:** things happen in a fixed order, shown on the Dawn Report:
1. **Cash-in:** survivors sell what they carry. Anyone who died loses what they were carrying.
2. **Medical bill.**
3. **Any payment due.**
4. **Farm damage:** the farm takes damage where the creature roamed, more if nobody was outside to stop it. After a full wipe the creature had the farm to itself, so farm damage is doubled and it sets extra traps for the morning.

The Dawn Report then plays (see Making It Fun With Friends).

---

## The Creature: Something in the Corn

You never see it clearly. It lives in the wild corn that rings the farm, a field players can't cut down or farm, so it always has somewhere to hide.
- **The layout:** ragged strips of corn reach in toward the buildings, and rows of it stand between the barn and the two fields. Every errand is a walk through its hunting ground.
- **Its tools:** it hunts with players' own voices and the traps it sets at night.

**What it looks like changes each run.** The host's game picks one of four bodies at random, so nobody knows what they are looking for:
- **Gaunt thing:** gaunt and hunched, in dark hide.
- **Scarecrow:** a ragged coat, a stitched sack head and ember eyes.
- **Boar brute:** a chained brute with tusks and an iron collar.
- **Corn husk:** a walking husk, all stalks and peeled leaves round a glowing heart, that all but vanishes in the corn.

The look is only skin: they all hunt the same way.

**Each body has one sound signature.** The look is hidden, so sound is how players learn which body they have this season:

| Body | Sound signature |
|---|---|
| Gaunt thing | clicks |
| Scarecrow | coat flaps |
| Boar brute | chain drags |
| Corn husk | a dry rattle that sounds distinct from ordinary corn rustle |

Players will start saying "it's the chain one this time," which is the kind of shared vocabulary friend groups love. Behavior stays identical.

**What players see of it:**
- **By day:** only parts and motion, such as a head above the corn, an arm, or stalks parting.
- **At night:** a clear view comes only during a chase, in the dark, and never for more than a second.
- **Lunges** cut to black or a knockdown before it is in full view.
- **The stare and hallucinations** are distant silhouettes.
- **Ghosts** follow the same rule (see Death and Respawning).

### How It Hunts

The creature hunts only with what it senses. It never knows a player's position any other way.

- **Hearing:** Its main sense. Louder sounds carry further. It hears:
  - tools, footsteps, doors and the well pump;
  - sprinting through corn;
  - **transmitted in-game voice.** The creature hears the volume of what each player's mic transmits, so a scream gives you away. Only the volume is sent (one byte per voice frame), and no audio is stored.
- **Sight:** Short range only. It spots players carrying light or standing in open ground, but tall corn blocks its view just as it blocks yours.
- **Taint:** It can track Tainted players from much further away (see The Taint).

**Hiding verbs:**
- **Crouch-walk:** silent but slow.
- **Go still:** no movement, while your own heartbeat rises in your audio. The host checks that a "still" player really is still.

### Behavior States

- **Lurk:** Moves through the corn, sets traps at night, and gathers voice clips.
- **Lure:** Plays a mimicked voice or sound from cover, usually near an armed trap or a player who is alone.
- **Stalk:** Follows one player from cover, getting closer.
- **Chase (night, or a day kill):** Breaks cover and runs a player down. To lose it, a player must break its line of sight **and** go quiet (crouch or go still) for a few seconds, or reach a lit building.
- **Retreat:** After a jumpscare, a kill, or a hit from a flare, it pulls back into the corn for a while.
- **By day:** It Lurks, Lures, Stalks and jumpscares. It kills only in the rare cases under Day Deaths.

**Readable states.** Every state has an audio tell players can learn, or the AI will feel random:

| State | What players notice |
|---|---|
| Lurk | Normal ambience: a constant bed of insects and frogs, birds, animals |
| Lure | A voice or tool sound from the corn |
| Stalk | The insect and frog bed cuts out and the wind drops |
| Chase | A hard music sting and the body's sound signature, loud |
| Retreat | The insects and frogs come back |

- **Crows aren't a state tell.** They already have other jobs (fake-outs, Taint sources, ghost possession).
- **Silence is the cue.** Stalk is a layer dropping away. It isn't the animals being missing, since escaped animals would give false tells.
- **Ambience runs locally.** Each client plays it from the replicated creature state.

Learning to "hear the farm go quiet" is the skill that makes veterans feel smart.

### Light Is the Rule

- **Lit buildings are safe.** The creature never enters one, with no exceptions.
- **Dark buildings are not.** A building whose lights are out can be entered, but only through a door, and the creature always bangs on that door first. Restoring power drives it out.
- **It attacks the light.** From day 6, if every player stays inside, the barn doors bang and bow while the creature circles to the generator and starts damaging it.

### Day Deaths

Deaths by day are rare, and always come from a risk the player took. The creature can kill by day only in two cases:

1. **Alone, Tainted and deep in the corn:**
   - no teammate within earshot;
   - Tainted (always by the player's own choice, see The Taint);
   - well inside the rows rather than at the edge.
2. **Losing the trap race.** When a bear trap springs by day, the creature's sound signature starts approaching from a set distance:
   - **Pry free in time** and you live, Shaken.
   - **Fail** and you die.
   - **A teammate** nearby shortens the pry.
   - **Tuning:** the race is tuned so a solo, untainted player who starts prying at once survives, with a few seconds to spare.
   - **What loses it:** hesitating, being Tainted (a slower pry), or the trap being deep in the corn.

**The AI Director can bend the distances:**
- How deep "deep in the corn" is, how far "earshot" reaches and the race's start distance all shift a little each day, so the rule can't be measured exactly.
- It never adds conditions or lowers the number needed.
- The fear lives in what players aren't sure of.

Almost nobody will die by day, but everyone will know it can happen, and that is enough. A day death counts like a night one: out until dawn, and on the medical bill.

### The Taint

One state, **Tainted**, with a few causes and one cure. Taint always comes from something the player chose to do, so black hands mean "you messed up."

**Causes:**
- Touching something the creature left behind (a dead crow, a strange seed).
- Picking up a stolen tool.
- Leaving a dropped item in the field at dusk (the item stays Tainted until picked up).
- Touching an unpicked moonflower (see Crops).

**Effects (until cured or dawn):**
- Sprint runs out 40% sooner, and prying free of a trap is slower.
- Footsteps are heard 50% further.
- At night the creature can follow your trail.
- Hallucinations happen to you more often (late season).

**The cue:** Black, oily stains spread up your character's hands and sleeves, visible to everyone, plus a faint wet heartbeat in your own audio. Friends can see who is Tainted and will absolutely give them grief for it.

**The cure:** Wash at the well. It takes about 10 seconds of noisy pumping, which can draw the creature. Every Taint can be washed off.

Being Tainted twice changes nothing, so one bad day doesn't pile up.

**Shaken** (from jumpscares and surviving a trap race) is separate:
- sprint is shorter for 60 seconds;
- it never Taints;
- it wears off on its own.

### The AI Director

A tension meter decides how aggressive the creature is from moment to moment, in the spirit of Left 4 Dead's AI Director. It cycles through **build-up, peak, fade and relax**:
- after a scare or a chase, the meter drops and the creature backs off;
- after a long quiet stretch, it rises and the creature pushes in.

There are separate profiles for the day, the night and the Harvest Moon. The number of "presence events" per player per phase is a tunable.

**What the AI Director may and may not use:**
- **Hunting** (movement, pursuit, trap placement) uses only the creature's senses and Taint. The AI Director may nudge the creature toward a *region*, never toward a position.
- **Presentation** (lure targeting, scare timing, hallucinations) may use true player positions.
- **The debug view** shows sensed and true positions side by side, so this can be tested.

**The day arc:**

| Part of the day | What the creature does |
|---|---|
| First third | Calm: no lures, stalking or scares, only evidence of last night's sabotage. Players settle back into cozy mode so the contrast lands. |
| Middle third | Low presence. |
| Last third | Builds toward dusk. |

**Rules of thumb:**
- At most one big scare per player per day.
- Never two big scares on the same player within 2 minutes.
- Spread attention: a player who hasn't been scared all day is more likely to be targeted next.
- **Private events count toward both limits.** Targeted lures, hallucinations and the wrong count all count, so one player never gets three private scares in a row while the rest hear nothing.

**The town stand is a daytime sanctuary:**
- Within 10 m of it there are no lures, scares or kills.
- The day clock keeps running there and nothing grows, so it's a breather, not a hiding place.

---

## Signature Mechanic: Voice Mimicry

The creature can copy players' voices. Proximity voice chat becomes both the team's best tool and its biggest weakness, because nobody can fully trust what they hear.

### How It Works

**What it copies:**
- **Voices:** it uses each player's lobby voice lines and barn chatter, and in a later phase short clips of what they say in proximity chat. The more someone talks, the more material it has.
- **Sounds:** it can fake a teammate's footsteps, a watering can or a hoe, so quiet players still give it something to use.

**Who hears a lure:**
- **By day, lures are targeted.** Only the target hears them, and only when no teammate is within about 15 m. The creature calls a player's name from the corn or the treeline in a teammate's voice, luring them away from the group and toward armed traps.
- **At night and during chases, lures are world sounds** that everyone nearby hears. It replays phrases like "come here" or "I found something" to pull players into the dark, then hunts them.
- **The Dawn Report replays targeted lures** to the whole group. Finding out what the creature whispered to a friend is a payoff in its own right.

**Its habits:**
- **It favors the dead.** Once a player dies, the creature is more likely to use their voice. Hearing a dead friend call from the corn is one of the game's strongest scares.
- **It rarely uses your own voice on you,** since you'd know it isn't you talking.
- **Players on the Off voice setting** are never imitated with a stand-in voice, because a mismatched voice is a free tell. The creature fakes their footsteps and tools instead. Generic voices are used only for unattributed "stranger" calls.
- **It gets better:** early in the season it plays back exact clips. From day 4 it mixes clips together, so the lines sound more natural and harder to spot.
- **Never tell players the line list is the whole pool.**

### How Players Fight Back

- **Tells:**
  - Each mimicked voice has at most one small giveaway, picked at random: a faint echo, a slightly wrong pitch, or a missing radio crackle.
  - About a third have no giveaway.
  - The one clue that never goes away is the voice coming from somewhere the teammate can't be.
- **Passwords:** Teams can agree on a code word, but the creature can pick that up too if someone says it near it.
- **Staying quiet:** Talking less gives it less to copy and less to hear, but it also makes teamwork harder.
- **Walkie-talkies:** A craftable radio the creature can't fake. It runs on limited batteries and fills with static when the creature is near, so "was that you?" doesn't always get through. Walkie-talkies carry only real teammates' voices.
- **The lantern flicker:** A dead teammate's one signal the creature can never fake (see Death and Respawning).
- **The whistle:** Every player can whistle (one button, short cooldown).
  - **Range:** it carries far, and teammates hear where it came from through 3D audio.
  - **Honest:** the creature can't fake a whistle, but it hears it too.
  - **No HUD marker.**
  - **Fallback:** if testing shows players can't place a whistle by ear, the whistler's lantern or hat briefly flashes.

### Keeping Players on In-Game Voice

Groups of friends often talk on Discord or a party chat instead. The game gives in-game voice real jobs, and the creature still has voices to use if a group doesn't.

- **Proximity chat carries position.** In-game voice is 3D, so it's the only way to hear where a teammate is and how far away.
- **Radios run on in-game chat.** Long-range talk only works through walkie-talkies.
- **The dead are only heard in-game.** Dead players' static voices exist only in proximity chat.
- **Lobby lines and chatter** give the creature voices regardless.
- **Say it up front.** The main menu and lobby recommend in-game voice. A lobby note reads: "The creature can't hear Discord, and you can't hear where your friends are."
- **Accepted trade-off.** A group on Discord sees through voices more easily and can coordinate silently at no cost. That weakens mimicry and the creature's hearing, but doesn't break the game, since traps, scares and the night still work. The AI Director doesn't cheat to compensate.

### Voice Settings and Consent

There is no forced consent screen. Each player picks their own voice setting, on their own machine, and can change it at any time from settings:

| Setting | What happens |
|---|---|
| **Off** | Nothing is recorded. The creature imitates this player's footsteps and tools only. |
| **Lobby lines** (default once recorded) | The player's lobby lines and barn chatter can be replayed by the creature and in the Dawn Report. |
| **Live clips** (opt-in, Phase 5) | Short clips of transmitted proximity speech can be kept and replayed too. |

**The setting governs every replay of a player's voice:**
- by the creature;
- in the Dawn Report (an Off player's lures appear as text plus the sound, with no voice);
- in streamer-safe mode.

**Storage:**
- Lobby lines stay on the owner's disk.
- They're sent to other players at session start and kept only in memory, never in the host's save.
- Turning voice Off deletes them.

**Recording notice:**
- A visible "recording" lantern, or tally light, shows whenever capture is live.
- Each clip can be reviewed and deleted before the match starts.

### Recording Lines That Sound Scared

Lines read from a menu come out calm and flat, which makes fakes easy to spot. The fix is staging, not prompts.

- **Record in the game, not the menu.** The lobby is the dark barn at night. Each line is triggered by a small staged moment:
  - a lantern blows out (never flickers; see Death and Respawning) before "help me";
  - something bangs on the barn door before "over here."

  People react, and the reaction is what gets recorded.
- **Record each line 2 to 3 times.** The game keeps the take with the most energy (loudness and pitch variation are a good enough proxy).
- **The line list:** "over here," "help me," "come look at this," "I found something," "where are you?", "wait for me," "it's fine, come on," and each teammate's name.
- **Barn chatter:**
  - **Who:** only players on the Lobby lines setting who take part in the staged recording.
  - **What:** 20 to 40 seconds of their free talk in the barn.
  - **How:** captured on the sender's machine, with the recording light on.
  - The staged recording can be skipped.
- **Keep a menu option** for players who want to re-record or skip.

### Build Notes

- **Lobby lines first:** record lobby lines and barn chatter, then replay them from the creature's position. This is the first version of mimicry.
- **Live clips later (Phase 5):**
  - only transmitted speech, from players on the Live clips setting;
  - at most 3 seconds a clip;
  - clips are kept for that session only and deleted when it ends;
  - each player can see and delete their kept clips from the pause menu;
  - there is no word filter, since that would need speech-to-text.
- **Fallback:** players with no mic, or on Off, are imitated only through sounds.
- **Group options:** a "no live clips" lobby toggle, and streamer-safe mode (never replays live clips, only lobby lines).

---

## Night Traps

While players work or hide through the night, the creature sets traps around the farm. Any trap still armed in the morning becomes a daytime chore, and a weapon for the voices.

### Trap Types

- **Bear traps:**
  - **Where they come from:** the creature steals them from the farm's tool shed and hides them in the corn.
  - **Getting caught:** a trapped player is pinned by the leg until they pry the jaws open, which takes a few seconds. A teammate can help, but nobody is ever stuck waiting. By day, a sprung trap starts the trap race (see Day Deaths).
  - **The slow:** after getting free, the player moves slower for a while (starting point: 40% slower for 60 seconds). By day that costs farming time; at night it makes them easy prey.
- **Small pits:** shallow holes dug between the rows and covered with stalks and husks. A player who steps in stumbles and drops what they were carrying, and that's it.
- **Tripwire bells (from day 4):**
  - **What:** a string of rusty bells strung low between corn rows.
  - **Effect:** stepping through makes a loud jangle that tells the creature exactly where you are. No damage; it's pure information for the monster.
  - **Disarming:** cheap (cut it), but it's easy to miss.

### The Tool Shed

- **Pegboard:** Bear traps hang on a pegboard with painted outlines, so one glance through the shed door shows how many are missing. Every empty outline is a trap hidden somewhere on the farm.
- **The lock (about 40 coins):** a lock caps theft without stopping it.
  - A locked shed still loses one trap a night ("pried a board loose").
  - From day 5 the creature can break the lock entirely.
- **Returning traps:** Disarmed bear traps can be carried back to the shed, which takes time but stops the creature from reusing them.
  - **The pegboard rule:** any bear trap not hanging on the pegboard at nightfall is the creature's to take, so hoarding traps only hands them over.
  - **Traps in buildings:** a trap kept inside a building disappears overnight only if that building went dark. Otherwise it turns up in the corn at dawn.

### Finding and Disarming

- **Clues:** Fresh dirt near pits, bent stalks, or a glint of metal show where traps might be, but only to players who look closely.
- **Disarming:** Bear traps need a tool and a few seconds of kneeling still in the corn. Pits are filled in with a shovel.
- **Spotting:** Disarming is safer with a teammate watching, which pulls two players off farming.
- **Flagging:**
  - Players can plant small red flags on a spot or row, as many as they like, for free.
  - Flags are a shared, honest map of "I checked here" or "trap here" that doesn't need voice. A team that uses them talks less and feeds the creature less.
  - From day 5 the creature can move one flag per night, so flags are reliable but not perfect.

### The Lure Combo

During the day, the creature uses a teammate's voice to call players toward rows where traps are still armed.
- A player who checked that row in the morning knows it's safe; a player who didn't gets caught.
- This rewards teams that split up their trap sweeps and talk about which rows are clear.
- That talk gives the creature more voice clips to use.

### Rules

- **Rarely lethal by day:** A trap sprung during the day holds, slows or costs you items. It only kills if the player loses the trap race.
- **Deadly at night:** Traps still armed at nightfall are far more dangerous, since a trapped player is easy prey.
- **Ramp up:** a few traps on night one, more and better-hidden ones as the season goes on (see Season and Numbers). Scaled trap counts round up.

---

## Nights

Hiding in the barn all night is never fully safe and never free. Nights are short, so fear doesn't turn into boredom, and there is always a reason for someone to go out.

- **The generator:**
  - **Fuel:** the barn and farmhouse lights run on a generator. Fuel runs low partway through the night, and the fuel drum is outside by the shed. The drum is free and never runs out; the cost is the walk.
  - **When it dies:** the sound carries across the whole farm and the creature comes to look.
  - **Running low:** it dims steadily. It never flickers.
  - **Repairs:** fixing creature damage takes 1 scrap. One scrap is salvaged free each dawn; extra scrap costs 15 coins.
  - **Left dead at dawn:** costs one extra trampled plot.
- **The unattended farm:** The longer nobody is outside, the more freely the creature roams, and the more crops and fences are wrecked by dawn.
- **Moonflowers:** The most valuable crop, harvested only in the dark. They glow faintly, so whoever picks them is easy to see.
- **It attacks the light:** From day 6, if every player stays inside, the creature bangs at the barn doors and then goes after the generator (see Light Is the Rule).
- **Night length:** nights 1 to 6 are about 5 minutes. The Harvest Moon (night 7) has no timer: it ends when the Prize Pumpkin's cart rolls out the farm gate, or when everyone is dead. A hard cap of 15 minutes keeps it from dragging. If the cap is reached, dawn comes, and the cart counts as out only if it's past the fields.

### The Harvest Moon

The final night has a three-act shape, run by the AI Director's finale profile:

1. **Loading.** At dusk the Prize Pumpkin has been moved to the barn. The team loads it onto the festival cart in the lit barn while tension builds. Then the generator fails during loading, the barn goes dark, and the barn is no longer safe.
2. **The push.**
   - **The cart:** carries a lantern. It's slow and squeaks, and its speed depends on how many players push it (it doesn't use physics).
   - **Attacks:** the creature knocks pushers off it with a jumpscare-style knockdown. Each stall lets it take a bite out of the pumpkin, dropping it one size, to a maximum of 2 bites per escort.
   - **Ghosts** can flicker the cart's lantern.
3. **The gate run.** A guaranteed peak as the cart nears the gate, then release when it rolls out.

---

## Jumpscares

The creature almost never kills during the day, but it can still terrify. The game never tells players the day is safe; they learn it, and doubt it.

A daytime jumpscare:
- knocks the player down (ragdoll);
- makes them drop what they're carrying;
- leaves them **Shaken** for 60 seconds.

Then the creature vanishes back into the corn. Jumpscares never Taint.

### Scare Moments

- **The disarm lunge:** While a player kneels to disarm a bear trap, the stalks part and the creature lunges at them, then pulls back into the rows.
- **The trap:** A player prying themselves out of a bear trap looks up to see the creature standing in the rows, watching, before it disappears.
- **The shed:** A player opens the shed to check the pegboard and the creature is inside, or the door slams shut behind them.
- **The whisper:** A teammate's voice speaks right behind a player, even though that teammate is across the field.
- **Your own voice:** On rare occasions, a player hears their own voice whispering their name from the corn. It won't fool them, but because it almost never happens, it's deeply unsettling.
- **Fake-outs:** The corn rustles and something bursts out, but it's only a crow. These keep players from relaxing between real scares.
- **Hallucinations (from day 5):** A player sometimes sees the creature standing in the field or at the edge of the corn for a moment, and then it's gone.
  - Nobody else sees it, and there's no knockdown and no dropped items.
  - Tainted players see them more often.
- **The wrong count:** Rarely, a player looking across the field sees one more farmer than there should be, wearing a teammate's hat, standing still at the edge of the corn. When they look back, it's gone. It's cheap to build (a static model and a timer).
- **The scarecrow moved:** A farm scarecrow is in a slightly different spot each morning, facing the farmhouse. Never explained, never dangerous.

### Making Them Land

- **Keep them rare:** Too many jumpscares and players get used to them. Long quiet stretches make each one hit harder.
- **Build up first:** Silence, the insects cutting out, or a voice calling from nearby works better than a scare out of nowhere.
- **Make them cost something:** Dropped items and being Shaken mean a scare matters for the game, not just for the moment.
- **Let the AI Director time them:** It decides when a scare is due and randomizes where, within the rules above, so players can't learn the pattern.
- **Sound does most of the work:** Budget more time for audio than for the creature's model.

---

## Death and Respawning

Death should matter without leaving anyone bored for long.

### Out Until Dawn

- **Respawn at dawn:** A player killed stays dead until the next dawn and comes back with the survivors.
- **Medical bill:** Each death costs the team money at dawn, so protecting each other directly protects the farm. Day deaths count the same as night deaths.

| Players | First death each night | Each later death | Nightly cap |
|---|---|---|---|
| 4 | 25 | 50 | 120 |
| 3 | 20 | 40 | 96 |
| 2 | 15 | 30 | 72 |

- **The floor:** the bill never takes the bank below 4 coins, the price of a turnip seed pack.
- **Deferred bills:** any part of the bill the bank can't cover is added to the final payment, so a death is never free.

### Dead Players Stay Involved

- **Ghost spectating:**
  - Dead players can follow their teammates.
  - Within about 20 m of themselves, they see the creature only as a smeared silhouette (the glimpse rule applies to ghosts too). Beyond that, they see it only through animals and crows reacting.
  - Ghosts never see traps: a ghost who saw every trap could read out the whole morning sweep.
- **The lantern flicker works on any light.** A dead player can make any light near a living teammate flicker: a carried lantern, a barn bulb, a porch light, the moonflower glow, or the festival cart's lantern. It has a short cooldown, so it stays meaningful.
  - **Nothing else in the game ever flickers a light,** whether the generator, ambience, weather or the lobby. One stray flicker would break the only honest signal.
- **Rustling the corn:** Dead players can rustle stalks to point at something, but the creature can fake that.
- **Static voices:** Living players can still hear dead teammates in proximity chat, but only through heavy static.
- **The crow:** A ghost can possess one crow per night for 20 seconds and fly it.
  - Crows are everywhere on the farm and the creature ignores them, so it's a way to scout and point.
  - The creature also sends fake crows, so a weird crow is a hint, not proof.

### The Dead-Voice Twist

Once a player dies, the creature is more likely to mimic their voice.
- **Same static:** when it does, it runs the voice through the same static as real ghost voices, including in targeted lures. A real dead teammate and the creature's fake sound alike.
- **Night lures heard by all:** at night these lures are world sounds, so the whole team can check for a flicker together.

**The flicker is the tiebreaker.** A static voice backed by a flickering light is a real teammate; a voice with no flicker might be the creature. The dead player is trying to help, the creature is trying to lure, and the living have to decide who to trust.

---

## Daytime Threats

Traps, voice lures and jumpscares already fill most of the day, so other daytime harm is kept to a small pool. The creature gets a daily disturbance budget, a fixed number of these it can spend each day, rising over the season.

### Sabotage Pool

- **Trampled crops:** Plants are destroyed where it roamed overnight: one plot a night, two if nobody was outside, and one more if the generator was left dead.
- **Stolen tools:** A watering can or hoe goes missing and turns up somewhere creepy, like the edge of the treeline, often next to an armed trap. Picking it back up Taints you.
- **Broken fences and gates:** Animals escape, so someone has to round them up far from the group.

### Setting Up the Night

- **Taint sources:** Dead crows and strange seeds left in the fields (see The Taint).
- **Clues:** Footprints, claw marks, or a moved scarecrow hint at where it will hunt tonight, but only if someone notices.

### Keeping It Fair

- **Annoying, not fatal:** daytime harm should cost time or money, and only become fatal through the player's own risks, so the day still feels like a break.
- **Every disturbance has a fix,** like repairing, rounding up or washing, so it feels like a task and not just bad luck.
- **Ramp-up:** day 1 might have one broken fence; by day 6 the whole pool is in play.

The core trade-off: the more players investigate and fix during the day, the safer the night is, but that time comes out of farming.

---

## Crops

Prices are in coins per plot. "Grows in N days" means the crop is ready on the Nth dawn after planting. For example, a turnip planted on day 1 is ready on the morning of day 2.

| Crop | Grows in | Seed cost | Sells for | Profit | Notes |
|---|---|---|---|---|---|
| Turnips | 1 day | 4 | 10 | 6 | Short and safe. Low value, steady money. |
| Pumpkins | 2 days | 10 | 28 | 18 | Low and sprawling. Unlocks at dawn 4, as a reward for the first payment. |
| Moonflowers | same night | 25 | 60 | 35 | Unlocks on day 3. Planted by day, harvested that night, wilted by dawn. They glow. |

- **Plots and labor:**
  - **Plots:** the farm starts with 16 field plots, and upgrades add up to 24.
  - **Labor:** planting, watering and harvesting are each a hold of a few seconds, and walking between them takes time too. Labor is measured in seconds, and plots-per-player is worked out from that. The starting estimate is about 6 plots per player per day, so nobody can work the whole farm alone. Plots are the bottleneck.
  - **Layout:** the plots are split into two fields far apart, one in front of the barn and one by the shipping crate, with corn rows between them.
- **Moonflowers:**
  - **The bed:** 1 moonflower plot per player (2 to 4 plots).
  - **Value:** they are by far the best crop per plot, and a large share of the season's income. That's intended, since it pushes people outside at night.
  - **Unpicked flowers:** a moonflower left unpicked at dawn becomes a Taint object in its plot. Touching it Taints you, and the plot can't be replanted until someone clears it.
- **End of season:** crops still in the ground at the final dawn sell at 50%, so late planting isn't wasted.
- **Corn is not a crop:** It can't be planted, cut or sold. The wild corn ring is always there.

### The Prize Pumpkin

One object the whole team cares about for seven days gives the season a face. Friends will name it, and they will be furious when the creature takes a bite out of it.

- **The patch:** One giant pumpkin, planted on day 1 in its own patch. The patch is at least 30 m from any building's door, in the open between the farmhouse and the first corn strip.
- **Watering:** it grows bigger every day it is watered, and visibly shrinks or rots on days it isn't.
- **Guarding:**
  - To reach Giant, someone must also guard it: be outdoors within 20 m of it for at least 60 seconds, on at least 2 of nights 1 to 6.
  - Time spent inside the light of a lit doorway doesn't count.
  - Carrying a lantern is allowed; it's a risk the guard chooses.
- **The creature wants it:**
  - Damage to the Prize Pumpkin is on its sabotage list from day 3.
  - It gnaws the pumpkin on any night nobody is within 20 m of it, dropping it one size.
- **On the Harvest Moon,** the team loads it onto the festival cart and escorts it to the farm gate (see The Harvest Moon).
- **Its size is the score.** A bigger pumpkin pays more at the festival, and that money counts toward the final payment.

---

## Season and Numbers

A season is 7 days. Night 7 is the Harvest Moon, the final night. All numbers here are starting values, to be checked with the season simulator before Phase 4 (see Build Plan).

### Debt and Payments

The team starts with 60 coins. The debt scales with player count:

| Players | Total debt | First payment (dawn after night 3) | Final payment (dawn after the Harvest Moon) |
|---|---|---|---|
| 4 | 1,300 | 255 | 1,045 |
| 3 | 1,040 | 204 | 836 |
| 2 | 780 | 153 | 627 |

- **Early payment** is allowed at any dawn.
- **What the final payment includes:** the Prize Pumpkin's festival money counts toward it. Any foreclosure penalty and any deferred medical bills are added to it.
- **Tuning target:** a median team needs to deliver a Large Prize Pumpkin to make the final payment.

### Winning and Losing

- **Win:** make the final payment and get the cart out the gate, with at least one player alive when it leaves.
- **Foreclosure Notice:** a missed first payment doesn't end the season.
  - The shortfall × 1.5 is added to the final payment.
  - The bank seizes one upgrade or 2 plots, its choice.
- **Lose:**
  - miss the final payment; or
  - everyone dies during the Harvest Moon before the cart is out.

  A full wipe on any earlier night isn't a loss; it just costs medical bills and farm damage.

### Prize Pumpkin Payout

| Size | How | 4 players | 3 players | 2 players |
|---|---|---|---|---|
| Giant | Watered all 7 days and guarded on 2 nights | 250 | 200 | 150 |
| Large | Watered 5 to 7 days | 150 | 120 | 90 |
| Medium | Watered 3 to 4 days | 75 | 60 | 45 |
| Sad | Watered 0 to 2 days | 20 | 16 | 12 (and the festival laughs at you) |

The size drops by one for each night the creature gnawed it, and for each bite during the escort (at most 2).

### Economy Check

A hand check of the first payment, assuming no deaths, turnips on every tendable field plot, and moonflowers from day 3.

**4 players (16 field plots, 4 moonflower plots):**

| Day | Coins |
|---|---|
| Day 1: start 60, plant 15 turnips (−60) | 0 |
| Day 2: sell 15 turnips (+150), plant 16 (−64) | 86 |
| Day 3: sell 16 (+160), plant 16 turnips (−64) and 4 moonflowers (−100) | 82 |
| Night 3: sell 4 moonflowers (+240) | **322 vs 255 owed** |

**2 players (8 field plots, 2 moonflower plots):**

| Day | Coins |
|---|---|
| Day 1: plant 8 turnips (−32) | 28 |
| Day 2: sell 8 (+80), plant 8 (−32) | 76 |
| Day 3: sell 8 (+80), plant 8 turnips (−32) and 2 moonflowers (−50) | 74 |
| Night 3: sell 2 moonflowers (+120) | **194 vs 153 owed** |

A perfect start has about 25% headroom. Scheduled sabotage and a death or two eat most of it, which is the right pressure for a first payment. The 8 of 12 tendable plots at 2 players, and 16 of 24 at 4, leave about a third of everyone's time for sweeps, washing and repairs.

### Season Simulator

Before Phase 4, build a season simulator and gate Phase 4 on it. It runs at 2, 3 and 4 players with every rule in this doc applied, including store purchases.

**The median team:**
- plays greedily, keeping about a third of its time for chores;
- takes the scheduled sabotage, plus one trampled plot a night (two on unattended nights);
- takes one death on each of 3 nights;
- delivers a Large pumpkin.

**Targets:**

| Measure | Target |
|---|---|
| Median team clears the first payment | about 85% of runs |
| Median team clears the final payment | 55–70% of runs |
| Spread across player counts | at most 10 percentage points |

**Playtest check:** live playtest logs must land within 15 points of the sim before the numbers are frozen.

### Ramp-Up (4 Players)

With fewer players, the payments, the medical bill, trap counts and the disturbance budget all scale down: 60% for 2 players and 80% for 3, rounded up.

| Day | Daytime disturbances | Traps set that night | Voice | New this day |
|---|---|---|---|---|
| 1 | 1 | 2 bear traps, 1 pit | Exact clips | Turnips; Prize Pumpkin planted |
| 2 | 1 | 2 bear traps, 2 pits | Exact clips | |
| 3 | 2 | 3 bear traps, 2 pits | Exact clips | Moonflowers; Taint sources start; Prize Pumpkin can be damaged; first payment at dawn |
| 4 | 2 | 3 bear traps, 2 pits, 1 bell line | Spliced clips | Pumpkins; more convincing mimicry; tripwire bells |
| 5 | 3 | 4 bear traps, 3 pits, 1 bell line | Spliced clips | It can break the shed lock; hallucinations; it can move a flag |
| 6 | 3 | 5 bear traps, 3 pits, 2 bell lines | Spliced clips | It attacks the light if everyone stays inside |
| 7 | 4 | Harvest Moon: hunts all night | Spliced clips | Push the cart; final payment at dawn |

### Players Joining and Leaving

**Joining:** a friend who joins late enters at once as a ghost (crow, flicker, static voice) and gets a body at the next dawn. On the Lobby lines setting, they do a short staged recording first.

**Leaving:**
- A player who drops counts as absent from the next dawn.
- Their character stays as an idle farmhand that doesn't count toward headcount.

**How the debt rescales:**
1. Each of the 7 days carries an equal share of the base debt (1,300 ÷ 7).
2. Each day's share is scaled by the headcount at that day's dawn (100/80/60%), and is fixed once that dawn begins.
3. **Total debt** is the sum of all 7 days' shares. Past days use their recorded headcount; future days use the current one.
4. **Still owed** is the total debt, minus all payments made (including early ones), plus any foreclosure penalty and deferred medical bills. Those additions never rescale.
5. **The split:** if the first payment is still ahead, it takes 255/1,300 of the total debt (rounded), and the final payment takes the rest.
6. **Everything else follows headcount:** the moonflower bed, the medical bill, trap counts and the disturbance budget.

**Worked example:** 4 players, one drops before dawn 2. The total debt becomes 185.7 + 6 × 148.6 = 1,077, so the first payment is 211.

**Rules:**
- A payment due at a dawn is locked when that dawn begins, so quitting saves nothing.
- **Below two players:** if the headcount at a dawn would be 1, the game saves at that dawn and the season pauses ("Waiting for a farmhand") until a second player joins. Solo play isn't supported.

### Length and Saving

- **Dawn saves:** the game saves at every dawn, including any foreclosure state, so a season can be played over several evenings.
- **Portable saves:** any player who was in the season can host it.
- **Host leaving:** if the host leaves, the session ends for everyone with a "host left" card, and the season resumes from the last dawn save. There's no host migration. Lost progress is at most one day and night.
- **Short season:** a 3-day option for a single sitting, with the Prize Pumpkin growing faster. Its debt, payments and payout table are set with the season simulator.

### The Next Season

- **What carries over:** upgrades and plots. Spare coins carry over at 25% as "savings".
- **The debt grows.**
- **The creature gains one new trait** each new season, for example copying tools better or setting more pits, so the farm players built is worth defending again.

### Upgrades

Over the season, players unlock new seeds, upgrade tools and expand the farm. Upgrades are bought at the store by the shipping crate.

| Item | Price | Notes |
|---|---|---|
| Shed lock | 40 | Caps trap theft at one a night; broken from day 5 |
| Scrap | 15 | For generator repairs; one free each dawn |
| Quiet watering can | sim | Slower, but heard less far |
| Walkie-talkies and batteries | sim | |
| Brighter lanterns | sim | |
| More scarecrows | sim | |
| New plots (up to 24) | sim | |
| Flare gun | sim | One shot, refilled each dawn. Scares the creature off for 30 seconds. Anyone can carry it. |
| Cosmetic hats and overalls | sim | Phase 5. Bought with leftover coins once the debt is paid. |

"sim" means the price is set with the season simulator before Phase 4.

---

## Mechanics That Tie Farming and Horror Together

- **Noise:** Tractors, watering cans, the well pump, the barn door and your own voice all make sound. Fast tools are loud; quiet tools are slow. Crouch-walking is silent but slow.
- **Light:** Lanterns help you work at night but make you visible from far away.
- **Crop risk vs. reward:** Moonflowers pay the most but have to be picked in the dark, and the far field means a long walk through the corn.
- **Fences and scarecrows as defense:** You build up your farm's protection over time, like a light tower-defense layer.
- **Splitting up:** One player waters the far field, one checks the traps, one sells at the stand, one guards the Prize Pumpkin. The farm is too big for a group to stay together.

---

## Roles (Optional, Good for 4 Players)

The four roles are Farmer, Rancher, Mechanic and Tracker. The flare gun is a store item anyone can carry, not a role.

- **Farmer:** gets one extra crop on every fifth harvest.
- **Rancher:** handles animals, which act as early warning when the creature is near.
- **Mechanic:** fixes the tractor, generator and lights, and refuels the generator faster.
- **Tracker:** spots trap clues like fresh dirt and glinting metal more easily, and disarms bear traps faster.

With fewer than 4 players, roles are optional and each player can pick any one. A team doesn't need every role to win.

---

## Making It Fun With Friends

Scary is half the job. The other half is the stories the group tells each other afterward.

### The Dawn Report

At every dawn, a short newspaper-style card shows the night. It also lists the dawn's cash-in, medical bill and payment, in that order.

- **"Best Impression":** the lure that worked best, replayed in the creature's voice (or as text, for players on Off). For example: *"The creature said 'come look at this' as Sam. Alex walked 40 meters into the corn."* Targeted lures nobody else heard are revealed here.
- **"Most Wanted":** who the creature chased the most.
- **"Cause of Death":** written like a small-town obituary. *"Jordan, 2nd night. Survived by 11 turnips."*
- **"Hero of the Night":** whoever refueled the generator, guarded the pumpkin, or freed a teammate.

Players can skip it. Replays follow each player's voice setting. This is where the "remember when..." moments come from, and it's what makes people want to play another night.

### Season Awards

At the end of a season, a short awards screen. Every player gets at least one award. Examples:
- most traps disarmed;
- most times fooled by a voice;
- most coins earned;
- longest time spent hiding in the barn ("Barn Goblin").

### Emotes and Physical Comedy

- **Emotes:** a small set (wave, point, shrug, scream).
- **Ragdoll knockdowns** on jumpscares. Watching a friend get launched into a pumpkin patch is funny, and funny right after scary is the best rhythm for friend groups.
- **Carrying:** players can pick up and carry a downed or slowed teammate a short way (slowly, noisily).

### Onboarding

Days 1 to 3 are the tutorial, and the ramp-up table is the curriculum.
- **One introduction per verb:** each new verb gets one introduction inside the game world, such as a note on the shed door or the dusk bell.
- **Never say the day is safe:** no introduction ever tells players that. They learn it, and doubt it.

### Difficulty and Group Settings

- **Easy:** fewer traps, gentler bills.
- **Normal.**
- **Nightmare:**
  - less generator fuel;
  - day deaths more likely, only through wider distance bends (never extra conditions);
  - no voice tells.

  The whistle stays honest, and the one tell that always remains is the voice coming from the wrong place.
- **Group options:** a "no live clips" lobby toggle, and streamer-safe mode (see Voice Settings and Consent).

---

## Build Plan

Starting from scratch: nothing below is built yet. Only move on once the current phase is fun to play. Each phase has a "done when" test, checked in at least 2 sessions, with at least one tester who hasn't read this doc, plus a measure from the logs.

A review sits between each phase and the next:
1. Read the phase's playtest logs and notes.
2. Add every new problem they show to Open Issues.
3. Settle the open issues the next phase depends on, and any others that are now answerable, and update the sections they touch.
4. Start the next phase only when nothing it depends on is still open.

**Phase 1 (prototype):**
- **First, before anything else:** Steam voice between two machines (see Engine and Tech).
- **Then the farm:**
  - one small field, the shed and the barn;
  - one day and one night, 2 players online, with proximity voice chat;
  - turnips (plant, water, sell), with every hold time logged;
  - a noisy watering can, and one generator run;
  - crouch and go-still;
  - three ambience layers driven by a simple scripted creature state (Lurk, Stalk, Chase);
  - the creature wandering and chasing by sound, bear traps and pits in scripted spots, and generic pre-recorded voice lines from the corn;
  - the spatial audio test (see Testing).
- **No AI Director yet.**
- **Done when:** the day feels safe, the night feels tense, and at least 30% of voice lures make the target walk toward them.

**Phase 2:**
- staged lobby recording in the barn, with barn chatter and the voice settings;
- the creature replaying those lines;
- the creature stealing bear traps from the shed and the pegboard;
- death with respawn at dawn and the medical bill;
- the two-field farm layout with corn rows between them;
- up to 4 players.
- **Done when:** hearing a friend's recorded voice from the corn fools someone, and trap sweeps feel worth doing.

**Phase 3:**
- the creature favoring dead players' voices;
- the AI Director, the day arc and jumpscares;
- the Taint and Shaken;
- ghosts with the lantern flicker and the crow;
- the whistle, flags and the Dawn Report.
- **Done when:** dead players stay engaged, the living argue over whether to trust a static voice, and someone laughs at the Dawn Report.

**Phase 4:**
- **Gate:** the season simulator first, and it must hit its targets (see Season Simulator).
- **Then:**
  - the full 7-day season with crops, the economy and the Prize Pumpkin;
  - upgrades, roles and payments;
  - Foreclosure, saving, and joining and leaving;
  - the short season and the Harvest Moon.
- **Done when:** teams sometimes win and sometimes lose, and the logs land within 15 points of the simulator.

**Phase 5 (later):** live voice clips from proximity chat, spliced clips, the next season, cosmetics.

**Fake it first:** scripted trap spots and simple timers can stand in for smart AI until the core loop is proven.

**Why live clips are in Phase 5:** capturing, trimming and splicing speech is the hardest technical piece, and staged lobby recordings plus barn chatter may be scary enough on their own. Prove the game is fun without them first.

---

## Engine and Tech: Godot

The game is built in Godot 4. It's free and open source under the MIT license, with no royalties ever.

### Networking

- **Steam:** the game uses GodotSteam with SteamMultiplayerPeer, which provides lobbies and invites. Friends join through the Steam overlay, and Steam relays get around port-forwarding problems.
- **Development:** plain ENet over LAN is used for development only.
- **Testing two machines:** use Steam's free test AppID (480) until the game has its own.
- **Authority:**
  - **Each player's machine owns:** their own movement and camera.
  - **The host owns:** the creature, the AI Director, traps, the pegboard, the economy (coins, sales and payments, with no selling from a player's own machine), Taint, deaths and the cart, and checks every interaction.
- **Fair calls:** when a close call (a lunge, a kill, reaching a lit doorway) depends on lag, the victim's own position wins. Lag must never kill anyone.

### Voice

- **Steam voice when shipping:** voice runs through Steam.
- **Two backends:** voice sits behind one interface with two backends, Steam voice for shipping and an Opus-over-ENet backend for development. The development backend can be fed from a WAV file, so voice can be tested alone.
- **Mic mode:** proximity chat defaults to open mic with voice activity detection; push-to-talk is an option.
  - **Push-to-talk is the stealth option:** you're only heard (by friends and the creature) when you transmit.
  - **Open mic is the coordination option.**
- **Spatial audio:** each player's voice plays from an `AudioStreamPlayer3D` on their character, which is what makes position a real tell.
- **The creature's voice:**
  - Recorded clips play from an `AudioStreamPlayer3D` on the creature.
  - They run through the same voice chain as real players, so fakes don't stand out by sounding cleaner.
  - Fakes of a dead player use the ghost static chain.
- **How lures are sent:** voice clips are sent to every player at session start, so a lure is a short host message ("play clip X at position P for player Y"), not streamed audio.
- **Weak localization:** Godot's stock 3D audio is weak at telling front from back. If the Phase 1 test fails, evaluate the Steam Audio GDExtension, or add per-source occlusion and reverb so distance and corn cover are audible.

---

## Testing

Most testing can be done alone, with group playtests at the end of each phase.

- **Multiple copies on one computer:** use Debug > Customize Run Instances to run two to four copies of the game at once, on the ENet development backend.
- **Fake mic and network:**
  - a "mic from WAV" input, so each copy can "speak" different recordings;
  - simulated latency and packet loss.
- **Bot teammates:** simple stand-in players that walk to fields, do chores, play voice clips and can be killed. They give the creature targets and voices.
- **Recorded voices:** your own recordings, plus voice lines from friends who agree to it.
- **Logging:** the game records each day and night: who died where, which traps were sprung, which lures worked, how long each hold and chore took, how much money was made, and how long players stayed inside at night. The Dawn Report is built from the same logs.
- **"A lure worked":** defined once and used everywhere (logs, the Dawn Report, the AI Director and the Phase 1 gate). It means the target moved more than 10 m toward the source within 8 seconds.
- **The trap race:** log whether a solo, untainted player who starts prying at once survives.
- **Spatial audio test (Phase 1 gate):** with headphones, check that players can tell where a voice and a whistle come from at 10, 30 and 60 m.
- **Debug view:** a top-down view showing the creature, its behavior state, what it senses compared with true positions, the AI Director's tension meter, traps and players. It's used to check the AI is behaving fairly.
- **Group playtests:** solo testing can't show whether the scares and voice confusion work on real people, so play with friends at the end of each phase and log those sessions too. Record the session (with everyone's OK) and watch it back: the moments people scream or laugh are the design working; the moments they go quiet and bored are what to fix.

---

## Open Issues

Problems that still need solving, most important first.

### 1. Scope is large for a first build

Voice chat, voice recording and playback, a trap-setting AI that lures players, the AI Director, jumpscares, a farming economy and online multiplayer add up to a lot, starting from nothing. The phased Build Plan and moving live clips to Phase 5 help. The biggest risk is voice chat, so it's built first in Phase 1.

### 2. The numbers are untested

Every price, payment and trap count is a first guess. Store prices are still open. The season simulator gates Phase 4, and live logs must then match it.

### 3. Can players place sounds by ear?

The whistle, the "voice from the wrong place" tell and Stalk direction all depend on players placing sounds by ear. This gets tested in Phase 1. If it fails, improve the spatial audio (see Voice) or turn on the whistle's lantern flash.

### 4. Do sound signatures make the four bodies feel different enough?

All four bodies hunt the same way. If players stop caring which one they got, consider one small behavior quirk each (the husk is quieter in corn, the boar is louder but faster). Check after Phase 3.

---

## Next Steps

1. Set up the Godot project in this repo.
2. Get Steam voice working between two machines (test AppID 480), with the development backend alongside it. This is the riskiest piece, so do it first.
3. Build Phase 1 and playtest it.
