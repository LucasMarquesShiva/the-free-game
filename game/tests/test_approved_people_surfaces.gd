extends SceneTree
const People=preload("res://presentation/approved_people.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize():call_deferred("run")
func expect(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
# A ray must hit the eye rather than forehead/hair. This caught the buried eyes
# and the later hairline regression independently of the placement formulas.
func front_color(mesh: ArrayMesh,x: float,y: float) -> Color:
	# Scale the ray geometry to avoid Geometry3D epsilon discarding tiny iris triangles.
	var origin:=Vector3(x,y,-1)*100.0;var distance:=INF;var result:=Color.MAGENTA
	for surface in range(mesh.get_surface_count()):
		var arrays:=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var intersection: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,vertices[indices[i]]*100.0,vertices[indices[i+1]]*100.0,vertices[indices[i+2]]*100.0)
			if intersection==null:continue
			var d:=origin.distance_to(intersection)
			if d<distance:
				distance=d;result=mesh.surface_get_material(surface).get_shader_parameter("base_color")
	return result
func walk(node: Node) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface);var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			expect(colors.size()==arrays[Mesh.ARRAY_VERTEX].size(),"every vertex retains material tint and cavity shade")
			for color: Color in colors:
				if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b):expect(false,"finite vertex colors");break
			var material: ShaderMaterial=node.mesh.surface_get_material(surface)
			expect(material!=null and material.get_shader_parameter("has_atlas"),"shared imported texture available")
	for child in node.get_children():walk(child)
func run():
	for role: String in People.APPROVED:
		var person:=People.create(role,1);root.add_child(person)
		var head: MeshInstance3D=person.get_node("Body/Head/HeadAndHair")
		for side: int in [-1,1]:
			var visible:=front_color(head.mesh,float(side)*0.043,0.004)
			expect(visible.is_equal_approx(People._material("pupil").albedo_color) or visible.is_equal_approx(People._material("iris").albedo_color),role+" eye unobstructed by skin or hair")
		walk(person);person.free()
	print("APPROVED_SURFACES_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
