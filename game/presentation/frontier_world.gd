extends Node3D
## A real, navigable 3D settlement. Civil orders remain entirely in the simulation.
const Models = preload("res://presentation/frontier_models.gd")
const People = preload("res://presentation/frontier_people.gd")
const Terrain = preload("res://presentation/frontier_terrain.gd")
const Basic = preload("res://presentation/model_factory.gd")
const CELL := 2.5
var sim: RefCounted
var camera: Camera3D
var terrain: Node3D
var focus := Vector3(26,0,31)
var target_focus := Vector3(26,0,31)
var yaw := -0.48
var target_yaw := -0.48
var view_size := 30.0
var target_size := 30.0
var visual_speed := 1.0
var buildings := {}
var people := {}
var selection: Node3D
var preview: Node3D
var road_preview: Node3D
var selected_id := -1
var preview_key := ""
var road_key := ""
var terrain_elapsed := 0.0
var elapsed := 0.0
var performance_elapsed := 0.0

func setup(village: RefCounted) -> void:
 sim = village
 _light()
 terrain = Terrain.new();add_child(terrain);terrain.setup(sim)
 camera = Camera3D.new();camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = view_size;camera.near = 0.5;camera.far = 280.0;add_child(camera);camera.make_current()
 selection = Node3D.new();add_child(selection)
 preview = Node3D.new();add_child(preview)
 road_preview = Node3D.new();add_child(road_preview)
 _camera_update(1.0)
 sync(0.0)

func _light() -> void:
 var sun := DirectionalLight3D.new();sun.rotation_degrees = Vector3(-48,-38,0);sun.light_color = Color("ffe2b8");sun.light_energy = 0.85 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.15;sun.shadow_enabled = true
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS;sun.directional_shadow_max_distance = 150;sun.shadow_bias = 0.035;sun.shadow_normal_bias = 0.65;sun.directional_shadow_blend_splits = true;sun.light_angular_distance = 0.65;add_child(sun)
 var environment := WorldEnvironment.new();var env := Environment.new();environment.environment = env
 env.background_mode = Environment.BG_COLOR;env.background_color = Color("b5cbbb")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color = Color("b9d2dc");env.ambient_light_energy = 0.48
 env.tonemap_mode = Environment.TONE_MAPPER_ACES
 env.fog_enabled = true;env.fog_light_color = Color("bac9ad");env.fog_light_energy = 0.5;env.fog_density = 0.00035
 if RenderingServer.get_current_rendering_method() != "gl_compatibility":
  env.ssao_enabled = true;env.ssao_radius = 1.3;env.ssao_intensity = 1.45;env.ssao_power = 1.2;env.ssao_light_affect = 0.12
 add_child(environment)
 get_viewport().msaa_3d = Viewport.MSAA_4X
 if RenderingServer.get_current_rendering_method()!="gl_compatibility":get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func _camera_update(delta: float) -> void:
 var blend := 1.0-exp(-delta*12.0)
 focus = focus.lerp(target_focus,blend);yaw = lerp_angle(yaw,target_yaw,blend);view_size = lerpf(view_size,target_size,blend)
 camera.size = view_size
 camera.position = focus+Vector3(sin(yaw)*65.0,55.0,cos(yaw)*65.0)
 camera.look_at(focus+Vector3(0,1.0,0))

func focus_cell(cell: Vector2i) -> void:
 target_focus = Vector3(cell.x*CELL,0,cell.y*CELL)
func pan_by(pixels: Vector2) -> void:
 var scale_factor := view_size/maxf(1.0,get_viewport().get_visible_rect().size.y)
 var right := camera.global_basis.x;right.y = 0;right = right.normalized()
 var forward := Vector3(-sin(yaw),0,-cos(yaw))
 target_focus += (-right*pixels.x+forward*pixels.y*1.38)*scale_factor
 target_focus.x = clampf(target_focus.x,0,88);target_focus.z = clampf(target_focus.z,0,68)
func zoom_by(amount: float) -> void:
 target_size = clampf(target_size+amount,16,66)
func orbit(amount: float) -> void:
 target_yaw += amount
func world_to_screen(p: Vector3) -> Vector2:
 return camera.unproject_position(p)
func cell_to_screen(cell: Vector2i) -> Vector2:
 return world_to_screen(Vector3(cell.x*CELL,0,cell.y*CELL))
func screen_to_cell(point: Vector2) -> Vector2i:
 var hit: Variant = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
 if hit == null:return Vector2i(-1,-1)
 var c := Vector2i(roundi(hit.x/CELL),roundi(hit.z/CELL))
 return c if c.x>0 and c.x<35 and c.y>0 and c.y<27 else Vector2i(-1,-1)
func building_at_screen(point: Vector2) -> Dictionary:
 var origin := camera.project_ray_origin(point)
 var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*300,2)
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  var id: int = hit.collider.get_meta("building_id",-1)
  for b: Dictionary in sim.buildings:
   if b.id==id and b.stage!="cancelled":return b
 return sim.building_at(screen_to_cell(point))

func sync(delta: float) -> void:
 if camera==null:return
 _camera_update(delta)
 elapsed += delta*visual_speed if not sim.paused else 0.0
 terrain_elapsed += delta
 if terrain_elapsed>=0.2:
  terrain_elapsed = 0.0;terrain.sync()
 var alive := {}
 for b: Dictionary in sim.buildings:
  if b.stage=="cancelled":continue
  alive[b.id]=true
  var stage: String = b.stage
  var phase := 3 if stage=="complete" else (int(float(b.progress)*3.0) if stage=="building" else -1)
  var signature: String = b.kind+str(phase)
  if not buildings.has(b.id) or buildings[b.id].get_meta("signature")!=signature:
   if buildings.has(b.id):buildings[b.id].free()
   var node: Node3D = Models.building(b.kind) if stage=="complete" else _construction(phase,b)
   node.position = Vector3(b.cell.x*CELL+CELL*0.5,0,b.cell.y*CELL+CELL*0.5);node.set_meta("signature",signature);add_child(node);buildings[b.id]=node
   var body := StaticBody3D.new();body.collision_layer=2;body.collision_mask=0;body.set_meta("building_id",b.id);node.add_child(body)
   var collision := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(4.7,5.0 if b.kind!="hall" else 8.5,4.7);collision.shape=box;collision.position.y=box.size.y*0.5;body.add_child(collision)
 for id in buildings.keys():
  if not alive.has(id):buildings[id].free();buildings.erase(id)
 alive.clear()
 for worker: Dictionary in sim.workers:
  alive[worker.id]=true
  if not people.has(worker.id) or people[worker.id].get_meta("role")!=worker.role:
   if people.has(worker.id):people[worker.id].free()
   var actor: Node3D = People.create(worker.role,worker.id);actor.set_meta("role",worker.role);actor.set_meta("cell",worker.cell);actor.position=_person_position(worker.cell,worker.id);actor.set_meta("from",actor.position);actor.set_meta("to",actor.position);actor.set_meta("fraction",1.0);actor.rotation.y=fmod(worker.id*2.399,TAU);add_child(actor);people[worker.id]=actor
  var actor: Node3D = people[worker.id]
  if actor.get_meta("cell")!=worker.cell:
   actor.set_meta("cell",worker.cell);actor.set_meta("from",actor.position);actor.set_meta("to",_person_position(worker.cell,worker.id));actor.set_meta("fraction",0.0)
  var fraction: float = actor.get_meta("fraction")
  if not sim.paused:fraction=minf(1.0,fraction+delta*visual_speed*2.0)
  actor.set_meta("fraction",fraction)
  var from: Vector3=actor.get_meta("from");var to:Vector3=actor.get_meta("to")
  actor.position=from.lerp(to,fraction)
  var direction := to-from
  var walking: bool=fraction<1.0 and direction.length_squared()>0.01
  if walking:actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*visual_speed*14))
  var working: bool=not walking and (worker.state.contains("Constru") or worker.state.contains("Produz") or worker.state.contains("Trabalh") or worker.state.contains("Paviment"))
  People.animate(actor,elapsed*8.0+worker.id*0.83,walking,working,not worker.cargo.is_empty())
 for id in people.keys():
  if not alive.has(id):people[id].free();people.erase(id)
 performance_elapsed+=delta
 if performance_elapsed>10:
  performance_elapsed=0;print("FRONTIER_FRAME: ",Engine.get_frames_per_second(),"fps; workers ",sim.workers.size(),"; roads ",sim.roads.size())

func _person_position(cell:Vector2i,id:int=-1) -> Vector3:
 var height:float=terrain.height_at(cell.x*CELL,cell.y*CELL)
 if cell.x>=22 and cell.x<=24 and cell.y>=13 and cell.y<=15:height=0.13
 return Vector3(cell.x*CELL+sin(id*19.7)*0.38,maxf(0.04,height+0.04),cell.y*CELL+sin(id*13.1)*0.38)

func _construction(phase:int,b:Dictionary) -> Node3D:
 var root:=Node3D.new()
 Basic.box(root,Vector3(4.8,0.11,4.8),Vector3(0,0.015,0),Color("a98f62"))
 for x in [-2.05,2.05]:
  for z in [-2.05,2.05]:Basic.box(root,Vector3(0.13,1.1,0.13),Vector3(x,0.55,z),Color("b08451"))
 for z in [-2.05,2.05]:Basic.box(root,Vector3(4.3,0.15,0.1),Vector3(0,0.82,z),Color("d0b47b"))
 for x in [-2.05,2.05]:Basic.box(root,Vector3(0.1,0.15,4.3),Vector3(x,0.82,0),Color("d0b47b"))
 if phase>=0:
  for x in [-1.65,1.65]:Basic.box(root,Vector3(0.3,0.5+phase*0.7,3.2),Vector3(x,0.25+phase*0.35,0),Color("c6b68d"))
  for z in [-1.5,1.5]:
   for x in [-1.55,1.55]:Basic.box(root,Vector3(0.17,3.8,0.17),Vector3(x,1.9,z),Color("72513b"))
  for z in [-1.5,1.5]:
   Basic.beam(root,Vector3(-1.6,3.5,z),Vector3(0,4.7,z),0.16,Color("94704b"));Basic.beam(root,Vector3(0,4.7,z),Vector3(1.6,3.5,z),0.16,Color("94704b"))
  if phase>=1:
   for y in [1.2,2.4,3.5]:Basic.box(root,Vector3(4.5,0.09,0.5),Vector3(0,y,1.95),Color("ae8955"))
 for i in range(mini(5,int(b.delivered.get("wood",0)))):Basic.box(root,Vector3(1.0,0.16,0.18),Vector3(-1.4,0.13+i*0.15,1.1),Color("aa7c45"))
 Basic.bake(root)
 return root

func _clear(node:Node) -> void:
 for child in node.get_children():child.free()
func _outline(parent:Node3D,center:Vector3,extent:float,color:Color) -> void:
 var mat:=Basic.material(color)
 for axis in [0,1]:
  for side in [-1,1]:
   var line:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(extent*2,0.035,0.045) if axis==0 else Vector3(0.045,0.035,extent*2);line.mesh=mesh;line.material_override=mat;line.position=center+Vector3(0,0.06,side*extent) if axis==0 else center+Vector3(side*extent,0.06,0);parent.add_child(line)
func _entrance(parent:Node3D,cell:Vector2i,color:Color) -> void:
 var center:=Vector3(cell.x*CELL,0.09,cell.y*CELL)
 _outline(parent,center,0.78,color)
 # The arrow points from the road into the front door, not to a unit.
 for sign_value in [-1,1]:Basic.beam(parent,center+Vector3(0,0,-0.55),center+Vector3(sign_value*0.35,0,0),0.08,color)
 Basic.beam(parent,center+Vector3(0,0,0.4),center+Vector3(0,0,-0.55),0.08,color)
func set_selected(id:int) -> void:
 selected_id=id;_clear(selection)
 for b:Dictionary in sim.buildings:
  if b.id==id:
   _outline(selection,Vector3(b.cell.x*CELL+1.25,0,b.cell.y*CELL+1.25),2.55,Color("f3d181"));_entrance(selection,b.entrance,Color("f3d181"))
func clear_preview() -> void:
 preview_key="";road_key="";_clear(preview);_clear(road_preview)
func set_preview(kind:String,cell:Vector2i,valid:bool) -> void:
 var key:=kind+str(cell)+str(valid)
 if key==preview_key:return
 preview_key=key;_clear(preview)
 if cell.x<0:return
 var color:=Color("c9edb0") if valid else Color("ee947f")
 var node:Node3D=Models.building(kind);node.position=Vector3(cell.x*CELL+1.25,0,cell.y*CELL+1.25);preview.add_child(node)
 _ghost(node,color)
 _outline(preview,node.position,2.55,color);_entrance(preview,cell+Vector2i(0,2),color)
func _ghost(node:Node,color:Color) -> void:
 if node is GeometryInstance3D:
  var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color,0.35);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children():_ghost(child,color)
func set_road_preview(cells:Array) -> void:
 var key:=str(cells)
 if road_key==key:return
 road_key=key;_clear(road_preview)
 for cell in cells:
  if cell.x<0:continue
  var valid:bool=sim.can_place_road(cell).is_empty() or sim.has_road(cell) or cell==Vector2i(7,12)
  _outline(road_preview,Vector3(cell.x*CELL,0.10,cell.y*CELL),1.16,Color("e0d7a0") if valid else Color("eb927b"))
 # Every entrance stays legible while the player plans the road network.
 for b:Dictionary in sim.buildings:
  if b.stage!="cancelled":_entrance(road_preview,b.entrance,Color("f4d28a"))
