extends SceneTree
var game:Node
var sim:RefCounted
func _initialize()->void:call_deferred("run")
func frames(n:int=30)->void:
 for i in range(n):
  game.world.sync(0.016)
  await process_frame
func capture(path:String)->void:
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
 print("CAPTURE_SAVED ",path)
func run()->void:
 root.size=Vector2i(1600,1000)
 game=load("res://scenes/approved.tscn").instantiate();root.add_child(game);game.set_process(false);sim=game.sim
 await capture("user://approved-village-initial.png")
 game.hud._dismiss_tutorial();game.hud._toast.hide()
 game._select_build("road")
 var connection:Array[Vector2i]=[]
 for x in range(8,14):connection.append(Vector2i(x,13))
 game.world.set_road_preview(connection)
 await capture("user://approved-village-road-plan.png")
 game._command("road",{"cells":connection});game._select_build("")
 for i in range(90):sim.step()
 game.hud.refresh()
 await capture("user://approved-village-working.png")
 build_mission()
 for i in range(1600):sim.step()
 game.hud.refresh();game.world.focus_cell(Vector2i(13,16));game.world.target_size=36
 await capture("user://approved-village-building.png")
 for i in range(12000):
  sim.step()
  if sim.won:break
 game.hud.refresh();game.hud._toast.hide();game.world.focus_cell(Vector2i(13,13));game.world.target_size=43
 await capture("user://approved-village-grown.png")
 game.hud._toggle_drawer("build")
 await capture("user://approved-village-menu.png")
 game.hud._toggle_drawer("training")
 await capture("user://approved-village-professions.png")
 game.hud.close_panels();game.hud.hide()
 game.world.focus_cell(Vector2i(19,18));game.world.target_size=18
 await capture("user://approved-village-winery.png")
 game.world.focus_cell(Vector2i(24,14));game.world.target_size=25
 await capture("user://approved-village-river.png")
 print("APPROVED_MISSION_RENDER ",sim.stats," conservation ",sim.conservation_errors())
 quit()
func build_mission()->void:
 for plan in [["house",Vector2i(4,6)],["house",Vector2i(8,5)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)],["farm",Vector2i(16,19)],["vineyard",Vector2i(17,5)],["winery",Vector2i(18,17)],["store",Vector2i(7,18)]]:
  var result: Dictionary = sim.command("build",{"kind":plan[0],"cell":plan[1]})
  assert(result.ok,"legal approved mission construction "+plan[0]+": "+result.message)
 var roads: Array[Vector2i] = []
 for x in range(2,21): roads.append(Vector2i(x,13))
 for y in range(8,13): roads.append(Vector2i(5,y))
 for x in range(4,11): roads.append(Vector2i(x,8))
 for y in range(7,13): roads.append(Vector2i(15,y))
 for x in range(8,20): roads.append(Vector2i(x,7))
 for y in range(14,22): roads.append(Vector2i(5,y))
 for x in range(3,20): roads.append(Vector2i(x,21))
 roads.append(Vector2i(3,20))
 roads.append(Vector2i(19,20))
 assert(sim.command("road",{"cells":roads}).ok,"full mission network routes around the expanded main building and school")
 for role in ["lumberjack","stonecutter","farmer","vintner","vintner","servant","servant"]:
  assert(sim.command("train",{"role":role}).ok,"professional training request "+role)
