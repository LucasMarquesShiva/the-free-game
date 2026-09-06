extends SceneTree
const People=preload("res://presentation/approved_people.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize():call_deferred("run")
func expect(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func meshes(node: Node,result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh!=null:result.append(node)
	for child in node.get_children():meshes(child,result)
func geometry(person: Node3D) -> Dictionary:
	var nodes: Array[MeshInstance3D]=[];meshes(person,nodes)
	var triangles:=0;var minimum:=Vector3.INF;var maximum:=-Vector3.INF
	for node in nodes:
		for surface in range(node.mesh.get_surface_count()):
			var arrays:=node.mesh.surface_get_arrays(surface);triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			expect(arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_NORMAL].size(),"LOD normals")
			expect(arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_TEX_UV].size(),"LOD UVs")
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var transformed:=node.global_transform*vertex;minimum=minimum.min(transformed);maximum=maximum.max(transformed)
	return {"triangles":triangles,"count":nodes.size(),"bounds":AABB(minimum,maximum-minimum)}
func run():
	for role: String in People.APPROVED:
		var tier_stats: Array=[]
		for tier in range(3):
			var person:=People.create(role,1,tier);root.add_child(person)
			var stats:=geometry(person);tier_stats.append(stats)
			expect(person.get_meta("quality")==tier,"quality metadata")
			expect(person.get_meta("reference")==People.Sculpt.REFERENCES[role],"LOD keeps source identity")
			expect(stats.count<=17,"LOD mesh count")
			if tier==1:expect(stats.triangles<=18500 and stats.triangles>=10000,"medium triangle budget: "+role)
			if tier==2:expect(stats.triangles<=6000 and stats.triangles>=3000,"distant triangle budget: "+role)
			for cargo: String in ["wood","food","wine","stone","grapes"]:
				People.animate(person,1.0,true,false,true,cargo)
				var rig: Dictionary=person.get_meta("approved_rig")
				expect(rig.cargo.visible and rig.cargo_mesh.mesh!=null,"LOD cargo is present")
			person.free()
		var high: AABB=tier_stats[0].bounds
		for tier in [1,2]:
			var lower: AABB=tier_stats[tier].bounds
			expect(absf(high.size.y-lower.size.y)<0.045,"LOD silhouette height: "+role)
			expect(absf(high.size.x-lower.size.x)<0.065,"LOD silhouette width: "+role)
			expect(tier_stats[tier].triangles<tier_stats[tier-1].triangles,"decreasing geometry")
		var active:=People.create(role,71);root.add_child(active);active.position=Vector3(3,0,6);active.rotation.y=0.37
		People.animate(active,1.15,true,false,true,"wood")
		var rig: Dictionary=active.get_meta("approved_rig");var original_body: Node3D=rig.body;var original_position:=active.position;var original_rotation:=active.rotation;var old_mesh: Mesh=active.get_node("Body/Clothing").mesh
		for tier in [1,2,0]:
			People.set_quality(active,tier)
			expect(active.get_meta("approved_rig").body==original_body,"switch preserves live rig")
			expect(active.position==original_position and active.rotation==original_rotation,"switch preserves world transform")
			expect(active.get_meta("role")==role and active.get_meta("id")==71,"switch preserves identity")
			People.animate(active,1.15,true,false,true,"wood")
			expect(rig.cargo.visible,"switch preserves current action on next animation frame")
			var copy:=People.create(role,72,tier)
			expect(copy.get_node("Body/Clothing").mesh==active.get_node("Body/Clothing").mesh,"quality-specific shared geometry")
			copy.free()
		expect(active.get_node("Body/Clothing").mesh==old_mesh,"full-detail cache remains unchanged")
		active.free()
		print("LOD_COUNTS ",role," ",tier_stats.map(func(item):return item.triangles))
	print("APPROVED_LOD_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
