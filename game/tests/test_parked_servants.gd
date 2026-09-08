extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func expect(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func order(sim:RefCounted,kind:String,payload:Dictionary)->void:
	var r:Dictionary=sim.command(kind,payload);expect(r.ok,"legal command: "+r.message)
func steps(sim:RefCounted,count:int)->void:
	for i in range(count):sim.step();expect(sim.conservation_errors().is_empty(),"resources conserved")
func idle_servants(sim:RefCounted)->int:
	var count:=0
	for p in sim.workers:
		if p.role=="servant" and p.task.is_empty() and p.route.is_empty() and p.cargo.is_empty():count+=1
	return count
func run()->void:
	var sim:=Sim.new();sim.setup()
	order(sim,"build",{"kind":"lumber","cell":Vector2i(4,11)})
	var road:Array[Vector2i]=[]
	for x in range(4,14):road.append(Vector2i(x,13))
	order(sim,"road",{"cells":road})
	for i in range(2400):
		sim.step();expect(sim.conservation_errors().is_empty(),"resources conserved during initial construction")
		if sim._completed("lumber")==1:break
	expect(sim._completed("lumber")==1,"close lumber hut completes through legal deliveries")
	steps(sim,320)
	expect(not sim._has_pending_road_delivery(),"empty unstaffed producer creates no demand")
	expect(idle_servants(sim)==5,"all five servants finish parking when there is no demand")
	var positions:Dictionary={}
	for p in sim.workers:
		if p.role=="servant":positions[p.id]=p.cell
	steps(sim,200)
	for p in sim.workers:
		if p.role=="servant":expect(p.cell==positions[p.id] and p.task.is_empty(),"idle producer does not send a parked servant back to the hub")
	order(sim,"train",{"role":"lumberjack"})
	steps(sim,1000)
	expect(int(sim.produced.get("trunks",0))>0 and sim.stock.wood>=100,"woodcutter fills trunk output while timber stock stays above its target")
	var parked:=false
	for i in range(1500):
		sim.step();expect(sim.conservation_errors().is_empty(),"resources conserved while trunks are collected")
		if not sim._has_pending_road_delivery() and idle_servants(sim)==5:
			parked=true
			break
	expect(parked and not sim._has_pending_road_delivery(),"servants re-park after trunks reach the storehouse target")
	expect(idle_servants(sim)==5,"trunk collection does not leave an idle traffic loop")
	order(sim,"build",{"kind":"house","cell":Vector2i(16,11)})
	var branch:Array[Vector2i]=[]
	for x in range(13,17):branch.append(Vector2i(x,13))
	order(sim,"road",{"cells":branch})
	var resumed:=false;var delivered:=false
	for i in range(2000):
		sim.step();expect(sim.conservation_errors().is_empty(),"resources conserved after new demand")
		for p in sim.workers:
			if p.role=="servant" and p.task.get("type","") in ["join_road","delivery"]:resumed=true
		for b in sim.buildings:
			if b.kind=="house" and (b.delivered.wood>0 or b.stage in ["building","complete"]):delivered=true
		if sim._completed("house")==1:break
	expect(resumed,"parked servants leave automatically when a new construction needs supplies")
	expect(delivered and sim._completed("house")==1,"new demand receives materials and completes")
	print("PARKED_SERVANTS_RESULT checks=",checks," failures=",failures," tick=",sim.tick)
	quit(0 if failures.is_empty() else 1)
