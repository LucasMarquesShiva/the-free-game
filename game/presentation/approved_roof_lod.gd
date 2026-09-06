extends RefCounted
## Index-only roof LODs keep the original high-detail triangles/attributes intact.
## Same analytic tile surface, pigment, UVs, thickness and instance transforms.
const MID_ERROR := 0.018
const FAR_ERROR := 0.031

static func attach(high: ArrayMesh, original: RefCounted, point: Callable, pigment: Callable) -> ArrayMesh:
 var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
 # Feed the same original data to Godot once, avoiding a second encode of normals.
 arrays[Mesh.ARRAY_VERTEX]=original.vertices.duplicate()
 arrays[Mesh.ARRAY_NORMAL]=original.normals.duplicate()
 arrays[Mesh.ARRAY_COLOR]=original.colors.duplicate()
 arrays[Mesh.ARRAY_TEX_UV]=original.uvs.duplicate()
 arrays[Mesh.ARRAY_INDEX]=original.indices.duplicate()
 var lods: Dictionary = {}
 for config: Vector3 in [Vector3(2,8,MID_ERROR),Vector3(2,4,FAR_ERROR)]:
  lods[config.z] = _append_level(arrays, int(config.x), int(config.y), point, pigment)
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
 mesh.custom_aabb = high.get_aabb()
 mesh.surface_set_name(0,high.surface_get_name(0))
 mesh.surface_set_material(0,high.surface_get_material(0))
 mesh.set_meta("roof_lod_high_vertices",high.surface_get_array_len(0))
 mesh.set_meta("roof_lod_triangles",[176,104,56])
 return mesh

static func _append_level(arrays: Array, rows: int, columns: int, point: Callable, pigment: Callable) -> PackedInt32Array:
 var result := PackedInt32Array()
 for row: int in range(rows):
  for col: int in range(columns):
   var t0 := float(row)/rows;var t1 := float(row+1)/rows
   var u0 := float(col)/columns;var u1 := float(col+1)/columns
   var a: Vector3=point.call(t0,u0);var b: Vector3=point.call(t0,u1)
   var c: Vector3=point.call(t1,u1);var d: Vector3=point.call(t1,u0)
   _quad(arrays,result,[a,b,c,d],[pigment.call(t0,u0),pigment.call(t0,u1),pigment.call(t1,u1),pigment.call(t1,u0)])
   var bottom := Vector3.UP*0.035
   if row==rows-1:_quad(arrays,result,[d-bottom,c-bottom,c,d],_solid(Color("a39c91")))
   if row==0:_quad(arrays,result,[a,b,b-bottom,a-bottom],_solid(Color("999186")))
   if col==0:_quad(arrays,result,[a-bottom,d-bottom,d,a],_solid(Color("aaa296")))
   if col==columns-1:_quad(arrays,result,[b,c,c-bottom,b-bottom],_solid(Color("aaa296")))
   _quad(arrays,result,[d-bottom,c-bottom,b-bottom,a-bottom],_solid(Color("999186")))
 return result

static func _solid(color: Color) -> Array[Color]:
 return [color,color,color,color]

static func _quad(arrays: Array, indices: PackedInt32Array, positions: Array[Vector3], colors: Array[Color]) -> void:
 for face: Vector3i in [Vector3i(0,1,2),Vector3i(0,2,3)]:
  var offset: int = arrays[Mesh.ARRAY_VERTEX].size()
  var edge_a := positions[face.y]-positions[face.x]
  var edge_b := positions[face.z]-positions[face.x]
  var normal := edge_a.cross(edge_b).normalized()
  var uv_a := Vector2(edge_a.x+edge_a.z,edge_a.y)
  var uv_b := Vector2(edge_b.x+edge_b.z,edge_b.y)
  var determinant := uv_a.x*uv_b.y-uv_a.y*uv_b.x
  var tangent := Vector3.RIGHT
  var bitangent := Vector3.FORWARD
  if absf(determinant)>0.00000001:
   tangent=(edge_a*uv_b.y-edge_b*uv_a.y)/determinant
   bitangent=(edge_b*uv_a.x-edge_a*uv_b.x)/determinant
  tangent=(tangent-normal*normal.dot(tangent)).normalized()
  if tangent.is_zero_approx():tangent=normal.cross(Vector3.FORWARD).normalized()
  var handedness := -1.0 if normal.cross(tangent).dot(bitangent)<0.0 else 1.0
  for id: int in [face.x,face.y,face.z]:
   var p: Vector3=positions[id]
   arrays[Mesh.ARRAY_VERTEX].append(p)
   arrays[Mesh.ARRAY_NORMAL].append(normal)
   if arrays[Mesh.ARRAY_TANGENT]!=null:
    arrays[Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,handedness]))
   arrays[Mesh.ARRAY_COLOR].append(colors[id])
   arrays[Mesh.ARRAY_TEX_UV].append(Vector2(p.x+p.z,p.y))
  indices.append_array(PackedInt32Array([offset,offset+2,offset+1]))
