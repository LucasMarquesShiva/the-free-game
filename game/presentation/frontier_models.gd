extends RefCounted
## Arquitetura tridimensional original baseada nas pranchas aprovadas.
## API estática; frente +Z, centro do lote na origem, solo Y=0.
## Um ArrayMesh com até oito superfícies + um MultiMesh de telhas por prédio.

const STONE := Color("b6ac8c")
const PALE_STONE := Color("d2c5a3")
const PLASTER := Color("dbcba4")
const TIMBER := Color("674629")
const WOOD := Color("aa763d")
const RED_TILE := Color("b86732")
const TEAL := Color("176567")
const GOLD := Color("bd9346")
const DARK := Color("353c32")
const LEAF := Color("677b30")
const MATERIAL_KEYS := ["stone","plaster","wood","roof","cloth","glass","foliage","metal"]

static var _materials: Dictionary = {}
static var _primitives: Dictionary = {}
static var _models: Dictionary = {}
static var _tile_mesh: ArrayMesh

class SurfaceData extends RefCounted:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

class Batch extends RefCounted:
	var surfaces: Dictionary = {}
	var tiles: Array[Transform3D] = []
	var tile_colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	var parts := 0

	func _init(seed_value: int = 1) -> void:
		rng.seed = seed_value

	func shade(color: Color, amount: float = 0.075) -> Color:
		var change := rng.randf_range(-amount,amount)
		return color.lightened(change) if change >= 0 else color.darkened(-change)

	func surface(key: String) -> SurfaceData:
		if not surfaces.has(key):
			surfaces[key] = SurfaceData.new()
		return surfaces[key]

	func append(mesh: Mesh, transform: Transform3D, key: String, color: Color) -> void:
		var arrays := mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var target := surface(key)
		var offset := target.vertices.size()
		var normal_transform := transform.basis.inverse().transposed()
		for i in range(positions.size()):
			target.vertices.append(transform * positions[i])
			target.normals.append((normal_transform * source_normals[i]).normalized())
			target.uvs.append(source_uvs[i] if i < source_uvs.size() else Vector2.ZERO)
			target.colors.append(color)
		if source_indices.is_empty():
			for i in range(positions.size()):
				target.indices.append(offset+i)
		else:
			for i in source_indices:
				target.indices.append(offset+i)
		parts += 1

	func triangle(a: Vector3, c: Vector3, d: Vector3, key: String, color: Color, normal: Vector3 = Vector3.ZERO) -> void:
		var target := surface(key)
		var offset := target.vertices.size()
		var n := normal if not normal.is_zero_approx() else (c-a).cross(d-a).normalized()
		for p in [a,c,d]:
			target.vertices.append(p)
			target.normals.append(n)
			target.colors.append(color)
			target.uvs.append(Vector2(p.x+p.z,p.y))
		# Índices horários do Godot; normais orientadas para fora da superfície.
		target.indices.append_array(PackedInt32Array([offset,offset+2,offset+1]))

	func quad(a: Vector3, c: Vector3, d: Vector3, e: Vector3, key: String, color: Color) -> void:
		triangle(a,c,d,key,color)
		triangle(a,d,e,key,color)

	func finish(shared_materials: Dictionary, roof_tile: Mesh) -> Dictionary:
		var mesh := ArrayMesh.new()
		var vertex_count := 0
		for key in MATERIAL_KEYS:
			if not surfaces.has(key):
				continue
			var data: SurfaceData = surfaces[key]
			if data.vertices.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = data.vertices
			arrays[Mesh.ARRAY_NORMAL] = data.normals
			arrays[Mesh.ARRAY_COLOR] = data.colors
			arrays[Mesh.ARRAY_TEX_UV] = data.uvs
			arrays[Mesh.ARRAY_INDEX] = data.indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(mesh.get_surface_count()-1,shared_materials[key])
			vertex_count += data.vertices.size()
		var roof: MultiMesh
		if not tiles.is_empty():
			roof = MultiMesh.new()
			roof.transform_format = MultiMesh.TRANSFORM_3D
			roof.use_colors = true
			roof.mesh = roof_tile
			roof.instance_count = tiles.size()
			for i in range(tiles.size()):
				roof.set_instance_transform(i,tiles[i])
				roof.set_instance_color(i,tile_colors[i])
		return {"mesh":mesh,"tiles":roof,"vertices":vertex_count,"parts":parts,"tile_count":tiles.size(),"draw_calls":mesh.get_surface_count()+(1 if roof != null else 0)}

static func building(kind: String) -> Node3D:
	if not _models.has(kind):
		var batch := Batch.new(absi(kind.hash())+7109)
		match kind:
			"hall": _hall(batch)
			"house": _house(batch)
			"training": _training(batch)
			"store": _store(batch)
			"winery": _winery(batch)
			"lumber": _lumber(batch)
			"quarry": _quarry(batch)
			"farm": _farm(batch)
			"vineyard": _vineyard(batch)
			_: _house(batch)
		_models[kind] = _finish(batch)
	return _instantiate(_models[kind],"Building_"+kind)

static func tree(seed_value: int = 1) -> Node3D:
	var batch := Batch.new(seed_value)
	_tree(batch,Vector3.ZERO,1.0)
	return _instantiate(_finish(batch),"Tree_%d" % seed_value)

static func rock(seed_value: int = 1) -> Node3D:
	var batch := Batch.new(seed_value)
	for i in range(3):
		var p := Vector3(batch.rng.randf_range(-0.4,0.4),0.2+i*0.09,batch.rng.randf_range(-0.4,0.4))
		_ellipsoid(batch,p,Vector3(0.6,0.42,0.48)*batch.rng.randf_range(0.7,1.4),batch.shade(STONE,0.16),"stone",true)
	return _instantiate(_finish(batch),"Rock_%d" % seed_value)

static func _finish(batch: Batch) -> Dictionary:
	for key in MATERIAL_KEYS:
		_material(key)
	return batch.finish(_materials,_roof_tile())

static func _instantiate(asset: Dictionary, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var masonry := MeshInstance3D.new()
	masonry.name = "Architecture"
	masonry.mesh = asset.mesh
	root.add_child(masonry)
	if asset.tiles != null:
		var roof := MultiMeshInstance3D.new()
		roof.name = "IndividualCurvedRoofTiles"
		roof.multimesh = asset.tiles
		roof.material_override = _material("roof")
		root.add_child(roof)
	root.set_meta("draw_calls",asset.draw_calls)
	root.set_meta("detail_parts",asset.parts)
	root.set_meta("roof_tiles",asset.tile_count)
	root.set_meta("vertices",asset.vertices)
	root.set_meta("front",Vector3.FORWARD*-1)
	root.set_meta("footprint_m",Vector2(4.7,4.7))
	return root

static func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = "Frontier_"+key
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.86
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key in ["stone","plaster","wood"]:
		var noise := FastNoiseLite.new()
		noise.seed = 501 if key == "wood" else 302
		noise.frequency = 0.08 if key == "wood" else 0.055
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.seamless = true
		texture.noise = noise
		var gradient := Gradient.new()
		gradient.set_color(0,Color(0.77,0.77,0.77))
		gradient.set_color(1,Color.WHITE)
		texture.color_ramp = gradient
		material.albedo_texture = texture
		if key == "wood":
			material.uv1_scale = Vector3(2.0,0.14,1.0)
			material.roughness = 0.76
	elif key == "metal":
		material.metallic = 0.55
		material.roughness = 0.36
	elif key == "glass":
		material.roughness = 0.27
		material.metallic = 0.2
		material.emission_enabled = true
		material.emission = Color("df9a45")
		material.emission_energy_multiplier = 0.16
	elif key == "cloth":
		material.roughness = 1.0
	_materials[key] = material
	return material

static func _primitive(kind: String) -> Mesh:
	if _primitives.has(kind):
		return _primitives[kind]
	var mesh: Mesh
	match kind:
		"box": mesh = BoxMesh.new()
		"bevel": mesh = _beveled_cube()
		"sphere", "rock":
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 12 if kind == "sphere" else 7
			sphere.rings = 6 if kind == "sphere" else 3
			mesh = sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.0
			cylinder.height = 1.0
			cylinder.radial_segments = 12
			mesh = cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.0
			cone.height = 1.0
			cone.radial_segments = 12
			mesh = cone
	_primitives[kind] = mesh
	return mesh

static func _box(b: Batch, at: Vector3, size: Vector3, color: Color, material: String = "wood", rotation: Vector3 = Vector3.ZERO, bevel: bool = false) -> void:
	var basis := Basis.from_euler(rotation).scaled_local(size)
	b.append(_primitive("bevel" if bevel else "box"),Transform3D(basis,at),material,color)

static func _beam(b: Batch, from: Vector3, to: Vector3, width: float, color: Color = TIMBER, material: String = "wood") -> void:
	if from.distance_to(to) < 0.001:
		return
	var basis := Basis(Quaternion(Vector3.UP,(to-from).normalized())).scaled_local(Vector3(width,from.distance_to(to),width))
	b.append(_primitive("bevel"),Transform3D(basis,(from+to)*0.5),material,color)

static func _cylinder(b: Batch, at: Vector3, radius: float, height: float, color: Color, material: String = "wood", rotation: Vector3 = Vector3.ZERO, pointed: bool = false) -> void:
	b.append(_primitive("cone" if pointed else "cylinder"),Transform3D(Basis.from_euler(rotation).scaled_local(Vector3(radius,height,radius)),at),material,color)

static func _ellipsoid(b: Batch, at: Vector3, size: Vector3, color: Color, material: String = "foliage", faceted: bool = false) -> void:
	var rotation := Vector3(b.rng.randf_range(-0.25,0.25),b.rng.randf()*TAU,b.rng.randf_range(-0.2,0.2))
	b.append(_primitive("rock" if faceted else "sphere"),Transform3D(Basis.from_euler(rotation).scaled_local(size),at),material,color)

static func _beveled_cube() -> ArrayMesh:
	var b := Batch.new()
	var half := 0.5
	var inner := 0.42
	for axis in range(3):
		for sign_value in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis] = sign_value*half
				p[(axis+1)%3] = pair.x*inner
				p[(axis+2)%3] = pair.y*inner
				points.append(p)
			_outward_face(b,points)
	for free_axis in range(3):
		var a := (free_axis+1)%3
		var c := (free_axis+2)%3
		for sign_a in [-1.0,1.0]:
			for sign_c in [-1.0,1.0]:
				var points: Array[Vector3] = []
				for step in [Vector3(-1,0,1),Vector3(1,0,1),Vector3(1,1,0),Vector3(-1,1,0)]:
					var p := Vector3.ZERO
					p[free_axis] = step.x*inner
					p[a] = sign_a*(half if step.y == 0 else inner)
					p[c] = sign_c*(half if step.z == 0 else inner)
					points.append(p)
				_outward_face(b,points)
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				_outward_face(b,[Vector3(x*half,y*inner,z*inner),Vector3(x*inner,y*half,z*inner),Vector3(x*inner,y*inner,z*half)])
	var data: SurfaceData = b.surfaces["stone"]
	return _mesh_from_data(data)

static func _outward_face(b: Batch, points: Array[Vector3]) -> void:
	var average := Vector3.ZERO
	for point in points:
		average += point
	var normal := (points[1]-points[0]).cross(points[2]-points[0])
	if normal.dot(average) < 0:
		points.reverse()
	for i in range(1,points.size()-1):
		b.triangle(points[0],points[i],points[i+1],"stone",Color.WHITE)

static func _mesh_from_data(data: SurfaceData) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_INDEX] = data.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _roof_tile() -> ArrayMesh:
	if _tile_mesh != null:
		return _tile_mesh
	var b := Batch.new()
	# Telha arqueada, espessura real e bordo inferior arredondado em oito segmentos.
	for segment in range(8):
		var z0 := float(segment)/8.0-0.5
		var z1 := float(segment+1)/8.0-0.5
		var y0 := 0.027+0.033*cos(z0*PI)
		var y1 := 0.027+0.033*cos(z1*PI)
		var end0 := 0.44+0.065*cos(z0*PI)
		var end1 := 0.44+0.065*cos(z1*PI)
		b.quad(Vector3(-0.5,y0,z0),Vector3(-0.5,y1,z1),Vector3(end1,y1,z1),Vector3(end0,y0,z0),"stone",Color.WHITE)
		b.quad(Vector3(end0,-0.015,z0),Vector3(end1,-0.015,z1),Vector3(end1,y1,z1),Vector3(end0,y0,z0),"stone",Color.WHITE)
	b.quad(Vector3(-0.5,0.027,-0.5),Vector3(-0.5,0.027,0.5),Vector3(-0.5,-0.015,0.5),Vector3(-0.5,-0.015,-0.5),"stone",Color.WHITE)
	_tile_mesh = _mesh_from_data(b.surfaces["stone"])
	return _tile_mesh

static func _foundation(b: Batch, size: Vector2 = Vector2(4.6,4.6)) -> void:
	_box(b,Vector3(0,0.09,0),Vector3(size.x,0.18,size.y),b.shade(Color("8f8a68")),"stone",Vector3.ZERO,true)
	for i in range(15):
		var x := b.rng.randf_range(-size.x*0.45,size.x*0.45)
		var z := b.rng.randf_range(-size.y*0.45,size.y*0.45)
		_box(b,Vector3(x,0.195,z),Vector3(b.rng.randf_range(0.22,0.45),0.065,b.rng.randf_range(0.20,0.36)),b.shade(PALE_STONE,0.10),"stone",Vector3(0,b.rng.randf()*0.4,0),true)

static func _body(b: Batch, at: Vector3, width: float, depth: float, height: float, stone_height: float = 1.0) -> void:
	_box(b,at+Vector3(0,height*0.5,0),Vector3(width,height,depth),b.shade(PLASTER,0.035),"plaster")
	_box(b,at+Vector3(0,stone_height*0.5,0),Vector3(width+0.04,stone_height,depth+0.04),STONE.darkened(0.15),"stone")
	for side in [-1.0,1.0]:
		_stone_face(b,at+Vector3(0,0,side*(depth*0.5+0.04)),width,stone_height,0.0 if side>0 else PI)
		_stone_face(b,at+Vector3(side*(width*0.5+0.04),0,0),depth,stone_height,PI*0.5*side)
	for y in [0.16,stone_height+0.05,height*0.53,height-0.07]:
		_box(b,at+Vector3(0,y,0),Vector3(width+0.19,0.14,depth+0.18),TIMBER,"wood",Vector3.ZERO,true)
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]:
			_box(b,at+Vector3(x,height*0.5,z),Vector3(0.18,height+0.12,0.18),TIMBER,"wood",Vector3.ZERO,true)
	for side in [-1.0,1.0]:
		for x in [-width*0.25,width*0.25]:
			_box(b,at+Vector3(x,(height+stone_height)*0.5,side*(depth*0.5+0.03)),Vector3(0.11,height-stone_height,0.12),TIMBER)
		for z in [-depth*0.25,depth*0.25]:
			_box(b,at+Vector3(side*(width*0.5+0.03),(height+stone_height)*0.5,z),Vector3(0.12,height-stone_height,0.11),TIMBER)
		_beam(b,at+Vector3(-width*0.49,stone_height+0.12,side*(depth*0.5+0.08)),at+Vector3(-width*0.27,height*0.53-0.04,side*(depth*0.5+0.08)),0.09,WOOD)
		_beam(b,at+Vector3(width*0.49,stone_height+0.12,side*(depth*0.5+0.08)),at+Vector3(width*0.27,height*0.53-0.04,side*(depth*0.5+0.08)),0.09,WOOD)

static func _stone_face(b: Batch, at: Vector3, width: float, height: float, rotation: float = 0.0) -> void:
	var rows := maxi(1,ceili(height/0.28))
	var row_height := height/rows
	var basis := Basis(Vector3.UP,rotation)
	for row in range(rows):
		var count := maxi(2,ceili(width/0.42))
		var block_width := width/count
		var stagger := 0.5 if row%2 else 0.0
		for col in range(count+(1 if row%2 else 0)):
			var left := maxf(-width*0.5,-width*0.5+(col-stagger)*block_width)
			var right := minf(width*0.5,-width*0.5+(col+1.0-stagger)*block_width)
			var p := Vector3((left+right)*0.5,(row+0.5)*row_height,b.rng.randf_range(0.025,0.055))
			_box(b,at+basis*p,Vector3(right-left-0.022,row_height-0.025,0.11),b.shade(STONE,0.14),"stone",Vector3(0,rotation,0),true)

static func _roof(b: Batch, at: Vector3, width: float, depth: float, rise: float, teal: bool = false) -> void:
	var tile_color := TEAL if teal else RED_TILE
	var half := width*0.5
	var slope := sqrt(half*half+rise*rise)
	var rows := maxi(3,ceili(slope/0.31))
	var columns := maxi(3,ceili(depth/0.23))
	for side in [-1.0,1.0]:
		var ridge_front := at+Vector3(0,rise,depth*0.5)
		var eave_front := at+Vector3(side*half,0,depth*0.5)
		var ridge_back := at+Vector3(0,rise,-depth*0.5)
		var eave_back := at+Vector3(side*half,0,-depth*0.5)
		b.quad(ridge_front-Vector3.UP*0.18,eave_front-Vector3.UP*0.18,eave_back-Vector3.UP*0.18,ridge_back-Vector3.UP*0.18,"roof",tile_color.darkened(0.20))
		for row in range(rows):
			var t := (float(row)+0.5)/rows
			var angle: float = -side*atan2(rise+0.14*PI*cos(t*PI),half)
			for col in range(columns):
				var z := -depth*0.5+(col+0.5)*depth/columns
				var y := rise*(1-t)-0.14*sin(t*PI)+0.015
				var position := at+Vector3(side*half*t,y,z)
				# Eixo Z positivo orienta a telha tangente ao plano inclinado.
				var basis := Basis(Vector3.BACK,angle).scaled_local(Vector3(slope/rows*1.20,1.0,depth/columns*0.98))
				b.tiles.append(Transform3D(basis,position))
				b.tile_colors.append(b.shade(tile_color,0.13))
		for z in [-depth*0.5-0.035,depth*0.5+0.035]:
			_beam(b,at+Vector3(-side*0.055,rise+0.05,z),at+Vector3(side*(half+0.06),-0.015,z),0.16,TIMBER)
			_beam(b,at+Vector3(side*(half-0.18),0.06,z),at+Vector3(side*(half+0.16),0.13,z),0.11,WOOD)
		_beam(b,at+Vector3(side*half,-0.03,-depth*0.5),at+Vector3(side*half,-0.03,depth*0.5),0.17,TIMBER)
	for i in range(columns):
		_cylinder(b,at+Vector3(0,rise+0.07,-depth*0.5+(i+0.5)*depth/columns),0.12,depth/columns*0.91,b.shade(tile_color.lightened(0.08),0.09),"roof",Vector3(PI*0.5,0,0))
	for z in [-depth*0.5-0.05,depth*0.5+0.05]:
		_cylinder(b,at+Vector3(0,rise+0.09,z),0.145,0.08,WOOD,"wood",Vector3(PI*0.5,0,0))

static func _gable(b: Batch, at: Vector3, width: float, rise: float) -> void:
	b.triangle(at+Vector3(-width*0.5,0,0),at+Vector3(width*0.5,0,0),at+Vector3(0,rise,0),"plaster",PLASTER)
	_beam(b,at+Vector3(-width*0.5,0,0.015),at+Vector3(width*0.5,0,0.015),0.13,TIMBER)
	_beam(b,at+Vector3(0,0,0.03),at+Vector3(0,rise,0.03),0.13,TIMBER)
	for sign_value in [-1.0,1.0]:
		_beam(b,at+Vector3(sign_value*width*0.45,0.015,0.02),at+Vector3(0,rise*0.93,0.02),0.13,TIMBER)
		_beam(b,at+Vector3(sign_value*width*0.20,0.04,0.03),at+Vector3(sign_value*width*0.20,rise*0.48,0.03),0.07,WOOD)

static func _door(b: Batch, facade: Vector3, width: float = 0.82, height: float = 1.50, teal: bool = false) -> void:
	var at := facade+Vector3(0,0,0.17)
	var radius := width*0.5
	var straight := height-radius
	var door_color := TEAL.darkened(0.1) if teal else TIMBER.darkened(0.18)
	for i in range(7):
		var x := (i+0.5)*width/7.0-radius
		var h := straight+sqrt(maxf(0,radius*radius-x*x))
		_box(b,at+Vector3(x,h*0.5,0),Vector3(width/7.0-0.012,h,0.07),b.shade(door_color,0.07),"wood",Vector3.ZERO,true)
	for side in [-1.0,1.0]:
		for row in range(5):
			_box(b,at+Vector3(side*(radius+0.115),(row+0.5)*straight/5.0,0.035),Vector3(0.22,straight/5.0-0.016,0.19),b.shade(PALE_STONE,0.07),"stone",Vector3.ZERO,true)
	for i in range(9):
		var angle := (float(i)+0.5)/9.0*PI
		_box(b,at+Vector3(cos(angle)*(radius+0.11),straight+sin(angle)*(radius+0.11),0.035),Vector3(0.23,0.21,0.19),b.shade(PALE_STONE,0.09),"stone",Vector3(0,0,angle-PI*0.5),true)
	for y in [0.28,0.86]:
		_box(b,at+Vector3(0,y,0.058),Vector3(width*0.9,0.055,0.04),DARK,"metal",Vector3.ZERO,true)
		for x in [-radius*0.67,radius*0.67]:
			_cylinder(b,at+Vector3(x,y,0.087),0.029,0.026,GOLD,"metal",Vector3(PI*0.5,0,0))
	_cylinder(b,at+Vector3(radius*0.44,0.63,0.08),0.044,0.04,GOLD,"metal",Vector3(PI*0.5,0,0))

static func _window(b: Batch, facade: Vector3, size: Vector2 = Vector2(0.64,0.83), rotation: float = 0.0, shutters: bool = true) -> void:
	var basis := Basis(Vector3.UP,rotation)
	var at := facade+basis*Vector3(0,0,0.10)
	var color := Color("b99a50")
	_box(b,at,Vector3(size.x+0.13,size.y+0.13,0.055),TIMBER.darkened(0.32),"wood",Vector3(0,rotation,0),true)
	_box(b,at+basis*Vector3(0,0,0.035),Vector3(size.x-0.07,size.y-0.08,0.038),color,"glass",Vector3(0,rotation,0))
	for x in [-size.x*0.5,0.0,size.x*0.5]:
		_box(b,at+basis*Vector3(x,0,0.078),Vector3(0.065,size.y+0.09,0.07),WOOD.lightened(0.15),"wood",Vector3(0,rotation,0),true)
	for y in [-size.y*0.5,0.05,size.y*0.5]:
		_box(b,at+basis*Vector3(0,y,0.075),Vector3(size.x+0.12,0.063,0.09),WOOD.lightened(0.15),"wood",Vector3(0,rotation,0),true)
	_box(b,at+basis*Vector3(0,-size.y*0.5-0.065,0.055),Vector3(size.x+0.28,0.13,0.22),PALE_STONE,"stone",Vector3(0,rotation,0),true)
	if shutters:
		for side in [-1.0,1.0]:
			var shutter_position := at+basis*Vector3(side*(size.x*0.5+0.20),0,0.025)
			_box(b,shutter_position,Vector3(0.25,size.y*0.92,0.075),TEAL,"wood",Vector3(0,rotation+side*0.18,0),true)
			for y in [-size.y*0.28,size.y*0.28]:
				_box(b,shutter_position+basis*Vector3(0,y,0.06),Vector3(0.23,0.045,0.045),GOLD.darkened(0.2),"metal",Vector3(0,rotation,0))

static func _chimney(b: Batch, at: Vector3, height: float = 1.65) -> void:
	_box(b,at+Vector3(0,height*0.5,0),Vector3(0.53,height,0.54),STONE.darkened(0.16),"stone")
	for side in [-1.0,1.0]:
		_stone_face(b,at+Vector3(0,0,side*0.29),0.53,height,0.0 if side>0 else PI)
		_stone_face(b,at+Vector3(side*0.285,0,0),0.54,height,PI*0.5*side)
	_box(b,at+Vector3(0,height+0.04,0),Vector3(0.71,0.16,0.72),PALE_STONE,"stone",Vector3.ZERO,true)
	_box(b,at+Vector3(0,height+0.13,0),Vector3(0.47,0.03,0.48),DARK,"stone")
	for x in [-0.30,0.30]:
		_box(b,at+Vector3(x,height+0.18,0),Vector3(0.12,0.12,0.72),STONE,"stone",Vector3.ZERO,true)
	for z in [-0.30,0.30]:
		_box(b,at+Vector3(0,height+0.18,z),Vector3(0.49,0.12,0.12),STONE,"stone",Vector3.ZERO,true)

static func _steps(b: Batch, x: float, z: float, width: float = 1.2, levels: int = 3) -> void:
	for level in range(levels):
		var height := (levels-level)*0.12
		_box(b,Vector3(x,height*0.5+0.02,z+level*0.21),Vector3(width,height,0.29),b.shade(PALE_STONE,0.065),"stone",Vector3.ZERO,true)

static func _banner(b: Batch, at: Vector3, width: float = 0.66, height: float = 1.10, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	for col in range(5):
		var x0 := -width*0.5+col*width/5.0
		var x1 := -width*0.5+(col+1)*width/5.0
		var bottom0 := -height+(absf(x0)/(width*0.5))*0.18
		var bottom1 := -height+(absf(x1)/(width*0.5))*0.18
		var z0 := 0.035*sin(float(col)*1.3)
		var z1 := 0.035*sin(float(col+1)*1.3)
		b.quad(at+basis*Vector3(x0,0,z0),at+basis*Vector3(x0,bottom0,z0),at+basis*Vector3(x1,bottom1,z1),at+basis*Vector3(x1,0,z1),"cloth",TEAL)
		_beam(b,at+basis*Vector3(x0,bottom0,0.018),at+basis*Vector3(x1,bottom1,0.018),0.025,GOLD,"metal")
	_beam(b,at+basis*Vector3(-width*0.66,0.06,0),at+basis*Vector3(width*0.66,0.06,0),0.055,GOLD,"metal")
	for p in [Vector2(-0.13,-0.35),Vector2(0.02,-0.35),Vector2(0.16,-0.35),Vector2(-0.06,-0.49),Vector2(0.10,-0.49),Vector2(0.03,-0.63)]:
		_ellipsoid(b,at+basis*Vector3(p.x*width/0.66,p.y*height/1.1,0.053),Vector3(0.065,0.074,0.025)*width/0.66,GOLD,"metal")
	_beam(b,at+basis*Vector3(0,-0.20,0.06),at+basis*Vector3(0.04,-0.28,0.06),0.024,GOLD,"metal")

static func _barrel(b: Batch, at: Vector3, scale_factor: float = 1.0, horizontal: bool = false) -> void:
	var axis := Basis(Vector3.RIGHT,PI*0.5) if horizontal else Basis.IDENTITY
	var center := at+Vector3.UP*0.34*scale_factor
	for row in range(5):
		var y := (row+0.5)*0.13-0.325
		var radius := 0.245+0.033*cos(y/0.325*PI*0.5)
		_cylinder(b,center+axis*Vector3(0,y,0)*scale_factor,radius*scale_factor,0.131*scale_factor,b.shade(WOOD,0.08),"wood",Vector3(PI*0.5,0,0) if horizontal else Vector3.ZERO)
	for y in [-0.265,-0.13,0.15,0.265]:
		_cylinder(b,center+axis*Vector3(0,y,0)*scale_factor,0.281*scale_factor,0.033*scale_factor,DARK.lightened(0.1),"metal",Vector3(PI*0.5,0,0) if horizontal else Vector3.ZERO)
	for i in range(12):
		var angle := float(i)/12.0*TAU
		_beam(b,center+axis*Vector3(cos(angle)*0.247,-0.32,sin(angle)*0.247)*scale_factor,center+axis*Vector3(cos(angle)*0.247,0.32,sin(angle)*0.247)*scale_factor,0.015*scale_factor,TIMBER)

static func _crate(b: Batch, at: Vector3, scale_factor: float = 1.0) -> void:
	var center := at+Vector3.UP*0.24*scale_factor
	_box(b,center,Vector3(0.57,0.47,0.51)*scale_factor,WOOD.darkened(0.12),"wood",Vector3.ZERO,true)
	for side in [-1.0,1.0]:
		for row in range(4):
			_box(b,center+Vector3(0,(row-1.5)*0.115,side*0.263)*scale_factor,Vector3(0.55,0.095,0.035)*scale_factor,b.shade(WOOD,0.09))
		for x in [-0.22,0.22]:
			_box(b,center+Vector3(x,0,side*0.285)*scale_factor,Vector3(0.055,0.49,0.04)*scale_factor,TIMBER)
		_beam(b,center+Vector3(-0.23,-0.20,side*0.30)*scale_factor,center+Vector3(0.23,0.20,side*0.30)*scale_factor,0.047*scale_factor,TIMBER)

static func _fence(b: Batch, from: Vector3, to: Vector3, height: float = 0.62) -> void:
	var count := maxi(1,ceili(from.distance_to(to)/0.60))
	for i in range(count+1):
		var p := from.lerp(to,float(i)/count)
		_box(b,p+Vector3.UP*height*0.5,Vector3(0.105,height,0.105),TIMBER,"wood",Vector3.ZERO,true)
		_cylinder(b,p+Vector3.UP*(height+0.01),0.080,0.08,WOOD,"wood",Vector3.ZERO,true)
	for y in [height*0.36,height*0.82]:
		_beam(b,from+Vector3.UP*y,to+Vector3.UP*y,0.065,WOOD)

static func _flowers(b: Batch, at: Vector3, width: float = 0.62) -> void:
	_box(b,at,Vector3(width,0.17,0.22),TIMBER,"wood",Vector3.ZERO,true)
	for i in range(7):
		var p := at+Vector3(b.rng.randf_range(-width*0.44,width*0.44),0.13,b.rng.randf_range(-0.07,0.07))
		_ellipsoid(b,p,Vector3(0.105,0.08,0.095),b.shade(LEAF,0.15),"foliage")
		_ellipsoid(b,p+Vector3(0,0.075,0),Vector3(0.038,0.031,0.038),Color("e1c66b") if i%2 else Color("dfd9ac"),"foliage")

static func _moss(b: Batch, at: Vector3, spread: float = 0.5) -> void:
	for i in range(6):
		var p := at+Vector3(b.rng.randf_range(-spread,spread),0.06,b.rng.randf_range(-spread*0.5,spread*0.5))
		_ellipsoid(b,p,Vector3(0.13,0.085,0.09),b.shade(LEAF,0.16),"foliage",true)

static func _porch(b: Batch, at: Vector3, width: float = 1.65, depth: float = 0.90, height: float = 1.8, teal: bool = false) -> void:
	for side in [-1.0,1.0]:
		var p := at+Vector3(side*(width*0.5-0.11),height*0.5,depth*0.5-0.12)
		_box(b,p,Vector3(0.16,height,0.16),TIMBER,"wood",Vector3.ZERO,true)
		_beam(b,p+Vector3(0,height*0.5-0.45,0),p+Vector3(-side*0.35,height*0.5-0.05,0),0.10,WOOD)
	_roof(b,at+Vector3(0,height,0),width+0.10,depth+0.15,0.38,teal)

static func _dormer(b: Batch, at: Vector3, width: float = 0.85) -> void:
	_body(b,at,width,0.65,0.72,0.18)
	_gable(b,at+Vector3(0,0.72,0.33),width,0.42)
	_roof(b,at+Vector3(0,0.72,0),width+0.18,0.85,0.42)
	_window(b,at+Vector3(0,0.38,0.40),Vector2(width*0.53,0.46),0.0,false)

static func _house(b: Batch) -> void:
	_foundation(b)
	var at := Vector3(0.22,0.31,-0.35)
	_body(b,at,2.85,2.8,3.10,0.98)
	_gable(b,at+Vector3(0,3.10,1.41),2.85,1.28)
	_gable(b,at+Vector3(0,3.10,-1.41),2.85,1.28)
	_roof(b,at+Vector3(0,3.1,0),3.32,3.22,1.28)
	_door(b,Vector3(-0.54,0.34,1.11),0.72,1.42)
	_steps(b,-0.54,1.33,1.18)
	for x in [-0.50,1.00]:
		_window(b,Vector3(x,2.67,1.09),Vector2(0.57,0.77))
		_flowers(b,Vector3(x,2.19,1.21),0.67)
	for side in [-1.0,1.0]:
		for y in [1.20,2.68]:
			_window(b,Vector3(0.22+side*1.45,y,-0.59),Vector2(0.52,0.72),side*PI*0.5)
	_body(b,Vector3(-1.53,0.31,-0.49),0.76,2.1,1.51,0.68)
	_roof(b,Vector3(-1.53,1.82,-0.49),1.15,2.40,0.66)
	_chimney(b,Vector3(-0.57,3.23,-0.86),1.62)
	_banner(b,Vector3(0.22,4.25,1.26),0.48,0.77)
	_fence(b,Vector3(-2.10,0.21,1.86),Vector3(-1.35,0.21,1.86))
	_fence(b,Vector3(0.38,0.21,1.86),Vector3(2.08,0.21,1.86))
	_barrel(b,Vector3(1.74,0.20,0.81),0.84)
	_flowers(b,Vector3(1.62,0.31,1.52),0.77)
	_moss(b,Vector3(-1.88,0.21,0.86),0.23)

static func _hall(b: Batch) -> void:
	_foundation(b)
	var at := Vector3(0,0.43,-0.38)
	# Salão largo, torretas frontais e campanário central compõem a sede da vila.
	_body(b,at,3.92,3.20,2.96,1.43)
	_gable(b,at+Vector3(0,2.96,1.605),3.92,1.34)
	_gable(b,at+Vector3(0,2.96,-1.605),3.92,1.34)
	_roof(b,at+Vector3(0,2.96,0),4.34,3.66,1.34)
	for side in [-1.0,1.0]:
		_window(b,Vector3(side*0.93,2.47,1.27),Vector2(0.58,0.76))
		_window(b,Vector3(side*1.99,2.49,-0.52),Vector2(0.61,0.83),side*PI*0.5)
		_window(b,Vector3(side*1.99,1.20,-1.34),Vector2(0.53,0.78),side*PI*0.5)
		_turret(b,Vector3(side*1.63,0.22,1.14),0.54,3.44)
	var tower := Vector3(0,3.48,-0.14)
	_body(b,tower,1.25,1.21,2.20,0.44)
	_gable(b,tower+Vector3(0,2.20,0.615),1.25,0.86)
	_roof(b,tower+Vector3(0,2.20,0),1.68,1.67,0.86)
	_clock(b,tower+Vector3(0,1.52,0.75),0.43)
	for side in [-1.0,1.0]:
		_window(b,tower+Vector3(side*0.655,1.54,0),Vector2(0.49,0.64),side*PI*0.5,false)
	_door(b,Vector3(-0.16,0.45,1.30),1.22,2.16,true)
	_steps(b,-0.16,1.65,1.95,3)
	_banner(b,Vector3(0,4.31,1.49),0.64,0.90)
	_chimney(b,Vector3(-1.04,3.61,-1.10),1.38)
	_flag(b,Vector3(0,6.66,-0.14),0.75)
	_notice_board(b,Vector3(1.48,0.23,1.96))
	_moss(b,Vector3(-1.89,0.20,1.89),0.23)

static func _turret(b: Batch, at: Vector3, radius: float, height: float) -> void:
	_cylinder(b,at+Vector3.UP*height*0.5,radius,height,STONE.darkened(0.17),"stone")
	var rows := ceili(height/0.29)
	for row in range(rows):
		for segment in range(12):
			var angle := (float(segment)+(0.5 if row%2 else 0.0))/12.0*TAU
			var position := at+Vector3(sin(angle)*radius,(row+0.5)*height/rows,cos(angle)*radius)
			_box(b,position,Vector3(radius*0.51,height/rows-0.025,0.12),b.shade(STONE,0.13),"stone",Vector3(0,angle,0),true)
	for y in [0.13,height-0.18,height-0.03]:
		_cylinder(b,at+Vector3.UP*y,radius+0.10,0.16,b.shade(PALE_STONE,0.055),"stone")
	_window(b,at+Vector3(0,height*0.46,radius+0.055),Vector2(0.28,0.75),0.0,false)
	_banner(b,at+Vector3(0,height-0.26,radius+0.14),0.36,0.90)
	# Cobertura cônica de telhas reais orientadas para cada faixa radial.
	var roof_at := at+Vector3.UP*(height+0.04)
	var roof_radius := radius+0.18
	var rise := 0.89
	_cylinder(b,roof_at+Vector3.UP*rise*0.49,roof_radius,rise*0.98,RED_TILE.darkened(0.17),"roof",Vector3.ZERO,true)
	var slope := sqrt(roof_radius*roof_radius+rise*rise)
	for row in range(5):
		var t := (row+0.5)/5.0
		var count := maxi(6,ceili(TAU*roof_radius*t/0.23))
		for segment in range(count):
			var angle := (float(segment)+(0.5 if row%2 else 0.0))/count*TAU
			var radial := Vector3(sin(angle),0,cos(angle))
			var x_axis := (radial*roof_radius-Vector3.UP*rise).normalized()
			var y_axis := (radial*rise+Vector3.UP*roof_radius).normalized()
			var basis := Basis(x_axis,y_axis,x_axis.cross(y_axis)).scaled_local(Vector3(slope/5.0*1.26,1.0,TAU*roof_radius*t/count*1.03))
			b.tiles.append(Transform3D(basis,roof_at+radial*roof_radius*t+Vector3.UP*(rise*(1-t)+0.04)))
			b.tile_colors.append(b.shade(RED_TILE,0.11))
	_cylinder(b,roof_at+Vector3.UP*(rise+0.10),0.04,0.21,GOLD,"metal")
	_ellipsoid(b,roof_at+Vector3.UP*(rise+0.21),Vector3(0.071,0.071,0.071),GOLD,"metal")

static func _training(b: Batch) -> void:
	_foundation(b)
	var at := Vector3(0.26,0.30,-0.35)
	_body(b,at,3.07,2.95,2.83,1.07)
	_gable(b,at+Vector3(0,2.83,1.48),3.07,1.55)
	_roof(b,at+Vector3(0,2.83,0),3.62,3.40,1.55)
	_door(b,Vector3(-0.30,0.33,1.19),0.77,1.62)
	_steps(b,-0.30,1.40,1.41)
	_porch(b,Vector3(-0.26,0.29,1.32),2.00,1.05,1.75,true)
	_banner(b,Vector3(0.26,4.21,1.37),0.68,1.03)
	_window(b,Vector3(1.28,1.69,1.17),Vector2(0.52,0.80))
	for z in [-1.0,0.47]:
		_window(b,Vector3(1.83,1.94,z),Vector2(0.55,0.95),PI*0.5)
	_chimney(b,Vector3(1.06,3.08,-0.95),1.94)
	_dormer(b,Vector3(-0.76,3.65,0.22),0.70)
	_workbench(b,Vector3(-1.88,0.27,0.45),0.92)
	_crate(b,Vector3(1.86,0.22,1.11),0.77)
	_target(b,Vector3(1.86,0.22,1.88),0.40)
	_flag(b,Vector3(0.26,4.81,-0.78),0.81)
	_moss(b,Vector3(-1.65,0.20,-1.78),0.40)

static func _store(b: Batch) -> void:
	_foundation(b)
	_body(b,Vector3(0,0.30,-0.53),3.22,2.76,2.63,0.77)
	_gable(b,Vector3(0,2.93,0.86),3.22,1.40)
	_roof(b,Vector3(0,2.93,-0.53),3.73,3.25,1.40)
	_door(b,Vector3(-0.47,0.31,0.90),1.2,1.87)
	_porch(b,Vector3(0.36,0.30,1.28),3.38,1.12,1.77)
	_banner(b,Vector3(0,4.08,1.04),0.66,1.00)
	for at in [Vector3(-1.48,0.24,1.21),Vector3(1.3,0.24,0.99),Vector3(1.81,0.24,0.66),Vector3(1.50,0.24,1.73)]:
		_crate(b,at,0.95)
	_crate(b,Vector3(1.33,0.68,0.99),0.80)
	_barrel(b,Vector3(-1.59,0.25,1.83),0.86)
	for i in range(3):
		_sack(b,Vector3(-0.87+i*0.36,0.24,1.97),0.72)
	_window(b,Vector3(-1.64,1.84,-0.95),Vector2(0.64,0.88),-PI*0.5)
	_window(b,Vector3(1.64,1.84,-0.95),Vector2(0.64,0.88),PI*0.5)
	_chimney(b,Vector3(-0.96,2.86,-1.15),1.40)

static func _winery(b: Batch) -> void:
	_foundation(b)
	_body(b,Vector3(0.36,0.33,-0.28),2.60,2.91,2.96,1.52)
	_gable(b,Vector3(0.36,3.29,1.185),2.60,1.21)
	_roof(b,Vector3(0.36,3.29,-0.28),3.09,3.36,1.21)
	_door(b,Vector3(-0.18,0.34,1.23),0.86,1.67,true)
	_steps(b,-0.18,1.48,1.31)
	_banner(b,Vector3(0.37,4.14,1.30),0.64,1.02)
	_window(b,Vector3(1.15,2.45,1.21),Vector2(0.49,0.67))
	_window(b,Vector3(1.69,1.88,-0.80),Vector2(0.62,0.80),PI*0.5)
	_chimney(b,Vector3(1.12,3.15,-1.04),1.63)
	_dormer(b,Vector3(-0.53,3.55,0.05),0.64)
	_porch(b,Vector3(-1.47,0.27,-0.20),1.22,2.51,1.84)
	_press(b,Vector3(-1.55,0.29,0.08),0.86)
	_porch(b,Vector3(1.63,0.27,0.75),1.12,2.23,1.76)
	_barrel(b,Vector3(1.72,0.25,0.98),1.15,true)
	_barrel(b,Vector3(1.72,0.89,0.98),0.88,true)
	_barrel(b,Vector3(1.18,0.24,1.82),0.87)
	_barrel(b,Vector3(1.82,0.24,1.72),0.77)
	_crate(b,Vector3(-1.63,0.24,1.57),0.76)
	for y in [0.6,1.1,1.6,2.1,2.6]:
		_moss(b,Vector3(-0.92,y,1.235),0.13)
	_vine_row(b,Vector3(-1.94,0.21,1.0),1.05,0.77)

static func _lumber(b: Batch) -> void:
	_foundation(b)
	_body(b,Vector3(0.59,0.27,-0.36),2.16,2.63,2.29,0.71)
	_gable(b,Vector3(0.59,2.56,0.97),2.16,1.13)
	_roof(b,Vector3(0.59,2.56,-0.36),2.64,3.10,1.13)
	_door(b,Vector3(0.29,0.29,0.99),0.70,1.40)
	_steps(b,0.29,1.21,1.00)
	_window(b,Vector3(1.70,1.74,-0.38),Vector2(0.61,0.74),PI*0.5)
	_porch(b,Vector3(-1.22,0.24,-0.02),1.34,2.82,1.63)
	for row in range(3):
		for col in range(3-row):
			_log(b,Vector3(-1.47+col*0.36+row*0.18,0.37+row*0.31,-0.09),0.17,2.1)
	_cylinder(b,Vector3(-0.93,0.49,1.61),0.37,0.48,WOOD)
	_box(b,Vector3(-0.92,0.96,1.64),Vector3(0.055,0.73,0.055),TIMBER,"wood",Vector3(0,0,-0.48))
	_box(b,Vector3(-0.75,1.21,1.64),Vector3(0.35,0.20,0.07),Color("b8bab0"),"metal",Vector3(0,0,-0.48),true)
	_workbench(b,Vector3(1.34,0.23,1.52),1.24)
	_chimney(b,Vector3(1.20,2.37,-1.04),1.37)
	_banner(b,Vector3(0.59,3.27,1.14),0.49,0.79)

static func _quarry(b: Batch) -> void:
	_foundation(b)
	for row in range(3):
		for i in range(4-row):
			_box(b,Vector3(-1.58+i*0.78+row*0.15,0.54+row*0.63,-1.34-row*0.04),Vector3(0.82,0.77,0.95),b.shade(STONE,0.16),"stone",Vector3(0,b.rng.randf_range(-0.06,0.06),0),true)
	_body(b,Vector3(0.96,0.27,0.18),1.46,1.73,1.78,0.97)
	_gable(b,Vector3(0.96,2.05,1.05),1.46,0.84)
	_roof(b,Vector3(0.96,2.05,0.18),1.88,2.16,0.84)
	_door(b,Vector3(0.96,0.29,1.09),0.62,1.26)
	_box(b,Vector3(-1.15,1.52,0.06),Vector3(0.20,2.75,0.20),TIMBER,"wood",Vector3.ZERO,true)
	_beam(b,Vector3(-1.30,2.88,0.03),Vector3(-0.22,2.88,0.03),0.18,WOOD)
	_beam(b,Vector3(-1.15,2.15,0.04),Vector3(-0.52,2.87,0.04),0.12,TIMBER)
	_beam(b,Vector3(-0.31,2.91,0.05),Vector3(-0.31,1.26,0.05),0.027,DARK,"metal")
	_box(b,Vector3(-0.31,1.13,0.05),Vector3(0.68,0.19,0.63),TIMBER)
	_box(b,Vector3(-0.31,1.48,0.05),Vector3(0.52,0.46,0.47),PALE_STONE,"stone",Vector3.ZERO,true)
	for i in range(5):
		_box(b,Vector3(-1.45+(i%3)*0.56,0.40+floorf(float(i)/3)*0.35,1.40),Vector3(0.51,0.33,0.52),b.shade(PALE_STONE,0.1),"stone",Vector3.ZERO,true)
	_banner(b,Vector3(0.96,2.65,1.20),0.43,0.66)

static func _farm(b: Batch) -> void:
	_foundation(b)
	_body(b,Vector3(-0.93,0.26,-0.84),1.72,1.74,1.98,0.66)
	_gable(b,Vector3(-0.93,2.24,0.04),1.72,0.97)
	_roof(b,Vector3(-0.93,2.24,-0.84),2.16,2.15,0.97)
	_door(b,Vector3(-0.93,0.29,0.08),0.64,1.29)
	_chimney(b,Vector3(-1.41,2.07,-1.18),1.11)
	for z in [0.77,1.61]:
		for x in [-1.21,0.25,1.50]:
			_bed(b,Vector3(x,0.25,z),Vector2(1.03,0.61))
	_bed(b,Vector3(1.24,0.25,-0.72),Vector2(1.29,1.61))
	_barrel(b,Vector3(-1.91,0.25,0.26),0.73)
	_fence(b,Vector3(-2.15,0.22,2.08),Vector3(2.16,0.22,2.08),0.55)
	_fence(b,Vector3(2.16,0.22,2.08),Vector3(2.16,0.22,-1.85),0.55)
	_banner(b,Vector3(-0.93,3.00,0.17),0.40,0.57)

static func _vineyard(b: Batch) -> void:
	_foundation(b)
	for x in [-1.5,0.0,1.5]:
		_vine_row(b,Vector3(x,0.25,-1.78),3.55,1.30)
	_fence(b,Vector3(-2.10,0.23,-2.04),Vector3(2.11,0.23,-2.04),0.67)
	for x in [-2.13,2.13]:
		_fence(b,Vector3(x,0.23,-2.04),Vector3(x,0.23,1.89),0.67)
	_crate(b,Vector3(-0.79,0.24,1.78),0.72)
	_barrel(b,Vector3(0.78,0.24,1.78),0.68)

static func _clock(b: Batch, at: Vector3, radius: float) -> void:
	_cylinder(b,at,radius,0.10,GOLD,"metal",Vector3(PI*0.5,0,0))
	_cylinder(b,at+Vector3(0,0,0.062),radius*0.83,0.025,PLASTER,"plaster",Vector3(PI*0.5,0,0))
	for i in range(12):
		var angle := float(i)/12.0*TAU
		var p := Vector3(sin(angle),cos(angle),0)*radius*0.65
		_box(b,at+p+Vector3(0,0,0.086),Vector3(0.022,radius*0.13,0.02),TIMBER,"wood",Vector3(0,0,-angle))
	_beam(b,at+Vector3(0,0,0.10),at+Vector3(-radius*0.44,radius*0.45,0.10),0.026,TIMBER)
	_beam(b,at+Vector3(0,0,0.11),at+Vector3(radius*0.11,radius*0.46,0.11),0.030,TIMBER)

static func _flag(b: Batch, at: Vector3, height: float) -> void:
	_cylinder(b,at+Vector3.UP*height*0.5,0.026,height,GOLD,"metal")
	_ellipsoid(b,at+Vector3.UP*(height+0.02),Vector3(0.058,0.10,0.058),GOLD,"metal")
	for i in range(5):
		var x0 := float(i)*0.13
		var x1 := float(i+1)*0.13
		var z0 := sin(float(i)*1.2)*0.045
		var z1 := sin(float(i+1)*1.2)*0.045
		b.quad(at+Vector3(x0,height-0.06,z0),at+Vector3(x0,height-0.36,z0),at+Vector3(x1,height-0.31,z1),at+Vector3(x1,height-0.03,z1),"cloth",TEAL)

static func _notice_board(b: Batch, at: Vector3) -> void:
	for x in [-0.28,0.28]:
		_box(b,at+Vector3(x,0.61,0),Vector3(0.075,1.23,0.075),TIMBER)
	_box(b,at+Vector3(0,0.94,0),Vector3(0.81,0.65,0.13),WOOD,"wood",Vector3.ZERO,true)
	for i in range(3):
		_box(b,at+Vector3(-0.23+i*0.23,0.92,0.075),Vector3(0.17,0.37-i*0.04,0.016),PLASTER,"plaster",Vector3(0,0,0.08*(i-1)))

static func _workbench(b: Batch, at: Vector3, width: float) -> void:
	_box(b,at+Vector3(0,0.71,0),Vector3(width,0.12,0.52),WOOD,"wood",Vector3.ZERO,true)
	for x in [-width*0.35,width*0.35]:
		for z in [-0.16,0.16]:
			_box(b,at+Vector3(x,0.37,z),Vector3(0.09,0.68,0.09),TIMBER)
	_box(b,at+Vector3(-width*0.16,0.81,0),Vector3(width*0.51,0.065,0.20),WOOD.lightened(0.12),"wood",Vector3(0,0.08,0),true)
	_box(b,at+Vector3(width*0.21,0.87,-0.08),Vector3(0.21,0.11,0.11),DARK,"metal",Vector3.ZERO,true)
	_box(b,at+Vector3(width*0.21,0.81,0.12),Vector3(0.045,0.05,0.36),WOOD)

static func _target(b: Batch, at: Vector3, radius: float) -> void:
	_box(b,at+Vector3.UP*0.60,Vector3(0.09,1.2,0.09),TIMBER)
	for size_factor in [1.0,0.72,0.46,0.20]:
		_cylinder(b,at+Vector3(0,0.94,0.08+(1-size_factor)*0.02),radius*size_factor,0.03,PLASTER if size_factor in [1.0,0.46] else TEAL,"wood",Vector3(PI*0.5,0,0))

static func _press(b: Batch, at: Vector3, scale_factor: float) -> void:
	_barrel(b,at,scale_factor*1.1)
	for x in [-0.43,0.43]:
		_box(b,at+Vector3(x,0.96,0)*scale_factor,Vector3(0.12,1.92,0.13)*scale_factor,TIMBER,"wood",Vector3.ZERO,true)
	_box(b,at+Vector3(0,1.78,0)*scale_factor,Vector3(1.02,0.16,0.21)*scale_factor,WOOD,"wood",Vector3.ZERO,true)
	_cylinder(b,at+Vector3(0,1.20,0)*scale_factor,0.045*scale_factor,1.07*scale_factor,TIMBER)
	for i in range(12):
		_cylinder(b,at+Vector3(0,0.76+i*0.075,0)*scale_factor,0.057*scale_factor,0.027*scale_factor,WOOD.lightened(0.16))
	_cylinder(b,at+Vector3(0,0.83,0)*scale_factor,0.31*scale_factor,0.09*scale_factor,TIMBER)
	_beam(b,at+Vector3(-0.34,1.52,0)*scale_factor,at+Vector3(0.34,1.52,0)*scale_factor,0.046*scale_factor,WOOD)

static func _sack(b: Batch, at: Vector3, scale_factor: float) -> void:
	_ellipsoid(b,at+Vector3.UP*0.30*scale_factor,Vector3(0.25,0.34,0.21)*scale_factor,Color("c6af79"),"cloth")
	_cylinder(b,at+Vector3.UP*0.58*scale_factor,0.095*scale_factor,0.1*scale_factor,Color("a89971"),"cloth")
	_cylinder(b,at+Vector3.UP*0.57*scale_factor,0.10*scale_factor,0.024*scale_factor,TIMBER)

static func _log(b: Batch, at: Vector3, radius: float, length: float) -> void:
	_cylinder(b,at,radius,length,TIMBER,"wood",Vector3(PI*0.5,0,0))
	for z in [-length*0.5-0.004,length*0.5+0.004]:
		_cylinder(b,at+Vector3(0,0,z),radius*0.88,0.012,WOOD.lightened(0.22),"wood",Vector3(PI*0.5,0,0))
		_cylinder(b,at+Vector3(0,0,z*1.01),radius*0.34,0.015,WOOD,"wood",Vector3(PI*0.5,0,0))

static func _bed(b: Batch, at: Vector3, size: Vector2) -> void:
	_box(b,at,Vector3(size.x,0.16,size.y),Color("594b30"),"stone",Vector3.ZERO,true)
	for x in [-size.x*0.5,size.x*0.5]:
		_box(b,at+Vector3(x,0.10,0),Vector3(0.064,0.16,size.y+0.12),WOOD)
	for z in [-size.y*0.5,size.y*0.5]:
		_box(b,at+Vector3(0,0.10,z),Vector3(size.x+0.09,0.16,0.064),WOOD)
	var cols := maxi(2,int(size.x/0.31))
	var rows := maxi(2,int(size.y/0.29))
	for row in range(rows):
		for col in range(cols):
			var p := at+Vector3((float(col)+0.5)/cols*size.x-size.x*0.5,0.18,(float(row)+0.5)/rows*size.y-size.y*0.5)
			for angle in [0.0,PI*0.5,PI,PI*1.5]:
				_ellipsoid(b,p+Vector3(cos(angle)*0.07,0.04,sin(angle)*0.07),Vector3(0.12,0.065,0.085),b.shade(LEAF.lightened(0.12),0.15),"foliage")
			_ellipsoid(b,p+Vector3.UP*0.07,Vector3(0.081,0.085,0.081),Color("c49239") if (row+col)%4 == 0 else LEAF.lightened(0.3),"foliage")

static func _vine_row(b: Batch, at: Vector3, length: float, height: float) -> void:
	var count := maxi(2,ceili(length/0.61))
	for i in range(count+1):
		var p := at+Vector3(0,0,float(i)/count*length)
		_box(b,p+Vector3.UP*height*0.5,Vector3(0.078,height,0.078),WOOD,"wood",Vector3.ZERO,true)
		_beam(b,p+Vector3(0,0.06,0),p+Vector3(0.06,height*0.88,0.06),0.047,TIMBER)
		for j in range(4):
			var leaf_at := p+Vector3(b.rng.randf_range(-0.18,0.18),height*0.70+b.rng.randf_range(-0.09,0.19),b.rng.randf_range(-0.19,0.19))
			_ellipsoid(b,leaf_at,Vector3(0.23,0.14,0.25),b.shade(LEAF,0.19),"foliage",true)
			if j%2 == 0:
				for g in range(4):
					_ellipsoid(b,leaf_at+Vector3((g%2)*0.063-0.035,-0.18-floorf(float(g)/2)*0.074,0.09),Vector3(0.058,0.074,0.052),Color("625079"),"foliage")
	for y in [height*0.40,height*0.80]:
		_beam(b,at+Vector3.UP*y,at+Vector3(0,y,length),0.021,DARK,"metal")

static func _branch(b: Batch, from: Vector3, to: Vector3, lower_radius: float, upper_radius: float) -> void:
	var direction := (to-from).normalized()
	var basis := Basis(Quaternion(Vector3.UP,direction))
	for i in range(9):
		var a0 := float(i)/9.0*TAU
		var a1 := float(i+1)/9.0*TAU
		var radial0 := basis*Vector3(cos(a0),0,sin(a0))
		var radial1 := basis*Vector3(cos(a1),0,sin(a1))
		var color := b.shade(TIMBER,0.10)
		b.quad(from+radial0*lower_radius,to+radial0*upper_radius,to+radial1*upper_radius,from+radial1*lower_radius,"wood",color)
		b.triangle(to,to+radial0*upper_radius,to+radial1*upper_radius,"wood",WOOD)
		if lower_radius > 0.12 and i%2 == 0:
			_beam(b,from+radial0*lower_radius*1.012,to+radial0*upper_radius*1.012,0.016,TIMBER.darkened(0.16))
	b.parts += 1

static func _tree(b: Batch, at: Vector3, scale_factor: float) -> void:
	var height := b.rng.randf_range(4.6,6.2)*scale_factor
	var bend := Vector3(b.rng.randf_range(-0.30,0.30),0,b.rng.randf_range(-0.27,0.27))*scale_factor
	var lower := at+Vector3.UP*height*0.27+bend*0.2
	var fork := at+Vector3.UP*height*0.53+bend
	var crown := at+Vector3.UP*height*0.85+bend*1.3
	_branch(b,at+Vector3.UP*0.015,lower,0.22*scale_factor,0.175*scale_factor)
	_branch(b,lower,fork,0.175*scale_factor,0.105*scale_factor)
	_branch(b,fork,crown,0.105*scale_factor,0.025*scale_factor)
	var leaf_color := Color("557b36")
	for i in range(8):
		var angle := float(i)*2.39
		var radial := Vector3(cos(angle),0,sin(angle))
		var branch := at+Vector3.UP*height*(0.40+0.042*i)+bend
		var tip := branch+radial*b.rng.randf_range(0.71,1.32)*scale_factor+Vector3.UP*height*0.12
		_branch(b,branch,tip,0.095*scale_factor,0.026*scale_factor)
		for j in range(3):
			var cluster := tip+Vector3(b.rng.randf_range(-0.33,0.33),b.rng.randf_range(-0.12,0.38),b.rng.randf_range(-0.33,0.33))*scale_factor
			var size_factor := b.rng.randf_range(0.79,1.15)*scale_factor
			_ellipsoid(b,cluster,Vector3(0.52,0.40,0.51)*size_factor,b.shade(leaf_color,0.12),"foliage")
			# Pequenos tufos arredondam a borda da copa e evitam uma silhueta de poliedros.
			for leaf in range(5):
				var leaf_angle := float(leaf)*TAU/5.0+b.rng.randf_range(-0.35,0.35)
				var leaf_at := cluster+Vector3(cos(leaf_angle)*0.42,b.rng.randf_range(0.03,0.30),sin(leaf_angle)*0.40)*size_factor
				_ellipsoid(b,leaf_at,Vector3(0.22,0.14,0.25)*size_factor,b.shade(leaf_color.lightened(0.07),0.10),"foliage")
	_ellipsoid(b,crown,Vector3(0.61,0.60,0.57)*scale_factor,leaf_color.lightened(0.07),"foliage")
	for i in range(5):
		var angle := float(i)/5.0*TAU
		_branch(b,at+Vector3.UP*0.27,at+Vector3(cos(angle)*0.56,0.03,sin(angle)*0.56)*scale_factor,0.12*scale_factor,0.018*scale_factor)
