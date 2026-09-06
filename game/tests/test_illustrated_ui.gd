extends SceneTree
var checks:=0
var failures: Array[String]=[]
var game: Node
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL: ",message)
func frames(n: int=3) -> void:
 for i in range(n):await process_frame
func run() -> void:
 root.size=Vector2i(1280,800)
 game=load("res://scenes/illustrated.tscn").instantiate();root.add_child(game);await frames(10)
 game.sim.paused=true
 var hud: CanvasLayer=game.hud
 expect(game.sim.peaceful and game.sim.battle==null,"illustrated scene starts in peaceful mode")
 expect(game.world.textures.size()>=12,"all approved artwork sprites are loaded")
 expect(game.world.people.size()==18 and game.world.buildings.size()==6,"renderer shows real people and initial buildings")
 expect(hud.blocks_pointer(Vector2(80,60)),"HUD catches resource clicks")
 hud._dismiss_tutorial();hud.close_panels();await frames()
 expect(not hud.blocks_pointer(Vector2(640,480)),"open terrain accepts village clicks")
 for c in [Vector2(13.5,3.5),Vector2(13.5,19.5),Vector2(18.5,7.5)]:
  expect(game.world.screen_to_cell(game.world.cell_to_screen(c))==Vector2i(c),"isometric projection round trip")
 hud.build_selected.emit("house")
 var count: int=game.sim.buildings.size()
 game._world_click(game.world.cell_to_screen(Vector2(13.5,3.5)))
 expect(game.sim.buildings.size()==count+1 and game.build_kind.is_empty(),"HUD and terrain create an actual autonomous construction site")
 game.world.sync(0)
 var site: Dictionary=game.sim.buildings.back()
 hud.inspect(site);hud._toggle_drawer("training");await frames(10)
 expect(hud._drawer.visible and hud._drawer_kind=="training","training can open while inspecting a site")
 hud._set_quantity(2);hud._train_role("servant")
 expect(game.sim.training.size()==2,"profession controls enqueue two servants without selecting people")
 hud.speed_selected.emit(4);expect(game.speed==4,"speed button controls actual clock")
 game._command("pause",{});expect(not game.sim.paused,"pause button resumes simulation")
 for i in range(2800):game.sim.step()
 game.sim.paused=true;game.world.sync(0)
 expect(game.sim.stats.houses_built==1,"autonomous workers finish the placed house")
 expect(game.sim.profession_counts().servant==5,"training forms both servants")
 var saved_tick: int=game.sim.tick
 expect(game._write_save("user://illustrated-ui-save.json"),"save writes to disk")
 game.sim.paused=false
 for i in range(50):game.sim.step()
 expect(game._load_paths(["user://illustrated-ui-save.json"]) and game.sim.tick==saved_tick,"load restores saved village exactly")
 expect(game.sim.battle==null,"restore keeps village without army")
 await frames()
 hud._toggle_drawer("build");await frames(10)
 expect(hud._build_grid.get_child_count()==8,"build menu contains eight civil building types")
 for resolution in [Vector2i(1280,800),Vector2i(980,650)]:
  root.size=resolution;await frames(12)
  hud._layout();await frames(5)
  expect(hud._drawer.get_global_rect().end.y<=resolution.y and hud._dock.get_global_rect().end.y<=resolution.y,"build controls fit screen "+str(resolution))
 hud.restart_requested.emit();await frames()
 expect(game.sim.tick==0 and game.sim.battle==null and game.sim.buildings.size()==6,"restart resets peaceful scene")
 print("ILLUSTRATED_UI_RESULT checks=",checks," failures=",failures)
 game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
