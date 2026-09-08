extends RefCounted
## Small deterministic battle simulation. Rendering never drives decisions.

const CAMP := Vector2i(30, 14)
const RALLY := Vector2i(17, 12)
const FALLBACK := Vector2i(15, 14)
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const ORDERS := ["attack", "defend", "regroup", "retreat"]
const MOVE_TICKS := 5
const MEMORY_TICKS := 50
const MAX_ALLIES := 24

var units: Array[Dictionary] = []
var order: String = "defend"
var target := RALLY
var status: String = "Companhia protegendo a vila"
var captured: bool = false
var defeated: bool = false
var events: Array[Dictionary] = []
var tick: int = 0
var capture_progress: int = 0
var order_revision: int = 0

var _walkable: Callable
var _pathfinder: Callable
var _next_id: int = 1
var _initial_health: int = 1200
var _risk_ticks: int = 0
var _known: Dictionary = {}
var _last_reason: String = ""
var _order_finished: bool = false


func setup(walkable: Callable, pathfinder: Callable, garrison: bool = true) -> void:
	_walkable = walkable
	_pathfinder = pathfinder
	units.clear()
	events.clear()
	_known.clear()
	tick = 0
	_next_id = 1
	order_revision = 0
	order = "defend"
	target = RALLY
	status = "Companhia protegendo a vila"
	captured = false
	defeated = false
	capture_progress = 0
	_risk_ticks = 0
	_last_reason = ""
	_order_finished = false
	if not garrison:
		_initial_health = 1
		_notice("ready", "Quartel pronto. Recrute soldados com equipamento.")
		return
	for index in range(8):
		_spawn("ally", "lancer", Vector2i(17 + index / 4, 11 + index % 4))
		units.back().reserve = index >= 6
	for index in range(4):
		_spawn("ally", "archer", Vector2i(16, 11 + index))
	for cell in [Vector2i(29, 13), Vector2i(30, 13), Vector2i(31, 13), Vector2i(31, 14)]:
		_spawn("enemy", "lancer", cell)
	_spawn("enemy", "archer", Vector2i(32, 15))
	_spawn("enemy", "archer", Vector2i(32, 16))
	_initial_health = _health("ally")
	_refresh_vision()
	_notice("ready", "12 soldados prontos. Escolha um objetivo para a companhia.")


func issue_order(kind: String, destination: Vector2i) -> Dictionary:
	if kind not in ORDERS:
		return {"ok": false, "message": "Ordem militar desconhecida."}
	if not _inside(destination) or not _walk(destination):
		return {"ok": false, "message": "Escolha um ponto em terra ou na ponte."}
	if _alive("ally").is_empty():
		return {"ok": false, "message": "Não há soldados disponíveis. Recrute no quartel."}
	order = kind
	target = destination
	order_revision += 1
	_order_finished = false
	capture_progress = 0
	_risk_ticks = 0
	_initial_health = maxi(1, _health("ally"))
	for unit in units:
		if unit.team == "ally" and unit.hp > 25:
			unit.retreating = false
	var names := {"attack": "Conquistar", "defend": "Defender", "regroup": "Reagrupar", "retreat": "Recuar"}
	_notice("order", "%s: companhia recebeu o objetivo." % names[kind])
	_evaluate_status()
	return {"ok": true, "message": status}


func recruit(role: String) -> bool:
	if role not in ["lancer", "archer"] or _alive("ally").size() >= MAX_ALLIES:
		return false
	if not _spawn("ally", role, RALLY):
		return false
	if role == "lancer":
		var line_count := 0
		var reserve_count := 0
		for peer in _alive("ally"):
			if peer.role == "lancer" and peer.id != units.back().id:
				if peer.reserve:
					reserve_count += 1
				else:
					line_count += 1
		units.back().reserve = line_count >= 6 and reserve_count < 2
	defeated = false
	_order_finished = false
	_initial_health += 100
	_notice("recruited", "Novo %s integrado automaticamente à companhia." % ("lanceiro" if role == "lancer" else "arqueiro"))
	_refresh_vision()
	return true


func step() -> void:
	tick += 1
	for unit in units:
		unit.previous = unit.cell
		unit.cooldown = maxi(0, int(unit.cooldown) - 1)
	_refresh_vision()
	if _alive("ally").is_empty():
		defeated = true
		status = "Companhia derrotada. Recrute novos soldados."
		_notice("defeated", status)
		return
	defeated = false
	_refresh_reserves()
	_assess_preservation()
	var damage: Dictionary = {}
	for unit in units:
		if unit.hp <= 0:
			unit.state = "Caído"
			continue
		var enemy := _nearest_enemy(unit)
		if _try_attack(unit, enemy, damage):
			continue
		if tick % MOVE_TICKS == 0:
			_decide_movement(unit, enemy)
	for unit in units:
		if damage.has(unit.id):
			unit.hp = maxi(0, int(unit.hp) - int(damage[unit.id]))
			if unit.hp == 0:
				unit.state = "Caído"
				_notice("casualty_%d" % unit.id, "%s perdeu um %s." % ["A companhia" if unit.team == "ally" else "O inimigo", "lanceiro" if unit.role == "lancer" else "arqueiro"])
	_refresh_vision()
	if _alive("ally").is_empty():
		defeated = true
		status = "Companhia derrotada. Recrute novos soldados."
		_notice("defeated", status)
		return
	_update_capture()
	if tick % MOVE_TICKS == 0:
		_evaluate_status()


func _spawn(team: String, role: String, preferred: Vector2i) -> bool:
	var location := _free_near(preferred, -1, 4)
	if location == Vector2i(-1, -1):
		return false
	units.append({"id": _next_id, "team": team, "role": role, "cell": location,
		"previous": location, "hp": 100, "max_hp": 100,
		"ammo": 24 if role == "archer" else 0, "state": "Em formação",
		"visible": team == "ally", "cooldown": 0, "retreating": false, "reserve": false})
	_next_id += 1
	return true


func _refresh_vision() -> void:
	var allies := _alive("ally")
	for unit in units:
		if unit.team == "ally":
			unit.visible = true
			continue
		unit.visible = false
		for observer in allies:
			if _distance_squared(observer.cell, unit.cell) <= 64 and _line_clear(observer.cell, unit.cell):
				unit.visible = true
				break
		if unit.visible:
			if unit.hp > 0:
				_known[unit.id] = {"id": unit.id, "cell": unit.cell, "seen_tick": tick,
					"hp": unit.hp, "role": unit.role, "ammo": unit.ammo}
			else:
				_known.erase(unit.id)


func _nearest_enemy(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 100000
	for other in units:
		if other.team == unit.team or other.hp <= 0:
			continue
		if unit.team == "ally" and not other.visible:
			continue
		var distance := _distance_squared(unit.cell, other.cell)
		if distance > 64 or not _line_clear(unit.cell, other.cell):
			continue
		if not _may_engage(unit, other.cell):
			continue
		if distance < best_distance or (distance == best_distance and int(other.id) < int(best.get("id", 100000))):
			best = other
			best_distance = distance
	return best


func _may_engage(unit: Dictionary, cell: Vector2i) -> bool:
	if unit.team == "enemy":
		return _distance_squared(CAMP, cell) <= 81
	if order == "retreat" or order == "regroup" or unit.retreating:
		return _distance_squared(unit.cell, cell) <= 2
	if _distance_squared(target, cell) <= 36:
		return true
	# Defend never pursues outside its designated area. Attack may protect its approach.
	if order == "defend":
		return false
	return _distance_squared(unit.cell, cell) <= 36 and _distance_squared(cell, target) <= _distance_squared(unit.cell, target) + 9


func _try_attack(unit: Dictionary, enemy: Dictionary, damage: Dictionary) -> bool:
	if enemy.is_empty():
		return false
	if (unit.team == "ally" and (order in ["retreat", "regroup"] or unit.retreating)):
		return false
	var distance := _distance_squared(unit.cell, enemy.cell)
	var can_attack: bool = distance <= 2 if unit.role == "lancer" else (distance >= 4 and distance <= 36 and unit.ammo > 0)
	if not can_attack or not _line_clear(unit.cell, enemy.cell):
		return false
	unit.state = "Protegendo a linha" if unit.role == "lancer" else "Arqueiros dando cobertura"
	if unit.cooldown == 0:
		var amount := 12 if unit.role == "lancer" else 16
		damage[enemy.id] = int(damage.get(enemy.id, 0)) + amount
		unit.cooldown = 10 if unit.role == "lancer" else 20
		if unit.role == "archer":
			unit.ammo -= 1
	return true


func _decide_movement(unit: Dictionary, enemy: Dictionary) -> void:
	if unit.team == "ally" and unit.hp <= 25:
		unit.retreating = true
	var destination: Vector2i
	if unit.team == "ally" and (order in ["retreat", "regroup"] or unit.retreating):
		destination = _formation_slot(unit, target if order in ["retreat", "regroup"] else FALLBACK)
		unit.state = "Recuando" if order == "retreat" or unit.retreating else "Reagrupando"
	elif not enemy.is_empty():
		if unit.role == "lancer":
			destination = _adjacent_goal(unit, enemy.cell)
			unit.state = "Protegendo arqueiros"
		else:
			destination = _archer_goal(unit, enemy)
			unit.state = "Buscando posição de tiro" if unit.ammo > 0 else "Sem munição; protegendo-se"
	else:
		destination = _formation_slot(unit, target if unit.team == "ally" else CAMP)
		unit.state = "Em formação" if unit.cell == destination else "Marchando"
	if unit.team == "enemy" and _distance_squared(destination, CAMP) > 64:
		destination = _formation_slot(unit, CAMP)
	if unit.team == "ally" and order == "defend" and _distance_squared(destination, target) > 36:
		destination = _formation_slot(unit, target)
	_move_toward(unit, destination)


func _formation_slot(unit: Dictionary, anchor: Vector2i) -> Vector2i:
	var peers: Array[Dictionary] = []
	for peer in units:
		if peer.team == unit.team and peer.role == unit.role and peer.hp > 0:
			peers.append(peer)
	var index := 0
	for position in range(peers.size()):
		if peers[position].id == unit.id:
			index = position
			break
	var side := 1 if unit.team == "ally" else -1
	var offset: Vector2i
	if unit.role == "archer":
		offset = Vector2i(-3 * side - index / 4 * side, index % 4 - 2)
	else:
		var reserve_count := mini(2, maxi(0, peers.size() - 1))
		var front_count := peers.size() - reserve_count
		if index >= front_count:
			offset = Vector2i(-4 * side, (index - front_count) * 2 - 1)
		else:
			offset = Vector2i(-side - index / 4 * side, index % 4 - 2)
	return _free_near(anchor + offset, unit.id, 3)


func _refresh_reserves() -> void:
	var ready: Array[Dictionary] = []
	var front_count := 0
	for unit in _alive("ally"):
		if unit.role == "lancer" and unit.hp > 25 and not unit.retreating:
			ready.append(unit)
			if not unit.reserve:
				front_count += 1
	var wanted := mini(6, ready.size())
	for unit in ready:
		if front_count >= wanted:
			break
		if unit.reserve:
			unit.reserve = false
			front_count += 1
			_notice("reserve_%d" % unit.id, "Reserva reforçando a linha de lanceiros.")


func _adjacent_goal(unit: Dictionary, enemy_cell: Vector2i) -> Vector2i:
	var best: Vector2i = unit.cell
	var best_length := 100000
	for direction in DIRECTIONS:
		var candidate: Vector2i = enemy_cell + direction
		if not _walk(candidate) or _occupied(candidate, unit.id):
			continue
		var route: Array = _path(unit.cell, candidate)
		if candidate == unit.cell:
			return candidate
		if not route.is_empty() and route.size() < best_length:
			best_length = route.size()
			best = candidate
	return best


func _archer_goal(unit: Dictionary, enemy: Dictionary) -> Vector2i:
	var distance := _distance_squared(unit.cell, enemy.cell)
	if distance >= 4 and distance <= 36 and unit.ammo > 0:
		return unit.cell
	var best: Vector2i = unit.cell
	var best_score := -100000
	for direction in DIRECTIONS:
		var candidate: Vector2i = unit.cell + direction
		if not _walk(candidate) or _occupied(candidate, unit.id):
			continue
		var separation := _distance_squared(candidate, enemy.cell)
		var score: int = -absi(separation - 20)
		if distance < 4 or unit.ammo == 0:
			score = separation
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _move_toward(unit: Dictionary, destination: Vector2i) -> void:
	if destination == Vector2i(-1, -1):
		unit.state = "Aguardando espaço"
		return
	if unit.cell == destination:
		return
	var route: Array = _path(unit.cell, destination)
	if route.is_empty():
		unit.state = "Sem caminho conhecido"
		return
	var next: Vector2i = route[0]
	if _occupied(next, unit.id):
		var alternative := Vector2i(-1, -1)
		var length := route.size() + 2
		for direction in DIRECTIONS:
			var candidate: Vector2i = unit.cell + direction
			if not _walk(candidate) or _occupied(candidate, unit.id):
				continue
			var remainder: Array = _path(candidate, destination)
			if (candidate == destination or not remainder.is_empty()) and remainder.size() < length:
				alternative = candidate
				length = remainder.size()
		if alternative == Vector2i(-1, -1):
			unit.state = "Aguardando passagem"
			return
		next = alternative
	if not _walk(next) or _occupied(next, unit.id):
		return
	unit.cell = next


func _assess_preservation() -> void:
	if order != "attack":
		_risk_ticks = 0
		return
	var current := _health("ally")
	var enemy_power := 0
	for memory in _known.values():
		if tick - int(memory.seen_tick) <= MEMORY_TICKS:
			enemy_power += int(memory.hp)
	if enemy_power > 0 and current * 10 < enemy_power * 12:
		_risk_ticks += 1
	else:
		_risk_ticks = 0
	var losses := _initial_health - current
	if _risk_ticks >= 10 or (losses > 0 and losses * 100 >= _initial_health * 35):
		order = "retreat"
		target = FALLBACK
		order_revision += 1
		_order_finished = false
		capture_progress = 0
		var reason := "inferioridade observada" if _risk_ticks >= 10 else "perdas elevadas"
		status = "Recuando: %s. Reforce a companhia no quartel." % reason
		_notice("preserve", status)


func _update_capture() -> void:
	if captured or order != "attack" or _distance_squared(target, CAMP) > 25:
		capture_progress = 0 if not captured else 30
		return
	var allies := _alive("ally")
	var present := 0
	for unit in allies:
		if _distance_squared(unit.cell, CAMP) <= 16:
			present += 1
	var opposition := false
	for enemy in units:
		if enemy.team == "enemy" and enemy.hp > 0 and enemy.visible and _distance_squared(enemy.cell, CAMP) <= 36:
			opposition = true
	if not opposition and present >= maxi(1, ceili(allies.size() * 0.5)):
		capture_progress += 1
	else:
		capture_progress = 0
	if capture_progress >= 30:
		captured = true
		order = "defend"
		target = CAMP
		status = "Acampamento conquistado! Companhia defendendo a posição."
		_notice("captured", status)


func _evaluate_status() -> void:
	if defeated:
		return
	var allies := _alive("ally")
	var arrived := 0
	var blocked := 0
	var fighting := 0
	for unit in allies:
		if _distance_squared(unit.cell, target) <= 36:
			arrived += 1
		if unit.state == "Sem caminho conhecido":
			blocked += 1
		if unit.state in ["Protegendo a linha", "Arqueiros dando cobertura"]:
			fighting += 1
	if blocked > 0:
		status = "Retirada bloqueada; aguardando passagem" if order == "retreat" else "Sem caminho conhecido; aguardando acesso"
	elif order == "retreat":
		status = "Retirada concluída. Companhia em segurança." if arrived == allies.size() else "Recuando e protegendo os sobreviventes"
	elif order == "regroup":
		status = "Companhia reagrupada" if arrived == allies.size() else "Reagrupando a companhia"
	elif fighting > 0:
		status = "Infantaria protegendo a linha; arqueiros dando cobertura"
	elif capture_progress > 0 and not captured:
		status = "Ocupando o acampamento: %d%%" % mini(100, capture_progress * 100 / 30)
	elif order == "attack":
		status = "Avançando para o objetivo"
	elif captured:
		status = "Acampamento conquistado; defendendo a posição"
	else:
		status = "Companhia defendendo a área"
	if order in ["retreat", "regroup"] and arrived == allies.size() and not _order_finished:
		_order_finished = true
		_notice("order_finished", status)
	elif blocked > 0:
		_notice("blocked", status)


func _notice(reason: String, text: String) -> void:
	if _last_reason == reason:
		return
	_last_reason = reason
	events.append({"tick": tick, "text": text, "reason": reason, "order_revision": order_revision})
	if events.size() > 100:
		events.pop_front()


func _alive(team: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in units:
		if unit.team == team and unit.hp > 0:
			result.append(unit)
	return result


func _health(team: String) -> int:
	var result := 0
	for unit in units:
		if unit.team == team:
			result += int(unit.hp)
	return result


func _occupied(cell: Vector2i, except_id: int = -1) -> bool:
	for unit in units:
		if unit.hp > 0 and unit.id != except_id and unit.cell == cell:
			return true
	return false


func _free_near(preferred: Vector2i, except_id: int, radius: int) -> Vector2i:
	if _walk(preferred) and not _occupied(preferred, except_id):
		return preferred
	for ring in range(1, radius + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var candidate := preferred + Vector2i(x, y)
				if _walk(candidate) and not _occupied(candidate, except_id):
					return candidate
	return Vector2i(-1, -1)


func _inside(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.x < 35 and cell.y > 0 and cell.y < 27


func _walk(cell: Vector2i) -> bool:
	return _inside(cell) and _walkable.is_valid() and bool(_walkable.call(cell))


func _path(start: Vector2i, goal: Vector2i) -> Array:
	if not _pathfinder.is_valid() or not _walk(goal):
		return []
	return _pathfinder.call(start, goal)


func _distance_squared(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return d.x * d.x + d.y * d.y


func _line_clear(start: Vector2i, finish: Vector2i) -> bool:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	for index in range(1, steps):
		var cell := Vector2i(roundi(start.x + delta.x * float(index) / steps), roundi(start.y + delta.y * float(index) / steps))
		# Water is not an opaque wall. Other blocked terrain occludes sight and arrows.
		if cell.x >= 22 and cell.x <= 24:
			continue
		if not _walk(cell):
			return false
	return true


func snapshot() -> Dictionary:
	var records: Array = []
	for unit in units:
		var record: Dictionary = unit.duplicate(true)
		record.cell = [unit.cell.x, unit.cell.y]
		record.previous = [unit.previous.x, unit.previous.y]
		records.append(record)
	var memory: Array = []
	for item in _known.values():
		var record: Dictionary = item.duplicate(true)
		record.cell = [item.cell.x, item.cell.y]
		memory.append(record)
	return {"schema": 1, "tick": tick, "units": records, "order": order,
		"target": [target.x, target.y], "status": status, "captured": captured,
		"defeated": defeated, "events": events.duplicate(true), "capture_progress": capture_progress,
		"order_revision": order_revision, "next_id": _next_id, "initial_health": _initial_health,
		"risk_ticks": _risk_ticks, "known": memory, "last_reason": _last_reason, "order_finished": _order_finished}


func restore(data: Dictionary) -> bool:
	# Validate into local values; never partially overwrite a running battle.
	if data.get("schema") != 1 or not _integer(data.get("tick"), 0, 1000000000):
		return false
	if data.get("order") not in ORDERS or not _saved_cell(data.get("target")):
		return false
	for key in ["captured", "defeated", "order_finished"]:
		if typeof(data.get(key)) != TYPE_BOOL:
			return false
	for key in ["status", "last_reason"]:
		if typeof(data.get(key)) != TYPE_STRING:
			return false
	for key in ["capture_progress", "order_revision", "next_id", "initial_health", "risk_ticks"]:
		if not _integer(data.get(key), 0, 1000000000):
			return false
	if data.capture_progress > 30 or data.next_id < 1 or not data.get("units") is Array or data.units.size() > 2000:
		return false
	var restored_units: Array[Dictionary] = []
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	var ally_count := 0
	for source in data.units:
		if not source is Dictionary or not _integer(source.get("id"), 1, int(data.next_id) - 1):
			return false
		if ids.has(int(source.id)) or source.get("team") not in ["ally", "enemy"] or source.get("role") not in ["lancer", "archer"]:
			return false
		if not _saved_cell(source.get("cell")) or not _saved_cell(source.get("previous")):
			return false
		if not _integer(source.get("hp"), 0, 100) or source.get("max_hp") != 100 or not _integer(source.get("ammo"), 0, 24):
			return false
		if not _integer(source.get("cooldown"), 0, 20) or typeof(source.get("state")) != TYPE_STRING:
			return false
		if typeof(source.get("visible")) != TYPE_BOOL or typeof(source.get("retreating")) != TYPE_BOOL or typeof(source.get("reserve")) != TYPE_BOOL:
			return false
		var unit: Dictionary = source.duplicate(true)
		unit.cell = Vector2i(int(source.cell[0]), int(source.cell[1]))
		unit.previous = Vector2i(int(source.previous[0]), int(source.previous[1]))
		for key in ["id", "hp", "max_hp", "ammo", "cooldown"]:
			unit[key] = int(unit[key])
		if unit.hp > 0:
			if occupied.has(unit.cell):
				return false
			occupied[unit.cell] = true
			if unit.team == "ally":
				ally_count += 1
		ids[unit.id] = unit
		restored_units.append(unit)
	if ally_count > MAX_ALLIES or bool(data.defeated) != (ally_count == 0):
		return false
	if not data.get("known") is Array or not data.get("events") is Array or data.events.size() > 100:
		return false
	var known: Dictionary = {}
	for source in data.known:
		if not source is Dictionary or not _integer(source.get("id"), 1, int(data.next_id) - 1):
			return false
		var id := int(source.id)
		if not ids.has(id) or ids[id].team != "enemy" or known.has(id) or not _saved_cell(source.get("cell")):
			return false
		if not _integer(source.get("seen_tick"), 0, int(data.tick)) or not _integer(source.get("hp"), 1, 100):
			return false
		if source.get("role") not in ["lancer", "archer"] or not _integer(source.get("ammo"), 0, 24):
			return false
		known[id] = {"id": id, "cell": Vector2i(int(source.cell[0]), int(source.cell[1])),
			"seen_tick": int(source.seen_tick), "hp": int(source.hp), "role": source.role, "ammo": int(source.ammo)}
	var restored_events: Array[Dictionary] = []
	for source in data.events:
		if not source is Dictionary or not _integer(source.get("tick"), 0, int(data.tick)) or typeof(source.get("text")) != TYPE_STRING:
			return false
		if typeof(source.get("reason")) != TYPE_STRING or not _integer(source.get("order_revision"), 0, int(data.order_revision)):
			return false
		var event: Dictionary = source.duplicate(true)
		event.tick = int(event.tick)
		event.order_revision = int(event.order_revision)
		restored_events.append(event)
	units = restored_units
	events = restored_events
	_known = known
	tick = int(data.tick)
	order = data.order
	target = Vector2i(int(data.target[0]), int(data.target[1]))
	status = data.status
	captured = data.captured
	defeated = data.defeated
	capture_progress = int(data.capture_progress)
	order_revision = int(data.order_revision)
	_next_id = int(data.next_id)
	_initial_health = int(data.initial_health)
	_risk_ticks = int(data.risk_ticks)
	_last_reason = data.last_reason
	_order_finished = data.order_finished
	return true


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


func _saved_cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0], 1, 34) and _integer(value[1], 1, 26)
