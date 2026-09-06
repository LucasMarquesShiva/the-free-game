extends Node3D
## Small opaque wildflower clumps. Their shared meshes follow land clearing.
const Flower=preload("res://presentation/approved_bank_ambience.gd")
const CELL:=2.5
const RADIUS:=0.30
var terrain:Node3D
var batches:Array[MultiMesh]=[]
var placements:Array[Dictionary]=[]

func setup(land:Node3D)->void:
 terrain=land;name="MeadowWildflowers"
 var random:=RandomNumberGenerator.new();random.seed=620719
 var pattern:=FastNoiseLite.new();pattern.seed=27081;pattern.frequency=0.20
 var material:=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1.0;material.metallic_specular=0.04
 for kind in range(2):
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var geometry_rng:=RandomNumberGenerator.new();geometry_rng.seed=9073+kind*173
  Flower._flower(st,Vector3.ZERO,geometry_rng,kind==1)
  for i in range(6):
   var angle:float=i*2.399963
   var direction:=Vector3(cos(angle),0,sin(angle))
   var side:=Vector3(-direction.z,0,direction.x)
   var start:=Vector3.UP*0.07
   var middle:=start+direction*0.09+Vector3.UP*0.018
   var tip:=start+direction*0.17-Vector3.UP*0.025
   Flower._tri(st,start,middle-side*0.024,tip,Color("596f34"))
   Flower._tri(st,start,tip,middle+side*0.024,Color("788a45"))
  var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=st.commit();multi.instance_count=120
  var instance:=MultiMeshInstance3D.new();instance.name="IvoryFlowers" if kind==0 else "Buttercups"
  instance.multimesh=multi;instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance);batches.append(multi)
  for index in range(multi.instance_count):
   var point:=Vector2.ZERO
   for attempt in range(90):
    point=Vector2(random.randf_range(-7.0,95.0),random.randf_range(-6.0,76.0))
    if absf(point.x-57.5)<5.0:continue
    if pattern.get_noise_2d(point.x,point.y)< -0.04:continue
    break
   var scale_value:float=random.randf_range(0.56,0.94)
   var location:=Vector3(point.x,terrain.ground_surface_height(point.x,point.y)+0.004,point.y)
   var transform:=Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*scale_value),location)
   multi.set_instance_transform(index,transform)
   placements.append({"batch":kind,"index":index,"transform":transform,"cell":Vector2i(roundi(point.x/CELL),roundi(point.y/CELL))})

func sync_occupancy(occupied:Dictionary)->void:
 for record:Dictionary in placements:
  var transform:Transform3D=record.transform
  var point:=Vector2(transform.origin.x,transform.origin.z)
  var hidden:=false
  for offset:Vector2 in [Vector2.ZERO,Vector2(-RADIUS,-RADIUS),Vector2(-RADIUS,RADIUS),Vector2(RADIUS,-RADIUS),Vector2(RADIUS,RADIUS)]:
   var cell:=Vector2i(roundi((point.x+offset.x)/CELL),roundi((point.y+offset.y)/CELL))
   if occupied.has(cell) or (cell.x>=22 and cell.x<=24):hidden=true;break
  if hidden:transform.origin.y=-10.0
  batches[record.batch].set_instance_transform(record.index,transform)
