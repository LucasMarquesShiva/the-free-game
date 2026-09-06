extends SceneTree

const Clock = preload("res://core/simulation_clock.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_elapsed_time()
	_test_frame_partition()
	_test_pause()
	_test_backlog()
	_test_clock_restore()
	_test_invalid_restore()
	if failures.is_empty():
		print("PASS: ", checks, " verificacoes da base; nao representam aprovacao dos prototipos CIV/MIL.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _test_elapsed_time() -> void:
	var clock := Clock.new()
	_expect(clock.advance_usec(70000) == 0, "partial step does not advance simulation")
	_expect(clock.advance_usec(30000) == 1 and clock.tick == 1 and clock.pending_usec == 0, "partial intervals complete exactly one step")
	var before: Dictionary = clock.capture()
	_expect(clock.advance_usec(-1) == 0 and clock.capture() == before, "negative elapsed time cannot rewind state")


func _test_frame_partition() -> void:
	var first := Clock.new()
	var second := Clock.new()
	first.advance_usec(750000)
	for interval in [16000, 17000, 23000, 194000, 100000, 400000]:
		second.advance_usec(interval)
	_expect(first.capture() == second.capture(), "same elapsed time with different frame partitions gives same clock")


func _test_pause() -> void:
	var clock := Clock.new()
	clock.advance_usec(70000)
	clock.paused = true
	var before: Dictionary = clock.capture()
	_expect(clock.advance_usec(5000000) == 0 and clock.capture() == before, "paused time does not accumulate for a return burst")
	clock.paused = false
	_expect(clock.advance_usec(30000) == 1 and clock.tick == 1, "resume preserves the partial step from before pause")


func _test_backlog() -> void:
	var clock := Clock.new()
	_expect(clock.advance_usec(2050000) == 8, "frame work is bounded")
	_expect(clock.pending_usec == 1250000, "overload retains time instead of silently dropping it")
	_expect(clock.advance_usec(0) == 8 and clock.advance_usec(0) == 4, "backlog can drain across later frames")
	_expect(clock.tick == 20 and clock.pending_usec == 50000, "backlog conserves the complete elapsed time")


func _test_clock_restore() -> void:
	var original := Clock.new()
	original.advance_usec(550000)
	var restored := Clock.new()
	var decoded: Variant = JSON.parse_string(JSON.stringify(original.capture()))
	_expect(restored.restore(decoded) == OK, "JSON round trip restores clock record")
	original.advance_usec(550000)
	restored.advance_usec(550000)
	_expect(original.capture() == restored.capture(), "restored clock advances identically to uninterrupted clock")


func _test_invalid_restore() -> void:
	var clock := Clock.new()
	clock.advance_usec(350000)
	var before: Dictionary = clock.capture()
	var invalid_records: Array[Dictionary] = [
		{},
		{"schema_version": 2, "step_usec": 100000, "tick": 1, "pending_usec": 0, "paused": false},
		{"schema_version": 1, "step_usec": 100000, "tick": -1, "pending_usec": 0, "paused": false},
		{"schema_version": 1, "step_usec": 100000, "tick": 1.5, "pending_usec": 0, "paused": false},
		{"schema_version": 1, "step_usec": 200000, "tick": 1, "pending_usec": 0, "paused": false},
		{"schema_version": 1, "step_usec": 100000, "tick": 1, "pending_usec": 0, "paused": "false"},
		{"schema_version": 1, "step_usec": 100000, "tick": true, "pending_usec": 0, "paused": false},
		{"schema_version": 1, "step_usec": 100000, "tick": 1, "pending_usec": INF, "paused": false},
	]
	for record in invalid_records:
		_expect(clock.restore(record) == ERR_INVALID_DATA and clock.capture() == before, "invalid clock record rejected atomically: " + str(record))

