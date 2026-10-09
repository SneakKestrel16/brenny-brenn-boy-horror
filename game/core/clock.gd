extends Node
## Doc 05 section 5: day, phase, time. The host advances `t_phase` and sends `apply_clock` on each
## phase change and every 5 s; clients advance by delta and snap to the host value, never decide a
## phase change. Lengths from season.json (doc 02 section 3); --phase1 uses phase1.json night_s.
## The `apply_clock` RPC is on `Net`, which calls `apply_clock` here. The Harvest Moon (final night)
## is not built in Phase 1.
## Playtest pacing (D-030): `--day-s=<n>`, `--dusk-s=<n>`, `--night-s=<n>` replace a phase's length in
## seconds. The host's values decide phase changes; a client with other values only shows a wrong
## countdown, so Host.bat and Join.bat pass the same ones.

signal phase_changed(phase: StringName)
signal day_changed(day: int)
signal season_ended  ## after the final dawn (P4-04)

const DAWN_S := 10.0  ## placeholder: dawn is a pipeline step, not a timed phase, in doc 02 section 9
const SYNC_EVERY_S := 5.0  ## doc 06 section 7

var day := 1
var phase: StringName = &"day"
var t_phase := 0.0
var running := false  ## host: ticking; client: set by the first apply_clock
var season_over := false  ## the final dawn has finished (`start` clears it)
var _since_sync := 0.0
var _override: Dictionary = {}  ## phase -> seconds, from the command line (D-030)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		for p in [&"day", &"dusk", &"night"]:
			var key := "--%s-s=" % p
			if a.begins_with(key) and a.substr(key.length()).is_valid_float():
				var s := a.substr(key.length()).to_float()
				if s > 0.0:
					_override[p] = s


func length_of(p: StringName) -> float:
	if _override.has(p):
		return float(_override[p])
	match p:
		&"day": return float(Data.value(&"season", &"day_s"))
		&"dusk": return float(Data.value(&"season", &"dusk_s"))
		&"night":
			if Data.phase1:
				return float(Data.value(&"phase1", &"night_s", &"seconds"))
			return float(Data.value(&"season", &"night_s"))
		&"harvest_moon": return float(Data.value(&"season", &"harvest_moon_cap_s"))
	return DAWN_S


## Host only: dev console `length` (D-031). Same effect as the command-line override.
func set_length(p: StringName, seconds: float) -> void:
	_override[p] = seconds


## Host only: dev console `phase` (D-031). Ends the current phase now, as its timer would.
func dev_advance() -> void:
	_advance()


## Host only. A loaded save resumes at its dawn (P4-10): `start(day, &"dawn")`; the dawn then runs out and day + 1 begins.
func start(p_day: int = 1, p_phase: StringName = &"day") -> void:
	day = p_day
	phase = p_phase
	t_phase = 0.0
	season_over = false
	running = true
	if not _override.is_empty():
		Log.event(&"clock_override", {"day_s": length_of(&"day"), "dusk_s": length_of(&"dusk"), "night_s": length_of(&"night")})
	_broadcast()


func stop() -> void:
	running = false


func _physics_process(delta: float) -> void:
	if not running:
		return
	t_phase += delta
	if not Game.is_host():
		return
	if t_phase >= length_of(phase):
		_advance()
		return
	_since_sync += delta
	if _since_sync >= SYNC_EVERY_S:
		_broadcast()


func _advance() -> void:
	t_phase = 0.0
	match phase:
		&"day": phase = &"dusk"
		&"dusk": phase = &"night"
		&"night": phase = &"dawn"
		_:
			if day >= int(Data.value(&"season", &"season_days")):  # the season ends after the final dawn (doc 02 s3)
				end_season()
				return
			phase = &"day"
			day += 1
			day_changed.emit(day)
			Log.event(&"day_start", {"day": day, "phase": phase})
	phase_changed.emit(phase)
	Log.event(&"phase_changed", {"day": day, "phase": phase})
	_broadcast()


## The final dawn is over: the clock stops on the last day's dawn. Host: from `_advance`. Client: from the
## final Dawn Report (`apply_clock` has no season flag, Q-085). The Season Awards screen listens (not built).
func end_season() -> void:
	if season_over:
		return
	season_over = true
	running = false
	Log.event(&"season_ended", {"day": day})
	season_ended.emit()


func _broadcast() -> void:
	_since_sync = 0.0
	Net.to_peers(&"apply_clock", [day, phase, t_phase])


## Client: from `Net.apply_clock`.
func apply_clock(p_day: int, p_phase: StringName, t: float) -> void:
	running = true
	t_phase = t
	if p_day != day:
		day = p_day
		day_changed.emit(day)
	if p_phase != phase:
		phase = p_phase
		phase_changed.emit(phase)
