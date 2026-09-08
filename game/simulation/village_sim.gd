extends RefCounted

const Battle = preload("res://simulation/battle_sim.gd")
const WIDTH := 36
const HEIGHT := 28
const SAVE_VERSION := 1
const ITEMS := ["wood", "stone", "food", "grapes", "wine", "gold", "trunks", "corn", "flour", "loaves", "axe", "bow"]
const ROLES := ["resident", "builder", "servant", "instructor", "lumberjack", "stonecutter", "farmer", "vintner", "miller", "baker", "recruit"]
const ROLE_NAMES := {"resident":"Morador", "builder":"Construtor", "servant":"Servente", "instructor":"Instrutor", "lumberjack":"Lenhador", "stonecutter":"Canteiro", "farmer":"Agricultor", "vintner":"Vinhateiro", "miller":"Moleiro", "baker":"Padeiro", "recruit":"Recruta"}
const ITEM_NAMES := {"wood":"madeira", "stone":"pedra", "food":"alimentos", "grapes":"uvas", "wine":"vinho", "gold":"ouro", "trunks":"troncos", "corn":"cereal", "flour":"farinha", "loaves":"pães", "axe":"machado", "bow":"arco"}
var definitions: Dictionary = {
	"hall": {"name":"Centro da vila", "description":"Administra a vila. Os moradores encontram trabalho sozinhos.", "cost":{}, "profession":"", "duration":12.0, "catalog_id":"bld_01_centro_da_vila"},
	"house": {"name":"Casa", "description":"Abrigo civil. A população nova sai da escola, não das casas.", "cost":{"wood":4,"stone":2}, "profession":"", "duration":10.0, "catalog_id":"bld_02_casas"},
	"store": {"name":"Armazém", "description":"Depósito físico. Serventes buscam e deixam mercadorias na entrada.", "cost":{"wood":8,"stone":4}, "profession":"", "duration":12.0, "catalog_id":"bld_03_armazem"},
	"training": {"name":"Escola", "description":"Gasta ouro e forma civis novos. Precisa de instrutor.", "cost":{"wood":10,"stone":6}, "profession":"instructor", "duration":14.0, "catalog_id":"bld_04_centro_de_treinamento"},
	"inn": {"name":"Taverna", "description":"Os trabalhadores vêm comer pão, ração ou vinho.", "cost":{"wood":8,"stone":4}, "profession":"", "duration":12.0, "catalog_id":"bld_19_taverna"},
	"lumber": {"name":"Cabana do lenhador", "description":"O lenhador corta árvores do mapa e traz troncos.", "cost":{"wood":6,"stone":2}, "profession":"lumberjack", "duration":10.0, "catalog_id":"bld_06_cabana_do_lenhador"},
	"sawmill": {"name":"Serraria", "description":"Transforma troncos em madeira de construção.", "cost":{"wood":8,"stone":4}, "profession":"lumberjack", "duration":12.0, "catalog_id":"bld_07_serraria"},
	"quarry": {"name":"Pedreira", "description":"Extrai pedra junto a uma jazida.", "cost":{"wood":6,"stone":2}, "profession":"stonecutter", "duration":10.0, "catalog_id":"bld_08_pedreira"},
	"farm": {"name":"Horta / cereal", "description":"Cultiva alimentos e cereal para o moinho.", "cost":{"wood":6,"stone":2}, "profession":"farmer", "duration":10.0, "catalog_id":"bld_12_horta"},
	"mill": {"name":"Moinho", "description":"Transforma cereal em farinha.", "cost":{"wood":8,"stone":4}, "profession":"miller", "duration":12.0, "catalog_id":"bld_14_moinho"},
	"bakery": {"name":"Padaria", "description":"Transforma farinha em pães para a taverna.", "cost":{"wood":8,"stone":4}, "profession":"baker", "duration":12.0, "catalog_id":"bld_15_padaria"},
	"vineyard": {"name":"Parreiral", "description":"Um vinhateiro colhe 4 uvas a cada 12 segundos.", "cost":{"wood":8,"stone":2}, "profession":"vintner", "duration":12.0, "catalog_id":"kit_03_lavouras_e_vinhedos"},
	"winery": {"name":"Vinícola", "description":"Um vinhateiro transforma 3 uvas em 2 vinhos a cada 10 segundos.", "cost":{"wood":12,"stone":6}, "profession":"vintner", "duration":16.0, "catalog_id":"bld_20_vinicola"},
	"workshop": {"name":"Oficina de armas", "description":"Faz machados e arcos com madeira.", "cost":{"wood":8,"stone":4}, "profession":"lumberjack", "duration":12.0, "catalog_id":"bld_22_carpintaria"},
	"barracks": {"name":"Quartel", "description":"Recrutas recebem machado ou arco e entram na companhia.", "cost":{"wood":12,"stone":8}, "profession":"recruit", "duration":16.0, "catalog_id":"bld_26_quartel"}
}
var tick := 0
var buildings: Array[Dictionary] = []
var workers: Array[Dictionary] = []
var stock: Dictionary = {}
var training: Array[Dictionary] = []
var events: Array[Dictionary] = []
var stats: Dictionary = {}
var battle: RefCounted
var peaceful := false
var won := false
var lost := false
var paused := false
var next_id := 1
var navigation := AStarGrid2D.new()
var reserved: Dictionary = {}
var consumed: Dictionary = {}
var produced: Dictionary = {}
var initial: Dictionary = {}
var food_shortage := 0
var arrival_ticks := 0
var last_notice := ""
var mission: RefCounted = null
var harvest_map: RefCounted = null
var stone_deposits: Array[Vector2i] = []

func setup(peaceful_mode: bool = false) -> void:
	peaceful = peaceful_mode
	mission = null
	battle = null
	tick = 0
	next_id = 1
	buildings.clear()
	workers.clear()
	training.clear()
	events.clear()
	won = false
	lost = false
	paused = false
	stock = _empty_items()
	stock.wood = 80
	stock.stone = 40
	stock.food = 100
	stock.gold = 20
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
	for spec in [["hall",Vector2i(5,11)], ["house",Vector2i(4,6)], ["store",Vector2i(8,10)], ["training",Vector2i(8,5)], ["lumber",Vector2i(3,17)], ["quarry",Vector2i(10,19)]]:
		_add_building(spec[0], spec[1], true)
	_rebuild_navigation()
	var roles := ["builder","builder","servant","servant","servant","instructor","lumberjack","stonecutter","farmer","vintner","vintner"]
	for i in range(roles.size()):
		_add_worker(roles[i], Vector2i(11+i%5, 8+i/5))
	for i in range(7):
		_add_worker("resident", Vector2i(4+i, 15))
	if not peaceful:
		battle = Battle.new()
		battle.setup(_military_walkable,find_path)
	_emit(tr("Bem-vindo ao Vale dos Vinhedos. Construa duas casas e uma horta para começar."))

func _empty_items() -> Dictionary:
	var items := {}
	for item in ITEMS:
		items[item] = 0
	return items

func _id() -> int:
	var value := next_id
	next_id += 1
	return value

func _add_building(kind: String, cell: Vector2i, complete: bool = false) -> Dictionary:
	var b := {"id":_id(),"kind":kind,"cell":cell,"entrance":cell+Vector2i(0,2),"stage":"complete" if complete else "preparing","progress":1.0 if complete else 0.0,"delivered":_empty_items(),"output":_empty_items(),"input":_empty_items(),"worker":-1,"builder":-1,"reason":"","production":0.0,"initial":complete}
	buildings.append(b)
	return b

func _add_worker(role: String, cell: Vector2i) -> Dictionary:
	var w := {"id":_id(),"role":role,"cell":cell,"previous":cell,"route":[],"state":tr("Disponível"),"task":{},"cargo":{},"work":0.0,"wait":0,"goal":cell,"meal":200,"yield_until":0,"jobs":0}
	workers.append(w)
	return w

func definition(kind: String) -> Dictionary:
	var spec: Dictionary = definitions.get(kind,{})
	if spec.is_empty():
		return spec
	var result := spec.duplicate(true)
	if typeof(spec.get("name","")) == TYPE_STRING and not str(spec.name).is_empty():
		result.name = tr(spec.name)
	if typeof(spec.get("description","")) == TYPE_STRING and not str(spec.description).is_empty():
		result.description = tr(spec.description)
	return result

func _terrain_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= WIDTH-1 or cell.y >= HEIGHT-1:
		return false
	if Rect2i(32,20,2,2).has_point(cell) or Rect2i(28,20,2,2).has_point(cell):
		return false
	return not (cell.x >= 22 and cell.x <= 24 and (cell.y < 13 or cell.y > 15))

func is_walkable(cell: Vector2i) -> bool:
	return _terrain_walkable(cell) and building_at(cell).is_empty()

func _military_walkable(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	for w in workers:
		if w.cell == cell:
			return false
	return true

func building_at(cell: Vector2i) -> Dictionary:
	for b in buildings:
		if b.stage != "cancelled" and Rect2i(b.cell,Vector2i(2,2)).has_point(cell):
			return b
	return {}

func _building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func _worker(id: int) -> Dictionary:
	for w in workers:
		if w.id == id:
			return w
	return {}

func _rebuild_navigation() -> void:
	navigation.region = Rect2i(0,0,WIDTH,HEIGHT)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.update()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			navigation.set_point_solid(Vector2i(x,y),not is_walkable(Vector2i(x,y)))

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not is_walkable(start) or not is_walkable(goal):
		return []
	var path: Array[Vector2i] = navigation.get_id_path(start,goal)
	if not path.is_empty():
		path.remove_at(0)
	return path

func _can_reach(start: Vector2i, goal: Vector2i) -> bool:
	return is_walkable(goal) and (start == goal or not find_path(start,goal).is_empty())

func can_place(kind: String, cell: Vector2i) -> String:
	if peaceful and kind == "barracks":
		return tr("O modo pacífico possui apenas construções da vila.")
	if mission != null and mission.has_method("allows_building") and not mission.allows_building(kind):
		return tr("Esta construção ainda não está disponível nesta missão.")
	if not definitions.has(kind) or kind == "hall":
		return tr("Construção desconhecida.")
	if kind == "quarry" and not stone_deposits.is_empty() and not _quarry_has_deposit(cell):
		return tr("A pedreira precisa ficar junto a uma jazida de pedra.")
	if cell.x < 2 or cell.x > 19 or cell.y < 2 or cell.y > 23:
		return tr("Construa na margem da vila, deixando espaço para a entrada.")
	var area := Rect2i(cell,Vector2i(2,2))
	for b in buildings:
		if b.stage == "cancelled":
			continue
		if area.intersects(Rect2i(b.cell,Vector2i(2,2))) or area.has_point(b.entrance) or area.has_point(b.cell+Vector2i(-1,1)):
			return tr("Espaço ocupado ou entrada de outra construção.")
	for w in workers:
		if area.has_point(w.cell):
			return tr("Há um morador passando. Aguarde um instante.")
	if battle != null:
		for u in battle.units:
			if u.hp > 0 and area.has_point(u.cell):
				return tr("Há soldados neste terreno.")
	var cells: Array[Vector2i] = []
	for y in range(2):
		for x in range(2):
			var c := cell+Vector2i(x,y)
			cells.append(c)
			navigation.set_point_solid(c,true)
	var access: Vector2i = cell+Vector2i(0,2)
	var valid := not navigation.get_id_path(Vector2i(8,12),access).is_empty()
	for b in buildings:
		if b.stage != "cancelled" and navigation.get_id_path(Vector2i(8,12),b.entrance).is_empty():
			valid = false
	for w in workers:
		if navigation.get_id_path(w.cell,Vector2i(8,12)).is_empty():
			valid = false
	for c in cells:
		navigation.set_point_solid(c,false)
	return "" if valid else tr("Esta obra bloquearia o acesso da vila.")

func command(kind: String, payload: Dictionary = {}) -> Dictionary:
	match kind:
		"build":
			if typeof(payload.get("cell")) != TYPE_VECTOR2I:
				return _result(false,tr("Escolha um terreno válido."))
			var error := can_place(str(payload.get("kind","")),payload.cell)
			if not error.is_empty():
				return _result(false,error)
			var b := _add_building(payload.kind,payload.cell)
			_rebuild_navigation()
			_emit(tr("{name}: obra marcada. A equipe vai trabalhar automaticamente.").format({"name":definition(b.kind).name}))
			var idle_builders := 0
			var builders_count := 0
			for person in workers:
				if person.role == "builder":
					builders_count += 1
					if person.task.is_empty(): idle_builders += 1
			if builders_count == 0:
				return _result(true,tr("Obra na fila: nenhum construtor formado. Use o centro de treinamento."))
			if idle_builders == 0:
				return _result(true,tr("Construtores ocupados. A obra começará sozinha quando houver alguém livre."))
			return _result(true,tr("Obra marcada. Construtores e serventes vão até ela."))
		"cancel":
			return _cancel_building(int(payload.get("id",-1)))
		"train":
			var role := str(payload.get("role",""))
			if not ROLES.has(role) or role == "resident":
				return _result(false,tr("Profissão inválida."))
			if mission != null and mission.has_method("allows_role") and not mission.allows_role(role):
				return _result(false,tr("Esta profissão ainda não está disponível nesta missão."))
			var quantity := clampi(int(payload.get("quantity",1)),1,5)
			for i in range(quantity):
				training.append({"id":_id(),"role":role,"worker":-1,"building":-1,"progress":0.0,"reason":tr("Aguardando vaga")})
			return _result(true,tr("Formação na fila. O centro seleciona moradores automaticamente."))
		"cancel_training":
			for t in training:
				if t.id == int(payload.get("id",-1)):
					var w := _worker(t.worker)
					if not w.is_empty():
						_release(w)
					training.erase(t)
					return _result(true,tr("Formação cancelada. O morador está disponível."))
			return _result(false,tr("Formação não encontrada."))
		"army":
			_ensure_battle()
			if battle == null:
				return _result(false,tr("Não há companhia formada."))
			if typeof(payload.get("target")) != TYPE_VECTOR2I:
				return _result(false,tr("Indique um objetivo no terreno."))
			return battle.issue_order(str(payload.get("order","")),payload.target)
		"recruit":
			return _recruit(str(payload.get("role","")))
		"pause":
			paused = not paused
			return _result(true,tr("Pausado") if paused else tr("Partida retomada"))
		"new_game":
			setup(peaceful)
			return _result(true,tr("Uma nova vila está pronta."))
		"load_mission":
			return _load_mission(str(payload.get("id","tsk-01")))
	return _result(false,tr("Comando não permitido. Civis trabalham de forma autônoma."))

func _load_mission(mission_id: String) -> Dictionary:
	var spec: RefCounted = load("res://simulation/mission_spec.gd").load_id(mission_id)
	if spec == null:
		return _result(false, tr("Missão não encontrada."))
	setup(peaceful)
	mission = spec
	if spec.start is Dictionary and spec.start.get("stock") is Dictionary:
		stock = _empty_items()
		for item in spec.start.stock:
			if ITEMS.has(str(item)):
				stock[str(item)] = int(spec.start.stock[item])
		initial = stock.duplicate(true)
		reserved = _empty_items()
		consumed = _empty_items()
		produced = _empty_items()
	for line in spec.briefing:
		_emit(tr(str(line)))
	return _result(true, tr("Missão {id} iniciada.").format({"id": spec.id}))


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}

func _emit(text: String, tone: String = "") -> void:
	var event := {"tick":tick,"text":text}
	if not tone.is_empty():
		event.tone = tone
	events.append(event)
	if events.size() > 80:
		events.pop_front()

func _cancel_building(id: int) -> Dictionary:
	var b := _building(id)
	if b.is_empty() or b.stage == "cancelled":
		return _result(false,tr("Obra não encontrada."))
	if b.initial or b.stage == "complete":
		return _result(false,tr("Edifícios concluídos são preservados nesta missão."))
	b.stage = "cancelled"
	b.reason = tr("Sobras aguardando recolhimento")
	for item in ITEMS:
		b.output[item] += b.delivered[item]
		b.delivered[item] = 0
	for w in workers:
		if int(w.task.get("building",-1)) == id:
			_release(w)
	_rebuild_navigation()
	return _result(true,tr("Obra cancelada. Os serventes recolherão os materiais restantes."))

func footprint_size(_kind: String) -> Vector2i:
	return Vector2i(2, 2)


func _quarry_has_deposit(cell: Vector2i) -> bool:
	var size := footprint_size("quarry")
	var dirs := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for y in range(size.y):
		for x in range(size.x):
			var tile := cell + Vector2i(x, y)
			for delta in dirs:
				if stone_deposits.has(tile + delta):
					return true
	return false


func _ensure_battle() -> void:
	if battle != null:
		return
	battle = Battle.new()
	battle.setup(_military_walkable, find_path, false)


func _recruit(role: String) -> Dictionary:
	if role not in ["lancer","archer"]:
		return _result(false,tr("Tipo de tropa inválido."))
	if _completed("barracks") == 0:
		return _result(false,tr("Construa um quartel para recrutar reforços."))
	var kit := "axe" if role == "lancer" else "bow"
	if available(kit) < 1:
		return _result(false,tr("Falta o equipamento no armazém: {item}.").format({"item":tr(ITEM_NAMES[kit])}))
	var recruit: Dictionary = {}
	for w in workers:
		if w.role != "recruit":
			continue
		var barracks := _building(int(w.task.get("building",-1)))
		if barracks.is_empty() or barracks.kind != "barracks":
			continue
		if not w.route.is_empty() or w.cell != w.goal:
			continue
		recruit = w
		break
	if recruit.is_empty():
		return _result(false,tr("Nenhum recruta chegou ao quartel. Forme recrutas na escola."))
	_ensure_battle()
	if battle == null or not battle.recruit(role):
		return _result(false,tr("Companhia cheia ou ponto de reunião ocupado."))
	_consume_stock(kit,1)
	var barracks := _building(int(recruit.task.get("building",-1)))
	if not barracks.is_empty() and int(barracks.worker) == int(recruit.id):
		barracks.worker = -1
	workers.erase(recruit)
	return _result(true,tr("Recruta equipado e incorporado à companhia."))

func _completed(kind: String) -> int:
	var total := 0
	for b in buildings:
		if b.kind == kind and b.stage == "complete":
			total += 1
	return total

func population_capacity() -> int:
	return 20+4*_completed("house")

func profession_counts() -> Dictionary:
	var result := {}
	for role in ROLES:
		result[role] = 0
	for w in workers:
		result[w.role] += 1
	return result

func available(item: String) -> int:
	return int(stock.get(item,0))-int(reserved.get(item,0))

func storage_capacity() -> int:
	return 200+200*_completed("store")

func _storage_used() -> int:
	var total := 0
	for item in ITEMS:
		total += int(stock[item])
	return total

func _consume_stock(item: String, amount: int) -> void:
	stock[item] -= amount
	consumed[item] += amount

func step() -> void:
	if paused or lost:
		return
	tick += 1
	if tick % 5 == 0:
		_move_workers()
	for w in workers:
		if not w.task.is_empty():
			_work(w)
	_assign_workplaces()
	_update_training()
	for w in workers:
		if w.task.is_empty():
			if int(w.get("meal", 0)) <= 0:
				_seek_inn(w)
			elif not w.cargo.is_empty():
				_assign_return(w)
			elif w.role == "builder":
				_assign_builder(w)
			elif w.role == "servant":
				_assign_delivery(w)
	_update_reasons()
	if tick % 200 == 0:
		for person in workers:
			person.meal = maxi(0, int(person.meal) - 1)
			if int(person.meal) <= 0:
				food_shortage += 1
			else:
				food_shortage = maxi(0, food_shortage - 1)
	if battle != null:
		battle.step()
		if bool(battle.defeated) and not lost:
			lost = true
			_emit(tr("A companhia foi derrotada."), "chime")
	if not won:
		if mission != null and mission.has_method("objectives_met") and mission.objectives_met(_completed_counts()):
			won = true
			_emit(tr("Objetivos da missão cumpridos. A vila pode continuar."))
		elif mission == null and _completed("training") > 0 and _completed("inn") > 0 and _completed("lumber") > 0 and _completed("quarry") > 0:
			won = true
			_emit(tr("Escola, taverna, lenhador e pedreira estão prontos. Você pode continuar construindo."))

func _free_cell(origin: Vector2i) -> Vector2i:
	for radius in range(1,9):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var cell := origin+Vector2i(x,y)
				if is_walkable(cell) and not _occupied(cell) and not _is_access(cell):
					return cell
	return Vector2i(-1,-1)

func _occupied(cell: Vector2i, except_id: int = -1) -> bool:
	for w in workers:
		if w.id != except_id and w.cell == cell:
			return true
	if battle != null:
		for u in battle.units:
			if u.hp > 0 and u.cell == cell:
				return true
	return false

func _is_access(cell: Vector2i) -> bool:
	for b in buildings:
		if cell == b.entrance or cell == b.cell+Vector2i(-1,1) or cell == b.cell+Vector2i(1,2):
			return true
	return false

func _go(w: Dictionary, goal: Vector2i) -> bool:
	var route := find_path(w.cell,goal)
	if w.cell != goal and route.is_empty():
		return false
	w.goal = goal
	w.route = route
	w.wait = 0
	return true

func _detour(w: Dictionary) -> void:
	var blocked: Array[Vector2i] = []
	for other in workers:
		if other.id != w.id and other.cell != w.goal and is_walkable(other.cell):
			navigation.set_point_solid(other.cell,true)
			blocked.append(other.cell)
	if battle != null:
		for u in battle.units:
			if u.hp > 0 and u.cell != w.goal and is_walkable(u.cell) and not blocked.has(u.cell):
				navigation.set_point_solid(u.cell,true)
				blocked.append(u.cell)
	var route: Array[Vector2i] = navigation.get_id_path(w.cell,w.goal)
	for c in blocked:
		navigation.set_point_solid(c,false)
	if route.size() > 1:
		route.remove_at(0)
		w.route = route

func _move_workers() -> void:
	for w in workers:
		w.previous = w.cell
		if tick < int(w.get("yield_until",0)):
			continue
		if w.route.is_empty():
			if w.task.is_empty() and _is_access(w.cell):
				var parking := _free_cell(w.cell)
				if parking.x >= 0:
					_go(w,parking)
			continue
		_detour(w)
		var next: Vector2i = w.route[0]
		if not is_walkable(next):
			_go(w,w.goal)
			continue
		if _occupied(next,w.id):
			w.wait += 1
			if int(w.wait) >= 3:
				for other in workers:
					if other.cell == next and not other.route.is_empty():
						var front: Vector2i = other.route[0]
						if front == w.cell and (_is_access(other.cell) or int(w.id) > int(other.id)):
							_yield_worker(w)
							break
			if int(w.wait) % 3 == 0:
				_detour(w)
			if int(w.wait) >= 6:
				# An idle person yields the doorway, without needing a player order.
				for other in workers:
					if other.cell == next and other.task.is_empty():
						var parking := _free_cell(other.cell)
						if parking.x >= 0:
							_go(other,parking)
			continue
		w.cell = next
		w.route.pop_front()
		w.wait = 0

func _yield_worker(w: Dictionary) -> void:
	for direction in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
		var cell: Vector2i = w.cell+direction
		if is_walkable(cell) and not _occupied(cell) and cell != w.goal:
			w.cell = cell
			w.yield_until = tick+15
			w.wait = 0
			w.route = find_path(cell,w.goal)
			return

func _release(w: Dictionary) -> void:
	var task: Dictionary = w.task
	if task.get("type","") == "delivery" and task.get("phase","") == "pickup":
		var source: int = task.get("source",-1)
		if source == 0:
			reserved[task.item] = maxi(0,int(reserved[task.item])-int(task.amount))
	var b := _building(int(task.get("building",-1)))
	if not b.is_empty():
		if b.builder == w.id:
			b.builder = -1
		if b.worker == w.id:
			b.worker = -1
	w.task = {}
	w.route = []
	w.goal = w.cell
	w.work = 0.0
	w.state = tr("Disponível")

func _assign_builder(w: Dictionary) -> void:
	for b in buildings:
		if b.builder != -1 or b.stage not in ["preparing","materials","building"]:
			continue
		if b.stage == "materials" and not _materials_ready(b):
			continue
		var goal: Vector2i = b.cell+Vector2i(1,2)
		if not _go(w,goal):
			continue
		b.builder = w.id
		w.task = {"type":"prepare" if b.stage == "preparing" else "build","building":b.id}
		w.state = tr("Indo à obra")
		return

func _materials_ready(b: Dictionary) -> bool:
	for item in definition(b.kind).cost:
		if int(b.delivered.get(item,0)) < int(definition(b.kind).cost[item]):
			return false
	return true

func _incoming(id: int, item: String) -> int:
	var value := 0
	for w in workers:
		if w.task.get("type","") == "delivery" and w.task.get("building",-1) == id and w.task.get("item","") == item:
			value += int(w.task.amount)
	return value

func _outgoing(id: int, item: String) -> int:
	var value := 0
	for w in workers:
		if w.task.get("type","") == "delivery" and w.task.get("source",-1) == id and w.task.get("phase","") == "pickup" and w.task.get("item","") == item:
			value += int(w.task.amount)
	return value

func _store_for(cell: Vector2i) -> Dictionary:
	# One physical logistics hub in this mission; annexes add capacity, not teleport exits.
	for b in buildings:
		if b.kind == "store" and b.initial and b.stage == "complete" and _can_reach(cell,b.entrance):
			return b
	return {}

func _assign_delivery(w: Dictionary) -> void:
	# Alternate exports and construction, so an expansion cannot starve the food chain.
	if int(w.get("jobs",0)) % 2 == 0 and _assign_export(w):
		return
	for b in buildings:
		if b.stage == "materials":
			for item in definition(b.kind).cost:
				var need: int = int(definition(b.kind).cost[item])-int(b.delivered[item])-_incoming(b.id,item)
				if need > 0 and available(item) > 0:
					if _transport(w,0,b.id,item,mini(2,mini(need,available(item)))):
						return
		if b.kind == "winery" and b.stage == "complete":
			var need: int = 6-int(b.input.grapes)-_incoming(b.id,"grapes")
			if need > 0 and available("grapes") > 0 and _transport(w,0,b.id,"grapes",mini(2,mini(need,available("grapes")))):
				return
		if b.kind == "training" and b.stage == "complete":
			var gold_need: int = _school_gold_need(b)
			if gold_need > 0 and available("gold") > 0 and _transport(w,0,b.id,"gold",mini(2,mini(gold_need,available("gold")))):
				return
		if b.kind == "sawmill" and b.stage == "complete":
			var need: int = 6-int(b.input.get("trunks",0))-_incoming(b.id,"trunks")
			if need > 0 and available("trunks") > 0 and _transport(w,0,b.id,"trunks",mini(2,mini(need,available("trunks")))):
				return
		if b.kind == "mill" and b.stage == "complete":
			var need: int = 6-int(b.input.get("corn",0))-_incoming(b.id,"corn")
			if need > 0 and available("corn") > 0 and _transport(w,0,b.id,"corn",mini(2,mini(need,available("corn")))):
				return
		if b.kind == "bakery" and b.stage == "complete":
			var need: int = 6-int(b.input.get("flour",0))-_incoming(b.id,"flour")
			if need > 0 and available("flour") > 0 and _transport(w,0,b.id,"flour",mini(2,mini(need,available("flour")))):
				return
		if b.kind == "inn" and b.stage == "complete":
			for item in ["loaves", "food", "wine"]:
				var room: int = 8-int(b.input.get(item,0))-_incoming(b.id,item)
				if room > 0 and available(item) > 0 and _transport(w,0,b.id,item,mini(2,mini(room,available(item)))):
					return
		if b.kind == "workshop" and b.stage == "complete":
			var wood_need: int = 6-int(b.input.get("wood",0))-_incoming(b.id,"wood")
			if wood_need > 0 and available("wood") > 0 and _transport(w,0,b.id,"wood",mini(2,mini(wood_need,available("wood")))):
				return
	_assign_export(w)

func _assign_export(w: Dictionary) -> bool:
	if _storage_used()+_incoming(0,"food") >= storage_capacity():
		return false
	# Food first during a shortage, otherwise oldest building gets a fair rotating turn.
	var ordered := buildings.duplicate()
	if not ordered.is_empty():
		var offset: int = (tick/10+int(w.id)) % ordered.size()
		ordered = ordered.slice(offset)+ordered.slice(0,offset)
	if available("food") < 20:
		ordered.sort_custom(func(a,b): return a.kind == "farm" and b.kind != "farm")
	for b in ordered:
		for item in ITEMS:
			var target: int = {"wood":100,"stone":60,"food":120,"grapes":24,"wine":32,"gold":40,"trunks":24,"corn":24,"flour":16,"loaves":24,"axe":8,"bow":8}.get(item, 12)
			if int(stock.get(item,0))+_incoming(0,item) >= target:
				continue
			var free: int = int(b.output.get(item,0))-_outgoing(b.id,item)
			if free > 0 and _transport(w,b.id,0,item,mini(2,free)):
				return true
	return false

func _transport(w: Dictionary, source: int, dest: int, item: String, amount: int) -> bool:
	var source_b := _store_for(w.cell) if source == 0 else _building(source)
	var dest_b := _store_for(source_b.get("entrance",w.cell)) if dest == 0 else _building(dest)
	if source_b.is_empty() or dest_b.is_empty() or not _can_reach(source_b.entrance,dest_b.entrance):
		return false
	if not _go(w,source_b.entrance):
		return false
	w.task = {"type":"delivery","phase":"pickup","source":source,"building":dest,"source_cell":source_b.entrance,"dest_cell":dest_b.entrance,"item":item,"amount":amount}
	if source == 0:
		reserved[item] += amount
	w.state = tr("Buscando {item}").format({"item":tr(ITEM_NAMES[item])})
	return true

func _assign_return(w: Dictionary) -> void:
	var store := _store_for(w.cell)
	if store.is_empty():
		w.state = tr("Carga preservada: sem acesso ao armazém")
		return
	if _go(w,store.entrance):
		w.task = {"type":"delivery","phase":"deliver","source":-1,"building":0,"dest_cell":store.entrance,"item":w.cargo.item,"amount":w.cargo.amount}
		w.state = tr("Devolvendo materiais")

func _assign_workplaces() -> void:
	for b in buildings:
		if b.stage != "complete" or b.worker != -1:
			continue
		var profession: String = definition(b.kind).profession
		if profession.is_empty():
			continue
		for w in workers:
			if w.role != profession or not w.task.is_empty() or not w.cargo.is_empty():
				continue
			if int(w.get("meal", 0)) <= 0:
				continue
			var goal: Vector2i = b.cell+Vector2i(-1,1)
			if not _go(w,goal):
				goal = b.cell+Vector2i(1,2)
				if not _go(w,goal):
					continue
			b.worker = w.id
			w.task = {"type":"produce","building":b.id}
			w.state = tr("Indo trabalhar")
			break

func _work(w: Dictionary) -> void:
	if not w.route.is_empty() or w.cell != w.goal:
		return
	var task: Dictionary = w.task
	var b := _building(int(task.get("building",-1)))
	match str(task.get("type","")):
		"prepare":
			if b.is_empty() or b.stage == "cancelled":
				_release(w)
				return
			w.state = tr("Preparando terreno")
			b.progress = minf(1.0,float(b.progress)+0.1/3.0)
			if b.progress >= 1.0:
				b.stage = "materials"
				b.progress = 0.0
				_release(w)
		"build":
			if b.is_empty() or b.stage == "cancelled":
				_release(w)
				return
			if b.stage == "materials":
				if not _materials_ready(b):
					_release(w)
					return
				for item in definition(b.kind).cost:
					var quantity: int = definition(b.kind).cost[item]
					b.delivered[item] -= quantity
					consumed[item] += quantity
				b.stage = "building"
			w.state = tr("Construindo")
			b.progress = minf(1.0,float(b.progress)+0.1/float(definition(b.kind).duration))
			if b.progress >= 1.0:
				b.stage = "complete"
				if b.kind == "house":
					stats.houses_built += 1
				_emit(tr("{name} concluída. Funcionamento automático ativado.").format({"name":definition(b.kind).name}),"chime")
				_release(w)
		"delivery":
			_delivery_work(w)
		"produce":
			_produce(w,b)
		"train":
			w.state = tr("Em formação")
		"eat":
			_eat_at_inn(w,b)
		"harvest":
			_chop_tree(w,b)

func _delivery_work(w: Dictionary) -> void:
	var task: Dictionary = w.task
	var item: String = task.item
	var amount: int = task.amount
	if task.phase == "pickup":
		if task.source == 0:
			if int(stock[item]) < amount:
				_release(w)
				return
			stock[item] -= amount
			reserved[item] -= amount
		else:
			var source := _building(task.source)
			if source.is_empty() or int(source.output[item]) < amount:
				_release(w)
				return
			source.output[item] -= amount
		w.cargo = {"item":item,"amount":amount}
		task.phase = "deliver"
		w.state = tr("Transportando {item}").format({"item":tr(ITEM_NAMES[item])})
		if not _go(w,task.dest_cell):
			_release(w)
		return
	if task.building == 0:
		if _storage_used()+amount > storage_capacity():
			w.state = tr("Armazém cheio: construa outro")
			return
		stock[item] += amount
		if item == "wine" and task.source > 0:
			stats.wine_delivered += amount
	else:
		var b := _building(task.building)
		if b.is_empty() or b.stage == "cancelled":
			_release(w)
			return
		if b.stage == "complete":
			b.input[item] += amount
		else:
			b.delivered[item] += amount
	w.cargo = {}
	w.jobs = int(w.get("jobs",0))+1
	_release(w)

func _school_gold_need(school: Dictionary) -> int:
	var queued := 0
	for t in training:
		if int(t.get("worker", -1)) < 0:
			queued += 1
	return maxi(0, queued - int(school.input.get("gold", 0)) - _incoming(school.id, "gold"))


func _inn() -> Dictionary:
	for b in buildings:
		if b.kind == "inn" and b.stage == "complete":
			return b
	return {}


func _seek_inn(w: Dictionary) -> void:
	var inn := _inn()
	if inn.is_empty():
		w.state = tr("Faminto: não há taverna")
		return
	if not _go(w, inn.entrance):
		w.state = tr("Faminto: sem caminho até a taverna")
		return
	w.task = {"type": "eat", "building": inn.id}
	w.state = tr("Indo comer na taverna")


func _eat_at_inn(w: Dictionary, inn: Dictionary) -> void:
	if inn.is_empty() or inn.kind != "inn":
		_release(w)
		return
	var eaten := ""
	for item in ["loaves", "food", "wine"]:
		if int(inn.input.get(item, 0)) >= 1:
			inn.input[item] -= 1
			consumed[item] += 1
			eaten = item
			break
	if eaten.is_empty():
		w.state = tr("Taverna sem comida")
		return
	w.meal = 80
	w.state = tr("Comeu na taverna")
	_release(w)


func _chop_tree(w: Dictionary, hut: Dictionary) -> void:
	if harvest_map == null or hut.is_empty():
		_release(w)
		return
	if int(w.get("meal", 0)) <= 0:
		_release(w)
		_seek_inn(w)
		return
	var tree: Vector2i = w.task.get("tree", Vector2i(-1, -1))
	if not harvest_map.has_tree(tree):
		_release(w)
		return
	w.state = tr("Cortando árvore")
	w.task.progress = float(w.task.get("progress", 0.0)) + 0.1 / 6.0
	if float(w.task.progress) < 1.0:
		return
	harvest_map.harvest(tree)
	hut.output.trunks = int(hut.output.get("trunks", 0)) + 2
	produced.trunks += 2
	w.state = tr("Árvore derrubada")
	w.task = {"type": "produce", "building": hut.id}
	w.goal = hut.cell + Vector2i(-1, 1)
	_go(w, w.goal)


func _completed_counts() -> Dictionary:
	var counts := {}
	for b in buildings:
		if b.stage == "complete":
			counts[b.kind] = int(counts.get(b.kind, 0)) + 1
	return counts


func _produce(w: Dictionary, b: Dictionary) -> void:
	if b.is_empty() or b.stage != "complete":
		_release(w)
		return
	if int(w.get("meal", 0)) <= 0:
		_release(w)
		_seek_inn(w)
		return
	if b.kind == "training":
		w.state = tr("Ensinando no centro")
		return
	if b.kind == "barracks":
		w.state = tr("Aguardando equipamento no quartel")
		return
	if b.kind == "lumber" and harvest_map != null:
		var tree: Vector2i = harvest_map.nearest_standing_tree(w.cell)
		if tree == Vector2i(-1, -1):
			w.state = tr("Sem árvores para cortar")
			return
		if int(b.output.get("trunks", 0)) >= 20:
			w.state = tr("Aguardando retirada da produção")
			return
		var stand := _tree_stand_cell(tree)
		if stand.x < 0:
			w.state = tr("Sem acesso à árvore")
			return
		if w.cell != stand:
			w.task = {"type": "harvest", "building": b.id, "tree": tree}
			_go(w, stand)
			w.state = tr("Indo cortar árvore")
			return
		w.task = {"type": "harvest", "building": b.id, "tree": tree}
		_chop_tree(w, b)
		return
	if b.kind == "quarry" and not stone_deposits.is_empty() and not _quarry_has_deposit(b.cell):
		w.state = tr("Pedreira sem jazida")
		return
	var recipes := {
		"lumber": ["wood", 4, 8.0, "", 0],
		"quarry": ["stone", 3, 10.0, "", 0],
		"farm": ["food", 8, 10.0, "", 0],
		"vineyard": ["grapes", 4, 12.0, "", 0],
		"winery": ["wine", 2, 10.0, "grapes", 3],
		"sawmill": ["wood", 2, 10.0, "trunks", 1],
		"mill": ["flour", 2, 10.0, "corn", 3],
		"bakery": ["loaves", 2, 10.0, "flour", 2],
		"workshop": ["axe", 1, 12.0, "wood", 2]
	}
	if not recipes.has(b.kind):
		return
	var recipe: Array = recipes[b.kind]
	if int(b.output.get(recipe[0], 0)) >= 20:
		w.state = tr("Aguardando retirada da produção")
		return
	var need_item: String = str(recipe[3])
	var need_amount: int = int(recipe[4])
	if not need_item.is_empty() and int(b.input.get(need_item, 0)) < need_amount:
		w.state = tr("Aguardando {item}").format({"item": tr(str(ITEM_NAMES[need_item] if ITEM_NAMES.has(need_item) else need_item))})
		return
	w.state = tr("Produzindo {item}").format({"item": tr(ITEM_NAMES[recipe[0]])})
	b.production += 0.1 / float(recipe[2])
	if b.production >= 1.0:
		b.production = 0.0
		if not need_item.is_empty():
			b.input[need_item] -= need_amount
			consumed[need_item] += need_amount
		b.output[recipe[0]] += int(recipe[1])
		produced[recipe[0]] += int(recipe[1])
		if b.kind == "farm":
			stats.food_produced += int(recipe[1])
			b.output.corn = int(b.output.get("corn", 0)) + 8
			produced.corn += 8
		if b.kind == "workshop" and int(b.output.get("bow", 0)) < int(b.output.get("axe", 0)):
			b.output.axe -= 1
			produced.axe -= 1
			b.output.bow = int(b.output.get("bow", 0)) + 1
			produced.bow += 1


func _tree_stand_cell(tree: Vector2i) -> Vector2i:
	for delta in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var cell: Vector2i = tree + delta
		if is_walkable(cell):
			return cell
	return Vector2i(-1, -1)

func _update_training() -> void:
	var completed: Array[Dictionary] = []
	for t in training:
		if t.worker == -1:
			var center: Dictionary = {}
			for b in buildings:
				if b.kind != "training" or b.stage != "complete" or b.worker < 0:
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
				t.reason = tr("Centro ocupado ou sem instrutor")
				continue
			if int(center.input.get("gold",0)) < 1:
				t.reason = tr("Aguardando ouro na escola")
				continue
			var spawn: Vector2i = center.cell+Vector2i(1,2)
			if not is_walkable(spawn):
				spawn = center.entrance
			if not is_walkable(spawn) or _occupied(spawn):
				t.reason = tr("Entrada da escola ocupada")
				continue
			var candidate: Dictionary = _add_worker("resident", spawn)
			t.worker = candidate.id
			t.building = center.id
			candidate.task = {"type":"train","building":center.id,"training":t.id}
			candidate.goal = spawn
			candidate.state = tr("Novo civil em formação")
			center.input.gold -= 1
			consumed.gold += 1
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

func _update_reasons() -> void:
	var counts := profession_counts()
	for b in buildings:
		b.reason = ""
		if b.stage in ["preparing","building"]:
			if b.builder < 0:
				b.reason = tr("Nenhum construtor formado") if counts.builder == 0 else tr("Construtores ocupados: aguardando vez")
			else:
				b.reason = tr("Construtor a caminho ou trabalhando")
		elif b.stage == "materials":
			if _materials_ready(b):
				b.reason = tr("Materiais completos. Aguardando construtor")
			elif counts.servant == 0:
				b.reason = tr("Nenhum servente formado. Use o treinamento")
			else:
				b.reason = tr("Serventes ocupados ou materiais a caminho")
				for item in definition(b.kind).cost:
					var missing: int = int(definition(b.kind).cost[item])-int(b.delivered[item])-_incoming(b.id,item)
					if missing > available(item):
						b.reason = tr("Faltam {count} {item}").format({"count":missing-available(item),"item":tr(ITEM_NAMES[item])})
		elif b.stage == "complete":
			var role: String = definition(b.kind).profession
			if not role.is_empty():
				b.reason = tr("Forme um {role}").format({"role":tr(ROLE_NAMES[role]).to_lower()}) if b.worker < 0 else _worker(b.worker).get("state",tr("Aguardando profissional"))

func notice() -> String:
	if available("food") < 10:
		return tr("Alimentos baixos. Construa uma horta e forme agricultores.")
	if _storage_used() >= storage_capacity()-4:
		return tr("Armazém quase cheio. Construa outro para liberar as entregas.")
	for b in buildings:
		if b.stage in ["complete","cancelled"]:
			continue
		if b.reason in [tr("Nenhum construtor formado"),tr("Construtores ocupados: aguardando vez"),tr("Nenhum servente formado. Use o treinamento")]:
			return b.reason
	for t in training:
		if t.reason == tr("Sem moradores livres para formação"):
			return t.reason
	return tr("Os habitantes trabalham sozinhos. Toque em um prédio para acompanhar.")

func objective_rows() -> Array[Dictionary]:
	if mission != null:
		var rows: Array[Dictionary] = []
		for row in mission.objectives:
			var kind := str(row.get("kind", ""))
			var need := int(row.get("count", 1))
			var have := _completed(kind)
			rows.append({"text": tr(str(row.get("text", kind))), "done": have >= need})
		return rows
	return [
		{"text":tr("Construir a escola"),"done":_completed("training")>0},
		{"text":tr("Construir a taverna"),"done":_completed("inn")>0},
		{"text":tr("Construir o lenhador"),"done":_completed("lumber")>0},
		{"text":tr("Construir a pedreira"),"done":_completed("quarry")>0}
	]

func conservation_errors() -> Array[String]:
	var errors: Array[String] = []
	var physical := stock.duplicate(true)
	for b in buildings:
		for key in ["delivered","output","input"]:
			for item in ITEMS:
				physical[item] += int(b[key][item])
	for w in workers:
		if not w.cargo.is_empty():
			physical[w.cargo.item] += int(w.cargo.amount)
	for item in ITEMS:
		if int(physical[item])+int(consumed[item]) != int(initial[item])+int(produced[item]):
			errors.append("Conservação: "+item)
		if int(stock[item]) < 0 or int(reserved[item]) < 0 or available(item) < 0:
			errors.append("Estoque/reserva negativa: "+item)
	var positions := {}
	for w in workers:
		if positions.has(w.cell):
			errors.append("Civis sobrepostos")
		positions[w.cell] = true
	return errors

func snapshot() -> Dictionary:
	return _encode({"version":SAVE_VERSION,"mode":"peaceful" if peaceful else "standard","tick":tick,"next_id":next_id,"buildings":buildings,"workers":workers,"stock":stock,"reserved":reserved,"consumed":consumed,"produced":produced,"initial":initial,"training":training,"events":events,"stats":stats,"won":won,"lost":lost,"paused":paused,"food_shortage":food_shortage,"arrival_ticks":arrival_ticks,"battle":battle.snapshot() if battle != null else null,"harvested_cells":harvest_map.harvested_cells() if harvest_map != null else []})

func _encode(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2I:
		return {"__cell":[value.x,value.y]}
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _encode(value[key])
		return result
	if value is Array:
		var result := []
		for entry in value:
			result.append(_encode(entry))
		return result
	return value

func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__cell"):
			return Vector2i(int(value.__cell[0]),int(value.__cell[1]))
		var result := {}
		for key in value:
			result[key] = _decode(value[key])
		return result
	if value is Array:
		var result := []
		for entry in value:
			result.append(_decode(entry))
		return result
	return value

func restore(state: Dictionary) -> bool:
	# Validate the shape before decoding; game saves are data, never executable objects.
	if not _valid_save(state):
		return false
	var s: Dictionary = _decode(state)
	var candidate: RefCounted = get_script().new()
	candidate.setup(peaceful)
	candidate._apply(s)
	if not peaceful and not candidate.battle.restore(s.battle):
		return false
	if not candidate.conservation_errors().is_empty():
		return false
	_apply(s)
	return true if peaceful else battle.restore(s.battle)

func _apply(s: Dictionary) -> void:
	tick = int(s.tick)
	next_id = int(s.next_id)
	buildings.assign(s.buildings)
	workers.assign(s.workers)
	training.assign(s.training)
	events.assign(s.events)
	for field in ["stock","reserved","consumed","produced","initial","stats"]:
		set(field,s[field].duplicate(true))
	won = s.won
	lost = s.lost
	paused = s.paused
	food_shortage = int(s.food_shortage)
	arrival_ticks = int(s.arrival_ticks)
	if harvest_map != null:
		harvest_map.apply_harvested(s.get("harvested_cells", []))
	_rebuild_navigation()

func _safe_int(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= 100000000

func _valid_cell(value: Variant) -> bool:
	return value is Dictionary and value.has("__cell") and value.__cell is Array and value.__cell.size() == 2 and _safe_int(value.__cell[0]) and _safe_int(value.__cell[1]) and value.__cell[0] < WIDTH and value.__cell[1] < HEIGHT

func _valid_save(s: Dictionary) -> bool:
	if s.get("version") != SAVE_VERSION:
		return false
	# Old version-1 saves are standard games. A scene never imports the other mode.
	if s.get("mode","standard") != ("peaceful" if peaceful else "standard"):
		return false
	if peaceful:
		if not s.has("battle") or s.battle != null:
			return false
	elif not s.get("battle") is Dictionary:
		return false
	for key in ["tick","next_id","food_shortage","arrival_ticks"]:
		if not _safe_int(s.get(key)):
			return false
	for key in ["won","lost","paused"]:
		if typeof(s.get(key)) != TYPE_BOOL:
			return false
	for key in ["buildings","workers","training","events"]:
		if not s.get(key) is Array or s[key].size() > 500:
			return false
	for key in ["stock","reserved","consumed","produced","initial"]:
		if not s.get(key) is Dictionary:
			return false
		for item in ITEMS:
			if not _safe_int(s[key].get(item)):
				return false
	if not s.get("stats") is Dictionary:
		return false
	for key in ["houses_built","wine_delivered","food_produced"]:
		if not _safe_int(s.stats.get(key)):
			return false
	var ids := {}
	for b in s.buildings:
		if not b is Dictionary or not _safe_int(b.get("id")) or ids.has(b.id) or not definitions.has(b.get("kind")) or not _valid_cell(b.get("cell")) or not _valid_cell(b.get("entrance")):
			return false
		ids[b.id] = true
		for key in ["stage","reason"]:
			if not b.get(key) is String:
				return false
		if b.stage not in ["preparing","materials","building","complete","cancelled"]:
			return false
		for key in ["progress","production","worker","builder"]:
			if typeof(b.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(b[key])):
				return false
		if typeof(b.get("initial")) != TYPE_BOOL:
			return false
		for key in ["delivered","output","input"]:
			if not b.get(key) is Dictionary:
				return false
			for item in ITEMS:
				if not _safe_int(b[key].get(item)):
					return false
	for w in s.workers:
		if not w is Dictionary or not _safe_int(w.get("id")) or ids.has(w.id) or not ROLES.has(w.get("role")):
			return false
		ids[w.id] = true
		for key in ["cell","previous","goal"]:
			if not _valid_cell(w.get(key)):
				return false
		if not w.get("route") is Array or w.route.size() > WIDTH*HEIGHT:
			return false
		for cell in w.route:
			if not _valid_cell(cell):
				return false
		if not w.get("task") is Dictionary or not w.get("cargo") is Dictionary or not w.get("state") is String:
			return false
		for key in ["yield_until","jobs"]:
			if not _safe_int(w.get(key)):
				return false
		for key in ["work","wait","meal"]:
			if typeof(w.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(w[key])):
				return false
		if not w.cargo.is_empty() and (not ITEMS.has(w.cargo.get("item")) or not _safe_int(w.cargo.get("amount"))):
			return false
		if not _valid_task(w.task):
			return false
	for event in s.events:
		if not event is Dictionary or not _safe_int(event.get("tick")) or not event.get("text") is String:
			return false
	for t in s.training:
		if not t is Dictionary or not _safe_int(t.get("id")) or not ROLES.has(t.get("role")) or not t.get("reason") is String:
			return false
		for key in ["worker","building","progress"]:
			if typeof(t.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(t[key])):
				return false
	if s.has("harvested_cells"):
		if not s.harvested_cells is Array or s.harvested_cells.size() > WIDTH * HEIGHT:
			return false
		for cell in s.harvested_cells:
			if not _valid_cell(cell):
				return false
	return true

func _valid_task(task: Dictionary) -> bool:
	if task.is_empty():
		return true
	if task.get("type") not in ["prepare","build","delivery","produce","train","eat","harvest"] or typeof(task.get("building")) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	if task.type == "delivery":
		if task.get("phase") not in ["pickup","deliver"] or not ITEMS.has(task.get("item")) or not _safe_int(task.get("amount")) or typeof(task.get("source")) not in [TYPE_INT,TYPE_FLOAT] or not _valid_cell(task.get("dest_cell")):
			return false
		if task.phase == "pickup" and not _valid_cell(task.get("source_cell")):
			return false
	if task.type == "harvest" and not _valid_cell(task.get("tree")):
		return false
	return true
