# Voice spike (PP-02)

A throwaway test of the riskiest piece of doc 01: friends on different home networks connecting by
join code and hearing each other's voices in 3D. It proves
[doc 06](../../docs/06_networking_and_voice.md) sections 2 to 4 and 8. Nothing in `game/` uses it
(DECISIONS D-004); DD Phase 1 rebuilds it in `game/net/` and `game/voice/`.

What it has: a host screen with the UPnP result, join codes and fallbacks; joining by code or IP;
capsules on a field, moved with WASD; mic (or WAV) audio captured with `AudioEffectCapture`, Opus
encoded by TwoVoIP (`addons/twovoip/`, D-009), sent over ENet, relayed by the host, and played from
an `AudioStreamPlayer3D` on each speaker's capsule; open mic with voice activity detection, or
push-to-talk; and CONTRACTS section 10 logs.

## Before the first run (one time per checkout)

A fresh checkout has no `.godot/` folder. Two things go wrong until it does:

- **The first headless editor import crashes** (exit 139 / 0xC0000005) when the TwoVoIP addon is
  first registered, then every later run passes (Q-008). Run the import **twice**, or give it time:
  ```bash
  "$GODOT" --headless --editor --quit --path .   # may crash once; that's this bug
  "$GODOT" --headless --editor --quit --path .   # passes
  ```
  Or create `.godot/extension_list.cfg` holding the single line
  `res://addons/twovoip/twovoip.gdextension` before the first import: then it doesn't crash at all.
- **A plain run without any import never loads the addon**, so the spike fails to parse
  (`Identifier "TwovoipOpusEncoder" not declared`) and the window hangs. The same file fixes it;
  the friend package (below) ships it.

Opening the project in the Godot editor once also does the import.

## Run it

```bash
"$GODOT" --path . res://spikes/voice/voice_spike.tscn
```

`$GODOT` is the Godot 4.7.2 path in CONTRACTS section 1. The menu has **Host** and two join boxes.

### Hosting, and what the host screen shows

Press **Host**. The game opens UDP port **45120** (doc 06 section 2) and asks your router, through
UPnP, to open it to the internet. That takes up to about 8 seconds. The biggest line on the screen
then says one of:

| Line | Colour | Meaning | What to do |
|---|---|---|---|
| **UPnP WORKED: port 45120 opened automatically.** | green | The router opened the port and your outside address is public | Send friends the **join code** shown (already copied to the clipboard). The first friend to join proves it works from outside |
| **UPnP opened the port, but you're behind a second router.** | amber | The router said yes, but its outside address is private or your provider's shared address (double NAT / CGNAT), so friends probably can't reach you | Use Tailscale (below) |
| **UPnP DIDN'T WORK:** *reason* | red | No UPnP router answered, or the router refused | Manual port forward, or Tailscale |

Under it, always:

- **Manual port forward:** "forward UDP port 45120 to this PC, *your LAN address*". Do that on the
  router's admin page, then type your public address (from the router's status page; the game
  doesn't look it up, doc 01 rules out third-party services) into the box, and it shows the code.
- **VPN:** your Tailscale or ZeroTier address with its own code, if one is running.
- **LAN code** for someone in the same house, and **Local test** (127.0.0.1) for two copies on one PC.
- A Windows Firewall reminder, and **Players connected**, each with its round-trip time and
  "creature hears N": the one volume byte per voice frame the creature will use (doc 06 "The volume
  byte"; 0 to 255, about 159 at normal speech). It is shown, never logged.

`H` hides or shows the host screen.

**On the CEO's PC (measured 2026-10-05):** the router at 10.0.0.1 doesn't answer UPnP at all
(seven other LAN devices answer discovery, none is a gateway), so the screen shows red "no UPnP
router found". Either turn UPnP on in the router's admin page, forward UDP 45120 to 10.0.0.73 by
hand, or use Tailscale.

### Joining from another network

The friend runs the spike (see "Sending it to a friend") and picks one:

- **Join code:** type it in the first box (`SC07-21W2` style, 8 characters; 12 if the port isn't
  45120). Case, spaces and hyphens don't matter, and O/I/L read as 0/1/1. A mistyped code says
  "That code has a typo" and never connects.
- **Raw IP:** type the host's public IP in the second box, optionally `IP:port`. IPv6 works as
  `[address]:port`.
- **Tailscale (if port forwarding is impossible):** both install Tailscale
  (https://tailscale.com, free for personal use) and sign in to the same tailnet. The host screen
  then lists the host's `100.x.y.z` address with its own code; the friend types either. Nothing
  else changes. ZeroTier works the same way.

The status line under the boxes says "Connecting...", then the session starts, or after 10 seconds
says it couldn't reach the host. If the host quits, everyone sees the "The host left" card (doc 06
section 5).

### In the field

| Key | Does |
|---|---|
| W A S D | Walk (relative to where you face) |
| Q / E (or arrow keys) | Turn |
| T | Toggle push-to-talk on or off. Default is open mic with voice activity detection |
| V | Hold to talk, in push-to-talk mode |
| M | Mute |
| H | Host screen on or off (host only) |
| Esc | Quit (writes the final stats to the log) |

The bottom of the screen shows your mode, whether you're transmitting, your input level and each
player's RTT and voice level. Wear headphones: there is no echo cancelling, so speakers feed the
other players back into your mic.

## Two (or more) copies on one PC

Generate synthetic test voices first (never a real person's voice; CONTRACTS section 11). The script
refuses to write inside the repo:

```bash
uv run spikes/voice/make_test_wav.py "$TEMP/voice_a.wav" --f0 110 --seed 1
uv run spikes/voice/make_test_wav.py "$TEMP/voice_b.wav" --f0 180 --seed 2
```

Then with QA's launcher (`tools/qa/README.md`), the host first:

```bash
uv run tools/qa/multi.py -n 2 --common "res://spikes/voice/voice_spike.tscn" \
  --args "-- --host --no-upnp --voice-wav $TEMP/voice_a.wav --run-seconds 45" \
  --args "-- --join FW00-00F7 --voice-wav $TEMP/voice_b.wav --run-seconds 38"
```

`FW00-00F7` is the code for 127.0.0.1; `--join 127.0.0.1` does the same by raw IP. Add `--headless`
for no windows, `-n 3` or `-n 4` with more `--args`. Logs land in `logs/qa/multi_<time>/user_logs/`.
By hand, two terminals with the plain run command above work too.

### Command-line options (after `--`)

| Option | Effect |
|---|---|
| `--host` / `--join <code or ip>` | Skip the menu |
| `--voice-wav <path>` | Voice from a WAV (looped) instead of the mic |
| `--port <n>` | Host port (default 45120) |
| `--no-upnp` | Don't ask the router (repeated local tests) |
| `--name <text>` | Display name |
| `--ptt` | Start in push-to-talk |
| `--walk` | Walk in a circle (moving-voice test) |
| `--run-seconds <n>` | Log final stats and quit after n seconds |
| `--denoise off\|speex\|rnnoise` | Default `rnnoise` (doc 06 "Encode") for mic and WAV alike; measured: it passes the synthetic voices with the same frames sent as `off` |
| `--net-sim-loss <0..1>` | Drop that share of this peer's outgoing voice frames |
| `--enet-throttle` | Keep ENet's default RTT throttle (comparison; see gotchas) |
| `--stall-at <s>` | Block the main thread 300 ms once (hitch test) |
| `--mute-output` | Mute Master (automated windowed runs) |
| `--screenshot <path>` `--screenshot-at <s>` | Save a PNG of the window |
| `--trace-voice` | Print every sent and received voice sequence number |

## Logs

One JSON Lines file per peer, `user://logs/<session>/peer_<id>.jsonl` (CONTRACTS section 10;
`%APPDATA%\Godot\app_userdata\Brenny Brenn Boy Horror\logs`). Every peer of a session writes into
the host's session folder. Players are named by ENet peer id (D-012). `day` is 0 and `phase` is
`day` throughout (placeholders: the spike has no clock).

| Event | Who | Data |
|---|---|---|
| `net_hosting` | host | port, input, LAN and VPN addresses, Godot version, mix rate |
| `net_upnp_result` | host | `result` (`success`, `no_devices`, a router error, `skipped`), `external_address_class`, `port`, `seconds`, `lease_s`, `gateway_found`. The public IP itself is not logged |
| `net_connected` / `net_connect_failed` | client | `connect_ms`, `via` (`code` or `ip`) |
| `net_join_code_rejected` | client | reason |
| `net_peer_joined` / `net_peer_left` | host | peer id; `reason` `quit`, `timeout` or `host_quit` |
| `net_host_left` | client | `how` (`quit` or `disconnected`) |
| `net_rtt` | everyone, every 10 s | `to`, `rtt_ms`, `enet_loss` (ENet's reliable-packet loss) |
| `net_bandwidth` | everyone, every 10 s | `up_kbps`, `down_kbps` including UDP/IP headers, datagrams per second |
| `voice_sent` | everyone, every 10 s | frames encoded and sent, bytes, talk spurts, largest Opus packet, frames dropped by `--net-sim-loss` |
| `voice_stats` | everyone, per speaker, every 10 s | `speaker`, `received`, `lost` (concealed by Opus PLC), `late`, `decoded`, `loss`, `underflow_ms`, `overflow_ms`, `decoded_peak` |
| `voice_mix` | everyone, every 10 s | clicks and largest sample step in the received-voice mix (crackle proxy), fps |
| `voice_relay_stats` | host | frames relayed |
| `spike_end` | everyone | seconds, players |

`uv run tools/qa/check_logs.py <folder>` validates the record shape; the voice numbers are read
from the events above.

**Measuring crackle.** Every received voice plays through a `SpikeVoiceIn` bus with a capture tap.
A click is a sample-to-sample jump above 0.25; the synthetic voices never step more than about 0.1,
so a click means a gap or discontinuity. `underflow_ms` is time a speaker's decoder ran dry
mid-speech, which is what crackling from buffer starvation sounds like.

## Sending it to a friend

There is **no Windows export**: Godot's export templates aren't installed on the CEO's PC, and
installing them is a download for the CEO to approve. Instead:

```bash
uv run spikes/voice/package_for_friend.py     # writes builds/voice_spike_friend.zip (gitignored)
```

The zip (about 11 MB) holds `project.godot`, the TwoVoIP addon with all five license files, this
spike, `Voice spike.bat`, `START HERE.txt` and the seeded `.godot/extension_list.cfg`. The friend:

1. Downloads **Godot 4.7.2, standard Windows build** from
   https://godotengine.org/download/archive/4.7.2-stable/ (the same engine the studio uses) and
   puts `Godot_v4.7.2-stable_win64.exe` in the unzipped `voice_spike` folder.
2. Double-clicks `Voice spike.bat`, allows it through Windows Firewall on Private networks, and
   joins with the code or IP.
3. Afterwards sends back the newest folder from
   `%APPDATA%\Godot\app_userdata\Brenny Brenn Boy Horror\logs` (statistics only, no audio).

## Gotchas found here

- **Godot 4.7.2 `ENetMultiplayerPeer.create_server(port, max_clients, max_channels)` with
  `max_channels > 0` ruins unreliable traffic.** The engine passes its arguments to
  `create_host_bound` shifted by one (`modules/enet/enet_multiplayer_peer.cpp` line 67), so
  `max_channels = 4` advertises an *incoming bandwidth* of 7 bytes per second. Every client's ENet
  bandwidth throttle then drops nearly all of its unreliable (voice) packets for about 15 seconds
  after joining: 20 to 40% voice loss over a session on loopback. The spike calls
  `create_server(port, max_clients)` and lets clients ask for 4 channels. Not yet reported upstream.
- **ENet's RTT throttle drops unreliable packets after a hitch.** When one round trip comes back
  slow (a frame hitch, a Wi-Fi blip), ENet drops a share of unreliable packets for seconds. The
  spike pins the throttle with `throttle_configure(5000, 2, 0)`; with a forced 300 ms hitch,
  ENet's default lost 4 and 13 voice frames, pinned 0 and 0.
- **TwoVoIP has no in-band FEC** (D-012). A lost frame is concealed by Opus PLC: the next packet is
  pushed with `decode_fec = 1`, and with no FEC data in it libopus conceals one frame.
- **TwoVoIP's `mark_end_opus_stream(false)` resets the decoder.** Call it only at a talk end.
- **`audio/driver/enable_input` can be set from code**, before any `AudioStreamMicrophone` plays
  (the spike does it in `_init`). Without it Godot warns and no input frames arrive.
- **A muted bus still feeds its `AudioEffectCapture`.** The spike's `SpikeMic` bus is muted.
- **Headless runs use the dummy audio driver** at 44.1 kHz and deliver capture in about 100 ms
  bursts, so headless jitter is worse than a real window (48 kHz on the CEO's PC).
- **UPnP `discover()` can return success with zero devices**; check `get_device_count()` before
  `get_gateway()`, which otherwise prints an engine `ERROR`.
- **Stop audio players before quitting**, or Godot warns about leaked playbacks at exit.
- **The CEO's mic gave pure silence** in every test (frames arrive, all zero; Windows mic access
  is allowed). Probably the headset is off or muted. Real-mic capture is untested until STOP 1.
