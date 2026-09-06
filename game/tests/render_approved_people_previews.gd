extends SceneTree
## Renders the actual playable civilians for the profession picker.
const People=preload("res://presentation/approved_people.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(256,320);root.transparent_bg=true;root.msaa_3d=Viewport.MSAA_4X
 RenderingServer.set_default_clear_color(Color(0,0,0,0))
 var studio:=Node3D.new();root.add_child(studio)
 var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_CLEAR_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c4d3d8");env.ambient_light_energy=0.40;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;studio.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,145,0);sun.light_color=Color("fff0d7");sun.light_energy=1.03;sun.shadow_enabled=true;studio.add_child(sun)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-18,-32,0);fill.light_color=Color("dce8f1");fill.light_energy=0.20;studio.add_child(fill)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.42;studio.add_child(camera);camera.position=Vector3(0.48,1.45,-6);camera.look_at(Vector3(0,1.21,0));camera.current=true
 DirAccess.make_dir_recursive_absolute("res://assets/approved/people-previews")
 for role:String in ["builder","servant","farmer","vintner","lumberjack","stonecutter","instructor"]:
  var person:=People.create(role,1,0);studio.add_child(person);People.animate(person,0.0,false,false,false)
  for i in range(12):await process_frame
  await RenderingServer.frame_post_draw
  var result:=root.get_texture().get_image().save_png("res://assets/approved/people-previews/"+role+".png")
  assert(result==OK,"render playable profession portrait "+role)
  print("PEOPLE_PREVIEW_SAVED ",role)
  person.free()
 quit()
