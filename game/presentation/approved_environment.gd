extends RefCounted
## Pinheiros e granito originais: geometria 3D fixa, solo Y=0, sem billboards.
## Seis pinheiros, três carvalhos, três tocos e seis rochas compartilhados.
## tree(seed): 12/17 pinheiros, 4/17 carvalhos, 1/17 tocos; sem aleatoriedade global.
## Uma superfície opaca por objeto; paleta sRGB convertida pelo Forward+/Mobile.
## A distribuição e colisão continuam sendo responsabilidade do terreno/simulação.

static var _trees: Dictionary = {}
static var _rocks: Dictionary = {}
static var _oaks: Dictionary = {}
static var _stumps: Dictionary = {}
static var _material: StandardMaterial3D

class Geometry extends RefCounted:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var silhouette_indices := PackedInt32Array()
	var micro_detail := false
	var rng := RandomNumberGenerator.new()
	func _init(seed_value: int) -> void:
		rng.seed = seed_value
	func tri(a: Vector3, b: Vector3, c: Vector3, tint: Color, normal: Vector3 = Vector3.ZERO) -> void:
		var n := normal if normal != Vector3.ZERO else (b-a).cross(c-a).normalized()
		var start := positions.size()
		for point: Vector3 in [a,b,c]:
			positions.append(Vector3(point.x,maxf(0.0,point.y),point.z)); normals.append(n); colors.append(tint.lerp(tint.srgb_to_linear(),0.4))
		indices.append_array(PackedInt32Array([start,start+2,start+1]))
		if not micro_detail:silhouette_indices.append_array(PackedInt32Array([start,start+2,start+1]))
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
		tri(a,b,c,tint); tri(a,c,d,tint)
	func quad_smooth(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, ns: Array[Vector3]) -> void:
		var start := positions.size()
		var ps: Array[Vector3] = [a,b,c,d]
		for i in range(4):
			positions.append(ps[i]); normals.append(ns[i]); colors.append(tint.lerp(tint.srgb_to_linear(),0.4))
		indices.append_array(PackedInt32Array([start,start+2,start+1,start,start+3,start+2]))
		if not micro_detail:silhouette_indices.append_array(PackedInt32Array([start,start+2,start+1,start,start+3,start+2]))
	func shade(tint: Color, spread: float = 0.09) -> Color:
		var value := rng.randf_range(-spread,spread)
		return tint.lightened(value) if value>0 else tint.darkened(-value)
	func finish() -> ArrayMesh:
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=positions; arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		# Closed sprays collapse their first/last ring. Zero-area triangles are
		# invisible but were still submitted in every color and shadow pass.
		var clean := _without_degenerate(indices)
		arrays[Mesh.ARRAY_INDEX]=clean
		var silhouette := _without_degenerate(silhouette_indices)
		var lods:Dictionary={}
		# Only sub-2.5cm ribs/grain are omitted; all canopy masses, branch tips,
		# bark volume and rock outline stay. Godot selects this by screen size.
		if silhouette.size()<clean.size():lods[0.025]=silhouette
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
		mesh.set_meta("silhouette_indices",silhouette)
		return mesh
	func _without_degenerate(source:PackedInt32Array)->PackedInt32Array:
		var clean:=PackedInt32Array()
		for i in range(0,source.size(),3):
			var a:Vector3=positions[source[i]];var b:Vector3=positions[source[i+1]];var c:Vector3=positions[source[i+2]]
			if (b-a).cross(c-a).length_squared()<0.000000000001:continue
			clean.append(source[i]);clean.append(source[i+1]);clean.append(source[i+2])
		return clean


static func tree(seed: int = 1) -> Node3D:
	var family := posmod(seed,17)
	if family==0:return stump(seed)
	if family<=4:
		var oak_variant := posmod(seed,3)
		if not _oaks.has(oak_variant):_oaks[oak_variant]=_mesh_for("oak",oak_variant)
		return _instance(_oaks[oak_variant],"ApprovedOak",oak_variant)
	return pine(seed)

static func pine(seed: int = 1) -> Node3D:
	var variant := posmod(seed,6)
	if not _trees.has(variant): _trees[variant]=_mesh_for("pine",variant)
	return _instance(_trees[variant],"ApprovedPine",variant)

static func stump(seed: int = 1) -> Node3D:
	var variant := posmod(seed,3)
	if not _stumps.has(variant):_stumps[variant]=_mesh_for("stump",variant)
	return _instance(_stumps[variant],"ApprovedStump",variant)

static func rock(seed: int = 1) -> Node3D:
	var variant := posmod(seed,6)
	if not _rocks.has(variant): _rocks[variant]=_mesh_for("rock",variant)
	return _instance(_rocks[variant],"ApprovedGranite",variant)

static func _mesh_for(kind:String,variant:int)->ArrayMesh:
	# LODs are baked with the Godot editor, never generated during gameplay.
	# Procedural originals remain a complete fallback and the editable source.
	var path := "res://assets/approved/environment-lod/%s-%d.res" % [kind,variant]
	if ResourceLoader.exists(path):return load(path) as ArrayMesh
	match kind:
		"oak":return _oak(variant)
		"rock":return _granite(variant)
		"stump":return _cut_stump(variant)
	return _pine(variant)

static func _instance(mesh: ArrayMesh, label: String, variant: int) -> Node3D:
	if _material==null:
		_material=StandardMaterial3D.new()
		_material.resource_name="ApprovedEnvironment_VertexPBR"
		_material.vertex_color_use_as_albedo=true
		_material.vertex_color_is_srgb=true
		_material.roughness=0.94
		_material.metallic_specular=0.12
		var noise := FastNoiseLite.new(); noise.seed=12071; noise.frequency=0.19
		noise.fractal_octaves=3
		var grain := NoiseTexture2D.new(); grain.width=256; grain.height=256
		grain.noise=noise; grain.seamless=true
		var ramp := Gradient.new(); ramp.set_color(0,Color(0.65,0.65,0.65)); ramp.set_color(1,Color.WHITE)
		grain.color_ramp=ramp
		_material.albedo_texture=grain
		_material.uv1_triplanar=true
		_material.uv1_scale=Vector3.ONE*2.5
	var root := Node3D.new(); root.name=label+str(variant)
	var model := MeshInstance3D.new(); model.name="Geometry"
	model.mesh=mesh; model.material_override=_material; root.add_child(model)
	root.set_meta("environment_variant",variant)
	root.set_meta("environment_kind",{"ApprovedPine":"pine","ApprovedOak":"oak","ApprovedStump":"stump","ApprovedGranite":"rock"}.get(label,"unknown"))
	root.set_meta("triangles",mesh.surface_get_array_index_len(0)/3)
	root.set_meta("draw_surfaces",1)
	root.set_meta("bounds",mesh.get_aabb())
	return root

static func _tube(g: Geometry, a: Vector3, b: Vector3, radius_a: float, radius_b: float, tint: Color, sides: int = 7) -> void:
	var axis := (b-a).normalized()
	var cross := axis.cross(Vector3.FORWARD).normalized()
	if cross.length_squared()<0.1: cross=Vector3.RIGHT
	var side := axis.cross(cross).normalized()
	for i in range(sides):
		var angle0 := TAU*float(i)/sides
		var angle1 := TAU*float(i+1)/sides
		var r0 := cross*cos(angle0)+side*sin(angle0)
		var r1 := cross*cos(angle1)+side*sin(angle1)
		var shade := g.shade(tint,0.12)
		g.quad(a+r0*radius_a,a+r1*radius_a,b+r1*radius_b,b+r0*radius_b,shade)
		g.tri(b,b+r0*radius_b,b+r1*radius_b,tint.lightened(0.05))

static func _pine(variant: int) -> ArrayMesh:
	var g := Geometry.new(88127+variant*691)
	var height := 6.0+variant*0.20+g.rng.randf_range(-0.2,0.2)
	var width := g.rng.randf_range(1.40,1.75)
	var lean := Vector3(g.rng.randf_range(-0.14,0.14),0,g.rng.randf_range(-0.14,0.14))
	var bark := Color("655038")
	# An uneven fluted trunk; bark ridges are real geometry, not camera-facing cards.
	for ring in range(7):
		var t0 := float(ring)/7.0
		var t1 := float(ring+1)/7.0
		var a := Vector3.UP*(height*t0)+lean*t0
		var b := Vector3.UP*(height*t1)+lean*t1
		var ra := lerpf(0.235,0.018,pow(t0,0.75))
		var rb := lerpf(0.235,0.018,pow(t1,0.75))
		_tube(g,a,b,ra,rb,bark,11)
		if ring<4:
			g.micro_detail=true
			for ridge in range(7):
				var angle := ridge*TAU/7.0+0.08*ring
				var outward := Vector3(cos(angle),0,sin(angle))
				_tube(g,a+outward*ra*0.98+Vector3.UP*0.025,b+outward*rb*0.98,0.023,0.011,g.shade(Color("423c2e")),4)
		g.micro_detail=false
	for i in range(6):
		var angle := i*TAU/6.0+g.rng.randf_range(-0.20,0.20)
		var outward := Vector3(cos(angle),0,sin(angle))
		_tube(g,Vector3.UP*0.43,outward*g.rng.randf_range(0.52,0.84)+Vector3.UP*0.015,0.125,0.016,bark,6)
	# Lower bare branches show the trunk and break the repetitive conical outline.
	for i in range(5):
		var angle := i*2.39
		var from := Vector3.UP*(0.95+i*0.16)
		var to := from+Vector3(cos(angle)*0.62,-0.11,sin(angle)*0.62)
		_tube(g,from,to,0.045,0.009,bark,5)
	# Staggered whorls carry overlapping needle sprays, with deliberately open gaps.
	for layer in range(8):
		var t := float(layer)/8.0
		var y := height*(0.24+t*0.65)
		var radius := width*pow(1.0-t,0.82)
		var branches := 7 if layer<4 else 6
		for branch in range(branches):
			var angle := TAU*float(branch)/branches+layer*1.37+g.rng.randf_range(-0.22,0.22)
			var direction := Vector3(cos(angle),0,sin(angle))
			var lateral := Vector3(-sin(angle),0,cos(angle))
			var reach := radius*g.rng.randf_range(0.75,1.16)
			var start := lean*t+Vector3.UP*(y+g.rng.randf_range(-0.12,0.12))
			var end := start+direction*reach+Vector3.UP*(-0.11+0.20*t)
			_tube(g,start,end,0.052*(1.0-t)+0.012,0.008,bark,5)
			var tint := Color("40562b").lerp(Color("657637"),t*0.58)
			for segment in range(4):
				var progress := 0.24+segment*0.24
				var center := start.lerp(end,progress)
				var fan_side := -1.0 if segment%2==0 else 1.0
				var fan_direction := (direction+lateral*fan_side*0.30).normalized()
				var length := (0.65+radius*0.27)*(1.0-segment*0.12)
				var breadth := (0.19+radius*0.065)*(1.0-segment*0.12)
				_spray(g,center,fan_direction,length,breadth,g.shade(tint,0.07))
				if segment==1 and layer<6:
					_spray(g,center+lateral*0.18, (direction-lateral*0.63).normalized(),length*0.73,breadth*0.65,g.shade(tint,0.05))
	# A slender leader, surrounded by upright young shoots.
	for i in range(5):
		var angle := TAU*i/5.0
		_spray(g,Vector3.UP*(height*0.88)+lean,Vector3(cos(angle)*0.65,0.30,sin(angle)*0.65).normalized(),0.44,0.12,Color("637638"))
	_tube(g,Vector3.UP*(height*0.90)+lean,Vector3.UP*(height*1.015)+lean,0.13,0.002,Color("587032"),7)
	return g.finish()

static func _spray(g: Geometry, at: Vector3, direction: Vector3, length: float, breadth: float, tint: Color) -> void:
	# Folded, closed needle masses have pointed scallops and a lit dorsal ridge.
	var side := Vector3.UP.cross(direction).normalized()
	if side.length_squared()<0.1: side=Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var previous := PackedVector3Array()
	var previous_normals: Array[Vector3] = []
	for ring in range(3):
		var t := float(ring)/2.0
		var center := at+direction*(t-0.20)*length-up*(t*t*0.27)
		var extent := sin(t*PI)*breadth
		var current := PackedVector3Array()
		var current_normals: Array[Vector3] = []
		for vertex in range(6):
			var angle := TAU*float(vertex)/6.0
			var jagged := 1.0+(0.20 if (ring+vertex)%2==0 else -0.06)
			var offset := side*cos(angle)*extent*jagged+up*sin(angle)*extent*0.36
			current.append(center+offset)
			current_normals.append((side*cos(angle)+up*sin(angle)*2.5+direction*(t*2.0-1.0)*0.5).normalized())
		if ring>0:
			for vertex in range(6):
				var next := (vertex+1)%6
				var face_tint := tint.lightened(0.065) if vertex<3 else tint.darkened(0.15)
				g.quad_smooth(previous[vertex],previous[next],current[next],current[vertex],g.shade(face_tint,0.025),[previous_normals[vertex],previous_normals[next],current_normals[next],current_normals[vertex]])
		previous=current
		previous_normals=current_normals
	# Small rigid needles extend the silhouette; they are actual folded leaves.
	for i in range(4):
		var t := 0.31+i*0.145
		var center := at+direction*(t-0.20)*length-up*t*t*0.27
		for sign_value: float in [-1.0,1.0]:
			var flank := side*sign_value
			var root := center+flank*breadth*sin(t*PI)*0.61
			var point := root+flank*breadth*0.45+direction*length*0.24-up*0.06
			g.tri(root-direction*0.10,point,root+up*0.065,tint.lightened(0.04))
			g.tri(root+up*0.065,point,root+direction*0.10,tint)

	# Fine folded needles across each spray add readable ribs without alpha textures.
	g.micro_detail=true
	for i in range(6):
		var t := 0.27+float(i%3)*0.16
		var sign_value := -1.0 if i<3 else 1.0
		var center := at+direction*(t-0.20)*length-up*(t*t*0.27)
		var stem := center+side*sign_value*breadth*0.19+up*breadth*0.22
		var tip := stem+direction*length*0.30+side*sign_value*breadth*0.66-up*0.07
		var ridge := stem.lerp(tip,0.52)+up*0.023
		var left := stem-side*0.017
		var right := stem+side*0.017
		g.tri(left,tip,ridge,tint.lightened(0.085))
		g.tri(ridge,tip,right,tint.lightened(0.025))
		g.tri(left,ridge,right,tint)
		g.tri(left,right,tip,tint.darkened(0.08))

	g.micro_detail=false

static func _granite(variant: int) -> ArrayMesh:
	var g := Geometry.new(18079+variant*409)
	# One dominant fractured boulder and differently sized fallen slabs, not spheres.
	_block(g,Vector3(0,0,0),Vector3(1.12,1.7+variant*0.065,0.88),0.22)
	for i in range(6):
		var angle := TAU*float(i)/6.0+g.rng.randf_range(-0.18,0.18)
		var radius := g.rng.randf_range(0.80,1.05)
		var scale := g.rng.randf_range(0.35,0.68)
		_block(g,Vector3(cos(angle)*radius,0.0,sin(angle)*radius),Vector3(scale,g.rng.randf_range(0.45,0.95),scale*0.77),0.13)
	for i in range(9):
		var angle := i*2.399
		_block(g,Vector3(cos(angle)*1.38,0,sin(angle)*1.15),Vector3(0.13,0.12,0.095),0.03)
	return g.finish()

static func _block(g: Geometry, at: Vector3, extent: Vector3, moss: float) -> void:
	var rings: Array[PackedVector3Array] = []
	var angle_offset := g.rng.randf()*TAU
	for layer in range(3):
		var ring := PackedVector3Array()
		var y: float = [0.015,0.52,1.0][layer]*extent.y
		for i in range(8):
			var angle := angle_offset+TAU*i/8.0
			var rough := g.rng.randf_range(0.86,1.14)*(0.71 if layer==2 else 1.0)
			var height := y+(g.rng.randf_range(-0.12,0.12)*extent.y if layer>0 else 0.0)
			ring.append(at+Vector3(cos(angle)*extent.x*rough,maxf(0.008,height),sin(angle)*extent.z*rough))
		rings.append(ring)
	var top := at+Vector3(-extent.x*0.08,extent.y*1.03,extent.z*0.14)
	for side in range(8):
		var next := (side+1)%8
		for layer in range(2):
			var color := g.shade(Color("8b8b78"),0.19)
			var a := rings[layer][side]; var b := rings[layer][next]
			var c := rings[layer+1][next]; var d := rings[layer+1][side]
			g.quad(a,d,c,b,color)
			if extent.x>0.3:
				var normal := (d-a).cross(b-a).normalized()*0.004
				g.micro_detail=true
				for grain in range(6):
					var u := g.rng.randf_range(0.10,0.85); var v := g.rng.randf_range(0.10,0.85)
					var point := a.lerp(b,u).lerp(d.lerp(c,u),v)+normal
					var du := (b-a).normalized()*g.rng.randf_range(0.009,0.027)
					var dv := (d-a).normalized()*g.rng.randf_range(0.012,0.036)
					g.tri(point,point+dv,point+du,g.shade(Color("b4b1a0") if grain%2==0 else Color("686c5e"),0.11))
			g.micro_detail=false
			# Thin irregular seams in the stone surface make fracture planes readable.
			if side%3==0:
				var n := (d-a).cross(b-a).normalized()*0.002
				var p := a.lerp(b,0.57)+n
				var q := d.lerp(c,0.54)+n
				g.tri(p,q,q+(b-a).normalized()*0.019,Color("5b6254"))
			if g.rng.randf()<moss+0.20:
				var a2 := a.lerp(d,0.38)+(a-b).normalized()*0.003
				var b2 := a.lerp(b,0.62).lerp(d.lerp(c,0.62),0.45)
				var c2 := d.lerp(c,0.52)
				var normal := (d-a).cross(b-a).normalized()*0.004
				_moss_patch(g,a2+normal,c2+normal,b2+normal,g.shade(Color("56643a"),0.13))
		var top_color := g.shade(Color("a5a48d"),0.12)
		g.tri(rings[2][side],top,rings[2][next],top_color)
		if g.rng.randf()<0.44:
			var a := rings[2][side].lerp(top,0.26)+Vector3.UP*0.005
			var b := rings[2][next].lerp(top,0.30)+Vector3.UP*0.005
			var c := top.lerp(rings[2][side],0.23)+Vector3.UP*0.005
			_moss_patch(g,a,c,b,g.shade(Color("687746"),0.14))

static func _moss_patch(g: Geometry,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	var center := (a+b+c)/3.0
	var edge: Array[Vector3] = [a,a.lerp(b,0.33),a.lerp(b,0.71),b,b.lerp(c,0.32),b.lerp(c,0.72),c,c.lerp(a,0.31),c.lerp(a,0.72)]
	for i in range(edge.size()): edge[i]=center.lerp(edge[i],g.rng.randf_range(0.54,1.0))
	for i in range(edge.size()): g.tri(center,edge[i],edge[(i+1)%edge.size()],g.shade(tint,0.10))

static func _oak(variant: int) -> ArrayMesh:
	var g := Geometry.new(44181+variant*811)
	var bark := Color("705238")
	var height := 5.15+variant*0.24
	var trunk_top := Vector3(0.17,height*0.57,-0.11)
	_tube(g,Vector3(0,0.02,0),Vector3(-0.10,1.6,0.08),0.30,0.235,bark,11)
	_tube(g,Vector3(-0.10,1.6,0.08),trunk_top,0.235,0.15,bark,9)
	for i in range(7):
		var angle := i*TAU/7.0+0.13
		var offset := Vector3(cos(angle),0,sin(angle))
		_tube(g,Vector3.UP*0.52,offset*g.rng.randf_range(0.61,0.95)+Vector3.UP*0.02,0.14,0.021,bark,6)
		_tube(g,offset*0.27+Vector3.UP*0.30,Vector3(-0.1,1.55,0.08)+offset*0.22,0.025,0.012,Color("493c2b"),4)
	var centers: Array[Vector3]=[]
	for i in range(7):
		var angle := i*2.399+variant*0.21
		var radial := Vector3(cos(angle),0,sin(angle))
		var from := Vector3(-0.02,1.75+i*0.16,0.04)
		var elbow := from+radial*g.rng.randf_range(0.65,0.85)+Vector3.UP*0.65
		var tip := elbow+radial*g.rng.randf_range(0.54,0.76)+Vector3.UP*(0.50+i*0.035)
		_tube(g,from,elbow,0.135-i*0.008,0.077,bark,8)
		_tube(g,elbow,tip,0.077,0.025,bark,7)
		centers.append(tip+Vector3.UP*0.17)
		var side := Vector3(-radial.z,0,radial.x)
		var fork := elbow+radial*0.66+side*0.55+Vector3.UP*0.73
		_tube(g,elbow,fork,0.057,0.016,bark,6)
		centers.append(fork)
	centers.append(Vector3(0.05,height-0.55,-0.15))
	centers.append(Vector3(-0.70,height-0.68,0.23))
	centers.append(Vector3(0.64,height-0.73,0.35))
	centers.append(Vector3(-0.10,height*0.70,0.36))
	centers.append(Vector3(0.24,height*0.78,-0.18))
	for cluster in range(centers.size()):
		var tint := Color("687b35").lerp(Color("a0a04f"),g.rng.randf_range(0.0,0.44))
		for leaf in range(43):
			var azimuth := g.rng.randf()*TAU
			var vertical := g.rng.randf_range(-0.78,1.0)
			var rim := sqrt(maxf(0.0,1.0-vertical*vertical))
			var outward := Vector3(cos(azimuth)*rim,vertical,sin(azimuth)*rim)
			var offset := outward*Vector3(0.58,0.48,0.56)*g.rng.randf_range(0.70,1.04)
			var up := (Vector3.UP*0.85+outward*0.65).normalized()
			var axis := up.cross(Vector3.FORWARD).normalized()
			if axis.length_squared()<0.1:axis=Vector3.RIGHT
			axis=axis.rotated(up,g.rng.randf()*TAU)
			var lateral := axis.cross(up).normalized()
			var leaf_basis := Basis(axis,up,lateral)
			_oak_leaf(g,centers[cluster]+offset,leaf_basis,g.rng.randf_range(0.31,0.48),g.rng.randf_range(0.22,0.30),g.shade(tint,0.095))
	return g.finish()

static func _oak_leaf(g: Geometry,at: Vector3,basis: Basis,length: float,width: float,tint: Color) -> void:
	# Broad lobed leaves, closed around a raised midrib; no billboard or foliage ball.
	var outline: Array[Vector2]=[Vector2(-0.5,0),Vector2(-0.32,0.45),Vector2(-0.15,0.27),Vector2(0.06,0.62),Vector2(0.24,0.34),Vector2(0.50,0),Vector2(0.24,-0.34),Vector2(0.06,-0.62),Vector2(-0.15,-0.27),Vector2(-0.32,-0.45)]
	var upper := at+basis*Vector3(0,0.020,0)
	var lower := at+basis*Vector3(0,-0.006,0)
	for i in range(outline.size()):
		var next := (i+1)%outline.size()
		var a := at+basis*Vector3(outline[i].x*length,0,outline[i].y*width)
		var b := at+basis*Vector3(outline[next].x*length,0,outline[next].y*width)
		g.tri(upper,a,b,tint.lightened(0.045) if i<5 else tint)
		g.tri(lower,b,a,tint.darkened(0.17))

static func _cut_stump(variant: int) -> ArrayMesh:
	var g := Geometry.new(55531+variant*617)
	var height := 0.68+variant*0.11
	var wood := Color("b38a4e")
	var bark := Color("654a32")
	_tube(g,Vector3.UP*0.015,Vector3.UP*(height*0.52),0.45,0.39,bark,13)
	_tube(g,Vector3.UP*(height*0.52),Vector3.UP*height,0.39,0.34,bark,13)
	for i in range(8):
		var angle := i*TAU/8.0+0.09
		var radial := Vector3(cos(angle),0,sin(angle))
		_tube(g,Vector3.UP*(height*0.43),radial*g.rng.randf_range(0.65,0.90)+Vector3.UP*0.022,0.135,0.014,bark,6)
		_tube(g,radial*0.43+Vector3.UP*0.07,radial*0.34+Vector3.UP*(height*0.98),0.035,0.017,g.shade(Color("463726")),5)
	var center := Vector3(0.016,height+0.011,-0.018)
	var radius := 0.34
	for i in range(22):
		var a0 := TAU*i/22.0;var a1 := TAU*(i+1)/22.0
		var a := Vector3(cos(a0)*radius,height+0.008,sin(a0)*radius)
		var b := Vector3(cos(a1)*radius,height+0.008,sin(a1)*radius)
		g.tri(center,b,a,g.shade(wood,0.07))
	for ring in range(1,7):
		var r := ring*0.047
		for i in range(22):
			var a0 := TAU*i/22.0;var a1 := TAU*(i+1)/22.0
			var wobble0 := sin(a0*3.0+ring)*0.004
			var wobble1 := sin(a1*3.0+ring)*0.004
			var a := center+Vector3(cos(a0)*(r+wobble0),0.004,sin(a0)*(r+wobble0))
			var b := center+Vector3(cos(a1)*(r+wobble1),0.004,sin(a1)*(r+wobble1))
			var c := center+Vector3(cos(a1)*(r+wobble1+0.008),0.004,sin(a1)*(r+wobble1+0.008))
			var d := center+Vector3(cos(a0)*(r+wobble0+0.008),0.004,sin(a0)*(r+wobble0+0.008))
			g.quad(a,b,c,d,Color("896139"))
	for i in range(3):
		var angle := i*2.13+variant*0.5
		var radial := Vector3(cos(angle),0,sin(angle))
		var tangent := Vector3(-radial.z,0,radial.x)
		g.tri(center+radial*0.13+Vector3.UP*0.007,center+radial*0.33+tangent*0.006+Vector3.UP*0.007,center+radial*0.33-tangent*0.006+Vector3.UP*0.007,Color("59442d"))
	return g.finish()
