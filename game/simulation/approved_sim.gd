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
var _road_supply_navigation := AStarGrid2D.new()
var _road_supply_nodes: Dictionary = {}
var _road_supply_connected: Dictionary = {}
var _road_supply_dirty := true
var _plaza: Array[Vector2i] = []


func setup(_peaceful_mode: bool = true) -> void:
	peaceful = true
	mission = null
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
	stock = _empty_items()
	stock.wood = 140
	stock.stone = 160
	stock.food = 280
	stock.gold = 50
	stock.axe = 2
	stock.bow = 2
	initial = stock.duplicate(true)
	reserved = _empty_items()
	consumed = _empty_items()
	produced = _empty_items()
	stats = {"houses_built":0,"wine_delivered":0,"food_produced":0}
	food_shortage = 0
	arrival_ticks = 0
	last_notice = ""
	definitions = definitions.duplicate(true)
	harvest_map = load("res://simulation/harvest_map.gd").new()
	harvest_map.setup_from_natural_cells(natural_cells)
	stone_deposits = [Vector2i(12, 19), Vector2i(12, 20), Vector2i(11, 19), Vector2i(13, 19), Vector2i(10, 19)]
	definitions.hall.name = "Edifício principal"
	definitions.hall.description = "Abriga os primeiros moradores e o estoque inicial. Sua entrada inicia a rede de estradas."
	definitions.store.description = "Depósito físico. Serventes buscam e deixam mercadorias na entrada."
	definitions.farm.description = "O horticultor semeia, cultiva e colhe 8 alimentos por ciclo, em cerca de 25 s na velocidade 1×."
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
	instructor.state = tr("Ensinando no centro")
	buildings[1].worker = instructor.id
	for person in workers:
		if person.task.is_empty():
			person.cell = plaza_rest_cell(person)
			person.previous = person.cell
			person.goal = person.cell
			person.state = tr("Na praça")
	_rebuild_roads()
	_emit(tr("A praça reúne os moradores livres. Trace uma estrada até a escola; a equipe trabalha sozinha."))


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
				notices.append(tr("Nenhum construtor formado") if role=="builder" else tr("Nenhum servente formado"))
			elif idle[role] == 0:
				notices.append(tr("Construtores ocupados") if role=="builder" else tr("Serventes ocupados"))
		if not notices.is_empty():
			return _result(true,tr("Obra na fila. {details}. Forme mais na escola ou aguarde: a equipe assumirá automaticamente.").format({"details":"; ".join(notices)}))
		return result
	if kind == "road":
		var requested: Variant = payload.get("cells",[payload.get("cell")])
		if not requested is Array or requested.is_empty() or requested.size() > 200:
			return _result(false,tr("Escolha até 200 terrenos para a estrada."))
		var cells: Array[Vector2i] = []
		for cell in requested:
			if typeof(cell) != TYPE_VECTOR2I:
				return _result(false,tr("Trecho de estrada inválido."))
			if is_plaza_cell(cell) or cell == HUB or not road_at(cell).is_empty() or cells.has(cell):
				continue
			var error := can_place_road(cell)
			if not error.is_empty():
				return _result(false,error)
			cells.append(cell)
		if cells.size() > available("stone"):
			return _result(false,tr("Cada trecho reserva 1 pedra. Não há pedra suficiente para este caminho."))
		for cell in cells:
			roads.append({"id":_id(),"cell":cell,"stage":"planned","progress":0.0,"builder":-1,"funded":true,"delivered":0,"carrier":-1,"reason":tr("Aguardando servente e traçado conectado")})
			reserved.stone += 1
		_road_supply_dirty = true
		return _result(true,tr("Estrada planejada. Serventes levam pedra às frentes conectadas e construtores trabalham em paralelo.") if not cells.is_empty() else tr("Este caminho já está planejado."))
	if kind == "remove_road":
		if payload.get("cell") is Vector2i and is_plaza_cell(payload.cell):
			return _result(false,tr("A praça é o ponto de encontro da vila e permanece livre."))
		if typeof(payload.get("cell")) != TYPE_VECTOR2I:
			return _result(false,tr("Escolha um trecho de estrada."))
		var road := road_at(payload.cell)
		if road.is_empty():
			return _result(false,tr("Não há estrada neste terreno."))
		if road.builder != -1 or _occupied(road.cell):
			return _result(false,tr("Aguarde a pessoa sair deste trecho antes de removê-lo."))
		if road.funded:
			reserved.stone -= 1
			road.funded = false
		road.stage = "cancelled"
		_rebuild_roads()
		_road_supply_cancel(road)
		return _result(true,tr("Trecho removido. Cargas permanecem com os serventes até existir um caminho."))
	return super.command(kind,payload)


func can_place_road(cell: Vector2i) -> String:
	if is_plaza_cell(cell):
		return tr("A praça já está pavimentada. Comece sua estrada em uma de suas bordas.")
	if cell == HUB:
		return tr("A entrada do edifício principal já é a origem da rede.")
	if not is_walkable(cell):
		return tr("Estradas precisam de terreno livre.")
	if not road_at(cell).is_empty():
		return tr("Este trecho já existe ou está planejado.")
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
	_road_supply_dirty = true
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
	if kind == "farm":building.crop_cycles = 0
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
	if mission != null and mission.has_method("allows_building") and not mission.allows_building(kind):
		return tr("Esta construção ainda não está disponível nesta missão.")
	if not definitions.has(kind) or kind == "hall":
		return tr("Construção desconhecida ou não disponível nesta vila.")
	if kind == "quarry" and not _quarry_has_deposit(cell):
		return tr("A pedreira precisa ficar junto a uma jazida de pedra.")
	var size := footprint_size(kind)
	if cell.x < 2 or cell.x > WIDTH-1-size.x or cell.y < 2 or cell.y > 23:
		return tr("Deixe espaço para toda a construção e sua entrada dentro do vale.")
	var area := Rect2i(cell,size)
	for y in range(size.y):
		for x in range(size.x):
			var tile := cell+Vector2i(x,y)
			if is_plaza_cell(tile):
				return tr("A praça fica livre para os moradores. Construa ao redor dela.")
			if tile.x>=22 and tile.x<=24:
				return tr("A ponte é uma passagem. Construa em terra firme, ao lado da estrada.")
			if is_terrain_natural(tile):
				return tr("Este terreno faz parte do bosque. Escolha uma área livre.")
			if not _terrain_walkable(tile):
				return tr("A construção precisa de terreno firme em toda a área.")
	for road in roads:
		if road.stage != "cancelled" and area.has_point(road.cell):
			return tr("Preserve o caminho: escolha um terreno ao lado da estrada.")
	if area.has_point(HUB):
		return tr("Preserve a entrada do edifício principal.")
	for building in buildings:
		if building.stage == "cancelled":
			continue
		if area.intersects(Rect2i(building.cell,footprint_size(building.kind))) or area.has_point(building.entrance) or area.has_point(_professional_work_cell(building)) or area.has_point(_builder_work_cell(building)):
			return tr("Espaço ocupado ou acesso de outra construção.")
	for person in workers:
		if area.has_point(person.cell):
			return tr("Há um morador passando. Aguarde um instante.")
	var access := cell+_entrance_offset(kind)
	var work_cell := access+Vector2i.RIGHT
	if not is_walkable(access) or not is_walkable(work_cell):
		return tr("Deixe livre a entrada e o espaço de trabalho da construção.")
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
	return "" if valid else tr("Esta obra bloquearia o acesso da vila.")


func _store_for(_cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building.kind == "store" and building.stage == "complete" and is_building_connected(building):
			return building
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
	return person.role == "servant" and (person.task.get("type","") in ["delivery","road_delivery"] or not person.cargo.is_empty())


func _go(person: Dictionary, goal: Vector2i) -> bool:
	if not _uses_roads(person):
		return super._go(person,goal)
	person.goal = goal
	person.route = _person_road_path(person,person.cell,goal)
	person.wait = 0
	if person.cell != goal and person.route.is_empty():
		person.state = tr("Estrada interrompida: carga preservada") if not person.cargo.is_empty() else tr("Aguardando estrada conectada")
		return false
	return _person_road_node(person,person.cell) and _person_road_node(person,goal)


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
	person.state = tr("Buscando {item} pela estrada").format({"item":tr(ITEM_NAMES[item])})
	return true


func _assign_delivery(person: Dictionary) -> void:
	if (int(person.get("jobs",0)) % 2 == 0 or not _road_node(person.cell)) and _assign_road_supply(person): return
	if not _road_node(person.cell):
		if _has_pending_road_delivery() and super._go(person,HUB):
			person.task = {"type":"join_road","building":buildings[0].id}
			person.state = tr("Indo ao depósito para iniciar entregas")
		return
	super._assign_delivery(person)
	if person.task.is_empty(): _assign_road_supply(person)


func _has_pending_road_delivery() -> bool:
	if _road_supply_demand(): return true
	# Match inherited delivery eligibility before asking a parked servant to join.
	# A producer existing does not imply work: its output may be empty, reserved,
	# or already stocked to its target. Idle servants should keep access clear.
	var can_export := _storage_used()+_incoming(0,"food") < storage_capacity()
	var export_targets := {"wood":100,"stone":60,"food":_food_stock_target(),"grapes":24,"wine":32,"gold":40,"trunks":24,"corn":24,"flour":16,"loaves":24,"axe":8,"bow":8}
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
		if building.kind == "training" and building.stage == "complete" and _school_gold_need(building) > 0 and available("gold") > 0:
			return true
		if building.kind == "sawmill" and building.stage == "complete" and 6-int(building.input.get("trunks",0))-_incoming(building.id,"trunks") > 0 and available("trunks") > 0:
			return true
		if building.kind == "mill" and building.stage == "complete" and 6-int(building.input.get("corn",0))-_incoming(building.id,"corn") > 0 and available("corn") > 0:
			return true
		if building.kind == "bakery" and building.stage == "complete" and 6-int(building.input.get("flour",0))-_incoming(building.id,"flour") > 0 and available("flour") > 0:
			return true
		if building.kind == "inn" and building.stage == "complete":
			for item in ["loaves", "food", "wine"]:
				if 8-int(building.input.get(item,0))-_incoming(building.id,item) > 0 and available(item) > 0:
					return true
		if building.kind == "workshop" and building.stage == "complete" and 6-int(building.input.get("wood",0))-_incoming(building.id,"wood") > 0 and available("wood") > 0:
			return true
		for item in ITEMS:
			if int(building.output[item])-_outgoing(building.id,item) <= 0:
				continue
			if building.stage == "cancelled" and _storage_used()+2 <= storage_capacity():
				return true
			if can_export and int(stock[item])+_incoming(0,item) < int(export_targets.get(item, 12)):
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
	# Starter food exceeds the legacy refill target. Keep room for all resources,
	# but let the first harvest actually leave the garden and reach the depot.
	if int(stock.food)+_incoming(0,"food") < _food_stock_target() and _storage_used()+_incoming(0,"food")+2 <= storage_capacity():
		for building in buildings:
			var remaining: int = int(building.output.food)-_outgoing(building.id,"food")
			if remaining > 0 and _transport(person,building.id,0,"food",mini(2,remaining)):
				return true
	return super._assign_export(person)


func _food_stock_target() -> int:
	return maxi(120,floori(storage_capacity()*0.40))


func _assign_return(person: Dictionary) -> void:
	if _road_reaches(person.cell,HUB):
		person.task = {"type":"delivery","phase":"deliver","source":-1,"building":0,"dest_cell":HUB,"item":person.cargo.item,"amount":person.cargo.amount}
		_go(person,HUB)
		person.state = tr("Devolvendo materiais pela estrada")
	else:
		person.state = tr("Carga preservada: reconecte a estrada ao depósito")


func _delivery_work(person: Dictionary) -> void:
	if person.task.get("phase","") == "pickup" and not _road_reaches(person.cell,person.task.dest_cell):
		person.state = tr("Aguardando reconexão da estrada")
		return
	super._delivery_work(person)


func _assign_builder(person: Dictionary) -> void:
	_road_supply_prepare()
	for road in roads:
		if road.stage not in ["planned","building"] or road.builder != -1 or int(road.get("delivered",0)) != 1 or not _road_supply_connected.has(road.cell): continue
		if not super._go(person,road.cell): continue
		road.builder = person.id
		person.task = {"type":"road","phase":"build","road":road.id,"building":buildings[0].id}
		person.state = tr("Indo pavimentar trecho abastecido")
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
		person.state = tr("Indo à obra")
		return


func _release(person: Dictionary) -> void:
	if _road_supply_task(person):
		var road := _road(int(person.task.get("road",-1)))
		if not road.is_empty() and int(road.get("carrier",-1)) == person.id: road.carrier = -1
	if person.task.get("type","") == "road":
		var road := _road(int(person.task.get("road",-1)))
		if not road.is_empty():
			road.builder = -1
	super._release(person)


func _work(person: Dictionary) -> void:
	if not person.route.is_empty() or person.cell != person.goal:
		return
	if _road_supply_task(person):
		_road_supply_work(person)
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
			person.state = tr("Aguardando pedra reservada")
			return
		stock.stone -= 1
		reserved.stone -= 1
		road.funded = false
		road.stage = "building"
		person.cargo = {"item":"stone","amount":1}
		person.task.phase = "build"
		person.goal = road.cell
		super._go(person,road.cell)
		person.state = tr("Levando pedra à frente da estrada")
		return
	# Legacy saves may contain a builder already carrying its own road stone.
	if person.cargo.get("item","") == "stone" and int(person.cargo.get("amount",0)) == 1:
		road.delivered = 1
		person.cargo = {}
	if int(road.get("delivered",0)) != 1:
		_release(person)
		return
	road.stage = "building"
	road.progress = minf(1.0,float(road.progress)+0.05)
	person.state = tr("Construindo estrada")
	if road.progress >= 1.0:
		road.stage = "complete"
		road.reason = ""
		consumed.stone += 1
		road.delivered = 0
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
			if int(person.get("meal", 0)) <= 0:
				continue
			if not _go(person,_professional_work_cell(building)) and not _go(person,_builder_work_cell(building)):
				continue
			building.worker = person.id
			person.task = {"type":"produce","building":building.id}
			person.state = tr("Indo trabalhar")
			break



# A farm cycle uses the existing persisted production value; no render clock grows food.
const CROP_CYCLE_SECONDS := 10.0
const CROP_OUTPUT_AMOUNT := 8
const CROP_STAGE_EDGES := [0.0,0.18,0.42,0.82,1.0]
const CROP_STAGE_KEYS := ["seeding","sprouts","growing","harvest"]
const CROP_STAGE_LABELS := ["Semeando","Brotos nascendo","Folhas crescendo","Colhendo"]

func crop_status(building: Dictionary) -> Dictionary:
	if building.is_empty() or building.get("kind","") != "farm":return {}
	var progress: float = clampf(float(building.get("production",0.0)),0.0,1.0)
	var index := 0
	for i in range(1,4):
		if progress >= CROP_STAGE_EDGES[i]:index = i
	var phase: String = CROP_STAGE_KEYS[index]
	var label: String = tr(CROP_STAGE_LABELS[index])
	if progress == 0.0:
		phase = "soil"
		label = tr("Solo preparado")
	var reason := ""
	var person: Dictionary = _worker(int(building.get("worker",-1)))
	if building.get("stage","") != "complete":reason = tr("A horta ainda está em construção")
	elif not is_building_connected(building):reason = tr("Conecte a horta ao edifício principal")
	elif person.is_empty() or person.role != "farmer" or person.task.get("type","") != "produce" or person.task.get("building",-1) != building.id:
		reason = tr("Aguardando horticultor formado")
	elif not person.route.is_empty() or person.cell != person.goal or person.cell not in [_professional_work_cell(building),_builder_work_cell(building)]:
		reason = tr("Horticultor a caminho da horta")
	elif int(building.output.food) >= 20:
		reason = tr("Reserva de alimentos abastecida: aguardando consumo") if int(stock.food)+_incoming(0,"food") >= _food_stock_target() else tr("Aguardando retirada dos alimentos pelos serventes")
	elif paused:reason = tr("Jogo pausado")
	elif lost:reason = tr("Cultivo interrompido")
	return {"stage":phase,"label":label,"progress":progress,"stage_progress":inverse_lerp(CROP_STAGE_EDGES[index],CROP_STAGE_EDGES[index+1],progress),"active":reason.is_empty(),"reason":reason,"completed_cycles":int(building.get("crop_cycles",0)),"seconds_remaining":(1.0-progress)*CROP_CYCLE_SECONDS,"output_amount":CROP_OUTPUT_AMOUNT,"cycle_seconds":CROP_CYCLE_SECONDS}

func _produce(person: Dictionary, building: Dictionary) -> void:
	if building.is_empty() or building.get("kind","") != "farm":
		super._produce(person,building)
		return
	if int(person.get("meal", 0)) <= 0:
		_release(person)
		_seek_inn(person)
		return
	if building.stage != "complete":
		_release(person)
		return
	var crop: Dictionary = crop_status(building)
	if not crop.active:
		person.state = crop.reason
		return
	person.state = tr("Trabalhando na horta: {stage}").format({"stage":str(crop.label)})
	# Each harvest takes exactly 100 fixed simulation ticks. Quantize to that
	# grid so a JSON roundtrip cannot shift a visible stage by floating drift.
	building.production = float(roundi(float(building.production)*100.0)+1)/100.0
	if building.production >= 1.0:
		building.production = 0.0
		building.crop_cycles = int(building.get("crop_cycles",0))+1
		building.output.food += CROP_OUTPUT_AMOUNT
		produced.food += CROP_OUTPUT_AMOUNT
		stats.food_produced += CROP_OUTPUT_AMOUNT
		building.output.corn = int(building.output.get("corn", 0)) + CROP_OUTPUT_AMOUNT
		produced.corn += CROP_OUTPUT_AMOUNT
		person.state = tr("Colheita recolhida: iniciando novo plantio")


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
				t.reason = tr("Conecte a escola ou aguarde um instrutor e uma vaga")
				continue
			if int(center.input.get("gold",0)) < 1:
				t.reason = tr("Aguardando ouro na escola")
				continue
			var spawn: Vector2i = _builder_work_cell(center)
			if not is_walkable(spawn) or _occupied(spawn):
				spawn = center.entrance
			if not is_walkable(spawn) or _occupied(spawn):
				t.reason = tr("Entrada da escola ocupada")
				continue
			var candidate: Dictionary = _add_worker("resident", spawn)
			t.worker = candidate.id
			t.building = center.id
			candidate.task = {"type":"train","building":center.id,"training":t.id}
			candidate.goal = spawn
			candidate.previous = spawn
			candidate.state = tr("Novo civil em formação")
			center.input.gold -= 1
			consumed.gold += 1
		if not is_building_connected(_building(int(t.building))):
			t.reason = tr("Conecte a escola ao edifício principal")
			continue
		var student := _worker(t.worker)
		if student.is_empty():
			t.worker = -1
			t.building = -1
			continue
		if not student.route.is_empty() or student.cell != student.goal:
			t.reason = tr("Morador indo ao centro")
			continue
		t.reason = tr("Formando {role}").format({"role":tr(ROLE_NAMES[t.role]).to_lower()})
		t.progress = minf(1.0,float(t.progress)+0.1/20.0)
		if t.progress >= 1.0:
			student.role = t.role
			_release(student)
			completed.append(t)
			_emit(tr("{role} formado. Já pode assumir trabalho automaticamente.").format({"role":tr(ROLE_NAMES[t.role])}),"chime")
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
	var route := _person_road_path(person,person.cell,person.goal,true)
	if not route.is_empty():
		person.route = route
	elif not _person_road_reaches(person,person.cell,person.goal):
		person.route = []
		person.state = tr("Estrada interrompida: aguardando reconexão")


func _yield_worker(person: Dictionary) -> void:
	if not _uses_roads(person):
		super._yield_worker(person)
		return
	for direction in ROAD_DIRECTIONS:
		var cell: Vector2i = person.cell+direction
		if _person_road_node(person,cell) and not _occupied(cell) and cell != person.goal:
			person.cell = cell
			person.yield_until = tick+10
			person.wait = 0
			person.route = _person_road_path(person,cell,person.goal)
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
					person.state = tr("Na praça")
				elif person.goal != resting or person.route.is_empty():
					super._go(person,resting)
					person.state = tr("Voltando à praça")
		if person.route.is_empty():
			if not person.task.is_empty() and person.cell != person.goal:
				_go(person,person.goal)
		if person.route.is_empty():
			continue
		_detour(person)
		if person.route.is_empty():
			continue
		var next: Vector2i = person.route[0]
		if not is_walkable(next) or (_uses_roads(person) and not _person_road_node(person,next)):
			person.route = []
			continue
		if _occupied(next,person.id):
			person.wait += 1
			for other in workers:
				if other.cell != next or _road_moved.has(other.id):
					continue
				# Two pedestrians pass within a 2-m road segment: atomic endpoint exchange,
				# never a field shortcut, duplicate occupied cell or dropped cargo.
				if _uses_roads(person) and _uses_roads(other) and not other.route.is_empty() and other.route[0] == person.cell and _person_road_node(other,person.cell):
					other.cell = person.cell
					person.cell = next
					person.route.pop_front()
					other.route.pop_front()
					person.wait = 0
					other.wait = 0
					_road_moved[person.id] = true
					_road_moved[other.id] = true
					break
				if person.wait >= 3 and (other.task.is_empty() or not _uses_roads(other) or (_road_supply_task(person) and _uses_roads(other) and other.route.is_empty())):
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
			building.reason = tr("Conecte a entrada à estrada do edifício principal")
	_road_supply_prepare()
	for road in roads:
		if road.stage not in ["planned","building"]: continue
		if road.builder != -1:
			road.reason = tr("Construtor pavimentando") if road.stage == "building" else tr("Construtor a caminho")
		elif int(road.get("delivered",0)) == 1:
			road.reason = tr("Pedra entregue: aguardando construtor")
		elif int(road.get("carrier",-1)) != -1:
			var courier := _worker(int(road.carrier))
			road.reason = tr("Pedra em transporte") if not courier.cargo.is_empty() else tr("Servente buscando pedra")
		elif not _road_supply_connected.has(road.cell):
			road.reason = tr("Conecte o traçado à praça ou à estrada")
		else:
			road.reason = tr("Aguardando servente para levar pedra")


func notice() -> String:
	if not is_building_connected(buildings[1]):
		return tr("Trace uma estrada da praça até a entrada da escola para iniciar as formações.")
	for building in buildings:
		if building.stage == "materials" and not is_building_connected(building):
			return tr("A obra aguarda estrada até sua entrada. Os serventes só transportam por caminhos concluídos.")
	return super.notice()


func snapshot() -> Dictionary:
	var state := super.snapshot()
	state.mode = "approved"
	state.roads = _encode(roads)
	return state


func _apply(state: Dictionary) -> void:
	super._apply(state)
	roads.assign(state.roads)
	for building in buildings:
		if building.kind == "farm" and not building.has("crop_cycles"):building.crop_cycles = 0
	for road in roads:
		if not road.has("delivered"): road.delivered = 0
		if not road.has("carrier"): road.carrier = -1
	_rebuild_roads()


func _valid_task(task: Dictionary) -> bool:
	if task.get("type","") == "road_delivery":
		return _safe_int(task.get("building")) and _safe_int(task.get("road")) and task.get("phase") in ["pickup","deliver","recover","return"] and task.get("item") == "stone" and _safe_int(task.get("amount")) and task.get("amount") == 1 and _valid_cell(task.get("dest_cell"))
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
		if building.kind == "farm":
			if float(building.production) < 0.0 or float(building.production) >= 1.0:return false
			if building.has("crop_cycles") and not _safe_int(building.crop_cycles):return false
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
		if not _road_supply_valid_road(road,saved_workers): return false
		if road.stage != "cancelled":
			if occupied.has(cell) or cell == HUB:
				return false
			occupied[cell] = true
			for building in state.buildings:
				if building.stage != "cancelled" and Rect2i(_decode(building.cell),footprint_size(building.kind)).has_point(cell):
					return false
	for person in state.workers:
		if not _road_supply_valid_person(person,saved_roads): return false
		if person.task.get("type") == "road":
			if not saved_roads.has(person.task.road) or saved_roads[person.task.road].builder != person.id:
				return false
	for id in ids:
		if id >= state.next_id:
			return false
	return true


func conservation_errors() -> Array[String]:
	var errors := super.conservation_errors()
	# The parent counts depots, buildings and carried loads; also count road piles.
	if _road_supply_stone_balanced():
		errors.erase("Conservação: stone")
	elif not errors.has("Conservação: stone"):
		errors.append("Conservação: stone")
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
		if person.role == "servant" and not person.cargo.is_empty() and not _person_road_node(person,person.cell):
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


# Planned road fronts are a private network for road stone. Ordinary deliveries
# continue to use road_navigation, which contains completed paving only.
func _road_supply_prepare() -> void:
	if not _road_supply_dirty: return
	_road_supply_dirty = false
	_road_supply_nodes = _complete_roads.duplicate()
	_road_supply_nodes[HUB] = true
	for road in roads:
		if road.stage in ["planned","building"]: _road_supply_nodes[road.cell] = true
	_road_supply_navigation.region = Rect2i(0,0,WIDTH,HEIGHT)
	_road_supply_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_road_supply_navigation.update()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x,y)
			_road_supply_navigation.set_point_solid(cell,not _road_supply_nodes.has(cell))
	_road_supply_connected.clear()
	var pending: Array[Vector2i] = [HUB]
	_road_supply_connected[HUB] = true
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		for direction in ROAD_DIRECTIONS:
			var next: Vector2i = cell+direction
			if _road_supply_nodes.has(next) and not _road_supply_connected.has(next):
				_road_supply_connected[next] = true
				pending.append(next)


func _road_supply_task(person: Dictionary) -> bool:
	return person.task.get("type","") == "road_delivery"


func _road_supply_node(person: Dictionary, cell: Vector2i) -> bool:
	_road_supply_prepare()
	if _road_supply_nodes.has(cell): return true
	# A cancelled pile is a recovery endpoint, never a through road for other loads.
	if person.task.get("phase","") in ["recover","return"]:
		var road := _road(int(person.task.get("road",-1)))
		return not road.is_empty() and road.stage == "cancelled" and cell == road.cell
	return false


func _road_supply_path(person: Dictionary, start: Vector2i, goal: Vector2i, avoid_people: bool = false) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _road_supply_node(person,start) or not _road_supply_node(person,goal) or start == goal: return path
	var opened: Array[Vector2i] = []
	for cell in [start,goal]:
		if not _road_supply_nodes.has(cell):
			_road_supply_navigation.set_point_solid(cell,false)
			opened.append(cell)
	var blocked: Array[Vector2i] = []
	if avoid_people:
		for other in workers:
			if other.id != person.id and other.cell != start and other.cell != goal and not is_plaza_cell(other.cell) and _road_supply_nodes.has(other.cell):
				_road_supply_navigation.set_point_solid(other.cell,true)
				blocked.append(other.cell)
	path = _road_supply_navigation.get_id_path(start,goal)
	for cell in blocked: _road_supply_navigation.set_point_solid(cell,false)
	for cell in opened: _road_supply_navigation.set_point_solid(cell,true)
	if not path.is_empty(): path.pop_front()
	return path


func _person_road_node(person: Dictionary, cell: Vector2i) -> bool:
	return _road_supply_node(person,cell) if _road_supply_task(person) else _road_node(cell)


func _person_road_path(person: Dictionary, start: Vector2i, goal: Vector2i, avoid_people: bool = false) -> Array[Vector2i]:
	return _road_supply_path(person,start,goal,avoid_people) if _road_supply_task(person) else _road_path(start,goal,avoid_people,person.id)


func _person_road_reaches(person: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	if not _road_supply_task(person): return _road_reaches(start,goal)
	return _road_supply_node(person,start) and _road_supply_node(person,goal) and (start == goal or not _road_supply_path(person,start,goal).is_empty())


func _road_supply_recoverable(road: Dictionary) -> bool:
	if road.stage != "cancelled" or int(road.get("delivered",0)) != 1 or int(road.get("carrier",-1)) != -1: return false
	_road_supply_prepare()
	for direction in ROAD_DIRECTIONS:
		if _road_supply_connected.has(road.cell+direction): return true
	return false


func _road_supply_demand() -> bool:
	_road_supply_prepare()
	for road in roads:
		if _road_supply_recoverable(road): return true
		if road.stage == "planned" and road.funded and int(road.get("carrier",-1)) == -1 and road.builder == -1 and _road_supply_connected.has(road.cell): return true
	return false


func _assign_road_supply(person: Dictionary) -> bool:
	_road_supply_prepare()
	for recovery in [true,false]:
		for road in roads:
			if recovery:
				if not _road_supply_recoverable(road): continue
			elif road.stage != "planned" or not road.funded or int(road.get("carrier",-1)) != -1 or road.builder != -1 or not _road_supply_connected.has(road.cell):
				continue
			person.task = {"type":"road_delivery","phase":"recover" if recovery else "pickup","road":road.id,"building":buildings[0].id,"item":"stone","amount":1,"dest_cell":HUB if recovery else road.cell}
			var goal: Vector2i = road.cell if recovery else HUB
			if not _person_road_reaches(person,person.cell,goal):
				person.task = {}
				continue
			road.carrier = person.id
			_go(person,goal)
			person.state = tr("Recolhendo pedra do trecho cancelado") if recovery else tr("Buscando pedra para a estrada")
			return true
	return false


func _road_supply_return(person: Dictionary) -> void:
	person.task.phase = "return"
	person.task.dest_cell = HUB
	_go(person,HUB)
	person.state = tr("Devolvendo pedra de estrada") if not person.route.is_empty() or person.cell == HUB else tr("Pedra preservada: reconecte o traçado ao depósito")


func _road_supply_work(person: Dictionary) -> void:
	var road := _road(int(person.task.road))
	if road.is_empty():
		_release(person)
		return
	match str(person.task.phase):
		"pickup":
			if road.stage != "planned" or not road.funded:
				_release(person)
				return
			if not _person_road_reaches(person,HUB,road.cell):
				person.state = tr("Aguardando reconexão do traçado")
				return
			if stock.stone < 1:
				person.state = tr("Aguardando pedra reservada")
				return
			stock.stone -= 1
			reserved.stone -= 1
			road.funded = false
			person.cargo = {"item":"stone","amount":1}
			person.task.phase = "deliver"
			_go(person,road.cell)
			person.state = tr("Levando pedra ao trecho da estrada")
		"deliver":
			if road.stage == "cancelled":
				_road_supply_return(person)
				return
			road.delivered = 1
			person.cargo = {}
			person.jobs = int(person.get("jobs",0))+1
			_release(person)
		"recover":
			if int(road.get("delivered",0)) != 1:
				_release(person)
				return
			road.delivered = 0
			person.cargo = {"item":"stone","amount":1}
			_road_supply_return(person)
		"return":
			if _storage_used()+1 > storage_capacity():
				person.state = tr("Depósito cheio: pedra preservada")
				return
			stock.stone += 1
			person.cargo = {}
			person.jobs = int(person.get("jobs",0))+1
			_release(person)


func _road_supply_cancel(road: Dictionary) -> void:
	var person := _worker(int(road.get("carrier",-1)))
	if person.is_empty() or not _road_supply_task(person): return
	if person.cargo.is_empty():
		_release(person)
	else:
		road.carrier = -1
		_road_supply_return(person)


func _road_supply_stone_balanced() -> bool:
	var physical := int(stock.stone)
	for building in buildings:
		for key in ["delivered","output","input"]: physical += int(building[key].stone)
	for person in workers:
		if person.cargo.get("item","") == "stone": physical += int(person.cargo.amount)
	for road in roads: physical += int(road.get("delivered",0))
	return physical+int(consumed.stone) == int(initial.stone)+int(produced.stone)


func _road_supply_valid_road(road: Dictionary, saved_workers: Dictionary) -> bool:
	var delivered: Variant = road.get("delivered",0)
	var carrier: Variant = road.get("carrier",-1)
	if not _safe_int(delivered) or delivered > 1: return false
	if typeof(carrier) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(carrier)) or carrier != floor(carrier) or carrier < -1: return false
	if road.stage != "planned" and road.funded: return false
	if road.funded and delivered != 0: return false
	if carrier != -1:
		if not saved_workers.has(carrier): return false
		var courier: Dictionary = saved_workers[carrier]
		if courier.role != "servant" or courier.task.get("type") != "road_delivery" or courier.task.get("road") != road.id: return false
		match str(courier.task.get("phase")):
			"pickup":
				if road.stage != "planned" or not road.funded or not courier.cargo.is_empty(): return false
			"deliver":
				if road.stage != "planned" or road.funded or delivered != 0 or courier.cargo.get("item") != "stone" or courier.cargo.get("amount") != 1: return false
			"recover":
				if road.stage != "cancelled" or delivered != 1 or not courier.cargo.is_empty(): return false
			"return":
				if road.stage != "cancelled" or delivered != 0 or courier.cargo.get("item") != "stone" or courier.cargo.get("amount") != 1: return false
			_: return false
	if road.builder != -1:
		if not saved_workers.has(road.builder): return false
		var builder: Dictionary = saved_workers[road.builder]
		if builder.role != "builder" or builder.task.get("type") != "road" or builder.task.get("road") != road.id: return false
		if carrier != -1: return false
	if road.stage == "planned":
		if road.progress != 0: return false
		if not road.funded and delivered == 0 and carrier == -1: return false
		if road.builder != -1:
			var builder: Dictionary = saved_workers[road.builder]
			if road.funded:
				if builder.task.get("phase") != "pickup" or not builder.cargo.is_empty(): return false
			elif delivered != 1 or builder.task.get("phase") != "build" or not builder.cargo.is_empty(): return false
	elif road.stage == "building":
		if road.builder == -1 or road.progress >= 1 or carrier != -1: return false
		var builder: Dictionary = saved_workers[road.builder]
		if builder.task.get("phase") != "build": return false
		var legacy_carried: bool = delivered == 0 and builder.cargo.get("item") == "stone" and builder.cargo.get("amount") == 1
		if not legacy_carried and (delivered != 1 or not builder.cargo.is_empty()): return false
	elif road.stage == "complete":
		if road.progress != 1 or road.builder != -1 or carrier != -1 or delivered != 0: return false
	elif road.stage == "cancelled":
		if road.builder != -1: return false
	return true


func _road_supply_valid_person(person: Dictionary, saved_roads: Dictionary) -> bool:
	var task: Dictionary = person.task
	if task.get("type") != "road_delivery": return true
	if person.role != "servant" or not saved_roads.has(task.road): return false
	var road: Dictionary = saved_roads[task.road]
	if task.phase == "return":
		return road.stage == "cancelled" and int(road.get("delivered",0)) == 0 and person.cargo.get("item") == "stone" and person.cargo.get("amount") == 1 and _decode(task.dest_cell) == HUB
	return int(road.get("carrier",-1)) == person.id and _decode(task.dest_cell) == (HUB if task.phase == "recover" else _decode(road.cell))
