extends Node3D
## Scene presentation only: never assigns tasks or mutates the simulation.

const Models = preload("res://presentation/model_factory.gd")
const CELL_SIZE: float = 2.0
const MAP_WIDTH: int = 36
const MAP_HEIGHT: int = 28

var camera: Camera3D
var _sim: RefCounted
var _building_nodes: Dictionary = {}
var _actor_nodes: Dictionary = {}
var _building_signatures: Dictionary = {}
var _cargo_signatures: Dictionary = {}
var _focus := Vector3(20, 0, 18)
var _time: float = 0.0
var _selected_id: int = -1
var _preview: Node3D
var _preview_kind: String = ""
var _preview_valid: bool = false
var _selection: Node3D
var _order_marker: Node3D
var _camp_banner: Node3D
var _entity_root: Node3D
var _terrain_root: Node3D
var _rng := RandomNumberGenerator.new()

func setup(sim: RefCounted) -> void:
	_sim = sim
	for child in get_children():
		child.free()
	_building_nodes.clear()
	_actor_nodes.clear()
	_building_signatures.clear()
	_cargo_signatures.clear()
	_rng.seed = 716042
	_terrain_root = Node3D.new()
	_terrain_root.name = "Landscape"
	add_child(_terrain_root)
	_entity_root = Node3D.new()
	_entity_root.name = "VillageAndCompanies"
	add_child(_entity_root)
	_make_lighting()
	_make_landscape()
	_make_bridge()
	_make_camp()
	_make_camera()
	_selection = _footprint_frame(Color("ead58c"), 4.06, 0.08)
	_selection.visible = false
	add_child(_selection)
	_order_marker = _make_order_marker()
	_order_marker.visible = false
	add_child(_order_marker)
	_preview = null
	_preview_kind = ""
	_selected_id = -1
	sync(1.0)

func _make_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b5c8b9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cbd9c6")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-52, -32, -12)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 0.58
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 142, 0)
	fill.light_color = Color("bcd7db")
	fill.light_energy = 0.08
	add_child(fill)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.name = "VillageCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.near = 0.1
	camera.far = 230.0
	camera.current = true
	add_child(camera)
	_position_camera()

func _position_camera() -> void:
	camera.position = _focus + Vector3(27, 43, 37)
	camera.look_at(_focus, Vector3.UP)

func _make_landscape() -> void:
	var grass := Color("799e61")
	# Every blocking feature follows the map contract; decorative trees live outside.
	Models.box(_terrain_root, Vector3(46.0, 0.80, 58.0), Vector3(20.0, -0.50, 27), grass)
	Models.box(_terrain_root, Vector3(24.0, 0.80, 58.0), Vector3(61.0, -0.50, 27), grass.darkened(0.025))
	Models.box(_terrain_root, Vector3(7.0, 0.23, 58.0), Vector3(46.0, -0.69, 27), Color("638f89"))
	# Soil strata around the raised playable land.
	Models.box(_terrain_root, Vector3(46.0, 0.40, 58.2), Vector3(20.0, -1.08, 27), Color("918664"))
	Models.box(_terrain_root, Vector3(24.0, 0.40, 58.2), Vector3(61.0, -1.08, 27), Color("918664"))
	var patches := Node3D.new()
	_terrain_root.add_child(patches)
	for i in range(125):
		var x: float = _rng.randf_range(-2.0, 71.0)
		var z: float = _rng.randf_range(-1.0, 55.0)
		if x > 42.0 and x < 50.0:
			continue
		var patch := Models.cylinder(patches, _rng.randf_range(0.45, 1.5), 0.018, Vector3(x, -0.082, z), grass.lightened(_rng.randf_range(-0.045, 0.055)), -1, 7)
		patch.scale.z = _rng.randf_range(0.45, 0.85)
	# Broad, understated merchant road makes the bridge and village axes readable.
	for x in range(2, 35):
		if x >= 22 and x <= 24:
			continue
		_path_tile(patches, Vector2i(x, 14), Color("b6ac7d"))
	for z in range(4, 24):
		_path_tile(patches, Vector2i(12, z), Color("b6ac7d"))
	Models.bake(patches)
	_make_water()
	_make_banks()
	var forest := Node3D.new()
	forest.name = "ForestOutsideWalkableLand"
	_terrain_root.add_child(forest)
	for i in range(66):
		var x: float
		var z: float
		match i % 4:
			0:
				x = _rng.randf_range(-8.0, -2.8)
				z = _rng.randf_range(-7.0, 59.0)
			1:
				x = _rng.randf_range(72.5, 78.0)
				z = _rng.randf_range(-7.0, 60.0)
			2:
				x = _rng.randf_range(-6.0, 76.0)
				z = _rng.randf_range(-8.0, -2.5)
			_:
				x = _rng.randf_range(-5.0, 76.0)
				z = _rng.randf_range(56.5, 62.0)
		if x > 42.0 and x < 50.0:
			continue
		var tree: Node3D = Models.make_tree(i)
		forest.add_child(tree)
		tree.position = Vector3(x, -0.12, z)
		tree.rotation.y = _rng.randf_range(0.0, TAU)
		tree.scale = Vector3.ONE * _rng.randf_range(0.82, 1.38)
	# Merge repeated static foliage while retaining material variation.
	Models.bake(forest)
	var rocks := Node3D.new()
	_terrain_root.add_child(rocks)
	for i in range(24):
		var x: float = _rng.randf_range(-3.0, 72.0)
		var z: float = -2.2 if i % 2 == 0 else 56.5
		if x > 42 and x < 50:
			continue
		var rock := Models.sphere(rocks, _rng.randf_range(0.40, 1.0), Vector3(x, 0.08, z), Color("a1a68c"))
		rock.scale = Vector3(1.45, 0.8, 1.1)
	Models.bake(rocks)

func _path_tile(parent: Node3D, cell: Vector2i, color: Color) -> void:
	Models.box(parent, Vector3(1.94, 0.035, 1.96), Vector3(cell.x * CELL_SIZE, -0.035, cell.y * CELL_SIZE), color)
	for j in range(2):
		var stone := Models.cylinder(parent, 0.17 + float(j) * 0.05, 0.027, Vector3(cell.x * CELL_SIZE + _rng.randf_range(-0.7, 0.7), -0.010, cell.y * CELL_SIZE + _rng.randf_range(-0.6, 0.6)), Color("c3bd94"), -1, 5)
		stone.scale.z = 0.7

func _make_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6.0, 68.0)
	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.position = Vector3(46.0, -0.25, 27)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; void fragment(){ float wave=sin(UV.y*115.0-TIME*1.9+sin(UV.x*20.0))*sin(UV.x*26.0+TIME*0.6); vec3 deep=vec3(0.22,0.48,0.50); vec3 light=vec3(0.37,0.65,0.63); ALBEDO=mix(deep,light,0.50+wave*0.22); ROUGHNESS=0.38; METALLIC=0.05; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	water.material_override = mat
	_terrain_root.add_child(water)

func _make_banks() -> void:
	var bank := Node3D.new()
	_terrain_root.add_child(bank)
	for z in range(-2, 59, 2):
		if z >= 24 and z <= 32:
			continue
		for x in [42.75, 49.25]:
			var rock := Models.sphere(bank, 0.47, Vector3(x, -0.10, z), Color("b2b6a0"))
			rock.scale = Vector3(0.65, 0.58, 1.40)
			if z % 6 == 0:
				for i in range(3):
					Models.beam(bank, Vector3(x, -0.04, z + i * 0.14), Vector3(x + 0.08, 0.68 + i * 0.13, z + i * 0.14), 0.035, Color("8d9f5d"))
	Models.bake(bank)

func _make_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "BridgeThreeCellsWide"
	_terrain_root.add_child(bridge)
	# Deck is almost at navigation-plane height, so nobody walks through it.
	for i in range(23):
		var x: float = 42.0 + float(i) * 0.36
		Models.box(bridge, Vector3(0.335, 0.15, 5.90), Vector3(x, -0.025, 28), Color("a58858").lightened(float(i % 3) * 0.025))
	for z in [24.91, 31.09]:
		for x in [42.0, 43.8, 45.6, 47.4, 49.2, 50.0]:
			Models.box(bridge, Vector3(0.18, 1.08, 0.18), Vector3(x, 0.50, z), Color("7d6240"))
		for y in [0.42, 0.93]:
			Models.box(bridge, Vector3(8.25, 0.11, 0.12), Vector3(46.0, y, z), Color("927344"))
		Models.box(bridge, Vector3(8.3, 0.30, 0.22), Vector3(46, -0.20, z), Color("755c3d"))
	Models.bake(bridge)

func _make_camp() -> void:
	var camp := Node3D.new()
	camp.name = "EnemyCamp"
	_terrain_root.add_child(camp)
	# Root reserves 2x2 terrain footprints at (32,20) and (28,20).
	# The palisade occupies the already blocked eastern map boundary.
	for i in range(26):
		Models.box(camp, Vector3(0.30, 1.1, 0.50), Vector3(70.15, 0.5, 24.0 + float(i) * 0.7), Color("92764a"))
	var tent := Node3D.new()
	camp.add_child(tent)
	tent.position = Vector3(65.0, 0.0, 41.0)
	Models.roof(tent, 2.3, 2.3, 0.14, 1.35, false)
	Models.box(tent, Vector3(0.06, 1.6, 0.06), Vector3(0, 0.8, 1.1), Color("674a30"))
	Models.box(camp, Vector3(3.7, 0.06, 3.7), Vector3(57, -0.015, 41), Color("b1a073"))
	Models.barrel(camp, Vector3(57.0, 0.0, 41.2))
	Models.barrel(camp, Vector3(57.7, 0.0, 41.2))
	Models.crate(camp, Vector3(56.4, 0.0, 40.5))
	Models.crate(camp, Vector3(57.1, 0.0, 40.5))
	Models.crate(camp, Vector3(56.4, 0.45, 40.5))
	Models.bake(camp)
	_camp_banner = Node3D.new()
	_camp_banner.position = _cell_position(Vector2i(30, 14)) + Vector3(0.70, 0, -0.55)
	Models.flag(_camp_banner, Vector3.ZERO, Color("a7504d"))
	add_child(_camp_banner)

func sync(delta: float) -> void:
	if _sim == null:
		return
	if not bool(_sim.get("paused")):
		_time += delta
	_sync_buildings()
	_sync_actors(delta)
	_sync_selection()
	var battle: RefCounted = _sim.get("battle")
	if battle != null:
		var target: Variant = battle.get("target")
		_order_marker.visible = target is Vector2i and str(battle.get("order")) != ""
		if _order_marker.visible:
			_order_marker.position = _cell_position(target) + Vector3(0, 0.045, 0)
			_order_marker.rotation.y = sin(_time * 0.9) * 0.06
		var captured: bool = bool(battle.get("captured"))
		if captured != bool(_camp_banner.get_meta("captured", false)):
			_camp_banner.set_meta("captured", captured)
			for child in _camp_banner.get_children():
				child.free()
			Models.flag(_camp_banner, Vector3.ZERO, Color("287a70") if captured else Color("a7504d"))

func _sync_buildings() -> void:
	var alive: Dictionary = {}
	var buildings: Array = _sim.get("buildings")
	for data: Dictionary in buildings:
		var id: int = int(data.get("id", -1))
		if str(data.get("stage", "")) == "cancelled":
			continue
		alive[id] = true
		var stage: String = str(data.get("stage", "preparing"))
		var progress: float = float(data.get("progress", 0.0))
		var bucket: int = 0 if progress <= 0.2 else (1 if progress <= 0.48 else (2 if progress <= 0.75 else 3))
		var signature: String = str(data.get("kind", "house")) + stage + str(bucket)
		if not _building_nodes.has(id) or _building_signatures.get(id, "") != signature:
			if _building_nodes.has(id):
				_building_nodes[id].free()
			var model: Node3D = Models.make_building(str(data.get("kind", "house"))) if stage == "complete" else Models.make_site(progress)
			model.name = "Building_%d" % id
			_entity_root.add_child(model)
			model.position = _cell_position(data.get("cell", Vector2i.ZERO)) + Vector3(1, 0, 1)
			_building_nodes[id] = model
			_building_signatures[id] = signature
			if stage != "complete":
				var label := Label3D.new()
				label.name = "Progress"
				label.font_size = 42
				label.pixel_size = 0.012
				label.position = Vector3(0, 3.05, 0)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.no_depth_test = false
				label.modulate = Color("fff4d5")
				label.outline_modulate = Color("314f40")
				label.outline_size = 8
				model.add_child(label)
		var existing: Node3D = _building_nodes[id]
		if stage != "complete":
			var label: Label3D = existing.get_node_or_null("Progress")
			if label != null:
				var stage_text: String = "Preparando" if stage == "preparing" else ("Materiais" if stage == "materials" else "Construindo")
				label.text = "%s · %d%%" % [stage_text, int(progress * 100.0)]
	for id: int in _building_nodes.keys():
		if not alive.has(id):
			_building_nodes[id].free()
			_building_nodes.erase(id)
			_building_signatures.erase(id)

func _sync_actors(delta: float) -> void:
	var alive: Dictionary = {}
	var workers: Array = _sim.get("workers")
	for worker: Dictionary in workers:
		var key: String = "civil_%s" % str(worker.get("id", 0))
		alive[key] = true
		_update_actor(key, worker, str(worker.get("role", "resident")), "ally", delta)
	var battle: RefCounted = _sim.get("battle")
	if battle != null:
		var units: Array = battle.get("units")
		for unit: Dictionary in units:
			var key: String = "soldier_%s" % str(unit.get("id", 0))
			alive[key] = true
			var actor: Node3D = _update_actor(key, unit, str(unit.get("role", "lancer")), str(unit.get("team", "ally")), delta)
			actor.visible = str(unit.get("team", "ally")) == "ally" or bool(unit.get("visible", false))
	for key: String in _actor_nodes.keys():
		if not alive.has(key):
			_actor_nodes[key].free()
			_actor_nodes.erase(key)
			_cargo_signatures.erase(key)

func _update_actor(key: String, data: Dictionary, role: String, team: String, delta: float) -> Node3D:
	var signature: String = role + team
	if _actor_nodes.has(key) and str(_actor_nodes[key].get_meta("signature", "")) != signature:
		_actor_nodes[key].free()
		_actor_nodes.erase(key)
		_cargo_signatures.erase(key)
	if not _actor_nodes.has(key):
		var fresh: Node3D = Models.make_actor(role, team, int(data.get("id", 0)))
		fresh.name = key
		fresh.set_meta("signature", signature)
		_entity_root.add_child(fresh)
		fresh.position = _cell_position(data.get("cell", Vector2i.ZERO))
		fresh.position.y = 0.06
		_actor_nodes[key] = fresh
	var actor: Node3D = _actor_nodes[key]
	var target: Vector3 = _cell_position(data.get("cell", Vector2i.ZERO)) + Vector3(0, 0.06, 0)
	var displacement: Vector3 = target - actor.position
	var moving: bool = Vector2(displacement.x, displacement.z).length() > 0.035
	actor.position = actor.position.lerp(target, minf(1.0, delta * 12.0))
	if moving:
		var target_angle: float = atan2(-displacement.x, -displacement.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, minf(1.0, delta * 15.0))
	var phase: float = _time * 11.5 + float(data.get("id", 0)) * 0.7
	var state: String = str(data.get("state", ""))
	var working: bool = state in ["working", "building", "preparing", "producing", "harvesting", "chopping", "mining", "gathering", "Construindo", "Preparando terreno", "Ensinando no centro"] or state.begins_with("Produzindo ")
	var dead: bool = int(data.get("hp", 1)) <= 0
	var cargo: Dictionary = data.get("cargo", {})
	var loaded: bool = not cargo.is_empty() and int(cargo.get("amount", 0)) > 0
	var leg_l: Node3D = actor.get_node("LegL")
	var leg_r: Node3D = actor.get_node("LegR")
	var arm_l: Node3D = actor.get_node("ArmL")
	var arm_r: Node3D = actor.get_node("ArmR")
	var body: Node3D = actor.get_node("Body")
	leg_l.rotation.x = sin(phase) * 0.57 if moving else 0.0
	leg_r.rotation.x = -leg_l.rotation.x
	body.position.y = absf(sin(phase)) * 0.035 if moving else sin(_time * 2.0) * 0.010
	arm_l.rotation.x = -sin(phase) * 0.40 if moving else 0.0
	arm_r.rotation.x = sin(phase) * 0.40 if moving else 0.0
	if loaded:
		arm_l.rotation.x = -0.95
		arm_r.rotation.x = -0.95
	elif working and not moving:
		arm_r.rotation.x = -0.7 + sin(phase * 0.8) * 0.65
		body.rotation.x = 0.10
	else:
		body.rotation.x = 0.0
	if (state in ["attacking", "firing", "shooting", "melee", "Protegendo a linha", "Arqueiros dando cobertura"] and int(data.get("cooldown", 0)) > 0) and not moving:
		arm_r.rotation.x = -1.1 + sin(phase * 1.2) * 0.50
		arm_l.rotation.x = -1.0 if role == "archer" else -0.2
	actor.rotation.z = lerpf(actor.rotation.z, PI * 0.48 if dead else 0.0, minf(1.0, delta * 5.0))
	if dead:
		leg_l.rotation.x = 0.1
		leg_r.rotation.x = -0.2
	_update_cargo(key, actor, cargo)
	return actor

func _update_cargo(key: String, actor: Node3D, cargo: Dictionary) -> void:
	var item: String = str(cargo.get("item", "")) if int(cargo.get("amount", 0)) > 0 else ""
	if _cargo_signatures.get(key, "") == item:
		return
	_cargo_signatures[key] = item
	var holder: Node3D = actor.get_node("Cargo")
	for child in holder.get_children():
		child.free()
	match item:
		"wine":
			Models.barrel(holder, Vector3(0, -0.20, 0), 0.70)
		"wood":
			var log := Models.cylinder(holder, 0.11, 0.75, Vector3.ZERO, Color("ae8654"))
			log.rotation.z = PI * 0.5
		"stone":
			Models.box(holder, Vector3(0.38, 0.28, 0.28), Vector3.ZERO, Color("aaa98f"))
		"grapes", "food":
			Models.cylinder(holder, 0.25, 0.22, Vector3.ZERO, Color("ae8853"), 0.30)
			for i in range(3):
				Models.sphere(holder, 0.11, Vector3(float(i - 1) * 0.15, 0.15, 0), Color("845979") if item == "grapes" else Color("83a15b"))
		_:
			pass
	if not item.is_empty():
		Models.bake(holder)

func _footprint_frame(color: Color, size: float, thickness: float) -> Node3D:
	var node := Node3D.new()
	for side in [-1.0, 1.0]:
		Models.box(node, Vector3(size, 0.06, thickness), Vector3(0, 0.02, side * size * 0.5), color)
		Models.box(node, Vector3(thickness, 0.06, size), Vector3(side * size * 0.5, 0.02, 0), color)
	Models.bake(node)
	return node

func _make_order_marker() -> Node3D:
	var node := Node3D.new()
	for side in [-1.0, 1.0]:
		var marker := Models.box(node, Vector3(0.15, 0.08, 0.85), Vector3(side * 0.29, 0.09, 0), Color("e8d796"))
		marker.rotation.y = side * 0.75
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 0.87
	ring.rings = 20
	ring.ring_segments = 6
	Models.piece(node, ring, Vector3(0, 0.035, 0), Color("e7d096"))
	return node

func _sync_selection() -> void:
	_selection.visible = _building_nodes.has(_selected_id)
	if _selection.visible:
		_selection.position = _building_nodes[_selected_id].position + Vector3(0, 0.04, 0)

func screen_to_cell(screen: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return Vector2i(-1, -1)
	return Vector2i(roundi(hit.x / CELL_SIZE), roundi(hit.z / CELL_SIZE))

func set_preview(kind: String, cell: Vector2i, valid: bool) -> void:
	if _preview == null or kind != _preview_kind or valid != _preview_valid:
		clear_preview()
		_preview_kind = kind
		_preview_valid = valid
		var tint := Color("70b49c") if valid else Color("c87564")
		_preview = _footprint_frame(tint, 3.94, 0.11)
		var ghost: Node3D = Models.make_building(kind)
		_preview.add_child(ghost)
		var ghost_material := StandardMaterial3D.new()
		ghost_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.35)
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for child: Node in ghost.get_children():
			if child is MeshInstance3D:
				child.material_override = ghost_material
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var entry := _make_order_marker()
		entry.position = Vector3(-1, 0.03, 3)
		_preview.add_child(entry)
		add_child(_preview)
	_preview.position = _cell_position(cell) + Vector3(1, 0.07, 1)

func clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	_preview_kind = ""

func focus_cell(cell: Vector2i) -> void:
	_focus = _cell_position(cell)
	_focus.x = clampf(_focus.x, 4.0, 66.0)
	_focus.z = clampf(_focus.z, 4.0, 50.0)
	_position_camera()

func zoom_by(amount: float) -> void:
	if camera == null:
		return
	camera.size = clampf(camera.size + amount, 17.0, 66.0)

func pan_by(delta: Vector2) -> void:
	if camera == null:
		return
	var screen_height: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var units_per_pixel: float = camera.size / screen_height
	var right: Vector3 = camera.global_basis.x
	var up_ground := Vector3(camera.global_basis.y.x, 0, camera.global_basis.y.z).normalized()
	_focus -= right * delta.x * units_per_pixel
	_focus += up_ground * delta.y * units_per_pixel * 1.55
	_focus.x = clampf(_focus.x, 3.0, 67.0)
	_focus.z = clampf(_focus.z, 3.0, 51.0)
	_position_camera()

func set_selected(id: int) -> void:
	_selected_id = id
	_sync_selection()

func _cell_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)
