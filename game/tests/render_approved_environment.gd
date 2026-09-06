extends SceneTree
const Models = preload("res://presentation/approved_environment.gd")
var failures: Array[String]=[]
var checks:=0
var stage:Node3D
var camera:Camera3D

func _initialize()->void:
	call_deferred("run")

func check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures.append(message); push_error(message)

func run()->void:
	var start:=Time.get_ticks_msec()
	for variant in range(6):
		var pine:Node3D=Models.pine(variant)
		var again:Node3D=Models.pine(variant+6)
		var granite:Node3D=Models.rock(variant)
		var mesh:Mesh=pine.get_node("Geometry").mesh
		var bounds:AABB=mesh.get_aabb()
		check(mesh==again.get_node("Geometry").mesh,"Shared pine mesh "+str(variant))
		check(mesh.get_surface_count()==1,"One opaque pine surface "+str(variant))
		check(bounds.position.y>=-0.001 and bounds.size.y>5.0 and bounds.size.y<8.5,"Pine ground/height "+str(variant))
		check(bounds.size.x<5.0 and bounds.size.z<5.0,"Pine crown bounds "+str(variant))
		check(int(pine.get_meta("triangles"))<20000,"Pine triangle budget "+str(variant))
		check(granite.get_node("Geometry").mesh.get_aabb().position.y>=0,"Rock above ground "+str(variant))
		print("ENV_MODEL ",variant," pine_triangles=",pine.get_meta("triangles")," rock_triangles=",granite.get_meta("triangles")," bounds=",bounds)
		pine.free();again.free();granite.free()
	var families := {"pine":0,"oak":0,"stump":0}
	for seed_value in range(34):
		var a:Node3D=Models.tree(seed_value);var b:Node3D=Models.tree(seed_value)
		var kind:String=a.get_meta("environment_kind")
		families[kind]+=1
		check(a.get_node("Geometry").mesh==b.get_node("Geometry").mesh,"Stable family/mesh "+str(seed_value))
		var bounds:AABB=a.get_node("Geometry").mesh.get_aabb()
		check(bounds.position.y>=0 and bounds.size.x<5.6 and bounds.size.z<5.6,"Family footprint "+str(seed_value))
		if kind=="stump":check(bounds.size.y<1.1,"Stump silhouette")
		if kind=="oak":
			check(bounds.size.y>4.2 and bounds.size.y<6.4,"Oak silhouette")
			check(a.get_meta("triangles")<20000,"Oak triangle budget")
		a.free();b.free()
	check(families=={"pine":24,"oak":8,"stump":2},"Deterministic mixed grove proportions")
	print("ENV_FAMILIES ",families)
	print("ENV_BUILD_MS ",Time.get_ticks_msec()-start)
	if DisplayServer.get_name()=="headless":
		print("ENVIRONMENT_TEST ",checks," checks; failures=",failures)
		quit(0 if failures.is_empty() else 1);return
	root.size=Vector2i(1400,1000)
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("c1c5b0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b9d2dc");env.ambient_light_energy=0.36
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":
		env.ssao_enabled=true;env.ssao_radius=1.3;env.ssao_intensity=1.45;env.ssao_power=1.2
	root.msaa_3d=Viewport.MSAA_4X
	world.environment=env;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.light_color=Color("fff0d7");sun.light_energy=0.85 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.06
	sun.rotation_degrees=Vector3(-48,-38,0);sun.shadow_enabled=true
	sun.directional_shadow_max_distance=120;stage.add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(140,140);ground.mesh=plane
	var shader:=Shader.new();shader.code="shader_type spatial; float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);} varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;} void fragment(){float n=h(floor(wp.xz*24.));float broad=h(floor(wp.xz*.6)); ALBEDO=mix(vec3(.21,.27,.095),vec3(.36,.39,.15),n*.45+broad*.22);ROUGHNESS=1.;}"
	var mat:=ShaderMaterial.new();mat.shader=shader;ground.material_override=mat;ground.position.y=-0.005;stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
	var close:=Node3D.new();stage.add_child(close)
	var a:=Models.pine(2);a.position=Vector3(-1.8,0,0);close.add_child(a)
	var b:=Models.pine(4);b.position=Vector3(2,0,1);b.scale=Vector3.ONE*0.69;close.add_child(b)
	var stone:=Models.rock(1);stone.position=Vector3(1.4,0,3.4);close.add_child(stone)
	await capture("close",Vector3(0,2.4,0),11.6)
	close.queue_free();await process_frame
	var deciduous:=Node3D.new();stage.add_child(deciduous)
	var oak:=Models.tree(1);oak.position=Vector3(-1.5,0,0);deciduous.add_child(oak)
	var stump:=Models.stump(1);stump.position=Vector3(1.7,0,2.0);deciduous.add_child(stump)
	var sample_rock:=Models.rock(3);sample_rock.position=Vector3(0.7,0,3.4);sample_rock.scale=Vector3.ONE*0.46;deciduous.add_child(sample_rock)
	await capture("oak-and-stump",Vector3(0,2.0,0),9.2)
	deciduous.queue_free();await process_frame
	var group:=Node3D.new();stage.add_child(group)
	var rng:=RandomNumberGenerator.new();rng.seed=71
	for i in range(150):
		var tree:=Models.tree(i)
		var x:float=(i%15-7)*3.5+rng.randf_range(-0.45,0.45)
		var z:float=(i/15-5)*3.5+rng.randf_range(-0.45,0.45)
		tree.position=Vector3(x,0,z);tree.rotation.y=rng.randf()*TAU
		tree.scale=Vector3.ONE*rng.randf_range(0.72,1.08);group.add_child(tree)
	for i in range(8):
		var rock:=Models.rock(i);rock.position=Vector3(-14+i*4.4,0,19+rng.randf_range(-0.7,0.7));rock.scale=Vector3.ONE*rng.randf_range(0.50,0.95);group.add_child(rock)
	await capture("forest-150",Vector3(0,1.6,0),60)
	var times:Array[float]=[]
	for i in range(90):
		var before:=Time.get_ticks_usec();await process_frame
		if i>=30:times.append((Time.get_ticks_usec()-before)/1000.0)
	times.sort()
	print("ENV_FRAME_SAMPLE ms_median=",times[times.size()/2]," p95=",times[floori(times.size()*0.95)]," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	group.queue_free(); await process_frame
	if ResourceLoader.exists("res://presentation/approved_buildings.gd") and ResourceLoader.exists("res://presentation/approved_people.gd"):
		await village_context()
	print("ENVIRONMENT_TEST ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)

func village_context()->void:
	var buildings:Script=load("res://presentation/approved_buildings.gd")
	var people:Script=load("res://presentation/approved_people.gd")
	var village:=Node3D.new();stage.add_child(village)
	var hall:Node3D=buildings.building("hall"); village.add_child(hall)
	var school:Node3D=buildings.building("training");school.position=Vector3(9.5,0,-3);village.add_child(school)
	var path:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(2.2,15);path.mesh=plane;path.position=Vector3(0,0.012,9)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("9b8860");mat.roughness=1.0;path.material_override=mat;village.add_child(path)
	for i in range(18):
		var tree:=Models.tree(i)
		if i<10:tree.position=Vector3(-13+(i%5)*5,0,-10-(i/5)*3.8)
		else:tree.position=Vector3(-8-(i%2)*3.3,0,-4+(i-10)*2.7)
		tree.rotation.y=i*2.39;tree.scale=Vector3.ONE*(0.8+(i%3)*0.11);village.add_child(tree)
	for i in range(5):
		var rock:=Models.rock(i);rock.position=Vector3(-4.5-i*0.7,0,5+i*1.5);rock.scale=Vector3.ONE*0.52;village.add_child(rock)
	for i in range(4):
		var worker:Node3D=people.create("builder" if i%2==0 else "servant",i+2)
		worker.position=Vector3(1.6+(i%2)*1.8,0,5.0+i*1.2);worker.rotation.y=0.3+i*0.5;village.add_child(worker)
	await capture("village-context",Vector3(0,2.0,1.5),30.0)
	village.queue_free();await process_frame

func capture(label:String,target:Vector3,size:float)->void:
	camera.size=size
	var yaw:=deg_to_rad(28.0);var elevation:=deg_to_rad(42.0)
	camera.position=target+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*70.0
	camera.look_at(target)
	for i in range(10):await process_frame
	RenderingServer.force_draw(false,0.016)
	var path:="user://approved-environment-"+RenderingServer.get_current_rendering_method()+"-"+label+".png"
	root.get_texture().get_image().save_png(path)
	print("ENV_RENDER_SAVED ",path)
