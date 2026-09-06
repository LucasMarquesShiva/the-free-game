extends RefCounted
## Acabamento 3D das fachadas, sem materiais ou nós adicionais por edifício.
const Base = preload("res://presentation/approved_primitives.gd")
const GOLD := Color("c59c47")
const DARK := Color("343329")
const WOOD := Color("76512e")
const TEAL := Color("155357")
const LEAF := Color("496327")

static func _ring(b, at: Vector3, radius: float, width: float, color: Color, key: String = "metal", rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	for i in range(32):
		var a := i*TAU/32.0
		var c := (i+1)*TAU/32.0
		var u := Vector3(cos(a),sin(a),0)
		var v := Vector3(cos(c),sin(c),0)
		b.quad(at+basis*u*(radius-width),at+basis*u*radius,at+basis*v*radius,at+basis*v*(radius-width),key,color)

static func _disc(b, at: Vector3, radius: float, color: Color, key: String = "plaster") -> void:
	for i in range(40):
		var a := i*TAU/40.0
		var c := (i+1)*TAU/40.0
		b.triangle(at,at+Vector3(cos(a),sin(a),0)*radius,at+Vector3(cos(c),sin(c),0)*radius,key,color,Vector3.BACK)

static func arch_glass(b, at: Vector3, width: float, height: float, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	var radius := width*0.5
	var shoulder := height-radius
	var outline: Array[Vector3] = [Vector3(-radius,0,0),Vector3(radius,0,0)]
	for i in range(17):
		var angle := i*PI/16.0
		outline.append(Vector3(cos(angle)*radius,shoulder+sin(angle)*radius,0))
	var center := Vector3(0,height*0.43,0)
	for i in range(outline.size()):
		b.triangle(at+basis*center,at+basis*outline[i],at+basis*outline[(i+1)%outline.size()],"glass",Color("26362d"),basis*Vector3.BACK)
	# Reflexos pequenos, abaixo dos caixilhos, mantêm o vidro escuro legível.
	for side in [-1.0,1.0]:
		var x: float = side*width*0.28
		var y := height*(0.57 if side<0 else 0.28)
		var tint := Color("657260") if side<0 else Color("77623a")
		b.quad(at+basis*Vector3(x-width*0.09,y,0.013),at+basis*Vector3(x+width*0.02,y+height*0.12,0.013),at+basis*Vector3(x+width*0.10,y+height*0.12,0.013),at+basis*Vector3(x-width*0.02,y,0.013),"glass",tint)

static func window_details(b, at: Vector3, width: float, height: float, rotation: float = 0.0, shutters: bool = false) -> void:
	var basis := Basis(Vector3.UP,rotation)
	for x in [-width*0.47,width*0.47]:
		for y in [-height*0.43,height*0.43]:
			Base._cylinder(b,at+basis*Vector3(x,y,0.169),0.017,0.014,GOLD.darkened(0.20),"metal",Vector3(PI*0.5,rotation,0))
	if shutters:
		for side in [-1.0,1.0]:
			for y in [-height*0.31,height*0.30]:
				Base._box(b,at+basis*Vector3(side*(width*0.5+0.14),y,0.083),Vector3(0.22,0.033,0.026),GOLD.darkened(0.25),"metal",Vector3(0,rotation,0))
	else:
		b.quad(at+basis*Vector3(-width*0.31,height*0.09,0.109),at+basis*Vector3(-width*0.15,height*0.31,0.109),at+basis*Vector3(-width*0.05,height*0.31,0.109),at+basis*Vector3(-width*0.21,height*0.09,0.109),"glass",Color("667160"))

static func door_details(b, at: Vector3, width: float, height: float) -> void:
	for side in [-1.0,1.0]:
		var center := at+Vector3(side*width*0.135,height*0.49,0.155)
		Base._box(b,center+Vector3(0,0.025,-0.018),Vector3(0.095,0.18,0.033),DARK,"metal",Vector3.ZERO,true)
		_ring(b,center-Vector3.UP*0.037,0.064,0.018,GOLD)
		Base._cylinder(b,center+Vector3(0,0.025,0.003),0.026,0.028,GOLD,"metal",Vector3(PI*0.5,0,0))
		Base._box(b,at+Vector3(side*width*0.25,0.17,0.090),Vector3(width*0.42,0.16,0.07),WOOD,"wood",Vector3.ZERO,true)
		for level in [0.45,1.25]:
			var base := at+Vector3(side*width*0.44,level,0.116)
			Base._beam(b,base,base+Vector3(-side*width*0.10,0.065,0.005),0.029,DARK,"metal")
			Base._beam(b,base,base+Vector3(-side*width*0.10,-0.065,0.005),0.029,DARK,"metal")

static func lantern(b, at: Vector3, scale_factor: float = 1.0, rotation: float = 0.0) -> void:
	var basis := Basis(Vector3.UP,rotation)
	Base._beam(b,at,at+basis*Vector3(0,0.04,0.28)*scale_factor,0.042*scale_factor,DARK,"metal")
	var center := at+basis*Vector3(0,-0.19,0.27)*scale_factor
	Base._box(b,center,Vector3(0.17,0.23,0.17)*scale_factor,Color("c89944"),"glass",Vector3(0,rotation,0),true)
	for x in [-0.10,0.10]:
		for z in [-0.10,0.10]:
			Base._beam(b,center+basis*Vector3(x,-0.14,z)*scale_factor,center+basis*Vector3(x,0.14,z)*scale_factor,0.027*scale_factor,DARK,"metal")
	for y in [-0.15,0.15]:
		Base._box(b,center+Vector3.UP*y*scale_factor,Vector3(0.23,0.045,0.23)*scale_factor,DARK,"metal",Vector3(0,rotation,0),true)
	Base._cylinder(b,center+Vector3.UP*0.20*scale_factor,0.17*scale_factor,0.10*scale_factor,GOLD.darkened(0.3),"metal",Vector3.ZERO,true)

static func clock(b, at: Vector3, radius: float) -> void:
	Base._cylinder(b,at,radius*1.08,0.15,WOOD.darkened(0.28),"wood",Vector3(PI*0.5,0,0))
	_ring(b,at+Vector3(0,0,0.094),radius*1.08,radius*0.11,GOLD.darkened(0.14))
	_ring(b,at+Vector3(0,0,0.112),radius*0.99,radius*0.044,GOLD.lightened(0.09))
	_disc(b,at+Vector3(0,0,0.114),radius*0.945,Color("cabe97"))
	_ring(b,at+Vector3(0,0,0.12),radius*0.90,radius*0.018,WOOD.darkened(0.25),"wood")
	var numerals := ["XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"]
	for i in range(12):
		var angle := i*TAU/12.0
		var center := at+Vector3(sin(angle),cos(angle),0)*radius*0.73+Vector3(0,0,0.13)
		var letters: String = numerals[i]
		var h := radius*0.18
		var w := radius*0.064
		for j in range(letters.length()):
			var p := center+Vector3((j-(letters.length()-1)*0.5)*w*1.37,0,0)
			if letters[j] == "I":
				Base._beam(b,p-Vector3.UP*h*0.5,p+Vector3.UP*h*0.5,0.014,DARK,"wood")
			elif letters[j] == "V":
				Base._beam(b,p+Vector3(-w*0.5,h*0.5,0),p-Vector3.UP*h*0.5,0.013,DARK,"wood")
				Base._beam(b,p-Vector3.UP*h*0.5,p+Vector3(w*0.5,h*0.5,0),0.013,DARK,"wood")
			else:
				Base._beam(b,p+Vector3(-w*0.5,h*0.5,0),p+Vector3(w*0.5,-h*0.5,0),0.013,DARK,"wood")
				Base._beam(b,p+Vector3(-w*0.5,-h*0.5,0),p+Vector3(w*0.5,h*0.5,0),0.013,DARK,"wood")
	var center := at+Vector3(0,0,0.157)
	for end in [Vector3(-radius*0.48,radius*0.54,0),Vector3(radius*0.08,radius*0.47,0)]:
		Base._beam(b,center,center+end,0.026,DARK,"metal")
		Base._ellipsoid(b,center+end*0.63,Vector3(0.032,0.048,0.01),DARK,"metal",true)
	_disc(b,center+Vector3(0,0,0.025),radius*0.065,GOLD,"metal")

static func _cloth_z(x: float, y: float, width: float, height: float) -> float:
	return 0.025*sin(x/width*TAU*1.15)+0.014*sin(y/height*PI*2.7+x/width*3.0)

static func banner(b, at: Vector3, width: float, height: float, crest: String = "lion") -> void:
	for col in range(10):
		var x0 := -width*0.5+col*width/10.0
		var x1 := -width*0.5+(col+1)*width/10.0
		var edge0 := -height+absf(x0)/width*height*0.22
		var edge1 := -height+absf(x1)/width*height*0.22
		for row in range(4):
			var y00 := edge0*row/4.0
			var y01 := edge0*(row+1)/4.0
			var y10 := edge1*row/4.0
			var y11 := edge1*(row+1)/4.0
			b.quad(at+Vector3(x0,y00,_cloth_z(x0,y00,width,height)),at+Vector3(x0,y01,_cloth_z(x0,y01,width,height)),at+Vector3(x1,y11,_cloth_z(x1,y11,width,height)),at+Vector3(x1,y10,_cloth_z(x1,y10,width,height)),"cloth",TEAL.lightened(0.024*float(col%3)))
		Base._beam(b,at+Vector3(x0,edge0,_cloth_z(x0,edge0,width,height)+0.015),at+Vector3(x1,edge1,_cloth_z(x1,edge1,width,height)+0.015),0.025,GOLD,"metal")
	for side in [-1.0,1.0]:
		for row in range(4):
			var x: float = side*width*0.5
			var y0 := -height*0.89*row/4.0
			var y1 := -height*0.89*(row+1)/4.0
			Base._beam(b,at+Vector3(x,y0,_cloth_z(x,y0,width,height)+0.015),at+Vector3(x,y1,_cloth_z(x,y1,width,height)+0.015),0.020,GOLD,"metal")
	Base._beam(b,at+Vector3(-width*0.59,0.045,0),at+Vector3(width*0.59,0.045,0),0.055,GOLD,"metal")
	for side in [-1.0,1.0]:
		Base._ellipsoid(b,at+Vector3(side*width*0.61,0.045,0),Vector3(0.055,0.037,0.037),GOLD,"metal",true)
	if crest == "tools":
		var center := at+Vector3(0,-height*0.47,0.09)
		for side in [-1.0,1.0]:
			Base._beam(b,center+Vector3(side*width*0.29,-height*0.23,0),center+Vector3(-side*width*0.29,height*0.23,0),0.043,WOOD.lightened(0.30))
			Base._box(b,center+Vector3(-side*width*0.27,height*0.21,0.023),Vector3(width*0.32,0.084,0.055),Color("b9b29a"),"metal",Vector3(0,0,side*PI*0.25))
	else:
		lion(b,at+Vector3(0,-height*0.50,0.085),minf(width*1.02,height*0.86))

static func lion(b, at: Vector3, scale_factor: float) -> void:
	# Crina, focinho, patas e cauda curvada compõem a silhueta heráldica.
	var shapes := [
		[Vector2(-0.12,0.21),Vector2(0.025,0.19),Vector2(0.14,0.015),Vector2(0.105,-0.14),Vector2(-0.025,-0.22),Vector2(-0.12,-0.09)],
		[Vector2(-0.21,0.40),Vector2(-0.10,0.38),Vector2(-0.04,0.31),Vector2(0.02,0.26),Vector2(-0.04,0.17),Vector2(-0.03,0.12),Vector2(-0.13,0.12),Vector2(-0.20,0.18),Vector2(-0.25,0.17),Vector2(-0.25,0.23),Vector2(-0.32,0.25),Vector2(-0.33,0.29),Vector2(-0.23,0.30)],
		[Vector2(-0.10,0.15),Vector2(-0.21,0.10),Vector2(-0.31,0.17),Vector2(-0.32,0.27),Vector2(-0.39,0.28),Vector2(-0.40,0.245),Vector2(-0.36,0.24),Vector2(-0.36,0.10),Vector2(-0.23,0.01),Vector2(-0.05,0.04)],
		[Vector2(0.025,0.05),Vector2(-0.16,-0.02),Vector2(-0.30,0.025),Vector2(-0.31,0.08),Vector2(-0.40,0.08),Vector2(-0.40,0.04),Vector2(-0.35,0.035),Vector2(-0.34,-0.06),Vector2(-0.16,-0.12),Vector2(0.06,-0.04)],
		[Vector2(0.015,-0.13),Vector2(-0.07,-0.25),Vector2(-0.21,-0.28),Vector2(-0.24,-0.35),Vector2(-0.17,-0.38),Vector2(-0.085,-0.38),Vector2(-0.085,-0.34),Vector2(-0.15,-0.33),Vector2(0.04,-0.28),Vector2(0.11,-0.16)],
		[Vector2(0.09,-0.095),Vector2(0.19,-0.20),Vector2(0.18,-0.31),Vector2(0.09,-0.36),Vector2(0.10,-0.40),Vector2(0.25,-0.40),Vector2(0.25,-0.36),Vector2(0.20,-0.35),Vector2(0.27,-0.23),Vector2(0.18,-0.06)],
		[Vector2(0.28,0.35),Vector2(0.33,0.43),Vector2(0.39,0.38),Vector2(0.37,0.29)]
	]
	for shape in shapes:
		var points := PackedVector2Array(shape)
		var indices := Geometry2D.triangulate_polygon(points)
		for i in range(0,indices.size(),3):
			var a: Vector2 = points[indices[i]]*scale_factor
			var c: Vector2 = points[indices[i+1]]*scale_factor
			var d: Vector2 = points[indices[i+2]]*scale_factor
			b.triangle(at+Vector3(a.x,a.y,0),at+Vector3(c.x,c.y,0),at+Vector3(d.x,d.y,0),"metal",GOLD,Vector3.BACK)
	var tail := [Vector2(0.12,-0.08),Vector2(0.25,0.01),Vector2(0.29,0.15),Vector2(0.23,0.23),Vector2(0.24,0.31),Vector2(0.31,0.36)]
	for i in range(tail.size()-1):
		Base._beam(b,at+Vector3(tail[i].x,tail[i].y,0)*scale_factor,at+Vector3(tail[i+1].x,tail[i+1].y,0)*scale_factor,0.033*scale_factor,GOLD,"metal")
	_disc(b,at+Vector3(-0.218,0.294,0.012)*scale_factor,0.010*scale_factor,DARK,"metal")

static func _leaf(b, at: Vector3, length: float, rotation: Vector3, color: Color) -> void:
	var basis := Basis.from_euler(rotation)
	var points := [Vector3(0,0,-0.55),Vector3(0.34,0,-0.21),Vector3(0.36,0,0.19),Vector3(0,0,0.55),Vector3(-0.36,0,0.19),Vector3(-0.34,0,-0.21)]
	var middle := at+basis*Vector3(0,0.085,0)*length
	for i in range(points.size()):
		var a: Vector3 = at+basis*points[i]*length
		var c: Vector3 = at+basis*points[(i+1)%points.size()]*length
		var normal := (a-middle).cross(c-middle).normalized()
		if normal.dot(basis*Vector3.UP)<0: normal=-normal
		b.triangle(middle,a,c,"foliage",color.lightened(0.035 if i<3 else 0.0),normal)

static func shrub(b, at: Vector3, radius: float, height: float, flowers: bool = false) -> void:
	for branch in range(9):
		var angle := branch*TAU/9.0+0.25
		var length: float = height*b.rng.randf_range(0.72,1.0)
		var end := at+Vector3(cos(angle)*radius*0.63,length,sin(angle)*radius*0.63)
		Base._beam(b,at,end,0.022,WOOD)
		for level in range(5):
			var t := (level+1)/5.0
			var center := at.lerp(end,t)
			for side in [-1.0,1.0]:
				var direction: float = angle+side*0.89
				var p := center+Vector3(cos(direction),0.01,sin(direction))*radius*0.32
				_leaf(b,p,radius*b.rng.randf_range(0.63,0.92),Vector3(b.rng.randf_range(-0.55,0.18),-direction,0),b.shade(LEAF,0.15))
		if flowers and branch%2 == 0:
			var center := end+Vector3.UP*0.025
			for petal in range(5):
				var p := petal*TAU/5.0
				Base._ellipsoid(b,center+Vector3(cos(p)*0.041,0,sin(p)*0.041),Vector3(0.041,0.022,0.034),Color("ddc356") if branch%3 else Color("e4dcc3"),"foliage",true)
			Base._ellipsoid(b,center+Vector3.UP*0.017,Vector3.ONE*0.027,Color("a67f29"),"foliage",true)

static func pot(b, at: Vector3, radius: float, height: float, flowering: bool = true) -> void:
	var profile := [Vector2(0.56,0),Vector2(0.76,0.12),Vector2(0.94,0.73),Vector2(1.0,0.86),Vector2(0.96,1.0)]
	for row in range(profile.size()-1):
		for side in range(20):
			var a := side*TAU/20.0
			var c := (side+1)*TAU/20.0
			var low: Vector2 = profile[row]
			var high: Vector2 = profile[row+1]
			b.quad(at+Vector3(cos(a)*low.x*radius,low.y*height,sin(a)*low.x*radius),at+Vector3(cos(c)*low.x*radius,low.y*height,sin(c)*low.x*radius),at+Vector3(cos(c)*high.x*radius,high.y*height,sin(c)*high.x*radius),at+Vector3(cos(a)*high.x*radius,high.y*height,sin(a)*high.x*radius),"plaster",Color("9c7040").lightened(0.025*(side%3)))
	Base._cylinder(b,at+Vector3.UP*height*0.94,radius*0.86,0.019,Color("403d28"),"plaster")
	shrub(b,at+Vector3.UP*height,radius*1.05,height*1.25,flowering)

static func small_conifer(b, at: Vector3, height: float = 1.5) -> void:
	Base._beam(b,at,at+Vector3.UP*height*0.94,0.055,WOOD)
	for layer in range(5):
		var y := height*(0.16+layer*0.17)
		var spread := height*(0.32-layer*0.049)
		for branch in range(7):
			var angle := branch*TAU/7.0+layer*0.67
			var direction := Vector3(cos(angle),0,sin(angle))
			var base := at+Vector3.UP*y
			var end := base+direction*spread-Vector3.UP*spread*0.28
			Base._beam(b,base,end,0.014,WOOD)
			for i in range(4):
				var center := base.lerp(end,(i+0.6)/4.0)
				for side in [-1.0,1.0]:
					_leaf(b,center,spread*(0.90-i*0.10),Vector3(-0.25,-angle+side*0.72,0),b.shade(LEAF.darkened(0.025),0.17))
	for branch in range(7):
		var angle := branch*TAU/7.0
		_leaf(b,at+Vector3.UP*height*0.89,height*0.22,Vector3(-0.62,angle,0),b.shade(LEAF,0.13))

static func moss_patch(b, at: Vector3, radius: float) -> void:
	for patch in range(9):
		var center := at+Vector3(b.rng.randf_range(-radius,radius),0.005+patch*0.0003,b.rng.randf_range(-radius,radius))
		var size: float = radius*b.rng.randf_range(0.10,0.24)
		var lengths: Array[float] = []
		for i in range(10): lengths.append(size*b.rng.randf_range(0.55,1.0))
		for i in range(10):
			var a := i*TAU/10.0
			var c := (i+1)*TAU/10.0
			b.triangle(center,center+Vector3(cos(a),0,sin(a))*lengths[i],center+Vector3(cos(c),0,sin(c))*lengths[(i+1)%10],"foliage",b.shade(Color("77804e"),0.065),Vector3.UP)
		if patch%3 == 0:
			for blade in range(3):
				var direction := blade*TAU/3.0+patch
				var across := Vector3(cos(direction),0,sin(direction))
				b.triangle(center-across*0.017,center+Vector3.UP*0.13+across*0.049,center+across*0.017,"foliage",Color("707d42"))
