extends SceneTree
const HarvestMap = preload("res://simulation/harvest_map.gd")
const Sim = preload("res://simulation/approved_sim.gd")
const Terrain = preload("res://presentation/approved_terrain.gd")
const Civil = preload("res://presentation/approved_civil_buildings.gd")
const World = preload("res://presentation/approved_world.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL ", message)

func run() -> void:
	_test_harvest_api()
	_test_grove_stumps()
	_test_sawmill_mesh()
	_test_site_fence()
	_test_harvest_persist()
	_test_dedicated_meshes()
	_test_chop_duration()
	_test_chop_facing()
	print("HARVEST_MAP_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _test_harvest_api() -> void:
	var harvest := HarvestMap.new()
	var cells: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(14, 1)]
	harvest.setup_from_natural_cells(cells)
	expect(harvest.tree_cells() == cells, "tree list matches grove cells in order")
	expect(harvest.has_tree(Vector2i(2, 2)) and not harvest.has_tree(Vector2i(8, 13)), "has_tree is standing grove only")
	expect(harvest.nearest_standing_tree(Vector2i(3, 2)) == Vector2i(2, 2), "nearest standing tree is the closest grove cell")
	expect(harvest.harvest(Vector2i(2, 2)), "first harvest of a standing tree succeeds")
	expect(harvest.is_harvested(Vector2i(2, 2)) and not harvest.has_tree(Vector2i(2, 2)), "harvested cell becomes a stump site")
	expect(not harvest.harvest(Vector2i(2, 2)), "second harvest of the same cell fails")
	expect(not harvest.harvest(Vector2i(9, 9)), "harvest of a non-tree cell fails")
	expect(harvest.nearest_standing_tree(Vector2i(3, 2)) == Vector2i(1, 2), "nearest skips harvested stumps")
	harvest.harvest(Vector2i(1, 2))
	harvest.harvest(Vector2i(14, 1))
	expect(harvest.nearest_standing_tree(Vector2i(0, 0)) == Vector2i(-1, -1), "no standing tree returns (-1,-1)")
	var sim := Sim.new()
	sim.setup()
	var from_sim := HarvestMap.new()
	from_sim.setup_from_natural_cells(sim.natural_cells)
	var grove: Array[Vector2i] = from_sim.tree_cells()
	var same_grove := grove.size() == sim.natural_cells.size()
	if same_grove:
		for i in range(grove.size()):
			if grove[i] != sim.natural_cells[i]:
				same_grove = false
				break
	expect(same_grove and grove.size() > 0, "harvest map uses the same natural grove cells")

func _test_grove_stumps() -> void:
	var sim := Sim.new()
	sim.setup()
	var terrain: Node3D = Terrain.new()
	root.add_child(terrain)
	terrain.setup(sim)
	var cell: Vector2i = sim.natural_cells[0]
	expect(terrain.harvest_map.has_tree(cell), "terrain binds a harvest map to the grove")
	var before: Node3D = terrain.grove_nodes[cell]
	var origin: Vector3 = before.position
	expect(before.get_meta("environment_kind") != "stump", "grove starts as a standing tree")
	expect(terrain.harvest_map.harvest(cell), "presentation harvest hook chops a grove cell")
	terrain.sync()
	var after: Node3D = terrain.grove_nodes[cell]
	expect(after.get_meta("environment_kind") == "stump", "chopped grove cell renders as a stump")
	expect(after.position.is_equal_approx(origin), "stump keeps the original grove transform")
	terrain.free()

func _test_sawmill_mesh() -> void:
	expect(Civil.KINDS.has("sawmill"), "sawmill is a civil kind")
	var model: Node3D = Civil.building("sawmill")
	expect(model != null and model.get_node_or_null("Architecture") != null, "building(sawmill) returns a 3D mesh")
	expect(model.get_meta("catalog_id") == "bld_07_serraria", "sawmill keeps catalog id")
	expect(model.get_meta("footprint_cells") == 2, "sawmill uses a 2x2 production hut footprint")
	var bounds: AABB = model.get_node("Architecture").mesh.get_aabb()
	expect(bounds.position.y >= -0.02 and bounds.size.x < 5.0 and bounds.size.z < 5.0, "sawmill stays on a 4.7m lot")
	model.free()

func _test_site_fence() -> void:
	var sim := Sim.new()
	sim.setup()
	var world: Node3D = World.new()
	world.sim = sim
	var planned := {"kind": "house", "cell": Vector2i(16, 17), "entrance": Vector2i(16, 19), "stage": "preparing", "progress": 0.0, "delivered": {"wood": 0, "stone": 0}}
	var site: Node3D = world._construction(-1, planned)
	expect(site.get_node_or_null("SitePalisade") != null, "preparing site shows a wooden palisade")
	expect(site.get_node_or_null("EntranceFlag") != null, "preparing site shows an entrance flag")
	var rising: Node3D = world._construction(1, planned)
	expect(rising.find_child("Architecture", true, false) != null, "building stage keeps the rising mesh")
	site.free()
	rising.free()
	world.free()

func _test_harvest_persist() -> void:
	var sim := Sim.new()
	sim.setup()
	var cell: Vector2i = sim.natural_cells[0]
	expect(sim.harvest_map.harvest(cell), "chop before save")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	expect(saved.has("harvested_cells") and not saved.harvested_cells.is_empty(), "snapshot records harvested grove cells")
	var restored := Sim.new()
	restored.setup()
	expect(restored.restore(saved), "restore save with harvested grove")
	expect(restored.harvest_map.is_harvested(cell) and not restored.harvest_map.has_tree(cell), "restored sim keeps stump cells")
	var terrain: Node3D = Terrain.new()
	root.add_child(terrain)
	terrain.setup(restored)
	terrain.sync()
	expect(terrain.grove_nodes[cell].get_meta("environment_kind") == "stump", "restored grove shows a stump")
	terrain.free()
	var legacy := Sim.new()
	legacy.setup()
	var old: Dictionary = JSON.parse_string(JSON.stringify(legacy.snapshot()))
	old.erase("harvested_cells")
	expect(legacy.restore(old), "old saves without harvested_cells still load")

func _test_dedicated_meshes() -> void:
	var house: Node3D = Civil.building("house")
	var lumber: Node3D = Civil.building("lumber")
	for kind in ["inn", "mill", "bakery", "workshop", "barracks"]:
		expect(Civil.KINDS.has(kind), kind + " is a civil kind")
		var model: Node3D = Civil.building(kind)
		expect(model != null and model.get_node_or_null("Architecture") != null, "building(" + kind + ") returns a 3D mesh")
		expect(model.get_meta("catalog_id") == Civil.IDS[kind], kind + " keeps catalog id")
		expect(model.get_meta("footprint_cells") == 2, kind + " uses a 2x2 lot")
		var bounds: AABB = model.get_node("Architecture").mesh.get_aabb()
		expect(bounds.position.y >= -0.02 and bounds.size.x < 5.0 and bounds.size.z < 5.0, kind + " stays on a 4.7m lot")
		expect(model.get_node("Architecture").mesh != house.get_node("Architecture").mesh, kind + " is not a reused house mesh")
		if kind == "mill":
			expect(model.get_node("Architecture").mesh != lumber.get_node("Architecture").mesh, "mill is not a reused lumber mesh")
			expect(bounds.size.y > lumber.get_node("Architecture").mesh.get_aabb().size.y, "mill tower is taller than the woodcutter hut")
		model.free()
	house.free()
	lumber.free()

func _test_chop_duration() -> void:
	var sim := Sim.new()
	sim.setup()
	var tree: Vector2i = sim.harvest_map.nearest_standing_tree(Vector2i(3, 18))
	expect(tree != Vector2i(-1, -1), "grove has a standing tree near the woodcutter lot")
	var placed: Dictionary = sim.command("build", {"kind": "lumber", "cell": Vector2i(3, 18)})
	expect(placed.ok, "woodcutter hut places for chop duration: " + str(placed.get("message", "")))
	var hut: Dictionary = sim.buildings.back()
	hut.stage = "complete"
	hut.progress = 1.0
	var stand: Vector2i = sim._tree_stand_cell(tree)
	expect(stand.x >= 0, "tree has a walkable stand cell")
	var worker: Dictionary = sim.workers[0]
	worker.role = "lumberjack"
	worker.meal = 80
	worker.route = []
	worker.cell = stand
	worker.goal = stand
	worker.task = {"type": "harvest", "building": hut.id, "tree": tree}
	sim._chop_tree(worker, hut)
	expect(sim.harvest_map.has_tree(tree), "first chop tick does not fell the tree")
	expect(str(worker.state).contains("Cort"), "woodcutter is facing the work of chopping")
	var felled := false
	for i in range(80):
		sim._chop_tree(worker, hut)
		if sim.harvest_map.is_harvested(tree):
			felled = true
			break
	expect(felled, "tree falls after a chopping duration")

func _test_chop_facing() -> void:
	var sim := Sim.new()
	sim.setup()
	var tree: Vector2i = sim.harvest_map.nearest_standing_tree(Vector2i(3, 18))
	var stand: Vector2i = sim._tree_stand_cell(tree)
	var worker: Dictionary = sim.workers[0]
	worker.role = "lumberjack"
	worker.route = []
	worker.cell = stand
	worker.goal = stand
	worker.task = {"type": "harvest", "building": 1, "tree": tree}
	worker.state = "Cortando árvore"
	worker.cargo = {}
	var world: Node3D = World.new()
	root.add_child(world)
	world.setup(sim)
	world.sync(0.2)
	var actor: Node3D = world.people[worker.id]
	var toward := Vector2(tree.x - stand.x, tree.y - stand.y)
	var expected: float = atan2(-toward.x, -toward.y)
	expect(absf(angle_difference(actor.rotation.y, expected)) < 0.35, "woodcutter faces the tree while chopping")
	world.free()
