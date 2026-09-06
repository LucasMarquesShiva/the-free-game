extends RefCounted
## Public gathering space: paved lanes remain clear for deliveries.
const P=preload("res://presentation/approved_primitives.gd")
const Materials=preload("res://presentation/approved_materials.gd")

static func create(terrain:Node3D, sim:RefCounted)->Node3D:
 var root:=Node3D.new();root.name="PracaDosMoradores"
 var material:=ShaderMaterial.new();material.shader=load("res://assets/approved/plaza.gdshader")
 material.set_shader_parameter("stones",load("res://assets/illustrated/road.png"))
 for cell:Vector2i in sim.plaza_cells():
  var tile:=MeshInstance3D.new();tile.name="PublicPaving_%d_%d"%[cell.x,cell.y]
  var p:=Vector2(cell)*2.5
  tile.mesh=terrain._road_mesh(cell,Rect2(p-Vector2.ONE*1.25,Vector2.ONE*2.5))
  tile.position=Vector3(p.x,0,p.y);tile.material_override=material
  tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(tile)
 # Furniture hugs the outer curb, away from the entrance and gathering slots.
 if sim.plaza_cells().size()==9:
  var batch:=P.Batch.new(90626)
  for x:float in [17.35,22.65]:
   var at:=Vector3(x,terrain.ground_surface_height(x,38.53)+0.02,38.53)
   for leg_x:float in [-0.44,0.44]:
    P._box(batch,at+Vector3(leg_x,0.23,0),Vector3(0.10,0.44,0.28),P.TIMBER,"wood",Vector3.ZERO,true)
    P._box(batch,at+Vector3(leg_x,0.63,0.13),Vector3(0.085,0.77,0.08),P.TIMBER,"wood",Vector3.ZERO,true)
   for slat_z:float in [-0.10,0,0.10]:
    P._box(batch,at+Vector3(0,0.47,slat_z),Vector3(1.30,0.07,0.086),P.WOOD,"wood",Vector3.ZERO,true)
   for slat_y:float in [0.73,0.92]:
    P._box(batch,at+Vector3(0,slat_y,0.14),Vector3(1.31,0.15,0.055),P.WOOD,"wood",Vector3.ZERO,true)
  for x:float in [16.57,23.43]:
   for z:float in [31.57,38.43]:
    var at:=Vector3(x,terrain.ground_surface_height(x,z)+0.11,z)
    P._cylinder(batch,at,0.19,0.20,P.STONE,"stone")
    P._ellipsoid(batch,at+Vector3.UP*0.20,Vector3(0.24,0.23,0.24),Color("698347"),"foliage")
    for i in range(5):
     var phase:float=i*TAU/5
     P._ellipsoid(batch,at+Vector3(cos(phase)*0.13,0.34,sin(phase)*0.13),Vector3(0.055,0.045,0.055),Color("e1b261") if i%2 else Color("e5d9ae"),"foliage")
  var props:=P._instantiate(P._finish(batch),"BenchesAndFlowers");Materials.apply(props);root.add_child(props)
 return root
