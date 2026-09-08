extends SceneTree
const Approved = preload("res://simulation/approved_sim.gd")
const Frontier = preload("res://simulation/frontier_sim.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures.append(message)
  printerr("FAIL: ",message)
func fresh() -> RefCounted:
 var sim := Approved.new()
 sim.setup()
 return sim
func state(sim: RefCounted) -> Dictionary:
 return JSON.parse_string(JSON.stringify(sim.snapshot()))
func advance(sim: RefCounted, ticks: int) -> void:
 for index in range(ticks): sim.step()
func connect_school(sim: RefCounted) -> Dictionary:
 var cells: Array[Vector2i] = []
 for x in range(8,14): cells.append(Vector2i(x,13))
 return sim.command("road",{"cells":cells})
func run() -> void:
 var sim := fresh()
 expect(sim.buildings.size() == 2 and sim.workers.size() == 17 and sim.battle == null and sim.roads.is_empty(),"approved starts with two buildings, seventeen civilians and no army or roads")
 expect(int(sim.stock.wood)==140 and int(sim.stock.stone)==160 and int(sim.stock.food)==280 and int(sim.stock.gold)>=1,"bootstrap stock keeps wood, stone, food and school gold")
 expect(sim.footprint_size("hall") == Vector2i(3,3) and sim.footprint_size("training") == Vector2i(3,3),"main building and school occupy three by three cells")
 expect(sim.footprint_size("store") == Vector2i(3,3) and sim.footprint_size("winery") == Vector2i(3,3),"store and winery occupy three by three cells")
 for kind in ["house","lumber","quarry","farm","vineyard"]:
  expect(sim.footprint_size(kind) == Vector2i(2,2),"small footprint remains two by two: "+kind)
 expect(sim.buildings[0].entrance == Vector2i(8,13) and sim.buildings[1].entrance == Vector2i(13,13),"expanded buildings have centered front entrances")
 for building in sim.buildings:
  var occupied: Array = sim.building_footprint(building)
  expect(occupied.size() == 9,"footprint enumerates all nine cells of "+building.kind)
  var blocked := true
  for cell in occupied:
   blocked = blocked and sim.building_at(cell).id == building.id and not sim.is_walkable(cell) and not sim.can_place_road(cell).is_empty()
  expect(blocked,"all nine occupied cells block walking and roads for "+building.kind)
 expect(sim.is_walkable(Vector2i(8,13)) and sim.is_walkable(Vector2i(13,13)),"front entrance cells remain walkable")
 expect(not sim.command("road",{"cell":Vector2i(9,12)}).ok and sim.reserved.stone == 0,"third-column and third-row building space cannot become a road")
 expect(not sim.command("build",{"kind":"house","cell":Vector2i(14,12)}).ok,"new construction cannot overlap the enlarged school corner")
 expect(sim.conservation_errors().is_empty(),"initial civilian positions are outside the enlarged buildings")
 expect(sim.command("train",{"role":"lumberjack"}).ok,"profession can be queued before school connection")
 advance(sim,100)
 expect(sim.profession_counts().lumberjack == 0,"school waits for its centered entrance to be connected")
 expect(connect_school(sim).ok and sim.reserved.stone == 4,"school road charges four new tiles beyond the public square")
 advance(sim,65)
 var restored := fresh()
 expect(restored.restore(state(sim)),"ongoing road work and training save through JSON in approved mode")
 advance(sim,1000)
 advance(restored,1000)
 expect(state(sim) == state(restored),"road work and training continue deterministically after restore")
 expect(sim.is_building_connected(sim.buildings[1]) and sim.profession_counts().lumberjack == 1,"road reaches the new school entrance and professional training finishes")
 expect(sim.conservation_errors().is_empty(),"new work slots preserve materials and keep civilians outside buildings")
 var before := state(sim)
 var old := Frontier.new()
 old.setup()
 expect(not sim.restore(state(old)) and state(sim) == before,"approved cannot import frontier 0.3 state")
 expect(not old.restore(before) and state(old).mode == "frontier","frontier cannot import approved state")
 var invalid := before.duplicate(true)
 invalid.buildings[0].entrance = {"__cell":[7,12]}
 expect(not sim.restore(invalid) and state(sim) == before,"save cannot use the old main entrance inside the new footprint")
 invalid = before.duplicate(true)
 invalid.roads[0].cell = {"__cell":[9,12]}
 expect(not sim.restore(invalid) and state(sim) == before,"save rejects roads overlapping the third footprint row")
 invalid = before.duplicate(true)
 invalid.workers[0].cell = {"__cell":[14,12]}
 expect(not sim.restore(invalid) and state(sim) == before,"save rejects a worker inside the enlarged school")
 _test_second_school()
 _test_expanded_industry("store")
 _test_expanded_industry("winery")
 _test_delivery_reconnection()
 _test_mission()
 print("APPROVED_TEST_RESULT checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)

func _test_second_school() -> void:
 var sim := fresh()
 expect(sim.command("build",{"kind":"training","cell":Vector2i(16,6)}).ok,"player can place an additional three by three school")
 var school: Dictionary = sim.buildings.back()
 expect(school.entrance == Vector2i(17,9) and sim.building_footprint(school).size() == 9,"new school uses the centered entrance and full footprint")
 var roads: Array[Vector2i] = []
 for x in range(8,18): roads.append(Vector2i(x,13))
 for y in range(9,13): roads.append(Vector2i(17,y))
 expect(sim.command("road",{"cells":roads}).ok,"new school road is legally planned around the initial buildings")
 sim.command("train",{"role":"instructor"})
 var inside := false
 for tick in range(5000):
  sim.step()
  for person in sim.workers:
   if not sim.building_at(person.cell).is_empty(): inside = true
  if school.stage == "complete" and school.worker != -1: break
 expect(school.stage == "complete" and school.worker != -1,"builders finish the expanded school and a trained instructor automatically occupies it")
 expect(not inside and sim.conservation_errors().is_empty(),"builder, instructor and student slots are outside all three by three footprints")
 sim.command("train",{"role":"builder","quantity":2})
 advance(sim,1500)
 expect(sim.profession_counts().builder == 5,"both connected schools can train workers without crossing building interiors")

func _test_expanded_industry(kind: String) -> void:
 var sim := fresh()
 var origin := Vector2i(18,17)
 expect(sim.command("build",{"kind":kind,"cell":origin}).ok,"expanded industry can be planned: "+kind)
 var building: Dictionary = sim.buildings.back()
 expect(sim.building_footprint(building).size() == 9 and building.entrance == Vector2i(19,20),kind+" has nine occupied cells and centered front entrance")
 expect(sim._builder_work_cell(building) == Vector2i(20,20) and sim.is_walkable(sim._builder_work_cell(building)),kind+" builder works outside the full footprint")
 expect(sim.is_walkable(sim._professional_work_cell(building)),kind+" professional has an external work position")
 var blocked := true
 for tile: Vector2i in sim.building_footprint(building):
  blocked = blocked and not sim.is_walkable(tile) and sim.building_at(tile).id == building.id and not sim.can_place_road(tile).is_empty()
 expect(blocked,kind+" blocks walking and road placement in all nine cells")
 var roads: Array[Vector2i] = []
 for x in range(8,22): roads.append(Vector2i(x,13))
 for y in range(14,21): roads.append(Vector2i(21,y))
 roads.append(Vector2i(20,20))
 roads.append(Vector2i(19,20))
 expect(sim.command("road",{"cells":roads}).ok,kind+" road connects its new entrance around the building")
 var before := state(sim)
 var restored := fresh()
 expect(restored.restore(before),kind+" planned construction and road network restore")
 var invalid := before.duplicate(true)
 invalid.buildings.back().entrance = {"__cell":[18,19]}
 expect(not restored.restore(invalid) and state(restored) == before,kind+" rejects the obsolete two by two entrance without changing state")
 invalid = before.duplicate(true)
 invalid.roads[0].cell = {"__cell":[20,19]}
 expect(not restored.restore(invalid) and state(restored) == before,kind+" save rejects roads in its expanded corner")
 invalid = before.duplicate(true)
 invalid.workers[0].cell = {"__cell":[20,19]}
 expect(not restored.restore(invalid) and state(restored) == before,kind+" save rejects a civilian in its expanded corner")
 invalid = before.duplicate(true)
 invalid.buildings[1].cell = {"__cell":[17,16]}
 invalid.buildings[1].entrance = {"__cell":[18,19]}
 expect(not restored.restore(invalid) and state(restored) == before,kind+" save rejects overlapping large footprints")
 var blocked_entrance := fresh()
 expect(blocked_entrance.command("build",{"kind":"house","cell":Vector2i(19,20)}).ok,"entrance blocking fixture is legal")
 expect(not blocked_entrance.command("build",{"kind":kind,"cell":origin}).ok,kind+" cannot be placed with its enlarged entrance inside another building")
 var blocked_corner := fresh()
 expect(blocked_corner.command("road",{"cell":Vector2i(20,19)}).ok,"expanded corner road fixture is legal")
 expect(not blocked_corner.command("build",{"kind":kind,"cell":origin}).ok,kind+" cannot cover a road only touched by its third row and column")
 var neighbor := fresh()
 expect(neighbor.command("build",{"kind":"house","cell":Vector2i(16,18)}).ok,"neighbor collision fixture is legal")
 expect(not neighbor.command("build",{"kind":kind,"cell":Vector2i(14,16)}).ok,kind+" cannot overlap a neighboring building with its added corner")
 if kind == "winery":
  expect(sim.command("train",{"role":"vintner"}).ok,"winery specialist enters the autonomous school queue")
  restored.command("train",{"role":"vintner"})
 var inside := false
 for tick in range(6000):
  sim.step()
  restored.step()
  for person in sim.workers:
   if not sim.is_walkable(person.cell): inside = true
  if building.stage == "complete" and (kind == "store" or building.worker != -1): break
 expect(building.stage == "complete" and sim.is_building_connected(building),kind+" is built and connected automatically with the new footprint")
 expect(not inside and sim.conservation_errors().is_empty(),kind+" workers and resources respect the new collision area")
 expect(state(sim) == state(restored),kind+" enlarged construction continues identically after save")
 if kind == "store":
  expect(sim.storage_capacity() == 1000 and sim._store_for(Vector2i(19,20)).kind == "store","completed storehouse is the physical depot and still expands capacity")
 else:
  expect(building.worker != -1 and sim._worker(building.worker).role == "vintner","trained vintner automatically occupies the expanded winery")

func _test_delivery_reconnection() -> void:
 var sim := fresh()
 var roads: Array[Vector2i] = []
 for x in range(8,17): roads.append(Vector2i(x,13))
 expect(sim.command("road",{"cells":roads}).ok,"delivery network uses the relocated principal entrance")
 expect(sim.command("build",{"kind":"house","cell":Vector2i(16,11)}).ok,"construction beside relocated road is legal")
 var broken := false
 var carrier_id := -1
 var amount := 0
 for tick in range(4000):
  sim.step()
  for person in sim.workers:
   if person.role == "servant" and not person.cargo.is_empty() and person.cell.x <= 10 and person.task.get("building",0) > 0 and sim.has_road(Vector2i(11,13)):
    if sim.command("remove_road",{"cell":Vector2i(11,13)}).ok:
     broken = true
     carrier_id = person.id
     amount = person.cargo.amount
     break
  if broken: break
 expect(broken,"a real loaded delivery can be interrupted on the new entrance network")
 if not broken: return
 advance(sim,100)
 var carrier: Dictionary = sim._worker(carrier_id)
 expect(not carrier.cargo.is_empty() and carrier.cargo.amount == amount and carrier.cell.x < 11,"road interruption preserves cargo outside building footprints")
 var restored := fresh()
 expect(restored.restore(state(sim)),"disconnected load restores in approved mode")
 expect(sim.command("road",{"cell":Vector2i(11,13)}).ok,"missing road tile can be replanned")
 restored.command("road",{"cell":Vector2i(11,13)})
 for tick in range(5000):
  sim.step()
  restored.step()
  if sim.buildings.back().stage == "complete": break
 expect(sim.buildings.back().stage == "complete" and state(sim) == state(restored),"reconnection and restored cargo finish the construction identically")
 expect(sim.conservation_errors().is_empty(),"new entrance logistics conserves all resources")

func _test_mission() -> void:
 var sim := fresh()
 for plan in [["house",Vector2i(4,6)],["house",Vector2i(8,5)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)],["farm",Vector2i(16,19)],["vineyard",Vector2i(17,5)],["winery",Vector2i(18,17)],["store",Vector2i(7,18)]]:
  var result: Dictionary = sim.command("build",{"kind":plan[0],"cell":plan[1]})
  expect(result.ok,"legal approved mission construction "+plan[0]+": "+result.message)
 var roads: Array[Vector2i] = []
 for x in range(2,21): roads.append(Vector2i(x,13))
 for y in range(8,13): roads.append(Vector2i(5,y))
 for x in range(4,11): roads.append(Vector2i(x,8))
 for y in range(7,13): roads.append(Vector2i(15,y))
 for x in range(8,20): roads.append(Vector2i(x,7))
 for y in range(14,22): roads.append(Vector2i(5,y))
 for x in range(3,20): roads.append(Vector2i(x,21))
 roads.append(Vector2i(3,20))
 roads.append(Vector2i(19,20))
 expect(sim.command("road",{"cells":roads}).ok,"full mission network routes around the expanded main building and school")
 for role in ["lumberjack","stonecutter","farmer","vintner","vintner","servant","servant"]:
  expect(sim.command("train",{"role":role}).ok,"professional training request "+role)
 var issues: Array[String] = []
 var invalid_movement := false
 var won_tick := 0
 for index in range(18000):
  sim.step()
  if index % 50 == 0:
   for issue in sim.conservation_errors():
    if not issues.has(issue): issues.append(issue)
  for person in sim.workers:
   if not sim.is_walkable(person.cell): invalid_movement = true
   if person.role == "servant" and not person.cargo.is_empty() and not _loaded_servant_uses_allowed_road(sim,person): invalid_movement = true
  if sim._completed("lumber")>0 and sim._completed("quarry")>0 and sim._completed("farm")>0 and sim._completed("vineyard")>0 and sim._completed("winery")>0 and sim._completed("store")>0:
   won_tick = sim.tick
   break
 expect(won_tick > 0,"civil mission completes through legal construction, roads and training commands")
 expect(not invalid_movement,"civilians avoid footprints and trees; building cargo stays on completed roads and road stone uses its planned network")
 expect(issues.is_empty(),"resources remain conserved throughout the approved mission: "+str(issues))
 expect(sim._completed("lumber") > 0 and sim._completed("quarry") > 0 and sim._completed("farm") > 0 and sim._completed("vineyard") > 0 and sim._completed("winery") > 0,"all required production buildings are physically complete")
 expect(sim._completed("store") > 0 and sim.storage_capacity() == 1000,"mission includes a completed three by three store that expands the principal depot")
 var resumed := fresh()
 expect(resumed.restore(state(sim)),"working production village saves and restores in approved mode")
 advance(sim,300)
 advance(resumed,300)
 expect(state(sim) == state(resumed),"production and deliveries remain deterministic after restore")
 print("APPROVED_MISSION_RESULT ",JSON.stringify({"victory_tick":won_tick,"tick":sim.tick,"roads":sim.roads.size(),"stats":sim.stats,"stock":sim.stock,"failures":failures}))
 if won_tick == 0:
  for building in sim.buildings: print("BUILDING ",building)
  for person in sim.workers: print("PERSON ",person)

# Delivery to buildings still requires completed paving. Only road supplies may
# cross the connected planned worksite; a cancelled pile is its own recovery endpoint.
func _loaded_servant_uses_allowed_road(sim: RefCounted, person: Dictionary) -> bool:
 if sim._road_node(person.cell): return true
 var task: Dictionary = person.task
 if task.get("type","") != "road_delivery": return false
 var road: Dictionary = sim.road_at(person.cell)
 if not road.is_empty() and road.stage in ["planned","building"]: return true
 if task.get("phase","") in ["recover","return"]:
  for cancelled in sim.roads:
   if cancelled.id == task.get("road",-1) and cancelled.stage == "cancelled" and cancelled.cell == person.cell: return true
 return false
