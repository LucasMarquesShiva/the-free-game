extends RefCounted
## Curved, reusable surfaces sculpted from the eight approved civilian sheets.
static var _sphere: SphereMesh
static var _detail:=0
static var _spheres: Dictionary={}
static var _builder_muzzle_surface:Array=[]
static var _builder_mouth_surface:Array=[]
static var _builder_eye_surface:Array=[]
static var _rest_eye_surface:Array=[]

static func set_detail(tier: int) -> void:
	_detail=clampi(tier,0,2)

static func _n(high: int,medium: int,distant: int) -> int:return [high,medium,distant][_detail]
const REFERENCES := {"resident":"civ_01_morador","servant":"civ_02_servente","builder":"civ_04_construtor","lumberjack":"civ_05_lenhador","stonecutter":"civ_07_canteiro","farmer":"civ_11_horticultor","vintner":"civ_19_vinhateiro","instructor":"civ_25_instrutor"}

static func female(role: String) -> bool:return role in ["farmer","lumberjack","stonecutter"]
static func skin(role: String) -> String:return "skin_brown" if role=="stonecutter" else ("skin_fair" if female(role) else "skin")
static func hair(role: String) -> String:return "hair_red" if role in ["farmer","lumberjack"] else ("hair_dark" if role in ["instructor","stonecutter","vintner"] else "hair")

static func _cat(a: Vector4,b: Vector4,c: Vector4,d: Vector4,t: float) -> Vector4:
	return 0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t)

## Smooth longitudinal profiles, with a proper UV seam and real radial folds.
static func _loft(profile: Array, folds: float=0.0, opening: Variant=0.0) -> ArrayMesh:
	var rings: Array[Vector4]=[];var gaps: Array[float]=[];var steps:=_n(3,2,1)
	for n in range(profile.size()-1):
		for sub in range(steps):
			var t:=float(sub)/float(steps)
			rings.append(_cat(profile[maxi(0,n-1)],profile[n],profile[n+1],profile[mini(n+2,profile.size()-1)],t))
			gaps.append(lerpf(opening[n],opening[n+1],t) if opening is Array else float(opening))
	rings.append(profile[-1]);gaps.append(float(opening[-1]) if opening is Array else float(opening))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var sides:=_n(32,14,8)
	for row in range(rings.size()-1):
		for col in range(sides):
			var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var r: Vector4=rings[pair.x];var u:=float(pair.y)/sides;var v:=float(pair.x)/float(rings.size()-1)
				var a: float=-PI*0.5+gaps[pair.x]+u*(TAU-2.0*gaps[pair.x])
				var ripple: float=folds*(sin(a*9.0+v*3.0)+0.35*sin(a*15.0-v*5.0))*sin(v*PI)
				ripple+=folds*0.7*sin(a*3.0+v*18.0)*exp(-pow((v-0.24)/0.20,2.0))
				pts.append(Vector3(cos(a)*maxf(0.001,r.y+ripple),r.x,sin(a)*maxf(0.001,r.z+ripple)+r.w));uv.append(Vector2(u,v));var shade:=1.0-minf(0.20,maxf(0,-ripple)*18.0);tints.append(Color(shade,shade,shade))
			_quad(st,pts,uv,false,tints)
	if not opening is Array and is_zero_approx(float(opening)):
		for index: int in [0,rings.size()-1]:
			var r: Vector4=rings[index]
			for col in range(sides):
				var a:=float(col)*TAU/sides-PI*0.5;var b:=float(col+1)*TAU/sides-PI*0.5
				var pts: Array[Vector3]=[Vector3(0,r.x,r.w),Vector3(cos(a)*r.y,r.x,sin(a)*r.z+r.w),Vector3(cos(b)*r.y,r.x,sin(b)*r.z+r.w)]
				for i: int in ([0,1,2] if index==0 else [0,2,1]):st.set_smooth_group(-1);st.set_uv(Vector2(pts[i].x,pts[i].z));st.add_vertex(pts[i])
	return _finish(st)

static func _quad(st: SurfaceTool,p: Array[Vector3],uv: Array[Vector2],reverse: bool=false,tints: Array=[]) -> void:
	for i: int in ([0,1,2,0,2,3] if reverse else [0,2,1,0,3,2]):
		st.set_smooth_group(0);st.set_uv(uv[i]);st.set_color(tints[i] if not tints.is_empty() else Color.WHITE);st.add_vertex(p[i])

static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals();st.index();st.generate_tangents();return st.commit()

## Broad garment values follow seams/weight, independently of scene lighting.
## No extra texture or surface is introduced; existing UVs/tangents are preserved.
static func _garment_values(mesh:ArrayMesh,kind:String)->ArrayMesh:
	var out:=ArrayMesh.new();var bounds:=mesh.get_aabb()
	for surface in range(mesh.get_surface_count()):
		var arrays:Array=mesh.surface_get_arrays(surface).duplicate(true)
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		if colors.size()!=points.size():colors.resize(points.size());colors.fill(Color.WHITE)
		for i in range(points.size()):
			var q:Vector3=points[i];var tint:=Color.WHITE;var value:=1.0
			if kind=="coat":
				var belt_shadow:float=0.16*exp(-pow((q.y-0.005)/0.057,2.0))
				var side_shadow:float=0.14*pow(clampf(absf(q.x)/0.26,0,1),2.0)*exp(-pow((q.y-0.29)/0.25,2.0))
				var chest:float=0.035*exp(-pow(q.x/0.14,2.0)-pow((q.y-0.32)/0.15,2.0))
				value=0.94-belt_shadow-side_shadow+chest;tint=Color(0.94,0.98,1.0)
			elif kind=="linen":
				var v:float=(q.y-bounds.position.y)/maxf(bounds.size.y,0.001)
				value=0.94-0.13*exp(-pow((v-0.24)/0.16,2.0));tint=Color(0.88,0.84,0.76)
			elif kind=="leather":
				var v:float=(q.y-bounds.position.y)/maxf(bounds.size.y,0.001)
				value=0.90-0.13*exp(-pow((v-0.94)/0.09,2.0))+0.045*exp(-pow(q.x/0.11,2.0)-pow((v-0.35)/0.22,2.0));tint=Color(0.97,0.93,0.88)
			elif kind=="wrap":value=0.90;tint=Color(0.92,0.88,0.80)
			colors[i]*=Color(tint.r*value,tint.g*value,tint.b*value,1.0)
		arrays[Mesh.ARRAY_COLOR]=colors;out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## A tapered swept ribbon/tube follows a Catmull-Rom path, for locks and seams.
static func curve(p: Array,path: Array,radius: float,material: String,flatten: float=1.0,taper: bool=false,close_ends:bool=false) -> void:
	var samples: Array[Vector3]=[];var steps:=_n(4,2,1);var sides:=_n(8,5,4)
	for n in range(path.size()-1):
		for sub in range(steps):samples.append((path[n] as Vector3).cubic_interpolate(path[n+1],path[maxi(0,n-1)],path[mini(n+2,path.size()-1)],float(sub)/float(steps)))
	samples.append(path[-1])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var frames: Array[Basis]=[]
	for i in range(samples.size()):
		var tangent: Vector3=(samples[mini(i+1,samples.size()-1)]-samples[maxi(0,i-1)]).normalized()
		var side:=tangent.cross(Vector3.FORWARD).normalized()
		if side.length_squared()<0.1:side=tangent.cross(Vector3.RIGHT).normalized()
		frames.append(Basis(side,tangent,side.cross(tangent).normalized()))
	for row in range(samples.size()-1):
		for col in range(sides):
			var pts: Array[Vector3]=[];var uv: Array[Vector2]=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var v:=float(pair.x)/float(samples.size()-1);var u:=float(pair.y)/float(sides);var a:=u*TAU
				var r:=radius*(pow(sin(PI*clampf(v,0.025,0.99)),0.4) if taper else 1.0)
				pts.append(samples[pair.x]+frames[pair.x]*Vector3(cos(a)*r,0,sin(a)*r*flatten));uv.append(Vector2(u,v))
			_quad(st,pts,uv)
	# The builder's moustache needs solid tips; other existing curves keep
	# their geometry. Caps reuse the exact end rings, radii and material.
	if close_ends:
		for index:int in [0,samples.size()-1]:
			var v:float=float(index)/float(samples.size()-1)
			var r:float=radius*(pow(sin(PI*clampf(v,.025,.99)),.4) if taper else 1.0)
			for col in range(sides):
				var a:float=float(col)/sides*TAU;var b:float=float(col+1)/sides*TAU
				var points:Array[Vector3]=[samples[index],samples[index]+frames[index]*Vector3(cos(a)*r,0,sin(a)*r*flatten),samples[index]+frames[index]*Vector3(cos(b)*r,0,sin(b)*r*flatten)]
				for i:int in ([0,2,1] if index==0 else [0,1,2]):
					st.set_smooth_group(-1);st.set_color(Color.WHITE);st.set_uv(Vector2(.5,v));st.add_vertex(points[i])
	_add(p,_finish(st),Vector3.ZERO,material)

## Draped panel wraps around the hips, thickened so rear/profile stay coherent.
static func drape(p: Array,top: float,bottom: float,width: float,depth: float,material: String,pointed: bool=false,center: float=0.0,belt_inset: float=0.0,weight:float=0.0) -> void:
	var curvature: float=minf(0.058,width*width*1.6) if top>0.20 else 0.058
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var rows:=_n(14,8,4);var columns:=_n(16,10,6)
	for back in [false,true]:
		for row in range(rows):
			for col in range(columns):
				var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
				for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
					var u:=float(pair.y)/float(columns);var v:=float(pair.x)/float(rows);var x: float=(u*2-1)*width*(0.90+v*0.10)
					var hem: float=bottom+(absf(u*2-1)*0.065 if pointed else sin(u*8+0.4)*0.013)
					var z: float=depth+pow(absf(u*2-1),2)*curvature-sin(v*PI)*0.035+sin(u*16+v*4.0)*0.014*sin(v*PI)+sin(u*7.0-v*8.0)*0.009*sin(v*PI)
					z+=belt_inset*(1.0-smoothstep(0.0,0.28,v))
					# Leather gathers at two belt attachment points and hangs outward.
					var gather:float=(exp(-pow((u-0.16-v*0.12)/0.044,2.0))+exp(-pow((u-0.85+v*0.10)/0.052,2.0)))*0.019*(1.0-v)*weight
					z+=gather-0.012*sin(v*PI)*weight
					pts.append(Vector3(center+x,lerpf(top,hem,v),z+(0.004 if back else 0.0)));uv.append(Vector2(u,v));var shade:=0.94+0.05*sin(u*16+v*4.0)*sin(v*PI)-0.12*exp(-v*18.0);tints.append(Color(shade,shade,shade))
				_quad(st,pts,uv,not back,tints)
	_add(p,_finish(st),Vector3.ZERO,material)
	# The sewn hem follows the real curved edge, instead of floating before it.
	var hemline: Array=[];var hem_steps:=_n(16,8,4)
	for i in range(hem_steps+1):
		var u:=float(i)/float(hem_steps);var x: float=(u*2-1)*width;var y: float=bottom+(absf(u*2-1)*0.065 if pointed else sin(u*8+0.4)*0.013)
		hemline.append(Vector3(center+x,y+0.008,depth+pow(absf(u*2-1),2)*curvature-0.004))
	curve(p,hemline,0.003,"stitch",1.0)
	for side: int in [-1,1]:
		var edge: Array=[];var edge_steps:=_n(8,4,2)
		for i in range(edge_steps+1):
			var v:=float(i)/float(edge_steps);edge.append(Vector3(center+float(side)*width*(0.9+v*0.1),lerpf(top,bottom+(0.065 if pointed else 0.0),v),depth+curvature-0.004-sin(v*PI)*0.035+belt_inset*(1.0-smoothstep(0.0,0.28,v))))
		curve(p,edge,0.0025,"stitch")

static func _add(parts: Array, mesh: Mesh, at: Vector3, material: String, scale: Vector3=Vector3.ONE, rotation: Vector3=Vector3.ZERO) -> void:
	parts.append({"mesh":mesh,"at":Transform3D(Basis.from_euler(rotation).scaled(scale),at),"material":material})

static func _oval(parts: Array, at: Vector3, size: Vector3, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	if not _spheres.has(_detail):
		var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=_n(20,12,6);sphere.rings=_n(12,6,3);_spheres[_detail]=sphere
	_sphere=_spheres[_detail]
	_add(parts,_sphere,at,material,size,rotation)

static func _box(parts: Array, at: Vector3, size: Vector3, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	var mesh:=BoxMesh.new();mesh.size=size;_add(parts,mesh,at,material,Vector3.ONE,rotation)

static func _cylinder(parts: Array, at: Vector3, radius: float, height: float, material: String, rotation: Vector3=Vector3.ZERO) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=_n(20,12,8)
	_add(parts,mesh,at,material,Vector3.ONE,rotation)

static func _line(parts: Array, a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=_n(8,6,4)
	var up: Vector3=(b-a).normalized()
	var side:=up.cross(Vector3.FORWARD).normalized()
	if side.length_squared()<0.1:side=Vector3.RIGHT
	var basis:=Basis(side,up,side.cross(up).normalized())
	parts.append({"mesh":mesh,"at":Transform3D(basis,(a+b)*0.5),"material":material})

static func _patch(p: Array,corners: Array,material: String,bulge: float=0.006) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var n:=_n(6,3,2)
	for back in [false,true]:
		for row in range(n):
			for col in range(n):
				var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
				for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
					var u:=float(pair.y)/n;var v:=float(pair.x)/n
					var top: Vector3=corners[0].lerp(corners[1],u);var bottom: Vector3=corners[3].lerp(corners[2],u)
					var point:=top.lerp(bottom,v);point.z-=sin(u*PI)*sin(v*PI)*bulge;point.z+=0.003 if back else 0.0
					pts.append(point);uv.append(Vector2(u,v));var shade:=0.80+0.20*sin(u*PI*0.85);tints.append(Color(shade,shade,shade))
				_quad(st,pts,uv,not back,tints)
	_add(p,_finish(st),Vector3.ZERO,material)

static func _profile_point(profile: Array,y: float,a: float) -> Vector3:
	var r: Vector4=profile[-1]
	for i in range(profile.size()-1):
		if y>=profile[i].x and y<=profile[i+1].x:
			r=_cat(profile[maxi(0,i-1)],profile[i],profile[i+1],profile[mini(profile.size()-1,i+2)],inverse_lerp(profile[i].x,profile[i+1].x,y));break
	return Vector3(cos(a)*r.y,y,sin(a)*r.z+r.w)

## Exact projected triangles of a garment, prepared once when its shared
## model is built. A folded loft cannot be represented by its smooth profile.
static func _garment_front(mesh:Mesh,at:Transform3D,min_y:float=.39)->Array:
	var result:Array=[]
	var data:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=data[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a:Vector3=at*vertices[indices[i]];var b:Vector3=at*vertices[indices[i+1]];var c:Vector3=at*vertices[indices[i+2]]
		if maxf(a.y,maxf(b.y,c.y))<min_y:continue
		var den:float=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(den)<.000000001:continue
		var u:=Vector3(b.y-c.y,c.x-b.x,b.x*c.y-c.x*b.y)/den
		var v:=Vector3(c.y-a.y,a.x-c.x,c.x*a.y-a.x*c.y)/den
		var z:Vector3=u*(a.z-c.z)+v*(b.z-c.z)+Vector3(0,0,c.z)
		result.append([Vector4(minf(a.x,minf(b.x,c.x)),maxf(a.x,maxf(b.x,c.x)),minf(a.y,minf(b.y,c.y)),maxf(a.y,maxf(b.y,c.y))),u,v,z])
	return result

static func _front_at(triangles:Array,x:float,y:float)->float:
	var nearest:float=INF;var p:=Vector3(x,y,1)
	for record:Array in triangles:
		var bounds:Vector4=record[0]
		if x<bounds.x-.000001 or x>bounds.y+.000001 or y<bounds.z-.000001 or y>bounds.w+.000001:continue
		var u:float=(record[1] as Vector3).dot(p);var v:float=(record[2] as Vector3).dot(p)
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001:nearest=minf(nearest,(record[3] as Vector3).dot(p))
	return nearest

static func _mesh_vertices(mesh:Mesh,points:PackedVector3Array)->ArrayMesh:
	var data:Array=mesh.surface_get_arrays(0);var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index:int in data[Mesh.ARRAY_INDEX]:
		st.set_smooth_group(0);st.set_uv(data[Mesh.ARRAY_TEX_UV][index]);st.set_color(data[Mesh.ARRAY_COLOR][index]);st.add_vertex(points[index])
	return _finish(st)

static func _seat_lining(mesh:Mesh,at:Transform3D,outer:Array)->ArrayMesh:
	var points:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate();var inverse:=at.affine_inverse()
	for i in range(points.size()):
		var point:Vector3=at*points[i]
		if point.y<.40 or point.y>.57:continue
		var radial:=Vector3(point.x,0,point.z);var length:float=radial.length()
		var probe:Vector3=point;probe.y=minf(probe.y,.552)
		var surface:float=_cap_radius(outer,probe,0.0,.40)
		if surface>.02 and length>surface-.006:
			radial=radial.normalized()*(surface-.006);point.x=radial.x;point.z=radial.z;points[i]=inverse*point
	return _mesh_vertices(mesh,points)

static func _collar_front(profile:Array,x:float,y:float,scales:Vector2,triangles:Array=[])->float:
	var radius:float=_profile_point(profile,y,0.0).x*scales.x
	var angle:float=-acos(clampf(x/maxf(radius,.001),-.995,.995))
	return minf(_profile_point(profile,y,angle).z*scales.y-.010,_front_at(triangles,x,y)-.008)

static func _fitted_collar(p:Array,corners:Array,profile:Array,scales:Vector2,triangles:Array=[])->void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var n:=_n(6,3,2)
	for back in [false,true]:
		for row in range(n):
			for col in range(n):
				var points:Array[Vector3]=[];var uv:Array[Vector2]=[];var tints:Array=[]
				for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
					var u:float=float(pair.y)/n;var v:float=float(pair.x)/n
					var point:Vector3=(corners[0] as Vector3).lerp(corners[1],u).lerp((corners[3] as Vector3).lerp(corners[2],u),v)
					point.z=minf(point.z,_collar_front(profile,point.x,point.y,scales,triangles))-sin(u*PI)*sin(v*PI)*.005+(0.003 if back else 0.0)
					points.append(point);uv.append(Vector2(u,v));var shade:float=.80+.20*sin(u*PI*.85);tints.append(Color(shade,shade,shade))
				_quad(st,points,uv,(not back)!=(corners[1].x<corners[0].x),tints)
	_add(p,_finish(st),Vector3.ZERO,"linen_light")

static func body(role: String) -> Array:
	var p: Array=[]
	var focus:bool=role in ["servant","builder","instructor"]
	var broad: float=1.06 if role in ["builder","stonecutter"] else (0.94 if role in ["farmer","lumberjack"] else 1.0)
	var feminine:=female(role)
	_add(p,_loft([Vector4(0.39,0.178,0.125,0),Vector4(0.47,0.150,0.105,0),Vector4(0.535,0.064,0.058,0),Vector4(0.57,0.059,0.052,0),Vector4(0.64,0.057,0.052,0)]),Vector3.ZERO,skin(role))
	var shirt: Array=[Vector4(-0.08,0.214,0.138,0),Vector4(0.02,0.19,0.130,0),Vector4(0.16,0.171 if feminine else 0.18,0.127,0),Vector4(0.30,0.205,0.15,-0.012 if feminine else -0.005),Vector4(0.42,0.233,0.147,0),Vector4(0.49,0.215,0.127,0.008),Vector4(0.54,0.141,0.088,0.0),Vector4(0.57,0.068,0.054,0)]
	if focus:
		for i in range(shirt.size()):
			var r:Vector4=shirt[i]
			if r.x>=0.25 and r.x<0.50:r.y*=1.025;r.z*=1.14;r.w-=0.003
			shirt[i]=r
	if role=="instructor":
		shirt[6]=Vector4(0.54,0.078,0.064,0.0)
		shirt[7]=Vector4(0.57,0.060,0.052,0.0)
	var collar_profile:Array=shirt
	var collar_scales:=Vector2(broad*.955,.95)
	var collar_triangles:Array=[]
	var linen_body:=role in ["resident","servant","vintner","farmer","instructor"]
	var shirt_mesh:=_loft(shirt,0.008 if focus else 0.006,[0.0,0.0,0.0,0.0,0.035,0.27,0.53,0.83])
	if focus:shirt_mesh=_garment_values(shirt_mesh,"linen" if linen_body else "coat")
	_add(p,shirt_mesh,Vector3.ZERO,"linen" if linen_body else "cloth",Vector3(broad*0.91 if role=="instructor" else broad*0.955,1,0.91 if role=="instructor" else 0.95))
	if role=="builder":collar_triangles=_garment_front(p[1].mesh,p[1].at)
	if role in ["resident","servant","vintner","instructor"]:
		var bottom: float=-0.355 if role=="instructor" else -0.19
		var shell: Array=[Vector4(bottom,0.252 if role=="instructor" else 0.241,0.174,0),Vector4(-0.14,0.252,0.174,0),Vector4(0.00,0.206,0.145,0),Vector4(0.13,0.188,0.137,0),Vector4(0.31,0.219,0.158,0),Vector4(0.43,0.239,0.156,0.006),Vector4(0.505,0.205,0.127,0.008),Vector4(0.554,0.09,0.072,0)]
		if focus:
			for i in range(shell.size()):
				var r:Vector4=shell[i]
				if r.x>=0.25 and r.x<0.50:r.y*=1.025;r.z*=1.13;r.w-=0.003
				shell[i]=r
		var gaps: Array=[0.29,0.16,0.12,0.035,0.035,0.05,0.10,0.16] if role=="instructor" else [0.20,0.10,0.015,0.015,0.025,0.16,0.50,0.75]
		if role=="instructor":
			for i in range(shell.size()):
				var ring: Vector4=shell[i];ring.z+=0.033*clampf((0.13-ring.x)/0.22,0.0,1.0);shell[i]=ring
		if role=="servant":collar_profile=shell;collar_scales=Vector2(broad,1.0)
		var coat_mesh:=_loft(shell,0.010 if focus else 0.007,gaps)
		if focus:coat_mesh=_garment_values(coat_mesh,"coat")
		_add(p,coat_mesh,Vector3.ZERO,"cloth",Vector3(broad,1,1))
		if role=="servant":
			collar_triangles=_garment_front(p[-1].mesh,p[-1].at)
			p[1].mesh=_seat_lining(p[1].mesh,p[1].at,_cap_triangles(p[-1].mesh))
		for side: int in [-1,1]:
			var edge: Array=[]
			for i in range(shell.size()):
				var r: Vector4=shell[i];var a: float=gaps[i]
				edge.append(Vector3(float(side)*sin(a)*r.y*broad,r.x,-cos(a)*r.z+r.w-0.002))
			curve(p,edge,0.005,"gold_thread")
			# Sculpted pointed collar folds, curved away from the breast.
			curve(p,[Vector3(float(side)*0.055,0.556,-0.057),Vector3(float(side)*0.089,0.52,-0.09),Vector3(float(side)*0.092,0.471,-0.137)],0.012,"cloth_dark",0.22,true)
			for front_side in [true,false]:
				var binding: Array=[];var stitch_path: Array=[]
				for y: float in [0.526,0.486,0.418,0.340,0.285]:
					var a: float=-0.73 if front_side else 0.73
					var point:=_profile_point(shell,y,a);point.x*=float(side)*broad;point+=Vector3(float(side)*0.005,0,-0.004 if front_side else 0.004)
					binding.append(point);stitch_path.append(point+Vector3(float(side)*-0.003,0,-0.004 if front_side else 0.004))
				curve(p,binding,0.007,"leather_dark" if front_side else "cloth_dark",0.45)
				if front_side:curve(p,stitch_path,0.002,"stitch")
			if role=="vintner":
				for y: float in [0.19,0.25,0.31]:_oval(p,Vector3(float(side)*0.067,y,-0.153),Vector3(0.008,0.008,0.003),"gold")
	else:
		var hem: float=-0.39 if role=="farmer" else -0.20
		_add(p,_loft([Vector4(hem,0.283 if role=="farmer" else 0.252,0.188,0),Vector4(-0.17,0.259,0.174,0),Vector4(0.04,0.201,0.146,0)] ,0.012,0.025),Vector3.ZERO,"cloth")
		_add(p,_loft([Vector4(hem,0.285 if role=="farmer" else 0.254,0.190,0),Vector4(hem+0.018,0.281 if role=="farmer" else 0.251,0.187,0)],0.002,0.025),Vector3.ZERO,"gold_thread")
	if role!="instructor":
		# Four-sided curved collar leaves, with a shaded seam at each folded edge.
		for side: int in [-1,1]:
			var q: float=float(side)
			var collar:Array=[Vector3(q*.033,.563,-.048),Vector3(q*.119,.525,-.052),Vector3(q*.098,.459,-.141),Vector3(q*.028,.514,-.116)]
			var collar_seam:Array=[Vector3(q*.034,.560,-.049),Vector3(q*.06,.536,-.088),Vector3(q*.030,.515,-.116)]
			if role in ["servant","builder"]:
				_fitted_collar(p,collar,collar_profile,collar_scales,collar_triangles)
				for i in range(collar_seam.size()):collar_seam[i].z=minf(collar_seam[i].z,_collar_front(collar_profile,collar_seam[i].x,collar_seam[i].y,collar_scales,collar_triangles)-.002)
			else:_patch(p,collar,"linen_light",.008)
			curve(p,collar_seam,.0035,"linen_shadow",.45)
		for y: float in [0.420,0.443,0.465]:
			for side: int in [-1,1]:
				curve(p,[Vector3(float(side)*0.029,y,-0.146),Vector3(0,y+0.010,-0.155),Vector3(float(-side)*0.030,y+0.021,-0.137)],0.0025,"leather_dark")
	else:
		# The approved instructor wears a standing collar and brass clasps,
		# not the wide open peasant collar shared by other occupations.
		_add(p,_garment_values(_loft([Vector4(0.516,0.087,0.074,0),Vector4(0.547,0.083,0.070,0),Vector4(0.579,0.070,0.064,0)],0.001,0.16),"coat"),Vector3.ZERO,"cloth")
		_add(p,_garment_values(_loft([Vector4(0.558,0.072,0.064,0),Vector4(0.587,0.066,0.059,0)],0.001,0.20),"linen"),Vector3.ZERO,"linen_light")
		for side:int in [-1,1]:
			var q:=float(side)
			curve(p,[Vector3(q*0.012,0.581,-0.063),Vector3(q*0.016,0.548,-0.075),Vector3(q*0.021,0.511,-0.093)],0.0035,"gold_thread")
		for y:float in [0.435,0.365]:
			var z:float=-0.174 if y>0.40 else -0.180
			_line(p,Vector3(-0.025,y,z),Vector3(0.025,y,z),0.0045,"gold")
			for q:float in [-1.0,1.0]:_box(p,Vector3(q*0.025,y,z),Vector3(0.012,0.016,0.006),"gold")
	_add(p,_loft([Vector4(0.022,0.211*broad,0.151,0),Vector4(0.078,0.207*broad,0.149,0)]),Vector3.ZERO,"leather_dark")
	_box(p,Vector3(0,0.050,-0.159),Vector3(0.084,0.069,0.014),"metal" if role=="servant" else "gold")
	_box(p,Vector3(0,0.050,-0.169),Vector3(0.061,0.046,0.004),"leather_dark")
	_line(p,Vector3(-0.027,0.05,-0.174),Vector3(0.015,0.05,-0.174),0.004,"metal" if role=="servant" else "gold")
	# Soft leather satchel: rounded gusset, overlapping curved flap and seam.
	_add(p,_loft([Vector4(-0.16,0.041,0.025,0),Vector4(-0.14,0.064,0.041,0),Vector4(-0.04,0.069,0.038,0),Vector4(0.028,0.054,0.03,0)]),Vector3(0.265,-0.015,-0.078),"leather")
	curve(p,[Vector3(0.216,0.005,-0.118),Vector3(0.263,-0.045,-0.125),Vector3(0.311,0.005,-0.118)],0.008,"leather_light",0.45)
	_oval(p,Vector3(0.263,-0.064,-0.123),Vector3(0.01,0.009,0.005),"gold")
	if role=="servant":
		var apron_start:int=p.size()
		drape(p,0.025,-0.33,0.194,-0.185,"leather",false,0.0,0.0,1.0)
		for i in range(apron_start,p.size()):
			if p[i].mesh is ArrayMesh:p[i].mesh=_garment_values(p[i].mesh,"leather")
		for side: int in [-1,1]:curve(p,[Vector3(0.0,0.03,0.151),Vector3(float(side)*0.04,-0.02,0.163),Vector3(float(side)*0.032,-0.15,0.18)],0.008,"leather",0.4)
	elif role=="builder":
		drape(p,0.022,-0.295,0.098,-0.165,"cloth",true)
		_emblem(p,Vector3(0,-0.092,-0.207),"lion")
		_add(p,_loft([Vector4(0.265,0.015,0.015,0.169),Vector4(0.30,0.076,0.039,0.156),Vector4(0.375,0.14,0.058,0.120),Vector4(0.47,0.17,0.055,0.064),Vector4(0.53,0.093,0.025,0.051)],0.008),Vector3.ZERO,"cloth_dark")
		curve(p,[Vector3(-0.17,0.465,0.08),Vector3(-0.10,0.33,0.184),Vector3(0,0.271,0.184),Vector3(0.10,0.33,0.184),Vector3(0.17,0.465,0.08)],0.006,"gold_thread")
		for x: float in [0.205,0.247]:_cylinder(p,Vector3(x,0.095,-0.028),0.012,0.17,"wood",Vector3(0,0,-0.16))
		_box(p,Vector3(0.223,0.178,-0.025),Vector3(0.07,0.024,0.03),"metal")
	elif role=="instructor":
		drape(p,-0.08,-0.305,0.073,-0.175,"cloth",true,0.135)
		_emblem(p,Vector3(0.135,-0.195,-0.215),"lion")
		_cylinder(p,Vector3(0.17,-0.095,0.065),0.027,0.235,"linen_light",Vector3(0,0,-0.25))
		_cylinder(p,Vector3(0.17,-0.095,0.065),0.028,0.018,"leather",Vector3(0,0,-0.25))
	elif role=="stonecutter":
		drape(p,0.045,-0.335,0.179,-0.210,"leather",false,0.0,0.044)
		drape(p,0.406,0.04,0.120,-0.164,"leather")
		for side: int in [-1,1]:
			curve(p,[Vector3(float(side)*0.092,0.40,-0.16),Vector3(float(side)*0.135,0.53,-0.049),Vector3(float(side)*0.126,0.46,0.121),Vector3(float(-side)*0.17,0.08,0.14)],0.018,"leather",0.28)
			_oval(p,Vector3(float(side)*0.089,0.379,-0.18),Vector3(0.008,0.008,0.004),"gold")
		for x: float in [0.191,0.221,0.25]:_cylinder(p,Vector3(x,0.1,-0.038),0.007,0.20,"metal",Vector3(0,0,-0.12))
	elif role=="farmer":
		drape(p,0.394,0.045,0.105,-0.161,"cloth_dark")
		_emblem(p,Vector3(0,0.263,-0.204),"plant")
		for side: int in [-1,1]:curve(p,[Vector3(float(side)*0.084,0.397,-0.158),Vector3(float(side)*0.10,0.54,-0.073),Vector3(float(side)*0.1,0.39,0.137),Vector3(float(side)*0.17,0.09,0.14)],0.016,"cloth",0.28)
		_add(p,_loft([Vector4(-0.422,0.276,0.181,0),Vector4(-0.386,0.272,0.177,0)],0.003,0.025),Vector3.ZERO,"linen_light")
	elif role=="vintner":
		_add(p,_loft([Vector4(0.51,0.082,0.072,0),Vector4(0.557,0.077,0.064,0),Vector4(0.59,0.065,0.057,0)],0.002),Vector3.ZERO,"scarf")
		curve(p,[Vector3(-0.036,0.538,-0.077),Vector3(-0.015,0.46,-0.151),Vector3(0.039,0.41,-0.166)],0.025,"scarf",0.3,true)
		_emblem(p,Vector3(0,0.27,0.165),"grapes",true)
	return p

static func _emblem(p: Array,at: Vector3,kind: String,back: bool=false) -> void:
	var zsign: float=-1.0 if back else 1.0
	if _detail==2:
		_oval(p,at,Vector3(0.025,0.031,0.003),"gold_thread");return
	if kind=="grapes":
		for i in range(6):_oval(p,at+Vector3(float(i%3-1)*0.016,-float(i/3)*0.018,0),Vector3(0.011,0.012,0.003),"gold_thread")
		curve(p,[at+Vector3(-0.025,0.026,0),at+Vector3(0,0.035,0),at+Vector3(0.02,0.026,0)],0.004,"gold_thread")
	elif kind=="plant":
		curve(p,[at+Vector3(0,-0.04,0),at,at+Vector3(0,0.045,0)],0.003,"gold_thread")
		for side: int in [-1,1]:
			for y: float in [-0.022,0.0,0.02]:curve(p,[at+Vector3(0,y,0),at+Vector3(float(side)*0.023,y+0.02,0),at+Vector3(float(side)*0.018,y+0.03,0)],0.004,"gold_thread",0.35,true)
	else:
		_oval(p,at,Vector3(0.016,0.032,0.003),"gold_thread",Vector3(0,0,-0.25))
		_oval(p,at+Vector3(0.015,0.035,-0.001*zsign),Vector3(0.019,0.015,0.004),"gold_thread")
		for sign: int in [-1,1]:
			curve(p,[at+Vector3(0,0.01,0),at+Vector3(float(sign)*0.03,0.023,0),at+Vector3(float(sign)*0.039,0.045,0)],0.004,"gold_thread")
			curve(p,[at+Vector3(0,-0.015,0),at+Vector3(float(sign)*0.026,-0.045,0),at+Vector3(float(sign)*0.045,-0.044,0)],0.004,"gold_thread")

static func sleeve(role: String) -> Array:
	var p: Array=[]
	var shirt: String="linen" if role in ["resident","servant","vintner","farmer"] else "cloth"
	var refined:bool=role in ["servant","builder","instructor"]
	var shape:Array=[Vector4(-0.279,0.065,0.066,0),Vector4(-0.242,0.076,0.078,-0.003),Vector4(-0.203,0.093,0.095,-0.001),Vector4(-0.139,0.095,0.10,0),Vector4(-0.065,0.088,0.09,0),Vector4(0.001,0.077,0.079,0),Vector4(0.045,0.045,0.048,0),Vector4(0.052,0.003,0.003,0)]
	if refined:shape=[Vector4(-0.279,0.065,0.066,0),Vector4(-0.242,0.076,0.078,-0.003),Vector4(-0.203,0.085,0.088,-0.001),Vector4(-0.139,0.086,0.091,0),Vector4(-0.065,0.079,0.083,0),Vector4(0.001,0.069,0.073,0),Vector4(0.016,0.044,0.048,0),Vector4(0.022,0.003,0.003,0)]
	var sleeve_mesh:=_loft(shape,0.006 if refined else 0.007)
	if refined:sleeve_mesh=_garment_values(sleeve_mesh,"linen" if shirt=="linen" else "coat")
	_add(p,sleeve_mesh,Vector3.ZERO,shirt)
	# Rolled fabric has two uneven rounded folds and a cloth lip, not a tube.
	_add(p,_loft([Vector4(-0.285,0.063,0.065,0),Vector4(-0.280,0.078,0.081,0),Vector4(-0.267,0.085,0.085,0),Vector4(-0.25,0.079,0.080,0),Vector4(-0.23,0.091,0.093,0),Vector4(-0.214,0.085,0.09,0),Vector4(-0.205,0.074,0.081,0)],0.002),Vector3.ZERO,"linen_light")
	curve(p,[Vector3(-0.046,-0.18,-0.084),Vector3(0.0,-0.155,-0.103),Vector3(0.059,-0.19,-0.071)],0.004,"linen_light" if shirt=="linen" else "cloth_light",0.35,true)
	if refined:
		for i in range(1,p.size()):
			if p[i].mesh is ArrayMesh and p[i].material=="linen_light":p[i].mesh=_garment_values(p[i].mesh,"linen")
	return p

static func forearm(role: String) -> Array:
	var p: Array=[]
	_add(p,_loft([Vector4(-0.27,0.033,0.034,0),Vector4(-0.20,0.039,0.040,0),Vector4(-0.125,0.052,0.049,-0.006),Vector4(-0.058,0.064,0.058,-0.004),Vector4(0.015,0.063,0.059,0),Vector4(0.032,0.049,0.05,0)],0),Vector3.ZERO,skin(role))
	if role in ["builder","lumberjack"]:
		_add(p,_loft([Vector4(-0.245,0.037,0.038,0),Vector4(-0.23,0.042,0.043,0),Vector4(-0.15,0.051,0.049,-0.003),Vector4(-0.139,0.049,0.049,-0.003)]),Vector3.ZERO,"leather")
		for y: float in [-0.226,-0.175]:_add(p,_loft([Vector4(y,0.047,0.046,-0.004),Vector4(y+0.012,0.047,0.046,-0.004)]),Vector3.ZERO,"leather_dark")
		for y: float in [-0.226,-0.175]:
			_box(p,Vector3(0.020,y+0.005,-0.046),Vector3(0.024,0.018,0.006),"metal")
			_box(p,Vector3(0.020,y+0.005,-0.050),Vector3(0.014,0.010,0.002),"leather_dark")
		curve(p,[Vector3(-0.021,-0.24,-0.034),Vector3(-0.028,-0.19,-0.043),Vector3(-0.030,-0.147,-0.044)],0.002,"stitch")
	return p

static func hand(role: String,side: int,gripping: bool=false) -> Array:
	var p: Array=[];var material:=skin(role)
	_add(p,_loft([Vector4(-0.065,0.035,0.02,-0.010),Vector4(-0.044,0.043,0.025,-0.007),Vector4(-0.006,0.038,0.029,0),Vector4(0.015,0.031,0.031,0)]),Vector3.ZERO,material)
	for index in range(0 if _detail==2 else 4):
		var x: float=(-1.5+float(index))*0.02;var length: float=0.054-absf(float(index)-1.4)*0.008
		var path: Array=[Vector3(x,-0.047,-0.012),Vector3(x,-0.073,-0.018),Vector3(x,-0.047-length,-0.03)]
		if gripping:path=[Vector3(x,-0.045,-0.021),Vector3(x,-0.069,-0.046),Vector3(x,-0.094,-0.019),Vector3(x,-0.085,0.006)]
		curve(p,path,0.010,material,0.88,true)
		_oval(p,Vector3(x,-0.060,-0.026),Vector3(0.011,0.012,0.007),material)
	curve(p,[Vector3(float(-side)*0.030,-0.015,-0.011),Vector3(float(-side)*0.052,-0.031,-0.026),Vector3(float(-side)*0.047,-0.063,-0.039)],0.014,material,0.92,true)
	return p

static func thigh(role: String) -> Array:
	var p: Array=[]
	_add(p,_loft([Vector4(-0.407,0.071,0.070,-0.005),Vector4(-0.357,0.086,0.085,-0.01),Vector4(-0.26,0.107,0.113,0.0),Vector4(-0.137,0.121,0.122,0.0),Vector4(-0.015,0.098,0.094,0.0),Vector4(0.065,0.062,0.064,0),Vector4(0.076,0.025,0.034,0)],0.009),Vector3.ZERO,"cloth_dark" if role=="servant" else "trouser")
	for y: float in [-0.26,-0.315]:curve(p,[Vector3(-0.075,y,-0.077),Vector3(-0.016,y+0.02,-0.115),Vector3(0.065,y-0.004,-0.089)],0.004,"trouser_light",0.3,true)
	return p

static func calf(role: String) -> Array:
	var p: Array=[]
	var material: String="skin_fair" if role=="farmer" else ("wrap" if role in ["servant","resident","stonecutter"] else "leather")
	if role=="lumberjack":material="cloth_dark"
	_add(p,_loft([Vector4(-0.382,0.043,0.048,0),Vector4(-0.3,0.053,0.056,0),Vector4(-0.205,0.075,0.073,0.01),Vector4(-0.10,0.082,0.077,0.01),Vector4(0.015,0.072,0.075,0)],0.003 if role in ["builder","instructor"] else 0.0),Vector3.ZERO,material)
	if role=="farmer":
		_add(p,_loft([Vector4(-0.14,0.065,0.07,0),Vector4(-0.12,0.085,0.09,0),Vector4(-0.02,0.098,0.10,0),Vector4(0.023,0.078,0.083,0)],0.006),Vector3.ZERO,"trouser")
	if material=="wrap":
		for i in range(7):
			var y: float=-0.05-float(i)*0.041;var radius: float=0.079-float(i)*0.0045
			curve(p,[Vector3(-radius,y,-0.009),Vector3(0,y+0.012,-radius),Vector3(radius,y+0.027,-0.012),Vector3(0,y+0.039,radius)],0.006,"wrap" if role=="servant" else "linen_light",0.3)
	elif material=="leather":
		_add(p,_loft([Vector4(-0.047,0.084,0.08,0.009),Vector4(-0.01,0.087,0.085,0.005),Vector4(0.014,0.084,0.080,0),Vector4(0.02,0.076,0.077,0)]),Vector3.ZERO,"leather_light")
		for side: int in [-1,1]:
			var q:=float(side)
			_patch(p,[Vector3(q*0.012,0.008,-0.084),Vector3(q*0.077,0.012,-0.045),Vector3(q*0.081,-0.094,-0.055),Vector3(q*0.024,-0.073,-0.09)],"leather_light",0.009)
			curve(p,[Vector3(q*0.079,-0.092,-0.058),Vector3(q*0.049,-0.081,-0.085),Vector3(q*0.025,-0.074,-0.092)],0.0025,"stitch")
	if role=="lumberjack":
		_add(p,_loft([Vector4(-0.374,0.050,0.057,0),Vector4(-0.145,0.08,0.078,0),Vector4(-0.132,0.077,0.077,0)]),Vector3.ZERO,"leather")
		for y: float in [-0.17,-0.255]:_add(p,_loft([Vector4(y,0.082,0.080,0),Vector4(y+0.026,0.083,0.081,0)]),Vector3.ZERO,"leather_dark")
	if role in ["servant","builder","instructor"]:
		for i in range(p.size()):
			if p[i].mesh is ArrayMesh:p[i].mesh=_garment_values(p[i].mesh,"wrap" if role=="servant" else "leather")
	return p

static func foot(role: String) -> Array:
	var p: Array=[]
	_oval(p,Vector3(0,-0.028,-0.058),Vector3(0.07,0.066,0.136),"leather")
	_oval(p,Vector3(0,-0.078,-0.054),Vector3(0.073,0.016,0.142),"sole")
	_add(p,_loft([Vector4(-0.031,0.058,0.066,0),Vector4(0.043,0.051,0.054,0),Vector4(0.086,0.049,0.052,0)]),Vector3.ZERO,"leather")
	for y: float in [0.04,0.012,-0.016]:
		for side: int in [-1,1]:
			curve(p,[Vector3(float(side)*0.029,y,-0.054),Vector3(0,y-0.012,-0.075),Vector3(float(-side)*0.032,y-0.026,-0.067)],0.0028,"leather_dark")
	if role in ["resident","servant","stonecutter","farmer"]:
		for side: int in [-1,1]:
			var q:=float(side)
			_patch(p,[Vector3(q*0.006,0.083,-0.051),Vector3(q*0.055,0.090,-0.018),Vector3(q*0.067,0.020,-0.036),Vector3(q*0.028,0.028,-0.072)],"leather_light",0.007)
	curve(p,[Vector3(-0.06,-0.064,-0.09),Vector3(0,-0.066,-0.185),Vector3(0.06,-0.064,-0.09)],0.0025,"stitch")
	return p

static func _gauss(x: float,y: float,cx: float,cy: float,sx: float,sy: float) -> float:
	return exp(-pow((x-cx)/sx,2.0)-pow((y-cy)/sy,2.0))

## Bounded shape differences traced from the three approved male portraits.
## Values are local metres; head height and the skull/hair attachment are fixed.
const FACE_SHAPES:Dictionary={
	"servant":{"jaw":.0055,"cheek_width":-.001,"cheek":.003,"hollow":.0008,"bridge":.001,"tip":-.0005,"nose_width":-.0006,"chin":.004,"brow":.002},
	"builder":{"jaw":.0050,"cheek_width":.0025,"cheek":.004,"hollow":-.001,"bridge":-.001,"tip":.002,"nose_width":.0015,"chin":.001,"brow":.0015},
	"instructor":{"jaw":.006,"cheek_width":-.0005,"cheek":.0045,"hollow":.0015,"bridge":.003,"tip":.001,"nose_width":.0005,"chin":.005,"brow":.0035}
}

static func _face(y: float,a: float,feminine: bool,role:String="") -> Vector3:
	var profile: Array=[Vector4(-0.146,0.030,0.041,-0.023),Vector4(-0.126,0.058,0.063,-0.019),Vector4(-0.090,0.079,0.073,-0.011),Vector4(-0.054,0.086,0.080,-0.001),Vector4(-0.019,0.096,0.086,0.008),Vector4(0.031,0.097,0.088,0.011),Vector4(0.078,0.091,0.085,0.014),Vector4(0.123,0.056,0.054,0.014),Vector4(0.145,0.003,0.003,0.014)]
	var r: Vector4=profile[-1]
	for i in range(profile.size()-1):
		if y>=profile[i].x and y<=profile[i+1].x:
			r=_cat(profile[maxi(0,i-1)],profile[i],profile[i+1],profile[mini(profile.size()-1,i+2)],inverse_lerp(profile[i].x,profile[i+1].x,y));break
	if FACE_SHAPES.has(role):
		var shape:Dictionary=FACE_SHAPES[role]
		r.y+=float(shape.jaw)*exp(-pow((y+.112)/.027,2.0))+float(shape.cheek_width)*exp(-pow((y+.039)/.028,2.0))
	var x: float=cos(a)*r.y*(0.96 if feminine else 1.0);var z: float=sin(a)*r.z+r.w
	var front: float=pow(maxf(0,-sin(a)),2.1 if FACE_SHAPES.has(role) else 5.0)
	if FACE_SHAPES.has(role):
		# A broad anterior jaw/cheek plane replaces the uninterrupted oval.
		# The back of the skull and the neck/hair attachment stay unchanged.
		var flatten:float=(.18*exp(-pow((y+.107)/.039,2.0))+.10*exp(-pow((y+.030)/.018,2.0)))*smoothstep(.15,.65,-sin(a))
		z=lerpf(z,-r.z+r.w,flatten)
	# Defined nasal bridge and tip on a continuous face, with adult cheek/jaw planes.
	var bridge: float=clampf((0.044-y)/0.10,0.0,1.0)*clampf((y+0.069)/0.018,0.0,1.0)
	var displacement: float=(0.025 if feminine else (.026 if FACE_SHAPES.has(role) else .031))*bridge*exp(-pow(absf(x)/0.017,1.5))
	displacement+=(.014 if FACE_SHAPES.has(role) else .011)*_gauss(x,y,0,-0.048,0.025,0.016)
	displacement+=0.011*_gauss(x,y,0,-0.092,0.036,0.022)+0.021*_gauss(x,y,0,-0.122,0.039,0.022)
	for side: int in [-1,1]:
		displacement+=(.010 if FACE_SHAPES.has(role) else .014)*_gauss(x,y,float(side)*0.061,-0.032,0.030,0.019)
		displacement+=0.012*_gauss(x,y,float(side)*0.043,0.030,0.034,0.016)
		displacement-=0.011*_gauss(x,y,float(side)*0.043,0.005,0.023,0.015)
		displacement-=(.0035 if FACE_SHAPES.has(role) else .005)*_gauss(x,y,float(side)*0.056,-0.076,0.022,0.024)
	if FACE_SHAPES.has(role):
		var shape:Dictionary=FACE_SHAPES[role]
		displacement+=float(shape.bridge)*bridge*exp(-pow(absf(x)/(.017+float(shape.nose_width)),1.5))
		displacement+=float(shape.tip)*_gauss(x,y,0,-.048,.022,.017)
		displacement+=float(shape.chin)*_gauss(x,y,0,-.123,.042,.023)
		for side:int in [-1,1]:
			var q:=float(side)
			displacement+=float(shape.cheek)*_gauss(x,y,q*.059,-.030,.032,.023)
			displacement-=float(shape.hollow)*_gauss(x,y,q*.062,-.067,.025,.027)
			displacement+=float(shape.brow)*_gauss(x,y,q*.043,.031,.033,.018)
			# Alar wings give the nose an adult base without a separate sphere.
			displacement+=(.0035 if role=="builder" else .0028)*_gauss(x,y,q*.016,-.051,.009,.012)
			if role=="builder":
				displacement+=.0025*_gauss(x,y,q*.037,-.056,.027,.021)
				# Release the upper orbit without moving the skull, brow height,
				# nose or mouth. The compact mask is exactly zero below the eye.
				var opening:float=smoothstep(-.025,-.014,y)*(1-smoothstep(.026,.040,y))
				displacement-=.0045*_gauss(x,y,q*.043,.012,.027,.022)*opening
	if role=="builder":
		displacement+=_builder_facial_volume(x,y)
		# A shallow continuous smile recess gives the opening an actual seat.
		# This is confined to the muzzle; skull, eyes and attachment are fixed.
		var smile:Vector2=_builder_smile_bounds(x)
		var centre:float=(smile.x+smile.y)*.5
		displacement-=.007*exp(-pow(x/.036,6.0)-pow((y-centre)/.0065,2.0))
	return Vector3(x,y,z-displacement*front)

## Smiling cheek mass rolls outside the accepted nose. Its central field,
## bridge, tip and nostrils retain the 2811 reference exactly; no nasal shelf
## or new pigment is added by this pass.
static func _builder_fold_x(y:float)->float:
	var t:float=clampf((-y-.043)/.042,0,1)
	return .027+.013*sin(t*PI*.65)

static func _builder_facial_volume(x:float,y:float)->float:
	var cheek:float=0.0
	for side:int in [-1,1]:
		var q:=float(side)
		# Raised zygomatic mass rolls into the cheek beside the smile.
		cheek+=.0095*_gauss(x,y,q*.055,-.034,.030,.025)
		cheek+=.0060*_gauss(x,y,q*.044,-.059,.027,.022)
	var cheek_gate:float=1-smoothstep(-.023,-.010,y)
	var fold:float=.0028*exp(-pow((absf(x)-_builder_fold_x(y))/.0055,2.0)-pow((y+.065)/.022,2.0))
	return (cheek-fold)*cheek_gate*smoothstep(.027,.043,absf(x))

static func _builder_skin_values(point:Vector3,shade:float,warmth:float)->Vector2:
	if point.z>=0:return Vector2(shade,warmth)
	var x:float=point.x;var y:float=point.y
	var original:=Vector2(shade,warmth)
	var mask:float=smoothstep(.027,.043,absf(x))
	for side:int in [-1,1]:
		var q:=float(side)
		shade-=.075*_gauss(x,y,q*.022,-.028,.007,.023)
		shade+=.055*_gauss(x,y,q*.056,-.032,.022,.017)
		warmth+=.050*_gauss(x,y,q*.060,-.039,.027,.021)
	shade-=.060*exp(-pow((absf(x)-_builder_fold_x(y))/.008,2.0)-pow((y+.065)/.020,2.0))
	return original.lerp(Vector2(clampf(shade,.52,1.04),minf(warmth,.17)),mask)

static func _face_point(x: float,y: float,feminine: bool,lift: float=0.002,role:String="") -> Vector3:
	var radius: float=_face(y,0.0,feminine,role).x
	var a: float=TAU-acos(clampf(x/maxf(radius,0.001),-0.999,0.999))
	var point:=_face(y,a,feminine,role);point.z-=lift;return point

static func _face_curve(p: Array,points: Array,radius: float,material: String,feminine: bool,lift: float=0.003,flatten: float=0.6,role:String="",close_ends:bool=false) -> void:
	var path: Array=[]
	for xy: Vector2 in points:path.append(_face_point(xy.x,xy.y,feminine,lift,role))
	curve(p,path,radius,material,flatten,true,close_ends)

## Builder's approved expression: the upper-lip hair is a low, continuous
## swept volume, rather than two disconnected oval tubes. These opaque curved
## meshes follow the face in three dimensions and retain a closed back.
static func _builder_smile_bounds(x:float)->Vector2:
	var edge:float=clampf(absf(x)/.039,0,1)
	var upper:float=-.0825+.0068*pow(edge,1.7)
	return Vector2(upper,upper-.016*pow(maxf(0,1-edge*edge),.7))

static func _builder_expression_bounds(kind:String,u:float)->Vector3:
	var width:float=.027 if kind=="teeth" else (.030 if kind=="lowerlip" else .039)
	var x:float=lerpf(-width,width,u);var edge:float=absf(x)/width
	var smile:Vector2=_builder_smile_bounds(x)
	var top:float=smile.x;var bottom:float=smile.y
	if kind=="moustache":
		# Hair grows from the philtrum down and outward into the beard, while
		# the lower edge has several shallow uneven tufts, not an oval rim.
		top=-.0675-.011*edge-.004*exp(-pow(x/.0038,2.0))
		bottom=minf(top-.0014,smile.x+.0007+.0004*sin(u*PI*17.0)*sin(u*PI))
	elif kind=="teeth":
		top-=.0013;bottom=top-.0052*pow(maxf(.02,1-edge*edge),.45)
	elif kind=="lowerlip":
		top=smile.y-.0006;bottom=top-.0038*pow(maxf(.02,1-edge*edge),.5)
	else:bottom=minf(bottom,top-.0006)
	return Vector3(x,top,bottom)

static func _builder_expression_point(kind:String,u:float,v:float)->Vector3:
	var bounds:Vector3=_builder_expression_bounds(kind,u)
	var y:float=lerpf(bounds.y,bounds.z,v)
	var lift:float=.0028
	if kind=="moustache":
		lift=.0018+.0032*sin(v*PI)*pow(maxf(0,sin(u*PI)),.5)
		lift+=.0007*sin(u*PI*10.0+v*1.8)*sin(v*PI)*sin(u*PI)
	elif kind=="teeth":lift=.0035
	elif kind=="lowerlip":lift=.0010+.0013*sin(v*PI)
	var point:Vector3=_face_point(bounds.x,y,false,lift,"builder")
	# Match the actual LOD face triangles; the analytic face alone can
	# otherwise let a low-resolution cheek facet cut across the smile.
	point.z=minf(point.z,_front_at(_builder_muzzle_surface,bounds.x,y)-lift)
	if kind=="teeth":point.z=minf(point.z,_front_at(_builder_mouth_surface,bounds.x,y)-.0012)
	return point

static func _builder_expression_patch(p:Array,kind:String,material:String,columns:int,rows:int)->void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Front, back and perimeter share identical coordinates. Re-evaluating a
	# Vector2 UV at the perimeter otherwise introduces float32 rounding seams.
	var grid:Array[Vector3]=[]
	for row in range(rows+1):
		for col in range(columns+1):grid.append(_builder_expression_point(kind,float(col)/columns,float(row)/rows))
	for row in range(rows):
		for col in range(columns):
			var points:Array[Vector3]=[];var uv:Array[Vector2]=[];var values:Array=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:float=float(pair.y)/columns;var v:float=float(pair.x)/rows
				points.append(grid[pair.x*(columns+1)+pair.y]);uv.append(Vector2(u,v))
				var value:float=.60+.12*v if kind=="mouth" else (.73+.11*sin(u*PI) if kind=="teeth" else .78+.13*sin(v*PI)-.07*exp(-pow((u-.5)/.055,2.0)))
				if kind=="lowerlip":value=.90-.06*v
				elif kind=="moustache":value+=.055*sin(u*PI*10.0+v*1.8)*sin(v*PI)
				values.append(Color(value,value,value))
			_quad(st,points,uv,true,values)
	var border:Array[int]=[]
	for col in range(columns+1):border.append(col)
	for row in range(1,rows+1):border.append(row*(columns+1)+columns)
	for col in range(columns-1,-1,-1):border.append(rows*(columns+1)+col)
	for row in range(rows-1,0,-1):border.append(row*(columns+1))
	# A back surface follows the same concave outline with real thickness.
	# No centre fan can cross the smiling outline or create exposed flaps.
	var thickness:=Vector3(0,0,.006)
	for row in range(rows):
		for col in range(columns):
			var points:Array[Vector3]=[];var uv:Array[Vector2]=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:float=float(pair.y)/columns;var v:float=float(pair.x)/rows
				points.append(grid[pair.x*(columns+1)+pair.y]+thickness);uv.append(Vector2(u,v))
			_quad(st,points,uv,false)
	for i in range(border.size()):
		var a:Vector3=grid[border[i]]
		var b:Vector3=grid[border[(i+1)%border.size()]]
		_quad(st,[a,a+thickness,b+thickness,b],[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)],true)
	_add(p,_finish(st),Vector3.ZERO,material)
	if kind=="mouth":_builder_mouth_surface=_garment_front(p[-1].mesh,Transform3D.IDENTITY,-INF)

static func _builder_smile(p:Array)->void:
	_builder_expression_patch(p,"mouth","lip",_n(20,8,8),_n(3,1,1))
	# One restrained upper dental arch, not separate bright tooth blocks.
	_builder_expression_patch(p,"teeth","eye",_n(12,6,6),1)
	_builder_expression_patch(p,"lowerlip","skin",_n(12,6,6),1)

## Continuous pinna: a shallow concha, fleshy lobe and closed rim. The
## medial surface enters the skull, so front/profile have no detached hoop.
static func _ear_point(r:float,a:float,q:float,back:bool)->Vector3:
	# Carve the bowl into a solid ellipsoidal ear. The outer seam closes into
	# the medial half instead of leaving a rim suspended beside the skull.
	var width:float=.017*sqrt(maxf(0,1-r*r))
	var cavity:float=.012*exp(-pow(r/.42,2.0))*(1-.5*smoothstep(.35,.8,r)*maxf(0,-cos(a)))
	var x:float=.096-width if back else .096+width-cavity
	return Vector3(q*x,-.034+cos(a)*.031*r,.008+sin(a)*.019*r+cos(a)*.002*r)

static func _ear_concha(p:Array,side:int,material:String,role:String="")->void:
	var q:=float(side);var first:int=p.size();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var rings:=_n(5,3,2);var sectors:=_n(18,10,6)
	for back in [false,true]:
		for row in range(rings):
			for col in range(sectors):
				var pts:Array[Vector3]=[];var uv:Array[Vector2]=[];var shades:Array=[]
				for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
					var r:float=float(pair.x)/rings;var u:float=float(pair.y)/sectors;var a:float=u*TAU
					pts.append(_ear_point(r,a,q,back));uv.append(Vector2(u,r))
					var shade:float=.86+.13*smoothstep(0,.8,r);shades.append(Color(shade,shade*.985,shade*.97))
				# Godot's clockwise triangles: lateral surface normals point out.
				_quad(st,pts,uv,(side<0)!=back,shades)
	_add(p,_finish(st),Vector3.ZERO,material)
	var rim:Array=[]
	for i in range(_n(13,8,7)):
		var a:float=float(i)/float(_n(12,7,6))*TAU
		rim.append(_ear_point(.76,a,q,false))
	curve(p,rim,.0022,material,.78)
	var inner:Array=[]
	for pair:Vector2 in [Vector2(.58,-.8),Vector2(.46,-1.5),Vector2(.52,-2.3),Vector2(.67,-2.8)]:inner.append(_ear_point(pair.x,pair.y,q,false)+Vector3(q*.0008,0,0))
	curve(p,inner,.0023,material,.65)
	var crease:Array=[]
	for a:float in [-.6,-1.5,-2.4]:crease.append(_ear_point(.24,a,q,false)+Vector3(q*.0008,0,0))
	curve(p,crease,.0015,"skin_shadow",.6)
	var anchor:=Vector3(q*.096,-.034,.008);var turn:=Basis(Vector3.UP,q*.20)
	var placement:=Transform3D(turn,anchor-turn*anchor)
	# The instructor's fixed hair is tucked behind the visible pinna.
	if role=="instructor":placement.origin.z-=.010
	for i in range(first,p.size()):p[i].at=placement*p[i].at

static func _portrait_angle(u:float)->float:
	if u<=.20:return u/.20*PI
	var front:float=(u-.20)/.80*2.0-1.0
	return PI*1.5+signf(front)*pow(absf(front),1.4)*PI*.5

## Open but almond-shaped eyes for the builder's approved friendly expression.
## The larger aperture is sculpted through the lid arcs and recessed orbit;
## the iris stays partly under the upper lid instead of becoming a round eye.
static func _builder_eye(p:Array,q:float)->void:
	var x:float=q*.043;var at:Vector3=_face_point(x,.004,false,.0020,"builder")
	var first:int=p.size();var eye_shift:float=0.0
	if _detail==2:
		# Seat the compact eye into the actual distant face facet. The white
		# remains partly embedded; only its exposed cap clears the cheek plane.
		eye_shift=minf(0,_front_at(_builder_eye_surface,x,.004)+.0020-at.z)
	_oval(p,at,Vector3(.0178,.0102,.0035),"eye")
	if _detail<2:_oval(p,at+Vector3(-q*.0012,.0010,-.0028),Vector3(.0067,.0082,.0021),"iris")
	_oval(p,at+Vector3(-q*.0012,.0012,-.0038),Vector3(.0044,.0050,.0014),"pupil")
	if _detail==0:_oval(p,at+Vector3(-.0025-q*.0012,.0042,-.0050),Vector3.ONE*.0015,"eye")
	_face_curve(p,[Vector2(x-q*.019,.003),Vector2(x+q*.001,.0162),Vector2(x+q*.019,.005)],.0032,"skin_shadow",false,.0048,.6,"builder")
	_face_curve(p,[Vector2(x-q*.019,.002),Vector2(x,-.0061),Vector2(x+q*.019,.004)],.0026,"skin",false,.0030,.55,"builder")
	if eye_shift<0:
		for i in range(first,p.size()):p[i].at.origin.z+=eye_shift

## A seated almond aperture for the two calm approved faces. The white is
## one shallow corneal cap with a defined lid boundary, not an entire exposed
## ellipsoid. Both lids meet the same endpoints and follow the real LOD face.
static func _rest_eye_point(role:String,q:float,u:float,v:float)->Vector3:
	var across:float=u*2.0-1.0
	var x:float=q*(.043+across*.0185)
	var arch:float=pow(maxf(.001,1.0-across*across),.78)
	var line:float=.004+across*.0008
	var top:float=line+(.0088 if role=="servant" else .0080)*arch
	var bottom:float=line-(.0068 if role=="servant" else .0060)*arch
	var y:float=lerpf(top,bottom,v)
	var lift:float=.0011+.0035*sin(PI*v)*sin(PI*u)
	var point:Vector3=_face_point(x,y,false,lift,role)
	point.z=minf(point.z,_front_at(_rest_eye_surface,x,y)-lift)
	return point

## Iris pigment follows the same corneal cap and is clipped by the lid
## aperture. A larger iris can therefore meet the upper lid without a sphere
## protruding over the skin or a white ring surrounding the complete iris.
static func _rest_eye_disc(p:Array,role:String,q:float,width:float,height:float,material:String,depth:float)->void:
	var columns:int=_n(12,8,6);var rows:int=_n(4,3,2)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var centre_y:float=.0058
	for row in range(rows):
		for col in range(columns):
			var points:Array[Vector3]=[];var uv:Array[Vector2]=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:float=float(pair.y)/columns;var v:float=float(pair.x)/rows
				var across:float=u*2.0-1.0
				var x:float=q*(.0424+across*width)
				var eye_u:float=clampf(((q*x-.043)/.0185+1)*.5,0,1)
				var upper:Vector3=_rest_eye_point(role,q,eye_u,0)
				var lower:Vector3=_rest_eye_point(role,q,eye_u,1)
				var half_y:float=height*sqrt(maxf(.0004,1-across*across))
				var top:float=minf(centre_y+half_y,upper.y-.00015)
				var bottom:float=maxf(centre_y-half_y,lower.y+.00015)
				var y:float=lerpf(top,bottom,v)
				var eye_v:float=clampf(inverse_lerp(upper.y,lower.y,y),0,1)
				var point:Vector3=_rest_eye_point(role,q,eye_u,eye_v)
				point.z-=depth
				points.append(point);uv.append(Vector2(u,v))
			_quad(st,points,uv,q>0)
	_add(p,_finish(st),Vector3.ZERO,material)

static func _rest_eye(p:Array,role:String,q:float)->void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns:int=_n(14,10,6);var rows:int=_n(6,4,2)
	for row in range(rows):
		for col in range(columns):
			var points:Array[Vector3]=[];var uv:Array[Vector2]=[];var values:Array=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:float=float(pair.y)/columns;var v:float=float(pair.x)/rows
				points.append(_rest_eye_point(role,q,u,v));uv.append(Vector2(u,v))
				# The upper eyelid casts a restrained local value; no bright ring.
				var value:float=.83+.14*sin(PI*v)
				values.append(Color(value,value,value))
			_quad(st,points,uv,q>0,values)
	_add(p,_finish(st),Vector3.ZERO,"eye")
	if _detail<2:_rest_eye_disc(p,role,q,.0071,.0080,"iris",.0006)
	_rest_eye_disc(p,role,q,.0040,.0050,"pupil",.0010)
	if _detail==0:_oval(p,_rest_eye_point(role,q,.46,.30)+Vector3(0,0,-.0015),Vector3.ONE*.0009,"eye")
	# The lids have flesh thickness and rounded corners but no free tube ends.
	var upper:Array=[];var lower:Array=[]
	for i in range(_n(5,4,3)):
		var u:float=float(i)/float(_n(4,3,2))
		upper.append(_rest_eye_point(role,q,u,0)+Vector3(0,.0005,-.0002))
		lower.append(_rest_eye_point(role,q,u,1)+Vector3(0,-.0004,-.0001))
	curve(p,upper,.0025,skin(role),.48,true,true)
	curve(p,lower,.0019,skin(role),.48,true,true)
	# A fine crease belongs above the fleshy upper lid, not across the pupil.
	var crease:Array=[]
	for u:float in [.13,.52,.88]:
		var point:Vector3=_rest_eye_point(role,q,u,0)
		crease.append(_face_point(point.x,point.y+.0040,false,.0010,role))
	curve(p,crease,.0009,"skin_shadow",.40,true,true)

static func head(role: String) -> Array:
	var p: Array=[];var feminine:=female(role);var hair_mat:=hair(role);var skin_mat:=skin(role);var refined:bool=FACE_SHAPES.has(role)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var face_rows:=_n(38,20,11);var face_columns:=_n(48,24,16)
	var face_heights:Array[float]=[]
	for row in range(face_rows+1):face_heights.append(lerpf(-.146,.145,float(row)/face_rows))
	if role=="builder":
		face_heights.append(-.092);face_heights.append(-.083)
		face_heights.sort();face_rows=face_heights.size()-1
	for row in range(face_rows):
		for col in range(face_columns):
			var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var v:=float(pair.x)/float(face_rows);var u:=float(pair.y)/float(face_columns);var point:=_face(face_heights[pair.x],_portrait_angle(u) if refined else u*TAU,feminine,role)
				var shade:=1.0
				if point.z<0.0:
					for side: int in [-1,1]:
						shade-=0.24*_gauss(point.x,point.y,float(side)*0.043,0.011,0.024,0.017)
						shade-=0.08*_gauss(point.x,point.y,float(side)*0.036,-0.073,0.012,0.02)
					shade-=0.16*_gauss(point.x,point.y,0,-0.069,0.029,0.012)
					shade-=0.09*_gauss(point.x,point.y,0,-0.104,0.030,0.008)
				if refined and point.z<0:
					for side:int in [-1,1]:
						var q:=float(side)
						shade-=.055*_gauss(point.x,point.y,q*.043,.014,.028,.018)
						shade-=.065*_gauss(point.x,point.y,q*.080,.020,.022,.039)
						shade-=(.065 if role=="instructor" else (.025 if role=="builder" else .040))*_gauss(point.x,point.y,q*.061,-.064,.027,.023)
						shade-=(.105 if role=="instructor" else .045)*_gauss(point.x,point.y,q*.035,-.071,.013,.025)
						shade-=.095*_gauss(point.x,point.y,q*.020,-.030,.008,.027)
						shade+=.022*_gauss(point.x,point.y,q*.054,-.029,.025,.016)
					shade=clampf(shade,.55,1.0)
				var warmth:=0.0
				if point.z<0:
					for side: int in [-1,1]:warmth+=0.045*_gauss(point.x,point.y,float(side)*0.066,-0.043,0.035,0.030)
					warmth+=0.024*_gauss(point.x,point.y,0,-0.050,0.025,0.025)
				if role=="builder":
					var paint:Vector2=_builder_skin_values(point,shade,warmth);shade=paint.x;warmth=paint.y
				pts.append(point);uv.append(Vector2(u,v));tints.append(Color(shade,shade*(1.0-warmth),shade*(1.0-warmth*1.6)))
			_quad(st,pts,uv,false,tints)
	_add(p,_finish(st),Vector3.ZERO,skin_mat)
	if role=="builder":
		_builder_eye_surface=_garment_front(p[0].mesh,Transform3D.IDENTITY,-.020) if _detail==2 else []
		_builder_muzzle_surface=[]
		for triangle:Array in _garment_front(p[0].mesh,Transform3D.IDENTITY,-.12):
			var bounds:Vector4=triangle[0]
			if bounds.y>=-.05 and bounds.x<=.05 and bounds.w>=-.11 and bounds.z<=-.05:_builder_muzzle_surface.append(triangle)
	if role in ["servant","instructor"]:
		_rest_eye_surface=_garment_front(p[0].mesh,Transform3D.IDENTITY,-.025)
	for side: int in [-1,1]:
		var q:=float(side)
		if refined:_ear_concha(p,side,skin_mat,role)
		else:
			_oval(p,Vector3(q*0.096,-0.034,0.008),Vector3(0.016,0.031,0.019),skin_mat,Vector3(0,0,q*-0.17))
			curve(p,[Vector3(q*0.100,-0.057,-0.002),Vector3(q*0.108,-0.026,-0.008),Vector3(q*0.10,-0.008,-0.005)],0.004,"skin_shadow",0.6)
		if role=="builder":_builder_eye(p,q)
		elif role in ["servant","instructor"]:_rest_eye(p,role,q)
		else:
			var eye_x:=q*0.043;var at:=_face_point(eye_x,0.004,feminine,.0015 if refined else .004,role)
			_oval(p,at,Vector3(.0178,.0078,.0035) if refined else Vector3(0.0185,0.0085,0.006),"eye")
			if _detail<2:_oval(p,at+Vector3(-q*0.0012,-0.0002,-.0028 if refined else -.0055),Vector3(.0065,.0072,.0021) if refined else Vector3(0.0065,0.0072,0.0025),"iris")
			_oval(p,at+Vector3(-q*0.0012,0,-.0038 if refined else -.007),Vector3(.0042,.0046,.0014) if refined else Vector3(0.0042,0.0046,0.0016),"pupil")
			if _detail==0:_oval(p,at+Vector3(-0.0025-q*0.0012,0.003,-.0050 if refined else -.0085),Vector3.ONE*0.0015,"eye")
			_face_curve(p,[Vector2(eye_x-0.019,0.004),Vector2(eye_x,.012),Vector2(eye_x+0.019,0.003)],.0036 if refined else .0032,"skin_shadow",feminine,.0055 if refined else .007,0.6,role)
			_face_curve(p,[Vector2(eye_x-0.019,0.002),Vector2(eye_x,-.005),Vector2(eye_x+0.019,0.002)],.0032 if refined else .0028,skin_mat,feminine,.0045 if refined else .006,0.7,role)
		var brow:Array=[Vector2(q*.020,.029),Vector2(q*.042,.037),Vector2(q*.063,.033),Vector2(q*.075,.025)]
		if role=="instructor":brow=[Vector2(q*.020,.029),Vector2(q*.042,.033),Vector2(q*.063,.030),Vector2(q*.075,.021)]
		elif role=="builder":brow=[Vector2(q*.020,.031),Vector2(q*.042,.039),Vector2(q*.063,.035),Vector2(q*.075,.028)]
		_face_curve(p,brow,0.0048 if feminine else 0.0058,"hair_brow",feminine,0.006,0.45,role)
		if _detail<2:_oval(p,_face_point(q*0.014,-0.055,feminine,0.003,role),Vector3(0.0044,0.0028,0.002),"skin_shadow")
		if role=="instructor":
			_face_curve(p,[Vector2(q*0.065,-0.009),Vector2(q*0.075,-0.014),Vector2(q*0.08,-0.009)],0.0017,"skin_shadow",feminine,0.001,0.4,role)
		if role=="stonecutter":
			var ring: Array=[]
			for i in range(13):ring.append(Vector3(q*0.11+cos(float(i)*TAU/12)*0.012,-0.06+sin(float(i)*TAU/12)*0.017,-0.001))
			curve(p,ring,0.0035,"gold")
	var mouth:Array=[Vector2(-.029,-.083),Vector2(-.015,-.085),Vector2(0,-.086),Vector2(.016,-.084),Vector2(.029,-.081)]
	if role=="servant":mouth=[Vector2(-.029,-.081),Vector2(-.014,-.084),Vector2(0,-.085),Vector2(.016,-.082),Vector2(.030,-.077)]
	elif role=="builder":mouth=[Vector2(-.034,-.075),Vector2(-.019,-.084),Vector2(0,-.087),Vector2(.019,-.084),Vector2(.034,-.075)]
	elif role=="instructor":mouth=[Vector2(-.031,-.082),Vector2(-.017,-.086),Vector2(0,-.087),Vector2(.018,-.084),Vector2(.031,-.080)]
	if role=="builder":_builder_smile(p)
	else:
		_face_curve(p,mouth,0.0026,"lip",feminine,0.003,0.6,role)
		_face_curve(p,[Vector2(-0.021,-0.091),Vector2(0,-0.094),Vector2(0.021,-0.089)],.0026 if refined else .0033,skin_mat,feminine,0.004,0.8,role)
	_hair(p,role)
	if role in ["builder","vintner"]:
		if role=="builder":_builder_expression_patch(p,"moustache",hair_mat,_n(24,8,6),_n(4,2,1))
		else:
			for side: int in [-1,1]:
				var moustache:Array=[Vector2(float(side)*.003,-.069),Vector2(float(side)*.022,-.073),Vector2(float(side)*.032,-.080)]
				_face_curve(p,moustache,.009,hair_mat,feminine,.005,.45,role)
		var beard:=SurfaceTool.new();beard.begin(Mesh.PRIMITIVE_TRIANGLES);var rows:=_n(8,5,3);var columns:=_n(24,16,10)
		for row in range(rows):
			for col in range(columns):
				var pts: Array[Vector3]=[];var uv: Array[Vector2]=[]
				for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
					var u:=float(pair.y)/columns;var v:=float(pair.x)/rows;var a:=PI+u*PI
					var upper:float=-.076+absf(u-.5)*.083
					if role=="builder":
						# Leave the lower lip visible and let a small irregular chin
						# tuft meet it; avoid a straight triangular beard cutout.
						upper-=.022*exp(-pow((u-.5)/.22,2.0))+.012*exp(-pow((u-.5)/.16,2.0))
						upper+=.007*exp(-pow((u-.493)/.052,2.0))+.0015*sin(u*13.0)
						upper-=.003*exp(-pow((u-.39)/.065,2.0))+.003*exp(-pow((u-.61)/.065,2.0))
					var y:=lerpf(-.145,upper,v)
					var point:=_face(maxf(-0.145,y),a,false,role);point.z-=0.004+sin(u*39+v*4)*0.001;point.y=y
					pts.append(point);uv.append(Vector2(u,v))
				_quad(beard,pts,uv)
		_add(p,_finish(beard),Vector3.ZERO,hair_mat)
	if role=="farmer":_hat(p)
	return p

## Thin convex locks overlap a continuous scalp volume. These are 3D surfaces,
## not tubes, alpha cards or camera-facing billboards.
static func _hair_lock(p: Array,path: Array,width: float,crest: float,material: String) -> void:
	var samples: Array[Vector3]=[];var steps:=_n(4,2,1);var columns:=_n(6,3,2)
	for n in range(path.size()-1):
		for sub in range(steps):samples.append((path[n] as Vector3).cubic_interpolate(path[n+1],path[maxi(0,n-1)],path[mini(n+2,path.size()-1)],float(sub)/steps))
	samples.append(path[-1])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	for row in range(samples.size()-1):
		for col in range(columns):
			var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var v:=float(pair.x)/float(samples.size()-1);var u:=float(pair.y)/columns;var across:=u*2-1
				var center:=samples[pair.x];var tangent: Vector3=(samples[mini(pair.x+1,samples.size()-1)]-samples[maxi(0,pair.x-1)]).normalized()
				var normal:=Vector3(center.x/0.11,(center.y-0.018)/0.17,(center.z-0.017)/0.10).normalized()
				if center.y < -0.10:normal=Vector3.BACK
				var lateral:=tangent.cross(normal).normalized();normal=lateral.cross(tangent).normalized()
				var taper:=pow(sin(PI*clampf(v,0.035,0.995)),0.40)
				var point:=center+lateral*(across*width*taper+sin(v*TAU)*width*0.28)
				if point.y > -0.055:
					var yy:=clampf((point.y-0.008)/0.163,-0.995,0.995);var rr:=sqrt(1-yy*yy)
					var radial:=Vector2(point.x/0.109,(point.z-0.011)/0.110)
					if radial.length() < rr+0.015:
						radial=radial.normalized()*(rr+0.015);point.x=radial.x*0.109;point.z=radial.y*0.110+0.011
				point+=normal*(crest*(1-across*across)*taper)
				pts.append(point);uv.append(Vector2(u,v));var shade:=0.80+0.20*(1-across*across);tints.append(Color(shade,shade,shade))
			_quad(st,pts,uv,true,tints)
	_add(p,_finish(st),Vector3.ZERO,material)

## Short, swept hair sculpted as broad asymmetric waves. The skull/face/rig
## keep their previous scale; the contour comes from locks, not a bigger head.
## Solid flattened locks with a closed cross section. Their underside lies
## against the scalp, avoiding the detached ribbon gaps visible in candidate1.
static func _hair_wave(p:Array,path:Array,width:float,crest:float,material:String)->void:
	var samples:Array[Vector3]=[];var steps:=_n(4,2,1);var sides:=_n(8,6,4)
	for n in range(path.size()-1):
		for sub in range(steps):samples.append((path[n] as Vector3).cubic_interpolate(path[n+1],path[maxi(0,n-1)],path[mini(path.size()-1,n+2)],float(sub)/steps))
	samples.append(path[-1])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var ends:Dictionary={0:{},samples.size()-1:{}}
	for row in range(samples.size()-1):
		for col in range(sides):
			var pts:Array[Vector3]=[];var uv:Array[Vector2]=[];var colors:Array=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var v:float=float(pair.x)/float(samples.size()-1);var u:float=float(pair.y)/sides;var a:float=u*TAU
				var center:Vector3=samples[pair.x]
				# Keep every lock seated on a continuous ellipsoidal scalp;
				# tangential curvature supplies waves instead of a large gap.
				var radial:=Vector3(center.x/.108,(center.y-.010)/.157,(center.z-.012)/.111)
				var original_radius:float=radial.length()
				radial=radial.normalized();center=Vector3(radial.x*.108,radial.y*.157+.010,radial.z*.111+.012)
				var normal:=Vector3(radial.x/.108,radial.y/.157,radial.z/.111).normalized()
				var prominence:float=clampf((original_radius-1.0)*.065,-.001,.011)
				center+=normal*prominence
				var tangent:Vector3=(samples[mini(pair.x+1,samples.size()-1)]-samples[maxi(pair.x-1,0)]).normalized()
				var lateral:Vector3=tangent.cross(normal).normalized()
				if lateral.length_squared()<.1:lateral=Vector3.RIGHT
				var taper:float=pow(sin(PI*clampf(v,.012,.997)),.40)
				var point:Vector3=center+lateral*cos(a)*width*taper+normal*(sin(a)*crest*taper-.0015)
				if ends.has(pair.x):ends[pair.x][pair.y%sides]=point
				pts.append(point);uv.append(Vector2(u,v));var shade:float=.77+.23*maxf(0,sin(a));colors.append(Color(shade*.88,shade*.91,shade*.91))
			_quad(st,pts,uv,false,colors)
	# Close the tiny taper ends, so no open ribbon edge remains in portraits.
	for index:int in ends:
		var ring:Dictionary=ends[index];var center:=Vector3.ZERO
		for point:Vector3 in ring.values():center+=point
		center/=float(ring.size())
		for col in range(sides):
			var points:Array[Vector3]=[center,ring[col],ring[(col+1)%sides]]
			for i:int in ([0,2,1] if index==0 else [0,1,2]):
				st.set_smooth_group(-1);st.set_color(Color(.80,.83,.83));st.set_uv(Vector2(.5,0 if index==0 else 1));st.add_vertex(points[i])
	_add(p,_finish(st),Vector3.ZERO,material)

static func _approved_short_hair(p:Array,role:String)->void:
	var material:=hair(role)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var rows:=_n(15,8,5);var columns:=_n(36,22,14)
	for row in range(rows):
		for col in range(columns):
			var pts:Array[Vector3]=[];var uv:Array[Vector2]=[];var colors:Array=[]
			for pair:Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:float=float(pair.y)/columns;var v:float=float(pair.x)/rows;var a:float=u*TAU
				var front:float=smoothstep(.02,.75,-sin(a));var back:float=smoothstep(.05,.8,sin(a))
				var bottom:float=.006+front*.065-back*.032+sin(a*3.0+.65)*.007
				var y:float=lerpf(bottom,.163,v);var radial:float=sqrt(maxf(.00001,1.0-pow((y-.010)/.153,2.0)))
				var wave:float=.0025*sin(a*4.0+v*4.8)*sin(v*PI)
				var point:=Vector3(cos(a)*(.105*radial+wave),y,sin(a)*(.107*radial+wave)+.012)
				pts.append(point);uv.append(Vector2(u,v));var shade:float=.78+.17*sin(v*PI*.75);colors.append(Color(shade,shade,shade))
			_quad(st,pts,uv,false,colors)
	_add(p,_finish(st),Vector3.ZERO,material)
	# Distinct approved partings: servant sweeps to one side; builder opens
	# from a soft central part into two uneven waves.
	if role=="servant":
		_hair_wave(p,[Vector3(-.064,.073,-.069),Vector3(-.065,.133,-.085),Vector3(-.018,.161,-.061),Vector3(.077,.122,-.036),Vector3(.126,.066,.012)],.032,.009,material)
		_hair_wave(p,[Vector3(-.068,.122,-.045),Vector3(-.032,.165,-.010),Vector3(.039,.156,.018),Vector3(.096,.094,.044),Vector3(.129,.071,.064)],.033,.008,material)
		_hair_wave(p,[Vector3(-.062,.141,.016),Vector3(-.005,.157,.060),Vector3(.065,.115,.075),Vector3(.111,.070,.083),Vector3(.119,.075,.102)],.030,.007,material)
		_hair_wave(p,[Vector3(-.062,.070,-.072),Vector3(-.079,.104,-.092),Vector3(-.065,.130,-.087),Vector3(-.037,.109,-.102),Vector3(-.051,.057,-.091)],.020,.007,material)
	else:
		_hair_wave(p,[Vector3(-.003,.117,-.087),Vector3(-.035,.160,-.064),Vector3(-.084,.140,-.037),Vector3(-.109,.085,-.006),Vector3(-.132,.073,-.004)],.035,.009,material)
		_hair_wave(p,[Vector3(.006,.114,-.087),Vector3(.044,.151,-.077),Vector3(.090,.109,-.049),Vector3(.110,.071,-.010),Vector3(.130,.084,.006)],.034,.009,material)
		_hair_wave(p,[Vector3(-.045,.143,-.030),Vector3(-.022,.167,.017),Vector3(.046,.139,.057),Vector3(.101,.085,.060),Vector3(.126,.085,.083)],.033,.007,material)
		_hair_wave(p,[Vector3(-.090,.105,.006),Vector3(-.085,.145,.041),Vector3(-.024,.151,.083),Vector3(.040,.103,.098),Vector3(.072,.063,.115)],.031,.007,material)
	# Ears stay exposed. Side locks sweep backward and turn upward at their
	# ends instead of forming a straight bob haircut edge.
	for side:int in [-1,1]:
		var q:=float(side)
		for i in range(_n(3,2,2)):
			var f:float=float(i)/float(_n(2,1,1));var y:float=.083-f*.048
			_hair_wave(p,[Vector3(q*.082,y+.034,.026),Vector3(q*.114,y+.009,.054),Vector3(q*.116,y-.020,.082),Vector3(q*.102,y-.029,.107),Vector3(q*.114,y-.017,.122)],.026-f*.003,.007,material)
	# Several broad diagonal waves break up the rear contour and nape.
	for i in range(_n(5,3,2)):
		var f:float=float(i)/float(_n(4,2,1));var x:float=-.076+f*.15
		_hair_wave(p,[Vector3(x*.7,.133,.067),Vector3(x,.083,.116),Vector3(x-.012,.035,.126),Vector3(x+.011,-.029+sin(f*5.0)*.008,.111),Vector3(x+.029,-.018+sin(f*5.0)*.008,.126)],.029,.007,material)

## Seat only the open perimeter of the instructor's scalp locks beneath the
## existing cap. The wave centres, face, hairline and tied tail stay fixed.
static func _cap_triangles(mesh:Mesh)->Array:
	var out:Array=[];var arrays:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a:Vector3=vertices[indices[i]];var b:Vector3=vertices[indices[i+1]];var c:Vector3=vertices[indices[i+2]]
		out.append([minf(a.y,minf(b.y,c.y)),maxf(a.y,maxf(b.y,c.y)),a*100,b*100,c*100])
	return out

static func _cap_radius(triangles:Array,point:Vector3,center_z:float=.011,cast_radius:float=.25)->float:
	var radial:=Vector3(point.x,0,point.z-center_z).normalized();var origin:Vector3=(Vector3(0,point.y,center_z)+radial*cast_radius)*100;var closest:float=INF
	for triangle:Array in triangles:
		if point.y<float(triangle[0])-.000001 or point.y>float(triangle[1])+.000001:continue
		var hit:Variant=Geometry3D.ray_intersects_triangle(origin,-radial,triangle[2],triangle[3],triangle[4])
		if hit!=null:closest=minf(closest,origin.distance_to(hit)/100)
	return cast_radius-closest

static func _seat_hair_edges(mesh:Mesh,cap:Array)->ArrayMesh:
	var arrays:Array=mesh.surface_get_arrays(0);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate();var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for i in range(points.size()):
		if uv[i].x>.00001 and uv[i].x<.99999 and uv[i].y>.00001 and uv[i].y<.99999:continue
		var point:Vector3=points[i];var angle:float=atan2((point.z-.011)/.110,point.x/.109)
		var front:float=smoothstep(.05,.55,-sin(angle))
		var bottom:float=-.063+front*(.141+sin(angle*3+.4)*.012+sin(angle*6)*.004)+sin(angle*5)*.004
		point.y=maxf(point.y,bottom+.003)
		var radius:float=maxf(.001,sqrt(maxf(0,1-pow((point.y-.008)/.163,2.0)))-.040)
		point.x=cos(angle)*.109*radius;point.z=sin(angle)*.110*radius+.011
		var radial:=Vector3(point.x,0,point.z-.011).normalized();var surface:float=_cap_radius(cap,point)
		if surface>.003:
			point.x=radial.x*(surface-.002);point.z=radial.z*(surface-.002)+.011
		points[i]=point
	return _mesh_vertices(mesh,points)

static func _hair(p: Array,role: String) -> void:
	if role in ["servant","builder"]:
		_approved_short_hair(p,role);return
	var material:=hair(role)
	var short_hair:=role in ["resident","servant","builder","vintner"]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE);var rows:=_n(18,8,6);var columns:=_n(40,24,14)
	for row in range(rows):
		for col in range(columns):
			var pts: Array[Vector3]=[];var uv: Array[Vector2]=[];var tints: Array=[]
			for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var u:=float(pair.y)/columns;var v:=float(pair.x)/rows;var a:=u*TAU
				var front: float=smoothstep(0.05,0.55,-sin(a))
				var bottom: float=(-0.025 if short_hair else -0.063)+front*((0.091 if short_hair else (0.141 if role=="instructor" else 0.128))+sin(a*3+0.4)*0.012+sin(a*6.0)*0.004)+sin(a*5)*0.004
				var y:=lerpf(bottom,0.171,v);var yy: float=(y-0.008)/0.163
				var radius:=sqrt(maxf(0.00001,1.0-yy*yy))
				var wave: float=0.0017*sin(a*7+v*5)
				pts.append(Vector3(cos(a)*(0.109*radius+wave),y,sin(a)*(0.110*radius+wave)+0.011));uv.append(Vector2(u,v));var shade:=0.86+0.12*sin(v*PI*0.65);tints.append(Color(shade,shade,shade))
			_quad(st,pts,uv,false,tints)
	_add(p,_finish(st),Vector3.ZERO,material)
	var first_lock:int=p.size()
	if role=="stonecutter":
		for i in range(_n(16,10,6)):
			var a:=float(i)*TAU/float(_n(16,10,6));var center:=Vector3(cos(a)*0.096,0.064+sin(float(i)*1.7)*0.025,sin(a)*0.078+0.026)
			var path: Array=[]
			for j in range(7):
				var t:=float(j)/6;path.append(center+Vector3(cos(t*TAU)*0.017,sin(t*TAU)*0.021,t*0.014))
			_hair_lock(p,path,0.017,0.007,material)
		_oval(p,Vector3(0,0.092,0.11),Vector3(0.066,0.059,0.059),material)
		curve(p,[Vector3(-0.058,0.094,0.096),Vector3(0,0.130,0.119),Vector3(0.058,0.094,0.096)],0.008,"cloth",0.45)
	else:
		# Broad swept waves keep the forehead and brows readable.
		for i in range(_n(5,4,3)):
			var t:=float(i)/float(_n(4,3,2))
			var x: float=-0.065+t*0.045
			if role=="instructor":
				_hair_lock(p,[Vector3(x,0.08+0.025*t,-0.066),Vector3(x+0.019,0.148,-0.028),Vector3(x+0.035,0.156,0.039),Vector3(x+0.028,0.073,0.101)],0.024,0.007,material)
			else:
				_hair_lock(p,[Vector3(x,0.068+0.031*t,-0.068+0.003*t),Vector3(x+0.029,0.129+0.023*t,-0.065+0.045*t),Vector3(0.056+0.017*t,0.132-0.014*t,-0.034+0.05*t),Vector3(0.098,0.066-0.007*t,0.006+0.043*t)],0.027,0.008,material)
		if role in ["servant","resident","builder"]:
			_hair_lock(p,[Vector3(-0.062,0.096,-0.063),Vector3(-0.078,0.084,-0.063),Vector3(-0.079,0.040,-0.052),Vector3(-0.067,0.026,-0.052)],0.013,0.005,material)
		for side: int in [-1,1]:
			for i in range(_n(3,2,2)):
				var z: float=0.015+float(i)*0.025
				_hair_lock(p,[Vector3(float(side)*0.068,0.123,z),Vector3(float(side)*0.101,0.063,z+0.012),Vector3(float(side)*0.108,0.014 if short_hair else -0.010,z+0.005),Vector3(float(side)*(0.105 if short_hair else 0.082),-0.016 if short_hair else -0.058,z+0.018)],0.022,0.006,material)
	if role!="stonecutter":
		for i in range(_n(7,5,3)):
			var a:=float(i)/float(_n(6,4,2))*PI
			_hair_lock(p,[Vector3(cos(a)*0.05,0.139,sin(a)*0.055+0.021),Vector3(cos(a)*0.093,0.075,sin(a)*0.086+0.023),Vector3(cos(a)*0.107,0.019 if short_hair else -0.009,sin(a)*0.091+0.025),Vector3(cos(a)*(0.095 if short_hair else 0.083),(-0.026 if short_hair else -0.067)+sin(a*4)*0.009,sin(a)*0.076+0.03)],0.025,0.005,material)
	if role=="instructor":
		var cap:Array=_cap_triangles(p[first_lock-1].mesh)
		for i in range(first_lock,p.size()):p[i].mesh=_seat_hair_edges(p[i].mesh,cap)
	if role in ["lumberjack","farmer"]:
		var braid_origin:=Vector3(0.0,-0.014,0.122) if role=="lumberjack" else Vector3(-0.092,-0.02,0.045)
		var length:=0.43 if role=="lumberjack" else 0.39
		for strand in range(3):
			var path: Array=[]
			for i in range(_n(22,15,10)):
				var t:=float(i)/float(_n(21,14,9));var a:=t*TAU*3.5+float(strand)*TAU/3.0
				path.append(braid_origin+Vector3(sin(a)*0.021,-t*length,cos(a)*0.018+(0.018*t if role=="lumberjack" else -t*0.15)))
			curve(p,path,0.016,material if strand!=1 else "hair_red_light",0.9,true)
		var end: Vector3=braid_origin+Vector3(0,-length,0.018 if role=="lumberjack" else -0.15)
		_cylinder(p,end+Vector3(0,0.027,0),0.026,0.014,"cloth")
		curve(p,[end+Vector3(-0.008,0.018,0),end+Vector3(0,-0.023,0),end+Vector3(0.011,-0.033,0.008)],0.018,material,0.4,true)
	elif role=="instructor":
		_add(p,_loft([Vector4(-0.255,0.020,0.014,0.122),Vector4(-0.213,0.038,0.024,0.143),Vector4(-0.120,0.035,0.030,0.151),Vector4(-0.035,0.026,0.020,0.133),Vector4(0.002,0.022,0.022,0.124)],0.001),Vector3.ZERO,material)
		for i in range(_n(4,2,1)):
			var x: float=(float(i)/float(_n(3,1,1))-0.5)*0.049
			_hair_lock(p,[Vector3(x*0.5,0.0,0.139),Vector3(x,-0.07,0.171),Vector3(x-0.004,-0.17,0.177),Vector3(x+0.01,-0.253,0.140)],0.016,0.004,material)
		_cylinder(p,Vector3(0,-0.013,0.133),0.028,0.014,"leather_dark")
static func _hat(p: Array) -> void:
	# Asymmetric shallow brim with a woven edge and a teal cloth band.
	_add(p,_loft([Vector4(0.089,0.107,0.102,0.015),Vector4(0.09,0.196,0.171,0.017),Vector4(0.102,0.198,0.173,0.017),Vector4(0.112,0.112,0.106,0.015)]),Vector3.ZERO,"straw")
	_add(p,_loft([Vector4(0.104,0.112,0.103,0.015),Vector4(0.173,0.098,0.092,0.015),Vector4(0.196,0.074,0.072,0.016),Vector4(0.205,0.02,0.018,0.016)]),Vector3.ZERO,"straw")
	_add(p,_loft([Vector4(0.112,0.112,0.103,0.015),Vector4(0.143,0.108,0.100,0.015)]),Vector3.ZERO,"cloth")
	for i in range(_n(4,2,0)):
		var path: Array=[];var radius: float=0.128+float(i)*0.018
		for n in range(33):
			var a:=float(n)*TAU/32.0;path.append(Vector3(cos(a)*radius,0.104,sin(a)*radius*0.86+0.015))
		curve(p,path,0.002,"stitch")

static func tool(role: String) -> Array:
	var p: Array=[]
	if role in ["resident","servant"]:return p
	if role=="farmer":
		_cylinder(p,Vector3(0,0.16,0),0.018,0.85,"wood")
		_box(p,Vector3(0,0.56,-0.07),Vector3(0.145,0.025,0.19),"metal",Vector3(-0.23,0,0))
	elif role=="lumberjack":
		curve(p,[Vector3(0,-0.27,0),Vector3(-0.01,0.02,0),Vector3(0.009,0.29,0),Vector3(0.0,0.36,0)],0.021,"wood")
		# Curved wedge, broad cutting edge and narrow neck.
		var outline: Array[Vector2]=[Vector2(-0.044,0.335),Vector2(0.02,0.371),Vector2(0.13,0.423),Vector2(0.19,0.374),Vector2(0.20,0.303),Vector2(0.16,0.238),Vector2(0.025,0.289),Vector2(-0.044,0.289)]
		_add(p,_extrude(outline,0.024),Vector3.ZERO,"metal")
	elif role=="vintner":
		_cylinder(p,Vector3(0,0.005,0),0.014,0.14,"wood")
		curve(p,[Vector3(0,0.068,0),Vector3(0.038,0.12,0),Vector3(0.031,0.153,0),Vector3(0.004,0.165,0)],0.012,"metal",0.27,true)
	elif role=="stonecutter":
		_cylinder(p,Vector3(0,0.045,0),0.017,0.29,"wood")
		_box(p,Vector3(0,0.178,0),Vector3(0.149,0.075,0.072),"metal")
	else:
		var small:=role=="instructor"
		_cylinder(p,Vector3(0,0.05,0),0.012 if small else 0.019,0.26 if small else 0.43,"wood")
		_cylinder(p,Vector3(0,0.18 if small else 0.255,0),0.029 if small else 0.069,0.09 if small else 0.20,"wood",Vector3(0,0,PI*0.5))
		for side: int in [-1,1]:_cylinder(p,Vector3(float(side)*(0.046 if small else 0.101),0.18 if small else 0.255,0),0.028 if small else 0.065,0.003,"wood_end",Vector3(0,0,PI*0.5))
	return p

static func _extrude(outline: Array[Vector2],thickness: float) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE)
	var indices:=Geometry2D.triangulate_polygon(PackedVector2Array(outline))
	for front in [true,false]:
		for i in range(0,indices.size(),3):
			for j: int in ([0,2,1] if front else [0,1,2]):
				var point:=outline[indices[i+j]];st.set_smooth_group(-1);st.set_uv(point);st.add_vertex(Vector3(point.x,point.y,-thickness if front else thickness))
	for i in range(outline.size()):
		var a:=outline[i];var b:=outline[(i+1)%outline.size()]
		_quad(st,[Vector3(a.x,a.y,-thickness),Vector3(a.x,a.y,thickness),Vector3(b.x,b.y,thickness),Vector3(b.x,b.y,-thickness)],[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)])
	return _finish(st)
