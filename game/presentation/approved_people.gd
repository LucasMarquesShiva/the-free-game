extends RefCounted
## Eight adult, articulated civilians modelled from their approved concept sheets.
## Forward -Z; semantic materials and geometry are cached between instances.
const Sculpt = preload("res://presentation/approved_anatomy.gd")
const APPROVED := ["resident","servant","builder","farmer","lumberjack","stonecutter","vintner","instructor"]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _sphere: SphereMesh
static var _surface_atlas: Texture2D
static var _fabric_texture: NoiseTexture2D
static var _fabric_normal: NoiseTexture2D
static var _garment_materials: Dictionary={}
static var _garment_shader: Shader
static var _rigid_shader: Shader
static var _requested_quality:=0
static var _spheres: Dictionary={}
const QUALITY_HIGH:=0
const QUALITY_MEDIUM:=1
const QUALITY_DISTANT:=2
# These gains match distance accumulation in the world controller.
const WALK_RADIANS_PER_METER:=5.6
const CARRY_RADIANS_PER_METER:=6.8
const STANCE_FRACTION:=0.52
const THIGH_LENGTH:=0.385
const SHIN_LENGTH:=0.390
const LEG_REACH:=0.770
const SOLE_CLEARANCE:=0.0015

static func create(role: String, id: int, detail: int=QUALITY_HIGH) -> Node3D:
	_requested_quality=clampi(detail,QUALITY_HIGH,QUALITY_DISTANT)
	if role not in APPROVED:role="resident"
	var person:=Node3D.new();person.name="Approved_%s_%d"%[role,id]
	if role=="stonecutter":person.scale=Vector3(1.10,0.99,1.08)
	person.set_meta("role",role);person.set_meta("id",id);person.set_meta("quality",_requested_quality);person.set_meta("reference",Sculpt.REFERENCES[role])
	var body:=_joint(person,"Body",Vector3(0,0.90,0))
	_attach(body,"Clothing",_cached(role+"_body",func():return Sculpt.body(role)))
	var head:=_joint(body,"Head",Vector3(0,0.69,0));head.scale=Vector3(1.06,1.045,1.07)
	_attach(head,"HeadAndHair",_cached(role+"_head",func():return Sculpt.head(role)))
	var rig: Dictionary={"body":body,"head":head}
	var shoulder: float=0.213 if role not in ["builder","stonecutter"] else 0.228
	for side: int in [-1,1]:
		var suffix: String="L" if side<0 else "R"
		var arm:=_joint(body,"Arm"+suffix,Vector3(float(side)*shoulder,0.472,0))
		_attach(arm,"Sleeve",_cached(role+"_sleeve",func():return Sculpt.sleeve(role)))
		var elbow:=_joint(arm,"Elbow",Vector3(0,-0.285,0))
		_attach(elbow,"Forearm",_cached(role+"_forearm",func():return Sculpt.forearm(role)))
		var hand:=_joint(elbow,"Hand",Vector3(0,-0.255,0))
		_attach(hand,"Fingers",_cached(role+"_hand_"+suffix,func():return Sculpt.hand(role,side,false)))
		var hip:=_joint(person,"Hip"+suffix,Vector3(float(side)*0.112,0.885,0))
		_attach(hip,"Trousers",_cached(role+"_thigh",func():return Sculpt.thigh(role)))
		var knee:=_joint(hip,"Knee",Vector3(0,-0.385,0))
		_attach(knee,"Calf",_cached(role+"_calf",func():return Sculpt.calf(role)))
		var ankle:=_joint(knee,"Ankle",Vector3(0,-0.39,0))
		_attach(ankle,"Boot",_cached(role+"_foot",func():return Sculpt.foot(role)))
		rig["arm_"+suffix]=arm;rig["elbow_"+suffix]=elbow;rig["hand_"+suffix]=hand
		rig["hip_"+suffix]=hip;rig["knee_"+suffix]=knee;rig["ankle_"+suffix]=ankle
	var tool:=_joint(body,"Tool",Vector3.ZERO)
	if role not in ["resident","servant"]:_attach(tool,"HeldTool",_cached(role+"_tool",func():return Sculpt.tool(role)))
	var cargo:=_joint(body,"Cargo",Vector3(0,0.125,-0.33))
	var cargo_mesh:=MeshInstance3D.new();cargo_mesh.name="CargoMesh";cargo.add_child(cargo_mesh);cargo.visible=false
	rig.tool=tool;rig.cargo=cargo;rig.cargo_mesh=cargo_mesh
	if role=="instructor":
		var board:=_joint(body,"TeachingBoard",Vector3(-0.23,0.16,-0.265));board.rotation=Vector3(-0.08,-0.12,-0.08)
		_attach(board,"Board",_cached("teaching_board",func():return _board()));rig.board=board
	person.set_meta("approved_rig",rig);person.set_meta("cargo_kind","");person.set_meta("grip_state","")
	animate(person,float(id)*0.61,false,false,false)
	return person

static func animate(person: Node3D,phase: float,walking: bool,working: bool,loaded: bool,cargo_kind: String="wood") -> void:
	if not is_instance_valid(person) or not person.has_meta("approved_rig"):return
	var rig: Dictionary=person.get_meta("approved_rig");var role: String=person.get_meta("role")
	_requested_quality=int(person.get_meta("quality",QUALITY_HIGH))
	var wave:=cos(phase) if walking else sin(phase);var idle:=sin(phase*0.23)
	var waiting:bool=not walking and not working and not loaded
	var rest:Dictionary=_rest_variation(int(person.get_meta("id",0)),phase) if waiting else {}
	var gait: Dictionary={}
	if walking:gait=_walk_pose(person,rig,phase,loaded)
	elif person.has_meta("gait_state"):person.get_meta("gait_state").walking=false
	var bob: float=float(gait.hip_height)-0.885 if walking else (float(rest.breath)*0.0025 if waiting else idle*0.002)
	var body: Node3D=rig.body;body.position=Vector3(0,0.90+bob,0);body.scale=Vector3.ONE
	body.rotation=Vector3(-0.025 if loaded else 0.0,wave*0.028 if walking else idle*0.011,wave*0.016 if walking else -0.017)
	(body.get_node("Clothing") as MeshInstance3D).set_instance_shader_parameter("cloth_stride",float(gait.cloth_stride) if walking else 0.0)
	(body.get_node("Clothing") as MeshInstance3D).set_instance_shader_parameter("cloth_forward",float(gait.cloth_forward) if walking else 0.0)
	rig.head.rotation=Vector3(idle*0.015,-body.rotation.y*0.7+idle*0.045,-body.rotation.z*0.6)
	if waiting:
		body.scale=Vector3(1.0+float(rest.breath)*0.002,1.0+float(rest.breath)*0.0025,1.0+float(rest.breath)*0.003)
		body.rotation=Vector3(float(rest.breath)*0.004,float(rest.look)*0.045,-0.017-float(rest.support)*0.018)
		rig.head.rotation=Vector3(float(rest.breath)*0.009-float(rest.look_strength)*0.026,float(rest.look)*0.25,-body.rotation.z*0.6+float(rest.look)*0.022)
	for side: int in [-1,1]:
		var suffix: String="L" if side<0 else "R";var stride: float=wave*float(side)
		var hip: Node3D=rig["hip_"+suffix];var knee: Node3D=rig["knee_"+suffix];var ankle: Node3D=rig["ankle_"+suffix]
		if not walking:
			hip.position=Vector3(float(side)*0.112,0.885+bob,0)
			hip.basis=Basis.from_euler(Vector3(-0.025 if side<0 else 0.015,0,float(side)*0.012))
			knee.basis=Basis.from_euler(Vector3(-0.028,0,0))
			ankle.basis=Basis.from_euler(Vector3(-hip.rotation.x-knee.rotation.x,0,0))
		var arm: Node3D=rig["arm_"+suffix];var elbow: Node3D=rig["elbow_"+suffix]
		arm.rotation=Vector3(-stride*0.25 if walking else 0.07,0,float(side)*0.065)
		elbow.rotation=Vector3(0.24+maxf(0,stride)*0.14 if walking else 0.23,0,float(side)*0.10)
		rig["hand_"+suffix].rotation=Vector3(0,0,float(side)*-0.07)
	# Waiting at a bridge lip needs the same per-foot floor as locomotion.
	# Preserve the resting foot positions/head/arms while solving their height.
	var resting_ground:Callable=person.get_meta("ground_height",Callable())
	if waiting or (not walking and resting_ground.is_valid()):
		var grounded:Dictionary=_idle_support(person,rig,resting_ground,float(rest.support)*0.018) if waiting else _stand_on_terrain(person,rig,resting_ground)
		if waiting:body.position.x=float(rest.support)*0.018
		body.position.y=float(grounded.hip_height)+0.015
		var cloth:MeshInstance3D=body.get_node("Clothing")
		cloth.set_instance_shader_parameter("cloth_stride",grounded.cloth_stride)
		cloth.set_instance_shader_parameter("cloth_forward",grounded.cloth_forward)
	var cargo: Node3D=rig.cargo;var tool: Node3D=rig.tool
	cargo.visible=loaded;tool.visible=not loaded and role not in ["resident","servant"]
	if rig.has("board"):rig.board.visible=not loaded
	var right_grip: bool=loaded or role not in ["resident","servant"]
	var left_grip: bool=loaded or role=="instructor" or (working and role in ["lumberjack","farmer"])
	var grip_state: String=str(left_grip)+str(right_grip)
	if person.get_meta("grip_state")!=grip_state:
		for side: int in [-1,1]:
			var suffix: String="L" if side<0 else "R";var gripping: bool=left_grip if side<0 else right_grip
			var hand_mesh: MeshInstance3D=rig["hand_"+suffix].get_node("Fingers")
			hand_mesh.mesh=_cached(role+"_hand_"+suffix+("_grip" if gripping else ""),func():return Sculpt.hand(role,side,gripping))
		person.set_meta("grip_state",grip_state)
	if loaded:
		var kind: String=cargo_kind
		if kind not in ["wood","stone","food","grapes","wine","trunks","corn","flour","loaves","gold","axe","bow"]:kind="food"
		if person.get_meta("cargo_kind")!=kind:
			rig.cargo_mesh.mesh=_cached("cargo_"+kind,func():return _cargo(kind));person.set_meta("cargo_kind",kind)
		cargo.rotation.z=wave*0.009 if walking else 0.0
		var width: float=0.15 if kind=="wine" else 0.225
		for side: int in [-1,1]:_arm_ik(rig,side,Vector3(float(side)*width,0.20,-0.31),Vector3(float(side)*0.52,0.19,-0.13))
	elif working and not walking:
		var stroke: float=pow((wave+1.0)*0.5,2.0)
		if role in ["resident","servant"]:
			for side: int in [-1,1]:_arm_ik(rig,side,Vector3(float(side)*0.17,0.12+wave*0.03,-0.34),Vector3(float(side)*0.45,0.16,-0.07))
			body.rotation.x=-0.065
		elif role in ["lumberjack","farmer"]:
			var a:=Vector3(0.18,0.14+stroke*0.42,-0.30+stroke*0.08)
			var b:=Vector3(-0.04,0.02+stroke*0.27,-0.48+stroke*0.10)
			_arm_ik(rig,1,a,Vector3(0.49,0.20,-0.1));_arm_ik(rig,-1,b,Vector3(-0.47,0.10,-0.1))
			body.rotation.x=-0.13+(stroke*0.09);body.rotation.y=wave*0.075
			rig.head.rotation.x=-0.1
		elif role=="instructor":
			_arm_ik(rig,1,Vector3(0.22,0.35+wave*0.04,-0.31),Vector3(0.47,0.17,-0.12))
		else:
			_arm_ik(rig,1,Vector3(0.15,0.14+stroke*0.37,-0.32+stroke*0.03),Vector3(0.47,0.21,-0.14))
			_arm_ik(rig,-1,Vector3(-0.14,0.04,-0.40),Vector3(-0.43,0.1,-0.12))
			body.rotation.x=-0.10+stroke*0.06;rig.head.rotation.x=-0.12
	elif not walking:
		# Relaxed contrapposto with elbows and wrists bent, shoulders asymmetric.
		var loosen:float=float(rest.hand) if waiting else 0.0
		_arm_ik(rig,-1,Vector3(-0.22,0.08+loosen*0.008,-0.18),Vector3(-0.48,0.20,-0.05))
		_arm_ik(rig,1,Vector3(0.285,-0.055-loosen*0.006,-0.095+loosen*0.008),Vector3(0.37,0.17,-0.03))
	if not loaded and role=="instructor":_arm_ik(rig,-1,Vector3(-0.345,0.13,-0.276),Vector3(-0.49,0.23,-0.05))
	if tool.visible:
		var wrist: Transform3D=rig.arm_R.transform*rig.elbow_R.transform*rig.hand_R.transform
		tool.position=wrist*Vector3(0,-0.068,-0.013)
		tool.basis=wrist.basis*Basis.from_euler(Vector3(-0.10,0,-0.18))
		if working and not walking and role in ["builder","stonecutter","vintner"]:
			var strike: float=pow((wave+1.0)*0.5,2.0)
			tool.basis=Basis.from_euler(Vector3(lerpf(-1.0,0.15,strike),0,-0.15))
		if working and role in ["lumberjack","farmer"]:
			var other: Transform3D=rig.arm_L.transform*rig.elbow_L.transform*rig.hand_L.transform
			var other_grip:=other*Vector3(0,-0.068,-0.013)
			tool.basis=Basis(Quaternion(Vector3.UP,(tool.position-other_grip).normalized()))

## Pure animation-time sampling: no wall clock or shared RNG. A paused World
## repeats its phase, so all waiting joints freeze exactly, including across LODs.
## At the current CIVIL_PACE, World advances idle phase by 3.2 rad/s in 1x.
static func _rest_variation(id:int,phase:float)->Dictionary:
	var seed:float=float((id*73+19)%251)/251.0
	var second_seed:float=float((id*137+47)%257)/257.0
	var time:float=phase/3.2
	var breath:float=sin(time*TAU/lerpf(3.6,5.2,seed)+second_seed*TAU)
	# Long holds with eased transfers read as a change of support, not swaying.
	var support_cycle:float=fposmod(time/lerpf(10.0,15.0,second_seed)+seed,1.0)
	var support:float=1.0
	if support_cycle<0.18:support=lerpf(-1.0,1.0,_ease_swing(support_cycle/0.18))
	elif support_cycle>0.50 and support_cycle<0.68:support=lerpf(1.0,-1.0,_ease_swing((support_cycle-0.50)/0.18))
	elif support_cycle>=0.68:support=-1.0
	var look_time:float=time/lerpf(9.0,14.0,seed)+second_seed
	var look_cycle:float=fposmod(look_time,1.0)
	var look_strength:float=0.0
	# Most of a cycle is still; turn, briefly observe, then settle back.
	if look_cycle>=0.43 and look_cycle<0.57:look_strength=_ease_swing((look_cycle-0.43)/0.14)
	elif look_cycle>=0.57 and look_cycle<0.70:look_strength=1.0
	elif look_cycle>=0.70 and look_cycle<0.84:look_strength=1.0-_ease_swing((look_cycle-0.70)/0.14)
	var direction:float=-1.0 if (id+int(floor(look_time)))%2==0 else 1.0
	var look:float=look_strength*direction*lerpf(0.72,1.0,second_seed)
	return {"breath":breath,"support":support,"look":look,"look_strength":look_strength,"hand":sin(time*0.58+seed*TAU)*0.55+breath*0.20}

## The canonical sole targets are independent of the moving pelvis and breath.
## Re-solve both legs against those targets; retain full-sole terrain probing at
## bridge lips, but never drag a planted foot sideways with the weight transfer.
static func _idle_support(person:Node3D,rig:Dictionary,query:Callable,pelvis_x:float)->Dictionary:
	var root_transform:Transform3D=person.global_transform if person.is_inside_tree() else person.transform
	var targets:Dictionary={};var orientations:Dictionary={};var hip_height:float=rig.hip_L.position.y
	for side:int in [-1,1]:
		var suffix:String="L" if side<0 else "R"
		var foot:MeshInstance3D=rig["ankle_"+suffix].get_node("Boot")
		var canonical:Transform3D=rig["hip_"+suffix].transform*rig["knee_"+suffix].transform*rig["ankle_"+suffix].transform
		var target:Vector3=canonical.origin
		target.y=_sole_ground_target(query,root_transform,target,canonical.basis,foot.mesh.get_aabb()) if query.is_valid() else -_box_min_y(foot.mesh.get_aabb(),canonical.basis)+SOLE_CLEARANCE
		targets[suffix]=target;orientations[suffix]=canonical.basis
		var horizontal:float=Vector2(target.x-float(side)*0.112-pelvis_x,target.z).length()
		hip_height=minf(hip_height,target.y+sqrt(maxf(0.0001,LEG_REACH*LEG_REACH-horizontal*horizontal)))
	for side:int in [-1,1]:
		var suffix:String="L" if side<0 else "R"
		_leg_ik(rig,side,hip_height,targets[suffix],orientations[suffix],pelvis_x)
	var left:Vector3=rig.hip_L.basis*Vector3(0,-0.35,0)
	var right:Vector3=rig.hip_R.basis*Vector3(0,-0.35,0)
	return {"hip_height":hip_height,"cloth_stride":(left.z-right.z)/0.28,"cloth_forward":(left.z+right.z)*0.5}

## Deterministic stride trajectory plus live world anchors during support.
## The swing is bounded between toe-off and touchdown; no future position is guessed.
static func _walk_pose(person: Node3D,rig: Dictionary,phase: float,loaded: bool) -> Dictionary:
	var root_transform: Transform3D=person.global_transform if person.is_inside_tree() else person.transform
	var inverse_root:=root_transform.affine_inverse()
	var ground_query:Callable=person.get_meta("ground_height",Callable())
	var scale_z:=maxf(0.01,root_transform.basis.z.length())
	var gain: float=CARRY_RADIANS_PER_METER if loaded else WALK_RADIANS_PER_METER
	var cycle_length: float=TAU/(gain*scale_z)
	var span: float=cycle_length*STANCE_FRACTION
	var half_span: float=span*0.5
	var state: Dictionary=person.get_meta("gait_state",{})
	var reset: bool=state.is_empty() or not bool(state.get("walking",false)) or bool(state.get("loaded",loaded))!=loaded
	if not reset:
		var phase_delta: float=phase-float(state.last_phase)
		reset=phase_delta < -0.00001 or phase_delta > PI
	if reset:state={"walking":true,"loaded":loaded,"last_phase":phase,"feet":{},"replants":0}
	var targets: Dictionary={};var orientations: Dictionary={};var supports: Dictionary={}
	for side: int in [-1,1]:
		var suffix: String="L" if side<0 else "R"
		var foot: MeshInstance3D=rig["ankle_"+suffix].get_node("Boot")
		var box:=foot.mesh.get_aabb()
		var angle: float=phase+(PI if side<0 else 0.0)
		var cycle: int=int(floor(angle/TAU));var u:=fposmod(angle,TAU)/TAU
		var stance:=u<STANCE_FRACTION
		var t:=clampf((u-STANCE_FRACTION)/(1.0-STANCE_FRACTION),0.0,1.0)
		var toe_pitch: float=0.16*sin(t*PI) if not stance else 0.0
		var rotation:=Basis.from_euler(Vector3(toe_pitch,0,0))
		var ground_height: float=-_box_min_y(box,rotation)+SOLE_CLEARANCE
		var z: float=-half_span+cycle_length*u if stance else lerpf(half_span,-half_span,_ease_swing(t))
		var lift: float=(0.085 if loaded else 0.11)*pow(sin(t*PI),2.0) if not stance else 0.0
		var planned:=Vector3(float(side)*0.112,ground_height+lift,z)
		var target:=planned
		var record: Dictionary=state.feet.get(suffix,{})
		if stance:
			if record.is_empty() or not bool(record.get("stance",false)) or int(record.get("cycle",cycle-1))!=cycle:
				record={"stance":true,"cycle":cycle,"anchor":root_transform*planned,"basis":root_transform.basis}
			target=inverse_root*Vector3(record.anchor)
			# Anchors are only retained inside a leg's safe step envelope. Large
			# teleports/sharp pivots trigger a new contact instead of stretching bones.
			var horizontal:=Vector2(target.x-float(side)*0.112,target.z)
			if horizontal.length()>0.35 or target.x*float(side)<0.025:
				target=planned;record.anchor=root_transform*planned;record.basis=root_transform.basis;state.replants=int(state.replants)+1
			rotation=root_transform.basis.inverse()*Basis(record.basis)
			# With a terrain provider, the trailing foot may stay below the root
			# plane as the body steps onto a bridge. Keep its X/Z contact fixed.
			if ground_query.is_valid():
				target.y=_sole_ground_target(ground_query,root_transform,target,rotation,box)
				var contact:Vector3=root_transform*target
				record.anchor=Vector3(record.anchor.x,contact.y,record.anchor.z)
			else:target.y=maxf(target.y,-_box_min_y(box,rotation)+SOLE_CLEARANCE)
		else:
			record={"stance":false,"cycle":cycle}
			if ground_query.is_valid():target.y=_sole_ground_target(ground_query,root_transform,target,rotation,box)+lift
		state.feet[suffix]=record;targets[suffix]=target;orientations[suffix]=rotation;supports[suffix]=stance
	# Solve a common pelvis height from both reach limits. It rises over the
	# supporting leg and lowers for long steps; bones keep their original length.
	var hip_height:=0.859
	for side: int in [-1,1]:
		var suffix: String="L" if side<0 else "R";var target: Vector3=targets[suffix]
		var horizontal: float=Vector2(target.x-float(side)*0.112,target.z).length()
		var allowed: float=target.y+sqrt(maxf(0.0001,LEG_REACH*LEG_REACH-horizontal*horizontal))
		hip_height=minf(hip_height,allowed)
	for side: int in [-1,1]:
		var suffix: String="L" if side<0 else "R"
		_leg_ik(rig,side,hip_height,targets[suffix],orientations[suffix])
	state.walking=true;state.loaded=loaded;state.last_phase=phase;state.supports=supports;state.targets=targets;state.hip_height=hip_height
	person.set_meta("gait_state",state)
	# The hem follows the thighs, not the ankles: a swinging knee can advance
	# while its foot is still behind. Keeping that distinction avoids trousers
	# passing through an apron or coat during the recovery phase.
	var thigh_left: Vector3=rig.hip_L.basis*Vector3(0,-0.35,0)
	var thigh_right: Vector3=rig.hip_R.basis*Vector3(0,-0.35,0)
	return {"hip_height":hip_height,"cloth_stride":(thigh_left.z-thigh_right.z)/0.28,"cloth_forward":(thigh_left.z+thigh_right.z)*0.5}

static func _stand_on_terrain(person:Node3D,rig:Dictionary,query:Callable)->Dictionary:
	var root_transform:Transform3D=person.global_transform if person.is_inside_tree() else person.transform
	var targets:Dictionary={};var orientations:Dictionary={};var hip_height:float=rig.hip_L.position.y
	for side:int in [-1,1]:
		var suffix:String="L" if side<0 else "R"
		var foot:MeshInstance3D=rig["ankle_"+suffix].get_node("Boot")
		var foot_transform:Transform3D=rig["hip_"+suffix].transform*rig["knee_"+suffix].transform*rig["ankle_"+suffix].transform
		var target:Vector3=foot_transform.origin
		target.y=_sole_ground_target(query,root_transform,target,foot_transform.basis,foot.mesh.get_aabb())
		targets[suffix]=target;orientations[suffix]=foot_transform.basis
		var horizontal:float=Vector2(target.x-float(side)*0.112,target.z).length()
		hip_height=minf(hip_height,target.y+sqrt(maxf(0.0001,LEG_REACH*LEG_REACH-horizontal*horizontal)))
	for side:int in [-1,1]:
		var suffix:String="L" if side<0 else "R"
		_leg_ik(rig,side,hip_height,targets[suffix],orientations[suffix])
	var left:Vector3=rig.hip_L.basis*Vector3(0,-0.35,0)
	var right:Vector3=rig.hip_R.basis*Vector3(0,-0.35,0)
	return {"hip_height":hip_height,"cloth_stride":(left.z-right.z)/0.28,"cloth_forward":(left.z+right.z)*0.5}

## Resolve the ankle from terrain under the full sole footprint, not the body.
## Nine probes include the extreme corners so rotated/wide boots catch step edges.
static func _sole_ground_target(query:Callable,root_transform:Transform3D,target:Vector3,foot_basis:Basis,box:AABB)->float:
	var vertical_scale:float=maxf(0.01,root_transform.basis.y.y)
	var required:float=-INF
	var foot_transform:=root_transform*Transform3D(foot_basis,target)
	for x:float in [box.position.x,box.get_center().x,box.end.x]:
		for z:float in [box.position.z,box.get_center().z,box.end.z]:
			var point:Vector3=foot_transform*Vector3(x,box.position.y,z)
			var height:float=float(query.call(point.x,point.z))
			if is_finite(height):required=maxf(required,target.y+(height+SOLE_CLEARANCE-point.y)/vertical_scale)
	return required if is_finite(required) else target.y

static func _ease_swing(t: float) -> float:
	# Quintic ease has zero endpoint velocity/acceleration and never overshoots.
	return t*t*t*(t*(t*6.0-15.0)+10.0)

static func _box_min_y(box: AABB,rotation: Basis) -> float:
	var center:=box.get_center();var extent:=box.size*0.5
	return (rotation*center).y-absf(rotation.x.y)*extent.x-absf(rotation.y.y)*extent.y-absf(rotation.z.y)*extent.z

static func _leg_ik(rig: Dictionary,side: int,hip_height: float,target: Vector3,foot_basis: Basis,pelvis_x:float=0.0) -> void:
	var suffix: String="L" if side<0 else "R"
	var hip: Node3D=rig["hip_"+suffix];var knee: Node3D=rig["knee_"+suffix];var ankle: Node3D=rig["ankle_"+suffix]
	hip.position=Vector3(float(side)*0.112+pelvis_x,hip_height,0)
	var delta:=target-hip.position
	var distance:=clampf(delta.length(),0.035,THIGH_LENGTH+SHIN_LENGTH-0.0001)
	var direction:=delta.normalized()
	var along: float=(THIGH_LENGTH*THIGH_LENGTH+distance*distance-SHIN_LENGTH*SHIN_LENGTH)/(2.0*distance)
	var knee_offset:=sqrt(maxf(0.0,THIGH_LENGTH*THIGH_LENGTH-along*along))
	var forward:=Vector3.FORWARD-direction*Vector3.FORWARD.dot(direction)
	if forward.length_squared()<0.001:forward=Vector3.UP-direction*Vector3.UP.dot(direction)
	var bend:=hip.position+direction*along+forward.normalized()*knee_offset
	hip.basis=Basis(Quaternion(Vector3.DOWN,(bend-hip.position).normalized()))
	var shin_basis:=Basis(Quaternion(Vector3.DOWN,(target-bend).normalized()))
	knee.basis=hip.basis.inverse()*shin_basis
	ankle.basis=shin_basis.inverse()*foot_basis

## Two-bone arm solve in body space: hands genuinely reach loads and tools.
static func _arm_ik(rig: Dictionary,side: int,target: Vector3,pole: Vector3) -> void:
	var suffix: String="L" if side<0 else "R"
	var arm: Node3D=rig["arm_"+suffix];var elbow: Node3D=rig["elbow_"+suffix]
	var direction: Vector3=target-arm.position;var distance:=clampf(direction.length(),0.055,0.538);direction=direction.normalized()
	var along: float=(0.285*0.285-0.255*0.255+distance*distance)/(2*distance)
	var height:=sqrt(maxf(0,0.285*0.285-along*along))
	var outward: Vector3=pole-arm.position;outward=(outward-direction*outward.dot(direction)).normalized()
	var bend: Vector3=arm.position+direction*along+outward*height
	arm.basis=Basis(Quaternion(Vector3.DOWN,(bend-arm.position).normalized()))
	var forearm_basis:=Basis(Quaternion(Vector3.DOWN,(target-bend).normalized()))
	elbow.basis=arm.basis.inverse()*forearm_basis
	rig["hand_"+suffix].basis=Basis.IDENTITY

static func _joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node:=Node3D.new();node.name=label;node.position=at;parent.add_child(node);return node

static func _attach(parent: Node3D, label: String, mesh: ArrayMesh) -> void:
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;parent.add_child(node)

static func _cached(key: String, producer: Callable) -> ArrayMesh:
	var cache_key: String="%d:%s"%[_requested_quality,key]
	if not _meshes.has(cache_key):
		Sculpt.set_detail(_requested_quality)
		var mesh:=_merge(producer.call())
		for surface in range(mesh.get_surface_count()):
			var original: StandardMaterial3D=mesh.surface_get_material(surface)
			mesh.surface_set_material(surface,_garment_material(original,key.ends_with("_body")))
		_meshes[cache_key]=mesh
	return _meshes[cache_key]

## Change shared mesh resources without replacing the civilian or its animated rig.
## The caller should use distance hysteresis; switching every frame is unnecessary.
static func set_quality(person: Node3D, tier: int) -> void:
	if not is_instance_valid(person) or not person.has_meta("approved_rig"):return
	tier=clampi(tier,QUALITY_HIGH,QUALITY_DISTANT)
	if int(person.get_meta("quality",QUALITY_HIGH))==tier:return
	var replacement:=create(str(person.get_meta("role")),int(person.get_meta("id")),tier)
	_replace_meshes(replacement,person,replacement)
	person.set_meta("quality",tier);person.set_meta("grip_state","");person.set_meta("cargo_kind","")
	replacement.free()

static func _replace_meshes(source: Node,target_root: Node,source_root: Node) -> void:
	if source is MeshInstance3D and source.mesh!=null:
		var target: MeshInstance3D=target_root.get_node_or_null(source_root.get_path_to(source))
		if target!=null:target.mesh=source.mesh
	for child in source.get_children():_replace_meshes(child,target_root,source_root)

static func _garment_material(source: StandardMaterial3D, deforming: bool=false) -> ShaderMaterial:
	# GLES reserves sixteen global slots per geometry using instance uniforms.
	# Only Clothing deforms; head, limbs, props and cargo must use the rigid shader.
	var key: String=str(source.get_instance_id())+":"+str(deforming)
	if _garment_materials.has(key):return _garment_materials[key]
	if _garment_shader==null:
		_garment_shader=Shader.new()
		_garment_shader.code="""shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color;
uniform float surface_roughness = 0.85;
uniform float surface_metallic = 0.0;
uniform bool use_vertex_color = false;
uniform sampler2D surface_atlas : filter_linear_mipmap, repeat_disable;
uniform int surface_family = 0;
uniform bool has_atlas = false;
instance uniform float cloth_stride = 0.0;
instance uniform float cloth_forward = 0.0;
void vertex() {
    float lower = clamp((-VERTEX.y + 0.015) / 0.35, 0.0, 1.0);
    float side = clamp(VERTEX.x / 0.12, -1.0, 1.0);
    VERTEX.z += (cloth_forward - cloth_stride * side * 0.14) * lower;
}
void fragment() {
    vec3 vertex_tint = use_vertex_color ? COLOR.rgb : vec3(1.0);
    vec3 color = base_color.rgb * vertex_tint;
    // Mesh vertex colors carry linear values, including the medium/far palette.
    // Compatibility shaders receive source_color uniforms in sRGB output space.
    if (OUTPUT_IS_SRGB) {
        vec3 linear_base = mix(pow((base_color.rgb + vec3(0.055)) / 1.055, vec3(2.4)), base_color.rgb / 12.92, lessThanEqual(base_color.rgb, vec3(0.04045)));
        vec3 linear_color = max(linear_base * vertex_tint, vec3(0.0));
        color = mix(1.055 * pow(linear_color, vec3(1.0 / 2.4)) - vec3(0.055), linear_color * 12.92, lessThanEqual(linear_color, vec3(0.0031308)));
    }
    float modulation = 1.0;
    if (has_atlas && surface_family > 0) {
        vec2 origin = vec2(0.0);
        float amount = 0.65;
        vec2 repeat_uv = UV;
        if (surface_family == 2) { origin = vec2(0.5, 0.0); amount = 0.65; }
        else if (surface_family == 3) { origin = vec2(0.0, 0.5); amount = 1.15; }
        else if (surface_family == 4) { origin = vec2(0.5, 0.5); amount = 0.40; }
        vec2 atlas_uv = origin + vec2(0.002) + fract(repeat_uv) * 0.496;
        float surface_value = texture(surface_atlas, atlas_uv).r;
        modulation += (surface_value - 0.50) * amount;
        vec2 texel = vec2(1.0) / vec2(textureSize(surface_atlas, 0));
        float dx = texture(surface_atlas, atlas_uv + vec2(texel.x, 0.0)).r - surface_value;
        float dy = texture(surface_atlas, atlas_uv + vec2(0.0, texel.y)).r - surface_value;
        NORMAL_MAP = normalize(vec3(-dx * 2.0, -dy * 2.0, 1.0)) * 0.5 + 0.5;
        NORMAL_MAP_DEPTH = surface_family == 3 ? 0.22 : 0.10;
    }
    ALBEDO = color * modulation;
    ROUGHNESS = surface_roughness;
    METALLIC = surface_metallic;
    SPECULAR = 0.23;
}
"""
	if not deforming and _rigid_shader==null:
		_rigid_shader=Shader.new()
		_rigid_shader.code=_garment_shader.code.replace("instance uniform float cloth_stride = 0.0;","const float cloth_stride = 0.0;").replace("instance uniform float cloth_forward = 0.0;","const float cloth_forward = 0.0;")
	var material:=ShaderMaterial.new();material.shader=_garment_shader if deforming else _rigid_shader
	if _surface_atlas==null:
		if ResourceLoader.exists("res://assets/humans/surface-atlas.png"):
			_surface_atlas=load("res://assets/humans/surface-atlas.png")
		elif FileAccess.file_exists("res://assets/humans/surface-atlas.png"):
			var surface_image:=Image.load_from_file("res://assets/humans/surface-atlas.png");surface_image.generate_mipmaps();_surface_atlas=ImageTexture.create_from_image(surface_image)
	material.set_shader_parameter("surface_atlas",_surface_atlas)
	material.set_shader_parameter("has_atlas",_surface_atlas!=null)
	material.set_shader_parameter("surface_family",int(source.get_meta("surface_family",0)))
	material.set_shader_parameter("use_vertex_color",source.vertex_color_use_as_albedo)
	material.set_shader_parameter("base_color",source.albedo_color);material.set_shader_parameter("surface_roughness",source.roughness);material.set_shader_parameter("surface_metallic",source.metallic)
	_garment_materials[key]=material
	return material

static func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key):return _materials[key]
	var colors: Dictionary={
		"cloth":"315e59","cloth_light":"397d72","linen_light":"e4d7b9","trouser_light":"665440","skin_brown":"9c684c","skin_fair":"c9946c","skin_shadow":"9c6349","hair_red":"87442d","hair_red_light":"ab5b38","iris":"635c38","leather_light":"916a44","stitch":"bd9e6d","gold_thread":"c19b53","scarf":"913f35","straw":"b99962","cloth_dark":"244b48","linen":"dacbab","wrap":"b8aa88","trouser":"514232","stone":"929184",
		"leather":"775033","leather_dark":"4f3525","sole":"342a21","wood":"98673f",
		"wood_end":"bd9562","metal":"85867b","gold":"b68d47","skin":"b7835b",
		"skin_warm":"cf996d","hair":"68452e","hair_light":"885d3d","hair_dark":"292923",
		"eye":"e1d5be","pupil":"211e17","lip":"7b493b","hair_brow":"3b291e","linen_shadow":"aa9676","slate":"39403b",
		"chalk":"cfcbb7","purple":"6a4054","green":"6e7750","bread":"c19357"
	}
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false
	mat.albedo_color=Color(colors.get(key,"ffffff"))
	mat.set_meta("surface_family",_surface_family(key))
	mat.roughness=0.92 if key.begins_with("cloth") or key in ["linen","wrap","trouser","stone"] else 0.64
	mat.metallic_specular=0.23
	if key.begins_with("skin"):
		mat.roughness=0.78;mat.metallic_specular=0.20
	if key.begins_with("hair"):mat.roughness=0.73
	if key.begins_with("leather"):mat.roughness=0.68
	if key in ["metal","gold"]:
		mat.roughness=0.38;mat.metallic=0.72;mat.metallic_specular=0.45
	if key in ["wood","wood_end"]:mat.roughness=0.82
	if key.begins_with("cloth") or key in ["linen","wrap","trouser"]:
		if _fabric_texture==null:
			var noise:=FastNoiseLite.new();noise.seed=441;noise.frequency=0.13;noise.fractal_octaves=2
			var ramp:=Gradient.new();ramp.colors=PackedColorArray([Color(0.97,0.97,0.97),Color.WHITE])
			_fabric_texture=NoiseTexture2D.new();_fabric_texture.width=128;_fabric_texture.height=128;_fabric_texture.noise=noise;_fabric_texture.color_ramp=ramp;_fabric_texture.seamless=true
			_fabric_normal=NoiseTexture2D.new();_fabric_normal.width=128;_fabric_normal.height=128;_fabric_normal.noise=noise;_fabric_normal.seamless=true;_fabric_normal.as_normal_map=true;_fabric_normal.bump_strength=1.2
		mat.albedo_texture=_fabric_texture;mat.normal_enabled=true;mat.normal_texture=_fabric_normal;mat.normal_scale=0.035
	_materials[key]=mat
	return mat

static func _add(parts: Array, mesh: Mesh, at: Vector3, material: String, scale: Vector3=Vector3.ONE, rotation: Vector3=Vector3.ZERO) -> void:
	parts.append({"mesh":mesh,"at":Transform3D(Basis.from_euler(rotation).scaled(scale),at),"material":material})

static func _oval(parts: Array, at: Vector3, size: Vector3, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	if not _spheres.has(_requested_quality):
		var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=[20,12,6][_requested_quality];sphere.rings=[12,6,3][_requested_quality];_spheres[_requested_quality]=sphere
	_sphere=_spheres[_requested_quality]
	_add(parts,_sphere,at,material,size,rotation)

static func _box(parts: Array, at: Vector3, size: Vector3, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	var mesh:=BoxMesh.new();mesh.size=size;_add(parts,mesh,at,material,Vector3.ONE,rotation)

static func _cylinder(parts: Array, at: Vector3, radius: float, height: float, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=[20,12,8][_requested_quality]
	_add(parts,mesh,at,material,Vector3.ONE,rotation)

static func _line(parts: Array, a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=[8,6,4][_requested_quality]
	var up: Vector3=(b-a).normalized()
	var side:=up.cross(Vector3.FORWARD).normalized()
	if side.length_squared()<0.1:side=Vector3.RIGHT
	var basis:=Basis(side,up,side.cross(up).normalized())
	parts.append({"mesh":mesh,"at":Transform3D(basis,(a+b)*0.5),"material":material})

## Closed elliptical lofts use UV seams, smooth normals and real cloth folds.
## Ring = (height, half width, half depth, depth offset). Front is -Z.
static func _loft(rings: Array, folds: float=0.0, gap: float=0.0) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int=[32,16,8][_requested_quality]
	for row: int in range(rings.size()-1):
		for col: int in range(sides):
			var points: Array[Vector3]=[]
			var uvs: Array[Vector2]=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var r: Vector4=rings[pair.x]
				var u:=float(pair.y)/float(sides)
				var v:=float(pair.x)/float(rings.size()-1)
				var angle: float=-PI*0.5+gap+u*(TAU-gap*2.0)
				var ripple: float=1.0+folds*(sin(angle*8.0+v*3.4)+0.4*sin(angle*13.0-v*2.0))*sin(v*PI)
				points.append(Vector3(cos(angle)*r.y*ripple,r.x,sin(angle)*r.z*ripple+r.w))
				uvs.append(Vector2(u,v))
			for index: int in [0,2,1,0,3,2]:
				st.set_smooth_group(0);st.set_uv(uvs[index]);st.add_vertex(points[index])
	if is_zero_approx(gap):
		for cap: int in [0,rings.size()-1]:
			var r: Vector4=rings[cap]
			for col: int in range(sides):
				var a: float=-PI*0.5+float(col)*TAU/float(sides)
				var b: float=-PI*0.5+float(col+1)*TAU/float(sides)
				var points: Array[Vector3]=[Vector3(0,r.x,r.w),Vector3(cos(a)*r.y,r.x,sin(a)*r.z+r.w),Vector3(cos(b)*r.y,r.x,sin(b)*r.z+r.w)]
				for index: int in ([0,1,2] if cap==0 else [0,2,1]):
					st.set_smooth_group(-1);st.set_uv(Vector2(points[index].x,points[index].z));st.add_vertex(points[index])
	st.generate_normals();st.index();st.generate_tangents();return st.commit()

static func _board() -> Array:
	var p: Array=[]
	_box(p,Vector3.ZERO,Vector3(0.265,0.34,0.023),"slate")
	for side: int in [-1,1]:
		_box(p,Vector3(float(side)*0.13,0,-0.003),Vector3(0.02,0.36,0.034),"wood")
		_box(p,Vector3(0,float(side)*0.167,-0.003),Vector3(0.27,0.02,0.034),"wood")
	for x: float in ([-0.073,0.057] if _requested_quality==0 else [0.0]):
		for edge: Array in [[Vector2(-0.033,-0.018),Vector2(0,0.017)],[Vector2(0,0.017),Vector2(0.033,-0.018)],[Vector2(-0.026,-0.013),Vector2(-0.026,-0.079)],[Vector2(0.026,-0.013),Vector2(0.026,-0.079)],[Vector2(-0.026,-0.079),Vector2(0.026,-0.079)]]:
			_line(p,Vector3(x+edge[0].x,edge[0].y,-0.015),Vector3(x+edge[1].x,edge[1].y,-0.015),0.002,"chalk")
		_line(p,Vector3(x,0.06,-0.015),Vector3(x,0.115,-0.015),0.002,"chalk")
		_line(p,Vector3(x-0.021,0.112,-0.015),Vector3(x+0.021,0.112,-0.015),0.003,"chalk")
	return p

static func _cargo(kind: String) -> Array:
	var p: Array=[]
	match kind:
		"wood":
			for i in range(3):
				var pos:=Vector3(0,-0.01+float(i/2)*0.087,(float(i%2)-0.5)*0.11)
				_cylinder(p,pos,0.053,0.48,"wood",Vector3(0,0,PI*0.5))
				for side: int in [-1,1]:_cylinder(p,pos+Vector3(float(side)*0.241,0,0),0.049,0.003,"wood_end",Vector3(0,0,PI*0.5))
			for x: float in [-0.13,0.13]:_line(p,Vector3(x,-0.065,-0.1),Vector3(x,0.11,-0.10),0.005,"leather_dark")
		"stone":
			_box(p,Vector3(0,-0.04,0),Vector3(0.42,0.025,0.27),"wood")
			for i in range(3):_box(p,Vector3((float(i%2)-0.5)*0.16,float(i/2)*0.083,0),Vector3(0.153,0.082,0.19),"stone",Vector3(0,float(i)*0.1,0))
		"wine":
			_add(p,_loft([Vector4(-0.13,0.105,0.105,0),Vector4(-0.11,0.12,0.12,0),Vector4(0,0.132,0.132,0),Vector4(0.11,0.12,0.12,0),Vector4(0.13,0.105,0.105,0)]),Vector3.ZERO,"wood")
			for y: float in [-0.10,0.1]:_add(p,_loft([Vector4(y,0.125,0.125,0),Vector4(y+0.016,0.125,0.125,0)]),Vector3.ZERO,"metal")
		"trunks":
			for i in range(2):
				var pos:=Vector3(0,0.02+float(i)*0.09,(float(i)-0.5)*0.08)
				_cylinder(p,pos,0.07,0.52,"wood",Vector3(0,0,PI*0.5))
				for side: int in [-1,1]:_cylinder(p,pos+Vector3(float(side)*0.26,0,0),0.066,0.004,"wood_end",Vector3(0,0,PI*0.5))
			for x: float in [-0.11,0.11]:_line(p,Vector3(x,-0.06,-0.12),Vector3(x,0.16,-0.10),0.006,"leather_dark")
		"corn":
			_add(p,_loft([Vector4(-0.12,0.17,0.11,0),Vector4(-0.105,0.19,0.125,0),Vector4(0.027,0.22,0.145,0)]),Vector3.ZERO,"wood")
			for i in range(6):_oval(p,Vector3((float(i%3)-1.0)*0.09,0.04+float(i/3)*0.05,(float(i%2)-0.5)*0.08),Vector3(0.055,0.09,0.04),"gold",Vector3(0.4,0.2*float(i),0.15))
		"flour":
			_add(p,_loft([Vector4(-0.12,0.17,0.11,0),Vector4(-0.105,0.19,0.125,0),Vector4(0.027,0.22,0.145,0)]),Vector3.ZERO,"wood")
			for i in range(2):
				_oval(p,Vector3((float(i)-0.5)*0.12,0.06,0.0),Vector3(0.09,0.11,0.07),"chalk")
				_cylinder(p,Vector3((float(i)-0.5)*0.12,0.16,0.0),0.03,0.03,"linen")
		"loaves":
			_add(p,_loft([Vector4(-0.12,0.17,0.11,0),Vector4(-0.105,0.19,0.125,0),Vector4(0.027,0.22,0.145,0)]),Vector3.ZERO,"wood")
			for i in range(5):_oval(p,Vector3((float(i%3)-1.0)*0.08,0.03+float(i/3)*0.045,(float(i%2)-0.5)*0.07),Vector3(0.06,0.04,0.10),"bread",Vector3(0,0.12*float(i),0.08))
		"gold":
			_box(p,Vector3(0,-0.05,0),Vector3(0.36,0.03,0.22),"wood")
			for i in range(4):_box(p,Vector3((float(i%2)-0.5)*0.12,0.02+float(i/2)*0.045,0),Vector3(0.11,0.04,0.16),"gold")
		"axe":
			_box(p,Vector3(0,-0.03,0),Vector3(0.34,0.08,0.22),"wood")
			for i in range(2):
				_box(p,Vector3((float(i)-0.5)*0.11,0.06,0.0),Vector3(0.04,0.16,0.04),"wood")
				_box(p,Vector3((float(i)-0.5)*0.11,0.16,0.06),Vector3(0.10,0.04,0.14),"metal")
		"bow":
			_box(p,Vector3(0,-0.03,0),Vector3(0.30,0.06,0.20),"wood")
			for i in range(2):
				_cylinder(p,Vector3((float(i)-0.5)*0.08,0.08,0.0),0.018,0.28,"wood",Vector3(0,0,0.35 if i==0 else -0.35))
				_line(p,Vector3((float(i)-0.5)*0.08,0.20,-0.04),Vector3((float(i)-0.5)*0.08,-0.04,0.04),0.004,"leather_dark")
		_:
			_add(p,_loft([Vector4(-0.12,0.17,0.11,0),Vector4(-0.105,0.19,0.125,0),Vector4(0.027,0.22,0.145,0)]),Vector3.ZERO,"wood")
			for y: float in [-0.105,-0.079,-0.053,-0.027,0.0,0.023]:_add(p,_loft([Vector4(y,0.215,0.14,0),Vector4(y+0.008,0.216,0.141,0)]),Vector3.ZERO,"wood_end")
			if kind=="grapes":
				for i in range(10):_oval(p,Vector3((float(i%4)-1.5)*0.079,0.043+float(i/4)*0.033,(float(i%3)-1)*0.069),Vector3.ONE*0.042,"purple")
			else:
				for i in range(4):_oval(p,Vector3((float(i%2)-0.5)*0.13,0.025,(float(i/2)-0.5)*0.12),Vector3(0.07,0.052,0.12),"bread",Vector3(0,0.1*float(i),0))
	return p

## Pack LOD colors into vertices while retaining broad PBR material families.
## The high-detail cache is untouched; distant subpixel color accents share draws.
static func _palette_key(original: String) -> String:
	if original in ["metal","gold"]:return "metal"
	if _requested_quality==QUALITY_DISTANT:return "matte"
	if original.begins_with("skin") or original in ["eye","iris","pupil","lip"]:return "skin"
	if original.begins_with("hair"):return "hair"
	if original.begins_with("leather") or original=="sole":return "leather"
	if original.begins_with("wood"):return "wood"
	return "fabric"

static func _surface_family(key: String) -> int:
	if key.begins_with("hair"):return 3
	if key.begins_with("leather") or key=="sole":return 2
	if key.begins_with("linen") or key=="wrap":return 4
	if key.begins_with("cloth") or key in ["fabric","trouser","trouser_light"]:return 1
	return 0

static func _palette_material(category: String) -> StandardMaterial3D:
	var key: String="palette_"+category
	if _materials.has(key):return _materials[key]
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color.WHITE;mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false;mat.metallic_specular=0.23
	mat.set_meta("surface_family",_surface_family(category))
	mat.roughness={"metal":0.38,"skin":0.78,"hair":0.73,"leather":0.68,"wood":0.82,"fabric":0.92,"matte":0.84}[category]
	if category=="metal":mat.metallic=0.72;mat.metallic_specular=0.45
	_materials[key]=mat
	return mat

static func _merge(parts: Array) -> ArrayMesh:
	var groups: Dictionary={}
	for part: Dictionary in parts:
		var key: String=_palette_key(part.material) if _requested_quality>0 else str(part.material)
		var record: Dictionary=part.duplicate()
		if _requested_quality>0:record.color=_material(part.material).albedo_color.srgb_to_linear()
		if not groups.has(key):groups[key]=[]
		groups[key].append(record)
	var result:=ArrayMesh.new()
	for key: String in groups:
		var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var tangents:=PackedFloat32Array();var indices:=PackedInt32Array();var colors:=PackedColorArray()
		for part: Dictionary in groups[key]:
			var mesh: Mesh=part.mesh;var transform: Transform3D=part.at
			var normal_basis:=transform.basis.inverse().transposed()
			for surface in range(mesh.get_surface_count()):
				var data:=mesh.surface_get_arrays(surface);var base:=vertices.size()
				var source_vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
				var source_normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
				var source_uvs: PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
				var source_tangents: PackedFloat32Array=data[Mesh.ARRAY_TANGENT] if data[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
				var source_colors: PackedColorArray=data[Mesh.ARRAY_COLOR] if data[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
				for i in range(source_vertices.size()):
					var tint:=source_colors[i] if i<source_colors.size() else Color.WHITE
					colors.append(tint*part.color if _requested_quality>0 else tint)
					vertices.append(transform*source_vertices[i]);normals.append((normal_basis*source_normals[i]).normalized());uvs.append(source_uvs[i] if i<source_uvs.size() else Vector2.ZERO)
					var tangent:=Vector3.RIGHT;var handedness:=1.0
					if source_tangents.size()>i*4+3:
						tangent=Vector3(source_tangents[i*4],source_tangents[i*4+1],source_tangents[i*4+2]);handedness=source_tangents[i*4+3]
					else:
						tangent=source_normals[i].cross(Vector3.UP).normalized()
						if tangent.length_squared()<0.1:tangent=Vector3.RIGHT
					tangent=(transform.basis*tangent).normalized()
					tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,handedness]))
				var source_indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
				if source_indices.is_empty():
					for i in range(source_vertices.size()):indices.append(base+i)
				else:
					for i in source_indices:indices.append(base+i)
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TANGENT]=tangents;arrays[Mesh.ARRAY_INDEX]=indices
		arrays[Mesh.ARRAY_COLOR]=colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,_palette_material(key) if _requested_quality>0 else _material(key))
	return result
