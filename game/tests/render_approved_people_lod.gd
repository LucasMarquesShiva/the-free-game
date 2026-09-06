extends SceneTree
## Native comparative render: same models, front/profile/back, no image assets.
const People = preload("res://presentation/approved_people.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1536,1440)
	var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(canvas)
	var background:=ColorRect.new();background.color=Color("e5dfcf");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(background)
	var roles: Array[String]=["servant","farmer","instructor"]
	var names: Array[String]=["SERVENTE","HORTICULTORA","INSTRUTOR"]
	var output:="user://approved-people-lod-comparison.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("roles="):
			roles.assign(argument.trim_prefix("roles=").split(","));names.assign(roles)
		if argument.begins_with("output="):output=argument.trim_prefix("output=")
	var views: Array[String]=["Detalhado · tier 0","Médio · tier 1","Distante · tier 2"]
	for row in range(3):
		for column in range(3):
			var viewport:=SubViewport.new();viewport.size=Vector2i(512,424);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X
			root.add_child(viewport)
			var studio:=Node3D.new();viewport.add_child(studio)
			var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("e5dfcf");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d6dce1");env.ambient_light_energy=0.30;env.ssao_enabled=true;env.ssao_radius=0.23;env.ssao_intensity=0.7;env.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.environment=env;studio.add_child(environment)
			var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,145,0);light.light_color=Color("fff3df");light.light_energy=1.0;light.shadow_enabled=true;studio.add_child(light)
			var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-18,-32,0);fill.light_color=Color("dce8f1");fill.light_energy=0.28;studio.add_child(fill)
			var person:=People.create(roles[row],1,column);person.rotation.y=-0.32;studio.add_child(person)
			var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("bbb7aa");mat.roughness=1;floor_mesh.material_override=mat;floor_mesh.position.y=-0.007;studio.add_child(floor_mesh)
			var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.03;camera.position=Vector3(0,1.05,-7);studio.add_child(camera);camera.look_at(Vector3(0,0.90,0));camera.current=true
			var texture:=TextureRect.new();texture.texture=viewport.get_texture();texture.position=Vector2(column*512,48+row*473);texture.size=Vector2(512,424);canvas.add_child(texture)
			var label:=Label.new();label.text=names[row]+" · "+views[column];label.position=Vector2(column*512,8+row*473);label.size=Vector2(512,40);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_color_override("font_color",Color("214c48"));label.add_theme_font_size_override("font_size",23);canvas.add_child(label)
	for i in range(18):await process_frame
	await RenderingServer.frame_post_draw
	var path:=output
	var result:=root.get_texture().get_image().save_png(path)
	print("APPROVED_PEOPLE_RENDER ",path," result=",result)
	quit(0 if result==OK else 1)
