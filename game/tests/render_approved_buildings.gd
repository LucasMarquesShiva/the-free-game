extends SceneTree
const Models = preload("res://presentation/approved_buildings.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1300,1150)
	var studio := Node3D.new()
	root.add_child(studio)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b4ad91")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b6c5cc")
	settings.ambient_light_energy = 0.38
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled = true
	settings.ssao_radius = 0.7
	settings.ssao_intensity = 1.6
	environment.environment = settings
	studio.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe6bb")
	sun.light_energy = 1.08
	sun.rotation_degrees = Vector3(-48,-31,0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	studio.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90,90)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("86876a")
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.02
	studio.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.1
	studio.add_child(camera)
	camera.current = true
	for kind in ["hall","training"]:
		var model: Node3D = Models.building(kind)
		studio.add_child(model)
		var bounds: AABB = model.get_node("Architecture").get_aabb()
		print("APPROVED ",kind," bounds=",bounds," draws=",model.get_meta("draw_calls")," tiles=",model.get_meta("roof_tiles"))
		var target := Vector3(0,3.0 if kind == "hall" else 2.5,0)
		for angle in ["main","front"]:
			camera.position = target+(Vector3(17,16,26) if angle == "main" else Vector3(0,11,29))
			camera.look_at(target)
			for i in range(6):
				await process_frame
			RenderingServer.force_draw(false,0.016)
			var path: String = "user://approved-"+kind+"-"+angle+".png"
			root.get_texture().get_image().save_png(path)
			print("RENDER_SAVED ",path)
		model.queue_free()
		await process_frame
	quit()
