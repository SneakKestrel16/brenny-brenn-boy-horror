# Tester brief

Read this to each tester before the session, or send it to them. It covers controls and setup only.
Do not explain the game, the creature or the voices (doc 09 section 12: "Do not coach the lure").

---

Thanks for testing. This is an early gray-box prototype: plain shapes, placeholder sound, bugs.

**What you need**

- Stereo headphones, worn left on left. Tell us the model. Turn Windows spatial sound off.
- A microphone. You talk to the other player in the game, not on Discord or a phone call, so close
  any other voice chat for the session.
- About 30 minutes: one in-game day (8 to 10 min), dusk, one night (about 5 min), then 10 minutes of
  questions.

**Before we start, we ask you**

- Whether you are happy for us to record your screen or voice. No is fine and changes nothing.
  Recordings never go into the project; they stay on our machine and are deleted after the notes are
  written.
- What you already know about the game. A stream or a trailer counts.

**Controls** (placeholders; the game shows each one the first time you need it)

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Shift | Sprint |
| C | Crouch |
| Hold X | Stand still |
| Hold E | Interact (plant, water, sell, refuel, pry) |
| Left / right mouse | Use tool / other use |
| G | Drop |
| F | Lantern |
| Q | Whistle |
| V | Push to talk (if you switch push-to-talk on; open mic is the default) |
| Esc | Menu |

**Your voice**

The game has a voice setting on your own machine: **Off** (nothing recorded) or **Lobby lines**. You
can change it any time. When the game is capturing your voice, a recording light shows. Anything it
keeps stays on your own disk, and Off deletes it.

**During play**

- Play however you like. There is no wrong way.
- We stay quiet while you play and only take notes. Ask us anything after.
- If you want to stop at any point, say so and we stop.

**If you are joining from home**

1. Install Tailscale and join the host's tailnet (the host sends you the invite).
2. Unzip the folder we sent you and double-click `Join.bat` (not the `.exe`). Type the host's
   Tailscale address (`100.x.y.z`) and press Enter. If Windows Firewall asks, allow it on Private
   networks. If SmartScreen says "Windows protected your PC", choose More info, then Run anyway (the
   build is not signed).
3. Afterwards, double-click `send_logs.bat`. It puts `brenny_logs.zip` on your Desktop. Send us that
   file. It holds game events and connection statistics only: no audio, no names.
