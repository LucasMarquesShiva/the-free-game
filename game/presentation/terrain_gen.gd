extends RefCounted
## Pure, thread-safe generation of one terrain chunk (40x40 m = 16x16 cells).
##
## Everything returned is plain data (packed arrays / dictionaries) so it can be
## produced on a worker thread and turned into nodes on the main thread. The
## output for a chunk depends only on the chunk key, the params and the shared
## WorldMap, so a chunk that is unloaded and streamed back in is identical.

const WorldMap := preload("res://core/world_map.gd")

const CELL := 2.5
const CHUNK_WORLD := WorldMap.CHUNK_CELLS * CELL
## Ground samples: 32 quads per chunk on non-flat chunks, 16 on flat ones.
const FINE_STRIDE := 1.25
const FINE_QUADS := 32
const COARSE_QUADS := 16
const RIVER_CENTER := 57.5
## Decorative (unreachable) scenery around the playable area.
const SCENERY_TREES_PER_CHUNK := 34
const SCENERY_ROCKS_PER_CHUNK := 7
const SCENERY_REACH := 90.0
const GRASS_REACH := 12.0
const GRASS_TILES := 4
const NOISE_SEED := 32
const NOISE_FREQUENCY := 0.032

const KIND_OAK := 0
const KIND_PINE := 1
const KIND_STUMP := 2
const KIND_ROCK := 3


static func make_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = NOISE_SEED
	noise.frequency = NOISE_FREQUENCY
	return noise


## World-space rectangle whose outside is "off the playable map" (hills start there).
static func play_rect() -> Rect2:
	return Rect2(Vector2(WorldMap.MAP.position) * CELL, Vector2(WorldMap.MAP.size - Vector2i.ONE) * CELL)


static func river_center(z: float) -> float:
	return RIVER_CENTER + sin(z * 0.065) * 0.3 + sin(z * 0.31) * 0.13


static func river_half_width(z: float) -> float:
	return 2.22 + sin(z * 0.17) * 0.25 + sin(z * 0.47) * 0.12


## Distance outside the playable rectangle (negative inside).
static func border_distance(x: float, z: float) -> float:
	var rect := play_rect()
	return maxf(maxf(rect.position.x - x, x - rect.end.x), maxf(rect.position.y - z, z - rect.end.y))


static func height_at(x: float, z: float, noise: FastNoiseLite) -> float:
	var border := border_distance(x, z)
	var hills := 0.0
	if border > -2.0:
		hills = smoothstep(-2.0, 15.0, border) * (1.5 + noise.get_noise_2d(x * 1.3, z * 1.3) * 4.5)
	var bank := 1.0 - smoothstep(river_half_width(z), river_half_width(z) + 2.0, absf(x - river_center(z)))
	return hills - bank * 1.4


## True when the whole rectangle is dead flat (height exactly zero): well inside
## the map and clear of the river and its banks. Lets those chunks skip noise
## sampling entirely and use a coarse mesh.
static func region_is_flat(min_x: float, min_z: float, max_x: float, max_z: float) -> bool:
	var rect := play_rect().grow(-4.0)
	if min_x < rect.position.x or min_z < rect.position.y or max_x > rect.end.x or max_z > rect.end.y:
		return false
	return max_x < RIVER_CENTER - 8.0 or min_x > RIVER_CENTER + 8.0


static func _hash_chunk(chunk: Vector2i, salt: int) -> int:
	return ((chunk.x * 73856093) ^ (chunk.y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


static func _cell_hash(cell: Vector2i, salt: int) -> int:
	return ((cell.x * 374761393) ^ (cell.y * 668265263) ^ (salt * 2147483647)) & 0x7fffffff


## Builds the complete chunk description. `params`: grass_density (tufts per m^2).
static func generate(chunk: Vector2i, params: Dictionary) -> Dictionary:
	var noise := make_noise()
	var origin := Vector2(chunk) * CHUNK_WORLD
	var result := {"chunk": chunk, "origin": origin}
	result.ground = _ground(origin, noise)
	result.grass = _grass(chunk, origin, noise, float(params.get("grass_density", 0.9)))
	result.trees = _trees(chunk, origin, noise)
	result.rocks = _rocks(chunk, origin, noise)
	return result


static func _ground(origin: Vector2, noise: FastNoiseLite) -> Dictionary:
	var flat := region_is_flat(origin.x, origin.y, origin.x + CHUNK_WORLD, origin.y + CHUNK_WORLD)
	var quads := COARSE_QUADS if flat else FINE_QUADS
	var stride := CHUNK_WORLD / quads
	var n := quads + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var min_y := 0.0
	var max_y := 0.0
	if not flat:
		# One-sample padding gives smooth normals that match across chunk seams.
		var padded := PackedFloat32Array()
		var pn := n + 2
		padded.resize(pn * pn)
		for iz in range(pn):
			for ix in range(pn):
				padded[iz * pn + ix] = height_at(origin.x + (ix - 1) * stride, origin.y + (iz - 1) * stride, noise)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for iz in range(n):
			for ix in range(n):
				var h := padded[(iz + 1) * pn + ix + 1]
				heights[iz * n + ix] = h
				min_y = minf(min_y, h)
				max_y = maxf(max_y, h)
				var hx := padded[(iz + 1) * pn + ix] - padded[(iz + 1) * pn + ix + 2]
				var hz := padded[iz * pn + ix + 1] - padded[(iz + 2) * pn + ix + 1]
				st.set_normal(Vector3(hx, 2.0 * stride, hz).normalized())
				st.set_uv(Vector2(origin.x + ix * stride, origin.y + iz * stride) * 0.1)
				st.add_vertex(Vector3(ix * stride, h, iz * stride))
		# Same diagonal as ground_surface_height(): a-b-c then a-c-d.
		for iz in range(quads):
			for ix in range(quads):
				var a := iz * n + ix
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(a + n + 1)
				st.add_index(a)
				st.add_index(a + n + 1)
				st.add_index(a + n)
		st.generate_tangents()
		return {"flat": false, "arrays": st.commit_to_arrays(), "min_y": min_y, "max_y": max_y}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(n):
		for ix in range(n):
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(origin.x + ix * stride, origin.y + iz * stride) * 0.1)
			st.add_vertex(Vector3(ix * stride, 0.0, iz * stride))
	for iz in range(quads):
		for ix in range(quads):
			var a := iz * n + ix
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_tangents()
	return {"flat": true, "arrays": st.commit_to_arrays(), "min_y": 0.0, "max_y": 0.0}


## Tufts, grouped into GRASS_TILES x GRASS_TILES sub-tiles of the chunk. Each tile
## becomes its own MultiMesh so the renderer can frustum-cull at ~10 m instead of
## drawing a whole 40 m chunk when only a corner is on screen. Buffers are ready
## to upload (12 transform + 4 colour floats per tuft).
static func _grass(chunk: Vector2i, origin: Vector2, noise: FastNoiseLite, density: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_chunk(chunk, 4051)
	var count := int(CHUNK_WORLD * CHUNK_WORLD * density)
	var flat := region_is_flat(origin.x, origin.y, origin.x + CHUNK_WORLD, origin.y + CHUNK_WORLD)
	var tile_size := CHUNK_WORLD / GRASS_TILES
	var buffers: Array = []
	var positions: Array = []
	var counts: Array = []
	for t in range(GRASS_TILES * GRASS_TILES):
		var empty_buffer := PackedFloat32Array()
		buffers.append(empty_buffer)
		positions.append(PackedVector3Array())
		counts.append(0)
	for i in range(count):
		# Fixed number of draws per attempt keeps the sequence stable.
		var x := origin.x + rng.randf() * CHUNK_WORLD
		var z := origin.y + rng.randf() * CHUNK_WORLD
		var scale_value := rng.randf_range(0.65, 1.5)
		var angle := rng.randf() * TAU
		var h := 0.0
		# The river band (cells 22..24) never has grass, as before.
		if x >= 53.75 and x < 61.25:
			continue
		if not flat:
			if border_distance(x, z) > GRASS_REACH:
				continue
			h = height_at(x, z, noise)
			if h < -0.35:
				continue
		var tile := mini(int((x - origin.x) / tile_size), GRASS_TILES - 1) + GRASS_TILES * mini(int((z - origin.y) / tile_size), GRASS_TILES - 1)
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_value)
		var tile_origin := Vector2(origin.x + (tile % GRASS_TILES) * tile_size, origin.y + (tile / GRASS_TILES) * tile_size)
		buffers[tile].append_array(PackedFloat32Array([
			basis.x.x, basis.y.x, basis.z.x, x - tile_origin.x,
			basis.x.y, basis.y.y, basis.z.y, h + 0.005,
			basis.x.z, basis.y.z, basis.z.z, z - tile_origin.y,
			0.85 + scale_value * 0.1, 0.86 + scale_value * 0.08, 0.9, 1.0]))
		positions[tile].append(Vector3(x, h + 0.005, z))
		counts[tile] += 1
	var tiles: Array = []
	for t in range(GRASS_TILES * GRASS_TILES):
		if counts[t] > 0:
			tiles.append({"index": t, "count": counts[t], "buffer": buffers[t], "positions": positions[t]})
	return {"tiles": tiles, "tile_size": tile_size}


static func _tree_kind(seed_value: int) -> Vector2i:
	## (kind, variant) for a natural tree seed, matching the original mapping.
	var family := posmod(seed_value, 17)
	if family == 0:
		return Vector2i(KIND_STUMP, posmod(seed_value, 3))
	if family <= 4:
		return Vector2i(KIND_OAK, posmod(seed_value, 3))
	return Vector2i(KIND_PINE, posmod(seed_value, 6))


## Trees: every natural (harvestable) cell of the chunk plus decorative
## scenery outside the playable area. Records are plain dictionaries.
static func _trees(chunk: Vector2i, origin: Vector2, noise: FastNoiseLite) -> Array:
	var records: Array = []
	for cell in WorldMap.natural_in_chunk(chunk):
		var seed_value := cell.x * 71 + cell.y * 97
		var kv := _tree_kind(seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = _cell_hash(cell, 88)
		var x := cell.x * CELL + rng.randf_range(-0.24, 0.24)
		var z := cell.y * CELL + rng.randf_range(-0.24, 0.24)
		records.append({
			"cell": cell, "natural": true, "kind": kv.x, "variant": kv.y, "seed": seed_value,
			"pos": Vector3(x, height_at(cell.x * CELL, cell.y * CELL, noise), z),
			"yaw": rng.randf() * TAU, "scale": rng.randf_range(0.78, 1.12),
		})
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_chunk(chunk, 7717)
	for i in range(SCENERY_TREES_PER_CHUNK):
		var x := origin.x + rng.randf() * CHUNK_WORLD
		var z := origin.y + rng.randf() * CHUNK_WORLD
		var yaw := rng.randf() * TAU
		var scale_value := rng.randf_range(0.8, 1.4)
		var seed_value := _hash_chunk(chunk, 91) % 100000 + i
		var border := border_distance(x, z)
		if border < 0.0 or border > SCENERY_REACH or absf(x - river_center(z)) < 5.1:
			continue
		var kv := _tree_kind(seed_value)
		if kv.x == KIND_STUMP:
			kv = Vector2i(KIND_PINE, posmod(seed_value, 6))
		records.append({
			"cell": Vector2i(-99999, -99999), "natural": false, "kind": kv.x, "variant": kv.y, "seed": seed_value,
			"pos": Vector3(x, height_at(x, z, noise), z), "yaw": yaw, "scale": scale_value,
		})
	return records


static func _rocks(chunk: Vector2i, origin: Vector2, noise: FastNoiseLite) -> Array:
	var records: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_chunk(chunk, 3319)
	for i in range(SCENERY_ROCKS_PER_CHUNK):
		var x := origin.x + rng.randf() * CHUNK_WORLD
		var z := origin.y + rng.randf() * CHUNK_WORLD
		var scale_value := rng.randf_range(0.3, 0.9)
		var variant := rng.randi() % 6
		var border := border_distance(x, z)
		if border < 0.0 or border > SCENERY_REACH or absf(x - river_center(z)) < 5.0:
			continue
		records.append({"kind": KIND_ROCK, "variant": variant, "pos": Vector3(x, height_at(x, z, noise), z), "yaw": rng.randf() * TAU, "scale": scale_value})
	return records
