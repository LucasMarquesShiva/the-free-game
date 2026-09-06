extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
const Legacy=preload("res://tests/legacy_approved_sim.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func expect(value:bool,message:String)->void:
 checks+=1
 if not value:failures.append(message);printerr("FAIL ",message)
func state(sim:RefCounted)->Dictionary:return JSON.parse_string(JSON.stringify(sim.snapshot()))
func _initialize()->void:call_deferred("run")
func run()->void:
 _branched()
 _legacy("pickup")
 _legacy("build")
 _malformed()
 print("PARALLEL_ROAD_SAVES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
 quit(0 if failures.is_empty() else 1)
func _branched()->void:
 var sim:=Sim.new();sim.setup()
 for i in range(50):sim.step()
 var cells:Array[Vector2i]=[Vector2i(10,13),Vector2i(10,14),Vector2i(10,15),Vector2i(11,13),Vector2i(11,14),Vector2i(11,15)]
 expect(sim.command("road",{"cells":cells}).ok,"PAR-08 legal three-front branch beside square")
 var peak:=0
 for tick in range(1000):
  sim.step()
  var busy:=0
  for p in sim.workers:
   if p.task.get("type")=="road" and p.cell==p.goal and p.route.is_empty():busy+=1
  peak=maxi(peak,busy)
  expect(sim.conservation_errors().is_empty(),"PAR-08 conservation on branched work")
  if sim.roads.all(func(r):return r.stage=="complete"):break
 expect(peak==3,"PAR-08 all three available builders can pave concurrently")
 expect(sim.roads.all(func(r):return r.stage=="complete"),"PAR-08 all branches complete")
 metrics.branched={"peak_builders":peak,"final_tick":sim.tick}
func _legacy(phase:String)->void:
 var old:=Legacy.new();old.setup()
 var cells:Array[Vector2i]=[Vector2i(10,13),Vector2i(11,13),Vector2i(12,13),Vector2i(13,13)]
 expect(old.command("road",{"cells":cells}).ok,"PAR-09 legacy order")
 var found:=false
 for i in range(900):
  old.step()
  for p in old.workers:
   if p.task.get("type")=="road" and p.task.get("phase")==phase:found=true;break
  if found:break
 expect(found,"PAR-09 actual legacy "+phase+" checkpoint")
 if not found:return
 var sim:=Sim.new();sim.setup()
 expect(sim.restore(state(old)),"PAR-09 legacy "+phase+" restores into parallel logistics")
 for i in range(1200):
  sim.step()
  expect(sim.conservation_errors().is_empty(),"PAR-09 legacy transfer conserves stone")
  if sim.roads.all(func(r):return r.stage=="complete"):break
 expect(sim.roads.all(func(r):return r.stage=="complete") and sim.reserved.stone==0,"PAR-09 legacy in-progress roads complete without duplicate supply")
 metrics["legacy_"+phase]=sim.tick
func _malformed()->void:
 var sim:=Sim.new();sim.setup()
 var cells:Array[Vector2i]=[Vector2i(10,13),Vector2i(11,13)]
 expect(sim.command("road",{"cells":cells}).ok,"PAR-10 legal validation fixture")
 sim.step()
 var original:=state(sim)
 for mutation in ["double_pile","negative_pile","missing_carrier","wrong_role","wrong_phase","orphan_task"]:
  var bad:=original.duplicate(true)
  var road:Dictionary=bad.roads[0]
  var person:Dictionary={}
  for w in bad.workers:
   if w.id==road.carrier:person=w;break
  match mutation:
   "double_pile":road.delivered=2
   "negative_pile":road.delivered=-1
   "missing_carrier":road.carrier=99999
   "wrong_role":person.role="builder"
   "wrong_phase":person.task.phase="teleport"
   "orphan_task":person.task.road=99999
  expect(not sim.restore(bad),"PAR-10 rejects "+mutation)
  expect(state(sim)==original,"PAR-10 rejected save leaves current game intact")
