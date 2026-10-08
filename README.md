# Brenny Brenn Boy Horror

A 2 to 4 player online co-op farming horror game: farm by day, survive the creature in the corn by
night. Built in Godot 4. The design doc, [docs/01_design_doc.md](docs/01_design_doc.md), is the
source of truth.

## Play

Download and install: [docs/10_install_and_updates.md](docs/10_install_and_updates.md). The game updates itself from GitHub releases when you start it with `Host.bat` or `Join.bat`.

## Open the project

1. Install **Godot 4.7.2** (standard build, not .NET). On this machine it came from winget:
   `winget install GodotEngine.GodotEngine`, which puts `Godot_v4.7.2-stable_win64.exe` under
   `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`.
2. Start Godot, choose **Import**, and select `project.godot` in this folder.

Headless check (Git Bash, using the `_console` build so output reaches the terminal):

```sh
"$GODOT" --headless --version
"$GODOT" --headless --editor --quit --path .   # import and open the project without a window
```

## Run 2 to 4 local instances

1. In the editor, open **Debug > Customize Run Instances...**
2. Tick **Enable Multiple Instances** and set the count to 2, 3 or 4.
3. Give each instance its own launch arguments if needed (for example `--host` on the first and
   `--join 127.0.0.1` on the rest, once the networking task defines them; see
   [docs/06](docs/README.md)).
4. Press **Run** (F5). Each instance opens its own window and connects over local ENet.

## Where things live

| Path | What |
|---|---|
| `docs/` | Design docs 01 to 09. Start at [docs/README.md](docs/README.md). |
| `production/` | Task board, contracts, decisions, questions, open issues and task handoffs. Start at [production/README.md](production/README.md). |
| `.claude/agents/` | Role definitions for the agent team. |
| `game/`, `data/`, `assets/` | Game code, game data and art (layout and owners in [production/CONTRACTS.md](production/CONTRACTS.md)). |
| `tools/` | Season simulator, Blender scripts, QA scripts. |
| `spikes/` | Throwaway technical spikes (the voice spike first). |
