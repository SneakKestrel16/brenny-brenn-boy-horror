# Work in progress

Unfinished task diffs saved when the CEO paused work. Each patch applies to `main` with
`git apply production/wip/<task>.patch`. Delete the patch once its task is merged.

| Patch | Task | State when paused (2026-10-11) | Worktree kept at |
|---|---|---|---|
| [P5-73.patch](P5-73.patch) | Pen fence and well in creature pathfinding; P5-72 regression | Code, tests and doc 03 started; not run to the end, no QA, no handoff | `.claude/worktrees/agent-abc1ef922343936e3` |
| [P5-75.patch](P5-75.patch) | D-190 gate-run chase speed and bot fixes | Data key, bot.gd, test started; creature.gd edit mid-way, no A/B, no QA | `.claude/worktrees/agent-aba6de6ddca9219e2` |

Both patches touch `game/creature/creature.gd`; merge one, then 3-way the other.
