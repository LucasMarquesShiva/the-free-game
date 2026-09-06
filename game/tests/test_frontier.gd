extends SceneTree

const Frontier = preload("res://simulation/frontier_sim.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func advance(sim: RefCounted, ticks: int) -> void:
	for index in range(ticks):
		sim.step()

func state(sim: RefCounted) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim.snapshot()))

func fresh() -> RefCounted:
	var sim := Frontier.new()
	sim.setup()
	return sim

func run() -> void:
	var sim := fresh()
	expect(sim.buildings.size() == 2 and sim.buildings[0].kind == "hall" and sim.buildings[1].kind == "training", "only main building and training center exist initially")
	expect(sim.battle == null and sim.roads.is_empty(), "no army or roads exist initially")
	var counts: Dictionary = sim.profession_counts()
	expect(counts.builder == 3 and counts.servant == 5 and counts.instructor == 1 and counts.resident == 8, "bootstrap professions exist without pre-trained producers")
	expect(counts.lumberjack == 0 and counts.farmer == 0 and counts.vintner == 0, "production specialists must be trained")
	expect(sim.command("train",{"role":"lumberjack"}).ok, "player can request a profession before road exists")
	advance(sim,100)
	expect(sim.profession_counts().lumberjack == 0 and sim.training[0].reason.contains("Conecte"), "school waits for its road connection")
	var cost_before: int = sim.available("stone")
	expect(sim.command("road",{"cells":[Vector2i(8,12),Vector2i(9,12),Vector2i(10,12),Vector2i(11,12),Vector2i(12,12)]}).ok, "road is planned through legal command")
	expect(sim.available("stone") == cost_before - 5 and sim.roads[0].stage == "planned", "planned road reserves one finite stone per cell")
	advance(sim,65)
	var saved := state(sim)
	var restored := fresh()
	expect(restored.restore(saved), "road construction and carried stone restore through JSON")
	advance(sim,900)
	advance(restored,900)
	expect(state(sim) == state(restored), "restored roads, training and worker movement are deterministic")
	expect(sim.is_building_connected(sim.buildings[1]) and sim.profession_counts().lumberjack == 1, "builders connect school and training resumes automatically")
	expect(sim.conservation_errors().is_empty(), "road building consumes physical stone exactly once")
	_test_natural_obstacles()
	_test_commands_and_saves()
	_test_interruption()
	_test_cancelled_delivery()
	_test_mission()
	if failures.is_empty():
		print("PASS: ",checks," verificações Frontier: início mínimo, estradas, interrupção, persistência e missão legal.")
		quit(0)
	else:
		print("FAILURES: ",failures)
		quit(1)

func _test_natural_obstacles() -> void:
	var sim := fresh()
	var other := fresh()
	expect(sim.natural_cells.size() == 93 and sim.natural_cells == other.natural_cells,"four natural groves expose the same 93 cells on every new game")
	var valid := true
	for cell in sim.natural_cells:
		valid = valid and sim.is_terrain_natural(cell) and not sim.is_walkable(cell) and not sim.can_place_road(cell).is_empty()
	expect(valid,"every tree cell blocks civilian paths and road placement")
	var initial_state := state(sim)
	expect(not sim.command("road",{"cells":[Vector2i(8,12),Vector2i(3,5)]}).ok and state(sim) == initial_state,"a road batch crossing a grove is rejected without reservations")
	expect(not sim.command("build",{"kind":"house","cell":Vector2i(13,2)}).ok and state(sim) == initial_state,"building checks all footprint cells, including a tree beyond its origin")
	expect(sim.can_place("house",Vector2i(4,6)).is_empty() and sim.can_place("lumber",Vector2i(3,18)).is_empty(),"groves preserve the legal mission building sites")
	expect(not sim.find_path(Vector2i(7,12),Vector2i(12,12)).is_empty(),"initial main-to-school route remains reachable")
	var malformed := initial_state.duplicate(true)
	malformed.workers[0].cell = {"__cell":[3,5]}
	expect(not sim.restore(malformed) and state(sim) == initial_state,"save cannot place a worker inside a tree")
	malformed = initial_state.duplicate(true)
	malformed.buildings[1].cell = {"__cell":[14,2]}
	expect(not sim.restore(malformed) and state(sim) == initial_state,"save cannot place a building over a grove")
	sim.command("road",{"cell":Vector2i(8,12)})
	var road_state := state(sim)
	malformed = road_state.duplicate(true)
	malformed.roads[0].cell = {"__cell":[3,5]}
	expect(not sim.restore(malformed) and state(sim) == road_state,"save cannot restore a road through a tree")

func _test_commands_and_saves() -> void:
	var sim := fresh()
	var initial_state := state(sim)
	expect(not sim.command("road",{"cells":[Vector2i(8,12),Vector2i(22,2)]}).ok and state(sim) == initial_state,"invalid road batch is rejected atomically without spending stone")
	expect(not sim.command("army",{"target":Vector2i(25,15)}).ok and not sim.command("recruit",{"role":"lancer"}).ok,"military commands cannot create troops in frontier")
	expect(sim.is_walkable(Vector2i(28,20)) and sim.is_walkable(Vector2i(32,20)),"former military camp footprints have no collision")
	expect(sim.command("road",{"cells":[Vector2i(7,12),Vector2i(8,12),Vector2i(8,12)]}).ok and sim.roads.size() == 1 and sim.reserved.stone == 1,"duplicate cells and main entrance are charged only once")
	expect(not sim.command("build",{"kind":"house","cell":Vector2i(8,12)}).ok,"building cannot cover a planned road")
	var valid := state(sim)
	var malformed := valid.duplicate(true)
	malformed.next_id = 1
	expect(not sim.restore(malformed) and state(sim) == valid,"save with reused future identifiers is rejected without changing the village")
	malformed = valid.duplicate(true)
	malformed.roads[0].builder = 9999
	expect(not sim.restore(malformed) and state(sim) == valid,"save cannot reference a nonexistent road builder")
	malformed = valid.duplicate(true)
	malformed.roads[0].cell = {"__cell":[22,2]}
	expect(not sim.restore(malformed) and state(sim) == valid,"save cannot add a road over impassable water")
	malformed = valid.duplicate(true)
	malformed.mode = "peaceful"
	expect(not sim.restore(malformed) and state(sim) == valid,"frontier does not import saves from another scene mode")
	expect(sim.command("remove_road",{"cell":Vector2i(8,12)}).ok and sim.reserved.stone == 0 and sim.stock.stone == 160,"cancelling an unstarted road releases its stone reservation")
	expect(sim.command("road",{"cell":Vector2i(15,12)}).ok,"disconnected road can be planned")
	advance(sim,200)
	expect(sim.road_at(Vector2i(15,12)).stage == "planned" and sim.stock.stone == 160,"builder waits for a connected construction front")

func _test_interruption() -> void:
	var sim := fresh()
	var route: Array[Vector2i] = []
	for x in range(7,16): route.append(Vector2i(x,12))
	expect(sim.command("road",{"cells":route}).ok,"delivery road requested")
	expect(sim.command("build",{"kind":"house","cell":Vector2i(15,10)}).ok,"house requested beside road endpoint")
	var carrier_id := -1
	var broken := false
	var before_total := 0
	for index in range(3000):
		sim.step()
		for worker in sim.workers:
			if worker.role == "servant" and not worker.cargo.is_empty() and worker.cell.x <= 9 and worker.task.get("building",0) > 0 and sim.has_road(Vector2i(11,12)):
				var response: Dictionary = sim.command("remove_road",{"cell":Vector2i(11,12)})
				if response.ok:
					carrier_id = worker.id
					before_total = worker.cargo.amount
					broken = true
					break
		if broken: break
	expect(broken,"connected delivery can be interrupted by removing an unoccupied road tile")
	if not broken: return
	advance(sim,100)
	var carrier: Dictionary = sim._worker(carrier_id)
	expect(not carrier.cargo.is_empty() and carrier.cargo.amount == before_total and carrier.cell.x < 11,"isolated delivery keeps its load and does not cross the field")
	expect(sim.conservation_errors().is_empty(),"road interruption loses no materials")
	var snapshot := state(sim)
	var restored := fresh()
	expect(restored.restore(snapshot),"waiting load on a disconnected road can be saved and restored")
	expect(sim.command("road",{"cell":Vector2i(11,12)}).ok,"player replans missing road tile")
	restored.command("road",{"cell":Vector2i(11,12)})
	for index in range(4000):
		sim.step()
		restored.step()
		if sim.buildings.back().stage == "complete": break
	expect(sim.buildings.back().stage == "complete" and sim.conservation_errors().is_empty(),"reconnection resumes transport and completes house automatically")
	expect(state(sim) == state(restored),"disconnected cargo resumes identically after save and reconnection")
	if sim.buildings.back().stage != "complete":
		print("INTERRUPTION_ROADS ",sim.roads)
		for worker in sim.workers: print("INTERRUPTION_WORKER ",worker)

func _test_cancelled_delivery() -> void:
	var sim := fresh()
	var cells: Array[Vector2i] = []
	for x in range(8,16): cells.append(Vector2i(x,12))
	sim.command("road",{"cells":cells})
	sim.command("build",{"kind":"house","cell":Vector2i(15,10)})
	var site: Dictionary = sim.buildings.back()
	for index in range(3000):
		sim.step()
		if site.delivered.wood > 0: break
	expect(site.stage == "materials" and site.delivered.wood > 0,"cancellation test reaches a real partially supplied construction site")
	expect(sim.command("cancel",{"id":site.id}).ok,"player can cancel the supplied construction")
	advance(sim,1500)
	expect(sim.stock.wood == 140 and site.output.wood == 0 and sim.conservation_errors().is_empty(),"servants return delivered and carried materials from a cancelled site by road")

func _test_mission() -> void:
	var sim := fresh()
	for plan in [["house",Vector2i(4,6)],["house",Vector2i(8,5)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)],["farm",Vector2i(16,19)],["vineyard",Vector2i(17,5)],["winery",Vector2i(18,14)]]:
		var response: Dictionary = sim.command("build",{"kind":plan[0],"cell":plan[1]})
		expect(response.ok,"legal frontier building: "+plan[0]+" / "+response.message)
	var cells: Array[Vector2i] = []
	for x in range(2,21): cells.append(Vector2i(x,12))
	for y in range(8,12): cells.append(Vector2i(5,y))
	for x in range(4,11): cells.append(Vector2i(x,8))
	for y in range(7,12): cells.append(Vector2i(15,y))
	for x in range(8,20): cells.append(Vector2i(x,7))
	for y in range(13,22): cells.append(Vector2i(5,y))
	for x in range(3,20): cells.append(Vector2i(x,21))
	cells.append(Vector2i(3,20))
	for y in range(13,17): cells.append(Vector2i(20,y))
	for x in range(18,20): cells.append(Vector2i(x,16))
	expect(sim.command("road",{"cells":cells}).ok,"all mission road branches legally planned")
	for role in ["lumberjack","stonecutter","farmer","vintner","vintner","servant","servant"]:
		expect(sim.command("train",{"role":role}).ok,"specialist requested by profession: "+role)
	var invalid_transport := false
	var walked_through_nature := false
	var invariant_issues: Array[String] = []
	var won_tick := 0
	var started := Time.get_ticks_msec()
	for index in range(18000):
		sim.step()
		if index % 50 == 0:
			for issue in sim.conservation_errors():
				if not invariant_issues.has(issue): invariant_issues.append(issue)
		for worker in sim.workers:
			if worker.role == "servant" and not worker.cargo.is_empty() and not sim._road_node(worker.cell): invalid_transport = true
			if sim.is_terrain_natural(worker.cell): walked_through_nature = true
		if sim.won:
			won_tick = sim.tick
			break
	expect(won_tick > 0,"legal roads, construction and training complete the peaceful frontier mission")
	expect(not invalid_transport,"every loaded servant stays on completed roads")
	expect(not walked_through_nature,"every civilian avoids tree cells throughout the legal mission")
	expect(sim.produced.wood > 0,"lumberjack uses the accessible front workplace beside the grove")
	expect(invariant_issues.is_empty(),"resources and road stone reservations remain conserved: "+str(invariant_issues))
	expect(sim._completed("lumber") > 0 and sim._completed("quarry") > 0 and sim._completed("farm") > 0 and sim._completed("vineyard") > 0 and sim._completed("winery") > 0,"all required production chains physically built")
	var continued := fresh()
	expect(continued.restore(state(sim)),"working production chains restore after the mission")
	advance(sim,250)
	advance(continued,250)
	expect(state(sim) == state(continued) and sim.conservation_errors().is_empty(),"production and transport continue deterministically after save")
	print("FRONTIER_RESULT ",JSON.stringify({"victory_tick":won_tick,"tick":sim.tick,"checks":checks,"failures":failures,"wall_ms":Time.get_ticks_msec()-started,"roads":sim.roads.size(),"stats":sim.stats,"stock":sim.stock}))
	if won_tick == 0:
		for building in sim.buildings: print("BUILDING ",building.kind," ",building.stage," ",building.reason)
		for worker in sim.workers: print("WORKER ",worker.id," ",worker.role," ",worker.cell," ",worker.state," ",worker.task," cargo=",worker.cargo)
