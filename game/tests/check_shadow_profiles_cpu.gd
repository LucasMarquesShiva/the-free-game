extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://presentation/approved_world.gd").new()
	root.add_child(world)
	world.camera = Camera3D.new()
	world.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.camera.near = 0.5
	world.camera.far = 280.0
	world.add_child(world.camera)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	var profiles = load("res://tests/shadow_profiles_approved.gd")
	for profile in profiles.PROFILES:
		var result: Dictionary = profiles.apply(world, profile)
		assert(sun.shadow_enabled)
		assert(world.camera.near == 0.5 and world.camera.far == 280.0)
		assert(result.atlas_size == 4096 and sun.light_angular_distance > 0.64)
		assert(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA)
		assert(root.msaa_3d == Viewport.MSAA_4X if profile == "baseline" else root.msaa_3d == Viewport.MSAA_2X)
		print("CPU_SHADOW_PROFILE_VALID ", JSON.stringify(result))
	world.free()
	quit()
