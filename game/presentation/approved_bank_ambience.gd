extends RefCounted
## Optional shoreline accents. One opaque surface, no shadows, physics or process.
## Root may add create(terrain) as a child after the terrain has been set up.
const CELL:=2.5
const WATER_MAX:=-0.81
const PATCH_Z:=[5.0,11.5,18.5,25.0,44.0,50.5,58.0,64.5]
const SAFE_RADIUS:=0.34

static func create(terrain:Node3D,seed_value:int=704193)->Node3D:
 var root:=Node3D.new();root.name="ShorelineFlowersAndSedges"
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var placements:Array=[]
 var plant_sites:Array=_composition_candidates(terrain)
 var placement_rng:=RandomNumberGenerator.new();placement_rng.seed=seed_value+39127
 var triangles:int=0
 for side:int in [-1,1]:
  for patch_z:float in PATCH_Z:
   var center_z:float=patch_z+rng.randf_range(-1.10,1.10)
   for sprig in range(7):
    var z:float=center_z+rng.randf_range(-0.90,0.90)
    if z<3.0 or z>66.0 or (z>28.0 and z<42.0):continue
    var x:float=_bank_x(terrain,side,z,rng)
    if x<-900:continue
    var y:float=terrain.ground_surface_height(x,z)
    var at:=Vector3(x,y+0.009,z)
    var flower:bool=sprig%3==0 and y>WATER_MAX+0.075
    at=_cluster_plant_position(terrain,plant_sites,at,side,placements.size(),placement_rng)
    if flower:
     triangles+=_flower(st,at,rng,sprig%2==0)
    else:
     triangles+=_sedge(st,at,rng)
    placements.append({"position":at,"kind":"flower" if flower else "sedge","side":side,"patch_z":patch_z,"radius":SAFE_RADIUS})
 if triangles>0:
  var mesh:=MeshInstance3D.new();mesh.name="OpaqueShorelineAccents";mesh.mesh=st.commit()
  var mat:=StandardMaterial3D.new();mat.resource_name="ShorelineWarmPetalsAndOliveLeaves";mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=0.96;mat.metallic_specular=0.06
  mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mesh)
 root.set_meta("placements",placements);root.set_meta("triangles",triangles);root.set_meta("seed",seed_value)
 return root


static func _composition_candidates(terrain:Node3D)->Array:
 # Fallback preserves the standalone ambience API when only ground has been built.
 if terrain.get("bank_cluster_sites")==null or terrain.bank_cluster_sites.is_empty():return []
 var candidates:Array=[]
 for side:int in [-1,1]:
  for zi:int in range(156):
   var z:float=3.2+zi*0.4
   if z>28.0 and z<42.0:continue
   for xi:int in range(15):
    var x:float=53.96+xi*0.11 if side<0 else 59.60+xi*0.11
    if not _blocked_disc(terrain.sim,Vector2(x,z),SAFE_RADIUS):continue
    var y:float=terrain.ground_surface_height(x,z)
    if y<WATER_MAX+0.085 or y> -0.24:continue
    var envelope:=Rect2(Vector2(x-SAFE_RADIUS,z-SAFE_RADIUS),Vector2.ONE*SAFE_RADIUS*2.0)
    var clear:bool=true
    for rock:AABB in terrain.bank_rock_bounds:
     if envelope.intersects(Rect2(Vector2(rock.position.x,rock.position.z),Vector2(rock.size.x,rock.size.z)).grow(0.035)):
      clear=false;break
    if clear:candidates.append({"position":Vector3(x,y+0.009,z),"side":side,"used":false})
 return candidates

static func _cluster_plant_position(terrain:Node3D,candidates:Array,original:Vector3,side:int,index:int,rng:RandomNumberGenerator)->Vector3:
 if candidates.is_empty():return original
 var target_z:float=original.z;var nearest:float=INF
 for site:Dictionary in terrain.bank_cluster_sites:
  if site.side!=side or site.z<3.0 or site.z>66.0:continue
  var distance:float=absf(site.z-original.z)
  if distance<nearest:nearest=distance;target_z=site.z
 target_z+=1.82 if index%2==0 else -1.82
 var chosen:int=-1;var score:float=INF
 for i:int in range(candidates.size()):
  var candidate:Dictionary=candidates[i]
  if candidate.side!=side or candidate.used:continue
  var merit:float=absf(candidate.position.z-target_z)+absf(candidate.position.x-original.x)*0.16+rng.randf_range(0.0,0.24)
  if merit<score:score=merit;chosen=i
 if chosen<0:return original
 candidates[chosen].used=true
 return candidates[chosen].position

static func _bank_x(terrain:Node3D,side:int,z:float,rng:RandomNumberGenerator)->float:
 # Scan actual triangulated shore height; do not duplicate the river formula.
 # Keep the entire small patch inside blocked river cells, never beside a path.
 var candidates:Array[float]=[]
 for i in range(25):
  var x:float=53.9+i*0.065 if side<0 else 59.54+i*0.065
  if not _blocked_disc(terrain.sim,Vector2(x,z),SAFE_RADIUS):continue
  var y:float=terrain.ground_surface_height(x,z)
  if y>=WATER_MAX+0.025 and y<=-0.30:candidates.append(x)
 if candidates.is_empty():return -999.0
 return candidates[rng.randi_range(0,candidates.size()-1)]

static func _blocked_disc(sim:RefCounted,point:Vector2,radius:float)->bool:
 for offset:Vector2 in [Vector2.ZERO,Vector2(-radius,-radius),Vector2(-radius,radius),Vector2(radius,-radius),Vector2(radius,radius)]:
  var p:=point+offset
  var cell:=Vector2i(roundi(p.x/CELL),roundi(p.y/CELL))
  if cell.x<22 or cell.x>24 or cell.y<1 or cell.y>26:return false
  if cell.y>=12 and cell.y<=16:return false
  if sim._terrain_walkable(cell):return false
 return true

static func _tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,tint:Color)->void:
 var normal:Vector3=(b-a).cross(c-a).normalized()
 st.set_normal(normal);st.set_color(tint)
 st.add_vertex(a);st.add_vertex(c);st.add_vertex(b)

static func _sedge(st:SurfaceTool,at:Vector3,rng:RandomNumberGenerator)->int:
 var count:int=rng.randi_range(5,8)
 for i in range(count):
  var angle:float=i*2.399963+rng.randf_range(-0.28,0.28)
  var direction:=Vector3(cos(angle),0,sin(angle))
  var side:=Vector3(-direction.z,0,direction.x)
  var height:float=rng.randf_range(0.30,0.62)
  var width:float=rng.randf_range(0.034,0.060)
  var base:Vector3=at+direction*rng.randf_range(0.0,0.035)
  var middle:Vector3=base+Vector3.UP*height*0.57+direction*0.052
  var tip:Vector3=base+Vector3.UP*height+direction*rng.randf_range(0.18,0.255)
  var tint:Color=Color("718a40").lerp(Color("a3aa55"),rng.randf_range(0.0,0.32))
  _tri(st,base-side*width,base+side*width,middle+side*width*0.72,Color("516932"))
  _tri(st,base-side*width,middle+side*width*0.72,middle-side*width*0.72,tint.darkened(0.12))
  _tri(st,middle-side*width*0.72,middle+side*width*0.72,tip,tint)
 return count*3

static func _flower(st:SurfaceTool,at:Vector3,rng:RandomNumberGenerator,gold:bool)->int:
 var triangles:int=0
 var heads:int=rng.randi_range(2,4)
 for head in range(heads):
  var angle:float=head*2.399963+rng.randf_range(-0.40,0.40)
  var offset:=Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.025,0.14)
  var base:Vector3=at+offset
  var center:Vector3=base+Vector3(rng.randf_range(-0.025,0.025),rng.randf_range(0.24,0.41),rng.randf_range(-0.025,0.025))
  var stem_side:=Vector3(cos(angle+0.7),0,sin(angle+0.7))*0.009
  _tri(st,base-stem_side,base+stem_side,center+stem_side,Color("627438"))
  _tri(st,base-stem_side,center+stem_side,center-stem_side,Color("627438"));triangles+=2
  var petal:Color=Color("e7be46") if gold else Color("eee4b8")
  var radius:float=rng.randf_range(0.080,0.105)
  for i in range(5):
   var a:float=TAU*i/5.0+angle
   var direction:=Vector3(cos(a),0,sin(a));var side:=Vector3(-direction.z,0,direction.x)
   var inner:Vector3=center+direction*0.013
   var middle:Vector3=center+direction*radius*0.62+Vector3.UP*0.016
   var tip:Vector3=center+direction*radius
   _tri(st,inner,middle-side*radius*0.30,tip,petal)
   _tri(st,inner,tip,middle+side*radius*0.30,petal.lightened(0.045));triangles+=2
  for i in range(5):
   var a:float=TAU*i/5.0;var b:float=TAU*(i+1)/5.0
   _tri(st,center+Vector3.UP*0.008,center+Vector3(cos(a)*0.021,0.009,sin(a)*0.021),center+Vector3(cos(b)*0.021,0.009,sin(b)*0.021),Color("b38836"));triangles+=1
 return triangles
