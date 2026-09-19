extends Node3D
## Streams the terrain in 40x40 m chunks around the camera.
##
## Each chunk owns a ground mesh, one grass MultiMesh and one MultiMesh per tree/
## rock mesh, so a chunk costs a handful of draw calls and frustum-culls as a
## unit. Heavy work (noise, mesh arrays, transform buffers) runs on worker
## threads (terrain_gen.gd); the main thread only wraps finished arrays in
## resources, a couple of chunks per frame at most.

const Gen := preload("res://presentation/terrain_gen.gd")
const WorldMap := preload("res://core/world_map.gd")
const Models := preload("res://presentation/approved_environment.gd")
const Broadleaf := preload("res://presentation/approved_broadleaf.gd")
const Settings := preload("res://core/graphics_settings.gd")

const CELL := 2.5
const CHUNK_WORLD := Gen.CHUNK_WORLD
const MAX_JOBS := 3
const APPLY_BUDGET_USEC := 3000
## Tree mesh tiers by zoom (view_size): full detail, ~2k triangles, ~450 triangles.
const TIER_MID_FROM := 19.0
const TIER_FAR_FROM := 42.0
const TIER_HYSTERESIS := 2.0

class Chunk extends RefCounted:
	var key := Vector2i.ZERO
	var node: Node3D
	var ground: MeshInstance3D
	## One entry per non-empty grass sub-tile: {node, buffer, positions}.
	var grass_tiles: Array = []
	var trees: Array = []
	var rocks: Array = []
	var tree_nodes: Array[MultiMeshInstance3D] = []
	var rock_nodes: Array[MultiMeshInstance3D] = []

var terrain: Node3D
var chunks: Dictionary = {}
var _jobs: Dictionary = {}
var _finished: Array = []
var _occupied: Dictionary = {}
var _grass_density := 0.9
var _grass_mesh: ArrayMesh
var _grass_material: Material
var _ground_material: ShaderMaterial
var _tree_material: Material
var _mesh_cache: Dictionary = {}
var _tier := 1
var _view_size := 30.0
var _grass_fraction := 1.0
var _last_stream_key := Vector3(1e9, 1e9, 1e9)
var _since_restream := 1.0
var _need_more := false
var _focus := Vector3.ZERO
var stats := {"loaded": 0, "pending": 0, "applied_total": 0, "unloaded_total": 0}


func setup(owner_terrain: Node3D) -> void:
	terrain = owner_terrain
	name = "StreamedTerrain"
	WorldMap.ensure_built()
	var quality := Settings.high_quality()
	# Performance mode keeps roughly the density of the old 8000-tuft valley.
	_grass_density = 2.6 if quality else 0.9
	_build_materials(quality)
	_build_grass_mesh()
	_tier = _tier_for(30.0, 1)


func _build_materials(quality: bool) -> void:
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://assets/approved/terrain.gdshader")
	_ground_material.set_shader_parameter("meadow_tex", load("res://assets/approved/meadow-albedo.png"))
	_ground_material.set_shader_parameter("earth_tex", load("res://assets/approved/earth-albedo.png"))
	var flat_grass := StandardMaterial3D.new()
	flat_grass.albedo_color = Color("749048")
	flat_grass.vertex_color_use_as_albedo = true
	flat_grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	flat_grass.roughness = 1.0
	if quality:
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode cull_disabled; varying vec4 tint; void vertex(){tint=COLOR; vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.x+=sin(TIME*1.5+w.x*0.9+w.z*0.7)*VERTEX.y*0.12;} void fragment(){vec3 c=tint.rgb*vec3(0.31,0.43,0.18); ALBEDO=OUTPUT_IS_SRGB ? c : pow(c,vec3(2.2));ROUGHNESS=1.0;}"
		var animated := ShaderMaterial.new()
		animated.shader = shader
		_grass_material = animated
	else:
		# Wind sway costs a sin() per vertex per frame; the flat material does not.
		_grass_material = flat_grass


func _build_grass_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(6):
		var angle := blade * 2.39996
		var right := Vector3(cos(angle), 0, sin(angle)) * 0.017
		var base := Vector3(sin(angle * 3.0), 0, cos(angle * 3.0)) * 0.025
		var middle := base + Vector3(sin(angle) * 0.024, 0.085 + float(blade % 3) * 0.008, cos(angle) * 0.024)
		var tip := base + Vector3(sin(angle) * 0.07, 0.14 + float(blade % 3) * 0.021, cos(angle) * 0.07)
		var points := [base - right, base + right, middle + right * 0.52, base - right, middle + right * 0.52, middle - right * 0.52, middle - right * 0.52, middle + right * 0.52, tip]
		for point: Vector3 in points:
			st.set_color(Color(0.86, 0.91, 0.75).lerp(Color(1.04, 1.02, 0.95), point.y / 0.19))
			st.set_normal(Vector3.UP)
			st.add_vertex(point)
	_grass_mesh = st.commit()


# --- tree / rock meshes ------------------------------------------------------

func _tier_for(view_size: float, current: int) -> int:
	# Leaving a tier needs to overshoot its threshold a little, so zoom jitter
	# around a boundary does not swap meshes back and forth.
	if view_size >= TIER_FAR_FROM - (TIER_HYSTERESIS if current == 2 else 0.0):
		return 2
	if view_size >= TIER_MID_FROM - (TIER_HYSTERESIS if current >= 1 else 0.0):
		return 1
	return 0


func _source_node(kind: int, variant: int) -> Node3D:
	match kind:
		Gen.KIND_OAK:
			# Seeds whose family is an oak and whose variant is `variant`.
			return Broadleaf.tree([3, 1, 2][variant])
		Gen.KIND_PINE:
			return Broadleaf.tree([6, 7, 8, 9, 10, 5][variant])
		Gen.KIND_STUMP:
			return Models.stump(variant)
	return Models.rock(variant)


func _full_mesh(kind: int, variant: int) -> Mesh:
	var key := "full/%d/%d" % [kind, variant]
	if not _mesh_cache.has(key):
		var source := _source_node(kind, variant)
		var geometry: MeshInstance3D = source.get_node("Geometry")
		_mesh_cache[key] = geometry.mesh
		if _tree_material == null:
			_tree_material = geometry.material_override
		source.free()
	return _mesh_cache[key]


func mesh_for(kind: int, variant: int, tier: int) -> Mesh:
	if tier == 0 or kind == Gen.KIND_ROCK or kind == Gen.KIND_STUMP:
		return _full_mesh(kind, variant)
	var key := "t%d/%d/%d" % [tier, kind, variant]
	if not _mesh_cache.has(key):
		var path := "res://assets/approved/tree-lods/%s-%d-t%d.res" % ["oak" if kind == Gen.KIND_OAK else "pine", variant, tier]
		_mesh_cache[key] = load(path) if ResourceLoader.exists(path) else _full_mesh(kind, variant)
	return _mesh_cache[key]


func _material() -> Material:
	if _tree_material == null:
		_full_mesh(Gen.KIND_STUMP, 0)
	return _tree_material


# --- streaming --------------------------------------------------------------

func chunk_key_at(world_x: float, world_z: float) -> Vector2i:
	return Vector2i(floori(world_x / CHUNK_WORLD), floori(world_z / CHUNK_WORLD))


func _chunk_allowed(key: Vector2i) -> bool:
	var rect := Rect2(Vector2(key) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
	return rect.intersects(Gen.play_rect().grow(Gen.SCENERY_REACH))


func _wanted(focus: Vector3, view_size: float) -> Dictionary:
	var radius := view_size * 1.3 + 15.0 + CHUNK_WORLD * 0.75
	var lo := chunk_key_at(focus.x - radius, focus.z - radius)
	var hi := chunk_key_at(focus.x + radius, focus.z + radius)
	var result := {}
	var center := Vector2(focus.x, focus.z)
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cy)
			if not _chunk_allowed(key):
				continue
			var distance := ((Vector2(key) + Vector2(0.5, 0.5)) * CHUNK_WORLD).distance_to(center)
			if distance <= radius:
				result[key] = distance
	return result


## Per-frame entry point. Cheap unless the camera moved to another chunk/zoom.
func stream(focus: Vector3, view_size: float, delta: float) -> void:
	_since_restream += delta
	_view_size = view_size
	var focus_key := chunk_key_at(focus.x, focus.z)
	var zoom_bucket := roundi(view_size / 4.0)
	var probe := Vector3(focus_key.x, focus_key.y, zoom_bucket)
	_focus = focus
	if (probe != _last_stream_key and _since_restream >= 0.05) or (_need_more and _jobs.size() < MAX_JOBS and _since_restream >= 0.05):
		_since_restream = 0.0
		_last_stream_key = probe
		_request_and_unload(focus, view_size)
	_poll_jobs()
	_apply_finished()
	_update_lod(view_size)
	stats.loaded = chunks.size()
	stats.pending = _jobs.size() + _finished.size()


func _request_and_unload(focus: Vector3, view_size: float) -> void:
	var wanted := _wanted(focus, view_size)
	var keep_radius := view_size * 1.3 + 15.0 + CHUNK_WORLD * 2.25
	var center := Vector2(focus.x, focus.z)
	for key: Vector2i in chunks.keys():
		if not wanted.has(key) and ((Vector2(key) + Vector2(0.5, 0.5)) * CHUNK_WORLD).distance_to(center) > keep_radius:
			_unload(key)
	var missing: Array = []
	for key: Vector2i in wanted:
		if not chunks.has(key) and not _jobs.has(key):
			missing.append(key)
	missing.sort_custom(func(a, b): return wanted[a] < wanted[b])
	_need_more = false
	for key: Vector2i in missing:
		if _jobs.size() >= MAX_JOBS:
			_need_more = true
			break
		_launch(key)


func _launch(key: Vector2i) -> void:
	var job := {"result": null, "id": -1}
	var params := {"grass_density": _grass_density}
	job.id = WorkerThreadPool.add_task(func(): job.result = Gen.generate(key, params), false, "terrain chunk")
	_jobs[key] = job


func _poll_jobs() -> void:
	for key: Vector2i in _jobs.keys():
		var job: Dictionary = _jobs[key]
		if WorkerThreadPool.is_task_completed(job.id):
			WorkerThreadPool.wait_for_task_completion(job.id)
			_jobs.erase(key)
			_finished.append(job.result)


func _apply_finished() -> void:
	var start := Time.get_ticks_usec()
	while not _finished.is_empty():
		var result: Dictionary = _finished.pop_front()
		if not chunks.has(result.chunk):
			_apply(result)
			stats.applied_total += 1
		if Time.get_ticks_usec() - start > APPLY_BUDGET_USEC:
			break


## Blocks until everything around `focus` is loaded. Used once at startup so
## the first frame is complete; regular streaming never blocks.
func load_around(focus: Vector3, view_size: float) -> void:
	var wanted := _wanted(focus, view_size)
	var ordered: Array = wanted.keys()
	ordered.sort_custom(func(a, b): return wanted[a] < wanted[b])
	for key: Vector2i in ordered:
		if not chunks.has(key):
			_apply(Gen.generate(key, {"grass_density": _grass_density}))
	_last_stream_key = Vector3(chunk_key_at(focus.x, focus.z).x, chunk_key_at(focus.x, focus.z).y, roundi(view_size / 4.0))
	_update_lod(view_size)


func _unload(key: Vector2i) -> void:
	var chunk: Chunk = chunks[key]
	chunks.erase(key)
	chunk.node.free()
	stats.unloaded_total += 1


func _apply(result: Dictionary) -> void:
	var chunk := Chunk.new()
	chunk.key = result.chunk
	var origin: Vector2 = result.origin
	chunk.node = Node3D.new()
	chunk.node.name = "Chunk_%d_%d" % [chunk.key.x, chunk.key.y]
	chunk.node.position = Vector3(origin.x, 0.0, origin.y)
	# Ground
	var ground: Dictionary = result.ground
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ground.arrays)
	chunk.ground = MeshInstance3D.new()
	chunk.ground.name = "Ground"
	chunk.ground.mesh = mesh
	chunk.ground.material_override = _ground_material
	chunk.node.add_child(chunk.ground)
	var bounds := AABB(Vector3(-2.0, -4.0, -2.0), Vector3(CHUNK_WORLD + 4.0, 16.0, CHUNK_WORLD + 4.0))
	# Grass: one MultiMesh per 10 m sub-tile so culling is fine-grained.
	var grass: Dictionary = result.grass
	var tile_size: float = grass.tile_size
	for tile: Dictionary in grass.tiles:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _grass_mesh
		multi.instance_count = int(tile.count)
		multi.buffer = tile.buffer
		multi.custom_aabb = AABB(Vector3(-0.5, -4.0, -0.5), Vector3(tile_size + 1.0, 16.0, tile_size + 1.0))
		var instance := MultiMeshInstance3D.new()
		instance.name = "Grass"
		instance.multimesh = multi
		instance.material_override = _grass_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var index: int = tile.index
		instance.position = Vector3((index % Gen.GRASS_TILES) * tile_size, 0.0, (index / Gen.GRASS_TILES) * tile_size)
		chunk.node.add_child(instance)
		chunk.grass_tiles.append({"node": instance, "buffer": tile.buffer, "positions": tile.positions})
	chunk.trees = result.trees
	chunk.rocks = result.rocks
	chunks[chunk.key] = chunk
	add_child(chunk.node)
	_build_trees(chunk)
	_build_rocks(chunk)
	if not _occupied.is_empty():
		_apply_grass_mask(chunk)
	_apply_grass_fraction(chunk)


func _record_mesh_key(record: Dictionary) -> Vector2i:
	var kind: int = record.kind
	var variant: int = record.variant
	if bool(record.get("natural", false)) and terrain.harvest_map != null and terrain.harvest_map.is_harvested(record.cell):
		return Vector2i(Gen.KIND_STUMP, posmod(int(record.seed), 3))
	return Vector2i(kind, variant)


func _transform_buffer(records: Array, origin: Vector3) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(records.size() * 12)
	var i := 0
	for record: Dictionary in records:
		var pos: Vector3 = record.pos
		var basis := Basis(Vector3.UP, float(record.yaw)).scaled(Vector3.ONE * float(record.scale))
		buffer[i] = basis.x.x; buffer[i + 1] = basis.y.x; buffer[i + 2] = basis.z.x; buffer[i + 3] = pos.x - origin.x
		buffer[i + 4] = basis.x.y; buffer[i + 5] = basis.y.y; buffer[i + 6] = basis.z.y; buffer[i + 7] = pos.y
		buffer[i + 8] = basis.x.z; buffer[i + 9] = basis.y.z; buffer[i + 10] = basis.z.z; buffer[i + 11] = pos.z - origin.z
		i += 12
	return buffer


func _group_nodes(chunk: Chunk, records: Array, tier: int, into: Array[MultiMeshInstance3D], group_name: String) -> void:
	var groups: Dictionary = {}
	for record: Dictionary in records:
		var kv := _record_mesh_key(record)
		if not groups.has(kv):
			groups[kv] = []
		groups[kv].append(record)
	var origin := chunk.node.position
	var bounds := AABB(Vector3(-6.0, -4.0, -6.0), Vector3(CHUNK_WORLD + 12.0, 20.0, CHUNK_WORLD + 12.0))
	for kv: Vector2i in groups:
		var list: Array = groups[kv]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh_for(kv.x, kv.y, tier)
		multi.instance_count = list.size()
		multi.buffer = _transform_buffer(list, origin)
		multi.custom_aabb = bounds
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_%d_%d" % [group_name, kv.x, kv.y]
		instance.multimesh = multi
		instance.material_override = _material()
		instance.set_meta("kind", kv.x)
		instance.set_meta("variant", kv.y)
		chunk.node.add_child(instance)
		into.append(instance)


func _build_trees(chunk: Chunk) -> void:
	for existing in chunk.tree_nodes:
		existing.free()
	chunk.tree_nodes.clear()
	_group_nodes(chunk, chunk.trees, _tier, chunk.tree_nodes, "Trees")


func _build_rocks(chunk: Chunk) -> void:
	for existing in chunk.rock_nodes:
		existing.free()
	chunk.rock_nodes.clear()
	_group_nodes(chunk, chunk.rocks, 0, chunk.rock_nodes, "Rocks")


# --- level of detail ---------------------------------------------------------

func _update_lod(view_size: float) -> void:
	var tier := _tier_for(view_size, _tier)
	if tier != _tier:
		_tier = tier
		for chunk: Chunk in chunks.values():
			for instance in chunk.tree_nodes:
				var kind: int = instance.get_meta("kind")
				if kind == Gen.KIND_OAK or kind == Gen.KIND_PINE:
					instance.multimesh.mesh = mesh_for(kind, instance.get_meta("variant"), _tier)
	# Grass thins out as the view zooms out, and disappears when blades are subpixel.
	var fraction := 1.0
	if view_size > 52.0:
		fraction = 0.0
	elif view_size > 40.0:
		fraction = 0.35
	elif view_size > 32.0:
		fraction = 0.6
	if not is_equal_approx(fraction, _grass_fraction):
		_grass_fraction = fraction
		for chunk: Chunk in chunks.values():
			_apply_grass_fraction(chunk)


func _apply_grass_fraction(chunk: Chunk) -> void:
	for tile: Dictionary in chunk.grass_tiles:
		var instance: MultiMeshInstance3D = tile.node
		instance.visible = _grass_fraction > 0.0
		instance.multimesh.visible_instance_count = -1 if _grass_fraction >= 1.0 else int(instance.multimesh.instance_count * _grass_fraction)


# --- gameplay hooks ------------------------------------------------------------

## Trees whose standing/stump state changed. Only loaded chunks need work;
## chunks streamed in later read the harvest map when they are built.
func sync_harvest() -> void:
	var harvest: RefCounted = terrain.harvest_map
	if harvest == null:
		return
	var touched: Dictionary = {}
	for cell: Vector2i in harvest.take_changed_cells():
		touched[WorldMap.chunk_of(cell)] = true
	for key: Vector2i in touched:
		if chunks.has(key):
			_build_trees(chunks[key])


## Hides grass under buildings/roads/plaza. `occupied` is the full set of cells.
func sync_occupancy(occupied: Dictionary) -> void:
	var changed: Dictionary = {}
	for cell: Vector2i in occupied:
		if not _occupied.has(cell):
			changed[WorldMap.chunk_of(cell)] = true
	for cell: Vector2i in _occupied:
		if not occupied.has(cell):
			changed[WorldMap.chunk_of(cell)] = true
	_occupied = occupied
	for key: Vector2i in changed:
		if chunks.has(key):
			_apply_grass_mask(chunks[key])


func _apply_grass_mask(chunk: Chunk) -> void:
	for tile: Dictionary in chunk.grass_tiles:
		var buffer: PackedFloat32Array = tile.buffer
		var positions: PackedVector3Array = tile.positions
		var dirty := false
		for i in range(positions.size()):
			var p := positions[i]
			var hidden := _occupied.has(Vector2i(roundi(p.x / CELL), roundi(p.z / CELL)))
			var target := -10.0 if hidden else p.y
			if buffer[i * 16 + 7] != target:
				buffer[i * 16 + 7] = target
				dirty = true
		if dirty:
			tile.buffer = buffer
			tile.node.multimesh.buffer = buffer


## Test/inspection helper: what is drawn for a natural tree cell right now.
func tree_info_at(cell: Vector2i) -> Dictionary:
	var chunk: Chunk = chunks.get(WorldMap.chunk_of(cell))
	if chunk == null:
		return {}
	for record: Dictionary in chunk.trees:
		if bool(record.natural) and record.cell == cell:
			var kv := _record_mesh_key(record)
			return {"kind": ["oak", "pine", "stump"][kv.x], "variant": kv.y, "position": record.pos, "yaw": record.yaw, "scale": record.scale}
	return {}
