extends SceneTree

const Village = preload("res://simulation/village_sim.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)


func fresh(peaceful: bool = true) -> RefCounted:
	var sim := Village.new()
	sim.setup(peaceful)
	return sim


func advance(sim: RefCounted, ticks: int) -> void:
	for index in range(ticks):
		sim.step()


func json_state(sim: RefCounted) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim.snapshot()))


func run() -> void:
	_test_mode_boundary()
	_test_save_modes()
	_test_legal_mission()
	if failures.is_empty():
		print("PASS: ", checks, " verificações do modo pacífico, missão civil e isolamento dos salvamentos.")
		quit(0)
	else:
		print("FAILURES: ", failures)
		quit(1)


func _test_mode_boundary() -> void:
	var sim := fresh()
	expect(sim.peaceful and sim.battle == null, "peaceful setup creates no military simulation or units")
	expect(sim.objective_rows().size() == 3, "peaceful objectives contain only houses, food and wine")
	expect(sim.snapshot().mode == "peaceful" and sim.snapshot().battle == null, "peaceful snapshot has explicit mode and no military state")
	expect(not sim._occupied(Vector2i(17,11)) and sim.can_place("house",Vector2i(17,11)).is_empty(), "former army spawn has no ghost occupancy or construction restriction")
	var before := json_state(sim)
	for request in [
		["army", {"order":"attack","target":Vector2i(30,14)}],
		["recruit", {"role":"lancer"}],
		["build", {"kind":"barracks","cell":Vector2i(17,23)}],
		["move_civil", {"id":7,"cell":Vector2i(8,8)}]
	]:
		var response: Dictionary = sim.command(request[0],request[1])
		expect(not response.ok and json_state(sim) == before, "forbidden command changes no people, stock or events: "+request[0])
	advance(sim, 300)
	expect(sim.battle == null and not sim.won and sim.conservation_errors().is_empty(), "civil simulation advances without military ticks, false victory or resource errors")
	sim.command("pause")
	before = json_state(sim)
	advance(sim, 100)
	expect(json_state(sim) == before, "peaceful pause freezes all simulation state")
	sim.command("new_game")
	expect(sim.peaceful and sim.battle == null and sim.tick == 0 and not sim.paused, "restart preserves peaceful mode and resets the village")
	var standard := Village.new()
	standard.setup()
	expect(not standard.peaceful and standard.battle != null and standard.battle.units.size() == 18, "setup without arguments retains version 0.1 military behavior")
	expect(standard.objective_rows().size() == 4 and standard.snapshot().mode == "standard", "standard still has its military objective and mode")
	standard.command("new_game")
	expect(not standard.peaceful and standard.battle != null, "standard restart remains standard")


func _test_save_modes() -> void:
	var peaceful := fresh()
	peaceful.command("build",{"kind":"house","cell":Vector2i(13,3)})
	peaceful.command("train",{"role":"servant","quantity":2})
	advance(peaceful, 140)
	var saved := json_state(peaceful)
	var resumed := fresh()
	expect(resumed.restore(saved) and resumed.battle == null, "peaceful in-progress work and training restore through JSON")
	expect(json_state(peaceful) == json_state(resumed), "restored peaceful state preserves cargo, queues, positions and statistics")
	advance(peaceful, 800)
	advance(resumed, 800)
	expect(json_state(peaceful) == json_state(resumed), "continued peaceful save produces the same simulation as uninterrupted play")
	var standard := fresh(false)
	var legacy := json_state(standard)
	legacy.erase("mode")
	var legacy_loaded := fresh(false)
	expect(legacy_loaded.restore(legacy) and legacy_loaded.battle != null and not legacy_loaded.peaceful, "legacy version 1 saves without mode still load as standard")
	var before_standard := json_state(standard)
	expect(not standard.restore(saved) and json_state(standard) == before_standard, "standard scene rejects peaceful save atomically")
	var before_peaceful := json_state(resumed)
	expect(not resumed.restore(legacy) and json_state(resumed) == before_peaceful, "peaceful scene rejects legacy military save atomically")
	expect(not resumed.restore(before_standard) and json_state(resumed) == before_peaceful, "peaceful scene rejects explicit standard mode")
	var invalid := saved.duplicate(true)
	invalid.battle = before_standard.battle
	expect(not resumed.restore(invalid) and json_state(resumed) == before_peaceful, "peaceful save cannot inject military state")
	invalid = saved.duplicate(true)
	invalid.mode = "unknown"
	expect(not resumed.restore(invalid) and json_state(resumed) == before_peaceful, "unknown save mode is rejected")
	invalid = saved.duplicate(true)
	invalid.stock.wood = -1
	expect(not resumed.restore(invalid) and json_state(resumed) == before_peaceful, "corrupted peaceful stock is rejected without mutation")


func _test_legal_mission() -> void:
	var sim := fresh()
	# Only public player commands: no injected materials, professions or completed buildings.
	for plan in [
		["house",Vector2i(13,3)], ["house",Vector2i(16,3)],
		["farm",Vector2i(13,19)], ["vineyard",Vector2i(16,19)],
		["winery",Vector2i(18,7)]
	]:
		var response: Dictionary = sim.command("build",{"kind":plan[0],"cell":plan[1]})
		expect(response.ok, "legal peaceful placement: "+plan[0]+" — "+response.message)
	expect(sim.command("train",{"role":"servant","quantity":3}).ok, "servant training selected only by profession and quantity")
	var start := Time.get_ticks_msec()
	var victory_tick := 0
	var invariant_failures: Array[String] = []
	var military_created := false
	for index in range(12000):
		sim.step()
		military_created = military_created or sim.battle != null
		if index % 100 == 0:
			for issue in sim.conservation_errors():
				if not invariant_failures.has(issue):
					invariant_failures.append(issue)
		if sim.won:
			victory_tick = sim.tick
			break
	expect(victory_tick > 0, "houses, food and wine complete the civil mission without a military objective")
	expect(not military_created and sim.battle == null, "no military simulation is ever created during the mission")
	var all_done := true
	for objective in sim.objective_rows():
		all_done = all_done and objective.done
	expect(all_done and sim.objective_rows().size() == 3, "all three independent civil objectives finish")
	expect(sim.stats.houses_built >= 2 and sim.stats.food_produced > 0 and sim.stats.wine_delivered >= 12, "victory is supported by actual houses, food production and wine delivery")
	expect(invariant_failures.is_empty(), "autonomous peaceful production conserves resources and exclusive civil positions")
	var military_event := false
	for event in sim.events:
		var lower: String = str(event.text).to_lower()
		military_event = military_event or lower.contains("acampamento") or lower.contains("soldado") or lower.contains("exército")
	expect(not military_event, "peaceful event stream and victory have no military narration")
	var won_save := json_state(sim)
	var restored := fresh()
	expect(restored.restore(won_save) and restored.won and restored.battle == null, "completed peaceful mission restores without a battle")
	advance(sim, 600)
	advance(restored, 600)
	expect(sim.tick > victory_tick and sim.won and json_state(sim) == json_state(restored), "village continues deterministically after peaceful victory")
	expect(sim.conservation_errors().is_empty(), "continued village remains resource-consistent")
	print("PEACEFUL_MISSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"victory_tick":victory_tick,"duration_ticks":sim.tick,"wall_ms":Time.get_ticks_msec()-start,
		"stats":sim.stats,"stock":sim.stock,"mode":sim.snapshot().mode,"battle":sim.snapshot().battle}))
