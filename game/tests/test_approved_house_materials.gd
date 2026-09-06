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
 var cells:Array[Vector2i]=[]
 for x in range(10,14):cells.append(Vector2i(x,13))
 for y in range(14,18):cells.append(Vector2i(13,y))
 for x in range(10,13):cells.append(Vector2i(x,17))
 expect(s.command("road",{"cells":cells}).ok,"plan road to future house")
 advance(s,1600)
 expect(s._connected_roads.has(Vector2i(10,17)),"future house access has a completed road")
 # All remaining stock stone is consumed elsewhere, preserving conservation.
 s._consume_stock("stone",int(s.stock.stone))
 expect(s.command("build",{"kind":"house","cell":Vector2i(10,15)}).ok,"mark house when wood is available but no stone remains")
 var b:Dictionary=s.buildings.back()
 advance(s,1600)
 expect(b.stage=="materials" and int(b.delivered.wood)==4 and int(b.delivered.stone)==0,"real deliveries bring wood but house cannot start without its two stones")
 expect(int(s.stats.houses_built)==0,"missing stone cannot be bypassed by free builders")
 # A later production delivery supplies exactly the missing material.
 s.stock.stone+=2;s.produced.stone+=2
 advance(s,1800)
 expect(b.stage=="complete" and int(s.stats.houses_built)==1,"house finishes automatically when the two stones arrive")
 expect(int(b.delivered.wood)==0 and int(b.delivered.stone)==0,"both material types are consumed by construction")
 expect(s.conservation_errors().is_empty(),"house resource accounting remains balanced through the wait")
 print("HOUSE_MATERIALS_RESULT checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
