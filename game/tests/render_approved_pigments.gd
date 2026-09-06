extends SceneTree
func _initialize()->void:call_deferred("run")
func tune(node:Node,value:float)->void:
 if node is MeshInstance3D and node.material_override is ShaderMaterial:
  var material:ShaderMaterial=node.material_override
  if material.shader.resource_path.ends_with("terrain.gdshader") or material.shader.resource_path.ends_with("water.gdshader"):
   material.set_shader_parameter("pigment_softness",value)
 for child in node.get_children():tune(child,value)
func run()->void:
 root.size=Vector2i(1600,1000)
 var game=load("res://scenes/approved.tscn").instantiate();root.add_child(game);game.set_process(false)
 game.hud.visible=false
 var world=game.world
 world.focus=Vector3(35,0,35);world.target_focus=world.focus
 world.view_size=42;world.target_size=42
 for softness in [0.0,0.2,0.4]:
  tune(world.terrain,softness)
  for i in range(12):world.sync(0.016);await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("user://approved-pigment-%d.png"%roundi(softness*100))
 quit()
