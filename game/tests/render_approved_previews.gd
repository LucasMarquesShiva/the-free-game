extends SceneTree
const Models=preload("res://presentation/approved_buildings.gd")
const Materials=preload("res://presentation/approved_materials.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(384,320)
 root.transparent_bg=true
 root.msaa_3d=Viewport.MSAA_4X
 var studio:=Node3D.new();root.add_child(studio)
 var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_CLEAR_COLOR;settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("bacddd");settings.ambient_light_energy=0.38;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=settings;studio.add_child(env)
 RenderingServer.set_default_clear_color(Color(0,0,0,0))
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-31,0);sun.light_color=Color("fff0d7");sun.light_energy=1.06;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40;studio.add_child(sun)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;studio.add_child(camera);camera.current=true
 DirAccess.make_dir_recursive_absolute("res://assets/approved/previews")
 for kind in ["hall","house","store","training","lumber","quarry","farm","vineyard","winery"]:
  var node:Node3D=Models.building(kind);studio.add_child(node);Materials.apply(node)
  var box:AABB=node.get_node("Architecture").get_aabb()
  var target:=Vector3(0,box.size.y*0.42,0)
  camera.size=maxf(box.size.y*1.25,box.size.x*1.25+box.size.z*0.3)
  camera.position=target+Vector3(17,16,26);camera.look_at(target)
  for i in range(10):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://assets/approved/previews/"+kind+".png")
  print("PREVIEW_SAVED ",kind)
  node.free()
 quit()
