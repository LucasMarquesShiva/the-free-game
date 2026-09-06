extends SceneTree
## Isolated rendering benchmark, not an FPS claim about the complete game.
const People = preload("res://presentation/approved_people.gd")
var persons: Array[Node3D]=[]
var times: Array[float]=[]
var cpu_times: Array[float]=[]
var draws: Array[float]=[]
var primitives: Array[float]=[]
var gpu_times: Array[float]=[]
var render_cpu_times: Array[float]=[]
var warmup:=90
var samples:=240
var current_frame:=0
var last_tick:=0
var phase:=0.0
var tier:=0
var camera_size:=30.0
var output:="user://approved-people-benchmark-high.json"

func _initialize() -> void:call_deferred("run")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("tier="):tier=int(argument.trim_prefix("tier="))
		if argument.begins_with("camera="):camera_size=float(argument.trim_prefix("camera="))
		if argument.begins_with("output="):output=argument.trim_prefix("output=")
	root.size=Vector2i(1280,720);root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	Engine.max_fps=0
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("d4d8c5");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=0.4;env.tonemap_mode=Environment.TONE_MAPPER_ACES;env.ssao_enabled=true;environment.environment=env;world.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,145,0);light.light_energy=1.0;light.shadow_enabled=true;world.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=camera_size;camera.position=Vector3(12,17,-18);world.add_child(camera);camera.look_at(Vector3(0,0.5,0));camera.current=true
	var plane:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(90,90);plane.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("627b51");mat.roughness=1;plane.material_override=mat;world.add_child(plane)
	var setup_start:=Time.get_ticks_usec()
	for i in range(48):
		var person:=People.create(People.APPROVED[i%8],i,tier)
		person.position=Vector3((float(i%8)-3.5)*1.8,0,(float(i/8)-2.5)*2.1);person.rotation.y=-0.28;world.add_child(person);persons.append(person)
	print("BENCHMARK_SETUP tier=",tier," people=48 ms=",float(Time.get_ticks_usec()-setup_start)/1000.0)
	last_tick=Time.get_ticks_usec()
	process_frame.connect(frame)

func frame() -> void:
	var start:=Time.get_ticks_usec();var elapsed:=float(start-last_tick)/1000.0;last_tick=start;phase+=elapsed*0.006
	for i in range(persons.size()):People.animate(persons[i],phase+float(i)*0.47,i%4!=0,i%4==0,i%3==0,"wood" if i%2==0 else "food")
	var cpu:=float(Time.get_ticks_usec()-start)/1000.0
	if current_frame>=warmup:
		times.append(elapsed);cpu_times.append(cpu);draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()));render_cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	current_frame+=1
	if times.size()>=samples:
		process_frame.disconnect(frame)
		var result:={"tier":tier,"people":48,"resolution":"1280x720","camera_size":camera_size,"rendering_method":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":"disabled","warmup_frames":warmup,"sample_frames":samples,"frame_ms":stats(times),"animation_cpu_ms":stats(cpu_times),"render_cpu_ms":stats(render_cpu_times),"render_gpu_ms":null if gpu_times.max()==0.0 else stats(gpu_times),"gpu_timer_available":gpu_times.max()>0.0,"draw_calls":stats(draws),"rendered_primitives":stats(primitives),"scope":"Isolated characters, one shadowed light, ground, SSAO and 4xMSAA; excludes game simulation, terrain, UI and buildings."}
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("BENCHMARK_RESULT ",JSON.stringify(result))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
		quit()

func stats(values: Array[float]) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in values:total+=value
	return {"mean":total/float(values.size()),"median":sorted[sorted.size()/2],"p95":sorted[int(float(sorted.size()-1)*0.95)],"max":sorted[-1]}
