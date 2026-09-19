extends RefCounted
## Deterministic grove harvest state. Trees are chop targets; harvested cells become stumps.
## Presentation (approved_terrain.harvest_map) owns or shares this instance.
##
## Trees are bucketed by 16x16-cell chunk so a woodcutter looking for the nearest
## tree walks outward ring by ring and stops as soon as no farther ring can win,
## instead of scanning every tree on a map that can hold thousands.
##
## Sim wiring:
##   1. `sim.harvest_map = HarvestMap.new()` then `setup_from_natural_cells(natural_cells)`.
##   2. Woodcutter target: `harvest_map.nearest_standing_tree(worker.cell, reachable_callable)`.
##   3. On chop: `harvest_map.harvest(cell)`; presentation drains `take_changed_cells()`.

const CHUNK := 16
## Search radius in chunks (~130 cells). Beyond that there is simply no tree "nearby".
const MAX_RINGS := 8

var _cells: Array[Vector2i] = []
var _index: Dictionary = {}
var _buckets: Dictionary = {}
var _harvested: Dictionary = {}
var _changed: Array[Vector2i] = []
var revision: int = 0


static func _bucket_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


func setup_from_natural_cells(natural_cells: Array) -> void:
	_cells.clear()
	_index.clear()
	_buckets.clear()
	_harvested.clear()
	_changed.clear()
	revision = 0
	for item in natural_cells:
		var cell: Vector2i = item
		if _index.has(cell):
			continue
		_cells.append(cell)
		_index[cell] = true
		var bucket := _bucket_of(cell)
		if not _buckets.has(bucket):
			_buckets[bucket] = [] as Array[Vector2i]
		_buckets[bucket].append(cell)


func tree_cells() -> Array[Vector2i]:
	return _cells.duplicate()


func has_tree(cell: Vector2i) -> bool:
	return _index.has(cell) and not _harvested.has(cell)


## True for any tree site of this grove, standing or already a stump.
func is_tree_site(cell: Vector2i) -> bool:
	return _index.has(cell)


func harvest(cell: Vector2i) -> bool:
	if not has_tree(cell):
		return false
	_harvested[cell] = true
	_changed.append(cell)
	revision += 1
	return true


func is_harvested(cell: Vector2i) -> bool:
	return _harvested.has(cell)


## Cells whose standing/stump state changed since the last call.
func take_changed_cells() -> Array[Vector2i]:
	var result := _changed
	_changed = []
	return result


func _better(cell: Vector2i, d: int, best: Vector2i, best_d: int) -> bool:
	if best == Vector2i(-1, -1) or d < best_d:
		return true
	return d == best_d and (cell.x < best.x or (cell.x == best.x and cell.y < best.y))


## `is_reachable`, when given, filters out standing trees the worker cannot
## actually stand next to (e.g. every neighboring cell blocked by other trees
## in a dense grove) so the search falls through to the next-nearest tree
## instead of getting stuck retargeting the same unreachable one forever.
func nearest_standing_tree(from: Vector2i, is_reachable: Callable = Callable()) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	var home := _bucket_of(from)
	for ring in range(0, MAX_RINGS + 1):
		if ring > 1 and best != Vector2i(-1, -1):
			var nearest_possible := (ring - 1) * CHUNK + 1
			if nearest_possible * nearest_possible > best_d:
				break
		for offset_y in range(-ring, ring + 1):
			var edge_row := absi(offset_y) == ring
			var step := 1 if edge_row else maxi(1, 2 * ring)
			var offset_x := -ring
			while offset_x <= ring:
				var list: Variant = _buckets.get(Vector2i(home.x + offset_x, home.y + offset_y))
				if list != null:
					for cell: Vector2i in list:
						if _harvested.has(cell):
							continue
						var d: int = (cell.x - from.x) * (cell.x - from.x) + (cell.y - from.y) * (cell.y - from.y)
						if not _better(cell, d, best, best_d):
							continue
						if is_reachable.is_valid() and not is_reachable.call(cell):
							continue
						best_d = d
						best = cell
				offset_x += step
	return best


func harvested_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _harvested:
		cells.append(cell)
	return cells


func apply_harvested(cells: Array) -> void:
	var previous := _harvested
	_harvested = {}
	for item in cells:
		var cell: Vector2i = item
		if _index.has(cell):
			_harvested[cell] = true
	for cell: Vector2i in previous:
		if not _harvested.has(cell):
			_changed.append(cell)
	for cell: Vector2i in _harvested:
		if not previous.has(cell):
			_changed.append(cell)
	revision += 1
