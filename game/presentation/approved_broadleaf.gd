extends RefCounted
## Broadleaf-only factory: preserves all forest families, seeds and transforms.
## Three deterministic opaque meshes shared by every oak. No alpha cards.
const Original = preload("res://presentation/approved_environment.gd")
const Pines = preload("res://presentation/approved_pine_tufts.gd")
static var _meshes: Dictionary = {}
static var _bounds: AABB

static func tree(seed_value: int = 1) -> Node3D:
	var family := posmod(seed_value, 17)
	if family == 0 or family > 4:
		return Pines.tree(seed_value)
	var variant := posmod(seed_value, 3)
	if not _meshes.has(variant):
		_meshes[variant] = _oak(variant)
	var node: Node3D = Original._instance(_meshes[variant], "ApprovedOak", variant)
	node.set_meta("broadleaf_revision", 7)
	return node

static func _oak(variant: int) -> ArrayMesh:
	var g := Original.Geometry.new(44181+variant*811)
	var bark := Color("705238")
	var height := 5.15+variant*0.24
	var trunk_top := Vector3(0.17,height*0.57,-0.11)
	Original._tube(g,Vector3(0,0.02,0),Vector3(-0.10,1.6,0.08),0.30,0.235,bark,11)
	Original._tube(g,Vector3(-0.10,1.6,0.08),trunk_top,0.235,0.15,bark,9)
	for i in range(7):
		var angle := i*TAU/7.0+0.13
		var offset := Vector3(cos(angle),0,sin(angle))
		Original._tube(g,Vector3.UP*0.52,offset*g.rng.randf_range(0.61,0.95)+Vector3.UP*0.02,0.14,0.021,bark,6)
		Original._tube(g,offset*0.27+Vector3.UP*0.30,Vector3(-0.1,1.55,0.08)+offset*0.22,0.025,0.012,Color("493c2b"),4)
	var centers: Array[Vector3]=[]
	for i in range(7):
		var angle := i*2.399+variant*0.21
		var radial := Vector3(cos(angle),0,sin(angle))
		var from := Vector3(-0.02,1.75+i*0.16,0.04)
		var elbow := from+radial*g.rng.randf_range(0.65,0.85)+Vector3.UP*0.65
		var tip := elbow+radial*g.rng.randf_range(0.54,0.76)+Vector3.UP*(0.50+i*0.035)
		Original._tube(g,from,elbow,0.135-i*0.008,0.077,bark,8)
		Original._tube(g,elbow,tip,0.077,0.025,bark,7)
		centers.append(tip+Vector3.UP*0.17)
		var side := Vector3(-radial.z,0,radial.x)
		var fork := elbow+radial*0.66+side*0.55+Vector3.UP*0.73
		Original._tube(g,elbow,fork,0.057,0.016,bark,6)
		centers.append(fork)
	centers.append(Vector3(0.05,height-0.55,-0.15))
	centers.append(Vector3(-0.70,height-0.68,0.23))
	centers.append(Vector3(0.64,height-0.73,0.35))
	centers.append(Vector3(-0.10,height*0.70,0.36))
	centers.append(Vector3(0.24,height*0.78,-0.18))
	_bounds = (load("res://assets/approved/environment-lod/oak-%d.res" % variant) as ArrayMesh).get_aabb()
	var trunk_indices: PackedInt32Array = g.indices.duplicate()
	var crown_indices := PackedInt32Array()
	var proxies: Array[Dictionary] = []
	# Branch tips carry open, staggered fans. Leaves follow shoots rather than
	# sitting on identical ellipsoid shells; gaps reveal the main forks.
	for cluster: int in range(centers.size()):
		var center: Vector3 = centers[cluster]
		var radial := Vector3(center.x, 0.0, center.z).normalized()
		if radial.length_squared() < 0.1: radial = Vector3.RIGHT
		var tier := clampf((center.y - 2.6) / 2.3, 0.0, 1.0)
		var base_tint := Color("536a2c").lerp(Color("98a143"), tier * 0.78)
		for fan: int in range(5):
			var angle := float(fan) * 2.399 + float(cluster) * 0.63 + variant * 0.31
			var side := Vector3(cos(angle), 0.0, sin(angle))
			var direction := (side * 0.78 + radial * 0.42 + Vector3.UP * (0.12 + 0.14 * float(fan % 2))).normalized()
			var lateral := Vector3.UP.cross(direction).normalized()
			var up := direction.cross(lateral).normalized()
			var start := center + side * (0.12 + 0.065 * float(fan % 3)) + Vector3.UP * (-0.26 + 0.125 * float(fan))
			var reach := g.rng.randf_range(0.50, 0.72)
			start = start.clamp(_bounds.position + Vector3.ONE * 0.02, _bounds.end - Vector3.ONE * 0.02)
			var tip := (start + direction * reach - Vector3.UP * 0.05).clamp(_bounds.position + Vector3.ONE * 0.02, _bounds.end - Vector3.ONE * 0.02)
			Original._tube(g, start, tip, 0.012, 0.003, bark, 4)
			var fan_tint: Color = g.shade(base_tint, 0.11)
			for leaf_index: int in range(8):
				var t := 0.12 + 0.104 * float(leaf_index)
				var angle_leaf := float(leaf_index) * 2.399 + float(cluster) * 0.31 + float(fan) * 0.43
				var around := cos(angle_leaf)
				var rise := sin(angle_leaf)
				var leaf_at := start.lerp(tip, t) + lateral * around * 0.12 + up * rise * 0.13
				var axis := (direction * 0.32 + lateral * around * 0.80 + Vector3.UP * rise * 0.30).normalized()
				var leaf_up := (up * 0.50 + Vector3.UP + lateral * around * 0.30 - direction * rise * 0.15).normalized()
				var length := g.rng.randf_range(0.32, 0.44) * (1.06 - 0.045 * float(leaf_index / 2))
				_leaf(g, leaf_at, axis, leaf_up, length, length * g.rng.randf_range(0.68, 0.86), g.shade(fan_tint, 0.06), tier)
			_leaf(g, tip - direction * 0.035, direction, up, 0.29, 0.17, fan_tint.lightened(0.07), tier)
			proxies.append({"at": start, "tip": tip, "side": lateral, "up": up, "tint": fan_tint})
	crown_indices = g.indices.duplicate()
	# The far LOD retains the same closed irregular shoot volumes and trunk.
	# It drops subpixel leaf margins and hidden twig cylinders, not the canopy.
	var proxy_start: int = g.indices.size()
	for fan: Dictionary in proxies:
		_proxy(g, fan)
	var lod_indices := trunk_indices.duplicate()
	lod_indices.append_array(g.indices.slice(proxy_start))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g.positions
	arrays[Mesh.ARRAY_NORMAL] = g.normals
	arrays[Mesh.ARRAY_COLOR] = g.colors
	arrays[Mesh.ARRAY_INDEX] = crown_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {0.29: lod_indices})
	mesh.custom_aabb = _bounds
	mesh.set_meta("lod_triangles", lod_indices.size() / 3)
	mesh.set_meta("leaf_count", centers.size() * 5 * 9)
	return mesh

static func _leaf(g: RefCounted, at: Vector3, axis: Vector3, up: Vector3, length: float, width: float, tint: Color, tier: float) -> void:
	var side := axis.cross(up).normalized()
	up = side.cross(axis).normalized()
	# A pointed, softly lobed closed blade: a raised vein and a curved tip.
	var outline: Array[Vector2] = [Vector2(0, 0), Vector2(0.18, 0.34), Vector2(0.47, 0.50), Vector2(0.79, 0.36), Vector2(1.0, 0), Vector2(0.77, -0.38), Vector2(0.42, -0.48), Vector2(0.16, -0.30)]
	var points: Array[Vector3] = []
	for p: Vector2 in outline:
		points.append(at + axis * p.x * length + side * p.y * width + up * (sin(p.x * PI) * 0.033 - p.x * p.x * 0.035))
	var ridge := at + axis * length * 0.44 + up * 0.050
	var lower := at + axis * length * 0.43 - up * 0.015
	for i: int in range(8):
		var next := (i + 1) % 8
		_face(g, ridge, points[i], points[next], tint.lightened(0.055 + tier * 0.025), up, 0.66)
		_face(g, lower, points[next], points[i], tint.darkened(0.20), -up, 0.48)

static func _proxy(g: RefCounted, fan: Dictionary) -> void:
	var start: Vector3 = fan.at
	var tip: Vector3 = fan.tip
	var side: Vector3 = fan.side
	var up: Vector3 = fan.up
	var d: Vector3 = (tip - start).normalized()
	# Three overlapping rounded leaf groups replace a single large blade.
	# Their unequal offsets retain the shoot silhouette without fern-like tips.
	for group: int in range(3):
		var t: float = [0.24, 0.52, 0.88][group]
		var sign_value: float = [-1.0, 1.0, -0.12][group]
		var center := start.lerp(tip, t) + side * sign_value * 0.12 + up * float(group % 2) * 0.025
		var axis := (d * 0.78 + side * sign_value * 0.45).normalized()
		var lateral := axis.cross(up).normalized()
		var length: float = [0.34, 0.33, 0.30][group]
		var width: float = [0.23, 0.25, 0.21][group]
		var tint: Color = (fan.tint as Color).lightened(0.025 * float(group))
		var rim: Array[Vector3] = []
		for i: int in range(8):
			var angle := TAU * float(i) / 8.0
			var uneven := 1.0 + 0.055 * sin(float(i * 3 + group))
			rim.append(center + axis * cos(angle) * length * uneven + lateral * sin(angle) * width * uneven - up * 0.025 * cos(angle))
		var top := center + up * 0.095 - axis * 0.045
		var bottom := center - up * 0.070
		for i: int in range(8):
			var next := (i + 1) % 8
			_lobe_face(g, top, rim[i], rim[next], center, axis, lateral, up, length, width, tint)
			_lobe_face(g, bottom, rim[next], rim[i], center, axis, lateral, up, length, width, tint)

static func _lobe_face(g: RefCounted, a: Vector3, b: Vector3, c: Vector3, center: Vector3, axis: Vector3, side: Vector3, up: Vector3, length: float, width: float, tint: Color) -> void:
	a = a.clamp(_bounds.position, _bounds.end)
	b = b.clamp(_bounds.position, _bounds.end)
	c = c.clamp(_bounds.position, _bounds.end)
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - center) < 0.0:
		var swap := b; b = c; c = swap; normal = -normal
	var first: int = g.positions.size()
	for p: Vector3 in [a,b,c]:
		var offset := p - center
		var round_normal := (axis * offset.dot(axis) / (length * length) + side * offset.dot(side) / (width * width) + up * offset.dot(up) / (0.095 * 0.095)).normalized()
		g.positions.append(p)
		g.normals.append(normal.lerp(round_normal, 0.85).normalized())
		var pigment := tint.darkened(0.12).lerp(tint.lightened(0.075), clampf(offset.dot(up) / 0.16 + 0.5, 0.0, 1.0))
		g.colors.append(pigment.lerp(pigment.srgb_to_linear(), 0.4))
	g.indices.append_array(PackedInt32Array([first, first + 2, first + 1]))

static func _face(g: RefCounted, a: Vector3, b: Vector3, c: Vector3, tint: Color, average_normal: Vector3, smooth_amount: float) -> void:
	a = a.clamp(_bounds.position, _bounds.end)
	b = b.clamp(_bounds.position, _bounds.end)
	c = c.clamp(_bounds.position, _bounds.end)
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(average_normal) < 0.0:
		var swap := b; b = c; c = swap; normal = -normal
	var first: int = g.positions.size()
	var n := normal.lerp(average_normal, smooth_amount).normalized()
	for p: Vector3 in [a,b,c]:
		g.positions.append(p); g.normals.append(n)
		g.colors.append(tint.lerp(tint.srgb_to_linear(), 0.4))
	g.indices.append_array(PackedInt32Array([first, first + 2, first + 1]))
