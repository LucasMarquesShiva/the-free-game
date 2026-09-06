extends SceneTree

const Models = preload("res://presentation/frontier_models.gd")
const KINDS := ["hall","house","store","training","lumber","quarry","farm","vineyard","winery"]
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		return
	checks += 1

func run() -> void:
	for kind in KINDS:
		var before := Time.get_ticks_msec()
		var model := Models.building(kind)
		verify(model.get_child_count() <= 2,kind+": geometria agrupada")
		verify(int(model.get_meta("draw_calls")) <= 9,kind+": orçamento de superfícies")
		verify(int(model.get_meta("detail_parts")) >= 80,kind+": detalhes tridimensionais")
		var geometry := model.get_node("Architecture") as MeshInstance3D
		var bounds := geometry.get_aabb()
		verify(bounds.size.is_finite() and bounds.size.y > 0.5,kind+": malha finita")
		for surface in range(geometry.mesh.get_surface_count()):
			var arrays := geometry.mesh.surface_get_arrays(surface)
			var valid_normals := true
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				valid_normals = valid_normals and normal.is_finite() and normal.length() > 0.99
			verify(valid_normals,kind+": normais válidas")
		verify(bounds.position.y >= -0.01,kind+": modelo acima do solo")
		verify(bounds.size.x < 5.0 and bounds.size.z < 5.0,kind+": cabe no lote 2 por 2")
		if kind != "vineyard":
			verify(int(model.get_meta("roof_tiles")) > 60,kind+": telhas individuais")
		print("MODEL ",kind," | bounds ",bounds," | tiles ",model.get_meta("roof_tiles")," | parts ",model.get_meta("detail_parts")," | vertices ",model.get_meta("vertices")," | draws ",model.get_meta("draw_calls")," | ms ",Time.get_ticks_msec()-before)
		var another := Models.building(kind)
		verify(another.get_node("Architecture").mesh == geometry.mesh,kind+": cache compartilhado")
		another.free()
		model.free()
	for i in range(3):
		var tree := Models.tree(i+1)
		verify(tree.get_node("Architecture").mesh.get_aabb().size.y > 4.0,"Árvore ramificada")
		tree.free()
		var rock := Models.rock(i+1)
		verify(rock.get_child_count() == 1,"Pedras agrupadas")
		rock.free()
	print("FRONTIER_MODELS_PASS ",checks," checks")
	quit()
