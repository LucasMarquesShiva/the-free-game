extends RefCounted
## Diagnostic candidates only. Does not alter project settings, shaders or production sources.
## Camera projection/near/far and the 4096 directional atlas remain unchanged.
const PROFILES := ["baseline", "msaa2_ortho", "msaa2_pssm2"]

static func apply(world: Node3D, profile: String) -> Dictionary:
	assert(profile in PROFILES)
	var sun: DirectionalLight3D
	for child in world.get_children():
		if child is DirectionalLight3D:
			sun = child
	assert(sun != null)
	assert(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) == 4096)
	var viewport := world.get_viewport()
	# Explicit reset makes each candidate independently reproducible.
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_max_distance = 150.0
	sun.light_angular_distance = 0.65
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	match profile:
		"msaa2_ortho":
			viewport.msaa_3d = Viewport.MSAA_2X
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_blend_splits = false
		"msaa2_pssm2":
			viewport.msaa_3d = Viewport.MSAA_2X
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			# Village depth is near85m; default0.1 ends the first split at28.45m.
			# A midpoint split uses the first map for the visible village.
			sun.directional_shadow_split_1 = 0.5
	return {"profile":profile,"msaa_enum":viewport.msaa_3d,"fxaa":true,
		"shadow_mode_enum":sun.directional_shadow_mode,"blend_splits":sun.directional_shadow_blend_splits,
		"split_1":sun.directional_shadow_split_1,"angular_distance":sun.light_angular_distance,
		"atlas_size":4096,"camera_near":world.camera.near,"camera_far":world.camera.far,
		"shadow_max_distance_ignored_by_orthographic_camera":sun.directional_shadow_max_distance}
