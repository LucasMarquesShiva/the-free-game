extends SceneTree
const Models = preload("res://presentation/approved_civil_buildings.gd")
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func verify(condition: bool, message: String) -> void:
	assert(condition,message)
	checks += 1
func run() -> void:
	for kind in Models.KINDS:
		var model: Node3D = Models.building(kind)
		var geometry: MeshInstance3D = model.get_node("Architecture")
		var mesh: ArrayMesh = geometry.mesh
		var bounds := mesh.get_aabb()
		var max_side := 7.5 if kind in ["store","winery"] else 5.0
		verify(bounds.position.y >= -0.02,kind+": acima do terreno")
		verify(bounds.size.x < max_side and bounds.size.z < max_side,kind+": dentro do lote")
		verify(int(model.get_meta("draw_calls")) <= (10 if model.has_node("EarthYard") else 9),kind+": limite de superfícies")
		verify(model.get_meta("catalog_id") == Models.IDS[kind],kind+": referência correta")
		for surface in range(mesh.get_surface_count()):
			verify(mesh.surface_get_name(surface) in ["stone","plaster","wood","roof","cloth","glass","foliage","metal"],kind+": superfície para material")
			var arrays := mesh.surface_get_arrays(surface)
			var valid := true
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				valid = valid and normal.is_finite() and normal.length() > 0.99
			verify(valid,kind+": normais válidas")
		var second: Node3D = Models.building(kind)
		verify(second.get_node("Architecture").mesh == mesh,kind+": malha compartilhada")
		second.free()
		print("CIVIL_MODEL ",kind," bounds=",bounds," tiles=",model.get_meta("roof_tiles")," parts=",model.get_meta("detail_parts")," vertices=",model.get_meta("vertices"))
		model.free()
	print("APPROVED_CIVIL_BUILDINGS_PASS ",checks," checks")
	quit()
