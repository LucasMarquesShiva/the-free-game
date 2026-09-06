extends SceneTree
## Exercises real input events against the 3D controller, HUD, camera and simulation.
const Game = preload("res://presentation/approved_game.gd")
var game: Node
var checks := 0
var failures: Array[String] = []
const SAVE_FILE := "user://vale-approved-integration-save.json"

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures.append(message)
  printerr("FAIL: ",message)
func frames(count: int = 4) -> void:
 for index in range(count): await process_frame
func mouse(button: MouseButton, pressed: bool, position: Vector2) -> void:
 var event := InputEventMouseButton.new()
 event.button_index = button
 event.pressed = pressed
 event.position = position
 game._input(event)
func motion(position: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
 var event := InputEventMouseMotion.new()
 event.position = position
 event.relative = relative
 game._input(event)
func key(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 game._input(event)
func point(cell: Vector2i) -> Vector2:
 return game.world.cell_to_screen(cell)
func begin_road(cell: Vector2i = Vector2i(10,13)) -> void:
 game._select_build("road")
 mouse(MOUSE_BUTTON_LEFT,true,point(cell))
func reset() -> void:
 game._restart()
 game.sim.paused = true
 game.hud._dismiss_tutorial()
 game.hud._toast.hide()
 game.world.sync(1.0)
func run() -> void:
 root.content_scale_size = Vector2i.ZERO
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(1280,800)
 game = Game.new()
 root.add_child(game)
 game.set_process(false)
 game.sim.paused = true
 game.hud._dismiss_tutorial()
 game.hud._toast.hide()
 await frames(8)
 expect(game.sim.buildings.size() == 2 and game.sim.battle == null,"real scene starts with the two civil buildings and no army")
 for cell in [Vector2i(8,13),Vector2i(13,13),Vector2i(10,16)]:
  expect(game.world.screen_to_cell(point(cell)) == cell,"3D picking matches cell projection "+str(cell))
 expect(not game.hud.blocks_pointer(point(Vector2i(9,13))),"road test starts on exposed terrain")
 begin_road(Vector2i(8,13))
 motion(point(Vector2i(13,13)))
 expect(game.road_path.size() == 6,"skipped mouse samples fill the five-cell school connection")
 var contiguous := true
 for index in range(1,game.road_path.size()):
  var delta: Vector2i = game.road_path[index]-game.road_path[index-1]
  contiguous = contiguous and absi(delta.x)+absi(delta.y) == 1
 expect(contiguous,"road stroke remains orthogonally contiguous")
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(13,13)))
 expect(game.sim.roads.size() == 4 and game.sim.reserved.stone == 4,"drag commits typed road cells and charges each new segment once")
 expect(game.build_kind == "road" and game.road_path.is_empty() and not game.pointer_down,"successful stroke retains road mode with clean gesture state")
 game.sim.paused = false
 for index in range(1000): game.sim.step()
 game.sim.paused = true
 expect(game.sim.is_building_connected(game.sim.buildings[1]),"input-built road is constructed automatically and connects school")
 expect(game.sim.conservation_errors().is_empty(),"controller road construction preserves simulation resources")
 reset()
 begin_road()
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(10,13)))
 expect(game.sim.roads.size() == 1,"isolated click places one road tile")
 game._world_click(point(Vector2i(11,13)))
 expect(game.sim.roads.size() == 2,"direct world click routes road mode to the road command")
 reset()
 begin_road()
 var camera_before: Vector3 = game.world.target_focus
 motion(Vector2(80,50),Vector2(200,50))
 expect(game.world.target_focus == camera_before,"drag entering HUD never pans the world")
 mouse(MOUSE_BUTTON_LEFT,false,Vector2(80,50))
 expect(game.sim.roads.is_empty() and game.road_path.is_empty() and not game.pointer_down,"releasing over HUD cancels the pending stroke")
 mouse(MOUSE_BUTTON_LEFT,true,Vector2(80,50))
 motion(point(Vector2i(11,13)))
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(11,13)))
 expect(game.sim.roads.is_empty(),"gesture starting on HUD cannot place roads on release")
 begin_road()
 motion(point(Vector2i(12,16)))
 contiguous = true
 for index in range(1,game.road_path.size()):
  var delta: Vector2i = game.road_path[index]-game.road_path[index-1]
  contiguous = contiguous and absi(delta.x)+absi(delta.y) == 1
 expect(contiguous and game.road_path.back() == Vector2i(12,16),"diagonal drag fills a legal orthogonal chain")
 key(KEY_ESCAPE)
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(12,16)))
 expect(game.sim.roads.is_empty() and game.build_kind.is_empty() and game.world.road_preview.get_child_count() == 0,"Escape clears road preview and release cannot place a ghost order")
 begin_road()
 game._select_build("house")
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(15,10)))
 expect(game.sim.buildings.size() == 2 and game.road_path.is_empty(),"changing build mode cannot reuse a held road gesture")
 begin_road()
 var yaw_before: float = game.world.target_yaw
 key(KEY_E)
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(12,13)))
 expect(game.world.target_yaw > yaw_before and game.sim.roads.is_empty() and not game.pointer_down,"orbit during drag cancels only the pending road stroke")
 expect(game.build_kind == "road","orbit preserves road tool selection")
 begin_road()
 camera_before = game.world.target_focus
 key(KEY_RIGHT)
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(11,13)))
 expect(game.world.target_focus != camera_before and game.sim.roads.is_empty(),"arrow pan during drag cannot commit shifted road cells")
 begin_road()
 var zoom_before: float = game.world.target_size
 mouse(MOUSE_BUTTON_WHEEL_UP,true,point(Vector2i(10,13)))
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(11,13)))
 expect(game.world.target_size < zoom_before and game.sim.roads.is_empty(),"zoom during drag cancels the pending stroke")
 camera_before = game.world.target_focus
 mouse(MOUSE_BUTTON_MIDDLE,true,point(Vector2i(10,13)))
 motion(point(Vector2i(11,13)),Vector2(45,20))
 mouse(MOUSE_BUTTON_MIDDLE,false,point(Vector2i(11,13)))
 expect(game.world.target_focus != camera_before and game.build_kind == "road" and game.sim.roads.is_empty(),"middle mouse pans while the road tool stays active")
 camera_before = game.world.target_focus
 mouse(MOUSE_BUTTON_MIDDLE,true,Vector2(80,50))
 motion(point(Vector2i(10,13)),Vector2(30,10))
 mouse(MOUSE_BUTTON_MIDDLE,false,point(Vector2i(10,13)))
 expect(game.world.target_focus == camera_before,"middle pan starting over HUD is ignored")
 reset()
 key(KEY_R)
 expect(game.build_kind == "road","R selects roads without choosing a person")
 begin_road(Vector2i(10,10))
 motion(point(Vector2i(14,10)))
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(14,10)))
 expect(game.sim.roads.is_empty() and game.sim.reserved.stone == 0,"stroke through a building is rejected atomically by the simulation")
 begin_road()
 reset()
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(10,13)))
 expect(game.sim.roads.is_empty() and game.sim.buildings.size() == 2 and game.road_path.is_empty() and not game.pointer_down,"restart clears pending placement and does not replay the old release")
 expect(game._write_save(SAVE_FILE),"approved controller writes its isolated save format")
 begin_road()
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(10,13)))
 begin_road(Vector2i(10,13))
 expect(game._load_paths([SAVE_FILE]),"controller loads the prior approved state")
 mouse(MOUSE_BUTTON_LEFT,false,point(Vector2i(12,13)))
 expect(game.sim.roads.is_empty() and game.build_kind.is_empty() and game.road_path.is_empty() and not game.pointer_down,"load clears in-flight input and release cannot alter the restored state")
 var file := FileAccess.open(SAVE_FILE,FileAccess.READ)
 var data: Dictionary = JSON.parse_string(file.get_as_text())
 file.close()
 data.speed = {"invalid":"metadata"}
 file = FileAccess.open(SAVE_FILE+".metadata",FileAccess.WRITE)
 file.store_string(JSON.stringify(data))
 file.close()
 expect(game._load_paths([SAVE_FILE+".metadata"]) and game.speed == 1,"malformed optional speed metadata falls back safely")
 game.hud.inspect(game.sim.buildings[1])
 expect(game.selected_id == game.sim.buildings[1].id and game.world.selected_id == game.selected_id,"HUD entrance highlight is connected to the real 3D selection")
 game.hud.close_panels()
 expect(game.selected_id == -1 and game.world.selected_id == -1,"closing inspection clears the 3D entrance marker")
 game.speed = 4
 game._process(0.01)
 expect(is_equal_approx(game.world.visual_speed,4.0*game.CIVIL_PACE),"controller applies the same natural pace to simulation and 3D animation")
 print("APPROVED_INTEGRATION_RESULT checks=",checks," failures=",failures)
 game.queue_free()
 await frames(5)
 quit(0 if failures.is_empty() else 1)
