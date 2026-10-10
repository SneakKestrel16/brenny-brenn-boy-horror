I'm the CEO. I want to build the farming horror game described in `docs/01_design_doc.md` (2 to 4 player online co-op: farm by day, survive the creature in the corn by night). Read it in full before doing anything else. It is the source of truth for tone, pillars and scope; nothing outside its scope gets built without my approval. Its Build Plan and Open Issues sections are binding, and only I approve changes to the design doc itself.

The engine is Godot 4 (design doc section "Engine and Tech"). You have access to Blender for creating 3D assets.

## Setup

1. Move `01design doc.md` to `docs/01_design_doc.md` and update any references.
2. Create the Godot 4 project at the repo root (`project.godot`) with a Godot-appropriate `.gitignore` (ignore `.godot/`, exports and local voice recordings).
3. Confirm Godot runs headless in this environment (`godot --headless --version`) and that the project opens without errors. If Godot or Blender isn't available, stop and tell me what's missing instead of working around it.
4. Write a short `README.md`: how to open the project, how to run 2 to 4 local instances (Debug > Customize Run Instances), and where the docs and production files live.

## How the team works

Run this as a team of agents with defined roles. You (the main session, Claude) are the Director and run the studio day to day: you plan, assign tasks, integrate work, resolve conflicts and make decisions, but you don't build features yourself. I'm the CEO: I set direction, approve the things listed under CEO below, and playtest at each STOP. Everything else is your call; don't bring me decisions you can make yourself.

Naming note: the design doc's in-game pacing system is called the **AI Director**. Always use that full name in code, docs and tasks, so it is never confused with your role. Create each role below as its own agent definition in `.claude/agents/`, with instructions covering its responsibilities, the files it owns, and the communication rules in this prompt.

### Roles

- **CEO (me, not an agent):** Approves changes to the design doc, anything outside its scope, starting each phase, spending money or using my accounts, downloaded assets and their licenses, and any real person's voice recordings. Playtests at every STOP. Doesn't manage tasks or agents.
- **Director (you, Claude):** Owns the plan, the task board and the design pillars. Breaks phases into tasks, assigns them, routes questions, approves changes to shared contracts, and protects scope using the design doc's Build Plan: anything the doc puts in a later phase (live voice clips, spliced clips, the next season, cosmetics are Phase 5) stays out until that phase. Runs the between-phase review the design doc describes (playtest logs → Open Issues → settle what the next phase depends on) and proposes design doc edits to the CEO rather than making them. Decides everything else within the design doc without asking, and logs each decision in DECISIONS.md.
- **Game Designer:** Writes doc 02 (Systems & Economy) and doc 03 (Creature, AI Director & Scares). Turns the design doc's numbers into game data: crops, prices, payments, medical bill, player-count scaling, Foreclosure, the joining/leaving debt formula, store prices, the day-by-day ramp-up table, trap types, Corruption causes and effects, the AI Director's rules, the voice-line list and Dawn Report templates. Builds the season simulator (a script or spreadsheet in `tools/`) and makes it hit the design doc's targets before Phase 4 starts.
- **Level Designer:** Writes doc 04 (Farm Layout). Builds the gray-box farm in Godot: the wild corn ring and the strips reaching toward buildings, the barn, farmhouse, tool shed with the pegboard, well, generator and fuel drum, the two fields, the moonflower bed, the Prize Pumpkin patch (at least 30 m from any building's door), the shipping crate and store, the town stand, the farm gate and the cart route. Places trap spots, creature cover points, crows, scarecrows and animal pens. Starts with the small Phase 1 layout (one field, shed, barn) and expands to the two-field farm in Phase 2.
- **Network & Voice Programmer:** Writes doc 06 (Networking & Voice). Owns the riskiest piece: ENet networking with the host/client authority split the design doc defines, UPnP hosting and join codes with the manual and VPN fallbacks, joining and leaving, host-left handling, Opus proximity voice over ENet (via a GDExtension), open mic with voice activity detection plus push-to-talk, the voice chain the creature's fakes also run through, walkie-talkies, dead players' static, lobby recording and barn chatter, and the per-player voice settings exactly as the design doc specifies them. Builds the voice spike first.
- **Gameplay Programmer:** Writes doc 05 (Technical Design): overall architecture, scene and autoload layout, data loading, save at dawn, logging, and the debug top-down view. Builds player systems: controller, interaction holds, farming (plant, water, harvest), tools and carrying, noise emission, crouch-walk and go-still, Corruption, Shaken and washing at the well, carrying teammates, traps from the player side (getting caught, prying free, disarming, flags), the generator and lights, the festival cart, death, ghosts (spectating, lantern flicker, crow possession), the whistle, emotes, the Dawn Report and Season Awards screens, menus, HUD-free diegetic info, and settings.
- **AI Programmer:** Implements doc 03 on the creature side: hearing (including transmitted voice volume) and short-range sight, with hunting driven only by what the creature senses, the behavior states (Lurk, Lure, Stalk, Chase, Retreat) with their readable audio tells, trap setting at night, pegboard theft, sabotage with the daily disturbance budget, the AI Director's tension meter, phase profiles, day arc, town-stand sanctuary and private-event budget, day-death conditions and the trap race, the light rules (dark-building entry, generator attacks), the Harvest Moon finale, jumpscares, hallucinations and fake-outs, and the bot teammates used for solo testing. Starts with "fake it first" scripted trap spots and timers, as the design doc says.
- **3D Artist:** Creates models in Blender from the asset list in doc 07. Low-poly, real-world scale (1 unit = 1 metre), exported as .glb with consistent naming. Covers the four creature bodies (gaunt thing, scarecrow, boar brute, corn husk) built to be seen only in parts and glimpses, the farmer character with swappable hats, crops at each growth stage, the Prize Pumpkin at each size, corn, buildings, tools, traps, the pegboard, the festival cart, crows and farm animals.
- **Technical Artist:** Writes doc 07 (Art Direction & Asset List). Owns lighting, materials, shaders and post-processing: the day → dusk → night transition, darkness that is scary but playable, lantern and building lights, the ghost flicker effect (and making sure nothing else in the game ever flickers a light), moonflower glow, the Corruption stain on hands and sleeves, corn rendering that blocks sight and stays fast with 4 players, fog, and the ragdoll knockdown look. Also the Dawn Report newspaper card style.
- **Audio Designer:** Writes doc 08 (Audio Design & Sound List). Sets up audio buses and the mixing rules, and implements sounds (see Sound below). Audio carries this game ("budget more time for audio than for the creature's model"), so this role owns the creature's state tells, each body's sound signature, the church bell at dusk, ambience that goes quiet during Stalk, the Corruption heartbeat, and works with the Network & Voice Programmer on the voice tells (echo, pitch, missing crackle) and dead-player static.
- **QA / Reviewer:** Writes doc 09 (Playtest Plan), built around the "done when" fun test for each phase in the design doc. Reviews every completed task against its acceptance criteria and the design pillars, runs the project headless to catch errors, runs multiple instances to check multiplayer stays in sync, checks the voice settings and recording rules are followed to the letter, checks that the logs capture each phase's "done when" measures (lure success, trap race, spatial audio test), and files bugs as tasks. Never reviews its own work, and no task is done until QA passes it.

### Communication

Agents coordinate through shared files in `production/`, not memory. Every agent reads the relevant files before starting a task and updates them when it finishes.

- **production/TASKS.md:** The task board. Each task has an ID, owner role, status, dependencies and acceptance criteria. Only the Director creates or reassigns tasks.
- **production/CONTRACTS.md:** Formats that more than one role depends on: data file schemas (crops, traps, ramp-up, voice lines), network message and RPC names, which node runs on the host vs clients, node and asset naming, scale, folder layout, event, signal and trigger IDs, audio bus names, log format. Changes need Director approval and a DECISIONS.md entry before any dependent work starts.
- **production/DECISIONS.md:** A log of every decision that affects another role, with date, who decided and why.
- **production/QUESTIONS.md:** When an agent is blocked or needs something from another role, it writes the question here addressed to that role. The Director routes it. Questions only the CEO can answer (design doc changes, anything needing my accounts or my microphone) are marked **FOR CEO** and collected for the next STOP. Everything else the Director answers.
- **production/OPEN_ISSUES.md:** Problems found in playtests and reviews, mirrored from the design doc's Open Issues format, for the between-phase review.
- **production/handoffs/<task-id>.md:** Written when a task finishes: what was done, files changed, what the next role needs to know, open issues.

Rules:
- Each role edits only the files and folders it owns (define ownership in CONTRACTS.md). Changes needed elsewhere become a task or question for the owner.
- One task in progress per agent at a time.
- Commit to git after each task passes QA, with the message prefixed by role and task ID.
- If a request conflicts with the design doc, flag it to the Director rather than improvising.
- Follow the design doc's authority split: each client owns its own movement and camera, and the host owns everything else that affects gameplay (creature, AI Director, traps, economy, Corruption, deaths, cart) and validates interactions. Any feature that only works single-player is not done.
- No real people's voice recordings are committed to the repo. Test voices are synthetic placeholders or recordings I provide and approve.

### Phases and checkpoints

The design doc's Build Plan defines what each phase contains and its "done when" test. These phases follow it; don't pull work forward from a later phase.

1. **Pre-production:** Docs 02–09 plus the voice spike: Opus voice over ENet between two machines on different home networks, connected through UPnP and a join code.
   - **Order:** 06 and the spike first, then 02 and 04 together, then 03, 05, 07, 08, 09.
   - **Review:** each doc is reviewed by QA and checked by the Director against 01 for consistency.
   - **STOP** after the spike so I can test it with a friend on another network.
2. **Design doc Phase 1 (prototype):** everything the Build Plan lists for Phase 1, in gray box. **STOP for my playtest.**
3. **Design doc Phase 2:** placeholder audio. **STOP for my playtest.**
4. **Design doc Phase 3.** **STOP for my playtest.**
5. **Design doc Phase 4:** the season simulator must hit its targets first. Then the full season in gray box, then final art, lighting and audio across the whole game. **STOP for my playtest** after the full gray-box season and again after art is in.
6. **Polish:** bugs, menus, settings (difficulty, voice settings, no-live-clips toggle, streamer-safe mode), performance, build export. **STOP for final review.**

Each phase's contents and "done when" test are exactly as the design doc's Build Plan states; don't repeat or reinterpret them here.

Design doc Phase 5 (live clips, spliced clips, the next season, cosmetics) is out of scope until I approve it.

Between phases, run the design doc's review: read the playtest logs and my notes, add new problems to OPEN_ISSUES.md, propose how to settle the ones the next phase depends on, and get my approval before starting it.

At each STOP, give me a short summary of what's done, what specifically to test, how to run the build (including how to host and join with 2 to 4 players), the open issues, and the questions you want my feedback on. Wait for my answer before continuing.

### Sound

I haven't decided how final sound will be made. For now, the Audio Designer writes the full sound list in doc 08, sets up the buses and mix, and generates simple procedural placeholder sounds in code (wind, corn rustle, the insect and frog bed, crows, animals, footsteps, tools, well pump, generator, church bell, tripwire bells, whistle, chain drag, clicks, coat flap, husk rattle, heartbeat, radio and ghost static, chase sting). Generic fallback voice lines are placeholders too. Mark every placeholder in the sound list so it can be replaced later. Don't download audio or voice packs from the internet without listing the source and license for my approval first.

## Start

1. Complete Setup above.
2. Read docs/01_design_doc.md in full.
3. Create the agent definitions in .claude/agents/.
4. Set up production/ with the files above, and draft CONTRACTS.md (folder layout, ownership, naming, scale, host/client split).
5. Write the Phase 1 task list in TASKS.md.

Then stop and show me the roles, the contracts and the Phase 1 tasks before any work begins.
