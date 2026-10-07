extends Node
## Doc 05 section 5: day, phase, time. The host advances `t_phase` and sends `apply_clock` on each
## phase change and every 5 s; clients advance by delta and snap to the host value, never decide a
## phase change. Lengths from season.json (doc 02 section 3); --phase1 uses phase1.json night_s.
## The `apply_clock` RPC is on `Net`, which calls `apply_clock` here. The Harvest Moon (final night)
## is not built in Phase 1.

signal phase_changed(phase: StringName)
signal day_changed(day: int)

const DAWN_S := 10.0  ## placeholder: dawn is a pipeline step, not a timed phase, in doc 02 section 9
const SYNC_EVERY_S := 5.0  ## doc 06 section 7

var day := 1
var phase: StringName = &"day"
var t_phase := 0.0
var running := false  ## host: ticking; client: set by the first apply_clock
var _since_sync := 0.0


func length_of(p: StringName) -> float:
	match p:
		&"day": return float(Data.value(&"season", &"day_s"))
		&"dusk": return float(Data.value(&"season", &"dusk_s"))
		&"night":
			if Data.phase1:
				return float(Data.value(&"phase1", &"night_s", &"seconds"))
			return float(Data.value(&"season", &"night_s"))
		&"harvest_moon": return float(Data.value(&"season", &"harvest_moon_cap_s"))
	return DAWN_S


## Host only.
func start() -> void:
	day = 1
	phase = &"day"
	t_phase = 0.0
	running = true
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
			phase = &"day"
			day += 1
			day_changed.emit(day)
			Log.event(&"day_start", {"day": day, "phase": phase})
	phase_changed.emit(phase)
	Log.event(&"phase_changed", {"day": day, "phase": phase})
	_broadcast()


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
