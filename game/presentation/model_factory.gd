extends RefCounted
## Original procedural miniatures. These meshes are playable prototype art.

static var _materials: Dictionary = {}

static func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = color.to_html(true) + str(roughness)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	_materials[key] = mat
	return mat

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, at, color)

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, top: float = -1.0, sides: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = sides
	return piece(parent, mesh, at, color)

static func sphere(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return piece(parent, mesh, at, color)

static func piece(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var node := box(parent, Vector3(width, a.distance_to(b), width), (a + b) * 0.5, color)
	node.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return node

static func barrel(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	var wood := Color("9b693b")
	cylinder(parent, 0.26 * scale_factor, 0.60 * scale_factor, at + Vector3.UP * 0.3 * scale_factor, wood)
	for y in [0.12, 0.48]:
		cylinder(parent, 0.275 * scale_factor, 0.045 * scale_factor, at + Vector3.UP * y * scale_factor, Color("464f4d"))
	for x in [-0.10, 0.10]:
		box(parent, Vector3(0.018, 0.60, 0.012) * scale_factor, at + Vector3(x, 0.3, 0.26) * scale_factor, Color("704c2d"))

static func crate(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	box(parent, Vector3(0.52, 0.45, 0.48) * scale_factor, at + Vector3.UP * 0.23 * scale_factor, Color("a97d4d"))
	for y in [0.05, 0.38]:
		box(parent, Vector3(0.56, 0.06, 0.53) * scale_factor, at + Vector3.UP * y * scale_factor, Color("715237"))

static func roof(parent: Node3D, width: float, depth: float, y: float, rise: float, teal: bool = false) -> void:
	var red := Color("bd7048") if not teal else Color("327e78")
	var shade := Color("9f5539") if not teal else Color("25625e")
	var angle: float = atan2(rise, width * 0.5)
	var length: float = sqrt(width * width * 0.25 + rise * rise)
	for side in [-1.0, 1.0]:
		var slab := box(parent, Vector3(length + 0.18, 0.15, depth + 0.36), Vector3(side * width * 0.25, y + rise * 0.5, 0), shade)
		slab.rotation.z = -side * angle
		for row in range(5):
			var t: float = (float(row) + 0.5) / 5.0
			for col in range(7):
				var z: float = (float(col) - 3.0) * (depth + 0.3) / 7.0
				var tile := box(parent, Vector3(length / 5.0 + 0.035, 0.085, (depth + 0.32) / 7.0 - 0.018), Vector3(side * width * 0.5 * t, y + rise * (1.0 - t) + 0.13, z), red.lightened(0.035 * float((row + col) % 3)))
				tile.rotation.z = -side * angle
		for z in [-depth * 0.5 - 0.13, depth * 0.5 + 0.13]:
			beam(parent, Vector3(0, y + rise + 0.05, z), Vector3(side * (width * 0.5 + 0.10), y, z), 0.12, Color("654a32"))
	box(parent, Vector3(0.18, 0.18, depth + 0.48), Vector3(0, y + rise + 0.12, 0), red.lightened(0.12))

static func cottage(parent: Node3D, width: float, depth: float, height: float, teal: bool = false) -> void:
	var stone := Color("b7b5a0")
	var wood := Color("654b34")
	box(parent, Vector3(width + 0.17, 0.32, depth + 0.17), Vector3(0, 0.16, 0), stone)
	box(parent, Vector3(width, height, depth), Vector3(0, height * 0.5 + 0.30, 0), Color("e4d4ac"))
	for x in [-width * 0.5, width * 0.5]:
		for z in [-depth * 0.5, depth * 0.5]:
			box(parent, Vector3(0.15, height + 0.15, 0.15), Vector3(x, height * 0.5 + 0.33, z), wood)
	for y in [0.48, height + 0.23]:
		box(parent, Vector3(width + 0.12, 0.12, depth + 0.12), Vector3(0, y, 0), wood)
	# Front faces positive Z, matching every building entrance in the contract.
	box(parent, Vector3(0.66, 1.06, 0.065), Vector3(-width * 0.23, 0.84, depth * 0.5 + 0.035), Color("493d31"))
	for x in [-0.21, 0.0, 0.21]:
		box(parent, Vector3(0.025, 0.94, 0.05), Vector3(-width * 0.23 + x, 0.83, depth * 0.5 + 0.08), Color("92704a"))
	box(parent, Vector3(0.88, 0.14, 0.5), Vector3(-width * 0.23, 0.12, depth * 0.5 + 0.18), stone)
	for z in [-depth * 0.23, depth * 0.24]:
		for side in [-1.0, 1.0]:
			box(parent, Vector3(0.04, 0.54, 0.43), Vector3(side * (width * 0.5 + 0.02), height * 0.64, z), Color("3c5450"))
	box(parent, Vector3(0.58, 0.57, 0.05), Vector3(width * 0.23, height * 0.66, depth * 0.5 + 0.03), Color("34534c"))
	box(parent, Vector3(0.07, 0.62, 0.10), Vector3(width * 0.23, height * 0.66, depth * 0.5 + 0.07), Color("c8b687"))
	box(parent, Vector3(0.62, 0.07, 0.10), Vector3(width * 0.23, height * 0.66, depth * 0.5 + 0.07), Color("c8b687"))
	beam(parent, Vector3(-width * 0.5, 0.50, depth * 0.5 + 0.04), Vector3(-0.06, height + 0.22, depth * 0.5 + 0.04), 0.08, wood)
	beam(parent, Vector3(width * 0.5, 0.50, -depth * 0.5 - 0.04), Vector3(0.03, height + 0.22, -depth * 0.5 - 0.04), 0.08, wood)
	roof(parent, width + 0.22, depth, height + 0.28, width * 0.34, teal)
	box(parent, Vector3(0.38, 1.06, 0.43), Vector3(width * 0.23, height + 0.94, -depth * 0.20), stone)
	box(parent, Vector3(0.47, 0.13, 0.52), Vector3(width * 0.23, height + 1.49, -depth * 0.20), Color("8d8e7b"))

static func make_building(kind: String) -> Node3D:
	var root := Node3D.new()
	var soil := Color("b6aa79")
	box(root, Vector3(3.85, 0.12, 3.85), Vector3(0, 0.025, 0), soil)
	match kind:
		"farm", "vineyard":
			make_crops(root, kind == "vineyard")
		"quarry":
			for i in range(9):
				var rock := sphere(root, 0.40 + float(i % 3) * 0.13, Vector3(float(i % 3) - 0.9, 0.26, float(i / 3) - 0.9), Color("9b9f90"))
				rock.scale = Vector3(1.3, 0.85 + float(i % 2) * 0.4, 0.95)
			beam(root, Vector3(-1.5, 0.2, 1.0), Vector3(-1.5, 2.2, 1.0), 0.18, Color("795336"))
			beam(root, Vector3(-1.5, 2.2, 1.0), Vector3(0.6, 2.0, 1.0), 0.14, Color("795336"))
			crate(root, Vector3(0.8, 0.12, 1.2))
		"hall":
			cottage(root, 2.65, 2.2, 2.25, true)
			box(root, Vector3(0.76, 2.9, 0.82), Vector3(-1.04, 1.60, -0.65), Color("b8b8a3"))
			cylinder(root, 0.66, 0.82, Vector3(-1.04, 3.46, -0.65), Color("367d74"), 0.0, 4)
			flag(root, Vector3(-1.0, 3.85, -0.65), Color("287a70"))
		"store":
			cottage(root, 2.45, 1.9, 1.45)
			for at in [Vector3(1.35, 0.13, 1.1), Vector3(0.72, 0.13, 1.3), Vector3(1.32, 0.13, 0.5)]:
				crate(root, at)
			barrel(root, Vector3(-1.35, 0.1, 0.7))
		"training", "barracks":
			cottage(root, 2.50, 2.1, 1.65, true)
			flag(root, Vector3(1.5, 0.10, 1.3), Color("287a70"))
			for x in [-0.5, 0.6]:
				beam(root, Vector3(x, 0.15, 1.5), Vector3(x, 1.15, 1.5), 0.13, Color("866540"))
				cylinder(root, 0.24, 0.52, Vector3(x, 0.9, 1.5), Color("b79557"), 0.22)
		"winery":
			cottage(root, 2.45, 1.95, 1.72)
			for x in [0.55, 1.2]:
				barrel(root, Vector3(x, 0.12, 1.25), 1.15)
			var press := Node3D.new()
			root.add_child(press)
			press.position = Vector3(-1.12, 0.16, 1.2)
			cylinder(press, 0.40, 0.56, Vector3(0, 0.3, 0), Color("93623d"))
			for x in [-0.46, 0.46]:
				box(press, Vector3(0.12, 1.25, 0.14), Vector3(x, 0.67, 0), Color("674a30"))
			box(press, Vector3(1.08, 0.16, 0.20), Vector3(0, 1.25, 0), Color("674a30"))
			cylinder(press, 0.06, 0.92, Vector3(0, 1.0, 0), Color("3f4b43"))
			box(press, Vector3(0.8, 0.08, 0.08), Vector3(0, 1.48, 0), Color("916741"))
			for i in range(5):
				sphere(root, 0.105, Vector3(-0.05 + float(i % 3) * 0.15, 2.1 + float(i / 3) * 0.13, 1.07), Color("794665"))
		"lumber":
			cottage(root, 1.80, 1.65, 1.25)
			for i in range(5):
				var log := cylinder(root, 0.18, 1.25, Vector3(0.72 + float(i % 2) * 0.38, 0.25 + float(i / 2) * 0.30, 1.16), Color("946638"))
				log.rotation.z = PI * 0.5
		_:
			cottage(root, 2.30, 2.10, 1.65)
			box(root, Vector3(0.7, 0.23, 0.32), Vector3(0.70, 0.19, 1.4), Color("71543b"))
			for x in [0.5, 0.8]:
				sphere(root, 0.17, Vector3(x, 0.47, 1.4), Color("65844b"))
	bake(root)
	return root

static func make_crops(root: Node3D, vineyard: bool) -> void:
	box(root, Vector3(3.55, 0.13, 3.5), Vector3(0, 0.13, 0), Color("715739"))
	for row in range(3):
		var x: float = (float(row) - 1.0) * 1.05
		box(root, Vector3(0.65, 0.10, 3.15), Vector3(x, 0.23, 0), Color("8c7047"))
		if vineyard:
			for z in [-1.6, 0.0, 1.6]:
				box(root, Vector3(0.09, 1.23, 0.10), Vector3(x, 0.78, z), Color("9b784b"))
			box(root, Vector3(0.045, 0.045, 3.3), Vector3(x, 1.28, 0), Color("69573e"))
		for col in range(5):
			var z: float = (float(col) - 2.0) * 0.63
			if vineyard:
				box(root, Vector3(0.08, 0.9, 0.08), Vector3(x, 0.72, z), Color("715034"))
				var leaves := sphere(root, 0.35, Vector3(x, 1.12, z), Color("597c36").lightened(float(col % 2) * 0.05))
				leaves.scale = Vector3(0.78, 0.65, 1.1)
				for k in range(3):
					sphere(root, 0.07, Vector3(x + 0.23, 0.84 - float(k) * 0.075, z + 0.05), Color("785077"))
			else:
				var cabbage := sphere(root, 0.24, Vector3(x, 0.37, z), Color("7f984a").lightened(float(col % 2) * 0.08))
				cabbage.scale.y = 0.68
	for x in [-1.83, 1.83]:
		for z in [-1.8, 1.8]:
			box(root, Vector3(0.13, 0.6, 0.13), Vector3(x, 0.4, z), Color("aa8b56"))
		box(root, Vector3(0.08, 0.1, 3.6), Vector3(x, 0.59, 0), Color("aa8b56"))

static func flag(root: Node3D, at: Vector3, color: Color) -> void:
	box(root, Vector3(0.06, 1.8, 0.06), at + Vector3.UP * 0.90, Color("947348"))
	box(root, Vector3(0.57, 0.50, 0.045), at + Vector3(0.30, 1.50, 0), color)
	box(root, Vector3(0.05, 0.36, 0.06), at + Vector3(0.27, 1.50, 0), Color("dcb967"))

static func make_actor(role: String, team: String = "ally", seed_id: int = 0) -> Node3D:
	var actor := Node3D.new()
	var cloth := Color("347e78") if team == "ally" else Color("aa5650")
	var skin: Color = [Color("d7a472"), Color("ba8058"), Color("e3b58a"), Color("996948")][posmod(seed_id, 4)]
	var leather := Color("765037")
	var body := Node3D.new()
	body.name = "Body"
	actor.add_child(body)
	cylinder(body, 0.18, 0.38, Vector3(0, 0.83, 0), cloth, 0.24)
	cylinder(body, 0.19, 0.07, Vector3(0, 0.66, 0), leather)
	sphere(body, 0.18, Vector3(0, 1.17, 0), skin)
	box(body, Vector3(0.11, 0.08, 0.10), Vector3(0, 1.16, -0.16), skin)
	for x in [-0.065, 0.065]:
		box(body, Vector3(0.028, 0.025, 0.025), Vector3(x, 1.22, -0.16), Color("3d362d"))
	if role in ["lancer", "archer"]:
		if role == "lancer":
			cylinder(body, 0.19, 0.13, Vector3(0, 1.33, 0), Color("80948e"), 0.14)
			box(body, Vector3(0.27, 0.32, 0.12), Vector3(0, 0.85, -0.13), Color("879a8e"))
		else:
			sphere(body, 0.185, Vector3(0, 1.29, 0.045), cloth.darkened(0.13))
			cylinder(body, 0.085, 0.40, Vector3(0.14, 0.90, 0.18), leather)
	else:
		cylinder(body, 0.18, 0.13, Vector3(0, 1.30, 0.02), Color("634935"), 0.14)
		if role in ["farmer", "vintner"]:
			cylinder(body, 0.27, 0.04, Vector3(0, 1.34, 0), Color("b9a56c"))
			cylinder(body, 0.16, 0.13, Vector3(0, 1.39, 0), Color("bfab73"), 0.12)
		if role == "builder":
			box(body, Vector3(0.29, 0.34, 0.04), Vector3(0, 0.79, -0.20), leather)
		if role == "vintner":
			box(body, Vector3(0.15, 0.15, 0.055), Vector3(0.08, 0.99, -0.18), Color("854b66"))
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.11, 0.60, 0)
		actor.add_child(leg)
		box(leg, Vector3(0.14, 0.31, 0.14), Vector3(0, -0.16, 0), Color("675c43"))
		box(leg, Vector3(0.17, 0.16, 0.26), Vector3(0, -0.39, -0.05), leather)
		bake(leg)
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * 0.235, 0.98, 0)
		actor.add_child(arm)
		box(arm, Vector3(0.12, 0.23, 0.14), Vector3(0, -0.12, 0), cloth)
		sphere(arm, 0.075, Vector3(0, -0.32, 0), skin)
		if side > 0:
			match role:
				"lancer":
					box(arm, Vector3(0.045, 1.9, 0.045), Vector3(0, 0.34, -0.05), Color("826242"))
					cylinder(arm, 0.10, 0.34, Vector3(0, 1.40, -0.05), Color("a8bcb2"), 0.0, 4)
				"builder", "lumberjack", "stonecutter":
					box(arm, Vector3(0.045, 0.45, 0.045), Vector3(0, -0.26, -0.10), Color("9f804d"))
					box(arm, Vector3(0.27, 0.14, 0.12), Vector3(0, -0.03, -0.10), Color("aaa88f") if role != "builder" else Color("986744"))
				"farmer", "vintner":
					box(arm, Vector3(0.035, 0.95, 0.035), Vector3(0, -0.02, -0.10), Color("9b8050"))
					box(arm, Vector3(0.15, 0.04, 0.19), Vector3(0, -0.50, -0.10), Color("7a8c80"))
		if side < 0 and role == "archer":
			var bow_color := Color("9b7749")
			beam(arm, Vector3(0, 0.17, -0.03), Vector3(0, -0.13, -0.23), 0.04, bow_color)
			beam(arm, Vector3(0, -0.13, -0.23), Vector3(0, -0.52, -0.03), 0.04, bow_color)
			beam(arm, Vector3(0, 0.17, -0.03), Vector3(0, -0.52, -0.03), 0.012, Color("dad3b7"))
		bake(arm)
	bake(body)
	var cargo := Node3D.new()
	cargo.name = "Cargo"
	cargo.position = Vector3(0, 0.82, -0.37)
	actor.add_child(cargo)
	return actor

static func make_tree(seed_id: int = 0) -> Node3D:
	var root := Node3D.new()
	var trunk := Color("806044")
	var green := Color("486e41").lightened(float(posmod(seed_id, 4)) * 0.035)
	cylinder(root, 0.20, 2.35, Vector3(0, 1.18, 0), trunk, 0.12)
	if seed_id % 3 == 0:
		for i in range(3):
			cylinder(root, 1.18 - float(i) * 0.24, 1.75, Vector3(0, 1.60 + float(i) * 0.75, 0), green.lightened(float(i) * 0.04), 0.0, 7)
	else:
		for i in range(3):
			var crown := sphere(root, 0.94, Vector3(sin(float(i) * 2.1) * 0.43, 2.1 + float(i % 2) * 0.45, cos(float(i) * 2.1) * 0.36), green.lightened(float(i) * 0.045))
			crown.scale.y = 1.20
	bake(root)
	return root

static func make_site(progress: float) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(3.72, 0.09, 3.72), Vector3(0, 0.035, 0), Color("927b56"))
	for side in [-1.0, 1.0]:
		box(root, Vector3(3.24, 0.26, 0.24), Vector3(0, 0.17, side * 1.48), Color("b2af95"))
		box(root, Vector3(0.24, 0.26, 3.24), Vector3(side * 1.48, 0.17, 0), Color("b2af95"))
	if progress > 0.2:
		for x in [-1.42, 1.42]:
			for z in [-1.42, 1.42]:
				box(root, Vector3(0.13, 1.9, 0.13), Vector3(x, 1.1, z), Color("927149"))
			box(root, Vector3(0.13, 0.13, 3.05), Vector3(x, 2.02, 0), Color("927149"))
			beam(root, Vector3(x, 0.25, -1.42), Vector3(x, 1.98, 1.42), 0.08, Color("a88656"))
	if progress > 0.48:
		for side in [-1.0, 1.0]:
			box(root, Vector3(2.9, 1.1, 0.17), Vector3(0, 0.82, side * 1.32), Color("c4b18b"))
	if progress > 0.75:
		for z in [-1.30, 0.0, 1.30]:
			beam(root, Vector3(-1.40, 2.08, z), Vector3(0, 2.80, z), 0.10, Color("89643d"))
			beam(root, Vector3(1.40, 2.08, z), Vector3(0, 2.80, z), 0.10, Color("89643d"))
	crate(root, Vector3(0.70, 0.1, 0.70))
	bake(root)
	return root

static func bake(root: Node3D) -> void:
	# Merge static primitive geometry by shared material to limit draw calls.
	var grouped: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	_collect(root, Transform3D.IDENTITY, grouped, originals)
	for key: int in grouped:
		var group: Dictionary = grouped[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.vertices
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_INDEX] = group.indices
		var combined := ArrayMesh.new()
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = combined
		instance.material_override = group.material
		root.add_child(instance)
	for original in originals:
		original.free()

static func _collect(node: Node3D, transform: Transform3D, groups: Dictionary, originals: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if not child is Node3D:
			continue
		var relative: Transform3D = transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var mat: Material = child.material_override
			if mat == null:
				continue
			var key: int = mat.get_instance_id()
			if not groups.has(key):
				groups[key] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "indices": PackedInt32Array(), "material": mat}
			var group: Dictionary = groups[key]
			for surface in range(child.mesh.get_surface_count()):
				var source: Array = child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
				var offset: int = group.vertices.size()
				var normal_basis: Basis = relative.basis.inverse().transposed()
				for i in range(vertices.size()):
					group.vertices.append(relative * vertices[i])
					group.normals.append((normal_basis * normals[i]).normalized())
				if indices.is_empty():
					for i in range(vertices.size()):
						group.indices.append(offset + i)
				else:
					for index in indices:
						group.indices.append(offset + index)
			originals.append(child)
		else:
			_collect(child, relative, groups, originals)
