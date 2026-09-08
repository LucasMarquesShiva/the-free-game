extends SceneTree
## Drives shipped approved_sim commands for the KaM remake gap criteria.
const Approved = preload("res://simulation/approved_sim.gd")
const Spec = preload("res://simulation/mission_spec.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func advance(sim: RefCounted, ticks: int) -> void:
	for i in range(ticks):
		sim.step()


func connect_school(sim: RefCounted) -> void:
	var cells: Array[Vector2i] = []
	for x in range(8, 14):
		cells.append(Vector2i(x, 13))
	sim.command("road", {"cells": cells})


func link_entrance(sim: RefCounted, entrance: Vector2i) -> void:
	var path: Array[Vector2i] = sim.find_path(Vector2i(8, 13), entrance)
	var accepted: Array[Vector2i] = []
	for cell in path:
		if str(sim.can_place_road(cell)) == "":
			accepted.append(cell)
	if str(sim.can_place_road(entrance)) == "":
		accepted.append(entrance)
	if not accepted.is_empty():
		sim.command("road", {"cells": accepted})


func wait_complete(sim: RefCounted, kind: String, ticks: int = 8000) -> bool:
	for i in range(ticks):
		sim.step()
		if sim._completed(kind) > 0:
			return true
	return sim._completed(kind) > 0


func run() -> void:
	_test_default_sandbox()
	_test_gold_school()
	_test_inn_eat_and_starve()
	_test_storehouse_node()
	_test_trees_trunks_timber()
	_test_quarry_deposit()
	_test_corn_loaves()
	_test_army_equipment()
	_test_mission_lock()
	print("KAM_GAPS_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _test_default_sandbox() -> void:
	var sim := Approved.new()
	sim.setup()
	expect(sim.buildings.size() == 2 and sim.workers.size() == 17, "default sandbox still starts hall+school and 17 civilians")
	expect(sim.battle == null, "default start does not spawn a field army")
	expect(sim.command("build", {"kind": "farm", "cell": Vector2i(16, 19)}).ok, "default sandbox can still place a farm")
	expect(not sim.command("army", {"order": "attack", "target": Vector2i(17, 12)}).ok, "army without soldiers is refused")


func _test_gold_school() -> void:
	var sim := Approved.new()
	sim.setup()
	connect_school(sim)
	advance(sim, 80)
	var residents := int(sim.profession_counts().get("resident", 0))
	var people := sim.workers.size()
	var gold := int(sim.stock.gold)
	expect(gold >= 1, "school gold exists as a ware at start")
	expect(sim.command("train", {"role": "lumberjack"}).ok, "gold school accepts a lumberjack request")
	advance(sim, 800)
	expect(int(sim.profession_counts().get("lumberjack", 0)) >= 1, "school created a lumberjack")
	expect(sim.workers.size() == people + 1, "school spawned a new civilian instead of retraining a resident")
	expect(int(sim.profession_counts().get("resident", 0)) == residents, "housed residents were not consumed")
	expect(int(sim.stock.gold) < gold or int(sim.consumed.gold) > 0, "training spent gold")


func _test_inn_eat_and_starve() -> void:
	var hungry := Approved.new()
	hungry.setup()
	for person in hungry.workers:
		person.meal = 0
	var lumber := 0
	for building in hungry.buildings:
		if building.kind == "training":
			building.output.wood = 0
	# No inn: producers must stop.
	var farmer_hut := hungry.command("build", {"kind": "farm", "cell": Vector2i(16, 19)})
	expect(farmer_hut.ok, "farm still places while testing hunger")
	advance(hungry, 40)
	for person in hungry.workers:
		if person.role in ["lumberjack", "stonecutter", "farmer", "instructor"]:
			expect(int(person.meal) <= 0, "hungry worker meal stays empty without an inn")
	var producing := false
	for person in hungry.workers:
		if str(person.state).begins_with("Produzindo") or str(person.state).contains("horta"):
			producing = true
	expect(not producing, "without inn food, workers stop producing")

	var sim := Approved.new()
	sim.setup()
	connect_school(sim)
	expect(sim.command("build", {"kind": "inn", "cell": Vector2i(4, 6)}).ok, "inn places")
	link_entrance(sim, sim.buildings.back().entrance)
	expect(wait_complete(sim, "inn", 5000), "inn completes through autonomous builders")
	for person in sim.workers:
		person.meal = 0
	advance(sim, 400)
	var ate := false
	for person in sim.workers:
		if int(person.meal) > 0:
			ate = true
	expect(ate, "workers walk to the inn and eat")


func _test_storehouse_node() -> void:
	var sim := Approved.new()
	sim.setup()
	var hall: Dictionary = sim._store_for(Vector2i(8, 13))
	expect(hall.kind == "hall", "hall is the fallback depot before a store exists")
	expect(sim.command("build", {"kind": "store", "cell": Vector2i(7, 18)}).ok, "store places")
	link_entrance(sim, sim.buildings.back().entrance)
	expect(wait_complete(sim, "store", 6000), "store completes")
	var depot: Dictionary = sim._store_for(Vector2i(8, 13))
	expect(depot.kind == "store", "completed storehouse becomes the pick/drop node")
	expect(depot.entrance != hall.entrance, "storehouse entrance is not the hall capacity buff")


func _test_trees_trunks_timber() -> void:
	var sim := Approved.new()
	sim.setup()
	connect_school(sim)
	expect(sim.command("build", {"kind": "lumber", "cell": Vector2i(3, 18)}).ok, "woodcutter places beside grove")
	link_entrance(sim, sim.buildings.back().entrance)
	sim.command("train", {"role": "lumberjack"})
	expect(wait_complete(sim, "lumber", 5000), "woodcutter hut completes")
	var trunks := 0
	var chopped := 0
	var saw_chopping := false
	for i in range(2500):
		sim.step()
		for person in sim.workers:
			if str(person.state).contains("Cort"):
				saw_chopping = true
		trunks = int(sim.produced.get("trunks", 0))
		if sim.harvest_map != null:
			for cell in sim.harvest_map.tree_cells():
				if sim.harvest_map.is_harvested(cell):
					chopped += 1
					break
		if trunks >= 1:
			break
	expect(saw_chopping, "woodcutter spends time chopping a standing tree")
	expect(trunks >= 1, "woodcutters harvest map trees into trunks")
	expect(chopped >= 1, "a grove cell is marked harvested")
	expect(sim.command("build", {"kind": "sawmill", "cell": Vector2i(16, 11)}).ok, "sawmill places")
	link_entrance(sim, sim.buildings.back().entrance)
	sim.command("train", {"role": "lumberjack"})
	expect(wait_complete(sim, "sawmill", 6000), "sawmill completes")
	var timber := 0
	for i in range(3000):
		sim.step()
		timber = int(sim.produced.get("wood", 0))
		if timber >= 1 and int(sim.consumed.get("trunks", 0)) >= 1:
			break
	expect(int(sim.consumed.get("trunks", 0)) >= 1 and timber >= 1, "sawmill turns trunks into timber used as wood")


func _test_quarry_deposit() -> void:
	var sim := Approved.new()
	sim.setup()
	var denied: Dictionary = sim.command("build", {"kind": "quarry", "cell": Vector2i(16, 6)})
	expect(not denied.ok, "quarry without a stone deposit is rejected: " + str(denied.message))
	var ok: Dictionary = sim.command("build", {"kind": "quarry", "cell": Vector2i(12, 19)})
	expect(ok.ok, "quarry against a deposit is allowed: " + str(ok.message))


func _test_corn_loaves() -> void:
	var sim := Approved.new()
	sim.setup()
	connect_school(sim)
	expect(sim.command("build", {"kind": "farm", "cell": Vector2i(16, 19)}).ok, "grain farm places")
	link_entrance(sim, sim.buildings.back().entrance)
	expect(sim.command("build", {"kind": "mill", "cell": Vector2i(17, 5)}).ok, "mill places")
	link_entrance(sim, sim.buildings.back().entrance)
	expect(sim.command("build", {"kind": "bakery", "cell": Vector2i(18, 17)}).ok, "bakery places")
	link_entrance(sim, sim.buildings.back().entrance)
	sim.command("train", {"role": "farmer"})
	sim.command("train", {"role": "miller"})
	sim.command("train", {"role": "baker"})
	var loaves := 0
	for i in range(12000):
		sim.step()
		loaves = int(sim.produced.get("loaves", 0))
		if loaves >= 1:
			break
	expect(int(sim.produced.get("corn", 0)) >= 1, "grain fields produce corn")
	expect(int(sim.produced.get("flour", 0)) >= 1, "mill turns corn into flour")
	expect(loaves >= 1, "bakery turns flour into loaves")
	var wine_win := false
	for row in sim.objective_rows():
		if str(row.text).contains("12") and str(row.text).to_lower().contains("vinh"):
			wine_win = true
	expect(not wine_win, "sandbox identity win is not deliver-12-wines")


func _test_army_equipment() -> void:
	var sim := Approved.new()
	sim.setup()
	connect_school(sim)
	expect(sim.definitions.has("barracks"), "approved scene keeps barracks")
	expect(sim.command("build", {"kind": "barracks", "cell": Vector2i(16, 6)}).ok, "barracks places on approved")
	link_entrance(sim, sim.buildings.back().entrance)
	expect(int(sim.stock.axe) >= 1 and int(sim.stock.bow) >= 1, "melee and ranged kits exist as wares")
	sim.command("train", {"role": "recruit"})
	sim.command("train", {"role": "recruit"})
	expect(wait_complete(sim, "barracks", 6000), "barracks completes")
	advance(sim, 1200)
	var melee: Dictionary = sim.command("recruit", {"role": "lancer"})
	expect(melee.ok, "barracks fields a melee unit from recruit+axe: " + str(melee.message))
	advance(sim, 800)
	var ranged: Dictionary = sim.command("recruit", {"role": "archer"})
	expect(ranged.ok, "barracks fields a ranged unit from recruit+bow: " + str(ranged.message))
	var order: Dictionary = sim.command("army", {"order": "attack", "target": Vector2i(17, 12)})
	expect(order.ok, "approved scene issues an army order: " + str(order.message))
	expect(sim.battle != null and sim.battle._alive("ally").size() >= 2, "company has the recruited soldiers")


func _test_mission_lock() -> void:
	var spec: RefCounted = Spec.load_id("tsk-01")
	var sim := Approved.new()
	sim.setup()
	sim.mission = spec
	expect(not sim.command("build", {"kind": "farm", "cell": Vector2i(16, 19)}).ok, "teaching set hides farm")
	expect(not sim.command("build", {"kind": "winery", "cell": Vector2i(18, 17)}).ok, "teaching set hides winery")
	expect(sim.command("build", {"kind": "inn", "cell": Vector2i(4, 6)}).ok, "teaching set allows inn")
	expect(spec.objectives_met({"training": 1, "inn": 1, "lumber": 1, "quarry": 1}), "teaching win is school/inn/wood/stone")
	expect(not spec.objectives_met({"house": 2, "farm": 1, "wine": 12}), "wine checklist does not win the teaching set")
	var sandbox := Approved.new()
	sandbox.setup()
	expect(sandbox.mission == null and sandbox.command("build", {"kind": "farm", "cell": Vector2i(16, 19)}).ok, "default sandbox start is unchanged")
	var lesson := Approved.new()
	var loaded: Dictionary = lesson.command("load_mission", {"id": "tsk-01"})
	expect(loaded.ok, "first lesson starts from a sim command: " + str(loaded.message))
	expect(lesson.mission != null and not lesson.command("build", {"kind": "farm", "cell": Vector2i(16, 19)}).ok, "loaded lesson still hides farm")
	var gold_school := Approved.new()
	gold_school.setup()
	connect_school(gold_school)
	gold_school.command("train", {"role": "builder"})
	var school_gold := 0
	for i in range(400):
		gold_school.step()
		var school: Dictionary = gold_school.buildings[1]
		school_gold = int(school.input.get("gold", 0))
		if school_gold > 0 or int(gold_school.consumed.get("gold", 0)) > 0:
			break
	expect(school_gold > 0 or int(gold_school.consumed.gold) > 0, "servants deliver gold to the school before training spends it")
	var defeat := Approved.new()
	defeat.setup()
	defeat._ensure_battle()
	advance(defeat, 8)
	expect(defeat.lost and defeat.battle.defeated, "empty company defeat sets lost")
