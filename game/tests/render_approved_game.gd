extends SceneTree
var game:Node
func _initialize()->void:call_deferred("run")
func frames(n:int=16)->void:
 for i in range(n):await process_frame
func capture(path:String)->void:
 await frames(40)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
 print("CAPTURE_SAVED ",path)
func run()->void:
 root.size=Vector2i(1600,1000)
 game=load("res://scenes/approved.tscn").instantiate();root.add_child(game)
 await frames(20)
 game.sim.paused=true
 await capture("user://approved-game-initial.png")
 game.hud._dismiss_tutorial()
 game.world.focus=Vector3(27,0,30);game.world.target_focus=game.world.focus
 game.world.view_size=30;game.world.target_size=30
 await capture("user://approved-game-close.png")
 game.hud.hide()
 game.world.view_size=17;game.world.target_size=17
 game.world.focus=Vector3(20,0,28);game.world.target_focus=game.world.focus
 await capture("user://approved-game-hall.png")
 game.world.focus=Vector3(32.5,0,28);game.world.target_focus=game.world.focus
 await capture("user://approved-game-school.png")
 print("APPROVED_RENDER_READY fps ",Engine.get_frames_per_second())
 quit()
