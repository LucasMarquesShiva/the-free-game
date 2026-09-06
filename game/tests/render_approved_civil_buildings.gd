extends SceneTree
const Models = preload("res://presentation/approved_buildings.gd")
const Civil = preload("res://presentation/approved_civil_buildings.gd")
const Materials = preload("res://presentation/approved_materials.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1250,1100)
	var studio := Node3D.new()
	root.add_child(studio)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b4ad91")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b6c5cc")
	settings.ambient_light_energy = 0.40
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled = true
	settings.ssao_radius = 0.6
	settings.ssao_intensity = 1.6
	environment.environment = settings
	studio.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe6bb")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-48,-31,0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	studio.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90,90)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("858669")
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.025
	studio.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	studio.add_child(camera)
	camera.current = true
	var kinds: Array = Civil.KINDS.duplicate()
	var textured := false
	for argument in OS.get_cmdline_user_args():
		if argument == "textures": textured = true
		if argument == "all": kinds = ["hall","training"]+Civil.KINDS
		if argument.begins_with("kind="): kinds = [argument.trim_prefix("kind=")]
	for kind in kinds:
		var model: Node3D = Models.building(kind)
		if textured: Materials.apply(model)
		studio.add_child(model)
		var bounds: AABB = model.get_node("Architecture").get_aabb()
		camera.size = maxf(bounds.size.x*1.43,bounds.size.y*1.30)+0.9
		var target := Vector3(0,bounds.size.y*0.37,0)
		for angle in ["main","front"]:
			camera.position = target+(Vector3(17,17,25) if angle == "main" else Vector3(0,11,29))
			camera.look_at(target)
			for i in range(5): await process_frame
			RenderingServer.force_draw(false,0.016)
			var path: String = "user://approved-civil-"+kind+"-"+angle+("-textured" if textured else "")+".png"
			root.get_texture().get_image().save_png(path)
			print("RENDER_SAVED ",path)
		model.queue_free()
		await process_frame
	quit()
