extends SceneTree
const Original=preload("res://tests/original_environment.gd")
const Optimized=preload("res://presentation/approved_environment.gd")
const OldTerrain=preload("res://tests/original_terrain.gd")
const Terrain=preload("res://presentation/approved_terrain.gd")
const Sim=preload("res://simulation/approved_sim.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func original_mesh(kind:String,variant:int)->ArrayMesh:
 match kind:
  "pine":return Original._pine(variant)
  "oak":return Original._oak(variant)
  "stump":return Original._cut_stump(variant)
 return Original._granite(variant)
func clean_indices(arrays:Array)->PackedInt32Array:
 var clean:=PackedInt32Array();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,indices.size(),3):
  var a:Vector3=vertices[indices[i]];var b:Vector3=vertices[indices[i+1]];var c:Vector3=vertices[indices[i+2]]
  if (b-a).cross(c-a).length_squared()<0.000000000001:continue
  clean.append(indices[i]);clean.append(indices[i+1]);clean.append(indices[i+2])
 return clean
func indexed_bounds(vertices:PackedVector3Array,indices:PackedInt32Array)->AABB:
 var bounds:=AABB(vertices[indices[0]],Vector3.ZERO)
 for i:int in indices:bounds=bounds.expand(vertices[i])
 return bounds
func run()->void:
 var removed:int=0;var shadow_vertex_reduction:int=0
 for kind:String in ["pine","oak","rock","stump"]:
  for variant in range(6 if kind in ["pine","rock"] else 3):
   var before:ArrayMesh=original_mesh(kind,variant);var after:ArrayMesh=Optimized._mesh_for(kind,variant)
   var a:Array=before.surface_get_arrays(0);var b:Array=after.surface_get_arrays(0)
   var label:String=kind+str(variant)
   check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX],label+" keeps every original vertex exactly")
   check(a[Mesh.ARRAY_COLOR]==b[Mesh.ARRAY_COLOR],label+" keeps original vertex palette")
   check(clean_indices(a)==b[Mesh.ARRAY_INDEX],label+" full detail differs only by zero-area triangles")
   removed+=(a[Mesh.ARRAY_INDEX].size()-b[Mesh.ARRAY_INDEX].size())/3
   check(before.get_aabb().is_equal_approx(after.get_aabb()),label+" bounds unchanged")
   check(after.shadow_mesh!=null,label+" has position-only shadow geometry")
   if after.shadow_mesh!=null:
    var shadow:Array=after.shadow_mesh.surface_get_arrays(0)
    var indices:PackedInt32Array=b[Mesh.ARRAY_INDEX];var shadow_indices:PackedInt32Array=shadow[Mesh.ARRAY_INDEX]
    var positions:PackedVector3Array=b[Mesh.ARRAY_VERTEX];var shadow_positions:PackedVector3Array=shadow[Mesh.ARRAY_VERTEX]
    var equal:bool=indices.size()==shadow_indices.size()
    if equal:
     for i in range(indices.size()):
      if positions[indices[i]]!=shadow_positions[shadow_indices[i]]:equal=false;break
    check(equal,label+" shadow triangles have exactly the original positions")
    shadow_vertex_reduction+=positions.size()-shadow_positions.size()
   var importer:=ImporterMesh.from_mesh(after)
   check(importer.get_surface_lod_count(0)>0,label+" baked LODs survived resource serialization")
   if kind in ["pine","rock"]:
    var first:PackedInt32Array=importer.get_surface_lod_indices(0,0)
    var lod_bounds:AABB=indexed_bounds(b[Mesh.ARRAY_VERTEX],first)
    check(lod_bounds.is_equal_approx(indexed_bounds(b[Mesh.ARRAY_VERTEX],b[Mesh.ARRAY_INDEX])),label+" first LOD keeps silhouette extrema")
    check(first.size()<b[Mesh.ARRAY_INDEX].size(),label+" first LOD removes interior microdetail")
 var old_sim:=Sim.new();old_sim.setup();var new_sim:=Sim.new();new_sim.setup()
 var snapshot:Dictionary=new_sim.snapshot()
 var old:=OldTerrain.new();root.add_child(old);old.setup(old_sim)
 var current:=Terrain.new();root.add_child(current);current.setup(new_sim)
 check(new_sim.snapshot()==snapshot,"Terrain optimization never mutates simulation")
 check(old.tufts==current.tufts,"All 24,000 grass positions unchanged")
 check(current.grass_slots.size()==24000,"Every tuft has a chunk slot")
 check(current.grass_chunks.size()>1 and current.grass_chunks.size()<100,"Grass uses bounded spatial chunks")
 var exact_transforms:bool=true;var exact_colors:bool=true;var slots:Dictionary={};var total:int=0
 for chunk:MultiMeshInstance3D in current.grass_chunks:
  total+=chunk.multimesh.instance_count
  check(chunk.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Chunk keeps grass shadows disabled")
  check(chunk.multimesh.custom_aabb.size.x<=12.51,"Chunk visibility bounds remain spatially tight")
 for i in range(24000):
  var slot:Vector2i=current.grass_slots[i];slots[slot]=true
  var multi:MultiMesh=current.grass_chunks[slot.x].multimesh
  if old.details.multimesh.get_instance_transform(i)!=multi.get_instance_transform(slot.y):exact_transforms=false
  if old.details.multimesh.get_instance_color(i)!=multi.get_instance_color(slot.y):exact_colors=false
 check(total==24000 and slots.size()==24000,"Chunk assignment is bijective, no missing or duplicate grass")
 check(exact_transforms,"Grass scale, rotation and hidden state exactly preserved")
 check(exact_colors,"Grass instance colors exactly preserved")
 for s in [old_sim,new_sim]:
  check(s.command("road",{"cells":[Vector2i(9,13),Vector2i(10,13)]}).ok,"Road fixture remains legal")
  for road:Dictionary in s.roads:road.stage="complete"
  s._rebuild_roads()
 old.sync();current.sync()
 var masks:bool=true
 for i in range(24000):
  var slot:Vector2i=current.grass_slots[i]
  if old.details.multimesh.get_instance_transform(i).origin.y!=current.grass_chunks[slot.x].multimesh.get_instance_transform(slot.y).origin.y:masks=false
 check(masks,"Road/building grass hiding preserved after updates")
 print("ENVIRONMENT_OPT_TEST ",JSON.stringify({"checks":checks,"failures":failures,"removed_degenerate_unique_triangles":removed,"shadow_unique_vertices_saved":shadow_vertex_reduction,"grass_chunks":current.grass_chunks.size(),"grass_instances":total}))
 old.free();current.free();quit(0 if failures.is_empty() else 1)
