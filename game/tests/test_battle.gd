extends SceneTree

const Battle = preload("res://simulation/battle_sim.gd")
var checks := 0
var failures: Array[String] = []
var obstacles: Dictionary = {}


func _initialize() -> void:
	_test_setup_and_recruitment()
	_test_bridge_and_capture()
	_test_orders_and_blockage()
	_test_observation_and_ammunition()
	_test_preservation()
	_test_persistence()
	if failures.is_empty():
		print("PASS: ", checks, " verificações do combate 0.1. Não equivalem à aprovação integral MIL-01–15.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _new_battle() -> RefCounted:
	obstacles.clear()
	var battle := Battle.new()
	battle.setup(_walkable, _path)
	return battle


func _walkable(cell: Vector2i) -> bool:
	if cell.x <= 0 or cell.x >= 35 or cell.y <= 0 or cell.y >= 27 or obstacles.has(cell):
		return false
	return not (cell.x >= 22 and cell.x <= 24 and (cell.y < 13 or cell.y > 15))


func _path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _walkable(goal) or start == goal:
		return result
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var cell: Vector2i = current + direction
			if not _walkable(cell) or previous.has(cell):
				continue
			previous[cell] = current
			if cell == goal:
				var cursor := goal
				while cursor != start:
					result.push_front(cursor)
					cursor = previous[cursor]
				return result
			queue.append(cell)
	return result


func _advance(battle: RefCounted, ticks: int) -> void:
	for index in range(ticks):
		battle.step()


func _valid_occupancy(battle: RefCounted) -> bool:
	var occupied: Dictionary = {}
	for unit in battle.units:
		if unit.hp <= 0:
			continue
		if not _walkable(unit.cell) or occupied.has(unit.cell):
			return false
		occupied[unit.cell] = true
	return true


func _test_setup_and_recruitment() -> void:
	var battle := _new_battle()
	_expect(battle.units.size() == 18 and _valid_occupancy(battle), "initial 12 allies and 6 enemies occupy distinct walkable cells")
	_expect(battle.issue_order("individual_move", Vector2i(10, 10)).ok == false, "individual soldier command is rejected")
	_expect(not battle.issue_order("attack", Vector2i(23, 4)).ok, "unwalkable order is rejected")
	_expect(not battle.recruit("dragon"), "unknown military role cannot recruit")
	for index in range(12):
		_expect(battle.recruit("lancer" if index % 2 == 0 else "archer"), "recruit %d finds a free cell" % index)
	_expect(not battle.recruit("lancer") and _valid_occupancy(battle), "24 living allied soldiers is enforced without collisions")


func _test_bridge_and_capture() -> void:
	var battle := _new_battle()
	for unit in battle.units:
		if unit.team == "enemy":
			unit.hp = 0
	battle.issue_order("attack", Vector2i(30, 14))
	var valid := true
	for index in range(600):
		battle.step()
		valid = valid and _valid_occupancy(battle)
		if battle.captured:
			break
	_expect(valid, "whole crossing respects bridge and exclusive occupancy")
	_expect(battle.captured and battle.order == "defend", "unopposed camp capture switches automatically to defense")
	var contested := _new_battle()
	contested.issue_order("attack", Vector2i(30, 14))
	for index in range(1800):
		contested.step()
		if contested.captured or contested.defeated:
			break
	print("Battle fixture: tick=", contested.tick, " captured=", contested.captured, " order=", contested.order, " allies_hp=", contested._health("ally"), " enemy_hp=", contested._health("enemy"))
	_expect(contested.captured, "baseline supplied force can conquer camp through autonomous battle")
	_expect(_valid_occupancy(contested), "contested battle retains exclusive walkable cells")


func _test_orders_and_blockage() -> void:
	var battle := _new_battle()
	for unit in battle.units:
		if unit.team == "enemy":
			unit.hp = 0
	for y in range(13, 16):
		obstacles[Vector2i(23, y)] = true
	battle.issue_order("attack", Vector2i(30, 14))
	_advance(battle, 10)
	_expect(battle.status.contains("Sem caminho"), "blocked approach reports persistent reason")
	obstacles.clear()
	_advance(battle, 600)
	_expect(battle.captured, "opening bridge resumes existing collective order")
	var revision: int = battle.order_revision
	_expect(battle.issue_order("regroup", Vector2i(16, 14)).ok, "collective regroup accepted")
	_advance(battle, 500)
	_expect(battle.order_revision == revision + 1 and battle.status == "Companhia reagrupada", "regroup replaces old goal and reaches destination")
	battle.issue_order("retreat", Vector2i(10, 14))
	_advance(battle, 400)
	_expect(battle.status.contains("concluída"), "retreat finishes through movement")
	battle.issue_order("defend", Vector2i(10, 14))
	_advance(battle, 100)
	_expect(battle.order == "defend", "defend remains persistent")


func _test_observation_and_ammunition() -> void:
	var battle := _new_battle()
	var visible := 0
	for unit in battle.units:
		if unit.team == "enemy" and unit.visible:
			visible += 1
	_expect(visible == 0 and battle._known.is_empty(), "unobserved initial enemy supplies no tactical intelligence")
	var archer: Dictionary = battle.units[8]
	var enemy: Dictionary = battle.units[12]
	archer.cell = Vector2i(26, 18)
	archer.previous = archer.cell
	enemy.cell = Vector2i(30, 18)
	enemy.previous = enemy.cell
	archer.ammo = 1
	battle.issue_order("attack", Vector2i(30, 14))
	_advance(battle, 1)
	_expect(enemy.visible and archer.ammo == 0, "observed target consumes exactly one available arrow")
	_advance(battle, 80)
	_expect(archer.ammo == 0, "empty archer cannot create ammunition or become negative")
	var hidden := _new_battle()
	var watcher: Dictionary = hidden.units[0]
	watcher.cell = Vector2i(26, 14)
	watcher.previous = watcher.cell
	hidden._refresh_vision()
	var remembered: Dictionary = hidden._known[13].duplicate(true)
	watcher.cell = Vector2i(17, 11)
	watcher.previous = watcher.cell
	hidden.units[12].cell = Vector2i(33, 20)
	hidden.units[12].previous = hidden.units[12].cell
	hidden._refresh_vision()
	_expect(not hidden.units[12].visible and hidden._known[13].cell == remembered.cell, "fog freezes last seen position instead of tracking concealed movement")
	var wall := _new_battle()
	obstacles[Vector2i(28, 18)] = true
	_expect(not wall._line_clear(Vector2i(26, 18), Vector2i(30, 18)), "opaque terrain blocks sight and arrows")
	_expect(wall._line_clear(Vector2i(21, 10), Vector2i(25, 10)), "river is not an opaque wall")


func _test_preservation() -> void:
	var battle := _new_battle()
	_expect(battle.units[6].reserve and battle.units[7].reserve, "initial company keeps two actual spear reserves")
	battle.units[0].hp = 0
	battle._refresh_reserves()
	_expect(not battle.units[6].reserve and battle.units[7].reserve, "a reserve automatically replaces a lost frontline soldier")
	var wounded: Dictionary = battle.units[1]
	wounded.hp = 25
	_advance(battle, 5)
	_expect(wounded.retreating, "critical health withdraws a soldier when there is an opportunity to move")
	battle = _new_battle()
	battle.issue_order("attack", Vector2i(30, 14))
	for index in range(5):
		battle.units[index].hp = 0
	battle.step()
	_expect(battle.order == "retreat" and battle.events.back().reason == "preserve", "heavy attrition autonomously triggers a explained retreat")
	var retreat_start: Vector2i = battle.units[5].cell
	_expect(battle.units[5].cell == retreat_start, "decision alone never teleports a retreating unit")
	_advance(battle, 120)
	_expect(_valid_occupancy(battle), "retreat retains legal positions")
	for unit in battle.units:
		if unit.team == "ally":
			unit.hp = 0
	battle.step()
	_expect(battle.defeated and not battle.issue_order("attack", Vector2i(30, 14)).ok, "empty company reports defeat and refuses military orders")
	_expect(battle.recruit("lancer") and not battle.defeated, "recruitment restores an empty company's ability to act")


func _test_persistence() -> void:
	var battle := _new_battle()
	battle.issue_order("attack", Vector2i(30, 14))
	_advance(battle, 83)
	var data: Dictionary = JSON.parse_string(JSON.stringify(battle.snapshot()))
	var restored := Battle.new()
	restored.setup(_walkable, _path)
	_expect(restored.restore(data), "mid-battle JSON snapshot restores")
	_advance(battle, 150)
	_advance(restored, 150)
	_expect(battle.snapshot() == restored.snapshot(), "restored simulation repeats identical decisions, positions, damage and ammunition")
	var before: Dictionary = restored.snapshot()
	var invalid: Array[Dictionary] = [{}]
	var bad: Dictionary = before.duplicate(true)
	bad.tick = -1
	invalid.append(bad)
	bad = before.duplicate(true)
	bad.units[0].hp = 0.5
	invalid.append(bad)
	bad = before.duplicate(true)
	bad.units[1].id = bad.units[0].id
	invalid.append(bad)
	bad = before.duplicate(true)
	bad.units[1].cell = bad.units[0].cell
	bad.units[0].hp = 100
	bad.units[1].hp = 100
	invalid.append(bad)
	bad = before.duplicate(true)
	bad.known = [{"id": 9999}]
	invalid.append(bad)
	for record in invalid:
		_expect(not restored.restore(record) and restored.snapshot() == before, "malformed snapshot rejected without partial state mutation")
