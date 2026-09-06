extends SceneTree
const Sim = preload("res://simulation/approved_sim.gd")
const Models = preload("res://presentation/approved_buildings.gd")
const Crops = preload("res://presentation/approved_crop_growth.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:failures.append(label);push_error(label)
func advance(sim: RefCounted, count: int) -> void:
 for i in range(count):sim.step()
func state(sim: RefCounted) -> Dictionary:return JSON.parse_string(JSON.stringify(sim.snapshot()))
func fresh() -> RefCounted:
 var sim := Sim.new();sim.setup();return sim
func run() -> void:
 var sim: RefCounted = fresh()
 check(sim.command("build",{"kind":"farm","cell":Vector2i(16,17)}).ok,"farm planned through legal construction command")
 var farm: Dictionary = sim.buildings.back()
 check(sim.crop_status(farm).stage == "soil" and not sim.crop_status(farm).active,"new farm has soil and no growth during construction")
 var roads: Array[Vector2i] = []
 for x in range(8,16):roads.append(Vector2i(x,13))
 for y in range(14,20):roads.append(Vector2i(15,y))
 roads.append(Vector2i(16,19))
 check(sim.command("road",{"cells":roads}).ok,"farm and school have a legal connected road plan")
 advance(sim,2200)
 check(farm.stage == "complete" and float(farm.production) == 0.0 and sim.crop_status(farm).reason.contains("horticultor"),"completed farm remains bare without a trained horticulturist")
 check(sim.command("train",{"role":"farmer"}).ok,"horticulturist training requested legally")
 var saw_travel := false
 for i in range(3000):
  sim.step()
  var status: Dictionary = sim.crop_status(farm)
  if status.reason.contains("caminho"):
   saw_travel = true
   check(float(farm.production) == 0.0,"crop waits while the horticulturist is still travelling")
  if status.active:break
 check(saw_travel and sim.crop_status(farm).active,"horticulturist reaches the work slot autonomously")
 var start_food: int = sim.produced.food
 var stages: Dictionary = {}
 var remaining_ticks: int = roundi((1.0-float(farm.production))*100.0)
 for i in range(remaining_ticks-1):
  sim.step();stages[sim.crop_status(farm).stage] = true
 check(sim.produced.food == start_food,"no food minted before the first cycle finishes")
 sim.step()
 check(sim.produced.food == start_food+8 and farm.crop_cycles == 1 and float(farm.production) == 0.0,"100 active ticks harvest exactly eight food and reset to soil")
 check(stages.has("seeding") and stages.has("sprouts") and stages.has("growing") and stages.has("harvest"),"cycle visits every visible cultivation stage")
 advance(sim,37)
 var saved: Dictionary = state(sim)
 var restored: RefCounted = fresh()
 check(restored.restore(saved),"mid-growth save restores")
 var restored_farm: Dictionary = restored._building(farm.id)
 check(sim.crop_status(farm).stage == restored.crop_status(restored_farm).stage and sim.crop_status(farm).completed_cycles == restored.crop_status(restored_farm).completed_cycles and is_equal_approx(farm.production,restored_farm.production),"phase, progress and cycle counter survive restore")
 advance(sim,150);advance(restored,150)
 check(state(sim) == state(restored),"crop, deliveries and economy remain deterministic after restore")
 check(sim.conservation_errors().is_empty(),"harvests preserve resource conservation")
 sim.paused = true
 var paused_progress: float = farm.production
 advance(sim,100)
 check(float(farm.production) == paused_progress and not sim.crop_status(farm).active,"game pause freezes cultivation")
 sim.paused = false
 var removed: bool = false
 for cell: Vector2i in [Vector2i(16,19),Vector2i(15,19),Vector2i(15,16)]:
  if sim.command("remove_road",{"cell":cell}).ok:removed = true;break
 check(removed and not sim.is_building_connected(farm),"road disconnect created through legal command")
 var frozen: float = farm.production
 advance(sim,150)
 check(float(farm.production) == frozen and sim.crop_status(farm).reason.contains("Conecte"),"disconnected farm preserves partial progress without growing")
 var disconnected_save: Dictionary = state(sim)
 var disconnected: RefCounted = fresh()
 check(disconnected.restore(disconnected_save) and disconnected.conservation_errors().is_empty(),"disconnected crop and pending cargo restore without loss")
 check(sim.command("road",{"cells":roads}).ok,"reconnection can be requested legally")
 var resumed := false
 for i in range(2500):
  sim.step()
  if sim.is_building_connected(farm) and float(farm.production) != frozen:resumed = true;break
 check(resumed,"crop resumes preserved work after road reconstruction")
 var valid: Dictionary = state(sim)
 var invalid: Dictionary = valid.duplicate(true)
 for b: Dictionary in invalid.buildings:
  if b.kind == "farm":b.crop_cycles = -1
 check(not sim.restore(invalid) and state(sim) == valid,"invalid crop cycle counter rejects atomically")
 invalid = valid.duplicate(true)
 for b: Dictionary in invalid.buildings:
  if b.kind == "farm":b.production = 2.0
 check(not sim.restore(invalid) and state(sim) == valid,"out of range crop progress rejects atomically")
 var legacy: Dictionary = valid.duplicate(true)
 for b: Dictionary in legacy.buildings:
  if b.kind == "farm":b.erase("crop_cycles")
 var migrated: RefCounted = fresh()
 check(migrated.restore(legacy) and is_equal_approx(migrated._building(farm.id).production,farm.production),"legacy approved save preserves partial production without a crop counter")
 test_visual()
 print("CROP_GROWTH_TEST ",JSON.stringify({"checks":checks,"failures":failures,"food":sim.produced.food,"cycles":farm.crop_cycles}))
 quit(0 if failures.is_empty() else 1)
func status(progress: float) -> Dictionary:
 return {"progress":progress,"stage":"harvest" if progress>=0.82 else "growing","completed_cycles":0,"active":true}
func test_visual() -> void:
 var a: Node3D = Models.building("farm");var b: Node3D = Models.building("farm")
 var original_mesh: ArrayMesh = a.get_node("Architecture").mesh
 var original_arrays: Array = []
 for i: int in range(original_mesh.get_surface_count()):original_arrays.append(original_mesh.surface_get_arrays(i))
 Crops.install(a);Crops.install(b)
 var immutable := true
 for i: int in range(original_mesh.get_surface_count()):immutable = immutable and original_mesh.surface_get_arrays(i) == original_arrays[i]
 check(a.get_node("Architecture").mesh != original_mesh and immutable,"source farmhouse mesh remains immutable")
 var crop_only := Crops.Base.Batch.new(1)
 for plant: Dictionary in Crops._layout():Crops.Civil._vegetable(crop_only,plant.position,0.15,plant.kind)
 var crop_mesh: ArrayMesh = Crops.Base._finish(crop_only).mesh
 var expected: int = 0
 for i: int in range(crop_mesh.get_surface_count()):expected += crop_mesh.surface_get_array_index_len(i)/3
 var removed: int = a.get_node("Architecture").mesh.get_meta("removed_crop_triangles")
 check(removed == expected,"only all crop triangles are removed; farm structure and other foliage remain")
 print("CROP_GEOMETRY removed=",removed," expected=",expected)
 Crops.sync(a,status(0.0));Crops.sync(b,status(0.73))
 check(not a.get_node("GardenGrowth/Sprouts").visible and b.get_node("GardenGrowth/Vegetables0").visible,"bare and leafy farms can exist simultaneously")
 var a_group: MultiMeshInstance3D = a.get_node("GardenGrowth/Vegetables0")
 var b_group: MultiMeshInstance3D = b.get_node("GardenGrowth/Vegetables0")
 var before: Transform3D = b_group.multimesh.get_instance_transform(0)
 Crops.sync(a,status(0.95))
 check(a_group.multimesh != b_group.multimesh and b_group.multimesh.get_instance_transform(0) == before,"updating one farm cannot change another farm's growth")
 check(a_group.multimesh.mesh == b_group.multimesh.mesh,"only immutable crop geometry is shared")
 Crops.sync(a,status(0.0))
 var lag: float = 0.0
 var reached_harvest := false
 for frame in range(1,370):
  var target: float = floorf(float(frame)/60.0*16.0)*0.01
  Crops.sync(a,status(target),1.0/60.0)
  var shown: float = a.get_node("GardenGrowth").get_meta("progress")
  lag = maxf(lag,target-shown)
  if shown > 0.94:reached_harvest = true
 check(lag < 0.025 and reached_harvest,"4x visual interpolation reaches harvest without capped growth speed")
 Crops.sync(a,{"progress":0.0,"stage":"soil","completed_cycles":1,"active":true})
 check(not a_group.visible and a.get_node("GardenGrowth").get_meta("progress") == 0.0,"harvest reset returns the visible bed to soil")
 a.free();b.free()
