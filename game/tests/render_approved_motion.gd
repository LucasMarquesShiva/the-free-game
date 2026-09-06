extends SceneTree
## Visual review only: legal setup is advanced before recording.
## Fixed 30 Hz frames demonstrate motion; this is not a performance measurement.
var game:Node
var sim:RefCounted
var output := "user://vale-vila-viva-motion"
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,720)
 game=load("res://scenes/approved.tscn").instantiate();root.add_child(game);game.set_process(false)
 sim=game.sim
 var connection:Array[Vector2i]=[]
 for x in range(8,14):connection.append(Vector2i(x,13))
 assert(game.sim.command("road",{"cells":connection}).ok)
 for i in range(90):game.sim.step()
 build_mission()
 for i in range(1600):game.sim.step()
 assert(game.sim.conservation_errors().is_empty())
 game.hud._dismiss_tutorial();game.hud._toast.hide();game.hud.hide()
 game.world.focus_cell(Vector2i(12,15));game.world.target_size=34
 for i in range(45):
  game.world.sync(1.0/30.0)
  await process_frame
 game.sim.paused=false;game.speed=1
 game.set_process(true)
 DirAccess.make_dir_recursive_absolute(output+"/frames")
 var tick_start:int=game.sim.tick
 for frame in range(360):
  if frame==180:game.world.focus_cell(Vector2i(14,17));game.world.target_size=23
  await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(output+"/frames/%04d.png"%frame)==OK)
 game.set_process(false)
 var meta={"frames":360,"fps":30,"size":[1280,720],"speed":1,"tick_start":tick_start,"tick_end":game.sim.tick,"conservation_errors":game.sim.conservation_errors(),"note":"Capturas sem retoque do motor, com passo fixo para avaliação de movimento. A preparação da vila foi adiantada por comandos legais. Não mede FPS real."}
 var file=FileAccess.open(output+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(meta,"\t"));file.close()
 print("MOTION_CAPTURE ",JSON.stringify(meta))
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
