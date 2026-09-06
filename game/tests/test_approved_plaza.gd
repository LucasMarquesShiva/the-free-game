extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func expect(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL ",message)
func advance(s:RefCounted,n:int)->void:
 for i in range(n):s.step()
func run()->void:
 var s:=Sim.new();s.setup()
 expect(s.plaza_cells().size()==9,"new settlement has nine permanent paved square tiles")
 expect(s.buildings.size()==2 and s.roads.is_empty(),"square does not add production buildings or prebuilt player roads")
 var slots:={}
 for w in s.workers:
  if not w.task.is_empty():continue
  expect(s.is_plaza_cell(w.cell),"idle resident starts on square")
  slots[str(w.cell)+str(s.plaza_rest_offset(w))]=true
 expect(slots.size()==16,"initial idle people occupy distinct waiting positions")
 expect(not s.can_place("house",Vector2i(8,14)).is_empty(),"square remains available for people")
 expect(not s.command("remove_road",{"cell":Vector2i(8,14)}).ok,"public square cannot be erased")
 expect(s.command("build",{"kind":"house","cell":Vector2i(10,15)}).ok,"former waiting area is now available for construction")
 var returning:Dictionary=s.workers[10]
 returning.cell=Vector2i(15,16);returning.goal=returning.cell
 advance(s,350)
 expect(returning.cell==s.plaza_rest_cell(returning) and returning.route.is_empty(),"unemployed citizen walks back and stays in square")
 var path:Array[Vector2i]=[]
 for x in range(8,14):path.append(Vector2i(x,13))
 expect(s.command("road",{"cells":path}).ok,"road extends from existing plaza")
 expect(s.roads.size()==4,"only four new tiles connect school; public paving is free")
 s.command("train",{"role":"farmer"})
 advance(s,1800)
 expect(s.profession_counts().farmer==1,"residents leave plaza automatically to study")
 var idle_outside:=0
 for w in s.workers:
  if w.task.is_empty() and w.cargo.is_empty() and not s.is_plaza_cell(w.cell):idle_outside+=1
 expect(idle_outside==0,"all free workers return after road completion and training")
 var load_sim:=Sim.new();load_sim.setup()
 expect(load_sim.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"plaza population and network survive save/load")
 expect(JSON.parse_string(JSON.stringify(load_sim.snapshot()))==JSON.parse_string(JSON.stringify(s.snapshot())),"plaza restore preserves simulation state")
 for kind in s.definitions:
  if kind=="hall":continue
  var cost:Dictionary=s.definition(kind).cost
  expect(cost.get("wood",0)>0 and cost.get("stone",0)>0,"each constructible building requires wood and stone: "+kind)
 expect(s.conservation_errors().is_empty(),"public paving never fabricates or consumes stock")
 var legacy:=Sim.new();legacy.setup()
 var old_state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/approved-v040-initial.json"))
 expect(legacy.restore(old_state),"unmodified 0.4.0 save loads without resetting progress")
 expect(JSON.parse_string(JSON.stringify(legacy.stock))==JSON.parse_string(JSON.stringify(s.initial)) and legacy.buildings.size()==2,"legacy stock and buildings remain intact")
 advance(legacy,350)
 var migrated:=true
 for person in legacy.workers:
  if person.task.is_empty() and not legacy.is_plaza_cell(person.cell):migrated=false
 expect(migrated and legacy.conservation_errors().is_empty(),"old idle residents walk to the new square after loading")
 print("PLAZA_TEST_RESULT checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
