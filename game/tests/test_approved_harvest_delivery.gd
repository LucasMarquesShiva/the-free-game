extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func expect(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL ",message)
func run()->void:
 var s:=Sim.new();s.setup()
 expect(s._food_stock_target()==320,"initial warehouse keeps a working food reserve above starter stock")
 expect(s.command("build",{"kind":"farm","cell":Vector2i(16,17)}).ok,"garden placed")
 var farm:Dictionary=s.buildings.back()
 var roads:Array[Vector2i]=[]
 for x in range(10,16):roads.append(Vector2i(x,13))
 for y in range(14,20):roads.append(Vector2i(15,y))
 roads.append(Vector2i(16,19))
 expect(s.command("road",{"cells":roads}).ok,"garden road planned")
 s.command("train",{"role":"farmer"})
 var delivered_food:=0
 for i in range(4000):
  s.step()
  delivered_food=int(s.stock.food)+int(s.consumed.food)-int(s.initial.food)
  if delivered_food>=8:break
 expect(farm.stage=="complete" and int(s.produced.food)>=8,"garden is built and harvested through autonomous jobs")
 expect(delivered_food>=8,"servants physically bring first harvest to the depot despite initial food reserve")
 expect(int(s.stock.food)<=s._food_stock_target()+1,"food deliveries keep space for other resources")
 expect(s.conservation_errors().is_empty(),"first harvest delivery preserves all food and construction materials")
 print("HARVEST_DELIVERY_RESULT checks=",checks," failures=",failures," delivered_food=",delivered_food," tick=",s.tick)
 quit(0 if failures.is_empty() else 1)
