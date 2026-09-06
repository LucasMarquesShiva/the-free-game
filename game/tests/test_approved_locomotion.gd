extends SceneTree
const People=preload("res://presentation/approved_people.gd")
var checks:=0
var failures: Array[String]=[]
var max_slip:=0.0
var min_sole:=INF
var max_reach:=0.0
func _initialize():call_deferred("run")
func expect(value: bool,message: String):
	checks+=1
	if not value:
		failures.append(message)
		if failures.size()<15:printerr("FAIL ",message)
func foot_min(foot: MeshInstance3D)->float:
	var box:=foot.mesh.get_aabb();var transform:=foot.global_transform;var center:=transform*box.get_center();var extent:=box.size*0.5
	return center.y-absf(transform.basis.x.y)*extent.x-absf(transform.basis.y.y)*extent.y-absf(transform.basis.z.y)*extent.z
func verify(person: Node3D,previous: Dictionary)->Dictionary:
	var rig: Dictionary=person.get_meta("approved_rig");var state: Dictionary=person.get_meta("gait_state")
	var current: Dictionary={}
	var contact_count:=0
	for side: String in ["L","R"]:
		var hip: Node3D=rig["hip_"+side];var knee: Node3D=rig["knee_"+side];var ankle: Node3D=rig["ankle_"+side]
		var foot: MeshInstance3D=ankle.get_node("Boot")
		var bottom:=foot_min(foot);min_sole=minf(min_sole,bottom)
		expect(bottom>=-0.00005,"sole above ground")
		var local_ankle: Vector3=person.global_transform.affine_inverse()*ankle.global_position
		var reach: float=hip.position.distance_to(local_ankle);max_reach=maxf(max_reach,reach)
		expect(reach<=People.THIGH_LENGTH+People.SHIN_LENGTH+0.00002,"no leg overextension")
		expect(absf(knee.position.length()-People.THIGH_LENGTH)<0.00001,"thigh length unchanged")
		expect(absf(ankle.position.length()-People.SHIN_LENGTH)<0.00001,"shin length unchanged")
		expect(absf(hip.basis.determinant()-1.0)<0.0001 and absf(knee.basis.determinant()-1.0)<0.0001,"bones only rotate")
		var record: Dictionary=state.feet[side]
		current[side]={"stance":record.stance,"cycle":record.cycle,"position":ankle.global_position,"toe":foot.global_transform*Vector3(0,-0.094,-0.14),"heel":foot.global_transform*Vector3(0,-0.094,0.05),"anchor":record.get("anchor",Vector3.ZERO)}
		if record.stance:
			contact_count+=1
			expect(bottom<=0.004,"support sole touches ground")
			if previous.has(side) and previous[side].stance and previous[side].cycle==record.cycle and Vector3(previous[side].anchor).is_equal_approx(record.anchor):
				var slip: float=maxf(ankle.global_position.distance_to(previous[side].position),maxf(Vector3(current[side].toe).distance_to(previous[side].toe),Vector3(current[side].heel).distance_to(previous[side].heel)));max_slip=maxf(max_slip,slip)
				expect(slip<0.001,"planted foot remains fixed in world")
	expect(contact_count>=1,"always a support foot")
	return current
func run():
	for role: String in People.APPROVED:
		for tier in [0,1,2]:
			for loaded: bool in [false,true]:
				var person:=People.create(role,11,tier);root.add_child(person)
				var previous: Dictionary={};var distance:=0.0
				var gain:=People.CARRY_RADIANS_PER_METER if loaded else People.WALK_RADIANS_PER_METER
				for frame in range(120):
					distance+=5.0/60.0;person.position.z=-distance
					People.animate(person,distance*gain+0.23,true,false,loaded,"wood")
					previous=verify(person,previous)
				expect(person.get_meta("gait_state").replants==0,"straight walk never forcibly replants")
				person.free()
	# Curves, low frame rate, quality switches and a deliberate teleport.
	var person:=People.create("stonecutter",4,1);root.add_child(person)
	var previous: Dictionary={};var distance:=0.0
	for frame in range(180):
		var dt:=1.0/24.0;person.rotation.y+=dt*1.4;var step:=5.0*dt;distance+=step
		person.position+=-person.basis.z.normalized()*step
		People.animate(person,distance*People.WALK_RADIANS_PER_METER,true,false,false)
		previous=verify(person,previous)
		if frame in [30,60,90]:People.set_quality(person,int(frame/30)%3)
	print("CURVE_REPLANTS ",person.get_meta("gait_state").replants)
	person.position+=Vector3(10,0,-10)
	People.animate(person,distance*People.WALK_RADIANS_PER_METER,true,false,false)
	verify(person,{})
	expect(person.get_meta("gait_state").replants>0,"teleport safely creates new contacts")
	People.animate(person,0.0,false,false,false)
	expect(not person.get_meta("gait_state").walking,"idle resets walking contact lifecycle")
	person.free()
	print("LOCOMOTION_RESULT checks=",checks," failures=",failures.size()," max_world_slip_m=",max_slip," min_sole_y=",min_sole," max_leg_reach_m=",max_reach)
	quit(0 if failures.is_empty() else 1)
