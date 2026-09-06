extends Node3D
## A real, navigable 3D settlement. Civil orders remain entirely in the simulation.
const Models = preload("res://presentation/approved_buildings.gd")
const People = preload("res://presentation/approved_people.gd")
const Terrain = preload("res://presentation/approved_terrain.gd")
const Basic = preload("res://presentation/model_factory.gd")
const Materials=preload("res://presentation/approved_materials.gd")
const CropGrowth=preload("res://presentation/approved_crop_growth.gd")
const CELL := 2.5
var sim: RefCounted
var camera: Camera3D
var terrain: Node3D
var focus := Vector3(28,0,33)
var target_focus := Vector3(28,0,33)
var yaw := 0.48
var target_yaw := 0.48
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
var detail_cursor:=0

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
 var sun := DirectionalLight3D.new();sun.rotation_degrees = Vector3(-48,-38,0);sun.light_color = Color("fff0d7");sun.light_energy = 0.85 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.06;sun.shadow_enabled = true
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance = 150;sun.shadow_bias = 0.035;sun.shadow_normal_bias = 0.22;sun.directional_shadow_blend_splits = false;sun.light_angular_distance = 0.0;sun.shadow_blur=1.0;add_child(sun)
 var environment := WorldEnvironment.new();var env := Environment.new();environment.environment = env
 env.background_mode = Environment.BG_COLOR;env.background_color = Color("b5cbbb")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color = Color("b9d2dc");env.ambient_light_energy = 0.36
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.fog_enabled = true;env.fog_light_color = Color("bac9ad");env.fog_light_energy = 0.5;env.fog_density = 0.00035
 if RenderingServer.get_current_rendering_method() != "gl_compatibility":
  env.ssao_enabled = true;env.ssao_radius = 1.3;env.ssao_intensity = 1.45;env.ssao_power = 1.2;env.ssao_light_affect = 0.12
 add_child(environment)
 get_viewport().msaa_3d = Viewport.MSAA_2X
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
 var detail_tier:=0 if view_size<20 else (2 if view_size>48 else 1)
 var detail_index:=0
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
   if stage=="complete" and b.kind=="farm":CropGrowth.install(node)
   if stage=="complete":Materials.apply(node)
   _add_clearing(node,b.kind)
   node.position = _building_center(b.cell,b.kind);node.set_meta("signature",signature);add_child(node);buildings[b.id]=node
   var body := StaticBody3D.new();body.collision_layer=2;body.collision_mask=0;body.set_meta("building_id",b.id);node.add_child(body)
   var collision := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(sim.footprint_size(b.kind).x*CELL-0.15,6.4 if b.kind!="hall" else 8.5,sim.footprint_size(b.kind).y*CELL-0.15);collision.shape=box;collision.position.y=box.size.y*0.5;body.add_child(collision)
  if stage!="complete":_update_supplies(buildings[b.id],b)
  elif b.kind=="farm":CropGrowth.sync(buildings[b.id],sim.crop_status(b),delta)
 for id in buildings.keys():
  if not alive.has(id):buildings[id].free();buildings.erase(id)
 alive.clear()
 for worker: Dictionary in sim.workers:
  alive[worker.id]=true
  if not people.has(worker.id) or people[worker.id].get_meta("role")!=worker.role:
   if people.has(worker.id):people[worker.id].free()
   var actor: Node3D = People.create(worker.role,worker.id,1);actor.set_meta("ground_height",Callable(terrain,"support_height"));actor.set_meta("role",worker.role);actor.set_meta("cell",worker.cell);actor.position=_person_position(worker.cell,worker.id);actor.set_meta("from",actor.position);actor.set_meta("to",actor.position);actor.set_meta("fraction",1.0);actor.rotation.y=fmod(worker.id*2.399,TAU);add_child(actor);people[worker.id]=actor
  var actor: Node3D = people[worker.id]
  if actor.get_meta("cell")!=worker.cell:
   var heading:Vector2i=worker.cell-actor.get_meta("cell")
   actor.set_meta("cell",worker.cell);actor.set_meta("from",actor.position);actor.set_meta("to",_person_position(worker.cell,worker.id,heading));actor.set_meta("fraction",0.0)
  var fraction: float = actor.get_meta("fraction")
  if not sim.paused:fraction=minf(1.0,fraction+delta*visual_speed/(sim.MOVEMENT_STEP_TICKS*0.1))
  actor.set_meta("fraction",fraction)
  var from: Vector3=actor.get_meta("from");var to:Vector3=actor.get_meta("to")
  var old_position:Vector3=actor.position
  actor.position=from.lerp(to,fraction)
  actor.position.y=terrain.support_height(actor.position.x,actor.position.z)+0.002
  var direction := to-from
  var continuing:bool=not worker.route.is_empty() and int(worker.get("wait",0))==0
  var walking: bool=(fraction<1.0 or continuing) and direction.length_squared()>0.01
  if walking:actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*visual_speed*14))
  var working: bool=not walking and (worker.state.contains("Constru") or worker.state.contains("Produz") or worker.state.contains("Trabalh") or worker.state.contains("Paviment") or worker.state.contains("Prepar") or worker.state.contains("Ensin"))
  if detail_index==detail_cursor:People.set_quality(actor,detail_tier)
  detail_index+=1
  var gait_phase:float=actor.get_meta("gait_phase",worker.id*0.83)
  if walking:gait_phase+=Vector2(actor.position.x-old_position.x,actor.position.z-old_position.z).length()*(6.8 if not worker.cargo.is_empty() else 5.6)
  actor.set_meta("gait_phase",gait_phase)
  People.animate(actor,gait_phase if walking else elapsed*8.0+worker.id*0.83,walking,working,not worker.cargo.is_empty(),worker.cargo.get("item","wood"))
 detail_cursor=(detail_cursor+1)%maxi(1,sim.workers.size())
 for id in people.keys():
  if not alive.has(id):people[id].free();people.erase(id)
 performance_elapsed+=delta
 if performance_elapsed>10:
  performance_elapsed=0;print("FRONTIER_FRAME: ",Engine.get_frames_per_second(),"fps; workers ",sim.workers.size(),"; roads ",sim.roads.size())

func _person_position(cell:Vector2i,id:int=-1,heading:Vector2i=Vector2i.ZERO) -> Vector3:
 var offset:=Vector2(sin(id*19.7),sin(id*13.1))*0.26
 if heading!=Vector2i.ZERO:
  var direction:=Vector2(heading).normalized()
  offset=Vector2(-direction.y,direction.x)*0.42
 var person:Dictionary=sim._worker(id)
 if not person.is_empty() and person.task.is_empty() and person.cargo.is_empty() and cell==sim.plaza_rest_cell(person):
  offset=sim.plaza_rest_offset(person)
 var x:float=cell.x*CELL+offset.x
 var z:float=cell.y*CELL+offset.y
 if x>51.6 and x<63.4 and cell.y>=13 and cell.y<=15:
  z=clampf(z,32.30,37.70)
 return Vector3(x,terrain.support_height(x,z)+0.002,z)

func _construction(phase:int,b:Dictionary) -> Node3D:
 var root:=Node3D.new()
 var height:=5.0
 if phase>=0:
  var building:Node3D=Models.building(b.kind)
  if b.kind=="farm":CropGrowth.strip_static_crops(building)
  if building.has_node("Architecture"):
   height=building.get_node("Architecture").get_aabb().end.y
  Materials.apply(building,maxf(0.5,height*(phase+1)/3.5))
  root.add_child(building)
 var scaffold:=Node3D.new();root.add_child(scaffold)
 var half:float=sim.footprint_size(b.kind).x*CELL*0.5-0.28
 var level:=0.60 if phase<0 else minf(height-0.2,3.8)
 var oak:=Color("8a653f")
 for x in [-half,half]:
  for z in [-half,half]:Basic.cylinder(scaffold,0.06,level,Vector3(x,level*0.5,z),oak,-1,9)
 for z in [-half,half]:
  for h in ([0.43] if phase<0 else [0.8,1.8,2.8]):
   if h>level:continue
   Basic.beam(scaffold,Vector3(-half,h,z),Vector3(half,h,z),0.028 if phase<0 else 0.095,Color("c8ae79") if phase<0 else oak)
   if phase>=0:
    for plank in range(3):Basic.box(scaffold,Vector3(half*2+0.15,0.065,0.15),Vector3(0,h-0.1,z+(plank-1)*0.17),Color("b59362").darkened(plank*0.04))
  if phase>=0:
   Basic.beam(scaffold,Vector3(-half,0.35,z),Vector3(half,level-0.15,z),0.075,oak)
 if phase<0:
  for x in [-half,half]:Basic.beam(scaffold,Vector3(x,0.43,-half),Vector3(x,0.43,half),0.028,Color("c8ae79"))
 if phase>=0:
  for x in [-half,half]:
   for h in [0.8,1.8]:
    if h<level:Basic.beam(scaffold,Vector3(x,h,-half),Vector3(x,h,half),0.09,oak)
  var ladder_x:float=half-0.35
  for x in [ladder_x-0.16,ladder_x+0.16]:Basic.beam(scaffold,Vector3(x,0,half+0.2),Vector3(x,minf(3.0,level),half-0.35),0.06,Color("a88353"))
  for i in range(10):
   var t:=i/10.0
   Basic.beam(scaffold,Vector3(ladder_x-0.17,t*minf(3.0,level),lerpf(half+0.2,half-0.35,t)),Vector3(ladder_x+0.17,t*minf(3.0,level),lerpf(half+0.2,half-0.35,t)),0.05,Color("ba9868"))
 Basic.bake(scaffold)
 return root

func _update_supplies(building:Node3D,state:Dictionary)->void:
 var wood:=mini(8,int(state.delivered.get("wood",0)))
 var stone:=mini(8,int(state.delivered.get("stone",0)))
 var signature:=Vector2i(wood,stone)
 if building.get_meta("supplies",Vector2i(-1,-1))==signature:return
 building.set_meta("supplies",signature)
 if building.has_node("Supplies"):building.get_node("Supplies").free()
 var piles:=Node3D.new();piles.name="Supplies";building.add_child(piles)
 var half:float=sim.footprint_size(state.kind).x*CELL*0.5-0.28
 for i in range(wood):
  Basic.box(piles,Vector3(1.15,0.10,0.18),Vector3(-half+0.74,0.3+(i/3)*0.12,half-0.38+(i%3)*0.19),Color("ad8553").darkened((i%3)*0.03))
 for i in range(stone):
  var rock:=Basic.cylinder(piles,0.16,0.18,Vector3(half-0.56+(i%2)*0.25,0.29+(i/4)*0.17,half-0.45+((i/2)%2)*0.23),Color("929181").darkened((i%3)*0.04),0.12,6)
  rock.rotation.y=i*1.73
 Basic.bake(piles)

func _add_clearing(node:Node3D,kind:String)->void:
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new()
 var size:Vector2i=sim.footprint_size(kind)
 plane.size=Vector2(size.x*CELL+1.65,size.y*CELL+1.65)
 ground.mesh=plane;ground.position.y=0.007
 ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=load("res://assets/approved/clearing.gdshader")
 material.set_shader_parameter("earth_tex",load("res://assets/approved/earth-albedo.png"))
 ground.material_override=material;node.add_child(ground)

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
   _outline(selection,_building_center(b.cell,b.kind),sim.footprint_size(b.kind).x*CELL*0.5+0.05,Color("f3d181"));_entrance(selection,b.entrance,Color("f3d181"))
func clear_preview() -> void:
 preview_key="";road_key="";_clear(preview);_clear(road_preview)
func set_preview(kind:String,cell:Vector2i,valid:bool) -> void:
 var key:=kind+str(cell)+str(valid)
 if key==preview_key:return
 preview_key=key;_clear(preview)
 if cell.x<0:return
 var color:=Color("c9edb0") if valid else Color("ee947f")
 var node:Node3D=Models.building(kind);node.position=_building_center(cell,kind);preview.add_child(node)
 _ghost(node,color)
 _outline(preview,node.position,sim.footprint_size(kind).x*CELL*0.5+0.05,color);_entrance(preview,cell+Vector2i((sim.footprint_size(kind).x-1)/2,sim.footprint_size(kind).y),color)
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
  var valid:bool=sim.can_place_road(cell).is_empty() or sim.has_road(cell) or cell==Vector2i(8,13)
  _outline(road_preview,Vector3(cell.x*CELL,0.10,cell.y*CELL),1.16,Color("e0d7a0") if valid else Color("eb927b"))
 # Every entrance stays legible while the player plans the road network.
 for b:Dictionary in sim.buildings:
  if b.stage!="cancelled":_entrance(road_preview,b.entrance,Color("f4d28a"))

func set_road_removal_preview(cell:Vector2i) -> void:
 var exists:bool=not sim.road_at(cell).is_empty()
 var key:="erase"+str(cell)+str(exists)
 if road_key==key:return
 road_key=key;_clear(road_preview)
 if exists:
  var position:=Vector3(cell.x*CELL,0.12,cell.y*CELL)
  position.y=terrain.support_height(position.x,position.z)+0.10
  _outline(road_preview,position,1.16,Color("f07869"))

func _building_center(cell:Vector2i,kind:String)->Vector3:
 var footprint:Vector2i=sim.footprint_size(kind)
 return Vector3((cell.x+(footprint.x-1)*0.5)*CELL,0,(cell.y+(footprint.y-1)*0.5)*CELL)
