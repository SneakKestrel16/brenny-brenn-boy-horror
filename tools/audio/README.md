# Audio render pipeline

Owner: Audio Designer (CONTRACTS section 2). Decision: D-015.

Generated sounds are written as SuperCollider code and rendered to WAV files without opening any
app or audio device, the same way `tools/blender/` drives Blender headless for models.

```
assets/audio/src/sfx_taint_heartbeat.scd  --render.py-->  assets/audio/sfx_taint_heartbeat.wav
```

## One-time setup on Windows

Both tools are free.

1. **SuperCollider.** Download the Windows 64-bit installer from
   https://supercollider.github.io/downloads and run it with the default options. It installs to
   `C:\Program Files\SuperCollider-<version>\`. Record the version in CONTRACTS section 1.
2. **SoX.** Download `sox-14.4.2-win32.exe` from https://sourceforge.net/projects/sox/files/sox/14.4.2/
   and run it with the default options. It installs to `C:\Program Files (x86)\sox-14-4-2\`.
3. **Check it.** In Git Bash at the repo root:

   ```bash
   uv run tools/audio/render.py sfx_taint_heartbeat --spectrogram
   ```

   You should see `1 of 1 rendered and passed checks.` Then open
   `assets/audio/sfx_taint_heartbeat.wav` and listen: a slow, low heartbeat.

`render.py` finds both tools in their default folders. If you installed them somewhere else, set
`SCLANG` and `SOX` to the full paths of `sclang.exe` and `sox.exe`, or pass `--sclang` and `--sox`.

If Windows Firewall asks about `scsynth.exe` the first time, you can choose **Cancel**. Rendering
uses no network.

## Use

```bash
uv run tools/audio/render.py                        # render every source
uv run tools/audio/render.py sfx_taint_heartbeat    # render only these sound ids
uv run tools/audio/render.py --spectrogram          # also save a spectrogram PNG per sound
uv run tools/audio/render.py --peak -6              # normalize peaks to -6 dBFS instead of -1
```

Each sound is rendered at 48 kHz and 16 bits, then peak-normalized by SoX and checked. It fails if
SuperCollider reports an error, if no file comes out, if the result is silent (peak below
-60 dBFS) or if any sample clips. The report shows length, channels, peak and RMS.

Raw renders, SuperCollider's output and spectrograms go to `logs/audio/render_<timestamp>/`
(gitignored). The exit code is 0 when every sound passed and 1 otherwise.

## Writing a source

A source is `assets/audio/src/<sound_id>.scd`, with the id named per CONTRACTS section 3
(`<bus>_<name>[_<variant>]`). Its last expression is an Event:

| Key | Meaning |
|---|---|
| `channels` | 1 for sounds placed in 3D, 2 only for non-positional beds and UI. Default 1 |
| `duration` | File length in seconds. For a loop, make it an exact number of periods |
| `defs` | Array of `SynthDef`s |
| `events` | Array of `[time, [OSC command]]` in time order, such as `[0.5, [\s_new, \thump, -1, 0, 0, \freq, 50]]` |

`sfx_taint_heartbeat.scd` is the worked example. Synths should free themselves (`doneAction: 2`).
`render_nrt.scd` is the driver that turns the Event into a non-real-time score.

## Checking a sound without listening

Claude agents can't hear. They check what can be measured: length, peak, RMS and the spectrogram
(time across, pitch up, loudness as brightness). That catches wrong timing, clicks at a loop point,
energy in the wrong range and tails that run past the end. Whether a sound is right is decided by
ear, so every handoff lists the new and changed sounds for the CEO to listen to.
