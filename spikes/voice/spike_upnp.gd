extends RefCounted
## UPnP port opening, doc 06 section 3 "Host flow". discover() blocks for seconds, so it runs on a
## thread; the result comes back through `finished` on the main thread (call_deferred).
## Spike code (DECISIONS D-004).

signal finished(result: Dictionary)

const JoinCode := preload("res://spikes/voice/join_code.gd")
## Doc 06 section 3 (placeholders): 2-hour lease; ports 45120..45124 on a conflict.
const LEASE_S := 7200
const MAPPING_NAME := "Brenny voice spike"
const EXTRA_PORTS := 4

var _thread: Thread
var _upnp: UPNP
var _mapped_external := 0


func start(internal_port: int) -> void:
	_thread = Thread.new()
	_thread.start(_run.bind(internal_port))


func _run(internal_port: int) -> void:
	var t0 := Time.get_ticks_msec()
	var r := {"result": "", "result_code": -1, "external_port": 0, "external_address": "",
			"external_address_class": "unknown", "gateway_lan_address": "", "lease_s": LEASE_S}
	_upnp = UPNP.new()
	var err := _upnp.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		r["result"] = _name(err)
		r["result_code"] = err
	elif _upnp.get_device_count() == 0:
		r["result"] = "no_devices"  # discover() can return success with nothing found
		r["result_code"] = UPNP.UPNP_RESULT_NO_DEVICES
	elif _upnp.get_gateway() == null or not _upnp.get_gateway().is_valid_gateway():
		r["result"] = "no_valid_gateway"
		r["result_code"] = UPNP.UPNP_RESULT_NO_GATEWAY
	else:
		r["gateway_lan_address"] = _upnp.get_gateway().our_addr
		var lease := LEASE_S
		for ext in range(internal_port, internal_port + EXTRA_PORTS + 1):
			err = _upnp.add_port_mapping(ext, internal_port, MAPPING_NAME, "UDP", lease)
			if err == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
				lease = 0
				err = _upnp.add_port_mapping(ext, internal_port, MAPPING_NAME, "UDP", 0)
			if err == UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING:
				continue
			if err == UPNP.UPNP_RESULT_SUCCESS:
				_mapped_external = ext
				r["external_port"] = ext
			break
		r["lease_s"] = lease
		r["result"] = _name(err)
		r["result_code"] = err
		var ext_ip := _upnp.query_external_address()
		r["external_address"] = ext_ip
		r["external_address_class"] = JoinCode.classify(ext_ip) if ext_ip != "" else "unknown"
	r["seconds"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.01)
	finished.emit.call_deferred(r)


## Called on quit (doc 06 section 3 step 5). Blocks briefly; a crash leaves the lease to expire.
func cleanup() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	if _upnp and _mapped_external > 0:
		var err := _upnp.delete_port_mapping(_mapped_external, "UDP")
		print("voice spike: UPnP mapping %d removed: %s" % [_mapped_external, _name(err)])
		_mapped_external = 0


static func _name(code: int) -> String:
	match code:
		UPNP.UPNP_RESULT_SUCCESS: return "success"
		UPNP.UPNP_RESULT_NOT_AUTHORIZED: return "not_authorized"
		UPNP.UPNP_RESULT_PORT_MAPPING_NOT_FOUND: return "port_mapping_not_found"
		UPNP.UPNP_RESULT_INCONSISTENT_PARAMETERS: return "inconsistent_parameters"
		UPNP.UPNP_RESULT_NO_SUCH_ENTRY_IN_ARRAY: return "no_such_entry_in_array"
		UPNP.UPNP_RESULT_ACTION_FAILED: return "action_failed"
		UPNP.UPNP_RESULT_SRC_IP_WILDCARD_NOT_PERMITTED: return "src_ip_wildcard_not_permitted"
		UPNP.UPNP_RESULT_EXT_PORT_WILDCARD_NOT_PERMITTED: return "ext_port_wildcard_not_permitted"
		UPNP.UPNP_RESULT_INT_PORT_WILDCARD_NOT_PERMITTED: return "int_port_wildcard_not_permitted"
		UPNP.UPNP_RESULT_REMOTE_HOST_MUST_BE_WILDCARD: return "remote_host_must_be_wildcard"
		UPNP.UPNP_RESULT_EXT_PORT_MUST_BE_WILDCARD: return "ext_port_must_be_wildcard"
		UPNP.UPNP_RESULT_NO_PORT_MAPS_AVAILABLE: return "no_port_maps_available"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM: return "conflict_with_other_mechanism"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING: return "conflict_with_other_mapping"
		UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED: return "only_permanent_lease_supported"
		UPNP.UPNP_RESULT_INVALID_GATEWAY: return "invalid_gateway"
		UPNP.UPNP_RESULT_INVALID_PORT: return "invalid_port"
		UPNP.UPNP_RESULT_INVALID_PROTOCOL: return "invalid_protocol"
		UPNP.UPNP_RESULT_INVALID_DURATION: return "invalid_duration"
		UPNP.UPNP_RESULT_INVALID_ARGS: return "invalid_args"
		UPNP.UPNP_RESULT_INVALID_RESPONSE: return "invalid_response"
		UPNP.UPNP_RESULT_INVALID_PARAM: return "invalid_param"
		UPNP.UPNP_RESULT_HTTP_ERROR: return "http_error"
		UPNP.UPNP_RESULT_SOCKET_ERROR: return "socket_error"
		UPNP.UPNP_RESULT_MEM_ALLOC_ERROR: return "mem_alloc_error"
		UPNP.UPNP_RESULT_NO_GATEWAY: return "no_gateway"
		UPNP.UPNP_RESULT_NO_DEVICES: return "no_devices"
		UPNP.UPNP_RESULT_UNKNOWN_ERROR: return "unknown_error"
	return "code_%d" % code
