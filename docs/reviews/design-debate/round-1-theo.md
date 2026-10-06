# Round 1 — Theo (creature AI, fear & tension)

## Strong features

- **Traps as tomorrow's level design** (Night Traps, pegboard). The creature authors the next morning, and the pegboard shows at a glance how much it authored. It's honest diegetic UI.
- **The glimpse-only rule** (What players see of it). Lunges cut to black before a full view, and silhouettes stay distant. That rule protects the monster for the whole season. Keep it sacred.
- **"Hear the farm go quiet"** (Readable states). Audio state tells are the right foundation: fear turns into skill without turning into safety.
- **The creature's voice runs through the same chain as real players** (Engine and Tech). It's the most important tech line for mimicry.
- **The lantern flicker and the dead-voice twist.** These give the dead a real job and give the living something to argue about.
- **Cheap dread:** the scarecrow that moved, the wrong count, private hallucinations.
- **The Director's no-scare opening and the 2-minute same-player spacing.** Both are correct.

## Issues

**T1 — BLOCKER — The Taint / Jumpscares / Director.** A jumpscare Taints you until dawn and can't be washed off. The Director "spreads attention" to players who haven't been scared yet. Put together, by dusk on an active day every player is Tainted by Director choices, not by their own play. That causes three failures:
(a) The cue no longer tells anyone anything. If everyone has black hands, nobody is "the Tainted one."
(b) Tainted is one of the day-death conditions, so the Director produces the very condition that lets it kill. That breaks "always the player's own mistake."
(c) Night tracking becomes universal, so trail-following stops being a consequence of anything.
*Change:* A jumpscare costs a knockdown, dropped items and a "Shaken" state (shorter sprint for 60 s). It does not Taint. Taint comes only from causes the player chose: touching creature leavings, picking up a stolen tool, leaving items out at dusk. Every Taint can be washed off at the well.

**T2 — MAJOR — Day Deaths, bear-trap clause.** The Lure Combo uses a teammate's voice to pull a player toward an armed, hidden trap. A player who is caught alone can then die. Being lured by an indistinguishable fake into a hidden trap is not a "mistake" in any sense the player will accept. *Change:* A day bear-trap kill must be a telegraphed race. When the trap springs, the creature's sound signature starts approaching from a set distance. Prying free in time means you live, shaken. Failing means you die. A teammate shortens the pry. The kill stays possible, and the trap becomes the day's best tension beat.

**T3 — MAJOR — The Director.** The Director is a single tension meter with three rules. Two things are missing:
(a) **Knowledge separation.** The doc never says whether the creature knows where players are beyond what it senses. If it does, hiding is meaningless and players feel cheated within an hour. *Rule:* the creature acts only on what it hears, sees or reads from the Taint. The Director may nudge it toward a *region* (Alien: Isolation's "menace" hinting), never toward a position.
(b) **Phases and profiles.** Use build-up, peak, fade and relax (L4D), with separate day, night and finale profiles. A 5-minute night and a 10-minute day can't share one meter tuning. Add the number of creature "presence events" per player per phase as a tunable.

**T4 — MAJOR — Chase / How It Hunts.** Players have no defensive verbs. The chase is lost by "breaking line of sight for a few seconds," and the farm is ringed with corn that blocks sight. That makes every untainted chase trivially escapable: step into the rows and you're gone. *Change:* Losing a chase requires breaking sight **and** going quiet. Add crouch-walk (silent, slow) and "go still" (no movement, your own heartbeat rising in your audio). Sprinting through corn makes stalk noise. State explicitly that live mic volume feeds the creature's hearing, so a scream gives you away. That is the Lethal Company rule, and it's our best tension generator.

**T5 — MAJOR — Core Loop / Daytime Threats.** The day is supposed to be the cozy half, yet it carries Lure, Stalk, jumpscares, hallucinations, the wrong count, sabotage, traps and possible deaths across 8 to 10 minutes. The night gets 5 minutes. Most of the horror minutes are in daylight, so the contrast the doc names as its hook will erode. *Change:* Give the day a fixed arc. The first third is calm (no Lure, Stalk or scares, only sabotage evidence). The middle allows low presence. The last third builds into dusk. Cap big scares at 1 per player per day. Make the town stand an absolute daytime sanctuary.

**T6 — MAJOR — Nights / Tool Shed: the lit-building rule leaks.** "Won't enter a lit building" is the night's only hard rule. Yet a trap kept in a lit building "is simply gone by morning," and from day 6 the creature "works at the barn doors" with no stated outcome. Once one rule turns out to be a lie, players assume every rule is. *Change:* The creature never enters a lit building, full stop. A hoarded trap vanishes only if the generator went dark that night; otherwise it turns up in the corn at dawn. When it tests the doors, the doors bang and bow while the creature circles to **the generator** and starts damaging it. Light is the rule, and the creature attacks the light.

**T7 — MAJOR — Harvest Moon finale.** The doc defines the objective (escort the cart) but not what the night feels like. How does the creature behave toward the cart? Can it bite the pumpkin mid-escort? What happens to the pushers? Is there any lit refuge on the route? Can the Director pause pressure? *Change:* Script a three-act Director profile:
1. Load the cart in the lit barn. Tension builds while the generator is attacked.
2. The push. The cart carries a lantern, and the creature knocks pushers off it, which stalls the cart. Each stall lets it take a bite, dropping one size.
3. The gate run. Guaranteed peak, then release.
Ghosts flicker the cart lantern.

**T8 — MAJOR — Dead-Voice Twist: two specs that protect the doc's best scare.**
(a) When the creature mimics a dead player, it must use the **ghost static chain**. If it plays them clean, the fake is obvious, because the real dead player is in static.
(b) **Nothing else in the game may flicker a light.** That covers the generator running low (it dims steadily, it doesn't flicker), art-pass ambience, storms, and the lobby's guttering lantern, which needs to be a different effect. One stray flicker anywhere breaks the only honest signal.

**T9 — MINOR — Readable states: overloaded channels.** Crows are currently:
- the Stalk tell (lift off),
- the Retreat tell (settle),
- the fake-out jumpscare,
- a Taint source,
- ghost possession,
- creature-sent fakes.

That is six jobs on one signal. *Change:* Drop crows from the Stalk and Retreat tells. Use a constant insect/frog bed that cuts out on Stalk, so silence is a positive layer dropping away rather than an absence of animals (escaped animals would cause false Stalk tells). Also, the husk's "dry rustle" signature can't sound like ordinary corn rustle, or a husk season loses its chase tell.

**T10 — MINOR — The whistle.** The HUD marker is the problem behind Open Issue 3, and it is a non-diegetic crutch. *Change:* Drop the marker. The whistle is an unfakeable 3D sound, and spatial audio already gives position. It stays honest and costly, and it stays inside the fiction.

**T11 — MINOR — Build Plan.** Phase 1's test is "the night feels tense," but the audio state tells don't arrive until Phase 3 with the Director. *Change:* Move the Lurk, Stalk and Chase ambience layers and the crouch/go-still verbs (T4) into Phase 1. They're cheap, and they're the tension.

VERDICT: DISAGREE — open points: T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11
