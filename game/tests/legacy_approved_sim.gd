extends "res://simulation/village_sim.gd"
## Independent approved-scale rules. Frontier 0.3 and its saves remain unchanged.

const HUB := Vector2i(8,13)
const MOVEMENT_STEP_TICKS := 5
const ROAD_DIRECTIONS := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
const NATURAL_AREAS := [Rect2i(1,2,3,7),Rect2i(1,18,2,8),Rect2i(14,1,7,3),Rect2i(27,2,7,5),Rect2i(2,9,2,3),Rect2i(19,9,2,3),Rect2i(14,23,3,3)]
# Presentation reads this deterministic map; natural obstacles cannot be cleared in 0.4.
var natural_cells: Array[Vector2i] = _create_natural_cells()
var roads: Array[Dictionary] = []
var road_navigation := AStarGrid2D.new()
var _road_moved: Dictionary = {}
var _complete_roads: Dictionary = {}
var _connected_roads: Dictionary = {}
var _plaza: Array[Vector2i] = []


func setup(_peaceful_mode: bool = true) -> void:
	peaceful = true
	battle = null
	tick = 0
	next_id = 1
	buildings.clear()
	workers.clear()
	training.clear()
	events.clear()
	roads.clear()
	won = false
	lost = false
	paused = false
	stock = {"wood":140,"stone":160,"food":280,"grapes":0,"wine":0}
	initial = stock.duplicate(true)
	reserved = _empty_items()
	consumed = _empty_items()
	produced = _empty_items()
	stats = {"houses_built":0,"wine_delivered":0,"food_produced":0}
	food_shortage = 0
	arrival_ticks = 0
	last_notice = ""
	definitions = definitions.duplicate(true)
	definitions.erase("barracks")
	definitions.hall.name = "Edifício principal"
	definitions.hall.description = "Abriga os primeiros moradores e o estoque inicial. Sua entrada inicia a rede de estradas."
	definitions.store.description = "Amplia em 200 unidades a capacidade do depósito principal, com acesso pela rede."
	_add_building("hall",Vector2i(7,10),true)
	_add_building("training",Vector2i(12,10),true)
	_rebuild_navigation()
	_rebuild_plaza()
	var roles := ["builder","builder","builder","servant","servant","servant","servant","servant","instructor"]
	for index in range(roles.size()):
		_add_worker(roles[index],Vector2i(3+index%5,14+index/5))
	for index in range(8):
		_add_worker("resident",Vector2i(10+index%4,15+index/4))
	var instructor: Dictionary = workers[8]
	instructor.cell = Vector2i(11,11)
	instructor.previous = instructor.cell
	instructor.goal = instructor.cell
	instructor.task = {"type":"produce","building":buildings[1].id}
	instructor.state = "Ensinando no centro"
	buildings[1].worker = instructor.id
	for person in workers:
		if person.task.is_empty():
			person.cell = plaza_rest_cell(person)
			person.previous = person.cell
			person.goal = person.cell
			person.state = "Na praça"
	_rebuild_roads()
	_emit("A praça reúne os moradores livres. Trace uma estrada até a escola; a equipe trabalha sozinha.")


func population_capacity() -> int:
	return 17+4*_completed("house")


func storage_capacity() -> int:
	return 800+200*_completed("store")


static func _create_natural_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for area: Rect2i in NATURAL_AREAS:
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				cells.append(Vector2i(x,y))
	return cells


func is_terrain_natural(cell: Vector2i) -> bool:
	for area: Rect2i in NATURAL_AREAS:
		if area.has_point(cell):
			return true
	return false


func _terrain_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= WIDTH-1 or cell.y >= HEIGHT-1:
		return false
	if is_terrain_natural(cell):
		return false
	return not (cell.x >= 22 and cell.x <= 24 and (cell.y < 13 or cell.y > 15))


func command(kind: String, payload: Dictionary = {}) -> Dictionary:
	if kind == "build":
		var idle := {"builder":0,"servant":0}
		var total := {"builder":0,"servant":0}
		for person in workers:
			if total.has(person.role):
				total[person.role] += 1
				if person.task.is_empty():idle[person.role] += 1
		var result: Dictionary = super.command(kind,payload)
		if not result.ok:return result
		var notices: Array[String] = []
		for role in ["builder","servant"]:
			if total[role] == 0:
				notices.append("Nenhum "+("construtor" if role=="builder" else "servente")+" formado")
			elif idle[role] == 0:
				notices.append("Construtores ocupados" if role=="builder" else "Serventes ocupados")
		if not notices.is_empty():
			return _result(true,"Obra na fila. "+"; ".join(notices)+". Forme mais na escola ou aguarde: a equipe assumirá automaticamente.")
		return result
	if kind == "road":
		var requested: Variant = payload.get("cells",[payload.get("cell")])
		if not requested is Array or requested.is_empty() or requested.size() > 200:
			return _result(false,"Escolha até 200 terrenos para a estrada.")
		var cells: Array[Vector2i] = []
		for cell in requested:
			if typeof(cell) != TYPE_VECTOR2I:
				return _result(false,"Trecho de estrada inválido.")
			if is_plaza_cell(cell) or cell == HUB or not road_at(cell).is_empty() or cells.has(cell):
				continue
			var error := can_place_road(cell)
			if not error.is_empty():
				return _result(false,error)
			cells.append(cell)
		if cells.size() > available("stone"):
			return _result(false,"Cada trecho reserva 1 pedra. Não há pedra suficiente para este caminho.")
		for cell in cells:
			roads.append({"id":_id(),"cell":cell,"stage":"planned","progress":0.0,"builder":-1,"funded":true,"reason":"Aguardando frente conectada"})
			reserved.stone += 1
		return _result(true,"Estrada planejada. Construtores avançam a partir da entrada do edifício principal." if not cells.is_empty() else "Este caminho já está planejado.")
	if kind == "remove_road":
		if payload.get("cell") is Vector2i and is_plaza_cell(payload.cell):
			return _result(false,"A praça é o ponto de encontro da vila e permanece livre.")
		if typeof(payload.get("cell")) != TYPE_VECTOR2I:
			return _result(false,"Escolha um trecho de estrada.")
		var road := road_at(payload.cell)
		if road.is_empty():
			return _result(false,"Não há estrada neste terreno.")
		if road.builder != -1 or _occupied(road.cell):
			return _result(false,"Aguarde a pessoa sair deste trecho antes de removê-lo.")
		if road.funded:
			reserved.stone -= 1
			road.funded = false
		road.stage = "cancelled"
		_rebuild_roads()
		return _result(true,"Trecho removido. Cargas permanecem com os serventes até existir um caminho.")
	return super.command(kind,payload)


func can_place_road(cell: Vector2i) -> String:
	if is_plaza_cell(cell):
		return "A praça já está pavimentada. Comece sua estrada em uma de suas bordas."
	if cell == HUB:
		return "A entrada do edifício principal já é a origem da rede."
	if not is_walkable(cell):
		return "Estradas precisam de terreno livre."
	if not road_at(cell).is_empty():
		return "Este trecho já existe ou está planejado."
	return ""


func road_at(cell: Vector2i) -> Dictionary:
	for road in roads:
		if road.cell == cell and road.stage != "cancelled":
			return road
	return {}


func _road(id: int) -> Dictionary:
	for road in roads:
		if road.id == id:
			return road
	return {}


func has_road(cell: Vector2i) -> bool:
	return _complete_roads.has(cell)


func _road_node(cell: Vector2i) -> bool:
	return cell == HUB or has_road(cell)


func is_building_connected(building: Dictionary) -> bool:
	if building.is_empty() or building.get("stage","") == "cancelled":
		return false
	return building.kind == "hall" or _connected_roads.has(building.entrance)


func _rebuild_roads() -> void:
	_rebuild_plaza()
	_complete_roads.clear()
	_connected_roads.clear()
	road_navigation.region = Rect2i(0,0,WIDTH,HEIGHT)
	road_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	road_navigation.update()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			road_navigation.set_point_solid(Vector2i(x,y),true)
	road_navigation.set_point_solid(HUB,false)
	for cell in _plaza:
		road_navigation.set_point_solid(cell,false)
		_complete_roads[cell] = true
	for road in roads:
		if road.stage == "complete":
			road_navigation.set_point_solid(road.cell,false)
			_complete_roads[road.cell] = true
	var pending: Array[Vector2i] = [HUB]
	_connected_roads[HUB] = true
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		for direction in ROAD_DIRECTIONS:
			var adjacent: Vector2i = current+direction
			if _complete_roads.has(adjacent) and not _connected_roads.has(adjacent):
				_connected_roads[adjacent] = true
				pending.append(adjacent)


func _road_path(start: Vector2i, goal: Vector2i, avoid_people: bool = false, except_id: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _road_node(start) or not _road_node(goal) or start == goal:
		return result
	var blocked: Array[Vector2i] = []
	if avoid_people:
		for person in workers:
			if person.id != except_id and person.cell != start and person.cell != goal and _road_node(person.cell) and not is_plaza_cell(person.cell):
				road_navigation.set_point_solid(person.cell,true)
				blocked.append(person.cell)
	result = road_navigation.get_id_path(start,goal)
	for cell in blocked:
		road_navigation.set_point_solid(cell,false)
	if not result.is_empty():
		result.pop_front()
	return result


func _road_reaches(start: Vector2i, goal: Vector2i) -> bool:
	if _connected_roads.has(start) and _connected_roads.has(goal):
		return true
	return _road_node(start) and _road_node(goal) and (start == goal or not _road_path(start,goal).is_empty())


func footprint_size(kind: String) -> Vector2i:
	return Vector2i(3,3) if kind in ["hall","training","store","winery"] else Vector2i(2,2)


func building_footprint(building: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if building.is_empty():
		return cells
	var size := footprint_size(str(building.kind))
	for y in range(size.y):
		for x in range(size.x):
			cells.append(building.cell+Vector2i(x,y))
	return cells


func _entrance_offset(kind: String) -> Vector2i:
	var size := footprint_size(kind)
	return Vector2i(floori(float(size.x-1)*0.5),size.y)


func _add_building(kind: String, cell: Vector2i, complete: bool = false) -> Dictionary:
	var building := super._add_building(kind,cell,complete)
	building.entrance = cell+_entrance_offset(kind)
	return building


func building_at(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building.stage != "cancelled" and Rect2i(building.cell,footprint_size(building.kind)).has_point(cell):
			return building
	return {}


func _builder_work_cell(building: Dictionary) -> Vector2i:
	return building.entrance+Vector2i.RIGHT


func _professional_work_cell(building: Dictionary) -> Vector2i:
	return building.cell+Vector2i(-1,1)


func _is_access(cell: Vector2i) -> bool:
	for building in buildings:
		if building.stage != "cancelled" and cell in [building.entrance,_builder_work_cell(building),_professional_work_cell(building)]:
			return true
	return false


func can_place(kind: String, cell: Vector2i) -> String:
	if not definitions.has(kind) or kind == "hall":
		return "Construção desconhecida ou não disponível nesta vila."
	var size := footprint_size(kind)
	if cell.x < 2 or cell.x > WIDTH-1-size.x or cell.y < 2 or cell.y > 23:
		return "Deixe espaço para toda a construção e sua entrada dentro do vale."
	var area := Rect2i(cell,size)
	for y in range(size.y):
		for x in range(size.x):
			var tile := cell+Vector2i(x,y)
			if is_plaza_cell(tile):
				return "A praça fica livre para os moradores. Construa ao redor dela."
			if tile.x>=22 and tile.x<=24:
				return "A ponte é uma passagem. Construa em terra firme, ao lado da estrada."
			if is_terrain_natural(tile):
				return "Este terreno faz parte do bosque. Escolha uma área livre."
			if not _terrain_walkable(tile):
				return "A construção precisa de terreno firme em toda a área."
	for road in roads:
		if road.stage != "cancelled" and area.has_point(road.cell):
			return "Preserve o caminho: escolha um terreno ao lado da estrada."
	if area.has_point(HUB):
		return "Preserve a entrada do edifício principal."
	for building in buildings:
		if building.stage == "cancelled":
			continue
		if area.intersects(Rect2i(building.cell,footprint_size(building.kind))) or area.has_point(building.entrance) or area.has_point(_professional_work_cell(building)) or area.has_point(_builder_work_cell(building)):
			return "Espaço ocupado ou acesso de outra construção."
	for person in workers:
		if area.has_point(person.cell):
			return "Há um morador passando. Aguarde um instante."
	var access := cell+_entrance_offset(kind)
	var work_cell := access+Vector2i.RIGHT
	if not is_walkable(access) or not is_walkable(work_cell):
		return "Deixe livre a entrada e o espaço de trabalho da construção."
	var temporary_cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			var tile := cell+Vector2i(x,y)
			temporary_cells.append(tile)
			navigation.set_point_solid(tile,true)
	var valid := not navigation.get_id_path(HUB,access).is_empty() and not navigation.get_id_path(HUB,work_cell).is_empty()
	for building in buildings:
		if building.stage != "cancelled" and navigation.get_id_path(HUB,building.entrance).is_empty():
			valid = false
	for person in workers:
		if person.cell != HUB and navigation.get_id_path(person.cell,HUB).is_empty():
			valid = false
	for tile in temporary_cells:
		navigation.set_point_solid(tile,false)
	return "" if valid else "Esta obra bloquearia o acesso da vila."


func _store_for(_cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building.kind == "hall" and building.stage == "complete":
			return building
	return {}


func _free_cell(origin: Vector2i) -> Vector2i:
	# New arrivals join the square rather than claiming a future building lot.
	var seats := plaza_rest_cells()
	if not seats.is_empty():
		var least := seats[0]
		var load_count := workers.size()+1
		for cell in seats:
			var count := 0
			for person in workers:
				if person.cell == cell: count += 1
			if count < load_count:
				least = cell
				load_count = count
		return least
	for radius in range(1,12):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var cell := origin+Vector2i(x,y)
				if is_walkable(cell) and not _occupied(cell) and not _is_access(cell) and cell != HUB and road_at(cell).is_empty():
					return cell
	return Vector2i(-1,-1)


func _uses_roads(person: Dictionary) -> bool:
	return person.role == "servant" and (person.task.get("type","") == "delivery" or not person.cargo.is_empty())


func _go(person: Dictionary, goal: Vector2i) -> bool:
	if not _uses_roads(person):
		return super._go(person,goal)
	person.goal = goal
	person.route = _road_path(person.cell,goal)
	person.wait = 0
	if person.cell != goal and person.route.is_empty():
		person.state = "Estrada interrompida: carga preservada" if not person.cargo.is_empty() else "Aguardando estrada conectada"
		return false
	return _road_node(person.cell) and _road_node(goal)


func _transport(person: Dictionary, source: int, dest: int, item: String, amount: int) -> bool:
	var source_building := _store_for(person.cell) if source == 0 else _building(source)
	var destination := _store_for(person.cell) if dest == 0 else _building(dest)
	if source_building.is_empty() or destination.is_empty() or not _connected_roads.has(source_building.entrance) or not is_building_connected(destination):
		return false
	if not _road_reaches(person.cell,source_building.entrance) or not _road_reaches(source_building.entrance,destination.entrance):
		return false
	person.task = {"type":"delivery","phase":"pickup","source":source,"building":dest,"source_cell":source_building.entrance,"dest_cell":destination.entrance,"item":item,"amount":amount}
	if not _go(person,source_building.entrance):
		person.task = {}
		return false
	if source == 0:
		reserved[item] += amount
	person.state = "Buscando "+ITEM_NAMES[item]+" pela estrada"
	return true


func _assign_delivery(person: Dictionary) -> void:
	if not _road_node(person.cell):
		if _has_pending_road_delivery() and super._go(person,HUB):
			person.task = {"type":"join_road","building":buildings[0].id}
			person.state = "Indo ao depósito para iniciar entregas"
		return
	super._assign_delivery(person)


func _has_pending_road_delivery() -> bool:
	# Match inherited delivery eligibility before asking a parked servant to join.
	# A producer existing does not imply work: its output may be empty, reserved,
	# or already stocked to its target. Idle servants should keep access clear.
	var can_export := _storage_used()+_incoming(0,"food") < storage_capacity()
	var export_targets := {"wood":100,"stone":60,"food":120,"grapes":24,"wine":32}
	for building in buildings:
		if not _connected_roads.has(building.entrance):
			continue
		if building.stage == "materials":
			for item in definition(building.kind).cost:
				var missing: int = int(definition(building.kind).cost[item])-int(building.delivered[item])-_incoming(building.id,item)
				if missing > 0 and available(item) > 0:
					return true
		if building.kind == "winery" and building.stage == "complete":
			if 6-int(building.input.grapes)-_incoming(building.id,"grapes") > 0 and available("grapes") > 0:
				return true
		for item in ITEMS:
			if int(building.output[item])-_outgoing(building.id,item) <= 0:
				continue
			if building.stage == "cancelled" and _storage_used()+2 <= storage_capacity():
				return true
			if can_export and int(stock[item])+_incoming(0,item) < int(export_targets[item]):
				return true
	return false


func _assign_export(person: Dictionary) -> bool:
	if _storage_used()+2 <= storage_capacity():
		for building in buildings:
			if building.stage != "cancelled":
				continue
			for item in ITEMS:
				var remaining: int = int(building.output[item])-_outgoing(building.id,item)
				if remaining > 0 and _transport(person,building.id,0,item,mini(2,remaining)):
					return true
	return super._assign_export(person)


func _assign_return(person: Dictionary) -> void:
	if _road_reaches(person.cell,HUB):
		person.task = {"type":"delivery","phase":"deliver","source":-1,"building":0,"dest_cell":HUB,"item":person.cargo.item,"amount":person.cargo.amount}
		_go(person,HUB)
		person.state = "Devolvendo materiais pela estrada"
	else:
		person.state = "Carga preservada: reconecte a estrada ao depósito"


func _delivery_work(person: Dictionary) -> void:
	if person.task.get("phase","") == "pickup" and not _road_reaches(person.cell,person.task.dest_cell):
		person.state = "Aguardando reconexão da estrada"
		return
	super._delivery_work(person)


func _assign_builder(person: Dictionary) -> void:
	for road in roads:
		if road.stage != "planned" or road.builder != -1 or not road.funded:
			continue
		var connected := false
		for direction in ROAD_DIRECTIONS:
			if _road_reaches(HUB,road.cell+direction):
				connected = true
				break
		if not connected or not super._go(person,_professional_work_cell(buildings[0])):
			continue
		road.builder = person.id
		person.task = {"type":"road","phase":"pickup","road":road.id,"building":buildings[0].id}
		person.state = "Buscando pedra para a estrada"
		return
	for building in buildings:
		if building.builder != -1 or building.stage not in ["preparing","materials","building"]:
			continue
		if building.stage == "materials" and not _materials_ready(building):
			continue
		if not _go(person,_builder_work_cell(building)):
			continue
		building.builder = person.id
		person.task = {"type":"prepare" if building.stage == "preparing" else "build","building":building.id}
		person.state = "Indo à obra"
		return


func _release(person: Dictionary) -> void:
	if person.task.get("type","") == "road":
		var road := _road(int(person.task.get("road",-1)))
		if not road.is_empty():
			road.builder = -1
	super._release(person)


func _work(person: Dictionary) -> void:
	if not person.route.is_empty() or person.cell != person.goal:
		return
	if person.task.get("type","") == "join_road":
		_release(person)
		return
	if person.task.get("type","") != "road":
		super._work(person)
		return
	var road := _road(int(person.task.road))
	if road.is_empty() or road.stage == "cancelled":
		_release(person)
		return
	if person.task.phase == "pickup":
		if stock.stone < 1:
			person.state = "Aguardando pedra reservada"
			return
		stock.stone -= 1
		reserved.stone -= 1
		road.funded = false
		road.stage = "building"
		person.cargo = {"item":"stone","amount":1}
		person.task.phase = "build"
		person.goal = road.cell
		super._go(person,road.cell)
		person.state = "Levando pedra à frente da estrada"
		return
	road.progress = minf(1.0,float(road.progress)+0.05)
	person.state = "Construindo estrada"
	if road.progress >= 1.0:
		road.stage = "complete"
		road.reason = ""
		consumed.stone += 1
		person.cargo = {}
		_release(person)
		_rebuild_roads()


func _assign_workplaces() -> void:
	for building in buildings:
		if building.stage != "complete" or building.worker != -1 or not is_building_connected(building):
			continue
		var profession: String = definition(building.kind).profession
		if profession.is_empty():
			continue
		for person in workers:
			if person.role != profession or not person.task.is_empty() or not person.cargo.is_empty():
				continue
			if not _go(person,_professional_work_cell(building)) and not _go(person,_builder_work_cell(building)):
				continue
			building.worker = person.id
			person.task = {"type":"produce","building":building.id}
			person.state = "Indo trabalhar"
			break


func _update_training() -> void:
	var completed: Array[Dictionary] = []
	for t in training:
		if t.worker == -1:
			var center: Dictionary = {}
			for b in buildings:
				if b.kind != "training" or b.stage != "complete" or b.worker < 0 or not is_building_connected(b):
					continue
				var instructor := _worker(b.worker)
				if instructor.is_empty() or not instructor.route.is_empty():
					continue
				var occupied := false
				for other in training:
					if other.building == b.id:
						occupied = true
				if not occupied:
					center = b
					break
			if center.is_empty():
				t.reason = "Conecte a escola ou aguarde um instrutor e uma vaga"
				continue
			if available("food") < 2:
				t.reason = "Faltam 2 alimentos para a formação"
				continue
			var candidate: Dictionary = {}
			for w in workers:
				if w.role == "resident" and w.task.is_empty() and _go(w,_builder_work_cell(center)):
					candidate = w
					break
			if candidate.is_empty():
				t.reason = "Sem moradores livres para formação"
				continue
			t.worker = candidate.id
			t.building = center.id
			candidate.task = {"type":"train","building":center.id,"training":t.id}
			candidate.state = "Indo estudar"
			_consume_stock("food",2)
		if not is_building_connected(_building(int(t.building))):
			t.reason = "Conecte a escola ao edifício principal"
			continue
		var student := _worker(t.worker)
		if student.is_empty():
			t.worker = -1
			t.building = -1
			continue
		if not student.route.is_empty() or student.cell != student.goal:
			t.reason = "Morador indo ao centro"
			continue
		t.reason = "Formando "+ROLE_NAMES[t.role].to_lower()
		t.progress = minf(1.0,float(t.progress)+0.1/20.0)
		if t.progress >= 1.0:
			student.role = t.role
			_release(student)
			completed.append(t)
			_emit(ROLE_NAMES[t.role]+" formado. Já pode assumir trabalho automaticamente.")
	for t in completed:
		training.erase(t)

func _detour(person: Dictionary) -> void:
	if not _uses_roads(person):
		var blocked: Array[Vector2i] = []
		for other in workers:
			if other.id != person.id and other.cell != person.goal and not is_plaza_cell(other.cell) and is_walkable(other.cell):
				navigation.set_point_solid(other.cell,true)
				blocked.append(other.cell)
		var route: Array[Vector2i] = navigation.get_id_path(person.cell,person.goal)
		for cell in blocked: navigation.set_point_solid(cell,false)
		if route.size() > 1:
			route.pop_front()
			person.route = route
		return
	var route := _road_path(person.cell,person.goal,true,person.id)
	if not route.is_empty():
		person.route = route
	elif not _road_reaches(person.cell,person.goal):
		person.route = []
		person.state = "Estrada interrompida: aguardando reconexão"


func _yield_worker(person: Dictionary) -> void:
	if not _uses_roads(person):
		super._yield_worker(person)
		return
	for direction in ROAD_DIRECTIONS:
		var cell: Vector2i = person.cell+direction
		if _road_node(cell) and not _occupied(cell) and cell != person.goal:
			person.cell = cell
			person.yield_until = tick+10
			person.wait = 0
			person.route = _road_path(cell,person.goal)
			return


func _move_workers() -> void:
	if tick % MOVEMENT_STEP_TICKS != 0:return
	_road_moved.clear()
	for person in workers:
		person.previous = person.cell
	for person in workers:
		if _road_moved.has(person.id) or tick < int(person.get("yield_until",0)):
			continue
		if person.task.is_empty() and person.cargo.is_empty():
			var resting := plaza_rest_cell(person)
			if resting.x >= 0:
				if person.cell == resting:
					person.route = []
					person.goal = resting
					person.state = "Na praça"
				elif person.goal != resting or person.route.is_empty():
					super._go(person,resting)
					person.state = "Voltando à praça"
		if person.route.is_empty():
			if not person.task.is_empty() and person.cell != person.goal:
				_go(person,person.goal)
		if person.route.is_empty():
			continue
		_detour(person)
		if person.route.is_empty():
			continue
		var next: Vector2i = person.route[0]
		if not is_walkable(next) or (_uses_roads(person) and not _road_node(next)):
			person.route = []
			continue
		if _occupied(next,person.id):
			person.wait += 1
			for other in workers:
				if other.cell != next or _road_moved.has(other.id):
					continue
				# Two pedestrians pass within a 2-m road segment: atomic endpoint exchange,
				# never a field shortcut, duplicate occupied cell or dropped cargo.
				if _uses_roads(person) and _uses_roads(other) and not other.route.is_empty() and other.route[0] == person.cell:
					other.cell = person.cell
					person.cell = next
					person.route.pop_front()
					other.route.pop_front()
					person.wait = 0
					other.wait = 0
					_road_moved[person.id] = true
					_road_moved[other.id] = true
					break
				if person.wait >= 3 and (other.task.is_empty() or not _uses_roads(other)):
					_yield_worker(other)
			if person.wait >= 6 and not _road_moved.has(person.id):
				_yield_worker(person)
			continue
		person.cell = next
		person.route.pop_front()
		person.wait = 0
		_road_moved[person.id] = true


func _update_reasons() -> void:
	super._update_reasons()
	for building in buildings:
		if building.kind != "hall" and building.stage not in ["cancelled","preparing","building"] and not is_building_connected(building):
			building.reason = "Conecte a entrada à estrada do edifício principal"
	for road in roads:
		if road.stage == "planned":
			road.reason = "Construtor buscando pedra" if road.builder != -1 else "Aguardando construtor e frente conectada"


func notice() -> String:
	if not is_building_connected(buildings[1]):
		return "Trace uma estrada da praça até a entrada da escola para iniciar as formações."
	for building in buildings:
		if building.stage == "materials" and not is_building_connected(building):
			return "A obra aguarda estrada até sua entrada. Os serventes só transportam por caminhos concluídos."
	return super.notice()


func snapshot() -> Dictionary:
	var state := super.snapshot()
	state.mode = "approved"
	state.roads = _encode(roads)
	return state


func _apply(state: Dictionary) -> void:
	super._apply(state)
	roads.assign(state.roads)
	_rebuild_roads()


func _valid_task(task: Dictionary) -> bool:
	if task.get("type","") == "join_road":
		return _safe_int(task.get("building"))
	if task.get("type","") == "road":
		return _safe_int(task.get("building")) and _safe_int(task.get("road")) and task.get("phase") in ["pickup","build"]
	return super._valid_task(task)


func _valid_save(state: Dictionary) -> bool:
	if state.get("mode") != "approved" or not state.get("roads") is Array or state.roads.size() > WIDTH*HEIGHT:
		return false
	var parent_state := state.duplicate(true)
	parent_state.mode = "peaceful"
	if not super._valid_save(parent_state):
		return false
	var ids := {}
	var saved_workers := {}
	for collection in [state.buildings,state.workers,state.training]:
		for entry in collection:
			ids[entry.id] = true
	for person in state.workers:
		saved_workers[person.id] = person
		if is_terrain_natural(_decode(person.cell)):
			return false
	var building_cells := {}
	var building_accesses: Array[Vector2i] = []
	for building in state.buildings:
		if building.stage == "cancelled":
			continue
		var origin: Vector2i = _decode(building.cell)
		if _decode(building.entrance) != origin+_entrance_offset(building.kind):
			return false
		var size := footprint_size(building.kind)
		if origin.x < 2 or origin.x > WIDTH-1-size.x or origin.y < 2 or origin.y > 23:
			return false
		for y in range(size.y):
			for x in range(size.x):
				var cell := origin+Vector2i(x,y)
				if cell.x>=22 and cell.x<=24:return false
				if not _terrain_walkable(cell) or building_cells.has(cell):
					return false
				building_cells[cell] = true
		var entrance: Vector2i = _decode(building.entrance)
		building_accesses.append(entrance)
		building_accesses.append(entrance+Vector2i.RIGHT)
	for access in building_accesses:
		if not _terrain_walkable(access) or building_cells.has(access):
			return false
	var saved_roads := {}
	var occupied := {}
	for road in state.roads:
		if not road is Dictionary or not _safe_int(road.get("id")) or ids.has(road.id) or not _valid_cell(road.get("cell")):
			return false
		ids[road.id] = true
		saved_roads[road.id] = road
		if road.get("stage") not in ["planned","building","complete","cancelled"] or typeof(road.get("funded")) != TYPE_BOOL:
			return false
		if typeof(road.get("progress")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(road.progress)) or road.progress < 0 or road.progress > 1:
			return false
		if typeof(road.get("builder")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(road.builder)) or road.builder != floor(road.builder) or not road.get("reason") is String:
			return false
		var cell: Vector2i = _decode(road.cell)
		if not _terrain_walkable(cell):
			return false
		if road.stage == "planned" and (not road.funded or road.progress != 0):
			return false
		if road.stage != "planned" and road.funded:
			return false
		if road.stage == "complete" and (road.progress != 1 or road.builder != -1):
			return false
		if road.stage == "cancelled" and road.builder != -1:
			return false
		if road.builder != -1:
			if not saved_workers.has(road.builder):
				return false
			var builder: Dictionary = saved_workers[road.builder]
			if builder.role != "builder" or builder.task.get("type") != "road" or builder.task.get("road") != road.id:
				return false
		if road.stage == "building":
			if road.builder == -1 or road.progress >= 1:
				return false
			var builder: Dictionary = saved_workers[road.builder]
			if builder.task.get("phase") != "build" or builder.cargo.get("item") != "stone" or builder.cargo.get("amount") != 1:
				return false
		if road.stage != "cancelled":
			if occupied.has(cell) or cell == HUB:
				return false
			occupied[cell] = true
			for building in state.buildings:
				if building.stage != "cancelled" and Rect2i(_decode(building.cell),footprint_size(building.kind)).has_point(cell):
					return false
	for person in state.workers:
		if person.task.get("type") == "road":
			if not saved_roads.has(person.task.road) or saved_roads[person.task.road].builder != person.id:
				return false
	for id in ids:
		if id >= state.next_id:
			return false
	return true


func conservation_errors() -> Array[String]:
	var errors := super.conservation_errors()
	# Shared navigation tiles in the square have separate rendered waiting slots.
	while errors.has("Civis sobrepostos"): errors.erase("Civis sobrepostos")
	var occupied_outside := {}
	for person in workers:
		if is_plaza_cell(person.cell): continue
		if occupied_outside.has(person.cell): errors.append("Civis sobrepostos fora da praça")
		occupied_outside[person.cell] = true
	var stone_reservations := 0
	for road in roads:
		if road.funded and road.stage == "planned":
			stone_reservations += 1
	for person in workers:
		if not building_at(person.cell).is_empty():
			errors.append("Civil dentro da área de uma construção")
		if person.task.get("type","") == "delivery" and person.task.get("phase","") == "pickup" and person.task.get("source",-1) == 0 and person.task.get("item","") == "stone":
			stone_reservations += int(person.task.amount)
		if person.role == "servant" and not person.cargo.is_empty() and not _road_node(person.cell):
			errors.append("Servente transportando fora da estrada")
	if int(reserved.stone) != stone_reservations:
		errors.append("Reserva de pedra inconsistente com estradas e entregas")
	return errors


func _rebuild_plaza() -> void:
	_plaza.clear()
	# Older saves keep their buildings. Only unobstructed original square tiles
	# become public paving; a fresh settlement always has all nine tiles.
	for y in range(13,16):
		for x in range(7,10):
			var cell := Vector2i(x,y)
			if building_at(cell).is_empty(): _plaza.append(cell)


func plaza_cells() -> Array[Vector2i]:
	return _plaza.duplicate()


func is_plaza_cell(cell: Vector2i) -> bool:
	return _plaza.has(cell)


func plaza_rest_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _plaza:
		if cell.y > 13 and not _is_access(cell): cells.append(cell)
	return cells


func plaza_rest_cell(person: Dictionary) -> Vector2i:
	var cells := plaza_rest_cells()
	if cells.is_empty(): return Vector2i(-1,-1)
	return cells[maxi(0,workers.find(person)) % cells.size()]


func plaza_rest_offset(person: Dictionary) -> Vector2:
	var seats := plaza_rest_cells()
	if seats.is_empty(): return Vector2.ZERO
	var lane := (maxi(0,workers.find(person)) / seats.size()) % 8
	var offsets := [Vector2(-0.65,-0.66),Vector2(0.65,0.64),Vector2(-0.65,0.64),Vector2(0.65,-0.66),Vector2(0,-0.66),Vector2(0,0.64),Vector2(-0.65,0),Vector2(0.65,0)]
	return offsets[lane]


func _occupied(cell: Vector2i, except_id: int = -1) -> bool:
	# The square has several physical waiting positions per navigation tile.
	# Its middle lanes remain passable even when all residents are at rest.
	return false if is_plaza_cell(cell) else super._occupied(cell,except_id)
