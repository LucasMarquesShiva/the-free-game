extends SceneTree
const Models=preload("res://presentation/approved_buildings.gd")
const Materials=preload("res://presentation/approved_materials.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,1000)
 var studio:=Node3D.new()
 root.add_child(studio)
 var env:=WorldEnvironment.new()
 var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR
 settings.background_color=Color("a3a380")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color=Color("b6c5cc")
 settings.ambient_light_energy=0.4
 settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 settings.ssao_enabled=true
 settings.ssao_radius=0.6
 settings.ssao_intensity=1.6
 env.environment=settings
 studio.add_child(env)
 var sun:=DirectionalLight3D.new()
 sun.light_color=Color("ffe6bb")
 sun.light_energy=1.1
 sun.rotation_degrees=Vector3(-48,-31,0)
 sun.shadow_enabled=true
 sun.directional_shadow_max_distance=60
 studio.add_child(sun)
 var ground:=MeshInstance3D.new()
 var plane:=PlaneMesh.new()
 plane.size=Vector2(90,90)
 ground.mesh=plane
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=Color("828667")
 mat.roughness=1.0
 ground.material_override=mat
 ground.position.y=-0.025
 studio.add_child(ground)
 for kind in ["hall","training"]:
  var model:Node3D=Models.building(kind)
  Materials.apply(model)
  model.position.x=-4.55 if kind=="hall" else 4.55
  studio.add_child(model)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=25.5
 var target:=Vector3(0,2.1,0)
 camera.position=target+Vector3(14,20,31)
 studio.add_child(camera)
 camera.look_at(target)
 camera.current=true
 for i in range(8):await process_frame
 RenderingServer.force_draw(false,0.016)
 var suffix:String="after" if OS.get_cmdline_user_args().has("after") else "before"
 var path:String="user://approved-facade-strategy-"+suffix+".png"
 root.get_texture().get_image().save_png(path)
 print("STRATEGY_RENDER ",path)
 quit()
