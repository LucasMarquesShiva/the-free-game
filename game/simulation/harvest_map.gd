extends RefCounted
## Deterministic grove harvest state. Trees are chop targets; harvested cells become stumps.
## Presentation (approved_terrain.harvest_map) owns or shares this instance.
##
## Sim wiring (other agent — do not edit village_sim / approved_sim from this slice):
##   1. Before world.setup, optionally assign `sim.harvest_map = HarvestMap.new()`
##      then `sim.harvest_map.setup_from_natural_cells(natural_cells)`.
##      Terrain will bind that instance if present; otherwise it creates one.
##   2. Woodcutter target: `var cell := harvest_map.nearest_standing_tree(worker.cell)`.
##   3. On chop: `harvest_map.harvest(cell)` — `terrain.sync()` swaps the 3D tree for a stump.
##   4. Do not add HUD / definitions here. Sawmill placement stays a sim job.

var _cells: Array[Vector2i] = []
var _index: Dictionary = {}
var _harvested: Dictionary = {}
var revision: int = 0


func setup_from_natural_cells(natural_cells: Array) -> void:
	_cells.clear()
	_index.clear()
	_harvested.clear()
	revision = 0
	for item in natural_cells:
		var cell: Vector2i = item
		if _index.has(cell):
			continue
		_cells.append(cell)
		_index[cell] = true


func tree_cells() -> Array[Vector2i]:
	return _cells.duplicate()


func has_tree(cell: Vector2i) -> bool:
	return _index.has(cell) and not _harvested.has(cell)


func harvest(cell: Vector2i) -> bool:
	if not has_tree(cell):
		return false
	_harvested[cell] = true
	revision += 1
	return true


func is_harvested(cell: Vector2i) -> bool:
	return _harvested.has(cell)


func nearest_standing_tree(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell: Vector2i in _cells:
		if _harvested.has(cell):
			continue
		var d: int = (cell.x - from.x) * (cell.x - from.x) + (cell.y - from.y) * (cell.y - from.y)
		if d < best_d or (d == best_d and (best == Vector2i(-1, -1) or cell.x < best.x or (cell.x == best.x and cell.y < best.y))):
			best_d = d
			best = cell
	return best


func harvested_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		if _harvested.has(cell):
			cells.append(cell)
	return cells


func apply_harvested(cells: Array) -> void:
	_harvested.clear()
	for item in cells:
		var cell: Vector2i = item
		if _index.has(cell):
			_harvested[cell] = true
	revision += 1
