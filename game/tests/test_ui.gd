extends SceneTree
var checks := 0
var failures: Array[String] = []
var game: Node
func _initialize() -> void:
	call_deferred("run")
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: "+message)
func frames(amount: int = 3) -> void:
	for i in range(amount): await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.sim.paused=true
	var hud: CanvasLayer = game.hud
	expect(hud.blocks_pointer(Vector2(80,60)),"resource bar catches clicks")
	expect(not hud.blocks_pointer(Vector2(640,420)),"open terrain accepts clicks")
	# Exercise actual signals connected to the game controller.
	hud.build_selected.emit("house")
	await frames()
	expect(game.build_kind=="house","build signal selects placement mode")
	var before: int = game.sim.buildings.size()
	var screen: Vector2 = game.world.camera.unproject_position(Vector3(26,0,6))
	game._world_click(screen)
	expect(game.sim.buildings.size()==before+1 and game.build_kind.is_empty(),"terrain selection creates an actual work site and leaves placement mode")
	var house: Dictionary = game.sim.buildings.back()
	hud.inspect(house)
	hud._toggle_drawer("army")
	await frames(20)
	expect(hud._drawer.visible and hud._drawer_kind=="army","inspecting a building does not forcibly close the army drawer")
	hud.close_panels()
	hud.command_requested.emit("train",{"role":"servant","quantity":2})
	expect(game.sim.training.size()==2,"training HUD signal submits profession and quantity")
	hud.speed_selected.emit(4)
	expect(game.speed==4,"speed control changes controller")
	hud.army_selected.emit("defend")
	game._world_click(game.world.camera.unproject_position(Vector3(30,0,28)))
	expect(game.sim.battle.order=="defend" and game.army_order.is_empty(),"collective military target is accepted without selecting an individual")
	var save_path := "user://vale-ui-save.json"
	expect(game._write_save(save_path),"save writes valid state to disk")
	var saved_tick: int = game.sim.tick
	game.sim.paused=false
	for i in range(130): game.sim.step()
	expect(game._load_paths([save_path]),"load restores actual on-disk state")
	expect(game.sim.tick==saved_tick,"load restores exact saved time")
	var saved_before: int = game.sim.tick
	var bad := FileAccess.open("user://vale-ui-bad.json",FileAccess.WRITE)
	bad.store_string('{"format":"vale-v1","simulation":{"version":1}}')
	bad.close()
	expect(not game._load_paths(["user://vale-ui-bad.json"]),"incomplete file safely rejected")
	expect(game.sim.tick==saved_before,"failed load leaves current game intact")
	hud.restart_requested.emit()
	expect(game.sim.tick==0 and game.sim.stats.houses_built==0,"restart resets mission through connected signal")
	print("UI_RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
