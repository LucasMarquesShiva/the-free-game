extends RefCounted
## Articulated, reusable civilian miniatures; forward is -Z, feet rest at Y=0.
## Each person has 10 body meshes, plus one tool and one optional cargo mesh.

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _sphere: SphereMesh
const TEAL := Color("286e68")
const CREAM := Color("e4d5b5")
const LEATHER := Color("755035")
const DARK_LEATHER := Color("493627")
const GOLD := Color("b99a54")
const PANTS := Color("514b39")

static func create(role: String, id: int) -> Node3D:
	var person := Node3D.new()
	person.name = "Civilian_%d" % id
	person.set_meta("role", role)
	person.set_meta("id", id)
	var skin := _skin(role, id)
	var body := _joint(person, "Body", Vector3(0, 0.62, 0))
	_attach(body, "Tunic", _cached("body_" + role, func(): return _body_parts(role)))
	var head := _joint(body, "Head", Vector3(0, 0.59, 0))
	var head_key := "head_%s_%d" % [role, posmod(id, 4)]
	_attach(head, "FaceAndHair", _cached(head_key, func(): return _head_parts(role, id)))
	for side: int in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		var arm := _joint(body, "Arm" + suffix, Vector3(float(side) * 0.202, 0.36, 0))
		arm.rotation.z = float(side) * 0.07
		_attach(arm, "Sleeve", _cached("sleeve_" + role, func(): return _upper_arm_parts(role)))
		var forearm := _joint(arm, "Forearm", Vector3(0, -0.205, 0))
		_attach(forearm, "HandAndCuff", _cached("forearm_" + skin.to_html(), func(): return _forearm_parts(skin)))
		var hip := _joint(person, "Hip" + suffix, Vector3(float(side) * 0.091, 0.59, 0))
		_attach(hip, "Trousers", _cached("thigh", func(): return _thigh_parts()))
		var knee := _joint(hip, "Knee", Vector3(0, -0.25, 0))
		_attach(knee, "Boot", _cached("boot", func(): return _boot_parts()))
	var tool := _joint(body.get_node("ArmR/Forearm"), "Tool", Vector3(0, -0.215, -0.018))
	if role != "resident" and role != "servant":
		_attach(tool, "ToolMesh", _cached("tool_" + role, func(): return _tool_parts(role)))
	var cargo := _joint(body, "Cargo", Vector3(0, 0.16, -0.30))
	_attach(cargo, "Crate", _cached("cargo", func(): return _cargo_parts()))
	cargo.visible = false
	# Cache node references once. Animation never searches the tree per frame.
	person.set_meta("rig", {
		"body":body, "head":head,
		"left_arm":body.get_node("ArmL"), "right_arm":body.get_node("ArmR"),
		"left_elbow":body.get_node("ArmL/Forearm"), "right_elbow":body.get_node("ArmR/Forearm"),
		"left_hip":person.get_node("HipL"), "right_hip":person.get_node("HipR"),
		"left_knee":person.get_node("HipL/Knee"), "right_knee":person.get_node("HipR/Knee"),
		"tool":tool, "cargo":cargo
	})
	animate(person, float(id) * 0.47, false, false, false)
	return person

static func animate(person: Node3D, phase: float, walking: bool, working: bool, loaded: bool) -> void:
	if not is_instance_valid(person) or not person.has_meta("rig"):
		return
	var rig: Dictionary = person.get_meta("rig")
	var wave := sin(phase)
	var opposite := -wave
	var body: Node3D = rig.body
	var head: Node3D = rig.head
	var left_arm: Node3D = rig.left_arm
	var right_arm: Node3D = rig.right_arm
	var left_elbow: Node3D = rig.left_elbow
	var right_elbow: Node3D = rig.right_elbow
	var left_hip: Node3D = rig.left_hip
	var right_hip: Node3D = rig.right_hip
	var left_knee: Node3D = rig.left_knee
	var right_knee: Node3D = rig.right_knee
	body.position.y = 0.62 + (absf(wave) * 0.014 if walking else sin(phase * 0.24) * 0.003)
	body.rotation = Vector3(0, wave * 0.025 if walking else 0.0, wave * 0.018 if walking else 0.0)
	head.rotation = Vector3(0, -body.rotation.y * 0.5, -body.rotation.z * 0.6)
	left_hip.rotation.x = wave * 0.40 if walking else 0.0
	right_hip.rotation.x = opposite * 0.40 if walking else 0.0
	left_knee.rotation.x = -maxf(0, -wave) * 0.60 if walking else 0.0
	right_knee.rotation.x = -maxf(0, wave) * 0.60 if walking else 0.0
	left_arm.rotation = Vector3(opposite * 0.31 if walking else 0.035, 0, -0.07)
	right_arm.rotation = Vector3(wave * 0.31 if walking else 0.035, 0, 0.07)
	left_elbow.rotation.x = 0.13 + (maxf(0, wave) * 0.15 if walking else 0.0)
	right_elbow.rotation.x = 0.13 + (maxf(0, opposite) * 0.15 if walking else 0.0)
	var cargo: Node3D = rig.cargo
	var tool: Node3D = rig.tool
	cargo.visible = loaded
	tool.visible = not loaded
	if loaded:
		left_arm.rotation = Vector3(0.38, 0.08, -0.025)
		right_arm.rotation = Vector3(0.38, -0.08, 0.025)
		left_elbow.rotation.x = 1.03
		right_elbow.rotation.x = 1.03
		cargo.rotation.z = wave * 0.012 if walking else 0.0
		body.rotation.x = -0.035
	elif working and not walking:
		body.rotation.x = -0.085 + wave * 0.018
		head.rotation.x = -0.10
		right_arm.rotation.x = 0.57 + wave * 0.35
		right_elbow.rotation.x = 0.55 + sin(phase + 0.55) * 0.42
		left_arm.rotation.x = 0.28
		left_elbow.rotation.x = 0.34
		if str(person.get_meta("role", "")) in ["farmer", "horticulturist", "vintner"]:
			left_arm.rotation.x = 0.56 + wave * 0.10
			left_elbow.rotation.x = 0.48

static func _skin(role: String, id: int) -> Color:
	if role == "stonecutter":
		return Color("ab7752")
	if role in ["farmer", "horticulturist", "lumberjack"]:
		return Color("d7a071")
	var palette := [Color("d9a475"), Color("b98760"), Color("c18e65"), Color("e1b184")]
	return palette[posmod(id, palette.size())]

static func _joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node

static func _attach(parent: Node3D, label: String, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = _material("cloth")
	parent.add_child(instance)

static func _material(key: String) -> StandardMaterial3D:
	if not _material_cache.has(key):
		var value := StandardMaterial3D.new()
		value.vertex_color_use_as_albedo = true
		value.vertex_color_is_srgb = true
		value.roughness = 0.84
		value.metallic_specular = 0.22
		_material_cache[key] = value
	return _material_cache[key]

static func _cached(key: String, producer: Callable) -> ArrayMesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _merge(producer.call())
	return _mesh_cache[key]

static func _shape(parts: Array, mesh: Mesh, at: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	parts.append({"mesh":mesh, "transform":Transform3D(Basis.from_euler(rotation).scaled(size), at), "color":color})

static func _oval(parts: Array, at: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 12
		_sphere.rings = 6
	_shape(parts, _sphere, at, size, color, rotation)

static func _box(parts: Array, at: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_shape(parts, mesh, at, Vector3.ONE, color, rotation)

static func _cylinder(parts: Array, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3 = Vector3.ZERO, top: float = -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 14
	_shape(parts, mesh, at, Vector3.ONE, color, rotation)

static func _body_parts(role: String) -> Array:
	var parts: Array = []
	var farmer: bool = role in ["farmer", "horticulturist"]
	var shirt := TEAL.lightened(0.055) if role == "instructor" else TEAL
	var rings := [Vector3(-0.12,0.19,0.115), Vector3(0.02,0.18,0.115), Vector3(0.13,0.147,0.105), Vector3(0.29,0.19,0.119), Vector3(0.38,0.199,0.109), Vector3(0.44,0.12,0.083)]
	if farmer:
		rings[0] = Vector3(-0.25,0.205,0.135)
		rings[1] = Vector3(-0.07,0.186,0.123)
	_shape(parts, _tailored(rings), Vector3.ZERO, Vector3.ONE, shirt)
	_cylinder(parts, Vector3(0,0.48,0),0.057,0.095,CREAM)
	# Cream shirt and split collar sit over the shaped teal torso.
	_oval(parts, Vector3(0,0.351,-0.102),Vector3(0.064,0.078,0.017),CREAM)
	for side: int in [-1,1]:
		_box(parts,Vector3(float(side)*0.042,0.396,-0.119),Vector3(0.047,0.097,0.018),CREAM,Vector3(0,0,float(side)*-0.38))
		_box(parts,Vector3(float(side)*0.074,0.24,-0.113),Vector3(0.009,0.205,0.011),GOLD,Vector3(0,0,float(side)*-0.10))
	_shape(parts,_tailored([Vector3(0.10,0.159,0.116),Vector3(0.15,0.159,0.116)]),Vector3.ZERO,Vector3.ONE,LEATHER)
	_box(parts,Vector3(0,0.126,-0.123),Vector3(0.063,0.056,0.018),GOLD)
	_box(parts,Vector3(0,0.126,-0.135),Vector3(0.040,0.034,0.008),DARK_LEATHER)
	for y: float in [0.21,0.265,0.32]:
		_oval(parts,Vector3(0.012,y,-0.126),Vector3(0.012,0.012,0.009),GOLD)
	_oval(parts,Vector3(0.167,0.034,-0.015),Vector3(0.059,0.092,0.059),LEATHER)
	_box(parts,Vector3(0.18,0.05,-0.069),Vector3(0.028,0.025,0.009),GOLD)
	if role in ["servant","builder","stonecutter"]:
		var apron := LEATHER.lightened(0.09) if role == "stonecutter" else LEATHER
		_box(parts,Vector3(0,-0.012,-0.124),Vector3(0.245,0.215,0.020),apron)
		if role == "stonecutter":
			_box(parts,Vector3(0,0.276,-0.131),Vector3(0.23,0.237,0.018),apron)
			for side: int in [-1,1]:
				_box(parts,Vector3(float(side)*0.093,0.372,-0.126),Vector3(0.022,0.125,0.023),LEATHER)
	if role == "vintner":
		for side: int in [-1,1]:
			_oval(parts,Vector3(float(side)*0.042,0.399,-0.140),Vector3(0.026,0.069,0.019),Color("944c3f"),Vector3(0,0,float(side)*0.38))
		for i: int in range(5):
			_oval(parts,Vector3(0.082+float(i%2)*0.014,0.299-float(i)*0.017,-0.132),Vector3.ONE*0.012,GOLD)
	return parts

static func _head_parts(role: String, id: int) -> Array:
	var parts: Array = []
	var skin := _skin(role,id)
	var female: bool = role in ["farmer","horticulturist","lumberjack","stonecutter"]
	var hair := Color("65442d") if posmod(id,2)==0 else Color("48372a")
	if role in ["farmer","horticulturist","lumberjack"]:
		hair = Color("87502d")
	_oval(parts,Vector3.ZERO,Vector3(0.124,0.156,0.114),skin)
	_oval(parts,Vector3(0,-0.074,-0.012),Vector3(0.103,0.078,0.096),skin)
	for side: int in [-1,1]:
		_oval(parts,Vector3(float(side)*0.123,-0.016,0),Vector3(0.023,0.043,0.031),skin)
		_oval(parts,Vector3(float(side)*0.047,0.014,-0.107),Vector3(0.022,0.013,0.010),Color("ece5d5"))
		_oval(parts,Vector3(float(side)*0.046,0.015,-0.116),Vector3(0.008,0.009,0.004),Color("34302a"))
		_oval(parts,Vector3(float(side)*0.048,0.040,-0.108),Vector3(0.030,0.008,0.010),hair,Vector3(0,0,float(side)*0.10))
	_oval(parts,Vector3(0,-0.019,-0.120),Vector3(0.022,0.038,0.036),skin.lightened(0.035))
	_oval(parts,Vector3(0,-0.075,-0.105),Vector3(0.027,0.004,0.006),Color("885744"))
	_oval(parts,Vector3(0,0.083,0.031),Vector3(0.13,0.094,0.111),hair)
	_oval(parts,Vector3(0,0.013,0.086),Vector3(0.115,0.104,0.052),hair)
	for i: int in range(5):
		var x := (float(i)-2.0)*0.045
		_oval(parts,Vector3(x,0.115-absf(x)*0.32,-0.045),Vector3(0.046,0.042,0.072),hair.lightened(float(i%2)*0.05),Vector3(0.15,0,0.18))
	if female or role == "instructor":
		for i: int in range(5):
			_oval(parts,Vector3(sin(float(i)*2.4)*0.012,-0.045-float(i)*0.040,0.116),Vector3(0.036,0.034,0.038),hair.lightened(float(i%2)*0.04))
		_oval(parts,Vector3(0,-0.215,0.118),Vector3(0.039,0.015,0.037),TEAL)
	if role == "vintner":
		_oval(parts,Vector3(0,-0.095,-0.044),Vector3(0.096,0.057,0.077),hair)
		_oval(parts,Vector3(0,-0.065,-0.110),Vector3(0.051,0.016,0.014),hair)
	if role in ["farmer","horticulturist"]:
		_oval(parts,Vector3(0,0.115,0.016),Vector3(0.227,0.022,0.187),Color("bea26c"))
		_cylinder(parts,Vector3(0,0.161,0.017),0.119,0.085,Color("c6ae77"),Vector3.ZERO,0.089)
		_cylinder(parts,Vector3(0,0.13,0.017),0.121,0.028,TEAL,Vector3.ZERO,0.113)
	return parts

static func _upper_arm_parts(role: String) -> Array:
	var parts: Array = []
	var cloth := CREAM if role in ["resident","servant","farmer","horticulturist","vintner"] else TEAL
	_oval(parts,Vector3(0,-0.091,0),Vector3(0.079,0.128,0.076),cloth)
	_cylinder(parts,Vector3(0,-0.184,0),0.065,0.040,CREAM)
	return parts

static func _forearm_parts(skin: Color) -> Array:
	var parts: Array = []
	_oval(parts,Vector3(0,-0.085,0),Vector3(0.053,0.104,0.050),skin)
	_cylinder(parts,Vector3(0,-0.139,0),0.049,0.034,LEATHER)
	_oval(parts,Vector3(0,-0.203,-0.01),Vector3(0.052,0.065,0.052),skin)
	_oval(parts,Vector3(-0.035,-0.193,-0.038),Vector3(0.025,0.039,0.021),skin)
	return parts

static func _thigh_parts() -> Array:
	var parts: Array = []
	_oval(parts,Vector3(0,-0.11,0),Vector3(0.083,0.159,0.084),PANTS)
	return parts

static func _boot_parts() -> Array:
	var parts: Array = []
	_oval(parts,Vector3(0,-0.103,0),Vector3(0.066,0.134,0.066),CREAM.darkened(0.17))
	_oval(parts,Vector3(0,-0.189,0),Vector3(0.078,0.091,0.079),LEATHER)
	_oval(parts,Vector3(0,-0.275,-0.040),Vector3(0.086,0.064,0.130),DARK_LEATHER)
	_oval(parts,Vector3(0,-0.299,-0.041),Vector3(0.089,0.027,0.131),Color("302c22"))
	_cylinder(parts,Vector3(0,-0.14,0),0.079,0.025,LEATHER.lightened(0.08))
	for y: float in [-0.213,-0.239,-0.262]:
		_box(parts,Vector3(0,y,-0.105),Vector3(0.047,0.010,0.008),Color("bb9871"))
	return parts

static func _tool_parts(role: String) -> Array:
	var parts: Array = []
	var steel := Color("92988d")
	match role:
		"builder", "stonecutter":
			_cylinder(parts,Vector3(0,0.025,0),0.018,0.33,Color("a37a4b"))
			_cylinder(parts,Vector3(0,0.176,0),0.059,0.20,LEATHER.lightened(0.19) if role=="builder" else steel,Vector3(0,0,PI*0.5))
		"lumberjack":
			_cylinder(parts,Vector3(0,0.035,0),0.018,0.43,Color("a37a4b"))
			_box(parts,Vector3(0.033,0.206,0),Vector3(0.14,0.095,0.042),steel,Vector3(0,0,-0.12))
			_box(parts,Vector3(0.095,0.205,0),Vector3(0.014,0.12,0.043),steel.lightened(0.13),Vector3(0,0,-0.12))
		"farmer", "horticulturist":
			_cylinder(parts,Vector3(0,-0.008,0),0.015,0.66,Color("a37a4b"))
			_box(parts,Vector3(0,-0.327,-0.051),Vector3(0.11,0.023,0.132),steel)
		"vintner":
			_cylinder(parts,Vector3(0,0.018,0),0.021,0.12,LEATHER)
			_oval(parts,Vector3(0.023,0.126,0),Vector3(0.029,0.075,0.011),steel,Vector3(0,0,-0.24))
		"instructor":
			_cylinder(parts,Vector3(0,0.025,0),0.030,0.25,CREAM)
			_cylinder(parts,Vector3(0,0.025,0),0.033,0.025,TEAL)
		_:
			_cylinder(parts,Vector3(0,0.018,0),0.018,0.27,LEATHER)
	return parts

static func _cargo_parts() -> Array:
	var parts: Array = []
	var wood := Color("a17a4c")
	_box(parts,Vector3(0,-0.105,0),Vector3(0.39,0.026,0.28),wood.darkened(0.10))
	for side: int in [-1,1]:
		for y: float in [-0.064,0.018,0.091]:
			_box(parts,Vector3(0,y,float(side)*0.14),Vector3(0.41,0.053,0.020),wood)
			_box(parts,Vector3(float(side)*0.198,y,0),Vector3(0.020,0.053,0.28),wood.darkened(0.10))
		for z: float in [-0.126,0.126]:
			_box(parts,Vector3(float(side)*0.183,0,z),Vector3(0.027,0.232,0.026),wood.lightened(0.10))
	_oval(parts,Vector3(-0.077,0.070,0),Vector3(0.089,0.13,0.099),CREAM.darkened(0.08))
	_oval(parts,Vector3(0.07,0.067,0.017),Vector3(0.075,0.115,0.092),Color("b9a175"))
	return parts

static func _tailored(rings: Array) -> ArrayMesh:
	# Elliptical rings give shoulders, waist and coat hem a continuous silhouette.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 18
	for row: int in range(rings.size()-1):
		for segment: int in range(sides):
			var vertices: Array[Vector3] = []
			for pair: Vector2i in [Vector2i(row,segment),Vector2i(row+1,segment),Vector2i(row+1,segment+1),Vector2i(row,segment+1)]:
				var ring: Vector3 = rings[pair.x]
				var angle := float(pair.y) / float(sides) * TAU
				vertices.append(Vector3(cos(angle)*ring.y,ring.x,sin(angle)*ring.z))
			for index: int in [0,2,1,0,3,2]:
				tool.set_smooth_group(0)
				tool.add_vertex(vertices[index])
	tool.generate_normals()
	tool.index()
	return tool.commit()

static func _merge(parts: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part: Dictionary in parts:
		var mesh: Mesh = part.mesh
		var transform: Transform3D = part.transform
		var normal_basis := transform.basis.inverse().transposed()
		for surface: int in range(mesh.get_surface_count()):
			var data := mesh.surface_get_arrays(surface)
			var base := vertices.size()
			var source_vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
			for i: int in range(source_vertices.size()):
				vertices.append(transform * source_vertices[i])
				normals.append((normal_basis * source_normals[i]).normalized())
				colors.append(part.color)
			var source_indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			if source_indices.is_empty():
				for i: int in range(source_vertices.size()):
					indices.append(base+i)
			else:
				for index: int in source_indices:
					indices.append(base+index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
