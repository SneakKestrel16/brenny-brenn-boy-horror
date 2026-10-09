extends Node
## P4-07 (doc 02 s7, doc 01 "Debt and payments"): the host owns the debt; every peer mirrors the few flags the
## farm shows (pumpkin seeds on sale, early-payment verb). Child of Death, in group `debt`. Numbers: debt.json,
## player_scaling.json `payment_pct_by_players` (D-079), season.json (`first_payment_dawn`, `bank_floor`,
## `foreclosure_*`), difficulty.json `short_season` (D-082). Dawn "n" is the one before day n, so the dawn that
## follows day `Clock.day` is dawn `Clock.day + 1`.

const Plot := preload("res://game/farming/plot.gd")
const EARLY_STEP := 50  ## placeholder: coins one `pay_early` hold pays (doc 01 gives no amount; Q-108)

## Mirrored on every peer. `Crops.first_paid` reads it (replaces the day-based stand-in, Q-088).
static var first_made := false

var foreclosed := false
var lost := false  ## the final payment was missed
var paid := 0  ## total paid so far, early payments included
var penalty := 0  ## Foreclosure penalty, added to the final payment, never rescaled
var owed := 0  ## mirrored: still owed on the current headcount
var first_due := 0  ## locked at the first-payment dawn
var _pcts: Array[int] = []  ## host: the headcount pct fixed at each dawn that has begun (dawn 1 first)


# ---- pure rules (tests call these) ----

static func rhu(a: int, b: int) -> int:
	return (2 * a + b) / (2 * b)


static func days() -> int:
	return int(Data.value(&"season", &"season_days"))


static func short_season() -> bool:
	return days() < 7


static func pct_for(players: int) -> int:  # clamped like traps and sabotage: no solo play (doc 01 "One player left")
	var heads := clampi(players, 2, Game.max_players())
	return int(Data.record(&"player_scaling", &"headcount").get("payment_pct_by_players", {}).get(str(heads), 100))


## Total debt: recorded days at their pct, the rest at `cur` (doc 02 s7.2). Short season: difficulty.json base.
static func total_for(pcts: Array, cur: int, players: int) -> int:
	var base := int(Data.record(&"debt", &"season").total_4p)
	if short_season():
		var s: Dictionary = Data.record(&"difficulty", &"short_season")
		base = int(s.get("debt_total_4p_by_players", {}).get(str(players), s.debt_total_4p))
	var n := days()
	var sum := 0
	for p in pcts.slice(0, n):
		sum += int(p)
	return rhu(base * (sum + maxi(n - pcts.size(), 0) * cur), n * 100)


## First payment of `total`; 0 in the short season (one payment, at the end).
static func first_of(total: int) -> int:
	if short_season():
		return 0
	var d: Dictionary = Data.record(&"debt", &"season")
	return rhu(int(d.first_payment_4p) * total, int(d.total_4p))


static func penalty_for(shortfall: int) -> int:
	return (int(Data.value(&"season", &"foreclosure_penalty_pct")) * shortfall + 99) / 100  # ceil, placeholder


# ---- lifecycle ----

func _ready() -> void:
	add_to_group(&"debt")
	first_made = false
	Net.apply_received.connect(_on_apply)
	if not Game.is_host():
		return
	if Save.pending.is_empty():  # a loaded season brings its own record (Save.apply_pending)
		_pcts.append(pct_for(Game.player_count()))  # dawn 1 starts the season
	# P4-10 (doc 02 s4): a join or leave changes what is still owed at once; the pct locked for each dawn stays.
	Game.player_joined.connect(func(_p: int) -> void: _headcount_changed())
	Game.player_left.connect(func(_p: int) -> void: _headcount_changed())
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":
			Net.to_peers(&"apply_debt", _wire(), [peer]))
	_refresh_owed.call_deferred()  # the Farm is a sibling that may not be in the tree yet


func _wire() -> Array:
	return [first_made, foreclosed, lost, owed, paid]


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"debt":
		first_made = bool(args[0])
		foreclosed = bool(args[1])
		lost = bool(args[2])
		owed = int(args[3])
		paid = int(args[4])


func _send() -> void:
	Net.to_peers(&"apply_debt", _wire())
	Net.apply_received.emit(&"debt", _wire())


func _farm() -> Node:
	return get_tree().get_first_node_in_group(&"farm")


func _headcount_changed() -> void:
	if _farm() == null:
		return
	_refresh_owed()
	_send()
	Log.event(&"debt_rescaled", {"players": Game.player_count(), "owed": owed, "pct": pct_for(Game.player_count())})


## Host: what is still owed if the headcount stays as it is now.
func _refresh_owed() -> void:
	var total := total_for(_pcts, pct_for(Game.player_count()), Game.player_count())
	var farm := _farm()
	owed = maxi(total - paid + penalty + (farm.final_extra if farm else 0), 0)


# ---- early payment ----

## Host: why `pay_early` cannot start, "" if it can.
func early_blocked() -> StringName:
	if lost:
		return &"season_lost"
	var farm := _farm()
	if farm == null or farm.coins - int(Data.value(&"season", &"bank_floor")) <= 0:
		return &"no_coins"
	_refresh_owed()
	return &"" if owed > 0 else &"nothing_owed"


## Host: pay up to EARLY_STEP coins now (doc 01: allowed at any dawn; here whenever the host is asked, Q-108).
## It fills the first payment, then the final (debt.json `early_order`).
func pay_early(peer: int) -> int:
	if early_blocked() != &"":
		return 0
	var farm := _farm()
	var n := mini(EARLY_STEP, mini(farm.coins - int(Data.value(&"season", &"bank_floor")), owed))
	farm.add_coins(-n, &"payment", peer)
	paid += n
	_refresh_owed()
	Log.event(&"payment_made", {"amount": n, "balance": farm.coins, "due": owed, "late": false, "early": true, "player": peer})
	_send()
	return n


# ---- dawn step 4 ----

## Host: dawn step 4 (doc 02 s9). Records the headcount, then takes the first payment (the first-payment dawn)
## or the final one (the last dawn).
func dawn_payment(farm: Node, final: bool) -> void:
	var dawn_no: int = Clock.day + 1
	var players := Game.player_count()
	if dawn_no <= days():
		_pcts.append(pct_for(players))
	var total := total_for(_pcts, pct_for(players), players)
	var floor_c := int(Data.value(&"season", &"bank_floor"))
	if final:
		var due := maxi(total - paid + penalty + farm.final_extra, 0)
		var ok: bool = farm.coins >= due
		if ok and due > 0:
			farm.add_coins(-due, &"payment", 0)
			paid += due
		lost = not ok
		Log.event(&"payment_made", {"amount": due if ok else 0, "balance": farm.coins, "due": due, "late": false, "final": true,
				"ok": ok, "players": players})
		if lost:
			Log.event(&"season_lost", {"reason": "final_payment", "day": Clock.day, "short": due - farm.coins})
	elif not short_season() and dawn_no == int(Data.value(&"season", &"first_payment_dawn")):
		first_due = first_of(total)
		var need := maxi(first_due - paid, 0)  # early payments count first (debt.json `early_order`)
		var take := mini(need, maxi(farm.coins - floor_c, 0))  # partial payment: every coin down to the floor (doc 02 s7.4)
		if take > 0:
			farm.add_coins(-take, &"payment", 0)
			paid += take
		var short := need - take
		first_made = short == 0
		if not first_made:
			foreclosed = true
			penalty += penalty_for(short)
			var seized := foreclose()
			Log.event(&"foreclosure", {"shortfall": short, "penalty": penalty, "seized": seized, "day": Clock.day})
		Log.event(&"payment_made", {"amount": take, "balance": farm.coins, "due": first_due, "late": not first_made, "final": false,
				"ok": first_made, "players": players})
	_refresh_owed()
	_send()


## Host: the bank seizes one upgrade or 2 plots (doc 01 "Debt and payments"), by season.json
## `foreclosure_seizure_order`: the dearest upgrade if it cost more than 2 plots (the `plot_pair` price),
## else a bought plot pair, else 2 starting plots. Needs the P4-06 store; without it only starting plots go.
func foreclose() -> String:
	var store := get_tree().get_first_node_in_group(&"store")
	if store and store.has_method(&"seizable") and store.has_method(&"seize"):
		var pair_cost := int(Data.record(&"store", &"plot_pair").get("price", 0))
		var best: StringName = &""
		var best_price := 0
		for id: StringName in store.seizable():
			var price := int(Data.record(&"store", id).get("price", 0))
			if id != &"plot_pair" and price > best_price:
				best = id
				best_price = price
		if best != &"" and best_price > pair_cost:
			store.seize(best)
			return String(best)
		if store.seizable().has(&"plot_pair"):
			store.seize(&"plot_pair")
			return "plot_pair"
	var n := 0
	var farm := _farm()
	var plots: Array = []
	for t in farm.targets.values():
		if t is Plot and not t.locked and not t.bed:
			plots.append(t)
	plots.reverse()
	for t in plots:
		if n >= int(Data.value(&"season", &"foreclosure_seized_plots")):
			break
		t._reset()
		t.locked = true
		t._refresh()
		farm.plot_changed(t)
		n += 1
	return "starting_plots:%d" % n
