extends RefCounted
## Casas e produção reconstruídas a partir das pranchas individuais do catálogo.
## Core contém apenas os auxiliares geométricos; sua delegação usa load em runtime.
const Core = preload("res://presentation/approved_buildings.gd")
const Base = preload("res://presentation/approved_primitives.gd")
const EarthYard = preload("res://presentation/approved_earth_yard.gd")
const KINDS := ["house","store","lumber","sawmill","quarry","farm","vineyard","winery","inn","mill","bakery","workshop","barracks"]
const IDS := {"house":"bld_02_casas","store":"bld_03_armazem","lumber":"bld_06_cabana_do_lenhador","sawmill":"bld_07_serraria","quarry":"bld_08_pedreira","farm":"bld_12_horta","vineyard":"kit_03_lavouras_e_vinhedos","winery":"bld_20_vinicola","inn":"bld_19_taverna","mill":"bld_14_moinho","bakery":"bld_15_padaria","workshop":"bld_22_carpintaria","barracks":"bld_26_quartel"}
const WOOD := Color("81582f")
const DARK_WOOD := Color("4d3521")
const LIGHT_WOOD := Color("ae8248")
const STONE := Color("787b6d")
const TRIM := Color("aaa38a")
const PLASTER := Color("c6b389")
const TEAL := Color("195c5c")
const GOLD := Color("c19741")
const LEAF := Color("56712f")
const DARK := Color("293029")
static var _cache: Dictionary = {}
static var _materials: Dictionary = {}

static func building(kind: String) -> Node3D:
	if not KINDS.has(kind): return Base.building(kind)
	if not _cache.has(kind):
		var b := Base.Batch.new(absi(kind.hash())+29103)
		match kind:
			"house": _house(b)
			"store": _store(b)
			"winery": _winery(b)
			"lumber": _lumber(b)
			"sawmill": _sawmill(b)
			"quarry": _quarry(b)
			"farm": _farm(b)
			"vineyard": _vineyard(b)
			"inn": _inn(b)
			"mill": _mill(b)
			"bakery": _bakery(b)
			"workshop": _workshop(b)
			"barracks": _barracks(b)
		for key in Base.MATERIAL_KEYS:
			if not _materials.has(key):
				_materials[key] = Base._material(key).duplicate()
				_materials[key].resource_name = "ApprovedCivil_"+key
		var asset: Dictionary = b.finish(_materials,Base._roof_tile())
		var index := 0
		for key in Base.MATERIAL_KEYS:
			if b.surfaces.has(key) and not b.surfaces[key].vertices.is_empty():
				asset.mesh.surface_set_name(index,key)
				index += 1
		if kind != "store":
			asset["earth_yard"] = EarthYard.prepare(asset.mesh,7.08 if kind == "winery" else 4.66)
		_cache[kind] = asset
	var root: Node3D = Base._instantiate(_cache[kind],"ApprovedCivil_"+kind)
	if _cache[kind].has("earth_yard"):
		var yard: Dictionary = _cache[kind].earth_yard
		root.add_child(EarthYard.instantiate(yard))
		root.set_meta("draw_calls",int(root.get_meta("draw_calls"))+1)
		root.set_meta("vertices",int(root.get_meta("vertices"))+int(yard.vertices))
	root.set_meta("catalog_id",IDS[kind])
	root.set_meta("footprint_m",Vector2.ONE*(7.1 if kind in ["store","winery"] else 4.7))
	root.set_meta("footprint_cells",3 if kind in ["store","winery"] else 2)
	if root.has_node("IndividualCurvedRoofTiles"):
		root.get_node("IndividualCurvedRoofTiles").material_override = _materials["roof"]
	return root

static func _box(b, at: Vector3, size: Vector3, color: Color, key: String = "wood", rotation: Vector3 = Vector3.ZERO) -> void:
	Core._box(b,at,size,color,key,rotation)

static func _beam(b, a: Vector3, c: Vector3, width: float, color: Color = WOOD, key: String = "wood") -> void:
	Core._beam(b,a,c,width,color,key)

static func _base(b, size: float = 4.66, paved: bool = false) -> void:
	if paved:
		_box(b,Vector3(0,0.065,0),Vector3(size,0.13,size),Color("756c4b"),"plaster")
		var count := int(size/0.44)
		for row in range(count):
			for col in range(count):
				var p := Vector3(-size*0.5+(col+0.5)*size/count,0.15,-size*0.5+(row+0.5)*size/count)
				_box(b,p,Vector3(size/count-0.03,0.095,size/count-0.032),b.shade(STONE,0.13),"stone",Vector3(0,b.rng.randf_range(-0.018,0.018),0))
	else:
		for i in range(24):
			var p := Vector3(b.rng.randf_range(-size*0.46,size*0.46),0.16,b.rng.randf_range(-size*0.46,size*0.46))
			Base._ellipsoid(b,p,Vector3(0.16,0.07,0.13)*b.rng.randf_range(0.6,1.1),b.shade(STONE,0.14),"stone",true)

static func _plaster_floor(b, at: Vector3, width: float, depth: float, height: float, middle_beam: bool = false) -> void:
	_box(b,at+Vector3.UP*height*0.5,Vector3(width,height,depth),PLASTER,"plaster")
	for y in [0.055,height-0.055]:
		_box(b,at+Vector3.UP*y,Vector3(width+0.17,0.17,depth+0.18),DARK_WOOD)
	if middle_beam:
		_box(b,at+Vector3.UP*height*0.43,Vector3(width+0.18,0.15,depth+0.18),WOOD)
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]:
			_box(b,at+Vector3(x,height*0.5,z),Vector3(0.17,height+0.06,0.17),WOOD)
	for side in [-1.0,1.0]:
		for x in [-width*0.29,0.0,width*0.29]:
			_box(b,at+Vector3(x,height*0.5,side*(depth*0.5+0.04)),Vector3(0.095,height-0.08,0.12),WOOD)
		for z in [-depth*0.27,depth*0.27]:
			_box(b,at+Vector3(side*(width*0.5+0.04),height*0.5,z),Vector3(0.12,height-0.08,0.10),WOOD)
		_beam(b,at+Vector3(-width*0.45,0.13,side*(depth*0.5+0.1)),at+Vector3(-width*0.23,height*0.36,side*(depth*0.5+0.1)),0.082,LIGHT_WOOD)
		_beam(b,at+Vector3(width*0.45,0.13,side*(depth*0.5+0.1)),at+Vector3(width*0.23,height*0.36,side*(depth*0.5+0.1)),0.082,LIGHT_WOOD)

static func _roof(b, at: Vector3, width: float, depth: float, rise: float, transverse: bool = false, close_sides: bool = true) -> void:
	Core._roof(b,at,width,depth,rise,transverse)
	if close_sides:
		if transverse:
			Core._side_gables(b,at,width-0.38,depth-0.18,rise-0.055)
		else:
			Core._gable(b,at+Vector3(0,0,depth*0.5-0.12),width-0.22,rise-0.05)
			var back := Base.Batch.new()
			Core._gable(back,Vector3.ZERO,width-0.22,rise-0.05)
			Core._merge(b,back,Transform3D(Basis(Vector3.UP,PI),at-Vector3(0,0,depth*0.5-0.12)))

static func _dormer(b, at: Vector3, width: float) -> void:
	var scale_factor := clampf(width/0.85,0.55,1.0)
	var source := Base.Batch.new()
	Core._dormer(source,Vector3.ZERO,width/scale_factor)
	Core._merge(b,source,Transform3D(Basis.IDENTITY.scaled_local(Vector3.ONE*scale_factor),at))

static func _awning(b, at: Vector3, width: float, depth: float, drop: float, rotation: float = 0.0, posts: bool = true) -> void:
	var source := Base.Batch.new()
	# Tecido em geometria curva; usa cloth para preservar o teal sob o atlas.
	for stripe in range(5):
		var x0 := -width*0.5+stripe*width/5.0
		var x1 := -width*0.5+(stripe+1)*width/5.0
		var color := TEAL if stripe%2 == 0 else Color("c4b387")
		var key := "cloth" if stripe%2 == 0 else "plaster"
		for segment in range(5):
			var t0 := segment/5.0
			var t1 := (segment+1)/5.0
			var y0 := -drop*t0-0.12*sin(t0*PI)
			var y1 := -drop*t1-0.12*sin(t1*PI)
			source.quad(Vector3(x0,y0,depth*t0),Vector3(x0,y1,depth*t1),Vector3(x1,y1,depth*t1),Vector3(x1,y0,depth*t0),key,color)
		var center := (x0+x1)*0.5
		source.quad(Vector3(x0,-drop,depth),Vector3(center,-drop-0.19,depth+0.025),Vector3(x1,-drop-0.04,depth),Vector3(x1,-drop,depth),key,color)
	for side in [-1.0,1.0]:
		_beam(source,Vector3(side*width*0.5,0.03,0),Vector3(side*width*0.5,-drop+0.02,depth),0.12,LIGHT_WOOD)
		if posts:
			_box(source,Vector3(side*(width*0.5-0.075),-at.y*0.5-drop*0.5+0.16,depth-0.07),Vector3(0.13,at.y-drop-0.12,0.13),WOOD)
	_beam(source,Vector3(-width*0.55,-drop,depth),Vector3(width*0.55,-drop,depth),0.13,WOOD)
	Core._merge(b,source,Transform3D(Basis(Vector3.UP,rotation),at))

static func _yard_fence(b, start: Vector3, end: Vector3, height: float = 0.66) -> void:
	var count := maxi(1,ceili(start.distance_to(end)/0.83))
	for i in range(count+1):
		var p := start.lerp(end,float(i)/count)
		if i%2 == 0 or i == count:
			Core._masonry(b,p,0.22,0.22,height*0.68)
			_box(b,p+Vector3.UP*(height*0.75),Vector3(0.14,height*0.45,0.14),WOOD)
		else: _box(b,p+Vector3.UP*height*0.5,Vector3(0.13,height,0.13),WOOD)
	for y in [height*0.32,height*0.77]:
		_beam(b,start+Vector3.UP*y,end+Vector3.UP*y,0.075,WOOD)

static func _leaf(b, at: Vector3, size: float, rotation: Vector3, color: Color = LEAF) -> void:
	var outline := [Vector2(0,0.55),Vector2(0.13,0.23),Vector2(0.35,0.32),Vector2(0.28,0.05),Vector2(0.50,-0.05),Vector2(0.26,-0.18),Vector2(0.32,-0.42),Vector2(0,-0.28),Vector2(-0.32,-0.42),Vector2(-0.26,-0.18),Vector2(-0.50,-0.05),Vector2(-0.28,0.05),Vector2(-0.35,0.32),Vector2(-0.13,0.23)]
	var basis := Basis.from_euler(rotation)
	var center := at+basis*Vector3(0,size*0.10,0)
	for i in range(outline.size()):
		var a: Vector2 = outline[i]*size
		var c: Vector2 = outline[(i+1)%outline.size()]*size
		b.triangle(center,at+basis*Vector3(a.x,0,a.y),at+basis*Vector3(c.x,0,c.y),"foliage",color)
	_beam(b,at+basis*Vector3(0,0.014,-size*0.31),at+basis*Vector3(0,size*0.10,size*0.44),size*0.012,color.lightened(0.16),"foliage")

static func _flower_patch(b, at: Vector3, size: Vector2, count: int = 14) -> void:
	for i in range(count):
		var p := at+Vector3(b.rng.randf_range(-size.x*0.5,size.x*0.5),0,b.rng.randf_range(-size.y*0.5,size.y*0.5))
		var height: float = b.rng.randf_range(0.12,0.31)
		_beam(b,p,p+Vector3.UP*height,0.018,LEAF,"foliage")
		_leaf(b,p+Vector3.UP*height*0.35,0.19,Vector3(-0.5,b.rng.randf()*TAU,0),b.shade(LEAF,0.12))
		var flower_color := Color("dbbf4e") if i%3 else Color("e5ddbd")
		for petal in range(5):
			var angle := petal*TAU/5.0
			Base._ellipsoid(b,p+Vector3(cos(angle)*0.037,height,sin(angle)*0.037),Vector3(0.035,0.018,0.028),flower_color,"foliage",true)
		Base._ellipsoid(b,p+Vector3.UP*(height+0.012),Vector3.ONE*0.022,Color("be8c32"),"foliage",true)

static func _flower_box(b, at: Vector3, width: float) -> void:
	_box(b,at,Vector3(width,0.17,0.23),WOOD)
	for side in [-1.0,1.0]:
		_box(b,at+Vector3(side*width*0.37,0,0.135),Vector3(0.055,0.19,0.03),DARK_WOOD)
	_flower_patch(b,at+Vector3.UP*0.10,Vector2(width*0.9,0.20),8)

static func _sack(b, at: Vector3, scale_factor: float = 1.0) -> void:
	Base._ellipsoid(b,at+Vector3.UP*0.32*scale_factor,Vector3(0.26,0.34,0.23)*scale_factor,Color("b7a47b"),"plaster")
	Base._cylinder(b,at+Vector3.UP*0.60*scale_factor,0.085*scale_factor,0.095*scale_factor,PLASTER,"plaster")
	Base._cylinder(b,at+Vector3.UP*0.58*scale_factor,0.096*scale_factor,0.035*scale_factor,DARK_WOOD,"wood")

static func _pot(b, at: Vector3, radius: float = 0.19) -> void:
	Base._cylinder(b,at+Vector3.UP*radius*0.75,radius,radius*1.5,Color("856241"),"plaster")
	Base._cylinder(b,at+Vector3.UP*radius*1.43,radius*1.1,radius*0.23,Color("aa7a45"),"plaster")
	Base._cylinder(b,at+Vector3.UP*radius*1.57,radius*0.87,0.026,Color("3d3628"),"plaster")
	for i in range(4):
		_leaf(b,at+Vector3.UP*radius*1.6,radius*1.4,Vector3(-0.8,i*PI*0.5,0),LEAF)

static func _bench(b, at: Vector3, width: float, rotation: float = 0.0) -> void:
	var source := Base.Batch.new()
	_box(source,Vector3(0,0.49,0),Vector3(width,0.09,0.39),WOOD)
	for x in [-width*0.34,width*0.34]:
		_box(source,Vector3(x,0.25,0),Vector3(0.10,0.49,0.31),DARK_WOOD)
		_box(source,Vector3(x,0.76,-0.14),Vector3(0.077,0.55,0.08),WOOD)
	_box(source,Vector3(0,0.95,-0.16),Vector3(width,0.14,0.07),WOOD)
	Core._merge(b,source,Transform3D(Basis(Vector3.UP,rotation),at))

static func _wheel(b, at: Vector3, radius: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	for i in range(14):
		var a0 := i*TAU/14.0
		var a1 := (i+1)*TAU/14.0
		_beam(b,at+basis*Vector3(0,cos(a0)*radius,sin(a0)*radius),at+basis*Vector3(0,cos(a1)*radius,sin(a1)*radius),0.07,WOOD)
		if i%2 == 0: _beam(b,at,at+basis*Vector3(0,cos(a0)*radius,sin(a0)*radius),0.039,LIGHT_WOOD)
	var cylinder := Base.Batch.new()
	Base._cylinder(cylinder,Vector3.ZERO,0.084,0.17,DARK_WOOD,"wood",Vector3(0,0,PI*0.5))
	Core._merge(b,cylinder,Transform3D(basis,at))

static func _cart(b, at: Vector3, width: float = 0.91, depth: float = 1.10, rotation: float = 0.0, cargo: String = "crates") -> void:
	var source := Base.Batch.new(188)
	_box(source,Vector3(0,0.43,0),Vector3(width,0.12,depth),DARK_WOOD)
	for x in [-width*0.51,width*0.51]:
		_wheel(source,Vector3(x,0.32,0.07),0.31)
		for row in range(3):
			_box(source,Vector3(x,0.55+row*0.14,0),Vector3(0.06,0.10,depth+0.06),WOOD)
		_beam(source,Vector3(x*0.75,0.42,depth*0.4),Vector3(x*0.75,0.48,depth*1.07),0.070,LIGHT_WOOD)
	for row in range(3):
		_box(source,Vector3(0,0.55+row*0.14,-depth*0.5),Vector3(width+0.08,0.10,0.06),WOOD)
	if cargo == "sacks":
		_sack(source,Vector3(-0.2,0.51,-0.15),0.70)
		_sack(source,Vector3(0.18,0.51,0.16),0.65)
	elif cargo == "logs":
		for i in range(3): Base._log(source,Vector3((i-1)*0.20,0.63,-0.1),0.12,depth*0.95)
	elif cargo == "stone":
		for i in range(2): _box(source,Vector3((i-0.5)*0.33,0.70,0),Vector3(0.32,0.37,0.46),TRIM,"stone")
	else: Base._crate(source,Vector3(0,0.51,-0.08),0.9)
	Core._merge(b,source,Transform3D(Basis(Vector3.UP,rotation),at))

static func _painted_door(b, at: Vector3, width: float, height: float, partially_open: bool = false) -> void:
	Core._arched_panel(b,at,width,height,Color("2c3028"),"plaster")
	Core._arch_frame(b,at,width,height,0.21)
	var source := Base.Batch.new()
	Core._arched_panel(source,Vector3.ZERO,width*(0.64 if partially_open else 0.98),height-0.05,TEAL,"cloth")
	for y in [0.42,1.20]:
		_box(source,Vector3(0,y,0.08),Vector3(width*0.59,0.053,0.04),DARK,"metal")
	Base._cylinder(source,Vector3(width*0.2,0.90,0.10),0.041,0.048,GOLD,"metal",Vector3(PI*0.5,0,0))
	Core._merge(b,source,Transform3D(Basis(Vector3.UP,-0.10 if partially_open else 0.0),at+Vector3(-width*0.14 if partially_open else 0,0,0.08)))

static func _house(b) -> void:
	_base(b)
	var at := Vector3(-0.08,0.24,-0.51)
	Core._masonry(b,at,2.72,2.47,1.11)
	_plaster_floor(b,at+Vector3.UP*1.17,2.74,2.49,2.16,true)
	_roof(b,at+Vector3.UP*3.39,3.26,3.01,1.31,true)
	_dormer(b,Vector3(-0.83,3.90,0.40),0.57)
	_dormer(b,Vector3(0.66,3.90,0.40),0.57)
	Core._chimney(b,Vector3(-0.50,3.62,-0.66),1.74,0.46)
	for x in [-0.78,0.76]:
		Core._small_window(b,Vector3(x,2.77,0.84),0.47,0.64)
		_flower_box(b,Vector3(x,2.36,0.95),0.57)
		Core._small_window(b,Vector3(x,0.99,0.85),0.42,0.56)
	for side in [-1.0,1.0]:
		Core._small_window(b,Vector3(-0.08+side*1.53,2.71,-0.71),0.51,0.65,side*PI*0.5)
		_flower_box(b,Vector3(-0.07+side*1.47,2.25,-0.72),0.47)
	# Pórtico de entrada, alas baixas e jardim cercado da prancha02.
	Core._masonry(b,Vector3(-0.11,0.23,0.91),1.11,0.51,1.93)
	Core._door(b,Vector3(-0.11,0.33,1.32),0.75,1.87)
	_roof(b,Vector3(-0.11,2.31,0.95),1.51,0.96,0.59)
	Core._steps(b,Vector3(-0.11,0.17,1.40),0.97,3)
	Core._banner(b,Vector3(-0.12,3.70,1.12),0.40,0.77)
	Core._lean_roof(b,Vector3(1.34,1.92,-0.15),1.76,0.74,0.30,false,PI*0.5)
	for z in [-0.85,0.51]: _box(b,Vector3(1.97,0.91,z),Vector3(0.13,1.60,0.13),WOOD)
	_awning(b,Vector3(1.34,1.94,1.07),0.83,0.74,0.30,PI*0.5)
	_bench(b,Vector3(1.68,0.20,1.00),0.77,PI*0.5)
	_pot(b,Vector3(1.74,0.21,-0.57),0.14)
	for pair in [[Vector3(-2.11,0.18,-1.96),Vector3(-2.11,0.18,1.98)],[Vector3(2.11,0.18,-1.96),Vector3(2.11,0.18,1.98)],[Vector3(-2.11,0.18,1.98),Vector3(-0.78,0.18,1.98)],[Vector3(0.64,0.18,1.98),Vector3(2.11,0.18,1.98)]]:
		_yard_fence(b,pair[0],pair[1],0.67)
	_flower_patch(b,Vector3(-1.43,0.17,1.30),Vector2(0.70,0.88),18)
	_flower_patch(b,Vector3(1.26,0.17,1.60),Vector2(0.62,0.51),15)
	for z in [-0.44,1.19]: _box(b,Vector3(-1.86,1.03,z),Vector3(0.073,1.73,0.073),WOOD)
	_beam(b,Vector3(-1.86,1.84,-0.46),Vector3(-1.86,1.84,1.21),0.023,DARK_WOOD)
	for i in range(4):
		var z := -0.25+i*0.33
		b.quad(Vector3(-1.86,1.78,z),Vector3(-1.84,1.22,z),Vector3(-1.84,1.20,z+0.26),Vector3(-1.86,1.78,z+0.26),"cloth" if i%2 == 0 else "plaster",TEAL if i%2 == 0 else PLASTER)
	_box(b,Vector3(-1.57,0.64,2.04),Vector3(0.075,0.9,0.075),WOOD)
	_box(b,Vector3(-1.57,1.00,2.04),Vector3(0.30,0.22,0.22),LIGHT_WOOD)

static func _store(b) -> void:
	_base(b,7.08,true)
	Core._masonry(b,Vector3(1.22,0.28,-0.68),2.23,3.62,1.43)
	_plaster_floor(b,Vector3(1.22,1.79,-0.68),2.27,3.64,0.87)
	Core._masonry(b,Vector3(-1.32,0.28,-2.10),2.85,0.30,1.11)
	Core._timber_storey(b,Vector3(-1.32,1.46,-2.10),2.86,0.31,1.18)
	_roof(b,Vector3(-0.14,2.77,-0.61),5.66,4.20,1.67,true)
	# Baia aberta e frontão largo de carga: identidade principal do armazém.
	_box(b,Vector3(-1.38,0.36,0.57),Vector3(2.72,0.27,3.01),WOOD)
	for x in [-2.70,-0.08]:
		for z in [-0.85,1.92]:
			Core._masonry(b,Vector3(x,0.28,z),0.35,0.35,0.46)
			_box(b,Vector3(x,1.70,z),Vector3(0.19,1.97,0.19),WOOD)
			_beam(b,Vector3(x,2.18,z),Vector3(x+(0.42 if x<0 else -0.42),2.66,z),0.14,LIGHT_WOOD)
	Core._gable(b,Vector3(-1.39,2.73,2.03),2.75,1.28)
	Core._roof(b,Vector3(-1.39,2.74,0.89),3.18,2.58,1.29)
	Core._banner(b,Vector3(-1.39,3.24,2.24),0.63,1.03)
	Core._door(b,Vector3(1.15,0.41,1.37),0.97,2.02)
	Core._steps(b,Vector3(1.15,0.19,1.62),1.25,3)
	_awning(b,Vector3(1.13,2.74,1.27),1.65,1.02,0.27)
	_dormer(b,Vector3(0.84,3.44,0.12),0.66)
	Core._chimney(b,Vector3(1.60,3.69,-1.41),1.52,0.62)
	for row in range(2):
		for col in range(4):
			Base._crate(b,Vector3(-2.42+col*0.60,0.49+row*0.47,-1.11),0.92)
	for i in range(7):
		_sack(b,Vector3(-2.37+(i%3)*0.60,0.51+floorf(i/3.0)*0.05,-0.30+floorf(i/3.0)*0.64),b.rng.randf_range(0.85,1.1))
	Base._barrel(b,Vector3(-0.49,0.51,1.09),1.05)
	for x in [-2.33,-1.76,-1.19]:
		Base._crate(b,Vector3(x,0.51,1.58),0.89)
	_sack(b,Vector3(-1.76,0.96,1.57),0.68)
	Base._crate(b,Vector3(2.65,0.24,1.71),0.92)
	Base._crate(b,Vector3(2.65,0.69,1.72),0.69)
	Base._barrel(b,Vector3(2.97,0.24,0.89),0.83)
	_cart(b,Vector3(-2.19,0.20,2.42),0.91,0.95,0.10,"sacks")
	_yard_fence(b,Vector3(-3.00,0.20,-1.67),Vector3(-3.00,0.20,1.86),0.52)
	_yard_fence(b,Vector3(-2.85,0.20,2.18),Vector3(-0.48,0.20,2.18),0.52)
	_bench(b,Vector3(2.99,0.20,-1.39),1.06,PI*0.5)
	for i in range(5): _box(b,Vector3(2.98,0.24+i*0.055,-2.24),Vector3(0.71,0.055,1.02),b.shade(WOOD,0.07))

static func _winery(b) -> void:
	_base(b,7.08)
	Core._masonry(b,Vector3(0.25,0.27,-0.55),3.42,3.33,2.22)
	_plaster_floor(b,Vector3(0.25,2.56,-0.55),3.44,3.34,0.48)
	_roof(b,Vector3(0.25,3.10,-0.55),4.03,3.95,1.47,true)
	Core._gable(b,Vector3(0.15,3.03,1.35),2.73,1.24)
	Core._roof(b,Vector3(0.15,3.07,0.80),3.02,1.57,1.23)
	_dormer(b,Vector3(1.29,3.69,0.03),0.61)
	_dormer(b,Vector3(-0.75,3.66,0.16),0.43)
	Core._chimney(b,Vector3(1.29,3.78,-1.23),1.44,0.61)
	_painted_door(b,Vector3(-0.06,0.41,1.37),1.18,2.09,true)
	Core._steps(b,Vector3(-0.06,0.19,1.62),1.48,3)
	var banner := Base.Batch.new()
	Base._banner(banner,Vector3.ZERO,0.69,1.03)
	Core._merge(b,banner,Transform3D(Basis.IDENTITY,Vector3(0.16,3.93,1.71)))
	# Prensa lateral aberta, maior que os barris portáteis.
	Core._lean_roof(b,Vector3(-1.47,2.97,-0.01),2.46,1.44,0.43,false,-PI*0.5)
	for z in [-1.03,1.0]:
		Core._masonry(b,Vector3(-2.82,0.20,z),0.36,0.36,0.45)
		_box(b,Vector3(-2.82,1.58,z),Vector3(0.20,1.97,0.20),WOOD)
		_beam(b,Vector3(-2.82,2.12,z),Vector3(-2.45,2.60,z),0.14,LIGHT_WOOD)
	Base._press(b,Vector3(-2.29,0.27,1.05),1.15)
	# Ala de pedra da prancha20: a cobertura avança sobre o tonel principal.
	Core._lean_roof(b,Vector3(1.97,2.37,0.17),2.47,1.06,0.41,false,PI*0.5)
	for z in [-0.89,1.19]:
		_box(b,Vector3(2.98,1.16,z),Vector3(0.16,1.90,0.16),WOOD)
	_winery_cellar_wing(b)
	_winery_cask(b,Vector3(2.43,0.99,1.24),0.53,1.03,0.16)
	Base._barrel(b,Vector3(1.62,0.21,2.09),1.02)
	Base._barrel(b,Vector3(2.31,0.21,2.15),0.73)
	Base._crate(b,Vector3(2.74,0.19,2.05),0.86)
	Core._arch_window(b,Vector3(1.22,1.08,1.31),0.57,1.11)
	Core._arch_window(b,Vector3(2.08,1.08,-0.86),0.55,1.08,PI*0.5)
	Core._banner(b,Vector3(2.10,2.72,-0.04),0.41,0.66)
	_pot(b,Vector3(-1.33,0.19,1.90),0.18)
	_pot(b,Vector3(0.85,0.19,1.93),0.17)
	_vine_strip(b,Vector3(-2.66,0.18,2.10),1.61,1.28,PI*0.5)
	_vine_strip(b,Vector3(-2.66,0.18,3.00),1.61,1.28,PI*0.5)
	for side in [-1.0,1.0]:
		_climbing_vine(b,Vector3(0.20+side*1.36,0.21,1.32),3.20,side)

static func _cellar_wall(b, at: Vector3, width: float, height: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	# Só a face exterior recebe blocos; a parede conserva espessura real.
	_box(b,at+basis*Vector3(0,height*0.5,-0.085),Vector3(width,height,0.17),Core.MORTAR,"stone",Vector3(0,rotation,0))
	Core._stone_face(b,at,width,height,rotation)

static func _winery_cellar_wing(b) -> void:
	var wing := Base.Batch.new(20381)
	_box(wing,Vector3(2.43,0.245,-0.20),Vector3(1.18,0.17,1.89),STONE,"stone")
	_cellar_wall(wing,Vector3(2.43,0.28,0.61),1.10,1.52)
	_cellar_wall(wing,Vector3(2.43,0.28,-1.05),1.10,1.52,PI)
	# Parede +X formada em torno de uma abertura, em vez de vidro sobre pedra.
	# Janela: z -0,61..0,01 / y 0,79..1,56; topo sob o beiral existente.
	_cellar_wall(wing,Vector3(2.87,0.28,-0.83),0.44,1.52,PI*0.5)
	_cellar_wall(wing,Vector3(2.87,0.28,0.31),0.60,1.52,PI*0.5)
	_cellar_wall(wing,Vector3(2.87,0.28,-0.30),0.62,0.51,PI*0.5)
	_cellar_wall(wing,Vector3(2.87,1.56,-0.30),0.62,0.24,PI*0.5)
	Core._arch_window(wing,Vector3(2.91,0.79,-0.30),0.62,0.77,PI*0.5)
	_box(wing,Vector3(2.88,1.84,-0.20),Vector3(0.16,0.13,1.91),DARK_WOOD)
	_box(wing,Vector3(2.43,1.84,0.63),Vector3(1.16,0.13,0.15),DARK_WOOD)
	Core._merge(b,wing,Transform3D.IDENTITY)

static func _cask_radius(z: float, radius: float, length: float) -> float:
	return radius*(0.84+0.16*cos(z/(length*0.5)*PI*0.5))

static func _winery_cask(b, at: Vector3, radius: float, length: float, yaw: float) -> void:
	var cask := Base.Batch.new(20477)
	var wood := Color("764b2d")
	var iron := Color("414138")
	var staves := 20
	var segments := 5
	for stave in range(staves):
		var a0 := float(stave)/staves*TAU+0.008
		var a1 := float(stave+1)/staves*TAU-0.008
		var pigment: Color = cask.shade(wood,0.075)
		for segment in range(segments):
			var z0 := (float(segment)/segments-0.5)*length
			var z1 := (float(segment+1)/segments-0.5)*length
			var r0 := _cask_radius(z0,radius,length)
			var r1 := _cask_radius(z1,radius,length)
			cask.quad(Vector3(sin(a0)*r0,cos(a0)*r0,z0),Vector3(sin(a0)*r1,cos(a0)*r1,z1),Vector3(sin(a1)*r1,cos(a1)*r1,z1),Vector3(sin(a1)*r0,cos(a1)*r0,z0),"wood",pigment)
	# Aros ocos: espessura visível, sem discos de metal atravessando a madeira.
	for band in [-0.43,-0.20,0.20,0.43]:
		var z0: float = band*length-0.024
		var z1: float = band*length+0.024
		for segment in range(staves):
			var a0 := float(segment)/staves*TAU
			var a1 := float(segment+1)/staves*TAU
			var p: Array[Vector3] = []
			for z in [z0,z1]:
				for extra in [-0.003,0.017]:
					var r: float = _cask_radius(z,radius,length)+extra
					for angle in [a0,a1]: p.append(Vector3(sin(angle)*r,cos(angle)*r,z))
			cask.quad(p[2],p[6],p[7],p[3],"metal",iron)
			cask.quad(p[0],p[1],p[5],p[4],"metal",iron)
			cask.quad(p[0],p[2],p[3],p[1],"metal",iron.lightened(0.10))
			cask.quad(p[4],p[5],p[7],p[6],"metal",iron.lightened(0.10))
	var end_radius := radius*0.84
	for sign_value in [-1.0,1.0]:
		var z: float = sign_value*(length*0.5+0.003)
		# Fundo escuro entre tábuas e dez aduelas cortadas no círculo da tampa.
		for segment in range(staves):
			var a0 := float(segment)/staves*TAU
			var a1 := float(segment+1)/staves*TAU
			var p0 := Vector3(sin(a0)*end_radius,cos(a0)*end_radius,z-sign_value*0.008)
			var p1 := Vector3(sin(a1)*end_radius,cos(a1)*end_radius,z-sign_value*0.008)
			cask.triangle(Vector3(0,0,z-sign_value*0.008),p1 if sign_value>0 else p0,p0 if sign_value>0 else p1,"wood",DARK_WOOD)
		for plank in range(10):
			var x0 := -end_radius+plank*end_radius*0.2+0.003
			var x1 := -end_radius+(plank+1)*end_radius*0.2-0.003
			var y0 := sqrt(maxf(0,end_radius*end_radius-x0*x0))
			var y1 := sqrt(maxf(0,end_radius*end_radius-x1*x1))
			var p0 := Vector3(x0,-y0,z)
			var p1 := Vector3(x1,-y1,z)
			var p2 := Vector3(x1,y1,z)
			var p3 := Vector3(x0,y0,z)
			cask.quad(p0,p1 if sign_value>0 else p3,p2,p3 if sign_value>0 else p1,"wood",cask.shade(wood.lightened(0.06),0.08))
	for z in [-length*0.30,length*0.30]:
		_box(cask,Vector3(0,-radius-0.07,z),Vector3(radius*2.16,0.16,0.15),DARK_WOOD)
		for x in [-radius*0.77,radius*0.77]:
			_box(cask,Vector3(x,-radius-0.195,z),Vector3(0.15,0.27,0.18),wood)
	Core._merge(b,cask,Transform3D(Basis(Vector3.UP,yaw),at))

static func _lumber(b) -> void:
	_base(b)
	Core._masonry(b,Vector3(0.73,0.23,-0.57),1.83,2.08,1.14)
	_plaster_floor(b,Vector3(0.73,1.43,-0.57),1.85,2.10,0.88)
	_roof(b,Vector3(-0.16,2.39,-0.48),3.95,2.73,1.13,true)
	Core._masonry(b,Vector3(-1.11,0.22,-1.39),1.69,0.17,0.69)
	Core._timber_storey(b,Vector3(-1.11,0.98,-1.39),1.69,0.19,1.34)
	for x in [-1.95,-0.28]:
		Core._masonry(b,Vector3(x,0.21,0.91),0.28,0.28,0.42)
		_box(b,Vector3(x,1.53,0.91),Vector3(0.18,1.86,0.18),WOOD)
		_beam(b,Vector3(x,1.98,0.91),Vector3(x+(0.32 if x< -1 else -0.32),2.38,0.91),0.13,LIGHT_WOOD)
	Core._gable(b,Vector3(-1.10,2.35,1.03),1.78,0.91)
	Core._roof(b,Vector3(-1.10,2.38,0.32),2.13,1.82,0.93)
	Core._small_window(b,Vector3(-1.10,2.62,1.12),0.39,0.46)
	Core._door(b,Vector3(0.79,0.34,0.70),0.69,1.82)
	Core._steps(b,Vector3(0.79,0.17,0.94),0.91,3)
	Core._small_window(b,Vector3(1.77,1.78,-0.42),0.51,0.57,PI*0.5,true)
	_dormer(b,Vector3(0.88,2.76,0.29),0.53)
	Core._chimney(b,Vector3(1.04,3.07,-0.99),1.02,0.45)
	for row in range(3):
		for col in range(3-row):
			Base._log(b,Vector3(-1.61+col*0.38+row*0.19,0.43+row*0.32,-0.48),0.20,1.59)
	Base._workbench(b,Vector3(-1.10,0.21,0.88),1.26)
	_saw(b,Vector3(-1.10,1.10,0.90),0.86)
	Base._cylinder(b,Vector3(-1.72,0.44,1.68),0.28,0.44,WOOD)
	Base._cylinder(b,Vector3(-1.72,0.675,1.68),0.24,0.025,LIGHT_WOOD)
	_beam(b,Vector3(-1.72,0.75,1.68),Vector3(-1.44,1.36,1.70),0.05,WOOD)
	_box(b,Vector3(-1.50,1.25,1.70),Vector3(0.33,0.18,0.05),TRIM,"metal",Vector3(0,0,-0.38))
	for layer in range(4):
		for board in range(3): _box(b,Vector3(-0.77+board*0.22,0.26+layer*0.08,1.86),Vector3(0.19,0.075,0.65),b.shade(WOOD,0.10))
	_cart(b,Vector3(1.76,0.17,-0.70),0.70,1.03,0.0,"logs")
	Core._banner(b,Vector3(-1.33,3.98,-0.33),0.55,0.98)
	_beam(b,Vector3(-1.78,2.60,-0.33),Vector3(-1.78,4.22,-0.33),0.09,WOOD)
	_beam(b,Vector3(-1.89,4.05,-0.33),Vector3(-0.96,4.05,-0.33),0.08,WOOD)
	for i in range(8):
		var at := Vector3(-1.69+b.rng.randf()*1.4,0.22,-0.9+b.rng.randf()*2.7)
		_box(b,at,Vector3(0.09,0.018,0.16),LIGHT_WOOD,"wood",Vector3(0,b.rng.randf()*TAU,0))

static func _sawmill(b) -> void:
	_base(b)
	# Closed hut on +X; open teal workshop on -X. Serra, logs and timber piles.
	Core._masonry(b,Vector3(0.78,0.23,-0.50),1.86,2.10,1.16)
	_plaster_floor(b,Vector3(0.78,1.45,-0.50),1.88,2.12,0.86,true)
	_roof(b,Vector3(0.78,2.38,-0.50),2.38,2.56,1.06,true)
	Core._door(b,Vector3(0.78,0.34,0.70),0.66,1.78)
	Core._steps(b,Vector3(0.78,0.17,0.94),0.88,3)
	Core._small_window(b,Vector3(1.81,1.74,-0.38),0.46,0.54,PI*0.5,true)
	_dormer(b,Vector3(0.88,2.74,0.20),0.48)
	Core._chimney(b,Vector3(1.08,3.02,-0.96),0.98,0.43)
	for x in [-1.92,-0.26]:
		for z in [-1.28,0.86]:
			Core._masonry(b,Vector3(x,0.20,z),0.26,0.26,0.40)
			_box(b,Vector3(x,1.48,z),Vector3(0.16,1.78,0.16),WOOD)
	Core._lean_roof(b,Vector3(-1.10,2.32,-0.22),2.10,1.72,0.38,true)
	Core._gable(b,Vector3(-1.10,2.28,0.96),1.72,0.82)
	_circular_saw(b,Vector3(-1.10,0.78,0.08),0.46)
	Base._workbench(b,Vector3(-1.10,0.21,0.92),1.18)
	_saw(b,Vector3(-1.10,1.10,0.94),0.82)
	for row in range(3):
		for col in range(3-row):
			Base._log(b,Vector3(-1.58+col*0.36+row*0.18,0.42+row*0.30,-0.62),0.18,1.48)
	for layer in range(4):
		for board in range(3):
			_box(b,Vector3(-0.72+board*0.20,0.26+layer*0.075,1.78),Vector3(0.18,0.07,0.62),b.shade(WOOD,0.10))
	Core._banner(b,Vector3(-1.10,3.12,1.02),0.46,0.82)
	_beam(b,Vector3(-1.78,2.28,-0.22),Vector3(-0.42,2.28,-0.22),0.08,WOOD)

static func _circular_saw(b, at: Vector3, radius: float) -> void:
	# Disc faces +Z so the blade is readable from the front of the lot.
	Base._cylinder(b,at,radius,0.036,Color("b4b7b0"),"metal",Vector3(PI*0.5,0,0))
	Base._cylinder(b,at,0.08,0.09,DARK,"metal",Vector3(PI*0.5,0,0))
	for i in range(16):
		var angle := float(i)*TAU/16.0
		_box(b,at+Vector3(cos(angle)*radius,sin(angle)*radius,0),Vector3(0.07,0.08,0.04),Color("a5aba1"),"metal",Vector3(0,0,angle))
	for side in [-1.0,1.0]:
		_box(b,at+Vector3(side*0.52,0.02,0),Vector3(0.10,1.18,0.10),WOOD)
	_box(b,at+Vector3(0,0.62,0),Vector3(1.14,0.10,0.10),DARK_WOOD)
	_box(b,at+Vector3(0,-0.02,0),Vector3(0.16,0.16,0.16),DARK,"metal")

static func _saw(b, at: Vector3, length: float) -> void:
	b.quad(at+Vector3(-length*0.5,0,0),at+Vector3(length*0.5,0,0),at+Vector3(length*0.5,0.17,0),at+Vector3(-length*0.5,0.17,0),"metal",Color("afb2aa"))
	for i in range(12):
		var x := -length*0.5+i*length/12.0
		b.triangle(at+Vector3(x,0,0),at+Vector3(x+length/24.0,-0.055,0),at+Vector3(x+length/12.0,0,0),"metal",Color("a5aba1"))
	for side in [-1.0,1.0]:
		_box(b,at+Vector3(side*(length*0.5+0.03),0.06,0),Vector3(0.070,0.33,0.07),WOOD)
		_box(b,at+Vector3(side*(length*0.5+0.085),0.18,0),Vector3(0.16,0.065,0.07),DARK_WOOD)

static func _quarry(b) -> void:
	_base(b)
	# Face de corte alta, blocos fendidos e grua lateral, como na prancha08.
	for row in range(4):
		for col in range(3):
			var x := -1.86+col*0.57
			var z := -1.57-row*0.08
			_box(b,Vector3(x,0.51+row*0.64,z),Vector3(0.62,0.71,0.82),b.shade(STONE,0.13),"stone",Vector3(0,b.rng.randf_range(-0.04,0.04),0))
	for row in range(3):
		_box(b,Vector3(-2.00,0.47+row*0.54,-0.92+row*0.05),Vector3(0.52,0.63,0.80),b.shade(STONE,0.12),"stone")
	Core._masonry(b,Vector3(0.78,0.24,-0.38),1.86,1.88,1.40)
	_plaster_floor(b,Vector3(0.78,1.71,-0.38),1.90,1.90,0.53)
	_roof(b,Vector3(0.73,2.31,-0.41),2.40,2.38,1.04,true)
	_dormer(b,Vector3(0.58,2.54,0.41),0.51)
	Core._chimney(b,Vector3(1.25,2.93,-0.94),0.90,0.43)
	Core._door(b,Vector3(0.43,0.33,0.80),0.65,1.73)
	Core._steps(b,Vector3(0.43,0.18,1.02),0.83,3)
	_awning(b,Vector3(1.31,2.03,0.61),1.13,0.88,0.26)
	Core._small_window(b,Vector3(1.88,1.59,-0.33),0.43,0.62,PI*0.5,true)
	Base._workbench(b,Vector3(1.63,0.21,1.31),0.77)
	for row in range(2):
		for col in range(3-row):
			_box(b,Vector3(1.06+col*0.36,0.38+row*0.29,1.94),Vector3(0.33,0.28,0.44),b.shade(TRIM,0.10),"stone")
	# Grua com ferragens, corrente e plataforma suspensa carregada.
	Core._masonry(b,Vector3(-1.34,0.19,0.32),0.56,0.53,0.42)
	_box(b,Vector3(-1.34,1.59,0.32),Vector3(0.20,2.32,0.20),WOOD)
	_beam(b,Vector3(-1.34,2.81,0.18),Vector3(-1.34,2.81,1.18),0.18,WOOD)
	_beam(b,Vector3(-1.34,2.01,0.33),Vector3(-1.34,2.76,1.00),0.13,LIGHT_WOOD)
	for y in [0.77,2.64]: _box(b,Vector3(-1.34,y,0.32),Vector3(0.25,0.13,0.25),DARK,"metal")
	Base._cylinder(b,Vector3(-1.34,2.82,1.10),0.12,0.20,DARK,"metal",Vector3(0,0,PI*0.5))
	_beam(b,Vector3(-1.34,2.76,1.10),Vector3(-1.34,1.39,1.10),0.021,DARK,"metal")
	for side in [-1.0,1.0]:
		_beam(b,Vector3(-1.34,1.51,1.10),Vector3(-1.34+side*0.25,1.02,1.10),0.024,DARK,"metal")
	_box(b,Vector3(-1.34,0.97,1.10),Vector3(0.65,0.12,0.66),WOOD)
	_box(b,Vector3(-1.34,1.23,1.10),Vector3(0.49,0.42,0.49),TRIM,"stone")
	Core._banner(b,Vector3(-1.12,3.13,-1.26),0.45,0.79)
	_yard_fence(b,Vector3(-2.09,0.18,0.90),Vector3(-2.09,0.18,1.96),0.47)
	_cart(b,Vector3(-1.42,0.17,1.97),0.58,0.61,PI*0.5,"stone")
	for i in range(9):
		Base._ellipsoid(b,Vector3(b.rng.randf_range(-2.06,-0.60),0.19,b.rng.randf_range(-1.14,1.66)),Vector3(0.12,0.09,0.11),b.shade(STONE,0.13),"stone",true)

static func _farm(b) -> void:
	_base(b)
	var at := Vector3(-0.03,0.23,-0.72)
	Core._masonry(b,at,2.35,1.83,0.89)
	Core._timber_storey(b,at+Vector3.UP*0.95,2.37,1.85,1.18)
	_roof(b,at+Vector3.UP*2.20,2.87,2.30,1.14)
	Core._door(b,Vector3(-0.40,0.31,0.46),0.67,1.77)
	Core._steps(b,Vector3(-0.40,0.17,0.72),0.81,2)
	# Janela circular no frontão e banca de hortaliças sob toldo lateral.
	Base._cylinder(b,Vector3(-0.03,2.72,0.56),0.22,0.055,DARK_WOOD,"wood",Vector3(PI*0.5,0,0))
	Base._cylinder(b,Vector3(-0.03,2.72,0.598),0.17,0.017,Color("635236"),"glass",Vector3(PI*0.5,0,0))
	_box(b,Vector3(-0.03,2.72,0.626),Vector3(0.039,0.38,0.026),LIGHT_WOOD)
	_box(b,Vector3(-0.03,2.72,0.628),Vector3(0.38,0.035,0.028),LIGHT_WOOD)
	Core._chimney(b,Vector3(0.74,2.80,-0.99),1.02,0.41)
	Core._lean_roof(b,Vector3(1.18,2.19,-0.72),1.76,0.49,0.27,false,PI*0.5)
	_awning(b,Vector3(0.83,1.74,0.40),1.15,0.60,0.18,0.0,false)
	Base._workbench(b,Vector3(0.90,0.22,0.72),0.94)
	for i in range(4): _vegetable(b,Vector3(0.59+i*0.19,1.08,0.73),0.12,i%3)
	_vegetable_bed(b,Vector3(-1.33,0.20,1.25),Vector2(1.12,1.40),0)
	_vegetable_bed(b,Vector3(1.09,0.20,1.59),Vector2(1.20,0.91),1)
	_vegetable_bed(b,Vector3(-1.70,0.20,-0.56),Vector2(0.67,1.59),2)
	for pair in [[Vector3(-2.13,0.18,-1.82),Vector3(-2.13,0.18,2.08)],[Vector3(2.13,0.18,-1.82),Vector3(2.13,0.18,2.08)],[Vector3(-2.13,0.18,2.08),Vector3(-0.62,0.18,2.08)],[Vector3(0.45,0.18,2.08),Vector3(2.13,0.18,2.08)]]:
		_yard_fence(b,pair[0],pair[1],0.54)
	Base._barrel(b,Vector3(1.73,0.20,-0.92),0.78)
	_pot(b,Vector3(1.78,0.20,0.10),0.18)
	_sack(b,Vector3(-0.85,0.21,0.55),0.57)
	_crop_banner(b,Vector3(-0.02,3.43,0.53),0.34,0.65)
	for i in range(5):
		Base._ellipsoid(b,Vector3(0.17,1.64-i*0.12,0.55),Vector3(0.062,0.079,0.057),Color("c1a17b"),"plaster",true)
		_beam(b,Vector3(0.17,1.82,0.55),Vector3(0.17,1.12,0.55),0.013,LIGHT_WOOD)

static func _crop_banner(b, at: Vector3, width: float, height: float) -> void:
	b.quad(at+Vector3(-width*0.5,0,0),at+Vector3(-width*0.5,-height*0.89,0.02),at+Vector3(0,-height,0.03),at+Vector3(width*0.5,-height*0.89,0.02),"cloth",TEAL)
	b.triangle(at+Vector3(-width*0.5,0,0),at+Vector3(width*0.5,-height*0.89,0.02),at+Vector3(width*0.5,0,0),"cloth",TEAL)
	_beam(b,at+Vector3(-width*0.62,0.03,0),at+Vector3(width*0.62,0.03,0),0.042,GOLD,"metal")
	_beam(b,at+Vector3(0,-height*0.84,0.05),at+Vector3(0,-height*0.23,0.05),0.019,GOLD,"metal")
	for row in range(3):
		for side in [-1.0,1.0]:
			var p := at+Vector3(side*width*0.14,-height*(0.70-row*0.17),0.055)
			Base._ellipsoid(b,p,Vector3(width*0.16,height*0.057,0.010),GOLD,"metal",true)

static func _vegetable_bed(b, at: Vector3, size: Vector2, kind: int) -> void:
	_box(b,at,Vector3(size.x,0.16,size.y),Color("59462e"),"plaster")
	for x in [-size.x*0.5,size.x*0.5]: _box(b,at+Vector3(x,0.13,0),Vector3(0.063,0.22,size.y+0.10),WOOD)
	for z in [-size.y*0.5,size.y*0.5]: _box(b,at+Vector3(0,0.13,z),Vector3(size.x+0.10,0.22,0.063),WOOD)
	var columns := maxi(2,roundi(size.x/0.40))
	var rows := maxi(2,roundi(size.y/0.40))
	for row in range(rows):
		for col in range(columns):
			var p := at+Vector3((col+0.5)/columns*size.x-size.x*0.5,0.15,(row+0.5)/rows*size.y-size.y*0.5)
			_vegetable(b,p,0.15,kind if (row+col)%3 else 2)

static func _vegetable(b, at: Vector3, size: float, kind: int) -> void:
	if kind == 0:
		Base._ellipsoid(b,at+Vector3.UP*size*0.70,Vector3(size,size*0.8,size),Color("719545"),"foliage")
		for i in range(6):
			var angle := i*TAU/6.0
			_leaf(b,at+Vector3(cos(angle)*size*0.45,size*0.18,sin(angle)*size*0.45),size*1.73,Vector3(-0.60,angle,0),b.shade(Color("547d38"),0.11))
	elif kind == 1:
		Base._cylinder(b,at+Vector3.UP*size*0.50,size*0.41,size*1.3,Color("c5772a"),"foliage",Vector3(PI,0,0),true)
		for i in range(5):
			var angle := i*TAU/5.0
			_beam(b,at+Vector3.UP*size,at+Vector3(cos(angle)*size*0.6,size*2.1,sin(angle)*size*0.6),0.018,LEAF,"foliage")
	else:
		for i in range(7):
			var angle := i*TAU/7.0
			Base._ellipsoid(b,at+Vector3(cos(angle)*size*0.52,size*0.69,sin(angle)*size*0.52),Vector3(size*0.6,size*0.8,size*0.6),b.shade(Color("c78026"),0.06),"foliage",true)
		_beam(b,at+Vector3.UP*size*1.2,at+Vector3(0.025,size*1.65,0.02),size*0.17,DARK_WOOD)

static func _vineyard(b) -> void:
	_base(b)
	# Três linhas de treliças, troncos torcidos, folhas lobadas e cachos pendentes.
	for x in [-1.37,0.0,1.37]:
		_box(b,Vector3(x,0.14,-0.11),Vector3(0.60,0.12,3.72),Color("655337"),"plaster")
		_vine_strip(b,Vector3(x,0.21,-1.85),3.52,1.38)
	Base._fence(b,Vector3(-2.14,0.18,-2.03),Vector3(2.14,0.18,-2.03),0.56)
	Base._fence(b,Vector3(-2.14,0.18,-2.03),Vector3(-2.14,0.18,1.95),0.56)
	Base._fence(b,Vector3(2.14,0.18,-2.03),Vector3(2.14,0.18,1.95),0.56)
	Base._crate(b,Vector3(-0.53,0.19,1.95),0.72)
	for i in range(4): _grapes(b,Vector3(-0.53+(i%2)*0.12,0.66,1.91+floorf(i/2.0)*0.13),0.61)
	Base._barrel(b,Vector3(1.82,0.18,1.79),0.55)

static func _grapes(b, at: Vector3, scale_factor: float = 1.0) -> void:
	for row in range(4):
		var count := 4 if row < 2 else (3 if row == 2 else 1)
		for grape in range(count):
			var angle := grape*TAU/count+row*0.56
			var radius := 0.072*(1.0-row*0.19)
			var p := at+Vector3(cos(angle)*radius,-row*0.07,sin(angle)*radius)*scale_factor
			Base._ellipsoid(b,p,Vector3(0.048,0.054,0.047)*scale_factor,b.shade(Color("39344f"),0.11),"foliage",true)
	_beam(b,at+Vector3.UP*0.17*scale_factor,at,0.017*scale_factor,DARK_WOOD)

static func _vine_strip(b, at: Vector3, length: float, height: float, rotation: float = 0.0) -> void:
	var source := Base.Batch.new(b.rng.randi())
	var count := maxi(1,roundi(length/0.90))
	for i in range(count+1):
		var z := float(i)/count*length
		_box(source,Vector3(0,height*0.5,z),Vector3(0.085,height,0.085),WOOD)
		for y in [height*0.37,height*0.86]:
			for winding in range(3):
				Base._cylinder(source,Vector3(0,y+winding*0.021,z),0.060,0.018,LIGHT_WOOD,"wood")
		var last := Vector3(0,0.03,z)
		for step in range(5):
			var next := Vector3(sin(step*1.77)*0.12,(step+1)*height*0.17,z+cos(step*1.70)*0.065)
			_beam(source,last,next,0.036 if step<2 else 0.024,DARK_WOOD)
			last = next
		for leaf in range(9):
			var p := Vector3(source.rng.randf_range(-0.27,0.27),height*0.74+source.rng.randf_range(-0.04,0.25),z+source.rng.randf_range(-0.25,0.25))
			_leaf(source,p,source.rng.randf_range(0.29,0.45),Vector3(source.rng.randf_range(-0.55,0.20),source.rng.randf()*TAU,source.rng.randf_range(-0.18,0.18)),source.shade(LEAF,0.15))
		for bunch in range(3):
			_grapes(source,Vector3((bunch-1)*0.14,height*0.70,z+(bunch-1)*0.15),source.rng.randf_range(0.88,1.16))
	for y in [height*0.37,height*0.85]:
		_beam(source,Vector3(0,y,-0.08),Vector3(0,y,length+0.08),0.057,WOOD)
		_beam(source,Vector3(0.13,y*0.99,-0.05),Vector3(-0.11,y*1.04,length+0.05),0.018,DARK_WOOD)
	Core._merge(b,source,Transform3D(Basis(Vector3.UP,rotation),at))

static func _climbing_vine(b, at: Vector3, height: float, side: float) -> void:
	var last := at
	for i in range(11):
		var next := at+Vector3(sin(i*1.36)*0.15,height*(i+1)/11.0,0.03)
		_beam(b,last,next,0.026,DARK_WOOD)
		last = next
		for branch in [-1.0,1.0]:
			var tip := next+Vector3(branch*0.15,0.08,0.045)
			_beam(b,next,tip,0.012,WOOD)
			_leaf(b,tip,0.23+b.rng.randf()*0.10,Vector3(PI*0.5,0,side*b.rng.randf_range(-0.45,0.45)),b.shade(LEAF,0.15))
		if i%4 == 0: _grapes(b,next+Vector3(0,0,0.10),0.80)

static func _inn(b) -> void:
	_base(b)
	var at := Vector3(0.04,0.23,-0.42)
	Core._masonry(b,at,2.48,2.18,1.08)
	_plaster_floor(b,at+Vector3.UP*1.14,2.50,2.20,1.72,true)
	_roof(b,at+Vector3.UP*2.92,3.02,2.68,1.18,true)
	_dormer(b,Vector3(-0.62,3.42,0.28),0.50)
	Core._chimney(b,Vector3(0.72,3.18,-0.88),1.28,0.42)
	Core._door(b,Vector3(0.04,0.33,0.82),0.70,1.80)
	Core._steps(b,Vector3(0.04,0.17,1.04),0.90,3)
	Core._small_window(b,Vector3(-0.72,2.28,0.78),0.40,0.52)
	Core._small_window(b,Vector3(0.78,2.28,0.78),0.40,0.52)
	Core._small_window(b,Vector3(1.40,1.72,-0.30),0.44,0.56,PI*0.5,true)
	_awning(b,Vector3(1.18,1.88,0.72),1.22,0.70,0.22,PI*0.5)
	_box(b,Vector3(1.28,0.92,0.86),Vector3(0.62,0.10,0.38),WOOD)
	for i in range(3): Base._barrel(b,Vector3(-1.58+i*0.36,0.20,1.42),0.62)
	_bench(b,Vector3(-1.42,0.20,0.72),0.86,0.15)
	_bench(b,Vector3(1.46,0.20,1.42),0.80,PI*0.5)
	Core._banner(b,Vector3(0.04,3.22,0.92),0.42,0.74)
	_beam(b,Vector3(-1.62,2.42,1.02),Vector3(-0.72,2.42,1.02),0.06,WOOD)
	Base._cylinder(b,Vector3(-1.18,2.10,1.08),0.13,0.22,Color("8a5a28"),"plaster",Vector3(PI*0.5,0,0))
	Base._cylinder(b,Vector3(-1.18,2.10,1.08),0.08,0.10,Color("d8c49a"),"plaster",Vector3(PI*0.5,0,0))
	_box(b,Vector3(-1.18,2.26,1.08),Vector3(0.06,0.16,0.06),DARK_WOOD)
	_box(b,Vector3(1.72,0.72,1.58),Vector3(0.36,0.62,0.08),DARK_WOOD)
	_box(b,Vector3(1.72,0.72,1.60),Vector3(0.30,0.52,0.02),Color("c4b387"),"plaster")
	for pair in [[Vector3(-2.08,0.18,-1.72),Vector3(-2.08,0.18,1.86)],[Vector3(2.08,0.18,-1.72),Vector3(2.08,0.18,1.86)],[Vector3(-2.08,0.18,1.86),Vector3(-0.62,0.18,1.86)],[Vector3(0.68,0.18,1.86),Vector3(2.08,0.18,1.86)]]:
		_yard_fence(b,pair[0],pair[1],0.52)
	Base._crate(b,Vector3(1.62,0.20,-1.28),0.72)

static func _mill(b) -> void:
	_base(b)
	Core._masonry(b,Vector3(0.02,0.22,-0.28),1.86,1.86,1.62)
	_plaster_floor(b,Vector3(0.02,1.90,-0.28),1.68,1.68,1.28)
	_roof(b,Vector3(0.02,3.22,-0.28),2.22,2.22,1.12)
	Core._door(b,Vector3(0.02,0.34,0.76),0.62,1.70)
	Core._steps(b,Vector3(0.02,0.17,0.98),0.80,3)
	Core._small_window(b,Vector3(1.00,2.38,-0.28),0.38,0.48,PI*0.5,true)
	Core._small_window(b,Vector3(-0.96,2.38,-0.28),0.38,0.48,-PI*0.5,true)
	Core._banner(b,Vector3(0.02,2.48,0.82),0.38,0.66)
	_mill_sails(b,Vector3(0.02,3.02,0.88),1.22)
	_sack(b,Vector3(-1.52,0.20,1.28),0.58)
	_sack(b,Vector3(-1.18,0.20,1.48),0.52)
	_cart(b,Vector3(1.48,0.17,1.08),0.58,0.74,-0.18,"sacks")
	Core._lean_roof(b,Vector3(-1.28,1.72,-0.28),1.36,0.70,0.24,true,-PI*0.5)
	for z in [-0.72,0.18]: _box(b,Vector3(-1.78,0.86,z),Vector3(0.12,1.28,0.12),WOOD)
	_yard_fence(b,Vector3(-2.04,0.18,0.72),Vector3(-2.04,0.18,1.72),0.46)
	_yard_fence(b,Vector3(-2.04,0.18,1.72),Vector3(-0.40,0.18,1.72),0.46)

static func _mill_sails(b, at: Vector3, length: float) -> void:
	Base._cylinder(b,at,0.15,0.20,DARK_WOOD,"wood",Vector3(PI*0.5,0,0))
	Base._cylinder(b,at+Vector3(0,0,0.12),0.07,0.10,DARK,"metal",Vector3(PI*0.5,0,0))
	_box(b,at+Vector3(0,0,-0.28),Vector3(0.10,0.10,0.58),DARK_WOOD)
	for i in range(4):
		var angle := float(i)*PI*0.5+0.32
		var dir := Vector3(cos(angle),sin(angle),0)
		_box(b,at+dir*(length*0.52),Vector3(0.09,length,0.05),WOOD,"wood",Vector3(0,0,angle))
		_box(b,at+dir*(length*0.54)+Vector3(0,0,0.04),Vector3(0.38,length*0.70,0.02),Color("c4b387"),"cloth",Vector3(0,0,angle))

static func _bakery(b) -> void:
	_base(b)
	var at := Vector3(-0.18,0.23,-0.46)
	Core._masonry(b,at,2.22,2.06,1.12)
	_plaster_floor(b,at+Vector3.UP*1.18,2.24,2.08,1.48,true)
	_roof(b,at+Vector3.UP*2.72,2.72,2.52,1.10,true)
	_dormer(b,Vector3(-0.18,3.18,0.22),0.48)
	Core._chimney(b,Vector3(0.62,3.02,-0.86),1.36,0.46)
	Core._door(b,Vector3(-0.18,0.33,0.72),0.64,1.74)
	Core._steps(b,Vector3(-0.18,0.17,0.94),0.84,3)
	Core._small_window(b,Vector3(-0.86,2.12,0.68),0.38,0.50)
	_awning(b,Vector3(0.72,1.78,0.78),1.28,0.62,0.20)
	_box(b,Vector3(0.72,0.86,0.86),Vector3(1.10,0.12,0.42),WOOD)
	for i in range(4): _loaf_basket(b,Vector3(0.28+i*0.28,0.98,0.86),0.72)
	for i in range(3): _loaf_basket(b,Vector3(-1.42+i*0.28,0.20,1.48),0.80)
	Core._masonry(b,Vector3(1.42,0.22,-0.18),0.92,1.10,1.18)
	Base._cylinder(b,Vector3(1.42,1.28,-0.18),0.34,0.28,STONE,"stone",Vector3(PI*0.5,0,0))
	Base._cylinder(b,Vector3(1.42,1.28,0.02),0.16,0.08,Color("c19741"),"metal",Vector3(PI*0.5,0,0))
	for layer in range(3):
		for board in range(2): _box(b,Vector3(1.62+board*0.16,0.24+layer*0.08,0.72),Vector3(0.14,0.07,0.42),b.shade(WOOD,0.10))
	_sack(b,Vector3(-1.52,0.20,0.62),0.56)
	_sack(b,Vector3(-1.22,0.20,0.86),0.50)
	Core._banner(b,Vector3(-0.18,3.08,0.86),0.40,0.70)
	_beam(b,Vector3(-1.48,2.28,0.86),Vector3(-0.72,2.28,0.86),0.05,WOOD)
	for i in range(2): _oval(b,Vector3(-1.10,2.02,0.92)+Vector3(i*0.08,0,0),0.10)

static func _loaf_basket(b, at: Vector3, scale_factor: float = 1.0) -> void:
	_box(b,at,Vector3(0.28,0.08,0.22)*scale_factor,WOOD)
	for i in range(2):
		Base._ellipsoid(b,at+Vector3((float(i)-0.5)*0.08,0.08,0)*scale_factor,Vector3(0.09,0.05,0.12)*scale_factor,Color("c19357"),"plaster")

static func _oval(b, at: Vector3, size: float) -> void:
	Base._ellipsoid(b,at,Vector3(size,size*0.7,size*0.55),Color("c19357"),"plaster")

static func _workshop(b) -> void:
	_base(b)
	Core._masonry(b,Vector3(0.72,0.23,-0.46),1.72,2.02,1.14)
	_plaster_floor(b,Vector3(0.72,1.43,-0.46),1.74,2.04,0.82,true)
	_roof(b,Vector3(0.72,2.32,-0.46),2.18,2.46,1.02,true)
	Core._door(b,Vector3(0.72,0.34,0.70),0.64,1.76)
	Core._steps(b,Vector3(0.72,0.17,0.92),0.84,3)
	Core._small_window(b,Vector3(1.70,1.68,-0.36),0.42,0.52,PI*0.5,true)
	_dormer(b,Vector3(0.78,2.68,0.16),0.46)
	Core._chimney(b,Vector3(1.02,2.96,-0.92),0.96,0.40)
	for x in [-1.86,-0.22]:
		for z in [-1.18,0.78]:
			Core._masonry(b,Vector3(x,0.20,z),0.24,0.24,0.38)
			_box(b,Vector3(x,1.36,z),Vector3(0.14,1.58,0.14),WOOD)
	Core._lean_roof(b,Vector3(-1.04,2.18,-0.20),1.96,1.58,0.34,true)
	_awning(b,Vector3(-1.04,1.92,0.92),1.72,0.58,0.18)
	Base._workbench(b,Vector3(-1.04,0.21,0.86),1.16)
	_saw(b,Vector3(-1.04,1.10,0.88),0.78)
	_wheel(b,Vector3(-1.72,0.48,1.42),0.28)
	for i in range(3):
		_box(b,Vector3(-1.62+i*0.12,0.72,1.58),Vector3(0.05,1.22,0.05),WOOD,"wood",Vector3(0.08,0,0.12*float(i)))
	for i in range(2):
		Base._cylinder(b,Vector3(-0.52,0.62+i*0.28,1.52),0.20,0.04,WOOD,"wood",Vector3(PI*0.5,0.2,0))
		_box(b,Vector3(-0.52,0.62+i*0.28,1.52),Vector3(0.22,0.04,0.22),LIGHT_WOOD)
	for row in range(2):
		for col in range(3-row):
			Base._log(b,Vector3(-1.48+col*0.32+row*0.16,0.40+row*0.26,-0.58),0.16,1.28)
	for layer in range(3):
		for board in range(3): _box(b,Vector3(-0.68+board*0.18,0.24+layer*0.07,1.72),Vector3(0.16,0.06,0.52),b.shade(WOOD,0.10))
	_cart(b,Vector3(1.62,0.17,-0.72),0.64,0.92,0.08)
	Core._banner(b,Vector3(-1.04,3.02,0.96),0.42,0.74)

static func _barracks(b) -> void:
	_base(b)
	var at := Vector3(-0.36,0.23,-0.52)
	Core._masonry(b,at,2.28,2.10,1.28)
	_plaster_floor(b,at+Vector3.UP*1.34,2.30,2.12,1.22)
	_roof(b,at+Vector3.UP*2.62,2.78,2.56,1.08,true)
	Core._door(b,Vector3(-0.36,0.34,0.68),0.68,1.78)
	Core._steps(b,Vector3(-0.36,0.17,0.90),0.88,3)
	Core._small_window(b,Vector3(-1.12,2.08,0.64),0.36,0.48)
	Core._small_window(b,Vector3(0.38,2.08,0.64),0.36,0.48)
	Core._small_window(b,Vector3(0.90,1.72,-0.40),0.40,0.52,PI*0.5,true)
	Core._chimney(b,Vector3(0.42,3.02,-0.92),1.08,0.42)
	Core._banner(b,Vector3(-0.36,3.02,0.78),0.44,0.78)
	_yard_fence(b,Vector3(0.72,0.18,0.86),Vector3(0.72,0.18,1.86),0.48)
	_yard_fence(b,Vector3(0.72,0.18,1.86),Vector3(1.96,0.18,1.86),0.48)
	_yard_fence(b,Vector3(1.96,0.18,0.86),Vector3(1.96,0.18,1.86),0.48)
	_box(b,Vector3(1.34,0.86,1.18),Vector3(0.10,1.18,0.10),WOOD)
	_box(b,Vector3(1.34,1.42,1.18),Vector3(0.28,0.42,0.16),Color("c4b387"),"plaster")
	_box(b,Vector3(1.70,0.72,1.52),Vector3(0.08,1.02,0.08),WOOD)
	for i in range(3): _box(b,Vector3(1.70,0.42+i*0.22,1.58),Vector3(0.22,0.04,0.22),WOOD)
	for i in range(4): _box(b,Vector3(0.96+i*0.08,0.78,1.72),Vector3(0.04,1.10,0.04),WOOD,"wood",Vector3(0.06,0,0))
	Base._crate(b,Vector3(1.62,0.20,0.72),0.70)
	Base._barrel(b,Vector3(-1.62,0.20,1.42),0.70)
	_awning(b,Vector3(1.28,1.72,-0.08),1.10,0.58,0.18,PI*0.5)
