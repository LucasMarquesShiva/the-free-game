extends RefCounted
## Material swatches derived from the approved catalog. Atlas stays intact on disk.
static var _materials:Dictionary={}
static var _meshes:Dictionary={}
static var _atlas:Texture2D
static func _filtered_atlas()->Texture2D:
 if _atlas==null:_atlas=load("res://assets/approved/material-atlas.png")
 return _atlas
static func material(key:String,cutoff:float=1000.0) -> Material:
 var cache_key:=key+str(cutoff)
 if _materials.has(cache_key):return _materials[cache_key]
 var m:=ShaderMaterial.new();m.shader=load("res://assets/approved/catalog-material.gdshader")
 m.set_shader_parameter("material_atlas",_filtered_atlas())
 m.set_shader_parameter("cutoff_height",cutoff)
 match key:
  "stone":
   m.set_shader_parameter("pigment_depth",0.80)
   m.set_shader_parameter("quadrant",Vector2(0,0));m.set_shader_parameter("texture_scale",Vector2(0.70,0.70))
   m.set_shader_parameter("brightness",1.02);m.set_shader_parameter("detail_strength",0.65);m.set_shader_parameter("chroma_strength",0.30)
   m.set_shader_parameter("surface_roughness",0.94);m.set_shader_parameter("roughness_variation",0.09);m.set_shader_parameter("bump_height",0.035)
  "wood":
   m.set_shader_parameter("pigment_depth",0.87);m.set_shader_parameter("warm_pigments_only",true)
   # Faixa estreita do atlas: veios longos, sem fingir várias tábuas por viga.
   m.set_shader_parameter("quadrant",Vector2(0.5,0));m.set_shader_parameter("texture_scale",Vector2(0.22,0.90))
   m.set_shader_parameter("brightness",1.0);m.set_shader_parameter("detail_strength",0.62);m.set_shader_parameter("chroma_strength",0.22)
   m.set_shader_parameter("surface_roughness",0.83);m.set_shader_parameter("roughness_variation",0.10);m.set_shader_parameter("bump_height",0.018)
  "roof":
   m.set_shader_parameter("quadrant",Vector2(0,0.5));m.set_shader_parameter("texture_scale",Vector2(0.50,0.50))
   m.set_shader_parameter("brightness",0.99);m.set_shader_parameter("detail_strength",0.74);m.set_shader_parameter("chroma_strength",0.44)
   m.set_shader_parameter("surface_roughness",0.86);m.set_shader_parameter("roughness_variation",0.10);m.set_shader_parameter("bump_height",0.026)
  "cloth":
   m.set_shader_parameter("quadrant",Vector2(0.5,0.5));m.set_shader_parameter("texture_scale",Vector2(0.75,0.75))
   m.set_shader_parameter("surface_roughness",0.98);m.set_shader_parameter("detail_strength",0.10);m.set_shader_parameter("bump_height",0.003)
 _materials[cache_key]=m
 return m
static func apply(root:Node,cutoff:float=1000.0) -> void:
 if root is MeshInstance3D and root.mesh is ArrayMesh:
  var source:ArrayMesh=root.mesh
  var id:=str(source.get_instance_id())+str(cutoff)
  if not _meshes.has(id):
   var copy:ArrayMesh=source.duplicate()
   for i in range(copy.get_surface_count()):
    var key:String=copy.surface_get_name(i)
    if cutoff<999 or key in ["stone","wood","roof","cloth"]:copy.surface_set_material(i,material(key,cutoff))
   _meshes[id]=copy
  root.mesh=_meshes[id]
 if root is MultiMeshInstance3D and str(root.name).contains("RoofTiles"):
  root.material_override=material("roof",cutoff)
 for child in root.get_children():apply(child,cutoff)
