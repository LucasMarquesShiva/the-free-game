extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
const Terrain=preload("res://presentation/approved_terrain.gd")
const Ambience=preload("res://presentation/approved_bank_ambience.gd")
var count:int=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 count+=1
 if not ok:failures.append(label);push_error(label)
func run()->void:
 var sim:=Sim.new();sim.setup();var before:Dictionary=sim.snapshot()
 var terrain:=Terrain.new();terrain.sim=sim;terrain.terrain_noise.seed=32;terrain.terrain_noise.frequency=0.032;root.add_child(terrain);terrain._ground()
 var decor:Node3D=Ambience.create(terrain);terrain.add_child(decor)
 var copy:Node3D=Ambience.create(terrain)
 var placements:Array=decor.get_meta("placements")
 check(placements==copy.get_meta("placements"),"Placement is deterministic")
 check(sim.snapshot()==before,"Decoration does not modify game rules or state")
 check(placements.size()>25 and placements.size()<=112,"Small bounded quantity of shoreline accents")
 check(decor.get_meta("triangles")<6000,"Geometry stays below 6000 triangles")
 check(decor.get_child_count()==1,"One draw surface for the complete decoration")
 var mesh:MeshInstance3D=decor.get_child(0)
 check(mesh.mesh.get_surface_count()==1,"One material surface")
 check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"No extra shadow passes")
 check(mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Opaque material, no transparent sorting")
 var families:Dictionary={};var banks:Dictionary={}
 for p:Dictionary in placements:
  families[p.kind]=families.get(p.kind,0)+1;banks[p.side]=true
  check(Ambience._blocked_disc(sim,Vector2(p.position.x,p.position.z),p.radius),"Full plant envelope avoids every traversable cell and bridge")
  check(p.position.y>Ambience.WATER_MAX+0.02,"Roots sit above maximum water crest")
  if p.kind=="flower":check(p.position.y>Ambience.WATER_MAX+0.075,"Flowers occupy a dry part of the bank")
 check(families.has("flower") and families.has("sedge") and banks.size()==2,"Both banks and both plant families represented")
 var max_radius:float=0.0
 var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var valid:bool=true
 for v:Vector3 in vertices:
  var cell:=Vector2i(roundi(v.x/2.5),roundi(v.z/2.5))
  if sim._terrain_walkable(cell) or (cell.y>=12 and cell.y<=16):valid=false
 check(valid,"Every actual mesh vertex stays outside paths and bridge access")
 print("BANK_AMBIENCE_TEST ",JSON.stringify({"checks":count,"failures":failures,"placements":placements.size(),"families":families,"triangles":decor.get_meta("triangles"),"surfaces":mesh.mesh.get_surface_count()}))
 copy.free();terrain.free();quit(0 if failures.is_empty() else 1)
