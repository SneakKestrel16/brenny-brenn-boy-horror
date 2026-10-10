class_name DevGate
extends RefCounted
## D-044 (doc 01 "Hidden dev setting", "Dev toys"): the machine-hash gate. Open only when the SHA-256 of this
## machine's `OS.get_unique_id()` is in `HASHES`. `--dev` and debug builds do not open it. Only hashes are stored
## here, never a raw machine id. P5-10 (dev toys) uses it; P5-11 (the imposter dev setting) reuses `unlocked()`.
##
## The CEO prints their hash with (Git Bash, repo root; the hash is the last line):
##   "$GODOT" --headless --path . -s res://game/core/print_machine_hash.gd | tail -1
## and gives it to the Director, who pastes it into `HASHES` (QUESTIONS Q-261).
##
## Test path (automated tests): in a debug build only, `--dev-gate-test-hash=<hash>` adds one hash to the
## list. A test passes the hash printed by the script above for its own machine, so the real compare runs.
## Inference: anyone who can run that script can open the gate on their own PC in a debug build, so this is a
## guard against accidents and stray `--dev` runs, not against someone with the repo. What would settle it:
## the CEO asking for a secret (a salt kept outside the repo).

const HASHES: PackedStringArray = ["ec07b347a582a4161c1403d3194a621636f1ac43daffd3138db8aaf8a01a886a"]  ## the CEO's machine hashes, lowercase hex (Q-261, D-163)
const TEST_ARG := "--dev-gate-test-hash="


## SHA-256 of this machine's id, lowercase hex.
static func machine_hash() -> String:
	return OS.get_unique_id().sha256_text()


## True when this machine may use the hidden dev features. Call it on the host only (the host's machine decides).
static func unlocked() -> bool:
	var h := machine_hash()
	if h in HASHES:
		return true
	if OS.is_debug_build():
		for a in OS.get_cmdline_user_args():
			if a.begins_with(TEST_ARG) and a.substr(TEST_ARG.length()).to_lower() == h:
				return true
	return false
