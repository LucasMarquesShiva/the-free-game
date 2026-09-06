extends SceneTree
const Sim=preload("res://simulation/approved_sim.gd")
const Terrain=preload("res://presentation/approved_terrain.gd")
const People=preload("res://presentation/approved_people.gd")
var sim:RefCounted
var terrain:Node3D
var actor_root:Node3D
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,1000);root.msaa_3d=Viewport.MSAA_4X
 var stage:=Node3D.new();root.add_child(stage)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-38,0);light.light_color=Color("fff0d7");light.light_energy=0.85 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.06;light.shadow_enabled=true;light.directional_shadow_max_distance=100;light.shadow_bias=0.035;light.shadow_normal_bias=0.22;stage.add_child(light)
 var we:=WorldEnvironment.new();var env:=Environment.new();we.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color("b5cbbb");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b9d2dc");env.ambient_light_energy=0.36;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(we)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=23.0;stage.add_child(camera);camera.position=Vector3(57.5,0,35)+Vector3(sin(0.48)*36,30,cos(0.48)*36);camera.look_at(Vector3(57.5,0,35));camera.make_current()
 sim=Sim.new();sim.setup();terrain=Terrain.new();stage.add_child(terrain);terrain.setup(sim)
 var cells:Array=[]
 for y in [13,14,15]:
  for x in range(20,27):cells.append(Vector2i(x,y))
 sim.command("road",{"cells":cells});terrain.sync()
 actor_root=Node3D.new();stage.add_child(actor_root)
 for fixture in [[Vector2i(21,13),1],[Vector2i(25,13),13],[Vector2i(22,14),4],[Vector2i(23,15),6],[Vector2i(24,13),8]]:
  var cell:Vector2i=fixture[0];var id:int=fixture[1]
  var x:float=cell.x*2.5+sin(id*19.7)*0.38;var z:float=cell.y*2.5+sin(id*13.1)*0.38
  var actor:Node3D=People.create("builder" if id%2 else "servant",id);actor.position=Vector3(x,terrain.support_height(x,z)+0.04,z);actor.rotation.y=-PI/2;actor_root.add_child(actor)
 await capture("planned")
 for road:Dictionary in sim.roads:road.stage="complete"
 sim._rebuild_roads();terrain.sync()
 await capture("complete")
 # Same scene closer and lower for bridge entrance contact inspection.
 camera.size=10;camera.position=Vector3(52.6,0,33)+Vector3(8,8,12);camera.look_at(Vector3(53.4,0,33.7))
 await capture("feet")
 stage.free();quit()
func capture(label:String)->void:
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 var path:String="user://terrain-fixed-"+RenderingServer.get_current_rendering_method()+"-"+label+".png"
 var result:int=root.get_texture().get_image().save_png(path)
 print("TERRAIN_CAPTURE ",path," status=",result)
