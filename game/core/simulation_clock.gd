class_name SimulationClock
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_STEPS_PER_ADVANCE := 8
const MAX_SAFE_INTEGER := 9007199254740991

var step_usec: int
var tick := 0
var pending_usec := 0
var paused := false

func _init(fixed_step_usec: int = 100000) -> void:
	assert(fixed_step_usec > 0)
	step_usec = fixed_step_usec


func advance_usec(elapsed_usec: int) -> int:
	if paused or elapsed_usec < 0:
		return 0
	if elapsed_usec > MAX_SAFE_INTEGER - pending_usec:
		return 0
	pending_usec += elapsed_usec
	var due: int = mini(pending_usec / step_usec, MAX_STEPS_PER_ADVANCE)
	if due > MAX_SAFE_INTEGER - tick:
		pending_usec -= elapsed_usec
		return 0
	pending_usec -= due * step_usec
	tick += due
	return due


func capture() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"step_usec": step_usec,
		"tick": tick,
		"pending_usec": pending_usec,
		"paused": paused,
	}


func restore(state: Dictionary) -> Error:
	if state.get("schema_version") != SCHEMA_VERSION:
		return ERR_INVALID_DATA
	for key in ["step_usec", "tick", "pending_usec"]:
		if not _is_safe_unsigned_integer(state.get(key)):
			return ERR_INVALID_DATA
	if int(state["step_usec"]) != step_usec:
		return ERR_INVALID_DATA
	if typeof(state.get("paused")) != TYPE_BOOL:
		return ERR_INVALID_DATA
	# Apply only after the entire record is validated.
	tick = int(state["tick"])
	pending_usec = int(state["pending_usec"])
	paused = bool(state["paused"])
	return OK


func _is_safe_unsigned_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value <= MAX_SAFE_INTEGER
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= 0.0 and value <= MAX_SAFE_INTEGER and value == floor(value)
	return false

