extends SceneTree
var game:Node
func _initialize()->void:call_deferred("run")
func frames(n:int=8)->void:
 for i in range(n):await process_frame
func capture(path:String)->void:
 await frames(18)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run()->void:
 root.size=Vector2i(1440,900)
 game=load("res://scenes/frontier.tscn").instantiate();root.add_child(game)
 await capture("user://frontier-initial.png")
 game.hud._dismiss_tutorial()
 game._select_build("road")
 var cells:Array[Vector2i]=[]
 for x in range(7,13):cells.append(Vector2i(x,12))
 game.world.set_road_preview(cells)
 await capture("user://frontier-road-plan.png")
 game._command("road",{"cells":cells});game._select_build("")
 game.speed=4
 var end:=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<end:await process_frame
 await capture("user://frontier-working.png")
 # Exercise a complete settlement through legal player commands for visual QA.
 for plan in [["house",Vector2i(4,6)],["house",Vector2i(8,5)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)],["farm",Vector2i(16,19)],["vineyard",Vector2i(17,5)],["winery",Vector2i(18,14)]]:game.sim.command("build",{"kind":plan[0],"cell":plan[1]})
 cells.clear()
 for x in range(2,21):cells.append(Vector2i(x,12))
 for y in range(8,12):cells.append(Vector2i(5,y))
 for x in range(4,11):cells.append(Vector2i(x,8))
 for y in range(7,12):cells.append(Vector2i(15,y))
 for x in range(8,20):cells.append(Vector2i(x,7))
 for y in range(13,22):cells.append(Vector2i(5,y))
 for x in range(3,20):cells.append(Vector2i(x,21))
 cells.append(Vector2i(3,20))
 for y in range(13,17):cells.append(Vector2i(20,y))
 for x in range(18,20):cells.append(Vector2i(x,16))
 game.sim.command("road",{"cells":cells})
 for role in ["lumberjack","stonecutter","farmer","vintner","vintner","servant","servant"]:game.sim.command("train",{"role":role})
 for tick in range(8000):game.sim.step()
 game.world.focus_cell(Vector2i(13,13));game.world.zoom_by(13);game.hud.refresh()
 end=Time.get_ticks_msec()+4000
 while Time.get_ticks_msec()<end:await process_frame
 await capture("user://frontier-grown.png")
 print("FRONTIER_RENDER_READY ",game.sim.stats," fps ",Engine.get_frames_per_second())
 quit()
