extends SceneTree
# Frozen-root geometry audit. Reads actual ArrayMesh faces; no source mutations.
const Sim=preload("res://simulation/approved_sim.gd")
const Terrain=preload("res://presentation/approved_terrain.gd")
const World=preload("res://presentation/approved_world.gd")
var sim:RefCounted
var terrain:Node3D
var world:Node3D
var ground_faces:PackedVector3Array
var bridge_triangles:Array=[]
var report:Dictionary={"checks":[],"failures":[],"metrics":{}}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 report.checks.append({"ok":ok,"label":label})
 if not ok:report.failures.append(label)
func ground_height(x:float,z:float)->float:
 var xi:int=clampi(floori((x+27.0)/1.2),0,119)
 var zi:int=clampi(floori((z+27.0)/1.2),0,106)
 var offset:int=(zi*120+xi)*6
 for t in range(2):
  var a:=ground_faces[offset+t*3];var b:=ground_faces[offset+t*3+1];var c:=ground_faces[offset+t*3+2]
  var y:Variant=triangle_y(x,z,a,b,c)
  if y!=null:return y
 return -9999.0
func triangle_y(x:float,z:float,a:Vector3,b:Vector3,c:Vector3)->Variant:
 var den:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
 if absf(den)<0.000001:return null
 var u:float=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/den
 var v:float=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/den
 var w:float=1.0-u-v
 if minf(u,minf(v,w)) < -0.0001:return null
 return u*a.y+v*b.y+w*c.y
func collect_bridge(n:Node3D)->void:
 if n is MeshInstance3D:
  var faces:PackedVector3Array=n.mesh.get_faces()
  for index in range(0,faces.size(),3):
   var a:Vector3=n.global_transform*faces[index];var b:Vector3=n.global_transform*faces[index+1];var c:Vector3=n.global_transform*faces[index+2]
   # Both windings work. Keep projected non-vertical triangles only.
   if absf((b-a).cross(c-a).y)<0.000001:continue
   bridge_triangles.append([a,b,c,minf(a.x,minf(b.x,c.x)),maxf(a.x,maxf(b.x,c.x)),minf(a.z,minf(b.z,c.z)),maxf(a.z,maxf(b.z,c.z))])
 for child in n.get_children():
  if child is Node3D:collect_bridge(child)
func bridge_height(x:float,z:float)->float:
 var y:float=-9999.0
 for t:Array in bridge_triangles:
  if x<t[3]-0.0001 or x>t[4]+0.0001 or z<t[5]-0.0001 or z>t[6]+0.0001:continue
  var h:Variant=triangle_y(x,z,t[0],t[1],t[2])
  if h!=null:y=maxf(y,h)
 return y
func surface_height(x:float,z:float)->float:
 return maxf(ground_height(x,z),bridge_height(x,z))
func projected_position(cell:Vector2i,id:int)->Vector3:
 return world._person_position(cell,id)
func under_water(x:float,z:float,y:float)->bool:
 return x>=52.9 and x<=62.1 and z>=-39.5 and z<=115.5 and y < -0.81
func vertices_below_support(n:Node3D)->int:
 var count:int=0
 if n is MeshInstance3D:
  for local:Vector3 in n.mesh.get_faces():
   var p:Vector3=n.global_transform*local
   if p.y<surface_height(p.x,p.z)-0.02:count+=1
 for child in n.get_children():
  if child is Node3D:count+=vertices_below_support(child)
 return count
func run()->void:
 sim=Sim.new();sim.setup()
 terrain=Terrain.new();root.add_child(terrain);terrain.setup(sim)
 world=World.new();root.add_child(world);world.sim=sim;world.terrain=terrain
 check(sim.buildings.size()==2 and sim.workers.size()==17 and sim.roads.is_empty(),"Terrain setup preserves two buildings, 17 people and zero logical roads")
 check(terrain.road_nodes.is_empty(),"No initial road or origin paving appears before connected road construction")
 ground_faces=terrain.get_child(0).mesh.get_faces()
 collect_bridge(terrain.get_node("OakBridge"))
 check(ground_faces.size()==120*107*6,"Ground samples inspect actual rendered triangles")
 check(bridge_triangles.size()>100,"Bridge surfaces come from actual mesh geometry")
 var dry_failures:Array=[];var water_edges:Array=[];var foot_penetrations:Array=[];var excessive_float:Array=[]
 var dry_count:int=0;var min_clearance:float=999;var max_mesh_delta:float=0.0;var max_ground_api_error:float=0.0
 for y in range(1,Sim.HEIGHT-1):
  for x in range(1,Sim.WIDTH-1):
   var cell:=Vector2i(x,y)
   if not sim.is_walkable(cell):continue
   dry_count+=1
   var center:Vector2=Vector2(cell)*2.5
   var surface:float=surface_height(center.x,center.y)
   max_ground_api_error=maxf(max_ground_api_error,absf(terrain.ground_surface_height(center.x,center.y)-ground_height(center.x,center.y)))
   if under_water(center.x,center.y,surface):dry_failures.append({"cell":str(cell),"y":surface})
   max_mesh_delta=maxf(max_mesh_delta,absf(ground_height(center.x,center.y)-terrain.height_at(center.x,center.y)))
   for id in range(1,18):
    var p:Vector3=projected_position(cell,id)
    var floor_y:float=surface_height(p.x,p.z)
    var clearance:float=p.y-floor_y
    min_clearance=minf(min_clearance,clearance)
    if under_water(p.x,p.z,floor_y):dry_failures.append({"cell":str(cell),"id":id,"xz":str(Vector2(p.x,p.z)),"y":floor_y})
    if clearance < -0.015:foot_penetrations.append({"cell":str(cell),"id":id,"xz":str(Vector2(p.x,p.z)),"y":p.y,"surface":floor_y,"penetration":-clearance})
    if clearance > 0.14:excessive_float.append({"cell":str(cell),"id":id,"xz":str(Vector2(p.x,p.z)),"float":clearance})
   # Inside the nonfaded part of a road tile, not its invisible corner.
   for dx in [-0.9,0.0,0.9]:
    for dz in [-0.9,0.0,0.9]:
     if under_water(center.x+dx,center.y+dz,surface_height(center.x+dx,center.y+dz)):water_edges.append({"cell":str(cell),"dx":dx,"dz":dz})
 check(max_ground_api_error<0.0001,"Ground support API matches actual triangles to within 0.1 mm")
 report.metrics["ground_api_max_error_m"]=max_ground_api_error
 check(dry_failures.is_empty(),"All walkable centers and 17 character offsets have dry support")
 check(foot_penetrations.is_empty(),"Projected character origins never sink more than 1.5 cm into solid surface")
 check(excessive_float.is_empty(),"Projected character origins never float more than 14 cm above support")
 report.metrics["walkable_cells"]=dry_count
 report.metrics["dry_samples"]=dry_count*18
 report.metrics["dry_failures"]=dry_failures
 report.metrics["underwater_road_interior_samples"]=water_edges
 report.metrics["foot_penetrations"]=foot_penetrations
 report.metrics["excessive_float"]=excessive_float
 report.metrics["min_foot_clearance_m"]=min_clearance
 report.metrics["height_function_vs_actual_mesh_max_m"]=max_mesh_delta
 var tree_map:Dictionary={};var extra_tree_cells:Array=[];var vertical_tree_error:float=0.0
 var forest:Node3D=terrain.get_node("OakAndPineForest")
 var kinds:Dictionary={}
 for tree:Node3D in forest.get_children():
  var cell:=Vector2i(roundi(tree.position.x/2.5),roundi(tree.position.z/2.5))
  var kind:String=tree.get_meta("environment_kind","unknown")
  kinds[kind]=kinds.get(kind,0)+1
  if cell.x<1 or cell.y<1 or cell.x>=Sim.WIDTH-1 or cell.y>=Sim.HEIGHT-1:continue
  if not sim.is_terrain_natural(cell):extra_tree_cells.append(str(cell))
  tree_map[cell]=tree_map.get(cell,0)+1
  vertical_tree_error=maxf(vertical_tree_error,absf(tree.position.y-ground_height(tree.position.x,tree.position.z)))
 var missing:Array=[]
 for cell:Vector2i in sim.natural_cells:
  if tree_map.get(cell,0)!=1:missing.append(str(cell))
  check(not sim.is_walkable(cell) and not sim.can_place_road(cell).is_empty(),"Natural cell blocks walking and road "+str(cell))
 check(extra_tree_cells.is_empty() and missing.is_empty(),"One visual obstacle per natural cell and no additional interior trunks")
 report.metrics["natural_cells"]=sim.natural_cells.size();report.metrics["forest_instances"]=forest.get_child_count()
 report.metrics["forest_kinds"]=kinds;report.metrics["missing_nature"]=missing;report.metrics["extra_nature"]=extra_tree_cells;report.metrics["tree_origin_height_max_error_m"]=vertical_tree_error
 var crossing_gaps:Array=[];var samples:int=0
 for row in [13,14,15]:
  for id in range(1,18):
   for x in range(20,26):
    var a:Vector3=projected_position(Vector2i(x,row),id);var b:Vector3=projected_position(Vector2i(x+1,row),id)
    for fraction in range(21):
     var p:Vector3=a.lerp(b,float(fraction)/20.0)
     p.y=terrain.support_height(p.x,p.z)+0.002
     var floor_y:float=surface_height(p.x,p.z);samples+=1
     if p.y<floor_y-0.015:crossing_gaps.append({"cell":str(Vector2i(x,row)),"id":id,"fraction":fraction/20.0,"penetration":floor_y-p.y,"position":str(p)})
 check(crossing_gaps.is_empty(),"Height-corrected walking interpolation crosses bridge without deck penetration")
 report.metrics["bridge_crossing_samples"]=samples;report.metrics["crossing_penetration_count"]=crossing_gaps.size();report.metrics["crossing_penetration_examples"]=crossing_gaps.slice(0,15)
 var road_cells:Array=[]
 for row in [13,14,15]:
  for x in range(20,27):road_cells.append(Vector2i(x,row))
 check(sim.command("road",{"cells":road_cells}).ok,"All audited bank and bridge roads can legally be planned")
 terrain.sync()
 var buried_markers:int=0
 for road:Dictionary in sim.roads:buried_markers+=vertices_below_support(terrain.road_nodes[road.id])
 check(buried_markers==0,"All planned-road marker vertices remain above terrain and bridge")
 report.metrics["buried_marker_vertices"]=buried_markers
 # Geometry fixture only: complete the legal road records. This does not test construction or costs.
 for road:Dictionary in sim.roads:road.stage="complete"
 sim._rebuild_roads();terrain.sync()
 var road_bad:Array=[];var road_float:Array=[]
 var road_face_samples:int=0;var wood_roads:int=0;var masked_margin_nodes:int=0
 for road:Dictionary in sim.roads:
  var node:Node3D=terrain.road_nodes[road.id]
  if node.get_meta("uses_bridge_deck",false):
   wood_roads+=1
   if node.has_node("StoneSurface"):road_bad.append({"cell":str(road.cell),"reason":"Stone still exists over wood"})
   if bridge_height(road.cell.x*2.5,road.cell.y*2.5)<0.12:road_bad.append({"cell":str(road.cell),"reason":"No real wooden support"})
   continue
  if road.cell.x in [21,25]:masked_margin_nodes+=1
  if not node.has_node("StoneSurface"):
   road_bad.append({"cell":str(road.cell),"reason":"Missing bank pavement"});continue
  var tile:MeshInstance3D=node.get_node("StoneSurface")
  var faces:PackedVector3Array=tile.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a:Vector3=tile.global_transform*faces[i];var b:Vector3=tile.global_transform*faces[i+1];var c:Vector3=tile.global_transform*faces[i+2]
   # Actual vertices and centroids, including newly clipped bridge-facing edges.
   for p:Vector3 in [a,b,c,(a+b+c)/3.0]:
    road_face_samples+=1
    var deck:float=bridge_height(p.x,p.z)
    if deck>p.y+0.015:road_bad.append({"cell":str(road.cell),"reason":"Stone below bridge","position":str(p)})
    var gap:float=p.y-ground_height(p.x,p.z)
    if gap<0.007 or gap>0.025:road_float.append({"cell":str(road.cell),"position":str(p),"gap":gap})
    if under_water(p.x,p.z,ground_height(p.x,p.z)):road_bad.append({"cell":str(road.cell),"reason":"Stone above open water","position":str(p)})
 check(road_bad.is_empty() and wood_roads==9 and masked_margin_nodes==6,"All nine bridge roads use timber; bank paving stops before deck and water")
 check(road_float.is_empty() and road_face_samples>100,"Every visible stone vertex/centroid stays 7–25 mm above actual ground")
 report.metrics["roads_below_bridge"]=road_bad;report.metrics["road_float_samples"]=road_float
 report.metrics["bridge_roads_using_wood"]=wood_roads;report.metrics["pavement_geometry_samples"]=road_face_samples
 check(not sim.find_path(Vector2i(21,14),Vector2i(25,14)).is_empty(),"Logical route crosses bridge")
 check(not sim.can_place("house",Vector2i(22,13)).is_empty(),"Buildings cannot be placed on bridge")
 report["success"]=report.failures.is_empty()
 var f:=FileAccess.open("user://terrain-alignment-after-report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("TERRAIN_AUDIT ",JSON.stringify({"checks":report.checks.size(),"failures":report.failures,"walkable":dry_count,"dry_samples":dry_count*18,"feet_below":foot_penetrations.size(),"feet_float":excessive_float.size(),"bridge_motion_below":crossing_gaps.size(),"road_below":road_bad.size(),"road_float":road_float.size(),"river_tile_edges":water_edges.size(),"nature":sim.natural_cells.size(),"height_vs_mesh":max_mesh_delta}))
 world.terrain=null;world.free();terrain.free()
 quit(0 if report.success else 1)
