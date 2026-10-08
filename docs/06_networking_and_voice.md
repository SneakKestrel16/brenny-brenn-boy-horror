# Doc 06: Networking & Voice

Owner: Network & Voice Programmer. Task: PP-01. Status: draft, revised after QA's PP-01 review and
the voice spike (PP-02); for QA re-review and the Director's consistency check.

How friends connect, what the host and clients send each other, and how voice is captured, sent,
played, recorded and faked. Doc 01 is the source of truth; every rule here cites the doc 01 section
it comes from. **Numbers doc 01 doesn't give are marked `placeholder`** and get tuned in DD Phase 1
playtests. Inference is marked as inference, with what would settle it. Facts from the voice spike
are marked **measured (PP-02)** and come from `production/handoffs/PP-02.md`; they were measured on
loopback with synthetic voices unless the text says otherwise.

The transport rules here are the CONTRACTS section 7 contract (DECISIONS D-010). The doc 01
readings Q-005 raised are decided in D-011, the ones Q-012 raised in D-013; log identity and loss
handling in D-012.

## Contents

1. [Scope](#1-scope)
2. [Transport and ENet channels](#2-transport-and-enet-channels)
3. [Hosting, UPnP and the host screen](#3-hosting-upnp-and-the-host-screen)
4. [Join codes and fallbacks](#4-join-codes-and-fallbacks)
5. [Session lifecycle: joining, leaving, host left](#5-session-lifecycle-joining-leaving-host-left)
6. [Authority and close calls](#6-authority-and-close-calls)
7. [Message list](#7-message-list)
8. [Voice pipeline](#8-voice-pipeline)
9. [The shared voice chain](#9-the-shared-voice-chain)
10. [Walkie-talkies](#10-walkie-talkies)
11. [Lobby lines, barn chatter and voice settings](#11-lobby-lines-barn-chatter-and-voice-settings)
12. [Lures and clip pre-sharing](#12-lures-and-clip-pre-sharing)
13. [Bandwidth](#13-bandwidth)
14. [Testing hooks and logs](#14-testing-hooks-and-logs)
15. [Opus GDExtension and other addons](#15-opus-gdextension-and-other-addons)
16. [Later extension: live clips (DD Phase 5)](#16-later-extension-live-clips-dd-phase-5)
17. [Gotchas](#17-gotchas)
18. [Questions raised](#questions-raised)

---

## 1. Scope

Covers doc 01 "Engine and Tech > Networking" and "> Voice" (including "Weak localization"), "Voice
Mimicry" where it touches transport, playback and storage, "Voice settings", "Recording lines that
sound scared", "Season and Numbers > Joining and leaving" and "Saving > Host leaves".

Not covered here, and owned elsewhere: what the creature does with a heard sound (doc 03), which
lure the AI Director picks (doc 03), the Noise interface signature, the save contents and the full
log event list (doc 05), bus mix levels and the sound list (doc 08), item rules for walkie-talkies
such as price and battery life (doc 02).

Code lives in `game/net/` and `game/voice/` (CONTRACTS section 2). The voice spike in
`spikes/voice/` proved sections 2 to 4 and 8 on loopback and is thrown away (DECISIONS D-004); the
real two-network test is STOP 1 (Q-009).

## 2. Transport and ENet channels

- **Transport:** Godot's `ENetMultiplayerPeer` over UDP, no third-party services or servers
  (doc 01 "Networking").
- **Topology:** star. The host is peer 1 (CONTRACTS section 5) and every message goes through it.
  `SceneMultiplayer.server_relay` is set to **false** (D-010), so a client can only talk to the host
  and the host forwards what others need. That keeps the host in the path of every interaction it
  must validate (doc 01 "Authority") and of every voice frame it must read the volume from (doc 01
  "Senses").
- **Players:** 2 to 4 (doc 01 "Format"). The server is created with room for 4 clients, one more
  than the 3 allowed, so a 5th player connects long enough to be told "the farm is full" instead of
  timing out.
- **Creating the peers:** the host calls `create_server(port, 4)` and **never passes
  `max_channels`**; clients call `create_client(address, port, 4)` to ask for the 4 channels below.
  Godot 4.7.2 passes `create_server`'s `max_channels + 3` to ENet as the server's *incoming
  bandwidth*, which made every client's bandwidth throttle drop 20 to 40% of its voice
  (**measured (PP-02)**; see [Gotchas](#17-gotchas)). With `max_channels` left at 0 (unlimited),
  loss was 0.
- **ENet throttle pinned:** on every connection, both ends call
  `ENetPacketPeer.throttle_configure(5000, 2, 0)` (ENet's default is `(5000, 2, 2)`). ENet's RTT
  throttle otherwise drops a share of unreliable packets for seconds after one slow round trip. With
  a forced 300 ms hitch, the default lost 4 and 13 voice frames, pinned 0 and 0 (**measured
  (PP-02)**). Voice has its own concealment (section 8), so it needs no throttle. Whether pinning
  hurts over a congested real link is unmeasured (inference; STOP 1 logs with the spike's
  `--enet-throttle` comparison settle it).
- **Sends check the peer first:** the host checks each peer's connection state before sending, so a
  peer that is mid-disconnect doesn't print `Unable to send packet` errors (**measured (PP-02)**).
- **Default port:** UDP 45120 (`placeholder`; changeable in settings). If it is taken locally or
  the router reports a conflict, the host tries 45121 to 45124.

### Channels

ENet channels are independent: a lost packet on one never delays another.

| Channel | Mode | Carries |
|---|---|---|
| 0 | reliable | Gameplay: every `request_*` and `apply_*`, session and roster messages |
| 1 | unreliable ordered | Movement and creature transforms (latest wins) |
| 2 | unreliable | Voice frames (own sequence numbers and jitter buffer, section 8) |
| 3 | reliable | Bulk: lobby-line clip transfer and the dawn save copy, chunked so they never stall channel 0 |

This is CONTRACTS section 7 (D-010). Movement and voice use `SceneMultiplayer.send_bytes()` with a
one-byte type prefix rather than RPCs, to avoid RPC path overhead at 20 to 50 packets a second;
everything on channel 0 is an RPC on the `Net` autoload so it follows the CONTRACTS naming. The
spike sent on channels 1 and 2 this way with 4 channels (**measured (PP-02)**); channel 3 hasn't
carried traffic yet (see "Channel numbering" in [Gotchas](#17-gotchas)).

## 3. Hosting, UPnP and the host screen

Doc 01 "Networking > Hosting": the host's game opens its port with Godot's built-in `UPNP` and
reads its public address. "The host screen shows clearly whether UPnP worked."

### Host flow

1. Start the ENet server on the port (section 2).
2. On a worker thread (discovery blocks for seconds; 9.7 s on the CEO's router, **measured
   (PP-02)**): `UPNP.discover()`, then **check `get_device_count()` before `get_gateway()`**.
   `discover()` can return success with zero devices, and `get_gateway()` then prints an engine
   `ERROR` (**measured (PP-02)**).
3. `add_port_mapping(port, port, "Farm game", "UDP", 7200)` (lease `placeholder`, renewed every
   hour while hosting). If the router answers `UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED`, retry
   with lease 0. On `UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING`, try the next port.
4. `query_external_address()`, then classify it (below).
5. On quit, `delete_port_mapping()`. A crash leaves the mapping until its lease runs out.

### What the host screen shows

The result line is the biggest text on the screen, in one of three states.

| State | When | The screen shows |
|---|---|---|
| **UPnP worked** (green) | Mapping added and the external address is public | "Port 45120 opened automatically." Public address, join code with a Copy button, and "Not yet tested from outside: the first friend to join confirms it." |
| **UPnP worked, but you're behind a second router** (amber) | Mapping added but the external address is private (10/8, 172.16/12, 192.168/16) or carrier-grade NAT (100.64/10) | "Your router opened the port, but your internet provider or another router sits in front of it, so friends probably can't reach you." Points to the VPN option. No public join code. |
| **UPnP didn't work** (red) | No gateway found, or the router refused | The reason in plain words ("no UPnP router found", "your router refused to open the port"), then both fallbacks below |

The spike built all three states; on the CEO's router it showed red, "no UPnP router found"
(**measured (PP-02)**: the router answered no discovery under any filter; that UPnP is switched off
there is inference, settled by its admin page, Q-009).

Always on the screen, in every state:

- **Manual port forward:** "Forward UDP port 45120 to this PC, 192.168.1.23", with this PC's LAN
  address filled in. If UPnP failed the game doesn't know the public address (doc 01 forbids
  third-party services, so there is no "what is my IP" lookup), so there is a field: "Type your
  public address from your router's status page", which then generates the join code.
- **VPN:** every local address in 100.64.0.0/10 (Tailscale's range) or on an adapter whose name
  contains "ZeroTier" is listed with its own join code: "Friends on your Tailscale/ZeroTier network
  can use this code." Detection by range and adapter name is a heuristic (inference); the raw IP
  field (section 4) always works.
- **LAN code** for players in the same house.
- **Players connected**, each with its round-trip time. A friend appearing here is the real proof
  the port is reachable.
- A one-line Windows Firewall reminder (see [Gotchas](#17-gotchas)).

## 4. Join codes and fallbacks

Doc 01 "Networking > Joining": "a short join code that encodes their address and port. A friend
enters the code, or types an IP directly."

### Format

- **Alphabet:** Crockford base32, `0123456789ABCDEFGHJKMNPQRSTVWXYZ` (no `I L O U`).
  Case-insensitive. On entry, `O` reads as `0`, `I` and `L` read as `1`, and spaces and hyphens are
  ignored.
- **Short form, default port:** 32-bit IPv4 address + 8-bit CRC-8 (polynomial 0x07) = 40 bits =
  **8 characters**, shown as `XXXX-XXXX`.
- **Long form, any other port:** 32-bit address + 16-bit port + 12-bit CRC-12 (polynomial 0x80F) =
  60 bits = **12 characters**, shown as `XXXX-XXXX-XXXX`.
- **Packing, exactly** (two builds must agree):
  - The value is built most significant bit first: the address (as the 32-bit big-endian number,
    first octet highest), then the port (long form only, 16 bits), then the CRC in the lowest bits.
  - The CRC runs over the big-endian bytes of the address (short form) or the address followed by
    the port (long form), most significant bit first: **init 0, no input or output reflection, no
    final XOR**.
  - The value is written as base32 digits from the most significant 5 bits down, then split into
    groups of 4 with hyphens.
- The length tells the two apart. A code that fails its check says "That code has a typo" and never
  tries to connect.
- **Code-shaped input of the wrong length** (only alphabet characters, spaces and hyphens, but not
  8 or 12 characters once normalised, such as a 7- or 9-character code or `fw00 00f7` split by a
  shell) is also rejected as "That code has a typo", never read as a raw IP, and logged as
  `net_join_code_rejected` (Q-013 item 3; a DD Phase 1 `game/net/` acceptance criterion). Only
  input that parses as an IP (with dots or colons) goes to the raw-IP path.
- **Typo resistance:** a one-character mistake changes at most 5 adjacent bits and swapping two
  neighbours at most 10. CRC-8 is guaranteed to catch any error inside 8 adjacent bits, and CRC-12
  inside 12, so both forms catch every single wrong character and the long form catches every
  neighbour swap. The short form's neighbour-swap catch is not guaranteed by the CRC, but
  `tests/net/test_join_code.gd` ran every single substitution and neighbour swap over 3,000 random
  addresses in both forms (956,154 cases) and found none undetected (**measured (PP-02)**).
- **Examples** (documentation addresses from RFC 5737, not real ones): `203.0.113.7` on the
  default port is `SC07-21W2`; on port 45121 it is `SC07-21XG-85AX`. The same test checks both.

### Fallbacks

- **Raw IP:** the join screen has a second field for an IP (or `IP:port`). IPv6 literals work here;
  join codes are IPv4 only, because IPv4 behind a home router is the case UPnP serves.
- **VPN (Tailscale, ZeroTier):** the VPN address is just another IP. The host screen shows a code
  for it (section 3), or friends type the VPN IP into the raw field. Nothing else changes.
- **Manual port forward:** the host screen names the exact port and LAN address (section 3).
- **If UPnP fails for too many friends,** doc 01 "Open Issues" 1 says to reconsider a relay. Each
  host's UPnP result is logged (section 14) so that question gets data. First data point: the CEO's
  router, `no_devices` (**measured (PP-02)**).

## 5. Session lifecycle: joining, leaving, host left

### Identity

Each install creates a random 128-bit `player_uid` once and keeps it in `user://`. It lets a player
who drops and rejoins get their farmhand back, and lets "any player from the season" host the save
(doc 01 "Saving > Portable"). The ENet peer id changes every session; the uid doesn't. The host
gives each connected player a **slot** 0 to 3, which voice frames and voice messages use instead of
the 4-byte peer id. **Logs always name players by peer id, never by slot** (D-012); the host maps
between them.

### Joining

1. Client connects. ENet peer timeout is set to 5 s minimum, 10 s maximum (`placeholder`).
2. Client sends `request_join(protocol_version, build_id, player_uid, display_name, voice_setting)`.
   `voice_setting` is `off` or `lobby_lines` (section 11 "Setting IDs").
3. Host refuses (`apply_join_refused(reason)`, then disconnects) on a different protocol version or
   build, or a full farm.
4. Host sends `apply_join_accepted(slot, roster, session_state)` to the joiner and `apply_roster` to
   everyone.
5. **Lobby-lines players record first** (doc 01 "Joining"): if the joiner hasn't chosen Off and has
   no recorded lines, the staged recording is offered on their machine (section 11 "Before
   recording"). They can skip it.
6. The joiner shares their clips (section 12) and receives everyone else's, then sends
   `request_ready`.
7. **In the lobby,** the player appears in the barn. **Mid-season** (doc 01 "Joining"), the host
   spawns them as a ghost at once and gives them a body at the next dawn.

### Leaving

- Host sees `peer_disconnected`, broadcasts `apply_peer_left(slot)`, and drops their voice relay.
- Their character stays as an idle farmhand that doesn't count, and they count as absent from the
  next dawn (doc 01 "Joining and leaving").
- Every peer frees the leaver's lobby lines from memory, and any lure using them stops. **This is a
  reading** (inference): doc 01 "Storage" says only "peers' memory", not for how long; freeing them
  on leave is the strict reading, and a player who rejoins shares them again (section 12). Accepted
  in D-013; DD Phase 2 playtests can revisit it.
- **One player left** at a dawn: the host saves and pauses, showing "Waiting for a farmhand" until a
  second player joins (doc 01 "Joining and leaving"). There is no solo play.

### Host left

Doc 01 "Saving > Host leaves": "the session ends with a 'host left' card and resumes from the last
dawn save. There's no host migration."

1. **Quitting host:** sends `apply_host_leaving` on channel 0, flushes, then closes. Clients show
   the card at once (**measured (PP-02)**: the client logged `net_host_left` with `how: quit` and
   showed the card).
2. **Crashed or cut-off host:** clients get `server_disconnected` after the ENet timeout (up to
   10 s, `placeholder`) and show the same card.
3. The card: "The host left. The season continues from the last dawn save. Any farmhand from this
   season can host it." Then back to the main menu.
4. **Portable save:** at each dawn the host sends its dawn save to every client
   (`apply_dawn_save`, channel 3), and each client keeps it under `user://saves/<season_id>/`. That
   is how any player can host the season next time. The save holds **no voice data and no clips**
   (doc 01 "Voice settings > Storage"). Save contents are doc 05's.
5. No host migration: clients never try to take over.
6. **Before quitting,** every machine stops its audio players and waits about 0.1 s, or Godot
   reports leaked playbacks at exit (**measured (PP-02)**).

## 6. Authority and close calls

Doc 01 "Networking > Authority" and CONTRACTS section 5, unchanged:

- **Clients own** their movement and camera. They send transforms at 20 Hz (`placeholder`); the host
  checks speed and checks stillness for "go still" (doc 01 "Hiding verbs") from what it receives.
- **The host owns** the creature, AI Director, traps, pegboard, economy (no client-side selling),
  Taint, deaths and the cart, and validates every interaction.
- **Speed check:** a transform faster than the player's current maximum (sprint, Shaken, bear-trap
  slow) plus 20% (`placeholder`) is logged and relayed clamped. Only a jump over 3 times the maximum
  (`placeholder`) gets `apply_teleport` back. DD Phase 1 never rubber-bands friends over jitter.

### Close calls go to the victim

Doc 01 "Networking > Close calls": "lag-dependent lunges, kills and doorway reaches go to the
victim. Lag never kills."

The host sees each player late by about half the round-trip time, and the player has really moved
further than the host thinks. So a hit needs both views to agree. The same check covers all three
cases doc 01 names: **lunges, kills and doorway reaches** (the creature reaching through a door at a
player on or near the threshold).

1. When a lunge, kill or doorway reach connects in the host's view, the host sends
   `apply_close_call_check(call_id, creature_position, reach_m)` to the victim only. For a doorway
   reach, `creature_position` is the reaching point at the doorway.
2. The victim's client answers `request_close_call_result(call_id, own_position, inside_lit)` with
   its own current position and whether it is inside a lit building.
3. The hit lands only if the victim's own answer is also inside reach and not inside a lit
   building (doc 01 "Light is the rule": the creature never enters one; "Losing a chase": reaching a
   lit building escapes). So a player who crossed a lit threshold in their own view is safe even if
   the host still sees them in the doorway. **No answer within the timeout (300 ms plus the
   victim's RTT, `placeholder`) is a miss.** Lag can only save a player, never kill one.
4. **Trap race and pry holds:** the host credits the victim with their one-way latency (half RTT)
   when it compares a finished pry against the race deadline (doc 01 "Day deaths"). Doc 05
   section 7 applies the credit by stamping the pry's `started_at` with the host's receive time
   minus `Net.rtt_ms(peer) / 2`.

### `Net.rtt_ms(peer)`

`Net.rtt_ms(peer: int) -> int` returns ENet's smoothed round-trip time in milliseconds
(`ENetPacketPeer.get_statistic(PEER_ROUND_TRIP_TIME)`, the value the spike logged as `net_rtt`,
**measured (PP-02)**). On the host it takes any connected client's peer id and returns 0 for
peer 1 (the host's own actions have no network hop). On a client only `rtt_ms(1)` is meaningful;
other ids return 0. An unknown or disconnected peer returns 0, so a missing value never adds
credit. The close-call timeout (item 3) uses the same call. `request_ping` / `apply_pong` stay only
for the host screen's per-player ping, which clients also show.

Trusting the victim's answer means a modified client could dodge kills. This is co-op among
friends; doc 01 doesn't ask for cheat resistance (inference: settled by the CEO if it ever matters).

## 7. Message list

This is the CONTRACTS section 7 message list (D-010). Naming: client-to-host `request_<verb>`
(`@rpc("any_peer", "call_remote", "reliable")`, host validates); host-to-clients `apply_<event>`
(`@rpc("authority", ...)`). "Validated by" names who decides; the host always checks the sender's
slot against the message. Messages name players by slot; logs name them by peer id (D-012).

This is the **full transport list**. The gameplay verbs come from CONTRACTS section 5 and doc 01;
their exact arguments, timings and checks are filled in by doc 05 (hold framework), doc 02 (prices,
items) and doc 03 (creature), without adding message families. A verb not listed here is a change to
CONTRACTS section 7 and needs the Director (D-010). D-013 confirms `request_lantern`,
`request_place_defense` and `request_role` as part of the D-010 list.

### Session and roster (channel 0)

| Message | Direction | Validated by | Notes |
|---|---|---|---|
| `request_join(protocol_version, build_id, player_uid, display_name, voice_setting)` | client → host | host | Section 5 |
| `apply_join_accepted(slot, roster, session_state)` | host → joiner | — | |
| `apply_join_refused(reason)` | host → joiner | — | `version_mismatch`, `farm_full` |
| `apply_roster(roster)` | host → all | — | slot, uid, name, voice setting, role, alive/ghost/farmhand, has recorded lines |
| `request_role(role_id)` | client → host | host: lobby only, one player per role | Doc 01 "Roles" (optional); the result is the role in `apply_roster` |
| `request_ready()` | client → host | host | After recording and clip exchange |
| `apply_peer_left(slot)` | host → all | — | |
| `apply_host_leaving()` | host → all | — | |
| `apply_waiting_for_farmhand(on)` | host → all | — | Doc 01 "Joining and leaving" |
| `apply_dawn_save(chunk_index, chunk_count, bytes)` | host → all | — | Channel 3; no voice data |
| `request_ping(t)` / `apply_pong(t)` | client ↔ host | — | RTT for logs and the host screen |

### Movement and world state (channel 1, `send_bytes`)

| Message | Direction | Validated by | Notes |
|---|---|---|---|
| `move` (position, yaw, pitch, crouch, sprint, seq) | client → host, 20 Hz | host: speed, stillness | Clients own movement |
| `moves` (all players' latest, plus the cart's position, yaw and seq while it exists) | host → all, 20 Hz | — | Batched per tick. The festival cart (doc 05 section 13) rides this batch during the Harvest Moon, not a message of its own; clients interpolate it like a player |
| `creature` (transform, state, seq) | host → all, 15 Hz (`placeholder`) | — | State is one of `lurk`, `lure`, `stalk`, `chase`, `retreat` (CONTRACTS section 7) |
| `apply_teleport(position)` | host → one, channel 0 | — | Only for gross speed violations, respawn |

### Interactions (channel 0)

Every one is `request_<verb>(target_id, ...)` sent when a hold starts, plus `request_hold_cancel()`
on release; the host checks range, timing and state, runs the hold timer, and answers with
`apply_<result>` to all, or `apply_refused(verb, reason)` to the sender (CONTRACTS section 7; the
client rolls back its prediction). Doc 05 section 7 (hold framework) uses only these messages plus
`apply_hold_cancelled`; it adds none.

| Request (client → host) | Host result (host → all) | Doc 01 source |
|---|---|---|
| `request_plant`, `request_water`, `request_harvest` | `apply_plot_changed` | "Crops" |
| `request_sell` | `apply_money_changed` | "Networking > Authority" (no client-side selling) |
| `request_buy`, `request_pay` | `apply_money_changed`, `apply_item_given`, `apply_payment` | "Store" (including more scarecrows and brighter lanterns), "Debt and payments" |
| `request_pick_up`, `request_drop`, `request_carry_player` | `apply_item_moved`, `apply_carry` | "Daytime Threats", "Emotes and physical comedy" |
| `request_lantern(on)` | `apply_lights` | "Farming Meets Horror > Light": a carried lantern is a light, and lights are host-owned because the creature sees them (doc 01 "Senses > Sight") |
| `request_place_defense(kind, position, yaw)` (`scarecrow`, `fence`) | `apply_defense_changed` | "Farming Meets Horror > Defense", "Store: More scarecrows" |
| `request_disarm`, `request_pry`, `request_fill_pit`, `request_cut_tripwire` | `apply_trap_changed`, `apply_trap_race` | "Night Traps", "Day deaths" |
| `request_hang_trap` | `apply_pegboard_changed` | "The tool shed" |
| `request_place_flag`, `request_remove_flag` | `apply_flags` | "Night Traps > Flags" |
| `request_wash` | `apply_taint_changed` | "The Taint" |
| `request_refuel`, `request_repair_generator` | `apply_generator` | "Nights > Generator" |
| `request_door`, `request_repair_fence`, `request_round_up` | `apply_door`, `apply_fence`, `apply_animal` | "Light is the rule", "Daytime Threats" |
| `request_push_cart(on)` | `apply_cart(loaded, pushers)`, on change only; the transform rides `moves` | "The Harvest Moon" |
| `request_fire_flare` | `apply_flare` | "Store" |
| `request_whistle` | `apply_whistle(slot, position)` | "How players fight back > Whistle" |
| `request_emote(emote_id)` | `apply_emote` | "Emotes and physical comedy" |
| `request_flicker(light_id)` (ghost) | `apply_flicker(light_id)` | "Ghosts > Lantern flicker" |
| `request_possess_crow(crow_id)` (ghost) | `apply_crow_possessed` | "Ghosts > The crow" |
| `request_hold_cancel()` | `apply_hold_cancelled` | |

`apply_lights` turns a light on or off; it never flickers one. Only `apply_flicker` does (doc 01
"Ghosts").

### Host-driven events (channel 0, host → all unless noted)

| Message | Notes |
|---|---|
| `apply_clock(day, phase, t)` | Every phase change plus every 5 s; clients interpolate. Phase IDs from CONTRACTS section 8 |
| `apply_creature_state(state, body)` | Reliable copy of each state change, so ambience never misses one |
| `apply_taint_changed`, `apply_shaken`, `apply_death`, `apply_respawn` | |
| `apply_close_call_check(call_id, creature_position, reach_m)` | **victim only**; answered by `request_close_call_result(call_id, own_position, inside_lit)` (section 6) |
| `apply_scare(scare_id, ...)` | **target only** for private events (hallucinations, the wrong count), all for public ones |
| `apply_lure(...)` | Section 12; **target only** for targeted day lures, all for world lures |
| `apply_dawn_report(report)` | Lure references, not audio |
| `apply_lights`, `apply_plot_changed`, ... | The results listed above |

### Voice (sections 8 to 12)

| Message | Channel | Direction | Validated by |
|---|---|---|---|
| `voice_frame` (client form, with volume byte) | 2, `send_bytes` | client → host | host: sender slot, radio flag against the sender's walkie and life state |
| `voice_frame` (relay form) | 2, `send_bytes` | host → each other peer | — |
| `request_voice_setting(setting)` / `apply_voice_setting(slot, setting)` | 0 | owner → host → all | **the owner**; the host can't refuse it |
| `request_recording_light(on)` / `apply_recording_light(slot, on)` | 0 | owner → host → all | the owner |
| `request_clip_manifest(manifest)` / `apply_clip_manifest(slot, manifest)` | 0 | owner → host → all | host: owner only shares own clips, caps |
| `voice_clip_chunk(clip_id, index, count, bytes)` | 3 | owner → host → all | host: caps |
| `request_clip_deleted(clip_id)` / `apply_clip_deleted(slot, clip_id)` | 0 | owner → host → all | the owner |
| `apply_lure(lure_id, source, position, target_slot, tell, ghost)` | 0 | host → target or all | — |
| `apply_walkie(slot, has_walkie, battery)` | 0 | host → all | host (item state) |

## 8. Voice pipeline

Doc 01 "Engine and Tech > Voice": mic audio captured with `AudioEffectCapture`, compressed with
Opus through a GDExtension, sent over ENet, relayed by the host, played from an
`AudioStreamPlayer3D` on each player's character. The GDExtension is TwoVoIP v6.5 (D-009,
section 15).

### Capture

- A `Mic` bus, muted, holds an `AudioEffectCapture` (buffer 0.5 s, `placeholder`). An
  `AudioStreamPlayer` plays an `AudioStreamMicrophone` into it. Muting the bus keeps the player from
  hearing themselves while the capture effect still receives audio (**measured (PP-02)** with WAV
  input on 4.7.2; real-mic capture is untested because the CEO's headset gave all-zero samples,
  Q-009).
- `audio/driver/enable_input` must be on. It can be set from code before any
  `AudioStreamMicrophone` plays (**measured (PP-02)**); the game sets it in `project.godot`
  (Q-006). Without it Godot warns and no input frames arrive.
- **WAV input** (doc 01 "Voice > Test input", "Testing > Fake input"): `--voice-wav <path>` swaps the
  `AudioStreamMicrophone` for a looping `AudioStreamWAV` on the same player, so everything after the
  capture effect is identical, **denoising included**: RNNoise passed the synthetic test voices
  unchanged (it sent the same frames as denoise off, **measured (PP-02)**). Test voices are
  synthetic or CEO-approved and live outside the repo (CONTRACTS section 11).
- **Headless runs** use the dummy audio driver at 44.1 kHz and deliver capture in bursts of about
  100 ms (**measured (PP-02)**), so headless jitter and underflow figures are pessimistic. A
  windowed run on the CEO's PC used WASAPI at 48 kHz.

### Encode

- **Opus settings** (`placeholder`s, used unchanged by the spike): 48 kHz, mono, **20 ms frames
  (960 samples)**, `VOIP` application (TwoVoIP's `voice_optimal`), 24 kbps VBR, complexity 8. DTX
  off, because VAD already stops sending in silence.
- **No in-band FEC** (D-012). TwoVoIP v6.5's encoder sets only signal, bitrate and complexity; it
  never sets `OPUS_SET_INBAND_FEC` or `OPUS_SET_PACKET_LOSS_PERC`, and v6.6 doesn't either. Loss is
  handled by packet-loss concealment (PLC) alone ("Playback").
- Capture runs at Godot's output mix rate (`AudioServer.get_mix_rate()`), not the mic's rate.
  TwoVoIP's encoder is initialised with the mix rate and resamples to 48 kHz.
- **Packet size:** about 45 bytes on average, 90 at most, on the synthetic voices (**measured
  (PP-02)**). Real speech may differ (inference; STOP 1 logs settle it).
- **No automatic gain control.** AGC would make a whisper as loud as a scream and break "a scream
  gives you away" (doc 01 "Senses"). TwoVoIP's AGC is disabled. A lobby mic check instead sets a
  fixed manual gain and records the player's normal speaking level for the volume byte.
- Denoising: RNNoise, on by default, toggle in settings (`placeholder`).
- The encoder runs on **every** 20 ms frame, sending or not, and keeps the last 5 packets (100 ms,
  `placeholder`) so speech that opens the VAD isn't clipped: those packets go first.

### The volume byte

Doc 01 "Senses": "Only the volume is sent, one byte per voice frame, and nothing is stored."

- Computed on the sender from the frame's RMS after manual gain and denoise, relative to the
  player's calibrated normal speaking level:
  `volume = clamp(round((db_rel + 30) * 255 / 48), 1, 255)`, where `db_rel` is the frame's level in
  dB minus the normal level. So -30 dB relative is 1, normal speech is about 159, and a scream at
  +18 dB or louder is 255 (`placeholder` range).
- **Relative to each player's own normal level is a reading** (inference). Doc 01 "Senses" says
  only "louder sounds carry further". The reading makes a loud talker and a quiet one equally
  audible at normal speech, so mic hardware and natural voice don't decide who the creature hears;
  the alternative, an absolute level after fixed gain, would. Its weakness: a player who calibrates
  by shouting reads quieter to the creature afterwards. So the mic check asks for a normal voice,
  and the stored normal level is clamped to a plausible range (-40 to -15 dBFS, `placeholder`).
  Accepted in D-013; DD Phase 1 and 2 playtests can revisit it.
- **0 means not transmitting.** A frame is only sent while VAD or push-to-talk is open, so muted,
  push-to-talk released and Discord-only players are silent to the creature.
- The host reads it from each client frame, and `Voice` calls
  `NoiseBus.emit_voice(position, volume_byte, source_peer)` (CONTRACTS section 8, doc 05 section 8)
  at the speaker's position, at most every 100 ms using the loudest frame since the last report
  (`placeholder`). The host's own mic takes the same call. How far a volume carries is doc 03's;
  `NoiseBus` converts the byte to a radius.
- **Nothing is stored:** the host never logs volume values or keeps a history. The relay form of the
  frame drops the byte, so clients never see it.
- **Ghost frames don't feed the creature** (D-011): ghosts aren't in the world. `Voice` never calls
  `emit_voice` for a ghost speaker; `NoiseBus` rejects ghost sources as a second guard (doc 05
  section 8).

### Frame format (channel 2, `send_bytes`)

Client to host, 5 header bytes:

| Byte | Field |
|---|---|
| 0 | type `0x10` |
| 1 | flags: bit 0 radio, bit 1 talk start, bit 2 talk end |
| 2 to 3 | sequence number (u16, wraps) |
| 4 | volume (0 to 255) |
| 5 onward | Opus packet (about 45 bytes, section "Encode") |

Host to client (relay), 5 header bytes:

| Byte | Field |
|---|---|
| 0 | type `0x11` |
| 1 | speaker slot (0 to 3) |
| 2 | flags: bit 0 radio, bit 1 talk start, bit 2 talk end, bit 3 ghost |
| 3 to 4 | sequence number, copied |
| 5 onward | Opus packet, copied |

The spike used both formats with types `0x01` and `0x02` (**measured (PP-02)**). The game moved
them to `0x10` and `0x11` in P1-06 because every `send_bytes` packet arrives on one signal and
movement already uses `0x01` and `0x02` (`game/player/move_frame.gd`, P1-04); Q-042 asks for the
DECISIONS entry. Until slots exist, the slot byte is the speaker's index in the host's roster order
(`Game.players`), which clients receive in `apply_roster`. The **ghost** bit is set by the host
from its own death state, so clients never play a dead player's voice clean because their local
state lagged.

### Host relay

- For each client frame: check the sender is connected and has a slot, read the volume, then send
  the relay form to every other connected peer, ghosts included, and decode it for the host's own
  playback.
- The host's own mic frames take the same path minus the network hop.
- Relay is to everyone, not culled by distance: at 4 players it's cheap (section 13), and culling
  would cut a voice that walks back into range mid-word. Distance does the fading on each client.

### Playback

- Each remote player's character has a `VoiceEmitter` (`AudioStreamPlayer3D`) playing its own
  TwoVoIP `AudioStreamOpus`, one per speaker (decoders keep state and must not be shared).
- **Jitter buffer:** frames are reordered by sequence number and held to a 60 ms target
  (`placeholder`; the spike's buffer worked as described, **measured (PP-02)**).
- **Loss is concealed by Opus PLC only** (D-012): when a frame is missing and a later one has
  arrived, the later packet is pushed with `push_opus_packet(bytes, 0, decode_fec = 1)`; with no
  FEC data in it, libopus conceals exactly one frame, then the packet is pushed normally. With 10%
  simulated loss the spike lost 10.1% and 10.4% of frames, all concealed, with 0 clicks
  (**measured (PP-02)**).
- **`mark_end_opus_stream(false)` resets the decoder.** Call it only at a talk end, never on a gap
  inside speech (**measured (PP-02)**).
- **Underflow:** at most 216 ms per speaker over about 45 s, mostly at talk starts (**measured
  (PP-02)**, headless, so pessimistic).
- Attenuation `placeholder`s: inverse distance, unit size 10 m, max distance 120 m (raised from 6 / 80 at the Phase 1 playtest: quiet, short) plus a `voice_gain_db` setting (default +6 dB, no AGC), so a voice is
  still placeable at the 60 m spatial audio test distance (doc 01 "Testing > Spatial audio").
- Ghost voices play from the ghost's spectating position as the Ghost system reports it (Q-006).
- **Risk: TwoVoIP v6.5 playback thread safety.** v6.6's changelog makes "the decoded Opus playback
  ring safe between its single packet-producing thread and Godot's audio mixing thread"; v6.5 lacks
  that fix, which is a plausible cause of the crackling in upstream issues #45 and #80 (inference).
  The spike found **0 clicks** with 3 and 4 simultaneous speakers on every receiver (**measured
  (PP-02)**, loopback and the dummy driver, plus 4 windowed WASAPI runs with 0 loss). Real ears on
  real machines at STOP 1 settle it. All pushes to an `AudioStreamOpus` happen from one thread (the
  main thread), so we never add a second producer.

### Spatial audio and the weak-localization contingency

Doc 01 "Voice > Weak localization": "Godot's stock 3D audio is weak front-to-back. If the Phase 1
test fails, evaluate the Steam Audio GDExtension (Valve's free spatial-audio library, which doesn't
need Steam), or add per-source occlusion and reverb." The test is doc 01 "Testing > Spatial audio
(Phase 1 gate)": with headphones, place a voice and a whistle at 10, 30 and 60 m.

- **DD Phase 1 ships stock Godot spatialisation:** `AudioStreamPlayer3D` with the attenuation above.
- **`VoiceEmitter` stays swappable.** It is the only node that places a voice in 3D: real voices,
  ghosts, the creature's fakes and Dawn Report replays all play through it, and nothing outside it
  touches the underlying player node. Its interface is the stream to play, the bus (section 9) and
  the position it follows. So replacing the spatialiser changes one scene, not the voice chain.
  The whistle is a sound, not a voice (doc 08's); the same contingency applies to its emitter, and
  the Audio Designer keeps it equally swappable (inference: settled by doc 08).
- **If the DD Phase 1 test fails**, two routes, in doc 01's order:
  1. **Steam Audio GDExtension:** a new addon, so it needs CEO approval of source and license under
     D-005 before it enters the repo. Candidate facts are in section 15.
  2. **Per-source occlusion and reverb** in our own code: a raycast from each emitter to the
     listener sets a low-pass and volume drop when blocked (walls, buildings), and a reverb send
     per area (barn, shed, corn, open field). Stock Godot only (`AudioEffectLowPassFilter`,
     `AudioEffectReverb`, `Area3D` reverb buses), so no approval is needed. Whether occlusion helps
     front-to-back placement, rather than only realism, is unknown (inference; a re-run of the
     test settles it).
- Fakes and real voices must stay identical under whichever route is chosen, or the route becomes a
  tell (doc 01 "The creature's fakes": "so they don't sound cleaner").

### Mic modes

Doc 01 "Voice > Mic mode": open mic with voice activity detection is the default; push-to-talk is
an option and doubles as stealth.

- **VAD:** opens when the frame's level is above a threshold set by the lobby mic check (normal
  level minus 15 dB, `placeholder`), stays open 300 ms after the level drops (`placeholder`), and
  sends the 100 ms pre-roll on opening.
- **Push-to-talk:** a held key (`voice_push_to_talk`, Q-006). VAD is off while push-to-talk is on.
  Released means no frames and volume 0, which is the stealth.
- **Mute** stops frames entirely.
- The talk start and talk end flags let receivers drain their jitter buffer at the end of speech
  instead of waiting for frames that won't come.

## 9. The shared voice chain

Doc 01 "Voice > The creature's fakes": "played from the creature through the same voice chain, so
they don't sound cleaner. Fakes of the dead use the ghost static chain." Doc 01 "How players fight
back > Tells": "each fake has at most one random giveaway: a faint echo, a wrong pitch, or a
missing radio crackle; about a third have none; it always comes from a place the teammate can't be."

One chain, in `game/voice/`, used by real voices and fakes alike. Every voice, real or fake, plays
through the same Opus decode at the same settings: lobby lines are stored and shared as Opus packets
encoded with the live settings (section 11), so fakes carry the same codec character as live
speech.

| Stage | Real teammate | Fake |
|---|---|---|
| Opus decode | yes | yes, from the stored clip |
| `VoiceEmitter` 3D placement | on the character | on the creature, at the lure position |
| **Crackle layer** | yes | yes, unless the tell is `no_crackle` |
| Echo (`AudioEffectDelay`, faint, `placeholder` 180 ms, -18 dB) | no | only if the tell is `echo` |
| Pitch (`AudioEffectPitchShift`, `placeholder` ±6%) | no | only if the tell is `pitch_up` or `pitch_down` |
| Ghost static | if the speaker is dead | if the voice's owner is dead (doc 01 "The dead-voice twist") |

- **The crackle layer** is a faint radio-like crackle on every proximity voice, so that its absence
  can be a tell (D-011). It's a second `AudioStreamPlayer3D` on the emitter playing a generated
  crackle loop whose level follows the voice's envelope. D-011 records the reasoning: walkie-talkies
  can't be faked, so the crackle a fake can lack must be on proximity voice. It **must stay faint
  enough not to hurt the cozy day**; DD Phase 1 checks it (Q-005 answer).
- **Tells are picked by the host** per lure (one of `none`, `echo`, `pitch_up`, `pitch_down`,
  `no_crackle`; `none` about a third of the time per doc 01) and sent in `apply_lure`, so every
  client and the Dawn Report replay hear the same fake. **Nightmare** (doc 01 "Difficulty"): the
  host always picks `none`, and the wrong-place tell remains because it is positional, not in the
  chain.
- **Ghost static** (doc 01 "Ghosts > Static voices"): band-pass (`placeholder` 400 Hz to 3 kHz),
  distortion, and a static noise layer on the emitter gated by the voice envelope, heavy enough to
  disguise the speaker a little. Applies on top of the base chain, so a dead teammate's fake can
  still carry an echo or pitch tell (inference: doc 01 says fakes of the dead use "the same
  static", and doesn't exempt them from tells).
- **Implementation:** effects live on audio buses, so the chain is a small set of buses under
  `Voice` (CONTRACTS section 9): `VoiceBase`, `VoiceEcho`, `VoicePitchUp`, `VoicePitchDown`,
  `VoiceGhost`, `VoiceGhostEcho`, `VoiceGhostPitchUp`, `VoiceGhostPitchDown`, `VoiceRadio`. An
  emitter picks its bus per playback. **`game/voice/` creates them, and `Mic`, at runtime** (D-020,
  Q-007, Q-033); `default_bus_layout.tres` (Audio Designer) holds only the base buses, and the
  levels come from `game/audio/mix_levels.gd` (doc 08 sections 2.2 and 7.2), never constants in
  `game/voice/`.
- **The crackle player** is `vox_crackle_loop` (doc 08 section 7.2) on a second
  `AudioStreamPlayer3D` child of `VoiceEmitter`, at -34 dB relative to the voice's RMS envelope.
  It uses the same bus as the voice, so ghost static, echo and pitch apply to it too, and it is
  stopped for the `no_crackle` tell. It is part of `VoiceEmitter`, so a spatialiser swap
  (section 8) moves it with the voice.
- **Who hears ghosts** (D-011): the living hear them through static; ghosts hear each other clean.

## 10. Walkie-talkies

Doc 01 "How players fight back > Walkie-talkies": "craftable and unfakeable, carrying only real
teammates. Limited batteries; static when the creature is near." Price and battery life are doc
02's (`sim` per doc 01 "Store").

- **Talking:** a separate key (`voice_radio`, Q-006) sets the radio flag on frames. The speaker is
  still heard in proximity as normal; the same frame serves both, so radio costs no extra upload.
- **Host routing:** the host honours the radio flag only if the sender is alive and holds a walkie
  with battery (host-owned item state), and drains the battery while transmitting. It relays the
  frame with the radio flag to every peer, and clients play it on the radio only if the host says
  they hold a powered walkie (`apply_walkie`).
- **Only living senders is a reading** (inference): doc 01 says walkies carry "only real
  teammates" and that the living hear ghosts "in proximity chat through heavy static", and is silent
  on whether a ghost can transmit by radio. Ghosts don't hold items, so the strict reading is no.
  Accepted in D-013; DD Phase 3 playtests or doc 02's item rules can revisit it.
- **Playback:** on the receiver's own walkie, through `VoiceRadio` (band-pass, crackle), not
  attenuated by distance. **Only the holder hears a receiving walkie** (D-011); players standing
  near the receiver don't.
- **Static near the creature:** each client adds static to radio playback from the replicated
  creature distance, starting at 30 m (`placeholder`, doc 03 may tune).
- **Unfakeable by construction:** the radio path only plays relay frames from a live player's slot.
  There is no API from lure or clip playback into `VoiceRadio`.

## 11. Lobby lines, barn chatter and voice settings

### Voice settings

Doc 01 "Voice settings", exactly:

| Setting | Effect | Built |
|---|---|---|
| **Off** | Nothing recorded; the creature fakes only this player's footsteps and tools | DD Phase 2 |
| **Lobby lines** (default once recorded) | Lobby lines and barn chatter can be replayed by the creature and in the Dawn Report | DD Phase 2 |
| **Live clips** (opt-in, Phase 5) | Short clips of transmitted proximity speech can be kept and replayed | Not built (section 16) |

- **No forced consent screen.** Each player picks on their own machine and can change it any time,
  in the menu, lobby or pause menu. The setting lives in the player's local settings, never the
  host's save.
- **Changing it** sends `request_voice_setting`; the host applies it without question and
  broadcasts `apply_voice_setting`. The owner's machine is the authority.
- **Coverage:** the setting governs every replay: the creature's lures, the Dawn Report (Off players
  appear as text plus sound) and streamer-safe mode (doc 01 "Voice settings > Coverage"). A replay
  checks the owner's **current** setting at play time, not the setting when the lure first played.
- **Live speech isn't affected:** Off players still talk in proximity chat, and their volume still
  reaches the creature. The setting is about recording and replay. The one exception is on a
  machine that is capturing ("Recording" below, D-011).
- **Off players are never voiced by a stand-in** (doc 01 "Habits"): the host's lure picker never
  picks a clip of theirs or a generic voice in their name; it fakes their footsteps and tools.
- The lobby recommends in-game voice with doc 01's line: "The creature can't hear Discord, and you
  can't hear where your friends are." (doc 01 "Staying on in-game voice").
- UI copy never says or implies the line list is the whole pool (doc 01 "Habits").

### Setting IDs and before recording

- **On the wire** (`request_join`, `request_voice_setting`, `apply_voice_setting`, `apply_roster`):
  `off` or `lobby_lines`. `live_clips` is reserved for DD Phase 5; the host refuses it until then.
- **Locally,** a new install starts **unchosen**: the player has neither picked Off nor recorded.
  Doc 01 makes Lobby lines the default only "once recorded", so an unchosen player has nothing
  recorded and is sent as **`off`**: the creature fakes only their footsteps and tools, exactly as
  Off says. Recording is offered to unchosen players and to Lobby-lines players with no lines; a
  player who **chose** Off is not offered it until they change the setting.
- When an unchosen player accepts at least one recorded line, their setting becomes `lobby_lines`
  and the client sends `request_voice_setting`. If they skip, they stay unchosen and the menu offers
  re-record or skip later (doc 01 "Recording > Menu option").
- **This is a reading of "default once recorded"** (inference), accepted in D-013; DD Phase 2
  playtests can revisit it.

### Recording

Doc 01 "Recording lines that sound scared". Built in DD Phase 2 (doc 01 "Build Plan").

- **Who:** unchosen players and Lobby-lines players ("Before recording" above); not players who
  chose Off. It can be skipped, and re-recorded or skipped later from the menu.
- **Staging:** the lobby is the dark barn at night; each line follows a staged moment, such as a
  lantern blowing out before "help me", or a bang on the door before "over here". The lantern
  **blows out, never flickers** (doc 01 "Ghosts": nothing but a ghost flickers a light).
- **Lines:** "over here", "help me", "come look at this", "I found something", "where are you?",
  "wait for me", "it's fine, come on", and each teammate's name: 7 lines plus one per teammate, so
  10 at 4 players (doc 01 "Recording > Lines").
- **Line IDs:** the seven fixed lines take their IDs from `voice_lines.json` (CONTRACTS section 6).
  A teammate's name is `name:<player_uid>`, using the teammate's 128-bit uid as 32 hex digits, so
  the line survives new peer ids and slots and follows the teammate across sessions; its file is
  `name_<player_uid>.vclip`. A late joiner's name is a new line for everyone else (recorded at their
  next lobby or skipped; inference). A teammate who renames keeps their old recorded name until
  re-recorded (inference).
- **Takes:** 2 to 3 per line. The game keeps the most energetic take, scored by loudness (mean dB of
  voiced frames) plus pitch variation (standard deviation of the estimated pitch); the weights are
  `placeholder`s. The other takes are deleted once the player accepts the line.
- **Barn chatter:** 20 to 40 seconds of free talk, only from Lobby-lines players who join the staged
  recording. **Captured on the sender's machine** from their own mic, before any network hop.
- **No Off player's voice during capture** (D-011): while a machine is capturing a take or barn
  chatter, it plays **no Off player's voice** (proximity, walkie or ghost; unchosen players count
  as Off), so speaker bleed can't put an Off player into a clip. The recording screen says so: "While
  you record, you won't hear: Sam (voice Off)." This enforces doc 01 "Voice settings": "Off |
  Nothing recorded". Off players' frames are still decoded, just not played, so the decoder stays in
  step. If a player switches to Off during a capture, the capturing machine mutes them as soon as
  `apply_voice_setting` arrives and discards the take in progress, or the chatter captured so far,
  so the recorder redoes or skips it (inference: the strictest way to make "nothing recorded" hold
  for the moment before the message arrives; accepted in D-013, revisited in DD Phase 2 if needed).
- **Format:** each clip is the same Opus packets the live encoder would send (section 8 settings),
  in a small file: a header (clip id, line id, frame count, settings) followed by packets each
  prefixed with a u16 length. Stored as `user://voice/lines/<line_id file name>.vclip` and
  `user://voice/chatter/<n>.vclip`.
- **Review:** every clip can be played back and deleted before the match (doc 01 "Voice settings >
  Review"). Deleting sends `request_clip_deleted`.

### The recording light

Doc 01 "Voice settings > Recording light": "a 'recording' lantern or tally light shows whenever
capture is live." Doc 01 "Barn chatter": "Captured on the sender's machine, with the recording
light on."

- **Capture is live** whenever this machine is writing mic audio to a clip: every recorded take and
  the whole barn chatter window. (In DD Phase 5 also while live clips are kept.) **This is a
  reading** (inference): proximity chat also runs `AudioEffectCapture` all the time, but nothing it
  captures is kept, so it isn't "capture" in the sense the light warns about; a light that was always
  on would warn of nothing. Accepted in D-013; DD Phase 2 playtests can revisit it.
- The light shows on the recording player's own screen as a steady tally, and on their character in
  the barn for everyone (`apply_recording_light`, D-011), so friends know when they are being
  captured.
- It is on for the whole capture window, steady, never flickering.

### Storage and "Off deletes them"

Doc 01 "Voice settings > Storage": "lobby lines stay on the owner's disk and in peers' memory only,
never in the host save. Off deletes them."

- **Owner:** files under `user://voice/`, and nowhere else.
- **Peers, including the host:** in memory only. Received clips are never written to disk, cached,
  or put in a `Resource` that could be saved. The dawn save holds none of it.
- **Off:** switching to Off asks once ("This deletes your recorded lines", only if any exist), then
  deletes every file under `user://voice/lines/` and `user://voice/chatter/`, and broadcasts
  `apply_voice_setting`. On that message every peer frees that player's clips, **any lure already
  playing one of them stops at once**, and the host cancels any queued lure using them.
- **Leaving the session:** peers free the leaver's clips (a reading; section 5 "Leaving").
- **Logs** may name a `line_id` and the owner's peer id in `lure_played`, never audio (section 14).

## 12. Lures and clip pre-sharing

Doc 01 "Voice > Lures": "clips are sent to every peer at session start, so a lure is a host message
('play clip X at P for player Y'), not streamed audio."

### Pre-sharing

1. After joining (and recording, if needed), each Lobby-lines player sends
   `request_clip_manifest(manifest)`: clip ids, line ids, frame counts, byte sizes.
2. It then sends each clip in 16 KB chunks (`placeholder`) on channel 3. The host checks the sender
   owns the clips and the caps (64 clips and 400 KB per player, `placeholder`; two to three times
   the expected size, section 13), keeps a copy in memory, and forwards to every other peer.
3. A late joiner receives everyone's clips from the host; everyone receives theirs.
4. A re-recorded or deleted clip is re-sent or removed the same way.
5. Each client reports when it holds every clip in the manifest; the host doesn't start the match
   until all have, or a 30 s timeout passes (`placeholder`; any lure whose clip a target lacks is
   skipped for that target).

### A lure

`apply_lure(lure_id, source, position, target_slot, tell, ghost)`

| Field | Meaning |
|---|---|
| `lure_id` | Unique per session; shared by the `lure_played` and `lure_result` log events (D-012) and the Dawn Report |
| `source` | Either `{owner_slot, line_id, segments}` for a voice clip, or `{sound_id}` for faked footsteps, watering cans, hoes, generic "stranger" voices (doc 01 "Material", "Habits") and DD Phase 1's generic voice lines from the corn (doc 01 "Build Plan > Phase 1") |
| `segments` | List of `(clip_id, first_frame, frame_count)`. One whole-clip segment for exact clips (days 1 to 3); several for spliced clips from day 4 (doc 01 "Ramp-up" table). Choosing splice points is doc 03's |
| `position` | Where the creature plays it from |
| `target_slot` | The target for day lures (sent **only** to that peer), or -1 for night and chase lures (sent to all, a world sound) (doc 01 "Who hears a lure") |
| `tell` | `none`, `echo`, `pitch_up`, `pitch_down`, `no_crackle` (section 9) |
| `ghost` | True if the voice's owner is dead: the ghost static chain (doc 01 "The dead-voice twist") |

- Targeted lures go only to the target's machine, so a teammate's client never has them to leak.
- **Dawn Report** (doc 01 "Dawn Report", "Who hears a lure"): `apply_dawn_report` lists each lure
  by reference; every peer already holds the clips, so the replay plays locally, with the same tell
  and chain, following each owner's current setting: **Off players appear as text plus sound**
  (doc 01 "Voice settings > Coverage"), the sound being the footsteps or tools the creature faked
  for them.
- Clip frames are pushed into a fresh `AudioStreamOpus` on the creature's `VoiceEmitter` and played
  through the chain; TwoVoIP has no standalone PCM decoder, so this is the only way to play a clip,
  and it is the same decode path as live voice. A splice resets nothing: the decoder runs across
  segment joins, which may add a faint glitch at each join (inference; heard in DD Phase 2).

## 13. Bandwidth

Worst case: **4 players all talking at once**, one of them the host. **Measured (PP-02)**, 4 local
copies on loopback, synthetic voices talking about 84% of the time, movement at 20 Hz, UDP/IPv4
headers included (ENet's own byte counters plus 28 bytes per datagram):

| Players | Host up | Host down | Each client up | Each client down |
|---|---|---|---|---|
| 4 | 327 to 342 kbps | 111 to 113 kbps | 36 to 39 kbps | 109 to 118 kbps |
| 3 | 147 to 154 kbps | 72 to 74 kbps | not recorded | not recorded |
| 2 | about 36 to 39 kbps | about 36 to 39 kbps | about 36 to 39 kbps | about 36 to 39 kbps |

- **Host total: about 0.34 Mbps up and 0.11 Mbps down; client about 0.04 up and 0.11 down.** If
  all four talked 100% of the time, the voice share would rise by at most 1/0.84, so the host would
  stay under about 0.41 Mbps up (inference, an upper bound treating all traffic as voice). Typical
  home upload is several Mbps (inference; STOP 1 logs over the real internet settle it).
- **Why it beat the old estimate** (doc 06's first draft estimated about 0.45 Mbps host up):
  - Opus packets average about 45 bytes, not the 60 a constant 24 kbps implies (section 8).
  - ENet packs several commands bound for the same peer into one datagram. Each extra frame in a
    datagram saves the 28 B UDP/IPv4 header plus ENet's protocol header of about 4 B, so about
    32 B; the ENet send command (about 8 B) still repeats per frame (inference from ENet's
    protocol; the measured totals agree).
- Per frame sent alone: about 45 B Opus + 5 B our header + 1 B `send_bytes` type byte (inference)
  + about 12 B ENet + 28 B UDP/IPv4 = about 91 B.
- Walkie traffic adds nothing: it rides the same frame (section 10).
- **Clip sharing at session start:** 10 lines at 4 players (section 11) of about 1.5 s plus up to
  40 s of chatter is about 55 s. At the measured 45 B per frame plus the 2 B length prefix that is
  about 129 KB per player; at a full 24 kbps (60 B packets) plus the prefix it would be about 171 KB. The host sends 3 owners' clips to
  each of 3 clients: about 1.2 to 1.5 MB (9 transfers of 129 to 171 KB), a few seconds of upload (inference; real speech and
  channel 3 are measured in DD Phase 2).

## 14. Testing hooks and logs

Doc 01 "Testing": 2 to 4 local copies over ENet (Debug > Customize Run Instances), a mic-from-WAV
input per copy, simulated latency and packet loss. QA's `tools/qa/multi.py` launches the copies
(PP-03).

- **Command line** (after `--`, read with `OS.get_cmdline_user_args()`):
  `--voice-wav <path>`, `--host`, `--join <code or ip>`, `--net-sim-latency-ms <n>`,
  `--net-sim-jitter-ms <n>`, `--net-sim-loss <0..1>`. The simulation delays and drops outgoing
  packets in `game/net/` on channels 1 and 2 (dropping reliable packets would only stall them, so
  channels 0 and 3 are only delayed).
- **Every send goes through one `Net` wrapper.** Godot sends an RPC the moment `rpc()` or
  `rpc_id()` is called, so the simulator can only delay channel 0 if no code calls them directly.
  Gameplay code calls `Net` methods (for example `Net.to_host(method, args)` and
  `Net.to_peers(method, args, targets)`), which queue the call while simulation is on; `send_bytes`
  goes through the same wrapper. Direct `rpc()` calls outside `game/net/` are a review finding.
- **Log events** (CONTRACTS section 10 format; doc 05 holds the full list). Players are named by
  ENet peer id (CONTRACTS section 10 `peer`), never by slot (D-012). The spike logged the network
  and voice events below (**measured (PP-02)**; `spikes/voice/README.md` "Logs").

| Event | Data |
|---|---|
| `net_upnp_result` | `result` (`success`, `no_devices`, a router error, `skipped`), `external_address_class` (`public`, `private`, `cgnat`, `unknown`), `port`, `seconds`, `lease_s`, `gateway_found`. The public IP is never logged |
| `net_connected` / `net_connect_failed` | `connect_ms`, `via` (`code`, `ip`) |
| `net_join_code_rejected` | `reason` (`typo` for a failed check, `length` for code-shaped input of the wrong length; section 4). The typed code is not logged |
| `net_peer_joined` / `net_peer_left` | `peer`; `reason` (`quit`, `timeout`, `host_quit`) on leaving |
| `net_host_left` | `how` (`quit`, `disconnected`) |
| `net_rtt` | `to` (peer id), `rtt_ms`, `enet_loss`, every 10 s |
| `net_bandwidth` | `up_kbps`, `down_kbps` (UDP/IP headers included), `up_datagrams_per_s`, every 10 s |
| `voice_stats` | per speaker every 10 s and when the speaker leaves: `speaker` (peer id), `received`, `lost` (concealed by PLC), `late`, `decoded`, `loss`, `talk_spurts`, `underflow_ms`, `overflow_ms` |
| `voice_capture` | once when capture starts: `input` (`mic` or `wav`; the WAV's file name is never logged), `mix_rate`, `push_to_talk` |
| `voice_sent` | this machine's mic every 10 s: `input` (`mic`, `wav`, `off`), `encoded`, `sent`, `bytes`, `talk_spurts`, `push_to_talk`, `relayed` (host only: frames through the relay, its own included). No volume values |
| `lure_played` | `lure_id`, `owner` (peer id, or null for a `sound_id` lure), `line_id` (or null), `sound_id` (or null), `target` (peer id, or null for a world lure), `position` (`[x, y, z]`), `tell`, `ghost`. No audio, no volume |
| `lure_result` | `lure_id` (the same as its `lure_played`), `target`, `moved_m`, `within_s`, `worked` (CONTRACTS section 10; `within_s` is Q-002, doc 05's) |

Measured in PP-02 on loopback: connect 18 to 20 ms by code, 18 to 19 ms by raw IP; RTT 16 to 23 ms;
reliable loss 0; voice loss 0 in every 2, 3 and 4-player stream without simulated loss.

Measured in P1-06 (`game/voice/`, 2 headless instances on loopback, synthetic WAVs, 30 s): each side
received 813 to 836 frames with 0 lost and 0 late, underflow 4 to 20 ms, and the host emitted 460
`voice` noise events; 0 error lines.

## 15. Opus GDExtension and other addons

### Chosen: TwoVoIP v6.5 (D-009)

The CEO approved TwoVoIP v6.5 (Q-003, D-009) after the comparison below, and PP-02 installed it in
`addons/twovoip/`.

**What PP-02 found** (all **measured (PP-02)** unless marked):

- **It loads and runs on Godot 4.7.2** although built for 4.6 (`compatibility_minimum = "4.6.0"`):
  `TwovoipOpusEncoder` and `AudioStreamOpus` work at runtime, in headless and windowed runs.
- **The release archive has no license files.** The five license texts (TwoVoIP MIT; libopus,
  RNNoise, SpeexDSP BSD-3-Clause; godot-cpp MIT) were fetched as plain text from the exact commits
  v6.5 pins; sources and hashes are in `addons/twovoip/VERSION`. They ship with the game.
- **The first headless editor import segfaults** (Q-008). From a clean `.godot/`,
  `"$GODOT" --headless --editor --quit` crashes (exit 139, 0xC0000005) on 5 of 5 fresh copies; the
  control without the addon passed 2 of 2. It hits the run that first registers the extension:
  later runs pass, and deleting only `.godot/extension_list.cfg` brings it back.
  - It goes away if the editor runs 60 frames or more before quitting (`--quit-after 60`, 120 and
    200 pass; 30 crashes), or if `.godot/extension_list.cfg` is pre-seeded with the line
    `res://addons/twovoip/twovoip.gdextension`.
  - `reloadable = true` and using the release DLL in the editor change nothing. Mismatched init
    levels were ruled out. No native stack trace exists (no debugger installed, no Windows Error
    Reporting event), so the cause inside the extension or the engine is unknown. It is not
    upstream #107's code, which v6.5 lacks.
  - **Until it's fixed,** a clean-checkout import is run twice or the file is seeded first (Q-008
    answer). QA's `tools/qa/smoke.py --clean-import` now seeds the file for every
    `addons/*/*.gdextension` (Q-010).
  - An exported build isn't affected: it never runs the editor import, and the voice spike's export
    (D-014) loads TwoVoIP from a folder with no `.godot/` (**measured**, 2026-10-06).
- **A plain run never loads the addon without `.godot/extension_list.cfg`.** A fresh folder that
  never had an editor import fails to parse `TwovoipOpusEncoder` and hangs. Anything shipped as a
  project folder (the spike's friend package) seeds the file.
- **No in-band FEC** (D-012; section 8 "Encode").
- **Decision: keep v6.5 pinned.** Runtime is unaffected, the workaround is one file, and v6.6 is
  worse (#107 crashes the editor at every start).

### The comparison (2026-10-05)

For Q-001 and D-008 (CEO chose option 1). Godot has no built-in Opus (doc 01 "Voice"). Criteria:
open source, prebuilt Windows x86_64 binary, works on Godot 4.7.2 (CONTRACTS section 1), and
exposes encode and decode of raw PCM frames that fit `AudioEffectCapture` to ENet. Facts below
were read on 2026-10-05 from each repository's GitHub page, README, `.gdextension` file and
releases through the GitHub API; only TwoVoIP was later installed and tested.

All four bundle **libopus, BSD-3-Clause** (Xiph.Org). Its notice must ship with the game.

| | TwoVoIP | GodotOpus (BuzzLord) | godot4-opus (microtaur) | one-voip |
|---|---|---|---|---|
| Repo | https://github.com/goatchurchprime/two-voip-godot-4 | https://github.com/BuzzLord/godot-opus | https://github.com/microtaur/godot4-opus | https://github.com/RevoluPowered/one-voip-godot-4 |
| License | MIT | MIT | MIT | MIT |
| Bundled libraries | libopus, RNNoise, SpeexDSP (all BSD-3-Clause), godot-cpp (MIT) | libopus, godot-cpp | libopus, godot-cpp | libopus, godot-cpp; needs webrtc-native |
| Last release | v6.6, 2026-09-23 (v6.5, 2026-09-08) | v0.2.1, 2024-10-12 | 0.1.1, 2024-01-17 | v0.1, 2023-12-10 |
| Godot support | `compatibility_minimum = "4.6.0"`, built against 4.6; runs on 4.7.2 (**measured (PP-02)**) | `compatibility_minimum = "4.1"` | `compatibility_minimum = 4.2` | 4.x |
| Windows x86_64 binary | Yes, in `TwoVoIP.zip` (all platforms, about 120 MB; CI-built) | Yes, `Godot_Opus.zip` (per README) | Yes, `libopus-0.1.1.windows.x86_64.zip` (release only ships Windows) | Yes (per README) |
| Raw PCM encode | `TwovoipOpusEncoder.process_chunk(PackedVector2Array)` then `encode_chunk()` returns a `PackedByteArray`; takes any input rate and resamples | `GodotOpus` node: push frames, `get_encoded_packet()` | `Opus.encode()` | Only as a bus effect emitting packets |
| Raw PCM decode | **No standalone decoder:** decodes into an `AudioStreamOpus` playback (`push_opus_packet(bytes, begin, decode_fec)`). A standalone decoder is an open PR (#103) | Yes, plus `decode_dropped` for loss concealment | `decode()`, `decode_and_play()` | Into its own stream |
| Loss handling | **PLC only:** the encoder never enables in-band FEC (D-012) | FEC and PLC (per README) | none listed | none listed |
| Extras | RNNoise and Speex denoise, peak and RMS per chunk, buffer underflow and overflow diagnostics, jitter-buffer helper scripts | VBR/CBR, packet loss setting | none | jitter buffer and echo cancelling listed as unfinished |
| Maturity | 185 stars, 28 forks, active since 2024, in the Godot Asset Store. Fast-moving: 6.4 to 6.6 within three weeks, 6.5 removed methods. **v6.6 crashes the 4.7 editor on Windows x86_64 at startup** (issue #107, open). **v6.5 crashes the first headless import** (above). Open issues about crackling (#80) and crackling with 3+ simultaneous speakers (#45); see the thread-safety risk in section 8 | 0 stars, one author, no activity for two years | 16 stars; the API passes `PackedFloat32Array` for packets (from the README sample); open issues "it doesn't work" and "Wont build"; no activity since 2024 | Author marked it inactive and points to TwoVoIP |

Not listed because they have no prebuilt release or don't fit: jam-launch/godopus and
mrTag/listenclosely (no releases), punikonta/godot-gdextension-opus (no releases),
Joy-less/OpusGdextension and goatchurchprime/godot-xiph-audio (Ogg Opus file import, not VoIP),
ikbencasdoei/godot-voip (no Opus).

**Why TwoVoIP:** the only maintained candidate, ships Windows binaries built by CI, encodes raw
frames from a `PackedVector2Array` (exactly what `AudioEffectCapture.get_buffer()` returns), gives
peak and RMS for VAD and the volume byte, and has denoising. Its costs:

- No standalone decoder. Clips are played by pushing their stored Opus packets into an
  `AudioStreamOpus`, which is how section 12 works, so this costs nothing now. If decode to PCM is
  ever needed, PR #103 or option 2 provides it.
- No in-band FEC (above).
- Fast API churn: pinned, version recorded in `addons/twovoip/VERSION`, upgraded only by task
  (D-009).
- Recent releases are AI-assisted (stated in the release notes). That's a maturity signal, not a
  license issue.
- **Fallback if v6.5 ever fails at runtime on 4.7.2:** GodotOpus (BuzzLord) has the cleanest raw
  encode/decode API and real FEC but is unmaintained; otherwise option 2.

### Option 2: our own libopus wrapper

Not chosen (D-008); kept as the fallback if TwoVoIP stops working. What it would need (all
inference from the godot-cpp build process):

- **Toolchain on the CEO's machine:** Visual Studio 2022 Build Tools (MSVC, free, several GB),
  Python with SCons, and CMake. None is installed (CONTRACTS section 1).
- **Sources (each needs CEO approval under D-005):** godot-cpp at the tag matching Godot 4.7 (MIT),
  libopus v1.6.1 (latest tag, BSD-3-Clause), as git submodules or a pinned copy.
- **Code:** about 300 lines of C++: an `OpusCodec` class with `encode(PackedFloat32Array) ->
  PackedByteArray`, `decode(PackedByteArray, fec: bool) -> PackedFloat32Array` and
  `decode_lost() -> PackedFloat32Array`, plus a Godot-side resampler or a 48 kHz mix rate. Playback
  through an `AudioStreamGenerator` per speaker, with our own jitter buffer. In-band FEC would be
  available here.
- **Build:** libopus statically through CMake, then the extension through SCons, Windows x86_64
  debug and release. A GitHub Actions workflow would be needed for other platforms.
- **Cost:** about 1 to 2 days for a working wrapper, plus the toolchain install (inference). Full
  control and a true PCM decoder, but no denoiser unless RNNoise is wrapped too.

### Contingency: Steam Audio GDExtension (only if the DD Phase 1 spatial audio test fails)

Doc 01 "Voice > Weak localization" (section 8, "Spatial audio and the weak-localization
contingency"). **Nothing is downloaded or adopted unless the test fails; adopting it is a new addon
under D-005 and needs the CEO's approval of source and license first.** Facts read on 2026-10-06
from the GitHub API, for that decision:

- **Repo:** https://github.com/stechyo/godot-steam-audio, MIT, 684 stars, latest release 0.3.1
  (2025-12-28), last push 2026-04-10. Features: spatial ambisonics, occlusion and transmission
  through geometry, distance attenuation, reflections (reverb).
- **Steam Audio itself:** https://github.com/ValveSoftware/steam-audio, Apache-2.0. The extension's
  README says Steam Audio "does use proprietary libraries" unless everything is compiled from
  source; which libraries, and whether their terms allow free redistribution with the game, must be
  checked before asking the CEO.
- **Maturity:** the README targets Godot 4.4, calls it "alpha" that "may crash", and says it is "not
  really being maintained/developed at the rate it could be". Whether it loads on 4.7.2 is unknown (inference), and as a second
  GDExtension it must pass the same first-import check as TwoVoIP.
- **Fit with voice:** unknown whether its player node can play an arbitrary stream such as
  TwoVoIP's `AudioStreamOpus` (inference). That is the first thing an evaluation checks, since every
  voice must go through `VoiceEmitter` (section 8).
- **Cost of the fallback route instead:** per-source occlusion and reverb in our own code (section
  8) needs no addon.

## 16. Later extension: live clips (DD Phase 5)

Out of scope until DD Phase 5 (doc 01 "Build Plan"). Recorded here only so nothing built now blocks
it:

- Source: transmitted speech from Live-clips players only; at most 3 s a clip; kept for that session
  then deleted; reviewable and deletable from the pause menu; no word filter (doc 01 "Live clips").
- Group options: a "no live clips" lobby toggle and streamer-safe mode, which never replays live
  clips (doc 01 "Live clips", "Difficulty and group settings").
- Section 11's clip format, manifest and `apply_lure` already carry any clip, so a live clip would be
  another clip type. The `live_clips` setting ID is reserved (section 11). Where it is captured, how
  it is shared and when the recording light shows for it get designed then.
- Spliced clips from live speech are also DD Phase 5 (doc 01 "Build Plan").

## 17. Gotchas

Each is marked **measured (PP-02)** if the voice spike hit it, otherwise it is inference or comes
from the cited source.

### ENet and Godot networking

- **`create_server` with `max_channels` ruins voice on Godot 4.7.2 (measured (PP-02)).**
  `ENetMultiplayerPeer.create_server(port, max_clients, max_channels)` passes its arguments to
  `create_host_bound` shifted by one (`modules/enet/enet_multiplayer_peer.cpp` line 67, 4.7.2-stable
  source), so `max_channels = 4` advertised an incoming bandwidth of 7 bytes per second. Logging
  `PEER_PACKET_THROTTLE` and `_LIMIT` showed each client's bandwidth throttle drop its limit to 1
  about 1 s after joining; unreliable packets were then dropped until the RTT throttle climbed back
  at about 16 s: 20 to 40% voice loss on loopback. Call `create_server(port, max_clients)` and let
  clients ask for the channels. Not reported upstream (the CEO declined, Q-009).
- **ENet's RTT throttle drops unreliable packets after a hitch (measured (PP-02)).** One slow round
  trip (a frame hitch, a Wi-Fi blip) makes ENet drop a share of unreliable packets for seconds. A
  windowed start-up hitch cost 37 frames once. Pin it with `throttle_configure(5000, 2, 0)`.
- **Two wrong explanations, disproved (measured (PP-02)):** pinning the RTT throttle changed nothing
  while the `create_server` bandwidth was wrong, and unsequenced vs ordered voice sends made no
  real difference. Fix the bandwidth first; voice stays plain unreliable.
- **Sending to a peer that is mid-disconnect** prints `Unable to send packet on channel 0`
  (measured (PP-02)). Check the peer's state first.
- **Channel numbering.** `ENetMultiplayerPeer` reserves system channels and offsets the
  user-facing `transfer_channel` past them; both ends must agree on the channel count, or sends on
  high channels fail (inference from the engine's enet module). Channels 1 and 2 work with clients
  asking for 4 (measured (PP-02)); channel 3 is unproven until clip sharing sends on it.
- **`server_relay` false** means clients get no `peer_connected` for each other. Every client learns
  the roster from `apply_roster`, never from engine signals.
- **Command-line args go after `--`.** Godot only passes user args placed after `--` to
  `OS.get_cmdline_user_args()`.
- **`rpc()` can't be delayed after the fact.** Network simulation needs every send to go through
  `Net` (section 14).

### UPnP and reachability

- **UPnP "worked" doesn't mean reachable.** Double NAT and carrier-grade NAT accept the mapping on
  the inner router. Check the external address class (section 3); the first friend to join is the
  only real test.
- **`UPNP.discover()` can succeed with zero devices (measured (PP-02)).** Check
  `get_device_count()` before `get_gateway()`, which otherwise prints an engine `ERROR`.
- **Some routers don't answer UPnP at all (measured (PP-02)):** the CEO's router at 10.0.0.1 gave
  `no_devices` under every discovery filter. The red state and the fallbacks are the normal path for
  such hosts, not an edge case.
- **No public IP lookup.** Doc 01 rules out third-party services, so when UPnP fails the game can't
  know the host's public address. The host types it from the router page.
- **Windows Firewall.** The first launch of each new exe path asks to allow it; declining, or the
  network being marked Public, blocks inbound UDP even with a port forward. Every new export path
  asks again.
- **Lease 0.** Some routers only accept permanent mappings, others reject them. Try a lease first,
  fall back on `ONLY_PERMANENT_LEASE_SUPPORTED`. A crash leaves a permanent mapping behind.
- **`UPNP.discover()` blocks** for seconds (9.7 s measured (PP-02)). Run it on a thread, never on
  the main thread.
- **The join code is not secret.** It is the host's IP address. Share it with friends only.

### TwoVoIP and the addon

- **The first headless editor import segfaults with TwoVoIP v6.5 (measured (PP-02)).** Run a
  clean-checkout import twice, or seed `.godot/extension_list.cfg` with
  `res://addons/twovoip/twovoip.gdextension` first (section 15).
- **A plain run without `.godot/extension_list.cfg` never loads the addon (measured (PP-02))** and
  hangs on the first `TwovoipOpusEncoder` reference. Seed the file in anything shipped as a folder.
- **No in-band FEC in TwoVoIP (D-012).** `push_opus_packet(..., decode_fec = 1)` only triggers PLC
  for one frame; don't plan on FEC recovery.
- **`mark_end_opus_stream(false)` resets the decoder (measured (PP-02)).** Only at a talk end.
- **TwoVoIP v6.6 crashes the 4.7 editor** at startup on Windows (issue #107). Stay on v6.5.
- **v6.5's playback ring isn't thread-safe** (v6.6 changelog). Push packets from one thread only.
- **Shared decoders.** One decoder per speaker; sharing one across speakers corrupts both
  (GodotOpus README).

### Audio

- **`audio/driver/enable_input`** can be set from code, but only before any
  `AudioStreamMicrophone` plays; without it no input frames arrive (measured (PP-02)).
- **A muted bus still feeds its `AudioEffectCapture`** (measured (PP-02), WAV input).
- **Headless capture comes in about 100 ms bursts** from the dummy driver at 44.1 kHz (measured
  (PP-02)). Don't tune the jitter buffer from headless numbers.
- **Mix rate.** `AudioEffectCapture` delivers frames at the output mix rate (44.1 kHz headless,
  48 kHz on the CEO's WASAPI device, measured (PP-02)), not the mic's input rate. Passing the wrong
  one to the encoder makes voices chipmunk or slur.
- **Stop audio players before quitting** (measured (PP-02)), or Godot reports leaked playbacks.
- **RNNoise doesn't eat synthetic voices (measured (PP-02)).** The test voices pass it unchanged,
  so WAV tests keep the full chain. Don't add a "denoise off for WAV" path.
- **AGC breaks hearing.** Automatic gain flattens a scream to a whisper's level. Keep it off for the
  volume byte.
- **Windows mic privacy, or a headset that's off.** Capture then returns silence with no error. The
  CEO's mic gave all-zero samples with Windows mic access allowed (measured (PP-02); a switched-off
  headset is inference). The lobby mic check says so when the level stays at zero.
- **Speakers instead of headphones.** No echo cancelling exists in any candidate (TwoVoIP issue
  #106 is a request), so a player on speakers feeds friends back into their mic. During capture, a
  Lobby-lines player's mic could record an **Off** player's voice from their speakers; D-011 closes
  that by not playing Off players' voices on a capturing machine (section 11). Headphones are
  required for the spatial audio test anyway (doc 01 "Testing").
- **Fakes must not sound cleaner** (doc 01 "Voice"). Record lines at the live Opus settings, not a
  higher bitrate, and keep any spatialiser change identical for fakes and real voices (section 8).
- **Steam Audio "does use proprietary libraries"** (its Godot extension's README). Check them before
  asking the CEO to approve it (section 15).

### Privacy and design rules

- **Received clips must never touch disk** (doc 01 "Storage"). Don't wrap them in a saved
  `Resource`, don't cache them in `user://`, and keep them out of the dawn save.
- **Logs name peer ids, never slots** (D-012), and never carry audio or volume values.
- **Nothing flickers but ghosts.** The recording light and the staged lantern blow-out stay steady
  or go out, and `apply_lights` never flickers; a flicker anywhere else breaks the one unfakeable
  signal (doc 01 "Ghosts").

## Questions raised

Current state of the questions this doc raised or depends on ([QUESTIONS.md](../production/QUESTIONS.md)):

| Question | To | State |
|---|---|---|
| Q-003 Approve TwoVoIP v6.5 | CEO | Answered: approved (D-009) |
| Q-004 Channel 3, `send_bytes`, `server_relay = false`, the message list | Director | Answered: approved (D-010) |
| Q-005 Doc 01 readings (crackle, ghosts, walkie, recording light, speaker bleed) | Director | Answered (D-011); folded into sections 8 to 11 |
| Q-006 `project.godot` entries and the ghost's voice position | Gameplay Programmer | Answered by doc 05 sections 3 and 14 (D-018) |
| Q-007 Who creates the `Mic` and voice chain buses | Audio Designer | Answered (D-020): `game/voice/` creates them at runtime; levels from `mix_levels.gd` (section 9) |
| Q-008 First-import crash, FEC, log identity | Director | Answered (D-012); crash diagnosed in PP-02 (section 15), v6.5 stays pinned |
| Q-009 Export templates, upstream bug reports, router UPnP, silent mic | CEO | Answered: templates installed (D-014); no upstream reports; Tailscale and the headset mic worked at STOP 1 |
| Q-010 Seed `extension_list.cfg` in `smoke.py` | QA | Done: `smoke.py --clean-import` seeds it |
| Q-011 Spike findings for this doc, `*.dll binary` | Director | Answered; findings folded in here |
| Q-012 Readings added in this revision: initial voice setting, volume relative to calibrated level, what "capture is live" means, freeing a leaver's clips, ghosts and walkies, discarding a take when someone switches to Off | Director | Answered: all six accepted (D-013); D-013 also confirms the section 7 verbs |
| Q-013 PP-02 review bugs (host-quit poll `ERROR`, host-supplied `session_id` path, wrong-length codes) | Director | Answered: items 1 to 3 become DD Phase 1 `game/net/` acceptance criteria (written at PP-12); item 3 is in section 4 |
| Q-023 Hold messages, `Net.rtt_ms`, `Voice` calls `NoiseBus.emit_voice` | from Gameplay Programmer | Answered: sections 6, 7 and 8 (cart transform rides `moves`) |
| Q-033 Runtime voice buses, crackle player | from Audio Designer | Answered: section 9 |
