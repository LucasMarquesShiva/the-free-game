extends RefCounted
## Pátios de terra independentes dos materiais arquitetônicos.
## A malha só desce na margem livre; apoios existentes conservam y=0,13.
const TOP := 0.13
const EDGE := 0.008
const STEP := 0.16
static var _material: ShaderMaterial

static func prepare(architecture: ArrayMesh, size: float) -> Dictionary:
	var count := ceili(size/STEP)
	var stride := size/count
	var half := size*0.5
	var protected := PackedByteArray()
	protected.resize((count+1)*(count+1))
	var support_triangles := 0
	for surface in range(architecture.get_surface_count()):
		var data := architecture.surface_get_arrays(surface)
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var a := points[indices[i]]
			var b := points[indices[i+1]]
			var c := points[indices[i+2]]
			if minf(a.y,minf(b.y,c.y))>0.26: continue
			var lo := Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
			var hi := Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
			# Proteção conservadora para pés, postes, canteiros e pedras existentes.
			var rect := Rect2(lo,hi-lo).grow(0.06)
			support_triangles += 1
			var x0 := clampi(floori((rect.position.x+half)/stride)-1,0,count)
			var x1 := clampi(ceili((rect.end.x+half)/stride)+1,0,count)
			var z0 := clampi(floori((rect.position.y+half)/stride)-1,0,count)
			var z1 := clampi(ceili((rect.end.y+half)/stride)+1,0,count)
			for z in range(z0,z1+1):
				for x in range(x0,x1+1): protected[z*(count+1)+x]=1
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for z in range(count+1):
		for x in range(count+1):
			var p := Vector2(-half+x*stride,-half+z*stride)
			var kept := protected[z*(count+1)+x]==1
			# Unicamente pontos externos sem apoio recebem contorno ondulado.
			if not kept:
				if x==0 or x==count: p.x-=signf(p.x)*(0.025+0.065*_wave(p.y,1.7))
				if z==0 or z==count: p.y-=signf(p.y)*(0.025+0.065*_wave(p.x,4.3))
			var margin := minf(half-absf(p.x),half-absf(p.y))
			var width := 0.25+0.14*_wave(p.x+p.y*0.65,0.3)
			var height := TOP if kept else lerpf(EDGE,TOP,smoothstep(0.09,width,margin))
			vertices.append(Vector3(p.x,height,p.y))
			colors.append(Color((height-EDGE)/(TOP-EDGE),1.0 if kept else 0.0,0.0,1.0))
			uvs.append((p+Vector2.ONE*half)/size)
	var indices := PackedInt32Array()
	for z in range(count):
		for x in range(count):
			var a := z*(count+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+count+2,a,a+count+2,a+count+1]))
	# Fecha somente trechos da margem que precisaram continuar altos por um apoio.
	# Evita a aparência de lâmina suspensa sem recolocar a caixa quadrada inteira.
	var border: Array[int] = []
	for x in range(count+1): border.append(x)
	for z in range(1,count+1): border.append(z*(count+1)+count)
	for x in range(count-1,-1,-1): border.append(count*(count+1)+x)
	for z in range(count-1,0,-1): border.append(z*(count+1))
	for i in range(border.size()):
		var a := vertices[border[i]]
		var b := vertices[border[(i+1)%border.size()]]
		if maxf(a.y,b.y)<=EDGE+0.0001: continue
		var low_a := Vector3(a.x,EDGE,a.z)
		var low_b := Vector3(b.x,EDGE,b.z)
		for triangle in [[a,low_a,low_b],[a,low_b,b]]:
			if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<0.0000000001: continue
			var start := vertices.size()
			for point in triangle:
				vertices.append(point)
				colors.append(Color(0,0,0,1))
				uvs.append((Vector2(point.x,point.z)+Vector2.ONE*half)/size)
			indices.append_array(PackedInt32Array([start,start+1,start+2]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]; var b := indices[i+1]; var c := indices[i+2]
		var n := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a]+=n;normals[b]+=n;normals[c]+=n
	for i in range(normals.size()): normals[i]=normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_name(0,"earth_yard")
	return {"mesh":mesh,"vertices":vertices.size(),"triangles":indices.size()/3,"protected":protected,"count":count,"size":size,"support_triangles":support_triangles}

static func _wave(value: float, phase: float) -> float:
	return clampf(0.5+sin(value*3.1+phase)*0.29+sin(value*7.7-phase)*0.15,0.0,1.0)

static func instantiate(asset: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name="EarthYard"
	node.mesh=asset.mesh
	if _material==null:
		_material=ShaderMaterial.new()
		_material.shader=load("res://assets/approved/earth-yard.gdshader")
		_material.set_shader_parameter("earth_tex",load("res://assets/approved/earth-albedo.png"))
		_material.set_shader_parameter("meadow_tex",load("res://assets/approved/meadow-albedo.png"))
	# Override keeps this dedicated material through construction's height clipping.
	# The entire yard is below every nonnegative building-stage cutoff (>=0,5 m).
	node.material_override=_material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
