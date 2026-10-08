# 10. Install and updates

For players. Windows 10 or 11 only. No Godot needed. The game is a gray-box playtest build, not the
finished game.

## Install (first time only)

1. Open the [Releases page](https://github.com/SneakKestrel16/brenny-brenn-boy-horror/releases/latest).
2. Under **Assets**, download `brenny_playtest.zip`.
3. Right-click the zip, choose **Extract All**, and pick a folder you will keep, for example
   `C:\Games`. Do not run the game from inside the zip.
4. Install [Tailscale](https://tailscale.com/download), sign in, and ask the host to share their
   machine with you (the game joins by the host's `100.x.y.z` Tailscale address, D-024).
5. Wear stereo headphones, left on left. Turn Windows spatial sound off. Close other voice chat.

## Play

- **Host:** double-click `Host.bat`. It shows your Tailscale address; give it to the others.
- **Join:** double-click `Join.bat` and type the host's address.
- Do not double-click the `.exe` itself: it starts a solo session.

Windows may warn the first time. Firewall: allow the game on **Private** networks. SmartScreen
("Windows protected your PC"): **More info**, then **Run anyway** (the build is not signed).

## Updates

`Host.bat` and `Join.bat` check GitHub for a newer release every time and update the folder in place
before the game starts. `Update.bat` does only the check. You never download the zip again.

- Everyone in a session must be on the same build or the join is refused. If a join is refused, run
  `Update.bat` on both machines.
- If the game is open, close it first; the updater will not replace a running game.
- No internet or GitHub down: the check prints one line and the installed build starts anyway.

## Send logs after a session

Double-click `send_logs.bat`. It writes `brenny_logs.zip` to your Desktop; send that to the host. It
holds game events and connection statistics only: no audio, no names.

## Publishing a build (host only)

From a clean tree whose commit is already on `origin/main`:

```sh
uv run tools/qa/package_playtest.py --release
```

This exports, zips and publishes GitHub release `<build id>` with the asset `brenny_playtest.zip`.
Players' `update.ps1` reads the latest release and compares its tag to the `BUILD.txt` in their folder.

## Gotchas

- A running `.bat` is read by byte offset, so replacing one mid-run can break it. The updater never
  overwrites an existing `.bat`; a changed `.bat` reaches players only by a fresh zip download.
  (`update.ps1` and the game files do update.)
- The release asset must be named exactly `brenny_playtest.zip`; `--release` enforces it.
- A `-dirty` build id never matches a release tag, so a dirty local build updates to the latest
  release on the next `Host.bat`. Do not run `Host.bat` from a dev package you want to keep.
- Verified with a local fake release server (old folder to new: game files and `BUILD.txt` replaced,
  existing `.bat` kept, second run says up to date, unreachable server falls through). Not yet run
  against a real GitHub release.
