extends RefCounted
## River-only weighted normals and continuous granite/moss pigment.
## The 18 shared environment meshes, all geometry and native LODs are unchanged.
const Original = preload("res://presentation/approved_environment.gd")
const SurfaceShader = preload("res://assets/approved/river-rocks/organic-stone.gdshader")
static var _meshes: Dictionary = {}
static var _material: ShaderMaterial
static func rock(seed_value: int = 1) -> Node3D:
 var variant: int = posmod(seed_value, 6)
 var node: Node3D = Original.rock(seed_value)
 var geometry: MeshInstance3D = node.get_node("Geometry")
 if not _meshes.has(variant):
  _meshes[variant] = load("res://assets/approved/river-rocks/stone-%d.res" % variant)
 geometry.mesh = _meshes[variant]
 if _material == null:
  _material = ShaderMaterial.new()
  _material.resource_name = "RiverGranite_ContinuousMoss"
  _material.shader = SurfaceShader
  _material.set_shader_parameter("surface_field", load("res://assets/approved/river-rocks/surface-field.png"))
 geometry.material_override = _material
 node.set_meta("river_rock_attributes", true)
 return node
