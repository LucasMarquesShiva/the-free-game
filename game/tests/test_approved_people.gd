extends SceneTree
const People = preload("res://presentation/approved_people.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: ",message)

func collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child in node.get_children(): collect(child,result)

func world_bounds(person: Node3D) -> AABB:
	var nodes: Array[MeshInstance3D]=[]
	collect(person,nodes)
	var minimum:=Vector3.INF;var maximum:=-Vector3.INF
	for node in nodes:
		if not node.is_visible_in_tree():continue
		var box:=node.mesh.get_aabb()
		for i in range(8):
			var point:Vector3=node.global_transform*box.get_endpoint(i)
			minimum=minimum.min(point);maximum=maximum.max(point)
	return AABB(minimum,maximum-minimum)

func verify_walk(person: Node3D) -> void:
	var rig:Dictionary=person.get_meta("approved_rig")
	var distance:=0.0;var swing_seen:=false;var previous:Dictionary={}
	for frame in range(36):
		distance+=2.0/30.0;person.position.z=-distance
		People.animate(person,distance*People.WALK_RADIANS_PER_METER,true,false,false)
		var state:Dictionary=person.get_meta("gait_state")
		var supporting:=0
		for side:String in ["L","R"]:
			var record:Dictionary=state.feet[side]
			var hip:Node3D=rig["hip_"+side];var knee:Node3D=rig["knee_"+side];var ankle:Node3D=rig["ankle_"+side]
			expect(is_equal_approx(knee.position.length(),People.THIGH_LENGTH),"IK preserves thigh length")
			expect(is_equal_approx(ankle.position.length(),People.SHIN_LENGTH),"IK preserves shin length")
			expect(absf(hip.basis.determinant()-1.0)<0.0001,"IK uses rotation without bone scale")
			if record.stance:
				supporting+=1
				if previous.has(side) and previous[side].stance and previous[side].cycle==record.cycle:
					expect(ankle.global_position.distance_to(previous[side].position)<0.001,"support foot stays planted while root advances")
			else:swing_seen=true
			previous[side]={"stance":record.stance,"cycle":record.cycle,"position":ankle.global_position}
		expect(supporting>=1,"walking always has a support foot")
	expect(swing_seen,"walking includes a swing phase")
	person.position=Vector3.ZERO

func run() -> void:
	for role: String in People.APPROVED:
		var person: Node3D=People.create(role,1)
		root.add_child(person)
		var nodes: Array[MeshInstance3D]=[]
		collect(person,nodes)
		expect(nodes.size()<=20,role+" mesh count")
		var minimum:=Vector3.INF;var maximum:=-Vector3.INF;var triangles:=0
		for node in nodes:
			for surface in range(node.mesh.get_surface_count()):
				var arrays:=node.mesh.surface_get_arrays(surface)
				expect(arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_NORMAL].size(),"surface normals")
				expect(arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_TEX_UV].size(),"surface UVs")
				expect(node.mesh.surface_get_material(surface)!=null,"surface material")
				triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var p: Vector3=node.global_transform*vertex
					minimum=minimum.min(p);maximum=maximum.max(p)
			expect(node.mesh.get_aabb().size.length()>0,"nonempty mesh")
		expect(maximum.y>1.70 and maximum.y<1.82,role+" adult height")
		expect(minimum.y>-0.01,role+" grounded feet")
		var rig: Dictionary=person.get_meta("approved_rig")
		verify_walk(person)
		for item: String in ["wood","stone","food","grapes","wine","trunks","corn","flour","loaves","gold","axe","bow"]:
			People.animate(person,0.8,true,false,true,item)
			expect(rig.cargo.visible and not rig.tool.visible,"visible cargo hidden tool")
			expect(rig.cargo_mesh.mesh!=null and person.get_meta("cargo_kind")==item,"resource-specific cargo")
		People.animate(person,0.2,false,true,false)
		var first_hand:Vector3=rig.hand_R.global_position
		var first_tool:Vector3=rig.tool.global_position
		People.animate(person,2.1,false,true,false)
		expect(not rig.cargo.visible,"unloaded work hides cargo")
		expect(rig.tool.visible==(role not in ["resident","servant"]),"work uses a tool only for equipped professions")
		expect(rig.hand_R.global_position.distance_to(first_hand)>0.012,"working hands move visibly across a work cycle")
		if rig.tool.visible:expect(rig.tool.global_position.distance_to(first_tool)>0.012,"working tool moves with the hand")
		var copy: Node3D=People.create(role,2)
		expect(copy.get_node("Body/Clothing").mesh==person.get_node("Body/Clothing").mesh,"shared meshes")
		copy.free()
		People.animate(person,0.0,false,false,false)
		var high_bounds:=world_bounds(person);var original_scale:=person.scale
		for tier in [1,2,0]:
			People.set_quality(person,tier)
			People.animate(person,0.0,false,false,false)
			var lod_bounds:=world_bounds(person)
			expect(person.scale.is_equal_approx(original_scale),"LOD preserves role scale")
			expect(absf(lod_bounds.size.y-high_bounds.size.y)<0.025,"LOD preserves adult height within2.5cm")
			expect(absf(lod_bounds.position.y-high_bounds.position.y)<0.015,"LOD preserves contact height within1.5cm")
		print("APPROVED_PERSON ",role," meshes=",nodes.size()," triangles=",triangles," height=",maximum.y-minimum.y)
		person.free()
	var fallback: Node3D=People.create("unknown_profession",99)
	expect(fallback.get_meta("role")=="resident","unknown profession uses resident fallback")
	expect(fallback.scale.is_equal_approx(Vector3.ONE),"fallback preserves normal adult scale")
	People.animate(fallback,1.0,true,false,true,"food")
	fallback.free()
	expect(People._material("skin")!=People._material("cloth"),"separate skin/cloth materials")
	expect(People._material("metal").metallic>0.5 and People._material("cloth").metallic==0,"metal is distinct")
	print("APPROVED_PEOPLE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
