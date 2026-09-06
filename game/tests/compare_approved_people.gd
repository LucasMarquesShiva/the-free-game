extends SceneTree
## Read-only comparison: approved sheet crops beside real 3D. No runtime sprites.
const People = preload("res://presentation/approved_people.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1536,1440)
	var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(canvas)
	var background:=ColorRect.new();background.color=Color("e5dfcf");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(background)
	var roles: Array[String]=["servant","builder","instructor"]
	var names: Array[String]=["SERVENTE","CONSTRUTOR","INSTRUTOR"]
	var output:="user://approved-people-comparison.png"
	var poses:=false
	var references:={"resident":"01-morador","servant":"02-servente","builder":"04-construtor","farmer":"11-horticultor","lumberjack":"05-lenhador","stonecutter":"07-canteiro","vintner":"19-vinhateiro","instructor":"25-instrutor"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("roles="):
			roles.assign(argument.trim_prefix("roles=").split(","));names.assign(roles)
		if argument.begins_with("output="):output=argument.trim_prefix("output=")
		if argument=="poses=true":poses=true
	var views: Array[String]=["Referência aprovada","Modelo · 3/4","Modelo · perfil","Modelo · costas"]
	if poses:views=["Referência aprovada","Caminhando","Transportando","Trabalhando"]
	for row in range(3):
		for column in range(4):
			if column==0:
				var source:=Image.load_from_file(ProjectSettings.globalize_path("res://../art/catalogo-visual-v1/civis/")+references[roles[row]]+".png")
				if source!=null:
					var reference:=TextureRect.new();var atlas:=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(source);atlas.region=Rect2(170,70,340,535)
					if roles[row]=="builder":atlas.region=Rect2(110,30,390,575)
					if roles[row]=="stonecutter":atlas.region=Rect2(165,10,370,580)
					reference.texture=atlas;reference.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;reference.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;reference.position=Vector2(0,48+row*473);reference.size=Vector2(384,424);canvas.add_child(reference)
				var title:=Label.new();title.text=names[row]+" · referência";title.position=Vector2(0,8+row*473);title.size=Vector2(384,40);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",Color("214c48"));title.add_theme_font_size_override("font_size",20);canvas.add_child(title)
				continue
			var viewport:=SubViewport.new();viewport.size=Vector2i(384,424);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X
			root.add_child(viewport)
			var studio:=Node3D.new();viewport.add_child(studio)
			var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("e5dfcf");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d6dce1");env.ambient_light_energy=0.30;env.ssao_enabled=true;env.ssao_radius=0.23;env.ssao_intensity=0.7;env.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.environment=env;studio.add_child(environment)
			var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,145,0);light.light_color=Color("fff3df");light.light_energy=1.0;light.shadow_enabled=true;studio.add_child(light)
			var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-18,-32,0);fill.light_color=Color("dce8f1");fill.light_energy=0.28;studio.add_child(fill)
			var person:=People.create(roles[row],1);person.rotation.y=[0.0,-0.32,PI*0.5,PI][column];studio.add_child(person)
			if poses:
				person.rotation.y=-0.32;People.animate(person,1.15,column!=3,column==3,column==2,"wood")
			var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("bbb7aa");mat.roughness=1;floor_mesh.material_override=mat;floor_mesh.position.y=-0.007;studio.add_child(floor_mesh)
			var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.03;camera.position=Vector3(0,1.05,-7);studio.add_child(camera);camera.look_at(Vector3(0,0.90,0));camera.current=true
			var texture:=TextureRect.new();texture.texture=viewport.get_texture();texture.position=Vector2(column*384,48+row*473);texture.size=Vector2(384,424);canvas.add_child(texture)
			var label:=Label.new();label.text=names[row]+" · "+views[column];label.position=Vector2(column*384,8+row*473);label.size=Vector2(384,40);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_color_override("font_color",Color("214c48"));label.add_theme_font_size_override("font_size",20);canvas.add_child(label)
	for i in range(18):await process_frame
	await RenderingServer.frame_post_draw
	var path:=output
	var result:=root.get_texture().get_image().save_png(path)
	print("APPROVED_PEOPLE_RENDER ",path," result=",result)
	quit(0 if result==OK else 1)
