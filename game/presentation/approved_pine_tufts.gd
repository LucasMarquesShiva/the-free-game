extends RefCounted
## Exclusive pine candidate. Existing oak, stump and rock meshes are untouched.
const Original = preload("res://presentation/approved_environment.gd")
static var _meshes: Dictionary = {}
static var _spray_ranges: Array[Vector2i] = []
static var audit_original: bool = false
static var last_structure := PackedVector3Array()
static var _envelope: AABB

static func tree(seed_value: int = 1) -> Node3D:
 if posmod(seed_value, 17) <= 4:
  return Original.tree(seed_value)
 var variant: int = posmod(seed_value, 6)
 if not _meshes.has(variant):
  _meshes[variant] = load("res://assets/approved/pine-tufts/pine-%d.res" % variant)
 var node: Node3D = Original._instance(_meshes[variant], "ApprovedPine", variant)
 node.set_meta("bounds", (_meshes[variant] as ArrayMesh).custom_aabb)
 return node

static func _pine(variant: int) -> ArrayMesh:
 _spray_ranges.clear()
 var old_mesh: ArrayMesh = load("res://assets/approved/environment-lod/pine-%d.res" % variant)
 _envelope = old_mesh.get_aabb()
 var g := Original.Geometry.new(88127+variant*691)
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
  Original._tube(g,a,b,ra,rb,bark,11)
  if ring<4:
   g.micro_detail=true
   for ridge in range(7):
    var angle := ridge*TAU/7.0+0.08*ring
    var outward := Vector3(cos(angle),0,sin(angle))
    Original._tube(g,a+outward*ra*0.98+Vector3.UP*0.025,b+outward*rb*0.98,0.023,0.011,g.shade(Color("423c2e")),4)
  g.micro_detail=false
 for i in range(6):
  var angle := i*TAU/6.0+g.rng.randf_range(-0.20,0.20)
  var outward := Vector3(cos(angle),0,sin(angle))
  Original._tube(g,Vector3.UP*0.43,outward*g.rng.randf_range(0.52,0.84)+Vector3.UP*0.015,0.125,0.016,bark,6)
 # Lower bare branches show the trunk and break the repetitive conical outline.
 for i in range(5):
  var angle := i*2.39
  var from := Vector3.UP*(0.95+i*0.16)
  var to := from+Vector3(cos(angle)*0.62,-0.11,sin(angle)*0.62)
  Original._tube(g,from,to,0.045,0.009,bark,5)
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
   Original._tube(g,start,end,0.052*(1.0-t)+0.012,0.008,bark,5)
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
 Original._tube(g,Vector3.UP*(height*0.90)+lean,Vector3.UP*(height*1.015)+lean,0.13,0.002,Color("587032"),7)
 var result: ArrayMesh = g.finish()
 var structural := PackedVector3Array()
 var begin: int = 0
 for region: Vector2i in _spray_ranges:
  structural.append_array(g.positions.slice(begin, region.x))
  begin = region.y
 structural.append_array(g.positions.slice(begin))
 last_structure = structural
 var reference: ArrayMesh = load("res://assets/approved/environment-lod/pine-%d.res" % variant)
 result.custom_aabb = reference.get_aabb()
 return result

static func _spray(g: RefCounted, at: Vector3, direction: Vector3, length: float, breadth: float, tint: Color) -> void:
 var start: int = g.positions.size()
 var index_start: int = g.indices.size()
 var silhouette_start: int = g.silhouette_indices.size()
 # Advance the original generator exactly; later structural branches keep their RNG.
 Original._spray(g, at, direction, length, breadth, tint)
 var original_vertices: PackedVector3Array = g.positions.slice(start)
 if audit_original:
  _spray_ranges.append(Vector2i(start, g.positions.size()))
  return
 g.positions.resize(start); g.normals.resize(start); g.colors.resize(start)
 g.indices.resize(index_start); g.silhouette_indices.resize(silhouette_start)
 var side: Vector3 = Vector3.UP.cross(direction).normalized()
 if side.length_squared() < 0.1: side = Vector3.RIGHT
 var up: Vector3 = direction.cross(side).normalized()
 var frame := Basis(direction, up, side)
 var low := Vector3(INF, INF, INF)
 var high := Vector3(-INF, -INF, -INF)
 for point: Vector3 in original_vertices:
  var local: Vector3 = frame.transposed() * (point - at)
  low = low.min(local); high = high.max(local)
 var centers: Array[Vector3] = [Vector3(-0.03*length, 0.01, -0.07*breadth), Vector3(0.13*length, -0.015, 0.10*breadth), Vector3(0.36*length, -0.045, -0.03*breadth)]
 var reaches: Array[float] = [0.82, 0.67, 0.55]
 var turns: Array[float] = [-0.39, 0.43, -0.06]
 var widths: Array[float] = [0.53, 0.50, 0.47]
 # Three overlapping closed branchlets replace the single broad leaf-shaped body.
 for tuft: int in range(3):
  var d := Vector3(1.0, -0.09 - float(tuft)*0.015, turns[tuft]).normalized()
  var lateral := Vector3(-d.z, 0.0, d.x).normalized()
  var stem: Vector3 = centers[tuft]
  var reach: float = length * reaches[tuft]
  var middle: Vector3 = stem + d * reach * 0.46 + Vector3.UP * breadth * 0.10
  var finish: Vector3 = stem + d * reach - Vector3.UP * breadth * 0.16
  var w: float = breadth * widths[tuft]
  var local_points: Array[Vector3] = [stem, finish, middle+lateral*w, middle+Vector3.UP*w*0.46, middle-lateral*w*0.87, middle-Vector3.UP*w*0.34]
  var points: Array[Vector3] = []
  for v: Vector3 in local_points:
   points.append((at + frame * v.clamp(low, high)).clamp(_envelope.position, _envelope.end))
  var top_tint: Color = tint.lerp(Color("7d8942"), 0.15 + 0.06*float(tuft))
  var colors: Array[Color] = [tint.darkened(0.13), top_tint.lightened(0.085), tint, top_tint.lightened(0.075), tint.lightened(0.025), tint.darkened(0.16)]
  _octahedron(g, points, colors)
 # An asymmetric fine terminal shoot keeps the tip frayed without open cards.
 var tip_points: Array[Vector3] = [Vector3(0.51*length,-0.06,0.02*breadth),Vector3(0.89*length,-0.14,-0.14*breadth),Vector3(0.62*length,0.018,0.21*breadth),Vector3(0.63*length,-0.09,0.09*breadth)]
 for i: int in range(4): tip_points[i] = (at + frame * tip_points[i].clamp(low, high)).clamp(_envelope.position, _envelope.end)
 var tip_colors: Array[Color] = [tint, tint.lightened(0.11), tint.lightened(0.09), tint.darkened(0.09)]
 var center := Vector3.ZERO
 for point: Vector3 in tip_points: center += point * 0.25
 for ids: Vector3i in [Vector3i(0,1,2),Vector3i(0,3,1),Vector3i(0,2,3),Vector3i(1,3,2)]:
  _face(g, tip_points, tip_colors, ids, center)
 _spray_ranges.append(Vector2i(start, g.positions.size()))

static func _octahedron(g: RefCounted, points: Array[Vector3], colors: Array[Color]) -> void:
 var center: Vector3 = (points[0] + points[1]) * 0.5
 for i: int in range(4):
  var edge: int = 2 + i
  var next: int = 2 + (i+1)%4
  _face(g, points, colors, Vector3i(0,edge,next), center)
  _face(g, points, colors, Vector3i(1,next,edge), center)

static func _face(g: RefCounted, points: Array[Vector3], colors: Array[Color], ids: Vector3i, center: Vector3) -> void:
 var a: Vector3 = points[ids.x]; var b: Vector3 = points[ids.y]; var c: Vector3 = points[ids.z]
 var normal: Vector3 = (b-a).cross(c-a).normalized()
 if normal.dot((a+b+c)/3.0-center) < 0.0:
  var swap: int = ids.y; ids.y = ids.z; ids.z = swap
  b = points[ids.y]; c = points[ids.z]; normal = -normal
 var start: int = g.positions.size()
 for id: int in [ids.x,ids.y,ids.z]:
  var point: Vector3 = points[id]
  g.positions.append(Vector3(point.x,maxf(0.0,point.y),point.z))
  # Mostly planar shading keeps the tuft solid; a small radial blend softens creases.
  var radial: Vector3 = (point-center).normalized()
  g.normals.append(normal.lerp(radial,0.20).normalized())
  g.colors.append(colors[id].lerp(colors[id].srgb_to_linear(),0.4))
 g.indices.append_array(PackedInt32Array([start,start+2,start+1]))
 g.silhouette_indices.append_array(PackedInt32Array([start,start+2,start+1]))
