extends SceneTree
## Run headless with -- --save=/absolute/path/to/save.json --ticks=120.
## Reads a copy into memory; never writes the save or advances the real game.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := ""
	var ticks := 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
		if argument.begins_with("--ticks="): ticks = int(argument.trim_prefix("--ticks="))
	if path.is_empty() or ticks < 1 or not FileAccess.file_exists(path):
		printerr("Provide --save=/path/to/save.json and --ticks=positive_integer")
		quit(1);return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var sim = load("res://simulation/approved_sim.gd").new()
	sim.setup()
	if not data is Dictionary or not data.get("simulation") is Dictionary or not sim.restore(data.simulation):
		printerr("Invalid approved-game save")
		quit(1);return
	sim.paused = false
	var samples: Array[float] = []
	for i in range(ticks):
		var start := Time.get_ticks_usec()
		sim.step()
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	var errors: Array = sim.conservation_errors()
	print("SAVED_SIM_BENCHMARK ", JSON.stringify({"ticks":ticks,"workers":sim.workers.size(),"roads":sim.roads.size(),"median_ms":samples[ticks/2],"p95_ms":samples[mini(ticks-1,int(ticks*0.95))],"max_ms":samples.back(),"conservation_errors":errors,"scope":"CPU simulation only; not rendered FPS"}))
	quit(0 if errors.is_empty() else 1)
