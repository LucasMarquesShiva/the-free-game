extends SceneTree
## Reproducible full-scene benchmark. Production scripts are never modified.
## Legal setup is accelerated before sampling; all measured ticks run in game._process.
const CLOCK = preload("res://core/simulation_clock.gd")
var game: Node
var sim: RefCounted
var output_dir := "user://vale-performance-results"
var run_label := "auto"
var warmup_seconds := 6.0
var sample_seconds := 20.0
var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func argument_value(name: String, fallback: String) -> String:
	for item in OS.get_cmdline_user_args():
		if item.begins_with(name + "="):
			return item.substr(name.length() + 1)
	return fallback

func fail(message: String) -> void:
	push_error("BENCHMARK_FAILED: " + message)
	quit(1)

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Cannot write benchmark result " + path)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func statistics(values: Array, zero_means_unavailable: bool = false) -> Variant:
	if values.is_empty():
		return null
	var sorted := values.duplicate()
	sorted.sort()
	if zero_means_unavailable and float(sorted.back()) <= 0.0:
		return null
	var total := 0.0
	for value in values:
		total += float(value)
	return {"mean":total/values.size(), "p50":sorted[ceili(values.size()*0.5)-1],
		"p95":sorted[ceili(values.size()*0.95)-1], "min":sorted[0], "max":sorted.back()}

func run() -> void:
	output_dir = argument_value("--output", output_dir)
	run_label = argument_value("--label", RenderingServer.get_current_rendering_method())
	warmup_seconds = float(argument_value("--warmup", "6"))
	sample_seconds = float(argument_value("--seconds", "20"))
	assert(warmup_seconds >= 0.0 and sample_seconds > 0.0)
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1600, 1000)
	root.title = "Vale 0.4 — benchmark " + run_label
	game = load("res://scenes/approved.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	sim = game.sim
	game.hud._dismiss_tutorial()
	game.hud._toast.hide()
	# Same legal orders and setup sequence as render_approved_mission.gd.
	var connection: Array[Vector2i] = []
	for x in range(8, 14):
		connection.append(Vector2i(x, 13))
	assert(sim.command("road", {"cells":connection}).ok)
	for i in range(90):
		sim.step()
	build_mission()
	for i in range(1600):
		sim.step()
	for i in range(12000):
		sim.step()
		if sim.won:
			break
	assert(sim.won and sim.workers.size() == 25, "Expected finished legal mission with 25 civilians")
	assert(sim.conservation_errors().is_empty(), "Legal baseline conservation failed")
	var baseline: Dictionary = sim.snapshot().duplicate(true)
	write_json(output_dir + "/fixture-" + run_label + ".json", baseline)
	var completed := 0
	for building in sim.buildings:
		if building.stage == "complete":
			completed += 1
	results = {"label":run_label, "generated_utc":Time.get_datetime_string_from_system(true),
		"engine":Engine.get_version_info(), "rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"gpu":RenderingServer.get_video_adapter_name(), "os":OS.get_name(), "os_version":OS.get_version(),
		"cpu":OS.get_processor_name(), "cpu_threads":OS.get_processor_count(),
		"window_pixels":[root.size.x,root.size.y], "screen_scale":DisplayServer.screen_get_scale(),
		"screen_refresh_hz":DisplayServer.screen_get_refresh_rate(),
		"vsync_mode":DisplayServer.window_get_vsync_mode(), "engine_max_fps":Engine.max_fps,
		"fixture":{"tick":sim.tick,"workers":sim.workers.size(),"buildings":sim.buildings.size(),
			"completed_buildings":completed,"roads":sim.roads.size(),"won":sim.won},
		"warmup_seconds_per_case":warmup_seconds, "sample_seconds_per_case":sample_seconds,
		"samples":[], "notes":["Native development engine, not an exported release.",
			"VSync configuration preserved. Wall intervals measure cadence, not uncapped throughput.",
			"GPU/CPU render timings are null when the backend returns only zero.",
			"Performance monitors can refresh less often than once per frame.",
			"No manual sim.step, world.sync, screenshot or force_draw inside warmup or timed sampling."]}
	print("BENCHMARK_BASELINE ", JSON.stringify(results.fixture))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for case in [
		{"name":"strategy-1x","size":43.0,"focus":Vector2i(13,13),"speed":1},
		{"name":"strategy-4x","size":43.0,"focus":Vector2i(13,13),"speed":4},
		{"name":"close-1x","size":18.0,"focus":Vector2i(19,18),"speed":1},
		{"name":"close-4x","size":18.0,"focus":Vector2i(19,18),"speed":4}]:
		await measure_case(case, baseline)
	write_json(output_dir + "/" + run_label + ".json", results)
	print("BENCHMARK_COMPLETE ", output_dir + "/" + run_label + ".json")
	quit()

func measure_case(config: Dictionary, baseline: Dictionary) -> void:
	game.set_process(false)
	assert(sim.restore(baseline.duplicate(true)), "Cannot restore legal baseline")
	game.clock = CLOCK.new(100000)
	game.speed = config.speed
	game._clear_world()
	game.hud._toast.hide()
	game.world.focus_cell(config.focus)
	game.world.target_size = config.size
	game.set_process(true)
	var warmup_start := Time.get_ticks_usec()
	while (Time.get_ticks_usec()-warmup_start)/1000000.0 < warmup_seconds:
		await process_frame
	var metrics := {"frame_ms":[],"process_monitor_ms":[],"physics_monitor_ms":[],
		"render_cpu_ms":[],"frame_setup_cpu_ms":[],"render_gpu_ms":[],
		"draw_calls":[],"primitives":[],"objects":[],"video_memory_mib":[],"static_memory_mib":[]}
	var tick_start: int = sim.tick
	var paused_frames := 0
	var unfocused_frames := 0
	var start_usec := Time.get_ticks_usec()
	var previous_usec := start_usec
	print("BENCHMARK_SAMPLING ", run_label, " ", config.name)
	while (previous_usec-start_usec)/1000000.0 < sample_seconds:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		metrics.frame_ms.append((now_usec-previous_usec)/1000.0)
		previous_usec = now_usec
		metrics.process_monitor_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		metrics.physics_monitor_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		metrics.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		metrics.frame_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
		metrics.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		metrics.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		metrics.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		metrics.objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		metrics.video_memory_mib.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0)
		metrics.static_memory_mib.append(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
		if sim.paused or game.application_paused:
			paused_frames += 1
		if not root.has_focus():
			unfocused_frames += 1
	var elapsed_seconds := (previous_usec-start_usec)/1000000.0
	game.set_process(false)
	var sample := {"case":config.name,"camera_size":game.world.view_size,
		"focus_cell":[config.focus.x,config.focus.y],"speed":config.speed,
		"frame_count":metrics.frame_ms.size(),"elapsed_seconds":elapsed_seconds,
		"tick_start":tick_start,"tick_end":sim.tick,"ticks_per_wall_second":(sim.tick-tick_start)/elapsed_seconds,
		"paused_frames":paused_frames,"unfocused_frames":unfocused_frames,
		"world_buildings":game.world.buildings.size(),"world_people":game.world.people.size(),
		"conservation_errors":sim.conservation_errors(),"metrics":{}}
	for key in metrics:
		sample.metrics[key] = statistics(metrics[key], key in ["render_cpu_ms","frame_setup_cpu_ms","render_gpu_ms"])
	var long_frames := 0
	for ms in metrics.frame_ms:
		if ms > 33.333:
			long_frames += 1
	sample.frames_over_33_ms = long_frames
	results.samples.append(sample)
	write_json(output_dir + "/" + run_label + "-" + config.name + "-raw.json", metrics)
	write_json(output_dir + "/" + run_label + ".json", results)
	print("BENCHMARK_RESULT ", JSON.stringify(sample))
	# Readback and forced draw happen only after the timed interval has ended.
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.016)
	var screenshot := root.get_texture().get_image()
	sample.framebuffer_pixels = [screenshot.get_width(),screenshot.get_height()]
	var image_path: String = output_dir + "/" + run_label + "-" + config.name + ".png"
	assert(screenshot.save_png(image_path) == OK)
	sample.screenshot = image_path
	assert(sample.paused_frames == 0 and sample.tick_end > sample.tick_start, "Game must run throughout measurement")
	assert(sample.conservation_errors.is_empty(), "Conservation failed during benchmark")

func build_mission()->void:
	for plan in [["house",Vector2i(4,6)],["house",Vector2i(8,5)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)],["farm",Vector2i(16,19)],["vineyard",Vector2i(17,5)],["winery",Vector2i(18,17)],["store",Vector2i(7,18)]]:
		var result: Dictionary = sim.command("build",{"kind":plan[0],"cell":plan[1]})
		assert(result.ok,"legal approved mission construction "+plan[0]+": "+result.message)
	var roads: Array[Vector2i] = []
	for x in range(2,21): roads.append(Vector2i(x,13))
	for y in range(8,13): roads.append(Vector2i(5,y))
	for x in range(4,11): roads.append(Vector2i(x,8))
	for y in range(7,13): roads.append(Vector2i(15,y))
	for x in range(8,20): roads.append(Vector2i(x,7))
	for y in range(14,22): roads.append(Vector2i(5,y))
	for x in range(3,20): roads.append(Vector2i(x,21))
	roads.append(Vector2i(3,20))
	roads.append(Vector2i(19,20))
	assert(sim.command("road",{"cells":roads}).ok,"full mission network routes around the expanded main building and school")
	for role in ["lumberjack","stonecutter","farmer","vintner","vintner","servant","servant"]:
		assert(sim.command("train",{"role":role}).ok,"professional training request "+role)
