extends SceneTree
const Game=preload("res://presentation/approved_game.gd")
var game:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func expect(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func frames(n:int=3)->void:
	for i in range(n):await process_frame
func point(cell:Vector2i)->Vector2:return game.world.cell_to_screen(cell)
func mouse(down:bool,position:Vector2,button:MouseButton=MOUSE_BUTTON_LEFT)->void:
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down;e.position=position;game._input(e)
func motion(position:Vector2,relative:Vector2=Vector2.ZERO)->void:
	var e:=InputEventMouseMotion.new();e.position=position;e.relative=relative;game._input(e)
func key(code:Key)->void:
	var e:=InputEventKey.new();e.keycode=code;e.pressed=true;game._input(e)
func click(cell:Vector2i)->void:mouse(true,point(cell));mouse(false,point(cell))
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1280,800)
	# This test asserts Portuguese HUD text; pin the language so the OS locale cannot change it.
	Locale.set_language("pt_BR",false)
	game=Game.new();root.add_child(game);game.set_process(false);game.sim.paused=true
	game.hud._dismiss_tutorial();game.hud._toast.hide();await frames(8)
	game.hud._tabs.road.pressed.emit()
	expect(game.build_kind=="road" and game.hud._road_toggle.visible,"road dock opens trace tool and erase toggle")
	click(Vector2i(9,13));click(Vector2i(10,13))
	expect(game.sim.reserved.stone==2,"two planned tiles reserve two stones")
	game.hud._road_toggle.pressed.emit()
	expect(game.build_kind=="remove_road" and game.hud._road_toggle.text=="Traçar estrada","toggle enters individual eraser and offers trace return")
	motion(point(Vector2i(9,13)))
	expect(game.world.road_preview.get_child_count()>0 and game.world.road_key.begins_with("erase"),"existing road gets eraser highlight")
	motion(point(Vector2i(11,13)))
	expect(game.world.road_preview.get_child_count()==0,"empty terrain has no red removal target")
	var stock:int=game.sim.stock.stone;var available:int=game.sim.available("stone")
	click(Vector2i(9,13))
	expect(game.sim.road_at(Vector2i(9,13)).is_empty() and not game.sim.road_at(Vector2i(10,13)).is_empty(),"one click removes exactly one planned tile")
	expect(game.sim.reserved.stone==1 and game.sim.stock.stone==stock and game.sim.available("stone")==available+1,"unstarted tile releases reservation without creating stock")
	expect(game.world.road_preview.get_child_count()==0,"removed tile loses its highlight immediately")
	# Pointer gestures cannot reuse the eraser as a brush or commit through HUD.
	var p:=point(Vector2i(10,13));var camera_before:Vector3=game.world.target_focus
	mouse(true,p);motion(p+Vector2(35,0),Vector2(35,0));mouse(false,p+Vector2(35,0))
	expect(not game.sim.road_at(Vector2i(10,13)).is_empty() and game.world.target_focus!=camera_before,"drag in erase mode pans without removing")
	motion(p)
	expect(game.world.road_preview.get_child_count()>0,"eraser hover resumes after releasing a pan")
	mouse(true,p);mouse(false,p+Vector2(35,0))
	expect(not game.sim.road_at(Vector2i(10,13)).is_empty(),"large release movement without motion event cannot remove")
	mouse(true,p);mouse(false,Vector2(80,50))
	expect(not game.sim.road_at(Vector2i(10,13)).is_empty(),"release over HUD cannot remove")
	mouse(true,Vector2(80,50));motion(p);mouse(false,p)
	expect(not game.sim.road_at(Vector2i(10,13)).is_empty(),"press over HUD cannot remove on world release")
	mouse(true,p);key(KEY_ESCAPE);mouse(false,p)
	expect(game.build_kind.is_empty() and not game.hud._road_toggle.visible and not game.sim.road_at(Vector2i(10,13)).is_empty(),"Escape clears eraser and in-flight press")
	game.hud._tabs.road.pressed.emit();game.hud._road_toggle.pressed.emit()
	mouse(true,p);mouse(true,p,MOUSE_BUTTON_MIDDLE);motion(p+Vector2(20,10),Vector2(20,10));mouse(false,p,MOUSE_BUTTON_MIDDLE);mouse(false,p)
	expect(not game.sim.road_at(Vector2i(10,13)).is_empty(),"middle pan cancels a pending erase click")
	game.hud._road_toggle.pressed.emit()
	expect(game.build_kind=="road" and game.hud._road_toggle.text=="Apagar trecho","toggle returns to trace without leaving road tool")
	game._select_build("house")
	expect(not game.hud._road_toggle.visible,"road toggle stays hidden for building placement")
	# Placing a plan under a stationary person is legal; removal guard must survive UI.
	expect(game.sim.command("road",{"cell":Vector2i(11,11)}).ok,"legal road plan under stationary instructor")
	game._select_build("remove_road");click(Vector2i(11,11))
	expect(not game.sim.road_at(Vector2i(11,11)).is_empty() and game.hud._toast_label.text.contains("Aguarde"),"occupied tile guard returns its explanation without removing")
	var saved_path:="user://vale-erase-ui-save.json"
	expect(game._write_save(saved_path),"removal scenario save succeeds")
	mouse(true,p);expect(game._load_paths([saved_path]),"removal scenario save restores");mouse(false,p)
	expect(game.build_kind.is_empty() and not game.sim.road_at(Vector2i(10,13)).is_empty(),"load clears eraser gesture without an unintended removal")
	game._select_build("remove_road");mouse(true,p);game._restart();mouse(false,p)
	expect(game.build_kind.is_empty() and game.sim.roads.is_empty() and not game.hud._road_toggle.visible,"restart clears eraser state")
	game.sim.paused=false
	var cells:Array[Vector2i]=[]
	for x in range(8,14):cells.append(Vector2i(x,13))
	expect(game.sim.command("road",{"cells":cells}).ok,"completed-road fixture uses legal order")
	for i in range(800):game.sim.step()
	game.sim.paused=true;game.world.sync(0.0);game.hud._toast.hide()
	var finished:Vector2i=Vector2i(-1,-1)
	for road in game.sim.roads:
		if road.stage=="complete" and road.builder==-1 and not game.sim._occupied(road.cell):finished=road.cell;break
	expect(finished.x>=0,"completed unoccupied road available for removal")
	stock=game.sim.stock.stone;var consumed:int=game.sim.consumed.stone
	game._select_build("remove_road");click(finished)
	expect(game.sim.road_at(finished).is_empty() and game.sim.stock.stone==stock and game.sim.consumed.stone==consumed,"completed road removal does not refund already consumed stone")
	expect(game.sim.conservation_errors().is_empty(),"all UI removals preserve resources")
	var raw:String=game.sim.definition("lumber").description
	for pair in [["lumber",20],["quarry",25],["farm",25],["vineyard",30],["winery",25]]:
		var description:String=game.hud._definition(pair[0]).description
		expect(description.contains(str(pair[1])+" segundos em 1×"),"UI production time reflects current1× pace: "+str(pair[0]))
	expect(game.sim.definition("lumber").description==raw,"UI description formatting leaves simulation definitions unchanged")
	for size:Vector2i in [Vector2i(1280,800),Vector2i(980,650)]:
		root.size=size;game.hud._layout();await frames()
		var bar:Rect2=game.hud._mode_panel.get_global_rect();var toggle:Rect2=game.hud._road_toggle.get_global_rect()
		expect(bar.encloses(toggle) and toggle.size.y>=44.0 and Rect2(Vector2.ZERO,Vector2(size)).encloses(bar),"road mode controls remain visible and touch-sized: "+str(size))
	print("ROAD_REMOVAL_UI_RESULT checks=",checks," failures=",failures)
	game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
