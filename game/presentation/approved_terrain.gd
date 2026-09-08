extends Node3D
const Basic=preload("res://presentation/model_factory.gd")
const Models=preload("res://presentation/approved_environment.gd")
const Broadleaf=preload("res://presentation/approved_broadleaf.gd")
const RiverRocks=preload("res://presentation/approved_river_rocks.gd")
const Architecture=preload("res://presentation/approved_primitives.gd")
const HarvestMap=preload("res://simulation/harvest_map.gd")
const CELL:=2.5
const GROUND_ORIGIN:=-27.0
const GROUND_STRIDE:=1.2
const GROUND_COLUMNS:=120
const GROUND_ROWS:=107
# A continuous walking envelope covers tiny gaps/bevels between physical planks.
# Deck boxes are centered at y=.035 with height=.20; the walkable top is .135.
const BRIDGE_TOP:=0.135
const BRIDGE_DECK:=Rect2(52.65,31.80,9.70,6.40)
# Stop stone paving before the capstones as well as the wooden deck.
const BRIDGE_ROAD_LEFT:=52.54
const BRIDGE_ROAD_RIGHT:=62.46
const ROAD_OFFSET:=0.015
var _ground_heights:=PackedFloat32Array()
var sim: RefCounted
var plaza: Node3D
var roads: Node3D
var details: Node3D
const GRASS_CHUNK_SIZE:=12.0
var grass_chunks:Array[MultiMeshInstance3D]=[]
var grass_slots:Array[Vector2i]=[]
var meadow_flowers:Node3D
var road_nodes:={}
var rng:=RandomNumberGenerator.new()
var material_road:StandardMaterial3D
var terrain_noise:=FastNoiseLite.new()
var tufts: Array[Vector3]=[]
var last_land_signature:=""
var bank_cluster_sites:Array[Dictionary]=[]
var bank_rock_bounds:Array[AABB]=[]
var harvest_map:RefCounted
var grove_nodes:={}
var grove_forest:Node3D
var last_harvest_revision:=-1

func height_at(x:float,z:float)->float:
 var border:=maxf(maxf(-x,x-88.0),maxf(-z,z-68.0))
 var hills:=smoothstep(-2.0,15.0,border)*(1.5+terrain_noise.get_noise_2d(x*1.3,z*1.3)*4.5)
 var river_center:=57.5+sin(z*0.065)*0.3+sin(z*0.31)*0.13
 var half:=2.22+sin(z*0.17)*0.25+sin(z*0.47)*0.12
 var bank:=1.0-smoothstep(half,half+2.0,absf(x-river_center))
 return hills-bank*1.4


func ground_surface_height(x:float,z:float)->float:
 # Use the exact same samples and diagonal as the rendered ArrayMesh.
 if _ground_heights.is_empty():return height_at(x,z)
 var gx:float=(x-GROUND_ORIGIN)/GROUND_STRIDE
 var gz:float=(z-GROUND_ORIGIN)/GROUND_STRIDE
 if gx<0 or gx>GROUND_COLUMNS or gz<0 or gz>GROUND_ROWS:return height_at(x,z)
 var ix:int=mini(floori(gx),GROUND_COLUMNS-1)
 var iz:int=mini(floori(gz),GROUND_ROWS-1)
 var tx:float=gx-ix;var tz:float=gz-iz
 var a:float=_ground_heights[iz*(GROUND_COLUMNS+1)+ix]
 var b:float=_ground_heights[iz*(GROUND_COLUMNS+1)+ix+1]
 var c:float=_ground_heights[(iz+1)*(GROUND_COLUMNS+1)+ix+1]
 var d:float=_ground_heights[(iz+1)*(GROUND_COLUMNS+1)+ix]
 return a+(b-a)*tx+(c-b)*tz if tx>=tz else a+(c-d)*tx+(d-a)*tz

func support_height(x:float,z:float)->float:
 ## Shared presentation contract. Caller adds its model's foot clearance.
 var ground:float=ground_surface_height(x,z)
 if sim!=null:
  var cell:=Vector2i(roundi(x/CELL),roundi(z/CELL))
  if sim.is_plaza_cell(cell):ground+=ROAD_OFFSET
  elif sim.has_road(cell) or (cell==sim.HUB and road_nodes.has(-1)):
   var paved:Rect2=_road_rectangle(cell)
   if paved.has_point(Vector2(x,z)):ground+=ROAD_OFFSET
 if BRIDGE_DECK.has_point(Vector2(x,z)):return maxf(ground,BRIDGE_TOP)
 # Stone caps extend slightly past each end of the timber. The 2cm envelope
 # includes their bevel; characters do not step through these approach pieces.
 for pier_x in [53.0,62.0]:
  for pier_z in [32.25,37.75]:
   if absf(x-pier_x)<=0.445 and absf(z-pier_z)<=0.47:return maxf(ground,0.09)
 return ground

func setup(village:RefCounted)->void:
 sim=village;harvest_map=_bind_harvest();rng.seed=913760
 terrain_noise.seed=32;terrain_noise.frequency=0.032
 _ground();_water();_forest();_meadow();_bridge()
 add_child(preload("res://presentation/approved_bank_ambience.gd").create(self))
 plaza=preload("res://presentation/approved_plaza.gd").create(self,sim);add_child(plaza)
 roads=Node3D.new();add_child(roads)
 material_road=StandardMaterial3D.new();material_road.albedo_color=Color("d0bd92");material_road.roughness=0.96
 material_road.albedo_texture=load("res://assets/illustrated/road.png")
 material_road.uv1_scale=Vector3(0.48,0.48,0.48)
 sync()

func _ground()->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 _ground_heights.resize((GROUND_COLUMNS+1)*(GROUND_ROWS+1))
 for zi in range(GROUND_ROWS+1):
  for xi in range(GROUND_COLUMNS+1):
   _ground_heights[zi*(GROUND_COLUMNS+1)+xi]=height_at(GROUND_ORIGIN+xi*GROUND_STRIDE,GROUND_ORIGIN+zi*GROUND_STRIDE)
 for zi in range(GROUND_ROWS):
  for xi in range(GROUND_COLUMNS):
   var x:float=GROUND_ORIGIN+xi*GROUND_STRIDE;var z:float=GROUND_ORIGIN+zi*GROUND_STRIDE
   var index:int=zi*(GROUND_COLUMNS+1)+xi
   var pts:=[Vector3(x,_ground_heights[index],z),Vector3(x+GROUND_STRIDE,_ground_heights[index+1],z),Vector3(x+GROUND_STRIDE,_ground_heights[index+GROUND_COLUMNS+2],z+GROUND_STRIDE),Vector3(x,_ground_heights[index+GROUND_COLUMNS+1],z+GROUND_STRIDE)]
   for id in [0,1,2,0,2,3]:
    st.set_uv(Vector2(pts[id].x,pts[id].z)*0.1);st.add_vertex(pts[id])
 st.generate_normals();st.generate_tangents()
 var m:=MeshInstance3D.new();m.mesh=st.commit()
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/approved/terrain.gdshader");mat.set_shader_parameter("meadow_tex",load("res://assets/approved/meadow-albedo.png"));mat.set_shader_parameter("earth_tex",load("res://assets/approved/earth-albedo.png"));m.material_override=mat;add_child(m)

func _water()->void:
 var m:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(9.2,155);plane.subdivide_depth=70;plane.subdivide_width=5;m.mesh=plane;m.position=Vector3(57.5,-0.85,38)
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/approved/water.gdshader");mat.set_shader_parameter("water_tex",load("res://assets/approved/water-albedo.png"));m.material_override=mat;add_child(m)
 var banks:=Node3D.new();add_child(banks)
 for i in range(100):
  var z:=rng.randf_range(-18,94);var center:=57.5+sin(z*0.065)*0.3+sin(z*0.31)*0.13;var bank_width:=3.2+sin(z*0.17)*0.25+sin(z*0.47)*0.12;var x:=center-bank_width if i%2==0 else center+bank_width
  if absf(z-35)<5.5:continue
  # Consume the same random values so all existing trees/meadow placements stay fixed.
  var jitter:float=rng.randf_range(-0.3,0.3);var scale_value:float=rng.randf_range(0.22,0.52)
  var rock:=RiverRocks.rock(i)
  if not _shape_bank_rock(rock,x+jitter,z,scale_value):rock.free();continue
  banks.add_child(rock)
 _compose_bank_rocks(banks)


func _shape_bank_rock(rock:Node3D,x:float,z:float,scale_value:float)->bool:
 # Broad, low granite at the water line; no new meshes or shadow surfaces.
 var bounds:AABB=rock.get_meta("bounds")
 rock.scale=Vector3(scale_value*0.98,scale_value*0.48,scale_value*1.72)
 var lo:Vector3=bounds.position*rock.scale;var hi:Vector3=bounds.end*rock.scale
 # All visible rock geometry stays inside the nonwalkable river strip.
 # The bridge plus both approach rows remain entirely clear.
 if z+hi.z>28.75 and z+lo.z<41.25:return false
 x=clampf(x,53.79-lo.x,61.21-hi.x)
 rock.position=Vector3(x,ground_surface_height(x,z)-0.10,z)
 rock.set_meta("bank_rock",true)
 return true


func _bank_bounds(rock:Node3D)->AABB:
 var original:AABB=rock.get_meta("bounds")
 var result:=AABB(rock.transform*original.position,Vector3.ZERO)
 for corner:int in range(8):
  var point:Vector3=original.position+original.size*Vector3(1.0 if corner&1 else 0.0,1.0 if corner&2 else 0.0,1.0 if corner&4 else 0.0)
  result=result.expand(rock.transform*point)
 return result

func _compose_bank_rocks(banks:Node3D)->void:
 # Reuse exactly the existing meshes. A private RNG preserves all village/forest seeds.
 var composition:=RandomNumberGenerator.new();composition.seed=402718
 bank_cluster_sites.clear();bank_rock_bounds.clear();banks.name="GroupedRiverBanks"
 var west:Array=[-13.0,-4.0,5.8,12.0,21.5,26.6,44.5,52.8,61.8,71.5,82.5,92.0]
 var east:Array=[-11.0,-1.5,8.5,17.0,24.5,46.7,57.0,65.5,77.5,88.0]
 for side:int in [-1,1]:
  for z_value:float in (west if side<0 else east):
   bank_cluster_sites.append({"side":side,"z":z_value+composition.randf_range(-0.32,0.32)})
 var offsets:Array[float]=[0.0,-1.12,1.02,0.36]
 var aspects:Array[float]=[1.04,1.18,0.91,1.26]
 var heights:Array[float]=[0.559,0.56,0.63,0.72]
 for index:int in range(banks.get_child_count()):
  var rock:Node3D=banks.get_child(index)
  var group:Dictionary=bank_cluster_sites[mini(index/4,bank_cluster_sites.size()-1)]
  var side:int=group.side;var slot:int=index%4
  var z:float=group.z+offsets[slot]+composition.randf_range(-0.20,0.20)
  var center:float=57.5+sin(z*0.065)*0.3+sin(z*0.31)*0.13
  var shore:float=center+side*(3.2+sin(z*0.17)*0.25+sin(z*0.47)*0.12)
  var scale_value:float=composition.randf_range(0.52,0.64) if slot==0 else composition.randf_range(0.29,0.43)
  rock.position=Vector3.ZERO;rock.rotation.y=composition.randf_range(-PI,PI)
  rock.scale=Vector3(scale_value,scale_value*heights[slot],scale_value*aspects[slot])
  var bounds:AABB=_bank_bounds(rock)
  # Fit the rotated full envelope inside one blocked shore band, leaving open water.
  var min_x:float=53.79 if side<0 else 58.87
  var max_x:float=56.13 if side<0 else 61.21
  var shrink:float=minf(1.0,(max_x-min_x)/maxf(bounds.size.x,0.001))
  rock.scale.x*=shrink;rock.scale.z*=shrink;bounds=_bank_bounds(rock)
  var inward:float=0.28 if slot==0 else (0.68 if slot==3 else composition.randf_range(-0.08,0.12))
  var x:float=clampf(shore-side*inward,min_x-bounds.position.x,max_x-bounds.end.x)
  if group.z<35.0:z=minf(z,28.70-bounds.end.z)
  else:z=maxf(z,41.30-bounds.position.z)
  rock.position=Vector3(x,ground_surface_height(x,z)-0.085,z)
  # Preserve the real lower mesh point when shortening the dominant rock by 35%.
  if slot==0:
   var local_bounds:AABB=rock.get_meta("bounds")
   rock.position.y+=local_bounds.position.y*scale_value*(0.86-heights[0])
  rock.set_meta("bank_group",mini(index/4,bank_cluster_sites.size()-1));rock.set_meta("bank_side",side)
  bank_rock_bounds.append(_bank_bounds(rock))
 banks.set_meta("clusters",bank_cluster_sites.size())

func _bind_harvest()->RefCounted:
 var existing:Variant=sim.get("harvest_map") if sim!=null else null
 if existing!=null:return existing
 var map:=HarvestMap.new()
 if sim!=null:map.setup_from_natural_cells(sim.natural_cells)
 return map

func _grove_visual(cell:Vector2i)->Node3D:
 var seed:=cell.x*71+cell.y*97
 if harvest_map!=null and harvest_map.is_harvested(cell):return Models.stump(seed)
 return Broadleaf.tree(seed)

func _sync_grove_harvest()->void:
 if grove_forest==null:return
 var existing:Variant=sim.get("harvest_map") if sim!=null else null
 if existing!=null and existing!=harvest_map:
  harvest_map=existing;last_harvest_revision=-1
 if harvest_map==null:return
 if harvest_map.revision==last_harvest_revision:return
 last_harvest_revision=harvest_map.revision
 for cell:Vector2i in grove_nodes:
  var node:Node3D=grove_nodes[cell]
  var harvested:bool=harvest_map.is_harvested(cell)
  if harvested==(node.get_meta("environment_kind","")=="stump"):continue
  var replacement:Node3D=_grove_visual(cell)
  replacement.position=node.position;replacement.rotation=node.rotation;replacement.scale=node.scale
  grove_forest.add_child(replacement);node.free();grove_nodes[cell]=replacement

func _forest()->void:
 var forest:=Node3D.new();forest.name="OakAndPineForest";add_child(forest)
 grove_forest=forest;grove_nodes.clear();last_harvest_revision=-1
 for i in range(175):
  var x:=rng.randf_range(-19,107);var z:=rng.randf_range(-18,88)
  var outside:bool=x<1 or x>88 or z<0 or z>68
  if not outside:continue
  if absf(x-57.5)<5.1:continue
  var tree:Node3D=Broadleaf.tree(i);forest.add_child(tree);tree.position=Vector3(x,height_at(x,z),z);tree.rotation.y=rng.randf()*TAU;tree.scale=Vector3.ONE*rng.randf_range(0.8,1.4)
 for cell:Vector2i in sim.natural_cells:
  var tree:Node3D=_grove_visual(cell)
  forest.add_child(tree)
  tree.position=Vector3(cell.x*CELL+rng.randf_range(-0.24,0.24),height_at(cell.x*CELL,cell.y*CELL),cell.y*CELL+rng.randf_range(-0.24,0.24))
  tree.rotation.y=rng.randf()*TAU;tree.scale=Vector3.ONE*rng.randf_range(0.78,1.12)
  grove_nodes[cell]=tree
 last_harvest_revision=harvest_map.revision if harvest_map!=null else 0
 for i in range(36):
  var x:=rng.randf_range(-10,96);var z:=rng.randf_range(-9,80)
  if x>1 and x<88 and z>1 and z<68:continue
  if absf(x-57.5)<5:continue
  var rock:Node3D=Models.rock(i+500);add_child(rock);rock.position=Vector3(x,height_at(x,z),z);rock.scale=Vector3.ONE*rng.randf_range(0.3,0.9)

func _meadow()->void:
 var mesh:=ArrayMesh.new();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for blade in range(6):
  var angle:=blade*2.39996
  var right:=Vector3(cos(angle),0,sin(angle))*0.017
  var base:=Vector3(sin(angle*3.0),0,cos(angle*3.0))*0.025
  var middle:=base+Vector3(sin(angle)*0.024,0.085+float(blade%3)*0.008,cos(angle)*0.024)
  var tip:=base+Vector3(sin(angle)*0.07,0.14+float(blade%3)*0.021,cos(angle)*0.07)
  var points:=[base-right,base+right,middle+right*0.52,base-right,middle+right*0.52,middle-right*0.52,middle-right*0.52,middle+right*0.52,tip]
  for point:Vector3 in points:
   st.set_color(Color(0.86,0.91,0.75).lerp(Color(1.04,1.02,0.95),point.y/0.19));st.set_normal(Vector3.UP);st.add_vertex(point)
 mesh=st.commit()
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("749048");mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1.0
 var shader:=Shader.new();shader.code="shader_type spatial; render_mode cull_disabled; varying vec4 tint; void vertex(){tint=COLOR; vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.x+=sin(TIME*1.5+w.x*0.9+w.z*0.7)*VERTEX.y*0.12;} void fragment(){vec3 c=tint.rgb*vec3(0.31,0.43,0.18); ALBEDO=OUTPUT_IS_SRGB ? c : pow(c,vec3(2.2));ROUGHNESS=1.0;}"
 var grass_mat:=ShaderMaterial.new();grass_mat.shader=shader
 # Small spatial batches can be culled independently. Positions, scale,
 # color, animation and random-number order match the original 24k meadow.
 details=Node3D.new();details.name="MeadowChunks";add_child(details)
 var buckets:Dictionary={};grass_slots.resize(24000)
 for i in range(24000):
  var p:=Vector3(rng.randf_range(-9,98),0,rng.randf_range(-8,78));p.y=height_at(p.x,p.z)+0.005;tufts.append(p)
  var s:=rng.randf_range(0.65,1.5)
  var t:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*s),p)
  var key:=Vector2i(floori(p.x/GRASS_CHUNK_SIZE),floori(p.z/GRASS_CHUNK_SIZE))
  if not buckets.has(key):buckets[key]=[]
  buckets[key].append({"index":i,"transform":t,"color":Color(0.85+s*0.1,0.86+s*0.08,0.9,1)})
 for key:Vector2i in buckets:
  var records:Array=buckets[key]
  var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh;multi.instance_count=records.size()
  var chunk:=MultiMeshInstance3D.new();chunk.name="Grass_%d_%d" % [key.x,key.y];chunk.multimesh=multi;chunk.material_override=grass_mat;chunk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;details.add_child(chunk)
  # A fixed tight AABB excludes the buried hidden instances without making
  # the renderer recompute bounds after every road-construction update.
  var bounds:=AABB(Vector3(key.x*GRASS_CHUNK_SIZE,-3,key.y*GRASS_CHUNK_SIZE),Vector3(GRASS_CHUNK_SIZE,12,GRASS_CHUNK_SIZE)).grow(0.25)
  multi.custom_aabb=bounds
  var chunk_index:int=grass_chunks.size();grass_chunks.append(chunk)
  for local_index in range(records.size()):
   var record:Dictionary=records[local_index]
   multi.set_instance_transform(local_index,record.transform);multi.set_instance_color(local_index,record.color)
   grass_slots[record.index]=Vector2i(chunk_index,local_index)
 meadow_flowers=preload("res://presentation/approved_meadow_flowers.gd").new()
 add_child(meadow_flowers);meadow_flowers.setup(self)

func _bridge()->void:
 var b:=Architecture.Batch.new(8271)
 var oak:=Color("795331");var plank_color:=Color("9b7747")
 Architecture._box(b,Vector3(57.5,0.09,35),Vector3(9.70,0.06,6.40),Color("60432b"),"wood",Vector3.ZERO,false)
 for i in range(31):
  var x:=52.82+i*0.312
  Architecture._box(b,Vector3(x,0.035,35),Vector3(0.302,0.20,6.40),b.shade(plank_color,0.12),"wood",Vector3(0,0,b.rng.randf_range(-0.012,0.012)),true)
  for z in [32.06,37.94]:
   Architecture._cylinder(b,Vector3(x,0.141,z),0.021,0.007,Color("514a38"),"metal",Vector3.ZERO,false)
 for z in [31.90,38.10]:
  for x in [52.85,55.15,57.45,59.75,62.1]:
   Architecture._box(b,Vector3(x,0.61,z),Vector3(0.16,1.22,0.17),oak,"wood",Vector3.ZERO,true)
   Architecture._box(b,Vector3(x,1.22,z),Vector3(0.22,0.08,0.22),Color("906c3f"),"wood",Vector3.ZERO,true)
  for y in [0.48,1.10]:Architecture._beam(b,Vector3(52.8,y,z),Vector3(62.18,y,z),0.115,oak,"wood")
  for x in [54.0,57.5,61.0]:
   Architecture._beam(b,Vector3(x-0.65,-0.50,z),Vector3(x+0.65,0,z),0.19,oak,"wood")
 for x in [53.0,62.0]:
  for z in [32.25,37.75]:
   Architecture._box(b,Vector3(x,-0.4,z),Vector3(0.75,0.9,0.8),Color("75756a"),"stone",Vector3.ZERO,true)
   Architecture._box(b,Vector3(x,0.035,z),Vector3(0.85,0.11,0.9),Color("979487"),"stone",Vector3.ZERO,true)
 var materials:Dictionary={}
 for key in Architecture.MATERIAL_KEYS:materials[key]=Architecture._material(key)
 var asset:Dictionary=b.finish(materials,Architecture._roof_tile())
 var index:=0
 for key in Architecture.MATERIAL_KEYS:
  if b.surfaces.has(key) and not b.surfaces[key].vertices.is_empty():asset.mesh.surface_set_name(index,key);index+=1
 var root:Node3D=Architecture._instantiate(asset,"OakBridge")
 preload("res://presentation/approved_materials.gd").apply(root)
 add_child(root)

func _blocked_detail(cell:Vector2i)->bool:
 if not sim.building_at(cell).is_empty():return true
 if sim.has_road(cell):return true
 return cell.x>=22 and cell.x<=24


func _road_rectangle(cell:Vector2i)->Rect2:
 var rect:=Rect2(Vector2(cell)*CELL-Vector2.ONE*CELL*0.5,Vector2.ONE*CELL)
 if cell.y>=13 and cell.y<=15:
  if cell.x>=22 and cell.x<=24:return Rect2()
  if cell.x==21:rect.size.x=maxf(0.0,BRIDGE_ROAD_LEFT-rect.position.x)
  if cell.x==25:
   var right:float=rect.end.x
   rect.position.x=BRIDGE_ROAD_RIGHT;rect.size.x=maxf(0.0,right-rect.position.x)
 return rect

func _clip_polygon(points:Array[Vector2],axis:int,limit:float,keep_greater:bool)->Array[Vector2]:
 var result:Array[Vector2]=[]
 if points.is_empty():return result
 var previous:Vector2=points[-1]
 var previous_inside:bool=previous[axis]>=limit if keep_greater else previous[axis]<=limit
 for current:Vector2 in points:
  var inside:bool=current[axis]>=limit if keep_greater else current[axis]<=limit
  if inside!=previous_inside:
   var t:float=(limit-previous[axis])/(current[axis]-previous[axis])
   result.append(previous.lerp(current,t))
  if inside:result.append(current)
  previous=current;previous_inside=inside
 return result

func _road_mesh(cell:Vector2i,rect:Rect2)->ArrayMesh:
 # Clip the ground triangles themselves. Every road face remains parallel to
 # its supporting ground face, including along the curved river bank.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var min_x:int=floori((rect.position.x-GROUND_ORIGIN)/GROUND_STRIDE)
 var max_x:int=floori((rect.end.x-GROUND_ORIGIN)/GROUND_STRIDE)
 var min_z:int=floori((rect.position.y-GROUND_ORIGIN)/GROUND_STRIDE)
 var max_z:int=floori((rect.end.y-GROUND_ORIGIN)/GROUND_STRIDE)
 var center:=Vector2(cell)*CELL
 for zi in range(min_z,max_z+1):
  for xi in range(min_x,max_x+1):
   var a:=Vector2(GROUND_ORIGIN+xi*GROUND_STRIDE,GROUND_ORIGIN+zi*GROUND_STRIDE)
   var b:=a+Vector2(GROUND_STRIDE,0);var c:=a+Vector2.ONE*GROUND_STRIDE;var d:=a+Vector2(0,GROUND_STRIDE)
   for face in [[a,b,c],[a,c,d]]:
    var poly:Array[Vector2]=[];poly.assign(face)
    poly=_clip_polygon(poly,0,rect.position.x,true);poly=_clip_polygon(poly,0,rect.end.x,false)
    poly=_clip_polygon(poly,1,rect.position.y,true);poly=_clip_polygon(poly,1,rect.end.y,false)
    if poly.size()<3:continue
    for i in range(1,poly.size()-1):
     var p0:Vector2=poly[0];var p1:Vector2=poly[i];var p2:Vector2=poly[i+1]
     if absf((p1-p0).cross(p2-p0))<0.000001:continue
     for p:Vector2 in [p0,p1,p2]:
      st.set_uv((p-center)/CELL+Vector2.ONE*0.5)
      st.add_vertex(Vector3(p.x-center.x,ground_surface_height(p.x,p.y)+ROAD_OFFSET,p.y-center.y))
 st.generate_normals();st.generate_tangents()
 return st.commit()

func _build_road_visual(node:Node3D,road:Dictionary,neighbors:Vector4)->void:
 var center:=Vector2(road.cell)*CELL
 node.position=Vector3(center.x,0,center.y)
 var rect:Rect2=_road_rectangle(road.cell)
 var bridge_only:bool=rect.size.x<=0 or rect.size.y<=0
 node.set_meta("uses_bridge_deck",bridge_only)
 if road.stage=="complete":
  if bridge_only:return # Existing timber is the visible completed crossing.
  var tile:=MeshInstance3D.new();tile.name="StoneSurface";tile.mesh=_road_mesh(road.cell,rect)
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/approved/road.gdshader");mat.set_shader_parameter("stones",load("res://assets/illustrated/road.png"));mat.set_shader_parameter("earth_tex",load("res://assets/approved/earth-albedo.png"));mat.set_shader_parameter("connections",neighbors);tile.material_override=mat
  tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(tile)
  var edging:=Node3D.new();node.add_child(edging)
  for i in range(4):
   var x:float=(i%2*2-1)*1.13;var z:float=(i/2*2-1)*0.78
   var p:=center+Vector2(x,z)
   if not rect.grow(-0.06).has_point(p):continue
   var marker:=Basic.box(edging,Vector3(0.11,0.07,0.27),Vector3(x,ground_surface_height(p.x,p.y)+0.035,z),Color("a99a77"));marker.rotation.y=0.12*(i-2)
  Basic.bake(edging)
 else:
  if int(road.get("delivered",0))>0 or road.stage=="building":
   var supplies:=Node3D.new();supplies.name="DeliveredRoadStone";node.add_child(supplies)
   for index in range(5):
    var local:=Vector3(0.60+(index%2)*0.21,0,-0.57+((index/2)%2)*0.22)
    var at:=center+Vector2(local.x,local.z)
    local.y=support_height(at.x,at.y)+0.10+(index/4)*0.14
    var stone:=Basic.cylinder(supplies,0.13,0.15,local,Color("aba78f").darkened((index%3)*0.055),0.10,6)
    stone.rotation.y=index*1.71
   Basic.bake(supplies)
  if road.stage=="cancelled":return
  var progress:float=float(road.get("progress",0))
  if progress>0.02 and not bridge_only:
   var laid:=MeshInstance3D.new();laid.name="PavingInProgress"
   var patch:=rect;patch.size.x*=maxf(0.18,ceilf(progress*4.0)/4.0)
   laid.mesh=_road_mesh(road.cell,patch)
   var mat:=ShaderMaterial.new();mat.shader=load("res://assets/approved/road.gdshader")
   mat.set_shader_parameter("stones",load("res://assets/illustrated/road.png"));mat.set_shader_parameter("earth_tex",load("res://assets/approved/earth-albedo.png"));mat.set_shader_parameter("connections",Vector4.ONE)
   laid.material_override=mat;laid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(laid)
  var markers:=Node3D.new();markers.name="RoadSurveyMarkers";node.add_child(markers)
  for x in [-0.85,0.85]:
   for z in [-0.85,0.85]:
    var p:=center+Vector2(x,z)
    if p.x>=BRIDGE_DECK.position.x and p.x<=BRIDGE_DECK.end.x and road.cell.y>=13 and road.cell.y<=15:p.y=clampf(p.y,BRIDGE_DECK.position.y+0.35,BRIDGE_DECK.end.y-0.35)
    var marker:=Basic.cylinder(markers,0.035,0.28,Vector3(p.x-center.x,support_height(p.x,p.y)+0.15,p.y-center.y),Color("cdb379"),-1,6)
    marker.set_meta("road_marker",true)
  Basic.bake(markers)

func sync()->void:
 _sync_grove_harvest()
 var sig:=str(sim.buildings.size())+str(sim.roads.size())
 for building:Dictionary in sim.buildings:sig+=str(building.stage=="cancelled")
 var alive:={}
 var origin_visible:=false
 for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if sim.has_road(sim.HUB+direction):origin_visible=true
 var road_visuals:Array=sim.roads.duplicate()
 if origin_visible and not sim.is_plaza_cell(sim.HUB):road_visuals.append({"id":-1,"cell":sim.HUB,"stage":"complete"})
 for road:Dictionary in road_visuals:
  if (road.stage=="cancelled" and int(road.get("delivered",0))==0) or sim.is_plaza_cell(road.cell):continue
  var signature:String=str(road.stage)
  if road.stage!="complete":signature+="/%d/%d"%[int(road.get("delivered",0)),ceili(float(road.get("progress",0))*4)]
  var neighbors:=Vector4(1 if (sim.has_road(road.cell+Vector2i.LEFT) or road.cell+Vector2i.LEFT==sim.HUB) else 0,1 if (sim.has_road(road.cell+Vector2i.RIGHT) or road.cell+Vector2i.RIGHT==sim.HUB) else 0,1 if (sim.has_road(road.cell+Vector2i.UP) or road.cell+Vector2i.UP==sim.HUB) else 0,1 if (sim.has_road(road.cell+Vector2i.DOWN) or road.cell+Vector2i.DOWN==sim.HUB) else 0)
  if road.stage=="complete":signature+=str(neighbors)
  sig+=str(road.stage)
  alive[road.id]=true
  if road_nodes.has(road.id) and road_nodes[road.id].get_meta("stage")==signature:continue
  if road_nodes.has(road.id):road_nodes[road.id].free()
  var node:=Node3D.new();node.set_meta("stage",signature);roads.add_child(node)
  _build_road_visual(node,road,neighbors)
  road_nodes[road.id]=node
 for id in road_nodes.keys():
  if not alive.has(id):road_nodes[id].free();road_nodes.erase(id)
 if sig!=last_land_signature:
  last_land_signature=sig
  var occupied:Dictionary={}
  for cell:Vector2i in sim.plaza_cells():occupied[cell]=true
  if origin_visible:occupied[sim.HUB]=true
  for b:Dictionary in sim.buildings:
   if b.stage=="cancelled":continue
   for cell:Vector2i in sim.building_footprint(b):occupied[cell]=true
  for r:Dictionary in sim.roads:
   if r.stage!="cancelled":occupied[r.cell]=true
  meadow_flowers.sync_occupancy(occupied)
  for i in range(tufts.size()):
   var p:Vector3=tufts[i];var cell:=Vector2i(roundi(p.x/CELL),roundi(p.z/CELL));var hidden:bool=occupied.has(cell) or (cell.x>=22 and cell.x<=24)
   var slot:Vector2i=grass_slots[i]
   var multi:MultiMesh=grass_chunks[slot.x].multimesh
   var t:Transform3D=multi.get_instance_transform(slot.y)
   t.origin.y=-10 if hidden else p.y
   multi.set_instance_transform(slot.y,t)
