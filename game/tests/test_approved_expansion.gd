extends SceneTree
const Village=preload("res://simulation/approved_sim.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func expect(condition:bool,message:String)->void:
 checks+=1
 if not condition:failures.append(message);printerr("FAIL: ",message)
func run()->void:
 var sim:=Village.new();sim.setup()
 expect(not sim.command("build",{"kind":"house","cell":Vector2i(22,13)}).ok,"the physical bridge stays a passage, not a building plot")
 expect(not sim.command("build",{"kind":"winery","cell":Vector2i(33,12)}).ok,"large buildings cannot hang beyond the playable valley")
 var plan:=sim.command("build",{"kind":"house","cell":Vector2i(26,11)})
 expect(plan.ok,"player can settle on the opposite bank")
 var house:Dictionary=sim.buildings.back()
 for i in range(250):sim.step()
 expect(house.stage=="materials" and house.delivered.wood==0,"opposite-bank building waits for a real road before receiving cargo")
 var road:Array[Vector2i]=[Vector2i(8,13),Vector2i(8,14)]
 for x in range(9,27):road.append(Vector2i(x,14))
 road.append(Vector2i(26,13))
 for x in range(9,14):road.append(Vector2i(x,13))
 expect(sim.command("road",{"cells":road}).ok,"player can trace a connected route across the timber bridge")
 var crossing:=false
 var off_road:=false
 for i in range(10000):
  sim.step()
  for w in sim.workers:
   if not w.cargo.is_empty() and w.role=="servant":
    crossing=crossing or (w.cell.x>=22 and w.cell.x<=24)
    off_road=off_road or not (sim.has_road(w.cell) or w.cell==sim.HUB)
  if house.stage=="complete":break
 expect(house.stage=="complete" and crossing,"autonomous builders and loaded servants finish a home beyond the river")
 expect(not off_road,"loaded servants remain on completed roads during the river crossing")
 expect(sim.conservation_errors().is_empty(),"river expansion conserves materials and worker positions")
 var restored:=Village.new();restored.setup()
 expect(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"opposite-bank settlement restores from a real JSON save")
 var busy:=Village.new();busy.setup()
 var path:Array[Vector2i]=[]
 for x in range(8,14):path.append(Vector2i(x,13))
 path.append(Vector2i(7,13));path.append(Vector2i(8,14))
 busy.command("road",{"cells":path})
 for i in range(3):busy.step()
 var response:=busy.command("build",{"kind":"house","cell":Vector2i(5,5)})
 expect(response.ok and response.message.contains("Construtores ocupados") and response.message.contains("escola"),"queued work explains that busy builders can be awaited or trained")
 # This fixture represents a settlement with every porter already allocated;
 # command validation itself must not release any of those assignments.
 for worker in busy.workers:
  if worker.role=="servant":worker.task={"type":"delivery"}
 response=busy.command("build",{"kind":"house","cell":Vector2i(9,5)})
 expect(response.ok and response.message.contains("Serventes ocupados") and response.message.contains("automaticamente"),"busy servants are announced when placing the work order")
 var held:=0
 for worker in busy.workers:
  if worker.role=="servant" and not worker.task.is_empty():held+=1
 expect(held==5,"queuing a new building preserves existing porter assignments")
 print("APPROVED_EXPANSION checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
