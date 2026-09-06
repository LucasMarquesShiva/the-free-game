extends Node3D
const Basic=preload("res://presentation/model_factory.gd")
const Models=preload("res://presentation/frontier_models.gd")
const CELL:=2.5
var sim: RefCounted
var roads: Node3D
var details: MultiMeshInstance3D
var road_nodes:={}
var rng:=RandomNumberGenerator.new()
var material_road:StandardMaterial3D
var terrain_noise:=FastNoiseLite.new()
var tufts: Array[Vector3]=[]
var last_land_signature:=""

func height_at(x:float,z:float)->float:
 var border:=maxf(maxf(-x,x-88.0),maxf(-z,z-68.0))
 var hills:=smoothstep(-2.0,15.0,border)*(1.5+terrain_noise.get_noise_2d(x*1.3,z*1.3)*4.5)
 var river_center:=58.75+sin(z*0.065)*0.55
 var bank:=1.0-smoothstep(2.6,5.5,absf(x-river_center))
 return hills-bank*1.4

func setup(village:RefCounted)->void:
 sim=village;rng.seed=913760
 terrain_noise.seed=32;terrain_noise.frequency=0.032
 _ground();_water();_forest();_meadow();_bridge()
 roads=Node3D.new();add_child(roads)
 material_road=StandardMaterial3D.new();material_road.albedo_color=Color("d0bd92");material_road.roughness=0.96
 material_road.albedo_texture=load("res://assets/illustrated/road.png")
 material_road.uv1_scale=Vector3(0.48,0.48,0.48)
 sync()

func _ground()->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var stride:=1.8
 for zi in range(71):
  for xi in range(80):
   var x:float=-27+xi*stride;var z:float=-27+zi*stride
   var pts:=[Vector3(x,height_at(x,z),z),Vector3(x+stride,height_at(x+stride,z),z),Vector3(x+stride,height_at(x+stride,z+stride),z+stride),Vector3(x,height_at(x,z+stride),z+stride)]
   for id in [0,1,2,0,2,3]:
    st.set_uv(Vector2(pts[id].x,pts[id].z)*0.1);st.add_vertex(pts[id])
 st.generate_normals();st.generate_tangents()
 var m:=MeshInstance3D.new();m.mesh=st.commit()
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/frontier/terrain.gdshader");mat.set_shader_parameter("detail_tex",load("res://assets/illustrated/grass_v2.png"));m.material_override=mat;add_child(m)

func _water()->void:
 var m:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(7.3,155);plane.subdivide_depth=70;plane.subdivide_width=5;m.mesh=plane;m.position=Vector3(58.75,-0.85,38)
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/frontier/water.gdshader");m.material_override=mat;add_child(m)
 var banks:=Node3D.new();add_child(banks)
 for i in range(100):
  var z:=rng.randf_range(-18,94);var x:=54.6 if i%2==0 else 62.4
  if absf(z-35)<5.5:continue
  var rock:=Models.rock(i);rock.position=Vector3(x+rng.randf_range(-0.3,0.3),height_at(x,z)-0.08,z);rock.scale=Vector3.ONE*rng.randf_range(0.22,0.52);banks.add_child(rock)

func _forest()->void:
 var forest:=Node3D.new();forest.name="OakAndPineForest";add_child(forest)
 for i in range(175):
  var x:=rng.randf_range(-19,107);var z:=rng.randf_range(-18,88)
  var outside:bool=x<1 or x>88 or z<0 or z>68
  if not outside:continue
  if absf(x-58.75)<5.8:continue
  var tree:Node3D=Models.tree(i);forest.add_child(tree);tree.position=Vector3(x,height_at(x,z),z);tree.rotation.y=rng.randf()*TAU;tree.scale=Vector3.ONE*rng.randf_range(0.8,1.4)
 for cell:Vector2i in sim.natural_cells:
  var tree:Node3D=Models.tree(cell.x*71+cell.y*97)
  forest.add_child(tree)
  tree.position=Vector3(cell.x*CELL+rng.randf_range(-0.24,0.24),height_at(cell.x*CELL,cell.y*CELL),cell.y*CELL+rng.randf_range(-0.24,0.24))
  tree.rotation.y=rng.randf()*TAU;tree.scale=Vector3.ONE*rng.randf_range(0.78,1.12)
 for i in range(36):
  var x:=rng.randf_range(-10,96);var z:=rng.randf_range(-9,80)
  if x>1 and x<88 and z>1 and z<68:continue
  if absf(x-58.75)<5:continue
  var rock:Node3D=Models.rock(i+500);add_child(rock);rock.position=Vector3(x,height_at(x,z),z);rock.scale=Vector3.ONE*rng.randf_range(0.3,0.9)

func _meadow()->void:
 var mesh:=ArrayMesh.new();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for angle in [0.0,1.05,2.1]:
  var dx:=cos(angle)*0.065;var dz:=sin(angle)*0.065
  for p in [Vector3(-dx,0,-dz),Vector3(dx,0,dz),Vector3(dx*0.7,0.16,dz*0.7)]:st.set_normal(Vector3.UP);st.add_vertex(p)
 mesh=st.commit()
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("749048");mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1.0
 var shader:=Shader.new();shader.code="shader_type spatial; render_mode cull_disabled; varying vec4 tint; void vertex(){tint=COLOR; vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.x+=sin(TIME*1.5+w.x*0.9+w.z*0.7)*VERTEX.y*0.12;} void fragment(){vec3 c=tint.rgb*vec3(0.38,0.51,0.19); ALBEDO=OUTPUT_IS_SRGB ? c : pow(c,vec3(2.2));ROUGHNESS=1.0;}"
 var grass_mat:=ShaderMaterial.new();grass_mat.shader=shader
 details=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh;multi.instance_count=24000
 for i in range(24000):
  var p:=Vector3(rng.randf_range(-9,98),0,rng.randf_range(-8,78));p.y=height_at(p.x,p.z)+0.005;tufts.append(p)
  var s:=rng.randf_range(0.65,1.5);multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*s),p));multi.set_instance_color(i,Color(0.85+s*0.1,0.86+s*0.08,0.9,1))
 details.multimesh=multi;details.material_override=grass_mat;details.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(details)
 # Small flower heads catch the afternoon light, grouped into only a few draw calls.
 for group in range(2):
  var sphere:=SphereMesh.new();sphere.radius=0.04;sphere.height=0.05;sphere.radial_segments=5;sphere.rings=3
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=sphere;mm.instance_count=380
  for i in range(380):
   var p:Vector3=tufts[(i*13+group*53)%tufts.size()];p.y+=0.11
   mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
  var mi:=MultiMeshInstance3D.new();mi.multimesh=mm;mi.material_override=Basic.material(Color("f1d47a") if group==0 else Color("e7e0b9"));mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mi)

func _bridge()->void:
 var root:=Node3D.new();add_child(root)
 for i in range(26):
  Basic.box(root,Vector3(0.35,0.19,6.4),Vector3(54.0+i*0.36,0.025,35),Color("ac8452").lightened((i%4)*0.025))
 for z in [31.9,38.1]:
  for x in [54.0,56.1,58.2,60.3,63.0]:Basic.box(root,Vector3(0.16,1.25,0.16),Vector3(x,0.65,z),Color("795336"))
  for y in [0.5,1.1]:Basic.box(root,Vector3(9.1,0.12,0.12),Vector3(58.5,y,z),Color("9a7549"))
 Basic.bake(root)

func _blocked_detail(cell:Vector2i)->bool:
 if not sim.building_at(cell).is_empty():return true
 if sim.has_road(cell):return true
 return cell.x>=22 and cell.x<=24

func sync()->void:
 var sig:=str(sim.buildings.size())+str(sim.roads.size())
 var alive:={}
 for road:Dictionary in sim.roads:
  if road.stage=="cancelled":continue
  var signature:String=str(road.stage)
  var neighbors:=Vector4(1 if sim.has_road(road.cell+Vector2i.LEFT) else 0,1 if sim.has_road(road.cell+Vector2i.RIGHT) else 0,1 if sim.has_road(road.cell+Vector2i.UP) else 0,1 if sim.has_road(road.cell+Vector2i.DOWN) else 0)
  if road.stage=="complete":signature+=str(neighbors)
  sig+=signature
  alive[road.id]=true
  if road_nodes.has(road.id) and road_nodes[road.id].get_meta("stage")==signature:continue
  if road_nodes.has(road.id):road_nodes[road.id].free()
  var node:=Node3D.new();node.set_meta("stage",signature);roads.add_child(node);node.position=Vector3(road.cell.x*CELL,0.015,road.cell.y*CELL)
  if road.stage=="complete":
   var tile:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(CELL,CELL);tile.mesh=mesh;var road_mat:=ShaderMaterial.new();road_mat.shader=load("res://assets/frontier/road.gdshader");road_mat.set_shader_parameter("stones",load("res://assets/illustrated/road.png"));road_mat.set_shader_parameter("connections",neighbors);tile.material_override=road_mat;tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(tile)
   var edging:=Node3D.new();node.add_child(edging)
   for i in range(4):
    var marker:=Basic.box(edging,Vector3(0.11,0.07,0.27),Vector3((i%2*2-1)*1.13,0.02,(i/2*2-1)*0.78),Color("a99a77"));marker.rotation.y=0.12*(i-2)
   Basic.bake(edging)
  else:
   for x in [-0.85,0.85]:
    for z in [-0.85,0.85]:Basic.cylinder(node,0.035,0.28,Vector3(x,0.15,z),Color("cdb379"),-1,6)
   Basic.bake(node)
  road_nodes[road.id]=node
 for id in road_nodes.keys():
  if not alive.has(id):road_nodes[id].free();road_nodes.erase(id)
 if sig!=last_land_signature:
  last_land_signature=sig
  var occupied:Dictionary={}
  for b:Dictionary in sim.buildings:
   if b.stage=="cancelled":continue
   for x in range(2):
    for z in range(2):occupied[b.cell+Vector2i(x,z)]=true
  for r:Dictionary in sim.roads:
   if r.stage!="cancelled":occupied[r.cell]=true
  for i in range(tufts.size()):
   var p:Vector3=tufts[i];var cell:=Vector2i(roundi(p.x/CELL),roundi(p.z/CELL));var hidden:bool=occupied.has(cell) or (cell.x>=22 and cell.x<=24)
   var t:Transform3D=details.multimesh.get_instance_transform(i)
   t.origin.y=-10 if hidden else p.y
   details.multimesh.set_instance_transform(i,t)
