extends SceneTree
var game: Node
func _initialize() -> void:
 call_deferred("run")
func frames(n: int=3) -> void:
 for i in range(n): await process_frame
func run() -> void:
 root.size=Vector2i(1280,800)
 game=load("res://scenes/illustrated.tscn").instantiate();root.add_child(game)
 await frames(12)
 game.sim.paused=true
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://illustrated-initial.png")
 game.hud._dismiss_tutorial() if game.hud.has_method("_dismiss_tutorial") else game.hud.close_panels()
 game.sim.paused=false
 for plan in [["house",Vector2i(13,3)],["house",Vector2i(16,3)],["farm",Vector2i(13,19)],["vineyard",Vector2i(16,19)],["winery",Vector2i(18,7)]]:
  game.sim.command("build",{"kind":plan[0],"cell":plan[1]})
 game.sim.command("train",{"role":"servant","quantity":3})
 for i in range(6900):game.sim.step()
 game.sim.paused=true;game.world.sync(0);game.world.focus_cell(Vector2i(12,12));game.world.zoom_by(2)
 game.hud.refresh();game.hud.show_message("A vila prosperou: casas, horta, parreiral e vinícola em funcionamento.")
 await frames(10)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://illustrated-grown.png")
 print("ILLUSTRATED_RENDER_CAPTURED ",game.sim.stats)
 quit()
