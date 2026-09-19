extends RefCounted
## Deterministic description of the large playable map, shared by the
## simulation (walkability, forests) and the presentation (chunk streaming).
##
## Everything here is a pure function of a cell coordinate, so any chunk of the
## world can be regenerated on demand, on any thread, and always comes out the
## same. The original 36x28 valley keeps its hand-authored groves; the rest of
## the map is filled with procedural forests.
##
## The cached mask/arrays are built once (ensure_built) on the main thread
## before any worker thread reads them; after that they are read-only.

const CELL := 2.5
## Playable area in cells: [position, end). The original valley sits at 0..36 x 0..28.
const MAP := Rect2i(-56, -40, 160, 120)
const AUTHORED_ZONE := Rect2i(0, 0, 36, 28)
const AUTHORED_GROVES := [Rect2i(1,2,3,7), Rect2i(1,18,2,8), Rect2i(14,1,7,3), Rect2i(27,2,7,5), Rect2i(2,9,2,3), Rect2i(19,9,2,3), Rect2i(14,23,3,3)]
const RIVER_X0 := 22
const RIVER_X1 := 24
const BRIDGE_Y0 := 13
const BRIDGE_Y1 := 15
const CHUNK_CELLS := 16
## "No cell" sentinel for pointer/highlight state. (-1,-1) is a real cell on this map.
const NO_CELL := Vector2i(-99999, -99999)
const FOREST_SEED := 917
## Bits of the terrain mask.
const TREE := 1
const RIVER := 2
const EDGE := 4

static var _mask := PackedByteArray()
static var _natural_cells: Array[Vector2i] = []
static var _blocked_cells: Array[Vector2i] = []


static func interior() -> Rect2i:
	return MAP.grow(-1)


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_CELLS), floori(float(cell.y) / CHUNK_CELLS))


static func is_no_cell(cell: Vector2i) -> bool:
	return cell.x < -90000


static func in_map(cell: Vector2i) -> bool:
	return MAP.has_point(cell)


static func is_river(cell: Vector2i) -> bool:
	return cell.x >= RIVER_X0 and cell.x <= RIVER_X1 and (cell.y < BRIDGE_Y0 or cell.y > BRIDGE_Y1)


static func is_authored_grove(cell: Vector2i) -> bool:
	for area: Rect2i in AUTHORED_GROVES:
		if area.has_point(cell):
			return true
	return false


static func _hash(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0xffff
	return float(h) / 65535.0


static func _value_noise(x: float, y: float, period: float, salt: int) -> float:
	var fx := x / period
	var fy := y / period
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(ix, iy, salt)
	var b := _hash(ix + 1, iy, salt)
	var c := _hash(ix, iy + 1, salt)
	var d := _hash(ix + 1, iy + 1, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Procedural forest outside the authored valley. Leaves a wide clear margin
## around the valley and along the river banks so there is always room to build.
static func forest_cell(cell: Vector2i) -> bool:
	if AUTHORED_ZONE.grow(6).has_point(cell):
		return false
	if cell.x >= RIVER_X0 - 3 and cell.x <= RIVER_X1 + 3:
		return false
	var mask := 0.62 * _value_noise(cell.x, cell.y, 16.0, FOREST_SEED) + 0.38 * _value_noise(cell.x, cell.y, 7.0, FOREST_SEED + 1)
	var density := smoothstep(0.56, 0.72, mask)
	return density > 0.0 and _hash(cell.x, cell.y, FOREST_SEED + 2) < density * 0.85


## Any standing-tree cell, without the cache (safe anywhere, slower).
static func natural_uncached(cell: Vector2i) -> bool:
	if not interior().has_point(cell):
		return false
	if AUTHORED_ZONE.has_point(cell):
		return is_authored_grove(cell)
	return forest_cell(cell)


## Value-noise lattice for one octave, covering the whole map, so building the
## mask does not re-hash the four corners of every cell. Same math as _value_noise.
static func _lattice(period: float, salt: int) -> Dictionary:
	var ix0 := floori(float(MAP.position.x) / period) - 1
	var iy0 := floori(float(MAP.position.y) / period) - 1
	var ix1 := floori(float(MAP.end.x) / period) + 2
	var iy1 := floori(float(MAP.end.y) / period) + 2
	var width := ix1 - ix0 + 1
	var values := PackedFloat32Array()
	values.resize(width * (iy1 - iy0 + 1))
	for iy in range(iy0, iy1 + 1):
		for ix in range(ix0, ix1 + 1):
			values[(iy - iy0) * width + (ix - ix0)] = _hash(ix, iy, salt)
	return {"ix0": ix0, "iy0": iy0, "width": width, "values": values, "period": period}


static func _lattice_noise(lat: Dictionary, x: int, y: int) -> float:
	var period: float = lat.period
	var fx := float(x) / period
	var fy := float(y) / period
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var values: PackedFloat32Array = lat.values
	var i: int = (iy - int(lat.iy0)) * int(lat.width) + (ix - int(lat.ix0))
	var w: int = lat.width
	return lerpf(lerpf(values[i], values[i + 1], tx), lerpf(values[i + w], values[i + w + 1], tx), ty)


static func ensure_built() -> void:
	if not _mask.is_empty():
		return
	var size := MAP.size
	_mask.resize(size.x * size.y)
	_mask.fill(0)
	var inner := interior()
	var coarse := _lattice(16.0, FOREST_SEED)
	var fine := _lattice(7.0, FOREST_SEED + 1)
	var clear_zone := AUTHORED_ZONE.grow(6)
	_natural_cells.clear()
	_blocked_cells.clear()
	# Authored groves first, in their original order, so index 0 stays stable.
	for area: Rect2i in AUTHORED_GROVES:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				_natural_cells.append(Vector2i(x, y))
	var authored := _natural_cells.size()
	for y in range(size.y):
		var wy := MAP.position.y + y
		var row := y * size.x
		for x in range(size.x):
			var wx := MAP.position.x + x
			var bits := 0
			if wx < inner.position.x or wy < inner.position.y or wx >= inner.end.x or wy >= inner.end.y:
				bits = EDGE
			elif wx >= RIVER_X0 and wx <= RIVER_X1 and (wy < BRIDGE_Y0 or wy > BRIDGE_Y1):
				bits = RIVER
			elif AUTHORED_ZONE.has_point(Vector2i(wx, wy)):
				if is_authored_grove(Vector2i(wx, wy)):
					bits = TREE
			elif not clear_zone.has_point(Vector2i(wx, wy)) and (wx < RIVER_X0 - 3 or wx > RIVER_X1 + 3):
				var mask := 0.62 * _lattice_noise(coarse, wx, wy) + 0.38 * _lattice_noise(fine, wx, wy)
				var density := smoothstep(0.56, 0.72, mask)
				if density > 0.0 and _hash(wx, wy, FOREST_SEED + 2) < density * 0.85:
					bits = TREE
					_natural_cells.append(Vector2i(wx, wy))
			_mask[row + x] = bits
			if bits != 0 and bits != EDGE:
				_blocked_cells.append(Vector2i(wx, wy))
	assert(_natural_cells.size() >= authored)


static func mask_at(cell: Vector2i) -> int:
	if not MAP.has_point(cell):
		return EDGE
	return _mask[(cell.y - MAP.position.y) * MAP.size.x + (cell.x - MAP.position.x)]


## True where a person or building can never stand (trees, river, map edge).
static func terrain_blocked(cell: Vector2i) -> bool:
	return mask_at(cell) != 0


static func is_natural(cell: Vector2i) -> bool:
	return (mask_at(cell) & TREE) != 0


static func natural_cells() -> Array[Vector2i]:
	ensure_built()
	return _natural_cells


## Blocked cells strictly inside the map border (trees + river).
static func blocked_cells() -> Array[Vector2i]:
	ensure_built()
	return _blocked_cells


static func natural_in_chunk(chunk: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := chunk * CHUNK_CELLS
	for y in range(origin.y, origin.y + CHUNK_CELLS):
		for x in range(origin.x, origin.x + CHUNK_CELLS):
			var cell := Vector2i(x, y)
			if is_natural(cell):
				result.append(cell)
	return result
