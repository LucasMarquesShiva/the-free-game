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
