# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Self-test for tools/qa/grep_rules.py on a temp tree. Needs no Godot.

    uv run tests/qa/test_grep_rules.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "qa"))

import grep_rules  # noqa: E402


def _tree(files: dict[str, str]) -> Path:
    root = Path(tempfile.mkdtemp())
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8", newline="\n")
    subprocess.run(["git", "-C", str(root), "add", "-A", "-f"], check=True)
    return root


def _run(files: dict[str, str]) -> int:
    return grep_rules.run(_tree(files))


class GrepRules(unittest.TestCase):
    def test_clean_tree_passes(self) -> None:
        self.assertEqual(_run({
            "game/ghost/light_flicker.gd": "func flicker(): energy_override(1)",
            "game/render/light_rig.gd": "func energy_override(): light_energy = 1",
            "game/net/net.gd": "func request_flicker(): rpc_id(1)\nx.rpc_id(1)",
            "assets/audio/a.wav": "x",
        }), 0)

    def test_no_game_folder_passes(self) -> None:
        self.assertEqual(_run({"README.md": "x"}), 0)

    def test_flicker_elsewhere_fails(self) -> None:
        self.assertEqual(_run({"game/world/lamp.gd": "# it flickers\n"}), 1)
        self.assertEqual(_run({"game/net/net.gd": "func apply_flicker(): pass # flicker\n"}), 1)
        self.assertEqual(_run({"game/ui/hud.gd": "Net.request_flicker(id)\n"}), 1)

    def test_energy_override_elsewhere_fails(self) -> None:
        self.assertEqual(_run({"game/core/lights.gd": "rig.energy_override(0, 1)"}), 1)

    def test_light_energy_script_fails_scene_warns(self) -> None:
        self.assertEqual(_run({"game/world/a.gd": "l.light_energy = 2"}), 1)
        self.assertEqual(_run({"game/world/a.tscn": "light_energy = 2.0"}), 0)

    def test_rpc_outside_net_fails(self) -> None:
        self.assertEqual(_run({"game/player/p.gd": "foo.rpc_id(1, x)"}), 1)
        # Q-039 item 1: bare calls on self and @rpc annotations count too.
        self.assertEqual(_run({"game/player/p.gd": "\trpc_id(1, x)"}), 1)
        self.assertEqual(_run({"game/player/p.gd": "\trpc(x)"}), 1)
        self.assertEqual(_run({"game/player/p.gd": '@rpc("any_peer")\nfunc f(): pass'}), 1)
        self.assertEqual(_run({"game/player/p.gd": "  @rpc\nfunc f(): pass"}), 1)
        # Names that only contain the word are not calls.
        self.assertEqual(_run({"game/player/p.gd": "send_rpc_id(1)\nrpc_config(&\"f\", {})"}), 0)

    def test_voice_files_fail(self) -> None:
        self.assertEqual(_run({"spikes/a.wav": "x"}), 1)  # Q-039 item 2: no spikes/ exception
        self.assertEqual(_run({"spikes/voice/take.ogg": "x"}), 1)
        self.assertEqual(_run({"assets/audio/line.vclip": "x"}), 1)


if __name__ == "__main__":
    unittest.main()
