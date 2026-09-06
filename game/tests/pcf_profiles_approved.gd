extends RefCounted
const PROFILES := ["pcss", "pcf"]
static func apply(world: Node3D, profile: String) -> Dictionary:
	assert(profile in PROFILES)
	var sun: DirectionalLight3D
	for child in world.get_children():
		if child is DirectionalLight3D:
			sun = child
	assert(sun != null)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = false
	sun.light_angular_distance = 0.65 if profile == "pcss" else 0.0
	sun.shadow_blur = 1.0
	var viewport := world.get_viewport()
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var atlas: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")
	assert(atlas == 4096)
	return {"profile":profile,"msaa":"2x","fxaa":true,"shadow_maps":1,
		"angular_distance":sun.light_angular_distance,"shadow_blur":sun.shadow_blur,
		"filter_quality":ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"),
		"atlas_size":atlas,"camera_near":world.camera.near,"camera_far":world.camera.far}
