extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func expect(value:bool,message:String)->void:
 checks+=1
 if not value:
  failures.append(message)
  printerr("FAIL ",message)
func fresh()->RefCounted:
 var sim:=Sim.new();sim.setup();return sim
func snapshot(sim:RefCounted)->Dictionary:return JSON.parse_string(JSON.stringify(sim.snapshot()))
func cells_line(last:int=19,reverse:bool=false)->Array[Vector2i]:
 var cells:Array[Vector2i]=[]
 for x in range(10,last+1):cells.append(Vector2i(x,13))
 if reverse:cells.reverse()
 return cells
func advance(sim:RefCounted,n:int)->bool:
 for i in range(n):
  sim.step()
  if not sim.conservation_errors().is_empty():
   expect(false,"conservation at tick "+str(sim.tick)+": "+str(sim.conservation_errors()));return false
 return true
func restore_check(sim:RefCounted,label:String)->RefCounted:
 var copy:=fresh()
 expect(copy.restore(snapshot(sim)),label+" restores")
 expect(snapshot(sim)==snapshot(copy),label+" roundtrips unchanged")
 return copy
func completed(sim:RefCounted)->bool:
 for r in sim.roads:
  if r.stage not in ["complete","cancelled"]:return false
 return true
func _initialize()->void:call_deferred("run")
func run()->void:
 _parallel_and_building_routes()
 _disconnected_front()
 _cancel_reservation()
 _cancel_delivered_pile()
 _cancel_loaded_and_reconnect()
 print("PARALLEL_ROADS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
 var file:=FileAccess.open("user://vale-gameplay-06/parallel-result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"  "));file.close()
 quit(0 if failures.is_empty() else 1)
func _parallel_and_building_routes()->void:
 var sim:=fresh()
 expect(sim.plaza_cells().size()==9 and sim.roads.is_empty(),"PAR-01 plaza is ready without road orders")
 expect(sim.command("road",{"cells":cells_line(19,true)}).ok,"PAR-01 reverse-ordered connected stroke is legal")
 expect(sim.command("build",{"kind":"house","cell":Vector2i(17,11)}).ok,"PAR-01 building beside future road is legal")
 var max_carriers:=0;var max_builders:=0;var far_before_near:=false;var supplied:= {}
 var checkpoint:={"pickup":false,"deliver":false,"delivered":false,"building":false}
 var copies:Array[Dictionary]=[]
 var blocked_materials:=false
 for i in range(1600):
  if not advance(sim,1):return
  var carriers:=0;var builders:=0
  for person in sim.workers:
   if person.task.get("type")=="road_delivery":
    carriers+=1
    var phase:String=person.task.phase
    if phase in ["pickup","deliver"] and not checkpoint[phase]:
     copies.append({"sim":restore_check(sim,"PAR-02 "+phase),"tick":sim.tick});checkpoint[phase]=true
   elif person.task.get("type")=="road" and person.cell==person.goal and person.route.is_empty():builders+=1
   if person.task.get("type")=="delivery":
    expect(sim._road_node(person.cell),"PAR-03 building courier stays on finished road")
    for cell in person.route:expect(sim._road_node(cell),"PAR-03 building route never uses planned paving")
  max_carriers=maxi(max_carriers,carriers);max_builders=maxi(max_builders,builders)
  for road in sim.roads:
   if int(road.delivered)==1 or road.stage=="complete":supplied[road.id]=true
   if road.cell.x>=15 and (int(road.delivered)==1 or road.stage=="complete") and sim.road_at(Vector2i(10,13)).stage!="complete":far_before_near=true
   var stage:="building" if road.stage=="building" else ("delivered" if int(road.delivered)==1 else "")
   if not stage.is_empty() and not checkpoint[stage]:
    copies.append({"sim":restore_check(sim,"PAR-02 "+stage),"tick":sim.tick});checkpoint[stage]=true
  var house:Dictionary=sim.buildings.back()
  if house.stage=="materials" and not sim.is_building_connected(house):
   blocked_materials=true
   expect(house.delivered.wood==0 and house.delivered.stone==0,"PAR-03 no building goods cross unfinished chain")
  for entry in copies:
   if entry.tick<sim.tick:entry.sim.step()
   expect(snapshot(entry.sim)==snapshot(sim),"PAR-02 save continuation deterministic")
  if completed(sim) and house.stage=="complete":break
 expect(max_carriers>=5,"PAR-01 five servants independently supply the connected plan")
 expect(max_builders>=2,"PAR-01 multiple builders pave simultaneously")
 expect(far_before_near,"PAR-01 remote planned tiles supplied before first tile completes")
 expect(supplied.size()==10 and completed(sim),"PAR-01 every requested tile gets real stone and finishes")
 expect(blocked_materials and sim.buildings.back().stage=="complete","PAR-03 building waits for completed network then finishes")
 for phase in checkpoint:expect(checkpoint[phase],"PAR-02 exercised "+phase+" snapshot")
 expect(sim.reserved.stone==0,"PAR-01 road reservations settle")
 metrics.parallel={"max_carriers":max_carriers,"max_builders":max_builders,"final_tick":sim.tick,"far_before_near":far_before_near,"delivered_tiles":supplied.size()}
func _disconnected_front()->void:
 var sim:=fresh()
 var island:Array[Vector2i]=[Vector2i(15,13),Vector2i(16,13),Vector2i(17,13)]
 expect(sim.command("road",{"cells":island}).ok,"PAR-04 disconnected island can be planned")
 advance(sim,150)
 expect(sim.roads.all(func(r):return r.funded and r.carrier==-1 and r.delivered==0 and r.builder==-1),"PAR-04 isolated plans reserve stone but attract no carriers/builders")
 expect(sim.command("road",{"cells":cells_line(14)}).ok,"PAR-04 adding a planned connector is legal")
 var assigned_before_ready:=false
 for i in range(1000):
  if not advance(sim,1):return
  for r in sim.roads:
   if r.cell.x>=15 and r.carrier!=-1 and not sim.has_road(Vector2i(10,13)):assigned_before_ready=true
  if completed(sim):break
 expect(assigned_before_ready and completed(sim),"PAR-04 planned connector activates distant supplies without prior paving")
func _cancel_reservation()->void:
 var sim:=fresh();var stone:int=sim.stock.stone
 expect(sim.command("road",{"cell":Vector2i(10,13)}).ok,"PAR-05 legal unstarted tile")
 sim.step()
 var road:Dictionary=sim.road_at(Vector2i(10,13))
 expect(road.carrier!=-1 and road.funded,"PAR-05 real pickup task assigned")
 expect(sim.command("remove_road",{"cell":road.cell}).ok,"PAR-05 cancel during empty pickup")
 expect(sim.stock.stone==stone and sim.reserved.stone==0 and road.carrier==-1,"PAR-05 cancel releases reservation and assignment without creating stock")
 var restored:=restore_check(sim,"PAR-05 canceled pickup")
 advance(sim,120);advance(restored,120)
 expect(snapshot(sim)==snapshot(restored) and sim.conservation_errors().is_empty(),"PAR-05 no stale pickup after restore")
func _cancel_delivered_pile()->void:
 var sim:=fresh()
 for cell in [Vector2i(17,6),Vector2i(17,17),Vector2i(12,20)]:expect(sim.command("build",{"kind":"house","cell":cell}).ok,"PAR-06 occupy builders through legal house projects")
 expect(sim.command("road",{"cells":cells_line(15)}).ok,"PAR-06 supply a connected stroke")
 var target:Dictionary={}
 for i in range(900):
  if not advance(sim,1):return
  for road in sim.roads:
   if road.delivered==1 and road.builder==-1 and not sim._occupied(road.cell):target=road;break
  if not target.is_empty():break
 expect(not target.is_empty(),"PAR-06 delivered stone waits for a busy builder")
 if target.is_empty():return
 var stone:int=sim.stock.stone
 expect(sim.command("remove_road",{"cell":target.cell}).ok,"PAR-06 delivered tile can be canceled when unoccupied")
 expect(target.delivered==1 and sim.stock.stone==stone,"PAR-06 delivered stone remains physically at cancellation site")
 var copy:=restore_check(sim,"PAR-06 recoverable canceled pile")
 var recovery_seen:=false
 for i in range(1400):
  if not advance(sim,1):return
  copy.step()
  for p in sim.workers:
   if p.task.get("type")=="road_delivery" and p.task.get("road")==target.id and p.task.phase in ["recover","return"]:recovery_seen=true
  expect(snapshot(sim)==snapshot(copy),"PAR-06 recovery save continuation deterministic")
  if target.delivered==0 and target.carrier==-1 and recovery_seen:break
 expect(recovery_seen and target.delivered==0 and target.carrier==-1,"PAR-06 servant retrieves canceled stone and returns it")
 metrics.recovery={"cell":str(target.cell),"final_tick":sim.tick}
func _cancel_loaded_and_reconnect()->void:
 var sim:=fresh()
 expect(sim.command("road",{"cells":cells_line(20,true)}).ok,"PAR-07 long reversed connected front")
 var chosen:Dictionary={};var gap:Dictionary={};var target:Dictionary={}
 for i in range(1400):
  if not advance(sim,1):return
  for p in sim.workers:
   if p.task.get("type")!="road_delivery" or p.task.phase!="deliver" or p.cargo.is_empty() or p.cell.y!=13 or p.cell.x<12:continue
   var dest:Dictionary=sim._road(p.task.road)
   if dest.cell.x<=p.cell.x or dest.builder!=-1 or sim._occupied(dest.cell):continue
   for x in range(10,p.cell.x):
    var candidate:Dictionary=sim.road_at(Vector2i(x,13))
    if not candidate.is_empty() and candidate.builder==-1 and not sim._occupied(candidate.cell):
     chosen=p;gap=candidate;target=dest;break
   if not chosen.is_empty():break
  if not chosen.is_empty():break
 expect(not chosen.is_empty(),"PAR-07 real loaded courier beyond a legally removable link")
 if chosen.is_empty():return
 expect(sim.command("remove_road",{"cell":gap.cell}).ok,"PAR-07 remove the planned chain behind the carrier")
 expect(sim.command("remove_road",{"cell":target.cell}).ok,"PAR-07 cancel its destination while stone is in transit")
 expect(chosen.cargo.get("amount")==1 and chosen.task.phase=="return","PAR-07 cancellation converts in-flight stone into return delivery")
 var returned_jobs:int=chosen.get("jobs",0)
 var copy:=restore_check(sim,"PAR-07 disconnected return")
 for i in range(100):sim.step();copy.step()
 expect(chosen.cargo.get("amount")==1 and chosen.task.phase=="return","PAR-07 broken chain retains stone instead of teleporting it")
 expect(snapshot(sim)==snapshot(copy) and sim.conservation_errors().is_empty(),"PAR-07 interrupted return is deterministic and conserved")
 expect(sim.command("road",{"cell":gap.cell}).ok,"PAR-07 restore planned connection")
 expect(copy.command("road",{"cell":gap.cell}).ok,"PAR-07 restored game receives same reconnect command")
 var returned:=false
 for i in range(1600):
  if not advance(sim,1):return
  copy.step()
  expect(snapshot(sim)==snapshot(copy),"PAR-07 reconnection resumes identically")
  if int(chosen.get("jobs",0))>returned_jobs and chosen.task.get("road",-1)!=target.id:returned=true;break
 if not returned:
  var dump:=FileAccess.open("user://vale-gameplay-06/parallel-return-stall.json",FileAccess.WRITE)
  dump.store_string(JSON.stringify(snapshot(sim),"  "));dump.close()
  print("RETURN_STALL ",chosen," connected=",sim._road_supply_connected.keys())
 expect(returned,"PAR-07 real carrier can return its preserved stone after reconnect")
 expect(sim.conservation_errors().is_empty(),"PAR-07 cancellation and replanning conserve every stone")
 metrics.interrupted_return={"gap":str(gap.cell),"target":str(target.cell),"carrier":chosen.id,"final_tick":sim.tick}
