# Round 1 — Priya (co-op multiplayer & production)

## Strong features

- **Honest-signal toolkit** (How Players Fight Back; Death and Respawning). Whistle, flags, flicker-on-any-light and radios each give players a *costly* verification channel. That's how you make a mimic game argue-y instead of paranoid-and-silent. Flags letting a team talk less (and feed the creature less) is a strong emergent trade.
- **Dead players have jobs** (flicker, crow, static voice). Spectator boredom kills co-op sessions, and the crow is cheap and funny.
- **Staged barn recording** (Recording Lines That Sound Scared). It doubles as onboarding and as the first scare. Best-take selection by loudness/pitch variance is a cheap, real heuristic.
- **Dawn Report + Season Awards.** Built from the same logs as testing (Testing Solo → Logging), so it's nearly free and gives the group its "remember when". Correct priority.
- **Phase gates with a fun test** (Build Plan), and voice chat de-risked first (Next Steps). Right instinct.
- **Prize Pumpkin cart escort.** It gives the finale a readable co-op objective that two players pushing it makes better. Good social design.

## Issues

**P1 — blocker — Build Notes (Consent), Resolved Issues.** The hard consent gate is wrong on three fronts.
- *Legal:* voice recordings are personal data. Under GDPR Art. 7(4), consent isn't "freely given" when it's a condition of service for processing the service doesn't need. Here it isn't needed: lobby lines are optional and fallback voices exist (Keeping Players on In-Game Voice). Minors (COPPA) make it worse.
- *Contradictions:* "anything they say, including off-guard remarks" contradicts "only push-to-talk speech is kept". "Kept only for that match" is undefined when a season spans evenings (Dawn saves). And Phases 1–4 record no live clips at all, yet everyone has to accept live-clip terms on day one.
- *Social:* one friend declining closes *their* game, so the group can't play together. That's the worst possible onboarding.

*Change:* no gate. Each player gets their own setting with three tiers: **Off** (fallback voice), **Lobby lines** (default when recorded), **Live clips** (opt-in, Phase 5). A player's tier controls every replay of their voice: creature, Dawn Report and streamer mode. Lobby lines stay on the owner's disk. They go to peers at session start and live in peer memory only, never in the host save. Drop the "on any stream" promise, because the game can't control other people's recordings.

**P2 — major — Voice Mimicry / Recording Lines.** The lobby line list is public. Everyone recorded the same 8 lines plus names. Through Phases 2–4 the creature can say *only those*, so groups will work out within one session that anything off-list is real. And "say something only you'd know" beats every fake. The tells, the 1/3-no-tell rule and splicing are all beside the point.
*Change:* (a) Capture 20–40 s of free barn chatter during the staged lobby (PTT/VAD-trimmed on the sender's machine, no splicing) and add it to the pool. That's much easier than in-match capture and can land in Phase 2. (b) Write a rule: lures fire when a call-and-response check is costly, e.g. at range, while the target is alone, or when the "speaker" is dead/static. (c) Never tell players the line list is the whole pool.

**P3 — major — Voice Mimicry, How It Works.** The doc never says who hears a lure. If it's a world sound, then when the creature calls Alex's name in Sam's voice and Sam is standing next to Alex, it gets exposed instantly and loses all value. If it's per-listener, then "the voice coming from somewhere the teammate can't be" stops being a shared check, and "Best Impression" replays need a defined audience.
*Change:* define it. Lures are **targeted** (only the target hears them, and only when no teammate is within ~15 m), except at night/chase where they're world sounds. Hallucinations are already per-player, so this fits.

**P4 — major — Engine and Tech: networking model.** "Clients send inputs" means every client's own movement lags by a full RTT. That's unplayable for first-person over consumer internet, and it's not how Lethal Company-likes ship.
*Change:* clients own their movement and camera. The host owns the creature, Director, traps, pegboard, economy, Taint and deaths, and validates interactions. Lobby clips are pre-distributed so lures are a host RPC ("play clip X at position P for peer Y"), not streamed audio.

**P5 — major — Engine and Tech: Steam vs custom.** This is presented as an open choice, but it decides lobbies, invites, NAT traversal, drop-in and the voice codec. The custom route also has no relay, so many friends simply can't connect without port forwarding.
*Change:* commit to Steam (GodotSteam + SteamMultiplayerPeer + Steam voice) now. Use plain ENet on LAN only for dev. Next Steps step 2 then becomes concrete.

**P6 — major — Build Plan sequencing.** The pitch says "traps, crops and the day/night economy are the hook", yet crops land in Phase 4. Phase 1's "the day feels safe" has nothing to *do* in the day, so you can't test splitting up, noise-vs-speed tools, or the cozy contrast. The fun gates also use n=1 ("walks toward it at least once") with testers who know it's a test.
*Change:* Phase 1 gets turnips (plant/water/harvest/sell), a watering can that makes noise and one generator run. Phase 4 keeps economy *tuning*. Gates use at least 2 sessions with at least one tester who hasn't read the doc, plus a log metric (e.g. at least 30% of lures produce movement toward the source).

**P7 — major — Length and Saving: drop-in and leaving.** Drop-in "at the next dawn" can mean a 15-minute wait. Leaving isn't covered at all, so a quitter is a free payment cut (2-player = 60%). And dawn saves sit only on the host, so the season dies if the host can't make it.
*Change:* a late joiner enters straight away as a ghost (crow/flicker) and gets a body at dawn, after a 30 s staged recording. Payments rescale *only upward* mid-season, or lock at the first payment. If someone drops, the season continues and the farmhand becomes an NPC idler. The save is portable: any player who was in the season can host it.

**P8 — minor — Death and Respawning vs Discord.** The doc accepts that Discord weakens mimicry, but it also turns ghosts into perfect radar. Spectators see the creature live and can speak clearly off-platform, which breaks the flicker/static design.
*Change:* ghosts see the creature only within ~10 m of their own position, or only as the crows react to it.

**P9 — minor — onboarding.** That's ten-plus verbs (Taint, wash, whistle, flag, flicker, crow, pegboard, generator, radio, flare) and no teaching plan.
*Change:* state that days 1–3 *are* the tutorial. Each new verb gets one diegetic introduction (a note on the shed door, the bell). Long-term the ramp table is the curriculum.

**P10 — minor — Testing Solo.** Run Instances shares one mic and has zero latency. *Change:* add a "mic from WAV" debug input and simulated latency/loss. Define "a lure worked" (target moved more than 10 m toward the source within 8 s) once and reuse it for logs, the Dawn Report and the Phase 1 gate.

**P11 — minor — Economy Check.** It's not my lane (Mara will go deeper), but the 2-player check assumes 100% of day time on farming. That leaves zero slack for sweeps, washing and fixes, the exact chores the design wants. Simulate with a realistic chore tax (~30%).

VERDICT: DISAGREE — open points: P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11
