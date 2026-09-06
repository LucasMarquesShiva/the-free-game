extends SceneTree

const Models = preload("res://presentation/frontier_models.gd")
var studio: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600,1100)
	studio = Node3D.new()
	root.add_child(studio)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("7c8873")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c4cf")
	settings.ambient_light_energy = 0.62
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled = true
	settings.ssao_radius = 0.65
	settings.ssao_intensity = 1.3
	environment.environment = settings
	studio.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b2")
	sun.light_energy = 1.55
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	studio.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(65,65)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("657d42")
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.015
	studio.add_child(ground)
	var single := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("kind="):
			single = argument.trim_prefix("kind=")
	var kinds := ["hall","training","house","winery","store","lumber","farm","vineyard","quarry"] if single.is_empty() else [single]
	for i in range(kinds.size()):
		var building: Node3D = Models.tree(77) if kinds[i] == "tree" else Models.building(kinds[i])
		building.position = Vector3((i%3-1)*8.2,0,(i/3-1)*8.4) if single.is_empty() else Vector3.ZERO
		studio.add_child(building)
		if single.is_empty():
			var label := Label3D.new()
			label.text = kinds[i].to_upper()
			label.font_size = 44
			label.pixel_size = 0.008
			label.position = building.position+Vector3(0,0.25,3.1)
			label.rotation_degrees.x = -90
			label.modulate = Color("fff0bf")
			label.outline_modulate = Color("313d31")
			studio.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 35 if single.is_empty() else 11.6
	studio.add_child(camera)
	var target := Vector3(0,1.2,0) if single.is_empty() else Vector3(0,3.4,0)
	camera.position = target+Vector3(24,27,35)
	camera.look_at(target)
	camera.current = true
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://frontier-models-"+("all" if single.is_empty() else single)+".png"
	root.get_texture().get_image().save_png(path)
	print("RENDER_SAVED ",path)
	quit()
