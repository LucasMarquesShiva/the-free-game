extends SceneTree
const Models = preload("res://presentation/approved_buildings.gd")
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func verify(condition: bool, message: String) -> void:
	assert(condition,message)
	checks += 1
func run() -> void:
	for kind in ["hall","training"]:
		var model: Node3D = Models.building(kind)
		var mesh: ArrayMesh = model.get_node("Architecture").mesh
		var bounds := mesh.get_aabb()
		verify(bounds.position.y >= -0.01,kind+": modelo apoiado no solo")
		verify(bounds.size.x < 7.5 and bounds.size.z < 7.5,kind+": cabe em três células")
		verify(bounds.size.y > 6.0 and bounds.size.y < 9.0,kind+": proporção vertical")
		verify(model.get_child_count() == 2,kind+": arquitetura 3D agrupada")
		verify(model.get_meta("draw_calls") <= 9,kind+": orçamento de superfícies")
		verify(model.get_meta("roof_tiles") > 500,kind+": telhas individuais")
		for surface in range(mesh.get_surface_count()):
			verify(mesh.surface_get_name(surface) in ["stone","plaster","wood","roof","cloth","glass","foliage","metal"],kind+": superfície identificada para texturas")
			var arrays := mesh.surface_get_arrays(surface)
			var valid_normals := true
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				valid_normals = valid_normals and normal.is_finite() and normal.length() > 0.99
			verify(valid_normals,kind+": normais válidas")
		var another: Node3D = Models.building(kind)
		verify(another.get_node("Architecture").mesh == mesh,kind+": cache da malha")
		another.free()
		print("APPROVED_MODEL ",kind," bounds=",bounds," tiles=",model.get_meta("roof_tiles")," draws=",model.get_meta("draw_calls"))
		model.free()
	var delegated: Node3D = Models.building("house")
	verify(delegated.name == "ApprovedCivil_house","Casa delegada ao modelo da prancha")
	verify(delegated.get_meta("catalog_id") == "bld_02_casas","Casa mantém identidade do catálogo")
	delegated.free()
	print("APPROVED_BUILDINGS_PASS ",checks," checks")
	quit()
