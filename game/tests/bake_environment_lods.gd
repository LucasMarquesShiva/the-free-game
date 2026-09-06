extends SceneTree
const Models=preload("res://presentation/approved_environment.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var manifest:Array=[]
 for kind:String in ["pine","oak","rock","stump"]:
  for variant in range(6 if kind in ["pine","rock"] else 3):
   var source:ArrayMesh=Models._pine(variant) if kind=="pine" else Models._oak(variant) if kind=="oak" else Models._granite(variant) if kind=="rock" else Models._cut_stump(variant)
   var importer:=ImporterMesh.from_mesh(source);importer.generate_lods(25,60,[])
   var lods:Array=[]
   for i in range(importer.get_surface_lod_count(0)):lods.append({"screen_error":importer.get_surface_lod_size(0,i),"triangles":importer.get_surface_lod_indices(0,i).size()/3})
   var generated:ArrayMesh=importer.get_mesh()
   var arrays:Array=generated.surface_get_arrays(0)
   var lod_map:Dictionary={}
   if kind in ["pine","rock"]:lod_map[0.025]=source.get_meta("silhouette_indices")
   for i in range(importer.get_surface_lod_count(0)):
    var size:float=importer.get_surface_lod_size(0,i)
    if size>=0.25 or not kind in ["pine","rock"]:lod_map[size]=importer.get_surface_lod_indices(0,i)
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lod_map)
   # Shadow pass needs positions only. Weld attribute seams but preserve every
   # actual vertex and the same LOD topology; no cheaper silhouette is faked.
   var unique:Dictionary={};var shadow_vertices:=PackedVector3Array();var remap:=PackedInt32Array()
   for vertex:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    if not unique.has(vertex):unique[vertex]=shadow_vertices.size();shadow_vertices.append(vertex)
    remap.append(unique[vertex])
   var shadow_arrays:Array=[];shadow_arrays.resize(Mesh.ARRAY_MAX);shadow_arrays[Mesh.ARRAY_VERTEX]=shadow_vertices
   var shadow_indices:=PackedInt32Array()
   for index:int in arrays[Mesh.ARRAY_INDEX]:shadow_indices.append(remap[index])
   shadow_arrays[Mesh.ARRAY_INDEX]=shadow_indices
   var shadow_lods:Dictionary={}
   for size:float in lod_map:
    var mapped:=PackedInt32Array()
    for index:int in lod_map[size]:mapped.append(remap[index])
    shadow_lods[size]=mapped
   var shadow:=ArrayMesh.new();shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shadow_arrays,[],shadow_lods);mesh.shadow_mesh=shadow
   lods=[]
   for size:float in lod_map:lods.append({"screen_error":size,"triangles":lod_map[size].size()/3})
   mesh.set_meta("baked_lods",lods)
   var path:String="res://assets/approved/environment-lod/%s-%d.res" % [kind,variant]
   assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
   manifest.append({"kind":kind,"variant":variant,"path":path,"base_triangles":mesh.surface_get_array_index_len(0)/3,"shadow_mesh":mesh.shadow_mesh!=null,"lods":lods,"file_bytes":FileAccess.get_file_as_bytes(path).size()})
 var f:=FileAccess.open("res://assets/approved/environment-lod/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"  "))
 print("ENVIRONMENT_BAKED ",JSON.stringify(manifest));quit()
