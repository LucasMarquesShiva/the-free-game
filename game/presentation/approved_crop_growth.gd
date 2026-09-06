extends RefCounted
## Crop meshes evolve from persisted simulation progress, without rebuilding the farmhouse.
const Civil = preload("res://presentation/approved_civil_buildings.gd")
const Base = preload("res://presentation/approved_primitives.gd")
const BED_CENTERS := [Vector3(-1.33,0.20,1.25),Vector3(1.09,0.20,1.59),Vector3(-1.70,0.20,-0.56)]
const BED_SIZES := [Vector2(1.12,1.40),Vector2(1.20,0.91),Vector2(0.67,1.59)]
static var _bare_meshes: Dictionary = {}
static var _crop_meshes: Dictionary = {}
static var _plants: Array[Dictionary] = []

static func _layout() -> Array[Dictionary]:
 if not _plants.is_empty():return _plants
 for bed: int in range(3):
  var size: Vector2 = BED_SIZES[bed]
  var columns: int = maxi(2,roundi(size.x/0.40))
  var rows: int = maxi(2,roundi(size.y/0.40))
  for row: int in range(rows):
   for col: int in range(columns):
    var at: Vector3 = BED_CENTERS[bed]+Vector3((col+0.5)/columns*size.x-size.x*0.5,0.15,(row+0.5)/rows*size.y-size.y*0.5)
    _plants.append({"position":at,"kind":bed if (row+col)%3 else 2,"bed":bed,"row":row,"column":col})
 return _plants

static func _is_static_crop(key: String, a: Vector3, b: Vector3, c: Vector3) -> bool:
 if key not in ["foliage","wood"]:return false
 var center: Vector3 = (a+b+c)/3.0
 if key == "foliage":
  if minf(a.y,minf(b.y,c.y)) < 0.25 or maxf(a.y,maxf(b.y,c.y)) > 0.85:return false
  for i: int in range(3):
   var area := Rect2(Vector2(BED_CENTERS[i].x,BED_CENTERS[i].z)-BED_SIZES[i]*0.5,BED_SIZES[i]).grow(0.05)
   if area.has_point(Vector2(center.x,center.z)):return true
 elif minf(a.y,minf(b.y,c.y)) > 0.46 and maxf(a.y,maxf(b.y,c.y)) < 0.66:
  for plant: Dictionary in _layout():
   if plant.kind == 2 and Vector2(center.x-plant.position.x,center.z-plant.position.z).length() < 0.065:return true
 return false

static func strip_static_crops(building: Node3D) -> void:
 var architecture: MeshInstance3D = building.get_node_or_null("Architecture")
 if architecture == null or not architecture.mesh is ArrayMesh:return
 var source: ArrayMesh = architecture.mesh
 var cache_key: int = source.get_instance_id()
 if not _bare_meshes.has(cache_key):
  var bare := ArrayMesh.new()
  var removed: int = 0
  for surface: int in range(source.get_surface_count()):
   var arrays: Array = source.surface_get_arrays(surface).duplicate()
   var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   var kept := PackedInt32Array()
   var key: String = source.surface_get_name(surface)
   for i: int in range(0,indices.size(),3):
    if _is_static_crop(key,positions[indices[i]],positions[indices[i+1]],positions[indices[i+2]]):
     removed += 1
    else:
     kept.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
   if kept.is_empty():continue
   arrays[Mesh.ARRAY_INDEX] = kept
   bare.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var index: int = bare.get_surface_count()-1
   bare.surface_set_name(index,key)
   bare.surface_set_material(index,source.surface_get_material(surface))
  bare.set_meta("removed_crop_triangles",removed)
  _bare_meshes[cache_key] = bare
 architecture.mesh = _bare_meshes[cache_key]

static func _mesh(kind: int) -> ArrayMesh:
 if _crop_meshes.has(kind):return _crop_meshes[kind]
 var batch := Base.Batch.new(7281+kind*137)
 if kind >= 0:
  Civil._vegetable(batch,Vector3.ZERO,0.15,kind)
 elif kind == -1:
  Base._cylinder(batch,Vector3(0,0.042,0),0.012,0.084,Color("668b39"),"foliage")
  Base._ellipsoid(batch,Vector3(-0.049,0.088,0.006),Vector3(0.079,0.019,0.039),Color("769b43"),"foliage")
  Base._ellipsoid(batch,Vector3(0.048,0.105,-0.007),Vector3(0.073,0.018,0.037),Color("91ad50"),"foliage")
 else:
  for bed: int in range(3):
   var size: Vector2 = BED_SIZES[bed]
   var rows: int = maxi(2,roundi(size.y/0.40))
   for row: int in range(rows):
    var at: Vector3 = BED_CENTERS[bed]+Vector3(0,0.084,(row+0.5)/rows*size.y-size.y*0.5)
    Base._box(batch,at,Vector3(size.x-0.13,0.018,0.022),Color("423824"),"plaster")
 var asset: Dictionary = Base._finish(batch)
 _crop_meshes[kind] = asset.mesh
 return asset.mesh

static func install(building: Node3D) -> void:
 if building.has_node("GardenGrowth"):return
 strip_static_crops(building)
 var garden := Node3D.new();garden.name = "GardenGrowth";building.add_child(garden)
 var grooves := MeshInstance3D.new();grooves.name = "SowingRows";grooves.mesh = _mesh(-2);garden.add_child(grooves)
 for kind: int in [-1,0,1,2]:
  var group := MultiMeshInstance3D.new();group.name = "Sprouts" if kind == -1 else "Vegetables"+str(kind)
  var instances := MultiMesh.new();instances.transform_format = MultiMesh.TRANSFORM_3D;instances.mesh = _mesh(kind)
  var slots: Array[int] = []
  for i: int in range(_layout().size()):
   if kind == -1 or _layout()[i].kind == kind:slots.append(i)
  instances.instance_count = slots.size()
  group.multimesh = instances;group.set_meta("slots",slots);group.set_meta("crop_kind",kind);garden.add_child(group)
  group.visible = false
 garden.set_meta("progress",-1.0);garden.set_meta("cycle",-1)

static func sync(building: Node3D, status: Dictionary, delta: float = 0.0) -> void:
 if status.is_empty():return
 var garden: Node3D = building.get_node_or_null("GardenGrowth")
 if garden == null:return
 var target: float = float(status.progress)
 var previous: float = float(garden.get_meta("progress",-1.0))
 var cycle: int = int(status.completed_cycles)
 var visual: float = target
 if previous >= 0.0 and cycle == int(garden.get_meta("cycle")) and target >= previous and delta > 0.0 and bool(status.active):
  visual = lerpf(previous,target,1.0-exp(-delta*12.0))
 garden.set_meta("progress",visual);garden.set_meta("cycle",cycle);garden.set_meta("stage",status.stage)
 var mature: float = smoothstep(0.40,0.82,visual)
 var sprouting: float = smoothstep(0.18,0.42,visual)
 var harvest: float = clampf((visual-0.82)/0.18,0.0,1.0)
 var visible_plants: int = 0
 for group: Node in garden.get_children():
  if not group is MultiMeshInstance3D:continue
  var kind: int = group.get_meta("crop_kind")
  var slots: Array = group.get_meta("slots")
  var any_visible := false
  for i: int in range(slots.size()):
   var index: int = slots[i]
   var plant: Dictionary = _layout()[index]
   var gathered: float = smoothstep(float(index)/_layout().size(),minf(1.0,float(index+2)/_layout().size()),harvest)
   var growth: float = sprouting*(1.0-mature*0.50) if kind == -1 else mature
   growth *= 1.0-gathered
   var scale_factor: float = maxf(0.001,growth)
   var at: Vector3 = plant.position
   if growth < 0.015:at.y -= 2.0
   else:
    any_visible = true
    if kind >= 0:visible_plants += 1
   var basis := Basis(Vector3.UP,float(index)*2.399).scaled(Vector3.ONE*scale_factor)
   group.multimesh.set_instance_transform(i,Transform3D(basis,at))
  group.visible = any_visible
 garden.set_meta("visible_plants",visible_plants)
