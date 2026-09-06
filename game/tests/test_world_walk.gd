extends SceneTree
## CPU audit of the real controller/World. Fixtures only change isolated runtime data.
const Game=preload("res://presentation/approved_game.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var min_clearance:=INF
var min_record:Dictionary={}
var max_base_error:=0.0
var max_flat_support_float:=-INF
var contact_samples:=0
var bridge_samples:=0
var max_terrain_adjustment:=0.0
var max_leg_reach:=0.0
var terrain_probe_roles:Dictionary={}
var sole_cache:Dictionary={}
func _initialize():call_deferred("run")
func expect(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func sole_points(foot:MeshInstance3D)->Array[Vector3]:
 var id:int=foot.mesh.get_instance_id()
 if sole_cache.has(id):return sole_cache[id]
 var result:Array[Vector3]=[];var found:Dictionary={};var bottom:float=foot.mesh.get_aabb().position.y
 for surface in range(foot.mesh.get_surface_count()):
  for vertex:Vector3 in foot.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
   if vertex.y>bottom+0.015:continue
   var key:=vertex.snapped(Vector3.ONE*0.00001)
   if not found.has(key):found[key]=true;result.append(vertex)
 sole_cache[id]=result;return result
func measure(world:Node3D,person:Node3D,segment:int,frame:int):
 var root_support:float=world.terrain.support_height(person.position.x,person.position.z)
 max_base_error=maxf(max_base_error,absf(person.position.y-root_support-0.002))
 if person.position.x>52.65 and person.position.x<62.35:bridge_samples+=1
 var rig:Dictionary=person.get_meta("approved_rig")
 var gait:Dictionary=person.get_meta("gait_state",{})
 terrain_probe_roles[str(person.get_meta("role"))+"/"+str(person.get_meta("quality"))+"/"+str(person.get_meta("cargo_kind",""))]=true
 for side:String in ["L","R"]:
  var foot:MeshInstance3D=rig["ankle_"+side].get_node("Boot")
  var local_foot:Transform3D=person.global_transform.affine_inverse()*foot.global_transform
  var reach:float=rig["hip_"+side].position.distance_to(local_foot.origin)
  max_leg_reach=maxf(max_leg_reach,reach)
  if gait.get("walking",false):
   var phase:float=float(gait.last_phase)+(PI if side=="L" else 0.0)
   var u:=fposmod(phase,TAU)/TAU
   var t:=clampf((u-0.52)/0.48,0,1)
   var lift:float=(0.085 if bool(gait.loaded) else 0.11)*pow(sin(t*PI),2.0) if u>=0.52 else 0.0
   var flat:float=-Game.World.People._box_min_y(foot.mesh.get_aabb(),local_foot.basis)+Game.World.People.SOLE_CLEARANCE
   max_terrain_adjustment=maxf(max_terrain_adjustment,absf((local_foot.origin.y-lift-flat)*person.global_basis.y.length()))
  var lowest:=INF;var highest_ground:=-INF;var lowest_ground:=INF
  for vertex:Vector3 in sole_points(foot):
   var p:Vector3=foot.global_transform*vertex
   var ground:float=world.terrain.support_height(p.x,p.z)
   var clear:float=p.y-ground;lowest=minf(lowest,clear)
   highest_ground=maxf(highest_ground,ground);lowest_ground=minf(lowest_ground,ground)
   if clear<min_clearance:
    min_clearance=clear;min_record={"role":person.get_meta("role"),"segment":segment,"frame":frame,"side":side,"root":str(person.position),"sole_vertex":str(p),"floor_y":ground,"clearance":clear}
  if bool(gait.get("walking",false)) and bool(gait.feet[side].stance):
   contact_samples+=1
   if highest_ground-lowest_ground<0.001 and absf(highest_ground-root_support)<0.001:
    max_flat_support_float=maxf(max_flat_support_float,lowest)
func run():
 root.size=Vector2i(1280,800)
 var game:=Game.new();root.add_child(game);game.set_process(false)
 expect(is_equal_approx(Game.CIVIL_PACE,0.4),"normal civil pace is 0.4")
 for speed in [1,2,4]:
  game.speed=speed;game.clock.pending_usec=0
  var start_tick:int=game.sim.tick;var start_clock:int=game.clock.tick;var start_elapsed:float=game.world.elapsed
  for frame in range(4):game._process(0.25)
  expect(game.sim.tick-start_tick==speed*4 and game.clock.tick-start_clock==speed*4,"simulation and clock advance proportionally at %dx"%speed)
  expect(is_equal_approx(game.world.visual_speed,speed*0.4) and absf(game.world.elapsed-start_elapsed-speed*0.4)<0.00001,"visual time uses the same pace at %dx"%speed)
 game.sim.paused=true
 var before:int=game.sim.tick;var elapsed_before:float=game.world.elapsed
 game._process(0.25)
 expect(game.sim.tick==before and game.world.elapsed==elapsed_before,"pause freezes simulation and visual time")
 # Connected, complete roads are a rendering fixture, not a new production order.
 var sim:RefCounted=game.sim;var world:Node3D=game.world
 sim.workers.clear();sim.roads.clear();sim.paused=false
 var cells:Array[Vector2i]=[]
 for x in range(9,28):cells.append(Vector2i(x,13))
 for y in [14,15]:
  for x in range(19,28):cells.append(Vector2i(x,y))
 for index in range(cells.size()):sim.roads.append({"id":10000+index,"cell":cells[index],"stage":"complete"})
 sim._rebuild_roads();world.terrain.sync();world.visual_speed=0.4;world.sync(0.0)
 expect(absf(world.terrain.support_height(50,32.5)-world.terrain.ground_surface_height(50,32.5)-0.015)<0.00001,"road support includes the actual 15 mm paving offset")
 expect(absf(world.terrain.support_height(57.5,35)-0.135)<0.00001,"bridge support is the physical 135 mm timber top")
 for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
  var at:Vector3=world._person_position(Vector2i(18,14),7,direction)
  var offset:=Vector2(at.x-45,at.z-35)
  var right:=Vector2(-direction.y,direction.x)
  expect(offset.distance_to(right*0.42)<0.00001,"right-hand 42 cm lane for "+str(direction))
 var clamp_ok:=true
 for x in [21,22,23,24,25]:
  for y in [13,14,15]:
   for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
    var at:Vector3=world._person_position(Vector2i(x,y),7,direction)
    clamp_ok=clamp_ok and at.z>=32.3-0.00001 and at.z<=37.7+0.00001
 expect(clamp_ok,"bridge endpoints stay within z32.3..37.7 including both outer rows")
 var path_a:Array[Vector2i]=[Vector2i(19,13),Vector2i(20,13),Vector2i(21,13),Vector2i(22,13),Vector2i(22,14),Vector2i(23,14),Vector2i(24,14),Vector2i(24,15),Vector2i(25,15),Vector2i(26,15),Vector2i(27,15)]
 var path_b:Array[Vector2i]=[Vector2i(19,15),Vector2i(20,15),Vector2i(21,15),Vector2i(22,15),Vector2i(23,15),Vector2i(23,14),Vector2i(23,13),Vector2i(24,13),Vector2i(25,13),Vector2i(26,13),Vector2i(27,13)]
 var reverse_a:=path_a.duplicate();reverse_a.reverse();var reverse_b:=path_b.duplicate();reverse_b.reverse()
 var paths:Array=[path_a,reverse_a,path_b,reverse_b]
 var actors:Array[Dictionary]=[]
 for index in range(paths.size()):
  var path:Array=paths[index];var legal:=true
  for step in range(path.size()):
   legal=legal and sim.is_walkable(path[step]) and sim.has_road(path[step])
   if step>0:legal=legal and absi(path[step].x-path[step-1].x)+absi(path[step].y-path[step-1].y)==1
  expect(legal,"fixture follows contiguous completed walkable roads "+str(index))
  var worker:Dictionary=sim._add_worker("stonecutter" if index==3 else "servant",path[0])
  worker.route=path.slice(1);worker.state="Transportando pela estrada";worker.goal=path[-1]
  if index>=2:worker.cargo={"item":"wood","amount":1}
  actors.append(worker)
 world.sync(0.0)
 var bridge_lane_ok:=true;var continuous_motion:=true;var held_contacts:=true
 for segment in range(1,path_a.size()):
  # Exercise live mesh switches while walking, including both bridge lips.
  world.view_size=[18.0,30.0,55.0][segment%3];world.target_size=world.view_size
  for i in range(actors.size()):actors[i].cell=paths[i][segment];actors[i].route=paths[i].slice(segment+1)
  for frame in range(75):
   world.sync(1.0/60.0)
   for worker:Dictionary in actors:
    var person:Node3D=world.people[worker.id]
    if person.position.x>52.65 and person.position.x<62.35:bridge_lane_ok=bridge_lane_ok and person.position.z>=32.3-0.0001 and person.position.z<=37.7+0.0001
    if segment<path_a.size()-1:continuous_motion=continuous_motion and person.get_meta("gait_state",{}).get("walking",false)
    if frame%3==0:measure(world,person,segment,frame)
  if segment<path_a.size()-1:
   # An extra stationary frame at a cell boundary must retain contact while a route remains.
   world.sync(1.0/60.0)
   for worker:Dictionary in actors:held_contacts=held_contacts and world.people[worker.id].get_meta("gait_state",{}).get("walking",false)
 expect(bridge_lane_ok,"interpolated crossings and turns stay inside the bridge lane clamp")
 expect(continuous_motion and held_contacts,"continued routes keep walking/contact state across cell-boundary frames")
 expect(max_base_error<0.00001,"World root uses 2 mm clearance consistently during interpolation")
 expect(contact_samples>500 and bridge_samples>500,"real World.sync sampled crossing/turning support poses")
 expect(min_clearance>=-0.0001,"actual walking sole vertices stay above the bridge/road surface")
 expect(max_leg_reach<=0.77501,"terrain-aware legs never exceed their anatomical reach")
 expect(max_terrain_adjustment<=0.15,"bridge corrections stay within the 15 cm step envelope")
 expect(max_flat_support_float<0.015,"flat planted soles have no former 4 cm floating offset")
 # Waiting/working on both bridge lips must also resolve the actual sole floor.
 var previous_min:float=min_clearance
 for cell:Vector2i in [Vector2i(21,13),Vector2i(21,14),Vector2i(21,15),Vector2i(25,13),Vector2i(25,14),Vector2i(25,15)]:
  for tier in [0,1,2]:
   world.view_size=[18.0,30.0,55.0][tier];world.target_size=world.view_size
   for index in range(actors.size()):
    var worker:Dictionary=actors[index];worker.cell=cell;worker.route=[];worker.wait=4
    worker.state="Pavimentando" if index==3 else "Aguardando passagem"
    var person:Node3D=world.people[worker.id]
    var direction:=Vector2i.RIGHT if cell.x==21 else Vector2i.LEFT
    person.set_meta("cell",cell);person.position=world._person_position(cell,worker.id,direction)
    person.set_meta("from",person.position);person.set_meta("to",person.position);person.set_meta("fraction",1.0)
    person.rotation.y=-PI*0.5 if cell.x==21 else PI*0.5
   for index in range(actors.size()+1):world.sync(0.0)
   for worker:Dictionary in actors:measure(world,world.people[worker.id],20+tier,cell.y)
 expect(min_clearance>=-0.0001,"waiting and working soles also clear both lips in all three rows and LODs")
 expect(max_leg_reach<=0.77501,"waiting terrain poses preserve leg lengths too")
 expect(terrain_probe_roles.size()>=9,"wide/carrying boots exercised through all three LODs")
 var original_scales:Dictionary={}
 for worker:Dictionary in actors:original_scales[worker.id]=world.people[worker.id].scale
 for tier in [0,1,2]:
  world.view_size=[18.0,30.0,55.0][tier];world.target_size=world.view_size
  for index in range(actors.size()+1):world.sync(0.0)
  var quality_ok:=true;var scale_ok:=true
  for worker:Dictionary in actors:
   var person:Node3D=world.people[worker.id]
   quality_ok=quality_ok and int(person.get_meta("quality"))==tier
   scale_ok=scale_ok and person.scale.is_equal_approx(original_scales[worker.id])
  expect(quality_ok and scale_ok,"zoom applies LOD%d without changing adult/root scale"%tier)
 metrics={"min_sole_clearance_m":min_clearance,"worst_contact":min_record,"max_root_clearance_error_m":max_base_error,"max_flat_stance_float_m":max_flat_support_float,"contact_samples":contact_samples,"bridge_frame_samples":bridge_samples,"max_leg_reach_m":max_leg_reach,"max_terrain_adjustment_m":max_terrain_adjustment,"role_lod_cargo_combinations":terrain_probe_roles.size()}
 var result:Dictionary={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Real World.sync; isolated connected road/civil fixtures. People terrain support and one-line World callback integration in isolated mirror; no root source edits, no GPU."}
 FileAccess.open("user://approved-world-walk-audit/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("WORLD_WALK_AUDIT ",JSON.stringify(result))
 game.free();quit(0 if failures.is_empty() else 1)
