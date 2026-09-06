extends RefCounted
## Reconstruções das pranchas bld_01 e bld_04. Frente +Z, lote 7,10 m.
## Tipos civis usam as respectivas pranchas; Frontier permanece preservado.
const Base = preload("res://presentation/approved_primitives.gd")
const Decor = preload("res://presentation/approved_facade_details.gd")
const STONE := Color("74766b")
const TRIM := Color("969587")
const MORTAR := Color("484d46")
const WOOD := Color("78502c")
const DARK_WOOD := Color("4e321e")
const LIGHT_WOOD := Color("a47a40")
const TILE := Color("a65329")
const TEAL := Color("18575a")
const GOLD := Color("bd9142")
const DARK := Color("272d27")
static var _cache: Dictionary = {}
static var _materials: Dictionary = {}

static func building(kind: String) -> Node3D:
	if kind not in ["hall","training"]:
		# Runtime evita ciclo de preload: os civis reutilizam auxiliares deste script.
		return load("res://presentation/approved_civil_buildings.gd").building(kind)
	if not _cache.has(kind):
		var b := Base.Batch.new(1713 if kind == "hall" else 4417)
		if kind == "hall": _hall(b)
		else: _training(b)
		for key in Base.MATERIAL_KEYS:
			if not _materials.has(key):
				_materials[key] = Base._material(key).duplicate()
				_materials[key].resource_name = "Approved_"+key
		var asset: Dictionary = b.finish(_materials,Base._roof_tile())
		var index := 0
		for key in Base.MATERIAL_KEYS:
			if b.surfaces.has(key) and not b.surfaces[key].vertices.is_empty():
				asset.mesh.surface_set_name(index,key)
				index += 1
		_cache[kind] = asset
	var root: Node3D = Base._instantiate(_cache[kind],"Approved_"+kind)
	root.set_meta("footprint_m",Vector2(7.1,7.1))
	root.set_meta("catalog_id","bld_01_centro_da_vila" if kind == "hall" else "bld_04_centro_de_treinamento")
	root.set_meta("reference","01-centro_da_vila.png" if kind == "hall" else "04-centro_de_treinamento.png")
	if root.has_node("IndividualCurvedRoofTiles"):
		root.get_node("IndividualCurvedRoofTiles").material_override = _materials["roof"]
	return root

static func _box(b, at: Vector3, size: Vector3, color: Color, key: String = "wood", rotation: Vector3 = Vector3.ZERO) -> void:
	Base._box(b,at,size,color,key,rotation,true)

static func _beam(b, from: Vector3, to: Vector3, width: float, color: Color = WOOD, key: String = "wood") -> void:
	Base._beam(b,from,to,width,color,key)

static func _merge(b, source, transform: Transform3D, roof_tint: bool = false) -> void:
	for key in source.surfaces:
		var data = source.surfaces[key]
		var target = b.surface(key)
		var offset: int = target.vertices.size()
		for i in range(data.vertices.size()):
			target.vertices.append(transform*data.vertices[i])
			target.normals.append((transform.basis*data.normals[i]).normalized())
			target.uvs.append(data.uvs[i])
			var color: Color = data.colors[i]
			if roof_tint and key == "roof": color *= Color(0.90,0.81,0.76)
			if roof_tint and key == "wood": color *= Color(0.88,0.83,0.77)
			target.colors.append(color)
		for index in data.indices:
			target.indices.append(offset+index)
	for i in range(source.tiles.size()):
		b.tiles.append(transform*source.tiles[i])
		b.tile_colors.append(source.tile_colors[i]*Color(0.90,0.81,0.76) if roof_tint else source.tile_colors[i])
	b.parts += source.parts

static func _roof(b, at: Vector3, width: float, depth: float, rise: float, transverse: bool = false) -> void:
	var source := Base.Batch.new(b.rng.randi())
	Base._roof(source,Vector3.ZERO,depth if transverse else width,width if transverse else depth,rise)
	_merge(b,source,Transform3D(Basis(Vector3.UP,PI*0.5 if transverse else 0.0),at),true)

static func _gable(b, at: Vector3, width: float, height: float) -> void:
	b.triangle(at+Vector3(-width*0.5,0,0),at+Vector3(width*0.5,0,0),at+Vector3(0,height,0),"plaster",Color("a49168"))
	for x in [-width*0.25,0.0,width*0.25]:
		var h := height*(1.0-absf(x)/(width*0.5))
		_box(b,at+Vector3(x,h*0.5,0.05),Vector3(0.11,h,0.14),DARK_WOOD)
	_beam(b,at+Vector3(-width*0.52,-0.03,0.07),at+Vector3(width*0.52,-0.03,0.07),0.19,WOOD)
	for sign_value in [-1.0,1.0]:
		_beam(b,at+Vector3(sign_value*width*0.52,0,0.08),at+Vector3(0,height+0.06,0.08),0.20,WOOD)
		_beam(b,at+Vector3(sign_value*width*0.34,0.05,0.06),at+Vector3(sign_value*width*0.08,height*0.58,0.06),0.095,LIGHT_WOOD)

static func _foundation(b) -> void:
	_box(b,Vector3(0,0.09,0),Vector3(7.08,0.18,7.08),Color("666b58"),"stone")
	for row in range(15):
		for col in range(14):
			var x := -3.29+col*0.505+(0.12 if row%2 else 0.0)
			var z := -3.28+row*0.459
			if absf(x) < 3.5:
				_box(b,Vector3(x,0.19+b.rng.randf_range(-0.015,0.01),z),Vector3(0.47,0.10,0.425),b.shade(Color("888675"),0.11),"stone",Vector3(0,b.rng.randf_range(-0.02,0.02),0))

static func _stone_face(b, at: Vector3, width: float, height: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	var rows := maxi(1,ceili(height/0.32))
	var cols := maxi(1,ceili(width/0.47))
	for row in range(rows):
		var shift := 0.5 if row%2 else 0.0
		for col in range(cols+(1 if row%2 else 0)):
			var left := maxf(-width*0.5,-width*0.5+(col-shift)*width/cols)
			var right := minf(width*0.5,-width*0.5+(col+1-shift)*width/cols)
			var p := at+basis*Vector3((left+right)*0.5,(row+0.5)*height/rows,b.rng.randf_range(0.025,0.065))
			_box(b,p,Vector3(right-left-0.025,height/rows-0.028,0.16),b.shade(STONE,0.11),"stone",Vector3(0,rotation,0))

static func _masonry(b, at: Vector3, width: float, depth: float, height: float) -> void:
	_box(b,at+Vector3.UP*height*0.5,Vector3(width,height,depth),MORTAR,"stone")
	for side in [-1.0,1.0]:
		_stone_face(b,at+Vector3(0,0,side*depth*0.5),width,height,0.0 if side>0 else PI)
		_stone_face(b,at+Vector3(side*width*0.5,0,0),depth,height,side*PI*0.5)
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]:
			for row in range(ceili(height/0.39)):
				_box(b,at+Vector3(x,(row+0.5)*height/ceili(height/0.39),z),Vector3(0.30,height/ceili(height/0.39)-0.02,0.30),b.shade(TRIM,0.08),"stone")
	_box(b,at+Vector3.UP*(height+0.035),Vector3(width+0.25,0.16,depth+0.24),TRIM,"stone")

static func _timber_storey(b, at: Vector3, width: float, depth: float, height: float) -> void:
	_box(b,at+Vector3.UP*height*0.5,Vector3(width,height,depth),Color("8c7c59"),"plaster")
	for side in [-1.0,1.0]:
		for i in range(ceili(width/0.24)):
			var x := -width*0.5+(i+0.5)*width/ceili(width/0.24)
			_box(b,at+Vector3(x,height*0.5,side*(depth*0.5+0.035)),Vector3(width/ceili(width/0.24)-0.02,height-0.08,0.055),b.shade(WOOD,0.13))
		for i in range(ceili(depth/0.24)):
			var z := -depth*0.5+(i+0.5)*depth/ceili(depth/0.24)
			_box(b,at+Vector3(side*(width*0.5+0.035),height*0.5,z),Vector3(0.055,height-0.08,depth/ceili(depth/0.24)-0.02),b.shade(WOOD,0.13))
	for y in [0.02,height-0.025]:
		_box(b,at+Vector3.UP*y,Vector3(width+0.22,0.19,depth+0.22),DARK_WOOD)
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]:
			_box(b,at+Vector3(x,height*0.5,z),Vector3(0.22,height+0.14,0.22),WOOD)
	for side in [-1.0,1.0]:
		for x in [-width*0.28,0.0,width*0.28]:
			_box(b,at+Vector3(x,height*0.5,side*(depth*0.5+0.08)),Vector3(0.13,height,0.16),DARK_WOOD)

static func _arched_panel(b, at: Vector3, width: float, height: float, color: Color, key: String, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	var radius := width*0.5
	var shoulder := height-radius
	for i in range(11):
		var x := (i+0.5)*width/11.0-radius
		var h := shoulder+sqrt(maxf(0,radius*radius-x*x))
		_box(b,at+basis*Vector3(x,h*0.5,0),Vector3(width/11.0-0.006,h,0.075),b.shade(color,0.025),key,Vector3(0,rotation,0))

static func _arch_frame(b, at: Vector3, width: float, height: float, thickness: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	var radius := width*0.5
	var shoulder := height-radius
	for side in [-1.0,1.0]:
		for row in range(5):
			_box(b,at+basis*Vector3(side*(radius+thickness*0.5),(row+0.5)*shoulder/5.0,0.04),Vector3(thickness,shoulder/5.0-0.018,0.22),b.shade(TRIM,0.08),"stone",Vector3(0,rotation,0))
	for i in range(11):
		var angle := (float(i)+0.5)/11.0*PI
		var p := at+basis*Vector3(cos(angle)*(radius+thickness*0.5),shoulder+sin(angle)*(radius+thickness*0.5),0.04)
		var local := Base.Batch.new()
		_box(local,Vector3.ZERO,Vector3((radius+thickness)*PI/11.0,thickness,0.23),b.shade(TRIM,0.08),"stone",Vector3(0,0,angle-PI*0.5))
		_merge(b,local,Transform3D(basis,p))

static func _door(b, at: Vector3, width: float, height: float) -> void:
	_arched_panel(b,at,width,height,Color("63411f"),"wood")
	_arch_frame(b,at,width,height,0.24)
	for side in [-1.0,1.0]:
		for y in [0.45,1.25]:
			_box(b,at+Vector3(side*width*0.255,y,0.076),Vector3(width*0.42,0.070,0.045),DARK,"metal")
			for x in [0.10,0.34]:
				Base._cylinder(b,at+Vector3(side*x,y,0.112),0.026,0.025,GOLD,"metal",Vector3(PI*0.5,0,0))
		Base._cylinder(b,at+Vector3(side*0.11,0.98,0.105),0.045,0.05,GOLD,"metal",Vector3(PI*0.5,0,0))
	_box(b,at+Vector3(0,(height-width*0.5)*0.5,0.07),Vector3(0.055,height-width*0.5,0.035),DARK_WOOD)

	Decor.door_details(b,at,width,height)

static func _arch_window(b, at: Vector3, width: float, height: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	Decor.arch_glass(b,at,width,height,rotation)
	_arch_frame(b,at,width,height,0.14,rotation)
	for x in [-width*0.25,0.0,width*0.25]:
		var h := height-width*0.5+sqrt(maxf(0,width*width*0.25-x*x))
		_box(b,at+basis*Vector3(x,h*0.5,0.09),Vector3(0.047,h,0.065),LIGHT_WOOD,"wood",Vector3(0,rotation,0))
	_box(b,at+basis*Vector3(0,height*0.44,0.09),Vector3(width,0.055,0.065),LIGHT_WOOD,"wood",Vector3(0,rotation,0))
	_box(b,at+basis*Vector3(0,-0.06,0.07),Vector3(width+0.38,0.13,0.27),TRIM,"stone",Vector3(0,rotation,0))

static func _small_window(b, at: Vector3, width: float, height: float, rotation: float = 0.0, teal: bool = false) -> void:
	var basis := Basis(Vector3.UP,rotation)
	_box(b,at,Vector3(width+0.15,height+0.16,0.12),DARK_WOOD,"wood",Vector3(0,rotation,0))
	_box(b,at+basis*Vector3(0,0,0.08),Vector3(width,height,0.04),Color("293c35"),"glass",Vector3(0,rotation,0))
	for x in [-width*0.5,0.0,width*0.5]:
		_box(b,at+basis*Vector3(x,0,0.12),Vector3(0.065,height+0.13,0.07),LIGHT_WOOD,"wood",Vector3(0,rotation,0))
	for y in [-height*0.5,0.0,height*0.5]:
		_box(b,at+basis*Vector3(0,y,0.12),Vector3(width+0.13,0.067,0.075),LIGHT_WOOD,"wood",Vector3(0,rotation,0))
	if teal:
		for side in [-1.0,1.0]:
			_box(b,at+basis*Vector3(side*(width*0.5+0.14),0,0.04),Vector3(0.23,height+0.06,0.07),TEAL,"wood",Vector3(0,rotation,0))

	Decor.window_details(b,at,width,height,rotation,teal)

static func _dormer(b, at: Vector3, width: float = 0.95) -> void:
	_timber_storey(b,at,width,0.83,0.70)
	_gable(b,at+Vector3(0,0.70,0.43),width,0.66)
	_roof(b,at+Vector3(0,0.71,0),width+0.35,1.23,0.67)
	_small_window(b,at+Vector3(0,0.36,0.54),width*0.49,0.52,0.0,true)
	_box(b,at+Vector3(0,-0.025,0.5),Vector3(width+0.16,0.16,0.23),TRIM,"stone")

static func _hipped_roof(b, at: Vector3, width: float, depth: float, rise: float) -> void:
	for side in range(4):
		var angle := side*PI*0.5
		var radial := Vector3(sin(angle),0,cos(angle))
		var tangent := Vector3(cos(angle),0,-sin(angle))
		var half := (depth if side%2 == 0 else width)*0.5
		var span := width if side%2 == 0 else depth
		b.triangle(at+radial*half-tangent*span*0.5,at+radial*half+tangent*span*0.5,at+Vector3.UP*rise,"roof",TILE.darkened(0.20))
		var rows := 6
		var slope := sqrt(half*half+rise*rise)
		for row in range(rows):
			var t := (row+0.5)/rows
			var count := maxi(1,ceili(span*t/0.23))
			for col in range(count):
				var across := ((col+0.5)/count-0.5)*span*t
				var x_axis := (radial*half-Vector3.UP*rise).normalized()
				var y_axis := (radial*rise+Vector3.UP*half).normalized()
				var basis := Basis(x_axis,y_axis,x_axis.cross(y_axis)).scaled_local(Vector3(slope/rows*1.16,1.0,span*t/count*0.98))
				b.tiles.append(Transform3D(basis,at+radial*half*t+tangent*across+Vector3.UP*(rise*(1-t)+0.07)))
				b.tile_colors.append(b.shade(TILE,0.085))
		_beam(b,at+radial*half-tangent*span*0.54,at+radial*half+tangent*span*0.54,0.18,WOOD)
		_beam(b,at+Vector3.UP*(rise+0.045),at+radial*half+tangent*span*0.5,0.095,LIGHT_WOOD)
		# Cumeeiras diagonais de barro cobrem a junção das quatro águas.
		var hip_start := at+Vector3.UP*(rise+0.09)
		var hip_end := at+radial*half+tangent*span*0.5+Vector3.UP*0.08
		var hip_count := ceili(hip_start.distance_to(hip_end)/0.28)
		var cap_rotation := Basis(Quaternion(Vector3.UP,(hip_end-hip_start).normalized())).get_euler()
		for cap in range(hip_count):
			Base._cylinder(b,hip_start.lerp(hip_end,(cap+0.5)/hip_count),0.105,hip_start.distance_to(hip_end)/hip_count*0.94,b.shade(TILE.lightened(0.08),0.045),"roof",cap_rotation)
	Base._cylinder(b,at+Vector3.UP*(rise+0.09),0.075,0.25,GOLD,"metal")

static func _chimney(b, at: Vector3, height: float, width: float = 0.64) -> void:
	_masonry(b,at,width,width,height)
	_box(b,at+Vector3.UP*(height+0.12),Vector3(width+0.13,0.15,width+0.13),TRIM,"stone")
	_box(b,at+Vector3.UP*(height+0.21),Vector3(width-0.14,0.04,width-0.14),DARK,"stone")
	for side in [-1.0,1.0]:
		_box(b,at+Vector3(side*width*0.5,height+0.23,0),Vector3(0.11,0.13,width+0.11),STONE,"stone")
		_box(b,at+Vector3(0,height+0.23,side*width*0.5),Vector3(width-0.11,0.13,0.11),STONE,"stone")

static func _steps(b, at: Vector3, width: float, levels: int = 4) -> void:
	for level in range(levels):
		var h := (levels-level)*0.15
		_box(b,at+Vector3(0,h*0.5,level*0.26),Vector3(width,h,0.36),b.shade(TRIM,0.065),"stone")
		for side in [-1.0,1.0]:
			_box(b,at+Vector3(side*(width*0.5+0.16),h+0.12,level*0.26),Vector3(0.33,0.32,0.42),b.shade(STONE,0.08),"stone")

static func _banner(b, at: Vector3, width: float, height: float, crest: String = "lion") -> void:
	Decor.banner(b,at,width,height,crest)

static func _lion(b, at: Vector3, scale_factor: float) -> void:
	Decor.lion(b,at,scale_factor)

static func _side_gables(b, center: Vector3, body_width: float, roof_depth: float, rise: float) -> void:
	for side in [-1.0,1.0]:
		var source := Base.Batch.new()
		_gable(source,Vector3.ZERO,roof_depth,rise)
		_small_window(source,Vector3(0,rise*0.36,0.11),0.57,0.67)
		_merge(b,source,Transform3D(Basis(Vector3.UP,side*PI*0.5),center+Vector3(side*(body_width*0.5+0.025),0,0)))

static func _hanging_sign(b, at: Vector3, height: float = 3.4, wide: bool = false) -> void:
	_masonry(b,at,0.43,0.43,0.64)
	_box(b,at+Vector3.UP*(height*0.5+0.4),Vector3(0.16,height,0.16),WOOD)
	_beam(b,at+Vector3(-0.57,height+0.25,0),at+Vector3(0.57,height+0.25,0),0.12,WOOD)
	Base._cylinder(b,at+Vector3.UP*(height+0.50),0.09,0.29,GOLD,"metal",Vector3.ZERO,true)
	_banner(b,at+Vector3(0,height+0.18,0.06),0.76 if wide else 0.66,1.7 if wide else 0.90,"lion" if wide else "tools")

static func _lean_roof(b, at: Vector3, width: float, depth: float, drop: float, teal: bool = false, rotation: float = 0.0) -> void:
	var source := Base.Batch.new(339)
	var slope := sqrt(depth*depth+drop*drop)
	var rows := ceili(slope/0.29)
	var cols := ceili(width/0.24)
	var x_axis := Vector3(0,-drop,depth).normalized()
	var y_axis := Vector3(0,depth,drop).normalized()
	var basis := Basis(x_axis,y_axis,x_axis.cross(y_axis))
	for row in range(rows):
		var t := (row+0.5)/rows
		for col in range(cols):
			var position := Vector3(-width*0.5+(col+0.5)*width/cols,-drop*t,depth*t)
			source.tiles.append(Transform3D(basis.scaled_local(Vector3(slope/rows*1.2,1,width/cols*0.98)),position))
			source.tile_colors.append(source.shade(TEAL if teal else TILE,0.065))
	for side in [-1.0,1.0]:
		_beam(source,Vector3(side*width*0.5,0,0),Vector3(side*width*0.5,-drop,depth),0.18,WOOD)
	_beam(source,Vector3(-width*0.54,-drop,depth),Vector3(width*0.54,-drop,depth),0.20,WOOD)
	_merge(b,source,Transform3D(Basis(Vector3.UP,rotation),at))

static func _hall(b) -> void:
	_foundation(b)
	var at := Vector3(0,0.32,-0.67)
	_masonry(b,at,5.42,3.66,2.23)
	_timber_storey(b,at+Vector3.UP*2.28,5.44,3.68,0.69)
	_hall_roof(b,at+Vector3.UP*3.02,6.10,4.30,2.13,true)
	_side_gables(b,at+Vector3.UP*3.02,5.42,4.07,2.06)
	for side in [-1.0,1.0]:
		_arch_window(b,Vector3(side*1.92,0.87,1.33),0.67,1.31)
		_arch_window(b,Vector3(side*2.9,0.85,-0.43),0.64,1.35,side*PI*0.5)
		for x in [1.63,2.26]:
			_small_window(b,Vector3(side*x,2.94,1.30),0.34,0.37)
		_dormer(b,Vector3(side*1.78,3.70,0.63),0.97)
	# Volume do pórtico: pedra, frontão triangular e telhado avançado.
	_masonry(b,Vector3(0,0.32,1.68),2.44,1.47,2.24)
	_timber_storey(b,Vector3(0,2.63,1.67),2.47,1.49,0.66)
	_gable(b,Vector3(0,3.28,2.45),2.52,0.95)
	_hall_roof(b,Vector3(0,3.29,1.67),2.92,1.92,0.96)
	_small_window(b,Vector3(0,3.42,2.60),0.52,0.56)
	_door(b,Vector3(0,0.83,2.55),1.22,1.86)
	_steps(b,Vector3(0,0.24,2.56),1.98,3)
	# Torre retangular: não há torretas laterais na prancha aprovada.
	_masonry(b,Vector3(0,4.57,-0.30),1.36,1.27,0.60)
	_timber_storey(b,Vector3(0,5.20,-0.30),1.41,1.32,1.21)
	_hall_tower_roof(b,Vector3(0,6.48,-0.30))
	var clock := Base.Batch.new()
	Decor.clock(clock,Vector3.ZERO,0.49)
	_merge(b,clock,Transform3D(Basis.IDENTITY,Vector3(0,5.77,0.49)))
	_small_window(b,Vector3(0.83,5.80,-0.29),0.50,0.67,PI*0.5)
	_banner(b,Vector3(0,5.18,0.50),0.56,0.84)
	var flag := Base.Batch.new()
	Base._flag(flag,Vector3.ZERO,0.80)
	_merge(b,flag,Transform3D(Basis.IDENTITY,Vector3(0,7.82,-0.30)))
	_lion(b,Vector3(0.22,8.43,-0.24),0.28)
	_chimney(b,Vector3(2.20,4.22,-1.19),1.24,0.56)
	# Pequeno alpendre lateral e itens de administração.
	_lean_roof(b,Vector3(2.67,2.83,-0.12),2.3,0.69,0.34,false,PI*0.5)
	for z in [-1.06,0.83]:
		_masonry(b,Vector3(3.24,0.24,z),0.29,0.29,0.52)
		_box(b,Vector3(3.24,1.52,z),Vector3(0.17,2.01,0.17),WOOD)
	Base._notice_board(b,Vector3(2.10,0.27,2.81))
	_lean_roof(b,Vector3(2.10,1.63,2.70),0.95,0.34,0.13)
	for side in [-1.0,1.0]:
		_masonry(b,Vector3(side*2.09,0.25,2.05),0.83,0.26,0.31)
		_masonry(b,Vector3(side*2.54,0.25,2.05),0.36,0.36,0.54)
	_hanging_sign(b,Vector3(-2.90,0.23,1.72),3.89,true)
	_banner(b,Vector3(-1.03,2.79,2.57),0.51,1.03)
	for side in [-1.0,1.0]:
		Decor.pot(b,Vector3(side*2.0,0.25,1.64),0.25,0.38,true)
		Decor.moss_patch(b,Vector3(side*2.40,0.258,2.0),0.35)
	Base._barrel(b,Vector3(3.03,0.28,-1.85),0.84)
	Base._crate(b,Vector3(2.76,0.27,2.45),0.67)

	# Vasos, pequeno pinheiro e hera baixa presentes na praça da prancha01.
	Decor.small_conifer(b,Vector3(-2.22,0.25,1.84),1.38)
	Decor.pot(b,Vector3(-2.54,0.88,2.05),0.15,0.22,true)
	Decor.pot(b,Vector3(2.54,0.88,2.05),0.15,0.22,false)
	Decor.lantern(b,Vector3(0.97,2.12,2.67),0.92)
	Decor.shrub(b,Vector3(-1.70,0.26,1.65),0.25,0.45,true)
	for side in [-1.0,1.0]:
		Decor.moss_patch(b,Vector3(side*1.48,0.258,2.63),0.27)
		Decor.moss_patch(b,Vector3(side*2.77,0.258,0.31),0.29)

static func _training(b) -> void:
	_foundation(b)
	var at := Vector3(-0.43,0.32,-0.61)
	_masonry(b,at,4.54,3.69,1.26)
	_timber_storey(b,at+Vector3.UP*1.32,4.58,3.71,1.45)
	_roof(b,at+Vector3.UP*2.84,5.28,4.34,1.90,true)
	_side_gables(b,at+Vector3.UP*2.84,4.54,4.09,1.85)
	# Frontão avançado e grande estandarte central.
	_timber_storey(b,Vector3(-0.47,2.66,1.33),2.44,0.65,0.45)
	_gable(b,Vector3(-0.47,3.09,1.79),2.62,1.22)
	_roof(b,Vector3(-0.47,3.11,1.33),2.95,1.15,1.22)
	_banner(b,Vector3(-0.47,4.11,2.06),0.96,1.32)
	_door(b,Vector3(-0.51,0.82,1.65),1.14,1.84)
	_box(b,Vector3(-0.47,0.50,2.02),Vector3(2.10,0.46,1.49),STONE,"stone")
	for col in range(6):
		_box(b,Vector3(-1.29+col*0.33,0.765,2.02),Vector3(0.30,0.07,1.44),b.shade(TRIM,0.07),"stone")
	# Toldo teal de uma água, tirantes de madeira e colunas de base pétrea.
	_lean_roof(b,Vector3(-0.47,2.87,1.40),2.86,1.49,0.36,true)
	for x in [-1.70,0.77]:
		_masonry(b,Vector3(x,0.30,2.73),0.42,0.42,0.48)
		_box(b,Vector3(x,1.65,2.73),Vector3(0.22,1.80,0.22),WOOD)
		_beam(b,Vector3(x,2.05,2.73),Vector3(x+0.38*(-1 if x>0 else 1),2.47,2.73),0.15,LIGHT_WOOD)
		_box(b,Vector3(x,2.52,2.74),Vector3(0.37,0.22,0.36),LIGHT_WOOD)
	for x in [-1.46,-0.80,-0.14,0.52]:
		_beam(b,Vector3(x,2.96,1.38),Vector3(x,2.59,2.98),0.075,LIGHT_WOOD)
	_steps(b,Vector3(-0.48,0.24,2.60),1.97,3)
	_arch_window(b,Vector3(1.28,0.98,1.45),0.52,1.16)
	_arch_window(b,Vector3(-2.87,0.93,-0.48),0.61,1.26,-PI*0.5)
	_dormer(b,Vector3(1.03,3.72,0.24),0.62)
	_chimney(b,Vector3(1.40,3.84,-1.25),2.05,0.67)
	_chimney(b,Vector3(-2.30,3.89,-1.39),0.90,0.48)
	# Oficina lateral aberta, explicitamente visível da câmera frontal direita.
	_box(b,Vector3(2.54,0.38,-0.37),Vector3(1.47,0.28,3.48),STONE,"stone")
	_lean_roof(b,Vector3(1.86,3.17,-0.36),3.43,1.39,0.63,false,PI*0.5)
	for z in [-1.84,1.14]:
		_masonry(b,Vector3(3.13,0.45,z),0.34,0.34,0.57)
		_box(b,Vector3(3.13,1.70,z),Vector3(0.19,1.75,0.19),WOOD)
		_beam(b,Vector3(3.13,2.07,z),Vector3(2.76,2.57,z),0.15,LIGHT_WOOD)
	_masonry(b,Vector3(2.57,0.47,-1.76),1.07,0.19,1.08)
	var bench := Base.Batch.new()
	Base._workbench(bench,Vector3.ZERO,1.70)
	_merge(b,bench,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(2.84,0.50,-0.45)))
	Base._barrel(b,Vector3(2.62,0.54,0.94),0.76)
	Base._crate(b,Vector3(3.07,0.31,1.94),0.86)
	_box(b,Vector3(1.58,0.93,2.77),Vector3(0.09,1.26,0.09),DARK_WOOD)
	for ring in range(4):
		Base._cylinder(b,Vector3(1.58,1.37,2.88+ring*0.012),0.42*(1.0-ring*0.235),0.035,TRIM if ring%2 == 0 else DARK_WOOD,"wood",Vector3(PI*0.5,0,0))
	_hanging_sign(b,Vector3(-2.94,0.23,1.78),3.18,false)
	Base._barrel(b,Vector3(1.15,0.29,2.08),0.70)
	Base._crate(b,Vector3(-2.54,0.27,2.09),0.70)
	for x in [-2.79,2.56]:
		Decor.moss_patch(b,Vector3(x,0.258,2.42),0.35)
	for z in [-1.30,-0.68,0.07,0.77]:
		_beam(b,Vector3(3.24,0.56,z),Vector3(3.24,1.76,z+0.10),0.048,LIGHT_WOOD)
		_box(b,Vector3(3.24,1.79,z+0.10),Vector3(0.08,0.23,0.25),STONE,"metal")

	# Ferragens douradas do toldo e utensílios à entrada da escola.
	for x in [-1.46,-0.80,-0.14,0.52]:
		_box(b,Vector3(x,2.592,2.96),Vector3(0.145,0.13,0.20),GOLD,"metal",Vector3(-0.22,0,0))
		Base._cylinder(b,Vector3(x,2.63,3.055),0.026,0.025,DARK,"metal",Vector3(PI*0.5,0,0))
	Decor.lantern(b,Vector3(2.06,2.25,0.71),0.91,PI*0.5)
	Decor.pot(b,Vector3(-2.15,0.25,2.03),0.20,0.26,false)
	Decor.shrub(b,Vector3(-2.54,0.25,0.92),0.25,0.31,false)
	Decor.moss_patch(b,Vector3(2.49,0.258,2.67),0.33)
	Decor.moss_patch(b,Vector3(-1.91,0.258,2.95),0.30)

# Acabamento exclusivo do paço da prancha01. Não altera os auxiliares usados
# pela escola ou pelos sete edifícios civis, nem o RNG das partes seguintes.
static func _hall_roof(b, at: Vector3, width: float, depth: float, rise: float, transverse: bool = false) -> void:
	var source := Base.Batch.new(b.rng.randi())
	var span := depth if transverse else width
	var run := width if transverse else depth
	Base._roof(source,Vector3.ZERO,span,run,rise)
	var slope := sqrt(span*span*0.25+rise*rise)
	var rows := maxi(3,ceili(slope/0.31))
	var columns := maxi(3,ceili(run/0.23))
	var tile_pitch := run/columns
	for i in range(source.tiles.size()):
		var tile: Transform3D = source.tiles[i]
		var row := (i/columns)%rows
		var col := i%columns
		# Juntas ligeiramente desencontradas, sem mudar número ou malha das telhas.
		var edge_weight := sin(PI*(col+0.5)/columns)
		tile.origin.z += ((0.16 if row%2 else -0.16)*tile_pitch+source.rng.randf_range(-0.006,0.006))*edge_weight
		tile.origin += tile.basis.x.normalized()*source.rng.randf_range(-0.013,0.013)
		tile.origin.y += source.rng.randf_range(-0.004,0.006)
		tile.basis = tile.basis.rotated(tile.basis.y.normalized(),source.rng.randf_range(-0.018,0.018))
		source.tiles[i] = tile
		var clay: Color = source.tile_colors[i]
		source.tile_colors[i] = clay.darkened(0.065) if (row*7+col*13)%11 == 0 else clay
	# Colares estreitos fazem a sobreposição da cumeeira ler à distância.
	for i in range(columns-1):
		Base._cylinder(source,Vector3(0,rise+0.07,-run*0.5+(i+1)*tile_pitch),0.145,0.045,Base.RED_TILE.lightened(0.08),"roof",Vector3(PI*0.5,0,0))
	for sign_value in [-1.0,1.0]:
		var end := Vector3(0,rise+0.06,sign_value*(run*0.5+0.035))
		_beam(source,end,end+Vector3(0,0.11,sign_value*0.085),0.15,LIGHT_WOOD)
		_beam(source,end+Vector3(0,0.11,sign_value*0.085),end+Vector3(0,0.29,sign_value*0.11),0.14,WOOD)
		_box(source,end+Vector3(0,0.28,sign_value*0.11),Vector3(0.20,0.09,0.20),LIGHT_WOOD)
	_merge(b,source,Transform3D(Basis(Vector3.UP,PI*0.5 if transverse else 0.0),at),true)

static func _hall_tower_profile(t: float) -> float:
	# Sobe íngreme perto do pináculo e abre na borda: a cobertura da prancha
	# tem perfil côncavo, em vez da pirâmide reta anterior.
	return 1.32*pow(1.0-t,1.52)

static func _hall_tower_roof(b, at: Vector3) -> void:
	# Consome exatamente a sequência anterior para preservar relógio, janelas,
	# vasos e vegetação já aprovados, mesmo trocando apenas esta cobertura.
	var previous := Base.Batch.new()
	previous.rng.state = b.rng.state
	_hipped_roof(previous,Vector3.ZERO,1.98,1.90,1.18)
	b.rng.state = previous.rng.state
	var source := Base.Batch.new(1071713)
	var width := 1.98
	var depth := 1.90
	var rows := 7
	for side in range(4):
		var angle := side*PI*0.5
		var radial := Vector3(sin(angle),0,cos(angle))
		var tangent := Vector3(cos(angle),0,-sin(angle))
		var half := (depth if side%2 == 0 else width)*0.5
		var span := width if side%2 == 0 else depth
		for row in range(rows):
			var t0 := float(row)/rows
			var t1 := float(row+1)/rows
			var p0 := radial*half*t0+Vector3.UP*(_hall_tower_profile(t0)-0.075)
			var p1 := radial*half*t1+Vector3.UP*(_hall_tower_profile(t1)-0.075)
			if row == 0:
				source.triangle(p0,p1-tangent*span*t1*0.5,p1+tangent*span*t1*0.5,"roof",TILE.darkened(0.25))
			else:
				source.quad(p0-tangent*span*t0*0.5,p1-tangent*span*t1*0.5,p1+tangent*span*t1*0.5,p0+tangent*span*t0*0.5,"roof",TILE.darkened(0.25))
			var t := (row+0.5)/rows
			var count := maxi(1,ceili(span*t/0.23))
			var derivative := 1.32*1.52*pow(1.0-t,0.52)
			var down := (radial*half-Vector3.UP*derivative).normalized()
			var normal := (radial*derivative+Vector3.UP*half).normalized()
			var length := sqrt(half*half+derivative*derivative)/rows
			for col in range(count):
				var across := (col+0.5-count*0.5)*span*t/count
				var position := radial*half*t+tangent*across+Vector3.UP*(_hall_tower_profile(t)+0.025)
				position += down*source.rng.randf_range(-0.006,0.006)
				var tile_basis := Basis(down,normal,down.cross(normal)).scaled_local(Vector3(length*1.17,1.0,span*t/count*0.98))
				source.tiles.append(Transform3D(tile_basis,position))
				source.tile_colors.append(source.shade(TILE,0.10))
		_beam(source,radial*half-tangent*span*0.5-Vector3.UP*0.04,radial*half+tangent*span*0.5-Vector3.UP*0.04,0.18,DARK_WOOD)
		_beam(source,radial*(half+0.015)-tangent*span*0.5+Vector3.UP*0.065,radial*(half+0.015)+tangent*span*0.5+Vector3.UP*0.065,0.075,LIGHT_WOOD)
		# Cada espigão segue a curva, com peças sobrepostas independentes.
		var corner := radial*half+tangent*span*0.5
		for segment in range(8):
			var ta := float(segment)/8
			var tb := float(segment+1)/8
			var a := corner*ta+Vector3.UP*(_hall_tower_profile(ta)+0.075)
			var c := corner*tb+Vector3.UP*(_hall_tower_profile(tb)+0.075)
			_beam(source,a,c,0.09,WOOD)
			var direction := c-a
			var cap_rotation := Vector3.UP.cross(direction.normalized()).normalized()
			var basis := Basis(cap_rotation,Vector3.UP.angle_to(direction)) if not cap_rotation.is_zero_approx() else Basis.IDENTITY
			var cap := Base.Batch.new(17+segment+side*8)
			Base._cylinder(cap,Vector3.ZERO,0.105,direction.length()*0.96,source.shade(TILE.lightened(0.13),0.04),"roof")
			_merge(source,cap,Transform3D(basis,(a+c)*0.5))
		Base._cylinder(source,corner+Vector3.UP*0.15,0.046,0.24,GOLD,"metal")
		Base._ellipsoid(source,corner+Vector3.UP*0.28,Vector3(0.062,0.075,0.062),GOLD,"metal")
	# Colar escuro e pomo dourado ligam as telhas ao mastro existente.
	Base._cylinder(source,Vector3(0,1.28,0),0.095,0.17,DARK,"metal")
	Base._ellipsoid(source,Vector3(0,1.43,0),Vector3(0.11,0.14,0.11),GOLD,"metal")
	_merge(b,source,Transform3D(Basis.IDENTITY,at))
