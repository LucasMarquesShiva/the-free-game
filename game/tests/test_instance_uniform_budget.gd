extends SceneTree
const People = preload("res://presentation/approved_people.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: ",message)

func geometries(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child in node.get_children(): geometries(child,result)

func uniform_geometry_count(person: Node3D) -> int:
	var nodes: Array[MeshInstance3D] = []
	geometries(person,nodes)
	var count := 0
	for node in nodes:
		var needs_instance := false
		for surface in range(node.mesh.get_surface_count()):
			var material := node.get_active_material(surface)
			if material is ShaderMaterial:
				needs_instance = needs_instance or material.shader.code.contains("instance uniform")
		if needs_instance:
			count += 1
			expect(node.name=="Clothing", "only Clothing uses instance uniforms: "+str(node.name))
	return count

func run() -> void:
	var total := 0
	var people: Array[Node3D] = []
	for i in range(48):
		var person := People.create(People.APPROVED[i%People.APPROVED.size()],i,i%3)
		root.add_child(person);people.append(person)
		var count := uniform_geometry_count(person)
		expect(count==1,"one deforming mesh for civilian "+str(i));total+=count
		People.animate(person,float(i)*0.6,true,false,i%2==0,"wine")
		expect(uniform_geometry_count(person)==1,"cargo remains rigid "+str(i))
		People.set_quality(person,(i+1)%3)
		expect(uniform_geometry_count(person)==1,"LOD preserves budget "+str(i))
	var first_cloth:MeshInstance3D=people[0].get_node("Body/Clothing")
	var second_cloth:MeshInstance3D=people[1].get_node("Body/Clothing")
	first_cloth.set_instance_shader_parameter("cloth_stride",0.38)
	second_cloth.set_instance_shader_parameter("cloth_stride",-0.27)
	expect(is_equal_approx(float(first_cloth.get_instance_shader_parameter("cloth_stride")),0.38),"first garment phase remains independent")
	expect(is_equal_approx(float(second_cloth.get_instance_shader_parameter("cloth_stride")),-0.27),"second garment phase remains independent")
	expect(total==48,"48 populated civilians use48 allocation blocks")
	expect((total+1)*16<=1024,"population plus temporary LOD replacement fits hardware buffer")
	for person in people: person.free()
	print("INSTANCE_UNIFORM_BUDGET_", "PASS" if failures.is_empty() else "FAIL", " checks=",checks," instances=",total," reserved_items=",total*16," transient_items=",(total+1)*16)
	quit(0 if failures.is_empty() else 1)
